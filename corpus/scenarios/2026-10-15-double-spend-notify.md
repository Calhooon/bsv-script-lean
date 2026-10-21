# Double-spend notifications on two nodes: the callback and the dsdetected relay (#80)

[D] 2026-10-15, S3, lane s7-80. **A notification is never a verdict.** Nothing here is a
validity rule: the attempt handler tells an endpoint that a transaction it watches was
double spent, and a node relays and posts a peer's report of blocks carrying a double
spend; neither decides what is valid. The model is `lean/BsvChain/Wire/DoubleSpend.lean`,
its laws `lean/BsvChain/Properties/DoubleSpend.lean`; the runner is `run_scenarios --dsnt`
(`harness/src/scenarios/dsnt.rs`); the projection is `chaincheck --dsnt <record.json>`
(`lean/Test/DsntCheck.lean`). The settings are docs/PARAMETERS.md section 8.12.
[SRC] bitcoin-sv v1.2.3 at `6504a3aff65ba97c0f6c80962b033e35ecbfed4b`.

## Topology

Two fresh regtest instances on the loopback range 18571 to 18590, each started with
`dsnotifylevel=1` (standard inputs only), `dsendpointport` set to the receiver's port
and its own `dsdetectedwebhookurl` (`/dsdetected/a`, `/dsdetected/b`); every other
setting at its default. The receiver `R` is a small HTTP server inside the runner on a
port of the same range; it records every request and answers a query by the rule the
step sets. A has its funding prefix (`seed`) and the fan-out `G` (four outputs of
24000, mined in block 102). A accepts `E1`, `E2` and `E3` (each spends one output of
`G` and carries the notification output `006a0464736e7407 01017f00000100`: protocol 1,
the endpoint 127.0.0.1, every input watched) while B is not yet linked, so B never
hears of them. B then dials A once and reaches its tip; the test peer `PA` connects to
A and `PB` to B. Synthetic names only; nothing is broadcast (rule 10).

## Steps

| step | stimulus | what the model says [D] |
|---|---|---|
| s1 | R answers a query for `E1` with 200 and `x-bsv-dsnt: 1`; B accepts `C1` (spends `E1`'s outpoint) by RPC and relays it to A | A refuses `C1` at the pool's conflict check (stage 5, `txn-mempool-conflict`, 0x102) with `E1` its collided set; the handler checks `C1`'s input script itself (the admission had not run it) and sends `GET /dsnt/1/query/<E1>` then `POST /dsnt/1/submit?txid=<E1>&n=0&ctxid=<C1>&cn=0` with `C1`'s bytes; E1 is recorded as notified |
| s2 | R answers a query for `E2` with 200 and no `x-bsv-dsnt` header; B accepts `C2` and relays it | the query for `E2` only; the endpoint 127.0.0.1 is blacklisted for 3600 s and `E2` recorded (it "wants no proof") |
| s3 | R would answer a query for `E3` with 200 and the header; B accepts `C3` and relays it | no request: the endpoint is blacklisted; the node's line `Skipping notification to blacklisted endpoint 127.0.0.1` |
| s4 | PB sends `dsdetected`: two forks on A's tip, each one header and a proof (flags 5, index 1) of `X1` or `X2` (both spend `G`'s fourth output) beside its own coinbase | B reads it, finds it valid, accepts the headers, marks the blocks, relays it to A (never to PB) and posts its JSON to `/dsdetected/b`; A does the same to PA (never to B) and `/dsdetected/a` |
| s5 | PB sends the same message again | B's duplicate cache: nothing relayed, nothing posted |

## What is judged

The projection reads the receipt and runs the model three ways: the codecs (the
notification output of each `E`, the `dsdetected` payload sent and every relayed
frame, each read and written again byte for byte), the detector (#62's admission,
`acceptDetect`, replays `C1`, `C2`, `C3` against a pool holding `E1`, `E2`, `E3`), and
the handler and the `dsdetected` handling against the receiver's requests, bodies and
order, PA's frames and the nodes' lines. A disagreement is a witness (rule 4).

## What it cannot show

The blacklist's expiry after the hour (the system clock is not the scenario's mock
clock and the run is minutes long): proven only (`Blacklist.add_hour`). The slow queue,
the fast timeout and the suspension score: not driven here.
