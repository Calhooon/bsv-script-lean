# Double-spend notifications: the model, the run, the Teranode reading (#80)

Issue numbers on this page are the archived tracker's ([docs/GLOSSARY.md](GLOSSARY.md), "archived #n").

[D] 2026-10-15, on the box.
**A notification is never a verdict.** Everything on this page is node behavior and operator
settings: the attempt handler tells an endpoint that a transaction it watches was double spent,
and a node relays and posts a peer's report of blocks carrying a double spend. Neither decides
what is valid; the refusal of the double spend is #62's mempool machine, cited and never
re-decided. Reference bitcoin-sv v1.2.3 `6504a3aff65ba97c0f6c80962b033e35ecbfed4b`; Teranode
read at v0.16.0 `4edb60a40c6628ff0ef60231c2628efd7103fde5`. The settings: docs/PARAMETERS.md
section 8.12. The record: [docs/records/20261015-165715-s7-80-double-spend-s1.md](records/20261015-165715-s7-80-double-spend-s1.md).

## 1. The model

`lean/BsvChain/Wire/DoubleSpend.lean` [SRC], its laws `lean/BsvChain/Properties/DoubleSpend.lean`:

- **The notification output and the callback message.** An output is a notification output
  when its script is at least eleven bytes and begins `00 6a 04 64736e74` (`OP_FALSE OP_RETURN`,
  the protocol id `dsnt`; `src/script/script.cpp:174-179`); the earliest such output is the
  transaction's (`src/primitives/transaction.cpp:134-147`). The message is the push at byte seven
  (`src/double_spend/dscallback_msg.cpp:94-114`): a version byte (bit 0x80 IPv6, low five bits the
  protocol), the endpoint addresses (four or sixteen bytes), the inputs to watch (none listed:
  every input), its counts and inputs in the reference's **VARINT**, the MSB base-128 code with
  one subtracted from every digit but the last (`src/serialize.h:342-423`), not CompactSize;
  counts read at 64 bits, inputs at 32 (`src/double_spend/dscallback_msg.h:52-149`).
  `CallbackMsg.decode_encode`, `callbackOfScript_dsntScript`, `readVarInt64_write`,
  `readVarInt32_write` prove the round trips (`decode (encode m) = m`; the bytes direction
  measured, not proven); `varInt_2pow32_widths` shows the source's own table
  entry for 2^32 read at 64 bits and refused at 32.
- **The detector's events, a view of #62.** `acceptDetect` is `acceptWithTrace` with the
  detection read off the stopping stage (`acceptDetect_fst`): a refusal at the pool's conflict
  check (stage 5, `txn-mempool-conflict` 0x102, before any script; `src/validation.cpp:1147-1153`)
  or at the double-spend detector (stage 13, 0x102 or `txn-double-spend-detected` 0x12, after every
  script check; `src/validation.cpp:1478-1494`, `src/txn_double_spend_detector.cpp:11-58,111-138`),
  with the collided set (`src/txmempool.cpp:2257-2281`) and the scripts-checked flag
  (`src/validation.cpp:1482`). The handler hangs on the invalid-transaction publication of #84's
  vocabulary (`lean/BsvChain/Views/Events.lean`, `invalidEvent`, the `collidedWith` field), through
  the publisher's callback (`src/net/net.cpp:2653-2659`).
- **The handler** (`src/double_spend/dsattempt_handler.cpp:79-777`): the queue and its memory
  bound, the notice per collided transaction, the script check it runs itself when the admission
  had not, the endpoint loop (the count, the repeated address, the blacklist, the skip list, the
  slow tracker), the query `GET /dsnt/<protocol>/query/<txid>` and the proof
  `POST /dsnt/<protocol>/submit?txid=&n=&ctxid=&cn=` with the conflicting transaction's bytes
  (`src/rpc/client_config.cpp:87-117`, `src/rpc/http_request.cpp:46-53`,
  `src/rpc/http_request.h:76-103`), the `x-bsv-dsnt` header, two attempts, the fast and slow
  queues, the transactions remembered, the **time-limited blacklist**
  (`src/double_spend/time_limited_blacklist.h:20-114` over `src/limitedmap.h:14-50`).
- **The `dsdetected` message** (`src/double_spend/dsdetected_message.h:20-142`,
  `src/merkleproof.h:22-185`): its codec (`DSDetected.read_encode`), its checks
  (`src/double_spend/dsdetected_message.cpp:143-333`), and the node's handling
  (`src/net/net_processing.cpp:4452-4684`): the duplicate cache, the checks, the fork height
  (the census row `safeModeMaxForkDistance`), the headers, the relay to every peer but the sender,
  the webhook's JSON (`src/double_spend/dsdetected_message.cpp:93-141`, `src/merkleproof.cpp:44-72`).

## 2. THE THEOREM

`notification_only_after_detection`, `notification_conflict_after_validation`, `reach_invariant`,
`every_request_good` [D], axiom-clean (`propext`, `Classical.choice`, `Quot.sound`): every query
and every proof a processing step sends (`notification_conflict_after_validation`)
names a notice whose attempt is a completed refusal by #62's `acceptWithTrace` of a request whose
transaction is one side of the notice, the two sides on one outpoint, the enabled side carrying a
notification output; and either the refusal is the pool's conflict check (stage 5, 0x102),
reached before any script ran, and the handler's own check of the double-spend input passed
before it sent, or the refusal is the detector's (stage 13), reached after every earlier stage,
the script stage among them; every request of any reachable state, the slow queue's included,
carries a notice that is a detection's, of its conflict's shape, its check recorded passed
(`every_request_good`). `Detected` is existential: some state of #62's machine (pool, UTXO view,
settings, script oracle, detector observation) refuses the double spend with that detection, and
`Reach` queues any such detection, so the theorem binds a notice to a refusal #62's machine makes,
not to this node's own admission; the handler's own script check is an input (`Env.scriptCheck`),
not #62's oracle; the composed machine is owed. `Blacklist.add_hour`: an endpoint blacklisted at
`t` is held before `t + 3600` and not at or after it. `processDSDetected_sends`: the node sends
something only for a
message it read, had not seen, judged valid, found high enough, whose headers it accepted and
whose blocks it marked; to every peer but the sender, and to the webhook only when one is set.

## 3. The run [X]

`run_scenarios --dsnt` (`harness/src/scenarios/dsnt.rs`) at `5d1e312c`, the scenario
`corpus/scenarios/2026-10-15-double-spend-notify.md`: two fresh regtest instances of the node of
record, one link, the harness's test peer (`harness/peer/peer.py` over the reference's pinned
`mininode.py`) on each, a local HTTP receiver on the harness's port band.
`chaincheck --dsnt` (`lean/Test/DsntCheck.lean`): GREEN, 47 checks agree, 0 witnesses (the
record quotes every line and four negative controls, each RED with one witness). The run
observed, each as the model predicts: A refuses C1, C2 and C3 at stage 5 (`code 258`,
`checked 0`), checks each input's script itself, sends the query and the proof for E1 (method,
path and body equal to the model's), the query alone for E2 and blacklists 127.0.0.1 on the
missing header, skips E3 (`Skipping notification to blacklisted endpoint 127.0.0.1`), relays the
peer's `dsdetected` B to A to PA and never back to a sender, posts both webhooks with bodies
equal to the model's JSON byte for byte, and answers the repeat with its duplicate cache. Not
driven: the blacklist's expiry (a wall-clock hour; proven only), the slow queue, the timeouts,
the suspension score.

## 4. Findings

- **The issue's theorem sentence.** "A notification is emitted only for a conflict the detector
  saw after validation" holds literally of the detector's refusals only. In the common case the
  conflict is seen at stage 5, before the double spend's scripts run; the handler then validates
  the conflicting input itself before it notifies (`src/double_spend/dsattempt_handler.cpp:149-178,396-421`).
  `notification_conflict_after_validation` states the true form; the run's three attempts are all
  stage-5 refusals (`checked 0` in A's lines) [D] [X].
- [SRC] [X] **The node never originates `dsdetected` at the pin.** It reads, checks, relays and posts a
  peer's message (`src/net/net_processing.cpp:4573-4684`); no other site constructs one
  (`git grep -n 'DSDetected\b\|NetMsgType::DSDETECTED' 6504a3af -- src`, outside the tests and
  src/double_spend, names only src/net/net_processing.cpp:4452-4826 and src/protocol.cpp:118). So no mempool
  double spend puts a `dsdetected` on the wire; the run drives one from a peer.
- [SRC] [X] **The blacklist runs on the wall clock.** `TimeLimitedBlacklist` reads `system_clock`
  (`src/double_spend/time_limited_blacklist.h:20-23,74,95`), not the node's adjustable time: in
  the run the node's lines carry its mock time (2023) while the blacklist held on the receiver's
  wall clock (2026), so `setmocktime` cannot age an entry out.
- **A query answered without the header both blacklists the endpoint and marks the transaction
  notified** (`:482-489` then `:761-764`, `:644-649`): after the hour the endpoint is reachable
  again but that transaction is never notified again while it is remembered. [D] from source; the
  run shows the blacklist, the model the record.
- [D] Readings not executed: the proof's length field is read and never compared with the
  transaction (`src/merkleproof.h:105-115`); `ValidateDoubleSpends` counts a transaction that
  repeats one of its own outpoints as a double spend of its own block
  (`src/double_spend/dsdetected_message.cpp:228-273`); an IPv4-mapped IPv6 address and its IPv4
  address print the same endpoint key (`src/double_spend/dscallback_msg.cpp:116-130`), so they share
  a blacklist entry.

## 5. Teranode, a reading at `4edb60a4`

Teranode lacks both halves; spec/teranode-absences.md rows `tl.dsdetected` and
`tl.ds-attempt-callback` (#96) carry the absences with their searches, re-run for this page
(2026-10-15, the clone at the pin, `$BSV_SPEC_TERANODE_CLONE`, the maintainers' clone): `git -C $BSV_SPEC_TERANODE_CLONE grep -il -E '<word>' 4edb60a4` finds
no file for `dsdetected`, `dsattempt`, `dscallback`, `dsendpoint`, `dsnt` or `x-bsv-dsnt`. What it
has instead [SRC]: the second spend is refused at validation, `ErrTxConflicting` and
`ErrTxInvalidDoubleSpend` (`errors/Error_types.go:60,64`), answered on the propagation surface with
HTTP 409 (`services/propagation/Server.go:768-773`); the losing transaction is marked
`conflicting` in the UTXO store (row `rl.conflicting-record`); the rejection is gossiped to peers on
the rejected-transaction topic (`services/p2p/message_types.go:126-139`, `services/p2p/Server.go:1324,1350`;
row `rl.rejected-tx-gossip`), never to an endpoint a transaction declares, and no message reports
blocks carrying a double spend. So THE THEOREM has nothing to bind on Teranode: no notification
exists to be emitted. The measured leg (a double spend submitted to Teranode and its 409 observed)
waits on #66's cut 2.
