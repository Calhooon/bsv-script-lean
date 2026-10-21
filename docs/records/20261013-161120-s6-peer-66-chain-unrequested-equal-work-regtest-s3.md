# [X] 2026-10-13: lane peer-66 regtest receipt

[M] Commit measured: `e4745a84e05bc46862b27f279ecb8de8cf8ef7f9`. UTC start: `2026-10-13T16:11:20Z`. Run `s6-peer-66-chain-unrequested-equal-work-20261013-161120`; fresh per-row instances under `~/bsv/targets/spec-oracle-scenarios/s6-peer-66-chain-unrequested-equal-work-20261013-161120/`. Wall [M] 3.024 seconds. Framework SHA [SRC] `6504a3aff65ba97c0f6c80962b033e35ecbfed4b`. Runner SHA256 [M] `76250bc43339545e464fdb5bd1bcc70a9c2f3ce11927aca72c28f26cacf8f7e2`; runner dirty [M] `false`.

[M] Peer rows 1, measured 1, agree 1, diverge 0, unrealizable 0, needs-peer 0, pending 0.

[M] 2026-10-13 correction, lane fix-peer: the selected row plus the corpus at the named measured commit gives chain/oracle rows 472, measured 282, agree 282, diverge 0, rpc-precheck 7, unrealizable 147, needs-peer 19, pending 17; this corrects the derived aggregate only and preserves all measured observations; intake remains its separate inherited 20 measured agree rows.

| row [D] | steps [D] | token [X] | receipt [X] |
|---|---|---|---|
| `chain/chain-unrequested-equal-work` | [D] 2026-10-13: construct rival B at the same predecessor as A; accept A by RPC; send B body without inv/header/request from the unwhitelisted peer; observe header-only status, unavailable body, equal chainwork and unchanged active tip. | measured agree: {"bodyAbsent":true,"equalWork":true,"ignored":true,"notFailed":true} [M] 2026-10-13 [X] docs/records/20261013-161120-s6-peer-66-chain-unrequested-equal-work-regtest-s3.md | [chain-unrequested-equal-work](20261013-161120-s6-peer-66-chain-unrequested-equal-work-regtest-s3.json) |

[M] 2026-10-13: observed protocol 70016 commands: authch, block, getheaders, inv, ping, pong, protoconf, sendcmpct, sendheaders, verack, version.

[D] 2026-10-13: instrument design in ten lines:

- [D] 2026-10-13: Python imports the reference framework from its pinned clone; no framework bytes are copied.
- [D] 2026-10-13: HEAD and the framework working files are checked before importing; every event carries the SHA.
- [D] 2026-10-13: MY_VERSION is 70016 ([SRC] test/functional/test_framework/mininode.py:48 at the pin).
- [D] 2026-10-13: Reference P2PHandler and P2PEventHandler frame messages and dispatch callbacks ([SRC] mininode.py:2118-2690).
- [D] 2026-10-13: Reference message classes supply the tx/block/header/inventory steps and handshake traffic ([SRC] mininode.py:1177-1932).
- [D] 2026-10-13: The reference regtest magic is da b5 bf fa ([SRC] mininode.py:2462-2467).
- [D] 2026-10-13: JSON lines provide connect, send_tx, send_block, send_headers, send_inv, withhold, release, expect and close.
- [D] 2026-10-13: The runner binds listen=1 to the reserved loopback P2P port; it never enables whitelist.
- [D] 2026-10-13: Receipts retain UTC steps and full message serialization beside separate RPC receipts and node logs.
- [D] 2026-10-13: This is an executable test instrument for S6 observations; S7's wire machine remains owed.

[X] 2026-10-13 walls: loopback only; discover/dnsseed/upnp disabled; standing RPC instances and mini untouched; private programs, forbidden records and tracker untouched. Per-id orphan evidence is confined to a known empty pool with one child or an explicitly bounded two-child eviction probe whose independent parent arrivals attribute retention. Scheduler completion is never inferred from setmocktime.
