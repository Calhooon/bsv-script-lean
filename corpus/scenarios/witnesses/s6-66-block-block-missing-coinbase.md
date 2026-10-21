# s6-66-block-block-missing-coinbase

[X] Row `block/missing-coinbase`. Classification is `observation limit (RPC pre-check)` as data. The recorded live prefix, materialized block and exact RPC receipt form this witness.

```json
{
  "class": "node RPC envelope differs from isolated spec stage",
  "classification": "observation limit (RPC pre-check)",
  "id": "s6-66-block-block-missing-coinbase",
  "initial_chain": {
    "complete_rpc_history": "docs/records/20261013-024612-s6-66-regtest-s3.json",
    "family": "block",
    "recipe": "Build on live height 999 with actual mature coinbase prevout; reproduce named body mutation, recompute merkle root except the root-mismatch row and grind valid regtest PoW. Restore tip after accepted rows. Compare submitblock acceptance/reason; validation code and corruption flag are not exposed by this RPC.",
    "row": "block/missing-coinbase"
  },
  "input_label": "[D]",
  "replay": {
    "record": "docs/records/20261013-024612-s6-66-regtest-s3.md",
    "rpc_handler": "[SRC] src/rpc/mining.cpp:826-839,916-952 at 6504a3aff65ba97c0f6c80962b033e35ecbfed4b"
  },
  "source_pin": "6504a3aff65ba97c0f6c80962b033e35ecbfed4b",
  "steps": [
    {
      "action": {
        "hex": "04000000048c8562cbda8872eddfc5c20748329ebda807751b372810164ab43db5ee1e1416b25341df51d4805a9b0fa8c833eac88d6d2d43ca79d1174c62fce32a90f76b01f15365ffff7f200200000001010000000187416f6e1c94be63770af8f30b05b87dfe8c51ba7253fe475f9fe7a562a952b6000000006a4730440220343b00775abefca8012bd87a637207db00be251611656736e00c17dd2e8c3851022045855b93a7afebba724b485f268a54c2d842ac6209fc43f2793c4aa66c601081412103786333c3f42e3dc609bc9c5179ba8df99d6d01800f9558ea277688a4dced4bceffffffff01e8030000000000001976a914f09581d66893f0fddad00184dea48c588317975488ac00000000",
        "type": "submitblock"
      },
      "actual_observations": {
        "error": {
          "code": -22,
          "message": "Block does not start with a coinbase"
        },
        "status": "rpc-error"
      },
      "derived_status": {
        "fundingCoin": {
          "height": 1,
          "value": "minedActive"
        },
        "probe": {
          "value": "unknown"
        }
      },
      "expected_observations": {
        "reason": "bad-cb-missing",
        "status": "rejected"
      },
      "id": "submit",
      "node": "rpc-precheck: -22 Block does not start with a coinbase (src/rpc/mining.cpp:830-838) [X] docs/records/20261013-032121-s6-66b-regtest-s3.md",
      "status_basis": "A block RPC failure creates no transaction rejection receipt. The funding coin stays in its recorded active prefix; the probe has no active/stale inclusion or pool entry.",
      "kind": "observation limit",
      "rules": [
        "[SRC] src/rpc/mining.cpp:826-839,916-952 at 6504a3aff65ba97c0f6c80962b033e35ecbfed4b"
      ],
      "label": "[D]"
    }
  ],
  "witness": {
    "record": "docs/records/20261013-024612-s6-66-regtest-s3.md",
    "receipt": "docs/records/20261013-024612-s6-66-regtest-s3.json",
    "boundary": "node RPC envelope differs from isolated spec stage",
    "materialization": {
      "complete_rpc_history": "docs/records/20261013-024612-s6-66-regtest-s3.json",
      "family": "block",
      "recipe": "Build on live height 999 with actual mature coinbase prevout; reproduce named body mutation, recompute merkle root except the root-mismatch row and grind valid regtest PoW. Restore tip after accepted rows. Compare submitblock acceptance/reason; validation code and corruption flag are not exposed by this RPC.",
      "row": "block/missing-coinbase"
    }
  }
}
```
