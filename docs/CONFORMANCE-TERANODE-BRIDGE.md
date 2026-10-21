# Teranode's legacy bridge against the reference's wire protocol (#98, the reading half and the theorem half)

Issue numbers on this page are the archived tracker's ([docs/GLOSSARY.md](GLOSSARY.md), "archived #n").

[M] 2026-10-14 for #98, written from the sources at the pins and nothing else. This page is a
reading: no message in it has crossed a socket. Every class below is `[D]` (this page's judgement of what it
read); every citation is `[SRC]` at the pin named in §0. The mixed two-node scenario that turns the classes into
measurements is §4's list, owed to #66's runner and #78's machine; until it runs, no row here is a measured
agreement, and a disagreement the scenario finds is a witness filed against the reading (rule 4), never a
sentence edited to fit.

[M] 2026-10-18: the theorem half is §6, in Lean at `lean/BsvChain/Teranode/Bridge.lean` against #78's
protocol machine (`lean/BsvChain/Wire/Relay.lean`); it proves the mapping of §1 and the accept roads under named
correspondences, and leaves the correspondences to the scenario of §4.

## 0. The pins, the classes and the two dispatch roads

**The pins** `[SRC]`. The reference: bitcoin-sv `v1.2.3` = `6504a3aff65ba97c0f6c80962b033e35ecbfed4b`
(`docs/PROVENANCE.md` §1a). The bridge: Teranode `v0.16.0` = `4edb60a40c6628ff0ef60231c2628efd7103fde5`,
`services/legacy/` (`docs/DESIGN-S6.md` §5.2's last service row). The bridge's wire codec is not in Teranode's
tree: it is the module `github.com/bsv-blockchain/go-wire` `v1.2.11`, required at `go.mod:205` and hashed at
`go.sum:146` of the Teranode tag (`h1:jVbatioBZ21ebK7rrt9IY768VPVTMpk0KSPC2fm0lS0=`). The module was read from the
public Go module proxy on 2026-10-14 at 21:24Z (§5), and `go mod download` reported the same `h1` sum; that read
has no record file under `docs/records/` and is not booked in `docs/PROVENANCE.md` §6, both left to the §1a go-wire
row asked for below (§5). go-wire is not a pin of `docs/PROVENANCE.md` §1a, so its sixteen citations below are
written `go-wire@v1.2.11/<file>:<line>` and the cite leg reports them as `absent` (no pinned clone), never anchored. **Finding** for the harness side: a §1a row for go-wire at `v1.2.11` is owed
before #78 cites the bridge's codec.

**The classes** `[D]`. One per message type, judged at the protocol machine's level (what a peer of the bridge
observes and what state moves), never at the code's shape:

- **SAME**: the bridge's handler answers the message as the reference's does, or both ignore it.
- **TRANSLATED**: the bridge maps the message into a Teranode service call (named, cited) whose effect stands in for
  the reference's handler; each such row is one refinement obligation for #88.
- **DROPPED**: the bridge ignores, refuses or cannot decode a message the reference handles. The note says whether
  an SV-node peer can send it to the bridge at the pins (*reachable*) or only a hand-built peer can (*unreachable
  from an SV-node peer*).

**The reference's road** `[SRC]`. `ProcessMessages` (`src/net/net_processing.cpp:4958`) checks the network magic
(`:5033`), the header (`:5045`) and the checksum unless the header is extended (`:5055`), then `ProcessMessage`
(`:4689`) dispatches by command (`:4716–4878`). Before `version` only `reject`, `version`, `createstrm` and
`streamack` pass (`:4732`); before `verack` only `verack`, `authch` and `authresp` (`:4753`). **An unknown command is
ignored** (`:4874–4878`: "Ignore unknown commands for extensibility").

**The bridge's road** `[SRC]`. The read loop `inHandler` (`services/legacy/peer/peer.go:1869`) reads each message
through go-wire's streaming reader (`services/legacy/peer/peer.go:1923`; `go-wire@v1.2.11/message.go:565`). The reader builds the message
by command in `makeEmptyMessage` (`go-wire@v1.2.11/message.go:120`), whose cases are the commands of
`go-wire@v1.2.11/message.go:56–91`; any other command is an error (`go-wire@v1.2.11/message.go:228–230`, returned as a
message error at `:614–619`). **A read error ends the connection**, except when the network is regtest and the
peer's host is exactly `127.0.0.1` or `localhost`, where a `*wire.MessageError` is logged and the loop continues
(`services/legacy/peer/peer.go:1367–1390`, `:1930–1934`); otherwise a handled error pushes `reject` `malformed` and
disconnects (`services/legacy/peer/peer.go:1939–1954`), and an EOF disconnects with no reject (`services/legacy/peer/peer.go:1955–1960`).
A decoded message goes to the typed switch (`services/legacy/peer/peer.go:1990`) and from there to the listeners the server registers
(`services/legacy/peer_server.go:3121–3146`); a decoded type with no case is logged and dropped (`services/legacy/peer/peer.go:2129–2130`).
Nine of the reference's thirty-eight command names have no go-wire command, so the bridge's answer to each of them
is the read-error road, not a handler.

## 1. The mapping, one row per message type of the reference at v1.2.3

`src/protocol.h` declares thirty-eight command names (`src/protocol.h:199–445`; the strings at `src/protocol.cpp:16–53`)
and the extended header (`src/protocol.h:93`). The rows follow the declaration order. `[SRC]` for every citation,
`[D]` for every class.

| # | message | the reference's handler | the bridge's handler | class | note |
|---|---|---|---|---|---|
| 1 | `version` | `ProcessVersionMessage` `src/net/net_processing.cpp:1670` | `negotiateInboundProtocol` `services/legacy/peer/peer.go:2722`, `handleVersionMsg` `services/legacy/peer/peer.go:2757`, `OnVersion` `services/legacy/peer_server.go:769` | SAME | the bridge also rejects and bans a peer whose user agent lacks `Bitcoin SV` or `BSV` (`peer_server.go:762–764`, `:802–814`); its floor is protocol 209 (`services/legacy/peer/peer.go:44`, `wire.MultipleAddressVersion` = 209 in `go-wire@v1.2.11/protocol.go`, the line unread: no local clone) where the reference's is `MIN_PEER_PROTO_VERSION` 31800 (`src/version.h:17–20`); a duplicate `version` disconnects (`services/legacy/peer/peer.go:1991–1994`) where the reference rejects and scores 1 (`net_processing.cpp:1681–1683`) |
| 2 | `verack` | `ProcessVerAckMessage` `net_processing.cpp:1928` | the typed switch `services/legacy/peer/peer.go:1996–2009` | SAME | the reference answers a `verack` with `authch`, `sendheaders` and `sendcmpct` (`net_processing.cpp:1957–1981`); rows 36, 23 and 26 are the bridge's answers to those |
| 3 | `addr` | `ProcessAddrMessage` `net_processing.cpp:2280` | `OnAddr` `peer_server.go:2037` into the address manager (`services/legacy/addrmgr/addrmanager.go`) | SAME | an `addr` with no address disconnects (`peer_server.go:2048–2053`) |
| 4 | `inv` | `ProcessInvMessage` `net_processing.cpp:2454` | `OnInv` `peer_server.go:1624`, `QueueInv` `services/legacy/netsync/manager.go:3396`, `handleInvMsg` `manager.go:2654`, `processInvMsg` `manager.go:2809` | TRANSLATED | transaction entries go through the Kafka inv topic and back (`manager.go:3403–3445`) and are acted on only while the blockchain service's FSM is RUNNING (`manager.go:2812–2816`); "have it" is the blockchain service's `GetBlockHeader` for a block (`manager.go:2623`; `services/blockchain/Client.go:797`) and the UTXO store's `Get` for a transaction (`manager.go:2635`; `stores/utxo/Interface.go:408`); the request is a `getdata` (`manager.go:2753`) |
| 5 | `getdata` | `ProcessGetDataMessage` `net_processing.cpp:2537`, served by `ProcessGetData` `:1173` | `OnGetData` `peer_server.go:1680`; `pushTxMsg` `:2167`, `pushBlockMsg` `:2247`, `pushMerkleBlockMsg` `:2329` | TRANSLATED | a transaction is served from the UTXO store's record, mined or not (`peer_server.go:2180`), where the reference serves from its relay map, or from the mempool after a `mempool` request (`net_processing.cpp:1391–1428`); a block from the node's own asset service over HTTP (`peer_server.go:2254`); an entry of another type (the compact block, the dataref transaction) is skipped with no `notfound` (`peer_server.go:1725–1728`), where the reference answers `notfound` (`net_processing.cpp:1471–1481`) |
| 6 | `merkleblock` | no inbound case: the unknown-command branch `net_processing.cpp:4874–4878` (sent only, `:1303`) | decoded, case `services/legacy/peer/peer.go:2097–2100`, no listener registered (`peer_server.go:3121–3146`) | SAME | both ignore it inbound; the bridge never serves one, since no filter is ever loaded (`peer_server.go:2332–2338`, row 19) |
| 7 | `getblocks` | `ProcessGetBlocksMessage` `net_processing.cpp:2629` (`ProcessGetBlocks` `:2561`) | `OnGetBlocks` `peer_server.go:1764` into the blockchain service's `LocateBlockHeaders` (`peer_server.go:1779`; `services/blockchain/Client.go:2216`) | TRANSLATED | whenever the located list is empty (nothing past the locator, or a lookup error, which is only logged at `peer_server.go:1780–1782`), the bridge sends an empty `notfound` (`peer_server.go:1798`, `:1809–1823`), where the reference sends nothing |
| 8 | `getheaders` | `ProcessGetHeadersMessage` `net_processing.cpp:2978` | `OnGetHeaders` `peer_server.go:1828` into `GetBlockHeadersFromCommonAncestor` (`peer_server.go:1861`; `services/blockchain/Client.go:924`) | TRANSLATED | the bridge does not pass the stop hash (`peer_server.go:1861`), where the reference stops at it (`net_processing.cpp:3001–3002`, `:3034`); it sends nothing for an empty answer (`peer_server.go:1891–1893`) where the reference sends an empty `headers` (`net_processing.cpp:3056`); it ignores the request while the sync manager is in `headersFirstMode` (`peer_server.go:1839–1842`) and omits genesis on regtest (`peer_server.go:1877–1881`) |
| 9 | `gethdrsen` | `ProcessGetHeadersEnrichedMessage` `net_processing.cpp:3225` | none: no go-wire command (`go-wire@v1.2.11/message.go:56–91`) | DROPPED | read-error road (§0); unreachable from an SV-node peer, which sends it only as a client |
| 10 | `tx` | `ProcessTxMessage` `net_processing.cpp:3351`; a rejection answered by `CreateTxRejectMsgForP2PTxn` `src/validation.cpp:1934–1952` | `OnTx` `peer_server.go:1077`, `QueueTx` `manager.go:3096`, `handleTxMsg` `manager.go:1271` into the validator's `Validate` (`manager.go:1320`; `services/validator/Client.go:340`, `services/validator/Validator.go:608`) | TRANSLATED | validated at block height 0, which the validator reads as the UTXO store's height (`manager.go:1319`); `ErrTxMissingParent`, `ErrTxLocked` and `ErrTxCreating` park it as an orphan (`manager.go:1335–1356`); every other error is answered `reject` with code `0x10` and the reason `rejected` (`manager.go:1368`), where the reference sends the validation's own code and reason (`validation.cpp:1940–1950`); an accepted transaction and the orphans it frees are announced (`manager.go:1385`, `:1390`) |
| 11 | `headers` | `ProcessHeadersMessage` `net_processing.cpp:3413` | `OnHeaders` `peer_server.go:1670`, `QueueHeaders` `manager.go:3452`, `handleHeadersMsg` `manager.go:2470` | TRANSLATED | only in the sync manager's `headersFirstMode` toward a checkpoint; any other `headers` disconnects the peer as unrequested (`manager.go:2493–2498`); the reference takes unsolicited announcements (`net_processing.cpp:3413`); reachable only if the bridge sent `sendheaders`, which it never does (no `sendheaders` message is built anywhere in Teranode's Go sources at the tag), so an SV-node peer announces blocks to it by `inv` |
| 12 | `hdrsen` | no inbound case: `net_processing.cpp:4874–4878` (sent only, `:3340`, `:5500`) | none: no go-wire command | DROPPED | the reference ignores it, the bridge disconnects (§0); unreachable from an SV-node peer, which sends it only after `gethdrsen` or `sendhdrsen` |
| 13 | `block` | `ProcessBlockMessage` `net_processing.cpp:4050` | `OnBlock` `peer_server.go:1109`, `QueueBlock` `manager.go:3111`, `handleBlockMsg` `manager.go:1726`, `HandleBlockDirect` `services/legacy/netsync/handle_block.go:52` into subtrees (`handle_block.go:389`; `CheckSubtreeFromBlock` `handle_block.go:746`, `services/subtreevalidation/Client.go:137`) and the block validation service's `ProcessBlock` (`handle_block.go:348`; `services/blockvalidation/Client.go:167`, `services/blockvalidation/Server.go:1467`) | TRANSLATED | the block's transactions are validated with policy checks skipped (`handle_block.go:1612`); a failure is answered `reject` code `0x10` `block rejected` unless the node is catching up or the error is local (`manager.go:2098–2101`); the payload checksum is not checked on this road (`services/legacy/peer/wire_streaming.go:11–25`, registered `services/legacy/Server.go:384–393`); the largest block the bridge reads is 4,000,000,000 bytes, a compile-time constant of the bridge, not a setting (`services/legacy/config.go:29`, `:45`, handed to go-wire at `services/legacy/Server.go:383`; `go-wire@v1.2.11/msg_block.go:34–36`, `:249–254`); the setting `settings.Policy.ExcessiveBlockSize` only lowers the advertised size (`services/legacy/config.go:145–151`); the blocks it serves go out as a raw message bounded by its own length (`services/legacy/raw_block_message.go:57`, `services/legacy/peer_server.go:2275`); the reference's `-excessiveblocksize` is a mandatory consensus input with no launch default (`src/bitcoind.cpp:140–157`; `docs/PARAMETERS.md` §8, consensus, node-configurable) |
| 14 | `getaddr` | `ProcessGetAddrMessage` `net_processing.cpp:4122` | `OnGetAddr` `peer_server.go:1993` | SAME | answered once per connection, inbound peers only (`peer_server.go:1999–2012`) |
| 15 | `mempool` | `ProcessMempoolMessage` `net_processing.cpp:4158` | `OnMemPool` `peer_server.go:1063` | DROPPED | the bridge always disconnects (`peer_server.go:1070`); at the defaults (`-rejectmempoolrequest` true, `src/validation.h:75`) both disconnect a plain request from a non-whitelisted peer (`net_processing.cpp:4170–4175`); the rows differ on a whitelisted peer and on the extended request, which the reference ignores from a peer it does not sync with (`:4194–4200`) and the bridge disconnects; the reference disconnects the plain request under its own conditions (`net_processing.cpp:4167–4193`) and handles the extended, aged request from a configured sync peer, ignoring it from any other without a disconnect (`:4194–4200`) |
| 16 | `ping` | `ProcessPingMessage` `net_processing.cpp:4212` | `handlePingMsg` `services/legacy/peer/peer.go:1169` | SAME | `pong` above protocol 60000 (`services/legacy/peer/peer.go:1173–1175`) |
| 17 | `pong` | `ProcessPongMessage` `net_processing.cpp:4241` | `handlePongMsg` `services/legacy/peer/peer.go:1183` | SAME | |
| 18 | `notfound` | ignored, `net_processing.cpp:4870–4873` | `OnNotFound` `peer_server.go:2091`, logged | SAME | |
| 19 | `filterload` | `ProcessFilterLoadMessage` `net_processing.cpp:4317`, behind the bloom gate `:4705–4714` | `OnFilterLoad` `peer_server.go:1986` | DROPPED | both refuse at their defaults: the reference advertises no bloom service unless `-peerbloomfilters` (`src/net/net_processing.h:21`) and scores 100 at protocol 70011 or later (`net_processing.cpp:4706–4709`); the bridge clears the bloom bit (`peer_server.go:3803`) and disconnects without a score (`peer_server.go:1987`) |
| 20 | `filteradd` | `ProcessFilterAddMessage` `net_processing.cpp:4336`, behind the bloom gate `:4705–4714` | `OnFilterAdd` `peer_server.go:1969` | DROPPED | as row 19 |
| 21 | `filterclear` | `ProcessFilterClearMessage` `net_processing.cpp:4356` | `OnFilterClear` `peer_server.go:1977` | DROPPED | the reference accepts it outside the bloom gate and turns transaction relay back on (`net_processing.cpp:4356–4362`); the bridge disconnects (`peer_server.go:1978`); unreachable from an SV-node peer |
| 22 | `reject` | `ProcessRejectMessage` `net_processing.cpp:1485` | `OnReject` `peer_server.go:2082`, logged | DROPPED | the reference's one effect, backing off block requests to a peer that answers `REJECT_TOOBUSY` (`net_processing.cpp:1508–1511`), is absent; reachable: the reference sends it when its send queues are full (`net_processing.cpp:1057–1070`) |
| 23 | `sendheaders` | `ProcessSendHeadersMessage` `net_processing.cpp:2383` | the typed switch `services/legacy/peer/peer.go:2107–2114`, then block relay by `headers` (`peer_server.go:2686–2690`, `:2773`) | SAME | reachable: the reference sends it on every `verack` at protocol 70012 or later (`net_processing.cpp:1963–1969`) |
| 24 | `sendhdrsen` | `ProcessSendHdrsEnMessage` `net_processing.cpp:2404` | none: no go-wire command | DROPPED | read-error road; unreachable from an SV-node peer at the pins, which sends it only as a client |
| 25 | `feefilter` | `ProcessFeeFilterMessage` `net_processing.cpp:4368` | `OnFeeFilter` `peer_server.go:1949`, applied in `handleRelayTxMsg` `peer_server.go:2728` | SAME | except that a transaction accepted through row 10 is announced with no size (`manager.go:1375–1378`), so its rate stays at the maximum (`peer_server.go:2736–2751`) and the filter never withholds it (`:2755`); reachable: the reference sends `feefilter` (`net_processing.cpp:5882`) |
| 26 | `sendcmpct` | `ProcessSendCompactMessage` `net_processing.cpp:2428` | decoded (`go-wire@v1.2.11/message.go:220–221`), no case: `services/legacy/peer/peer.go:2129–2130` | DROPPED | reachable: the reference sends it on every `verack` at protocol 70014 or later (`net_processing.cpp:1971–1981`); the bridge never offers compact blocks, so the reference never asks it for one (`net_processing.cpp:3601–3607`) |
| 27 | `cmpctblock` | `ProcessCompactBlockMessage` `net_processing.cpp:3744` | none: no go-wire command | DROPPED | read-error road; unreachable from an SV-node peer, since the bridge never sends `sendcmpct` |
| 28 | `getblocktxn` | `ProcessGetBlockTxnMessage` `net_processing.cpp:2790` | none: no go-wire command | DROPPED | read-error road; unreachable from an SV-node peer, which asks it only of a compact-block source (`net_processing.cpp:3935`) |
| 29 | `blocktxn` | `ProcessBlockTxnMessage` `net_processing.cpp:3623` | none: no go-wire command | DROPPED | read-error road; unreachable from an SV-node peer, which sends it only after `getblocktxn` (`net_processing.cpp:2778`) |
| 30 | `protoconf` | `ProcessProtoconfMessage` `net_processing.cpp:4386` | `OnProtoconf` `peer_server.go:884` | SAME | stores the peer's largest receive payload and negotiates the block-priority stream policy (`peer_server.go:889–925`) |
| 31 | `createstrm` | `ProcessCreateStreamMessage` `net_processing.cpp:1526` | `negotiateInboundProtocol` `services/legacy/peer/peer.go:2730–2736`, `OnCreateStream` `peer_server.go:931` | SAME | when block priority is allowed; otherwise the bridge disconnects (`peer_server.go:937–941`) |
| 32 | `streamack` | `ProcessStreamAckMessage` `net_processing.cpp:1603` | `OnStreamAck` `peer_server.go:982`, logged | SAME | the bridge reads its own stream's `streamack` inline (`peer_server.go:1029–1040`) |
| 33 | `dsdetected` | `ProcessDoubleSpendMessage` `net_processing.cpp:4573` | none: no go-wire command | DROPPED | **reachable**: the reference relays every `dsdetected` it accepts to every other peer (`net_processing.cpp:4655–4663`), so a double-spend notification reaching an SV-node peer of the bridge ends that peer's connection to the bridge (§0) |
| 34 | `extmsg` | the header marker, never dispatched: written `src/protocol.cpp:221–227`, read `:256–266` | the marker is parsed `go-wire@v1.2.11/message.go:270–280` | DROPPED | see row 39 |
| 35 | `revokemid` | `ProcessRevokeMidMessage` `net_processing.cpp:4523` | none: no go-wire command | DROPPED | **reachable**: the reference relays an accepted `revokemid` to every other peer (`net_processing.cpp:4551–4558`) and the RPC `revokeminerid` pushes one to every peer (`src/rpc/miner_info.cpp:861–866`); the reference's own list of message types omits it (`src/protocol.cpp:107–121`, thirty-seven entries) though `src/protocol.h:419` declares it and `net_processing.cpp:4866` dispatches it |
| 36 | `authch` | `ProcessAuthChMessage` `net_processing.cpp:1989` (answered by `authresp`, `:2133`) | `handleAuthChMsg` `services/legacy/peer/peer.go:1211` (case `services/legacy/peer/peer.go:2116–2117`) | DROPPED | the bridge checks the version and the challenge and sends no `authresp` (`services/legacy/peer/peer.go:1231–1234`); reachable: the reference sends `authch` on every `verack` (`net_processing.cpp:1957–1958`) |
| 37 | `authresp` | `ProcessAuthRespMessage` `net_processing.cpp:2150` | decoded (`go-wire@v1.2.11/message.go:217–218`), no case: `services/legacy/peer/peer.go:2129–2130` | DROPPED | unreachable from an SV-node peer: the bridge never sends `authch` (no `authch` message is built anywhere in Teranode's Go sources at the tag) |
| 38 | `datareftx` | no inbound case: `net_processing.cpp:4874–4878` (sent only, `:1431–1440`) | none: no go-wire command | DROPPED | the reference ignores it, the bridge disconnects; unreachable from an SV-node peer, which sends it only for a dataref `getdata` the bridge never makes |
| 39 | the extended header | `CExtendedMessageHeader` `src/protocol.h:93`; written for a payload above `2^32 − 1` bytes (`src/protocol.cpp:221–227`), read `:256–266`, checksum skipped `net_processing.cpp:5055` | read: `readMessageHeader` `go-wire@v1.2.11/message.go:246`; write: `WriteMessageWithEncodingN` `go-wire@v1.2.11/message.go:329` | DROPPED | read: the header reader takes 24 bytes (`go-wire@v1.2.11/message.go:23`, `:253`) and reads the extended command and length from that already-consumed buffer (`:270–280`), so both come back empty and the message takes the read-error road; go-wire's own test names the limitation (`go-wire@v1.2.11/message_streaming_test.go:243–245`); write: a payload above `2^32 − 1` bytes returns before any byte is written, with the encode step's error value, nil after a successful encode (`go-wire@v1.2.11/message.go:385–386`), and no write path emits the extended fields (`:404`); the reference uses the header only above `2^32 − 1` bytes, above the bridge's read bound of row 13, so no block above 4,000,000,000 bytes enters through the bridge and none above `2^32 − 1` bytes leaves it |

**The count** `[M]`: 39 rows; SAME 13 (rows 1, 2, 3, 6, 14, 16, 17, 18, 23, 25, 30, 31, 32; rows 6 and 18 are
both-ignore); TRANSLATED 7 (rows 4, 5, 7, 8, 10, 11, 13); DROPPED 19 (rows 9, 12, 15, 19, 20, 21, 22, 24, 26, 27, 28, 29, 33,
34, 35, 36, 37, 38, 39). Of the DROPPED rows, five are reachable from an SV-node peer at the pins with the defaults
cited: 22 (`reject`'s back-off), 26 (`sendcmpct`, ignored), 33 (`dsdetected`, the connection ends), 35
(`revokemid`, the connection ends) and 36 (`authch`, unanswered).

## 2. What the bridge does that the reference does not

| # | behavior | where `[SRC]` | the reference at the same point `[SRC]` | note `[D]` |
|---|---|---|---|---|
| B1 | an undecodable or unknown command ends the connection with a `reject` `malformed` | `services/legacy/peer/peer.go:1952–1954` | ignored, `net_processing.cpp:4874–4878` | the source of every codec row of §1 and of B13 |
| B2 | the regtest loopback exception: the same message error is logged and skipped when the network is regtest and the peer's host is exactly `127.0.0.1` or `localhost` | `services/legacy/peer/peer.go:1367–1390`, `:1930–1934` | none | after a skipped error the stream may be misaligned (`go-wire@v1.2.11/message.go:614–619` discards the declared length); §4 (e) |
| B3 | the user-agent gate: reject and ban a peer whose agent lacks `Bitcoin SV` or `BSV` | `peer_server.go:762–764`, `:802–814`; the feeler applies the same test (`services/legacy/feeler.go:633`, `:762`) | none | a policy of the bridge, not a protocol rule |
| B4 | transaction `inv` entries pass through a Kafka topic and act only while the FSM is RUNNING | `manager.go:3403–3445`, `:2812–2816` | acted on at once, `net_processing.cpp:2454` | an `inv` received while catching up is not acted on later |
| B5 | transactions accepted by any Teranode service are announced to legacy peers from the txmeta topic, those carried in a block or subtree excluded, batched each second | `manager.go:3955`, `:3985`, `:4079–4087`, `:3662–3667` | the reference announces what its own validation accepts | the bridge's outbound relay is not tied to its inbound road |
| B6 | blocks announced from the blocks-final topic | `manager.go:3908`, `:3940` | `net_processing.cpp:5429–5500` (announcement by `headers`, `hdrsen` or `inv`) | |
| B7 | the rebroadcast queue: pending transaction `inv` entries replayed after each block until mined, conflicting, absent or aged out | `services/legacy/rebroadcast.go:356`, `:391`, `:494`, `:239` | none in the node | |
| B8 | the orphan pool admits on `ErrTxLocked` and `ErrTxCreating` as well as a missing parent; it evicts after a set duration with one last `Validate`, whose success this path does not announce | `manager.go:1335`, `:3615`, `:3674–3686` | `src/orphan_txns.cpp` (DESIGN-S6 §1.2) | an accepted evictee reaches peers only through B5 |
| B9 | when a freed orphan fails with `ErrTxConflicting`, the delete removes the parent's key, not the orphan's | `manager.go:1398`, `:1419–1422` (the parameter `txHash` is the parent) | | `[D]` reading: the conflicting orphan stays until B8's eviction; a witness is owed (§4 S4) |
| B10 | every transaction rejection carries code `0x10` and the reason `rejected`; every block rejection `0x10` and `block rejected` | `manager.go:1368`, `:2100` | the validation's own code and reason, `validation.cpp:1934–1952`; the block's, `net_processing.cpp:4894–4899` | a client reading reject codes from the bridge learns nothing from the code |
| B11 | the rejected-transaction filter is cleared at each block | `manager.go:2181` | | |
| B12 | `getdata` for a transaction is served from the UTXO store, mined transactions included | `peer_server.go:2180` | relay map, or mempool after `mempool` (`net_processing.cpp:1391–1428`) | |
| B13 | the go-wire-only commands: `exttx` decoded and dropped; `getcfilters`, `getcfheaders` and `getcfcheckpt` disconnect; `cfilter`, `cfheaders` and `cfcheckpt` decoded and dropped | `go-wire@v1.2.11/message.go:66`, `:79–84`; `peer_server.go:1897–1909`; `services/legacy/peer/peer.go:2129–2130` | unknown commands, ignored | none of the seven is a reference command |
| B14 | the block payload checksum is not checked on the streaming road | `wire_streaming.go:11–25`, `services/legacy/Server.go:384–393` | checked unless extended, `net_processing.cpp:5055–5075` | integrity rests on the downstream block checks (the bridge's own comment, `wire_streaming.go:16–25`) |
| B15 | the legacy block bound of 4,000,000,000 bytes on read | `services/legacy/config.go:38–45`, `:136–151`, `services/legacy/Server.go:383` | `-excessiveblocksize`, a mandatory consensus input with no launch default, `src/bitcoind.cpp:140–157` (`docs/PARAMETERS.md` §8) | a constant of the bridge's code below the reference's consensus setting: a block the reference's operator admits above 4,000,000,000 bytes cannot reach Teranode through the bridge |
| B16 | the bridge's peers are mirrored into the p2p service's registry | `services/legacy/peer_registry_sync.go:108`, `:131` | none | |

## 3. The theorem of #98 as sketched before #78's machine existed

`[D]` The sketch of 2026-10-14, kept as the reading half wrote it; its names were placeholders for #78's and #88's.
The theorem as proven is §6: it relates the bridge to #78's relay machine (`Wire.Node`) through explicit
correspondences rather than through #88's `Refines`, and the reject and the fee filter of the paragraph that closes this section are
stated there as model witnesses of named divergences.

**The statement.** For every bridge state `σT`, machine state `σM`, peer `p` and transaction `t`: if `σT` refines
`σM` under #88's relation (`Refines σT σM`), the parameters the bridge's services read project onto the machine's
named parameters (`ParamsAgree`, from #59's census: Teranode's defaults as the second oracle's, never the rule,
DESIGN-S6 §5.2), and the bridge accepts `t` from `p` (`BridgeAccepts σT p t`: `handleTxMsg` reached
`manager.go:1385` with `Validate` returning no error at `manager.go:1320`), then the machine, receiving `tx t` from
`p` in `σM`, reaches a state in which `t` is accepted and queued for announcement to every peer other than `p`
whose relay is on. Placeholder names only, no Lean exists: `theorem bridge_accept_relayed (hR : Refines σT σM) (hP : ParamsAgree σT σM)
(hS : ScriptOracleAgrees) (hA : BridgeAccepts σT p t) : t ∈ (Machine.recv σM p (.tx t)).relayQueue`. The orphan
road is the same statement applied to each transaction `processOrphanTransactions` frees, by induction on the
order it frees them (`manager.go:1390–1444`).

**Its hypotheses are the TRANSLATED rows.** Row 10 is the heart of it: `Validate` at height 0 read as the store's
height (`manager.go:1319`) must refine the machine's acceptance at the tip plus one, and the three orphan errors
of `manager.go:1335` must refine the machine's orphan pool (DESIGN-S6 §2.1). Row 4 supplies the known-inventory
relation (`haveInventory`, `manager.go:2619–2650`), rows 5, 7 and 8 the read side, rows 11 and 13 the chain the
height refers to. `ScriptOracleAgrees` is the script verdict through GoBDK equal to the spec's evaluator at the
pins (#76; DESIGN-S6 §4.3).

**What it cannot state, and why** `[D]`. The reject's code and reason (B10 flattens them, so no theorem relates the
bridge's reject to the machine's). Relay to a peer with a fee filter: the bridge announces a row-10 transaction
regardless of the peer's filter (row 25), where the machine would withhold it below the rate, so the conclusion is
"queued for announcement", with the filter a separate obligation or the statement scoped to peers with no filter.
Relay itself is outside the accept road (B5, B7), so "relayed" in the issue's sentence is read as "queued", the
machine's state, never the bytes on a socket. The DROPPED rows enter no theorem: a message the bridge cannot decode
is a disconnect, which the machine models as the end of the peer, not as a step.

## 4. What the mixed two-node scenario needs from #66's runner

`[D]` The scenario is #78's harness with one node a Teranode; the runner of #66 is its home. What it needs:

- **(a) Both nodes, never a standing one.** The Teranode instance of #41 driven on the box (#66's cut 2, #74); a
  fresh SV-node regtest instance on the runner's reserved pairs 18571 to 18590 (`harness/src/scenarios/core.rs:406`),
  stopped at the end. The Teranode instance runs with the legacy service ON, listening on a loopback address the
  SV-node instance can dial, which the instance of #41 does not run today (`docs/PROVENANCE.md` §1a, the instance's
  host row: legacy off; `harness/engines/instance41/instance.py:45` passes `-legacy=0`); its recipe in
  `harness/engines/instance41/instance.py` gains the switch as a second recipe, the bridge's listener on the loopback
  only, and the run's record names it.
- **(b) A connection step with its direction recorded.** The bridge treats inbound and outbound peers differently
  (`peer_server.go:789–791`, `:822–845`, `:1999–2003`), so each scenario names who dialed.
- **(c) Observation on both sides.** SV-node's `getpeerinfo` (the runner's table cites `src/rpc/net.cpp:69-280`) and
  its `debug=netmsg` log (already in the runner's configuration, `harness/src/scenarios/peer.rs:151`) for the
  messages the bridge sends; the bridge's peer gRPC (`services/legacy/peer_api/peer_api.proto`) and #97's
  observation contract for its side; the transaction's status by #74's mapping onto DESIGN-S6 §3.
- **(d) The raw speaker pointed at the bridge.** `harness/peer/peer.py` through the reference's framework
  (`harness/src/scenarios/peer.rs:1–60`) must be able to send any of the thirty-eight commands, including the nine the
  codec lacks, and a header with the extended marker.
- **(e) A loopback address other than `127.0.0.1`.** The runner connects from `127.0.0.1` (`peer.rs:53`) and the
  SV-node binds there (`peer.rs:151`); on regtest that host turns every DROPPED codec row into a logged skip (B2), so
  the disconnect is unobservable. Each codec row is therefore a two-cell witness: from `127.0.0.1` (skipped) and from
  another loopback address such as `127.0.0.2` (disconnected). On the box's Linux the whole `127.0.0.0/8` is the
  loopback interface `[LIT]` (RFC 1122 §3.2.1.3 (g); RFC 6890 Table 4, `127.0.0.0/8`, loopback); it stays inside rule 10.
- **(f) The scenarios, at least these seven.** S1 a transaction submitted to SV-node by RPC reaches the bridge,
  `Validate` accepts it, Teranode's status moves (rows 4, 5, 10). S2 a transaction submitted to Teranode's
  propagation service reaches SV-node's mempool through B5 and row 5. S3 a child then its parent across the bridge
  (row 10's orphan road). S4 a conflicting orphan freed by its parent (B9's witness). S5 a rejected transaction: the
  code `0x10` `rejected` recorded on SV-node's log (B10). S6 a `dsdetected` from the raw speaker to SV-node, relayed
  to the bridge, ending the connection (row 33), the two cells of (e). S7 a block each way: SV-node's by `inv`,
  `getdata`, `block` into `ProcessBlock` (row 13); Teranode's by the blocks-final topic and `headers` (B6, row 23).
- **(g) The spec column.** #78's machine exists (`lean/BsvChain/Wire/Relay.lean`) and the theorem is §6; the scenario
  measures the two nodes against each other and against this page, and §6's correspondences against S1 to S3 (§6's
  list of the rows the theorem leaves to the harness).

## 5. The reads

`[M]` 2026-10-14, on the Studio:

- Teranode at `4edb60a4` and bitcoin-sv at `6504a3af`, by `git show <commit>:<path>` from the local clones, never a
  working tree.
- go-wire `v1.2.11`: `https://proxy.golang.org/github.com/bsv-blockchain/go-wire/@v/v1.2.11.zip` at 21:24:34Z, and
  `go mod download -json github.com/bsv-blockchain/go-wire@v1.2.11` at 21:24:42Z into a scratch module cache outside
  the tree, which checked the sum database and reported `h1:jVbatioBZ21ebK7rrt9IY768VPVTMpk0KSPC2fm0lS0=`, equal to
  Teranode's `go.sum:146`. Public reads only; nothing was sent but the requests. The command's JSON and the scratch
  cache were not kept, so no record file stands for this read; the record and its booking in `docs/PROVENANCE.md` §6
  are left to the §1a row for `github.com/bsv-blockchain/go-wire` `v1.2.11` (§0's Finding), and the sixteen
  go-wire citations stay `absent` in the cite leg until that clone is pinned.

## 6. The theorem half (2026-10-18)

[M] 2026-10-18, read under the maintainers' framing rule of
2026-10-18 01:4xZ: Teranode reaches BSV's scale without a protocol change by an architecture of services (no
traditional mempool, the UTXO store as a transaction's one memory, subtrees, Kafka, the legacy service as the
compatibility edge), so a message the bridge translates or drops is an architecture decision with Teranode's reason
cited, and only a transaction or block the two nodes decide differently would be a finding. The module is
`lean/BsvChain/Teranode/Bridge.lean`; every theorem below is sorry-free and within Lean's three axioms `[X]`
(record `docs/records/20261018-021011-s8-98-bridge-theorem-s1.md`).

**The mapping** `[X]`. `bridge : Message → Handling` is §1's table, one constructor per row: `Message` is #78's 38
commands (`Wire.Command`) and the extended header; `Handling` is `same` (13 constructors of `Same`), `translated`
(7 of `Translation`, each naming the Teranode service: `invThroughKafka`, `getdataFromStore`, `getblocksLocate`,
`getheadersFromAncestor`, `txToValidator`, `headersToCheckpoint`, `blockToSubtrees`) or `dropped` (19 of
`DropReason`). Each constructor's docstring cites both handlers at the pins and, for a translated or dropped row,
Teranode's reason. `bridge_counts` proves §1's count (13, 7, 19), `bridge_rows_distinct` that no two rows share a
handling, `Message.all_length` the 39 rows, `reachable_drops` §1's five reachable drops. The module's go-wire
citations (`go-wire@v1.2.11/message.go:56-91`, `:220-221`, `:253`, `:270-280`, `msg_block.go:249-254`) were read in
the Go module cache at `v1.2.11`, the version `go.mod:205` requires, on 2026-10-18 `[X]`; the §1a
row for go-wire stays owed (§0).

**What is proven** `[X]`.

- **The transaction road** (row 10). `handleTx` is `handleTxMsg` (`manager.go:1271-1386`): the rejected map, then
  the validator's answer. The machine's relay predicate is `Relays`: after `Node.recvTx` the transaction is in the
  pool and in the propagator's queue (`RelayTransaction`, `net_processing.cpp:975-997`). **`bridge_accept_relayed`**:
  a transaction the bridge accepts from a peer, the validator's answer corresponding to the mempool machine's verdict
  (`VerdictAgrees`: no error is `accepted`, a missing parent `missingInputs`, any other error `invalid`), new to the
  machine, the peer present and not under blocks-only, not a miner-info data transaction, is one #78's machine
  relays. `bridge_accept_reaches_peers`: the propagator's next pass queues it for every other peer that relays
  transactions, passes its filters and is not known to have it. `bridge_tx_refines` is the total form: every acceptance
  by the bridge is a relay of the machine, or the machine already knows the transaction (its pool, its recent rejects
  or its orphans, `Node.knows`) and its queue stands; the pool case is the named divergence `resubmitReannounced`,
  the other two are states the two memories reach apart, measured by the measured half's rows below.
- **The orphan road** (row 10, `processOrphanTransactions` `manager.go:1390`). `bridge_orphan_relayed` and
  `bridge_orphan_reaches_peers`: an orphan the bridge accepts when its parent arrives, held by the machine, is relayed
  by the machine's retry.
- **The inventory road** (row 4). `bridge_inv_requests`: an entry the bridge requests (RUNNING, the store not having
  it), with RUNNING standing for the machine's download latch off and the store's "have it" for the machine's
  inventory test, is asked for by the machine (`AskFor`).
- **The reject map.** `bridge_rejected_ignored`: an id in both rejected memories is ignored by the bridge with no
  reject and relayed by neither.
- **The block road** (row 13). `bridgeBlockAccepts` is `handleBlockMsg` (`manager.go:1726`): requested or regtest,
  within the read bound, then Teranode's `ProcessBlock`. `bridge_block_filter`: the bridge adds no block acceptance
  of its own. **`bridge_block_accepted`**: under the block verdict's correspondence (`BlockVerdictAgrees`: #88's owed
  `block-check` and `block-connect` rows, a hypothesis, never asserted), a block the bridge accepts is one the
  reference accepts, or its checksum failed (`checksumSkipped`).

**The divergences** `[X]` the constructors, `[D]` their class (`BridgeDivergence`, 16 constructors, every one `design`, labeled policy: none decides a
transaction or a block differently; each changes what is heard, when or by whom). On row 10: `resubmitReannounced`
(the validator's idempotent success on a stored transaction, `Validator.go:1106-1117`; `bridge_known_accept_diverges`),
`parkOnInFlightParent` (`ErrTxLocked` and `ErrTxCreating` park a child whose parent is mid-commit across records,
`manager.go:1331-1335`; no verdict corresponds), `rejectFlattened` (0x10 `rejected`, B10; `bridge_reject_flattened`
and its witness), `invalidOrphanKept` (B8, B9; `bridge_orphan_invalid_kept`). On row 25: `feeFilterBypassed`
(`bridge_announce_passes_fee_filter`, `fee_filter_withholds_witness`). On row 4: `invGatedByFsm`. On row 5:
`getdataFromStore`. On row 11: `headersUnsolicitedDropped`. On row 13: `unrequestedBlockDropped`
(`bridge_block_unrequested`), `blockReadBound` (`bridge_block_bound`), `checksumSkipped` (`bridge_block_accepted`).
On the five reachable drops: `rejectBackoffAbsent` (22), `compactBlocksDeclined` (26), `dsdetectedDisconnects` (33),
`revokemidDisconnects` (35), `authchUnanswered` (36). `BridgeDivergence.rows_classed` proves each sits on a
TRANSLATED row, on row 25 or on a reachable DROPPED row.

**The obligation list** `[X]` (`corpus/teranode/obligations.json`, section 5 of `spec/node-client-contract.md`):
`tx-relay` and `reject-filter` are theorem rows, each with model witnesses of its divergences and the bridge's
measured half owed; `orphans` stays a design row with `bridge_orphan_relayed`, `bridge_orphan_reaches_peers`
and `bridge_orphan_invalid_kept` as its support; `wire-block` is a design row since 2026-10-18 (its
horizon measured below), naming the block road (`bridgeBlockAccepts`, `BlockVerdictAgrees`,
`bridge_block_accepted`) as its support, its horizon as its owed half. The list: 54 rows, 11 theorem (5 also
carrying model witnesses), 1 witness, 18 design, 1 chain-split, 10 report, 13 open (the Lean side 9, the harness side 4); 6 owed
halves (the Lean side 2, the harness side 4).

**The measured half, owed to the mixed two-node scenario** `[D]`. The theorems take the correspondences as
hypotheses; §4's scenario measures them. The rows it must run, by the theorem each one checks:

- `VerdictAgrees` on the accept road: §4 S1 (a transaction from SV-node accepted by `Validate`, Teranode's status
  moving) and S2 (one from Teranode reaching SV-node's mempool).
- The orphan road: S3 (a child then its parent); a child of a parent mid-commit (`parkOnInFlightParent`), if the
  instance can be made to show it; S4 (a conflicting orphan, `invalidOrphanKept`, B9's witness).
- The reject: S5 (0x10 `rejected` on SV-node's log, `rejectFlattened`); a rejected transaction resent before and
  after a block (the bridge's clear at each block, the reference's reset at a tip change, `bridge_rejected_ignored`).
- The resubmit: the same transaction sent twice through the bridge, another announcement observed on SV-node's
  `debug=netmsg` log (`resubmitReannounced`).
- The fee filter: an SV-node peer whose `feefilter` is above a transaction's rate, the bridge's announcement observed
  (`feeFilterBypassed`).
- The inventory gate: a transaction `inv` while Teranode's FSM is not RUNNING, no `getdata` then or after
  (`invGatedByFsm`).
- The block road: S7 (a block each way); a block with a wrong payload checksum from the raw speaker, accepted through
  the bridge and dropped by SV-node (`checksumSkipped`). `unrequestedBlockDropped` is unobservable on regtest, where
  the bridge keeps unrequested blocks (`manager.go:1796-1801`), and `blockReadBound` needs a block above
  4,000,000,000 bytes: both stay model rows, named, never run.
- The reachable drops: S6 (`dsdetected`, the two cells of §4 (e)), a `revokemid` from the raw speaker, `authch`
  unanswered on SV-node's peer view, `sendcmpct` ignored; `rejectBackoffAbsent` needs SV-node's send queues full and
  is named, not owed to the scenario.

`[M]` 2026-10-18: the measured half is run, 39 rows, agree 30, differ 7, not run 2; the transaction
rows (a) agree, the block rows (b) differ at the wrong-checksum cell (the honest road agrees), the double-spend
resolve (f) agrees; the counts, the verdict and every cell are in
[the record](records/20261018-063439-s4b-98-teranode-bridge-s4b.md) (withheld, `tools/export_withheld.txt`, group
`hz-98-teranode-bridge`).

`[M]` 2026-10-18: the horizon re-measured, the lens's two confounds removed by construction (the
chain built at wall-clock times so the reference's direct-fetch gate, `net_processing.cpp:308-313` at the pin, is
open, verified by arithmetic and rehearsed live: a good block pushed to the bridge only, fetched unaided; the
mining the reference's own `generatetoaddress` on a synthetic payout, no keys; no operator step on either node
after the frame, the journal's audit). The same wrong-checksum block bytes to both nodes: the reference drops them
(its `CHECKSUM ERROR` line), the bridge takes them and announces; the tips re-agree unaided inside one announce
round, the same second (the bridge's announce, the reference's open gate answering getdata, the bridge's serve, the
reference's connect: its `Requesting block` and `UpdateTip` lines), the reorg road never firing; then 8 blocks
mined at a 20 s cadence on the healed tip and a 180 s quiet watch (36 reads), both tips one at the end (the same
hash at height 124, one active chain each). The cell stays a differ at the message level (the list above keeps its
history), but the split heals itself unaided: `wire-block` moves from an open row to a design row, its reason read
from Teranode's bridge source at the pin (`wire_streaming.go:11-25`, `checksumSkipped`, the divergence constructor
of `bridge_block_accepted`) and the reference's side at its pin ([SRC] bitcoin-sv `6504a3af`
`src/net/net_processing.cpp:5053-5059`, the checksum check and its drop). The counts, the verdict and every call are in
[the record](records/20261018-145427-s8-98-teranode-bridge-horizon2-s4b.md) (withheld, `tools/export_withheld.txt`,
group `hz-98-teranode-bridge`); the lens's correction stands, its two confounds what this run removed.
