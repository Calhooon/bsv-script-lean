# Record lifetimes: expiry, coinbase maturity and the locked window (#92)

[M] 2026-10-15, lane s8-92. [D] Synthetic isolated regtest-intake profile from
README.md: `F1` a funding transaction mined in `base` at height 101 with one
spendable output `fund` (as the presence scenario's `F`); `CB2` and `CB3` the
height-2 and height-3 coinbases of `base`, each with one spendable output `fund`
paying a fixture key. `T` spends `F1:fund`; `S2` spends `CB2:fund`; `S3` spends
`CB3:fund`; `P` spends `F1:fund` and `C` spends `P:credit`. Every named
transaction is otherwise valid with a sufficient fee. Three primary steps and two
variants: the primary trace crosses the reference's expiry on both sides of its
strict cutoff (the nodes differ by design at `s3`,
`BsvChain.Teranode.Lifetimes.expiry_rules_differ`); `maturity` crosses the
coinbase boundary at depth 99 and 100 (the nodes agree,
`BsvChain.Teranode.Lifetimes.coinbase_maturity_agrees`); `locked` aims a child
at its parent's two-phase commit window, a mark the reference has no
counterpart for (`BsvChain.Teranode.Lifetimes.locked_refuses`).

[SRC] bitcoin-sv v1.2.3 at 6504a3aff65ba97c0f6c80962b033e35ecbfed4b:
src/txmempool.cpp:2201-2220 (`Expire`, the strict cutoff at :2207),
src/validation.cpp:853-856 (its call), src/config.cpp:87 and
src/validation.h:91 (`-mempoolexpiry`, 336 hours, POLICY),
src/validation.cpp:2617-2625 and src/consensus/consensus.h:75 (the coinbase
maturity, 100, consensus). Teranode v0.16.0 at
4edb60a40c6628ff0ef60231c2628efd7103fde5: stores/utxo/aerospike/create.go:892-899,919-921
(the coinbase's `spendingHeight`, the unmined stamp),
stores/utxo/aerospike/teranode.lua:305-333 (the spend's locked and coinbase
gates), :974-1055 (`setDeleteAtHeight`), stores/utxo/pruner_unmined.go:37-151
(an old unmined record is kept and only its parents preserved),
services/validator/Validator.go:663-690,2147-2152 and :1610-1630 (the locked
window and its retries). The model is the Aerospike store; the instance of
record runs `SETTINGS_CONTEXT=test`, so its store is SQLite
(stores/utxo/sql/sql.go), whose lifetime statements are a reading owed with this
file's measured run.

[D] The `second_oracle` objects are the Teranode column's expectations, read
from source through the Lean model (`lean/BsvChain/Teranode/Lifetimes.lean`),
never the reference's rule: `store_mempool` is the store's unmined,
non-conflicting records, `records` the marks of the named records. At `s3` the
columns disagree by design: `-mempoolexpiry` is a policy setting with no
Teranode counterpart, so the runner records that row as non-judging with this
file's basis, never as a divergence. Teranode's own unmined age is counted in
blocks and selects only the record's parents for preservation; crossing it
without mining `T` needs a transaction the assembler holds and never mines;
this lane found no setting for that at the pin [D], so no step drives it. The `locked`
variant's window is timing: its `realization` says how a run aims at it, and a
run that never lands inside it records the count. A `blocks` entry names the
fixture's block (`base@3`, the height-3 block of `base`; `b102`); Teranode's
`blockIDs` are store IDs, read through #97's observation contract at run time.
Nothing here was run [D];
every node marker is `pending #66` (#66's cut 2).

```json
{
  "id": "2026-10-15-record-lifetimes",
  "class": "record lifetimes: the reference's expiry against Teranode's unmined record, coinbase maturity on both nodes, the locked window (#92 done-bar)",
  "witness": "#92: BsvChain.Teranode.Lifetimes.expiry_rules_differ (removal differs by design), coinbase_maturity_agrees (maturity agrees), locked_refuses (no reference counterpart)",
  "input_label": "[D]",
  "source_pin": "6504a3aff65ba97c0f6c80962b033e35ecbfed4b",
  "second_oracle_pin": "4edb60a40c6628ff0ef60231c2628efd7103fde5",
  "initial_chain": {
    "profile": "regtest-intake",
    "input_label": "[D]",
    "params": "BsvChain.ChainParams.regtest",
    "config": "README.md initial-chain profile; F1 a funding transaction mined in base at height 101 with one spendable output fund (as the presence scenario's F); CB2 and CB3 the height-2 and height-3 coinbases of base, each with one spendable output fund paying a fixture key",
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
      "CB2",
      "CB3"
    ],
    "watched_transactions": [
      "F1",
      "CB2",
      "CB3",
      "T",
      "S2",
      "S3",
      "P",
      "C"
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
      "CB2": {
        "value": "minedActive",
        "label": "[D]",
        "rules": [
          "mine"
        ],
        "node": "pending #66",
        "height": 2
      },
      "CB3": {
        "value": "minedActive",
        "label": "[D]",
        "rules": [
          "mine"
        ],
        "node": "pending #66",
        "height": 3
      },
      "T": {
        "value": "unknown",
        "label": "[D]",
        "rules": [
          "unchanged"
        ],
        "node": "pending #66"
      },
      "S2": {
        "value": "unknown",
        "label": "[D]",
        "rules": [
          "unchanged"
        ],
        "node": "pending #66"
      },
      "S3": {
        "value": "unknown",
        "label": "[D]",
        "rules": [
          "unchanged"
        ],
        "node": "pending #66"
      },
      "P": {
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
        "transaction": "T",
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
          "F1": {
            "value": "minedActive",
            "label": "[D]",
            "rules": [
              "mine"
            ],
            "node": "pending #66",
            "height": 101
          },
          "T": {
            "value": "inMempool",
            "label": "[D]",
            "rules": [
              "receive"
            ],
            "node": "pending #66"
          }
        },
        "utxos": {
          "F1:fund": "spent in pool by T",
          "T:credit": "absent"
        },
        "evidence": [
          "getrawmempool = [T] on both nodes",
          "the Teranode record of T read through #97's observation contract: unminedSince 102, no block ID, no deleteAtHeight"
        ],
        "second_oracle": {
          "label": "[D]",
          "node": "pending #66",
          "store_mempool": [
            "T"
          ],
          "records": {
            "T": {
              "unminedSince": 102,
              "blocks": [],
              "conflicting": false,
              "locked": false,
              "deleteAtHeight": null,
              "preserveUntil": null
            }
          },
          "basis": "BsvChain.Teranode.Lifetimes.createUnmined (unminedSince = tip + 1, services/validator/Validator.go:898-900)"
        }
      }
    },
    {
      "id": "s2",
      "label": "[D]",
      "node": "pending #66",
      "action": {
        "type": "advanceTime",
        "now": 1701209600,
        "maintenance": "accepted-pool expiry at the boundary",
        "condition": "now - cfg.mempoolExpiry = T's entry time (the strict cutoff keeps T)",
        "trigger": {
          "type": "rpc",
          "rpc": "sendrawtransactions",
          "transactions": [
            "sweep0",
            "sweep1"
          ],
          "after": "setmocktime(1701209600) returned on the reference; no pending fixture validation",
          "completion": "both input-empty rejection receipts returned; the reference's expiry log line captured or its absence recorded; fresh pools read",
          "effects": {
            "accepted_pool": "the reference removes T and its descendants exactly when T's entry time < now - mempoolExpiry",
            "teranode": "no setmocktime equivalent is read here; the time move changes no Teranode mark (its age is counted in blocks), the runner records the instance's clock unchanged"
          },
          "sources": [
            "[SRC] src/validation.cpp:853-856",
            "[SRC] src/txmempool.cpp:2201-2220",
            "[SRC] src/config.cpp:87"
          ]
        }
      },
      "kind": "policy expiry boundary; no block transition",
      "rules": [
        "expiry"
      ],
      "expected_observations": {
        "label": "[D]",
        "node": "pending #66",
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
          "F1": {
            "value": "minedActive",
            "label": "[D]",
            "rules": [
              "mine"
            ],
            "node": "pending #66",
            "height": 101
          },
          "T": {
            "value": "inMempool",
            "label": "[D]",
            "rules": [
              "unchanged"
            ],
            "node": "pending #66"
          }
        },
        "utxos": {
          "F1:fund": "spent in pool by T",
          "T:credit": "absent"
        },
        "evidence": [
          "getrawmempool = [T] on both nodes: the reference's cutoff is strict (src/txmempool.cpp:2207)"
        ],
        "second_oracle": {
          "label": "[D]",
          "node": "pending #66",
          "store_mempool": [
            "T"
          ],
          "records": {
            "T": {
              "unminedSince": 102,
              "blocks": [],
              "conflicting": false,
              "locked": false,
              "deleteAtHeight": null,
              "preserveUntil": null
            }
          },
          "basis": "BsvChain.Teranode.Lifetimes.never_mined_kept"
        }
      }
    },
    {
      "id": "s3",
      "label": "[D]",
      "node": "pending #66",
      "action": {
        "type": "advanceTime",
        "now": 1701209601,
        "maintenance": "accepted-pool expiry past the boundary",
        "condition": "now > T's entry time + cfg.mempoolExpiry",
        "trigger": {
          "type": "rpc",
          "rpc": "sendrawtransactions",
          "transactions": [
            "sweep0",
            "sweep1"
          ],
          "after": "setmocktime(1701209601) returned on the reference; no pending fixture validation",
          "completion": "both input-empty rejection receipts returned; the reference's expiry log line captured or its absence recorded; fresh pools read",
          "effects": {
            "accepted_pool": "the reference removes T and its descendants exactly when T's entry time < now - mempoolExpiry",
            "teranode": "no setmocktime equivalent is read here; the time move changes no Teranode mark (its age is counted in blocks), the runner records the instance's clock unchanged"
          },
          "sources": [
            "[SRC] src/validation.cpp:853-856",
            "[SRC] src/txmempool.cpp:2201-2220",
            "[SRC] src/config.cpp:87"
          ]
        }
      },
      "kind": "policy expiry; no block transition; THE WITNESS (the nodes differ by design)",
      "rules": [
        "expiry"
      ],
      "expected_observations": {
        "label": "[D]",
        "node": "pending #66",
        "mempool": [],
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
          "T": {
            "value": "unknown",
            "label": "[D]",
            "rules": [
              "expiry"
            ],
            "node": "pending #66"
          }
        },
        "utxos": {
          "F1:fund": "unspent",
          "T:credit": "absent"
        },
        "evidence": [
          "reference: getrawmempool = [], T removed with reason EXPIRY",
          "Teranode: getrawmempool = [T]; the record of T unchanged",
          "the disagreement is expected [D]: -mempoolexpiry is policy and Teranode has no counterpart; a runner classifies it non-judging with this file's basis, never diverge"
        ],
        "second_oracle": {
          "label": "[D]",
          "node": "pending #66",
          "store_mempool": [
            "T"
          ],
          "records": {
            "T": {
              "unminedSince": 102,
              "blocks": [],
              "conflicting": false,
              "locked": false,
              "deleteAtHeight": null,
              "preserveUntil": null
            }
          },
          "basis": "BsvChain.Teranode.Lifetimes.expiry_rules_differ (the reference removes T; the store keeps its unmined record at every height)",
          "qualifier": "policy: -mempoolexpiry (src/config.cpp:87), no Teranode counterpart; non-judging, never diverge"
        }
      }
    }
  ],
  "variants": [
    {
      "id": "maturity",
      "fork_after": "initial",
      "steps": [
        {
          "id": "m1",
          "label": "[D]",
          "node": "pending #66",
          "action": {
            "type": "submit",
            "transaction": "S3",
            "now": 1700000000
          },
          "kind": "consensus: coinbase maturity at depth 99",
          "rules": [
            "receive",
            "maturity"
          ],
          "expected_observations": {
            "label": "[D]",
            "node": "pending #66",
            "mempool": [],
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
              "CB3": {
                "value": "minedActive",
                "label": "[D]",
                "rules": [
                  "mine"
                ],
                "node": "pending #66",
                "height": 3
              },
              "S3": {
                "value": "rejected",
                "label": "[D]",
                "rules": [
                  "maturity"
                ],
                "node": "pending #66",
                "namespace": "node",
                "code": 16,
                "reason": "bad-txns-premature-spend-of-coinbase"
              }
            },
            "utxos": {
              "CB3:fund": "unspent",
              "S3:credit": "absent"
            },
            "evidence": [
              "reference: sendrawtransaction refuses S3, reason bad-txns-premature-spend-of-coinbase (src/validation.cpp:2617-2625)",
              "Teranode: the refusal names the coinbase immaturity"
            ],
            "second_oracle": {
              "label": "[D]",
              "node": "pending #66",
              "store_mempool": [],
              "records": {
                "CB3": {
                  "isCoinbase": true,
                  "blocks": [
                    "base@3"
                  ],
                  "spendingHeight": 103
                }
              },
              "basis": "BsvChain.Teranode.Lifetimes.coinbase_maturity_agrees: spend height 102 < spendingHeight 103",
              "refusal": "TX_COINBASE_IMMATURE (38) inside the -25 RPC refusal (errors/Error_types.go:59; stores/utxo/aerospike/spend.go:1057)"
            }
          }
        },
        {
          "id": "m2",
          "label": "[D]",
          "node": "pending #66",
          "action": {
            "type": "submit",
            "transaction": "S2",
            "now": 1700000000
          },
          "kind": "consensus: coinbase maturity at depth 100",
          "rules": [
            "receive",
            "maturity"
          ],
          "expected_observations": {
            "label": "[D]",
            "node": "pending #66",
            "mempool": [
              "S2"
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
              "CB2": {
                "value": "minedActive",
                "label": "[D]",
                "rules": [
                  "mine"
                ],
                "node": "pending #66",
                "height": 2
              },
              "S2": {
                "value": "inMempool",
                "label": "[D]",
                "rules": [
                  "receive"
                ],
                "node": "pending #66"
              }
            },
            "utxos": {
              "CB2:fund": "spent in pool by S2",
              "S2:credit": "absent"
            },
            "evidence": [
              "getrawmempool = [S2] on both nodes"
            ],
            "second_oracle": {
              "label": "[D]",
              "node": "pending #66",
              "store_mempool": [
                "S2"
              ],
              "records": {
                "CB2": {
                  "isCoinbase": true,
                  "blocks": [
                    "base@2"
                  ],
                  "spendingHeight": 102
                }
              },
              "basis": "BsvChain.Teranode.Lifetimes.coinbase_maturity_agrees: spend height 102 = spendingHeight 102"
            }
          }
        },
        {
          "id": "m3",
          "label": "[D]",
          "node": "pending #66",
          "action": {
            "type": "mine",
            "blocks": 1,
            "now": 1700000600
          },
          "kind": "block transition",
          "rules": [
            "mine"
          ],
          "expected_observations": {
            "label": "[D]",
            "node": "pending #66",
            "mempool": [],
            "non_final_pool": [],
            "tip": {
              "block": "b102",
              "height": 102
            },
            "chain_tips": [
              {
                "block": "b102",
                "status": "active"
              }
            ],
            "transactions": {
              "CB2": {
                "value": "minedActive",
                "label": "[D]",
                "rules": [
                  "mine"
                ],
                "node": "pending #66",
                "height": 2
              },
              "S2": {
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
              "CB2:fund": "spent",
              "S2:credit": "unspent"
            },
            "evidence": [
              "getbestblockhash = b102 on both nodes; the body is observed and written into the step (the #72 contract)"
            ],
            "second_oracle": {
              "label": "[D]",
              "node": "pending #66",
              "store_mempool": [],
              "records": {
                "S2": {
                  "unminedSince": null,
                  "blocks": [
                    "b102"
                  ],
                  "locked": false
                }
              },
              "basis": "BsvChain.Teranode.Lifetimes.setMined"
            }
          }
        },
        {
          "id": "m4",
          "label": "[D]",
          "node": "pending #66",
          "action": {
            "type": "submit",
            "transaction": "S3",
            "now": 1700000600
          },
          "kind": "consensus: coinbase maturity at depth 100 after one block",
          "rules": [
            "receive",
            "maturity"
          ],
          "expected_observations": {
            "label": "[D]",
            "node": "pending #66",
            "mempool": [
              "S3"
            ],
            "non_final_pool": [],
            "tip": {
              "block": "b102",
              "height": 102
            },
            "chain_tips": [
              {
                "block": "b102",
                "status": "active"
              }
            ],
            "transactions": {
              "CB3": {
                "value": "minedActive",
                "label": "[D]",
                "rules": [
                  "mine"
                ],
                "node": "pending #66",
                "height": 3
              },
              "S3": {
                "value": "inMempool",
                "label": "[D]",
                "rules": [
                  "receive"
                ],
                "node": "pending #66"
              }
            },
            "utxos": {
              "CB3:fund": "spent in pool by S3",
              "S3:credit": "absent"
            },
            "evidence": [
              "getrawmempool = [S3] on both nodes"
            ],
            "second_oracle": {
              "label": "[D]",
              "node": "pending #66",
              "store_mempool": [
                "S3"
              ],
              "records": {
                "CB3": {
                  "isCoinbase": true,
                  "blocks": [
                    "base@3"
                  ],
                  "spendingHeight": 103
                }
              },
              "basis": "BsvChain.Teranode.Lifetimes.coinbase_maturity_agrees: spend height 103 = spendingHeight 103"
            }
          }
        }
      ]
    },
    {
      "id": "locked",
      "fork_after": "initial",
      "steps": [
        {
          "id": "l1",
          "label": "[D]",
          "node": "pending #66",
          "action": {
            "type": "submitConcurrent",
            "transactions": [
              "P",
              "C"
            ],
            "now": 1700000000,
            "realization": "C spends P:credit; both sent without awaiting the other's reply; repeated on fresh pairs until C reaches Teranode's validator inside P's locked window (between SpendAndCreate WithLocked(true), services/validator/Validator.go:2147-2152, and twoPhaseCommitTransaction, :1621) or the budget ends, the count recorded; on the reference C takes the orphan path while P is in validation, or none",
            "pairs": "P spends F1:fund; C spends P:credit"
          },
          "kind": "the store's two-phase commit mark; no reference counterpart",
          "rules": [
            "receive"
          ],
          "expected_observations": {
            "label": "[D]",
            "node": "pending #66",
            "mempool": [
              "P",
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
              "P": {
                "value": "inMempool",
                "label": "[D]",
                "rules": [
                  "receive"
                ],
                "node": "pending #66"
              },
              "C": {
                "value": "inMempool",
                "label": "[D]",
                "rules": [
                  "receive"
                ],
                "node": "pending #66"
              }
            },
            "utxos": {
              "F1:fund": "spent in pool by P",
              "P:credit": "spent in pool by C",
              "C:credit": "absent"
            },
            "evidence": [
              "both nodes end with P and C accepted when the retry budget suffices; Teranode's TX_LOCKED retries are recorded, not judged",
              "a Teranode refusal of C after the budget (validator_txlocked_maxRetries) is recorded as non-judging: no reference transition corresponds"
            ],
            "second_oracle": {
              "label": "[D]",
              "node": "pending #66",
              "store_mempool": [
                "P",
                "C"
              ],
              "records": {
                "P": {
                  "unminedSince": 102,
                  "locked": false
                },
                "C": {
                  "unminedSince": 102,
                  "locked": false
                }
              },
              "basis": "BsvChain.Teranode.Lifetimes.locked_refuses (a spend of a locked record is refused TX_LOCKED and retried, services/validator/Validator.go:663-690); setLocked false at the commit"
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
