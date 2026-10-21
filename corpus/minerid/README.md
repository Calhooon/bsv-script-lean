# corpus/minerid: mainnet Miner ID coinbase documents (#83)

[M] 2026-10-15, lane minerid-83. **Nothing of Miner ID is consensus** (cited in `lean/BsvChain/Views/MinerId.lean`'s header). These rows are
mainnet material READ ONLY (CLAUDE.md rule 10): public reads by URL, nothing broadcast.
The spec's view of the node's Miner ID index (`lean/BsvChain/Views/MinerId.lean`) is
checked against them by `chaincheck --minerid corpus/minerid/coinbase-docs.jsonl`
(`lean/Test/MinerIdCheck.lean`).

## coinbase-docs.jsonl

One row per coinbase output carrying the 0.1/0.2 Miner ID prefix `006a04ac1eed88`:

| field | meaning |
|---|---|
| `id` | `minerid-mainnet-<height>` |
| `height`, `block` | the block's height and hash (display order) |
| `coinbase_txid`, `vout` | the coinbase transaction and the output's index |
| `script` | the output script, hex |
| `coinbase_hex` | the whole coinbase transaction, hex (its double SHA-256 is `coinbase_txid`) |
| `expect` | the format, the document's `version`, `minerId`, `prevMinerId`, whether a dynamic document is present, and `node: accept`, read from the document's JSON by Python's `json` at intake, independently of the Lean reader |
| `miner_tag` | the explorer's miner label, informational only |
| `source` | the two URLs read and their UTC read times |
| `label` | `[M] mainnet, public read by URL, read only (rule 10)` |

## The recipe (2026-10-15, public reads of api.whatsonchain.com)

1. `GET https://api.whatsonchain.com/v1/bsv/main/block/height/<h>` for every 500th height
   from 620250 to 970750 (702 blocks, the tip read 971117 at 2026-10-15T03:27Z), every 1000th
   from 560000 to 620000 (61 blocks) and every 250th from 615250 to 620000 (20 blocks); a block is kept when an output of its
   `coinbaseTx` begins `006a04ac1eed88` or `006a04601dface`.
2. For each kept block, `GET https://api.whatsonchain.com/v1/bsv/main/tx/<coinbase_txid>/hex`;
   intake checks that the raw transaction's double SHA-256 is the txid and that it
   contains the output script.

Findings of the sample [M]: 63 blocks carry a Miner ID output, heights 620750 to
777750, all version `0.1` in the `ac1eed88` format, two miner ids (5 rows under one key
from 620750 to 626250, 58 under another from 631250 to 777750), none rotating
(`prevMinerId == minerId` in every row), none with a dynamic document or `dataRefs`. No
sampled block carries the version 0.3 prefix `601dface`, so the sample holds no
miner-info document and no revocation (only 0.3 documents carry revocation keys and
messages); the 0.3 path, `revokemid` and the database's revocation are checked on
synthetic [D] fixtures in `lean/Test/MinerIdCheck.lean`. A sample of every 500th block
does not show that no 0.3 document or revocation exists on mainnet; it shows none in
these 778 distinct blocks.
