# The RPC observation contract of the #66 runner (#85; written 2026-10-15)

Issue numbers on this page are the archived tracker's ([docs/GLOSSARY.md](GLOSSARY.md), "archived #n").

[D] 2026-10-15 (the design for #85 under the maintainers' ruling of 2026-10-14 23:2xZ, `S7 go` for
the issues that need no peer). The runner of #66 reads and drives the reference node through JSON-RPC; until this page
its handlers' arguments, fields, error codes and edge behaviors were cited nowhere as one contract. This page is that
contract: every handler the runner calls, its arguments and result fields, its error codes, and what it does under safe
mode, pruning and a mock clock, each cited at the reference pin, bitcoin-sv `v1.2.3` =
`6504a3aff65ba97c0f6c80962b033e35ecbfed4b`, with its counterpart at Teranode `v0.16.0` =
`4edb60a40c6628ff0ef60231c2628efd7103fde5` (docs/PROVENANCE.md §1a), read with `git show <commit>:<path>`, never a
working tree [SRC].

**Where the contract lives.** The machine-readable table is `corpus/rpc/contract.json`; `tools/rpc_contract.py`
generates from it the runner's typed interface, `harness/src/scenarios/rpc_contract.rs` (one method per handler with its
result type), and every table of this page between the `rpc_contract` markers (§4 to §8). A table here is changed by
changing the contract and running the generator; `tools/rpc_contract.py --check` fails on a stale one.

**What this page is not.** It wires nothing: the runner still calls the node through its own five handler tables
(§7), and the interface is compiled only by `harness/tests/rpc_contract.rs`, which replays recorded replies through it
(§9); the wiring is a later change's. The settings that drive the edges (`-testsafemode`, `-prune`,
`-preferredblockfilesize`, `setmocktime`) are a node's settings and a test clock, policy and instrumentation, never a
consensus rule. Nothing here was run against a public network: the probe ran fresh regtest instances only.

## 0. The answer in one block

- [M] The runner calls 50 handlers (§4): 46 on the node of record, 4 on its wallet build; `getblockbyheight` only on
  the second oracle. The contract holds 51: `setban` (added 2026-10-17) stands for #88's `alert-ban`
  row and is not called. Every handler's source span, registration row and okSafeMode flag is cited at the pin (§5).
- [X] A probe drove every handler on fresh regtest instances (ports 18571 to 18590, stopped after; record
  `docs/records/20261015-035438-s7-85-rpc-contract-s4b.md`): every success reply fits its handler's result type and every error
  code is one the contract lists, except the one reply Finding R2 names (§8). The typed interface decodes and
  re-serializes every recorded reply unchanged (`cargo test --test rpc_contract`, §9).
- **Finding R1** [X]: `getmerkleproof2`'s registration names its arguments `txid, blockhash`; the handler reads the
  block hash at position 0 and the txid at 1. A call with named arguments swaps them.
- **Finding R2** [X]: `getblock <hash> 0` on a pruned block writes a 200 chunked head, the 12 bytes `{"result": "`, a
  second status line `HTTP/1.1 500` and the error `-1 <hash> not found on disk` onto one connection, in an order that
  differed between two runs: no single JSON reply.
- Three edges witnessed [X] (§3): a one-transaction block's coinbase has no merkle proof (E1); `-testsafemode` refuses
  the okSafeMode-false handlers while `getsafemodeinfo` says `safemodeenabled: false` (E2); under a mock clock
  `getsafemodeinfo`'s `timeutc` is the wall clock (E3).

## 1. The envelope

[SRC] One HTTP/1.1 POST per call with cookie authentication (`src/httprpc.cpp:291-311`); the body is
`{"result": ..., "error": ..., "id": ...}`, an error being `{"code", "message"}` (`src/rpc/protocol.cpp:49-54`). The HTTP
status of an error reply is 400 for -32600, 404 for -32601 and 500 for every other code (`src/httprpc.cpp:66-81`); a
success is 200. The runner's transport (`harness/src/rpc.rs`) reads the error object from any status.

[SRC] The dispatch, in order (`src/rpc/server.cpp:558-594`): the warmup refusal, -28 (`:565`); the method lookup, -32601
`Method not found` (`:570`); the pre-command signal, where safe mode refuses with -2 (`:572`, connected to
`src/init.cpp:325-333`); named arguments mapped onto the registration's names, an unknown name -8 (`:578-582`,
`src/rpc/server.cpp:447-490`); the handler. Any `std::exception` a handler throws becomes -1 with its text
(`src/rpc/server.cpp:588-590`): a wrong argument count answers -1 with the handler's whole help text, a JSON value of the
wrong type read by `get_int`, `get_str` or `get_bool` answers -1 `JSON value is not ... as expected` [X]. A handler that
calls `RPCTypeCheck` answers -3 instead (`src/rpc/server.cpp:68-90`) [X].

[SRC] Ten handlers write their own reply in chunks (`getblock`, `getblockbyheight`, `getblockheader`, `getrawtransaction`,
`getrawmempool`, `getrawnonfinalmempool`, `sendrawtransactions`, `getsafemodeinfo`, `queryBlacklist`,
`queryConfiscationTxidWhitelist`): an error thrown before their head is an ordinary error reply; an error thrown after
it is written as a second HTTP response into the same connection (Finding R2).

The error codes of the pin and the envelope's generic errors (generated):

<!-- rpc_contract: codes begin -->
| name | value | cite [SRC] |
|---|---|---|
| `RPC_INVALID_REQUEST` | -32600 | `src/rpc/protocol.h:24` |
| `RPC_METHOD_NOT_FOUND` | -32601 | `src/rpc/protocol.h:27` |
| `RPC_INVALID_PARAMS` | -32602 | `src/rpc/protocol.h:28` |
| `RPC_INTERNAL_ERROR` | -32603 | `src/rpc/protocol.h:31` |
| `RPC_PARSE_ERROR` | -32700 | `src/rpc/protocol.h:32` |
| `RPC_MISC_ERROR` | -1 | `src/rpc/protocol.h:36` |
| `RPC_FORBIDDEN_BY_SAFE_MODE` | -2 | `src/rpc/protocol.h:38` |
| `RPC_TYPE_ERROR` | -3 | `src/rpc/protocol.h:40` |
| `RPC_INVALID_ADDRESS_OR_KEY` | -5 | `src/rpc/protocol.h:42` |
| `RPC_OUT_OF_MEMORY` | -7 | `src/rpc/protocol.h:44` |
| `RPC_INVALID_PARAMETER` | -8 | `src/rpc/protocol.h:46` |
| `RPC_DATABASE_ERROR` | -20 | `src/rpc/protocol.h:48` |
| `RPC_DESERIALIZATION_ERROR` | -22 | `src/rpc/protocol.h:50` |
| `RPC_VERIFY_ERROR` | -25 | `src/rpc/protocol.h:52` |
| `RPC_VERIFY_REJECTED` | -26 | `src/rpc/protocol.h:54` |
| `RPC_VERIFY_ALREADY_IN_CHAIN` | -27 | `src/rpc/protocol.h:56` |
| `RPC_IN_WARMUP` | -28 | `src/rpc/protocol.h:58` |
| `RPC_TRANSACTION_ERROR` | RPC_VERIFY_ERROR | `src/rpc/protocol.h:61` |
| `RPC_TRANSACTION_REJECTED` | RPC_VERIFY_REJECTED | `src/rpc/protocol.h:62` |
| `RPC_TRANSACTION_ALREADY_IN_CHAIN` | RPC_VERIFY_ALREADY_IN_CHAIN | `src/rpc/protocol.h:63` |
| `RPC_CLIENT_NOT_CONNECTED` | -9 | `src/rpc/protocol.h:67` |
| `RPC_CLIENT_IN_INITIAL_DOWNLOAD` | -10 | `src/rpc/protocol.h:69` |
| `RPC_CLIENT_NODE_ALREADY_ADDED` | -23 | `src/rpc/protocol.h:71` |
| `RPC_CLIENT_NODE_NOT_ADDED` | -24 | `src/rpc/protocol.h:73` |
| `RPC_CLIENT_NODE_NOT_CONNECTED` | -29 | `src/rpc/protocol.h:75` |
| `RPC_CLIENT_INVALID_IP_OR_SUBNET` | -30 | `src/rpc/protocol.h:77` |
| `RPC_CLIENT_P2P_DISABLED` | -31 | `src/rpc/protocol.h:79` |
| `RPC_WALLET_ERROR` | -4 | `src/rpc/protocol.h:83` |
| `RPC_WALLET_INSUFFICIENT_FUNDS` | -6 | `src/rpc/protocol.h:85` |
| `RPC_WALLET_INVALID_ACCOUNT_NAME` | -11 | `src/rpc/protocol.h:87` |
| `RPC_WALLET_KEYPOOL_RAN_OUT` | -12 | `src/rpc/protocol.h:89` |
| `RPC_WALLET_UNLOCK_NEEDED` | -13 | `src/rpc/protocol.h:91` |
| `RPC_WALLET_PASSPHRASE_INCORRECT` | -14 | `src/rpc/protocol.h:93` |
| `RPC_WALLET_WRONG_ENC_STATE` | -15 | `src/rpc/protocol.h:96` |
| `RPC_WALLET_ENCRYPTION_FAILED` | -16 | `src/rpc/protocol.h:98` |
| `RPC_WALLET_ALREADY_UNLOCKED` | -17 | `src/rpc/protocol.h:100` |
| `RPC_WALLET_NOT_FOUND` | -18 | `src/rpc/protocol.h:102` |
| `RPC_WALLET_NOT_SPECIFIED` | -19 | `src/rpc/protocol.h:104` |

| code | message | when | cite [SRC] |
|---|---|---|---|
| -1 | <the handler's help text> | a wrong argument count or fHelp: the handler throws std::runtime_error, execute turns it into RPC_MISC_ERROR [X] | `src/rpc/server.cpp:589` |
| -1 | JSON value is not <a type> as expected | an argument of the wrong JSON type read by get_int, get_str, get_bool [X] | `src/rpc/server.cpp:589` |
| -32601 | Method not found | no registered handler; HTTP 404 [X] | `src/rpc/server.cpp:570` |
| -28 | <warmup status> | the node is still starting | `src/rpc/server.cpp:565` |
| -8 | Unknown named parameter <name> | a named argument the registration does not list | `src/rpc/server.cpp:488` |
| -2 | Safe mode: <warning> | okSafeMode false while GetWarnings("rpc") is not empty and -disablesafemode is off [X] | `src/init.cpp:331` |
| -32700 | Parse error | a body that is not JSON | `src/httprpc.cpp:318` |
| -32600 | Invalid Request object / Missing method / Method must be a string / Params must be an array or object | a malformed request; HTTP 400 | `src/rpc/server.cpp:381` |
<!-- rpc_contract: codes end -->

## 2. The three edges

### 2.1 Safe mode

[SRC] The gate is one function: before every handler, when `GetWarnings("rpc")` is not empty, `-disablesafemode` is off
and the handler's registration says okSafeMode false, the call is refused with -2 `Safe mode: <warning>`
(`src/init.cpp:325-333`). The warning is set by the fork-driven safe-mode level (`src/warnings.cpp:54-74`) or by
`-testsafemode` (`src/warnings.cpp:46-47`, default off, `src/warnings.h:43`). Five handlers of the contract are refused
(the counts line of §4); the other 45 answer as usual. `getsafemodeinfo` reports the fork-driven level only
(`src/safe_mode.cpp:498`), so under `-testsafemode` it answers `safemodeenabled: false` while `sendrawtransaction` is
refused (E2) [X]. `getnetworkinfo`'s `warnings` is the status-bar text (`src/rpc/net.cpp:665`): `testsafemode enabled`
under the switch [X].

The scenario for the runner: [`corpus/scenarios/2026-10-15-rpc-safe-mode.md`](../corpus/scenarios/2026-10-15-rpc-safe-mode.md),
every step `node: "pending #66"`.

### 2.2 Pruning

[SRC] `-prune=1` is manual pruning (`src/init.cpp:2821-2826`); `pruneblockchain` refuses below the chain's
`PruneAfterHeight` (regtest 1000, `src/chainparams.cpp:1509`) and clamps a height inside the last `GetMinBlocksToKeep`
blocks (default 288, `src/validation.h:272`) to the tip minus 288, answering the clamped height
(`src/rpc/blockchain.cpp:1860-1874`). Files hold blocks up to `-preferredblockfilesize` bytes (default 128 MiB,
`src/validation.h:99`), so a small value lets a short regtest chain prune at all. Without `-prune`, `pruneblockchain`
answers -1 `Cannot prune blocks because node is not in prune mode.` [X].

[X] On a chain of 1300 blocks pruned at 1100 (clamped to 1012), block 5's reads:

| read | answer [X] | source [SRC] |
|---|---|---|
| `getblockheader <h5> 1` | answers; `size` gone, `status.data`, `status.undo` and `status."disk meta"` false | `src/rpc/blockchain.cpp:93-138`, `:140-158` |
| `getblockheader <h5> 2` | answers as verbosity 1: no `tx`, no `merkleproof` (the coinbase is not readable) | `src/rpc/blockchain.cpp:1009-1043` |
| `getblock <h5> 1` | -1 `Block file <hash> not available.` | `src/rpc/blockchain.cpp:1673-1678` |
| `getblock <h5> 0` | a 200 head, a partial chunk and a second status line, 500, with -1 on one connection (Finding R2) | `src/rpc/blockchain.cpp:1591-1620` |
| `getrawtransaction <coinbase of 5> 1` (with `-txindex`) | -5 `No such mempool or blockchain transaction. If using -prune, ...` | `src/rpc/rawtransaction.cpp:196-205` |
| `getmerkleproof <coinbase of 5> <h5>` | -32603 `Can't read block from disk` | `src/rpc/rawtransaction.cpp:2297-2300` |
| `gettxout <coinbase of 5> 0` | answers: the UTXO set is not pruned | `src/rpc/blockchain.cpp:1923-2028` |
| `getchaintips` | the tip `active`: `headers-only` means no chain transaction count, not a pruned file | `src/rpc/blockchain.cpp:2585-2608` |

The scenario: [`corpus/scenarios/2026-10-15-rpc-pruning.md`](../corpus/scenarios/2026-10-15-rpc-pruning.md).

### 2.3 Mock time

[SRC] `setmocktime` answers only on a chain that mines on demand (`src/rpc/misc.cpp:992-995`) and sets `nMockTime`;
`GetTime()` returns it while it is not zero (`src/utiltime.cpp:23-29`), `setmocktime 0` restores the wall clock, and a
relaunch clears it (the runner sets it again, `harness/src/scenarios/core.rs` `clock_receipt`). What follows the mock
clock: a mined block's time, `max(MTP + 1, GetAdjustedTime())` (`src/mining/assembler.cpp:80-84`), and the pool's
acceptance time, `GetTime()` at submission (`src/rpc/rawtransaction.cpp:1593`) [X]. What does not: `getsafemodeinfo`'s
`timeutc` (`std::time`, `src/safe_mode.cpp:500`, E3) [X], `verifyscript`'s budget (`std::chrono::steady_clock`,
`src/rpc/misc.cpp:867`), and `getnetworkinfo`'s `timeoffset`, which only five peer samples move (`src/timedata.cpp:74-82`;
0 on an isolated instance) [X].

The scenario: [`corpus/scenarios/2026-10-15-rpc-mock-time.md`](../corpus/scenarios/2026-10-15-rpc-mock-time.md).

## 3. Findings and edges

**Finding R1.** [SRC] `getmerkleproof2` is registered with the argument names `txid, blockhash, includeFullTx,
targetType, format` (`src/rpc/rawtransaction.cpp:2631`), while its handler reads the txid from position 1 and the block
hash from position 0 (`src/rpc/rawtransaction.cpp:2402`, `:2407`), as its own help text says (`blockhash` then `txid`).
Named arguments are placed by the registration's names (`src/rpc/server.cpp:447-490`), so a named call puts the txid
where the block hash is read. [X] On a fresh regtest instance: the positional call `[<block>, <txid>]` answers the proof;
the named call `{"txid": <txid>, "blockhash": <block>}` answers -5 `Block not found` (`src/rpc/rawtransaction.cpp:278`, GetBlockIndex reached from `:2409` with the
txid read as the block hash); the named call with the names
swapped answers the proof (record `docs/records/20261015-035438-s7-85-rpc-contract-s4b.md`, phase `named`). The contract and
the interface are positional only. The witness transaction is in the record's call log.

**Finding R2.** [SRC] `getblock` at verbosity 0 starts the chunked 200 reply (`src/rpc/blockchain.cpp:1591-1598`) and
writes `{"result": "` (`:1603`) before it opens the block's stream; on a pruned block the stream is absent and the handler
throws (`:1620`), which `src/rpc/blockchain.cpp:1474` turns into -1 and `src/httprpc.cpp:66-81` writes as a new
reply. [X] The bytes on the socket in the record's run (phase `prune`): `HTTP/1.1 200 OK` with `Transfer-Encoding:
chunked` and a second `Content-Type` header, the error object `{"result":null,"error":{"code":-1,"message":"<hash> not
found on disk"},"id":"rpc-85"}` unchunked, the 12-byte chunk `{"result": "`, then the status line `HTTP/1.1 500 Internal
Server Error` with its headers and no body, 515 bytes, the connection closed; the instance kept answering
(`getblockcount` next). An earlier run of the same probe, at the base commit with the probe not yet committed, read the
chunk before the 500 head and the error object after it, 483 bytes (the record quotes both): the pieces are fixed,
their order is not. A client reads a broken stream, not an error object. Verbosity 1 to 3 check the file before the head and answer a clean
-1 (`src/rpc/blockchain.cpp:1673-1678`) [X]. For the runner: read `getblockheader`'s `status.data` before a raw
`getblock`.

**Edge E1.** [SRC] For the only transaction of a block, the merkle proof has no node, and both proof handlers treat an
empty proof as absent: -5 `Transaction(s) not found in provided block` (`src/rpc/rawtransaction.cpp:2303-2307`,
`:2447-2451`). [X] `getmerkleproof` and `getmerkleproof2` on block 1's coinbase both answered -5.

**Edge E2.** [SRC] `-testsafemode` sets the RPC warning (`src/warnings.cpp:46-47`) without a safe-mode level, and
`getsafemodeinfo` reports the level (`src/safe_mode.cpp:498`). [X] Under `-testsafemode=1`: `sendrawtransaction` and
`sendrawtransactions` answered -2 `Safe mode: testsafemode enabled`; `getsafemodeinfo` answered `safemodeenabled: false`;
`getblockcount`, `getrawmempool` and `getnetworkinfo` answered.

**Edge E3.** [SRC] `getsafemodeinfo`'s `timeutc` is `std::time(nullptr)` (`src/safe_mode.cpp:500`). [X] With the mock
clock at 1700000000 (2023-11-14), it answered the wall clock (2026-10-15), while the block mined then carried time
1700000000.

**The binary of record's build.** [X] `getnetworkinfo`'s `warnings` on the node of record is the development-build text
(`src/warnings.cpp:41-44`): its build tree was configured with `ENABLE_PROD_BUILD=OFF`
(`CMakeCache.txt:408` in the build tree of `$BSV_SPEC_REFERENCE_BINARY`, docs/PROVENANCE.md §1a), which sets `CLIENT_VERSION_IS_RELEASE` false
(`src/config/CMakeLists.txt` lines 20 to 24 at the pin) and adds `IS_PRODUCTION_BUILD` nowhere else than the version
string (`src/CMakeLists.txt` lines 259 and 260, `src/clientversion.cpp:22`). No handler of the contract changes with it;
the RPC warning, which safe mode reads, stays empty.

## 4. The handlers

<!-- rpc_contract: summary begin -->
| handler | source [SRC] | registered (okSafeMode) | arguments | result | error codes | Teranode v0.16.0 | probe [X] |
|---|---|---|---|---|---|---|---|
| `acceptblock` | `src/rpc/blockchain.cpp:2894-2991` | `src/rpc/blockchain.cpp:3825` (true) | blockhash, numblocks? | null | -20, -8, -5, -1 | absent | -1, ok |
| `addToConfiscationTxidWhitelist` | `src/rpc/frozentxo_rpc.cpp:632-764` | `src/rpc/frozentxo_rpc.cpp:908` (true) | txs | WhitelistResult | -8 | absent | ok |
| `addToConsensusBlacklist` | `src/rpc/frozentxo_rpc.cpp:346-378` | `src/rpc/frozentxo_rpc.cpp:904` (true) | funds | FundsResult | -8, -3 | absent | ok |
| `addToPolicyBlacklist` | `src/rpc/frozentxo_rpc.cpp:320-344` | `src/rpc/frozentxo_rpc.cpp:903` (true) | funds | FundsResult | -8, -3 | absent | -3, ok |
| `generatetoaddress` | `src/rpc/mining.cpp:227-268` | `src/rpc/mining.cpp:968` (true) | nblocks, address, maxtries? | array of string | -32603, -5 | implemented | ok |
| `getbestblockhash` | `src/rpc/blockchain.cpp:220-235` | `src/rpc/blockchain.cpp:3796` (true) | none | string | generic only | implemented | ok |
| `getblock` | `src/rpc/blockchain.cpp:1108-1272` | `src/rpc/blockchain.cpp:3798` (true) | blockhash, verbosity? | GetBlock | -8, -5, -1 | implemented | -1, -5, -8, ok, raw |
| `getblockbyheight` | `src/rpc/blockchain.cpp:1274-1430` | `src/rpc/blockchain.cpp:3799` (true) | height, verbosity? | GetBlock | -8, -1 | implemented | ok |
| `getblockchainactivity` | `src/rpc/blockchain.cpp:3649-3683` | `src/rpc/blockchain.cpp:3829` (true) | none | BlockchainActivity | -31 | absent | ok |
| `getblockcount` | `src/rpc/blockchain.cpp:205-218` | `src/rpc/blockchain.cpp:3797` (true) | none | i64 | generic only | unimplemented | -1, ok |
| `getblockhash` | `src/rpc/blockchain.cpp:801-825` | `src/rpc/blockchain.cpp:3800` (true) | height | string | -8 | implemented | -1, -8, ok |
| `getblockheader` | `src/rpc/blockchain.cpp:884-1061` | `src/rpc/blockchain.cpp:3801` (true) | blockhash, verbosity? | GetBlockHeader | -8, -5 | implemented | -5, ok |
| `getchaintips` | `src/rpc/blockchain.cpp:2497-2615` | `src/rpc/blockchain.cpp:3804` (true) | none | array of ChainTip | generic only | implemented | ok |
| `getchaintxstats` | `src/rpc/blockchain.cpp:3054-3155` | `src/rpc/blockchain.cpp:3795` (true) | nblocks?, blockhash? | ChainTxStats | -8, -5 | absent | -8, ok |
| `getmempoolinfo` | `src/rpc/blockchain.cpp:2644-2673` | `src/rpc/blockchain.cpp:3809` (true) | none | MempoolInfo | generic only | unimplemented | ok |
| `getmerkleproof` | `src/rpc/rawtransaction.cpp:2242-2339` | `src/rpc/rawtransaction.cpp:2630` (true) | txid, blockhash? | MerkleProof | -32603, -5 | absent | -32603, -5, ok |
| `getmerkleproof2` | `src/rpc/rawtransaction.cpp:2342-2525` | `src/rpc/rawtransaction.cpp:2631` (true) | blockhash, txid, includeFullTx?, targetType?, format? | MerkleProof2 | -32603, -32602, -5, -1 | absent | -32602, -5, ok |
| `getnetworkinfo` | `src/rpc/net.cpp:543-667` | `src/rpc/net.cpp:896` (true) | none | NetworkInfo | generic only | unimplemented | ok |
| `getnewaddress` | `src/wallet/rpcwallet.cpp:119-172` | `src/wallet/rpcwallet.cpp:3524` (true) | account? | string | -12 | wallet | ok |
| `getorphaninfo` | `src/rpc/blockchain.cpp:2675-2693` | `src/rpc/blockchain.cpp:3833` (true) | none | OrphanInfo | generic only | absent | ok |
| `getpeerinfo` | `src/rpc/net.cpp:69-280` | `src/rpc/net.cpp:891` (true) | none | array of json | generic only | implemented | ok |
| `getrawmempool` | `src/rpc/blockchain.cpp:440-500` | `src/rpc/blockchain.cpp:3810` (true) | verbose? | RawMempool | generic only | implemented | ok |
| `getrawnonfinalmempool` | `src/rpc/blockchain.cpp:502-557` | `src/rpc/blockchain.cpp:3811` (true) | none | array of string | generic only | absent | ok |
| `getrawtransaction` | `src/rpc/rawtransaction.cpp:53-256` | `src/rpc/rawtransaction.cpp:2620` (true) | txid, verbose? | GetRawTransaction | -8, -5, -3 | implemented | -3, -5, ok |
| `getreceivedbyaddress` | `src/wallet/rpcwallet.cpp:680-764` | `src/wallet/rpcwallet.cpp:3527` (false) | address, minconf? | f64 | -5 | wallet | -5, ok |
| `getsafemodeinfo` | `src/rpc/safe_mode.cpp:97-196` | `src/rpc/safe_mode.cpp:206` (true) | none | SafeModeInfo | generic only | absent | ok |
| `gettransaction` | `src/wallet/rpcwallet.cpp:2061-2187` | `src/wallet/rpcwallet.cpp:3528` (false) | txid, include_watchonly? | WalletTransaction | -5 | wallet | -5, ok |
| `gettxout` | `src/rpc/blockchain.cpp:1923-2028` | `src/rpc/blockchain.cpp:3812` (true) | txid, n, include_mempool? | nullable of Coin | -20 | unimplemented | ok |
| `gettxoutsetinfo` | `src/rpc/blockchain.cpp:1877-1921` | `src/rpc/blockchain.cpp:3814` (true) | none | UtxoSetInfo | -32603 | wallet | ok |
| `getwalletinfo` | `src/wallet/rpcwallet.cpp:2798-2878` | `src/wallet/rpcwallet.cpp:3530` (false) | none | WalletInfo | generic only | wallet | -32601, ok |
| `ignoresafemodeforblock` | `src/rpc/safe_mode.cpp:12-51` | `src/rpc/safe_mode.cpp:204` (true) | blockhash | null | -32602 | absent | -32602, ok |
| `invalidateblock` | `src/rpc/blockchain.cpp:2732-2768` | `src/rpc/blockchain.cpp:3822` (true) | blockhash | null | -20, -5 | implemented | -5, ok |
| `preciousblock` | `src/rpc/blockchain.cpp:2695-2730` | `src/rpc/blockchain.cpp:3817` (true) | blockhash | null | -20, -5 | unimplemented | ok |
| `prioritisetransaction` | `src/rpc/mining.cpp:312-344` | `src/rpc/mining.cpp:963` (true) | txid, priority_delta, fee_delta | bool | -8 | absent | -8, ok |
| `pruneblockchain` | `src/rpc/blockchain.cpp:1810-1875` | `src/rpc/blockchain.cpp:3815` (true) | height | u64 | -8, -1 | absent | -1, -8, ok |
| `queryBlacklist` | `src/rpc/frozentxo_rpc.cpp:404-499` | `src/rpc/frozentxo_rpc.cpp:906` (true) | none | Blacklist | generic only | absent | ok |
| `queryConfiscationTxidWhitelist` | `src/rpc/frozentxo_rpc.cpp:799-894` | `src/rpc/frozentxo_rpc.cpp:910` (true) | verbose? | Whitelist | generic only | absent | ok |
| `reconsiderblock` | `src/rpc/blockchain.cpp:2770-2818` | `src/rpc/blockchain.cpp:3823` (true) | blockhash | null | -20, -5 | implemented | ok |
| `reconsidersafemodeforblock` | `src/rpc/safe_mode.cpp:53-95` | `src/rpc/safe_mode.cpp:205` (true) | blockhash | null | -32602 | absent | -32602, ok |
| `sendrawtransaction` | `src/rpc/rawtransaction.cpp:1530-1700` | `src/rpc/rawtransaction.cpp:2624` (false) | hexstring, allowhighfees?, dontcheckfee? | string | -31, -27, -26, -25, -22, -3 | implemented | -2, -22, -27, -3, ok |
| `sendrawtransactions` | `src/rpc/rawtransaction.cpp:1798-2240` | `src/rpc/rawtransaction.cpp:2625` (false) | inputs | SendRawTransactions | -22, -8 | absent | -2, ok |
| `setban` | `src/rpc/net.cpp:669-757` | `src/rpc/net.cpp:897` (true) | subnet, command, bantime?, absolute? | null | -31, -30, -23 | implemented | not called |
| `setmocktime` | `src/rpc/misc.cpp:980-1008` | `src/rpc/misc.cpp:1339` (true) | timestamp | null | -3, -1 | absent | -3, ok |
| `softrejectblock` | `src/rpc/blockchain.cpp:2820-2892` | `src/rpc/blockchain.cpp:3824` (true) | blockhash, numblocks | null | -20, -8, -5, -1 | absent | -8, ok |
| `stop` | `src/rpc/server.cpp:265-278` | `src/rpc/server.cpp:303` (true) | none | string | generic only | implemented | ok |
| `submitblock` | `src/rpc/mining.cpp:916-953` | `src/rpc/mining.cpp:966` (true) | hexdata, parameters? | nullable of string | -26, -25, -22 | unimplemented | -22, ok |
| `validateaddress` | `src/rpc/misc.cpp:206-300` | `src/rpc/misc.cpp:1330` (true) | address | AddressInfo | generic only | unimplemented | ok |
| `verifychain` | `src/rpc/blockchain.cpp:2321-2354` | `src/rpc/blockchain.cpp:3816` (true) | checklevel?, nblocks? | bool | generic only | unimplemented | ok |
| `verifymerkleproof` | `src/rpc/rawtransaction.cpp:2527-2612` | `src/rpc/rawtransaction.cpp:2632` (true) | proof, txid? | bool | -8 | absent | -8, ok |
| `verifyscript` | `src/rpc/misc.cpp:506-915` | `src/rpc/misc.cpp:1333` (true) | scripts, stopOnFirstInvalid?, totalTimeout? | array of ScriptVerdict | -22, -8 | absent | -22, ok |
| `waitforptvcompletion` | `src/rpc/blockchain.cpp:3769-3786` | `src/rpc/blockchain.cpp:3834` (true) | none | null | generic only | absent | ok |

[M] 51 handlers; by build: record 47, wallet 4; refused in safe mode (okSafeMode false): 5 (`getreceivedbyaddress`, `gettransaction`, `getwalletinfo`, `sendrawtransaction`, `sendrawtransactions`); the second oracle: absent 23, implemented 15, unimplemented 8, wallet 5.
<!-- rpc_contract: summary end -->

## 5. Per handler

[SRC] Each handler's arguments in position order, its result, its three edges, its counterpart and its errors. A node message is quoted as the node writes it, except the ordinal word the wording gate holds, elided as `[...]`; `corpus/rpc/contract.json` keeps every message literal.

<!-- rpc_contract: handlers begin -->
### `acceptblock`

[SRC] `src/rpc/blockchain.cpp:2894-2991`, registered `src/rpc/blockchain.cpp:3825` with okSafeMode true and the names `blockhash`, `numblocks`; the record build.

| position | argument | type | required | note |
|---|---|---|---|---|
| 0 | `blockhash` | string | yes |  |
| 1 | `numblocks` | i64 | no |  |

- result: null
- safe mode: answers (okSafeMode true at the registration)
- pruning: no block data read: unchanged by pruning
- mock time: no clock read in the handler
- Teranode v0.16.0: absent, `services/rpc/Server.go:991`, the command parser `services/rpc/Server.go:1061-1065`, answers -32601 Method not found [SRC]

| code | message | when | cite [SRC] |
|---|---|---|---|
| -8 | Parameter numBlocks must not be negative | numblocks below 0 | `src/rpc/blockchain.cpp:2939` |
| -5 | Block not found | the hash names no block index entry | `src/rpc/blockchain.cpp:2951` |
| -1 | Error unmarking block as soft rejected | the block is not soft rejected, or only through its parent | `src/rpc/blockchain.cpp:2968` |
| -20 | <reject reason> | ActivateBestChain reported an error | `src/rpc/blockchain.cpp:2987` |

### `addToConfiscationTxidWhitelist`

[SRC] `src/rpc/frozentxo_rpc.cpp:632-764`, registered `src/rpc/frozentxo_rpc.cpp:908` with okSafeMode true and the names `txs`; the record build.

| position | argument | type | required | note |
|---|---|---|---|---|
| 0 | `txs` | json | yes | {confiscationTxs: [{confiscationTx: {enforceAtHeight, hex}}]} |

- result: WhitelistResult. a transaction that is not a valid confiscation transaction is a notProcessed row with its reason [X]
- safe mode: answers (okSafeMode true at the registration)
- pruning: no block data read: unchanged by pruning
- mock time: no clock read in the handler
- Teranode v0.16.0: absent, `services/rpc/Server.go:991`, the command parser `services/rpc/Server.go:1061-1065`, answers -32601 Method not found [SRC]

| code | message | when | cite [SRC] |
|---|---|---|---|
| -8 | Negative enforceAtHeight | enforceAtHeight below 0 | `src/rpc/frozentxo_rpc.cpp:713` |

### `addToConsensusBlacklist`

[SRC] `src/rpc/frozentxo_rpc.cpp:346-378`, registered `src/rpc/frozentxo_rpc.cpp:904` with okSafeMode true and the names `funds`; the record build. Helpers: `src/rpc/frozentxo_rpc.cpp:281-301`.

| position | argument | type | required | note |
|---|---|---|---|---|
| 0 | `funds` | json | yes | {funds: [{txOut, enforceAtHeight: [{start, stop}], policyExpiresWithConsensus}]} |

- result: FundsResult
- safe mode: answers (okSafeMode true at the registration)
- pruning: no block data read: unchanged by pruning
- mock time: no clock read in the handler
- Teranode v0.16.0: absent, `services/rpc/Server.go:991`, the command parser `services/rpc/Server.go:1061-1065`, answers -32601 Method not found [SRC]

| code | message | when | cite [SRC] |
|---|---|---|---|
| -3 | Missing <key> / Expected type <t> for <key> | a fund object without txOut, txId or vout, or a key of the wrong type [X] | `src/rpc/server.cpp:98` |
| -8 | Negative vout / Too large vout | vout out of range | `src/rpc/frozentxo_rpc.cpp:126` |
| -8 | Missing start | an interval without start | `src/rpc/frozentxo_rpc.cpp:43` |

### `addToPolicyBlacklist`

[SRC] `src/rpc/frozentxo_rpc.cpp:320-344`, registered `src/rpc/frozentxo_rpc.cpp:903` with okSafeMode true and the names `funds`; the record build. Helpers: `src/rpc/frozentxo_rpc.cpp:281-301`.

| position | argument | type | required | note |
|---|---|---|---|---|
| 0 | `funds` | json | yes | {funds: [{txOut: {txId, vout}}]} |

- result: FundsResult. a fund already listed is a result row of notProcessed with its reason, never an error [X]
- safe mode: answers (okSafeMode true at the registration)
- pruning: no block data read: unchanged by pruning
- mock time: no clock read in the handler
- Teranode v0.16.0: absent, `services/rpc/Server.go:991`, the command parser `services/rpc/Server.go:1061-1065`, answers -32601 Method not found [SRC]

| code | message | when | cite [SRC] |
|---|---|---|---|
| -3 | Missing <key> / Expected type <t> for <key> | a fund object without txOut, txId or vout, or a key of the wrong type [X] | `src/rpc/server.cpp:98` |
| -8 | Negative vout / Too large vout | vout out of range | `src/rpc/frozentxo_rpc.cpp:126` |

### `generatetoaddress`

[SRC] `src/rpc/mining.cpp:227-268`, registered `src/rpc/mining.cpp:968` with okSafeMode true and the names `nblocks`, `address`, `maxtries`; the record build. Helpers: `src/rpc/mining.cpp:143-225`.

| position | argument | type | required | note |
|---|---|---|---|---|
| 0 | `nblocks` | i64 | yes |  |
| 1 | `address` | string | yes |  |
| 2 | `maxtries` | i64 | no | default 1000000 |

- result: array of string
- safe mode: answers (okSafeMode true at the registration)
- pruning: no block data read: unchanged by pruning
- mock time: the block's time is the assembler's adjusted time (the mock clock when set; at least the median time past + 1): the observed headers carry the mock clock, then the wall clock after setmocktime 0 [X]
- Teranode v0.16.0: implemented, `services/rpc/Server.go:168`, registered `services/rpc/bsvjson/btcdextcmds.go:141`, handler `services/rpc/handlers.go:1031` [SRC]

| code | message | when | cite [SRC] |
|---|---|---|---|
| -5 | Error: Invalid address | the address does not decode | `src/rpc/mining.cpp:259` |
| -32603 | Couldn't create new block | the assembler returned no block | `src/rpc/mining.cpp:175` |
| -32603 | ProcessNewBlock, block not accepted | the mined block was refused | `src/rpc/mining.cpp:212` |

### `getbestblockhash`

[SRC] `src/rpc/blockchain.cpp:220-235`, registered `src/rpc/blockchain.cpp:3796` with okSafeMode true and the names none; the record build.

- result: string
- safe mode: answers (okSafeMode true at the registration)
- pruning: no block data read: unchanged by pruning
- mock time: no clock read in the handler
- Teranode v0.16.0: implemented, `services/rpc/Server.go:171`, registered `services/rpc/bsvjson/chainsvrcmds.go:875`, handler `services/rpc/handlers.go:507` [SRC]

### `getblock`

[SRC] `src/rpc/blockchain.cpp:1108-1272`, registered `src/rpc/blockchain.cpp:3798` with okSafeMode true and the names `blockhash`, `verbosity|verbose`; the record build. Helpers: `src/rpc/blockchain.cpp:1432-1476`, `src/rpc/blockchain.cpp:1478-1663`, `src/rpc/blockchain.cpp:1665-1736`.

| position | argument | type | required | note |
|---|---|---|---|---|
| 0 | `blockhash` | string | yes |  |
| 1 | `verbosity` | json | no | 0, 1, 2, 3, a boolean, or a level's name; default 1 |

- result: GetBlock
- safe mode: answers (okSafeMode true at the registration)
- pruning: verbosity 1 to 3: -1 before any byte is written; verbosity 0: the handler writes the 200 head and {"result": " before the stream fails [SRC]; on the socket the 200 head, that chunk, a second status line 500 and the -1 error object, in an order that differed between two runs (Finding R2) [X]
- mock time: no clock read in the handler
- Teranode v0.16.0: implemented, `services/rpc/Server.go:172`, registered `services/rpc/bsvjson/chainsvrcmds.go:876`, handler `services/rpc/handlers.go:101` [SRC]

| code | message | when | cite [SRC] |
|---|---|---|---|
| -5 | Block not found | the hash names no block index entry | `src/rpc/blockchain.cpp:1257` |
| -8 | Verbosity value out of range | a numeric verbosity outside 0..3 | `src/rpc/blockchain.cpp:1078` |
| -8 | Verbosity value not recognized | a string verbosity that names no level | `src/rpc/blockchain.cpp:1095` |
| -8 | Invalid verbosity input type | a verbosity neither number, string nor boolean | `src/rpc/blockchain.cpp:1104` |
| -1 | Block file <hash> not available. | verbosity 1 to 3 on a block whose file is pruned | `src/rpc/blockchain.cpp:1677` |
| -1 | <hash> not found on disk | verbosity 0 on a pruned block: on the same connection as a 200 head, a partial chunk and a second status line, the order not fixed (Finding R2) | `src/rpc/blockchain.cpp:1620` |

### `getblockbyheight`

[SRC] `src/rpc/blockchain.cpp:1274-1430`, registered `src/rpc/blockchain.cpp:3799` with okSafeMode true and the names `blockhash`, `verbosity|verbose`; the record build. Helpers: `src/rpc/blockchain.cpp:1432-1476`.

| position | argument | type | required | note |
|---|---|---|---|---|
| 0 | `height` | i64 | yes | registered under the name blockhash |
| 1 | `verbosity` | json | no | as getblock |

- result: GetBlock. the runner calls it on the second oracle only (harness/src/scenarios/teranode.rs); the reference registers its height argument under the name blockhash
- safe mode: answers (okSafeMode true at the registration)
- pruning: as getblock
- mock time: no clock read in the handler
- Teranode v0.16.0: implemented, `services/rpc/Server.go:173`, registered `services/rpc/bsvjson/chainsvrcmds.go:877`, handler `services/rpc/handlers.go:177` [SRC]

| code | message | when | cite [SRC] |
|---|---|---|---|
| -8 | Block height out of range | height below 0 or above the tip | `src/rpc/blockchain.cpp:1411` |
| -8 | Verbosity value out of range | a numeric verbosity outside 0..3 | `src/rpc/blockchain.cpp:1078` |
| -8 | Verbosity value not recognized | a string verbosity that names no level | `src/rpc/blockchain.cpp:1095` |
| -8 | Invalid verbosity input type | a verbosity neither number, string nor boolean | `src/rpc/blockchain.cpp:1104` |
| -1 | Block file <hash> not available. | verbosity 1 to 3 on a block whose file is pruned | `src/rpc/blockchain.cpp:1677` |
| -1 | <hash> not found on disk | verbosity 0 on a pruned block: on the same connection as a 200 head, a partial chunk and a second status line, the order not fixed (Finding R2) [SRC], not probed | `src/rpc/blockchain.cpp:1620` |

### `getblockchainactivity`

[SRC] `src/rpc/blockchain.cpp:3649-3683`, registered `src/rpc/blockchain.cpp:3829` with okSafeMode true and the names none; the record build.

- result: BlockchainActivity
- safe mode: answers (okSafeMode true at the registration)
- pruning: no block data read: unchanged by pruning
- mock time: no clock read in the handler
- Teranode v0.16.0: absent, `services/rpc/Server.go:991`, the command parser `services/rpc/Server.go:1061-1065`, answers -32601 Method not found [SRC]

| code | message | when | cite [SRC] |
|---|---|---|---|
| -31 | Error: Peer-to-peer functionality missing or disabled | no connection manager | `src/rpc/blockchain.cpp:3669` |

### `getblockcount`

[SRC] `src/rpc/blockchain.cpp:205-218`, registered `src/rpc/blockchain.cpp:3797` with okSafeMode true and the names none; the record build.

- result: i64
- safe mode: answers (okSafeMode true at the registration)
- pruning: no block data read: unchanged by pruning
- mock time: no clock read in the handler
- Teranode v0.16.0: unimplemented, `services/rpc/Server.go:175`, registered `services/rpc/bsvjson/chainsvrcmds.go:879`, handler `services/rpc/Server.go:389`, answers -1 Command unimplemented [SRC]

### `getblockhash`

[SRC] `src/rpc/blockchain.cpp:801-825`, registered `src/rpc/blockchain.cpp:3800` with okSafeMode true and the names `height`; the record build.

| position | argument | type | required | note |
|---|---|---|---|---|
| 0 | `height` | i64 | yes |  |

- result: string
- safe mode: answers (okSafeMode true at the registration)
- pruning: no block data read: unchanged by pruning
- mock time: no clock read in the handler
- Teranode v0.16.0: implemented, `services/rpc/Server.go:176`, registered `services/rpc/bsvjson/chainsvrcmds.go:880`, handler `services/rpc/handlers.go:218` [SRC]

| code | message | when | cite [SRC] |
|---|---|---|---|
| -8 | Block height out of range | height below 0 or above the tip | `src/rpc/blockchain.cpp:820` |

### `getblockheader`

[SRC] `src/rpc/blockchain.cpp:884-1061`, registered `src/rpc/blockchain.cpp:3801` with okSafeMode true and the names `blockhash`, `verbosity|verbose`; the record build. Helpers: `src/rpc/blockchain.cpp:93-138`, `src/rpc/blockchain.cpp:177-203`.

| position | argument | type | required | note |
|---|---|---|---|---|
| 0 | `blockhash` | string | yes |  |
| 1 | `verbosity` | json | no | 0, 1, 2, a boolean, or a level's name; default 1 |

- result: GetBlockHeader
- safe mode: answers (okSafeMode true at the registration)
- pruning: answers after pruning: size gone, status.data, status.undo and status."disk meta" false; verbosity 2 drops tx and merkleproof (the coinbase is not read) [X]
- mock time: no clock read in the handler
- Teranode v0.16.0: implemented, `services/rpc/Server.go:177`, registered `services/rpc/bsvjson/chainsvrcmds.go:881`, handler `services/rpc/handlers.go:250` [SRC]

| code | message | when | cite [SRC] |
|---|---|---|---|
| -5 | Block not found | the hash names no block index entry | `src/rpc/blockchain.cpp:980` |
| -8 | Verbosity value out of range | a numeric verbosity outside 0..2 | `src/rpc/blockchain.cpp:844` |
| -8 | Verbosity value not recognized | a string verbosity that names no level | `src/rpc/blockchain.cpp:869` |
| -8 | Invalid verbosity input type | a verbosity neither number, string nor boolean | `src/rpc/blockchain.cpp:880` |

### `getchaintips`

[SRC] `src/rpc/blockchain.cpp:2497-2615`, registered `src/rpc/blockchain.cpp:3804` with okSafeMode true and the names none; the record build.

- result: array of ChainTip
- safe mode: answers (okSafeMode true at the registration)
- pruning: status headers-only is chain-tx-count zero, not missing files: a pruned chain still reads active [X]
- mock time: no clock read in the handler
- Teranode v0.16.0: implemented, `services/rpc/Server.go:181`, registered `services/rpc/bsvjson/chainsvrcmds.go:885`, handler `services/rpc/handlers.go:2928` [SRC]

### `getchaintxstats`

[SRC] `src/rpc/blockchain.cpp:3054-3155`, registered `src/rpc/blockchain.cpp:3795` with okSafeMode true and the names `nblocks`, `blockhash`; the record build.

| position | argument | type | required | note |
|---|---|---|---|---|
| 0 | `nblocks` | i64 | no | default one month of blocks, capped at the height - 1 |
| 1 | `blockhash` | string | no | default the tip |

- result: ChainTxStats
- safe mode: answers (okSafeMode true at the registration)
- pruning: no block data read: unchanged by pruning
- mock time: window_interval and txrate are median-time-past differences of the blocks: they follow the block times the mock clock wrote [X]
- Teranode v0.16.0: absent, `services/rpc/Server.go:991`, the command parser `services/rpc/Server.go:1061-1065`, answers -32601 Method not found [SRC]

| code | message | when | cite [SRC] |
|---|---|---|---|
| -5 | Block not found | the hash names no block index entry | `src/rpc/blockchain.cpp:3107` |
| -8 | Block is not in main chain | the block is off the active chain | `src/rpc/blockchain.cpp:3114` |
| -8 | Invalid block count: should be between 0 and the block's height - 1 | nblocks out of range | `src/rpc/blockchain.cpp:3129` |

### `getmempoolinfo`

[SRC] `src/rpc/blockchain.cpp:2644-2673`, registered `src/rpc/blockchain.cpp:3809` with okSafeMode true and the names none; the record build. Helpers: `src/rpc/blockchain.cpp:2617-2642`.

- result: MempoolInfo
- safe mode: answers (okSafeMode true at the registration)
- pruning: no block data read: unchanged by pruning
- mock time: no clock read in the handler
- Teranode v0.16.0: unimplemented, `services/rpc/Server.go:189`, registered `services/rpc/bsvjson/chainsvrcmds.go:892`, handler `services/rpc/Server.go:389`, answers -1 Command unimplemented [SRC]

### `getmerkleproof`

[SRC] `src/rpc/rawtransaction.cpp:2242-2339`, registered `src/rpc/rawtransaction.cpp:2630` with okSafeMode true and the names `txid`, `blockhash`; the record build. Helpers: `src/rpc/rawtransaction.cpp:265-345`.

| position | argument | type | required | note |
|---|---|---|---|---|
| 0 | `txid` | string | yes |  |
| 1 | `blockhash` | string | no |  |

- result: MerkleProof
- safe mode: answers (okSafeMode true at the registration)
- pruning: a pruned block answers -32603 Can't read block from disk [X]
- mock time: no clock read in the handler
- Teranode v0.16.0: absent, `services/rpc/Server.go:991`, the command parser `services/rpc/Server.go:1061-1065`, answers -32601 Method not found [SRC]

| code | message | when | cite [SRC] |
|---|---|---|---|
| -5 | Block not found | a named block hash with no index entry | `src/rpc/rawtransaction.cpp:278` |
| -5 | Transaction not yet in block, -txindex is not enabled, or the block containing the transaction has been pruned | no block named and the index has no entry | `src/rpc/rawtransaction.cpp:334` |
| -32603 | Block for this transaction not found | GetBlockIndex found no block | `src/rpc/rawtransaction.cpp:2290` |
| -32603 | Can't read block from disk | the block's file is pruned [X] | `src/rpc/rawtransaction.cpp:2299` |
| -5 | Transaction(s) not found in provided block | the transaction is not in the block, or it is the only transaction of its block (an empty proof, Edge E1) [X] | `src/rpc/rawtransaction.cpp:2306` |

### `getmerkleproof2`

[SRC] `src/rpc/rawtransaction.cpp:2342-2525`, registered `src/rpc/rawtransaction.cpp:2631` with okSafeMode true and the names `txid`, `blockhash`, `includeFullTx`, `targetType`, `format`; the record build. Helpers: `src/rpc/rawtransaction.cpp:265-345`.

| position | argument | type | required | note |
|---|---|---|---|---|
| 0 | `blockhash` | string | yes | an empty string for the block found through the index |
| 1 | `txid` | string | yes |  |
| 2 | `includeFullTx` | bool | no | default false |
| 3 | `targetType` | string | no | hash, header or merkleroot; default hash |
| 4 | `format` | string | no | json; default json |

- result: MerkleProof2. positional only: the handler reads blockhash from params[0] and txid from params[1], the registration names them txid, blockhash (Finding R1) [X]
- safe mode: answers (okSafeMode true at the registration)
- pruning: as getmerkleproof
- mock time: no clock read in the handler
- Teranode v0.16.0: absent, `services/rpc/Server.go:991`, the command parser `services/rpc/Server.go:1061-1065`, answers -32601 Method not found [SRC]

| code | message | when | cite [SRC] |
|---|---|---|---|
| -5 | Block not found | a named block hash with no index entry | `src/rpc/rawtransaction.cpp:278` |
| -5 | Transaction not yet in block, -txindex is not enabled, or the block containing the transaction has been pruned | no block named and the index has no entry | `src/rpc/rawtransaction.cpp:334` |
| -1 | Number of inputs is <n>,  must be between 2 and 5 | fewer than 2 or more than 5 arguments | `src/rpc/rawtransaction.cpp:2397` |
| -32602 | targetType is '<s>',  must be 'hash', 'header' or 'merkleroot' | an unknown target type [X] | `src/rpc/rawtransaction.cpp:2423` |
| -32602 | format is '<s>',  must be 'json' | a format other than json | `src/rpc/rawtransaction.cpp:2431` |
| -32603 | Block for this transaction not found | GetBlockIndex found no block | `src/rpc/rawtransaction.cpp:2412` |
| -32603 | Can't read block from disk | the block's file is pruned | `src/rpc/rawtransaction.cpp:2443` |
| -5 | Transaction(s) not found in provided block | as getmerkleproof, the one-transaction block included (Edge E1) [X] | `src/rpc/rawtransaction.cpp:2450` |

### `getnetworkinfo`

[SRC] `src/rpc/net.cpp:543-667`, registered `src/rpc/net.cpp:896` with okSafeMode true and the names none; the record build.

- result: NetworkInfo
- safe mode: answers (okSafeMode true at the registration)
- pruning: no block data read: unchanged by pruning
- mock time: timeoffset is nTimeOffset, moved only by five peer samples (src/timedata.cpp:74-82): 0 on an isolated instance under any mock clock [X]
- Teranode v0.16.0: unimplemented, `services/rpc/Server.go:281`, registered `services/rpc/bsvjson/chainsvrcmds.go:895`, handler `services/rpc/Server.go:389`, answers -1 Command unimplemented [SRC]

### `getnewaddress`

[SRC] `src/wallet/rpcwallet.cpp:119-172`, registered `src/wallet/rpcwallet.cpp:3524` with okSafeMode true and the names `account`; the wallet build.

| position | argument | type | required | note |
|---|---|---|---|---|
| 0 | `account` | string | no | deprecated |

- result: string. the wallet build only ($BSV_SPEC_REFERENCE_BINARY_WALLET, the maintainers' build); -32601 Method not found on the node of record [X]
- safe mode: answers (okSafeMode true at the registration)
- pruning: no block data read: unchanged by pruning
- mock time: no clock read in the handler
- Teranode v0.16.0: wallet, `services/rpc/Server.go:243`, registered `services/rpc/bsvjson/walletsvrcmds.go:660`, handler `services/rpc/Server.go:405`, answers -1 This implementation does not implement wallet commands [SRC]

| code | message | when | cite [SRC] |
|---|---|---|---|
| -12 | Error: Keypool ran out, please call keypoolrefill [...] | no key left | `src/wallet/rpcwallet.cpp:164` |

### `getorphaninfo`

[SRC] `src/rpc/blockchain.cpp:2675-2693`, registered `src/rpc/blockchain.cpp:3833` with okSafeMode true and the names none; the record build.

- result: OrphanInfo
- safe mode: answers (okSafeMode true at the registration)
- pruning: no block data read: unchanged by pruning
- mock time: no clock read in the handler
- Teranode v0.16.0: absent, `services/rpc/Server.go:991`, the command parser `services/rpc/Server.go:1061-1065`, answers -32601 Method not found [SRC]

### `getpeerinfo`

[SRC] `src/rpc/net.cpp:69-280`, registered `src/rpc/net.cpp:891` with okSafeMode true and the names none; the record build.

- result: array of json. an empty array on an isolated instance [X]; the per-peer fields are cited, not typed (no isolated reply carries one)
- safe mode: answers (okSafeMode true at the registration)
- pruning: no block data read: unchanged by pruning
- mock time: no clock read in the handler
- Teranode v0.16.0: implemented, `services/rpc/Server.go:193`, registered `services/rpc/bsvjson/chainsvrcmds.go:898`, handler `services/rpc/handlers.go:1203` [SRC]

### `getrawmempool`

[SRC] `src/rpc/blockchain.cpp:440-500`, registered `src/rpc/blockchain.cpp:3810` with okSafeMode true and the names `verbose`; the record build. Helpers: `src/rpc/blockchain.cpp:414-438`, `src/rpc/blockchain.cpp:378-412`.

| position | argument | type | required | note |
|---|---|---|---|---|
| 0 | `verbose` | bool | no | default false |

- result: RawMempool
- safe mode: answers (okSafeMode true at the registration)
- pruning: no block data read: unchanged by pruning
- mock time: the entries' time is the acceptance time, GetTime() at submission: the mock clock when set [X]
- Teranode v0.16.0: implemented, `services/rpc/Server.go:194`, registered `services/rpc/bsvjson/chainsvrcmds.go:899`, handler `services/rpc/handlers.go:1353` [SRC]

### `getrawnonfinalmempool`

[SRC] `src/rpc/blockchain.cpp:502-557`, registered `src/rpc/blockchain.cpp:3811` with okSafeMode true and the names none; the record build.

- result: array of string
- safe mode: answers (okSafeMode true at the registration)
- pruning: no block data read: unchanged by pruning
- mock time: no clock read in the handler
- Teranode v0.16.0: absent, `services/rpc/Server.go:991`, the command parser `services/rpc/Server.go:1061-1065`, answers -32601 Method not found [SRC]

### `getrawtransaction`

[SRC] `src/rpc/rawtransaction.cpp:53-256`, registered `src/rpc/rawtransaction.cpp:2620` with okSafeMode true and the names `txid`, `verbose`; the record build. Helpers: `src/core_write.cpp:237-332`.

| position | argument | type | required | note |
|---|---|---|---|---|
| 0 | `txid` | string | yes |  |
| 1 | `verbose` | json | no | a boolean or a number; default false |

- result: GetRawTransaction. two definitions: the streaming entry and the writer it calls
- safe mode: answers (okSafeMode true at the registration)
- pruning: with -txindex the transaction is read from its block file: a pruned block answers -5 [X]
- mock time: no clock read in the handler
- Teranode v0.16.0: implemented, `services/rpc/Server.go:195`, registered `services/rpc/bsvjson/chainsvrcmds.go:900`, handler `services/rpc/handlers.go:559` [SRC]

| code | message | when | cite [SRC] |
|---|---|---|---|
| -8 | txid must be of length 64 (not <n>) | a txid that is not 64 hex characters | `src/rpc/server.cpp:155` |
| -8 | txid must be hexadecimal string (not '<s>') and length of it must be divisible by 2 | a txid that is not hex | `src/rpc/server.cpp:151` |
| -3 | Invalid type provided. Verbose parameter must be a boolean. | a verbose neither number nor boolean | `src/rpc/rawtransaction.cpp:189` |
| -5 | No such mempool or blockchain transaction. If using -prune, the transaction may be in a pruned block. Use gettransaction for wallet transactions. | not in the pool and not readable through the index (a pruned block included) [X] | `src/rpc/rawtransaction.cpp:200` |

### `getreceivedbyaddress`

[SRC] `src/wallet/rpcwallet.cpp:680-764`, registered `src/wallet/rpcwallet.cpp:3527` with okSafeMode false and the names `address`, `minconf`; the wallet build.

| position | argument | type | required | note |
|---|---|---|---|---|
| 0 | `address` | string | yes |  |
| 1 | `minconf` | i64 | no | default 1 |

- result: f64. the wallet build only ($BSV_SPEC_REFERENCE_BINARY_WALLET, the maintainers' build); -32601 Method not found on the node of record [X]
- safe mode: refused with -2 `Safe mode: <warning>` before the handler runs (okSafeMode false; the gate `src/init.cpp:325-332`)
- pruning: no block data read: unchanged by pruning
- mock time: no clock read in the handler
- Teranode v0.16.0: wallet, `services/rpc/Server.go:246`, registered `services/rpc/bsvjson/walletsvrcmds.go:663`, handler `services/rpc/Server.go:405`, answers -1 This implementation does not implement wallet commands [SRC]

| code | message | when | cite [SRC] |
|---|---|---|---|
| -5 | Invalid Bitcoin address | the address does not decode [X] | `src/wallet/rpcwallet.cpp:724` |

### `getsafemodeinfo`

[SRC] `src/rpc/safe_mode.cpp:97-196`, registered `src/rpc/safe_mode.cpp:206` with okSafeMode true and the names none; the record build. Helpers: `src/safe_mode.cpp:450-553`.

- result: SafeModeInfo. safemodeenabled is the fork-driven level; -testsafemode refuses the okSafeMode-false handlers while this answers false (Edge E2) [X]
- safe mode: answers (okSafeMode true at the registration)
- pruning: no block data read: unchanged by pruning
- mock time: timeutc is std::time(nullptr), the wall clock: under a mock clock it differs from every block-derived time [X]
- Teranode v0.16.0: absent, `services/rpc/Server.go:991`, the command parser `services/rpc/Server.go:1061-1065`, answers -32601 Method not found [SRC]

### `gettransaction`

[SRC] `src/wallet/rpcwallet.cpp:2061-2187`, registered `src/wallet/rpcwallet.cpp:3528` with okSafeMode false and the names `txid`, `include_watchonly`; the wallet build.

| position | argument | type | required | note |
|---|---|---|---|---|
| 0 | `txid` | string | yes |  |
| 1 | `include_watchonly` | bool | no | default false |

- result: WalletTransaction. the wallet build only ($BSV_SPEC_REFERENCE_BINARY_WALLET, the maintainers' build); -32601 Method not found on the node of record [X]
- safe mode: refused with -2 `Safe mode: <warning>` before the handler runs (okSafeMode false; the gate `src/init.cpp:325-332`)
- pruning: no block data read: unchanged by pruning
- mock time: no clock read in the handler
- Teranode v0.16.0: wallet, `services/rpc/Server.go:247`, registered `services/rpc/bsvjson/walletsvrcmds.go:664`, handler `services/rpc/Server.go:405`, answers -1 This implementation does not implement wallet commands [SRC]

| code | message | when | cite [SRC] |
|---|---|---|---|
| -5 | Invalid or non-wallet transaction id | the wallet holds no such transaction [X] | `src/wallet/rpcwallet.cpp:2160` |

### `gettxout`

[SRC] `src/rpc/blockchain.cpp:1923-2028`, registered `src/rpc/blockchain.cpp:3812` with okSafeMode true and the names `txid`, `n`, `include_mempool`; the record build.

| position | argument | type | required | note |
|---|---|---|---|---|
| 0 | `txid` | string | yes |  |
| 1 | `n` | i64 | yes |  |
| 2 | `include_mempool` | bool | no | default true |

- result: nullable of Coin. null, never an error, for an absent or spent output; with include_mempool a pool spend makes it null, a pool output answers with confirmations 0
- safe mode: answers (okSafeMode true at the registration)
- pruning: reads the UTXO set, not block files: a pruned block's unspent coin still answers [X]
- mock time: no clock read in the handler
- Teranode v0.16.0: unimplemented, `services/rpc/Server.go:196`, registered `services/rpc/bsvjson/chainsvrcmds.go:901`, handler `services/rpc/Server.go:389`, answers -1 Command unimplemented [SRC]

| code | message | when | cite [SRC] |
|---|---|---|---|
| -20 | Best block not in index | the coins view's best block has no index entry | `src/rpc/blockchain.cpp:1987` |

### `gettxoutsetinfo`

[SRC] `src/rpc/blockchain.cpp:1877-1921`, registered `src/rpc/blockchain.cpp:3814` with okSafeMode true and the names none; the record build.

- result: UtxoSetInfo
- safe mode: answers (okSafeMode true at the registration)
- pruning: no block data read: unchanged by pruning
- mock time: no clock read in the handler
- Teranode v0.16.0: wallet, `services/rpc/Server.go:248`, registered `services/rpc/bsvjson/chainsvrcmds.go:903`, handler `services/rpc/Server.go:405`, answers -1 This implementation does not implement wallet commands [SRC]

| code | message | when | cite [SRC] |
|---|---|---|---|
| -32603 | Unable to read UTXO set | GetUTXOStats failed | `src/rpc/blockchain.cpp:1918` |

### `getwalletinfo`

[SRC] `src/wallet/rpcwallet.cpp:2798-2878`, registered `src/wallet/rpcwallet.cpp:3530` with okSafeMode false and the names none; the wallet build.

- result: WalletInfo. the wallet build only ($BSV_SPEC_REFERENCE_BINARY_WALLET, the maintainers' build); -32601 Method not found on the node of record [X]
- safe mode: refused with -2 `Safe mode: <warning>` before the handler runs (okSafeMode false; the gate `src/init.cpp:325-332`)
- pruning: no block data read: unchanged by pruning
- mock time: no clock read in the handler
- Teranode v0.16.0: wallet, `services/rpc/Server.go:250`, registered `services/rpc/bsvjson/walletsvrcmds.go:665`, handler `services/rpc/Server.go:405`, answers -1 This implementation does not implement wallet commands [SRC]

### `ignoresafemodeforblock`

[SRC] `src/rpc/safe_mode.cpp:12-51`, registered `src/rpc/safe_mode.cpp:204` with okSafeMode true and the names `blockhash`; the record build.

| position | argument | type | required | note |
|---|---|---|---|---|
| 0 | `blockhash` | string | yes |  |

- result: null
- safe mode: answers (okSafeMode true at the registration)
- pruning: no block data read: unchanged by pruning
- mock time: no clock read in the handler
- Teranode v0.16.0: absent, `services/rpc/Server.go:991`, the command parser `services/rpc/Server.go:1061-1065`, answers -32601 Method not found [SRC]

| code | message | when | cite [SRC] |
|---|---|---|---|
| -32602 | Unknown block!\n | the hash names no block index entry | `src/rpc/safe_mode.cpp:37` |
| -32602 | Can not ignore a block on the main chain!\n | the block is on the active chain [X] | `src/rpc/safe_mode.cpp:42` |

### `invalidateblock`

[SRC] `src/rpc/blockchain.cpp:2732-2768`, registered `src/rpc/blockchain.cpp:3822` with okSafeMode true and the names `blockhash`; the record build.

| position | argument | type | required | note |
|---|---|---|---|---|
| 0 | `blockhash` | string | yes |  |

- result: null
- safe mode: answers (okSafeMode true at the registration)
- pruning: no block data read: unchanged by pruning
- mock time: no clock read in the handler
- Teranode v0.16.0: implemented, `services/rpc/Server.go:201`, registered `services/rpc/bsvjson/chainsvrcmds.go:906`, handler `services/rpc/handlers.go:1862` [SRC]

| code | message | when | cite [SRC] |
|---|---|---|---|
| -5 | Block not found | the hash names no block index entry | `src/rpc/blockchain.cpp:2755` |
| -20 | <reject reason> | InvalidateBlock left the state invalid | `src/rpc/blockchain.cpp:2764` |

### `preciousblock`

[SRC] `src/rpc/blockchain.cpp:2695-2730`, registered `src/rpc/blockchain.cpp:3817` with okSafeMode true and the names `blockhash`; the record build.

| position | argument | type | required | note |
|---|---|---|---|---|
| 0 | `blockhash` | string | yes |  |

- result: null
- safe mode: answers (okSafeMode true at the registration)
- pruning: no block data read: unchanged by pruning
- mock time: no clock read in the handler
- Teranode v0.16.0: unimplemented, `services/rpc/Server.go:284`, registered `services/rpc/bsvjson/chainsvrcmds.go:908`, handler `services/rpc/Server.go:389`, answers -1 Command unimplemented [SRC]

| code | message | when | cite [SRC] |
|---|---|---|---|
| -5 | Block not found | the hash names no block index entry | `src/rpc/blockchain.cpp:2719` |
| -20 | <reject reason> | PreciousBlock left the state invalid | `src/rpc/blockchain.cpp:2726` |

### `prioritisetransaction`

[SRC] `src/rpc/mining.cpp:312-344`, registered `src/rpc/mining.cpp:963` with okSafeMode true and the names `txid`, `priority_delta`, `fee_delta`; the record build.

| position | argument | type | required | note |
|---|---|---|---|---|
| 0 | `txid` | string | yes |  |
| 1 | `priority_delta` | f64 | yes | must be 0 |
| 2 | `fee_delta` | i64 | yes | satoshis |

- result: bool
- safe mode: answers (okSafeMode true at the registration)
- pruning: no block data read: unchanged by pruning
- mock time: no clock read in the handler
- Teranode v0.16.0: absent, `services/rpc/Server.go:991`, the command parser `services/rpc/Server.go:1061-1065`, answers -32601 Method not found [SRC]

| code | message | when | cite [SRC] |
|---|---|---|---|
| -8 | Dummy parameter must be set to zero. | priority_delta not 0 [X] | `src/rpc/mining.cpp:338` |

### `pruneblockchain`

[SRC] `src/rpc/blockchain.cpp:1810-1875`, registered `src/rpc/blockchain.cpp:3815` with okSafeMode true and the names `height`; the record build.

| position | argument | type | required | note |
|---|---|---|---|---|
| 0 | `height` | i64 | yes | a height, or a block time above 1000000000 |

- result: u64
- safe mode: answers (okSafeMode true at the registration)
- pruning: the handler itself: -prune=1 (manual) enables it (src/init.cpp:2821-2826); a height inside the last GetMinBlocksToKeep (288) is clamped to tip - 288 and that height is the answer [X]
- mock time: no clock read in the handler
- Teranode v0.16.0: absent, `services/rpc/Server.go:991`, the command parser `services/rpc/Server.go:1061-1065`, answers -32601 Method not found [SRC]

| code | message | when | cite [SRC] |
|---|---|---|---|
| -1 | Cannot prune blocks because node is not in prune mode. | the node runs without -prune | `src/rpc/blockchain.cpp:1829` |
| -8 | Negative block height. | height below 0 | `src/rpc/blockchain.cpp:1834` |
| -8 | Could not find block with at least the specified timestamp. | a timestamp past the chain | `src/rpc/blockchain.cpp:1851` |
| -1 | Blockchain is too short for pruning. | the tip below the chain's PruneAfterHeight (regtest 1000, src/chainparams.cpp:1509) | `src/rpc/blockchain.cpp:1862` |
| -8 | Blockchain is shorter than the attempted prune height. | height above the tip | `src/rpc/blockchain.cpp:1866` |

### `queryBlacklist`

[SRC] `src/rpc/frozentxo_rpc.cpp:404-499`, registered `src/rpc/frozentxo_rpc.cpp:906` with okSafeMode true and the names none; the record build.

- result: Blacklist
- safe mode: answers (okSafeMode true at the registration)
- pruning: no block data read: unchanged by pruning
- mock time: no clock read in the handler
- Teranode v0.16.0: absent, `services/rpc/Server.go:991`, the command parser `services/rpc/Server.go:1061-1065`, answers -32601 Method not found [SRC]

### `queryConfiscationTxidWhitelist`

[SRC] `src/rpc/frozentxo_rpc.cpp:799-894`, registered `src/rpc/frozentxo_rpc.cpp:910` with okSafeMode true and the names `verbose`; the record build.

| position | argument | type | required | note |
|---|---|---|---|---|
| 0 | `verbose` | bool | no | default false |

- result: Whitelist
- safe mode: answers (okSafeMode true at the registration)
- pruning: no block data read: unchanged by pruning
- mock time: no clock read in the handler
- Teranode v0.16.0: absent, `services/rpc/Server.go:991`, the command parser `services/rpc/Server.go:1061-1065`, answers -32601 Method not found [SRC]

### `reconsiderblock`

[SRC] `src/rpc/blockchain.cpp:2770-2818`, registered `src/rpc/blockchain.cpp:3823` with okSafeMode true and the names `blockhash`; the record build.

| position | argument | type | required | note |
|---|---|---|---|---|
| 0 | `blockhash` | string | yes |  |

- result: null
- safe mode: answers (okSafeMode true at the registration)
- pruning: re-activation reads block data: a pruned block cannot be reconnected (not run)
- mock time: no clock read in the handler
- Teranode v0.16.0: implemented, `services/rpc/Server.go:205`, registered `services/rpc/bsvjson/chainsvrcmds.go:909`, handler `services/rpc/handlers.go:1919` [SRC]

| code | message | when | cite [SRC] |
|---|---|---|---|
| -5 | Block not found | the hash names no block index entry | `src/rpc/blockchain.cpp:2793` |
| -20 | <reject reason> | ActivateBestChain reported an error | `src/rpc/blockchain.cpp:2814` |

### `reconsidersafemodeforblock`

[SRC] `src/rpc/safe_mode.cpp:53-95`, registered `src/rpc/safe_mode.cpp:205` with okSafeMode true and the names `blockhash`; the record build.

| position | argument | type | required | note |
|---|---|---|---|---|
| 0 | `blockhash` | string | yes |  |

- result: null
- safe mode: answers (okSafeMode true at the registration)
- pruning: no block data read: unchanged by pruning
- mock time: no clock read in the handler
- Teranode v0.16.0: absent, `services/rpc/Server.go:991`, the command parser `services/rpc/Server.go:1061-1065`, answers -32601 Method not found [SRC]

| code | message | when | cite [SRC] |
|---|---|---|---|
| -32602 | Unknown block!\n | the hash names no block index entry [X] | `src/rpc/safe_mode.cpp:77` |
| -32602 | Can not reconsider a block on the main chain!\n | the block is on the active chain | `src/rpc/safe_mode.cpp:82` |

### `sendrawtransaction`

[SRC] `src/rpc/rawtransaction.cpp:1530-1700`, registered `src/rpc/rawtransaction.cpp:2624` with okSafeMode false and the names `hexstring`, `allowhighfees`, `dontcheckfee`; the record build.

| position | argument | type | required | note |
|---|---|---|---|---|
| 0 | `hexstring` | string | yes |  |
| 1 | `allowhighfees` | bool | no | default false |
| 2 | `dontcheckfee` | bool | no | default false |

- result: string
- safe mode: refused with -2 `Safe mode: <warning>` before the handler runs (okSafeMode false; the gate `src/init.cpp:325-332`)
- pruning: no block data read: unchanged by pruning
- mock time: the acceptance time is GetTime() (src/utiltime.cpp:23-29): the mock clock when set
- Teranode v0.16.0: implemented, `services/rpc/Server.go:207`, registered `services/rpc/bsvjson/chainsvrcmds.go:911`, handler `services/rpc/handlers.go:830` [SRC]

| code | message | when | cite [SRC] |
|---|---|---|---|
| -3 | Expected type string, got <type> | an argument of the wrong JSON type (RPCTypeCheck) | `src/rpc/server.cpp:85` |
| -22 | TX decode failed | the hex is not a transaction | `src/rpc/rawtransaction.cpp:1565` |
| -31 | Error: Peer-to-peer functionality missing or disabled | no connection manager | `src/rpc/rawtransaction.cpp:1583` |
| -25 | Missing inputs | an input is neither in the UTXO set nor in the pool | `src/rpc/rawtransaction.cpp:1638` |
| -26 | <reject code>: <reject reason> | validation rejected the transaction | `src/rpc/rawtransaction.cpp:1642` |
| -25 | <reject reason> | any other refusal | `src/rpc/rawtransaction.cpp:1648` |
| -27 | Transaction already in the mempool | already in the pool or the non-final pool [X] | `src/rpc/rawtransaction.cpp:1656` |

### `sendrawtransactions`

[SRC] `src/rpc/rawtransaction.cpp:1798-2240`, registered `src/rpc/rawtransaction.cpp:2625` with okSafeMode false and the names `inputs`; the record build.

| position | argument | type | required | note |
|---|---|---|---|---|
| 0 | `inputs` | array of json | yes | objects: hex, allowhighfees, dontcheckfee, listunconfirmedancestors, config |

- result: SendRawTransactions. answers 200 with the refused transactions listed (missing inputs read reject_code 16 missing-inputs, unlike sendrawtransaction's -25); accepted ones are never listed
- safe mode: refused with -2 `Safe mode: <warning>` before the handler runs (okSafeMode false; the gate `src/init.cpp:325-332`)
- pruning: no block data read: unchanged by pruning
- mock time: the acceptance time is GetTime(): the mock clock when set
- Teranode v0.16.0: absent, `services/rpc/Server.go:991`, the command parser `services/rpc/Server.go:1061-1065`, answers -32601 Method not found [SRC]

| code | message | when | cite [SRC] |
|---|---|---|---|
| -8 | Invalid parameter: An empty json array of objects | an empty array | `src/rpc/rawtransaction.cpp:1941` |
| -8 | Invalid parameter: Missing the hex string of the raw transaction | an object without hex | `src/rpc/rawtransaction.cpp:2004` |
| -22 | TX decode failed | an undecodable hex | `src/rpc/rawtransaction.cpp:2009` |
| -8 | listunconfirmedancestors: Invalid value | a listunconfirmedancestors that is not a boolean | `src/rpc/rawtransaction.cpp:2073` |

### `setban`

[SRC] `src/rpc/net.cpp:669-757`, registered `src/rpc/net.cpp:897` with okSafeMode true and the names `subnet`, `command`, `bantime`, `absolute`; the record build.

| position | argument | type | required | note |
|---|---|---|---|---|
| 0 | `subnet` | string | yes | an IP, or a subnet when it holds a '/' |
| 1 | `command` | string | yes | add or remove; any other word answers the help text |
| 2 | `bantime` | i64 | no | seconds, or a timestamp when absolute; 0 or absent takes -bantime (default 86400, src/net/net.cpp:545-549) |
| 3 | `absolute` | bool | no |  |

- result: null. not called by the #66 runner; the row stands for #88's alert-ban divergence (#154): Teranode serves the operator's ban by RPC beside its alert path
- safe mode: answers (okSafeMode true at the registration)
- pruning: no block data read: unchanged by pruning
- mock time: the ban's start and end read GetTime() (src/net/net.cpp:543-549), so a mock time moves them
- Teranode v0.16.0: implemented, `services/rpc/Server.go:208`, registered `services/rpc/bsvjson/chainsvrcmds.go:912`, handler `services/rpc/handlers.go:2447` [SRC]

| code | message | when | cite [SRC] |
|---|---|---|---|
| -31 | Error: Peer-to-peer functionality missing or disabled | no connection manager | `src/rpc/net.cpp:702` |
| -30 | Error: Invalid IP/Subnet | the subnet argument does not parse | `src/rpc/net.cpp:723` |
| -23 | Error: IP/Subnet already banned | add on an address already banned | `src/rpc/net.cpp:730` |
| -30 | Error: Unban failed. Requested address/subnet was not previously banned. | remove on an address not banned | `src/rpc/net.cpp:752` |

### `setmocktime`

[SRC] `src/rpc/misc.cpp:980-1008`, registered `src/rpc/misc.cpp:1339` with okSafeMode true and the names `timestamp`; the record build.

| position | argument | type | required | note |
|---|---|---|---|---|
| 0 | `timestamp` | i64 | yes | 0 restores the wall clock |

- result: null
- safe mode: answers (okSafeMode true at the registration)
- pruning: no block data read: unchanged by pruning
- mock time: sets nMockTime (src/utiltime.cpp:31-33); GetTime() answers it (src/utiltime.cpp:23-29) while GetTimeMillis, GetTimeMicros and std::time do not move; a relaunch clears it
- Teranode v0.16.0: absent, `services/rpc/Server.go:991`, the command parser `services/rpc/Server.go:1061-1065`, answers -32601 Method not found [SRC]

| code | message | when | cite [SRC] |
|---|---|---|---|
| -1 | setmocktime for regression testing (-regtest mode) only | a chain that does not mine on demand | `src/rpc/misc.cpp:994` |
| -3 | Expected type number, got <type> | a timestamp that is not a number [X] | `src/rpc/server.cpp:85` |

### `softrejectblock`

[SRC] `src/rpc/blockchain.cpp:2820-2892`, registered `src/rpc/blockchain.cpp:3824` with okSafeMode true and the names `blockhash`, `numblocks`; the record build.

| position | argument | type | required | note |
|---|---|---|---|---|
| 0 | `blockhash` | string | yes |  |
| 1 | `numblocks` | i64 | yes |  |

- result: null
- safe mode: answers (okSafeMode true at the registration)
- pruning: no block data read: unchanged by pruning
- mock time: no clock read in the handler
- Teranode v0.16.0: absent, `services/rpc/Server.go:991`, the command parser `services/rpc/Server.go:1061-1065`, answers -32601 Method not found [SRC]

| code | message | when | cite [SRC] |
|---|---|---|---|
| -8 | Parameter numblocks must not be negative | numblocks below 0 | `src/rpc/blockchain.cpp:2863` |
| -5 | Block not found | the hash names no block index entry | `src/rpc/blockchain.cpp:2874` |
| -1 | Error marking block as soft rejected | SoftRejectBlockNL refused (the reasons are in the node's log) | `src/rpc/blockchain.cpp:2882` |
| -20 | <reject reason> | the reorg away from the block failed | `src/rpc/blockchain.cpp:2888` |

### `stop`

[SRC] `src/rpc/server.cpp:265-278`, registered `src/rpc/server.cpp:303` with okSafeMode true and the names none; the record build.

- result: string. answers Bitcoin server stopping, then shuts down
- safe mode: answers (okSafeMode true at the registration)
- pruning: no block data read: unchanged by pruning
- mock time: no clock read in the handler
- Teranode v0.16.0: implemented, `services/rpc/Server.go:210`, registered `services/rpc/bsvjson/chainsvrcmds.go:917`, handler `services/rpc/Server.go:582` [SRC]

### `submitblock`

[SRC] `src/rpc/mining.cpp:916-953`, registered `src/rpc/mining.cpp:966` with okSafeMode true and the names `hexdata`, `parameters`; the record build. Helpers: `src/rpc/mining.cpp:830-876`, `src/rpc/mining.cpp:348-368`.

| position | argument | type | required | note |
|---|---|---|---|---|
| 0 | `hexdata` | string | yes |  |
| 1 | `parameters` | json | no | ignored |

- result: nullable of string. an invalid block is a RESULT string, never an error: null when accepted, else the reject reason, rejected, duplicate, duplicate-invalid, duplicate-inconclusive or inconclusive [X]
- safe mode: answers (okSafeMode true at the registration)
- pruning: no block data read: unchanged by pruning
- mock time: no clock read in the handler
- Teranode v0.16.0: unimplemented, `services/rpc/Server.go:211`, registered `services/rpc/bsvjson/chainsvrcmds.go:918`, handler `services/rpc/Server.go:389`, answers -1 Command unimplemented [SRC]

| code | message | when | cite [SRC] |
|---|---|---|---|
| -22 | Block decode failed | the hex is not a block [X] | `src/rpc/mining.cpp:944` |
| -22 | Block does not start with a coinbase | no transaction, or transaction 0 is not a coinbase | `src/rpc/mining.cpp:838` |
| -26 | bad-txns-vout-p2sh | the coinbase pays to P2SH | `src/rpc/mining.cpp:842` |
| -25 | <reject reason> | validation reported an error state (not an invalid block) | `src/rpc/mining.cpp:356` |

### `validateaddress`

[SRC] `src/rpc/misc.cpp:206-300`, registered `src/rpc/misc.cpp:1330` with okSafeMode true and the names `address`; the record build.

| position | argument | type | required | note |
|---|---|---|---|---|
| 0 | `address` | string | yes |  |

- result: AddressInfo. an invalid address is the result {isvalid: false}, never an error [X]; the wallet fields only on the wallet build
- safe mode: answers (okSafeMode true at the registration)
- pruning: no block data read: unchanged by pruning
- mock time: no clock read in the handler
- Teranode v0.16.0: unimplemented, `services/rpc/Server.go:213`, registered `services/rpc/bsvjson/chainsvrcmds.go:921`, handler `services/rpc/Server.go:389`, answers -1 Command unimplemented [SRC]

### `verifychain`

[SRC] `src/rpc/blockchain.cpp:2321-2354`, registered `src/rpc/blockchain.cpp:3816` with okSafeMode true and the names `checklevel`, `nblocks`; the record build.

| position | argument | type | required | note |
|---|---|---|---|---|
| 0 | `checklevel` | i64 | no | default -checklevel |
| 1 | `nblocks` | i64 | no | default -checkblocks |

- result: bool
- safe mode: answers (okSafeMode true at the registration)
- pruning: reads block files for its depth: pruned blocks inside the depth are not checkable (not run)
- mock time: no clock read in the handler
- Teranode v0.16.0: unimplemented, `services/rpc/Server.go:214`, registered `services/rpc/bsvjson/chainsvrcmds.go:922`, handler `services/rpc/Server.go:389`, answers -1 Command unimplemented [SRC]

### `verifymerkleproof`

[SRC] `src/rpc/rawtransaction.cpp:2527-2612`, registered `src/rpc/rawtransaction.cpp:2632` with okSafeMode true and the names `proof`, `txid`; the record build.

| position | argument | type | required | note |
|---|---|---|---|---|
| 0 | `proof` | json | yes | getmerkleproof's object |
| 1 | `txid` | string | no |  |

- result: bool. false, never an error, for a proof that does not reach the target's merkle root
- safe mode: answers (okSafeMode true at the registration)
- pruning: no block data read: unchanged by pruning
- mock time: no clock read in the handler
- Teranode v0.16.0: absent, `services/rpc/Server.go:991`, the command parser `services/rpc/Server.go:1061-1065`, answers -32601 Method not found [SRC]

| code | message | when | cite [SRC] |
|---|---|---|---|
| -8 | Invalid parameter, argument 1 must be non-null | a null proof [X] | `src/rpc/rawtransaction.cpp:2559` |
| -8 | "flags" must be a numeric value | flags not a number | `src/rpc/rawtransaction.cpp:2567` |
| -8 | verifymerkleproof only supports "flags" with value 2 | flags other than 2 | `src/rpc/rawtransaction.cpp:2571` |
| -8 | "index" must be a positive value | a negative index | `src/rpc/rawtransaction.cpp:2580` |
| -8 | "target" must be a block header Json object | target not an object | `src/rpc/rawtransaction.cpp:2586` |
| -8 | "nodes" must be a Json array | nodes not an array | `src/rpc/rawtransaction.cpp:2592` |

### `verifyscript`

[SRC] `src/rpc/misc.cpp:506-915`, registered `src/rpc/misc.cpp:1333` with okSafeMode true and the names `scripts`, `stopOnFirstInvalid`, `totalTimeout`; the record build.

| position | argument | type | required | note |
|---|---|---|---|---|
| 0 | `scripts` | array of json | yes | objects: tx, n, flags, reportflags, prevblockhash, txo |
| 1 | `stopOnFirstInvalid` | bool | no | default true |
| 2 | `totalTimeout` | i64 | no | milliseconds, default 100 |

- result: array of ScriptVerdict
- safe mode: answers (okSafeMode true at the registration)
- pruning: finds the spent output through the UTXO set and the pool, not block files
- mock time: the budget is std::chrono::steady_clock: the mock clock never moves it
- Teranode v0.16.0: absent, `services/rpc/Server.go:991`, the command parser `services/rpc/Server.go:1061-1065`, answers -32601 Method not found [SRC]

| code | message | when | cite [SRC] |
|---|---|---|---|
| -8 | Missing required argument (scripts)! | no argument | `src/rpc/misc.cpp:598` |
| -8 | Too many arguments (>3)! | more than three | `src/rpc/misc.cpp:602` |
| -8 | Invalid value for totalTimeout argument! | a negative timeout | `src/rpc/misc.cpp:623` |
| -22 | TX decode failed for scripts[<i>].tx! | an undecodable tx [X] | `src/rpc/misc.cpp:683` |
| -8 | Unable to find TXO spent by transaction scripts[<i>].tx! | no txo given and none in the UTXO set or pool | `src/rpc/misc.cpp:796` |

### `waitforptvcompletion`

[SRC] `src/rpc/blockchain.cpp:3769-3786`, registered `src/rpc/blockchain.cpp:3834` with okSafeMode true and the names none; the record build.

- result: null. blocks until the validator's queue is empty; no timeout argument
- safe mode: answers (okSafeMode true at the registration)
- pruning: no block data read: unchanged by pruning
- mock time: no clock read in the handler
- Teranode v0.16.0: absent, `services/rpc/Server.go:991`, the command parser `services/rpc/Server.go:1061-1065`, answers -32601 Method not found [SRC]
<!-- rpc_contract: handlers end -->

## 6. The result types

[D] Every object is a type with its fields, each field cited at the line that writes it [SRC]; `may be absent` is a field
the handler writes only in some cases (the note says which), and `nullable` one written as `null`.

<!-- rpc_contract: types begin -->
#### `AddressInfo` (`src/rpc/misc.cpp:206-300`)

| field | type | cite [SRC] | note |
|---|---|---|---|
| `isvalid` | bool | `src/rpc/misc.cpp:261` |  |
| `address` | string, may be absent | `src/rpc/misc.cpp:264` |  |
| `scriptPubKey` | string, may be absent | `src/rpc/misc.cpp:267` |  |
| `ismine` | bool, may be absent | `src/rpc/misc.cpp:272` |  |
| `iswatchonly` | bool, may be absent | `src/rpc/misc.cpp:274` |  |
| `isscript` | bool, may be absent | `src/rpc/misc.cpp:169` |  |
| `pubkey` | string, may be absent | `src/rpc/misc.cpp:171` |  |
| `iscompressed` | bool, may be absent | `src/rpc/misc.cpp:172` |  |
| `script` | string, may be absent | `src/rpc/misc.cpp:189` |  |
| `hex` | string, may be absent | `src/rpc/misc.cpp:191` |  |
| `account` | string, may be absent | `src/rpc/misc.cpp:279` |  |
| `timestamp` | i64, may be absent | `src/rpc/misc.cpp:289` |  |
| `hdkeypath` | string, may be absent | `src/rpc/misc.cpp:291` |  |
| `hdmasterkeyid` | string, may be absent | `src/rpc/misc.cpp:292` |  |

#### `Blacklist` (`src/rpc/frozentxo_rpc.cpp:439`)

| field | type | cite [SRC] | note |
|---|---|---|---|
| `funds` | array of BlacklistedFund | `src/rpc/frozentxo_rpc.cpp:439` |  |

#### `BlacklistedFund` (`src/rpc/frozentxo_rpc.cpp:404-499`)

| field | type | cite [SRC] | note |
|---|---|---|---|
| `txOut` | OutPoint | `src/rpc/frozentxo_rpc.cpp:465` |  |
| `enforceAtHeight` | array of Interval, may be absent | `src/rpc/frozentxo_rpc.cpp:476` | consensus entries only |
| `policyExpiresWithConsensus` | json, may be absent | `src/rpc/frozentxo_rpc.cpp:477` | written as a number on the node [X] |
| `blacklist` | array of string | `src/rpc/frozentxo_rpc.cpp:479` |  |

#### `Block` (`src/rpc/blockchain.cpp:1665-1736`)

| field | type | cite [SRC] | note |
|---|---|---|---|
| `tx` | array of BlockTx | `src/rpc/blockchain.cpp:1696` |  |
| (every field of `BlockHeader`) | | `src/rpc/blockchain.cpp:1719` | |

#### `BlockHeader` (`src/rpc/blockchain.cpp:93-138`)

| field | type | cite [SRC] | note |
|---|---|---|---|
| `hash` | string | `src/rpc/blockchain.cpp:100` |  |
| `confirmations` | i64 | `src/rpc/blockchain.cpp:101` |  |
| `size` | u64, may be absent | `src/rpc/blockchain.cpp:105` | only while the block's disk metadata is known; gone after pruning [X] |
| `height` | i64 | `src/rpc/blockchain.cpp:107` |  |
| `version` | i64 | `src/rpc/blockchain.cpp:108` |  |
| `versionHex` | string | `src/rpc/blockchain.cpp:110` |  |
| `merkleroot` | string | `src/rpc/blockchain.cpp:111` |  |
| `num_tx` | u64, may be absent | `src/rpc/blockchain.cpp:113` |  |
| `time` | i64 | `src/rpc/blockchain.cpp:115` |  |
| `mediantime` | i64 | `src/rpc/blockchain.cpp:116` |  |
| `nonce` | u64 | `src/rpc/blockchain.cpp:117` |  |
| `bits` | string | `src/rpc/blockchain.cpp:118` |  |
| `difficulty` | f64 | `src/rpc/blockchain.cpp:119` |  |
| `chainwork` | string | `src/rpc/blockchain.cpp:120` |  |
| `previousblockhash` | string, may be absent | `src/rpc/blockchain.cpp:126` | absent for genesis |
| `nextblockhash` | string, may be absent | `src/rpc/blockchain.cpp:131` | absent at the tip and off the active chain |
| `status` | BlockStatus | `src/rpc/blockchain.cpp:135` |  |

#### `BlockStatus` (`src/rpc/blockchain.cpp:140-158`)

| field | type | cite [SRC] | note |
|---|---|---|---|
| `validity` | string | `src/rpc/blockchain.cpp:145` |  |
| `data` | bool | `src/rpc/blockchain.cpp:148` |  |
| `undo` | bool | `src/rpc/blockchain.cpp:149` |  |
| `failed` | bool | `src/rpc/blockchain.cpp:150` |  |
| `parent failed` | bool | `src/rpc/blockchain.cpp:151` |  |
| `disk meta` | bool | `src/rpc/blockchain.cpp:152` |  |
| `soft reject` | bool | `src/rpc/blockchain.cpp:153` |  |
| `double spend` | bool | `src/rpc/blockchain.cpp:154` |  |
| `soft consensus frozen` | bool | `src/rpc/blockchain.cpp:155` |  |

#### `BlockTx` (`src/rpc/blockchain.cpp:1701`)

One of: `Id` string (verbosity 1); `Decoded` Tx (verbosity 2 and 3).

#### `BlockchainActivity` (`src/rpc/blockchain.cpp:3649`)

| field | type | cite [SRC] | note |
|---|---|---|---|
| `blocks` | i64 | `src/rpc/blockchain.cpp:3674` |  |
| `transactions` | u64 | `src/rpc/blockchain.cpp:3678` |  |

#### `ChainTip` (`src/rpc/blockchain.cpp:2577`)

| field | type | cite [SRC] | note |
|---|---|---|---|
| `height` | i64 | `src/rpc/blockchain.cpp:2578` |  |
| `hash` | string | `src/rpc/blockchain.cpp:2579` |  |
| `branchlen` | i64 | `src/rpc/blockchain.cpp:2583` |  |
| `status` | string | `src/rpc/blockchain.cpp:2609` | active, invalid, headers-only, valid-fork, valid-headers or unknown |

#### `ChainTxStats` (`src/rpc/blockchain.cpp:3142`)

| field | type | cite [SRC] | note |
|---|---|---|---|
| `time` | i64 | `src/rpc/blockchain.cpp:3143` |  |
| `txcount` | i64 | `src/rpc/blockchain.cpp:3144` |  |
| `window_block_count` | i64 | `src/rpc/blockchain.cpp:3145` |  |
| `window_tx_count` | i64, may be absent | `src/rpc/blockchain.cpp:3147` |  |
| `window_interval` | i64, may be absent | `src/rpc/blockchain.cpp:3148` |  |
| `txrate` | f64, may be absent | `src/rpc/blockchain.cpp:3150` |  |

#### `Coin` (`src/rpc/blockchain.cpp:1982`)

| field | type | cite [SRC] | note |
|---|---|---|---|
| `bestblock` | string | `src/rpc/blockchain.cpp:1990` |  |
| `confirmations` | i64 | `src/rpc/blockchain.cpp:1992` |  |
| `value` | f64 | `src/rpc/blockchain.cpp:1998` |  |
| `scriptPubKey` | ScriptPubKey | `src/rpc/blockchain.cpp:2004` |  |
| `coinbase` | bool | `src/rpc/blockchain.cpp:2005` |  |
| `confiscation` | bool | `src/rpc/blockchain.cpp:2006` |  |

#### `Collided` (`src/rpc/rawtransaction.cpp:1729`)

| field | type | cite [SRC] | note |
|---|---|---|---|
| `txid` | string | `src/rpc/rawtransaction.cpp:1733` |  |
| `size` | i64 | `src/rpc/rawtransaction.cpp:1734` |  |

#### `FundsResult` (`src/rpc/frozentxo_rpc.cpp:298`)

| field | type | cite [SRC] | note |
|---|---|---|---|
| `notProcessed` | array of NotProcessedFund | `src/rpc/frozentxo_rpc.cpp:298` |  |

#### `GetBlock` (`src/rpc/blockchain.cpp:1432-1476`)

One of: `Raw` string (verbosity 0: the serialized block, hex); `Decoded` Block.

#### `GetBlockHeader` (`src/rpc/blockchain.cpp:999`)

One of: `Raw` string (verbosity 0: the 80-byte header, hex); `Decoded` HeaderExtended.

#### `GetRawTransaction` (`src/rpc/rawtransaction.cpp:212`)

One of: `Raw` string (verbose false: the serialized transaction, hex); `Decoded` Tx.

#### `HeaderExtended` (`src/rpc/blockchain.cpp:177-203`)

| field | type | cite [SRC] | note |
|---|---|---|---|
| `tx` | array of Tx, may be absent | `src/rpc/blockchain.cpp:187` | verbosity 2, the coinbase, only while the block is on disk [X] |
| (every field of `BlockHeader`) | | `src/rpc/blockchain.cpp:192` | |
| `merkleproof` | array of string, may be absent | `src/rpc/blockchain.cpp:196` | verbosity 2, with the coinbase |

#### `Interval` (`src/rpc/frozentxo_rpc.cpp:472`)

| field | type | cite [SRC] | note |
|---|---|---|---|
| `start` | i64 | `src/rpc/frozentxo_rpc.cpp:472` |  |
| `stop` | i64 | `src/rpc/frozentxo_rpc.cpp:473` |  |

#### `InvalidTx` (`src/rpc/rawtransaction.cpp:1705-1747`)

| field | type | cite [SRC] | note |
|---|---|---|---|
| `txid` | string | `src/rpc/rawtransaction.cpp:1715` |  |
| `reject_code` | u64 | `src/rpc/rawtransaction.cpp:1718` |  |
| `reject_reason` | string | `src/rpc/rawtransaction.cpp:1719` | missing inputs read reject_code 16, reason missing-inputs |
| `collidedWith` | array of Collided, may be absent | `src/rpc/rawtransaction.cpp:1729` |  |

#### `LocalAddress` (`src/rpc/net.cpp:657`)

| field | type | cite [SRC] | note |
|---|---|---|---|
| `address` | string | `src/rpc/net.cpp:658` |  |
| `port` | i64 | `src/rpc/net.cpp:659` |  |
| `score` | i64 | `src/rpc/net.cpp:660` |  |

#### `MempoolEntry` (`src/rpc/blockchain.cpp:378-412`)

| field | type | cite [SRC] | note |
|---|---|---|---|
| `size` | u64 | `src/rpc/blockchain.cpp:391` |  |
| `fee` | f64 | `src/rpc/blockchain.cpp:392` |  |
| `modifiedfee` | f64 | `src/rpc/blockchain.cpp:393` |  |
| `time` | i64 | `src/rpc/blockchain.cpp:394` |  |
| `height` | u64 | `src/rpc/blockchain.cpp:395` |  |
| `depends` | array of string | `src/rpc/blockchain.cpp:405` |  |

#### `MempoolInfo` (`src/rpc/blockchain.cpp:2617-2642`)

| field | type | cite [SRC] | note |
|---|---|---|---|
| `size` | i64 | `src/rpc/blockchain.cpp:2620` |  |
| `journalsize` | i64 | `src/rpc/blockchain.cpp:2622` |  |
| `nonfinalsize` | i64 | `src/rpc/blockchain.cpp:2625` |  |
| `bytes` | i64 | `src/rpc/blockchain.cpp:2626` |  |
| `usage` | i64 | `src/rpc/blockchain.cpp:2627` |  |
| `usagedisk` | i64 | `src/rpc/blockchain.cpp:2628` |  |
| `usagecpfp` | i64 | `src/rpc/blockchain.cpp:2629` |  |
| `nonfinalusage` | i64 | `src/rpc/blockchain.cpp:2631` |  |
| `maxmempool` | i64 | `src/rpc/blockchain.cpp:2634` |  |
| `maxmempoolsizedisk` | i64 | `src/rpc/blockchain.cpp:2635` |  |
| `maxmempoolsizecpfp` | i64 | `src/rpc/blockchain.cpp:2636` |  |
| `mempoolminfee` | f64 | `src/rpc/blockchain.cpp:2638` |  |

#### `MerkleProof` (`src/rpc/rawtransaction.cpp:2323`)

| field | type | cite [SRC] | note |
|---|---|---|---|
| `flags` | i64 | `src/rpc/rawtransaction.cpp:2324` |  |
| `index` | u64 | `src/rpc/rawtransaction.cpp:2325` |  |
| `txOrId` | string | `src/rpc/rawtransaction.cpp:2326` |  |
| `target` | BlockHeader | `src/rpc/rawtransaction.cpp:2336` |  |
| `nodes` | array of string | `src/rpc/rawtransaction.cpp:2337` |  |

#### `MerkleProof2` (`src/rpc/rawtransaction.cpp:2468`)

| field | type | cite [SRC] | note |
|---|---|---|---|
| `index` | u64 | `src/rpc/rawtransaction.cpp:2468` |  |
| `txOrId` | string | `src/rpc/rawtransaction.cpp:2473` | the txid, or the transaction's hex with includeFullTx |
| `targetType` | string, may be absent | `src/rpc/rawtransaction.cpp:2504` | absent for the default hash |
| `target` | string | `src/rpc/rawtransaction.cpp:2510` | a block hash, a header's hex or a merkle root |
| `nodes` | array of string | `src/rpc/rawtransaction.cpp:2522` |  |

#### `Network` (`src/rpc/net.cpp:522-541`)

| field | type | cite [SRC] | note |
|---|---|---|---|
| `name` | string | `src/rpc/net.cpp:530` |  |
| `limited` | bool | `src/rpc/net.cpp:531` |  |
| `reachable` | bool | `src/rpc/net.cpp:532` |  |
| `proxy` | string | `src/rpc/net.cpp:533` |  |
| `proxy_randomize_credentials` | bool | `src/rpc/net.cpp:537` |  |

#### `NetworkInfo` (`src/rpc/net.cpp:543-667`)

| field | type | cite [SRC] | note |
|---|---|---|---|
| `version` | i64 | `src/rpc/net.cpp:619` |  |
| `subversion` | string | `src/rpc/net.cpp:620` |  |
| `protocolversion` | i64 | `src/rpc/net.cpp:621` |  |
| `localservices` | string | `src/rpc/net.cpp:623` |  |
| `localrelay` | bool | `src/rpc/net.cpp:625` |  |
| `timeoffset` | i64 | `src/rpc/net.cpp:626` |  |
| `txnpropagationfreq` | i64 | `src/rpc/net.cpp:628` |  |
| `txnpropagationqlen` | i64 | `src/rpc/net.cpp:629` |  |
| `networkactive` | bool | `src/rpc/net.cpp:630` |  |
| `connections` | i64 | `src/rpc/net.cpp:631` |  |
| `addresscount` | i64 | `src/rpc/net.cpp:632` |  |
| `streampolicies` | string | `src/rpc/net.cpp:642` |  |
| `networks` | array of Network | `src/rpc/net.cpp:645` |  |
| `relayfee` | f64 | `src/rpc/net.cpp:646` |  |
| `minconsolidationfactor` | i64 | `src/rpc/net.cpp:648` |  |
| `maxconsolidationinputscriptsize` | i64 | `src/rpc/net.cpp:649` |  |
| `minconfconsolidationinput` | i64 | `src/rpc/net.cpp:650` |  |
| `minconsolidationinputmaturity` | i64 | `src/rpc/net.cpp:651` |  |
| `acceptnonstdconsolidationinput` | bool | `src/rpc/net.cpp:652` |  |
| `localaddresses` | array of LocalAddress | `src/rpc/net.cpp:664` |  |
| `warnings` | string | `src/rpc/net.cpp:665` | GetWarnings("statusbar"): the binary of record's development-build text, or the safe-mode text [X] |

#### `NotProcessedFund` (`src/rpc/frozentxo_rpc.cpp:281-301`)

| field | type | cite [SRC] | note |
|---|---|---|---|
| `txOut` | OutPoint | `src/rpc/frozentxo_rpc.cpp:293` |  |
| `reason` | string | `src/rpc/frozentxo_rpc.cpp:294` |  |

#### `NotProcessedTx` (`src/rpc/frozentxo_rpc.cpp:753`)

| field | type | cite [SRC] | note |
|---|---|---|---|
| `confiscationTx` | TxIdOnly | `src/rpc/frozentxo_rpc.cpp:753` |  |
| `reason` | string | `src/rpc/frozentxo_rpc.cpp:754` |  |

#### `OrphanInfo` (`src/rpc/blockchain.cpp:2691`)

| field | type | cite [SRC] | note |
|---|---|---|---|
| `size` | i64 | `src/rpc/blockchain.cpp:2691` |  |

#### `OutPoint` (`src/rpc/frozentxo_rpc.cpp:291`)

| field | type | cite [SRC] | note |
|---|---|---|---|
| `txId` | string | `src/rpc/frozentxo_rpc.cpp:291` |  |
| `vout` | u64 | `src/rpc/frozentxo_rpc.cpp:292` |  |

#### `RawMempool` (`src/rpc/blockchain.cpp:414-438`)

One of: `Ids` array of string (verbose false); `Verbose` map of MempoolEntry (verbose true, keyed by txid).

#### `Reorg` (`src/safe_mode.cpp:502`)

| field | type | cite [SRC] | note |
|---|---|---|---|
| `happened` | bool | `src/safe_mode.cpp:505` |  |
| `numberofdisconnectedblocks` | i64 | `src/safe_mode.cpp:506` |  |
| `oldtip` | nullable of SafeModeBlock | `src/safe_mode.cpp:507` |  |

#### `SafeModeBlock` (`src/safe_mode.cpp:488`)

| field | type | cite [SRC] | note |
|---|---|---|---|
| `hash` | string | `src/safe_mode.cpp:488` |  |
| `height` | i64 | `src/safe_mode.cpp:489` |  |
| `blocktime` | string | `src/safe_mode.cpp:490` |  |
| `firstseentime` | string | `src/safe_mode.cpp:491` |  |
| `status` | string | `src/safe_mode.cpp:492` |  |

#### `SafeModeInfo` (`src/safe_mode.cpp:450-552`)

| field | type | cite [SRC] | note |
|---|---|---|---|
| `safemodeenabled` | bool | `src/safe_mode.cpp:498` | the fork-driven level only: false under -testsafemode [X] |
| `activetip` | SafeModeBlock | `src/safe_mode.cpp:499` |  |
| `timeutc` | string | `src/safe_mode.cpp:500` | std::time(nullptr): the wall clock, never the mock clock [X] |
| `reorg` | Reorg | `src/safe_mode.cpp:502` |  |
| `forks` | array of json | `src/safe_mode.cpp:530` | per fork: forkfirstblock, tips, lastcommonblock, activechainfirstblock; untyped, no isolated instance forks |

#### `ScriptPubKey` (`src/core_write.cpp:334-368`)

| field | type | cite [SRC] | note |
|---|---|---|---|
| `asm` | string | `src/core_write.cpp:338` |  |
| `hex` | string, may be absent | `src/core_write.cpp:344` |  |
| `reqSigs` | i64, may be absent | `src/core_write.cpp:359` | absent when no destination is extracted |
| `type` | string | `src/core_write.cpp:355` |  |
| `addresses` | array of string, may be absent | `src/core_write.cpp:362` |  |

#### `ScriptSig` (`src/core_write.cpp:267`)

| field | type | cite [SRC] | note |
|---|---|---|---|
| `asm` | string | `src/core_write.cpp:269` |  |
| `hex` | string | `src/core_write.cpp:274` |  |

#### `ScriptVerdict` (`src/rpc/misc.cpp:903`)

| field | type | cite [SRC] | note |
|---|---|---|---|
| `result` | string | `src/rpc/misc.cpp:903` | ok, error, timeout or skipped |
| `description` | string, may be absent | `src/rpc/misc.cpp:906` |  |
| `flags` | i64, may be absent | `src/rpc/misc.cpp:910` |  |

#### `SendRawTransactions` (`src/rpc/rawtransaction.cpp:2220`)

| field | type | cite [SRC] | note |
|---|---|---|---|
| `known` | array of string, may be absent | `src/rpc/rawtransaction.cpp:1771` | each array only when not empty; accepted txids are never listed |
| `invalid` | array of InvalidTx, may be absent | `src/rpc/rawtransaction.cpp:1709` |  |
| `evicted` | array of string, may be absent | `src/rpc/rawtransaction.cpp:1756` |  |
| `unconfirmed` | array of Unconfirmed, may be absent | `src/rpc/rawtransaction.cpp:1786` |  |

#### `Tx` (`src/core_write.cpp:237-332`)

| field | type | cite [SRC] | note |
|---|---|---|---|
| `txid` | string | `src/core_write.cpp:246` |  |
| `hash` | string | `src/core_write.cpp:247` |  |
| `version` | i64 | `src/core_write.cpp:248` |  |
| `size` | i64 | `src/core_write.cpp:249` |  |
| `locktime` | i64 | `src/core_write.cpp:250` |  |
| `vin` | array of TxIn | `src/core_write.cpp:252` |  |
| `vout` | array of TxOut | `src/core_write.cpp:287` |  |
| `blockhash` | string, may be absent | `src/core_write.cpp:307` | getrawtransaction of a mined transaction only |
| `confirmations` | i64, may be absent | `src/core_write.cpp:313` |  |
| `time` | i64, may be absent | `src/core_write.cpp:317` |  |
| `blocktime` | i64, may be absent | `src/core_write.cpp:318` |  |
| `blockheight` | i64, may be absent | `src/core_write.cpp:319` |  |
| `hex` | string | `src/core_write.cpp:326` |  |

#### `TxIdOnly` (`src/rpc/frozentxo_rpc.cpp:752`)

| field | type | cite [SRC] | note |
|---|---|---|---|
| `txId` | string | `src/rpc/frozentxo_rpc.cpp:752` |  |

#### `TxIn` (`src/core_write.cpp:252`)

| field | type | cite [SRC] | note |
|---|---|---|---|
| `coinbase` | string, may be absent | `src/core_write.cpp:258` | a coinbase input only |
| `txid` | string, may be absent | `src/core_write.cpp:265` |  |
| `vout` | i64, may be absent | `src/core_write.cpp:266` |  |
| `scriptSig` | ScriptSig, may be absent | `src/core_write.cpp:267` |  |
| `sequence` | i64 | `src/core_write.cpp:281` |  |

#### `TxOut` (`src/core_write.cpp:287`)

| field | type | cite [SRC] | note |
|---|---|---|---|
| `value` | f64 | `src/core_write.cpp:293` |  |
| `n` | i64 | `src/core_write.cpp:294` |  |
| `scriptPubKey` | ScriptPubKey | `src/core_write.cpp:296` |  |

#### `Unconfirmed` (`src/rpc/rawtransaction.cpp:1782-1796`)

| field | type | cite [SRC] | note |
|---|---|---|---|
| `txid` | string | `src/rpc/rawtransaction.cpp:1790` |  |
| `ancestors` | json | `src/rpc/rawtransaction.cpp:1791` |  |

#### `UtxoSetInfo` (`src/rpc/blockchain.cpp:1907`)

| field | type | cite [SRC] | note |
|---|---|---|---|
| `height` | i64 | `src/rpc/blockchain.cpp:1908` |  |
| `bestblock` | string | `src/rpc/blockchain.cpp:1909` |  |
| `transactions` | i64 | `src/rpc/blockchain.cpp:1910` |  |
| `txouts` | i64 | `src/rpc/blockchain.cpp:1911` |  |
| `bogosize` | i64 | `src/rpc/blockchain.cpp:1912` |  |
| `hash_serialized` | string | `src/rpc/blockchain.cpp:1913` |  |
| `disk_size` | u64 | `src/rpc/blockchain.cpp:1914` |  |
| `total_amount` | f64 | `src/rpc/blockchain.cpp:1916` |  |

#### `WalletInfo` (`src/wallet/rpcwallet.cpp:2798-2878`)

| field | type | cite [SRC] | note |
|---|---|---|---|
| `walletname` | string | `src/wallet/rpcwallet.cpp:2854` |  |
| `walletversion` | i64 | `src/wallet/rpcwallet.cpp:2855` |  |
| `balance` | f64 | `src/wallet/rpcwallet.cpp:2856` |  |
| `unconfirmed_balance` | f64 | `src/wallet/rpcwallet.cpp:2857` |  |
| `immature_balance` | f64 | `src/wallet/rpcwallet.cpp:2859` |  |
| `txcount` | i64 | `src/wallet/rpcwallet.cpp:2861` |  |
| `keypoololdest` | i64 | `src/wallet/rpcwallet.cpp:2862` |  |
| `keypoolsize` | i64 | `src/wallet/rpcwallet.cpp:2863` |  |
| `keypoolsize_hd_internal` | i64, may be absent | `src/wallet/rpcwallet.cpp:2867` |  |
| `unlocked_until` | i64, may be absent | `src/wallet/rpcwallet.cpp:2871` |  |
| `paytxfee` | f64 | `src/wallet/rpcwallet.cpp:2873` |  |
| `hdmasterkeyid` | string, may be absent | `src/wallet/rpcwallet.cpp:2875` |  |

#### `WalletTransaction` (`src/wallet/rpcwallet.cpp:2176`)

| field | type | cite [SRC] | note |
|---|---|---|---|
| `amount` | f64 | `src/wallet/rpcwallet.cpp:2171` |  |
| `fee` | f64, may be absent | `src/wallet/rpcwallet.cpp:2173` |  |
| `confirmations` | i64 | `src/wallet/wallet.cpp:1985` |  |
| `generated` | bool, may be absent | `src/wallet/wallet.cpp:1987` |  |
| `blockhash` | string, may be absent | `src/wallet/wallet.cpp:1991` |  |
| `blockindex` | i64, may be absent | `src/wallet/wallet.cpp:1992` |  |
| `blocktime` | i64, may be absent | `src/wallet/wallet.cpp:1993` |  |
| `trusted` | bool, may be absent | `src/wallet/wallet.cpp:1997` |  |
| `txid` | string | `src/wallet/wallet.cpp:2000` |  |
| `walletconflicts` | array of string | `src/wallet/wallet.cpp:2007` |  |
| `time` | i64 | `src/wallet/wallet.cpp:2008` |  |
| `timereceived` | i64 | `src/wallet/wallet.cpp:2009` |  |
| `details` | array of json | `src/wallet/rpcwallet.cpp:2180` |  |
| `hex` | string | `src/wallet/rpcwallet.cpp:2184` |  |

#### `Whitelist` (`src/rpc/frozentxo_rpc.cpp:799-894`)

| field | type | cite [SRC] | note |
|---|---|---|---|
| `confiscationTxs` | array of json | `src/rpc/frozentxo_rpc.cpp:843` | per entry confiscationTx: txId, enforceAtHeight, inputs with verbose; untyped, no entry on the isolated instance |

#### `WhitelistResult` (`src/rpc/frozentxo_rpc.cpp:761`)

| field | type | cite [SRC] | note |
|---|---|---|---|
| `notProcessed` | array of NotProcessedTx | `src/rpc/frozentxo_rpc.cpp:761` |  |
<!-- rpc_contract: types end -->

## 7. The runner's citations against the contract

[M] The runner names a source for every call it logs (`[SRC] <file:lines> at <pin>`) from five tables:
`harness/src/scenarios/core.rs` `handler`, `depth.rs` `source`, `chain.rs` `chain_operator_call`, `frozen.rs` and
`utxo.rs` `operator`. The contract's span is the handler's definition through its closing brace at the pin. A row that
differs is not a wrong rule; it is a span drawn otherwise, and the wiring change replaces the five tables with
`HANDLERS` of the interface, so one span stands per handler.

<!-- rpc_contract: runner begin -->
| handler | runner table | the runner's citation | the contract's | same |
|---|---|---|---|---|
| `preciousblock` | `harness/src/scenarios/chain.rs` line 1270 | `src/rpc/blockchain.cpp:2695-2731` | `src/rpc/blockchain.cpp:2695-2730` | no |
| `getblockheader` | `harness/src/scenarios/chain.rs` line 1271 | `src/rpc/blockchain.cpp:884-1063` | `src/rpc/blockchain.cpp:884-1061` | no |
| `getmempoolinfo` | `harness/src/scenarios/chain.rs` line 1272 | `src/rpc/blockchain.cpp:2617-2673` | `src/rpc/blockchain.cpp:2644-2673` | no |
| `softrejectblock` | `harness/src/scenarios/chain.rs` line 1273 | `src/rpc/blockchain.cpp:2820-2892` | `src/rpc/blockchain.cpp:2820-2892` | yes |
| `acceptblock` | `harness/src/scenarios/chain.rs` line 1274 | `src/rpc/blockchain.cpp:2894-2991` | `src/rpc/blockchain.cpp:2894-2991` | yes |
| `pruneblockchain` | `harness/src/scenarios/chain.rs` line 1275 | `src/rpc/blockchain.cpp:1810-1875` | `src/rpc/blockchain.cpp:1810-1875` | yes |
| `addToConsensusBlacklist` | `harness/src/scenarios/chain.rs` line 1276 | `src/rpc/frozentxo_rpc.cpp:346-378` | `src/rpc/frozentxo_rpc.cpp:346-378` | yes |
| `verifychain` | `harness/src/scenarios/chain.rs` line 1277 | `src/rpc/blockchain.cpp:2321-2354` | `src/rpc/blockchain.cpp:2321-2354` | yes |
| `gettxoutsetinfo` | `harness/src/scenarios/chain.rs` line 1278 | `src/rpc/blockchain.cpp:1877-1921` | `src/rpc/blockchain.cpp:1877-1921` | yes |
| `generatetoaddress` | `harness/src/scenarios/core.rs` line 148 | `src/rpc/mining.cpp:227-268` | `src/rpc/mining.cpp:227-268` | yes |
| `submitblock` | `harness/src/scenarios/core.rs` line 149 | `src/rpc/mining.cpp:916-952` | `src/rpc/mining.cpp:916-953` | no |
| `sendrawtransactions` | `harness/src/scenarios/core.rs` line 150 | `src/rpc/rawtransaction.cpp:1798-2239` | `src/rpc/rawtransaction.cpp:1798-2240` | no |
| `sendrawtransaction` | `harness/src/scenarios/core.rs` line 151 | `src/rpc/rawtransaction.cpp:1530-1672` | `src/rpc/rawtransaction.cpp:1530-1700` | no |
| `getrawtransaction` | `harness/src/scenarios/core.rs` line 152 | `src/rpc/rawtransaction.cpp:53-194` | `src/rpc/rawtransaction.cpp:53-256` | no |
| `verifyscript` | `harness/src/scenarios/core.rs` line 153 | `src/rpc/misc.cpp:506-914` | `src/rpc/misc.cpp:506-915` | no |
| `getmerkleproof` | `harness/src/scenarios/core.rs` line 154 | `src/rpc/rawtransaction.cpp:2242-2340` | `src/rpc/rawtransaction.cpp:2242-2339` | no |
| `getmerkleproof2` | `harness/src/scenarios/core.rs` line 156 | `src/rpc/rawtransaction.cpp:2342-2525` | `src/rpc/rawtransaction.cpp:2342-2525` | yes |
| `verifymerkleproof` | `harness/src/scenarios/core.rs` line 157 | `src/rpc/rawtransaction.cpp:2527-2612` | `src/rpc/rawtransaction.cpp:2527-2612` | yes |
| `setmocktime` | `harness/src/scenarios/core.rs` line 158 | `src/rpc/misc.cpp:980-1007` | `src/rpc/misc.cpp:980-1008` | no |
| `getchaintxstats` | `harness/src/scenarios/core.rs` line 160 | `src/rpc/blockchain.cpp:3054-3155` | `src/rpc/blockchain.cpp:3054-3155` | yes |
| `getnetworkinfo` | `harness/src/scenarios/core.rs` line 161 | `src/rpc/net.cpp:543-667` | `src/rpc/net.cpp:543-667` | yes |
| `getpeerinfo` | `harness/src/scenarios/core.rs` line 162 | `src/rpc/net.cpp:69-280` | `src/rpc/net.cpp:69-280` | yes |
| `addnode` | `harness/src/scenarios/core.rs` line 164 | `src/rpc/net.cpp:282-327` | `(not in the contract)` | no |
| `listbanned` | `harness/src/scenarios/core.rs` line 165 | `src/rpc/net.cpp:759-789` | `(not in the contract)` | no |
| `getblockcount` | `harness/src/scenarios/core.rs` line 166 | `src/rpc/blockchain.cpp:205-218` | `src/rpc/blockchain.cpp:205-218` | yes |
| `getblockhash` | `harness/src/scenarios/core.rs` line 168 | `src/rpc/blockchain.cpp:801-828` | `src/rpc/blockchain.cpp:801-825` | no |
| `getbestblockhash` | `harness/src/scenarios/core.rs` line 169 | `src/rpc/blockchain.cpp:220-236` | `src/rpc/blockchain.cpp:220-235` | no |
| `getrawmempool` | `harness/src/scenarios/core.rs` line 170 | `src/rpc/blockchain.cpp:440-500` | `src/rpc/blockchain.cpp:440-500` | yes |
| `getrawnonfinalmempool` | `harness/src/scenarios/core.rs` line 171 | `src/rpc/blockchain.cpp:502-550` | `src/rpc/blockchain.cpp:502-557` | no |
| `getblock` | `harness/src/scenarios/core.rs` line 172 | `src/rpc/blockchain.cpp:1108-1242` | `src/rpc/blockchain.cpp:1108-1272` | no |
| `gettxout` | `harness/src/scenarios/core.rs` line 173 | `src/rpc/blockchain.cpp:1923-2029` | `src/rpc/blockchain.cpp:1923-2028` | no |
| `getchaintips` | `harness/src/scenarios/core.rs` line 174 | `src/rpc/blockchain.cpp:2497-2632` | `src/rpc/blockchain.cpp:2497-2615` | no |
| `getorphaninfo` | `harness/src/scenarios/core.rs` line 175 | `src/rpc/blockchain.cpp:2675-2693` | `src/rpc/blockchain.cpp:2675-2693` | yes |
| `invalidateblock` | `harness/src/scenarios/core.rs` line 176 | `src/rpc/blockchain.cpp:2732-2768` | `src/rpc/blockchain.cpp:2732-2768` | yes |
| `reconsiderblock` | `harness/src/scenarios/core.rs` line 177 | `src/rpc/blockchain.cpp:2770-2818` | `src/rpc/blockchain.cpp:2770-2818` | yes |
| `waitforptvcompletion` | `harness/src/scenarios/core.rs` line 179 | `src/rpc/blockchain.cpp:3769-3786` | `src/rpc/blockchain.cpp:3769-3786` | yes |
| `getmempoolinfo` | `harness/src/scenarios/core.rs` line 180 | `src/rpc/blockchain.cpp:2634-2673` | `src/rpc/blockchain.cpp:2644-2673` | no |
| `getblockheader` | `harness/src/scenarios/core.rs` line 181 | `src/rpc/blockchain.cpp:884-1038` | `src/rpc/blockchain.cpp:884-1061` | no |
| `pruneblockchain` | `harness/src/scenarios/core.rs` line 183 | `src/rpc/blockchain.cpp:1810-1875` | `src/rpc/blockchain.cpp:1810-1875` | yes |
| `getblockchaininfo` | `harness/src/scenarios/core.rs` line 184 | `src/rpc/blockchain.cpp:2394-2482` | `(not in the contract)` | no |
| `getblockchainactivity` | `harness/src/scenarios/core.rs` line 185 | `src/rpc/blockchain.cpp:3649-3688` | `src/rpc/blockchain.cpp:3649-3683` | no |
| `prioritisetransaction` | `harness/src/scenarios/core.rs` line 186 | `src/rpc/mining.cpp:312-351` | `src/rpc/mining.cpp:312-344` | no |
| `stop` | `harness/src/scenarios/core.rs` line 187 | `src/rpc/server.cpp:265-287` | `src/rpc/server.cpp:265-278` | no |
| `getwalletinfo` | `harness/src/scenarios/core.rs` line 189 | `src/wallet/rpcwallet.cpp:2798-2878` | `src/wallet/rpcwallet.cpp:2798-2878` | yes |
| `getnewaddress` | `harness/src/scenarios/core.rs` line 190 | `src/wallet/rpcwallet.cpp:119-172` | `src/wallet/rpcwallet.cpp:119-172` | yes |
| `getreceivedbyaddress` | `harness/src/scenarios/core.rs` line 191 | `src/wallet/rpcwallet.cpp:680-764` | `src/wallet/rpcwallet.cpp:680-764` | yes |
| `gettransaction` | `harness/src/scenarios/core.rs` line 192 | `src/wallet/rpcwallet.cpp:2061-2187` | `src/wallet/rpcwallet.cpp:2061-2187` | yes |
| `validateaddress` | `harness/src/scenarios/core.rs` line 193 | `src/rpc/misc.cpp:206-300` | `src/rpc/misc.cpp:206-300` | yes |
| `submitblock` | `harness/src/scenarios/depth.rs` line 36 | `src/rpc/mining.cpp:916-952` | `src/rpc/mining.cpp:916-953` | no |
| `setmocktime` | `harness/src/scenarios/depth.rs` line 37 | `src/rpc/misc.cpp:980-1007` | `src/rpc/misc.cpp:980-1008` | no |
| `getbestblockhash` | `harness/src/scenarios/depth.rs` line 38 | `src/rpc/blockchain.cpp:220-236` | `src/rpc/blockchain.cpp:220-235` | no |
| `getblockcount` | `harness/src/scenarios/depth.rs` line 39 | `src/rpc/blockchain.cpp:205-218` | `src/rpc/blockchain.cpp:205-218` | yes |
| `getblockheader` | `harness/src/scenarios/depth.rs` line 40 | `src/rpc/blockchain.cpp:884-1038` | `src/rpc/blockchain.cpp:884-1061` | no |
| `getchaintips` | `harness/src/scenarios/depth.rs` line 41 | `src/rpc/blockchain.cpp:2497-2632` | `src/rpc/blockchain.cpp:2497-2615` | no |
| `gettxout` | `harness/src/scenarios/depth.rs` line 42 | `src/rpc/blockchain.cpp:1923-2029` | `src/rpc/blockchain.cpp:1923-2028` | no |
| `sendrawtransaction` | `harness/src/scenarios/depth.rs` line 43 | `src/rpc/rawtransaction.cpp:1530-1672` | `src/rpc/rawtransaction.cpp:1530-1700` | no |
| `getsafemodeinfo` | `harness/src/scenarios/depth.rs` line 44 | `src/rpc/safe_mode.cpp:97-196` | `src/rpc/safe_mode.cpp:97-196` | yes |
| `ignoresafemodeforblock` | `harness/src/scenarios/depth.rs` line 45 | `src/rpc/safe_mode.cpp:12-51` | `src/rpc/safe_mode.cpp:12-51` | yes |
| `reconsidersafemodeforblock` | `harness/src/scenarios/depth.rs` line 46 | `src/rpc/safe_mode.cpp:53-95` | `src/rpc/safe_mode.cpp:53-95` | yes |
| `addToPolicyBlacklist` | `harness/src/scenarios/frozen.rs` line 15 | `src/rpc/frozentxo_rpc.cpp:320-344` | `src/rpc/frozentxo_rpc.cpp:320-344` | yes |
| `addToConsensusBlacklist` | `harness/src/scenarios/frozen.rs` line 16 | `src/rpc/frozentxo_rpc.cpp:346-378` | `src/rpc/frozentxo_rpc.cpp:346-378` | yes |
| `queryBlacklist` | `harness/src/scenarios/frozen.rs` line 17 | `src/rpc/frozentxo_rpc.cpp:404-499` | `src/rpc/frozentxo_rpc.cpp:404-499` | yes |
| `addToConfiscationTxidWhitelist` | `harness/src/scenarios/frozen.rs` line 18 | `src/rpc/frozentxo_rpc.cpp:632-764` | `src/rpc/frozentxo_rpc.cpp:632-764` | yes |
| `queryConfiscationTxidWhitelist` | `harness/src/scenarios/frozen.rs` line 19 | `src/rpc/frozentxo_rpc.cpp:799-894` | `src/rpc/frozentxo_rpc.cpp:799-894` | yes |
| `getblockheader` | `harness/src/scenarios/frozen.rs` line 20 | `src/rpc/blockchain.cpp:884-1038` | `src/rpc/blockchain.cpp:884-1061` | no |
| `addToPolicyBlacklist` | `harness/src/scenarios/utxo.rs` line 355 | `src/rpc/frozentxo_rpc.cpp:320-344` | `src/rpc/frozentxo_rpc.cpp:320-344` | yes |
| `addToConsensusBlacklist` | `harness/src/scenarios/utxo.rs` line 356 | `src/rpc/frozentxo_rpc.cpp:346-380` | `src/rpc/frozentxo_rpc.cpp:346-378` | no |
| `addToConfiscationTxidWhitelist` | `harness/src/scenarios/utxo.rs` line 357 | `src/rpc/frozentxo_rpc.cpp:632-762` | `src/rpc/frozentxo_rpc.cpp:632-764` | no |

[M] 68 table rows over 52 handlers; 34 name the contract's span, 34 another.
<!-- rpc_contract: runner end -->

## 8. The probe against the contract

<!-- rpc_contract: probe begin -->
[X] the probe record `docs/records/20261015-035438-s7-85-rpc-contract-s4b.json`: 160 calls of contract handlers, 118 results checked against their types, 41 errors checked against the listed codes; 1 mismatch, 0 outside the findings.

Mismatches:

- prune getblock ["04058bb21426bd8c3e65904b38addef2f2067777d91c46e5d5e8b79d5a: no single JSON reply (Finding R2, known)
<!-- rpc_contract: probe end -->

## 9. The interface

[D] `harness/src/scenarios/rpc_contract.rs` is generated: the result types with serde derives, the trait `RpcContract`
with one method per handler (typed arguments in position order, a typed result) over the one transport method
`call_raw`, the dispatcher `call_typed` (positional JSON arguments in, the typed result re-serialized out), and the table
`HANDLERS` (source, registration, okSafeMode, build, the listed error codes, the second oracle's class). The runner does
not declare the module yet. `harness/tests/rpc_contract.rs` includes it by path and passes every recorded success reply
of `corpus/rpc/replies.json` through `call_typed` over a transport that answers that one reply; the typed result must
re-serialize to the node's JSON, so a field the node writes that the contract omits fails the test. The wiring change
implements `call_raw` for the runner's `Node` (its `call` already logs the source), declares the module and replaces the
five tables of §7 with `HANDLERS`. No leg of `make check` runs `--check` or `--verify`
yet; the wiring change adds them to the harness or cite leg.

## 10. Reproduce

```sh
tools/rpc_probe.py --out docs/records/<stamp>-s7-85-rpc-contract-s4b.json --replies corpus/rpc/replies.json
tools/rpc_contract.py            # the interface and this page's tables
tools/rpc_contract.py --check    # stale outputs, or a probe reply outside the contract
tools/rpc_contract.py --verify   # every citation of the contract at the pins
cd harness && cargo test --test rpc_contract
```
