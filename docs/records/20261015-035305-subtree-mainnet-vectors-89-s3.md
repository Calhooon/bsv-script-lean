# Lane vec-89 (#89, the done-bar's mainnet sentence): ten mainnet blocks as read-only subtree vectors, 2026-10-15

[M] Written by lane vec-89 (S3, Claude Opus 5.5, on the Studio) at 2026-10-15T03:53:05Z. Base `origin/main`
`77a68cba`; the tree of record is the lane's commit that adds this file (`lane/vec-89`). Not a full
`make check`: the box tripwire of record is the landing's.

## The reads [M]

Public reads of raw block data by URL (rule 10: mainnet material READ only; nothing broadcast; no
node instance started; the node of record and the mini untouched), `urllib` from the Studio,
2026-10-15. Each read's URL, UTC time, HTTP status and byte count is also in its block's line of
`corpus/chain/merkle/2026-10-15-mainnet-blocks.jsonl` (`reads`).

| height | transactions | block hash | header merkle root (display order) | confirmations at read | read (URL, UTC time, HTTP, bytes) |
|---:|---:|---|---|---:|---|
| 160000 | 1 | `000000000000066c6e629b2fb49c7fcc52b82fe9833f328e0c3943856facf231` | `0a95c3df67a742c477f6562d30e671d7f555448019ee10199ded32049aca933a` | 811,118 | <https://api.whatsonchain.com/v1/bsv/main/block/height/160000> 2026-10-15T03:28:09Z HTTP 200, 1,730 bytes |
| 100000 | 4 | `000000000003ba27aa200b1cecaad478d2b00432346c3f1f3986da1afd33e506` | `f3e94742aca4b5ef85488dc37c06c3282295ffec960994b2c0d5ac2a25a95766` | 870,878 | read 2026-10-13 by lane fix-65 (`corpus/chain/merkle/2026-10-13-mainnet-paths.jsonl`) |
| 100002 | 9 | `0000000000013b8ab2cd513b0261a14096412195a72a0c4827d229dcc7e0f7af` | `2fda58e5959b0ee53c5253da9b9f3c0c739422ae04946966991cf55895287552` | 870,877 | read 2026-10-13 by lane fix-65 (`corpus/chain/merkle/2026-10-13-mainnet-paths.jsonl`) |
| 150000 | 10 | `0000000000000a3290f20e75860d505ce0e948a1d1d846bec7e39015d242884b` | `be0b136f2f3db38d4f55f1963f0acac506d637b3c27a4c42f3504836a4ec52b1` | 821,118 | <https://api.whatsonchain.com/v1/bsv/main/block/height/150000> 2026-10-15T03:28:10Z HTTP 200, 2,302 bytes |
| 128500 | 17 | `0000000000001efd5791bcc29a59e24c25ad4c8c35d5a6dbe050aae69e4c7b12` | `eef16f2af32d1abef2a8e0533465d3661f14dc9487fe208be8739f3542bb9514` | 842,618 | <https://api.whatsonchain.com/v1/bsv/main/block/height/128500> 2026-10-15T03:28:10Z HTTP 200, 2,800 bytes |
| 170000 | 27 | `000000000000051f68f43e9d455e72d9c4e4ce52e8a00c5e24c07340632405cb` | `ad590f24a9a2f3895d7b1597ab6f5f5dfec1571d346be40f971d37ebbb6a8e2b` | 801,118 | <https://api.whatsonchain.com/v1/bsv/main/block/height/170000> 2026-10-15T03:28:11Z HTTP 200, 3,460 bytes |
| 142500 | 129 | `00000000000001efa43fc0052cca77939f62c6f81079e6a157c9e5c58d68ad7d` | `e18e7073f36534b5e3268143cce8c7556d2ac13c50725f838337444d8e20a96f` | 828,618 | <https://api.whatsonchain.com/v1/bsv/main/block/height/142500> 2026-10-15T03:28:12Z HTTP 200, 10,306 bytes |
| 180000 | 235 | `00000000000004ff83b6c10460b239ef4a6aa320e5fffd6c7bcedefa8c78593c` | `8c9ec994b061d373a41ebbe56d46d6b36e230d07cbb5d8fcf9a09b9fd9acc4ad` | 791,118 | <https://api.whatsonchain.com/v1/bsv/main/block/height/180000> 2026-10-15T03:28:12Z HTTP 200, 17,293 bytes |
| 200000 | 388 | `000000000000034a7dedef4a161fa058a2d67a173a90155f3a2fe6fc132e0ebf` | `a08f8101f50fd9c9b3e5252aff4c1c1bd668f878fffaf3d0dbddeb029c307e88` | 771,118 | <https://api.whatsonchain.com/v1/bsv/main/block/height/200000> 2026-10-15T03:28:13Z HTTP 200, 27,989 bytes |
| 714000 | 8,100 | `000000000000000006ef1c82d99b86d7b3e7dff3146eb459ce816a2bb0f5ebdb` | `136abe81d0857398dba0336e7cb37d291621bd7bd8c32cba8fa0cfbac8096d5a` | 257,118 | <https://api.whatsonchain.com/v1/bsv/main/block/height/714000> 2026-10-15T03:30:37Z HTTP 200, 11,226 bytes; <https://api.whatsonchain.com/v1/bsv/main/block/hash/000000000000000006ef1c82d99b86d7b3e7dff3146eb459ce816a2bb0f5ebdb/page/1> 2026-10-15T03:30:38Z HTTP 200, 536,002 bytes |

Blocks 100000 (4 transactions) and 100002 (9) are the two of `corpus/chain/merkle/2026-10-13-mainnet-paths.jsonl`
(public reads of 2026-10-13, lane fix-65), kept as they stood. Ten blocks, ten distinct counts:
1, 4, 9, 10, 17, 27, 129, 235, 388, 8,100. One transaction: 160000. A count just above a power of two:
128500 (17 = 16 + 1) and 142500 (129 = 128 + 1).

The survey that chose them [M]: `https://api.whatsonchain.com/v1/bsv/main/block/height/<h>`
read for its `txcount` only, 2026-10-15T03:25:29Z to about 03:30:30Z, at heights 150000 to 500000
(15 heights), 100500 to 149500 by 500, 560000 to 800000 by 5000, 741000 to 759000 by 1000, 711000 to
718000, 713900 to 714100 and 757900 to 758100 by 10, 664000 to 667000 by 50; none of those bodies
is kept. Blocks 665000 (7,523) and 750000 (8,971) were read whole at 03:28:14Z and 03:28:16Z and not kept.

## The checks on each read [X]

- At read time (the lane's fetch script): the txid list complete (its length equals `txcount`, no
  repeat); the 80-byte header serialized from the read's fields ([D]: version, previous hash, merkle
  root, time, bits, nonce, little-endian) hashes by SHA256d to the read's block hash; a plain
  pairwise merkle over the txids equals the header's root.
- In `tools/subtree_vectors.py` (every generation, so `--check` in the chain leg repeats it): each
  line's header is 80 bytes hashing to its block hash; its bytes 36 to 68 equal `merkle_root`; that
  root, internal order, is the row's `header_root`; both transcriptions (Teranode's root over block
  assembly's partition, and bitcoin-sv v1.2.3 `6504a3af` src/consensus/merkle.cpp:247-282
  ComputeMerkleRoot through :312-319 BlockMerkleRoot [SRC]) must equal it or the generator stops.
- In the chain leg: `chaincheck --subtree` recomputes both roots through the Lean definitions
  (`lean/BsvChain/Teranode/Subtree.lean`'s `checkMerkleRoot` with every root recomputed, #63's
  `computeMerkleRoot`) and requires each to equal `header_root` on every row that has one.

## The file [M]

`corpus/merkle/subtree-vectors.jsonl`: 153 rows (117 before), 974,685 bytes, sha256
`69af1aaf8b885307ff4eb7d6448ce3f686d3e82e80050a571cb5a1f5bd4df608`. The 36 new rows: blocks 160000,
150000, 128500, 170000, 142500, 180000 and 200000 at sizes 1, 2, 4, 8, 16, and block 714000 once at
size 1024 (eight subtrees of 1,024 and a final one of 932). A txid costs 67 bytes in a row; under a
megabyte (1,000,000 bytes) the single-row budget left after the other rows is 8,477 transactions;
714000's 8,100 is the largest count of the blocks surveyed at or under it (the next above, 8,797 at
758000 and 8,971 at 750000, would carry the file past a megabyte: 8,971 measured 1,033,047 bytes).
`corpus/chain/merkle/2026-10-15-mainnet-blocks.jsonl`: 8 lines, 602,623 bytes, sha256
`85abd6f90fb79a861b9ec2b0374d1001cfe3513da9b14c78087c7fb90d4e101e`.

## The legs, verdict lines as printed

Run on the Studio from the lane's working tree (the content the lane's commit records), 2026-10-15.

- chain leg, `bash tools/chain_leg.sh` (the leg as `tools/check.sh` runs it, its Lean build under
  the Studio's one slot: `lean_lock: s6-66-leg took slot1 (03:49:09Z)`, after a wait from 03:31:06Z
  behind three other lanes and a dead holder the lock broke itself; `Build completed successfully (2155 jobs).`;
  `lean_lock: released slot1 (03:51:45Z)`; load1 15 to 19 through the wait):
  - `subtree vectors: GREEN [X] (the file equals a fresh generation)`
  - `chaincheck subtree vectors: GREEN [X] ([M] 153 rows; Teranode root = flat root on 149; refused 3; roots differ 1; failures 0)`
  - `chain timing: chaincheck subtree wall [M] 0.769758s`
  - `chain: GREEN [X] (spec projection; replay wall [M] 50.253723s, 3 executables at a time, parts summed [M] 106.391308s; node excluded)`, exit 0
- the check bites: a scratch copy with one bit of `mainnet-714000-size1024`'s `header_root` flipped:
  `chaincheck subtree: ERROR mainnet-714000-size1024: a root differs from the mainnet header's`,
  `chaincheck subtree vectors: RED [X] ([M] 152 rows; ...; failures 1)`, exit 1.
- `python3 tools/cite_check.py`: `cite_check: GREEN` (the rest of the line names the checked citations held at the pin, MOVED 0)
- `make check-pins`: `check-pins: GREEN (99 sites agree with docs/PROVENANCE.md §1a; 2 skipped by name: the built gobdk-runner, the predecessor-lean clone)`
- `git diff --check`: clean.

No node was started (no instance on any port), nothing was broadcast, no wallet was touched.

