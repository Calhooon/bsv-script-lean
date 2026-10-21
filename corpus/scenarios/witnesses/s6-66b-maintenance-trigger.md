# Maintenance trigger amendment

[M] 2026-10-13, R2. Classification `spec-wrong` as data applies to the unavailable direct instrumentation declaration. The RPC batch rejects both probes and witnesses expiry without admitting either. [SRC] `src/rawtxvalidator.cpp:54-92,126-138`; `src/txn_validator.cpp:303-314`; `src/validation.cpp:853-856` at the pinned source.

```json
{
  "id": "s6-66b-maintenance-trigger",
  "class": "maintenance trigger implementation",
  "classification": "spec-wrong",
  "source_pin": "6504a3aff65ba97c0f6c80962b033e35ecbfed4b",
  "initial_chain": {
    "scenario": "2026-10-12-mempool-presence-terminal",
    "receipt": "docs/records/20261013-032121-s6-66b-regtest-s3.json",
    "complete_rpc_history": "docs/records/20261013-032121-s6-66b-regtest-s3.json"
  },
  "steps": [
    {
      "id": "e1",
      "action": {
        "type": "sendrawtransactions",
        "probes": [
          "sweep0",
          "sweep1"
        ]
      },
      "expected_observations": "historical direct oracleInstrumentation event was unavailable on the pinned binary",
      "actual_observations": [
        {
          "auxiliary_rejections": {
            "invalid": [
              {
                "reject_code": 16,
                "reject_reason": "bad-txns-vin-empty",
                "txid": "2bff6837a7182e489570ff2b92f56342dc64bee03e32fc71109ef724e14306cc"
              },
              {
                "reject_code": 16,
                "reject_reason": "bad-txns-vin-empty",
                "txid": "d374b8319d17a8061109901f40306c692c3e04e03994de8c8087adaf7fa32ca4"
              }
            ]
          },
          "event": "maintenance-completion",
          "log": "2023-11-28 22:13:21 [rawtransactionvalidator] Expired 1 transactions from the memory pool",
          "rpc_completed": true,
          "source": "[SRC] src/validation.cpp:853-856; src/rawtxvalidator.cpp:64-91 at 6504a3aff65ba97c0f6c80962b033e35ecbfed4b"
        }
      ],
      "derived_status": {
        "F": {
          "height": 101,
          "value": "minedActive"
        },
        "K": {
          "value": "unknown"
        },
        "T": {
          "value": "unknown"
        }
      },
      "node": "measured agree [X] docs/records/20261013-032121-s6-66b-regtest-s3.md",
      "kind": "maintenance input",
      "rules": [
        "[SRC] src/rawtxvalidator.cpp:54-92,126-138 at 6504a3aff65ba97c0f6c80962b033e35ecbfed4b"
      ],
      "label": "[D]"
    }
  ],
  "replay": {
    "record": "docs/records/20261013-032121-s6-66b-regtest-s3.md"
  },
  "witness": {
    "record": "docs/records/20261013-032121-s6-66b-regtest-s3.md",
    "receipt": "docs/records/20261013-032121-s6-66b-regtest-s3.json",
    "boundary": "maintenance trigger implementation",
    "materialization": {
      "scenario": "2026-10-12-mempool-presence-terminal",
      "receipt": "docs/records/20261013-032121-s6-66b-regtest-s3.json",
      "complete_rpc_history": "docs/records/20261013-032121-s6-66b-regtest-s3.json"
    }
  },
  "input_label": "[D]"
}
```
