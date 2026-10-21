# Two nodes, one connection: a compact block reconstructed (#79)

[D] 2026-10-15, S3, lane s7-79. Nothing here is a validity rule: a compact block
decides how a node receives a block, never whether it is valid. The encoding and
the reconstruction are `lean/BsvChain/Wire/CompactBlocks.lean`; the theorems are in
`lean/BsvChain/Properties/CompactBlocks.lean`; the runner is `run_scenarios --compact`
(`harness/src/scenarios/compact.rs`), on #78's two-node harness; the projection is
`chaincheck --compact <record.json>` (`lean/Test/CompactCheck.lean`).
[SRC] bitcoin-sv v1.2.3 at `6504a3aff65ba97c0f6c80962b033e35ecbfed4b`.

## Topology

Two fresh regtest instances on the loopback range 18571 to 18590, `-excessiveblocksize`
1000001 and every compact-block setting at its default (docs/PARAMETERS.md section
8.11). A has its funding prefix (`seed`: 100 blocks and a block carrying F); B dials A
once (`addnode onetry`, `src/rpc/net.cpp:282-327`) and reaches A's tip. The reference's
test peer `PA` (`harness/peer/peer.py`, the pinned `mininode.py`) connects to A and logs
every frame it receives. Synthetic names only; nothing is broadcast (rule 10).

Each node tells the other it serves compact blocks and wants none announced
(`sendcmpct` false, 1, `src/net/net_processing.cpp:1971-1981`) and prefers headers
(`sendheaders`, `:1963-1969`). A block A accepts is announced to B by `headers`; B, out
of its initial download and one block behind, asks for it as a compact block
(`getdata` MSG_CMPCT_BLOCK, the direct fetch, `:3599-3612`); A answers from disk with a
fresh nonce (`SendCompactBlock`, `:1331-1350`); B reconstructs (`:3880-3935`): with
nothing missing it fills the block at once, else it asks with `getblocktxn` and fills
it from `blocktxn` (`:3623-3700`). PA asks A for each block the same way and for some
of its transactions with `getblocktxn`, so the frames are seen byte for byte.

## Steps

A takes four blocks by `submitblock` (`src/rpc/mining.cpp:916-952`), each a coinbase
and a chain of spends of F; a relayed transaction reaches both pools by A's
`sendrawtransaction`, the others never leave the runner.

| step | block | relayed (in B's pool) | the Lean function's answer [D] |
|---|---|---|---|
| k0 | the coinbase alone | none | no short id; nothing missing (`compact_reconstruction`) |
| k1 | the coinbase, T1, T2 | T1, T2 | nothing missing; the block filled at once |
| k2 | the coinbase, T3, T4 | T3 | position 2 missing: `getblocktxn` [2], then the block |
| k3 | the coinbase, T5, T6 | none | positions 1 and 2 missing: `getblocktxn` [1, 2], then the block |

```json
{
  "id": "2026-10-15-compact-blocks-two-node",
  "class": "the relay layer: compact block encoding, reconstruction from the pool, the missing set requested",
  "witness": "#79",
  "source_pin": "6504a3aff65ba97c0f6c80962b033e35ecbfed4b",
  "label": "[D]",
  "topology": {"A": {"peers": ["B", "PA"]}, "B": {"peers": ["A"], "link": "A"}, "address": "127.0.0.1, local, every peer"},
  "steps": [
    {"id": "k0-coinbase-only", "block": ["coinbase"], "relayed": [],
     "rules": ["[SRC] src/blockencodings.cpp:18-32,84-242,254-316; src/net/net_processing.cpp:3919-3935 at 6504a3af"],
     "expected": {"missing": [], "from_pool": 0}, "label": "[D]"},
    {"id": "k1-has-all", "block": ["coinbase", "T1", "T2"], "relayed": ["T1", "T2"],
     "rules": ["[SRC] src/blockencodings.cpp:171-199 at 6504a3af"],
     "expected": {"missing": [], "from_pool": 2}, "label": "[D]"},
    {"id": "k2-has-part", "block": ["coinbase", "T3", "T4"], "relayed": ["T3"],
     "rules": ["[SRC] src/blockencodings.cpp:171-199,254-316; src/net/net_processing.cpp:3919-3935,3623-3700 at 6504a3af"],
     "expected": {"missing": [2], "from_pool": 1}, "label": "[D]"},
    {"id": "k3-lacks-all", "block": ["coinbase", "T5", "T6"], "relayed": [],
     "rules": ["[SRC] src/net/net_processing.cpp:2734-2783 (2 of 3 is under the 99 percent setting) at 6504a3af"],
     "expected": {"missing": [1, 2], "from_pool": 0}, "label": "[D]"}
  ],
  "replay": {"command": "harness/target/release/run_scenarios --compact --record docs/records/<stamp>-s7-79-compact-blocks-s1.md, then lean/.lake/build/bin/chaincheck --compact docs/records/<stamp>-s7-79-compact-blocks-s1.json"}
}
```
