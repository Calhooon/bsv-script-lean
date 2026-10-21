import BsvChain.Wire.P2P

/-!
# The relay machine (#78), 2026-10-15 [D]

The per-peer state and the transitions of the reference's P2P layer for
transactions: what is announced, to whom and when, what is requested and
held in flight, what is answered with `reject`, how a missing parent is
fetched, how misbehavior is scored and a ban reached, and how the initial
block download gates requests. Nothing here is a block-validity rule: the
validity of a transaction is the mempool machine's answer (#62,
`lean/BsvChain/Mempool.lean`), an explicit input (`Verdict`) of the receive
transition; this layer decides what a node hears and when. Every setting is
a field of `RelayConfig`, labeled policy with its default and source
(docs/PARAMETERS.md section 8.6; rule 1).

Time is abstracted. The node announces on a timer (the propagator's period,
`-txnpropagationfreq`; the trickle delay, `-broadcastdelay`) and requests on
a timer (`TXN_REREQUEST_INTERVAL`); here the propagator's pass (`propagate`),
a peer's inventory flush (`flush`) and a peer's request pass (`request`) are
explicit transitions, taken by a run in the order its observation fixes
(the harness waits past each delay before it observes, docs/records of the
run). Block announcements and the header sync are #79's (compact blocks) and
the chain layer's; a block item in an `inv` is read here only for its type.

A view of the relay layer, never a rule of validity.

[SRC] bitcoin-sv v1.2.3 at 6504a3aff65ba97c0f6c80962b033e35ecbfed4b:
src/net/net_processing.cpp:610-634 (`Misbehaving`),:930-961 (`IsTxnKnown`),
:975-997 (`RelayTransaction`),:1392-1430,1468-1479 (`getdata` for a
transaction, `notfound`),:2454-2532 (`inv`),:3351-3408 (`tx`),:4890-4921 (the
ban's consumption),:5029-5041 (the bad magic),:5536-5570,5572-5674 (the
inventory flush),:5782-5843 (the request pass); src/net/net.cpp:535-580
(`Ban`),:836-878 (`AddTxnsToInventory`),:907-928 (`FetchNInventory`),
:3269-3318 (`AskFor`),:3401-3406 (the stream moved across addresses),
:3574-3582 (`EnqueueTransaction`); src/net/net_message.cpp:22-26 and
src/net/association.cpp:396-401 (the oversized header);
src/validation.cpp:1873-1932 (the orphan's parents),:1934-1952 (the reject
message),:2030-2095 (an invalid transaction),:2097-2137 (an accepted one);
src/txn_propagator.cpp:56-61,136-175; src/rpc/net.cpp:745-746 (`setban`);
src/rpc/rawtransaction.cpp:1682 (`sendrawtransaction`'s enqueue).
-/

namespace BsvChain.Wire
open BsvScript.Numbers

/-- [D] 2026-10-15: a peer's id (`NodeId`) and an address's id (`CNetAddr`). -/
abbrev PeerId := Nat
abbrev AddrId := Nat

/-! ## 1. The settings -/

/-- [SRC] 2026-10-15: the relay layer's node settings, every one policy.
`banScore` `-banscore` 100 (`DEFAULT_BANSCORE_THRESHOLD`, src/validation.h:191;
src/config.cpp:118,1449-1462, at least 1); `banTime` `-bantime` 86400 seconds
(src/net/net.h:152; src/net/net.cpp:546); `blocksOnly` `-blocksonly` false
(src/net/net.h:121; src/init.cpp:3691), which also softly turns
`whitelistRelay` off (src/init.cpp:2018-2021); `whitelistRelay` true and
`whitelistForceRelay` true (src/validation.h:71,73; src/init.cpp:2712-2717);
`invBroadcastDelayMs` `-broadcastdelay` 150 (src/net/net_processing.h:15-17;
src/init.cpp:3618-3623); `propagationFreqMs` `-txnpropagationfreq` 250
(src/txn_propagator.h:70; src/txn_propagator.cpp:18); `broadcastMax` the
items one flush takes, `INVENTORY_BROADCAST_MAX_PER_MB` (7 * 5) per megabyte
of the block-size setting (src/validation.h:165,170;
src/net/net_processing.cpp:515-518), 35 * 1 here for the scenario's 1000001
bytes; `askForCap` the request queue's cap, the receive cap times
`-recvinvqueuefactor` (3, src/protocol.h:57) over 36 bytes an item
(src/net/net.cpp:3271-3280; src/protocol.h:588-591), 174762 at the defaults
((2 MiB * 3 - 8) / 36). The timing fields are recorded, never read: time is
abstracted (the module header). -/
structure RelayConfig where
  banScore : Nat := 100
  banTime : Nat := 86400
  blocksOnly : Bool := false
  whitelistRelay : Bool := true
  whitelistForceRelay : Bool := true
  invBroadcastDelayMs : Nat := 150
  propagationFreqMs : Nat := 250
  broadcastMax : Nat := 35
  askForCap : Nat := 174762
  deriving DecidableEq, Repr

/-- [D] 2026-10-15: the defaults above; `askForCap` is the defaults' quotient. -/
theorem askForCap_default :
    ((2 * 1024 * 1024) * 3 - 8) / 36 = (({} : RelayConfig).askForCap) := by decide

/-! ## 2. The per-peer state -/

/-- [SRC] 2026-10-15: one peer as the node keeps it (`CNode`, src/net/net.h:929-1334;
`CNodeState`, src/net/node_state.h:49-134 at 6504a3af):
* `known`: the inventory the peer is known to have (`filterInventoryKnown`,
  a rolling bloom filter of 50000 entries, src/net/net.h:1028; the ideal set
  here, its false positives out of scope);
* `pending`: transactions queued for its next announcement (`mInvList`,
  src/net/net.cpp:836-878);
* `requested`: transactions queued to be requested from it (`mapAskFor`,
  src/net/net.h:1035);
* `inFlight`: transactions requested and not yet answered (`indexAskFor`,
  src/net/net.h:1034; cleared by the answer, src/net/net_processing.cpp:3373-3378,
  or by its ten-minute expiry, src/net/net.cpp:3314-3317);
* `relayTxes`: the version message's relay flag (src/net/net.h:969-976;
  src/net/net_processing.cpp:1763-1765); `whitelisted`, `manual` (an
  `-addnode` or `addnode` connection) and `isLocal` (a local address);
* `minFeeFilter`: its `feefilter` (src/net/net.h:1062), 0 for none;
* `filtered`: the transactions its loaded BIP37 filter rejects (an explicit
  input; with no filter loaded every transaction is relevant, src/bloom.cpp:140-143);
* `shouldBan` and `disconnect` (`fShouldBan`, src/net/node_state.h:59;
  `fDisconnect`, src/net/net.h:968).
The misbehavior score is not a field: it is the sum of the node's recorded
increments for the peer (`Node.score`), as `nMisbehavior` starts at 0
(src/net/node_state.h:56) and is written only by `Misbehaving`
(src/net/net_processing.cpp:620; `git grep nMisbehavior 6504a3af -- src`). -/
structure Peer where
  id : PeerId
  addr : AddrId
  isLocal : Bool := false
  whitelisted : Bool := false
  manual : Bool := false
  relayTxes : Bool := true
  minFeeFilter : Nat := 0
  filtered : List Bytes := []
  known : List Bytes := []
  pending : List Bytes := []
  requested : List Bytes := []
  inFlight : List Bytes := []
  shouldBan : Bool := false
  disconnect : Bool := false
  deriving DecidableEq, Repr

/-- [SRC] 2026-10-15: a transaction queued for announcement with its fee and
size (`CTxnSendingDetails`, the pool entry's fee rate and size; the
propagator's queue src/txn_propagator.cpp:56-61). -/
structure Queued where
  id : Bytes
  fee : Nat
  size : Nat
  deriving DecidableEq, Repr

/-- [SRC] 2026-10-15: why an address is banned. `misbehavior` is the score's
threshold crossing consumed by the send pass (src/net/net_processing.cpp:4900-4917);
`badMagic` a message whose start is not the network's
(src/net/net_processing.cpp:5029-5041); `oversizedHeader` a header over its
command's cap or a malformed header (src/net/net_message.cpp:22-36,
src/net/association.cpp:396-401); `streamMismatch` a stream moved between
associations of different addresses (src/net/net.cpp:3401-3406); `operator`
the `setban` RPC (src/rpc/net.cpp:745-746, reason `BanReasonManuallyAdded`).
The node records two reasons only, node misbehaving and manually added
(src/net/net.cpp:535-580); the four direct causes all record the former. -/
inductive BanCause where
  | misbehavior | badMagic | oversizedHeader | streamMismatch | operator
  deriving DecidableEq, Repr

/-- [D] 2026-10-15: one entry of the ban list: the address, its cause and,
for a cause a peer gave, the peer. -/
structure BanEntry where
  addr : AddrId
  cause : BanCause
  peer : Option PeerId
  deriving DecidableEq, Repr

/-- [D] 2026-10-15: a message the node sends, at the level of its payload. A
transaction is named by its id; its bytes are the scenario's. -/
inductive Msg where
  | inv (items : List InvItem)
  | getdata (items : List InvItem)
  | tx (id : Bytes)
  | notfound (items : List InvItem)
  | reject (r : Reject)
  deriving DecidableEq, Repr

/-- [D] 2026-10-15: a transaction's inventory item. -/
def txItem (id : Bytes) : InvItem := { kind := msgTx, hash := id }

/-- [SRC] 2026-10-15: the node: its settings, the chain's initial-download
latch (`IsInitialBlockDownload`, an input here), its peers, the propagator's
queue (`mNewTxns`), the relay memory answering `getdata` (`mapRelay`,
fifteen minutes, src/net/net_processing.cpp:5557-5568), the transactions it
knows (the inventory test's union: the accepted and held pools, the recently
removed held transactions, the ids in validation or kept as orphans, the
recent rejects and the coins cache, src/net/net_processing.cpp:930-961; here
`pool`, `orphans` and `rejects`), the ids it has asked for anywhere
(`mapAlreadyAskedFor`), the miner-info data transactions never relayed
(`g_MempoolDatarefTracker`, src/net/net.cpp:3576-3578), the ban list and the
log of every misbehavior increment (peer, amount, reason). -/
structure Node where
  cfg : RelayConfig := {}
  ibd : Bool := false
  peers : List Peer := []
  queue : List Queued := []
  relayMem : List Bytes := []
  pool : List Bytes := []
  orphans : List (Bytes × PeerId × List Bytes) := []
  rejects : List Bytes := []
  askedFor : List Bytes := []
  datarefs : List Bytes := []
  banned : List BanEntry := []
  log : List (PeerId × Nat × Bytes) := []
  deriving Repr

/-- [SRC] 2026-10-15: a peer's misbehavior score: the sum of its recorded
increments (src/net/node_state.h:56; src/net/net_processing.cpp:620). -/
def Node.score (s : Node) (pid : PeerId) : Nat :=
  ((s.log.filter (fun e => e.1 == pid)).map (fun e => e.2.1)).sum

/-- [SRC] 2026-10-15: `IsTxnKnown` over the modelled sets
(src/net/net_processing.cpp:930-961). -/
def Node.knows (s : Node) (id : Bytes) : Bool :=
  s.pool.contains id || s.rejects.contains id || (s.orphans.map (·.1)).contains id

/-- [D] 2026-10-15: change one peer. -/
def Node.updPeer (s : Node) (pid : PeerId) (f : Peer → Peer) : Node :=
  { s with peers := s.peers.map (fun p => if p.id = pid then f p else p) }

/-- [D] 2026-10-15: the peer with this id. -/
def Node.peer? (s : Node) (pid : PeerId) : Option Peer := s.peers.find? (·.id = pid)

/-! ## 3. The transitions -/

/-- [D] 2026-10-15: a validation answer, the mempool machine's (#62): the
transaction entered the accepted or held pool; its inputs are missing (the
parents named); or it is invalid with a code, a reason, a DoS score and the
corruption flag (`CValidationState`, src/consensus/validation.h:27-140). A
validation timeout (#71) is out of scope here. -/
inductive Verdict where
  | accepted
  | missingInputs (parents : List Bytes)
  | invalid (code : Nat) (reason : Bytes) (dos : Nat) (corruption : Bool)
  deriving DecidableEq, Repr

/-- [SRC] 2026-10-15: `Misbehaving` (src/net/net_processing.cpp:610-634): a
zero amount does nothing; else the increment is recorded, and the peer is
marked for a ban when the score crosses the threshold, from below to at or
above it. -/
def Node.misbehaving (s : Node) (pid : PeerId) (n : Nat) (reason : Bytes) : Node :=
  if n = 0 then s else
  let before := s.score pid
  let s' := { s with log := s.log ++ [(pid, n, reason)] }
  if before < s.cfg.banScore ∧ s.cfg.banScore ≤ before + n then
    s'.updPeer pid (fun p => { p with shouldBan := true })
  else s'

/-- [SRC] 2026-10-15: `AskFor` (src/net/net.cpp:3269-3318): dropped when the
peer's queue is at its cap (:3276-3280) or the id is already in flight from
it (:3282-3286); else queued, and remembered as asked for anywhere. -/
def Node.askFor (s : Node) (pid : PeerId) (id : Bytes) : Node :=
  match s.peer? pid with
  | none => s
  | some p =>
    if p.requested.length > s.cfg.askForCap ∨ p.inFlight.contains id ∨ p.requested.contains id then s
    else
      { (s.updPeer pid (fun p => { p with requested := p.requested ++ [id] })) with
        askedFor := if s.askedFor.contains id then s.askedFor else s.askedFor ++ [id] }

/-- [D] 2026-10-15: mark an id known to a peer. -/
def Node.addKnown (s : Node) (pid : PeerId) (id : Bytes) : Node :=
  s.updPeer pid (fun p => { p with known := if p.known.contains id then p.known else p.known ++ [id] })

/-- [SRC] 2026-10-15: `EnqueueTransaction` (src/net/net.cpp:3574-3582): a
miner-info data transaction is never queued; any other joins the propagator's
queue (src/txn_propagator.cpp:56-61). -/
def Node.enqueue (s : Node) (q : Queued) : Node :=
  if s.datarefs.contains q.id then s else { s with queue := s.queue ++ [q] }

/-- [D] 2026-10-15: the blocks-only rule for a peer: transactions from it are
ignored unless it is whitelisted under `whitelistRelay`
(src/net/net_processing.cpp:2463-2469,3356-3364). -/
def Node.ignoresTxFrom (s : Node) (p : Peer) : Bool :=
  s.cfg.blocksOnly && !(p.whitelisted && s.cfg.whitelistRelay)

/-- [SRC] 2026-10-15: the `inv` message (src/net/net_processing.cpp:2454-2532):
a transaction item is marked known to the sender and, unless the node is in
blocks-only mode for it, already knows the id, or is in the initial block
download, queued for request; a block item is left to the header sync
(#79); any other type ends the connection (:2522-2527; the type is compared
whole, high bits included). -/
def Node.invItem (p : Peer) (pid : PeerId) (s : Node) (i : InvItem) : Node :=
  if i.kind = msgTx then
    let s := s.addKnown pid i.hash
    if s.ignoresTxFrom p then s
    else if !s.knows i.hash && !s.ibd then s.askFor pid i.hash else s
  else if i.kind = msgBlock then s
  else s.updPeer pid (fun p => { p with disconnect := true })

/-- [SRC] 2026-10-15: the `inv` message, item by item (`Node.invItem`) in
the message's order (src/net/net_processing.cpp:2472-2531). -/
def Node.recvInv (s : Node) (pid : PeerId) (items : List InvItem) : Node :=
  match s.peer? pid with
  | none => s
  | some p => items.foldl (Node.invItem p pid) s

/-- [SRC] 2026-10-15: the reject message for a transaction
(`CreateTxRejectMsgForP2PTxn`, src/validation.cpp:1934-1952): sent only for
a code above 0 and below `REJECT_INTERNAL`, the reason cut at 111 bytes. -/
def rejectFor (pid : PeerId) (id : Bytes) (code : Nat) (reason : Bytes) : List (PeerId × Msg) :=
  if 0 < code ∧ code < rejectInternal then
    [(pid, .reject { message := Command.tx.bytes, code, reason := reason.take maxRejectReason,
                     hash := some id })]
  else []

/-- [SRC] 2026-10-15: the `tx` message and its validation's answer
(src/net/net_processing.cpp:3351-3408; src/validation.cpp:1786-1797,
1873-1932,2005-2137): ignored in blocks-only mode for the peer; else known to
the sender and no longer requested or in flight from it. A transaction the
node already knows is relayed only for a whitelisted peer under
`whitelistForceRelay`. Otherwise its verdict: accepted joins the pool and the
propagator's queue (`RelayTransaction`, :975-997); missing inputs with a
rejected parent is remembered as rejected, else kept as an orphan with each
unknown parent requested from the sender (`AskForMissingParents`); invalid is
remembered as rejected unless corruption is possible, relayed for a
whitelisted forced-relay peer when its DoS score is 0, answered with a reject
message, and scored against the sender. -/
def Node.recvTx (s : Node) (pid : PeerId) (q : Queued) (v : Verdict) :
    Node × List (PeerId × Msg) :=
  match s.peer? pid with
  | none => (s, [])
  | some p =>
    if s.ignoresTxFrom p then (s, []) else
    let s := (s.addKnown pid q.id).updPeer pid (fun p =>
      { p with requested := p.requested.filter (· != q.id), inFlight := p.inFlight.filter (· != q.id) })
    let forced := p.whitelisted && s.cfg.whitelistForceRelay
    if s.knows q.id then ((if forced then s.enqueue q else s), [])
    else match v with
    | .accepted => ({ s.enqueue q with pool := s.pool ++ [q.id] }, [])
    | .missingInputs parents =>
      if parents.any s.rejects.contains then ({ s with rejects := s.rejects ++ [q.id] }, [])
      else
        let s := parents.foldl (fun s par =>
          let s := s.addKnown pid par
          if s.knows par then s else s.askFor pid par) s
        ({ s with orphans := s.orphans ++ [(q.id, pid, parents)] }, [])
    | .invalid code reason dos corruption =>
      let s := if corruption then s else { s with rejects := s.rejects ++ [q.id] }
      let s := if forced && dos == 0 then s.enqueue q else s
      (s.misbehaving pid dos reason, rejectFor pid q.id code reason)

/-- [SRC] 2026-10-15: an orphan retried after its parents arrived
(src/txn_validator.cpp:695-720; src/validation.cpp:1859-1865,2109-2116;
src/net/net_processing.cpp:975-997): accepted, it
leaves the orphans for the pool and the queue; invalid, it leaves the orphans
and its sender is scored (src/validation.cpp:1954-2003). -/
def Node.retryOrphan (s : Node) (q : Queued) (v : Verdict) : Node × List (PeerId × Msg) :=
  match s.orphans.find? (·.1 = q.id) with
  | none => (s, [])
  | some (_, pid, _) =>
    let s := { s with orphans := s.orphans.filter (·.1 != q.id) }
    match v with
    | .accepted => ({ s.enqueue q with pool := s.pool ++ [q.id] }, [])
    | .missingInputs _ => (s, [])
    | .invalid code reason dos corruption =>
      let s := if corruption then s else { s with rejects := s.rejects ++ [q.id] }
      (s.misbehaving pid dos reason, rejectFor pid q.id code reason)

/-- [SRC] 2026-10-15: `sendrawtransaction`'s acceptance: the pool and the
propagator's queue (src/rpc/rawtransaction.cpp:1682 at 6504a3af). -/
def Node.rpcAccepted (s : Node) (q : Queued) : Node :=
  { s.enqueue q with pool := s.pool ++ [q.id] }

/-- [SRC] 2026-10-15: `CFeeRate::GetFee`: the fee of a size at a rate per
1000 bytes, at least 1 for a positive rate and a nonzero size
(src/amount.cpp:28-42). -/
def feeAt (rate size : Nat) : Nat :=
  let f := size * rate / 1000
  if f = 0 ∧ size ≠ 0 ∧ rate > 0 then 1 else f

/-- [SRC] 2026-10-15: whether the peer's fee filter passes a queued
transaction (src/net/net.cpp:861-866; the priority delta of
`prioritisetransaction` is taken as 0). -/
def Peer.feeOk (p : Peer) (q : Queued) : Bool :=
  p.minFeeFilter == 0 || feeAt p.minFeeFilter q.size ≤ q.fee

/-- [SRC] 2026-10-15: one queued transaction offered to a peer
(src/net/net.cpp:859-876): queued for it and marked known when its fee filter
passes, it is not known to have it, and its loaded filter accepts it. -/
def Peer.addOne (p : Peer) (q : Queued) : Peer :=
  if p.feeOk q && !p.known.contains q.id && !p.filtered.contains q.id then
    { p with pending := p.pending ++ [q.id], known := p.known ++ [q.id] }
  else p

/-- [SRC] 2026-10-15: `AddTxnsToInventory` (src/net/net.cpp:836-878): a
peer that asked for no transactions has its queue cleared; else each queued
transaction its fee filter passes, it is not known to have, and its loaded
filter accepts is queued for it and marked known. -/
def Peer.addTxns (p : Peer) (qs : List Queued) : Peer :=
  if !p.relayTxes then { p with pending := [] } else qs.foldl Peer.addOne p

/-- [SRC] 2026-10-15: the propagator's pass (src/txn_propagator.cpp:136-175):
every peer's inventory gains the queue, and the queue empties. -/
def Node.propagate (s : Node) : Node :=
  { s with peers := s.peers.map (·.addTxns s.queue), queue := [] }

/-- [SRC] 2026-10-15: one peer's inventory flush (`SendInventory` and
`SendTxnInventory`, src/net/net_processing.cpp:5536-5570,5572-5674): up to
`broadcastMax` queued transactions announced in one `inv` (an `inv` is also
cut at the items one message holds, :5550-5555, not reached here) and kept in
the relay memory. -/
def Node.flush (s : Node) (pid : PeerId) : Node × List (PeerId × Msg) :=
  match s.peer? pid with
  | none => (s, [])
  | some p =>
    let sent := p.pending.take s.cfg.broadcastMax
    if sent = [] then (s, []) else
    ({ s.updPeer pid (fun p => { p with pending := p.pending.drop s.cfg.broadcastMax }) with
       relayMem := s.relayMem ++ sent.filter (fun i => !s.relayMem.contains i) },
     [(pid, .inv (sent.map txItem))])

/-- [SRC] 2026-10-15: one peer's request pass (`SendGetDataNonBlocks`,
src/net/net_processing.cpp:5782-5843): every queued request whose time has
come (all, time abstracted) is sent unless the node already has the
transaction, and moves to in flight; one it has is dropped. -/
def Node.request (s : Node) (pid : PeerId) : Node × List (PeerId × Msg) :=
  match s.peer? pid with
  | none => (s, [])
  | some p =>
    let ask := p.requested.filter (fun i => !s.knows i)
    let s' := s.updPeer pid (fun p => { p with requested := [], inFlight := p.inFlight ++ ask })
    (s', if ask = [] then [] else [(pid, .getdata (ask.map txItem))])

/-- [SRC] 2026-10-15: a `getdata` for transactions (src/net/net_processing.cpp:1392-1430,
1468-1479): each in the relay memory is sent; the rest are answered with
`notfound`. (A peer's `mempool` request also opens the pool to it,
:1410-1426; not modelled.) -/
def Node.recvGetData (s : Node) (pid : PeerId) (items : List InvItem) : List (PeerId × Msg) :=
  let txs := items.filter (·.kind = msgTx)
  let found := txs.filter (fun i => s.relayMem.contains i.hash)
  let missing := txs.filter (fun i => !s.relayMem.contains i.hash)
  found.map (fun i => (pid, .tx i.hash)) ++ (if missing = [] then [] else [(pid, .notfound missing)])

/-- [SRC] 2026-10-15: `Ban` (src/net/net.cpp:535-580): the entry, and every
peer at the address disconnected. -/
def Node.ban (s : Node) (addr : AddrId) (cause : BanCause) (pid : Option PeerId) : Node :=
  { s with banned := s.banned ++ [{ addr, cause, peer := pid }],
           peers := s.peers.map (fun p => if p.addr = addr then { p with disconnect := true } else p) }

/-- [SRC] 2026-10-15: the send pass's ban step (src/net/net_processing.cpp:4900-4919):
a marked peer is unmarked; a whitelisted or manual peer is kept; any other is
disconnected, and banned unless its address is local. -/
def Node.consumeBan (s : Node) (pid : PeerId) : Node :=
  match s.peer? pid with
  | none => s
  | some p =>
    if !p.shouldBan then s else
    let s := s.updPeer pid (fun p => { p with shouldBan := false })
    if p.whitelisted || p.manual then s
    else
      let s := s.updPeer pid (fun p => { p with disconnect := true })
      if p.isLocal then s else s.ban p.addr .misbehavior (some pid)

/-- [D] 2026-10-15: the transitions. The direct bans (`badMagic`,
`oversizedHeader`, `streamMismatch`) and the operator's `setban` record no
increment; `misbehave` stands for every other `Misbehaving` call site
(src/net/net_processing.cpp:1683,1756,2010,2164,2294,2392,2415,2771,3426,
3484,3493,3506,3660,3801,3907,4324,4345,4565,4593,4620,4630,4708,4733,4754,
5082,5127, src/double_spend/dsattempt_handler.cpp:429,
src/net/block_download_tracker.cpp:126). -/
inductive Event where
  | recvInv (pid : PeerId) (items : List InvItem)
  | recvTx (pid : PeerId) (q : Queued) (v : Verdict)
  | retryOrphan (q : Queued) (v : Verdict)
  | recvGetData (pid : PeerId) (items : List InvItem)
  | rpcAccepted (q : Queued)
  | propagate
  | flush (pid : PeerId)
  | request (pid : PeerId)
  | misbehave (pid : PeerId) (n : Nat) (reason : Bytes)
  | sendBan (pid : PeerId)
  | badMagic (pid : PeerId)
  | oversizedHeader (pid : PeerId)
  | streamMismatch (pid : PeerId)
  | setban (addr : AddrId)
  | setIbd (b : Bool)
  deriving DecidableEq, Repr

/-- [D] 2026-10-15: a direct ban by a peer's address. -/
def Node.directBan (s : Node) (pid : PeerId) (cause : BanCause) : Node :=
  match s.peer? pid with
  | none => s
  | some p => s.ban p.addr cause (some pid)

/-- [D] 2026-10-15: one transition and the messages it sends. -/
def Node.step (s : Node) : Event → Node × List (PeerId × Msg)
  | .recvInv pid items => (s.recvInv pid items, [])
  | .recvTx pid q v => s.recvTx pid q v
  | .retryOrphan q v => s.retryOrphan q v
  | .recvGetData pid items => (s, s.recvGetData pid items)
  | .rpcAccepted q => (s.rpcAccepted q, [])
  | .propagate => (s.propagate, [])
  | .flush pid => s.flush pid
  | .request pid => s.request pid
  | .misbehave pid n reason => (s.misbehaving pid n reason, [])
  | .sendBan pid => (s.consumeBan pid, [])
  | .badMagic pid => (s.directBan pid .badMagic, [])
  | .oversizedHeader pid => (s.directBan pid .oversizedHeader, [])
  | .streamMismatch pid => (s.directBan pid .streamMismatch, [])
  | .setban addr => (s.ban addr .operator none, [])
  | .setIbd b => ({ s with ibd := b }, [])

/-- [D] 2026-10-15: a run of transitions and every message sent. -/
def Node.run (s : Node) : List Event → Node × List (PeerId × Msg)
  | [] => (s, [])
  | e :: es =>
    let (s1, o1) := s.step e
    let (s2, o2) := s1.run es
    (s2, o1 ++ o2)

end BsvChain.Wire
