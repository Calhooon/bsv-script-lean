# Chain eras corpus (#69)

[D] 2026-10-13, lane `s6-69`: one row per side of each chain-layer era boundary
at bitcoin-sv v1.2.3 `6504a3aff65ba97c0f6c80962b033e35ecbfed4b`: `bip34Height`,
`bip66Height`, `bip65Height` (the version floors and BIP30's BIP34 shortcut),
`csvHeight` (the lock-time cutoff), `uahfHeight` (the size checks and the script
word), `daaHeight` (the difficulty branch), `genesisHeight` and `chronicleHeight`
(the block's era and its sigop count), and the two BIP30 exception blocks
(91842 and 91880, by height and hash). Every expectation is a literal derived
from the cited source lines, never from the judge's output.

`chaincheck --eras corpus/chain/eras/eras.jsonl` judges every row node-free
inside the chain leg (`tools/chain_leg.sh`), against `lean/BsvChain/Eras.lean`
and the existing definitions it names. Mainnet rows are the spec projection only:
their node token is `unrealizable: mainnet height, the spec projection only`,
because a private regtest instance compiles regtest's heights
(`src/chainparams.cpp:1463–1490`) and nothing installs a mainnet height or
ancestry. Regtest rows are measured on fresh loopback instances by
`tools/node_scenarios.sh --eras-only`; the node compares only the submitblock
status and reason (or, for the bits row, the bits of each generated block).

Cases: `version` (`checkBlockVersion` at the row's height), `bip30`
(`bip30Enforced`), `bip30-connect` (block A at 102 holds coinbase C, block B at
103 repeats it; the default chain context computes the gate), `lock-cutoff`
(`contextualCheckTransactionForBlock`, lock time equal to the previous median),
`uahf-size` (a coinbase-only block through `checkBlock` with proof of work off,
`contextualCheckBlock`, and the block word's FORKID bit), `work-path`
(`nextWorkPath`), `regtest-bits` (`getNextWorkRequired` iterated from regtest's
genesis bits) and `era` (`protocolEraOf` and whether block sigops are counted).

What the rows say that the issue's sentences did not: regtest's next-work
computation never reaches the DAA (`fPowNoRetargeting` precedes the `daaHeight`
test, `src/pow.cpp:106–113`); no block size rule reads `uahfHeight` at the pin
(`src/validation.cpp:5795–5816,6058–6065`); regtest's BIP34 height never binds
alone, because BIP66's floor binds from 1251; and the BIP30 exceptions carry no
network test (`src/validation.cpp:3070–3077`).
