# Safe mode under -testsafemode: the okSafeMode-false handlers refused, the rest answering (#85)

[D] 2026-10-15, lane rpc-85 (#85, docs/CONFORMANCE-RPC-CONTRACT.md §2.1 and Edge E2). A fresh regtest instance
of the node of record launched with `-testsafemode=1` (a node setting, policy and instrumentation, never a consensus
rule) on the base configuration `harness/oracle/scenarios.conf`, the mock clock at 1700000000, one block mined to a fresh
key. [SRC] at bitcoin-sv v1.2.3 `6504a3aff65ba97c0f6c80962b033e35ecbfed4b`: the gate `src/init.cpp:325-333`, the
warning `src/warnings.cpp:46-47`, the registrations `src/rpc/rawtransaction.cpp:2624-2625` (okSafeMode false) and
`src/rpc/blockchain.cpp:3797` (true), the level `src/safe_mode.cpp:498`. The expectations are the contract's [D]; the
probe of #85 observed them [X] (record `docs/records/20261015-035438-s7-85-rpc-contract-s4b.md`); the runner's column is `pending #66`: it needs a launch-flag profile
and an `rpc` action, owed by the wiring lane.

```json
{
  "id": "2026-10-15-rpc-safe-mode",
  "class": "Safe mode under -testsafemode: the okSafeMode-false handlers refused, the rest answering (#85)",
  "witness": "#85: docs/CONFORMANCE-RPC-CONTRACT.md and corpus/rpc/contract.json",
  "input_label": "[D]",
  "source_pin": "6504a3aff65ba97c0f6c80962b033e35ecbfed4b",
  "initial_chain": {
    "profile": "rpc-85",
    "input_label": "[D]",
    "base_config": "harness/oracle/scenarios.conf",
    "launch": [
      "testsafemode=1"
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
          1,
          "<addr>"
        ]
      }
    ],
    "active_tip": {
      "block": "b1",
      "height": 1
    },
    "key": "a fresh regtest key; its address is <addr> below"
  },
  "steps": [
    {
      "id": "s1",
      "action": {
        "type": "rpc",
        "method": "getblockcount",
        "params": []
      },
      "kind": "observe",
      "rules": [
        "src/rpc/blockchain.cpp:3797",
        "src/init.cpp:325-333"
      ],
      "expected_observations": {
        "reply": {
          "result": 1
        }
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
          "00"
        ]
      },
      "kind": "observe",
      "rules": [
        "src/rpc/rawtransaction.cpp:2624",
        "src/init.cpp:325-333",
        "src/warnings.cpp:46-47"
      ],
      "expected_observations": {
        "reply": {
          "error": {
            "code": -2,
            "message": "Safe mode: testsafemode enabled"
          }
        }
      },
      "label": "[D]",
      "node": "pending #66",
      "note": "refused before the handler decodes the hex"
    },
    {
      "id": "s3",
      "action": {
        "type": "rpc",
        "method": "sendrawtransactions",
        "params": [
          [
            {
              "hex": "00"
            }
          ]
        ]
      },
      "kind": "observe",
      "rules": [
        "src/rpc/rawtransaction.cpp:2625",
        "src/init.cpp:325-333"
      ],
      "expected_observations": {
        "reply": {
          "error": {
            "code": -2,
            "message": "Safe mode: testsafemode enabled"
          }
        }
      },
      "label": "[D]",
      "node": "pending #66"
    },
    {
      "id": "s4",
      "action": {
        "type": "rpc",
        "method": "getsafemodeinfo",
        "params": []
      },
      "kind": "observe",
      "rules": [
        "src/rpc/safe_mode.cpp:206",
        "src/safe_mode.cpp:498"
      ],
      "expected_observations": {
        "reply": {
          "result": {
            "safemodeenabled": false
          }
        }
      },
      "label": "[D]",
      "node": "pending #66",
      "note": "the fork-driven level only (Edge E2)"
    },
    {
      "id": "s5",
      "action": {
        "type": "rpc",
        "method": "getnetworkinfo",
        "params": []
      },
      "kind": "observe",
      "rules": [
        "src/rpc/net.cpp:665",
        "src/warnings.cpp:46-47"
      ],
      "expected_observations": {
        "reply": {
          "result": {
            "warnings": "testsafemode enabled"
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
