import BsvChain.Chain

/-!
# Event vocabularies, 2026-10-15 [D] (#84)

Every definition and theorem here is a view, never a rule. The reference's
outward events are its ZMQ topics and its invalid-transaction sinks; this
module names each topic and payload at the pin and maps the machine's
transitions onto the events the node publishes. An event with no machine
transition and a transition with no event are recorded as such, by name.
[M] 2026-10-15 (#84): the node of record and the wallet build are
configured with `BUILD_BITCOIN_ZMQ=OFF` (their CMakeCache.txt), so no topic
exists on them; the measurement runs a third binary of the same pin with the
option ON (record docs/records/20261015-035435-s7-84-events-s1.md).

[SRC] bitcoin-sv v1.2.3 at 6504a3aff65ba97c0f6c80962b033e35ecbfed4b:
src/zmq/zmqnotificationinterface.cpp:33-47 (the nine signal slots),:59-80
(the eleven notifier factories),:176-352 (the slot bodies);
src/zmq/zmqpublishnotifier.cpp:22-36 (the message names),:104-158 (the
frames),:160-292 (each notifier's payload); src/txmempool.h:284-303,326-340;
src/txmempool.cpp:865-872 (the removal topic split); src/invalid_txn_publisher.cpp:76-181,254-303;
src/invalid_txn_sinks/zmq_sink.cpp:11-20; src/invalid_txn_sinks/file_sink.cpp:12-40,146-183;
doc/zmq.md:57-143. Teranode has no ZMQ (corpus/teranode/absences.json rows
tl.zmq-announce and tl.zmq-removal); its Kafka topics map onto these by
docs/CONFORMANCE-TERANODE-OBSERVATION.md section 5.
-/

namespace BsvChain.Views.Events
open BsvScript.Tx

/-- [SRC] 2026-10-15: the eleven notifier factories, in the factory table's order,
src/zmq/zmqnotificationinterface.cpp:59-80 at 6504a3af. The node creates a
notifier only for an option set at launch (:82-94). Views, never rules. -/
inductive Topic where
  | hashblock | hashtx | rawblock | rawtx | invalidtx
  | discardedfrommempool | removedfrommempoolblock
  | hashblock2 | rawblock2 | hashtx2 | rawtx2
  deriving DecidableEq, Repr

/-- [SRC] 2026-10-15: every topic once, in the factory table's order
(src/zmq/zmqnotificationinterface.cpp:59-80 at 6504a3af). A view, never a rule. -/
def Topic.all : List Topic :=
  [.hashblock, .hashtx, .rawblock, .rawtx, .invalidtx, .discardedfrommempool,
   .removedfrommempoolblock, .hashblock2, .rawblock2, .hashtx2, .rawtx2]

/-- [SRC] 2026-10-15: the factory key; the launch option is `-zmq` followed by
it (src/zmq/zmqnotificationinterface.cpp:59-80,85 at 6504a3af). A view, never a rule. -/
def Topic.factory : Topic → String
  | .hashblock => "pubhashblock" | .hashtx => "pubhashtx"
  | .rawblock => "pubrawblock" | .rawtx => "pubrawtx"
  | .invalidtx => "pubinvalidtx"
  | .discardedfrommempool => "pubdiscardedfrommempool"
  | .removedfrommempoolblock => "pubremovedfrommempoolblock"
  | .hashblock2 => "pubhashblock2" | .rawblock2 => "pubrawblock2"
  | .hashtx2 => "pubhashtx2" | .rawtx2 => "pubrawtx2"

/-- [SRC] 2026-10-15: the topic frame of each message, the notifier's
command (src/zmq/zmqpublishnotifier.cpp:22-36; invalidtx is the text
notifier's argument at src/zmq/zmqnotificationinterface.cpp:204 at 6504a3af).
A message is three frames: this command, the body and a four-byte
little-endian per-notifier sequence number (zmqpublishnotifier.h:20-25,
zmqpublishnotifier.cpp:109-112; the little-endian write
src/zmq/zmq_publisher.cpp:124-127). A view, never a rule. -/
def Topic.command : Topic → String
  | .hashblock => "hashblock" | .hashtx => "hashtx"
  | .rawblock => "rawblock" | .rawtx => "rawtx"
  | .invalidtx => "invalidtx"
  | .discardedfrommempool => "discardedfrommempool"
  | .removedfrommempoolblock => "removedfrommempoolblock"
  | .hashblock2 => "hashblock2" | .rawblock2 => "rawblock2"
  | .hashtx2 => "hashtx2" | .rawtx2 => "rawtx2"

/-- [D] 2026-10-15: each factory key is `pub` and the command it publishes.
The source pairs them by hand in two files; this theorem is about a view,
never a rule. -/
theorem factory_is_pub_command (t : Topic) : t.factory = "pub" ++ t.command := by
  cases t <;> rfl

/-- [SRC] 2026-10-15: the launch help names `-zmqpubremovedfrommempool`
(src/init.cpp:904-906 at 6504a3af), a key no factory registers; the factory
is `pubdiscardedfrommempool` (src/zmq/zmqnotificationinterface.cpp:69).
The node disagrees with its own help text (rule 15); the factory table is
what the node reads. A view, never a rule. -/
def helpOnlyOption : String := "pubremovedfrommempool"

/-- [D] 2026-10-15: no topic answers the help text's option. A view, never a rule. -/
theorem help_option_registers_nothing (t : Topic) : t.factory ≠ helpOnlyOption := by
  cases t <;> decide

/-- [SRC] 2026-10-15: the reason a mempool removal passes to its signal,
src/txmempool.h:284-303 at 6504a3af. A view, never a rule. -/
inductive RemovalReason where
  | UNKNOWN | EXPIRY | SIZELIMIT | REORG | BLOCK | CONFLICT | REPLACED
  | FROZEN_INPUT | NOT_WHITELISTED
  deriving DecidableEq, Repr

/-- [SRC] 2026-10-15: BLOCK and REORG raise the block-removal signal, every
other reason the discard signal (src/txmempool.cpp:865-872 at 6504a3af).
A view, never a rule. -/
def removalTopic : RemovalReason → Topic
  | .REORG | .BLOCK => .removedfrommempoolblock
  | _ => .discardedfrommempool

/-- [SRC] 2026-10-15: the discard notifier's reason words, a switch with a
default arm (src/zmq/zmqpublishnotifier.cpp:181-220 at 6504a3af).
A view, never a rule. -/
def discardedWord : RemovalReason → String
  | .EXPIRY => "expired"
  | .SIZELIMIT => "mempool-sizelimit-exceeded"
  | .CONFLICT => "collision-in-block-tx"
  | _ => "unknown-reason"

/-- [SRC] 2026-10-15: the block-removal notifier's reason words
(src/zmq/zmqpublishnotifier.cpp:238-248 at 6504a3af). A view, never a rule. -/
def blockWord : RemovalReason → String
  | .REORG => "reorg"
  | .BLOCK => "included-in-block"
  | _ => "unknown-reason"

/-- [D] 2026-10-15: the word the removal's own topic publishes. A view, never a rule. -/
def reasonWord (r : RemovalReason) : String :=
  match removalTopic r with
  | .removedfrommempoolblock => blockWord r
  | _ => discardedWord r

/-- [D] 2026-10-15: the block-removal topic carries exactly BLOCK and REORG.
A view, never a rule. -/
theorem block_topic_iff (r : RemovalReason) :
    removalTopic r = .removedfrommempoolblock ↔ r = .REORG ∨ r = .BLOCK := by
  cases r <;> simp [removalTopic]

/-- [D] 2026-10-15: four reasons share one discard word, so the word has no
inverse onto the reason: a frozen input, a lost whitelisting, a replacement
and an unknown removal all read `unknown-reason`. The node disagrees with
its documentation (rule 15): doc/zmq.md:98-99 lists three discard reasons;
the default arm (src/zmq/zmqpublishnotifier.cpp:218-219) publishes
unknown-reason for FROZEN_INPUT and NOT_WHITELISTED
(src/txmempool.cpp:1291,1338 at 6504a3af). REPLACED and UNKNOWN have no
removal site at the pin. A view, never a rule. -/
theorem unknown_reason_collapses :
    reasonWord .FROZEN_INPUT = "unknown-reason" ∧ reasonWord .NOT_WHITELISTED = "unknown-reason" ∧
    reasonWord .REPLACED = "unknown-reason" ∧ reasonWord .UNKNOWN = "unknown-reason" := by
  simp [reasonWord, removalTopic, discardedWord]

/-- [D] 2026-10-15: the three named discard reasons have three words.
A view, never a rule. -/
theorem discard_words_distinct :
    reasonWord .EXPIRY ≠ reasonWord .SIZELIMIT ∧ reasonWord .EXPIRY ≠ reasonWord .CONFLICT ∧
    reasonWord .SIZELIMIT ≠ reasonWord .CONFLICT := by
  simp [reasonWord, removalTopic, discardedWord]

/-- [SRC] 2026-10-15: a conflict removal names the block's spender and the
block (src/txmempool.cpp:1115-1116 builds it; src/zmq/zmqpublishnotifier.cpp:189-212
writes `collidedWith` {txid, size, hex} and `blockhash`). A view, never a rule. -/
structure Collided where
  spender : Tx
  blockhash : BitVec 256
  deriving Repr

/-- [SRC] 2026-10-15: the invalid-transaction record's fields a machine
verdict determines, out of src/invalid_txn_publisher.cpp:76-181 at 6504a3af:
`fromBlock` false and `source` for a transaction (:99-108), `txid` (:119),
`isMissingInputs`, `rejectionCode`, `rejectionReason` (:140-149).
A view, never a rule. -/
structure InvalidRecord where
  fromBlock : Bool
  source : String
  txid : TxId
  isMissingInputs : Bool
  rejectionCode : Nat
  rejectionReason : String
  deriving DecidableEq, Repr

/-- [SRC] 2026-10-15: the record's other fields, each with the input the
machine's verdict does not carry (src/invalid_txn_publisher.cpp:76-181,
src/validation.cpp:1733-1757, src/invalid_txn_sinks/zmq_sink.cpp:13-17 and
file_sink.cpp:157-164 at 6504a3af). Recorded, never inferred. Views, never rules. -/
def invalidFieldsOutsideMachine : List (String × String) :=
  [("size", "the body's serialized size (:120); a function of the body, not of the verdict"),
   ("hex", "the body, written only when the message fits the ZMQ sink's bound (zmq_sink.cpp:13-17) and, in the file sink, only at a txid's earliest file (file_sink.cpp:157-164)"),
   ("address, nodeId", "the submitting peer (:103-107; validation.cpp:1751-1754); absent for an RPC submission"),
   ("isInvalid, isValidationError", "the validation state's mode (:140-141), not its code and reason"),
   ("isDoubleSpendDetected, isMempoolConflictDetected, isNonFinal, isValidationTimeoutExceeded, isStandardTx", "the validation state's flags (:143-147)"),
   ("collidedWith", "the double-spend detector's set (:169-176), filled by the publisher's callback"),
   ("rejectionTime", "the wall clock at publication (:153-158; validation.cpp:1756)"),
   ("origins, blockhash, blocktime, blockheight", "a block's invalid transaction only (:78-98)")]

/-- [SRC] 2026-10-15: the source words of the record, enumTable(TxSource) at
src/txn_validation_data.cpp:13-26 at 6504a3af. The table's `unknown` and
`wallet` have no machine source. A view, never a rule. -/
def sourceWord : BsvChain.TxSource → String
  | .rpc => "rpc" | .p2p => "p2p" | .reorg => "reorg"
  | .finalised => "finalised" | .file => "file"

/-- [SRC] 2026-10-15: every published body, by notifier
(src/zmq/zmqpublishnotifier.cpp:118-158,160-292 at 6504a3af). A hash body is
the 32 bytes in display order, the reverse of the internal id (:121-126).
doc/zmq.md:86 calls a hash body hexadecimal; the source sends the 32 bytes
themselves (:121-127). Views, never rules. -/
inductive Payload where
  | txHash (id : TxId)
  | rawTx (tx : Tx)
  | blockHash (hash : BitVec 256)
  | rawBlock (block : Block)
  | removal (id : TxId) (reason : String) (collided : Option Collided)
  | invalid (record : InvalidRecord)
  deriving Repr

/-- [D] 2026-10-15: one published message without its sequence number, which
counts the notifier's own sends and is not machine state
(src/zmq/zmqpublishnotifier.cpp:109-112 at 6504a3af). A view, never a rule. -/
structure Event where
  topic : Topic
  payload : Payload
  deriving Repr

/-- [D] 2026-10-15: the removal sites at the pin, each named by the machine
function that performs it, or by the reference function it has no machine
counterpart for. Views, never rules. -/
inductive RemovalSite where
  /-- Chain.removeForBlock, a mined entry: src/txmempool.cpp:1157 -/
  | removeForBlockMined
  /-- Chain.removeForBlock, a spender of a block input and its descendants: :1091-1117 -/
  | removeForBlockConflict (spender : Tx) (blockhash : BitVec 256)
  /-- Mempool.expire: :2201-2220 -/
  | expire
  /-- Mempool.trimToSize under limitPool: :2763 -/
  | trimToSize
  /-- Chain.removeForReorg: :947-1023 -/
  | removeForReorg
  /-- Chain.addToMempoolForReorg, a filtered body's descendants: :2357-2363 -/
  | reorgFiltered
  /-- Chain.addToMempoolForReorg, a body not readmitted: :2392-2401 -/
  | reorgNotReadmitted
  /-- Chain.removeFromMempoolForReorg: :2446-2485 -/
  | removeFromMempoolForReorg
  /-- Chain.capDisconnectPool, a dropped body's descendants: :2549-2559 -/
  | capDisconnectPool
  /-- Chain.removeFrozenForReorg, a frozen input: :1253-1292 -/
  | removeFrozenInput
  /-- Chain.removeFrozenForReorg, a confiscation no longer whitelisted: :1303-1339 -/
  | removeNotWhitelisted
  /-- no machine transition: a miner-info dataref removal, :2222-2256 called
  from src/rpc/miner_info.cpp:406, src/validation.cpp:4790 and src/init.cpp:190 -/
  | minerInfoDataref
  deriving Repr

/-- [SRC] 2026-10-15: the reason each site passes, at the cited lines of
src/txmempool.cpp at 6504a3af. A view, never a rule. -/
def RemovalSite.reason : RemovalSite → RemovalReason
  | .removeForBlockMined => .BLOCK
  | .removeForBlockConflict _ _ => .CONFLICT
  | .expire | .minerInfoDataref => .EXPIRY
  | .trimToSize => .SIZELIMIT
  | .removeForReorg | .reorgFiltered | .reorgNotReadmitted
  | .removeFromMempoolForReorg | .capDisconnectPool => .REORG
  | .removeFrozenInput => .FROZEN_INPUT
  | .removeNotWhitelisted => .NOT_WHITELISTED

/-- [SRC] 2026-10-15: only the conflict site passes a conflict record; every
other site passes noConflict (src/txmempool.cpp:1115 against :1022,1157,1291,
1338,2218,2231,2252,2362,2399,2463,2557,2763 at 6504a3af). A view, never a rule. -/
def RemovalSite.collided : RemovalSite → Option Collided
  | .removeForBlockConflict spender hash => some ⟨spender, hash⟩
  | _ => none

/-- [D] 2026-10-15: the machine function a site names, or none.
A view, never a rule. -/
def RemovalSite.machine : RemovalSite → Option String
  | .removeForBlockMined | .removeForBlockConflict _ _ => some "BsvChain.removeForBlock"
  | .expire => some "BsvChain.expire"
  | .trimToSize => some "BsvChain.trimToSize"
  | .removeForReorg => some "BsvChain.removeForReorg"
  | .reorgFiltered | .reorgNotReadmitted => some "BsvChain.addToMempoolForReorg"
  | .removeFromMempoolForReorg => some "BsvChain.removeFromMempoolForReorg"
  | .capDisconnectPool => some "BsvChain.capDisconnectPool"
  | .removeFrozenInput | .removeNotWhitelisted => some "BsvChain.removeFrozenForReorg"
  | .minerInfoDataref => none

/-- [D] 2026-10-15: the one message a removed transaction raises: its
reason's topic and word, and the conflict record when the site passes one.
[SRC] src/txmempool.cpp:865-872; src/zmq/zmqpublishnotifier.cpp:170-256 at
6504a3af. A view, never a rule. -/
def removalEvent (site : RemovalSite) (id : TxId) : Event :=
  ⟨removalTopic site.reason, .removal id (reasonWord site.reason) site.collided⟩

/-- [D] 2026-10-15: the transactions a removal took out of the accepted
pool, read from the machine's states before and after it. The source raises
one signal per removed entry (src/txmempool.cpp:823-872 at 6504a3af).
A view, never a rule. -/
def removedIds (before after : Mempool) : List TxId :=
  (before.accepted.filter fun e => !after.accepted.any (fun f => f.id == e.id)).map (·.id)

/-- [D] 2026-10-15: the removal messages of one machine removal step.
A view, never a rule. -/
def removalEvents (site : RemovalSite) (before after : Mempool) : List Event :=
  (removedIds before after).map (removalEvent site)

/-- [D] 2026-10-15: an evicted transaction's removal message carries the
reason its transition names, on that reason's topic, and the conflict record
only when the site passes one. A view, never a rule. -/
theorem removal_carries_reason (site : RemovalSite) (before after : Mempool) :
    ∀ e ∈ removalEvents site before after, e.topic = removalTopic site.reason ∧
      ∃ id, e.payload = .removal id (reasonWord site.reason) site.collided := by
  intro e he
  simp only [removalEvents, List.mem_map] at he
  obtain ⟨id, _, rfl⟩ := he
  exact ⟨rfl, id, rfl⟩

/-- [D] 2026-10-15: the expiry step's messages read `expired` on the discard
topic and carry no conflict record. A view, never a rule. -/
theorem expire_events_say_expired (p : Mempool) (cfg : NodeConfig) (now : Int) :
    ∀ e ∈ removalEvents .expire p (expire p cfg now),
      e.topic = .discardedfrommempool ∧ ∃ id, e.payload = .removal id "expired" none := by
  intro e he
  obtain ⟨ht, id, hp⟩ := removal_carries_reason .expire p (expire p cfg now) e he
  exact ⟨ht, id, hp⟩

/-- [D] 2026-10-15: a conflict removal's message names the block's spender
and the block, with the word `collision-in-block-tx`. A view, never a rule. -/
theorem conflict_names_spender (spender : Tx) (hash : BitVec 256) (before after : Mempool) :
    ∀ e ∈ removalEvents (.removeForBlockConflict spender hash) before after,
      e.topic = .discardedfrommempool ∧
        ∃ id, e.payload = .removal id "collision-in-block-tx" (some ⟨spender, hash⟩) := by
  intro e he
  exact removal_carries_reason _ before after e he

/-- [D] 2026-10-15: a mined entry's message reads `included-in-block` on the
block-removal topic. A view, never a rule. -/
theorem mined_says_included (before after : Mempool) :
    ∀ e ∈ removalEvents .removeForBlockMined before after,
      e.topic = .removedfrommempoolblock ∧ ∃ id, e.payload = .removal id "included-in-block" none := by
  intro e he
  exact removal_carries_reason _ before after e he

/-- [D] 2026-10-15: `expired` has no inverse onto the machine's transitions:
a miner-info dataref removal, which no machine transition performs, passes
the same reason as Mempool.expire. A view, never a rule. -/
theorem expired_without_transition :
    RemovalSite.minerInfoDataref.reason = RemovalSite.expire.reason ∧
    RemovalSite.minerInfoDataref.machine = none := ⟨rfl, rfl⟩

/-- [D] 2026-10-15: the two messages of a transaction on the original
transaction topics, hashtx then rawtx: the notifiers' order in the slot
TransactionAddedToMempool, src/zmq/zmqnotificationinterface.cpp:38,217-238 at
6504a3af (tx2Events gives the pair of :39). A view, never a rule. -/
def txEvents (tx : Tx) : List Event :=
  [⟨.hashtx, .txHash (BsvScript.Sighash.txid tx)⟩, ⟨.rawtx, .rawTx tx⟩]

/-- [D] 2026-10-15: the second-generation pair of an added transaction.
A view, never a rule. -/
def tx2Events (tx : Tx) : List Event :=
  [⟨.hashtx2, .txHash (BsvScript.Sighash.txid tx)⟩, ⟨.rawtx2, .rawTx tx⟩]

/-- [D] 2026-10-15: the invalid-transaction message of a completed refusal.
A view, never a rule. -/
def invalidEvent (tx : Tx) (source : BsvChain.TxSource) (missing : Bool) (code : Nat)
    (reason : String) : Event :=
  ⟨.invalidtx, .invalid ⟨false, sourceWord source, BsvScript.Sighash.txid tx, missing, code, reason⟩⟩

/-- [D] 2026-10-15: the messages of one admission, by its outcome.
An accepted or held transaction raises TransactionAddedToMempool: the
validation state is valid in both (src/txn_validator.cpp:203-207,673-679;
src/validation.cpp:911-924 holds a non-final body without an invalid state).
A completed refusal publishes the invalid record unless its code is
REJECT_ALREADY_KNOWN, 257 (src/validation.cpp:1798-1803); a missing input is
an invalid state with code 0 and an empty reason (src/validation.cpp:1185-1186).
A deferred request publishes nothing (the low-priority return,
src/validation.cpp:1740-1747); a suppressed or unverifiable one reaches no
publisher. An RPC-namespace code is the handler's, never a validation
state's, and reaches no publisher. [SRC] at 6504a3af. A view, never a rule. -/
def acceptEvents (tx : Tx) (source : BsvChain.TxSource) : TxOutcome → List Event
  | .completed .accepted | .completed .heldNonFinal => txEvents tx ++ tx2Events tx
  | .completed .orphan => [invalidEvent tx source true 0 ""]
  | .completed (.rejected (.node code) reason) =>
    if code = 257 then [] else [invalidEvent tx source false code reason]
  | .completed (.rejected (.rpc _) _) => []
  | .deferred | .suppressed | .unverifiable _ => []

/-- [D] 2026-10-15: the messages of one machine connectTip. Every body
transaction raises hashtx and rawtx through BlockConnected, outside initial
download or not (src/zmq/zmqnotificationinterface.cpp:300-310; emitted after
the activation step, src/validation.cpp:5058-5062); outside initial download
the transactions not in the pool before the connection raise hashtx2 and
rawtx2, and the block raises hashblock2 and rawblock2 (:314-342; txNew is the
body less the pool's entries, src/txmempool.cpp:1047-1119; emitted at
src/validation.cpp:4402). The accepted list holds primary and secondary
entries, as mapTx does; the non-final pool is not in mapTx. [SRC] at 6504a3af.
A view, never a rule. -/
def connectEvents (pre : Mempool) (hash : BitVec 256) (block : Block) (ibd : Bool) : List Event :=
  let fresh := block.transactions.filter fun tx =>
    !pre.accepted.any (fun e => e.id == BsvScript.Sighash.txid tx)
  (if ibd then [] else fresh.flatMap tx2Events ++ [⟨.hashblock2, .blockHash hash⟩, ⟨.rawblock2, .rawBlock block⟩])
    ++ block.transactions.flatMap txEvents

/-- [D] 2026-10-15: the messages of one machine disconnectTip: every body
transaction raises hashtx and rawtx through BlockDisconnected
(src/zmq/zmqnotificationinterface.cpp:345-352; src/validation.cpp:4126 at
6504a3af). Nothing names the disconnection itself. A view, never a rule. -/
def disconnectEvents (block : Block) : List Event :=
  block.transactions.flatMap txEvents

/-- [D] 2026-10-15: the messages of an activation's tip notification: the new
tip's hash and body, never in initial download and never when the new tip
is the fork point (src/zmq/zmqnotificationinterface.cpp:176-197, the return
at :180). The node notifies once per outer iteration of ActivateBestChain
(src/validation.cpp:4913-5070), and an iteration's step returns once its
connected work exceeds the old tip's (:4755-4762): one notice per
Chain.activationStep, whose connectRun ends at the same threshold. [SRC] at
6504a3af. A view, never a rule. -/
def tipEvents (newTip fork : BitVec 256) (block : Block) (ibd : Bool) : List Event :=
  if ibd || newTip == fork then [] else [⟨.hashblock, .blockHash newTip⟩, ⟨.rawblock, .rawBlock block⟩]

/-- [D] 2026-10-15: machine transitions that publish nothing, each with the
reason at the pin. The ZMQ interface connects nine signals only
(src/zmq/zmqnotificationinterface.cpp:38-46); src/orphan_txns.cpp and
src/time_locked_mempool.cpp call no GetMainSignals at 6504a3af. Views, never rules. -/
inductive Silent where
  /-- Chain.acceptHeader: no slot for a header -/
  | acceptHeader
  /-- Chain.acceptBlock storing a body off the active chain: no slot until a connection -/
  | acceptBlockStored
  /-- Chain.invalidateBlock, reconsiderBlock, preciousBlock, setSoftRejection, setSoftFreeze:
  index flags; their disconnects and connects publish as those transitions -/
  | operatorFlags
  /-- Mempool.limitOrphans and the orphan pool: no signal in src/orphan_txns.cpp -/
  | orphanPool
  /-- Mempool.checkNonFinalPool and removeNonFinal: no signal in src/time_locked_mempool.cpp -/
  | nonFinalPool
  /-- Mempool.retryOrphans and revalidatePending queueing: the later accept publishes -/
  | queueing
  /-- the reject filter's remember and reset (BsvChain.Rejects): no slot -/
  | rejectFilter
  /-- advanceTime .blockObserved: the rolling fee's clock, no slot -/
  | rollingFee
  deriving DecidableEq, Repr

/-- [D] 2026-10-15: the transitions of the machine that the vocabulary
reads, by DESIGN-S6 section 2: accept is receiveTx's outcome (§2.1); connect
is connectBlock through Chain.connectTip (§2.2); disconnect is
disconnectBlock through Chain.disconnectTip (§2.3); tipUpdated is one
Chain.activationStep of activateBestChain (§2.4), invalidateBlock and
reconsiderBlock ending in it; removal is a pool step of connectBlock, the
reorg path of activateBestChain, or advanceTime (§2.5), by its site; silent
names receiveHeader, acceptBlock's stored body, the operator marks and
advanceTime's silent events. Removals carry the machine's states before and
after. Views, never rules. -/
inductive Transition where
  | accept (tx : Tx) (source : BsvChain.TxSource) (outcome : TxOutcome)
  | removal (site : RemovalSite) (before after : Mempool)
  | connect (pre : Mempool) (hash : BitVec 256) (block : Block) (ibd : Bool)
  | disconnect (block : Block)
  | tipUpdated (newTip fork : BitVec 256) (block : Block) (ibd : Bool)
  | silent (transition : Silent)

/-- [D] 2026-10-15: the function from a declared transition to the messages
the node publishes on a node with every topic created. A removal names its
site, and one site's messages are a function of the states before and after
it; Chain.removeForBlock performs two sites in one call (a mined entry, BLOCK,
src/txmempool.cpp:1157, and a conflict, CONFLICT, :1115-1116, one per
in-block spender), and its two states do not say which removed id took which
site, so a declaration splits them (the scenario's `ids`) and this function
does not derive the split. A view, never a rule. -/
def events : Transition → List Event
  | .accept tx source outcome => acceptEvents tx source outcome
  | .removal site before after => removalEvents site before after
  | .connect pre hash block ibd => connectEvents pre hash block ibd
  | .disconnect block => disconnectEvents block
  | .tipUpdated newTip fork block ibd => tipEvents newTip fork block ibd
  | .silent _ => []

/-- [D] 2026-10-15: the messages of a node configured with some topics: a
message needs its notifier (src/zmq/zmqnotificationinterface.cpp:82-94);
invalidtx needs the ZMQ sink as well, which src/init.cpp:2757-2768 makes
equivalent to its option at 6504a3af. A view, never a rule. -/
def published (enabled : List Topic) (t : Transition) : List Event :=
  (events t).filter fun e => enabled.contains e.topic

/-- [D] 2026-10-15: a silent transition publishes nothing. A view, never a rule. -/
theorem silent_publishes_nothing (s : Silent) : events (.silent s) = [] := rfl

/-- [D] 2026-10-15: REJECT_ALREADY_KNOWN publishes no invalid record.
A view, never a rule. -/
theorem already_known_silent (tx : Tx) (source : BsvChain.TxSource) (reason : String) :
    events (.accept tx source (.completed (.rejected (.node 257) reason))) = [] := by
  simp [events, acceptEvents]

/-- [D] 2026-10-15: every other completed refusal publishes one invalid record
carrying the verdict's code and reason, byte for byte. A view, never a rule. -/
theorem rejection_publishes_reason (tx : Tx) (source : BsvChain.TxSource) (code : Nat)
    (reason : String) (h : code ≠ 257) :
    events (.accept tx source (.completed (.rejected (.node code) reason))) =
      [invalidEvent tx source false code reason] := by
  simp [events, acceptEvents, h]

/-- [D] 2026-10-15: the record's reason is the one the machine's rejection
journal keeps for the same body (Mempool.recordTxOutcome, #67's status view
reads it). A view, never a rule. -/
theorem invalid_record_matches_journal (j : TxJournal) (tx : Tx) (source : BsvChain.TxSource)
    (code : Nat) (reason : String) (h : code ≠ 257) :
    (recordTxOutcome j tx (.completed (.rejected (.node code) reason))).rejected.lookup
        (BsvScript.Sighash.txid tx) = some ⟨.node code, reason⟩ ∧
      events (.accept tx source (.completed (.rejected (.node code) reason))) =
        [invalidEvent tx source false code reason] := by
  refine ⟨?_, rejection_publishes_reason tx source code reason h⟩
  simp [recordTxOutcome, List.lookup]

/-- [D] 2026-10-15: a missing input publishes the invalid record with
isMissingInputs, code 0 and an empty reason. A view, never a rule. -/
theorem orphan_publishes_missing (tx : Tx) (source : BsvChain.TxSource) :
    events (.accept tx source (.completed .orphan)) = [invalidEvent tx source true 0 ""] := rfl

/-- [D] 2026-10-15: an accepted and a held transaction publish the same four
messages, so the transaction topics cannot tell the pool from the non-final
pool. A view, never a rule. -/
theorem held_reads_as_accepted (tx : Tx) (source : BsvChain.TxSource) :
    events (.accept tx source (.completed .heldNonFinal)) =
      events (.accept tx source (.completed .accepted)) := rfl

/-- [D] 2026-10-15: a disconnection's messages are those of re-adding its body;
nothing on the transaction topics tells a disconnect from an acceptance of
the same transactions. A view, never a rule. -/
theorem disconnect_reads_as_added (block : Block) :
    events (.disconnect block) = block.transactions.flatMap txEvents := rfl

/-- [D] 2026-10-15: an activation that ends at its fork point publishes no
block hash. A view, never a rule. -/
theorem fork_tip_silent (tip : BitVec 256) (block : Block) (ibd : Bool) :
    events (.tipUpdated tip tip block ibd) = [] := by
  simp [events, tipEvents]

/-- [D] 2026-10-15: in initial download a connection publishes only its
transactions on hashtx and rawtx. A view, never a rule. -/
theorem ibd_connect_publishes_body (pre : Mempool) (hash : BitVec 256) (block : Block) :
    events (.connect pre hash block true) = block.transactions.flatMap txEvents := by
  simp [events, connectEvents]

/-- [D] 2026-10-15: a transaction the pool held before the connection gets
no hashtx2 from it, whatever the block. A view, never a rule. -/
theorem pooled_tx_no_hashtx2 (pre : Mempool) (hash : BitVec 256) (block : Block) (ibd : Bool)
    (tx : Tx) (h : pre.accepted.any (fun e => e.id == BsvScript.Sighash.txid tx) = true) :
    ∀ e ∈ events (.connect pre hash block ibd),
      e.topic = .hashtx2 → ∃ t ∈ block.transactions,
        e.payload = .txHash (BsvScript.Sighash.txid t) ∧
        BsvScript.Sighash.txid t ≠ BsvScript.Sighash.txid tx := by
  intro e he htopic
  simp only [events, connectEvents, List.mem_append] at he
  rcases he with he | he
  · split at he
    · simp at he
    · simp only [List.mem_append, List.mem_flatMap, List.mem_filter, List.mem_cons,
        List.not_mem_nil, or_false] at he
      rcases he with ⟨t, ⟨ht, hfresh⟩, he⟩ | he
      · simp only [tx2Events, List.mem_cons, List.not_mem_nil, or_false] at he
        rcases he with rfl | rfl
        · refine ⟨t, ht, rfl, ?_⟩
          intro heq
          rw [heq] at hfresh
          simp [h] at hfresh
        · simp at htopic
      · rcases he with rfl | rfl <;> simp at htopic
  · simp only [List.mem_flatMap, txEvents, List.mem_cons, List.not_mem_nil, or_false] at he
    obtain ⟨_, _, he⟩ := he
    rcases he with rfl | rfl <;> simp at htopic

/-- [D] 2026-10-15: a chain event read through the machine's own tree: a
connection publishes the connected body's messages, a disconnection the
disconnected body's. A body absent from the tree publishes nothing here.
A view, never a rule. -/
def chainEventEvents (s : ChainState) (pre : Mempool) (ibd : Bool) : ChainEvent → List Event
  | .connected hash => match (s.tree.get hash).bind (·.body) with
    | some block => connectEvents pre hash block ibd
    | none => []
  | .disconnected _ hash => match (s.tree.get hash).bind (·.body) with
    | some block => disconnectEvents block
    | none => []

/-- [D] 2026-10-15: the messages never name a disconnection's cause: a reorg,
an operator's invalidation and a soft rejection publish alike. No function
from the event stream recovers the DisconnectCause. A view, never a rule. -/
theorem disconnect_cause_invisible (s : ChainState) (pre : Mempool) (ibd : Bool)
    (a b : DisconnectCause) (hash : BitVec 256) :
    chainEventEvents s pre ibd (.disconnected a hash) = chainEventEvents s pre ibd (.disconnected b hash) := rfl

/-- [SRC] 2026-10-15: the two sinks, src/init.cpp:1537-1562,2635-2646 and
src/net/net.cpp:2629-2653 at 6504a3af: FILE writes one pretty-printed JSON
file per record under the network data directory's `invalidtxs`
(file_sink.h:52; file_sink.cpp:25-27), ZMQ hands the compact JSON to the
invalidtx topic (zmq_sink.cpp:11-20). Views, never rules. -/
inductive Sink where
  | FILE | ZMQ
  deriving DecidableEq, Repr

/-- [SRC] 2026-10-15: the file name, `YYYY-MM-DD_HH-MM-SS_<txid>_<n>.json`
with the UTC wall time and the count of earlier files of that txid
(src/invalid_txn_sinks/file_sink.cpp:15-20,44-46 at 6504a3af). A view, never a rule. -/
def fileName (utcStamp txidHex : String) (earlier : Nat) : String :=
  utcStamp ++ "_" ++ txidHex ++ "_" ++ toString earlier ++ ".json"

/-- [SRC] 2026-10-15: the file sink writes the body's hex only for a txid's
earliest file and only when it fits the disk bound
(src/invalid_txn_sinks/file_sink.cpp:157-164 at 6504a3af). A view, never a rule. -/
def fileWritesHex (earlier : Nat) (fits : Bool) : Bool := earlier == 0 && fits

/-- [SRC] 2026-10-15: the ZMQ sink writes the hex only when the estimated
message fits `-invalidtxzmqmaxmessagesize` (src/invalid_txn_sinks/zmq_sink.cpp:13-17
at 6504a3af). A view, never a rule. -/
def zmqWritesHex (estimated maxMessageSize : Nat) : Bool := estimated ≤ maxMessageSize

/-- [SRC] 2026-10-15: the sink options' defaults, policy settings of the
node, never consensus: FILE's disk bound 3 GiB and eviction IGNORE_NEW, ZMQ's
message bound 500 MiB (src/invalid_txn_publisher.h:319-322; src/init.cpp:1545-1562
at 6504a3af). A view, never a rule. -/
def sinkDefaults : List (String × Nat) :=
  [("invalidtxfilemaxdiskusage", 3 * 1024 * 1024 * 1024),
   ("invalidtxzmqmaxmessagesize", 500 * 1024 * 1024)]

/-- [D] 2026-10-15: a later file of the same txid never carries the hex.
A view, never a rule. -/
theorem later_file_no_hex (earlier : Nat) (fits : Bool) (h : earlier ≠ 0) :
    fileWritesHex earlier fits = false := by
  simp [fileWritesHex, h]

end BsvChain.Views.Events
