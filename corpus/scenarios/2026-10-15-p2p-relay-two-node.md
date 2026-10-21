# Two nodes, one connection: the relay machine observed (#78)

[D] 2026-10-15, S3, lane s7-78. Nothing here is a validity rule: the P2P layer
decides what a node hears and when. The machine is `lean/BsvChain/Wire/Relay.lean`;
its theorems are in `lean/BsvChain/Properties/Relay.lean`; the runner is
`run_scenarios --relay` (`harness/src/scenarios/relay.rs`); the projection is
`chaincheck --p2p <record.json>` (`lean/Test/P2PCheck.lean`), which runs the machine
over this file's stimuli and compares it with the run's receipt.
[SRC] bitcoin-sv v1.2.3 at `6504a3aff65ba97c0f6c80962b033e35ecbfed4b`.

## Topology

Two fresh regtest instances on the loopback range 18571 to 18590, the default ban
score (100) and every other relay setting at its default (docs/PARAMETERS.md section
8.6). A has its funding prefix (`seed`: 100 blocks and a block carrying F); B starts at
genesis, in its initial block download. B dials A once (`addnode onetry`,
`src/rpc/net.cpp:282-327`): the one connection between the nodes. The reference's test
peer (`harness/peer/peer.py`, the pinned `mininode.py`) logs every message it receives:
`probe` on B for the download gate, then `PB` on B and `PA` on A. `R` is a raw loopback
socket on A for the header over its cap. Every peer address is 127.0.0.1, a local
address (`src/net/net_processing.cpp:4911-4913`). Synthetic names only; nothing is
broadcast (rule 10).

## Steps

| step | stimulus | the machine's answer [D] |
|---|---|---|
| s1 | B in the download; `probe` announces X | no request (`ibd_inv_requests_nothing`) |
| s2 | `probe` closes; B dials A and reaches A's tip; the download ends; `PB` connects | the latch only |
| s3 | `PB` announces Y | B requests Y from `PB` |
| s4 | PA connects to A; A accepts T by RPC | `inv T` to PA and B; B requests T, A sends it; `inv T` to PB, none back to A (`rpcAccepted_announced_within` at A, `accepted_announced_within` and `accepted_announced_when_idle` at B, `known_never_queued`) |
| s5 | `PB` sends C before its parent P, then P | B keeps C, requests P from `PB`; P then C accepted; both announced to A, fetched, announced to PA; none to `PB` (`retryOrphan_announced_within` for C) |
| s6 | `PB` sends K, a conflicting spend (code 0x102) | no `reject` on the wire, no score (`step_rejects_on_wire`) |
| s7 | `PB` sends D, an input repeated (code 0x10, DoS 100) | `reject` 0x10 to `PB`, the score crosses 100, `PB` disconnected, no ban: it is local (`local_never_banned_by_score`) |
| s8 | `R` connects to A and sends a `ping` header of 2 MiB + 1 | 127.0.0.1 banned with no increment; B and PA disconnected (`ban_without_increment`); the bytes sent read as that header and over its cap (`s8_header_read`, `s8_header_oversized`, and in `chaincheck --p2p` from the receipt's `raw.sent`) |

The verdicts are the mempool machine's (#62), declared, never decided here: T, P and C
accepted once their parents are pooled (a transaction whose parent is neither mined nor
pooled has missing inputs), K refused `txn-mempool-conflict` (0x102, internal), D
refused `bad-txns-inputs-duplicate` (0x10, DoS 100).

```json
{
  "id": "2026-10-15-p2p-relay-two-node",
  "class": "the relay layer: announcement, request, orphan parent, reject, score, ban, download gate",
  "witness": "#78",
  "source_pin": "6504a3aff65ba97c0f6c80962b033e35ecbfed4b",
  "label": "[D]",
  "initial_chain": {"A": "seed: 100 blocks and the block carrying F (harness/src/scenarios/core.rs `seed`)", "B": "genesis, in the initial block download", "mined": ["F"]},
  "topology": {
    "A": {"ibd": false, "peers": ["B", "PA", "R"], "link": "B", "connected": []},
    "B": {"ibd": true, "peers": ["probe", "A", "PB"], "link": "A", "connected": ["probe"]},
    "address": "127.0.0.1, local, every peer"
  },
  "verdicts": {
    "T": "accepted", "P": "accepted", "C": "accepted",
    "K": {"invalid": [258, "txn-mempool-conflict", 0]},
    "D": {"invalid": [16, "bad-txns-inputs-duplicate", 100]}
  },
  "steps": [
    {"id": "s1-ibd-gate", "kind": "download gate", "stimulus": [{"at": "B", "event": "recvInv", "from": "probe", "items": ["X"]}],
     "rules": ["[SRC] src/net/net_processing.cpp:2509-2520 at 6504a3af"],
     "expected_observations": {"to": {"probe": {}}, "pool": {"B": []}},
     "label": "[D]", "node": "measured agree [X] docs/records/20261015-125403-s7-78-p2p-machine-s1.md"},
    {"id": "s2-connect-sync", "kind": "the latch", "stimulus": [{"at": "B", "event": "close", "peer": "probe"}, {"at": "B", "event": "connect", "peer": "A"}, {"at": "A", "event": "connect", "peer": "B"}, {"at": "B", "event": "setIbd", "value": false}, {"at": "B", "event": "connect", "peer": "PB"}],
     "rules": ["[SRC] src/validation.cpp:2265-2313 (IsInitialBlockDownload); src/rpc/net.cpp:282-327 at 6504a3af"],
     "expected_observations": {},
     "label": "[D]", "node": "measured agree [X] docs/records/20261015-125403-s7-78-p2p-machine-s1.md"},
    {"id": "s3-ibd-lifted", "kind": "request", "stimulus": [{"at": "B", "event": "recvInv", "from": "PB", "items": ["Y"]}],
     "rules": ["[SRC] src/net/net_processing.cpp:2518-2520,5782-5843; src/net/net.cpp:3269-3318 at 6504a3af"],
     "expected_observations": {"to": {"PB": {"getdata": ["Y"]}}},
     "label": "[D]", "node": "measured agree [X] docs/records/20261015-125403-s7-78-p2p-machine-s1.md"},
    {"id": "s4-relay", "kind": "announcement", "stimulus": [{"at": "A", "event": "connect", "peer": "PA"}, {"at": "A", "event": "rpcAccepted", "tx": "T"}],
     "rules": ["[SRC] src/rpc/rawtransaction.cpp:1682; src/net/net.cpp:836-878,3574-3582; src/net/net_processing.cpp:1392-1430,2454-2532,3351-3408,5536-5674; src/validation.cpp:2097-2116 at 6504a3af"],
     "expected_observations": {"to": {"PA": {"inv": ["T"]}, "PB": {"inv": ["T"]}},
       "edges": {"A>B": {"inv": ["T"], "tx": ["T"]}, "B>A": {"getdata": ["T"]}},
       "pool": {"A": ["T"], "B": ["T"]}},
     "label": "[D]", "node": "measured agree [X] docs/records/20261015-125403-s7-78-p2p-machine-s1.md"},
    {"id": "s5-orphan-fetch", "kind": "orphan parent", "stimulus": [{"at": "B", "event": "recvTx", "from": "PB", "tx": "C"}, {"at": "B", "event": "recvTx", "from": "PB", "tx": "P"}],
     "rules": ["[SRC] src/validation.cpp:1855-1932; src/txn_validator.cpp:695-724; src/net/net_processing.cpp:5782-5843 at 6504a3af"],
     "expected_observations": {"to": {"PA": {"inv": ["P", "C"]}, "PB": {"getdata": ["P"]}},
       "edges": {"B>A": {"inv": ["P", "C"], "tx": ["P", "C"]}, "A>B": {"getdata": ["P", "C"]}},
       "pool": {"A": ["C", "P", "T"], "B": ["C", "P", "T"]}},
     "label": "[D]", "node": "measured agree [X] docs/records/20261015-125403-s7-78-p2p-machine-s1.md"},
    {"id": "s6-internal-code-silent", "kind": "reject vocabulary", "stimulus": [{"at": "B", "event": "recvTx", "from": "PB", "tx": "K"}],
     "rules": ["[SRC] src/validation.cpp:1934-1952,2030-2095; src/validation.h:1150-1163 at 6504a3af"],
     "expected_observations": {"to": {"PB": {}}, "score": {"PB": 0}},
     "label": "[D]", "node": "measured agree [X] docs/records/20261015-125403-s7-78-p2p-machine-s1.md"},
    {"id": "s7-reject-score", "kind": "reject and score", "stimulus": [{"at": "B", "event": "recvTx", "from": "PB", "tx": "D"}],
     "rules": ["[SRC] src/validation.cpp:1934-1952,2030-2095; src/net/net_processing.cpp:610-634,4900-4919 at 6504a3af"],
     "expected_observations": {"to": {"PB": {"reject": [[16, "bad-txns-inputs-duplicate", "D"]]}}, "score": {"PB": 100},
       "increments": {"B": [["PB", 100, "bad-txns-inputs-duplicate"]]}, "disconnected": {"B": ["PB"]}, "banned": {"B": []}},
     "label": "[D]", "node": "measured agree [X] docs/records/20261015-125403-s7-78-p2p-machine-s1.md"},
    {"id": "s8-direct-ban", "kind": "ban without increment", "stimulus": [{"at": "A", "event": "connect", "peer": "R"}, {"at": "A", "event": "oversizedHeader", "from": "R"}],
     "rules": ["[SRC] src/net/net_message.cpp:22-26; src/net/association.cpp:396-401; src/net/net.cpp:535-580 at 6504a3af"],
     "expected_observations": {"increments": {"A": []}, "disconnected": {"A": ["B", "PA", "R"]}, "banned": {"A": [["127.0.0.1", "oversizedHeader"]]}},
     "label": "[D]", "node": "measured agree [X] docs/records/20261015-125403-s7-78-p2p-machine-s1.md"}
  ],
  "replay": {"command": "harness/target/release/run_scenarios --relay --record docs/records/<stamp>-s7-78-p2p-machine-s1.md, then lean/.lake/build/bin/chaincheck --p2p docs/records/<stamp>-s7-78-p2p-machine-s1.json"}
}
```
