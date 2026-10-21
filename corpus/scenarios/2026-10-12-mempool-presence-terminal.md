# Mempool presence becomes a terminal door word

[M] Scenario `2026-10-12-mempool-presence-terminal`; [M] 10 declared steps. Every expected
observation below and in JSON is [D]; every node verdict is `measured agree [X] docs/records/20261013-032121-s6-66b-regtest-s3.md`.
The [format, regtest profile and rule citations](README.md) are normative
for this seed. This page contains synthetic names only.

## Class and witness

[D] A selected node accepts `T`; an independent broadcaster's conflict hints
are delivered beside a courier's mempool-only `Present`. The legacy door
answers `Accepted`, latches `networkSeen` and serves `seen`. A block then
mines `K`, a distinct spend of the exact input. The chain removes `T` while
the door's old word persists. This is the audit's primary mechanism. The
released input-pointer observation is a separate client history from the
follow-up audit: releasing an index pointer does not unspend the chain coin.
The corrected relatch rule leaves mempool-only presence pending under a
terminal hint; a fresh broadcaster witness or checked active proof is a
separate input, and a mined conflict must be reconciled by its bound spender.

## Initial chain and steps

[D] Use `regtest-intake` from the format page. Named bodies, blocks and
outpoints are symbolic fixtures for #66 to materialize, never incident bytes.
The JSON specifies delivery boundaries as well as node actions. Variants
restart at their named checkpoint, including that checkpoint's client history.

[D] Primary p1–p4 follows the mined-conflict mechanism. e1–e2 substitutes
expiry. r1–r4 mines `T`, invalidates its block, expires the re-admitted entry,
then reconsiders the block. Invalidation supplies a deterministic regtest
reorganization without an unresolved equal-work tie. In r2 pool membership
wins over the off-active body; in r3 expiry exposes `onStaleBranch`.

[D] e1 and r3 execute the format's explicit `action.trigger` RPC batch
after changing mock time: `LimitMempoolSize` completes expiry and applies
the mining-journal removal before pool reads. Its implementation is owed to
#66. The event adds no transaction or rejection, so the expected pool sets
and status rows are unchanged ([SRC] `src/validation.cpp:847–879`,
`src/txmempool.cpp:2201–2221`; DESIGN-S6 §2.1 row 14 and §2.5).

[D] The client-history columns are local stub inputs, not claims about a current
production deployment. p4/e2 name the repaired histories explicitly.

## Expected observations per machine

[D] `F` remains `minedActive 101` throughout. The table abbreviates the exact
pool, tip, transaction and client observations in JSON; the rule ids expand to
DESIGN-S6 sections/rows and pinned source lines in README. The client column
is the divergent history under test; a later repair is explicitly named.

| step | T status [D] | other status [D] | client observations [D] | source rules | node |
|---|---|---|---|---|---|
| p1 | inMempool | K=unknown | not delivered; pending; networkSeen=false; pending | receive | measured agree [X] docs/records/20261013-032121-s6-66b-regtest-s3.md |
| p2 | inMempool | K=unknown | Present; confirmed:false; Accepted; networkSeen=true; seen | unchanged, receive | measured agree [X] docs/records/20261013-032121-s6-66b-regtest-s3.md |
| p3 | conflictedByMinedSpend | K=minedActive 102 | Present; confirmed:false; Accepted; networkSeen=true; seen; spent=false, pointer=None | mine, conflict | measured agree [X] docs/records/20261013-032121-s6-66b-regtest-s3.md |
| p4 | conflictedByMinedSpend | K=minedActive 102 | Absent; refused; networkSeen=false; refused; spent=true, pointer=K | unchanged, conflict | measured agree [X] docs/records/20261013-032121-s6-66b-regtest-s3.md |
| e1 | unknown | K=unknown | Present; confirmed:false; Accepted; networkSeen=true; seen | expiry | measured agree [X] docs/records/20261013-032121-s6-66b-regtest-s3.md |
| e2 | unknown | K=unknown | Absent; pending; networkSeen=false; pending | unchanged, expiry | measured agree [X] docs/records/20261013-032121-s6-66b-regtest-s3.md |
| r1 | minedActive 102 | K=unknown | MINED; claimed height 102; Accepted; networkSeen=true; seen | mine | measured agree [X] docs/records/20261013-032121-s6-66b-regtest-s3.md |
| r2 | inMempool | K=unknown | MINED; cached claimed height 102; Accepted; networkSeen=true; seen | invalidate | measured agree [X] docs/records/20261013-032121-s6-66b-regtest-s3.md |
| r3 | onStaleBranch | K=unknown | MINED; cached claimed height 102; Accepted; networkSeen=true; seen | expiry | measured agree [X] docs/records/20261013-032121-s6-66b-regtest-s3.md |
| r4 | minedActive 102 | K=unknown | MINED; refreshed claimed height 102; Accepted; networkSeen=true; seen | reconsider | measured agree [X] docs/records/20261013-032121-s6-66b-regtest-s3.md |

## Trace as data

[M] #64 spec projection: `chaincheck` executes the mapped chain/pool steps on explicit derived P2SH fixtures and an assumed prefix; the added `spec` fields record agreement for accepted/held sets, tip, chain tips and chain UTXOs. Client, transaction-status and path assertions remain [D] and owed; node columns remain measured agree [X] docs/records/20261013-032121-s6-66b-regtest-s3.md.

```json
{
  "id": "2026-10-12-mempool-presence-terminal",
  "class": "mempool presence read as terminal at the overlay door",
  "witness": "mechanism-only local audit intake; provenance in the intake record",
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
      "K"
    ],
    "transactions": {
      "F": {
        "value": "minedActive",
        "label": "[D]",
        "rules": [
          "mine"
        ],
        "node": "measured agree [X] docs/records/20261013-032121-s6-66b-regtest-s3.md",
        "height": 101
      },
      "T": {
        "value": "unknown",
        "label": "[D]",
        "rules": [
          "unchanged"
        ],
        "node": "measured agree [X] docs/records/20261013-032121-s6-66b-regtest-s3.md"
      },
      "K": {
        "value": "unknown",
        "label": "[D]",
        "rules": [
          "unchanged"
        ],
        "node": "measured agree [X] docs/records/20261013-032121-s6-66b-regtest-s3.md"
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
      "kind": "policy admission; consensus input/finality prerequisites",
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
          "K": {
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
          "K:credit": "absent"
        },
        "evidence": [
          "getrawmempool = [T]; getrawnonfinalmempool = []",
          "getbestblockhash = base; getblock base contains F",
          "getrawtransaction T matches F:fund; synchronous accepted receipt"
        ],
        "client_views": {
          "courier": "not delivered",
          "door": "pending",
          "networkSeen": false,
          "felt": "pending",
          "broadcaster": [],
          "hop_index": {
            "spent": true,
            "spending_transaction": "T",
            "spentConfirmed": false
          }
        }
      },
      "spec": {
        "agree": true,
        "label": "[M]",
        "observed": {
          "chain_tips": [
            {
              "block": "base",
              "status": "active"
            }
          ],
          "mempool": [
            "T"
          ],
          "non_final_pool": [],
          "tip": {
            "block": "base",
            "height": 101
          },
          "utxos": {
            "F:fund": "unspent",
            "K:credit": "absent",
            "T:credit": "absent"
          }
        },
        "scope": "symbolic chain/pool projection; standard P2SH fixture; assumed prefix; client/path/status projections owed",
        "runner": "chaincheck",
        "run_utc": "2026-10-12T19:22:17Z"
      }
    },
    {
      "id": "p2",
      "label": "[D]",
      "node": "measured agree [X] docs/records/20261014-032012-s6-72-regtest-s3.md",
      "action": {
        "type": "observeClient",
        "input": "deliver a mempool-only Present and conflict-shaped broadcaster hints; legacy door latches"
      },
      "kind": "client evidence only; no node transition",
      "rules": [
        "unchanged",
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
          "K": {
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
          "K:credit": "absent"
        },
        "evidence": [
          "repeat pool/tip observations from p1",
          "courier input explicitly has no mined height or checked path; hints are local stubs"
        ],
        "client_views": {
          "courier": "Present; confirmed:false",
          "door": "Accepted",
          "networkSeen": true,
          "felt": "seen",
          "broadcaster": [
            "REJECTED",
            "DOUBLE_SPEND_ATTEMPTED"
          ],
          "hop_index": {
            "spent": true,
            "spending_transaction": "T",
            "spentConfirmed": false
          }
        }
      },
      "spec": {
        "agree": true,
        "label": "[M]",
        "observed": {
          "chain_tips": [
            {
              "block": "base",
              "status": "active"
            }
          ],
          "mempool": [
            "T"
          ],
          "non_final_pool": [],
          "tip": {
            "block": "base",
            "height": 101
          },
          "utxos": {
            "F:fund": "unspent",
            "K:credit": "absent",
            "T:credit": "absent"
          }
        },
        "scope": "symbolic chain/pool projection; standard P2SH fixture; assumed prefix; client/path/status projections owed",
        "runner": "chaincheck",
        "run_utc": "2026-10-12T19:22:17Z"
      }
    },
    {
      "id": "p3",
      "label": "[D]",
      "node": "measured agree [X] docs/records/20261014-032012-s6-72-regtest-s3.md",
      "action": {
        "type": "mine",
        "branch": "active",
        "parent": "base",
        "block": "conflict",
        "transactions": [
          "K"
        ],
        "method": "submitblock",
        "now": 1700000001,
        "client_input": "retain the legacy door latch; independently expose the released-pointer client history"
      },
      "kind": "consensus block validity and active spending; policy conflict removal",
      "rules": [
        "mine",
        "conflict"
      ],
      "expected_observations": {
        "label": "[D]",
        "node": "measured agree [X] docs/records/20261014-032012-s6-72-regtest-s3.md",
        "mempool": [],
        "non_final_pool": [],
        "tip": {
          "block": "conflict",
          "height": 102
        },
        "chain_tips": [
          {
            "block": "conflict",
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
            "value": "conflictedByMinedSpend",
            "label": "[D]",
            "rules": [
              "conflict"
            ],
            "node": "measured agree [X] docs/records/20261014-032012-s6-72-regtest-s3.md"
          },
          "K": {
            "value": "minedActive",
            "label": "[D]",
            "rules": [
              "mine"
            ],
            "node": "measured agree [X] docs/records/20261014-032012-s6-72-regtest-s3.md",
            "height": 102
          }
        },
        "utxos": {
          "F:fund": "spent",
          "T:credit": "absent",
          "K:credit": "unspent"
        },
        "evidence": [
          "getrawmempool = []; getrawnonfinalmempool = []",
          "getbestblockhash = conflict; getblock conflict contains K and has positive confirmations",
          "getrawtransaction K spends the exact F:fund named by journaled T; gettxout F:fund = null",
          "no active or off-active block body contains T; no earlier status clause matches"
        ],
        "client_views": {
          "courier": "Present; confirmed:false",
          "door": "Accepted",
          "networkSeen": true,
          "felt": "seen",
          "broadcaster": [
            "REJECTED",
            "DOUBLE_SPEND_ATTEMPTED"
          ],
          "hop_index": {
            "spent": false,
            "spending_transaction": null,
            "spentConfirmed": false
          }
        }
      },
      "spec": {
        "agree": true,
        "label": "[M]",
        "observed": {
          "chain_tips": [
            {
              "block": "conflict",
              "status": "active"
            }
          ],
          "mempool": [],
          "non_final_pool": [],
          "tip": {
            "block": "conflict",
            "height": 102
          },
          "utxos": {
            "F:fund": "spent",
            "K:credit": "unspent",
            "T:credit": "absent"
          }
        },
        "scope": "symbolic chain/pool projection; standard P2SH fixture; assumed prefix; client/path/status projections owed",
        "runner": "chaincheck",
        "run_utc": "2026-10-12T19:22:17Z"
      }
    },
    {
      "id": "p4",
      "label": "[D]",
      "node": "measured agree [X] docs/records/20261014-032012-s6-72-regtest-s3.md",
      "action": {
        "type": "observeClient",
        "input": "reconcile the active input-bound competitor; refresh the presence read and repair the released pointer"
      },
      "kind": "client repair; chain state unchanged",
      "rules": [
        "unchanged",
        "conflict"
      ],
      "expected_observations": {
        "label": "[D]",
        "node": "measured agree [X] docs/records/20261014-032012-s6-72-regtest-s3.md",
        "mempool": [],
        "non_final_pool": [],
        "tip": {
          "block": "conflict",
          "height": 102
        },
        "chain_tips": [
          {
            "block": "conflict",
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
            "value": "conflictedByMinedSpend",
            "label": "[D]",
            "rules": [
              "conflict"
            ],
            "node": "measured agree [X] docs/records/20261014-032012-s6-72-regtest-s3.md"
          },
          "K": {
            "value": "minedActive",
            "label": "[D]",
            "rules": [
              "mine"
            ],
            "node": "measured agree [X] docs/records/20261014-032012-s6-72-regtest-s3.md",
            "height": 102
          }
        },
        "utxos": {
          "F:fund": "spent",
          "T:credit": "absent",
          "K:credit": "unspent"
        },
        "evidence": [
          "repeat the active K body and exact-input witness of p3",
          "client repair consumes checked active competitor evidence; no refund or release of the chain coin"
        ],
        "client_views": {
          "courier": "Absent",
          "door": "refused",
          "networkSeen": false,
          "felt": "refused",
          "broadcaster": [
            "REJECTED",
            "DOUBLE_SPEND_ATTEMPTED"
          ],
          "hop_index": {
            "spent": true,
            "spending_transaction": "K",
            "spentConfirmed": true
          }
        }
      },
      "spec": {
        "agree": true,
        "label": "[M]",
        "observed": {
          "chain_tips": [
            {
              "block": "conflict",
              "status": "active"
            }
          ],
          "mempool": [],
          "non_final_pool": [],
          "tip": {
            "block": "conflict",
            "height": 102
          },
          "utxos": {
            "F:fund": "spent",
            "K:credit": "unspent",
            "T:credit": "absent"
          }
        },
        "scope": "symbolic chain/pool projection; standard P2SH fixture; assumed prefix; client/path/status projections owed",
        "runner": "chaincheck",
        "run_utc": "2026-10-12T19:22:17Z"
      }
    }
  ],
  "variants": [
    {
      "id": "expiry",
      "fork_after": "p2",
      "steps": [
        {
          "id": "e1",
          "label": "[D]",
          "node": "measured agree [X] docs/records/20261014-032012-s6-72-regtest-s3.md",
          "action": {
            "type": "advanceTime",
            "now": 1701209601,
            "maintenance": "accepted-pool expiry completed",
            "condition": "now > p1 entry time + cfg.mempoolExpiry",
            "trigger": {
              "type": "rpc",
              "rpc": "sendrawtransactions",
              "transactions": [
                "sweep0",
                "sweep1"
              ],
              "after": "setmocktime(now) returned; no pending fixture validation",
              "completion": "both input-empty rejection receipts returned; new Expired 1 transactions from the memory pool log line captured; fresh pools read",
              "effects": {
                "accepted_pool": "remove T and descendants; no auxiliary admission",
                "mining_journal": "remove expired T before RPC completion",
                "chain_and_node_journals": "unchanged fixture chain and journals; two auxiliary rejection receipts recorded separately",
                "size_eviction": "none; profile has no memory pressure"
              },
              "sources": [
                "[SRC] src/rawtxvalidator.cpp:54-92,126-138",
                "[SRC] src/txn_validator.cpp:216-228,303-314",
                "[SRC] src/rpc/rawtransaction.cpp:2134-2155",
                "[SRC] src/validation.cpp:853-856"
              ]
            }
          },
          "kind": "policy expiry; no block transition",
          "rules": [
            "expiry"
          ],
          "expected_observations": {
            "label": "[D]",
            "node": "measured agree [X] docs/records/20261014-032012-s6-72-regtest-s3.md",
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
                "value": "unknown",
                "label": "[D]",
                "rules": [
                  "expiry"
                ],
                "node": "measured agree [X] docs/records/20261014-032012-s6-72-regtest-s3.md"
              },
              "K": {
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
              "K:credit": "absent"
            },
            "evidence": [
              "setmocktime returned; action.trigger returned with T EXPIRY removal and mining-journal change applied; getrawmempool = []; getrawnonfinalmempool = []",
              "getbestblockhash = base; gettxout F:fund remains unspent",
              "complete isolated journal: no T block, active spender, orphan/non-final entry or node rejection"
            ],
            "client_views": {
              "courier": "Present; confirmed:false",
              "door": "Accepted",
              "networkSeen": true,
              "felt": "seen",
              "broadcaster": [
                "REJECTED",
                "DOUBLE_SPEND_ATTEMPTED"
              ],
              "hop_index": {
                "spent": true,
                "spending_transaction": "T",
                "spentConfirmed": false
              }
            }
          },
          "spec": {
            "agree": true,
            "label": "[M]",
            "observed": {
              "chain_tips": [
                {
                  "block": "base",
                  "status": "active"
                }
              ],
              "mempool": [],
              "non_final_pool": [],
              "tip": {
                "block": "base",
                "height": 101
              },
              "utxos": {
                "F:fund": "unspent",
                "K:credit": "absent",
                "T:credit": "absent"
              }
            },
            "scope": "symbolic chain/pool projection; standard P2SH fixture; assumed prefix; client/path/status projections owed",
            "runner": "chaincheck",
            "run_utc": "2026-10-12T19:22:17Z"
          }
        },
        {
          "id": "e2",
          "label": "[D]",
          "node": "measured agree [X] docs/records/20261014-032012-s6-72-regtest-s3.md",
          "action": {
            "type": "observeClient",
            "input": "refresh the expired presence; clear the terminal latch"
          },
          "kind": "client refresh; policy-expired state unchanged",
          "rules": [
            "unchanged",
            "expiry"
          ],
          "expected_observations": {
            "label": "[D]",
            "node": "measured agree [X] docs/records/20261014-032012-s6-72-regtest-s3.md",
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
                "value": "unknown",
                "label": "[D]",
                "rules": [
                  "expiry"
                ],
                "node": "measured agree [X] docs/records/20261014-032012-s6-72-regtest-s3.md"
              },
              "K": {
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
              "K:credit": "absent"
            },
            "evidence": [
              "repeat e1 complete observations; no node submission or rejection"
            ],
            "client_views": {
              "courier": "Absent",
              "door": "pending",
              "networkSeen": false,
              "felt": "pending",
              "broadcaster": [
                "REJECTED",
                "DOUBLE_SPEND_ATTEMPTED"
              ],
              "hop_index": {
                "spent": true,
                "spending_transaction": "T",
                "spentConfirmed": false
              }
            }
          },
          "spec": {
            "agree": true,
            "label": "[M]",
            "observed": {
              "chain_tips": [
                {
                  "block": "base",
                  "status": "active"
                }
              ],
              "mempool": [],
              "non_final_pool": [],
              "tip": {
                "block": "base",
                "height": 101
              },
              "utxos": {
                "F:fund": "unspent",
                "K:credit": "absent",
                "T:credit": "absent"
              }
            },
            "scope": "symbolic chain/pool projection; standard P2SH fixture; assumed prefix; client/path/status projections owed",
            "runner": "chaincheck",
            "run_utc": "2026-10-12T19:22:17Z"
          }
        }
      ]
    },
    {
      "id": "invalidate-expire-reconsider",
      "fork_after": "p2",
      "steps": [
        {
          "id": "r1",
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
            "now": 1700000001,
            "client_input": "deliver courier MINED with claimed height only"
          },
          "kind": "consensus block inclusion and finality; policy pool removal",
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
              "K": {
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
              "K:credit": "absent"
            },
            "evidence": [
              "getblock A contains T at height 102 with positive confirmations; getbestblockhash = A",
              "getrawmempool = []; gettxout T:credit is unspent"
            ],
            "client_views": {
              "courier": "MINED; claimed height 102",
              "door": "Accepted",
              "networkSeen": true,
              "felt": "seen",
              "broadcaster": [
                "REJECTED",
                "DOUBLE_SPEND_ATTEMPTED"
              ],
              "hop_index": {
                "spent": true,
                "spending_transaction": "T",
                "spentConfirmed": false
              }
            }
          },
          "spec": {
            "agree": true,
            "label": "[M]",
            "observed": {
              "chain_tips": [
                {
                  "block": "A",
                  "status": "active"
                }
              ],
              "mempool": [],
              "non_final_pool": [],
              "tip": {
                "block": "A",
                "height": 102
              },
              "utxos": {
                "F:fund": "spent",
                "K:credit": "absent",
                "T:credit": "unspent"
              }
            },
            "scope": "symbolic chain/pool projection; standard P2SH fixture; assumed prefix; client/path/status projections owed",
            "runner": "chaincheck",
            "run_utc": "2026-10-12T19:22:17Z"
          }
        },
        {
          "id": "r2",
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
              "K": {
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
              "K:credit": "absent"
            },
            "evidence": [
              "getchaintips marks A invalid; getblock A confirmations = -1; getbestblockhash = base",
              "getrawmempool = [T] proves re-admission, so clause 2 precedes clause 5",
              "gettxout F:fund unspent with include_mempool=false"
            ],
            "client_views": {
              "courier": "MINED; cached claimed height 102",
              "door": "Accepted",
              "networkSeen": true,
              "felt": "seen",
              "broadcaster": [
                "REJECTED",
                "DOUBLE_SPEND_ATTEMPTED"
              ],
              "hop_index": {
                "spent": true,
                "spending_transaction": "T",
                "spentConfirmed": false
              }
            }
          },
          "spec": {
            "agree": true,
            "label": "[M]",
            "observed": {
              "chain_tips": [
                {
                  "block": "A",
                  "status": "invalid"
                },
                {
                  "block": "base",
                  "status": "active"
                }
              ],
              "mempool": [
                "T"
              ],
              "non_final_pool": [],
              "tip": {
                "block": "base",
                "height": 101
              },
              "utxos": {
                "F:fund": "unspent",
                "K:credit": "absent",
                "T:credit": "absent"
              }
            },
            "scope": "symbolic chain/pool projection; standard P2SH fixture; assumed prefix; client/path/status projections owed",
            "runner": "chaincheck",
            "run_utc": "2026-10-12T19:22:17Z"
          }
        },
        {
          "id": "r3",
          "label": "[D]",
          "node": "measured agree [X] docs/records/20261014-032012-s6-72-regtest-s3.md",
          "action": {
            "type": "advanceTime",
            "now": 1701209603,
            "maintenance": "accepted-pool expiry completed",
            "condition": "now > r2 re-admission time + cfg.mempoolExpiry",
            "trigger": {
              "type": "rpc",
              "rpc": "sendrawtransactions",
              "transactions": [
                "sweep0",
                "sweep1"
              ],
              "after": "setmocktime(now) returned; no pending fixture validation",
              "completion": "both input-empty rejection receipts returned; new Expired 1 transactions from the memory pool log line captured; fresh pools read",
              "effects": {
                "accepted_pool": "remove T and descendants; no auxiliary admission",
                "mining_journal": "remove expired T before RPC completion",
                "chain_and_node_journals": "unchanged fixture chain and journals; two auxiliary rejection receipts recorded separately",
                "size_eviction": "none; profile has no memory pressure"
              },
              "sources": [
                "[SRC] src/rawtxvalidator.cpp:54-92,126-138",
                "[SRC] src/txn_validator.cpp:216-228,303-314",
                "[SRC] src/rpc/rawtransaction.cpp:2134-2155",
                "[SRC] src/validation.cpp:853-856"
              ]
            }
          },
          "kind": "policy expiry; off-active body retained",
          "rules": [
            "expiry"
          ],
          "expected_observations": {
            "label": "[D]",
            "node": "measured agree [X] docs/records/20261014-032012-s6-72-regtest-s3.md",
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
                "value": "onStaleBranch",
                "label": "[D]",
                "rules": [
                  "expiry",
                  "invalidate"
                ],
                "node": "measured agree [X] docs/records/20261014-032012-s6-72-regtest-s3.md"
              },
              "K": {
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
              "K:credit": "absent"
            },
            "evidence": [
              "setmocktime returned; action.trigger returned with T EXPIRY removal and mining-journal change applied; getrawmempool = []; getrawnonfinalmempool = []",
              "A remains invalid/off-active with its T body and confirmations = -1; getbestblockhash = base"
            ],
            "client_views": {
              "courier": "MINED; cached claimed height 102",
              "door": "Accepted",
              "networkSeen": true,
              "felt": "seen",
              "broadcaster": [
                "REJECTED",
                "DOUBLE_SPEND_ATTEMPTED"
              ],
              "hop_index": {
                "spent": true,
                "spending_transaction": "T",
                "spentConfirmed": false
              }
            }
          },
          "spec": {
            "agree": true,
            "label": "[M]",
            "observed": {
              "chain_tips": [
                {
                  "block": "A",
                  "status": "invalid"
                },
                {
                  "block": "base",
                  "status": "active"
                }
              ],
              "mempool": [],
              "non_final_pool": [],
              "tip": {
                "block": "base",
                "height": 101
              },
              "utxos": {
                "F:fund": "unspent",
                "K:credit": "absent",
                "T:credit": "absent"
              }
            },
            "scope": "symbolic chain/pool projection; standard P2SH fixture; assumed prefix; client/path/status projections owed",
            "runner": "chaincheck",
            "run_utc": "2026-10-12T19:22:17Z"
          }
        },
        {
          "id": "r4",
          "label": "[D]",
          "node": "measured agree [X] docs/records/20261014-032012-s6-72-regtest-s3.md",
          "action": {
            "type": "reconsiderBlock",
            "block": "A",
            "now": 1701209603,
            "completion": "activation completed"
          },
          "kind": "operator reconsideration; consensus inclusion restored",
          "rules": [
            "reconsider"
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
                  "reconsider"
                ],
                "node": "measured agree [X] docs/records/20261014-032012-s6-72-regtest-s3.md",
                "height": 102
              },
              "K": {
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
              "K:credit": "absent"
            },
            "evidence": [
              "getbestblockhash = A; getblock A contains T with positive confirmations",
              "A is the sole eligible tip above base; getrawmempool = []"
            ],
            "client_views": {
              "courier": "MINED; refreshed claimed height 102",
              "door": "Accepted",
              "networkSeen": true,
              "felt": "seen",
              "broadcaster": [
                "REJECTED",
                "DOUBLE_SPEND_ATTEMPTED"
              ],
              "hop_index": {
                "spent": true,
                "spending_transaction": "T",
                "spentConfirmed": false
              }
            }
          },
          "spec": {
            "agree": true,
            "label": "[M]",
            "observed": {
              "chain_tips": [
                {
                  "block": "A",
                  "status": "active"
                }
              ],
              "mempool": [],
              "non_final_pool": [],
              "tip": {
                "block": "A",
                "height": 102
              },
              "utxos": {
                "F:fund": "spent",
                "K:credit": "absent",
                "T:credit": "unspent"
              }
            },
            "scope": "symbolic chain/pool projection; standard P2SH fixture; assumed prefix; client/path/status projections owed",
            "runner": "chaincheck",
            "run_utc": "2026-10-12T19:22:17Z"
          }
        }
      ]
    }
  ],
  "replay": {
    "node": "measured agree [X] docs/records/20261013-032121-s6-66b-regtest-s3.md",
    "runner": "#66",
    "views": "#67",
    "client_columns": "derived local histories, not client runs"
  }
}
```

## Replay and boundary

[D] #66 owes node/evaluator replay, actual RPC receipts, maintenance-completion
evidence and the divergence report. #67 owes the client view functions or
no-function witnesses; the table is in README. No wallet, broadcaster or
node was run for this filing. Block-path inclusion and finality are consensus;
pool admission, non-final holding, expiry and eviction are policy. Operator
invalidation/reconsideration are settings, not a most-work theorem.
