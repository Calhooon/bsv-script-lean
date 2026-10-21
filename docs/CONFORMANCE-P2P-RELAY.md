# The P2P layer as a parameterized machine (#78)

Issue numbers on this page are the archived tracker's ([docs/GLOSSARY.md](GLOSSARY.md), "archived #n").

[M] 2026-10-15. **Nothing on this page is a
validity rule.** The P2P layer decides what a node hears and when: what it announces, to whom, what it asks for,
what it answers with `reject`, when it stops listening to a peer. Whether a transaction or a block is valid is the
mempool's and the chain's (#62, #64), an explicit input here. Every node setting below is policy, with its default
and its source in [docs/PARAMETERS.md section 8.6](PARAMETERS.md#86-auxiliary-p2p-relay-settings-78) (rule 1). The
reference is bitcoin-sv v1.2.3 at `6504a3aff65ba97c0f6c80962b033e35ecbfed4b` (`[SRC]` throughout); Teranode is read at
v0.16.0 `4edb60a40c6628ff0ef60231c2628efd7103fde5` in section 5.

## 1. The formats (`lean/BsvChain/Wire/P2P.lean`)

`[SRC]` The header of 24 bytes (magic, a twelve-byte command, a 32-bit length, the leading four bytes of the
payload's double SHA-256; `src/protocol.h:68-86,131-191`) and the extended header of 44 for a payload above
2^32 - 1 bytes (the command `extmsg`, the length field 0xffffffff, a zero checksum, then the real command and a
64-bit length; `src/protocol.h:93-119`, `src/protocol.cpp:208-241`); the reader (`src/protocol.cpp:244-276`) and the
frame reader (`src/net/net_message.cpp:12-53`); the caps (`src/protocol.cpp:63-99`: `protoconf` 1 MiB, `tx` and
`datareftx` the consensus transaction-size bound, `getblocktxn` an estimate, the block-like commands the block
size, every other command the receive setting, 2 MiB by default); the thirty-eight command names
(`src/protocol.cpp:16-53`); the payloads of `inv`, `getdata`, `notfound`, `reject`, `ping`, `pong`, `protoconf` and
`version`; the reject codes on the wire and the validator's internal codes that never reach it.

`[D]` Theorems (`lean/BsvChain/Properties/P2P.lean`, sorry-free, in the axiom walk): `unframe_frame`, **the framing
round trip** (four bytes of magic, a command the frame carries, any payload below 2^64 bytes: the frame reads back
the command and the payload and leaves the stream's rest untouched, through the basic header and its checksum or
the extended one); `frame_length` (24 or 44 bytes of header); `vocabulary_frames` (every command but `extmsg` is
one the frame carries) and `extmsg_not_framed` (a basic header whose command begins with `extmsg` is read as an
extended one, `src/protocol.cpp:259-266`); the payload codecs' round trips `decodeInv_encodeInv`,
`Reject.decode_encode`, `decodeNonce_encode`, `Protoconf.decode_encode`, `Version.decode_encode`. The caps:
`frame_valid` (the writer's header for a command the frame carries and a payload within its command's cap passes the
reader's validity check, `src/protocol.cpp:174-190,329-365`), and by evaluation at the run's caps (a block size of
1000001, the rest at their defaults): `ping` at 2 MiB within its cap and at 2 MiB + 1 over it, the latter being
step s8's 24 bytes read back (`s8_header_read`, `s8_header_oversized`); `protoconf` at 1 MiB and 1 MiB + 1;
`getblocktxn` at its estimate of 27930 bytes and one above; `block` and `hdrsen` at the block size and one above;
`tx` at the consensus bound and one above; a basic header with the length field 0xffffffff and an extended header
of 2^32 bytes each read back from their bytes (`basic_header_max_read`, `extended_header_read`).

**Finding (rule 15).** The registered list `allNetMessageTypes` has thirty-seven names and omits `revokemid`
(`src/protocol.cpp:107-121`), which the comment above it (`:103-106`) says the list keeps in step with the
declarations; the per-command byte counters of `getpeerinfo` are keyed by that list. `registered_omits_revokemid`
states it. Recorded, never repaired.

## 2. The machine (`lean/BsvChain/Wire/Relay.lean`)

`[SRC]` Per peer: the inventory known to it (`filterInventoryKnown`, the ideal set here), the transactions queued
for its next announcement (`mInvList`), the requests queued (`mapAskFor`) and in flight (`indexAskFor`), its relay
flag, fee filter and loaded filter, its ban mark and its disconnect flag; the score is the sum of the node's
recorded increments, as `nMisbehavior` starts at 0 (`src/net/node_state.h:56`) and is written only by `Misbehaving`
(`src/net/net_processing.cpp:620`). Per node: the propagator's queue, the relay memory that answers `getdata`, the
pools and the orphans as the inventory test reads them (`src/net/net_processing.cpp:930-961`), the ban list and the
log of increments. The transitions: `inv` (`:2454-2532`), `tx` with the mempool's verdict as an input
(`:3351-3408`; `src/validation.cpp:1786-1932,2005-2137`), an orphan's retry (`src/txn_validator.cpp:695-724`), the
RPC's acceptance (`src/rpc/rawtransaction.cpp:1682`), the propagator's pass (`src/txn_propagator.cpp:136-175`;
`src/net/net.cpp:836-878`), a peer's flush (`src/net/net_processing.cpp:5536-5674`) and request pass (`:5782-5843`),
`getdata` (`:1392-1430,1468-1479`), `Misbehaving` (`:610-634`), the send pass's ban step (`:4900-4919`), and the four
bans with no increment: a bad message start (`:5029-5041`), a header over its cap or malformed
(`src/net/net_message.cpp:22-36`, `src/net/association.cpp:396-401`), a stream moved across addresses
(`src/net/net.cpp:3401-3406`), and the operator's `setban` (`src/rpc/net.cpp:745-746`). Time is abstracted: the
timers become explicit transitions, taken in the order a run observes.

`[D]` Theorems (`lean/BsvChain/Properties/Relay.lean`): the ban and the framing in the form that holds at the pin;
the announcement for each of the machine's three acceptances, queued under any load and announced under any load,
qualified as the pin qualifies it (a peer that relays transactions, passes its fee filter and loaded filter, and is
not known to have it, `src/net/net.cpp:852-876`; "not seen" is the machine's `known`, the ideal set the rolling
filter approximates):

- **Announcement.** Queued: `accepted_queued_for_unseen` (a peer's `tx`, every peer but the sender),
  `rpcAccepted_queued_for_unseen` (`sendrawtransaction`) and `retryOrphan_accepted_queued_for_unseen` (an orphan
  accepted on retry): the next propagator's pass queues the transaction for every such peer. Flushed:
  `pending_announced_within`: an id at index `i` of a peer's queue is in the `inv` of that peer's
  `(i / broadcastMax + 1)`-th flush, the flushes of that peer following one another with no other
  transition of the node between them, for
  `broadcastMax` above 0 (`src/net/net_processing.cpp:5539-5570`, `SendTxnInventory`'s fetch at `:5543`). Announced, whatever was queued before:
  `accepted_announced_within`, `rpcAccepted_announced_within`, `retryOrphan_announced_within`; on an idle node the
  next flush is exactly one `inv` naming it (`accepted_announced_when_idle`). Never to a peer known to have it, the
  sender included: `known_never_queued` and `accepted_never_back_to_sender`.
- **The ban.** `ban_sound_run`: along any run from a node with no marks and no ban for misbehavior, every peer marked
  for a ban has recorded increments summing to the threshold or more, and every ban entry for misbehavior names such
  a peer. **Finding (the issue's sentence).** "A ban is reached only through recorded misbehavior increments" is
  false of the ban list at the pin: the four direct causes above ban with no increment, the node recording the
  reason "node misbehaving" for three of them. `ban_without_increment` is the witness by evaluation; the run's step
  s8 is the witness on a node. The theorem names the cause in each entry (`BanCause`) and states the true form.
- **Framing** is `unframe_frame` (section 1); the caps and the extended header at their boundaries are section 1's
  `frame_valid` and the decided lemmas beside it.

Beside them: `ibd_inv_requests_nothing` (the initial block download requests nothing, `:2518-2520`);
`relay_off_offered_nothing` (a peer whose version asked for no transactions is offered none,
`src/net/net.cpp:852-856`); `dataref_never_queued` (`:3576-3578`); `step_rejects_on_wire` (no transition sends an
internal code or a reason over 111 bytes, `src/validation.cpp:1940-1950`); `local_never_banned_by_score` (a local peer
is disconnected, never banned, for its score, `src/net/net_processing.cpp:4911-4913`).

Out of the machine, named: block announcements by `inv` and `headers` and the header sync (the chain layer; #79's
compact blocks are their own functions, section 7); the `mempool` request's
answers; the bloom filter's matching (an explicit input); the 50000-entry rolling filter's false positives; the
streams and associations; the validation's time budgets (#71); the re-request delay of a second announcer
(`mapAlreadyAskedFor`, `src/net/net.cpp:3290-3310`; `askedFor` is recorded, never read); `Ban`'s early return on a
longer existing entry (`src/net/net.cpp:553-558`); the in-flight index's cap (`:3274-3276`) and its erase on a `tx`
(`src/net/net_processing.cpp:3377`).

## 3. The two-node run

`[X]` [The scenario](../corpus/scenarios/2026-10-15-p2p-relay-two-node.md) on two fresh regtest instances (one link,
B dialing A once; the reference's test peer logging on each), eight steps; `chaincheck --p2p` runs the machine over
the scenario's stimuli and compares three ways (declared, machine, node). At `ca3855b6`: 8 of 8 steps agree, 81
checks, 0 witnesses ([record](records/20261015-125403-s7-78-p2p-machine-s1.md); the receipt replayed by the chain leg
from `corpus/p2p/2026-10-15-relay-two-node.receipt.json`). Since the lens fixes the checker also derives
step s8's header from the bytes sent and checks every command a logging peer receives, nine checks more: the run
again at `79955c61` on a fresh pair of the node of record (sha256 `ea73a708d277d88487a5d8ffc97e2b859937b8428387fc117b07f4add88b1421`, its banner, the test peer and the
ports in the receipt) gives **8 of 8 steps agree, 90 checks, 0 witnesses; 37 received frames read back and written
again byte for byte through the Lean codec, 21 of them through a payload codec as well**
([record](records/20261015-135113-s7-78-p2p-machine-s1.md), with seven negative controls each turning it RED or
ERROR); the corpus receipt agrees in the chain leg (GREEN in the record; its count is not quoted), and its frames are
`corpus/p2p/2026-10-15-relay-frames.jsonl` (`chaincheck --p2p-frames`). The download gate,
a relay A to B (61 bytes of `inv`, 61 of `getdata`, 215 of `tx`, none back), an orphan's parent fetched from the
sender, an internal code kept off the wire, a reject with a score of 100 that disconnects a local peer without a
ban, and a ban with no increment, each as the machine predicts.

## 4. What the reference's machine is measured against

The corpus is the spec's judge (rule 4): the run above is one implementation (the reference at the pin) on one
corpus (the eight steps). No other implementation's P2P layer has been run against the machine.

## 5. Teranode's P2P, the reading half

`[M]` 2026-10-15, read at Teranode v0.16.0 `4edb60a4` (`git show` at the tag), never run. The bridge's wire codec,
its message mapping and its behaviors beside the reference's are [#98's page](CONFORMANCE-TERANODE-BRIDGE.md) (its
sections 1 and 2, rows B1 to B16); they are cited here, not repeated. The absences are
[spec/teranode-absences.md](../spec/teranode-absences.md)'s rows `tl.orphan-pool`, `tl.compact-blocks` and
`rl.rejected-tx-gossip`.

| the reference's machine | `services/p2p` `[SRC]` | `services/legacy` `[SRC]` | reading `[D]` |
|---|---|---|---|
| the frame (section 1) | none: libp2p GossipSub topics carrying JSON messages (`services/p2p/message_types.go:62-134`: node status, block, subtree, rejected transaction) | go-wire `v1.2.11` (#98 section 0) | the machine's framing theorem binds the bridge only through go-wire, not a pin of `docs/PROVENANCE.md` section 1a (#98's Finding) |
| per-peer transaction inventory: known, requested, in flight | none: no transaction is announced or requested on the p2p topics | the bridge's peer and `haveInventory` (#98 row 4, B4) | the p2p service has no state the machine's peer refines |
| announcement to every peer not known to have it | blocks and subtrees to the mesh, a per-topic seen-hash cache of 10000 entries (`services/p2p/seen_hash_cache.go:9-34`) | B5 (from the txmeta topic, batched each second), B7 (rebroadcast) | `accepted_queued_for_unseen` has no counterpart on the p2p service; on the bridge the queue is fed from Kafka, not from its own acceptance (#98 section 3) |
| the reject vocabulary | the rejected-transaction topic (`message_types.go:134`), a gossip the reference lacks | B10: every code `0x10` | `step_rejects_on_wire` has no counterpart: the bridge flattens the codes |
| the orphan's parent fetched | none | B8, B9 | |
| the score and the ban | one registry in the blockchain service: points per reason, a decay of 1 point a minute, a threshold of 100, a ban of 24 hours, the score reset when a ban expires (`services/blockchain/peer_registry.go:173-200,761-848`; `settings/settings.go:560-561`); the operator's `BanPeer` bypasses the score (`services/p2p/ban_reasons.go:24-28`) | btcd's dynamic score: a persistent part and a transient part halving every 60 seconds (`services/legacy/connmgr/dynamicbanscore.go:14-20,121-150`); a ban only above the threshold, strictly (`services/legacy/peer_server.go:742`), against the reference's at or above (`src/net/net_processing.cpp:622`); a whitelisted peer never scored (`peer_server.go:718-721`); three scoring sites (`:1414`, `:1696`, `:1929`) | `ban_sound_run` does not transfer: with a decay the score is not the sum of the recorded increments, and at exactly the threshold the bridge does not ban where the reference marks the peer (`peer_server.go:1929-1930` scores 100 and disconnects without a ban) |
| the initial block download gate | the FSM's state (#98 B4) | B4: transaction `inv` acted on only while RUNNING | the gate's shape differs: the reference drops the request, the bridge drops the entry |

**The measured leg waits.** A run with one node a Teranode (#98 section 4's mixed scenario) needs #66's cut 2 (the
Teranode instance with the legacy service on, held for the maintainers' decision); until then every row above is a reading,
`[D]` against `[SRC]`, and a disagreement the run finds is a witness filed against the reading (rule 4).

**Compact blocks (#79), the reading half.** `[M]` 2026-10-15, read at Teranode v0.16.0 `4edb60a4` (`git show` at
the tag), never run. Neither service has them: `git grep -il 'cmpctblock\|sendcmpct\|compactblock\|shorttxid'
4edb60a4 -- '*.go'` returns no file ([spec/teranode-absences.md](../spec/teranode-absences.md)'s row
`tl.compact-blocks`). The bridge reads the wire through go-wire `v1.2.11` (Teranode's `go.mod:205`; read from the
module cache, not a pin of `docs/PROVENANCE.md` section 1a, #98's Finding): its message table knows `sendcmpct` (the
constant `CmdSendcmpct`, go-wire `message.go:87`, and its case in `makeEmptyMessage`, `:120`, `:220-221`, at v1.2.11,
h1 `jVbatio…`) and none of `cmpctblock`, `getblocktxn` or `blocktxn`, which it reads as an unhandled command (the
default branch, `:229-230`); the peer's dispatch has no case for the
`sendcmpct` message, so the reference's `sendcmpct` at the handshake (`src/net/net_processing.cpp:1971-1981`) lands in
its default branch, logged and dropped (`services/legacy/peer/peer.go:2129-2130`). The bridge neither sends
`sendcmpct` nor asks for `MSG_CMPCT_BLOCK`, so the reference never sends it a compact block: it answers one only to
that request (`src/net/net_processing.cpp:1331-1350`) and announces one only to a peer that asked with the
announcement flag (`:852-860`, `:5378-5410`). A compact-block message that did reach the bridge would be a read
error, answered outside regtest's loopback with `reject` malformed and a disconnection
(`services/legacy/peer/peer.go:1925-1957`; the regtest allowance `:1364-1390`). Reading `[D]`: section 7's
reconstruction has no counterpart on either Teranode service; a legacy peer still delivers the whole block.

## 6. Owed

- The mixed two-node run of section 5 (#66's cut 2), and #98's theorem stated over this machine.
- A pin of go-wire `v1.2.11` in `docs/PROVENANCE.md` section 1a (#98's Finding), before the bridge's framing is
  related to `unframe_frame`.
- Block announcements by `inv` and `headers` as transitions of this machine (#79's compact blocks are section 7's
  functions, not yet transitions of it), and double-spend notifications (#80).
- `RelayConfig` and `CapInputs` into `NodeConfig` (the census debt named in docs/PARAMETERS.md section 8.6).

## 7. Compact blocks (#79)

`[M]` 2026-10-15. **Nothing here is a validity
rule**: a compact block decides how a node receives a block it may partly hold; whether the block is valid stays the
reference's `CheckBlock` (#63's `checkBlock`), which the reconstruction ends in. Every setting is policy or a relay
constant, with its default and source in [docs/PARAMETERS.md section 8.11](PARAMETERS.md#811-auxiliary-compact-block-settings-79).

`[SRC]` The encoding and the procedure (`lean/BsvChain/Wire/CompactBlocks.lean`): the short id, SipHash-2-4
(`src/hash.cpp:104-236`) of the transaction's id keyed by the leading two little-endian words of the single SHA-256 of
the header and the 64-bit nonce, cut to 48 bits (`src/blockencodings.cpp:65-82`; BIP152 lines 100-104, the document's
raw form read at <https://raw.githubusercontent.com/bitcoin/bips/master/bip-0152.mediawiki> on 2026-10-15T16:01:41Z;
`master` is mutable, the pin is the sha256 `b710fa0a4ab9ec92d84884adc77df25b974add79dbc23b8158bf3a791e47cd85`); the payloads of `cmpctblock`
(`CBlockHeaderAndShortTxIDs`, `src/blockencodings.h:155-225`), `getblocktxn` and `blocktxn`
(`BlockTransactionsRequest`, `BlockTransactions`, `:36-115`, the indices differentially encoded) and `sendcmpct`
(`src/net/net_processing.cpp:1971-1981,2428-2449`); the sender's message (the coinbase prefilled, a short id for every
other transaction, `src/blockencodings.cpp:18-63`); `InitData` (`:84-242`: the prefilled placed, each short id on the
next empty position, an equal pair of short ids FAILED, the pool's and the extra transactions' matches with the
source's early exit); the missing set (`:244-252`; `src/net/net_processing.cpp:3919-3935`); `FillBlock`
(`src/blockencodings.cpp:254-316`); the answers of both sides (`src/net/net_processing.cpp:2734-2843,3623-3700,3744-4030`).

`[D]` Theorems (`lean/BsvChain/Properties/CompactBlocks.lean`, 36, sorry-free, each on `[propext, Classical.choice,
Quot.sound]` or fewer): `sipHash24_empty_vector` and `sipHash24_uint256_vector` (the reference's own test vectors,
`src/test/hash_tests.cpp:62-63,111-115`); the round trips `CompactBlock.decode_encode`, `BlockTxnRequest.decode_encode`,
`BlockTxns.decode_encode`, `SendCmpct.decode_encode`. **The reconstruction theorem** `compact_reconstruction` (with its
halves `initData_ofBlock`, `missing_ofBlock`, `fillBlock_ofBlock`): for the message a sender builds from a block and a
receiver whose pool holds distinct transactions, when the block's short ids are distinct and no bucket of the reference's table holds
more than 12 of them (an input here, `crowded`) and no candidate transaction
shares a short id with a different block transaction, reconstruction names exactly the missing set (the positions of
the block's transactions the receiver holds neither in its pool nor among its extra transactions, and nothing else,
in increasing order, so the request reads back) and, given the block's transactions at those positions, yields
exactly the announced block, or the reference's `CheckBlock` verdict on it. **The collision case, as the source handles
it:** `initData_ofBlock_duplicate` (two equal short ids in the message: FAILED, and the receiver asks for the whole
block with no score, BIP152 line 142); `double_match_requested` (two pool transactions on one short id: the position is
emptied and requested); `early_exit_places_first` (the scan's early exit can place a pool transaction that only shares
the short id, "worth the extra risk", `src/blockencodings.cpp:192-197`); `fillBlock_ok_checked` (whatever the
collisions, a block `FillBlock` returns has the announced header and passes `CheckBlock`, whose merkle check refuses a
wrong body with the corruption mark, so FAILED and the whole block). The exactness of "the announced block" beyond the
merkle commitment rests on the hash: two bodies under one root differ only by a SHA-256d collision; a whole-tree
injectivity lemma is not proved here.

`[X]` [The scenario](../corpus/scenarios/2026-10-15-compact-blocks-two-node.md) on two fresh regtest instances (the
node of record, sha256 `ea73a708d277d88487a5d8ffc97e2b859937b8428387fc117b07f4add88b1421`; RPC 18573 and 18575, P2P
18574 and 18576), B dialing A once, the reference's test peer on A: four blocks by `submitblock` (the coinbase alone;
two transactions B held; one held, one never relayed; two never relayed). B asked for each as a compact block and
reconstructed it: 0, 0, 1 and 2 transactions requested with `getblocktxn`, as declared. `chaincheck --compact` over the
receipt: **149 checks, 0 witnesses** (at the lens fixes, [record](records/20261015-173931-fix-s7-79-compact-lens-s1.md)), the 28 frames the peer received read back and written again byte for byte, each
`cmpctblock` equal to the Lean sender's message at its nonce (the short ids are the Lean SipHash's), B's log counts,
its required ids and its byte counters for the three commands equal to the Lean reconstruction's, the filled block
equal to the block over B's pool, a full pool and an empty one, and the 64 SipHash vectors of the reference's test
([record](records/20261015-162637-s7-79-compact-blocks-s1.md), with six negative controls each turning it RED). The
chain leg replays it from `corpus/p2p/2026-10-15-compact-two-node.receipt.json`.

Not measured, named: the announcement mode (`sendcmpct` with the flag set, `:852-860`, `:5378-5410`); the optimistic
reconstruction of a block in flight from another peer (`:3939-3956`); the extra transactions (B's log counts 0 transactions from the extra pool at every block [X]; the ring's contents were not
read); the
FAILED paths on a node (a 48-bit collision is not constructed; the bucket bound is an input); a `getblocktxn` over the
99 percent setting. One implementation (the reference at the pin), one corpus (four blocks).
