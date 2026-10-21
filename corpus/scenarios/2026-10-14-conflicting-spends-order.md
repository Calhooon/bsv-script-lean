# Conflicting spends: arrival order, concurrency and reorg (#90)

[M] 2026-10-14, lane spend-90. [D] Synthetic isolated regtest-intake profile
from README.md with two funding transactions, `F1` and `F2`, each with one
spendable output `fund`, both in `base` at height 101; each spends one of the two
outputs of the height-1 coinbase (the runner's `seed_pair`, harness/src/scenarios/intake.rs;
a coinbase at height 2 is at depth 99 at 101, below `COINBASE_MATURITY` 100,
src/consensus/consensus.h:75 and src/validation.cpp:2617-2623 [SRC] 6504a3af; lane
cut2-66q2, 2026-10-15). `A` spends `F1:fund` then `F2:fund`; `B` spends
`F2:fund` then `F1:fund`; `C` and `D` each spend `F1:fund` alone. Every named
transaction is otherwise valid with a sufficient fee. Two steps and two
variants: the primary trace is sequential arrival (the two nodes agree,
`BsvChain.Teranode.accepted_eq_mempool`); `concurrent` submits `A` and `B`
together; `reorg` connects and invalidates a block whose `D` double-spends the
pool's `C`.

[SRC] bitcoin-sv v1.2.3 at 6504a3aff65ba97c0f6c80962b033e35ecbfed4b:
src/validation.cpp:1147-1152 (the conflict stage), src/validation.cpp:1484-1494
and src/txn_double_spend_detector.cpp:11-57 (the detector),
src/txmempool.cpp:298-304 (the spent index), src/txmempool.cpp:1025-1173
(removal for a block) and src/txmempool.cpp:2283-2443 (re-admission after a
disconnection). Teranode v0.16.0 at 4edb60a40c6628ff0ef60231c2628efd7103fde5:
stores/utxo/aerospike/spend.go:387-548 (the spend and its rollback),
services/validator/Validator.go:1105-1257 (the mempool path),
stores/utxo/process_conflicting.go:135,458 (the reorg swap) and
services/blockassembly/subtreeprocessor/SubtreeProcessor.go:4159-4264. The
store is Teranode's Aerospike backend; the SQL backend
(stores/utxo/sql/sql.go), which the `test` settings context selects
(settings.conf:1592), reaches the same per-output outcomes by a per-input
enqueue into one serialized batch (sql.go:223,2104-2128,2206-2207,2275) [SRC]
4edb60a4. The Lean model's witnesses are about the Aerospike store; the
instance of record runs `SETTINGS_CONTEXT=test` (docs/lanes/harness.md, A3),
so its store is SQLite, and `realization` says what each backend needs.

[D] The `second_oracle` objects are the Teranode column's expectations, read
from source through the Lean model (`lean/BsvChain/Teranode/Spend.lean`), never
the reference's rule: `store_mempool` is the store's unmined, non-conflicting
records, `spenders` the spending data per output. `submitConcurrent`, the `*_one_of` keys and
`fork_after: "initial"` (a variant forked before `s1`) are new to this format: the runner's support for them is owed
by #66, and a disagreement between the two columns is a finding with a witness
transaction (rule 4), never a sentence. Nothing here was run [D].

```json
{
  "id": "2026-10-14-conflicting-spends-order",
  "class": "the earlier spend wins: earliest-seen under arrival order, concurrency and reorg (#90 done-bar)",
  "witness": "#90: BsvChain.Teranode.accepted_eq_mempool (sequential arrival agrees), concurrent_both_refused and reorg_keeps_differ (the two model witnesses, unobserved)",
  "input_label": "[D]",
  "source_pin": "6504a3aff65ba97c0f6c80962b033e35ecbfed4b",
  "second_oracle_pin": "4edb60a40c6628ff0ef60231c2628efd7103fde5",
  "initial_chain": {
    "profile": "regtest-intake",
    "input_label": "[D]",
    "params": "BsvChain.ChainParams.regtest",
    "config": "README.md initial-chain profile; F1 and F2 each spend one of the two outputs of the height-1 coinbase, both in base",
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
      "F1",
      "F2"
    ],
    "watched_transactions": [
      "F1",
      "F2",
      "A",
      "B",
      "C",
      "D"
    ],
    "transactions": {
      "F1": {
        "value": "minedActive",
        "label": "[D]",
        "rules": [
          "mine"
        ],
        "node": "pending #66",
        "height": 101
      },
      "F2": {
        "value": "minedActive",
        "label": "[D]",
        "rules": [
          "mine"
        ],
        "node": "pending #66",
        "height": 101
      },
      "A": {
        "value": "unknown",
        "label": "[D]",
        "rules": [
          "unchanged"
        ],
        "node": "pending #66"
      },
      "B": {
        "value": "unknown",
        "label": "[D]",
        "rules": [
          "unchanged"
        ],
        "node": "pending #66"
      },
      "C": {
        "value": "unknown",
        "label": "[D]",
        "rules": [
          "unchanged"
        ],
        "node": "pending #66"
      },
      "D": {
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
      "id": "s1",
      "label": "[D]",
      "node": "pending #66",
      "action": {
        "type": "submit",
        "transaction": "A",
        "now": 1700000000
      },
      "kind": "policy admission; consensus prerequisites",
      "rules": [
        "receive"
      ],
      "expected_observations": {
        "label": "[D]",
        "node": "pending #66",
        "mempool": [
          "A"
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
          "F1": {
            "value": "minedActive",
            "label": "[D]",
            "rules": [
              "mine"
            ],
            "node": "pending #66",
            "height": 101
          },
          "F2": {
            "value": "minedActive",
            "label": "[D]",
            "rules": [
              "mine"
            ],
            "node": "pending #66",
            "height": 101
          },
          "A": {
            "value": "inMempool",
            "label": "[D]",
            "rules": [
              "receive"
            ],
            "node": "pending #66"
          },
          "B": {
            "value": "unknown",
            "label": "[D]",
            "rules": [
              "unchanged"
            ],
            "node": "pending #66"
          }
        },
        "utxos": {
          "F1:fund": "spent in pool by A",
          "F2:fund": "spent in pool by A",
          "A:credit": "absent",
          "B:credit": "absent"
        },
        "second_oracle": {
          "label": "[D]",
          "node": "pending #66",
          "store_mempool": [
            "A"
          ],
          "conflicting": [],
          "spenders": {
            "F1:fund": "A",
            "F2:fund": "A"
          },
          "basis": "BsvChain.Teranode.submit; accepted_eq_mempool"
        }
      },
      "timing_sensitive": true,
      "timing_note": "[M] 2026-10-16, lane ns-140 (#140 item 4, the road's input of 2026-10-16 00:57 UTC on #140): the second oracle's verdict on this step differs between runs at one harness code (checks 4 and 5 at d693844b and a6347801, whose harness differs in a README only); read as timing-sensitive, not adjudicated, and no run is re-cut for it; the readings are the projections' own",
      "timing_readings": [
        {
          "run": "the record of cut 2, chunk c1",
          "verdict": "agree",
          "projection": "docs/records/20261015-170946-s6-66-cut2-second-oracle-s3.json",
          "record": "docs/records/20261015-170946-s6-66-cut2q5-column-s3.md"
        },
        {
          "run": "check 4 (whole)",
          "verdict": "diverge",
          "projection": "docs/records/20261015-233751-s6-66-cut2-second-oracle-s3.json",
          "record": "docs/records/20261015-233751-s8-97-contract-check4-s4b.md"
        },
        {
          "run": "check 5 (whole)",
          "verdict": "agree",
          "projection": "docs/records/20261016-001926-s6-66-cut2-second-oracle-s3.json",
          "record": "docs/records/20261016-001926-s8-97-contract-check5-s4b.md"
        }
      ]
    },
    {
      "id": "s2",
      "label": "[D]",
      "node": "pending #66",
      "action": {
        "type": "submit",
        "transaction": "B",
        "now": 1700000000
      },
      "kind": "policy admission refused by the conflict stage",
      "rules": [
        "receive"
      ],
      "expected_observations": {
        "label": "[D]",
        "node": "pending #66",
        "mempool": [
          "A"
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
          "F1": {
            "value": "minedActive",
            "label": "[D]",
            "rules": [
              "mine"
            ],
            "node": "pending #66",
            "height": 101
          },
          "F2": {
            "value": "minedActive",
            "label": "[D]",
            "rules": [
              "mine"
            ],
            "node": "pending #66",
            "height": 101
          },
          "A": {
            "value": "inMempool",
            "label": "[D]",
            "rules": [
              "receive"
            ],
            "node": "pending #66"
          },
          "B": {
            "value": "rejected",
            "label": "[D]",
            "rules": [
              "receive"
            ],
            "node": "pending #66",
            "namespace": "node",
            "code": 258,
            "reason": "txn-mempool-conflict"
          }
        },
        "utxos": {
          "F1:fund": "spent in pool by A",
          "F2:fund": "spent in pool by A",
          "A:credit": "absent",
          "B:credit": "absent"
        },
        "evidence": [
          "the reference refuses at src/validation.cpp:1147-1152 [SRC]; Teranode refuses on the store's SPENT error and rolls back (Validator.go:1143-1257) [SRC]"
        ],
        "second_oracle": {
          "label": "[D]",
          "node": "pending #66",
          "store_mempool": [
            "A"
          ],
          "conflicting": [],
          "spenders": {
            "F1:fund": "A",
            "F2:fund": "A"
          },
          "basis": "the spend of F2:fund fails SPENT; nothing of B persists"
        }
      }
    }
  ],
  "variants": [
    {
      "id": "concurrent",
      "fork_after": "initial",
      "steps": [
        {
          "id": "c1",
          "label": "[D]",
          "node": "pending #66",
          "action": {
            "type": "submitConcurrent",
            "transactions": [
              "A",
              "B"
            ],
            "now": 1700000000,
            "realization": "both raw transactions sent without awaiting the other's reply: on the reference two sendrawtransaction calls on two RPC connections; on Teranode two propagation submissions (#97's observation contract); repeated on fresh pairs until each outcome class is recorded or the budget ends, the count recorded; record the instance's `utxostore` setting; on Aerospike the empty outcome needs A's and B's input groups in two spend batches in flight together (a batch closes at 100 items or 100 ms, `settings/settings.go:485-486`), on SQLite it needs their inputs interleaved inside one batch (`stores/utxo/sql/sql.go:2104-2128,2275`), or across two, since SQL batches run one at a time (`sql.go:223`); on both, each losing claim lands before the holder's rollback (BsvChain.Teranode.concurrent_outcome_iff)",
            "pairs": "A spends F1:fund then F2:fund; B spends F2:fund then F1:fund (two parent records)"
          },
          "kind": "concurrent double spend; detector serialization in the reference",
          "rules": [
            "receive"
          ],
          "expected_observations": {
            "label": "[D]",
            "node": "pending #66",
            "mempool_one_of": [
              [
                "A"
              ],
              [
                "B"
              ]
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
            "evidence": [
              "the reference keeps exactly one: its detector inserts every input of a transaction under one mutex, the other refused txn-double-spend-detected (code 18) or txn-mempool-conflict (code 258); src/txn_double_spend_detector.cpp:11-57, src/validation.cpp:1484-1494 [SRC]"
            ],
            "second_oracle": {
              "label": "[D]",
              "node": "pending #66",
              "store_mempool_one_of": [
                [
                  "A"
                ],
                [
                  "B"
                ],
                []
              ],
              "basis": "the empty outcome is BsvChain.Teranode.concurrent_both_refused: each spend wins one record and loses the other, both roll back (spend.go:513-527); in one batch the earlier group wins (spend.go:692, duplicate_spend.go:15-52); across two concurrent batches (aerospike.go:514-516) each can win one record [SRC]; the exact condition over every schedule is BsvChain.Teranode.concurrent_outcome_iff; observing it is the finding, its absence over the recorded count is not a proof"
            }
          }
        }
      ]
    },
    {
      "id": "reorg",
      "fork_after": "initial",
      "steps": [
        {
          "id": "r1",
          "label": "[D]",
          "node": "pending #66",
          "action": {
            "type": "submit",
            "transaction": "C",
            "now": 1700000000
          },
          "kind": "policy admission",
          "rules": [
            "receive"
          ],
          "expected_observations": {
            "label": "[D]",
            "node": "pending #66",
            "mempool": [
              "C"
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
              "F1": {
                "value": "minedActive",
                "label": "[D]",
                "rules": [
                  "mine"
                ],
                "node": "pending #66",
                "height": 101
              },
              "C": {
                "value": "inMempool",
                "label": "[D]",
                "rules": [
                  "receive"
                ],
                "node": "pending #66"
              },
              "D": {
                "value": "unknown",
                "label": "[D]",
                "rules": [
                  "unchanged"
                ],
                "node": "pending #66"
              }
            },
            "utxos": {
              "F1:fund": "spent in pool by C",
              "C:credit": "absent",
              "D:credit": "absent"
            },
            "second_oracle": {
              "label": "[D]",
              "node": "pending #66",
              "store_mempool": [
                "C"
              ],
              "conflicting": [],
              "spenders": {
                "F1:fund": "C"
              },
              "basis": "BsvChain.Teranode.submit"
            }
          }
        },
        {
          "id": "r2",
          "label": "[D]",
          "node": "pending #66",
          "action": {
            "type": "mine",
            "branch": "X",
            "parent": "base",
            "block": "X",
            "transactions": [
              "D"
            ],
            "method": "submitblock",
            "now": 1700000001
          },
          "kind": "block connection with a spend conflicting with the pool",
          "rules": [
            "mine",
            "conflict"
          ],
          "expected_observations": {
            "label": "[D]",
            "node": "pending #66",
            "mempool": [],
            "non_final_pool": [],
            "tip": {
              "block": "X",
              "height": 102
            },
            "chain_tips": [
              {
                "block": "X",
                "status": "active"
              }
            ],
            "transactions": {
              "F1": {
                "value": "minedActive",
                "label": "[D]",
                "rules": [
                  "mine"
                ],
                "node": "pending #66",
                "height": 101
              },
              "C": {
                "value": "conflictedByMinedSpend",
                "label": "[D]",
                "rules": [
                  "conflict"
                ],
                "node": "pending #66"
              },
              "D": {
                "value": "minedActive",
                "label": "[D]",
                "rules": [
                  "mine"
                ],
                "node": "pending #66",
                "height": 102
              }
            },
            "utxos": {
              "F1:fund": "spent by D (active)",
              "C:credit": "absent",
              "D:credit": "unspent"
            },
            "second_oracle": {
              "label": "[D]",
              "node": "pending #66",
              "store_mempool": [],
              "conflicting": [
                "C"
              ],
              "spenders": {
                "F1:fund": "D"
              },
              "basis": "D created conflicting at validation (Validator.go:1155,1169-1217), then ProcessConflicting at connection (SubtreeProcessor.go:5272, after the mined mark :5253-5259)"
            }
          }
        },
        {
          "id": "r3",
          "label": "[D]",
          "node": "pending #66",
          "action": {
            "type": "invalidateBlock",
            "block": "X",
            "now": 1700000002,
            "completion": "clean undo and policy re-admission completed"
          },
          "kind": "disconnection; the reference re-admits the block's transactions",
          "rules": [
            "invalidate"
          ],
          "expected_observations": {
            "label": "[D]",
            "node": "pending #66",
            "mempool": [
              "D"
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
                "block": "X",
                "status": "invalid"
              }
            ],
            "transactions": {
              "F1": {
                "value": "minedActive",
                "label": "[D]",
                "rules": [
                  "mine"
                ],
                "node": "pending #66",
                "height": 101
              },
              "C": {
                "value": "unknown",
                "label": "[D]",
                "rules": [
                  "invalidate",
                  "unchanged"
                ],
                "node": "pending #66"
              },
              "D": {
                "value": "inMempool",
                "label": "[D]",
                "rules": [
                  "invalidate"
                ],
                "node": "pending #66"
              }
            },
            "utxos": {
              "F1:fund": "spent in pool by D",
              "C:credit": "absent",
              "D:credit": "absent"
            },
            "evidence": [
              "the reference removed C at the connection (src/txmempool.cpp:1025-1173) and re-admits D (src/txmempool.cpp:2283-2443) [SRC]"
            ],
            "second_oracle": {
              "label": "[D]",
              "node": "pending #66",
              "store_mempool": [
                "C"
              ],
              "conflicting": [
                "D"
              ],
              "spenders": {
                "F1:fund": "C"
              },
              "basis": "BsvChain.Teranode.reorg_keeps_differ: ReverseProcessConflicting restores C and marks D (process_conflicting.go:420-458, SubtreeProcessor.go:4205); after a reorg through reorgBlocks C stays out of block assembly until resubmitted (SubtreeProcessor.go:4226-4251); after an invalidation, as here, handleReorg resets and reloads unmined transactions (BlockAssembler.go:2258-2291); a large reorg resets without the reverse (:2225-2239) [SRC] 4edb60a4; the realization on Teranode of an invalidation is #74's"
            }
          }
        }
      ]
    }
  ],
  "replay": {
    "node": "pending #66",
    "runner": "#66",
    "second_oracle": "#66 cut 2 with #74's Teranode instance",
    "views": "#67"
  }
}
```
