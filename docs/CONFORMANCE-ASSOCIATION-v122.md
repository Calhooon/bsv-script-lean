# The Association's protocol documentation read against the spec (#139, parts 1 to 4)

Issue numbers on this page are the archived tracker's ([docs/GLOSSARY.md](GLOSSARY.md), "archived #n").

`[M]` 2026-10-14, the read for #139 and its fix. **What this page is.** A
reading, sentence by sentence, of the BSV Association's protocol documentation (https://protocol.bsvblockchain.org/, a
GitBook) against the Lean definitions of this spec. Every specification page of that site names its ground truth as
bitcoin-sv **v1.2.2** = `879fc8b42168dd0e608dafd51b39c6dabad37d4d`; the node of record here is **v1.2.3** =
`6504a3aff65ba97c0f6c80962b033e35ecbfed4b` (`docs/PROVENANCE.md` §1). Each row quotes their sentence with its page and
section (their citation is at v1.2.2 `[LIT]`), names the spec's definition (file and line, this tree at the page's
commit) and the node line at v1.2.3 `[SRC]` (read with `git show v1.2.3:<path>`, never a working tree). No
implementation was run for this page: a row says what a sentence and a definition state, it is not a conformance run,
and it names no corpus `[D]`.

**The read.** The index `/llms.txt` and the Markdown twin (`<url>.md`) of each of the 19 pages it lists, read
2026-10-14 from 21:24:24Z to 21:24:39Z, and the HTML of nine pages for their section ids, 21:35:38Z to 21:35:46Z;
the 19 twins read again from 22:04:18Z to 22:04:22Z (each byte-identical to the earlier read) and the HTML of
`/concepts/transaction-templates` and `/specification/opcodes` at 22:04:26Z. Every URL, its UTC time, its HTTP status,
its bytes and its sha256 are in the record,
[`records/20261014-213924-xread-139-s4b.md`](records/20261014-213924-xread-139-s4b.md). Public reads only (rule 10).

**The verdicts.** AGREE: their sentence and the spec's definition state the same rule. THEIRS: they differ and the
spec's definition is read from source at the pin; the two sentences stand side by side in §3 for the maintainers to route
(no filing, no public word: the Association's source repository is private). OURS: the spec is wrong or silent where
it should not be; an issue here. This reading found **no OURS row**.

**The counts** `[M]`: §1, 22 rows (6 from the eight pages, 16 from the eleven): 18 AGREE, 4 THEIRS; the THEIRS rows
are 4 distinct disagreements (§3, T1 to T4); §2, the byte values AGREE; OURS none; 335 sentences held (§0).

## 0. Scope: what has a row, what is held, what states no rule here

**Held.** 335 rule-stating sentences of the nineteen pages (the unit: a sentence, a bullet or a table row that states
a value, a validity condition, an era status or a kind; counted by hand at the read `[M]`, a recount may move a count
by the unit's edges) carry no row and no value on this page. Rows whose rule is read from a file the v1.2.2 to v1.2.3
compare touched are held under the node team's discretion request until its clock; their cross-read is a private
record.

| page | held |
|---|---|
| `/introduction` | 1 |
| `/specification/transactions` | 11 |
| `/specification/script` | 24 |
| `/specification/opcodes` (the per-opcode descriptions, the era statuses, and the number and push detail) | 149 |
| `/specification/signature-hashing` | 25 |
| `/specification/blocks` | 22 |
| `/specification/consensus-rules` | 49 |
| `/specification/upgrade-history` | 20 |
| `/concepts/concepts` | 6 |
| `/concepts/economic-model` | 4 |
| `/concepts/transaction-templates` | 3 |
| `/concepts/sequence-and-locktime` | 9 |
| `/concepts/privacy-and-identity` | 2 |
| `/implementation-notes/policy-vs-consensus` | 2 |
| `/implementation-notes/node-operations` | 5 |
| `/implementation-notes/light-clients-and-spv` | 3 |
| **total** | **335** |

**No rule of the spec.** The spec has no peer-to-peer layer: the wire protocol page and the overview page state
transport rules (framing, the handshake, the message catalogue, the network magic, `protoconf`, the message-size
limits) that no definition here models, and both pages say themselves that nothing on them bears on validity. Their
two sentences that restate the transaction serialization are rows A5 and A6. The narrative sentences of the concept
pages (incentives, pseudonymity, the white paper's quotations) state no rule and have no row.

## 1. The rows

### 1a. The eight pages outside the specification section

| id | theirs (page, section: the sentence) `[LIT]` | the spec | the node at v1.2.3 `[SRC]` | verdict |
|---|---|---|---|---|
| A1 | `/concepts/economic-model` §Proof of work as an incentive: "The difficulty-adjustment algorithm targets a fixed average block interval regardless of how much computation the network applies" | `lean/BsvChain/Pow.lean:131–139` (`getNextCashWorkRequired`); `lean/BsvChain/Params.lean:134` (`powTargetSpacing := 600`) | `src/pow.cpp:256–297`; `src/chainparams.cpp:1051` | AGREE |
| A2 | `/concepts/transaction-templates` §P2PKH: "Locking Script - OP_DUP OP_HASH160 <Public Key Hash> OP_EQUALVERIFY OP_CHECKSIG ... Unlocking Script - <Signature> <Public Key>" (and `/implementation-notes/light-clients-and-spv` §Proof of integrity, the same pair) | `lean/BsvScript/Standard.lean:59` (`tmplPubKeyHash`) | `src/script/standard.cpp:55` | AGREE |
| A3 | `/concepts/transaction-templates`: "the templates below are the widely used standard forms", with the example "OP_3 <pubKey1> ... <pubKey5> OP_5 OP_CHECKMULTISIG" | `lean/BsvScript/Standard.lean:177–184` (`isStandardOutput`: a multisig output is standard up to x-of-3); the setting `acceptNonStandardOutput` (`lean/BsvScript/Params.lean`, `NodeConfig`) | `src/script/standard.cpp:353–374` (360–366) | **THEIRS** (§3, T1; policy) |
| A4 | `/concepts/digital-asset-recovery`: "The consensus handling of frozen outputs: a transaction or block that spends a consensus-frozen output is invalid" (and `/specification/upgrade-history` §Confiscation: "Consensus-frozen outputs invalidate blocks/transactions that spend them; the whitelist overrides this for valid confiscation transactions.") | `lean/BsvChain/Frozen.lean:3–18` (the module: every record is operator data supplied through the freeze RPCs; the reference's list name "Consensus" is its label; the spec's kind is the operator-list mechanism, a policy parameter, `docs/DESIGN-S6.md` §1.5, `docs/PARAMETERS.md` §8.2), `:24–29` (`Blacklist`) | `src/frozentxo_db.h:192–219` | **THEIRS** (§3, T2; the kind, the maintainers' to rule (rule 15)) |
| A5 | `/peer-to-peer-networking/p2p` §Relationship to the specification: "The serialization of a transaction ... on the wire is the same consensus serialization specified in Transactions" | `lean/BsvScript/Tx.lean:16–37` (`TxIn`, `TxOut`, `Tx`), `:62–75` (the readers) | `src/primitives/transaction.h`; `src/serialize.h:315–340` | AGREE (the transaction serialization) |
| A6 | `/peer-to-peer-networking/sv-node-wire-protocol` §Conventions: "`var_int` (CompactSize) ... identical to the encoding used throughout the consensus serialization" | `lean/BsvScript/Tx.lean:44–57` (`readVarInt`) | `src/serialize.h:315–340` | AGREE |

### 1b. The eleven specification-side pages: the upgrade history by height, and the rules read from files outside the held set

| id | theirs (page, section: the sentence) `[LIT]` | the spec | the node at v1.2.3 `[SRC]` | verdict |
|---|---|---|---|---|
| B1 | `/specification/upgrade-history` §Genesis: "Mainnet height **620,538** (Testnet 1,344,302; STN 100; Regtest 10,000)"; §Chronicle: "Mainnet height **943,816** (Testnet 1,713,168; Regtest 15,000)"; `/specification/opcodes` §Protocol eras (the same two mainnet heights) | `lean/BsvChain/Params.lean:122,124` (mainnet), `:162,164` (testnet), `:202` (STN Genesis), `:242,244` (regtest); `lean/BsvScript/Params.lean:188–190` | `src/chainparams.cpp:18–26`, `:1071,1074`, `:1367,1370`, `:1231`, `:1493,1496` | AGREE (STN's Chronicle height, 250, `lean/BsvChain/Params.lean:204`, `src/chainparams.cpp:24`, is not on their page) |
| B2 | `/specification/upgrade-history` §Timeline: UAHF "fork by time (MTP)"; Nov 2017, May 2018 and Nov 2018 "fork by time" | by height: `uahfHeight` 478,558 and `daaHeight` 504,031 (`lean/BsvChain/Params.lean:118,120`; `lean/BsvScript/Properties/Eras.lean:231–251`, the `flagWord_block_*` theorems; `lean/BsvChain/Eras.lean:108`, `nextWorkPath`); the 500-operation limit at every pre-Genesis height (`lean/BsvScript/Params.lean:272`) | `src/chainparams.cpp:1065,1068`; `src/verify_script_flags.cpp:54–69`; `src/pow.cpp:95–117`; `src/consensus/consensus.h:40`; `src/configscriptpolicy.cpp:65–69` | **THEIRS** (§3, T3) |
| B3 | `/specification/upgrade-history` §Nov 2017: "Enforce LOW_S (BIP146) and NULLFAIL; replace EDA with the current DAA (a 144-block-window retarget ...)" | `lean/BsvScript/Params.lean:42,60`; `lean/BsvScript/Properties/Eras.lean:244,251`; `lean/BsvChain/Pow.lean:131–139`; `lean/BsvChain/Eras.lean:108` | `src/verify_script_flags.cpp:61–69`; `src/pow.cpp:101–116,256–297` | AGREE |
| B4 | `/specification/upgrade-history` §UAHF and §Genesis, `/specification/script` §Limits by era, `/specification/transactions` §Size limits by era: the maximum transaction size 1,000,000 bytes before Genesis and 1,000,000,000 from it; operations per script 500, then `UINT32_MAX`; script size 10,000 bytes, then `UINT32_MAX`; script number length 4 bytes, 750,000 bytes from Genesis, 32 MB from Chronicle; public keys per multisig 20, then `UINT32_MAX`; 20,000 signature operations per transaction before Genesis | `lean/BsvScript/Params.lean:272–281`; `lean/BsvScript/TxRules.lean:27–28`; `lean/BsvScript/TxPolicy.lean:93` | `src/consensus/consensus.h:27–29,40,43,47,50,55,58,60,62,64,66` | AGREE (32 MB is 32 × 1,000,000 bytes, `consensus.h:15`) |
| B5 | `/specification/upgrade-history` §Genesis and `/specification/script` §Limits by era: the stack memory usage rule `Σ(32 + element_size)` over the main stack and the alt stack | `lean/BsvScript/Params.lean:287` (`elementOverhead`); `lean/BsvScript/Machine.lean:134–146` (the alt stack shares the budget) | `src/script/limitedstack.h:43`; `src/consensus/consensus.h:81–82` | AGREE |
| B6 | `/specification/script` §Limits by era: "That limit is a consensus value miners coordinate on; the specific number is operator policy." | `lean/BsvScript/Params.lean:205–206` (`maxStackMemoryUsageConsensus`: consensus, node-configurable); `docs/PARAMETERS.md` §8 (mandatory at launch) | `src/consensus/consensus.h:82`; `src/bitcoind.cpp:140–157` | **THEIRS** (§3, T4; rule 1) |
| B7 | `/specification/blocks` §Block size by era: "`LEGACY_MAX_BLOCK_SIZE` = 1,000,000 bytes (1 MB)" | `lean/BsvChain/Eras.lean:127` | `src/consensus/consensus.h:31` | AGREE (the constant's value) |
| B8 | `/specification/blocks` §Proof of work: the target decoded from `nBits`, refused when negative, zero, overflowing or above `powLimit`, and the hash at most the target; `nBits` equal to `GetNextWorkRequired`'s value; the DAA from `daaHeight` 504,031 over a 144-block window; a 10-minute spacing | `lean/BsvChain/Pow.lean:46–47` (`checkProofOfWork`), `:131–139`, `:145–146` (`getNextWorkRequired`); `lean/BsvChain/Params.lean:120,134` | `src/pow.cpp:150–171,95–117,256–297`; `src/chainparams.cpp:1051,1068` | AGREE |
| B9 | `/specification/consensus-rules` §Genesis Block Rule: "000000000019d6689c085ae165831e934ff763ae46a2a6c172b3f1b60a8ce26f" | `lean/BsvChain/Params.lean:142` (`hashGenesisBlock`) | `src/chainparams.cpp:1094–1099` | AGREE (the hash; the spec carries no header field, so their timestamp `1231006505` has no row) |
| B10 | `/specification/consensus-rules` and `/specification/upgrade-history`, the constants: `MAX_COINBASE_SCRIPTSIG_SIZE` (100), `COINBASE_MATURITY` (100), `CONFISCATION_MATURITY` (1000), `MAX_MONEY` (21,000,000 × 10⁸ sat), the 20,000 signature operations per transaction before Genesis | `lean/BsvScript/TxRules.lean:26–29`; `lean/BsvChain/Params.lean:691,699` | `src/consensus/consensus.h:47,69,75,79`; `src/amount.h:130` | AGREE (the values) |
| B11 | `/specification/transactions` §Serialization format: the layout of the transaction, `CTxIn`, `COutPoint` (36 bytes) and `CTxOut` (an 8-byte signed value), little-endian integers, the txid in internal byte order | `lean/BsvScript/Tx.lean:16–37,62–75` | `src/primitives/transaction.h`; `src/serialize.h` | AGREE |
| B12 | `/specification/transactions` §CompactSize (VarInt): the four widths and "The encoding must be **canonical** ... the decoder rejects a non-minimal encoding" | `lean/BsvScript/Tx.lean:44–57` | `src/serialize.h:315–340` | AGREE |
| B13 | `/specification/transactions` §Coinbase transaction: the null prevout, "a `txid` of all zeroes and `n = 0xffffffff`" | `lean/BsvScript/TxRules.lean:32–33` (`outPointIsNull`) | `src/primitives/transaction.h:68` | AGREE |
| B14 | `/specification/transactions` §BIP68 relative locktime: `SEQUENCE_FINAL` `0xffffffff`, `SEQUENCE_LOCKTIME_DISABLE_FLAG` `1 << 31`, `SEQUENCE_LOCKTIME_TYPE_FLAG` `1 << 22`, `SEQUENCE_LOCKTIME_MASK` `0x0000ffff` | `lean/BsvScript/TxContext.lean:28–31` | `src/primitives/transaction.h:99,106,113,119` | AGREE (their `SEQUENCE_LOCKTIME_GRANULARITY` has no definition here) |
| B15 | `/specification/transactions` §Top-level transaction: "Pre-Chronicle standard versions are 1–2" | `lean/BsvScript/Standard.lean:219–222,254–255` | `src/primitives/transaction.h:264–265`; `src/script/standard.cpp:431–439` | AGREE (a policy rule) |
| B16 | `/specification/signature-hashing` §The sighash type byte: `SIGHASH_ALL` `0x01`, `NONE` `0x02`, `SINGLE` `0x03`, `CHRONICLE` `0x20`, `FORKID` `0x40`, `ANYONECANPAY` `0x80`; "`baseType = sigHash & 0x1F`"; "`forkValue = sigHash >> 8`" | `lean/BsvScript/Sighash.lean:52–57,70–73` | `src/script/sighashtype.h:16–21,43,73–77` | AGREE |

## 2. The opcode byte values (part 2)

The byte values are `lean/BsvScript/Opcodes.lean:16–140` and, for the template matcher's four pseudo-words,
`lean/BsvScript/Standard.lean:52–55`, against `src/script/opcodes.h:13–160` at v1.2.3 `[SRC]`: AGREE on every value
(111 opcodes, `OP_INVALIDOPCODE` and the four pseudo-words) `[M]`. The era statuses of `/specification/opcodes` are held
(§0).

## 3. The disagreements, side by side (for the maintainers' ruling; no filing)

| | their sentence (v1.2.2 `[LIT]`) | the spec's sentence (v1.2.3 `[SRC]`) |
|---|---|---|
| T1 | the 3-of-5 bare multisig among "the widely used standard forms" (`/concepts/transaction-templates`) | The node's standardness test classes a bare multisig output standard up to x-of-3 (`standard.cpp:360–366`; `Standard.lean:177–184`); a 3-of-5 output is non-standard, and after Genesis the node reads the setting `-acceptnonstdoutputs` for it, default true (`configscriptpolicy.cpp:60,468–471`; `Params.lean` `acceptNonStandardOutput`). Policy, not validity. |
| T2 | "a transaction or block that spends a consensus-frozen output is invalid" (`/concepts/digital-asset-recovery`; `/specification/upgrade-history` §Confiscation) | The frozen lists are operator data supplied through the node's freeze RPCs; "Consensus" is the reference's name for the list the node also applies at block connection (`frozentxo_db.h:192–219`; `frozentxo.cpp:51–61`), and the spec's kind is the operator-list mechanism, a policy parameter (`lean/BsvChain/Frozen.lean:3–18`; DESIGN-S6 §1.5; PARAMETERS §8.2). Which reading is consensus is the maintainers' ruling (rule 15). |
| T3 | UAHF "fork by time (MTP)"; Nov 2017, May 2018, Nov 2018 "fork by time" (`/specification/upgrade-history` §Timeline) | At the pin no rule activates by time. The UAHF flags and the DAA start at heights (`uahfHeight` 478,558, `daaHeight` 504,031: `chainparams.cpp:1065,1068`, the file their page names as its ground truth; `verify_script_flags.cpp:54–69`; `pow.cpp:95–117`), and the 500-operation limit applies at every pre-Genesis height (`configscriptpolicy.cpp:65–69`, the getter returns `MAX_OPS_PER_SCRIPT_BEFORE_GENESIS`, `consensus.h:40`). The dates are history; the node selects by height. |
| T4 | "That limit is a consensus value miners coordinate on; the specific number is operator policy." (`/specification/script` §Limits by era) | `maxstackmemoryusageconsensus` is a consensus setting, mandatory at launch (`bitcoind.cpp:140–157`; `consensus.h:82`; `Params.lean:205–206`); the policy limit is a separate setting. Calling the consensus number policy blurs rule 1. |

**OURS.** None. The spec defines no `SEQUENCE_LOCKTIME_GRANULARITY` and no genesis header field (B14, B9); neither is a
rule the spec states, and neither is filed.

## 4. Part 3: their page beside the node line on the public pages

The citations land in the Lean docstrings (the Lean side's files) and reach `spec/` by `make spec`; this work changes
no Lean file. The list, for the docstrings' owners: every AGREE row above whose sentence states the rule the docstring
states. Each cites `https://protocol.bsvblockchain.org/<page>#<section-id>` (the ids read from the pages' HTML at the
read) beside the existing node line, labelled `[LIT]` at v1.2.2.

| file | declaration | cite |
|---|---|---|
| `lean/BsvScript/Opcodes.lean` | the module docstring (the byte table) | `/specification/opcodes#how-to-read-this-page` (the byte values only: the Hex column it defines for every family table) |
| `lean/BsvScript/Flags.lean` | `protocolEraOf` (78); `Properties/Eras.lean` `protocolEraOf_total` (76) | `/specification/opcodes#protocol-eras` (the heights only) |
| `lean/BsvScript/Params.lean` | `ChainParams.mainnet` (188) | `/specification/upgrade-history#timeline` (the heights only), `#genesis-2020-02-04`, `#chronicle-2026-04-07` |
| `lean/BsvChain/Params.lean` | `ChainParams.mainnet` (107), `.testnet` (147), `.regtest` (227): the Genesis and Chronicle heights; `hashGenesisBlock` (142) | `/specification/upgrade-history#genesis-2020-02-04`, `#chronicle-2026-04-07`; `/specification/consensus-rules#genesis-block-rule` |
| `lean/BsvScript/Params.lean` | the `Consensus` constants (270–289) | `/specification/script#limits-by-era`; `/specification/transactions#size-limits-by-era` |
| `lean/BsvScript/Properties/Eras.lean` | `flagWord_block_lowS` (244), `flagWord_block_nullFail` (251) | `/specification/upgrade-history#nov-2017` |
| `lean/BsvScript/Sighash.lean` | `SIGHASH_*` (52–57), `baseType` (71), `forkValue` (73) | `/specification/signature-hashing#the-sighash-type-byte` |
| `lean/BsvScript/TxRules.lean` | `MAX_MONEY` (26), `outPointIsNull` (33) | `/specification/transactions#output-ctxout`, `#coinbase-transaction` |
| `lean/BsvScript/TxContext.lean` | `SEQUENCE_FINAL` and the three BIP68 constants (28–31) | `/specification/transactions#bip68-relative-locktime-pre-genesis-only` |
| `lean/BsvScript/Tx.lean` | `TxIn`, `TxOut`, `Tx` (16, 24, 31); `readVarInt` (50) | `/specification/transactions#serialization-format`, `#compactsize-varint` |
| `lean/BsvScript/Standard.lean` | `tmplPubKeyHash` (59) | `/concepts/transaction-templates#transaction-template-example-payment-to-public-key-hash`; `/implementation-notes/light-clients-and-spv#proof-of-integrity` |
| `lean/BsvChain/Pow.lean` | `checkProofOfWork` (47), `getNextCashWorkRequired` (131), `getNextWorkRequired` (146) | `/specification/blocks#proof-of-work` |
| `lean/BsvChain/Eras.lean` | `LEGACY_MAX_BLOCK_SIZE` (127) | `/specification/blocks#block-size-by-era` (the constant only) |

No THEIRS sentence is cited: two cited sections also carry one (`upgrade-history#timeline`, T3; `script#limits-by-era`, T4), and their cite lines carry scope words that exclude it.

## 5. Part 4: the site as a documentation upstream

`docs/PROVENANCE.md` §1 carries the row and §1a the machine-readable keys (`association-docs.*`): the index URL, the
pin the specification pages name (v1.2.2, `879fc8b`), the read of 2026-10-14. The recon (rule 18, `docs/recon.md`)
reads the index and every page's Markdown twin at each entry and records each specification page's named pin and its
sha256; a moved pin or a changed page re-opens this page's rows for that page.
