import BsvChain.Properties.Relay

/-!
# Teranode's legacy bridge as a refinement of the protocol machine (#98, the theorem half)

[M] 2026-10-18 (#98). The reading half (`docs/CONFORMANCE-TERANODE-BRIDGE.md`,
2026-10-14) classed every wire message type of the reference, 39 rows: SAME 13, TRANSLATED 7, DROPPED 19. This
module states that table as a function (`bridge`, one constructor per row) and proves what Teranode accepts through
the bridge is what #78's protocol machine (`BsvChain.Wire.Node`, `lean/BsvChain/Wire/Relay.lean`) would have
relayed, under named correspondences, with every place the two part named as a `BridgeDivergence`.

**The north star it is read under** (the maintainers' framing rule of 2026-10-18 01:4xZ, the rule of card Z8 carried to
the bridge). Teranode reaches BSV's scale without a protocol change by an architecture of services: no
traditional mempool (`docs/topics/architecture/teranode-overall-system-design.md:174` at `4edb60a4` [LIT]), the
UTXO store as the one memory of a transaction, subtrees as the unit of block work, Kafka between the services, and
the legacy service (`services/legacy/`) as the compatibility edge that speaks the reference's wire protocol to the
existing network. A message the bridge translates or drops is an architecture decision for scale, written with
Teranode's reason; only a transaction or block the two nodes decide differently would be a finding. No
`BridgeDivergence` below is such a finding: each changes what is heard, when or by whom, never whether a
transaction or a block is valid (`BridgeDivergence.cls`, all `design`, labeled policy).

**The theorems.** The transaction road (`OnTx` `services/legacy/peer_server.go:1077`, `QueueTx`
`services/legacy/netsync/manager.go:3096`, `handleTxMsg` `manager.go:1271`, the validator's `Validate`
`manager.go:1320`) is `handleTx`; the machine's relay predicate is `Relays`: the transaction joins the machine's
pool and the propagator's queue (`Node.recvTx`'s accepted branch, `RelayTransaction`
`src/net/net_processing.cpp:975-997` at `6504a3af`). `bridge_accept_relayed`: a transaction the bridge accepts from
a peer, the validator's answer agreeing with the mempool machine's verdict (`VerdictAgrees`), new to the machine,
the peer present and not under blocks-only, not a miner-info data transaction, is one the machine relays; and
`bridge_accept_reaches_peers`: the propagator's next pass queues it for every other peer that relays transactions,
passes its filters and is not known to have it (from #78's `accepted_queued_for_unseen`). The orphan road
(`processOrphanTransactions` `manager.go:1390`) is `bridge_orphan_relayed`; the inventory road (`processInvMsg`
`manager.go:2809`) `bridge_inv_requests`. `bridge_tx_refines` is the total form: every acceptance by the bridge is
a relay of the machine, or the machine already knows the transaction (its pool, its recent rejects or its orphans,
`Node.knows`) and its queue stands; the pool case is the named divergence `resubmitReannounced`, the other two are
states the two memories reach apart, measured by #98's bridge rows. The block road (`handleBlockMsg` `manager.go:1726`,
`HandleBlockDirect` `services/legacy/netsync/handle_block.go:52`, the block validation service's `ProcessBlock`
`handle_block.go:348`) is `bridgeBlockAccepts`: `bridge_block_accepted` proves the bridge adds no block acceptance
of its own (a block it accepts is one Teranode's block validation accepts, within the read bound), and with the
block verdict's agreement (`BlockVerdictAgrees`, #88's owed `block-check` and `block-connect` rows, a hypothesis
here, never asserted) one the reference processes and accepts, or the named divergence `checksumSkipped`.

**What stays to the harness.** The theorems take the correspondences as hypotheses: the validator's answer
against the mempool machine's verdict (#88's `utxo-spend`, `script-word`), the bridge's "have it" against the
machine's inventory test, the FSM's RUNNING against the machine's download latch, the block verdict against the
reference's. The mixed two-node scenario (`docs/CONFORMANCE-TERANODE-BRIDGE.md` section 4) measures
them; each divergence's reachable cell is a scenario row there.

The reference is bitcoin-sv v1.2.3 at `6504a3aff65ba97c0f6c80962b033e35ecbfed4b`; the bridge is Teranode v0.16.0
at `4edb60a40c6628ff0ef60231c2628efd7103fde5` (`docs/PROVENANCE.md` §1a) [SRC]. Every citation below is at those
pins; the go-wire codec's are `go-wire@v1.2.11/<file>:<line>`, the version Teranode's `go.mod:205` requires, read in
the Go module cache (2026-10-18).
A view of the bridge, never a rule of validity.
-/

namespace BsvChain.Teranode.Bridge
open BsvChain.Wire BsvScript.Numbers

/-! ## 1. The message types: the reference's 38 commands and the extended header -/

/-- One row of the reading half's table: a command of `NetMsgType` (`src/protocol.cpp:16-53`, declared
`src/protocol.h:199-445`; #78's `Wire.Command`) or the extended header (`CExtendedMessageHeader`,
`src/protocol.h:93`). -/
inductive Message where
  | cmd (c : Command)
  | extendedHeader
  deriving DecidableEq, Repr

/-- The 39 rows in the table's order: the commands in `src/protocol.cpp:16-53`'s order, then the extended
header. -/
def Message.all : List Message := Command.all.map .cmd ++ [.extendedHeader]

/-- [M] 2026-10-18: the table has 39 rows. -/
theorem Message.all_length : Message.all.length = 39 := by decide

/-- [M] 2026-10-18: every message type is a row of the table. -/
theorem Message.mem_all (m : Message) : m ∈ Message.all := by
  cases m with
  | cmd c => cases c <;> decide
  | extendedHeader => decide

/-! ## 2. The bridge's handling, one constructor per row -/

/-- The SAME rows: the bridge answers as the reference does, or both ignore the message. -/
inductive Same where
  /-- Row 1. Reference `ProcessVersionMessage` (`src/net/net_processing.cpp:1670`); bridge
  `negotiateInboundProtocol` (`services/legacy/peer/peer.go:2722`), `handleVersionMsg` (`peer.go:2757`), `OnVersion`
  (`services/legacy/peer_server.go:769`). The bridge also rejects and bans an agent without `Bitcoin SV` or `BSV`
  (`peer_server.go:762-764`, `:802-814`, B3, a policy of the edge), floors at protocol 209 where the reference floors
  at 31800 (`src/version.h:17-20`), and disconnects a duplicate `version` (`peer.go:1991-1994`) where the reference
  rejects and scores 1 (`net_processing.cpp:1681-1683`). -/
  | version
  /-- Row 2. Reference `ProcessVerAckMessage` (`net_processing.cpp:1928`); bridge the typed switch (`peer.go:1996-2009`). -/
  | verack
  /-- Row 3. Reference `ProcessAddrMessage` (`net_processing.cpp:2280`); bridge `OnAddr` (`peer_server.go:2037`) into
  the address manager (`services/legacy/addrmgr/addrmanager.go`). -/
  | addr
  /-- Row 6. Inbound both ignore it: the reference's unknown-command branch (`net_processing.cpp:4874-4878`), the
  bridge's decoded case with no listener (`peer.go:2097-2100`; `peer_server.go:3121-3146`). -/
  | merkleblock
  /-- Row 14. Reference `ProcessGetAddrMessage` (`net_processing.cpp:4122`); bridge `OnGetAddr`
  (`peer_server.go:1993`), once per connection, inbound peers only (`:1999-2012`). -/
  | getaddr
  /-- Row 16. Reference `ProcessPingMessage` (`net_processing.cpp:4212`); bridge `handlePingMsg` (`peer.go:1169`). -/
  | ping
  /-- Row 17. Reference `ProcessPongMessage` (`net_processing.cpp:4241`); bridge `handlePongMsg` (`peer.go:1183`). -/
  | pong
  /-- Row 18. Both ignore it: the reference at `net_processing.cpp:4870-4873`, the bridge's `OnNotFound`
  (`peer_server.go:2091`) logs it. -/
  | notfound
  /-- Row 23. Reference `ProcessSendHeadersMessage` (`net_processing.cpp:2383`); bridge the typed switch
  (`peer.go:2107-2114`), then block relay by `headers` (`peer_server.go:2686-2690`, `:2773`). -/
  | sendheaders
  /-- Row 25. Reference `ProcessFeeFilterMessage` (`net_processing.cpp:4368`); bridge `OnFeeFilter`
  (`peer_server.go:1949`), applied in `handleRelayTxMsg` (`peer_server.go:2728`). A transaction accepted through
  row 10 is announced with no size, so the filter never withholds it: `BridgeDivergence.feeFilterBypassed`. -/
  | feefilter
  /-- Row 30. Reference `ProcessProtoconfMessage` (`net_processing.cpp:4386`); bridge `OnProtoconf`
  (`peer_server.go:884`, the stream policy `:889-925`). -/
  | protoconf
  /-- Row 31. Reference `ProcessCreateStreamMessage` (`net_processing.cpp:1526`); bridge `negotiateInboundProtocol`
  (`peer.go:2730-2736`), `OnCreateStream` (`peer_server.go:931`), when block priority is allowed (`:937-941`). -/
  | createstrm
  /-- Row 32. Reference `ProcessStreamAckMessage` (`net_processing.cpp:1603`); bridge `OnStreamAck`
  (`peer_server.go:982`), its own stream's read inline (`:1029-1040`). -/
  | streamack
  deriving DecidableEq, Repr

/-- The TRANSLATED rows: the bridge maps the message into a Teranode service call whose effect stands in for the
reference's handler. Each docstring names the service (Teranode's design: the edge hands the work to the service
that owns it). -/
inductive Translation where
  /-- Row 4, `inv`. Reference `ProcessInvMessage` (`net_processing.cpp:2454`); bridge `OnInv` (`peer_server.go:1624`),
  `QueueInv` (`manager.go:3396`), `handleInvMsg` (`manager.go:2654`), `processInvMsg` (`manager.go:2809`). The
  service: transaction entries through the Kafka inv topic and back (`manager.go:3403-3445`), acted on only while the
  blockchain service's FSM is RUNNING (`manager.go:2812-2816`); "have it" is the blockchain service's
  `GetBlockHeader` for a block (`manager.go:2623`) and the UTXO store's `Get` for a transaction (`manager.go:2635`).
  Teranode's reason: the services scale apart, so an announcement is a message on the bus, and the store is the one
  memory of a transaction (no mempool). `bridge_inv_requests`; `BridgeDivergence.invGatedByFsm`. -/
  | invThroughKafka
  /-- Row 5, `getdata`. Reference `ProcessGetDataMessage` (`net_processing.cpp:2537`, `ProcessGetData` `:1173`);
  bridge `OnGetData` (`peer_server.go:1680`), `pushTxMsg` (`:2167`), `pushBlockMsg` (`:2247`). The service: a
  transaction from the UTXO store's record, mined or not (`peer_server.go:2180`); a block from the node's asset
  service over HTTP (`peer_server.go:2254`). `BridgeDivergence.getdataFromStore`. -/
  | getdataFromStore
  /-- Row 7, `getblocks`. Reference `ProcessGetBlocksMessage` (`net_processing.cpp:2629`); bridge `OnGetBlocks`
  (`peer_server.go:1764`) into the blockchain service's `LocateBlockHeaders` (`peer_server.go:1779`); an empty
  answer is an empty `notfound` (`peer_server.go:1798`, `:1809-1823`), where the reference sends nothing. Teranode's
  reason: the edge implements `NodeNetworkLimited` and answers an empty locate with `notfound` so the peer need not
  time out (`peer_server.go:1810-1816`). -/
  | getblocksLocate
  /-- Row 8, `getheaders`. Reference `ProcessGetHeadersMessage` (`net_processing.cpp:2978`); bridge `OnGetHeaders`
  (`peer_server.go:1828`) into `GetBlockHeadersFromCommonAncestor` (`peer_server.go:1861`); no stop hash
  (`net_processing.cpp:3001-3002` stops at it), nothing for an empty answer (`peer_server.go:1891-1893`; the
  reference sends an empty `headers`, `net_processing.cpp:3056`). Teranode's reason: the blockchain service owns the
  header index, so the edge asks it from the common ancestor. -/
  | getheadersFromAncestor
  /-- Row 10, `tx`. Reference `ProcessTxMessage` (`net_processing.cpp:3351`); bridge `OnTx` (`peer_server.go:1077`),
  `QueueTx` (`manager.go:3096`), `handleTxMsg` (`manager.go:1271`) into the validator's `Validate`
  (`manager.go:1320`; `services/validator/Validator.go:608`) at block height 0, read as the UTXO store's height
  (`manager.go:1319`). The service: the validator, which spends the inputs and creates the outputs in the UTXO store
  in one operation (`Validator.go:1102-1105`): validity is the store's, the edge only carries. `handleTx`,
  `bridge_accept_relayed`. -/
  | txToValidator
  /-- Row 11, `headers`. Reference `ProcessHeadersMessage` (`net_processing.cpp:3413`); bridge `OnHeaders`
  (`peer_server.go:1670`), `QueueHeaders` (`manager.go:3452`), `handleHeadersMsg` (`manager.go:2470`), only in the
  sync manager's `headersFirstMode` toward a checkpoint; any other `headers` disconnects as unrequested
  (`manager.go:2493-2498`). Teranode's reason: the sync manager reads headers only in its `headersFirstMode` walk toward
  a checkpoint and treats any other `headers` as misbehavior (`manager.go:2489`: "The remote peer is misbehaving if we
  didn't request headers"). `BridgeDivergence.headersUnsolicitedDropped`. -/
  | headersToCheckpoint
  /-- Row 13, `block`. Reference `ProcessBlockMessage` (`net_processing.cpp:4050`); bridge `OnBlock`
  (`peer_server.go:1109`), `QueueBlock` (`manager.go:3111`), `handleBlockMsg` (`manager.go:1726`), `HandleBlockDirect`
  (`handle_block.go:52`) into subtrees (`handle_block.go:389`, `CheckSubtreeFromBlock` `:746`) and the block
  validation service's `ProcessBlock` (`handle_block.go:348`). The service: subtrees are Teranode's unit of block
  work, so a legacy block is cut into them and validated where blocks are validated. `bridgeBlockAccepts`,
  `bridge_block_accepted`. -/
  | blockToSubtrees
  deriving DecidableEq, Repr

/-- The DROPPED rows: the bridge ignores, refuses or cannot decode a message the reference handles. Nine commands
have no go-wire command (`go-wire@v1.2.11/message.go:56-91`), so the bridge's answer is the read-error road: a
`reject` `malformed` and a disconnect (`services/legacy/peer/peer.go:1939-1954`; on regtest from `127.0.0.1` or
`localhost` a logged skip, `peer.go:1367-1390`, `:1930-1934`), where the reference ignores an unknown command
(`net_processing.cpp:4874-4878`). Teranode's reason for the codec rows: the edge carries what the network uses
between full nodes for transactions and blocks; the client-only and the reference's own extension messages are
not carried. -/
inductive DropReason where
  /-- Row 9, `gethdrsen`. Reference `ProcessGetHeadersEnrichedMessage` (`net_processing.cpp:3225`); bridge: no codec.
  Unreachable from an SV-node peer, which sends it only as a client. -/
  | gethdrsenNoCodec
  /-- Row 12, `hdrsen`. The reference ignores it inbound (`net_processing.cpp:4874-4878`); bridge: no codec, a
  disconnect. Unreachable: sent only after `gethdrsen` or `sendhdrsen`. -/
  | hdrsenNoCodec
  /-- Row 15, `mempool`. Reference `ProcessMempoolMessage` (`net_processing.cpp:4158`); bridge `OnMemPool`
  (`peer_server.go:1063`) always disconnects (`:1070`). Teranode's reason: there is no mempool to list (the
  bridge's own log: `peer_server.go:1070`). At the
  defaults (`-rejectmempoolrequest` true, `src/validation.h:75`) both disconnect a plain request from a
  non-whitelisted peer (`net_processing.cpp:4170-4175`). -/
  | mempoolNoPool
  /-- Row 19, `filterload`. Reference `ProcessFilterLoadMessage` (`net_processing.cpp:4317`) behind the bloom gate
  (`:4705-4714`); bridge `OnFilterLoad` (`peer_server.go:1986`) disconnects (`:1987`), the bloom bit cleared
  (`peer_server.go:3803`). Both refuse at their defaults (`-peerbloomfilters`, `src/net/net_processing.h:21`). -/
  | filterloadNoBloom
  /-- Row 20, `filteradd`. As row 19: reference `net_processing.cpp:4336`; bridge `OnFilterAdd`
  (`peer_server.go:1969`). -/
  | filteraddNoBloom
  /-- Row 21, `filterclear`. Reference `ProcessFilterClearMessage` (`net_processing.cpp:4356`) turns transaction relay
  back on; bridge `OnFilterClear` (`peer_server.go:1977`) disconnects (`:1978`). Unreachable from an SV-node peer. -/
  | filterclearDisconnect
  /-- Row 22, `reject`. Reference `ProcessRejectMessage` (`net_processing.cpp:1485`) backs off block requests on
  `REJECT_TOOBUSY` (`:1508-1511`); bridge `OnReject` (`peer_server.go:2082`) logs it. Reachable: the reference sends
  it when its send queues are full (`net_processing.cpp:1057-1070`). Teranode's reason: the edge logs every `reject`
  it receives (`peer_server.go:2081`: "OnReject logs all reject messages received from the remote peer").
  `BridgeDivergence.rejectBackoffAbsent`. -/
  | rejectLogged
  /-- Row 24, `sendhdrsen`. Reference `ProcessSendHdrsEnMessage` (`net_processing.cpp:2404`); bridge: no codec.
  Unreachable: sent only as a client. -/
  | sendhdrsenNoCodec
  /-- Row 26, `sendcmpct`. Reference `ProcessSendCompactMessage` (`net_processing.cpp:2428`); bridge: decoded
  (`go-wire@v1.2.11/message.go:220-221`), no case (`peer.go:2129-2130`). Reachable: the reference sends it on every
  `verack` at protocol 70014 or later (`net_processing.cpp:1971-1981`). Teranode's reason: blocks move as subtrees
  between Teranodes, and the edge serves whole blocks. `BridgeDivergence.compactBlocksDeclined`. -/
  | sendcmpctIgnored
  /-- Row 27, `cmpctblock`. Reference `ProcessCompactBlockMessage` (`net_processing.cpp:3744`); bridge: no codec.
  Unreachable: the bridge never sends `sendcmpct`. -/
  | cmpctblockNoCodec
  /-- Row 28, `getblocktxn`. Reference `ProcessGetBlockTxnMessage` (`net_processing.cpp:2790`); bridge: no codec.
  Unreachable: asked only of a compact-block source (`net_processing.cpp:3935`). -/
  | getblocktxnNoCodec
  /-- Row 29, `blocktxn`. Reference `ProcessBlockTxnMessage` (`net_processing.cpp:3623`); bridge: no codec.
  Unreachable: sent only after `getblocktxn` (`net_processing.cpp:2778`). -/
  | blocktxnNoCodec
  /-- Row 33, `dsdetected`. Reference `ProcessDoubleSpendMessage` (`net_processing.cpp:4573`), relayed to every
  other peer (`:4655-4663`); bridge: no codec, a disconnect. Reachable. `BridgeDivergence.dsdetectedDisconnects`. -/
  | dsdetectedNoCodec
  /-- Row 34, `extmsg`. The header marker, never dispatched by the reference (written `src/protocol.cpp:221-227`,
  read `:256-266`); the bridge parses the marker (`go-wire@v1.2.11/message.go:270-280`). See row 39. -/
  | extmsgMarkerOnly
  /-- Row 35, `revokemid`. Reference `ProcessRevokeMidMessage` (`net_processing.cpp:4523`), relayed to every other
  peer (`:4551-4558`) and pushed by the RPC `revokeminerid` (`src/rpc/miner_info.cpp:861-866`); bridge: no codec, a
  disconnect. Reachable. `BridgeDivergence.revokemidDisconnects`. -/
  | revokemidNoCodec
  /-- Row 36, `authch`. Reference `ProcessAuthChMessage` (`net_processing.cpp:1989`), answered by `authresp`
  (`:2133`); bridge `handleAuthChMsg` (`peer.go:1211`) checks and sends no `authresp` (`peer.go:1231-1234`).
  Reachable: the reference sends `authch` on every `verack` (`net_processing.cpp:1957-1958`). Teranode's reason: the
  bridge answers the authenticated-connection handshake as a seed node would, with no miner-id support
  (`peer.go:1205-1210`: "Legacy nodes are handling messages without Miner ID as the base assumption").
  `BridgeDivergence.authchUnanswered`. -/
  | authchUnanswered
  /-- Row 37, `authresp`. Reference `ProcessAuthRespMessage` (`net_processing.cpp:2150`); bridge: decoded, no case
  (`peer.go:2129-2130`). Unreachable: the bridge never sends `authch`, having no miner id (`peer.go:1205-1210`). -/
  | authrespIgnored
  /-- Row 38, `datareftx`. The reference ignores it inbound (`net_processing.cpp:4874-4878`); bridge: no codec, a
  disconnect. Unreachable: sent only for a dataref `getdata` the bridge never makes. -/
  | datareftxNoCodec
  /-- Row 39, the extended header. Reference `CExtendedMessageHeader` (`src/protocol.h:93`), used above `2^32 - 1`
  bytes (`src/protocol.cpp:221-227`, read `:256-266`); bridge: the reader takes 24 bytes and reads the extended
  fields from the consumed buffer (`go-wire@v1.2.11/message.go:253`, `:270-280`), so the message takes the
  read-error road. Unreachable below the bridge's block bound (`BridgeDivergence.blockReadBound`). -/
  | extendedHeaderUnread
  deriving DecidableEq, Repr

/-- Whether an SV-node peer can send the dropped message to the bridge at the pins with the defaults cited (the
reading half's *reachable*). -/
def DropReason.reachable : DropReason → Bool
  | .rejectLogged | .sendcmpctIgnored | .dsdetectedNoCodec | .revokemidNoCodec | .authchUnanswered => true
  | _ => false

/-- The bridge's handling of a message type: the same as the reference, translated into a named service call, or
dropped for a named reason. -/
inductive Handling where
  | same (s : Same)
  | translated (t : Translation)
  | dropped (r : DropReason)
  deriving DecidableEq, Repr

/-- **THE MAPPING** (`docs/CONFORMANCE-TERANODE-BRIDGE.md` section 1, one constructor per row). [D] the class, the
reading half's; [SRC] the handlers, in the constructors' docstrings. -/
def bridge : Message → Handling
  | .cmd .version => .same .version
  | .cmd .verack => .same .verack
  | .cmd .addr => .same .addr
  | .cmd .inv => .translated .invThroughKafka
  | .cmd .getdata => .translated .getdataFromStore
  | .cmd .merkleblock => .same .merkleblock
  | .cmd .getblocks => .translated .getblocksLocate
  | .cmd .getheaders => .translated .getheadersFromAncestor
  | .cmd .gethdrsen => .dropped .gethdrsenNoCodec
  | .cmd .tx => .translated .txToValidator
  | .cmd .headers => .translated .headersToCheckpoint
  | .cmd .hdrsen => .dropped .hdrsenNoCodec
  | .cmd .block => .translated .blockToSubtrees
  | .cmd .getaddr => .same .getaddr
  | .cmd .mempool => .dropped .mempoolNoPool
  | .cmd .ping => .same .ping
  | .cmd .pong => .same .pong
  | .cmd .notfound => .same .notfound
  | .cmd .filterload => .dropped .filterloadNoBloom
  | .cmd .filteradd => .dropped .filteraddNoBloom
  | .cmd .filterclear => .dropped .filterclearDisconnect
  | .cmd .reject => .dropped .rejectLogged
  | .cmd .sendheaders => .same .sendheaders
  | .cmd .sendhdrsen => .dropped .sendhdrsenNoCodec
  | .cmd .feefilter => .same .feefilter
  | .cmd .sendcmpct => .dropped .sendcmpctIgnored
  | .cmd .cmpctblock => .dropped .cmpctblockNoCodec
  | .cmd .getblocktxn => .dropped .getblocktxnNoCodec
  | .cmd .blocktxn => .dropped .blocktxnNoCodec
  | .cmd .protoconf => .same .protoconf
  | .cmd .createstrm => .same .createstrm
  | .cmd .streamack => .same .streamack
  | .cmd .dsdetected => .dropped .dsdetectedNoCodec
  | .cmd .extmsg => .dropped .extmsgMarkerOnly
  | .cmd .revokemid => .dropped .revokemidNoCodec
  | .cmd .authch => .dropped .authchUnanswered
  | .cmd .authresp => .dropped .authrespIgnored
  | .cmd .datareftx => .dropped .datareftxNoCodec
  | .extendedHeader => .dropped .extendedHeaderUnread

/-- The class of a handling, as the reading half names it. -/
def Handling.cls : Handling → String
  | .same _ => "SAME"
  | .translated _ => "TRANSLATED"
  | .dropped _ => "DROPPED"

/-- The rows of a class. -/
def rowsOf (k : String) : List Message := Message.all.filter (fun m => (bridge m).cls == k)

/-- [M] 2026-10-18: one constructor per row: no two rows share a handling. -/
theorem bridge_rows_distinct : (Message.all.map bridge).Nodup := by decide

/-- [M] 2026-10-18: the reading half's count, 13 SAME, 7 TRANSLATED, 19 DROPPED. -/
theorem bridge_counts :
    ((rowsOf "SAME").length, (rowsOf "TRANSLATED").length, (rowsOf "DROPPED").length) = (13, 7, 19) := by
  decide

/-- [M] 2026-10-18: the reading half's five reachable drops: `reject`, `sendcmpct`, `dsdetected`, `revokemid`,
`authch`. -/
theorem reachable_drops :
    Message.all.filter (fun m => match bridge m with | .dropped r => r.reachable | _ => false) =
      [.cmd .reject, .cmd .sendcmpct, .cmd .dsdetected, .cmd .revokemid, .cmd .authch] := by
  decide

/-! ## 3. The transaction road: `handleTxMsg` -/

/-- The validator's answer as `handleTxMsg` reads it (`manager.go:1320-1370`): no error; the three errors that park
the transaction as an orphan (`ErrTxMissingParent`, `ErrTxLocked`, `ErrTxCreating`, `manager.go:1335`); a conflict
(`ErrTxConflicting`, read on the orphan road, `manager.go:1419`); any other error. -/
inductive ValidateResult where
  | ok
  | missingParent
  | locked
  | creating
  | conflicting
  | invalid
  deriving DecidableEq, Repr

/-- The bridge's transaction memory: the rejected-transaction map (`sm.rejectedTxns`, `manager.go:1297`, bounded at
10,000 by `maxRejectedTxns` `manager.go:96`, cleared at each block `manager.go:2181`) and the orphan map
(`sm.orphanTxs`, each entry with its parents, `manager.go:1338-1353`). -/
structure TxState where
  rejected : List Bytes := []
  orphans : List (Bytes × List Bytes) := []
  deriving DecidableEq, Repr

/-- What `handleTxMsg` does with a transaction: ignores it (already rejected, `manager.go:1295-1299`); accepts it
and announces it with the orphans it frees (`manager.go:1373-1386`); parks it as an orphan (`manager.go:1335-1356`);
or rejects it with a `reject` (`manager.go:1357-1369`). -/
inductive TxOutcome where
  | ignored
  | accepted
  | parked
  | rejected (r : Reject)
  deriving DecidableEq, Repr

/-- The bridge's `reject` for a transaction: always `RejectInvalid` (0x10) and the reason `rejected`
(`peer.PushRejectMsg(wire.CmdTx, wire.RejectInvalid, "rejected", txHash, false)`, `manager.go:1368`). -/
def bridgeReject (id : Bytes) : Reject :=
  { message := Command.tx.bytes, code := rejectInvalid, reason := asciiBytes "rejected", hash := some id }

/-- **`handleTxMsg`** (`services/legacy/netsync/manager.go:1271-1386` at `4edb60a4`) [SRC]: an id in the rejected
map is ignored with no reject (`:1295-1299`); else by the validator's answer: no error accepts (`:1373-1386`); a
missing parent, a locked or a creating parent parks it in the orphan map unless already there (`:1335-1356`); any
other error records the id as rejected and answers the bridge's `reject` (`:1357-1369`). -/
def handleTx (b : TxState) (id : Bytes) (parents : List Bytes) (r : ValidateResult) : TxState × TxOutcome :=
  if b.rejected.contains id then (b, .ignored) else
  match r with
  | .ok => (b, .accepted)
  | .missingParent | .locked | .creating =>
    (if (b.orphans.map (·.1)).contains id then b else { b with orphans := b.orphans ++ [(id, parents)] }, .parked)
  | .conflicting | .invalid => ({ b with rejected := b.rejected ++ [id] }, .rejected (bridgeReject id))

/-- **The verdict correspondence** (a hypothesis of every transaction theorem, the harness's to measure): the
validator's answer stands for the mempool machine's verdict (#62; #78's `Verdict`). No error is `accepted`; a
missing parent is `missingInputs`; a conflict or any other error is `invalid`. `locked` and `creating` correspond to
no verdict: the reference validates under its own lock and has no parent mid-commit
(`BridgeDivergence.parkOnInFlightParent`). #88's `utxo-spend` and `script-word` rows are where this is proved for
the components (`accepted_eq_mempool`, `teranode_word_eq_mempool_word`). -/
def VerdictAgrees : ValidateResult → Verdict → Prop
  | .ok, .accepted => True
  | .missingParent, .missingInputs _ => True
  | .conflicting, .invalid .. => True
  | .invalid, .invalid .. => True
  | _, _ => False

/-- **The machine's relay predicate**: after the machine receives the transaction from the peer, it is in the pool
and in the propagator's queue (`RelayTransaction`, `src/net/net_processing.cpp:975-997`;
`EnqueueTransaction`, `src/net/net.cpp:3574-3582`; #78's `Node.recvTx`). -/
def Relays (s : Node) (pid : PeerId) (q : Queued) (v : Verdict) : Prop :=
  q ∈ (s.recvTx pid q v).1.queue ∧ q.id ∈ (s.recvTx pid q v).1.pool

/-- [M] 2026-10-18: the bridge accepts only on the validator's no-error answer, for an id it has not rejected. -/
theorem handleTx_accepted_iff (b : TxState) (id : Bytes) (ps : List Bytes) (r : ValidateResult) :
    (handleTx b id ps r).2 = .accepted ↔ b.rejected.contains id = false ∧ r = .ok := by
  unfold handleTx
  by_cases h : id ∈ b.rejected <;> cases r <;> simp [h]

/-- [M] 2026-10-18: under the correspondence, the bridge's acceptance is the machine's `accepted` verdict. -/
theorem accepted_verdict (b : TxState) (id : Bytes) (ps : List Bytes) (r : ValidateResult) (v : Verdict)
    (hB : (handleTx b id ps r).2 = .accepted) (hV : VerdictAgrees r v) : v = .accepted := by
  have hr := ((handleTx_accepted_iff b id ps r).mp hB).2
  subst hr
  cases v <;> simp_all [VerdictAgrees]

/-- [M] 2026-10-18: **THE BRIDGE ACCEPTS ONLY WHAT THE MACHINE RELAYS.** A transaction the bridge accepts from a
peer (`handleTxMsg` reaching the announcement, `manager.go:1385`, on `Validate`'s no-error answer at `:1320`),
the validator's answer agreeing with the machine's verdict, is one #78's protocol machine relays on receiving it
from the same peer: it joins the pool and the propagator's queue. The machine's side conditions are the
reference's own: the peer present and not under blocks-only (`net_processing.cpp:3356-3364`), the transaction new
to the machine (`IsTxnKnown`, `:930-961`; a known one is `bridge_known_accept_diverges`), not a miner-info data
transaction (`src/net/net.cpp:3576-3578`). A view, never a rule. -/
theorem bridge_accept_relayed (b : TxState) (ps : List Bytes) (r : ValidateResult) (v : Verdict)
    (s : Node) (pid : PeerId) (p : Peer) (q : Queued)
    (hB : (handleTx b q.id ps r).2 = .accepted) (hV : VerdictAgrees r v)
    (hp : s.peer? pid = some p) (hign : s.ignoresTxFrom p = false)
    (hnew : s.knows q.id = false) (hdr : q.id ∉ s.datarefs) :
    Relays s pid q v := by
  have hv := accepted_verdict b q.id ps r v hB hV
  subst hv
  unfold Relays Node.recvTx
  simp only [hp, hign, Bool.false_eq_true, ite_false]
  rw [show ((s.addKnown pid q.id).updPeer pid _).knows q.id = s.knows q.id from rfl, hnew]
  have hd : ((s.addKnown pid q.id).updPeer pid (fun p =>
      { p with requested := p.requested.filter (· != q.id),
               inFlight := p.inFlight.filter (· != q.id) })).datarefs = s.datarefs := rfl
  simp only [Bool.false_eq_true, ite_false, Node.enqueue, hd, List.contains_iff_mem, hdr]
  simp

/-- [M] 2026-10-18: **AND THE MACHINE ANNOUNCES IT.** Under `bridge_accept_relayed`'s conditions the propagator's
next pass queues the transaction for every other peer that relays transactions, passes its fee filter and loaded
filter and is not known to have it (from #78's `accepted_queued_for_unseen`). "Relayed" is the machine's queue,
never the bytes on a socket: the bridge's own outbound relay is the txmeta topic (B5, `manager.go:3955`), outside
the accept road, and measured by the harness. A view, never a rule. -/
theorem bridge_accept_reaches_peers (b : TxState) (ps : List Bytes) (r : ValidateResult) (v : Verdict)
    (s : Node) (pid : PeerId) (p : Peer) (q : Queued)
    (hB : (handleTx b q.id ps r).2 = .accepted) (hV : VerdictAgrees r v)
    (hp : s.peer? pid = some p) (hign : s.ignoresTxFrom p = false)
    (hnew : s.knows q.id = false) (hdr : q.id ∉ s.datarefs)
    (p' : Peer) (hp' : p' ∈ s.peers) (hne : p'.id ≠ pid) (hr : p'.relayTxes = true)
    (hf : p'.feeOk q = true) (hb : q.id ∉ p'.filtered) (hk : q.id ∉ p'.known) :
    ∃ p'' ∈ (s.recvTx pid q v).1.propagate.peers, p''.id = p'.id ∧ q.id ∈ p''.pending := by
  have hv := accepted_verdict b q.id ps r v hB hV
  subst hv
  exact accepted_queued_for_unseen s pid p hp hign q hnew hdr p' hp' hne hr hf hb hk

/-- [M] 2026-10-18: **THE RESUBMIT** (`BridgeDivergence.resubmitReannounced`). A transaction the machine already
knows is not queued again on a `tx` from a peer that is not whitelisted under forced relay
(`net_processing.cpp:3380-3392`): the machine's queue is unchanged. The bridge's validator answers a transaction
already in the store with an idempotent success (`Validator.go:1106-1117`), so the bridge announces it again. A view,
never a rule. -/
theorem bridge_known_accept_diverges (s : Node) (pid : PeerId) (p : Peer) (q : Queued) (v : Verdict)
    (hp : s.peer? pid = some p) (hign : s.ignoresTxFrom p = false)
    (hknown : s.knows q.id = true) (hforce : (p.whitelisted && s.cfg.whitelistForceRelay) = false) :
    (s.recvTx pid q v).1.queue = s.queue ∧ (s.recvTx pid q v).2 = [] := by
  unfold Node.recvTx
  simp only [hp, hign, Bool.false_eq_true, ite_false]
  rw [show ((s.addKnown pid q.id).updPeer pid _).knows q.id = s.knows q.id from rfl, hknown]
  simp [Node.addKnown, Node.updPeer, hforce]

/-- [M] 2026-10-18: **THE TOTAL FORM.** Every acceptance by the bridge, the correspondence holding and the peer
not whitelisted under forced relay, is a relay of the machine, or the machine already knows the transaction (its
pool, its recent rejects or its orphans, `Node.knows`, `IsTxnKnown` `net_processing.cpp:930-961`) and its queue
stands. The pool case is the named divergence `resubmitReannounced`; the other two are states the two memories reach
apart (an earlier receipt the machine refused, a parent the machine does not know), measured by #98's bridge rows. A
view, never a rule. -/
theorem bridge_tx_refines (b : TxState) (ps : List Bytes) (r : ValidateResult) (v : Verdict)
    (s : Node) (pid : PeerId) (p : Peer) (q : Queued)
    (hB : (handleTx b q.id ps r).2 = .accepted) (hV : VerdictAgrees r v)
    (hp : s.peer? pid = some p) (hign : s.ignoresTxFrom p = false) (hdr : q.id ∉ s.datarefs)
    (hforce : (p.whitelisted && s.cfg.whitelistForceRelay) = false) :
    Relays s pid q v ∨ ((s.recvTx pid q v).1.queue = s.queue ∧
      (q.id ∈ s.pool ∨ q.id ∈ s.rejects ∨ q.id ∈ s.orphans.map (·.1))) := by
  cases hk : s.knows q.id
  · exact Or.inl (bridge_accept_relayed b ps r v s pid p q hB hV hp hign hk hdr)
  · refine Or.inr ⟨(bridge_known_accept_diverges s pid p q v hp hign hk hforce).1, ?_⟩
    simp only [Node.knows, Bool.or_eq_true, List.contains_iff_mem] at hk
    exact hk.elim (fun h => h.elim Or.inl (fun h => Or.inr (Or.inl h))) (fun h => Or.inr (Or.inr h))

/-- [M] 2026-10-18: **THE REJECTED ID.** The bridge ignores a transaction whose id it has rejected, with no reject
(`manager.go:1295-1299`); the machine, its inventory test holding the id among its recent rejects, relays nothing and
answers nothing for a peer not whitelisted under forced relay (`net_processing.cpp:930-961`, `:3380-3392`). Both
memories are cleared at a block: the bridge's at each accepted block (`manager.go:2181`), the reference's when the
active tip moves (`net_processing.cpp:934-942`). A view, never a rule. -/
theorem bridge_rejected_ignored (b : TxState) (ps : List Bytes) (r : ValidateResult)
    (s : Node) (pid : PeerId) (p : Peer) (q : Queued) (v : Verdict)
    (hrej : b.rejected.contains q.id = true) (hm : q.id ∈ s.rejects)
    (hp : s.peer? pid = some p) (hign : s.ignoresTxFrom p = false)
    (hforce : (p.whitelisted && s.cfg.whitelistForceRelay) = false) :
    (handleTx b q.id ps r).2 = .ignored ∧ (s.recvTx pid q v).1.queue = s.queue ∧ (s.recvTx pid q v).2 = [] := by
  have hmem : q.id ∈ b.rejected := by simpa using hrej
  refine ⟨by simp [handleTx, hmem], ?_⟩
  have hk : s.knows q.id = true := by simp [Node.knows, hm]
  exact bridge_known_accept_diverges s pid p q v hp hign hk hforce

/-- [M] 2026-10-18: **THE FLATTENED REJECT** (`BridgeDivergence.rejectFlattened`). The bridge's `reject` for a
rejected transaction carries 0x10 and `rejected` whatever the validator said (`manager.go:1368`); the machine's
carries the verdict's own code and reason (`src/validation.cpp:1934-1952`). The two messages are equal only when
the verdict's code is 0x10 and its reason is `rejected`. A view, never a rule. -/
theorem bridge_reject_flattened (pid : PeerId) (id : Bytes) (code : Nat) (reason : Bytes)
    (h : rejectFor pid id code reason = [(pid, .reject (bridgeReject id))]) :
    code = rejectInvalid ∧ reason.take maxRejectReason = asciiBytes "rejected" := by
  unfold rejectFor at h
  split at h
  · simp only [List.cons.injEq, Prod.mk.injEq, Msg.reject.injEq, Reject.mk.injEq, bridgeReject] at h
    exact ⟨h.1.2.2.1, h.1.2.2.2.1⟩
  · simp at h

/-- [M] 2026-10-18: a witness of `bridge_reject_flattened`: a verdict refused for a non-standard script (0x40,
`REJECT_NONSTANDARD`, `src/consensus/validation.h:16-24`) reaches the peer from the reference with its code and
from the bridge as 0x10. A view, never a rule. -/
theorem bridge_reject_flattened_witness :
    rejectFor 0 [1] 0x40 (asciiBytes "scriptpubkey") ≠ [(0, .reject (bridgeReject [1]))] := by decide

/-- [M] 2026-10-18: **THE FEE FILTER** (`BridgeDivergence.feeFilterBypassed`). An announcement with no size passes
every peer's fee filter (`peer_server.go:2736-2755`: the rate stays at the maximum when the size is 0); in the
machine's terms the fee at any rate of a zero size is 0. A view, never a rule. -/
theorem bridge_announce_passes_fee_filter (p : Peer) (q : Queued) (h : q.size = 0) : p.feeOk q = true := by
  simp [Peer.feeOk, feeAt, h]

/-- [M] 2026-10-18: the machine withholds a transaction below a peer's filter: at 1000 satoshis per kilobyte a
250-byte transaction paying 100 is not offered (`src/net/net.cpp:861-866`), where the bridge's sizeless announcement
is. A view, never a rule. -/
theorem fee_filter_withholds_witness :
    ({ id := 0, addr := 0, minFeeFilter := 1000 } : Peer).feeOk { id := [1], fee := 100, size := 250 } = false ∧
      ({ id := 0, addr := 0, minFeeFilter := 1000 } : Peer).feeOk { id := [1], fee := 100, size := 0 } = true := by
  decide

/-! ## 4. The orphan road: `processOrphanTransactions` -/

/-- What `processOrphanTransactions` does with one orphan the arriving parent names (`manager.go:1390-1444`): no
error accepts it and announces it with its size (`:1424-1437`); a missing, locked or creating parent leaves it
(`:1411-1415`); a conflict deletes the PARENT's key, so the orphan stays (`:1417-1421`, B9, the reading half's
reading); any other error is logged and the orphan stays (`:1423-1426`). -/
inductive OrphanOutcome where
  | accepted
  | stays
  deriving DecidableEq, Repr

/-- The bridge's per-orphan step (`manager.go:1404-1437`) [SRC]. -/
def orphanStep : ValidateResult → OrphanOutcome
  | .ok => .accepted
  | _ => .stays

/-- [M] 2026-10-18: **A FREED ORPHAN THE BRIDGE ACCEPTS, THE MACHINE RELAYS.** An orphan the bridge accepts when its
parent arrives (`orphanStep` `.ok`, the correspondence giving `accepted`), held by the machine as an orphan, is
relayed by the machine's retry: it joins the pool and the queue (#78's `Node.retryOrphan`;
`src/txn_validator.cpp:695-720`). A view, never a rule. -/
theorem bridge_orphan_relayed (r : ValidateResult) (v : Verdict) (s : Node) (q : Queued)
    (o : Bytes × PeerId × List Bytes)
    (hB : orphanStep r = .accepted) (hV : VerdictAgrees r v)
    (ho : s.orphans.find? (·.1 = q.id) = some o) (hdr : q.id ∉ s.datarefs) :
    q ∈ (s.retryOrphan q v).1.queue ∧ q.id ∈ (s.retryOrphan q v).1.pool := by
  have hr : r = .ok := by cases r <;> simp_all [orphanStep]
  subst hr
  have hv : v = .accepted := by cases v <;> simp_all [VerdictAgrees]
  subst hv
  obtain ⟨oid, opid, ops⟩ := o
  simp [Node.retryOrphan, ho, Node.enqueue, hdr]

/-- [M] 2026-10-18: and the propagator's next pass queues it for every peer that relays transactions, passes its
filters and is not known to have it (from #78's `retryOrphan_accepted_queued_for_unseen`). A view, never a rule. -/
theorem bridge_orphan_reaches_peers (r : ValidateResult) (v : Verdict) (s : Node) (q : Queued)
    (o : Bytes × PeerId × List Bytes)
    (hB : orphanStep r = .accepted) (hV : VerdictAgrees r v)
    (ho : s.orphans.find? (·.1 = q.id) = some o) (hdr : q.id ∉ s.datarefs)
    (p : Peer) (hp : p ∈ s.peers) (hr : p.relayTxes = true) (hf : p.feeOk q = true)
    (hb : q.id ∉ p.filtered) (hk : q.id ∉ p.known) :
    ∃ p' ∈ (s.retryOrphan q v).1.propagate.peers, p'.id = p.id ∧ q.id ∈ p'.pending := by
  have hr' : r = .ok := by cases r <;> simp_all [orphanStep]
  subst hr'
  have hv : v = .accepted := by cases v <;> simp_all [VerdictAgrees]
  subst hv
  exact retryOrphan_accepted_queued_for_unseen s q o ho hdr p hp hr hf hb hk

/-- [M] 2026-10-18: a misbehavior increment leaves the orphans alone. -/
theorem misbehaving_orphans (s : Node) (pid : PeerId) (n : Nat) (r : Bytes) :
    (s.misbehaving pid n r).orphans = s.orphans := by
  unfold Node.misbehaving
  split
  · rfl
  · dsimp only
    split <;> rfl

/-- [M] 2026-10-18: **THE KEPT ORPHAN** (`BridgeDivergence.invalidOrphanKept`). An orphan whose retry is invalid
leaves the machine's orphans (`src/validation.cpp:1954-2003`; #78's `retryOrphan`), while the bridge keeps it until
its eviction (`orphanStep` `.stays`; `manager.go:3615`, `:3674-3686`). A view, never a rule. -/
theorem bridge_orphan_invalid_kept (s : Node) (q : Queued) (code : Nat) (reason : Bytes) (dos : Nat)
    (corruption : Bool) :
    orphanStep .invalid = .stays ∧
      q.id ∉ ((s.retryOrphan q (.invalid code reason dos corruption)).1.orphans.map (·.1)) := by
  refine ⟨rfl, ?_⟩
  unfold Node.retryOrphan
  split
  · rename_i hn
    intro hm
    obtain ⟨e, he, hid⟩ := List.mem_map.mp hm
    have := List.find?_eq_none.mp hn e he
    simp_all
  · simp only [misbehaving_orphans]
    split <;> simp

/-! ## 5. The inventory road: `processInvMsg` -/

/-- **The bridge's request on a transaction `inv` entry** (`processInvMsg` `manager.go:2809-2816`, `haveInventory`
`:2619-2650`, the `getdata` `:2753`) [SRC]: a transaction entry is requested only while the FSM is RUNNING and the
UTXO store does not have it. -/
def bridgeInvRequests (running held : Bool) : Bool := running && !held

/-- [M] 2026-10-18: **THE INVENTORY ROAD.** An `inv` entry the bridge requests (RUNNING, the store not having it),
with the FSM's RUNNING standing for the machine's download latch being off and the store's "have it" for the
machine's inventory test (`BridgeDivergence.invGatedByFsm` where they part), the peer present and not under
blocks-only, its request queue under the cap and the id neither in flight from it nor queued for it, is asked for by
the machine (`ProcessInvMessage`, `net_processing.cpp:2454-2532`; `AskFor`, `src/net/net.cpp:3269-3318`). A view,
never a rule. -/
theorem bridge_inv_requests (running held : Bool) (s : Node) (pid : PeerId) (p : Peer) (id : Bytes)
    (hB : bridgeInvRequests running held = true) (hrun : running = !s.ibd) (hheld : held = s.knows id)
    (hp : s.peer? pid = some p) (hign : s.ignoresTxFrom p = false)
    (hcap : ¬ p.requested.length > s.cfg.askForCap) (hfl : id ∉ p.inFlight) (hrq : id ∉ p.requested) :
    id ∈ (s.recvInv pid [txItem id]).askedFor := by
  have hibd : s.ibd = false := by
    cases h : s.ibd <;> simp_all [bridgeInvRequests]
  have hkn : s.knows id = false := by
    cases h : s.knows id <;> simp_all [bridgeInvRequests]
  have hpid : p.id = pid := by simpa using List.find?_some hp
  simp only [Node.recvInv, hp, List.foldl_cons, List.foldl_nil, Node.invItem, txItem, ite_true]
  have hk1 : (s.addKnown pid id).knows id = false := hkn
  have hi1 : (s.addKnown pid id).ibd = false := hibd
  have hg1 : (s.addKnown pid id).ignoresTxFrom p = false := hign
  simp only [hk1, hi1, hg1, Bool.not_false, Bool.and_self, Bool.false_eq_true, ite_false, ite_true]
  have hp1 : (s.addKnown pid id).peer? pid =
      some { p with known := if p.known.contains id then p.known else p.known ++ [id] } := by
    unfold Node.addKnown Node.updPeer
    rw [peer?_map s _ (fun r => by split <;> simp)]
    simp [hp, hpid]
  unfold Node.askFor
  rw [hp1]
  simp only
  have hc : ¬ (p.requested.length > (s.addKnown pid id).cfg.askForCap ∨ p.inFlight.contains id = true ∨
      p.requested.contains id = true) := by
    simp only [List.contains_iff_mem, not_or]
    exact ⟨hcap, hfl, hrq⟩
  simp only [hc, ite_false]
  split <;> simp_all

/-! ## 6. The block road: `handleBlockMsg` -/

/-- The bridge's read bound on a block: 4,000,000,000 bytes, a compile-time constant of the bridge
(`services/legacy/config.go:29`, `:45`, handed to go-wire at `services/legacy/Server.go:383`), not a setting. -/
def legacyReadBound : Nat := 4000000000

/-- A block as it arrives at the bridge: whether the bridge requested it from the peer (`state.requestedBlocks`,
`manager.go:1795-1810`), whether the network is regtest (the duplicate-feeding exception, `manager.go:1796-1801`), its
serialized size, and whether the payload's checksum matches the header's. -/
structure BlockArrival where
  requested : Bool
  regtest : Bool
  size : Nat
  checksumOk : Bool
  deriving DecidableEq, Repr

/-- **The bridge's block road** (`handleBlockMsg` `manager.go:1726-2185`, `HandleBlockDirect`
`handle_block.go:52`) [SRC]: a block is read within the bound (`go-wire@v1.2.11/msg_block.go:249-254`), its
checksum not checked on this road (`services/legacy/peer/wire_streaming.go:11-25`); an unrequested block off
regtest disconnects the peer (`manager.go:1796-1801`); else Teranode's block validation decides
(`ProcessBlock`, `handle_block.go:348`; `processBlockOk`). -/
def bridgeBlockAccepts (a : BlockArrival) (processBlockOk : Bool) : Bool :=
  (a.requested || a.regtest) && decide (a.size ≤ legacyReadBound) && processBlockOk

/-- **The reference's block road** (`ProcessMessages` `net_processing.cpp:5055-5075`, `ProcessBlockMessage`
`:4050-4115`) [SRC]: a message whose checksum fails is dropped before dispatch; any other block, requested or not, the
reference hands to `ProcessNewBlock` (`net_processing.cpp:4068-4074`, the call `:4092`), forced only for a whitelisted
peer, where `AcceptBlock` may still skip an unrequested block (`src/validation.cpp:6309-6324`); `refVerdict` carries
that answer. -/
def refBlockAccepts (a : BlockArrival) (refVerdict : Bool) : Bool := a.checksumOk && refVerdict

/-- **The block verdict correspondence** (a hypothesis, never asserted): a block Teranode's block validation accepts
is one the reference's chain layer accepts. It is #88's owed `block-check` row (Teranode's block pass onto
`checkBlock`) and `block-connect` row (`connectSimulates`), S1's. -/
def BlockVerdictAgrees (processBlockOk refVerdict : Bool) : Prop := processBlockOk = true → refVerdict = true

/-- [M] 2026-10-18: **THE BRIDGE ADDS NO BLOCK ACCEPTANCE.** A block the bridge accepts is one Teranode's block
validation accepts, and within the bridge's read bound. A view, never a rule. -/
theorem bridge_block_filter (a : BlockArrival) (ok : Bool) (h : bridgeBlockAccepts a ok = true) :
    ok = true ∧ a.size ≤ legacyReadBound := by
  simp only [bridgeBlockAccepts, Bool.and_eq_true, decide_eq_true_eq] at h
  exact ⟨h.2, h.1.2⟩

/-- [M] 2026-10-18: **THE BLOCK ROAD.** A block the bridge accepts, the block verdict corresponding, is one the
reference accepts, or its checksum failed (the named divergence `checksumSkipped`: the bridge carries a block whose
header checksum is wrong and whose payload Teranode's validation accepts; the reference drops that message before
dispatch, and accepts the same block delivered with its checksum). A view, never a rule. -/
theorem bridge_block_accepted (a : BlockArrival) (ok ref : Bool) (h : bridgeBlockAccepts a ok = true)
    (hV : BlockVerdictAgrees ok ref) :
    refBlockAccepts a ref = true ∨ (a.checksumOk = false ∧ ref = true) := by
  have ⟨hok, _⟩ := bridge_block_filter a ok h
  have hr := hV hok
  cases hc : a.checksumOk
  · exact Or.inr ⟨rfl, hr⟩
  · exact Or.inl (by simp [refBlockAccepts, hc, hr])

/-- [M] 2026-10-18: **THE UNREQUESTED BLOCK** (`BridgeDivergence.unrequestedBlockDropped`). Off regtest, a block the
bridge did not request is not accepted through it, whatever the validation would say; the reference hands it to
`ProcessNewBlock` (`net_processing.cpp:4068-4074`, the call `:4092`), forced only for a whitelisted peer, where
`AcceptBlock` may still skip an unrequested block (`src/validation.cpp:6309-6324`); `refVerdict` carries that answer.
A view, never a rule. -/
theorem bridge_block_unrequested (a : BlockArrival) (ok ref : Bool) (hreq : a.requested = false)
    (hreg : a.regtest = false) (hc : a.checksumOk = true) (href : ref = true) :
    bridgeBlockAccepts a ok = false ∧ refBlockAccepts a ref = true := by
  simp [bridgeBlockAccepts, refBlockAccepts, hreq, hreg, hc, href]

/-- [M] 2026-10-18: **THE READ BOUND** (`BridgeDivergence.blockReadBound`). A block above 4,000,000,000 bytes is never
accepted through the bridge. A view, never a rule. -/
theorem bridge_block_bound (a : BlockArrival) (ok : Bool) (h : legacyReadBound < a.size) :
    bridgeBlockAccepts a ok = false := by
  have : ¬ a.size ≤ legacyReadBound := by omega
  simp [bridgeBlockAccepts, this]

/-! ## 7. The divergences -/

/-- The places the bridge and the protocol machine part, each an architecture decision of Teranode's at its
compatibility edge, its reason cited before the difference (the maintainers' framing rule of 2026-10-18 01:4xZ). None
decides a transaction or a block differently: each changes what is heard, when or by whom. -/
inductive BridgeDivergence where
  /-- Row 10. Teranode's validator answers a transaction already in the UTXO store with an idempotent success
  (`services/validator/Validator.go:1106-1117`: "a resubmit is an idempotent success"), so the bridge announces it
  again (`manager.go:1385`); the machine's inventory test drops a known transaction (`net_processing.cpp:930-961`,
  `:3380-3392`). `bridge_known_accept_diverges`. -/
  | resubmitReannounced
  /-- Row 10. The UTXO store commits a transaction in phases across records, so a parent mid-commit answers
  `ErrTxLocked` or `ErrTxCreating`, and the bridge parks the child as an orphan (`manager.go:1331-1335`: "the parent
  this tx spends from is still completing its own commit"); the reference validates under its own lock and has no
  such state. `handleTx`. -/
  | parkOnInFlightParent
  /-- Row 10, B10. Every rejected transaction is answered 0x10 `rejected` (`manager.go:1366-1368`: "TODO better
  rejection code and message from the error"); the reference answers the validation's own code and reason
  (`src/validation.cpp:1934-1952`). `bridge_reject_flattened`. -/
  | rejectFlattened
  /-- Row 10's orphan road, B8 and B9. An orphan whose retry fails stays in the bridge's orphan map until its
  eviction (`manager.go:1417-1426`, `:3615`, `:3674-3686`); the machine drops it and remembers it as rejected
  (`src/validation.cpp:1954-2003`). `bridge_orphan_invalid_kept`. -/
  | invalidOrphanKept
  /-- Row 25. A transaction accepted through row 10 is announced with no size (`manager.go:1375-1378`), so its rate
  stays at the maximum and a peer's fee filter never withholds it (`peer_server.go:2736-2755`); the machine applies
  the filter to every queued transaction (`src/net/net.cpp:861-866`). `bridge_announce_passes_fee_filter`. -/
  | feeFilterBypassed
  /-- Row 4, B4. Transaction entries act only while the blockchain service's FSM is RUNNING (`manager.go:2812-2816`)
  and pass the Kafka inv topic (`:3403-3445`); the machine's gate is its initial-download latch
  (`net_processing.cpp:2518-2520`). The two agree when RUNNING is the latch off (`bridge_inv_requests`'s hypothesis). -/
  | invGatedByFsm
  /-- Row 5, B12. A transaction is served from the UTXO store's record, mined or not (`peer_server.go:2180`); the
  reference serves from its relay memory, or its mempool after `mempool` (`net_processing.cpp:1391-1428`). The store
  is Teranode's one memory of a transaction. -/
  | getdataFromStore
  /-- Row 11. The sync manager reads headers only in its `headersFirstMode` walk toward a checkpoint and treats any
  other `headers` as misbehavior (`manager.go:2489`: "The remote peer is misbehaving if we didn't request
  headers"), so it disconnects (`:2493-2498`); the reference takes unsolicited announcements
  (`net_processing.cpp:3413`). The bridge never sends `sendheaders`, so an SV-node peer announces blocks to it by
  `inv`. -/
  | headersUnsolicitedDropped
  /-- Row 13. The sync manager treats an unrequested block as misbehavior (`manager.go:1789`: "If we didn't ask for
  this block then the peer is misbehaving") and, off regtest, disconnects the peer (`:1796-1800`); the reference hands
  it to `ProcessNewBlock` (`net_processing.cpp:4068-4074`, the call `:4092`), forced only for a whitelisted peer, where
  `AcceptBlock` may still skip an unrequested block (`src/validation.cpp:6309-6324`). The block arrives again by `inv`
  and `getdata`. `bridge_block_unrequested`. -/
  | unrequestedBlockDropped
  /-- Row 13, B15. The bridge reads at most 4,000,000,000 bytes, a compile-time constant (`services/legacy/config.go:29`,
  `:45`); the reference's `-excessiveblocksize` is a mandatory consensus input with no launch default
  (`src/bitcoind.cpp:140-157`; `docs/PARAMETERS.md` §8). The bridge decides no such block; Teranode's own size rule is
  #88's `block-size` row. `bridge_block_bound`. -/
  | blockReadBound
  /-- Row 13, B14. The block payload's checksum is not checked on the streaming road; integrity rests on the
  downstream block checks (`services/legacy/peer/wire_streaming.go:16-25`, the bridge's own comment); the reference
  drops a message whose checksum fails (`net_processing.cpp:5055-5075`). `bridge_block_accepted`. -/
  | checksumSkipped
  /-- Row 22. The edge logs every `reject` it receives (`peer_server.go:2081`: "OnReject logs all reject messages
  received from the remote peer", `:2082`), so the reference's back-off on `REJECT_TOOBUSY`
  (`net_processing.cpp:1508-1511`) has no counterpart. -/
  | rejectBackoffAbsent
  /-- Row 26. The bridge never offers compact blocks; the reference never asks it for one
  (`net_processing.cpp:3601-3607`). Between Teranodes blocks move as subtrees. -/
  | compactBlocksDeclined
  /-- Row 33. The edge carries the messages full nodes use for transactions and blocks, and the reference's own
  extension messages have no codec (`go-wire@v1.2.11/message.go:56-91`, `DropReason`'s reason), so a double-spend
  notification the reference relays to every other peer (`net_processing.cpp:4655-4663`) ends that peer's connection
  to the bridge (the read-error road). -/
  | dsdetectedDisconnects
  /-- Row 35. The edge carries the messages full nodes use for transactions and blocks, and the reference's own
  extension messages have no codec (`go-wire@v1.2.11/message.go:56-91`, `DropReason`'s reason), so a miner-id
  revocation the reference relays to every other peer (`net_processing.cpp:4551-4558`) ends that peer's connection
  to the bridge (the read-error road). -/
  | revokemidDisconnects
  /-- Row 36. The bridge answers the authenticated-connection handshake as a seed node would, with no miner-id support
  (`peer.go:1205-1210`: "Legacy nodes are handling messages without Miner ID as the base assumption"), so it checks
  the reference's `authch` and sends no `authresp` (`peer.go:1231-1234`); the reference answers it
  (`net_processing.cpp:2133`). -/
  | authchUnanswered
  deriving DecidableEq, Repr

/-- Every bridge divergence, in the constructors' order. -/
def BridgeDivergence.all : List BridgeDivergence :=
  [.resubmitReannounced, .parkOnInFlightParent, .rejectFlattened, .invalidOrphanKept, .feeFilterBypassed,
   .invGatedByFsm, .getdataFromStore, .headersUnsolicitedDropped, .unrequestedBlockDropped, .blockReadBound,
   .checksumSkipped, .rejectBackoffAbsent, .compactBlocksDeclined, .dsdetectedDisconnects, .revokemidDisconnects,
   .authchUnanswered]

/-- [M] 2026-10-18: `BridgeDivergence.all` lists every constructor. -/
theorem BridgeDivergence.mem_all (d : BridgeDivergence) : d ∈ BridgeDivergence.all := by
  cases d <;> decide

/-- The row of the table each divergence sits on. -/
def BridgeDivergence.row : BridgeDivergence → Message
  | .resubmitReannounced | .parkOnInFlightParent | .rejectFlattened | .invalidOrphanKept => .cmd .tx
  | .feeFilterBypassed => .cmd .feefilter
  | .invGatedByFsm => .cmd .inv
  | .getdataFromStore => .cmd .getdata
  | .headersUnsolicitedDropped => .cmd .headers
  | .unrequestedBlockDropped | .blockReadBound | .checksumSkipped => .cmd .block
  | .rejectBackoffAbsent => .cmd .reject
  | .compactBlocksDeclined => .cmd .sendcmpct
  | .dsdetectedDisconnects => .cmd .dsdetected
  | .revokemidDisconnects => .cmd .revokemid
  | .authchUnanswered => .cmd .authch

/-- The class of every bridge divergence: `design` (policy), an architecture decision at the compatibility edge. No
bridge divergence is a chain split: none decides a transaction or a block differently. -/
def BridgeDivergence.cls (_ : BridgeDivergence) : String := "design"

/-- The theorem that states the divergence in the model, where one does. -/
def BridgeDivergence.model : BridgeDivergence → Option Lean.Name
  | .resubmitReannounced => some ``bridge_known_accept_diverges
  | .rejectFlattened => some ``bridge_reject_flattened
  | .invalidOrphanKept => some ``bridge_orphan_invalid_kept
  | .feeFilterBypassed => some ``bridge_announce_passes_fee_filter
  | .unrequestedBlockDropped => some ``bridge_block_unrequested
  | .blockReadBound => some ``bridge_block_bound
  | .checksumSkipped => some ``bridge_block_accepted
  | _ => none

/-- [M] 2026-10-18: every divergence sits on a TRANSLATED row, on row 25 (`feefilter`, SAME but for the
announcement's size) or on one of the five reachable DROPPED rows. A view, never a rule. -/
theorem BridgeDivergence.rows_classed :
    BridgeDivergence.all.all (fun d => match bridge d.row with
      | .translated _ => true
      | .same s => s == .feefilter
      | .dropped r => r.reachable) = true := by
  decide

end BsvChain.Teranode.Bridge
