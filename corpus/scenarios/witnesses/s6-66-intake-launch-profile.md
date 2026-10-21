# Intake launch profile refusal

[X] The declared configuration is refused before scenario execution. Both intake files were unchanged at that historical run; their current declarations incorporate R1/R2. Classification is `spec-wrong` as data; no transaction step is counted as realized.

```json
{
  "id": "s6-66-intake-launch-profile",
  "class": "declared scenario launch input refused",
  "classification": "spec-wrong",
  "source_pin": "6504a3aff65ba97c0f6c80962b033e35ecbfed4b",
  "initial_chain": {
    "profile": "regtest-intake",
    "excessiveBlockSize": 1000000,
    "conf": "harness/oracle/scenarios.conf",
    "run_id": "s6-66-20261013-025700",
    "complete_rpc_history": "docs/records/20261013-024612-s6-66-regtest-s3.json"
  },
  "steps": [
    {
      "id": "launch",
      "action": {
        "type": "startOwnedRegtest",
        "excessiveblocksize": 1000000
      },
      "expected_observations": {
        "launch": "usable regtest-intake instance"
      },
      "actual_observations": {
        "reason": "launch exit exit status: 1: Error: Excessive block size (excessiveblocksize) must be larger than 1000000\n",
        "status": "blocked",
        "trace": "primary"
      },
      "derived_status": {
        "value": "unknown"
      },
      "status_basis": "No chain or transaction step ran; launch refusal supplies no transaction receipt.",
      "node": "measured diverge [X] docs/records/20261013-024612-s6-66-regtest-s3.md",
      "kind": "launch input",
      "rules": [
        "[SRC] src/config.cpp:232-245 at 6504a3aff65ba97c0f6c80962b033e35ecbfed4b"
      ],
      "label": "[D]"
    }
  ],
  "replay": {
    "record": "docs/records/20261013-024612-s6-66-regtest-s3.md",
    "source": "[SRC] src/config.cpp:232-245 at 6504a3aff65ba97c0f6c80962b033e35ecbfed4b"
  },
  "witness": {
    "record": "docs/records/20261013-024612-s6-66-regtest-s3.md",
    "receipt": "docs/records/20261013-024612-s6-66-regtest-s3.json",
    "boundary": "declared scenario launch input refused",
    "materialization": {
      "profile": "regtest-intake",
      "excessiveBlockSize": 1000000,
      "conf": "harness/oracle/scenarios.conf",
      "run_id": "s6-66-20261013-025700",
      "complete_rpc_history": "docs/records/20261013-024612-s6-66-regtest-s3.json"
    }
  },
  "input_label": "[D]"
}
```

[M] 2026-10-13, R1 amendment: the active README declaration now uses `excessiveBlockSize = 1000001`; the refused historical value above is retained as the witness. [SRC] `src/config.cpp:232-245` at the pinned source.
