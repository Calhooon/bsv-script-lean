# Depth chain corpus (#73: validation depth and safe mode)

[M] 2026-10-14, lane s6-73. `depth.jsonl` holds the rows of #73: what a node
establishes for itself when it connects a block (the assumed-valid setting, the
work floor, the checkpoints) and safe mode as a client behavior. None of these
is a consensus rule (rule 1): every row varies a setting and reads what the node
then does. The definitions are `lean/BsvChain/Depth.lean`, the theorems
`lean/BsvChain/Properties/Depth.lean`, the census `docs/PARAMETERS.md` §8.4.
[SRC] bitcoin-sv v1.2.3 at `6504a3aff65ba97c0f6c80962b033e35ecbfed4b`.

[M] 2026-10-14, lane s6-73, the column after one fresh-instance run at `b7d28215`: rows 17, realized 16, agree 16, diverge 0, rpc-precheck 0, unrealizable 1, needs-peer 0, pending 0. [X] Per-row node observations at the pinned build; the [record](../../../docs/records/20261014-013925-s6-73-regtest-s3.md) holds the run, its receipts and the legs.

Every expectation is [D], derived from the model and checked with no node by
`chaincheck --depth corpus/chain/depth/depth.jsonl` (the chain leg runs it). The
`node` token is the independent column, written by
`tools/node_scenarios.sh --depth-only` from fresh instances of the pinned build on
the loopback; only that token changes in a run. The SHA256 cell of
`corpus/INDEX.md` hashes the complete current file.

## The assumevalid rows

[SRC] `src/validation.cpp:3482-3518`. Six rows, one fresh instance each, launched
with the row's `-assumevalid` (and `-minimumchainwork` where named). Every block is
built by the harness from the regtest genesis block and handed over by
`submitblock`: [D] 101 common blocks, an active chain, and a side chain whose opening
block (height [D] 102, the bad block) spends the height-1 coinbase with a signature
that does not cover its output, so its script fails wherever it is run. A side
chain with no more work than the active chain is stored without its scripts being
run; its last block gives it more work, and the reorganization then connects the
bad block with the side tip as the best header. That is how the burial is reached
with RPC alone, without a peer that sends headers ahead of bodies.

| row | setting | burial of the bad block | [D] decision | what the node must show |
|---|---|---|---|---|
| `depth-assumevalid-zero` | `-assumevalid=0` | 2,017 blocks | run the scripts | the side chain is refused: the tip stays on the active chain, the side tip is `invalid` |
| `depth-assumevalid-buried` | the side chain's tip | 2,017 blocks, 1,210,200 s | skip | the side chain becomes active: the bad block is in the active chain and its output is a coin |
| `depth-assumevalid-two-weeks-exact` | the side chain's tip | 2,016 blocks, 1,209,600 s | run (the test is `<=`) | refused |
| `depth-assumevalid-other-chain` | the active chain's tip (a block the instance has, of which the bad block is no ancestor) | 2,017 blocks | run | refused |
| `depth-assumevalid-unknown-hash` | the hash of no block | 2,017 blocks | run | refused |
| `depth-assumevalid-work-floor` | the side chain's tip, with `-minimumchainwork=010000` above the best header's work | 2,017 blocks | run | refused |

On regtest the compiled floor is zero (`src/chainparams.cpp:1480`), so in the
second row the floor conjunct holds for every best header and the skip rests on
ancestry and burial alone; the last row sets the floor to show the conjunct. No
mock-clock step decides any row: the burial is work converted at the best header's
proof (`src/block_index.cpp:130-150`), and the instance's clock is fixed once so
that the built blocks' times are acceptable. The skip is observed from outside:
the same blocks are refused on one instance and connected on another, and the
instance's own log names the launch decision ("Assuming ancestors of block ... have
valid signatures" or "Validating signatures for all blocks", `src/init.cpp:2358-2362`).

**The model's replay of these rows is scaled** [D]: an index lookup in the model
recomputes header hashes, so a tree of 4,136 indices is out of reach of the leg.
`chaincheck --depth` runs the same shape through the machine (`acceptBlock` and
`activateBestChain` under `ChainContext.withValidationDepth`, with a real failing
script) with 2,015 blocks removed from both chains and 2,015 spacings removed from
the two-week setting, which leaves the burial less the setting unchanged; beside it
the full-size burial is checked as arithmetic (`burialSeconds`).

## The checkpoint row

`depth-checkpoint-mismatch` is `unrealizable:` at the pin: regtest's only checkpoint
is its genesis block at height 0 and the table is compiled, with no launch input
(`src/chainparams.cpp:1530-1533`); no second header exists at height 0, since a
header that is not the genesis block needs a known parent
(`src/validation.cpp:5903-5930,6152-6177`). The model's side of the row holds:
`checkCheckpoint` refuses the header with the setting on and passes it with the
setting off.

## The safe-mode rows

[SRC] `src/safe_mode.cpp:58-115,117-127,129-179,207-302,324-405`;
`src/init.cpp:324-333`; `src/warnings.cpp:36-96`. Two fresh instances, each
launched with the row's `-safemodemaxforkdistance`, `-safemodeminforklength` and
`-safemodeminblockdifference`; the rows of one instance run in file order and only
extend its chains ([D] 10 common blocks, an active chain `A11…`, a side chain of
stored bodies `F11…`). `getsafemodeinfo` is read back by block name.

| instance | row | what it shows |
|---|---|---|
| `depth-safemode-length-distance` (distance 10, length 3, difference −50) | `depth-safemode-fork-short` | a fork of 2 blocks triggers nothing |
| | `depth-safemode-fork-at-length` | a fork of 3 blocks triggers safe mode: one fork, base `F11`, tip `F13` |
| | `depth-safemode-rpc-refused` | `sendrawtransaction` is refused with code −2 and the `VALID` level's warning; `getblockcount` is answered |
| | `depth-safemode-ignored` | `ignoresafemodeforblock F11`: safe mode off |
| | `depth-safemode-rpc-answered` | `sendrawtransaction` is no longer refused by safe mode |
| | `depth-safemode-reconsidered` | `reconsidersafemodeforblock F13`: safe mode on again |
| | `depth-safemode-distance-at-setting` | active tip at 20: distance 10, still triggering |
| | `depth-safemode-distance-over-setting` | active tip at 21: distance 11, nothing |
| `depth-safemode-work` (distance 1,000, length 3, difference −5) | `depth-safemode-work-at-setting` | fork tip at 14, active tip at 19: exactly 5 blocks of work behind, triggering |
| | `depth-safemode-work-under-setting` | active tip at 20: 6 blocks behind, nothing |

Safe mode changes no validity: in every safe-mode row the active chain keeps
growing by `submitblock` while the level is set.

## The regtest genesis block's hash

[M] 2026-10-17 (#107, lane gate-107): `regtest-genesis.json` holds the hash every depth chain is built on, [SRC]
`src/chainparams.cpp:1512-1515` at `6504a3af` (the census row `hashGenesisBlock` of `docs/PARAMETERS.md`).
`harness/src/scenarios/depth.rs` reads it there; it held the value as a literal until the mechanism check, which
refuses a 64-hex literal in `harness/src`, moved it into the corpus.
