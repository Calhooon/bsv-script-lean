# The sentinel's refusal pair: a same-block parent and the promiscuous word (#91)

[D] 2026-10-15, lane cut2-66q2 (#66 cut 2), the witness #91 left owed ("the done-bar's witness run
through both nodes (the refusal pair on the instance of #74) is owed to #66's cut 2"). Synthetic
isolated regtest-intake profile from README.md: `F` spends the height-1 coinbase in `base` at 101
(the common prefix, core.rs `seed`); `P` spends `F`, `Q` spends `P`; `N` spends `F` to an output
with an empty locking script; `M` spends `N`'s output with the unlocking script `01 01` (a one-byte
push of 0x01 where `OP_1` is the minimal form), version 1, paying 98,000 satoshis to `OP_TRUE`.
Every signed input is P2PKH with SIGHASH_ALL|FORKID.

**Pair (1), consensus** (`b1`): a block carrying `P` and its child `Q`. The reference connects it,
`Q`'s coin at the block's own height (its block word); Teranode, through the legacy bridge, runs
CheckSubtree's legacy branch, which sets the candidate-height option, so its word is the
reference's (`teranode_word_eq_block_word`). The refusal the model states,
`teranode_unconfirmed_refused_without_option`, belongs to the peer-facing branch, which the instance
of record (p2p off) does not run: the scenario records it as the model's statement.

**Pair (2), policy** (the variants): with `-promiscuousmempoolflags=0` on a chain that does not
require standardness (regtest, src/chainparams.cpp:1527) the reference verifies `M`'s input under
the empty word and admits it (src/verify_script_flags.cpp:11-30; src/init.cpp:2463-2469); with the
default it verifies under the standard word, whose `SCRIPT_VERIFY_MINIMALDATA`
(src/policy/policy.h:182-189) refuses the push: 64 `non-mandatory-script-verify-flag (Data push
larger than necessary)` (src/validation.cpp:2763-2765; src/script/script_error.cpp:75-76). Teranode
has no such setting (`teranode_word_ne_promiscuous`): a node's setting, never block validity
(CLAUDE.md rule 1), so its column is non-judging on this pair.

[SRC] bitcoin-sv v1.2.3 at 6504a3aff65ba97c0f6c80962b033e35ecbfed4b; Teranode v0.16.0 at 4edb60a40c6628ff0ef60231c2628efd7103fde5; GoBDK at its pin
(docs/PROVENANCE.md section 1). The `second_oracle` objects are the Teranode column's
expectations, never the reference's rule; a disagreement between the two columns is a finding
with a witness transaction (rule 4).

```json
{
  "id": "2026-10-15-sentinel-refusal-pair",
  "class": "the unconfirmed-parent sentinel against the reference's word: a same-block parent connected, and the promiscuous mempool word (#91's two pairs)",
  "witness": "#91: BsvChain.Teranode.teranode_word_eq_block_word and teranode_unconfirmed_refused_without_option (pair 1), teranode_word_ne_promiscuous (pair 2), lean/BsvChain/Teranode/Sentinel.lean",
  "input_label": "[D]",
  "source_pin": "6504a3aff65ba97c0f6c80962b033e35ecbfed4b",
  "second_oracle_pin": "4edb60a40c6628ff0ef60231c2628efd7103fde5",
  "initial_chain": {
    "profile": "regtest-intake",
    "input_label": "[D]",
    "params": "BsvChain.ChainParams.regtest",
    "config": "README.md initial-chain profile; F funded by the height-1 coinbase in base; the promiscuous variant adds promiscuousmempoolflags=0",
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
      "P",
      "Q",
      "N",
      "M"
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
      "P": {
        "value": "unknown",
        "label": "[D]",
        "rules": [
          "unchanged"
        ],
        "node": "pending #66"
      },
      "Q": {
        "value": "unknown",
        "label": "[D]",
        "rules": [
          "unchanged"
        ],
        "node": "pending #66"
      },
      "N": {
        "value": "unknown",
        "label": "[D]",
        "rules": [
          "unchanged"
        ],
        "node": "pending #66"
      },
      "M": {
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
      "id": "b1",
      "label": "[D]",
      "node": "pending #66",
      "action": {
        "type": "mine",
        "branch": "X",
        "parent": "base",
        "block": "X",
        "transactions": [
          "P",
          "Q"
        ],
        "method": "submitblock",
        "now": 1700000001
      },
      "kind": "block connection: a parent and its child in one block (consensus)",
      "rules": [
        "mine"
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
          "F": {
            "value": "minedActive",
            "label": "[D]",
            "rules": [
              "mine"
            ],
            "node": "pending #66",
            "height": 101
          },
          "P": {
            "value": "minedActive",
            "label": "[D]",
            "rules": [
              "mine"
            ],
            "node": "pending #66",
            "height": 102
          },
          "Q": {
            "value": "minedActive",
            "label": "[D]",
            "rules": [
              "mine"
            ],
            "node": "pending #66",
            "height": 102
          }
        },
        "second_oracle": {
          "label": "[D]",
          "node": "pending #66",
          "verdict": "accepted",
          "basis": "pair (1) of #91: Q's parent P is in the same block, so the UTXO store holds P with no block height when Q is validated and the adapter stamps the sentinel (services/validator/Validator.go:1752-1767); through the legacy bridge the block's subtrees run CheckSubtree's legacy branch, which sets UnconfirmedParentsAtCandidateHeight unconditionally (services/subtreevalidation/Server.go:864,902-909), so the sentinel becomes the block's height and Q verifies under the reference's block word (BsvChain.Teranode.teranode_word_eq_block_word) [SRC] 4edb60a4; the refusal of the pair, teranode_unconfirmed_refused_without_option, is the peer-facing branch's (:954-963), which the instance of record does not run (p2p off): a model statement, unobserved"
        }
      }
    }
  ],
  "variants": [
    {
      "id": "promiscuous",
      "fork_after": "initial",
      "config": "promiscuousmempoolflags=0",
      "steps": [
        {
          "id": "p1",
          "label": "[D]",
          "node": "pending #66",
          "action": {
            "type": "mine",
            "branch": "Y",
            "parent": "base",
            "block": "Y",
            "transactions": [
              "N"
            ],
            "method": "submitblock",
            "now": 1700000001
          },
          "kind": "block connection: N's output carries an empty locking script (consensus-valid, nonstandard)",
          "rules": [
            "mine"
          ],
          "expected_observations": {
            "label": "[D]",
            "node": "pending #66",
            "mempool": [],
            "non_final_pool": [],
            "tip": {
              "block": "Y",
              "height": 102
            },
            "chain_tips": [
              {
                "block": "Y",
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
                "node": "pending #66",
                "height": 101
              },
              "N": {
                "value": "minedActive",
                "label": "[D]",
                "rules": [
                  "mine"
                ],
                "node": "pending #66",
                "height": 102
              }
            },
            "second_oracle": {
              "label": "[D]",
              "node": "pending #66",
              "verdict": "accepted",
              "basis": "a block's transactions are validated with the policy checks skipped (services/legacy/netsync/handle_block.go:1612) [SRC] 4edb60a4"
            }
          }
        },
        {
          "id": "p2",
          "label": "[D]",
          "node": "pending #66",
          "action": {
            "type": "submit",
            "transaction": "M",
            "now": 1700000002
          },
          "kind": "policy admission: the mempool's script word (-promiscuousmempoolflags=0, the empty word)",
          "rules": [
            "receive"
          ],
          "expected_observations": {
            "label": "[D]",
            "node": "pending #66",
            "mempool": [
              "M"
            ],
            "non_final_pool": [],
            "tip": {
              "block": "Y",
              "height": 102
            },
            "chain_tips": [
              {
                "block": "Y",
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
                "node": "pending #66",
                "height": 101
              },
              "N": {
                "value": "minedActive",
                "label": "[D]",
                "rules": [
                  "mine"
                ],
                "node": "pending #66",
                "height": 102
              },
              "M": {
                "value": "inMempool",
                "label": "[D]",
                "rules": [
                  "receive"
                ],
                "node": "pending #66"
              }
            },
            "second_oracle": {
              "label": "[D]",
              "node": "pending #66",
              "verdict": "rejected",
              "judging": "non-judging: a node's setting, never block validity (rule 1)",
              "basis": "pair (2) of #91, BsvChain.Teranode.teranode_word_ne_promiscuous: GoBDK has no promiscuous word (core/txvalidator.hpp:43-45 at the GoBDK pin) and Teranode passes none, so M's input runs under the standard word, whose MINIMALDATA refuses the one-byte push of 0x01 (the reference's STANDARD_SCRIPT_VERIFY_FLAGS, src/policy/policy.h:182-189, compiled into GoBDK)"
            }
          }
        }
      ]
    },
    {
      "id": "standard",
      "fork_after": "initial",
      "steps": [
        {
          "id": "s1",
          "label": "[D]",
          "node": "pending #66",
          "action": {
            "type": "mine",
            "branch": "Y",
            "parent": "base",
            "block": "Y",
            "transactions": [
              "N"
            ],
            "method": "submitblock",
            "now": 1700000001
          },
          "kind": "block connection: N's output carries an empty locking script (consensus-valid, nonstandard)",
          "rules": [
            "mine"
          ],
          "expected_observations": {
            "label": "[D]",
            "node": "pending #66",
            "mempool": [],
            "non_final_pool": [],
            "tip": {
              "block": "Y",
              "height": 102
            },
            "chain_tips": [
              {
                "block": "Y",
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
                "node": "pending #66",
                "height": 101
              },
              "N": {
                "value": "minedActive",
                "label": "[D]",
                "rules": [
                  "mine"
                ],
                "node": "pending #66",
                "height": 102
              }
            },
            "second_oracle": {
              "label": "[D]",
              "node": "pending #66",
              "verdict": "accepted",
              "basis": "a block's transactions are validated with the policy checks skipped (services/legacy/netsync/handle_block.go:1612) [SRC] 4edb60a4"
            }
          }
        },
        {
          "id": "s2",
          "label": "[D]",
          "node": "pending #66",
          "action": {
            "type": "submit",
            "transaction": "M",
            "now": 1700000002
          },
          "kind": "policy admission: the mempool's script word (the standard word)",
          "rules": [
            "receive"
          ],
          "expected_observations": {
            "label": "[D]",
            "node": "pending #66",
            "mempool": [],
            "non_final_pool": [],
            "tip": {
              "block": "Y",
              "height": 102
            },
            "chain_tips": [
              {
                "block": "Y",
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
                "node": "pending #66",
                "height": 101
              },
              "N": {
                "value": "minedActive",
                "label": "[D]",
                "rules": [
                  "mine"
                ],
                "node": "pending #66",
                "height": 102
              },
              "M": {
                "value": "rejected",
                "label": "[D]",
                "rules": [
                  "receive"
                ],
                "node": "pending #66",
                "namespace": "node",
                "code": 64,
                "reason": "non-mandatory-script-verify-flag (Data push larger than necessary)"
              }
            },
            "second_oracle": {
              "label": "[D]",
              "node": "pending #66",
              "verdict": "rejected",
              "judging": "non-judging: a node's setting, never block validity (rule 1)",
              "basis": "pair (2) of #91, BsvChain.Teranode.teranode_word_ne_promiscuous: GoBDK has no promiscuous word (core/txvalidator.hpp:43-45 at the GoBDK pin) and Teranode passes none, so M's input runs under the standard word, whose MINIMALDATA refuses the one-byte push of 0x01 (the reference's STANDARD_SCRIPT_VERIFY_FLAGS, src/policy/policy.h:182-189, compiled into GoBDK)"
            }
          }
        }
      ]
    }
  ],
  "replay": {
    "node": "pending #66",
    "runner": "#66",
    "second_oracle": "#66 cut 2 with #74's Teranode instance"
  }
}
```
