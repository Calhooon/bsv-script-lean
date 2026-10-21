# corpus/rpc: the RPC observation contract of the #66 runner (#85)

[D] 2026-10-15, lane rpc-85. Two files, both data:

- `contract.json`: every handler the runner calls (50), its arguments, result type, error codes, and its behaviors
  under safe mode, pruning and a mock clock, each cited at bitcoin-sv v1.2.3 `6504a3af` and Teranode v0.16.0
  `4edb60a4` [SRC]; the result types in a small type language (`tools/rpc_contract.py`'s docstring). It is the
  source of `harness/src/scenarios/rpc_contract.rs` and of the tables of `docs/CONFORMANCE-RPC-CONTRACT.md`;
  change it, then run `python3 tools/rpc_contract.py`.
- `replies.json`: the replay projection of the probe record `docs/records/20261015-035438-s7-85-rpc-contract-s4b.json`
  (`tools/rpc_probe.py` on fresh regtest instances): every success reply of a contract handler called with positional
  arguments, by method. `harness/tests/rpc_contract.rs` passes each through the typed interface [X].

Nothing here was read from a public network; the regtest keys are fresh per run and the key's private half is redacted
from the record.
