# Operator-list corpus: frozen outputs and the confiscation whitelist (#70)

[D] 2026-10-14, lane `s6-70`: twenty rows at bitcoin-sv v1.2.3
`6504a3aff65ba97c0f6c80962b033e35ecbfed4b`. Every row is `kind: policy`: the
frozen-output records and the confiscation whitelist are operator data, the
operator-list mechanism of DESIGN-S6 §1.5 (rule 13). The reference names one of
its lists "consensus" (`Blacklist::Consensus`, `src/frozentxo_db.h:194–202`);
that name labels an operator list the node also applies at block connection,
not a consensus rule of the chain. Every expectation is a literal derived from
the cited source lines, never from the judge's output.

Each row names the freeze RPCs it installs (`operator`, in call order) over
three named outputs: `F` and `F2` (funded outputs of block 102) and `CTX` (a
confiscation transaction spending `F`: output 0 the protocol marker, version 1,
a 20-byte order hash; `src/frozentxo_db.cpp:614–717`). Cases:

- `spend`: the spend of `F` or `F2` (or `CTX`) on `path` `admission` (at the
  tip's successor `height`) or `block` (at the block's `height`), with
  `explicitFreeze` for a block in an explicit soft consensus freeze. The spec
  replays the calls into `OperatorLists` (`lean/BsvChain/Frozen.lean`) and judges
  the UTXO stage (`checkTxInputs`) with the derived projection: `ok`, or the
  reason with its code on admission (16, `REJECT_INVALID`) and, on the block
  path, whether the refusal is the soft consensus freeze code 0x13
  (`softFreeze`, `src/validation.cpp:2594–2607,3402–3407`).
- `query-blacklist` and `query-whitelist`: the records as `queryBlacklist` and
  `queryConfiscationTxidWhitelist` report them (`src/rpc/frozentxo_rpc.cpp:404–499,799–894`),
  outputs by name and sorted.

`chaincheck --frozen corpus/chain/frozen/frozen.jsonl` judges every row
node-free inside the chain leg (`tools/chain_leg.sh`). The node column is
measured on four fresh loopback regtest instances by
`tools/node_scenarios.sh --frozen-only` (`harness/src/scenarios/frozen.rs`): the
policy list, the ranged list (inside and outside its interval [103, 105), with
and without the policy expiry), the explicit soft consensus freeze's release
(block A at 103 refused, then four descendants: the fourth activates the chain
through A), and the whitelist (unlisted, listed below and at its enforce height
105, and an ordinary spend of the confiscated output). The node runs full
admission (`sendrawtransaction`) or connection (`submitblock`, the new tip and
`getblockheader`'s soft consensus freeze mark); nothing is broadcast.
