import BsvChain.Wire.P2P
import BsvChain.Merkle
import BsvChain.Mempool
import BsvScript.Standard

/-!
# Double-spend notifications (#80), 2026-10-15 [D]

**A notification is never a verdict.** Nothing in this module decides whether
a transaction or a block is valid. The reference's double-spend notifications
are node behavior with operator settings: a node that refuses a conflicting
transaction may tell the endpoint the original transaction declared in its
notification output (the attempt handler), and a node that receives a peer's
`dsdetected` message about blocks carrying a double spend checks it, relays it
and posts it to its own webhook. Every delay, size and count here is a policy
setting with its default and source (`DSConfig`; docs/PARAMETERS.md section
8.12), or a constant of the handler, named as such (rule 1). The refusal of
the double spend itself is #62's mempool machine (`BsvChain.Mempool`); this
module reads that machine's outcomes, it never re-decides them.

The parts: the reference's VARINT (the callback message's integer encoding,
not CompactSize); the notification output and the callback message it carries;
the detector's events as a view of #62's admission (`acceptDetect`, which is
`acceptWithTrace` with the detection read off the stopping stage); the attempt
handler (`DSAttemptHandler`): its queue, its notification choice, its script
check, its delivery to each endpoint (the query, the proof, the retries, the
fast and slow queues) and its time-limited blacklist; the `dsdetected` message
(its codec, its checks) and the node's handling of it (the duplicate cache, the
relay, the webhook post). #84's event vocabulary (`BsvChain.Views.Events`)
already names the publication the handler hangs on: the invalid-transaction
record of a completed refusal (`invalidEvent`, `acceptEvents`) whose
`collidedWith` field (`invalidFieldsOutsideMachine`) is the detector's set read
here; that vocabulary is cited, never repeated.

[SRC] bitcoin-sv v1.2.3 at 6504a3aff65ba97c0f6c80962b033e35ecbfed4b:
src/double_spend/dsattempt_handler.h:34-204, src/double_spend/dsattempt_handler.cpp:18-777,
src/double_spend/dscallback_msg.h:20-163, src/double_spend/dscallback_msg.cpp:94-130,
src/double_spend/dsdetected_message.h:20-142, src/double_spend/dsdetected_message.cpp:79-380,
src/double_spend/dsdetected_defaults.h:12-17, src/double_spend/time_limited_blacklist.h:20-114,
src/double_spend/dstxn_serialiser.cpp:86-106, src/limitedmap.h:14-50, src/limited_cache.h:9-40,
src/merkleproof.h:22-185, src/merkleproof.cpp:30-72, src/script/script.cpp:174-179,
src/script/script.h:104-133, src/primitives/transaction.cpp:134-147, src/serialize.h:342-427,
src/txmempool.cpp:2257-2281, src/txn_double_spend_detector.cpp:11-58,111-138,
src/validation.cpp:1142-1153,1478-1494,1733-1757,1786-1806, src/net/net.cpp:2653-2659,
src/net/net_processing.cpp:4452-4518,4570-4684,4826-4827, src/rpc/client_config.h:24-26,
src/rpc/client_config.cpp:87-159, src/rpc/http_request.cpp:28-53, src/rpc/http_request.h:76-103,
src/rpc/client.cpp:184-200, src/rpc/webhook_client.cpp:13,28-73, src/config.cpp:1702-1931,1985-2049,
src/init.cpp:1575-1645,2956-3027.
-/

namespace BsvChain.Wire.DoubleSpend
open BsvScript.Numbers BsvScript.Tx BsvScript.Hash BsvScript.Sighash BsvChain

/-! ## 1. The reference's VARINT -/

/-- [SRC] 2026-10-15: `WriteVarInt`'s digits before the last, the most significant
leading, each with the continuation bit 0x80 and one subtracted from the value
above it (src/serialize.h:342-364,379-394 at 6504a3af). -/
def varIntHigh (m : Nat) : Bytes :=
  (if h : m < 128 then [] else varIntHigh (m / 128 - 1)) ++ [m % 128 + 128]
termination_by m
decreasing_by omega

/-- [SRC] 2026-10-15: `WriteVarInt` (src/serialize.h:379-394 at 6504a3af): the
MSB base-128 encoding with one subtracted from every digit but the last; the
last byte has no continuation bit. 0 is `[0x00]`, 128 is `[0x80, 0x00]`. -/
def writeVarInt (n : Nat) : Bytes :=
  if n < 128 then [n] else varIntHigh (n / 128 - 1) ++ [n % 128]

/-- [SRC] 2026-10-15: `ReadVarInt<I>`'s loop (src/serialize.h:396-423 at
6504a3af): at most ten bytes (`maxSize`, :407); before each byte the 64-bit
accumulator above `overflow` (the type's maximum shifted right by seven, :405)
throws; the byte's low seven bits are shifted in (:414); a byte without the
continuation bit ends the read (:415-417), else the accumulator is incremented
in 64-bit arithmetic (:418). The fuel is the bytes left of the ten. -/
def readVarIntLoop (overflow : Nat) : Nat → Nat → Bytes → Option (Nat × Bytes)
  | 0, _, _ => none
  | _ + 1, _, [] => none
  | fuel + 1, n, b :: rest =>
    if n > overflow then none
    else
      let n' := (n * 128 + b % 128) % 2 ^ 64
      if b % 256 < 128 then some (n', rest)
      else readVarIntLoop overflow fuel ((n' + 1) % 2 ^ 64) rest

/-- [SRC] 2026-10-15: `ReadVarInt<uint64_t>`: overflow 2^57 - 1 (src/serialize.h:405-408 at 6504a3af). -/
def readVarInt64 (bs : Bytes) : Option (Nat × Bytes) := readVarIntLoop (2 ^ 57 - 1) 10 0 bs

/-- [SRC] 2026-10-15: `ReadVarInt<uint32_t>`: overflow 2^25 - 1 (src/serialize.h:405-408 at 6504a3af). -/
def readVarInt32 (bs : Bytes) : Option (Nat × Bytes) := readVarIntLoop (2 ^ 25 - 1) 10 0 bs

/-! ## 2. The notification output and the callback message -/

/-- [SRC] 2026-10-15: the notification output's leading seven bytes: `OP_FALSE
OP_RETURN`, a four-byte push, the protocol id `dsnt` (src/script/script.cpp:174-179 at 6504a3af). -/
def dsntTag : Bytes := [0x00, 0x6a, 0x04, 0x64, 0x73, 0x6e, 0x74]

/-- [SRC] 2026-10-15: `IsDSNotification`: at least eleven bytes and the tag
(src/script/script.cpp:174-179 at 6504a3af). Nothing after the tag is read here. -/
def isDSNotification (script : Bytes) : Bool :=
  decide (11 ≤ script.length) && script.take 7 == dsntTag

/-- [SRC] 2026-10-15: `TxnHasDSNotificationOutput`: the earliest output whose
script is a notification output (src/primitives/transaction.cpp:134-147 at 6504a3af). -/
def dsOutput (tx : Tx) : Option Nat := tx.outputs.findIdx? (fun o => isDSNotification o.scriptPubKey)

/-- [SRC] 2026-10-15: `DSCallbackMsg` (src/double_spend/dscallback_msg.h:20-163
at 6504a3af): the version byte (bit 0x80 the address family, the low five bits
the protocol version, :24-26,39-40), the endpoint addresses (four bytes each, or
sixteen for IPv6, network order, :55-105) and the inputs to watch, as indices
(:107-127). An empty input list means every input (dsattempt_handler.cpp:220-229). -/
structure CallbackMsg where
  version : Nat
  addrs : List Bytes
  inputs : List Nat
  deriving DecidableEq, Repr

/-- [SRC] 2026-10-15: `IP_VERSION_MASK` 0x80 (src/double_spend/dscallback_msg.h:25 at 6504a3af). -/
def CallbackMsg.isIPv6 (m : CallbackMsg) : Bool := 128 ≤ m.version % 256

/-- [SRC] 2026-10-15: `GetProtocolVersion`, the version byte under `PROTOCOL_VERSION_MASK`
0x1F (src/double_spend/dscallback_msg.h:26,40 at 6504a3af). -/
def CallbackMsg.protocolVersion (m : CallbackMsg) : Nat := m.version % 32

/-- [SRC] 2026-10-15: an address's width by the family bit (:69-82 at 6504a3af). -/
def addrWidth (version : Nat) : Nat := if 128 ≤ version % 256 then 16 else 4

/-- [SRC] 2026-10-15: the writer (src/double_spend/dscallback_msg.h:52-53,85-127
at 6504a3af): the version byte, a VARINT count and the addresses, a VARINT
count and each input as a VARINT. The writer copies four or sixteen bytes per
address; a shorter address is outside the writer's domain. -/
def CallbackMsg.encode (m : CallbackMsg) : Bytes :=
  headerWordBytes 1 m.version ++ writeVarInt m.addrs.length ++ m.addrs.flatten ++
    writeVarInt m.inputs.length ++ (m.inputs.map writeVarInt).flatten

/-- [SRC] 2026-10-15: the reader (src/double_spend/dscallback_msg.h:52-149 at
6504a3af): the version byte; a VARINT address count, zero refused (:58-64); the
addresses at the family's width; a VARINT input count; each input a 32-bit
VARINT (:113-118); trailing bytes refused (:129-148). -/
def CallbackMsg.decode (bs : Bytes) : Option CallbackMsg := do
  let (version, r1) ← readLE 1 bs
  let (na, r2) ← readVarInt64 r1
  if na = 0 then none else
  let (addrs, r3) ← readMany (readBytes (addrWidth version)) na r2
  let (ni, r4) ← readVarInt64 r3
  let (inputs, r5) ← readMany readVarInt32 ni r4
  if r5 = [] then pure { version, addrs, inputs } else none

/-- [SRC] 2026-10-15: `CScript << std::vector<uint8_t>`, the push writer
(src/script/script.h:104-133 at 6504a3af). -/
def pushData (d : Bytes) : Bytes :=
  (if d.length < 0x4c then [d.length]
   else if d.length ≤ 0xff then [0x4c, d.length]
   else if d.length ≤ 0xffff then [0x4d] ++ headerWordBytes 2 d.length
   else [0x4e] ++ headerWordBytes 4 d.length) ++ d

/-- [D] 2026-10-15: a notification output carrying a callback message: the
tag, then the message as one push (the layout `DSCallbackMsg(const CScript&)`
reads, src/double_spend/dscallback_msg.cpp:94-114 at 6504a3af). -/
def dsntScript (m : CallbackMsg) : Bytes := dsntTag ++ pushData m.encode

/-- [SRC] 2026-10-15: `DSCallbackMsg(const CScript&)` (src/double_spend/dscallback_msg.cpp:94-114
at 6504a3af): a notification output, then one instruction read at byte seven
(`GetOp`, src/script/script.h:165-200) whose data is the message; bytes after
that instruction are not read. A non-push instruction yields empty data, which
the reader refuses. -/
def callbackOfScript (script : Bytes) : Option CallbackMsg :=
  if !isDSNotification script then none
  else match BsvScript.Standard.getOp (script.drop 7) with
    | none => none
    | some (_, data, _) => CallbackMsg.decode data

/-- [SRC] 2026-10-15: `IPAddrToString` (src/double_spend/dscallback_msg.cpp:116-130 at
6504a3af), the endpoint's key in the blacklist, the skip list and the slow
tracker: an IPv4 address in dotted decimal. [D] An IPv6 address is keyed here
by its hex digits: `CNetAddr::ToStringIP`'s IPv6 text is not modelled, and an
IPv4-mapped IPv6 address prints as its IPv4 text there, so the two families
can share a key at the pin (not executed). -/
def endpointKey (addr : Bytes) : String :=
  match addr with
  | [a, b, c, d] => s!"{a}.{b}.{c}.{d}"
  | _ => "ipv6:" ++ hexEncode addr

/-! ## 3. The detector's events, a view of #62's admission -/

/-- [SRC] 2026-10-15: `CheckTxConflicts` (src/txmempool.cpp:2257-2281 at
6504a3af): the accepted spenders of the request's outpoints (`mapNextTx`), and
for a final request the held non-final spenders unless it finalises one of
them. The reference returns a set; the order here is the pool's and is not
observed. -/
def poolCollided (p : Mempool) (tx : Tx) (final : Bool) : List Tx :=
  let ids := tx.inputs.filterMap fun i =>
    (p.mapNextTx.find? (fun kv => kv.1 == OutPoint.ofInput i)).map (·.2)
  (p.accepted.filter fun e => ids.contains e.id).map (·.tx) ++
    (if final && !(nonFinalConflicts p tx).isEmpty && !finalisesExisting p tx then
      (nonFinalConflicts p tx).map (·.entry.tx) else [])

/-- [D] 2026-10-15: the concurrent transactions that hold one of the request's
outpoints among the detector's observed outpoints (`isAnyOfInputsKnownNL`,
src/txn_double_spend_detector.cpp:111-138 at 6504a3af): `others` are the
transactions behind `DetectorObservation`'s outpoints, which the observation
itself keeps as outpoints only. -/
def sharing (others : List Tx) (tx : Tx) (outpoints : List OutPoint) : List Tx :=
  others.filter fun t => t.inputs.any fun j =>
    outpoints.contains (OutPoint.ofInput j) &&
      tx.inputs.any (fun i => OutPoint.ofInput i == OutPoint.ofInput j)

/-- [SRC] 2026-10-15: where the detector saw the conflict. `conflictStage`: the
pool check of stage 5, before any script runs (src/validation.cpp:1147-1153);
`detectorConflict`: the same check repeated at the detector's insertion, after
every script check (src/validation.cpp:1481-1488, src/txn_double_spend_detector.cpp:39-42);
`detectorAttempt`: a concurrent spend still being validated
(src/validation.cpp:1489-1491, src/txn_double_spend_detector.cpp:49-51) at 6504a3af. -/
inductive Site where
  | conflictStage | detectorConflict | detectorAttempt
  deriving DecidableEq, Repr

/-- [SRC] 2026-10-15: the detector's event: the refused request (the double
spend), its channel, the transactions it collided with (the validation state's
`mCollidedWithTx`, src/consensus/validation.h:51,114-123), the site, whether the
scripts were checked (`fScriptsChecked`, set at src/validation.cpp:1482 only
after every script check, :47,110,129) and the refusal. The handler reads
exactly these (`HandleDoubleSpend`, src/double_spend/dsattempt_handler.cpp:89-146 at 6504a3af). -/
structure Detection where
  spender : Tx
  source : TxSource
  collided : List Tx
  site : Site
  scriptsChecked : Bool
  code : Nat
  reason : String
  deriving Repr

/-- [SRC] 2026-10-15: the detection read off the stopping stage of an
admission (the stage-5 and stage-13 refusals of `BsvChain.Mempool`); any other
outcome is no detection. The spender is the request's transaction, the one
the publisher publishes (`mTxInputData->GetTxnPtr()`, src/validation.cpp:1755-1756);
the collided set reads the pool and the finality the stopping stage saw. -/
def detection (observation : DetectorObservation) (others : List Tx) (request : TxRequest)
    (w : AdmissionWork) (outcome : TxOutcome) (trace : List AdmissionStage) : Option Detection :=
  let tx := request.tx
  match outcome, trace.getLast? with
  | .completed (.rejected (.node code) reason), some .conflict =>
    some { spender := tx, source := request.source, collided := poolCollided w.pool tx w.judgedFinal,
           site := .conflictStage, scriptsChecked := false, code, reason }
  | .completed (.rejected (.node code) reason), some .detector =>
    if code = 0x102 then
      some { spender := tx, source := request.source,
             collided := poolCollided w.pool tx w.judgedFinal ++ sharing others tx observation.committedSpends,
             site := .detectorConflict, scriptsChecked := true, code, reason }
    else
      some { spender := tx, source := request.source,
             collided := sharing others tx observation.validatingSpends,
             site := .detectorAttempt, scriptsChecked := true, code, reason }
  | _, _ => none

/-- [D] 2026-10-15: #62's admission (`acceptWithTrace`, step for step) with the
detector's event beside it (`acceptDetect_fst` in `BsvChain.Properties.DoubleSpend`
proves its admission component is `acceptWithTrace`'s). [SRC] as `acceptWithTrace`. -/
def acceptDetect (p : Mempool) (utxo : UtxoSet) (cfg : NodeConfig)
    (ctx : AdmissionContext) (lists : FrozenLists) (oracle : ScriptOracle)
    (observation : DetectorObservation) (others : List Tx) (request : TxRequest) :
    (Mempool × TxOutcome × List AdmissionStage) × Option Detection :=
  let cfg := request.configOverride.getD cfg
  if request.source == .p2p && p.recentRejects.contains (BsvScript.Sighash.txid request.tx) then
    ((p, .suppressed, []), none)
  else
    let w : AdmissionWork := { pool := p, view := mempoolView p utxo, request }
    let (w, result, trace) := beforeDetector cfg ctx lists oracle w
    match result with
    | some outcome => ((finishAdmission w outcome, outcome, trace), detection observation others request w outcome trace)
    | none =>
      let (w, result, suffix) := runAdmissionStages
        [(.detector, stageDetector observation), (.commit, stageCommit cfg ctx)] w
      let outcome := result.getD (.unverifiable "commit returned no outcome")
      ((if suffix.contains .commit then finishCommit w outcome else finishAdmission w outcome,
        outcome, trace ++ suffix), detection observation others request w outcome (trace ++ suffix))

/-! ## 4. The handler's settings -/

/-- [SRC] 2026-10-15: `NotificationLevel` (src/double_spend/dsattempt_handler.h:39-44 at 6504a3af). -/
inductive NotifyLevel where
  | none | standard | all
  deriving DecidableEq, Repr

/-- [SRC] 2026-10-15: the operator's settings of the attempt handler and of
the `dsdetected` webhook, each a policy setting (docs/PARAMETERS.md section
8.12; defaults src/double_spend/dsattempt_handler.h:46-63,
src/rpc/client_config.h:24-26, src/double_spend/dsdetected_defaults.h:16; launch
src/init.cpp:2956-3027; bounds src/config.cpp:1702-1931,1985-2049 at 6504a3af).
Sizes are bytes (`-dsattemptqueuemaxmemory` and `-dsdetectedwebhookmaxtxnsize`
are read in MiB, src/init.cpp:3013,3025); timeouts are seconds. -/
structure DSConfig where
  level : NotifyLevel := .none
  fastTimeout : Nat := 5
  slowTimeout : Nat := 60
  slowRatePerHour : Nat := 3
  endpointPort : Nat := 80
  blacklistSize : Nat := 1000
  skipList : List String := []
  maxEndpoints : Nat := 3
  txnRemember : Nat := 1000
  fastThreads : Nat := 2
  slowThreads : Nat := 2
  queueMaxMemory : Nat := 4096 * 1024 * 1024
  /-- `-dsdetectedwebhookurl` split into host, port (80 when absent) and path; unset by default. -/
  webhook : Option (String × Nat × String) := none
  webhookMaxTxnSize : Nat := 100 * 1024 * 1024
  deriving Repr

/-- [SRC] 2026-10-15: the handler's constants, never settings: an endpoint's
blacklist term `ENDPOINT_BLACKLIST_DURATION` 3600 s (:28), the protocol version
`SUPPORTED_PROTOCOL_VERSION` 1 (:31), the response header `x-bsv-dsnt` (:34),
`MAX_PROOF_SUBMIT_ATTEMPTS` 2 (:37) (src/double_spend/dsattempt_handler.cpp at
6504a3af); the webhook client's `NumHTTPRetries` 3 (src/rpc/webhook_client.cpp:13). -/
def blacklistDuration : Int := 60 * 60
def supportedProtocolVersion : Nat := 1
def dsntHeader : String := "x-bsv-dsnt"
def maxProofSubmitAttempts : Nat := 2
def webhookRetries : Nat := 3

/-! ## 5. The time-limited blacklist -/

/-- [SRC] 2026-10-15: `TimeLimitedBlacklist<std::string>` over a `limitedmap`
from the endpoint to its expiry (src/double_spend/time_limited_blacklist.h:20-114,
src/limitedmap.h:14-50 at 6504a3af). The entries keep insertion order; the
map's eviction takes the least expiry, the earliest inserted among equals (the
multimap's `begin`). -/
structure Blacklist where
  maxSize : Nat
  entries : List (String × Int) := []
  deriving DecidableEq, Repr

/-- [D] 2026-10-15: the earliest entry holding the least expiry. -/
def leastExpiry : List (String × Int) → Option (String × Int)
  | [] => none
  | e :: es => match leastExpiry es with
    | none => some e
    | some m => if m.2 < e.2 then some m else some e

/-- [SRC] 2026-10-15: `limitedmap::insert` (src/limitedmap.h:41-50 at
6504a3af): a new key is inserted; when the map is then over its size, the
least-valued entry among the OLD ones is erased (the reverse map's `begin` is
read before the new entry joins it), so an insertion never evicts itself. -/
def Blacklist.insert (b : Blacklist) (item : String) (expiry : Int) : Blacklist :=
  if b.entries.any (·.1 == item) then b
  else
    let kept := if b.entries.length + 1 > b.maxSize then
      match leastExpiry b.entries with
      | some m => b.entries.erase m
      | none => b.entries
    else b.entries
    { b with entries := kept ++ [(item, expiry)] }

/-- [SRC] 2026-10-15: `Add(item, expiry)` with `updateIfExists` true
(src/double_spend/time_limited_blacklist.h:41-64 at 6504a3af): an existing
entry is erased and the item inserted again. -/
def Blacklist.add (b : Blacklist) (item : String) (expiry : Int) : Blacklist :=
  ({ b with entries := b.entries.filter (·.1 != item) }).insert item expiry

/-- [SRC] 2026-10-15: `IsBlacklisted` (src/double_spend/time_limited_blacklist.h:86-107
at 6504a3af): an entry whose expiry is after now; an expired entry is erased. -/
def Blacklist.check (b : Blacklist) (item : String) (now : Int) : Bool × Blacklist :=
  match b.entries.find? (·.1 == item) with
  | none => (false, b)
  | some (_, expiry) =>
    if now < expiry then (true, b) else (false, { b with entries := b.entries.filter (·.1 != item) })

/-! ## 6. The attempt handler -/

/-- [SRC] 2026-10-15: a queued attempt: the detection and its memory usage
(`RecursiveDynamicUsage` of the transactions, src/double_spend/dsattempt_handler.cpp:115-121
at 6504a3af; an observation, supplied). The sender is the detection's. -/
structure Queued where
  detection : Detection
  usage : Nat
  deriving Repr

/-- [SRC] 2026-10-15: the script check of the double spend's input when the
admission did not run it (`ValidateDoubleSpend`, src/double_spend/dsattempt_handler.cpp:149-178
at 6504a3af): passed, invalid (a failed script) or cancelled (a timeout under
`maxNonStdTxnValidationDuration`, :165, or a policy limit). -/
inductive ScriptCheck where
  | passed | invalid | cancelled
  deriving DecidableEq, Repr

/-- [SRC] 2026-10-15: `NotificationDetails` (src/double_spend/dsattempt_handler.h:96-105
at 6504a3af): the notification-enabled transaction and its watched input, the
conflicting transaction and its input, the double spend's input, the callback
message; with the detection it came from and the script check's verdict
that let it be sent (`check`, set by `verdictLoop`; a notice not yet checked
carries `cancelled`). -/
structure Notice where
  detection : Detection
  enabled : Tx
  enabledInput : Nat
  conflicting : Tx
  conflictingInput : Nat
  spendInput : Nat
  msg : CallbackMsg
  check : ScriptCheck := .cancelled
  deriving Repr

/-- [SRC] 2026-10-15: a slow-queue task: the endpoint, its retry budget and the notice
(src/double_spend/dsattempt_handler.cpp:585-588,613,634 at 6504a3af). -/
structure SlowTask where
  endpoint : String
  retries : Nat
  notice : Notice
  deriving Repr

/-- [SRC] 2026-10-15: the handler's state (src/double_spend/dsattempt_handler.h:172-197
at 6504a3af): the submit queue and its size, the transactions already notified
(a `limitedmap` keyed by id and valued by arrival, so the oldest is evicted),
the blacklist, and the slow queue's tasks. The suspension and slow-endpoint
leaky buckets are inputs (`Env`), not state here. -/
structure HandlerState where
  queue : List Queued := []
  queueSize : Nat := 0
  notified : List TxId := []
  blacklist : Blacklist
  slow : List SlowTask := []
  deriving Repr

/-- [SRC] 2026-10-15: the constructor (src/double_spend/dsattempt_handler.cpp:79-86 at 6504a3af). -/
def HandlerState.init (cfg : DSConfig) : HandlerState := { blacklist := { maxSize := cfg.blacklistSize } }

/-- [SRC] 2026-10-15: `HandleDoubleSpend` (src/double_spend/dsattempt_handler.cpp:89-146
at 6504a3af), reached from the publisher's callback for a refusal with a
nonempty collided set (src/net/net.cpp:2653-2659; the publication
src/validation.cpp:1733-1757,1799-1803): nothing at level none, nothing for an
empty set, nothing when the queue would pass its memory bound; else the
attempt joins the queue. -/
def handle (cfg : DSConfig) (h : HandlerState) (d : Detection) (usage : Nat) : HandlerState :=
  if cfg.level = .none then h
  else if d.collided.isEmpty then h
  else if h.queueSize + usage > cfg.queueMaxMemory then h
  else { h with queue := h.queue ++ [⟨d, usage⟩], queueSize := h.queueSize + usage }

/-- [SRC] 2026-10-15: an endpoint's answer to one request, as the client
reports it: a timeout (`CConnectionTimeout`), another failure (no connection,
a malformed reply: an exception), or a status and the `x-bsv-dsnt` header's
text if present (src/rpc/client.cpp:184-200; the header read
src/double_spend/dsattempt_handler.cpp:59-75 at 6504a3af). -/
inductive Reply where
  | timeout | failure
  | response (status : Nat) (dsnt : Option String)
  deriving DecidableEq, Repr

/-- [D] 2026-10-15: `boost::lexical_cast<bool>` of the header's text
(src/double_spend/dsattempt_handler.cpp:72 at 6504a3af): "1" and "0"; any other
text throws. A draft of the library's rule, not read from the pin. -/
def castBool : String → Option Bool
  | "1" => some true
  | "0" => some false
  | _ => none

/-- [D] 2026-10-15: what the handler observes and does not own: the clock
(the blacklist's `system_clock`, seconds), the sender's suspension bucket and
each endpoint's slow bucket (`LeakyBucket`, src/leaky_bucket.h; their state is
observed, not modelled), each double-spend input's coin (`GetScriptDetails`,
src/double_spend/dsattempt_handler.cpp:280-314 at 6504a3af: `none` when the coin
is not found, else whether its script is standard), the script check, and the
endpoints' replies in order (a request past the list reads a failure). -/
structure Env where
  now : Int
  suspended : Bool := false
  slowEndpoint : String → Bool := fun _ => false
  coinStandard : Tx → Nat → Option Bool
  scriptCheck : Tx → Nat → ScriptCheck
  replies : List Reply := []

/-- [SRC] 2026-10-15: what the handler does that a test can see: a query (`GET`)
and a proof (`POST`, the conflicting transaction's bytes) to an endpoint at the
configured port, each under its notice; an endpoint skipped (blacklisted,
skip-listed, a duplicate, past the count); a slow-queue task; an endpoint
blacklisted; a transaction recorded as notified; a peer penalised (the ban
score) or its suspension score raised (src/double_spend/dsattempt_handler.cpp:316-777
at 6504a3af). -/
inductive Effect where
  | query (notice : Notice) (endpoint : String) (port : Nat) (path : String) (timeout : Nat)
  | submit (notice : Notice) (endpoint : String) (port : Nat) (path : String) (body : Bytes) (timeout : Nat)
  | skipped (endpoint : String) (why : String)
  | slowQueued (endpoint : String) (retries : Nat)
  | blacklisted (endpoint : String) (expiry : Int)
  | recorded (id : TxId)
  | misbehaving (score : Nat)
  | suspensionRaised
  deriving Repr

/-- [D] 2026-10-15: the notice an HTTP request carries, if it is one. -/
def Effect.notice? : Effect → Option Notice
  | .query n .. | .submit n .. => some n
  | _ => none

/-- [D] 2026-10-15: a display-order id, the hash's bytes reversed in hex (`uint256::ToString`). -/
def displayId (id : Bytes) : String := hexEncode id.reverse

/-- [SRC] 2026-10-15: the query path, `/dsnt/<protocol>/query/<txid>`
(src/rpc/client_config.cpp:104-107, src/rpc/http_request.cpp:46-53 at 6504a3af). -/
def queryPath (n : Notice) : String :=
  s!"/dsnt/{n.msg.protocolVersion}/query/{displayId (txid n.enabled)}"

/-- [SRC] 2026-10-15: the proof path with its four parameters in order
(src/double_spend/dsattempt_handler.cpp:720-726, src/rpc/http_request.h:84-97 at
6504a3af); every value is hex or decimal, which the URI encoder leaves as is. -/
def submitPath (n : Notice) : String :=
  s!"/dsnt/{n.msg.protocolVersion}/submit?txid={displayId (txid n.enabled)}&n={n.enabledInput}&ctxid={displayId (txid n.conflicting)}&cn={n.conflictingInput}"

/-- [SRC] 2026-10-15: the delivery's working state across one notice: the
blacklist, the notified list, the slow queue, the remaining replies, the
effects in order. -/
structure Wk where
  blacklist : Blacklist
  notified : List TxId
  slow : List SlowTask
  replies : List Reply
  effects : List Effect
  deriving Repr

def Wk.emit (k : Wk) (e : Effect) : Wk := { k with effects := k.effects ++ [e] }

def Wk.next (k : Wk) : Reply × Wk :=
  match k.replies with
  | [] => (.failure, k)
  | r :: rs => (r, { k with replies := rs })

/-- [SRC] 2026-10-15: `AddToBlacklist`: until now plus an hour
(src/double_spend/dsattempt_handler.cpp:316-321 at 6504a3af). -/
def Wk.ban (k : Wk) (now : Int) (ep : String) : Wk :=
  { k with blacklist := k.blacklist.add ep (now + blacklistDuration) }.emit (.blacklisted ep (now + blacklistDuration))

/-- [SRC] 2026-10-15: `RecordNotifiedTxn` (src/double_spend/dsattempt_handler.cpp:769-777
at 6504a3af): a new id is remembered; past the setting the oldest is evicted
(the `limitedmap` keeps the highest arrival numbers, src/limitedmap.h:41-50). -/
def Wk.record (cfg : DSConfig) (k : Wk) (id : TxId) : Wk :=
  if k.notified.contains id then k
  else
    let ns := k.notified ++ [id]
    { k with notified := if ns.length > cfg.txnRemember then ns.drop 1 else ns }.emit (.recorded id)

/-- [SRC] 2026-10-15: one `QueryAndSubmitProof` (src/double_spend/dsattempt_handler.cpp:698-767,
the query `SubmitQuery` :467-511, the reply's header :59-75 at 6504a3af).
Returns the working state and the call's ending: `ok success wantsProof retry`,
or an escaping exception (`timeout`, or `error`), with `wantsProof` true and
`retry` false as the call set them before its exchanges (:709-710). -/
inductive Ending where
  | ok (success wantsProof retry : Bool)
  | timeout
  | error
  deriving DecidableEq, Repr

def attempt (cfg : DSConfig) (now : Int) (n : Notice) (ep : String) (timeout : Nat) (k : Wk) : Ending × Wk :=
  let k := k.emit (.query n ep cfg.endpointPort (queryPath n) timeout)
  let (r, k) := k.next
  match r with
  | .timeout => (.timeout, k)
  | .failure => (.error, k)
  | .response _ none => (.ok false false false, k.ban now ep)
  | .response status (some text) =>
    match castBool text with
    | none => (.error, k)
    | some wants =>
      if status = 400 then (.ok false false false, k)
      else if status ≠ 200 then (.ok false false false, k.ban now ep)
      else if !wants then (.ok false false false, k)
      else
        let k := k.emit (.submit n ep cfg.endpointPort (submitPath n) (serTx n.conflicting) timeout)
        let (r, k) := k.next
        match r with
        | .timeout => (.timeout, k)
        | .failure => (.error, k)
        | .response _ none => (.error, k.ban now ep)
        | .response status (some text) =>
          match castBool text with
          | none => (.error, k)
          | some wants =>
            if status ≠ 200 then
              if !wants then (.ok false false false, k) else (.ok false true true, k)
            else (.ok true true false, k)

/-- [SRC] 2026-10-15: the fast path's loop for one endpoint
(src/double_spend/dsattempt_handler.cpp:617-649 at 6504a3af): while not sent,
retry asked and attempts left; a timeout ends it, raises the slow tracker and
queues a slow task with the attempts left before this one's decrement
(:628-635); another exception ends it (`retry` false); at the end a sent proof or
an endpoint that wants none records the transaction (:644-649). -/
def fastLoop (cfg : DSConfig) (now : Int) (n : Notice) (ep : String) :
    Nat → Bool → Bool → Bool → Wk → Wk
  | count + 1, false, _, true, k =>
    match attempt cfg now n ep cfg.fastTimeout k with
    | (.ok s w r, k) => fastLoop cfg now n ep count s w r k
    | (.timeout, k) =>
      fastLoop cfg now n ep count false true false
        ({ k with slow := k.slow ++ [({ endpoint := ep, retries := count + 1, notice := n } : SlowTask)] }.emit (.slowQueued ep (count + 1)))
    | (.error, k) => fastLoop cfg now n ep count false true false k
  | _, success, wants, _, k =>
    if success || !wants then k.record cfg (txid n.enabled) else k

/-- [SRC] 2026-10-15: `SendNotificationSlow` (src/double_spend/dsattempt_handler.cpp:660-696
at 6504a3af): the same loop at the slow timeout with the task's budget; any
exception ends the task without a record (:687-695). -/
def slowLoop (cfg : DSConfig) (now : Int) (n : Notice) (ep : String) :
    Nat → Bool → Bool → Bool → Wk → Wk
  | count + 1, false, _, true, k =>
    match attempt cfg now n ep cfg.slowTimeout k with
    | (.ok s w r, k) => slowLoop cfg now n ep count s w r k
    | (_, k) => k
  | _, success, wants, _, k =>
    if success || !wants then k.record cfg (txid n.enabled) else k

/-- [SRC] 2026-10-15: `SendNotification`'s loop over the message's addresses
(src/double_spend/dsattempt_handler.cpp:556-657 at 6504a3af): the count is
raised before every other test and past the setting ends the loop (:575-579);
a repeated address is skipped (:590-599); then the blacklist (which erases an
expired entry), the skip list, the slow tracker (a slow task with two
attempts, :610-614), else the fast loop. -/
def sendLoop (cfg : DSConfig) (env : Env) (n : Notice) :
    List Bytes → Nat → List String → Wk → Wk
  | [], _, _, k => k
  | a :: rest, count, seen, k =>
    if count + 1 > cfg.maxEndpoints then k.emit (.skipped (endpointKey a) "count")
    else
      let ep := endpointKey a
      if seen.contains ep then sendLoop cfg env n rest (count + 1) seen (k.emit (.skipped ep "duplicate"))
      else
        let (black, bl) := k.blacklist.check ep env.now
        let k := { k with blacklist := bl }
        let k :=
          if black then k.emit (.skipped ep "blacklist")
          else if cfg.skipList.contains ep then k.emit (.skipped ep "skiplist")
          else if env.slowEndpoint ep then
            { k with slow := k.slow ++ [({ endpoint := ep, retries := maxProofSubmitAttempts, notice := n } : SlowTask)] }.emit (.slowQueued ep maxProofSubmitAttempts)
          else fastLoop cfg env.now n ep maxProofSubmitAttempts false false true k
        sendLoop cfg env n rest (count + 1) (seen ++ [ep]) k

/-- [SRC] 2026-10-15: the notification-enabled side and the conflicting side:
the pooled transaction when it carries a notification output, else the double
spend when it does (src/double_spend/dsattempt_handler.cpp:187-208 at
6504a3af); with the output's index and whether the enabled side is the double
spend. -/
def sides (pooled spender : Tx) : Option (Tx × Nat × Tx × Bool) :=
  match dsOutput pooled, dsOutput spender with
  | some o, _ => some (pooled, o, spender, false)
  | none, some o => some (spender, o, pooled, true)
  | none, none => none

/-- [SRC] 2026-10-15: the (watched input, conflicting input) pairs on one
outpoint in the loops' order (src/double_spend/dsattempt_handler.cpp:231-240 at
6504a3af); a watched index past the inputs is skipped (:234-235). -/
def conflictPairs (enabled conflicting : Tx) (watched : List Nat) : List (Nat × Nat) :=
  watched.flatMap fun i =>
    match enabled.inputs[i]? with
    | some ei => (List.range conflicting.inputs.length).filterMap fun c =>
        match conflicting.inputs[c]? with
        | some ci => if OutPoint.ofInput ci == OutPoint.ofInput ei then some (i, c) else none
        | none => none
    | none => []

/-- [SRC] 2026-10-15: the double spend's input of a pair: the watched input when
the double spend is the enabled side, else the conflicting one
(src/double_spend/dsattempt_handler.cpp:242 at 6504a3af). -/
def spendIndex (isSpender : Bool) (i c : Nat) : Nat := if isSpender then i else c

/-- [SRC] 2026-10-15: the inputs to check: the message's, or every input of the
enabled side when the message lists none (src/double_spend/dsattempt_handler.cpp:220-229 at 6504a3af). -/
def watchedInputs (msg : CallbackMsg) (enabled : Tx) : List Nat :=
  if msg.inputs.isEmpty then List.range enabled.inputs.length else msg.inputs

/-- [SRC] 2026-10-15: `GetNotificationDetails` (src/double_spend/dsattempt_handler.cpp:182-277
at 6504a3af): the pooled transaction if it has a notification output, else the
double spend if it has one; a message of a protocol above 1 is ignored; the
watched inputs (all when the list is empty) in the message's order, the
conflicting inputs in order; the earliest pair on one outpoint whose double-spend
input's coin is found, and standard when only standard inputs are checked.
A malformed callback message throws outside the pair loop's handler
(:211-212 against the `try` at :243-269), so it ends the whole attempt: `.error`. -/
def noticeFor (env : Env) (d : Detection) (pooled : Tx) (stdOnly : Bool) : Except Unit (Option Notice) :=
  match sides pooled d.spender with
  | none => .ok none
  | some (enabled, out, conflicting, isSpender) =>
    match (enabled.outputs[out]?).map (·.scriptPubKey) with
    | none => .ok none
    | some script =>
      match callbackOfScript script with
      | none => .error ()
      | some msg =>
        if msg.protocolVersion > supportedProtocolVersion then .ok none
        else
          let watched := watchedInputs msg enabled
          let ok := fun (ic : Nat × Nat) =>
            match env.coinStandard d.spender (spendIndex isSpender ic.1 ic.2) with
            | none => false
            | some standard => !stdOnly || standard
          match (conflictPairs enabled conflicting watched).find? ok with
          | none => .ok none
          | some (i, c) =>
            .ok (some { detection := d, enabled, enabledInput := i, conflicting, conflictingInput := c,
                        spendInput := spendIndex isSpender i c, msg })

/-- [SRC] 2026-10-15: `ValidateDoubleSpend`'s verdict for a notice: passed when
the admission already checked the scripts (:154-158), else the check's
(src/double_spend/dsattempt_handler.cpp:149-178,399-400 at 6504a3af). -/
def checkOf (env : Env) (n : Notice) : ScriptCheck :=
  if n.detection.scriptsChecked then .passed else env.scriptCheck n.detection.spender n.spendInput

/-- [SRC] 2026-10-15: the verdict loop of `ProcessDoubleSpend`
(src/double_spend/dsattempt_handler.cpp:396-459 at 6504a3af): a passed check
(or scripts already checked by the admission) sends unless the
notification-enabled transaction was already notified (:404-420); a failed
script penalises the sender at the ban score and ends the processing
(:424-431); a cancelled check raises the sender's suspension score (:432-457). -/
def verdictLoop (cfg : DSConfig) (env : Env) (banScore : Nat) : List Notice → Wk → Wk
  | [], k => k
  | n :: rest, k =>
    match checkOf env n with
    | .passed =>
      let n := { n with check := .passed }
      let k := if k.notified.contains (txid n.enabled) then k else sendLoop cfg env n n.msg.addrs 0 [] k
      verdictLoop cfg env banScore rest k
    | .invalid => k.emit (.misbehaving banScore)
    | .cancelled => verdictLoop cfg env banScore rest (k.emit .suspensionRaised)

/-- [SRC] 2026-10-15: the notices of one queued attempt
(src/double_spend/dsattempt_handler.cpp:364-394 at 6504a3af): standard inputs
only at level standard or while the sender is suspended; one notice at most
per collided transaction, in the set's order; a malformed message ends the
attempt with no notice at all (the handler's outer `catch`, :461-464). -/
def noticesLoop (env : Env) (d : Detection) (stdOnly : Bool) : List Tx → Option (List Notice)
  | [] => some []
  | t :: ts =>
    match noticeFor env d t stdOnly with
    | .error _ => none
    | .ok o => (noticesLoop env d stdOnly ts).map (o.toList ++ ·)

def notices (cfg : DSConfig) (env : Env) (d : Detection) : List Notice :=
  (noticesLoop env d (cfg.level = .standard || env.suspended) d.collided).getD []

/-- [SRC] 2026-10-15: `ProcessDoubleSpend` (src/double_spend/dsattempt_handler.cpp:323-465
at 6504a3af): the queue's head is popped and its size released; its notices
are checked and sent. The ban score is the relay setting's (`-banscore`,
docs/PARAMETERS.md section 8.6). -/
def process (cfg : DSConfig) (banScore : Nat) (h : HandlerState) (env : Env) : HandlerState × List Effect :=
  match h.queue with
  | [] => (h, [])
  | q :: rest =>
    let k : Wk := { blacklist := h.blacklist, notified := h.notified, slow := h.slow,
                    replies := env.replies, effects := [] }
    let k := verdictLoop cfg env banScore (notices cfg env q.detection) k
    ({ queue := rest, queueSize := h.queueSize - min h.queueSize q.usage, notified := k.notified,
       blacklist := k.blacklist, slow := k.slow }, k.effects)

/-- [SRC] 2026-10-15: one slow-queue task run (src/double_spend/dsattempt_handler.cpp:660-696
at 6504a3af), the oldest task taken. -/
def processSlow (cfg : DSConfig) (h : HandlerState) (env : Env) : HandlerState × List Effect :=
  match h.slow with
  | [] => (h, [])
  | t :: rest =>
    let k : Wk := { blacklist := h.blacklist, notified := h.notified, slow := rest,
                    replies := env.replies, effects := [] }
    let k := slowLoop cfg env.now t.notice t.endpoint t.retries false false true k
    ({ h with notified := k.notified, blacklist := k.blacklist, slow := k.slow }, k.effects)

/-! ## 7. The `dsdetected` message -/

/-- [SRC] 2026-10-15: a merkle proof node: its type (only 0 is accepted here)
and a 32-byte hash (src/merkleproof.h:26-45 at 6504a3af). -/
structure ProofNode where
  kind : Nat
  value : Bytes
  deriving DecidableEq, Repr

/-- [SRC] 2026-10-15: `MerkleProof` (src/merkleproof.h:22-165 at 6504a3af): the
flags, the index, the transaction's length field (read and not checked against
the transaction, :105-115), the transaction or its id, the target and the
nodes. With a transaction the id is the transaction's (:113-114). -/
structure MerkleProof where
  flags : Nat
  index : Nat
  txLen : Nat
  tx : Option Tx
  txId : Bytes
  target : Bytes
  nodes : List ProofNode
  deriving Repr

/-- [SRC] 2026-10-15: a node's serialization, the type byte then the hash
(src/merkleproof.h:32-38 at 6504a3af). -/
def ProofNode.encode (n : ProofNode) : Bytes := headerWordBytes 1 n.kind ++ n.value

def ProofNode.read (bs : Bytes) : Option (ProofNode × Bytes) := do
  let (kind, r1) ← readLE 1 bs
  let (value, r2) ← readBytes 32 r1
  pure ({ kind, value }, r2)

/-- [SRC] 2026-10-15: the proof's writer (src/merkleproof.h:100-137 at
6504a3af): the flags byte, the index as CompactSize, the length field and the
transaction when it carries one (else the 32-byte id), the target, the nodes. -/
def MerkleProof.encode (p : MerkleProof) : Bytes :=
  headerWordBytes 1 p.flags ++ compactSize p.index ++
    (match p.tx with
     | some t => compactSize p.txLen ++ serTx t
     | none => p.txId) ++
    p.target ++ compactSize p.nodes.length ++ (p.nodes.map ProofNode.encode).flatten

/-- [SRC] 2026-10-15: the proof's reader (src/merkleproof.h:100-137 at
6504a3af): flag bit 0x01 selects a transaction (its length field read and
kept, the transaction read by its own reader) over an id. [D] The CompactSize
bound `MAX_SIZE` (src/serialize.h:297-299,336-338) is left out, as in the
model's transaction reader (`decodeTxPrefix_serTx`'s docstring). -/
def MerkleProof.read (bs : Bytes) : Option (MerkleProof × Bytes) := do
  let (flags, r1) ← readLE 1 bs
  let (index, r2) ← readVarInt r1
  let (txLen, tx, txId, r3) ← if flags % 2 = 1 then do
      let (len, ra) ← readVarInt r2
      let (t, rb) ← decodeTxPrefix ra
      pure (len, some t, txid t, rb)
    else do
      let (id, ra) ← readBytes 32 r2
      pure (0, none, id, ra)
  let (target, r4) ← readBytes 32 r3
  let (count, r5) ← readVarInt r4
  let (nodes, r6) ← readMany ProofNode.read count r5
  pure ({ flags, index, txLen, tx, txId, target, nodes }, r6)

/-- [SRC] 2026-10-15: `BlockDetails` (src/double_spend/dsdetected_message.h:29-54
at 6504a3af): the headers from the block holding the transaction back to the
earliest block after the common ancestor, and the proof of the transaction in
the earliest-listed header's block. -/
structure BlockDetails where
  headers : List BlockHeader
  proof : MerkleProof
  deriving Repr

/-- [SRC] 2026-10-15: `BlockDetails::Validate`, run while reading: flags 5,
a nonzero index, every node of type 0 (src/double_spend/dsdetected_message.cpp:79-91 at 6504a3af). -/
def proofShapeOk (p : MerkleProof) : Bool :=
  p.flags == 5 && p.index != 0 && p.nodes.all (·.kind == 0)

def BlockDetails.encode (b : BlockDetails) : Bytes :=
  compactSize b.headers.length ++ (b.headers.map BlockHeader.encode).flatten ++ b.proof.encode

/-- [SRC] 2026-10-15: the reader (src/double_spend/dsdetected_message.h:31-43
at 6504a3af): the headers' vector, refused when empty; the proof, refused
unless its shape passes `Validate`. -/
def BlockDetails.read (bs : Bytes) : Option (BlockDetails × Bytes) := do
  let (n, r1) ← readVarInt bs
  let (headers, r2) ← readMany BlockHeader.decodePrefix n r1
  if headers.isEmpty then none else
  let (proof, r3) ← MerkleProof.read r2
  if !proofShapeOk proof then none else
  pure ({ headers, proof }, r3)

/-- [SRC] 2026-10-15: `DSDetected` (src/double_spend/dsdetected_message.h:20-115
at 6504a3af): the version (only 1, `MSG_VERSION`, :24) and the blocks. -/
structure DSDetected where
  version : Nat
  blocks : List BlockDetails
  deriving Repr

/-- [SRC] 2026-10-15: the writer: the 16-bit version, the blocks' vector
(src/double_spend/dsdetected_message.h:73-98 at 6504a3af). -/
def DSDetected.encode (m : DSDetected) : Bytes :=
  headerWordBytes 2 m.version ++ compactSize m.blocks.length ++ (m.blocks.map BlockDetails.encode).flatten

/-- [SRC] 2026-10-15: the reader (src/double_spend/dsdetected_message.h:73-98
at 6504a3af): a version other than 1 refused, fewer than two blocks refused.
The node reads the message from the payload's front and does not test for
bytes after it (src/net/net_processing.cpp:4581-4597), so the rest is returned. -/
def DSDetected.read (bs : Bytes) : Option (DSDetected × Bytes) := do
  let (version, r1) ← readLE 2 bs
  if version ≠ 1 then none else
  let (n, r2) ← readVarInt r1
  let (blocks, r3) ← readMany BlockDetails.read n r2
  if blocks.length < 2 then none else
  pure ({ version, blocks }, r3)

/-! ## 8. The `dsdetected` checks -/

/-- [D] 2026-10-15: a 32-byte internal-order hash as the header's word. -/
def word256 (bs : Bytes) : BitVec 256 := BitVec.ofNat 256 (leNat bs)

/-- [SRC] 2026-10-15: `FormsChain`: each header's previous hash is the next
header's hash (src/double_spend/dsdetected_message.cpp:335-357 at 6504a3af). -/
def formsChain : List BlockHeader → Bool
  | [] => false
  | [_] => true
  | a :: b :: rest => a.prevBlock == b.hash && formsChain (b :: rest)

/-- [D] 2026-10-15: `ContainsDuplicateHeaders` compares boost hashes of the
header fields (src/double_spend/dsdetected_message.cpp:34-44,359-371 at
6504a3af); read here as equality of headers, the hash's collisions not modelled. -/
def duplicateHeaders (hs : List BlockHeader) : Bool := hs.eraseDups.length != hs.length

/-- [SRC] 2026-10-15: `MerkleProof::Verify`: the root recomputed from the id,
the nodes and the index (cut to 32 bits by the call) equals the target
(src/merkleproof.cpp:30-42; src/consensus/merkle.cpp:291-310 at 6504a3af). -/
def MerkleProof.verify (p : MerkleProof) : Bool :=
  BsvChain.computeRootFromBranch p.txId (p.nodes.map (·.value)) (p.index % 2 ^ 32) == p.target

/-- [SRC] 2026-10-15: `IsValid(const BlockDetails&)`, in its order
(src/double_spend/dsdetected_message.cpp:143-207 at 6504a3af): headers, a
transaction, not the coinbase, a merkle-root target, a chain, no duplicate
header, the proof verifies, the target is the earliest-listed header's root. -/
def BlockDetails.valid (b : BlockDetails) : Bool :=
  !b.headers.isEmpty && b.proof.flags % 2 == 1 && b.proof.index != 0 &&
    (b.proof.flags / 2) % 4 == 2 && formsChain b.headers && !duplicateHeaders b.headers &&
    b.proof.verify &&
    match b.headers.head? with
    | some h => word256 b.proof.target == h.merkleRoot
    | none => false

/-- [SRC] 2026-10-15: `ValidateCommonAncestor`: every block's last-listed
header names the same previous block (src/double_spend/dsdetected_message.cpp:214-225 at 6504a3af). -/
def commonAncestor (m : DSDetected) : Bool :=
  match m.blocks.map (fun b => (b.headers.getLast?).map (·.prevBlock)) with
  | [] => true
  | a :: rest => rest.all (· == a)

/-- [SRC] 2026-10-15: `AreTxsUnique` (src/double_spend/dsdetected_message.cpp:275-287 at 6504a3af). -/
def txsUnique (m : DSDetected) : Bool :=
  let ids := m.blocks.map (·.proof.txId)
  ids.eraseDups.length == ids.length

/-- [SRC] 2026-10-15: `ValidateDoubleSpends` (src/double_spend/dsdetected_message.cpp:228-273
at 6504a3af): every (block, outpoint) pair over every input; the pairs whose
outpoint occurs more than once; at least as many such pairs as blocks and
exactly every block among them. A transaction that repeats one of its own
outpoints counts its own block. -/
def doubleSpends (m : DSDetected) : Bool :=
  let pairs := (m.blocks.zipIdx).flatMap fun (b, i) =>
    match b.proof.tx with
    | some t => t.inputs.map fun inp => (i, OutPoint.ofInput inp)
    | none => []
  let dup := (pairs.filter fun p => (pairs.filter (·.2 == p.2)).length > 1).map (·.1)
  decide (dup.length ≥ m.blocks.length) && dup.eraseDups.length == m.blocks.length

/-- [SRC] 2026-10-15: `IsValid(const DSDetected&)` in its order
(src/double_spend/dsdetected_message.cpp:289-333 at 6504a3af). -/
def DSDetected.valid (m : DSDetected) : Bool :=
  decide (m.blocks.length ≥ 2) && m.blocks.all BlockDetails.valid && commonAncestor m &&
    txsUnique m && doubleSpends m

/-! ## 9. The node's handling of `dsdetected` -/

/-- [SRC] 2026-10-15: what `ProcessDoubleSpendMessage` reads from the chain
(src/net/net_processing.cpp:4452-4518 at 6504a3af): the common ancestor's height
(`none` when unknown), the best header's height, whether every header is
accepted (`AcceptBlockHeader`, the header machine's verdict) and whether every
last-listed header's block index exists for the status update. -/
structure ChainView where
  ancestorHeight : BitVec 256 → Option Nat
  bestHeaderHeight : Nat
  headersAccepted : Bool
  statusUpdated : Bool

/-- [SRC] 2026-10-15: `ValidateForkHeight` with `MaxForkLength`: the longest
fork's ancestor height plus its length plus the safe-mode fork distance above
the best header (src/net/net_processing.cpp:4499-4518,
src/double_spend/dsdetected_message.cpp:373-380 at 6504a3af); the distance is
the census row `safeModeMaxForkDistance` (docs/PARAMETERS.md section 8.2). -/
def forkHeightOk (maxForkDistance : Nat) (cv : ChainView) (m : DSDetected) : Bool :=
  let longest := m.blocks.foldl (fun acc b => if acc.headers.length < b.headers.length then b else acc)
    (m.blocks.headD { headers := [], proof := { flags := 0, index := 0, txLen := 0, tx := none, txId := [], target := [], nodes := [] } })
  match longest.headers.getLast? with
  | none => false
  | some last => match cv.ancestorHeight last.prevBlock with
    | none => false
    | some h => decide (h + longest.headers.length + maxForkDistance > cv.bestHeaderHeight)

/-- [D] 2026-10-15: the duplicate cache's key: the version and the blocks up to
order (`sort_hasher` hashes each fork and sorts the hashes,
src/double_spend/dsdetected_message.cpp:62-77 at 6504a3af); the key is the
encoded blocks sorted, the boost hash's collisions not modelled. -/
def cacheKey (m : DSDetected) : List Bytes :=
  (m.blocks.map BlockDetails.encode).mergeSort (fun a b => decide (a.length < b.length) || (a.length == b.length && decide (leNat a ≤ leNat b)))

/-- [SRC] 2026-10-15: the duplicate cache, `limited_cache` of 1000 keys: a
ring that overwrites its oldest slot when full (src/limited_cache.h:9-40;
`cache_size` src/net/net_processing.cpp:4602-4603 at 6504a3af). -/
structure DSDCache where
  keys : List (List Bytes) := []
  deriving Repr

def dsdCacheSize : Nat := 1000

def DSDCache.insert (c : DSDCache) (k : List Bytes) : DSDCache :=
  { keys := (if c.keys.length < dsdCacheSize then c.keys else c.keys.drop 1) ++ [k] }

/-- [SRC] 2026-10-15: the endings of `ProcessDoubleSpendMessage`
(src/net/net_processing.cpp:4573-4684 at 6504a3af), each with its penalty:
unreadable (10), a duplicate (none), invalid (10), a fork too low (10), headers
refused (none), status not updated (none), or relayed. -/
inductive DSDOutcome where
  | unreadable | duplicate | invalid | forkTooLow | headersRefused | statusFailed | relayed
  deriving DecidableEq, Repr

/-- [SRC] 2026-10-15: the penalty of each ending, `misbehaviour_penalty` 10
(src/net/net_processing.cpp:4580,4593-4595,4620-4621,4630-4631 at 6504a3af). -/
def DSDOutcome.penalty : DSDOutcome → Nat
  | .unreadable | .invalid | .forkTooLow => 10
  | _ => 0

/-- [SRC] 2026-10-15: what the handling sends: the message to a peer (every
peer but the sender, by association, :4486-4497,4657-4666), and the webhook's
JSON post when a URL is set (:4668-4677) at 6504a3af. -/
inductive DSDEffect where
  | relay (peer : Nat) (payload : Bytes)
  | webhook (host : String) (port : Nat) (path : String) (body : String)
  deriving DecidableEq, Repr

/-! ### The webhook's JSON -/

/-- [D] 2026-10-15: a JSON string of hex or ASCII (no escapes are needed for these values). -/
def jstr (s : String) : String := "\"" ++ s ++ "\""

/-- [D] 2026-10-15: a JSON object's opening brace, written as a character so the axiom leg's string
reader reads every literal one way (an open brace alone in a string literal reads
two ways to it). -/
def jopen : String := String.singleton '{'

/-- [SRC] 2026-10-15: a signed 32-bit word as UniValue writes an `int`. -/
def int32Text (v : Nat) : String :=
  let i := toInt32 (v % 2 ^ 32)
  if i < 0 then "-" ++ toString i.natAbs else toString i.toNat

/-- [SRC] 2026-10-15: one header's object (src/double_spend/dsdetected_message.cpp:112-128
at 6504a3af): the version as a signed int, the hashes in display order, the
time, bits and nonce as unsigned numbers. -/
def headerJson (h : BlockHeader) : String :=
  jopen ++ jstr "version" ++ ":" ++ int32Text h.version.toNat ++ "," ++
    jstr "hashPrevBlock" ++ ":" ++ jstr (displayId (headerWordBytes 32 h.prevBlock.toNat)) ++ "," ++
    jstr "hashMerkleRoot" ++ ":" ++ jstr (displayId (headerWordBytes 32 h.merkleRoot.toNat)) ++ "," ++
    jstr "time" ++ ":" ++ toString h.time.toNat ++ "," ++
    jstr "bits" ++ ":" ++ toString h.bits.toNat ++ "," ++
    jstr "nonce" ++ ":" ++ toString h.nonce.toNat ++ "}"

/-- [SRC] 2026-10-15: `MerkleProof::ToJSON` (src/merkleproof.cpp:44-72 at
6504a3af): the index; the transaction's hex when it carries one no larger than
the webhook's size setting (`GetTotalSize`, its serialized size), else the id;
the target type `merkleRoot`; the target; the nodes. -/
def proofJson (maxTxnSize : Nat) (p : MerkleProof) : String :=
  let txOrId := match p.tx with
    | some t => if (serTx t).length ≤ maxTxnSize then hexEncode (serTx t) else displayId p.txId
    | none => displayId p.txId
  jopen ++ jstr "index" ++ ":" ++ toString p.index ++ "," ++ jstr "txOrId" ++ ":" ++ jstr txOrId ++ "," ++
    jstr "targetType" ++ ":" ++ jstr "merkleRoot" ++ "," ++ jstr "target" ++ ":" ++ jstr (displayId p.target) ++ "," ++
    jstr "nodes" ++ ":[" ++ ",".intercalate (p.nodes.map fun n => jstr (displayId n.value)) ++ "]}"

/-- [SRC] 2026-10-15: `DSDetected::ToJSON` (src/double_spend/dsdetected_message.cpp:93-141
at 6504a3af) as UniValue's compact writer prints it, with the JSON post's
trailing CR LF (src/rpc/http_request.cpp:28-34): the version, then per block
the last-listed header's hash (`divergentBlockHash`), the headers and the proof. -/
def DSDetected.json (maxTxnSize : Nat) (m : DSDetected) : String :=
  let block (b : BlockDetails) : String :=
    jopen ++ (match b.headers.getLast? with
      | some h => jstr "divergentBlockHash" ++ ":" ++ jstr (displayId (headerWordBytes 32 h.hash.toNat)) ++ ","
      | none => "") ++
    jstr "headers" ++ ":[" ++ ",".intercalate (b.headers.map headerJson) ++ "]," ++
    jstr "merkleProof" ++ ":" ++ proofJson maxTxnSize b.proof ++ "}"
  jopen ++ jstr "version" ++ ":" ++ toString m.version ++ "," ++ jstr "blocks" ++ ":[" ++
    ",".intercalate (m.blocks.map block) ++ "]}\r\n"

/-- [SRC] 2026-10-15: `ProcessDoubleSpendMessage` (src/net/net_processing.cpp:4573-4684
at 6504a3af), in its order: read (a failure penalises), the duplicate cache
(the key inserted before any check, :4601-4616), `IsValid`, the fork height,
the headers, the status update; then the relay to every peer but the sender,
with the message as read, and the webhook post. -/
def processDSDetected (cfg : DSConfig) (maxForkDistance : Nat) (cv : ChainView) (c : DSDCache)
    (sender : Nat) (peers : List Nat) (payload : Bytes) : DSDCache × DSDOutcome × List DSDEffect :=
  match DSDetected.read payload with
  | none => (c, .unreadable, [])
  | some (m, _) =>
    let key := cacheKey m
    if c.keys.contains key then (c, .duplicate, [])
    else
      let c := c.insert key
      if !m.valid then (c, .invalid, [])
      else if !forkHeightOk maxForkDistance cv m then (c, .forkTooLow, [])
      else if !cv.headersAccepted then (c, .headersRefused, [])
      else if !cv.statusUpdated then (c, .statusFailed, [])
      else
        let relays := (peers.filter (· != sender)).map fun p => DSDEffect.relay p m.encode
        let hook := match cfg.webhook with
          | some (host, port, path) => [DSDEffect.webhook host port path (m.json cfg.webhookMaxTxnSize)]
          | none => []
        (c, .relayed, relays ++ hook)

end BsvChain.Wire.DoubleSpend
