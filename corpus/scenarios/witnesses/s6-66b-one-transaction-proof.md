# One-transaction proof RPC boundary

[X] Classification `spec-wrong` as data: the #75 done-bar predicts a proof object. The pinned RPC returns code -5 instead. The leaf at body index [M] 0 and empty body-derived branch are not fields returned by the RPC. [SRC] `src/rpc/rawtransaction.cpp:2302-2306` at the pin rejects an empty proof vector. This probe is outside the intake step counts.

```json
{
  "id": "s6-66b-one-transaction-proof",
  "class": "getmerkleproof single-entry body",
  "classification": "spec-wrong",
  "source_pin": "6504a3aff65ba97c0f6c80962b033e35ecbfed4b",
  "initial_chain": {
    "receipt": "docs/records/20261013-032121-s6-66b-regtest-s3.json",
    "run_id": "s6-66b-oracle-20261013-040214",
    "complete_rpc_history": "docs/records/20261013-032121-s6-66b-regtest-s3.json"
  },
  "steps": [
    {
      "id": "proof",
      "action": {
        "type": "getmerkleproof",
        "leaf": "b652a962a5e79f5f47fe5372ba518cfe7db8050bf3f80a7763be941c6e6f4187",
        "block": "57905263dc7cac2583b7e339681718f9c7dd278d0f35c21232ec7458351e3f90"
      },
      "expected_observations": {
        "index": 0,
        "nodes": [],
        "txOrId": "b652a962a5e79f5f47fe5372ba518cfe7db8050bf3f80a7763be941c6e6f4187"
      },
      "actual_observations": {
        "error": {
          "code": -5,
          "message": "Transaction(s) not found in provided block"
        }
      },
      "derived_status": {
        "value": "minedActive",
        "height": 1
      },
      "node": "measured diverge [X] docs/records/20261013-032121-s6-66b-regtest-s3.md",
      "kind": "observation limit",
      "rules": [
        "[SRC] src/rpc/rawtransaction.cpp:2302-2306 at 6504a3aff65ba97c0f6c80962b033e35ecbfed4b"
      ],
      "label": "[D]"
    }
  ],
  "replay": {
    "record": "docs/records/20261013-032121-s6-66b-regtest-s3.md",
    "handler": "[SRC] src/rpc/rawtransaction.cpp:2302-2306"
  },
  "witness": {
    "record": "docs/records/20261013-032121-s6-66b-regtest-s3.md",
    "receipt": "docs/records/20261013-032121-s6-66b-regtest-s3.json",
    "boundary": "getmerkleproof single-entry body",
    "materialization": {
      "receipt": "docs/records/20261013-032121-s6-66b-regtest-s3.json",
      "run_id": "s6-66b-oracle-20261013-040214",
      "complete_rpc_history": "docs/records/20261013-032121-s6-66b-regtest-s3.json"
    }
  },
  "input_label": "[D]"
}
```
