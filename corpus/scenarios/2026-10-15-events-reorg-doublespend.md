# event vocabulary through a reorg and a double spend (#84)

[M] 2026-10-15. Scenario `2026-10-15-events-reorg-doublespend`; [M] twelve declared steps after the common prefix, which is a
thirteenth judged step (`s0`). [D] Every word here describes a view, never a rule. The [format and profile](README.md) supply the
isolated synthetic prefix; the vocabulary is `lean/BsvChain/Views/Events.lean`.

[D] Initial chain: the common intake prefix (`seed` in `harness/src/scenarios/core.rs`): 100 generated blocks `g1` to `g100`, then
`base` at height 101 holding `base:coinbase` and the funding transaction `F`. The subscriber connects before the prefix, so the
prefix's own messages are judged in `s0`. Synthetic names only: `T` and `K` both spend `F:fund` (`K` is the double spend); `U` spends
`T`; `M` spends the coinbase of `g4`, mature at height 104 and immature at height 102 (coinbase maturity 100, a consensus constant,
`src/consensus/consensus.h:71-75`). `A` (holding `K`) and `B1` (holding `T`) are sibling blocks on `base`; `B2` extends `B1`; `C` is
generated on `B2`. Equal work is decided by the machine's comparator `Chain.preferred` (the earlier completion wins, `A`), and an
activation step ends once its connected work exceeds the old tip's (`Chain.connectRun`); each step is one tip notice. No public peer, standing node or wallet is contacted. Nothing is broadcast.

[D] The instance runs the third binary of the pin (`BUILD_BITCOIN_ZMQ=ON`; the node of record and the wallet build are configured
OFF and create no notifier). Its configuration extras: every one of the eleven `-zmqpub<topic>` options on one loopback address
(the address is shared, `src/zmq/zmqpublishnotifier.cpp:38-72`), `invalidtxsink=ZMQ` and `invalidtxsink=FILE` (the ZMQ sink requires
its option and the option its sink, `src/init.cpp:2757-2768`), `debug=mempool` and `debug=zmq`. These are selected launch inputs.

[D] Each step declares the machine transitions it performs (the `transitions` list, the constructors of `Events.Transition`) and the
pool and tip after it. The runner computes each transition's messages by the mapping of `Events.events` (its Rust transcription,
`harness/src/scenarios/events.rs`), records every message the node publishes until the subscriber has been quiet for 1.5 s, and
matches the two as multisets of message keys: a hash topic by its 32-byte body, a raw topic by the decoded body's id, a removal
topic by `txid`, `reason`, `collidedWith.txid` and `blockhash`, `invalidtx` by `txid`, `fromBlock`, `source`, `isMissingInputs`,
`rejectionCode` and `rejectionReason`. A recorded message with no mapped transition, or a mapped message the node did not publish,
is filed as a witness in the record; neither is dropped.

[SRC] bitcoin-sv v1.2.3 at `6504a3aff65ba97c0f6c80962b033e35ecbfed4b`: `src/zmq/zmqnotificationinterface.cpp:33-47,59-80,176-352`;
`src/zmq/zmqpublishnotifier.cpp:22-36,104-292`; `src/txmempool.cpp:865-872,947-1023,1025-1173,2330-2443`;
`src/validation.cpp:1733-1757,1798-1803,4126,4402,5058-5070`; `src/txn_validator.cpp:203-207,673-679`;
`src/invalid_txn_publisher.cpp:76-181`; `src/invalid_txn_sinks/zmq_sink.cpp:11-20`; `src/invalid_txn_sinks/file_sink.cpp:12-40,146-183`.

[D] Not exercised by this run: expiry, the size limit, frozen-input and whitelist removals (the unknown-reason word), the removal
sites reorgFiltered, removeFromMempoolForReorg and capDisconnectPool, a held non-final transaction, a P2P source, a block's invalid
transaction (fromBlock true), the deferred, suppressed, unverifiable and RPC-namespace outcomes, the ZMQ sink's message bound and
the FILE sink's disk bound and eviction, the help text's -zmqpubremovedfrommempool, a miner-info dataref removal, and initial
download beyond genesis; the order of messages is not judged (multisets). Each has its mapping and citation in the module.

| step | action | declared transitions [D] |
|---|---|---|
| s0 | the common prefix | 100 connections and tip notices of `g1`..`g100`; `base` connected with `F` new to the pool |
| e1 | submit `T` | accept `T` (rpc) accepted |
| e2 | submit `K`, the double spend | accept `K` (rpc) rejected 258 `txn-mempool-conflict` |
| e3 | resubmit `F`, already mined | accept `F` (rpc) rejected 257 `txn-already-known`: no message |
| e4 | submit `A` = [`A:coinbase`, `K`] on `base` | `T` removed for conflict with `K` in `A`; connect `A` (pool held `T`); tip `A` |
| e5 | submit `B1` = [`B1:coinbase`, `T`] on `base` | stored off the active chain: silent |
| e6 | submit `B2` on `B1`: the reorg | disconnect `A`; connect `B1`, `B2`; `K` readmitted (reorg) with a missing input; tip `B2` |
| e7 | submit `U` spending `T` | accept `U` (rpc) accepted |
| e8 | generate `C` | `U` removed as mined; connect `C` (pool held `U`); tip `C` |
| e9 | submit `M` spending `g4:coinbase` | accept `M` (rpc) accepted |
| e10 | invalidate `C` | disconnect `C`; `U` readmitted (reorg) accepted; no tip notice (the new tip is the fork point) |
| e11 | invalidate `B2` | disconnect `B2`; `M` removed for reorg (now immature); `A` and `B1` tie on work and `A` completed earlier (`Chain.preferred`): disconnect `B1`, connect `A`; `T` readmitted (reorg) with a missing input, so `U` is removed for reorg; tip `A` |
| e12 | reconsider `B2` | disconnect `A`; connect `B1`, `B2`; `K` readmitted (reorg) with a missing input; tip `B2` (the step ends once its work exceeds the old tip's, `Chain.connectRun`); connect `C`; tip `C` |

```json
{
  "id": "2026-10-15-events-reorg-doublespend",
  "class": "event vocabulary (#84): every published message a mapped transition or a witness",
  "witness": "#84 done-bar: a regtest scenario with a subscriber recording every event through a reorg and a double spend",
  "label": "[D]",
  "input_label": "[D]",
  "source_pin": "6504a3aff65ba97c0f6c80962b033e35ecbfed4b",
  "binary": "zmq",
  "vocabulary": "lean/BsvChain/Views/Events.lean",
  "initial_chain": {"profile": "regtest-intake", "prefix": "core::seed: g1..g100 generated, base at 101 with F", "subscriber": "connected before the prefix"},
  "config_extras": ["zmqpubhashblock", "zmqpubhashtx", "zmqpubrawblock", "zmqpubrawtx", "zmqpubinvalidtx", "zmqpubdiscardedfrommempool", "zmqpubremovedfrommempoolblock", "zmqpubhashblock2", "zmqpubrawblock2", "zmqpubhashtx2", "zmqpubrawtx2", "invalidtxsink=ZMQ", "invalidtxsink=FILE", "debug=mempool", "debug=zmq"],
  "steps": [
    {"id": "s0", "action": {"type": "seed"}, "kind": "setup", "rules": ["connect", "tip"],
     "transitions": [{"connectRange": [1, 100], "pre_pool": []},
                     {"connect": "base", "pre_pool": [], "body": ["base:coinbase", "F"]},
                     {"tip": "base", "fork": "g100"}],
     "expected_observations": {"mempool": [], "tip": "base"}, "label": "[D]", "node": "measured agree [X] docs/records/20261015-035435-s7-84-events-s1.md"},
    {"id": "e1", "action": {"type": "submit", "tx": "T"}, "kind": "accept", "rules": ["accept"],
     "transitions": [{"accept": "T", "source": "rpc", "outcome": "accepted"}],
     "expected_observations": {"mempool": ["T"], "tip": "base"}, "label": "[D]", "node": "measured agree [X] docs/records/20261015-035435-s7-84-events-s1.md"},
    {"id": "e2", "action": {"type": "submit", "tx": "K"}, "kind": "accept", "rules": ["accept", "invalidtx"],
     "transitions": [{"accept": "K", "source": "rpc", "outcome": {"rejected": [258, "txn-mempool-conflict"]}}],
     "expected_observations": {"mempool": ["T"], "tip": "base"}, "label": "[D]", "node": "measured agree [X] docs/records/20261015-035435-s7-84-events-s1.md"},
    {"id": "e3", "action": {"type": "submit", "tx": "F"}, "kind": "accept", "rules": ["already_known_silent"],
     "transitions": [{"accept": "F", "source": "rpc", "outcome": {"rejected": [257, "txn-already-known"]}}],
     "expected_observations": {"mempool": ["T"], "tip": "base"}, "label": "[D]", "node": "measured agree [X] docs/records/20261015-035435-s7-84-events-s1.md"},
    {"id": "e4", "action": {"type": "submitblock", "block": "A", "parent": "base", "transactions": ["A:coinbase", "K"]}, "kind": "connect", "rules": ["conflict_names_spender", "connect", "tip"],
     "transitions": [{"removal": "removeForBlockConflict", "ids": ["T"], "spender": "K", "block": "A"},
                     {"connect": "A", "pre_pool": ["T"], "body": ["A:coinbase", "K"]},
                     {"tip": "A", "fork": "base"}],
     "expected_observations": {"mempool": [], "tip": "A"}, "label": "[D]", "node": "measured agree [X] docs/records/20261015-035435-s7-84-events-s1.md"},
    {"id": "e5", "action": {"type": "submitblock", "block": "B1", "parent": "base", "transactions": ["B1:coinbase", "T"]}, "kind": "store", "rules": ["silent"],
     "transitions": [{"silent": "acceptBlockStored"}],
     "expected_observations": {"mempool": [], "tip": "A"}, "label": "[D]", "node": "measured agree [X] docs/records/20261015-035435-s7-84-events-s1.md"},
    {"id": "e6", "action": {"type": "submitblock", "block": "B2", "parent": "B1", "transactions": ["B2:coinbase"]}, "kind": "reorg", "rules": ["disconnect", "connect", "orphan_publishes_missing", "tip"],
     "transitions": [{"disconnect": "A", "body": ["A:coinbase", "K"]},
                     {"connect": "B1", "pre_pool": [], "body": ["B1:coinbase", "T"]},
                     {"connect": "B2", "pre_pool": [], "body": ["B2:coinbase"]},
                     {"accept": "K", "source": "reorg", "outcome": "orphan"},
                     {"tip": "B2", "fork": "base"}],
     "expected_observations": {"mempool": [], "tip": "B2"}, "label": "[D]", "node": "measured agree [X] docs/records/20261015-035435-s7-84-events-s1.md"},
    {"id": "e7", "action": {"type": "submit", "tx": "U"}, "kind": "accept", "rules": ["accept"],
     "transitions": [{"accept": "U", "source": "rpc", "outcome": "accepted"}],
     "expected_observations": {"mempool": ["U"], "tip": "B2"}, "label": "[D]", "node": "measured agree [X] docs/records/20261015-035435-s7-84-events-s1.md"},
    {"id": "e8", "action": {"type": "generate", "block": "C"}, "kind": "connect", "rules": ["mined_says_included", "pooled_tx_no_hashtx2", "tip"],
     "transitions": [{"removal": "removeForBlockMined", "ids": ["U"]},
                     {"connect": "C", "pre_pool": ["U"], "body": ["C:coinbase", "U"]},
                     {"tip": "C", "fork": "B2"}],
     "expected_observations": {"mempool": [], "tip": "C"}, "label": "[D]", "node": "measured agree [X] docs/records/20261015-035435-s7-84-events-s1.md"},
    {"id": "e9", "action": {"type": "submit", "tx": "M"}, "kind": "accept", "rules": ["accept"],
     "transitions": [{"accept": "M", "source": "rpc", "outcome": "accepted"}],
     "expected_observations": {"mempool": ["M"], "tip": "C"}, "label": "[D]", "node": "measured agree [X] docs/records/20261015-035435-s7-84-events-s1.md"},
    {"id": "e10", "action": {"type": "invalidateblock", "block": "C"}, "kind": "disconnect", "rules": ["disconnect_reads_as_added", "accept", "fork_tip_silent"],
     "transitions": [{"disconnect": "C", "body": ["C:coinbase", "U"]},
                     {"accept": "U", "source": "reorg", "outcome": "accepted"},
                     {"tip": "B2", "fork": "B2"}],
     "expected_observations": {"mempool": ["M", "U"], "tip": "B2"}, "label": "[D]", "node": "measured agree [X] docs/records/20261015-035435-s7-84-events-s1.md"},
    {"id": "e11", "action": {"type": "invalidateblock", "block": "B2"}, "kind": "reorg", "rules": ["disconnect_cause_invisible", "removal_carries_reason", "orphan_publishes_missing", "tip"],
     "transitions": [{"disconnect": "B2", "body": ["B2:coinbase"]},
                     {"removal": "removeForReorg", "ids": ["M"]},
                     {"disconnect": "B1", "body": ["B1:coinbase", "T"]},
                     {"connect": "A", "pre_pool": ["U"], "body": ["A:coinbase", "K"]},
                     {"removal": "reorgNotReadmitted", "ids": ["U"]},
                     {"accept": "T", "source": "reorg", "outcome": "orphan"},
                     {"tip": "A", "fork": "base"}],
     "expected_observations": {"mempool": [], "tip": "A"}, "label": "[D]", "node": "measured agree [X] docs/records/20261015-035435-s7-84-events-s1.md"},
    {"id": "e12", "action": {"type": "reconsiderblock", "block": "B2"}, "kind": "reorg", "rules": ["disconnect", "connect", "orphan_publishes_missing", "tip"],
     "transitions": [{"disconnect": "A", "body": ["A:coinbase", "K"]},
                     {"connect": "B1", "pre_pool": [], "body": ["B1:coinbase", "T"]},
                     {"connect": "B2", "pre_pool": [], "body": ["B2:coinbase"]},
                     {"accept": "K", "source": "reorg", "outcome": "orphan"},
                     {"tip": "B2", "fork": "base"},
                     {"connect": "C", "pre_pool": [], "body": ["C:coinbase", "U"]},
                     {"tip": "C", "fork": "B2"}],
     "expected_observations": {"mempool": [], "tip": "C"}, "label": "[D]", "node": "measured agree [X] docs/records/20261015-035435-s7-84-events-s1.md"}
  ],
  "replay": {"runner": "run_scenarios --events --record docs/records/<stamp>-s7-84-events-s1.md", "boundary": "every message the instance published between its start and its stop; sequences per topic checked from 0; the console's zmq publish lines and the file sink's files compared"}
}
```
