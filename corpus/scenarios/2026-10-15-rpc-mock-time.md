# The mock clock: what follows it and what does not (#85)

[D] 2026-10-15, lane rpc-85 (#85, docs/CONFORMANCE-RPC-CONTRACT.md §2.3 and Edge E3). A fresh regtest instance of
the node of record on `harness/oracle/scenarios.conf`. [SRC] at `6504a3aff65ba97c0f6c80962b033e35ecbfed4b`:
`setmocktime` (`src/rpc/misc.cpp:980-1008`, regtest only at `:992-995`), `GetTime` (`src/utiltime.cpp:23-29`), a block's
time `max(MTP + 1, GetAdjustedTime())` (`src/mining/assembler.cpp:80-84`), `timeutc` (`src/safe_mode.cpp:500`, the
wall clock), the offset (`src/timedata.cpp:74-82`). The probe observed every step [X] (record `docs/records/20261015-035438-s7-85-rpc-contract-s4b.md`); the runner's
column is `pending #66`.

```json
{
  "id": "2026-10-15-rpc-mock-time",
  "class": "The mock clock: what follows it and what does not (#85)",
  "witness": "#85: docs/CONFORMANCE-RPC-CONTRACT.md and corpus/rpc/contract.json",
  "input_label": "[D]",
  "source_pin": "6504a3aff65ba97c0f6c80962b033e35ecbfed4b",
  "initial_chain": {
    "profile": "rpc-85",
    "input_label": "[D]",
    "base_config": "harness/oracle/scenarios.conf",
    "launch": [],
    "mock_time": 1700000000,
    "setup": [],
    "active_tip": {
      "block": "genesis",
      "height": 0
    },
    "key": "a fresh regtest key; its address is <addr> below"
  },
  "steps": [
    {
      "id": "s1",
      "action": {
        "type": "rpc",
        "method": "setmocktime",
        "params": [
          1700000000
        ]
      },
      "kind": "observe",
      "rules": [
        "src/rpc/misc.cpp:1004-1005",
        "src/utiltime.cpp:31-33"
      ],
      "expected_observations": {
        "reply": {
          "result": null
        }
      },
      "label": "[D]",
      "node": "pending #66"
    },
    {
      "id": "s2",
      "action": {
        "type": "rpc",
        "method": "generatetoaddress",
        "params": [
          1,
          "<addr>"
        ]
      },
      "kind": "observe",
      "rules": [
        "src/mining/assembler.cpp:80-84"
      ],
      "expected_observations": {
        "reply": {
          "block_time": 1700000000
        }
      },
      "label": "[D]",
      "node": "pending #66",
      "note": "read through getblockheader"
    },
    {
      "id": "s3",
      "action": {
        "type": "rpc",
        "method": "getsafemodeinfo",
        "params": []
      },
      "kind": "observe",
      "rules": [
        "src/safe_mode.cpp:500"
      ],
      "expected_observations": {
        "reply": {
          "timeutc_is": "the wall clock, not 2023-11-14T22:13:20Z"
        }
      },
      "label": "[D]",
      "node": "pending #66",
      "note": "Edge E3"
    },
    {
      "id": "s4",
      "action": {
        "type": "rpc",
        "method": "setmocktime",
        "params": [
          1700086400
        ]
      },
      "kind": "observe",
      "rules": [
        "src/utiltime.cpp:31-33"
      ],
      "expected_observations": {
        "reply": {
          "result": null
        }
      },
      "label": "[D]",
      "node": "pending #66"
    },
    {
      "id": "s5",
      "action": {
        "type": "rpc",
        "method": "generatetoaddress",
        "params": [
          1,
          "<addr>"
        ]
      },
      "kind": "observe",
      "rules": [
        "src/mining/assembler.cpp:80-84"
      ],
      "expected_observations": {
        "reply": {
          "block_time": 1700086400
        }
      },
      "label": "[D]",
      "node": "pending #66"
    },
    {
      "id": "s6",
      "action": {
        "type": "rpc",
        "method": "getnetworkinfo",
        "params": []
      },
      "kind": "observe",
      "rules": [
        "src/rpc/net.cpp:626",
        "src/timedata.cpp:74-82"
      ],
      "expected_observations": {
        "reply": {
          "result": {
            "timeoffset": 0
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
        "method": "setmocktime",
        "params": [
          0
        ]
      },
      "kind": "observe",
      "rules": [
        "src/utiltime.cpp:23-29"
      ],
      "expected_observations": {
        "reply": {
          "result": null
        }
      },
      "label": "[D]",
      "node": "pending #66",
      "note": "the wall clock again"
    },
    {
      "id": "s8",
      "action": {
        "type": "rpc",
        "method": "generatetoaddress",
        "params": [
          1,
          "<addr>"
        ]
      },
      "kind": "observe",
      "rules": [
        "src/mining/assembler.cpp:80-84"
      ],
      "expected_observations": {
        "reply": {
          "block_time_is": "the wall clock"
        }
      },
      "label": "[D]",
      "node": "pending #66"
    },
    {
      "id": "s9",
      "action": {
        "type": "rpc",
        "method": "setmocktime",
        "params": [
          "x"
        ]
      },
      "kind": "observe",
      "rules": [
        "src/rpc/misc.cpp:1004",
        "src/rpc/server.cpp:68-90"
      ],
      "expected_observations": {
        "reply": {
          "error": {
            "code": -3,
            "message": "Expected type number, got string"
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
