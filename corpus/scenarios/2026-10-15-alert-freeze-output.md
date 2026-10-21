# Freezing an output on both nodes: the reference's RPC and Teranode's alert (#94)

[D] 2026-10-15, lane s8-94 (#94; `lean/BsvChain/Teranode/Alert.lean`, `docs/PARAMETERS.md` §8.10). One output
frozen, a spend of it refused, the freeze ended, the spend admitted, on a fresh regtest instance of the node of
record and on a fresh Teranode instance; a variant ends the freeze without ending its policy half, where the two
nodes part. The lists are operator data and the authority over them a node setting (policy, rule 1); nothing
here is a rule of validity. [SRC] bitcoin-sv v1.2.3 `6504a3aff65ba97c0f6c80962b033e35ecbfed4b`: the RPC
`addToConsensusBlacklist` `src/rpc/frozentxo_rpc.cpp:346-378`, the check `src/frozentxo.cpp:37-83`, the refusal
`src/validation.cpp:2594-2607`, the RPC's rejection form `src/rpc/rawtransaction.cpp:1640-1645`. Teranode v0.16.0
`4edb60a40c6628ff0ef60231c2628efd7103fde5`: `services/alert/node.go:274-353` (`AddToConsensusBlacklist`),
`stores/utxo/aerospike/teranode.lua:713` (`freeze`), `:795` (`unfreeze`), `:406-411` (the spend's `FROZEN`), the
refusal word UTXO_FROZEN 72 (docs/CONFORMANCE-TERANODE-MACHINE.md, the rejection table's row).

[D] The expectations are the spec's, never a run: each step's `theorem` names the statement of
`lean/BsvChain/Teranode/Alert.lean` the step witnesses, and `second_oracle` is the Teranode column read from
source through that module. The reference's steps are RPC calls in the format of the #85 edge scenarios (README,
2026-10-15); the Teranode column needs what #66's cut 2 owes: an instance whose alert service takes test genesis
keys (`alert_genesis_keys`, the regtest topic `bitcoin_alert_system_regtest`, `services/alert/server.go:332-337`)
and a signed freeze alert, or a call to the node interface `AddToConsensusBlacklist` behind it, and a `fork_after`
variant (the #90 format). Every node marker is `pending #66` (cut 2). Synthetic names only: `<addr>` is a fresh
regtest key's address, `C` the coinbase of block 1 (mature at height 101), `S` a transaction spending `C:0` to
`<addr>` under that key, built by the runner.

```json
{
  "id": "2026-10-15-alert-freeze-output",
  "class": "Freezing an output on both nodes: the reference's RPC and Teranode's alert (#94)",
  "witness": "#94: lean/BsvChain/Teranode/Alert.lean (freeze_agrees, unfreeze_agrees, unfreeze_keeps_policy_freeze)",
  "input_label": "[D]",
  "source_pin": "6504a3aff65ba97c0f6c80962b033e35ecbfed4b",
  "second_oracle_pin": "4edb60a40c6628ff0ef60231c2628efd7103fde5",
  "initial_chain": {
    "profile": "alert-94",
    "input_label": "[D]",
    "base_config": "harness/oracle/scenarios.conf",
    "launch": [],
    "setup": [
      {
        "method": "generatetoaddress",
        "params": [
          101,
          "<addr>"
        ]
      }
    ],
    "active_tip": {
      "block": "b101",
      "height": 101
    },
    "key": "a fresh regtest key; its address is <addr>",
    "fixtures": {
      "C": "the coinbase transaction of block 1, paying <addr>",
      "S": "a transaction spending C:0 to <addr>, signed under the key, built by the runner"
    },
    "second_oracle": {
      "label": "[D]",
      "launch": [
        "alert_genesis_keys = <the runner's test keys>",
        "startAlert = true"
      ],
      "note": "the topic off mainnet is bitcoin_alert_system_<network> (services/alert/server.go:332-337)"
    }
  },
  "steps": [
    {
      "id": "s1",
      "action": {
        "type": "rpc",
        "method": "addToConsensusBlacklist",
        "params": [
          {
            "funds": [
              {
                "txOut": {
                  "txId": "<C>",
                  "vout": 0
                },
                "enforceAtHeight": [
                  {
                    "start": 0,
                    "stop": 2147483647
                  }
                ],
                "policyExpiresWithConsensus": false
              }
            ]
          }
        ]
      },
      "kind": "operator",
      "rules": [
        "src/rpc/frozentxo_rpc.cpp:346-378",
        "src/rpc/frozentxo_rpc.cpp:188-206"
      ],
      "expected_observations": {
        "reply": {
          "result": {
            "notProcessed": []
          }
        }
      },
      "theorem": "BsvChain.Teranode.Alert.freeze_agrees",
      "second_oracle": {
        "label": "[D]",
        "action": "a freeze alert with one fund (C:0, start 0, end 2147483647, expiry 0), go-alert-system v0.1.17 app/models/alert_message_freeze_utxo.go:46-97, reaching services/alert/node.go:274",
        "store": {
          "C:0": "frozen"
        },
        "node": "pending #66"
      },
      "label": "[D]",
      "node": "pending #66"
    },
    {
      "id": "s2",
      "action": {
        "type": "rpc",
        "method": "sendrawtransaction",
        "params": [
          "<S>"
        ]
      },
      "kind": "observe",
      "rules": [
        "src/validation.cpp:2594-2607",
        "src/frozentxo.cpp:37-83",
        "src/rpc/rawtransaction.cpp:1640-1645"
      ],
      "expected_observations": {
        "reply": {
          "error": {
            "code": -26,
            "message": "16: bad-txns-inputs-frozen"
          }
        },
        "mempool": []
      },
      "theorem": "BsvChain.Teranode.Alert.freeze_agrees",
      "second_oracle": {
        "label": "[D]",
        "refused": "UTXO_FROZEN (72)",
        "store": {
          "C:0": "frozen"
        },
        "node": "pending #66"
      },
      "label": "[D]",
      "node": "pending #66"
    },
    {
      "id": "s3",
      "action": {
        "type": "rpc",
        "method": "addToConsensusBlacklist",
        "params": [
          {
            "funds": [
              {
                "txOut": {
                  "txId": "<C>",
                  "vout": 0
                },
                "enforceAtHeight": [
                  {
                    "start": 0,
                    "stop": 1
                  }
                ],
                "policyExpiresWithConsensus": true
              }
            ]
          }
        ]
      },
      "kind": "operator",
      "rules": [
        "src/rpc/frozentxo_rpc.cpp:145-163",
        "src/frozentxo_db.h:323-377"
      ],
      "expected_observations": {
        "reply": {
          "result": {
            "notProcessed": []
          }
        }
      },
      "theorem": "BsvChain.Teranode.Alert.unfreeze_agrees",
      "second_oracle": {
        "label": "[D]",
        "action": "an unfreeze alert with one fund (C:0, start 0, end 1, expiry 1), go-alert-system v0.1.17 app/models/alert_message_unfreeze_utxo.go:36-69; end 1 is behind the store's height 101, so services/alert/node.go:339-343 unfreezes",
        "store": {
          "C:0": "unspent"
        },
        "node": "pending #66"
      },
      "label": "[D]",
      "node": "pending #66"
    },
    {
      "id": "s4",
      "action": {
        "type": "rpc",
        "method": "sendrawtransaction",
        "params": [
          "<S>"
        ]
      },
      "kind": "observe",
      "rules": [
        "src/frozentxo.cpp:37-83",
        "src/frozentxo_db.h:323-377"
      ],
      "expected_observations": {
        "reply": {
          "result": "<txid of S>"
        },
        "mempool": [
          "S"
        ]
      },
      "theorem": "BsvChain.Teranode.Alert.unfreeze_agrees",
      "second_oracle": {
        "label": "[D]",
        "accepted": true,
        "store": {
          "C:0": "spent by S"
        },
        "node": "pending #66"
      },
      "label": "[D]",
      "node": "pending #66"
    },
    {
      "id": "v1",
      "fork_after": "s2",
      "action": {
        "type": "rpc",
        "method": "addToConsensusBlacklist",
        "params": [
          {
            "funds": [
              {
                "txOut": {
                  "txId": "<C>",
                  "vout": 0
                },
                "enforceAtHeight": [
                  {
                    "start": 0,
                    "stop": 1
                  }
                ],
                "policyExpiresWithConsensus": false
              }
            ]
          }
        ]
      },
      "kind": "operator",
      "rules": [
        "src/frozentxo_db.h:323-348"
      ],
      "expected_observations": {
        "reply": {
          "result": {
            "notProcessed": []
          }
        }
      },
      "theorem": "BsvChain.Teranode.Alert.unfreeze_keeps_policy_freeze",
      "second_oracle": {
        "label": "[D]",
        "action": "an unfreeze alert with one fund (C:0, start 0, end 1, expiry 0); services/alert/node.go:339 reads only the end",
        "store": {
          "C:0": "unspent"
        },
        "node": "pending #66"
      },
      "label": "[D]",
      "node": "pending #66"
    },
    {
      "id": "v2",
      "fork_after": "v1",
      "action": {
        "type": "rpc",
        "method": "sendrawtransaction",
        "params": [
          "<S>"
        ]
      },
      "kind": "observe",
      "rules": [
        "src/validation.cpp:2594-2607",
        "src/frozentxo_db.h:323-348"
      ],
      "expected_observations": {
        "reply": {
          "error": {
            "code": -26,
            "message": "16: bad-txns-inputs-frozen"
          }
        },
        "mempool": []
      },
      "theorem": "BsvChain.Teranode.Alert.unfreeze_keeps_policy_freeze",
      "second_oracle": {
        "label": "[D]",
        "accepted": true,
        "store": {
          "C:0": "spent by S"
        },
        "node": "pending #66"
      },
      "label": "[D]",
      "node": "pending #66",
      "note": "the two columns part here: a divergence the run files as a witness, never a sentence (rule 4)"
    }
  ]
}
```
