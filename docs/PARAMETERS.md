# PARAMETERS: the consensus-vs-policy census (2026-09-22, #6; completed at #21 the same night: every parameter cited in bitcoin-sv v1.2.2 and in Teranode v0.15.9, the witnesses of §7; Teranode's cells re-read at v0.16.0 by #54 on 2026-10-06)

Issue numbers on this page are the archived tracker's ([docs/GLOSSARY.md](GLOSSARY.md), "archived #n").

**Constitution 01: consensus rules are the spec; policy limits are parameters;
the line is written down with citations.** Every value the interpreter reads is
listed with its **kind**, its default in bitcoin-sv **v1.2.3** (`6504a3aff`, the
reference; `[SRC]` file:line) and in Teranode **v0.16.0** (`4edb60a`, the pin since #54, 2026-10-06; v0.15.9 until then) (whose engine is
GoBDK = the reference compiled in, so the values are the ones Teranode passes
to it: `services/validator/ScriptVerifierGoBDK.go:147–243`, the defaults in
`settings/settings.go:101–135`), and bsv-rs **0.3.32** (the spec's pin since 2026-10-06, R1.6; 0.3.30 from 2026-09-27, #47, the stack memory budget under a word; its cells below were read at **0.3.28**, the pin from 2026-09-24, and 0.3.29 to 0.3.32 move only what they name: the CHRONICLE hash-type bit, the undefined base type, the shifts' size test and count bound and the `int64` splice operand at 0.3.29, the memory budget at 0.3.30, the splice operand reader at 0.3.32; a crate line cited "at 0.3.32" is the crates.io copy of commit `c05edf5`; 0.3.27 from 2026-09-23; **0.3.24** when the census was taken, its differences noted in the cells) where it has a
counterpart. The record type is `lean/BsvScript/Params.lean` (final at #21:
every field is read by the semantics or by `Params.derive`, except `maxTxSigOpsCountPolicy`
and `maxTxSizePolicy` (2026-09-27), read by the mempool's policy gate `BsvScript.TxPolicy` beside
`TxRules`; the other transaction-level policies of §4 are outside the script semantics
(DESIGN §5.5); the chain-layer extension and its fields are §8). Teranode's citations are read at the tag (`git show v0.16.0:<path>`;
never a working tree, `docs/PROVENANCE.md` §1).

**The kinds.**

| kind | meaning |
|---|---|
| **consensus** | decides block validity for every node; a constant in the source, selected by the UTXO era or the block height |
| **consensus, node-configurable** | a value that decides block validity but is a node setting with a default (the activation heights on test networks; the consensus stack memory) |
| **policy** | a node's setting for what it relays or mines; never decides block validity (`policy.h:176–180`: "scripts violating these flags may still be present in valid blocks and we must accept those blocks") |
| **era marker** | a flag that carries the era into the interpreter; derived from heights, not a setting |
| **never set** | defined but absent from every set the node computes at the pin |

## 1. The limits (`eval_script_params` / `verify_script_params`, `interpreter.h:136–195`)

Built per input by `make_eval_script_params` / `make_verify_script_params`
(`interpreter.cpp:2282–2302`) from `ConfigScriptPolicy`, the UTXO era of the flag
word and the `consensus` switch. A configured zero means "the consensus limit"
for every setter (`configscriptpolicy.cpp:164–308`).
This table carries the kind (the legend above) in its column headers, not in a kind column: the pre-Genesis and the post-Genesis `consensus = true` columns are **consensus** (the post-Genesis stack memory budget is **consensus, node-configurable**), the `consensus = false` column is **policy**, and the Teranode and bsv-rs columns give those implementations' values beside both.

| value | read at | pre-Genesis UTXO (consensus) | post-Genesis, `consensus = true` | policy (`consensus = false`): bitcoin-sv default | Teranode default | bsv-rs 0.3.28 (unchanged since 0.3.24 except the number-length limit, 0.3.28) |
|---|---|---|---|---|---|---|
| **MaxOpsPerScript** | `interpreter.cpp:466–467`, `377–380`: every opcode above `OP_16`, executed or not; over → `SCRIPT_ERR_OP_COUNT` | **500** `consensus.h:40`, `configscriptpolicy.cpp:67–70` | **UINT32_MAX** (4,294,967,295) `consensus.h:43`, `cpp:72–75` | `-maxopsperscriptpolicy`, default **UINT32_MAX** `policy.h:147`, `cpp:45`; 0 → the consensus limit `cpp:164–190` | **1,000,000** `settings.go:114` (`ScriptVerifierGoBDK.go:167`) | no limit (`spend.rs`: no op counter) |
| **MaxScriptNumLength** | every `CScriptNum` read (`script_num.cpp:62`), `OP_BIN2NUM` (`1789`); over → `SCRIPT_ERR_SCRIPTNUM_OVERFLOW` (`1807–1810`); CLTV/CSV read at width 5 regardless (`546`, `577`) | **4** `consensus.h:62`, `cpp:83–86` | **750,000** post-Genesis `consensus.h:64` (750 × 1,000, `consensus.h:13`), `cpp:90–93`; **32,000,000** post-Chronicle `consensus.h:66`, `cpp:94` | `-maxscriptnumlengthpolicy`, default **10,000** `policy.h:156`, `cpp:46`; 0 → the era's consensus limit `cpp:97–106`; minimum 4 `cpp:192–210` | **10,000** `settings.go:115` (`:179`) | since 0.3.28 the reference's limit under a word: 750,000 / 32,000,000 by the coin's era on the block path, the policy default 10,000 on the mempool path, 0 → the consensus limit (`flags.rs:52–58`, `371–382` at 0.3.32; `Spend::set_script_num_length_policy`, `spend.rs:448` at 0.3.32; bsv-rs#17, the spec's #20 Finding); 0.3.24 to 0.3.27 read any length (`script_num.rs`: a BigNumber); the default mode still does |
| **MaxScriptSize** | `interpreter.cpp:429–430`, per script (unlocking and locking separately); over → `SCRIPT_ERR_SCRIPT_SIZE` | **10,000** `consensus.h:58`, `cpp:113–116` | **UINT32_MAX** `consensus.h:60`, `cpp:117–120` | `-maxscriptsizepolicy`, default **500,000** `policy.h:93`, `cpp:47`; 0 → UINT32_MAX `cpp:212–234` | **100,000,000** `settings.go:113` (`:183`; the struct tag's default `settings/policy_settings.go:9`): a **policy** default, moved by v0.16.0 from 500,000 (v0.15.9 `settings.go:102`), the recon's entry 2; 0 → UINT32_MAX by the reference's setter compiled in | no limit |
| **MaxPubKeysPerMultiSig** | `OP_CHECKMULTISIG` (`1522+`, #11 cites the line); over → `SCRIPT_ERR_PUBKEY_COUNT` | **20** `consensus.h:50`, `cpp:126–129` | **UINT32_MAX** `consensus.h:55` | `-maxpubkeyspermultisigpolicy`, default **UINT32_MAX** `policy.h:150`, `cpp:48`; 0 → UINT32_MAX `cpp:236–258` | 0 → **UINT32_MAX** `settings.go:116` (`:187`) | **i32::MAX** (2,147,483,647) `spend.rs:76` `MAX_MULTISIG_KEY_COUNT` at 0.3.29 (`:75` at 0.3.28, `:57` at 0.3.24), checked at `1570–1574` |
| **MaxStackMemoryUsage** | the combined budget of the main and alt stacks (`limitedstack.cpp:194–207`; the alt stack is a child, `interpreter.cpp:1993`); each element costs size + **32** (`limitedstack.h:43, 163, 171`); over → `SCRIPT_ERR_STACK_SIZE` (`1814–1817`) | **INT64_MAX** (unlimited; the 520-byte element and 1,000-element limits apply instead: `script.h:29, 32`, `interpreter.cpp:455–458`, `1800–1803`) `cpp:143–146` | **`maxstackmemoryusageconsensus`**, default **INT64_MAX** `consensus.h:82`, `cpp:50`; 0 → INT64_MAX `cpp:269–308`: **consensus, node-configurable**; `bitcoind` refuses to start without it (`bitcoind.cpp:140–157`: a MANDATORY operator setting, so the library default above is never a daemon's), and the spec's oracle sets 0 (`harness/oracle/bitcoin.conf:40`) | `-maxstackmemoryusagepolicy`, default **100,000,000** `policy.h:153` (100 × 1,000,000, `consensus.h:15`), `cpp:49`; 0 → INT64_MAX; must be ≤ the consensus value `cpp:298–306` | consensus 0 → INT64_MAX; policy **104,857,600** `settings.go:118–119` (`:191`) | bsv-rs 0.3.30 and 0.3.32: **under a word, 100,000,000 on the node's count** (one budget over both stacks, each element its size + 32: `flags.rs:66`, `:70` at 0.3.32), `WORD_MEMORY_LIMIT` `spend.rs:110–118` at 0.3.32, the policy default on the block path too (a resource limit, never a verdict: `engine.resource-abort`, D15); **the default mode 32,000,000 per stack**, the bytes alone, `DEFAULT_MEMORY_LIMIT` `:108`; `memory_limit()` `:467–473` (an explicit `memory_limit` wins in every mode); charged before each growth by `charge` `:2379–2386` through `check_node_budget` `:2406–2421` (the policy's verdict before the budget, `:2407–2413`, then the budget, `:2414–2419`); `OP_NUM2BIN`'s element charged under a word at `:1219–1223` (the default mode's element-size check `:1198–1200`); `resource_error` `:2442–2455` (every line at 0.3.32). Through 0.3.29: 32,000,000 per stack in every mode (`spend.rs:73` at 0.3.29) |
| element size, pre-Genesis | `interpreter.cpp:455–458` → `SCRIPT_ERR_PUSH_SIZE` | **520** `script.h:29` | none (the memory budget) | none | none | **1 GiB** per element `spend.rs:70` `MAX_SCRIPT_ELEMENT_SIZE` at 0.3.29 (`:69` at 0.3.28, `:51` at 0.3.24), checked at `524`, `991` and `1033–1036` |
| stack elements, pre-Genesis | `interpreter.cpp:1800–1803` → `SCRIPT_ERR_STACK_SIZE` | **1,000** `script.h:32` | none | none | none | none |

**The evaluator's reach** (lean #53, `[M]`, `docs/records/20260929-094751-ladder53-s1.md`): on the box (Apple M5 Max, 36 GiB) `eval/bsvs` judges a 255,999,976-byte locking script (a stack 4,654,545 deep, `eval/ladder48.py`'s 55-opcode steps, each reaching `needI` and the `Impl` families' size tests) valid on the block path in 31.02 s at a peak memory footprint of 21.82 GB (a peak resident set of 17.02 GB, the compressor holding the rest; lean #50's evaluator the same minutes: 31.35 s, 21.82 GB); the footprint is linear, 85.3 to 86.0 bytes per lock byte from 16 MB up, and the time 0.10 to 0.12 s per million bytes, so the consensus size class (a lock inside the 1,000,000,000-byte transaction, `consensus.h:29`) needs some 86 GB `[D on M]`: beyond the box, inside a 128-GiB container.

**Teranode's side of §1, cited.** `newScriptVerifierGoBDK`
(`services/validator/ScriptVerifierGoBDK.go:147–243`) pushes every value of
`settings/settings.go:104–125` into GoBDK's own `ConfigScriptPolicy` through the
setters `SetMaxOpsPerScriptPolicy` (`:167`), `SetMaxScriptNumLengthPolicy` (`:179`),
`SetMaxScriptSizePolicy` (`:183`), `SetMaxPubKeysPerMultiSigPolicy` (`:187`) and
`SetMaxStackMemoryUsage` (`:191`, both values), which `bdk/core/txvalidator.cpp:372–395`
forwards verbatim to bitcoin-sv's setters (`configscriptpolicy.cpp:164–308`;
`#include <configscriptpolicy.h>`, `txvalidator.hpp:12`), so the zero rules and
the bounds are the reference's own. The limits reach the interpreter through the
reference's `make_verify_script_params` (`core/txvalidator.cpp:931`) with `consensus` =
Teranode's `SkipPolicyChecks` (`services/validator/TxValidator.go:227–229`; block
validation sets it: `subtreevalidation/Server.go:903, 959`,
`subtreevalidation/check_block_subtrees.go:702, 1284`,
`legacy/netsync/handle_block.go:1453, 1612, 1635`; every other path leaves it false). The
pre-Genesis element and stack-element limits are the reference's constants
compiled in (`script.h:29, 32`; GoBDK's archives carry `879fc8b42`,
`docs/PROVENANCE.md` §1). At the pin v0.16.0 the default `maxscriptsizepolicy` is 100,000,000
(`settings/settings.go:113`), a **policy** default that moved: 500,000 at v0.15.9 and through
v0.16.0-beta-11, 100,000,000 from v0.16.0-beta-12 (the recon, `docs/recon.md`, entries 1 and 2) `[SRC]`;
bitcoin-sv's default stays 500,000 (`policy.h:93`), so the two nodes' defaults now differ (§5).

**The `consensus` switch** is the caller's: block validation passes `true`
(`validation.cpp`, `CScriptCheck` `2504–2544`; BDK `core/txvalidator.cpp:931`),
mempool acceptance `false`. It selects the policy column above and, in
Teranode, the error mapping (`ScriptVerifierGoBDK.go:351–434`: op count, number
length or minimal encoding, script size, pubkey count and stack size are
reported as *policy* rejections when `consensus = false`). The interpreter
itself never reads it (`docs/DESIGN.md` §5.4): it is an argument of the
derivation, not a field of `EvalParams`. **SV-node exposes no RPC that judges
a lone transaction on the consensus path**: the `verifyscript` RPC hard-codes
`consensus = false` (`rpc/misc.cpp:855–856`) and `testmempoolaccept` does not
exist at v1.2.2. `CScriptCheck` with `consensus = true` is built for every input
when a block is connected (`CheckInputs(…, true, …, &vChecks)` at
`validation.cpp:3381–3394`, the check constructed at `2702–2710` and queued at
`2711–2714`), and on the mempool path only to re-check a failed script under the
mandatory flags (`2743–2750`, `2774–2781`, `2798–2805`); since D97 the harness's
own block road (`submitblock` on the block instance, DESIGN §7) carries an
arbitrary transaction to that block path. On `verifyscript` the consensus
*limits* are reproduced by zeroing every policy setting (the ops, script-size,
multisig-key and stack-memory setters store the consensus maximum for 0,
`configscriptpolicy.cpp:182`, `232`, `259`, `291`; the number-length setter
stores the 0, `:211`, and its getter resolves it per era, `:97–106`). Whether
that is the consensus path is DESIGN Q6.

## 2. The flags (`script_flags.h:13–115`)

How the word is built: the block flags by height (`verify_script_flags.cpp:32–81`),
the mempool flags (`11–30`: `StandardScriptVerifyFlags(era)` `policy.h:208–222`,
plus FORKID when standardness is not required), the per-input flags
(`InputScriptVerifyFlags(era, utxoEra)` `policy.h:226–245`); the mandatory sets
(`standard.h:55–68`) name what every block must satisfy since Chronicle.
Teranode: `bdk core/txvalidator.cpp:659–683` (`CalculateFlags`: the same three
functions; in consensus mode the block flags at `blockHeight − 1` with the era
of `blockHeight`, in policy mode the mempool flags with the era of
`blockHeight + 1`, plus the input flags from the UTXO height). bsv-rs has the word since 0.3.26 (`src/script/flags.rs`: `ScriptFlags::block(era)` = `GetBlockScriptFlags` at any post-DAA height with the per-input flags, `standard(era)` = `StandardScriptVerifyFlags` with them, the reference's bit values; `Spend::set_flags` applies a word under the reference's version gate at every gated site); the last column is its 0.3.28 behaviour (the pin since 2026-09-24), with the 0.3.24 knob in parentheses where it differed. bsv-rs models no pre-Genesis block or UTXO (a word without `GENESIS` or `UTXO_AFTER_GENESIS` is refused by `ScriptFlags::check`).

| flag (bit) | kind | in which set `[SRC]` | read at (`interpreter.cpp`) | effect | bsv-rs 0.3.28 (0.3.24 in parentheses) |
|---|---|---|---|---|---|
| `SCRIPT_VERIFY_P2SH` (0) | consensus by height (`p2shHeight`) | block `verify_script_flags.cpp:39`; mandatory `standard.h:56, 63` | `2354`, `2382`, `2435` | P2SH evaluation for **pre-Genesis UTXOs only** (`2383`); CLEANSTACK requires it | no P2SH evaluation (faithful: bsv-rs models post-Genesis UTXOs only); CLEANSTACK without P2SH refused by `check` |
| `SCRIPT_VERIFY_STRICTENC` (1) | consensus by height (`uahfHeight`), and implied by FORKID (`2315–2319`) | block `:55–57`; mandatory `:57, 64` | `291`, `314` | hash-type byte defined; the FORKID/CHRONICLE bit legality (`293–307`); pubkey encoding (`314–318`) | always on: a word must carry `SIGHASH_FORKID` (`check`), which forces STRICTENC as the reference does (`2315–2318`); the FORKID bit required of every signature (`spend.rs:1964–1966` at 0.3.32) |
| `SCRIPT_VERIFY_DERSIG` (2) | consensus by height (`BIP66Height`) | block `:43`; standard `policy.h:183` | `275` (with LOW_S or STRICTENC) | DER shape of the signature; redundant since STRICTENC is always on post-UAHF | strict DER always (`spend.rs:1911–1914` at 0.3.32; redundant under STRICTENC, as on the reference) |
| `SCRIPT_VERIFY_LOW_S` (3) | consensus by height (`daaHeight`), **version-gated** | block `:65–66`; mandatory `:60, 67` | `282–287` | low-S, unless the version gate lifts it | the word's LOW_S under the version gate (`set_flags`, `spend.rs:377–394` at 0.3.32; 0.3.24: `require_low_s` iff version ≤ 1) |
| `SCRIPT_VERIFY_NULLDUMMY` (4) | **policy**, version-gated | standard `src/policy/policy.h:184` only | `1664–1670` | the `CHECKMULTISIG` dummy must be empty | the word's NULLDUMMY under the version gate (0.3.26; 0.3.24 enforced it at every version: `flags.version-gate.nulldummy`, a witness of #15 now in the crate's tests) |
| `SCRIPT_VERIFY_SIGPUSHONLY` (5) | consensus by height (Genesis), gated by era and version | block `:71–75`; input `policy.h:226–229` | `2321–2334` | push-only unlocking script for Genesis-without-Chronicle, or Chronicle with version ≤ 1 | the word's SIGPUSHONLY with the era and version gate of `2321–2334` (0.3.26; 0.3.24 required push-only at every version: `flags.sigpushonly`) |
| `SCRIPT_VERIFY_MINIMALDATA` (6) | **policy**, version-gated | standard `src/policy/policy.h:189` only | `433` (→ every push `474–479` and every number read) | minimal pushes and minimal number encodings | the word's MINIMALDATA under the version gate (0.3.24: `require_minimal` iff version ≤ 1, in every mode) |
| `SCRIPT_VERIFY_DISCOURAGE_UPGRADABLE_NOPS` (7) | **policy** | standard `src/policy/policy.h:185` only | `522`, `565`, `613`, `646`, `671`, `696`, `732`, `768` | CLTV/CSV as NOPs (post-Genesis UTXOs), `0xb3`–`0xb7` pre-Chronicle, `NOP1/9/10` are rejected | the word's bit, in the standard word only (0.3.26; 0.3.24 had no such rule: `flags.discourage-upgradable-nops`) |
| `SCRIPT_VERIFY_CLEANSTACK` (8) | **policy**, version-gated | standard `src/policy/policy.h:188` only | `2430–2448` | exactly one element after evaluation | the word's CLEANSTACK under the version gate (0.3.24: `require_clean_stack` iff version ≤ 1) |
| `SCRIPT_VERIFY_CHECKLOCKTIMEVERIFY` (9) | consensus by height (`BIP65Height`) | block `:47`; standard `src/policy/policy.h:186` | `520` | CLTV live for **pre-Genesis UTXOs only** (`520`: `\|\| utxo_after_genesis` → NOP) | no check: a NOP for every UTXO, faithful for the post-Genesis UTXOs bsv-rs models (`520`) |
| `SCRIPT_VERIFY_CHECKSEQUENCEVERIFY` (10) | consensus by height (`CSVHeight`) | block `:51`; standard `src/policy/policy.h:187` | `563` | CSV live for pre-Genesis UTXOs only | no check (as CLTV) |
| `SCRIPT_VERIFY_MINIMALIF` (13) | **never set** by any derivation (absent from the block, standard and mandatory sets; settable only by a word given from outside: the `verifyscript` RPC's integer `flags`, `rpc/misc.cpp:697–702`, or a `-promiscuousmempoolflags` word; `:1295` is the flag's entry in the RPC's name map), version-gated where read | none | `796–804` | `IF`/`NOTIF` operand must be `[]` or `[0x01]` | the word's bit under the version gate (0.3.26; none before) |
| `SCRIPT_VERIFY_NULLFAIL` (14) | consensus by height (`daaHeight`), **version-gated** | block `:67–68`; mandatory `:59, 66` | `1491–1497`, `1641–1647` | a failed signature check must have an empty signature | the word's NULLFAIL under the version gate (0.3.26; 0.3.24 had no NULLFAIL rule: `flags.version-gate.nullfail`) |
| `SCRIPT_VERIFY_COMPRESSED_PUBKEYTYPE` (15) | **never set** by any derivation (only by a word given from outside: the `verifyscript` RPC's integer `flags`, `rpc/misc.cpp:697–702`, or a `-promiscuousmempoolflags` word; `:1299` is the flag's entry in the RPC's name map) | none | `322–326` | only compressed keys | the word's bit (0.3.26; none before) |
| `SCRIPT_ENABLE_SIGHASH_FORKID` (16) | consensus by height (`uahfHeight`) | block `:58`; mandatory `:58, 65` | `260`, `299`, `1487`, `1619`, `2315` | BIP143 digest for FORKID signatures; `FindAndDelete` only for non-FORKID (`255–263`); FORKID mandatory when enabled (`306–307`) | required (a word must carry it; the BIP143 digest only, no original digest); `CleanupScriptCode` only for a non-FORKID signature since 0.3.27 (0.3.24 deleted every signature: `sighash.scriptcode.findanddelete`) |
| `SCRIPT_GENESIS` (18) | **era marker** (the spending era) | block `:71–73`; standard `policy.h:217–220` | `2326` | the SIGPUSHONLY gate | `ProtocolEra::PostGenesis`/`PostChronicle` (`flags.rs`; no pre-Genesis era: `ProtocolEra::mainnet` is `None` below 620,538); required in a word |
| `SCRIPT_UTXO_AFTER_GENESIS` (19) | **era marker** (the UTXO's creation era) | input `policy.h:233–238` | `411` → 34 `utxo_after_genesis` sites (§3 of DESIGN) | the post-Genesis rules: limits, memory budget, `OP_RETURN`, one `ELSE`, CLTV/CSV as NOPs, P2SH off | required in a word (`check`): post-Genesis UTXOs only; one `ELSE` per `IF` since 0.3.27 (`flow.else`) |
| `SCRIPT_CHRONICLE` (20) | **era marker** (the spending era); in the post-Chronicle mandatory set `standard.h:68` | block `:77–78`; standard post-Chronicle `policy.h:196–198, 212–215` | `43` (the version gate), `298`, `1475`, `1571`, `2326–2327` | the version gate; the CHRONICLE hash-type bit; `scriptCode` += locking script for a `CHECKSIG` in the unlocking script | the version gate `EnforceNonMalleability` at every gated site (`ScriptFlags::gates`, 0.3.26; 0.3.24: three knobs on `transaction_version <= 1`, `spend.rs:190–192` at 0.3.24); no CHRONICLE hash-type bit at 0.3.28 (`sighash.rs`); since 0.3.29 the bit dispatches the digest (the original with it, BIP143 without: `compute_sighash_dispatched_for_signing`, `sighash.rs:878` at bsv-rs 0.4.4) and is refused under STRICTENC before Chronicle (`spend.rs:1953–1960` at 0.3.32; bsv-rs#22) |
| `SCRIPT_UTXO_AFTER_CHRONICLE` (21) | **era marker** (the UTXO's creation era) | input `policy.h:239–242` | `412` → `600`, `611`, `644`, `669`, `694`, `730`, `775`, `360–375` | `OP_VER`, `OP_VERIF`/`OP_VERNOTIF`, `OP_SUBSTR`/`OP_LEFT`/`OP_RIGHT`, `OP_LSHIFTNUM`/`OP_RSHIFTNUM`, `OP_2MUL`/`OP_2DIV`; numbers to 32 MB | all of them since 0.3.27 under the word's bit (bsv-rs#12; 0.3.24 disabled the version opcodes and `OP_2MUL`/`OP_2DIV` and ran `0xb3`–`0xb7` as NOPs); the number width is the reference's limit under a word since 0.3.28 (32,000,000 for a post-Chronicle coin on the block path, `flags.rs:52–58`; bsv-rs#17): unbounded until 0.3.27; since 0.3.29 a left shift's result size is tested before the shift and a count past `INT_MAX` is `SCRIPT_ERR_BIG_INT` on both shifts (`spend.rs:2120–2150` at 0.3.32; bsv-rs#21), and `OP_SUBSTR`/`OP_LEFT`/`OP_RIGHT` read their operands through the reference's `int64` path (`read_splice_operand`, `spend.rs:2208–2219` at 0.3.32; bsv-rs#20). The reading of record at v1.2.3 is a defined refusal ([SRC] `int_serialization.h:61–118`, `script_num.cpp:80–91` at `6504a3af`); the previous pin's reading and its measurements are recorded in material withheld from the public edition at the maintainers' request (group `d8-node-team-discretion`). |
| `SCRIPT_FLAG_LAST` (22) | the bound | `script_flags.h:114` | `2259–2262` (`valid_flags`) | `UTXO_AFTER_CHRONICLE` requires `UTXO_AFTER_GENESIS` | none |
| bits 11, 12, 17 | unassigned at the pin | none | none | none | none |

**Teranode's side of §2, cited.** GoBDK computes the word per input in
`CalculateFlags` (`bdk/core/txvalidator.cpp:658–681`) with the reference's own
functions compiled in (`#include <verify_script_flags.h>`, `<policy/policy.h>`,
`<protocol_era.h>`, `core/txvalidator.cpp:6–8`): the block word
`GetBlockScriptFlags(consensusParams, blockHeight − 1, era)` with the era of
`blockHeight` (`:663–668`), the mempool word `GetScriptVerifyFlags(era, requireStandard)`
with the era of `blockHeight + 1` (`:669–674`; no promiscuous word exists on this
side), the per-input word `InputScriptVerifyFlags(era, utxoEra)` (`:677–678`),
OR-ed (`:680`). The heights the block word reads are bitcoin-sv's `CChainParams`
compiled in, selected by network name (`getBDKChainNameFromParams`,
`ScriptVerifierGoBDK.go:124–137`; the validator's `consensusParams`, read at `core/txvalidator.cpp:668`, is
`chainParams->GetConsensus()` for every chain but STN, which since `4eab3acd` takes GoBDK's own table, `:271–321`,
set in the constructor `:324–337`);
only the Genesis and Chronicle heights are pushed from Teranode's own `chaincfg`
(`ScriptVerifierGoBDK.go:158–165`, from go-chaincfg v1.6.2 `params.go:276–277`,
through `core/txvalidator.cpp:397–414`). Teranode's height convention: `bdkBlockHeight`
passes the block's height in consensus mode and the tip (`blockHeight − 1`) in
policy mode (`ScriptVerifierGoBDK.go:261–271`), which lands on the reference's
`chainActive.Height()` / `+ 1` sites; an unconfirmed parent's UTXO height is
`MEMPOOL_HEIGHT` in consensus mode (rejected, `core/txvalidator.cpp:903–904`) and the
candidate height in policy mode (`substituteUnconfirmedHeights`,
`ScriptVerifierGoBDK.go:54–79`; the reference substitutes the next height,
`validation.cpp:2667–2674`). Every row of the table therefore holds for Teranode
as written; the last column is bsv-rs's own.

## 3. The version gate and the eras

| value | kind | bitcoin-sv | Teranode | bsv-rs |
|---|---|---|---|---|
| `IsMalleableTxnVersion(v) = v > 1`; `EnforceNonMalleability(flags, v) = ¬(IsChronicle(flags) ∧ v > 1)` | consensus | `interpreter.cpp:34–44`; `v` = the spending transaction's `nVersion` (`2254–2257`) | the same code | transcribed (`flags.rs`, `ScriptFlags::gates`) at every gated site under a word (0.3.26); the default mode (no word) keeps `transaction_version <= 1` on four knobs (`spend.rs:314–320` at 0.3.32) |
| Genesis activation height (mainnet) | consensus; node-configurable for test networks (`-genesisactivationheight`, `init.cpp:2613`; `configscriptpolicy.cpp:353–364` for Chronicle) | **620,538** `chainparams.cpp:18`, `1071`; `params.h:37` | **620,538** go-chaincfg v1.6.2 `params.go:276` (the pin since #54; the same line at v1.5.8) | **620,538** `ProtocolEra::MAINNET_GENESIS_HEIGHT` (`flags.rs`, 0.3.26) |
| Chronicle activation height (mainnet) | consensus; node-configurable as above | **943,816** `chainparams.cpp:23`, `1074` | **943,816** `params.go:277` | **943,816** `ProtocolEra::MAINNET_CHRONICLE_HEIGHT` |
| the era of a height | consensus | `protocol_era.h:28–41`: PreGenesis / PostGenesis / PostChronicle (`Unknown = 0` is the invalid value); "the height of the block where the new rules are active" `params.h:33–36` | `GetProtocolEra` in BDK | `ProtocolEra::mainnet(height)`: `None` below Genesis (not modelled), `PostGenesis`, `PostChronicle` |
| the graceful periods | **policy** (mempool acceptance around an activation) | 72 blocks `policy.h:128, 133`, max 7,200 `:139, 144`; `InProtocolGracePeriod` | none in the engine: no grace-period logic in `bdk/core` (`InProtocolGracePeriod` absent; the reference's lives in `validation.cpp`, outside GoBDK) | none |
| the other block heights (P2SH, BIP65, BIP66, CSV, UAHF, DAA) | consensus by height | `chainparams.cpp:1038–1076`: BIP34 227,931 · BIP66 363,725 · BIP65 388,381 · CSV 419,328 · UAHF 478,558 · DAA 504,031 · P2SH `P2SH_ACTIVATION_MAIN` 173,805 (`:28`, `:1076`) | the reference's `chainparams.cpp` compiled into GoBDK, selected by network name (`ScriptVerifierGoBDK.go:124–137`, `core/txvalidator.cpp:667`); the version Teranode v0.16.0's `go.mod:15` requires (`go.sum:132–133`), go-chaincfg v1.6.2 `params.go:265–274` (the same lines at v1.5.8, the pin from 2026-09-27 until #54), carries Teranode's own copies (BIP34 227,931 · BIP65 388,381 · BIP66 363,725 · CSV 419,328 · UAHF 478,558 · DAA 504,031, equal to the reference's; no P2SH height) that the script engine never reads | no entry |
| `requireStandard` | **policy** | **the default, named once (D123)**: `requireStandard = !GetBoolArg("-acceptnonstdtxn", !chainparams.RequireStandard())` `init.cpp:3158–3160`, so mainnet `true` (`chainparams.cpp:1121`) and regtest `false` (`chainparams.cpp:1527`: a regtest instance runs at mainnet's default only with `acceptnonstdtxn=0`); the Config's own initial value `configscriptpolicy.cpp:61`, overwritten at init; `-acceptnonstdtxn` accepted on all chains since 1.2.2 (release notes); the mempool gate `validation.cpp:1074–1089` (a non-standard transaction is rejected when `!acceptNonStandardOutput`, or post-Genesis when `requireStandard` and the reason is not `scriptpubkey`), `IsStandardTx` `script/standard.cpp:427–500`, `GetAcceptNonStandardOutput(era)` `configscriptpolicy.cpp:468–471` (post-Genesis the explicit setting, pre-Genesis `!requireStandard`) | **`false`** `settings.go:123`, pushed at `ScriptVerifierGoBDK.go:203`; `acceptnonstdoutputs` **true** `:122`, `:202`; the same gate replicated in `bdk/core/txvalidator.cpp:978–1004` (`implCheckStandardness`, policy mode only) | no entry |
| `DEFAULT_SPEND_HEIGHT` (the spec's default spending height, `docs/DESIGN.md` §6) | a spec constant, not a node value | **967,896**: the mainnet tip read at the pin date (2026-09-22T15:48Z, WhatsOnChain `chain/info`, a read) `[M]`; every derived default flag word is reproducible from it; re-stamped only with the pin | none | none |
| `-promiscuousmempoolflags` | **policy** | replaces the mempool flag word when standardness is off `verify_script_flags.cpp:20–25`, `validation.cpp:796–802` | none: no such setting (`settings.go:101–135`); GoBDK's mempool word is `GetScriptVerifyFlags(era, requireStandard)` with no word to replace it (`core/txvalidator.cpp:674`) | no entry |
| the sighash type space | consensus | base 1/2/3 (`sighashtype.h:14–35`), bits `0x20` CHRONICLE, `0x40` FORKID, `0x80` ANYONECANPAY; `isDefined` `79–84` | the same code compiled in (GoBDK, `docs/PROVENANCE.md` §1) | `SIGHASH_*` `sighash.rs:89–101` at 0.3.28 (no CHRONICLE bit); since 0.3.29 `sighash.rs:91–109` with `SIGHASH_CHRONICLE` at 109 and the dispatch, the undefined base type refused (`spend.rs:1935–1945` at 0.3.32; bsv-rs#23) |
| the height convention of the block word (#20) | consensus | `GetBlockScriptFlags(config, tip)` (`validation.cpp:2973–2982`) is called with the block's parent (`validation.cpp:3472`), so the flags tested against `height` (P2SH `verify_script_flags.cpp:39`, UAHF `:55`, DAA `:65`) enter the block word one block after their chain height (P2SH from block 173,806; the UAHF fork block 478,559; the DAA fork block 504,032) and the flags tested against `height + 1` (DERSIG `:43`, CLTV `:47`, CSV `:51`) enter at theirs (363,725; 388,381; 419,328); the era bits follow the era of the block itself (`validation.cpp:2980`: `tip + 1`; the height read at `2978`). Theorems `flagWord_block_*`, `flagWord_era_bits` (`lean/BsvScript/Properties/Eras.lean`); the rows `eras.height.*` of `corpus/eras` | BDK `core/txvalidator.cpp:663–668`: `GetBlockScriptFlags(params, blockHeight − 1, era(blockHeight))`, the same word (`bdkCalculateFlags_consensus`) | `ScriptFlags::block(era)` (`flags.rs`): the post-DAA word of an era; no word below Genesis (`ProtocolEra::at_height` is `None` there) |
| the height convention of the mempool word | policy path | `GetScriptVerifyFlags(config, era)` with the era of `tip + 1` (`validation.cpp:1031`, `1329`): the standard set of the era, no height test (`flagWord_mempool_of_eras`) | BDK `:669–674`: the era of `blockHeight + 1`, `blockHeight` the tip (`bdkCalculateFlags_policy`) | `ScriptFlags::standard(era)` |
| `MEMPOOL_HEIGHT`, a mempool coin | the mempool path's convention | `0x7FFFFFFF` (`protocol_era.h:14`); `GetProtocolEra` throws on it (`protocol_era.cpp:25–30`); `GetInputScriptBlockHeight` substitutes `chainActive.Height() + 1` (`validation.cpp:2667–2674`, the substitution at `2671`): a coin created in the mempool is the next block's, its era the spend height's (`inputScriptBlockHeight`, `Flags.lean`; `inputScriptBlockHeight_mempool`); `verifyscript` does the same (`rpc/misc.cpp:803–809`); not a corpus value (DESIGN §6) | BDK `resolveUtxoEraHeight(utxoHeight, blockHeight + 1)` (`core/txvalidator.cpp:267–269`, `677`); refused in consensus mode (`903–904`, `UnconfirmedInputInBlock`) | no entry (no heights) |
| the activation heights of the other networks | consensus by chain; node-configurable | `chainparams.cpp:19–21` (Genesis: STN 100, testnet 1,344,302, regtest 10,000), `:24–26` (Chronicle: STN 250, testnet 1,713,168, regtest 15,000), `:29–31` (P2SH: STN 1, testnet 519, regtest 1); `-genesisactivationheight` and `-chronicleactivationheight` override them (`init.cpp:2609–2616`; `SetChronicleActivationHeight` refuses zero or a negative value, `configscriptpolicy.cpp:353–364`): what the harness's node oracle on regtest sets (#27) | the chain's Genesis and Chronicle heights pushed by Teranode (`ScriptVerifierGoBDK.go:158–165`, through GoBDK's setters `core/txvalidator.cpp:397–414`) from the params its `network` setting selects (`settings/settings.go:21`, `:102`; no setting at the tag overrides them; Teranode v0.16.0's `go.mod:15` requires go-chaincfg v1.6.2): go-chaincfg v1.6.2 `params.go:276–277` for mainnet (620,538 / 943,816), **`params.go:475–476` for regtest (100 / 200; 10,000 / 15,000 at v1.5.8)**, `params.go:394–395` for STN (100 / 250), `params.go:556–557` for testnet (1,344,302 / 1,713,168), go-chaincfg `params.go:732–733` for tstn (1 / 2); tstn's genesis block is its own since v1.6.2 (`params.go:719–720`, `scalingTeraTestNetGenesisBlock`; testnet's at v1.5.8) | `ProtocolEra::at_height(height, genesis, chronicle)` takes them as arguments (`flags.rs`) |

## 4. Teranode's other policy values (not read by the interpreter; recorded because the runner sets them)

`settings.go:104–125` at the tag, each pushed into GoBDK by `ScriptVerifierGoBDK.go`: `maxtxsizepolicy` **10,485,760** (`:108`, `SetMaxTxSizePolicy :171`; bitcoin-sv **10,000,000**, `policy.h:70`, read by `IsStandardTx` `script/standard.cpp:445–449` through `GetMaxTxSize(era, false)` `configscriptpolicy.cpp:397–412`; the consensus size is 1 GB in both, `consensus.h:29`) · `excessiveblocksize` 4,294,967,296 (`:104`) · `datacarriersize` 1,000,000 (`:112`, `SetDataCarrierSize :201`; bitcoin-sv `DEFAULT_DATA_CARRIER_SIZE` = UINT32_MAX, `script/standard.h:46`) · `datacarrier` **false** (`:124`, `SetDataCarrier :200`; bitcoin-sv true) · `acceptnonstdoutputs` true (`:122`, `:202`) · `requirestandard` false (`:123`, `:203`) · `permitbaremultisig` true (`:125`, `:204`) · `minminingtxfee` 0.000005 BSV/kB (`:109`, `SetMinMiningTxFee`) · `maxtxsigopscountspolicy` 0 = unlimited (`:117`, `SetMaxSigOpsPostGenesisPolicy :175`) · the consolidation settings (`:219–235`). The relay and mining settings are **policy**; `excessiveblocksize` is **consensus, node-configurable** (§8). These are transaction/block-level settings outside the script semantics (DESIGN §5.5: the spec's `TxRules` carries the consensus checks only); `maxtxsizepolicy` and `maxtxsigopscountspolicy` are `NodeConfig` fields read by `BsvScript.TxPolicy` since 2026-09-27; the harness runners set them (#27, #30). `-datacarrier`, `-datacarriersize` and `-permitbaremultisig` are `NodeConfig` fields since 2026-09-28, and with `requireStandard` and `-acceptnonstdoutputs` they are read by `BsvScript.Standard` and `TxPolicy.standardnessRefusal`, the mempool's standardness gate (`eb4cddf`).

## 5. The findings of the census

Each is a configuration fact read from source, not a verdict divergence (those need a witness, #15/#30).

**Finding.** Teranode's default `maxopsperscriptpolicy` is **1,000,000** (`settings/settings.go:114`, passed to the engine at `ScriptVerifierGoBDK.go:167`), while bitcoin-sv's default policy value is **UINT32_MAX** (`policy.h:147`, `configscriptpolicy.cpp:45`); the consensus limit is UINT32_MAX in both (`consensus.h:43`). A script with more than a million non-push opcodes is consensus-valid and mined by an SV-node with defaults, but a Teranode with defaults rejects it as policy (`ScriptVerifierGoBDK.go:436–442`: `SCRIPT_ERR_OP_COUNT` is a policy error when `consensus = false`). **No witness at defaults (#21, re-read at v0.16.0 by #54):** every counted opcode is at least one byte and the op count is per script (`interpreter.cpp:466–467`, `nOpCount` local to `EvalScript`), so a script exceeding 1,000,000 ops exceeds 1,000,000 bytes, and bitcoin-sv's default `maxscriptsizepolicy` of 500,000 (`policy.h:93`) refuses it first. At v0.15.9 Teranode's default was 500,000 too and refused it first as well; at v0.16.0 Teranode's is 100,000,000 (`settings.go:113`), so such a script up to 100,000,000 bytes is refused by both default mempools, by bitcoin-sv for its size and by Teranode for its op count: the same verdict, two reasons, both policy.

**Finding.** Teranode's default `maxstackmemoryusagepolicy` is **104,857,600** (100 MiB, `settings.go:118`) while bitcoin-sv's is **100,000,000** (100 MB, `policy.h:153` with `consensus.h:15`); the consensus value is Teranode's 0 → INT64_MAX (`settings.go:119`, `configscriptpolicy.cpp:280–283`) and bitcoin-sv's operator's mandatory `-maxstackmemoryusageconsensus` (`bitcoind.cpp:140–157`; 0 → INT64_MAX, as the spec's oracle sets it, `harness/oracle/bitcoin.conf:40`). A spend whose combined stack (size + 32 bytes per element) lies between 100,000,000 and 104,857,600 bytes is relayed by a default Teranode and refused by a default SV-node's mempool; a block carrying it is valid for both (the consensus budget), and a default SV-node never mines it. **Witness `witness-policy-00001`** (§7, `corpus/witnesses/policy-defaults.jsonl`): a 3-byte element doubled 25 times by `OP_DUP OP_CAT`, peak stack memory 100,663,360 bytes at the last `OP_DUP`.

**Finding.** Teranode's default `requirestandard` is **false** (`settings.go:123`) while bitcoin-sv's mainnet default is **true** (`configscriptpolicy.cpp:61`, set from the chain's `RequireStandard` at `init.cpp:3158–3160`). The interpreter's flag word is the same either way except for `-promiscuousmempoolflags` (`verify_script_flags.cpp:18–26`); the difference is in the standardness checks outside the interpreter (`script/standard.cpp:427–500`, the gate `validation.cpp:1074–1089`; BDK's `implCheckStandardness` `core/txvalidator.cpp:978–1004`): a transaction `IsStandardTx` refuses for a reason other than `scriptpubkey` (`version`, `tx-size`, `scriptsig-size`, `scriptsig-not-pushonly`, `bare-multisig`, `dust`, `datacarrier-size-exceeded`) is refused by a default SV-node's mempool and accepted by a default Teranode's. **Witness `witness-policy-00002`** (§7): a 0-satoshi P2PKH output, `dust` (`standard.cpp:482–484`; the threshold 1 satoshi, `primitives/transaction.h:203–213`).

**Finding.** Teranode's default `maxtxsizepolicy` is **10,485,760** (`settings.go:108`) while bitcoin-sv's is **10,000,000** (`policy.h:70`): the same MiB-vs-MB slip as the stack policy. Policy; transaction-level (`IsStandardTx` "tx-size", `script/standard.cpp:445–449`; the consensus size is 1 GB in both, `consensus.h:29`). **Witness `witness-policy-00003`** (§7, regenerated by `make policywitnesses`): 21 inputs each pushing 490,000 bytes that the lock drops, about 10.29 MB.

**Finding (#54, 2026-10-06; policy).** Teranode's default `maxscriptsizepolicy` is **100,000,000** at v0.16.0 (`settings.go:113`; the struct tag's default `settings/policy_settings.go:9`; 500,000 at v0.15.9, `settings.go:102` at v0.15.9) while bitcoin-sv's is **500,000** (`policy.h:93`, `configscriptpolicy.cpp:47`); the consensus limit is UINT32_MAX in both (`consensus.h:60`). A post-Genesis spend whose locking or unlocking script is between 500,001 and 100,000,000 bytes, every other policy met, is refused by a default SV-node's mempool (`SCRIPT_ERR_SCRIPT_SIZE`, `interpreter.cpp:429–430`, a policy rejection when `consensus = false`) and accepted by a default Teranode's; a block carrying it is valid on both nodes' block paths. A policy default, never a consensus rule. The spec's `NodeConfig.teranodeDefault.maxScriptSizePolicy` carries the v0.16.0 value since #54's fix (`lean/BsvScript/Params.lean`, re-cited at `settings/settings.go:113` and `settings/policy_settings.go:9`). **Witness owed:** none is generated yet (`make policywitnesses` carries three); a later change's, with the instance's column (#41).

**Finding (#54, 2026-10-06; consensus by chain, regtest only).** The default regtest activation heights of the two nodes now differ: Teranode v0.16.0 pushes go-chaincfg v1.6.2's regtest Genesis **100** and Chronicle **200** (`params.go:475–476`) into GoBDK at construction (`ScriptVerifierGoBDK.go:158–165`), over the 10,000 / 15,000 of the bitcoin-sv regtest parameters GoBDK compiles in, while a default bitcoin-sv regtest node keeps **10,000** and **15,000** (`chainparams.cpp:21`, `:26`). Until #54 both were 10,000 / 15,000 (go-chaincfg v1.5.8, the same lines). Each is a consensus parameter of the regtest chain, set by `-genesisactivationheight` and `-chronicleactivationheight` on the SV side (`init.cpp:2609–2616`) and by no setting on Teranode's at the tag. Mainnet's heights are unchanged (`params.go:276–277` at both versions), and so are the spec's corpora and words, which are mainnet's. A regtest comparison of the two nodes (the harness's node oracle, #27; the instance, #41) must set the SV node's heights to Teranode's, or its block-path verdicts between heights 100 and 15,000 compare two different chains. A configuration fact, recorded for the runners; no witness, because no single transaction separates two chains' parameters.

**Finding (#21).** Teranode judges standardness at the tip's era, bitcoin-sv at the next block's: `implCheckStandardness` takes the era of `blockHeight` (`bdk/core/txvalidator.cpp:988`, `:993`) and Teranode passes the tip (`blockHeight − 1`) in policy mode (`ScriptVerifierGoBDK.go:261–271`), while the reference calls `IsStandardTx(…, chainActive.Height() + 1, …)` (`validation.cpp:1073`; `time_locked_mempool.cpp:331, 645`). The flag word itself is unaffected (`CalculateFlags` uses `blockHeight + 1`, `core/txvalidator.cpp:672`). The difference is one block wide at each activation height (the `version` rule pre-Chronicle, the 1,650-byte scriptSig and push-only rules pre-Genesis, `GetMaxTxSize(era)`); no activation is pending at the pin, so no mainnet witness exists; recorded for the harness runners' height convention.

**Finding (#21).** In consensus mode Teranode labels a `SCRIPT_ERR_STACK_SIZE` failure a policy error (`ScriptVerifierGoBDK.go:417–418`: `consensus && errCode == SCRIPT_ERR_STACK_SIZE`), although on the block path the limit is the consensus budget (`maxstackmemoryusageconsensus`: Teranode passes 0, INT64_MAX; bitcoin-sv's operator must set it, `bitcoind.cpp:140–157`) or the pre-Genesis 1,000-element limit (`interpreter.cpp:1800–1803`). The verdict stays invalid: the policy error is wrapped in a `TxInvalidError` (`:419–420`). At v0.15.9 `ERR_TX_POLICY` had no consumer outside the error package; at v0.16.0 one reads it: the validator publishes a transaction whose error matches `ErrTxPolicy` to the policy-rejected topic as "consensus-valid but policy-rejected" (`services/validator/Validator.go:765–769`; `errors/Error_types.go:68, 95`). Whether a block-path `SCRIPT_ERR_STACK_SIZE` failure reaches that publish is not read here `[D]`, unverified. A classification, not a verdict difference; recorded so that #30's runner reads the verdict, never the label.

**Finding.** The `verifyscript` RPC's help text says `stopOnFirstInvalid` defaults to **true** (`src/rpc/misc.cpp:565`) while the code makes it **false** when the argument is absent (`misc.cpp:606–612`): the reference disagrees with its own documentation (CLAUDE.md rule 15; the harness passes the argument explicitly, DESIGN §7).

**Finding.** At the ordinal of bitcoin-sv v1.2.2's `SCRIPT_ERR_ILLEGAL_CHRONICLE` (`src/script/script_error.h:80`, string at `script_error.cpp:100`), GoBDK's Go binding names the code `SCRIPT_ERR_ILLEGAL_RELAX` (`bdk/module/gobdk/script/scripterror.go:86` at `4eab3acd`, the same line at `cdfa7814`): the same enum, two names. BDK compiles against an external bitcoin-sv tree (`core/setting-bitcoin.cmake:9–11`), so a Teranode-vs-SV-node reason difference can be a naming or a version difference; the harness compares reasons by the `SCRIPT_ERR_*` name at the pin and records the tree GoBDK was built from (`879fc8b42` per `docs/PROVENANCE.md` §1).

**The bsv-rs candidates of the census, decided (#15, then the bump to 0.3.27 on 2026-09-23, to 0.3.28 on 2026-09-24 and to 0.3.29 on 2026-09-27, which fixed the four `impl-wrong` classes of the spec's `corpus/gen`, bsv-rs#20 to #23).** bsv-rs still has no op-count or script-size limit (since 0.3.28 it has the reference's number-length limit under a word: the coin's era's consensus width on the block path, the policy default of 10,000 on the mempool path, `flags.rs:52–58`, `371–382`, `spend.rs:438–450` at 0.3.32; bsv-rs#17, the spec's #20 Finding, eras-00041), a 1 GiB element limit and a 32,000,000-byte budget per stack without the 32-byte overhead (an `undecided`, never a verdict), `i32::MAX` multisig keys, no P2SH evaluation and no CLTV/CSV check (all faithful for the post-Genesis UTXOs it models, or a local budget). The rest became #15's witnesses at 0.3.24 (push-only and NULLDUMMY regardless of version, no NULLFAIL, `find_and_delete` regardless of FORKID, the disabled Chronicle opcodes, the lenient truncated push, the NOP undefined opcodes, the second `OP_ELSE`, `OP_RETURN` in a conditional) and every one is fixed in 0.3.26/0.3.27 (bsv-rs#10, #12), the witnesses being the crate's tests; `corpus/INDEX.md` §4 carries the state.

**Finding (#20).** The reference's block word tests P2SH against the chain tip's height: `GetBlockScriptFlags(config, tip)` (`validation.cpp:2973–2982`) is called with the block's parent (`validation.cpp:3472`) and `verify_script_flags.cpp:39` tests `height >= p2shHeight`, so P2SH enters the block word of block **173,806** on mainnet, while the comment above the test says "P2SH became active on Apr 1 2012, block height 173,805" (`:38`; `chainparams.cpp:28`). DERSIG, CLTV and CSV test `height + 1` and enter at their chain heights; the UAHF and DAA heights are the parents' by design (the fork blocks are 478,559 and 504,032). The reference against its own comment (CLAUDE.md rule 15): the spec transcribes the code (`flagWord_block_p2sh`, `lean/BsvScript/Properties/Eras.lean`; the rows `eras.height.p2sh` of `corpus/eras`); the only chain fact the two readings could disagree on is a P2SH-shaped spend in block 173,805 whose redeem script fails, a historical-replay question for the harness's public replay family (#26), never a transaction today. Recorded on #20 for the maintainers' ruling.

**Finding (the recon, #39, 2026-09-29).** At the pin, bitcoin-sv's STN parameters leave `BIP65Height`, `BIP66Height` and `CSVHeight` unset: `CStnParams` (`chainparams.cpp:1195–1304`) assigns `BIP34Height` (`:1212`), `uahfHeight` (`:1225`), `daaHeight` (`:1228`), `genesisHeight` (`:1231`), `chronicleHeight` (`:1234`) and `p2shHeight` (`:1236`) and none of the three; `Consensus::Params` gives its fields no initializer (`consensus/params.h:15–28`); and `CreateChainParams` allocates the object with `new CStnParams()` (`chainparams.cpp:1603`), whose user-provided constructor leaves them uninitialized. So on STN the DERSIG, CLTV and CSV bits of `GetBlockScriptFlags` (`verify_script_flags.cpp:43–52`), the block-version rule (`validation.cpp:5965–5967`), the sequence locks (`validation.cpp:3465`) and the median-time-past lock time (`validation.cpp:6048`) read indeterminate values. Main, testnet and regtest assign all three (`chainparams.cpp:1042–1046`, `:1338–1342`, `:1466–1470`). GoBDK at bdk `4eab3ac`, the pin Teranode's v0.16.0-beta-13 and -14 and v0.16.0 (the pin since #54) require, builds its own STN table with the three at 0 (its constructor's comment names the reference's gap), while Teranode's own STN copy reads 1,351, 1,251 and 0 (go-chaincfg v1.6.2 `params.go:384–386`, the same lines at v1.5.8). STN only: the mainnet and regtest words the spec derives are unaffected. A configuration fact, with no witness: a verdict that depends on uninitialized memory is not a reproducible verdict.

## 6. The flags model: how the word and the limits are derived (#13, 2026-09-22; `lean/BsvScript/Flags.lean`)

`Params.derive (cfg : NodeConfig) (spendHeight utxoHeight : ℕ) (consensus : Bool) : EvalParams`
(`docs/DESIGN.md` §5.4) is the reference's own derivation, transcribed and cited
line by line, and every value of §1–§3 enters the semantics only through it:

| step | the reference `[SRC]` | the Lean |
|---|---|---|
| the era of a height: below the Genesis height pre-Genesis, below the Chronicle height post-Genesis, else post-Chronicle; `IsProtocolActive` on the ordered enum | `protocol_era.cpp:21–39`, `42–47`, `89–103`; the configured heights `configscriptpolicy.cpp:156–162`, defaulting to the chain's `init.cpp:2609–2616` | `protocolEraOf`, `NodeConfig.protocolEra`, `Era.genesisActive`, `Era.chronicleActive` |
| **the block word** at the tip's height with the era of the block being connected: P2SH from `p2shHeight`; DERSIG, CLTV, CSV from `height + 1`; STRICTENC and FORKID from `uahfHeight`; LOW_S and NULLFAIL from `daaHeight`; GENESIS and SIGPUSHONLY when Genesis is active; CHRONICLE when Chronicle is | `verify_script_flags.cpp:32–81`; the call `validation.cpp:3472` → `2973–2982` (height = the previous block's, era = that of `tip + 1`); the mainnet heights `chainparams.cpp:1034–1076`, `consensus/params.h:20–39` | `blockScriptFlags`, `ChainParams` (`Params.lean`), `ChainParams.mainnet` |
| **the mempool word**: the era's standard set (the mandatory set with the standard set, plus GENESIS when active); without `requireStandard`, `-promiscuousmempoolflags` replaces the word when set, and FORKID is added | `verify_script_flags.cpp:11–30`; `policy.h:176–223`; `standard.h:55–68`, `standard.cpp:330–337`; the call `validation.cpp:1031`, `1329`, `796–802` (the era of `tip + 1`) | `mempoolScriptFlags`, `standardScriptVerifyFlags`, `mandatoryFlags`, `standardOnly`, `mandatoryPreChronicle`, `mandatoryPostChronicle` |
| **the per-input word**: SIGPUSHONLY when Genesis is active in the spend era; the two UTXO markers from the UTXO's era, OR-ed onto the caller's word | `policy.h:226–245`; `validation.cpp:2694–2702` (`CheckInputScripts`: the era of `spendHeight`, the UTXO's era of the coin's height, `flags \| perInputScriptFlags`) | `inputScriptVerifyFlags`, `Flags.union`, `NodeConfig.flagWord` |
| **the limits** from the word's UTXO era and the switch; a configured zero as the setters leave it | `interpreter.cpp:2282–2302`; `configscriptpolicy.cpp:65–154` (the getters), `164–308` (the setters' zero rules); the call `validation.cpp:2701`, BDK `core/txvalidator.cpp:911` | `NodeConfig.limitsFor`, `NodeConfig.normalize`, `consensusMaxScriptNumLength` |
| Teranode's engine computes the same word under its height convention | BDK `core/txvalidator.cpp:659–681` (`CalculateFlags`) | the corpus convention of `docs/DESIGN.md` §6 (`spend_height` = the block's height; BDK consensus mode takes it as is, policy mode `spend_height − 1` as the tip) |
| the 32-bit word both ways (the `uint32_t` of `VerifyScript`, the `verifyscript` RPC and the corpus's explicit `flags`) | `script_flags.h:13–115`; the names `rpc/misc.cpp:1281–1302` = `test/scriptflags.cpp:17–38` | `Flags.toWord`, `Flags.ofWord`, `FlagBit` (bit, kind, gate sites, both names) |

**What is proven** (`lean/AxiomCheck.lean`, all axiom-clean):

| theorem | what it says |
|---|---|
| `blockScriptFlags_policy_off` | the block word never carries a policy flag (NULLDUMMY, MINIMALDATA, DISCOURAGE_UPGRADABLE_NOPS, CLEANSTACK), for every chain, height and era: constitution 01 at the flag level |
| `derive_consensus_separation`, `verifyScript_consensus_separation` (**P5**) | on the block path `derive` reads only the consensus fields of a node's configuration (the chain, the two activation heights, `maxstackmemoryusageconsensus`); two nodes agreeing on those verify every input under the same `EvalParams` and reach the same verdict, whatever their policy settings; SV-node's and Teranode's defaults derive the same block parameters and differ on the mempool path in exactly the two limits of §5 (decided) |
| `flagWord_valid`, `flagWord_block_valid`, `flagWord_utxoEra` | the derived word is always `valid_flags` and carries the UTXO's era (the block path unconditionally; the mempool path without promiscuous flags, see the finding below) |
| `flagWord_neverSet_off` | MINIMALIF and COMPRESSED_PUBKEYTYPE are set by neither path |
| `flagWord_mempool_eq_block_mainnet` | on mainnet with every activation passed, the relay word = the block word + NULLDUMMY + DISCOURAGE_UPGRADABLE_NOPS + CLEANSTACK + MINIMALDATA |
| `verifyScript_relay_block_version2` | a version-2 spend post-Chronicle is judged under the relay word exactly as under the block word with DISCOURAGE_UPGRADABLE_NOPS added, whatever the limits: the version gate clears the other three; a relaying node and a mining node differ on such a spend only on executed upgradable NOPs and on the resource limits |
| `Flags.ofWord_toWord`, `Flags.toWord_ofWord` | the `uint32_t` round-trips (bits 11, 12, 17 and everything from `SCRIPT_FLAG_LAST` up are the only information it can lose) |
| `Flags.gate_off_of_chronicle` | with CHRONICLE set and a version above 1 the gate clears the seven restrictions |

Decided at the spec's default height (`defaultSpendHeight` 967,896, a
post-Chronicle output): the block word is `0x3D462F` (P2SH · STRICTENC · DERSIG ·
LOW_S · SIGPUSHONLY · CLTV · CSV · NULLFAIL · FORKID · GENESIS ·
UTXO_AFTER_GENESIS · CHRONICLE · UTXO_AFTER_CHRONICLE) with the consensus limits
of §1; the mempool word is `0x3D47FF`; a pre-Genesis output spent today gets no
UTXO marker and the pre-Genesis limits (500 ops, 4-byte numbers, 10,000-byte
scripts, 20 keys); the `+ 1` sites put DERSIG in the block word of block 363,725
and P2SH in that of 173,806.

**The leg** (`make flagscheck`, `lean/Test/FlagsCheck.lean`) runs `corpus/flow`
and `corpus/seed` under both derived words and decides that the hand-written
relay word of the earlier legs is the derivation's. 2026-09-22 `[X]`: version-2
(the gate OFF) 529 + 8,500 entries and version-1 (the gate ON) 529 + 1,500 agree
with bsv-rs under the mempool word with 0 mismatches (102 seed mutations explained
by bsv-rs's then three known divergences, 64 recorded flow families, 6 seed entries on
the expansion opcodes; since #18 the same night: 103 explained by four classes, 0 waiting); block versus mempool differ on 3 + 2 version-2
entries, all `DISCOURAGE_UPGRADABLE_NOPS`, and on version-1 entries by
`MINIMALDATA` 268 + 10, `SCRIPTNUM_MINENCODE` 85, `CLEANSTACK` 21 + 65,
`DISCOURAGE_UPGRADABLE_NOPS` 3, nothing else; clearing the seven gated bits changes
0 version-2 verdicts and 299 + 160 version-1 verdicts. **At bsv-rs 0.3.28 (2026-09-24): the same counts, entry for entry** (the seven regenerated corpora carry 0 verdict changes against 0.3.27 on seed, flow, arith, stack, crypto and bytes and one on eras, eras-00041, now `Script number overflow` as the reference; `make diff` at `spec@e78a043`: seed 10,000 / flow 1,094 / arith 692 / stack 260 + 2 undecided / crypto 84 / eras 32 + 42 not applicable agree in both columns, zero witnesses; the record `docs/records/20260924-030828-svnode-record-s3.md` for the reference's own run). **At bsv-rs 0.3.27 under the node's standard word (2026-09-23, the bump):** flow 547 + 547 and seed 8,500 + 1,500 entries agree with 0 mismatches and **0 explained** (the former divergence classes are fixed upstream and every former candidate family is comparable), block versus mempool differ on version 2 only by `DISCOURAGE_UPGRADABLE_NOPS` (3 + 2) and on version 1 by `MINIMALDATA` 274 + 10, `SCRIPTNUM_MINENCODE` 85, `CLEANSTACK` 23 + 65, `DISCOURAGE_UPGRADABLE_NOPS` 3; clearing the gated bits changes 0 version-2 and 309 + 160 version-1 verdicts `[X]`; the differential's witnesses under every rule of #15 are GONE (`corpus/INDEX.md` §4).

**Finding.** A `-promiscuousmempoolflags` word replaces the standard word
(`verify_script_flags.cpp:21–23`), gains `SCRIPT_ENABLE_SIGHASH_FORKID` (`:25`) and is OR-ed with the per-input word
(`validation.cpp:2701`), so a word carrying `SCRIPT_UTXO_AFTER_CHRONICLE` without
`SCRIPT_UTXO_AFTER_GENESIS` makes every pre-Genesis input of that node fail with
`SCRIPT_ERR_INVALID_FLAGS` (`interpreter.cpp:2312–2313`): one of the two ways a node's own
derivation reaches that error, the other a word carrying CLEANSTACK without P2SH (`interpreter.cpp:2435–2436`), which such a word can also carry. A policy setting and a misconfiguration; the block
path never reads it (`flagWord_block_valid`). Recorded so that #27's runner never
sets the bit by hand.

## 7. The witnesses (#21, 2026-09-22)

`corpus/witnesses/policy-defaults.jsonl` (`harness/src/bin/policy_witnesses.rs`,
`make policywitnesses`; `corpus/INDEX.md` §4): the policy-default differences of
§5 that a transaction exhibits, one transaction each, with both nodes' mempool
verdicts read from source in the entry's `divergence` record (`[D]`, the
citations in `decided_by`, `ruling: open` because no one is wrong: a block
carrying any of them is valid for both, though a default SV-node's mempool refuses them). `lean/Test/WitnessCheck.lean` (`make witnesscheck`) decides
the spec's own verdict for every input under the four parameter sets
`Params.derive` builds from `NodeConfig.svMainnetDefault` and
`NodeConfig.teranodeDefault` (block and mempool). No node runner has measured
the node verdicts (#27 and #30 closed without a run of these witnesses); the two nodes' columns are `[D]` from source.

| witness | exhibits | bitcoin-sv v1.2.2 mempool `[D]` | Teranode v0.15.9 mempool `[D]` (the defaults these rows read are the same at v0.16.0: `settings.go:118`, `:123`, `:108`) | both block paths | the spec (`make witnesscheck`) | bsv-rs (script only; the verdicts recorded at 0.3.30 in `corpus/witnesses/policy-defaults.jsonl` by `make policywitnesses`; not re-run at 0.3.32) |
|---|---|---|---|---|---|---|
| `witness-policy-00001` (`witness-policy/stack-memory`) | `maxstackmemoryusagepolicy` 100,000,000 vs 104,857,600: a 3-byte element doubled 25 times by `OP_DUP OP_CAT`; the peak 100,663,360 bytes at the last `OP_DUP` (two elements of 50,331,648 + 32 each) | invalid, `SCRIPT_ERR_STACK_SIZE` (policy) | valid | valid (INT64_MAX) | invalid `SCRIPT_ERR_STACK_SIZE` under bitcoin-sv's mempool limits, valid under Teranode's, valid on both block paths `[X]` (23 s, 4.5 GB peak: the 100 MB element as a Lean list) | invalid under every recorded key (its default, `memory_limit` 100,000,000 and 104,857,600): the crate's mempool-path policy of 100,000,000 bytes over both stacks refuses the 100,663,360-byte peak under each, so no key ran under 104,857,600 alone |
| `witness-policy-00002` (`witness-policy/dust`) | `requirestandard` true vs false: a standard P2PKH output of 0 satoshis (`dust`) | invalid, `REJECT_NONSTANDARD dust` | valid | valid (a 0-value output is consensus-valid) | valid under all four (transaction-level, outside the script semantics) | valid |
| `witness-policy-00003` (`witness-policy/tx-size`; `policy-defaults-large.jsonl`, regenerated, not committed) | `maxtxsizepolicy` 10,000,000 vs 10,485,760 (with `requirestandard`): 21 inputs each pushing 490,000 bytes dropped by the lock, 10,291,094 bytes | invalid, `REJECT_NONSTANDARD tx-size` | valid | valid (1 GB) | valid under all four (transaction-level) | valid |

Not exhibitable at defaults: `maxopsperscriptpolicy` (bitcoin-sv's script-size policy binds
first, §5). Files: `policy-defaults.jsonl` sha256 `6fef159fc1b94e74f864ab6feb83a857bddcfe19db6d1cdfafa04cd2fefa8153` (regenerated 2026-09-23 with bsv-rs 0.3.27's verdicts under the standard word; `17ec9c48…` at #21);
`policy-defaults-large.jsonl` sha256 `544f64a0117d78b00f70f0aea7b58dfef6881b420dc48164f2da665f46421077` (20,586,686 bytes), regenerated
byte-for-byte by the generator; the manifest `policy-defaults-manifest.json`.

**Reference reader (#57).** The reading of record at v1.2.3 is a defined refusal ([SRC] `int_serialization.h:61–118`, `script_num.cpp:80–91` at `6504a3af`); the previous pin's reading and its measurements are recorded in material withheld from the public edition at the maintainers' request (group `d8-node-team-discretion`). `OP_SPLIT` refuses positions over `INT32_MAX` with `SCRIPT_ERR_INVALID_SPLIT_RANGE` ([SRC] `interpreter.cpp:1708–1721` at `6504a3af`). These are interpreter bounds; policy settings are separate.

## 8. Chain-layer configuration (#59, 2026-10-12)

`BsvChain.NodeConfig` in `lean/BsvChain/Params.lean` extends the interpreter's
`BsvScript.Params.NodeConfig`. The tables use §3's five-cell row shape: value,
kind, reference, second oracle, and the reading transition in place of the
script-engine comparison. Each table follows its record's declaration order.
The script projection has **17 fields (4 consensus / 13 policy)**; the extension
has **81 fields (9 consensus / 72 policy, including 23 node settings)**: **98
fields (13 consensus / 85 policy)** in the flattened configuration [M].

All SV citations in this section are [SRC] **v1.2.3 at
`6504a3aff65ba97c0f6c80962b033e35ecbfed4b`**. The second oracle's cells are
[SRC] **Teranode v0.16.0 at `4edb60a40c6628ff0ef60231c2628efd7103fde5`**,
read through the GitHub contents API. They record settings, not verdicts or a
second rule. `-` means no matching setting in the cited initializer; it is not
zero, unlimited, or an assertion that the service lacks the underlying check.
#74 owns that service-to-transition mapping. The legacy bridge's count cap,
expiry and reject map are explicitly different representations.

**Kinds and presence.** `policy (node setting)` preserves DESIGN-S6's narrower
setting/client-setting/operator-list-companion classifications inside the
non-consensus side of this census. Such a switch can change a local validation
or selection path; its value is not a shared consensus rule. The actual frozen,
confiscation and whitelist contents remain the separate **operator-list
mechanism**, supplied as the explicit `OperatorLists` input (#70, §8.2's
operator-list table), never policy limits or consensus constants. `mandatory` means the daemon requires an explicit launch input;
`optional` includes documented model parameters for constants with no CLI.
Units and resolved-zero meanings accompany every field. The `default` instance
is a **library template**, never a daemon launch default: the operator must
supply excessive block size, consensus stack memory and mining fee even when
choosing their template values. A scenario must resolve these inputs before
calling a transition. #59 supplies the pinned network data in §8.3 and its partial script projection;
#69 integrates the selected network, checkpoints and permitted switches with
the transitions and proves their activation properties (§8.3, 2026-10-13).

The census/record rule of #6 applies here: change both together.
`tools/check.sh parameters` compares names, order, kinds, literal defaults and
presence; it also compares both interpreter default records with §8.1 and
rejects a `BsvScript` import of `BsvChain`, including escaped module names.
It also compares every §8.3 network cell with its Lean assignment and requires
a unique presence word on inherited, added and network metadata rows. The existing `pins` leg runs this
subcheck and requires its own GREEN line. The new library is a second
`lean_lib` in the same package, rooted at `BsvChain`, with the dependency
expressed by `import BsvScript.Params`; the library default build includes it.

### 8.1 The inherited script projection

These are the existing fields, with their detailed semantics and units in
§§1–4. Values are the resolved mainnet library defaults, including the two
activation heights. The separate `chainRequireStandard` field in §8.2 lets
#76 preserve the source's chain flag-word switch independently of the node's
`requireStandard` refusal switch (the modelling qualification of §3).

<!-- script-node-config:start -->
| value | kind | bitcoin-sv default and presence `[SRC]` | Teranode v0.16.0 default (second oracle) `[SRC]` | read at and transition `[SRC]` |
|---|---|---|---|---|
| `chain` | consensus | `ChainParams.mainnet` · **optional**. [SRC] `src/chainparams.cpp:1038–1076`. | `ChainParams.mainnet` · [SRC] `§3; go-chaincfg v1.6.2 params.go:265–277`. | receiveTx, applyTx and connectBlock derive the per-input script parameters (`src/validation.cpp:2693–2707`; §§1–3). |
| `maxOpsPerScriptPolicy` | policy | `4294967295` · **optional**. [SRC] `src/policy/policy.h:147; src/configscriptpolicy.cpp:45`. | `1000000` · [SRC] `settings/settings.go:114`. | receiveTx derives the relay script parameters (`src/validation.cpp:1328–1348`; §§1–3). |
| `maxScriptNumLengthPolicy` | policy | `10000` · **optional**. [SRC] `src/policy/policy.h:156; src/configscriptpolicy.cpp:46`. | `10000` · [SRC] `settings/settings.go:115`. | receiveTx derives the relay script parameters (`src/validation.cpp:1328–1348`; §§1–3). |
| `maxScriptSizePolicy` | policy | `500000` · **optional**. [SRC] `src/policy/policy.h:93; src/configscriptpolicy.cpp:47`. | `100000000` · [SRC] `settings/settings.go:113`. | receiveTx derives the relay script parameters (`src/validation.cpp:1328–1348`; §§1–3). |
| `maxPubKeysPerMultiSigPolicy` | policy | `4294967295` · **optional**. [SRC] `src/policy/policy.h:150; src/configscriptpolicy.cpp:48`. | `4294967295` · [SRC] `settings/settings.go:116; resolved zero, §1`. | receiveTx derives the relay script parameters (`src/validation.cpp:1328–1348`; §§1–3). |
| `maxStackMemoryUsagePolicy` | policy | `100000000` · **optional**. [SRC] `src/policy/policy.h:153; src/configscriptpolicy.cpp:49`. | `104857600` · [SRC] `settings/settings.go:118`. | receiveTx derives the relay script parameters (`src/validation.cpp:1328–1348`; §§1–3). |
| `maxStackMemoryUsageConsensus` | consensus, node-configurable | `9223372036854775807` · **mandatory**. [SRC] `src/consensus/consensus.h:82; src/configscriptpolicy.cpp:50; src/bitcoind.cpp:140–157`. | `9223372036854775807` · [SRC] `settings/settings.go:119; resolved zero, §1`. | receiveTx, applyTx and connectBlock derive the per-input script parameters (`src/validation.cpp:2693–2707`; §§1–3). |
| `maxTxSigOpsCountPolicy` | policy | `4294967295` · **optional**. [SRC] `src/policy/policy.h:85; src/config.cpp:61`. | `4294967295` · [SRC] `settings/settings.go:117; resolved zero, §4`. | receiveTx caps transaction sigops (`src/validation.cpp:1241–1252`). |
| `maxTxSizePolicy` | policy | `10000000` · **optional**. [SRC] `src/policy/policy.h:70; src/configscriptpolicy.cpp:57`. | `10485760` · [SRC] `settings/settings.go:108`. | receiveTx applies transaction standardness (`src/validation.cpp:1070–1088`; §4). |
| `genesisActivationHeight` | consensus, node-configurable | `620538` · **optional**. [SRC] `src/chainparams.cpp:18,1071; src/init.cpp:2609–2612`. | `620538` · [SRC] `go-chaincfg v1.6.2 params.go:276; §3`. | receiveTx, applyTx and connectBlock derive the per-input script parameters (`src/validation.cpp:2693–2707`; §§1–3). |
| `chronicleActivationHeight` | consensus, node-configurable | `943816` · **optional**. [SRC] `src/chainparams.cpp:23,1074; src/init.cpp:2613–2616`. | `943816` · [SRC] `go-chaincfg v1.6.2 params.go:277; §3`. | receiveTx, applyTx and connectBlock derive the per-input script parameters (`src/validation.cpp:2693–2707`; §§1–3). |
| `requireStandard` | policy | `true` · **optional**. [SRC] `src/chainparams.cpp:1121; src/init.cpp:3158–3160`. | `false` · [SRC] `settings/settings.go:123`. | receiveTx applies transaction standardness (`src/validation.cpp:1070–1088`; §4). |
| `promiscuousMempoolFlags` | policy | `none` · **optional**. [SRC] `src/config.cpp:92–93; src/init.cpp:2463–2466`. | `none` · [SRC] `no option, §3; settings/settings.go:103–136`. | receiveTx derives the relay script parameters (`src/validation.cpp:1328–1348`; §§1–3). |
| `acceptNonStandardOutput` | policy | `true` · **optional**. [SRC] `src/configscriptpolicy.cpp:60; src/init.cpp:3162–3163`. | `true` · [SRC] `settings/settings.go:122`. | receiveTx applies transaction standardness (`src/validation.cpp:1070–1088`; §4). |
| `dataCarrier` | policy | `true` · **optional**. [SRC] `src/script/standard.h:20; src/configscriptpolicy.cpp:59`. | `false` · [SRC] `settings/settings.go:124`. | receiveTx applies transaction standardness (`src/validation.cpp:1070–1088`; §4). |
| `dataCarrierSize` | policy | `4294967295` · **optional**. [SRC] `src/script/standard.h:46; src/configscriptpolicy.cpp:58`. | `1000000` · [SRC] `settings/settings.go:112`. | receiveTx applies transaction standardness (`src/validation.cpp:1070–1088`; §4). |
| `permitBareMultisig` | policy | `true` · **optional**. [SRC] `src/script/standard.h:23; src/configscriptpolicy.cpp:62`. | `true` · [SRC] `settings/settings.go:125`. | receiveTx applies transaction standardness (`src/validation.cpp:1070–1088`; §4). |
<!-- script-node-config:end -->

### 8.2 The added chain fields

Each row gives the definition and initialization, then the transition that
reads it in DESIGN-S6 §2. A method's existence is not used as evidence for a
default. Per-call overrides (including the RPC high-fee override), validation
completion, pointer tie rank and time remain explicit request/event inputs.

<!-- chain-node-config:start -->
| value | kind | bitcoin-sv default and presence `[SRC]` | Teranode v0.16.0 default (second oracle) `[SRC]` | read at and transition `[SRC]` |
|---|---|---|---|---|
| `limitAncestorCount` | policy | `10000` · **optional** · transactions. [SRC] Definition `src/validation.h:86`; initialization `src/config.cpp:49`. | [SRC] No admission counterpart in the policy initializer; the assignment is commented out at `settings/settings.go:120`. | receiveTx checks the accepted ancestor count. [SRC] `src/validation.cpp:783–792,1313–1318`. |
| `maxMempool` | policy | `1000000000` · **optional** · bytes. [SRC] Definition `src/policy/policy.h:87`; initialization `src/config.cpp:83`. 1,000 decimal MB, resolved to bytes. | [SRC] - No matching setting in `settings/settings.go:103–136,715–742`; no reference default is assigned to this oracle. | receiveTx trims the pool; disconnectBlock caps its temporary disconnect pool. [SRC] `src/validation.cpp:938–945,4111`. |
| `maxMempoolNonFinal` | policy | `52428800` · **optional** · bytes. [SRC] Definition `src/policy/policy.h:89`; initialization `src/time_locked_mempool.cpp:400`. 50 MiB, resolved to bytes; the option is -maxmempoolnonfinal. | [SRC] - No matching setting in `settings/settings.go:103–136,715–742`; no reference default is assigned to this oracle. | receiveTx refuses holding when the non-final pool has no capacity. [SRC] `src/validation.cpp:1119–1123`. |
| `mempoolExpiry` | policy | `1209600` · **optional** · seconds. [SRC] Definition `src/validation.h:91`; initialization `src/config.cpp:87`. 336 hours, resolved to seconds. | [SRC] - No matching setting in `settings/settings.go:103–136,715–742`; no reference default is assigned to this oracle. | advanceTime expires accepted entries and their descendants. [SRC] `src/txmempool.cpp:2201–2221`. |
| `mempoolNonFinalExpiry` | policy | `2419200` · **optional** · seconds. [SRC] Definition `src/validation.h:93`; initialization `src/time_locked_mempool.cpp:404`. 672 hours, resolved to seconds; the option is -mempoolexpirynonfinal. | [SRC] - No matching setting in `settings/settings.go:103–136,715–742`; no reference default is assigned to this oracle. | advanceTime purges expired non-final entries. [SRC] `src/time_locked_mempool.cpp:627–628,655–660`. |
| `maxOrphanTxSize` | policy | `1000000000` · **optional** · bytes. [SRC] Definition `src/orphan_txns.h:49`; initialization `src/config.cpp:88`. One decimal GB of aggregate transactions, distinct from the inherited per-transaction maxTxSizePolicy. | [SRC] No equivalent byte cap: `settings/settings.go:111` is commented out; the legacy bridge caps count at 100 (`:720`), used at `services/legacy/netsync/manager.go:3615`. | receiveTx caps the total orphan pool. [SRC] `src/validation.cpp:1911–1915`. |
| `orphanTrimHysteresisDivisor` | policy | `10` · **optional** · divisor. [SRC] Definition `src/validation.cpp:1914`; initialization `src/validation.cpp:1914`. Model parameter for a local constant, no CLI; must be positive. | [SRC] - No matching setting in `settings/settings.go:103–136,715–742`; no reference default is assigned to this oracle. | receiveTx trims with hysteresis equal to maxOrphanTxSize divided by this value. [SRC] `src/orphan_txns.cpp:175–192`. |
| `blockMinTxFee` | policy | `500` · **mandatory** · satoshis per 1000 bytes. [SRC] Definition `src/policy/policy.h:64–66`; initialization `src/txmempool.h:437–438`. Constructor template only; no implicit daemon default. Launch requires -minminingtxfee (src/bitcoind.cpp:158–164; src/init.cpp:3115–3121). | [SRC] 500 sat/kB: 0.00000500 BSV/kB (`settings/settings.go:109`). | receiveTx credits consolidation fees and classifies primary-pool entries. [SRC] `src/validation.cpp:1267–1273`. |
| `minRelayTxFee` | policy | `0` · **optional** · satoshis per 1000 bytes. [SRC] Definition `src/config.cpp:2350–2351`; initialization `src/config.cpp:32; src/init.cpp:3093–3099`. The launch value is zero; -minrelaytxfee is removed. DEFAULT_MIN_RELAY_TX_FEE = 250 (src/validation.h:77) is not this initialized value. | [SRC] - No matching setting in `settings/settings.go:103–136,715–742`; no reference default is assigned to this oracle. | No admission transition reads this static value; the fee-estimate observation takes its maximum with the rolling floor. [SRC] `src/txmempool.cpp:1883–1888`. |
| `minDebugRejectionFee` | policy | `0` · **optional** · satoshis per 1000 bytes. [SRC] Definition `src/txmempool.h:439`; initialization `src/txmempool.h:439; src/init.cpp:3135–3146`. A nonzero override is permitted only off mainnet. | [SRC] - No matching setting in `settings/settings.go:103–136,715–742`; no reference default is assigned to this oracle. | receiveTx takes the maximum of this value and the truncated rolling fee. [SRC] `src/txmempool.cpp:2644–2647`. |
| `maxTxFee` | policy | `10000000` · **optional** · satoshis. [SRC] Definition `src/validation.h:79`; initialization `src/validation.cpp:108; src/rpc/rawtransaction.cpp:1571–1573`. RPC request default; allowhighfees replaces that request ceiling with zero, never a consensus cap. | [SRC] 10000000 (`settings/settings.go:110`, MaxRawTxFee). | receiveTx applies the request fee ceiling. [SRC] `src/validation.cpp:1249–1254`. |
| `maxStdTxnValidationDuration` | policy | `3` · **optional** · milliseconds. [SRC] Definition `src/txn_validation_config.h:39–40`; initialization `src/config.cpp:64`. Budget observations whose outcome depends on the node's validation clock are non-judging, on an available budget as on an expired one (`ClockDependence`, `budgetJudgment`; fix-71, [M] 2026-10-14); the elapsed time on that clock is an explicit input of the machine (`BsvChain.ElapsedObservation`, `budgetObservation`; #71, [M] 2026-10-14). | [SRC] No active assignment: `settings/settings.go:126` is commented out; no reference CPU-budget equivalence is claimed. | receiveTx supplies the standard validation budget; expiration is an explicit observation. A high-priority request is validated under it (`validationDuration`); when it fires the request is queued again at low priority with no answer. [SRC] `src/validation.cpp:999–1005,1077`; `src/txn_validator.cpp:633–641`. |
| `maxNonStdTxnValidationDuration` | policy | `1000` · **optional** · milliseconds. [SRC] Definition `src/txn_validation_config.h:42–43`; initialization `src/config.cpp:65`. One second, resolved to milliseconds. | [SRC] No active assignment (`settings/settings.go:127`, commented out). | receiveTx supplies the non-standard validation budget. A low-priority request is validated under it; when it fires the request is refused with `too-long-validation-time` (#71). [SRC] `src/validation.cpp:999–1005,1210–1240`; `src/txn_validator.cpp:633–641`. |
| `excessiveBlockSize` | consensus, node-configurable | `9223372036854775807` · **mandatory** · bytes. [SRC] Definition `src/config.cpp:232–251`; initialization `src/policy/policy.h:39; src/chainparams.cpp:1178; src/config.cpp:211–218`. Library template and zero-resolution value only; launch requires -excessiveblocksize (src/bitcoind.cpp:140–157), with zero resolved by src/config.cpp:243. | [SRC] 4294967296 bytes (`settings/settings.go:104`). | acceptBlock and connectBlock check serialized block size. [SRC] `src/validation.cpp:5795–5814,6058–6064`. |
| `disableBip30Checks` | policy (node setting) | `false` · **optional** · switch. [SRC] Definition `src/config.cpp:2051–2067`; initialization `src/chainparams.cpp:1186–1187`. Resolved default: false on all four networks [SRC] src/chainparams.cpp:1186,1300,1447,1555. Declared permission: false on mainnet, true on STN, testnet and regtest [SRC] src/chainparams.cpp:1187,1301,1448,1556 at `6504a3af`. The getter resolves an unset value to the network default [SRC] src/config.cpp:2065–2067. #69 records each network's permission (`NetworkData.canDisableBip30Checks`) and reads the resolved value in `bip30Enforced`; the setting does not replace the historical exceptions. | [SRC] - No matching setting in `settings/settings.go:103–136,715–742`; no reference default is assigned to this oracle. | connectBlock resolves the BIP30 switch. [SRC] `src/validation.cpp:3097–3100`. |
| `softConsensusFreezeDuration` | policy (node setting) | `3` · **optional** · blocks. [SRC] Definition `src/validation.h:219`; initialization `src/config.cpp:180`. Resolved value; option zero maps to 2147483647 at src/config.cpp:2602–2610. The lists themselves remain State inputs (#70). | [SRC] - No matching setting in `settings/settings.go:103–136,715–742`; no reference default is assigned to this oracle. | connectBlock sets the operator-list companion freeze; activateBestChain observes it. [SRC] `src/validation.cpp:3402–3407,3720–3741`. |
| `minimumChainWork` | policy (node setting) | `0x000000000000000000000000000000000000000000a0f3064330647e2f6c4828` · **optional** · accumulated work. [SRC] Definition `src/consensus/params.h:50`; initialization `src/chainparams.cpp:1056–1057; src/init.cpp:2364–2375`. Mainnet template; `NodeConfig.withNetwork` (#69) supplies the network defaults (regtest zero). Mainnet template; #69 supplies network defaults (regtest zero). | [SRC] - No matching setting in `settings/settings.go:103–136,715–742`; no reference default is assigned to this oracle. | acceptBlock gates unrequested bodies and connectBlock gates assumevalid. [SRC] `src/validation.cpp:3496,6329`. [SRC] `src/validation.cpp:2291,3496,6329`. |
| `assumeValid` | policy (node setting) | `0x000000000000000000e45ad2fbcc5ff3e85f0868dd8f00ad4e92dffabe28f8d2` · **optional** · block hash, displayed integer order. [SRC] Definition `src/consensus/params.h:51`; initialization `src/chainparams.cpp:1061–1062; src/init.cpp:2355–2357`. Zero disables the shortcut; `NodeConfig.withNetwork` (#69) replaces this mainnet template with the selected network's default. Mainnet template; selected network defaults are in §8.3. | [SRC] - No matching setting in `settings/settings.go:103–136,715–742`; no reference default is assigned to this oracle. | connectBlock may omit ordinary script checks only under the ancestry, work and depth predicates. [SRC] `src/validation.cpp:3482–3518`. |
| `checkpointsEnabled` | policy (node setting) | `true` · **optional** · switch. [SRC] Definition `src/validation.h:189`; initialization `src/init.cpp:2352–2353`. The per-network tables are `NetworkData.checkpoints` (#69). The per-network table belongs to ChainParams (#69). | [SRC] - No matching setting in `settings/settings.go:103–136,715–742`; no reference default is assigned to this oracle. | receiveHeader applies the selected network checkpoint table. [SRC] `src/validation.cpp:6179–6184`. |
| `minBlocksToKeep` | policy (node setting) | `288` · **optional** · blocks. [SRC] Definition `src/validation.h:272`; initialization `src/config.cpp:100`. | [SRC] - No matching setting in `settings/settings.go:103–136,715–742`; no reference default is assigned to this oracle. | acceptBlock limits how far an unrequested body may be ahead. [SRC] `src/validation.cpp:6289–6290,6321`. |
| `minTtorValidationDistance` | policy | `100` · **optional** · blocks. [SRC] Definition `src/validation.h:345–350`; initialization `src/validation.h:350`. Model parameter for a local policy constant, no CLI. | [SRC] - No matching setting in `settings/settings.go:103–136,715–742`; no reference default is assigned to this oracle. | acceptBlock selects the local TTOR order check below the active tip. [SRC] `src/validation.cpp:5671–5682`. |
| `txIndex` | policy (node setting) | `false` · **optional** · switch. [SRC] Definition `src/validation.h:190`; initialization `src/validation.cpp:7183`. | [SRC] - No matching setting in `settings/settings.go:103–136,715–742`; no reference default is assigned to this oracle. | No state-validity transition reads this setting; it selects the supplementary transaction observation surface. [SRC] `src/rpc/rawtransaction.cpp:194–204`. |
| `invalidBlocks` | policy (node setting) | `[]` · **optional** · block hashes, displayed integer order. [SRC] Definition `src/config.h:879`; initialization `src/config.h:879; src/init.cpp:3265–3274`. An empty operator input by default, never a consensus blacklist. | [SRC] - No matching setting in `settings/settings.go:103–136,715–742`; no reference default is assigned to this oracle. | receiveHeader refuses an operator-listed block. [SRC] `src/config.cpp:992–994; src/validation.cpp:6144–6149`. |
| `limitSecondaryMempoolAncestorCount` | policy | `25` · **optional** · transactions. [SRC] Definition `src/validation.h:88`; initialization `src/config.cpp:50`. | [SRC] - No matching setting in `settings/settings.go:103–136,715–742`; no reference default is assigned to this oracle. | receiveTx checks the secondary-pool ancestor count. [SRC] `src/validation.cpp:783–792`. |
| `maxCoinsViewCacheSize` | policy | `0` · **optional** · bytes. [SRC] Definition `src/config.cpp:872–879`; initialization `src/config.cpp:70`. Zero means unlimited. | [SRC] 0, unlimited (`settings/settings.go:135`). | receiveTx bounds the fetched input scripts when request limits apply. [SRC] `src/validation.cpp:1168–1175`. |
| `maxMempoolSizeDisk` | policy | `0` · **optional** · bytes. [SRC] Definition `src/policy/policy.h:94–95`; initialization `src/config.cpp:84`. Default disk factor zero times maxMempool; this field stores the resolved bytes. | [SRC] - No matching setting in `settings/settings.go:103–136,715–742`; no reference default is assigned to this oracle. | receiveTx and advanceTime use RAM plus disk accounting for eviction. [SRC] `src/validation.cpp:834–844; src/txmempool.cpp:2704–2800`. |
| `mempoolMaxPercentCPFP` | policy | `10` · **optional** · percent. [SRC] Definition `src/policy/policy.h:96–97`; initialization `src/config.cpp:85`. The source comment mentions RAM plus disk; the constructor actually multiplies this fraction by limitMemory (src/validation.cpp:843). | [SRC] - No matching setting in `settings/settings.go:103–136,715–742`; no reference default is assigned to this oracle. | receiveTx and advanceTime cap secondary-pool memory as this percentage of maxMempool. [SRC] `src/validation.cpp:834–844`. |
| `nonFinalMaxReplacementRate` | policy | `7200` · **optional** · updates per configured period. [SRC] Definition `src/validation.h:94–95`; initialization `src/time_locked_mempool.cpp:406`. | [SRC] - No matching setting in `settings/settings.go:103–136,715–742`; no reference default is assigned to this oracle. | receiveTx checks the retained non-final replacement-rate history. [SRC] `src/validation.cpp:1127–1130`. |
| `nonFinalReplacementPeriodMinutes` | policy | `60` · **optional** · minutes. [SRC] Definition `src/validation.h:96–97`; initialization `src/time_locked_mempool.cpp:408`. | [SRC] - No matching setting in `settings/settings.go:103–136,715–742`; no reference default is assigned to this oracle. | receiveTx measures the non-final replacement rate over this period. [SRC] `src/time_locked_mempool.cpp:53,179–205`. |
| `nonFinalCheckFrequencyMs` | policy | `600000` · **optional** · milliseconds. [SRC] Definition `src/time_locked_mempool.h:78–79`; initialization `src/time_locked_mempool.cpp:402`. The scheduler completion is an explicit event, not inferred from now alone. | [SRC] - No matching setting in `settings/settings.go:103–136,715–742`; no reference default is assigned to this oracle. | advanceTime schedules revalidation and purging of held transactions. [SRC] `src/time_locked_mempool.cpp:611–660`. |
| `orphanExpirySeconds` | policy | `1200` · **optional** · seconds. [SRC] Definition `src/orphan_txns.h:27–28`; initialization `src/orphan_txns.h:28; src/orphan_txns.cpp:68`. Model parameter for a local constant, no CLI. | [SRC] 600 seconds in the legacy bridge (`settings/settings.go:719`; `services/legacy/netsync/manager.go:3615`), a separate service observation. | advanceTime expires orphan entries. [SRC] `src/orphan_txns.cpp:195–225`. |
| `orphanExpiryCheckIntervalSeconds` | policy | `300` · **optional** · seconds. [SRC] Definition `src/orphan_txns.h:29–30`; initialization `src/orphan_txns.h:30; src/orphan_txns.cpp:224`. Model parameter for a local constant, no CLI. | [SRC] - No matching setting in `settings/settings.go:103–136,715–742`; no reference default is assigned to this oracle. | advanceTime gates the next orphan sweep. [SRC] `src/orphan_txns.cpp:195–225`. |
| `maxPercentageOfOrphansInBatch` | policy | `60` · **optional** · percent. [SRC] Definition `src/orphan_txns.h:55–56`; initialization `src/config.cpp:89; src/txn_validator.cpp:39`. | [SRC] - No matching setting in `settings/settings.go:103–136,715–742`; no reference default is assigned to this oracle. | receiveTx and advanceTime bound orphan retries in a validation batch. [SRC] `src/orphan_txns.cpp:303–307`. |
| `maxInputsOutputsPerSecondaryOrphan` | policy | `5` · **optional** · inputs or outputs. [SRC] Definition `src/orphan_txns.h:53–54`; initialization `src/config.cpp:90; src/txn_validator.cpp:40`. | [SRC] - No matching setting in `settings/settings.go:103–136,715–742`; no reference default is assigned to this oracle. | receiveTx and advanceTime bound secondary orphan retries. [SRC] `src/orphan_txns.cpp:318–339`. |
| `minConsolidationFactor` | policy | `20` · **optional** · ratio. [SRC] Definition `src/policy/policy.h:71–72`; initialization `src/config.cpp:45`. | [SRC] 20 (`settings/settings.go:130`). | receiveTx checks consolidation eligibility. [SRC] `src/policy/policy.cpp:24–29,147; src/validation.cpp:1267`. |
| `maxConsolidationInputScriptSize` | policy | `150` · **optional** · bytes. [SRC] Definition `src/policy/policy.h:73–74`; initialization `src/config.cpp:46`. | [SRC] 150 (`settings/settings.go:131`). | receiveTx caps each consolidation unlocking script. [SRC] `src/policy/policy.cpp:111; src/validation.cpp:1267`. |
| `minConfConsolidationInput` | policy | `6` · **optional** · confirmations. [SRC] Definition `src/policy/policy.h:75–76`; initialization `src/config.cpp:47`. | [SRC] 6 (`settings/settings.go:132–133`, the maturity alias also 6). | receiveTx checks consolidation input confirmations. [SRC] `src/policy/policy.cpp:97–107; src/validation.cpp:1267`. |
| `acceptNonStdConsolidationInput` | policy | `false` · **optional** · switch. [SRC] Definition `src/policy/policy.h:77–78`; initialization `src/config.cpp:48`. | [SRC] false (`settings/settings.go:134`). | receiveTx selects whether non-standard inputs qualify for consolidation. [SRC] `src/policy/policy.cpp:123–133; src/validation.cpp:1267`. |
| `rollingFeeHalfLifeSeconds` | policy | `43200` · **optional** · seconds. [SRC] Definition `src/txmempool.h:626–627`; initialization `src/txmempool.h:485`. Optional CLI range 1800 to 43200, checked at src/txmempool.cpp:2615–2621. | [SRC] - No matching setting in `settings/settings.go:103–136,715–742`; no reference default is assigned to this oracle. | receiveTx and advanceTime decay the retained rolling fee. [SRC] `src/txmempool.cpp:2624–2647`. |
| `mempoolFullFeeIncrement` | policy | `1000` · **optional** · satoshis per 1000 bytes. [SRC] Definition `src/policy/policy.h:90–91`; initialization `src/policy/policy.h:91`. Model parameter for a local constant, no CLI. | [SRC] - No matching setting in `settings/settings.go:103–136,715–742`; no reference default is assigned to this oracle. | receiveTx and advanceTime raise the rolling fee after eviction. [SRC] `src/txmempool.cpp:2781–2787`. |
| `recentRejectCapacity` | policy | `120000` · **optional** · entries. [SRC] Definition `src/txn_recent_rejects.cpp:9–11`; initialization `src/txn_recent_rejects.cpp:11`. Model parameter for the rolling filter, no CLI. The filter keeps three generations of half this value: 180,000 insertions between two resets are wipe-free (`RejectFilter.wipeFree`, #71; [SRC] `src/bloom.cpp:222–225,265–281`). An inventory reading is judged only when this filter and the separate removed non-final filter are both wipe-free with no declared false positive (`inventoryJudgment`, fix-71). | [SRC] 10000 entries in a bounded map (`services/legacy/netsync/manager.go:94–96,3617`); not an equivalent rolling bloom filter. | receiveTx consults and inserts in the reject filter; the next inventory test that observes another tip hash resets it (`observeTip`, #71). [SRC] `src/net/net.cpp:3558–3564; src/net/net_processing.cpp:930–942; src/validation.cpp:1988–1995,2043–2048`. |
| `recentRejectFalsePositiveRate` | policy | `(1, 1000000)` · **optional** · probability numerator and denominator. [SRC] Definition `src/txn_recent_rejects.cpp:9–11`; initialization `src/txn_recent_rejects.cpp:11`. The requested probability 0.000001 is represented as a ratio; the machine's set is ideal, and a false positive is a declared input (`InventoryObservation.filterFalsePositive`) whose reading is non-judging (`filterJudgment`, #71, [M] 2026-10-14; composed with the separate removed non-final filter in `inventoryJudgment`, fix-71). No randomness is read here. | [SRC] No false-positive parameter for the bounded map (`services/legacy/netsync/manager.go:3617`). | receiveTx uses the reject-filter observation contract of `BsvChain.Rejects` (#71). [SRC] `src/txn_recent_rejects.cpp:19–21`. |
| `maxTxnChainValidationBudget` | policy | `50` · **optional** · milliseconds. [SRC] Definition `src/txn_validation_config.h:44–46`; initialization `src/init.cpp:2880–2885`. | [SRC] No active assignment (`settings/settings.go:128`, commented out). | receiveTx caps carried validation budget along a transaction chain: the carry enters `validationAllowance` in microseconds, capped by this value (#71). [SRC] `src/validation.cpp:1577`; `src/taskcancellation.h:113–121`. |
| `validationClockCpu` | policy | `true` · **optional** · switch. [SRC] Definition `src/txn_validation_config.h:36–37`; initialization `src/init.cpp:2890`. The executable machine reads neither clock itself. | [SRC] No active assignment (`settings/settings.go:129`, commented out). | receiveTx selects the supplied CPU-time or wall-time budget observation; `ElapsedObservation` is in that clock's microseconds (#71). [SRC] `src/validation.cpp:999–1005`. |
| `safeModeMaxForkDistance` | policy (node setting) | `1000` · **optional** · blocks. [SRC] Definition `src/validation.h:310–315`; initialization `src/config.cpp:185`. No effect on block validity. | [SRC] - No matching setting in `settings/settings.go:103–136,715–742`; no reference default is assigned to this oracle. | activateBestChain updates the client safe-mode observation. [SRC] `src/safe_mode.cpp:81–87`. [SRC] `src/safe_mode.cpp:81–88,117–127`; launch `-safemodemaxforkdistance`, `src/init.cpp:2659–2661`. |
| `safeModeMinForkLength` | policy (node setting) | `6` · **optional** · blocks. [SRC] Definition `src/validation.h:317–320`; initialization `src/config.cpp:186`. No effect on block validity. | [SRC] - No matching setting in `settings/settings.go:103–136,715–742`; no reference default is assigned to this oracle. | activateBestChain updates the client safe-mode observation. [SRC] `src/safe_mode.cpp:72–78`. [SRC] `src/safe_mode.cpp:72–79`; launch `-safemodeminforklength`, `src/init.cpp:2662–2664`. |
| `safeModeMinPowDifference` | policy (node setting) | `-72` · **optional** · block-equivalent work difference. [SRC] Definition `src/validation.h:322–326`; initialization `src/config.cpp:187`. Signed; no effect on block validity. | [SRC] - No matching setting in `settings/settings.go:103–136,715–742`; no reference default is assigned to this oracle. | activateBestChain updates the client safe-mode observation. [SRC] `src/safe_mode.cpp:90–99`. [SRC] `src/safe_mode.cpp:90–100`; launch `-safemodeminblockdifference`, `src/init.cpp:2656–2658`. |
| `enableAssumeWhitelistedBlockDepth` | policy (node setting) | `false` · **optional** · switch. [SRC] Definition `src/policy/policy.h:98–99`; initialization `src/config.cpp:97`. Companion setting of the operator-list mechanism; the lists are State inputs (#70). | [SRC] - No matching setting in `settings/settings.go:103–136,715–742`; no reference default is assigned to this oracle. | connectBlock selects the operator-list depth waiver. [SRC] `src/validation.cpp:3530–3554`. |
| `assumeWhitelistedBlockDepth` | policy (node setting) | `6` · **optional** · blocks. [SRC] Definition `src/policy/policy.h:100–101`; initialization `src/config.cpp:98`. Companion setting of the operator-list mechanism. | [SRC] - No matching setting in `settings/settings.go:103–136,715–742`; no reference default is assigned to this oracle. | connectBlock measures the operator-list depth waiver. [SRC] `src/validation.cpp:3532–3554`. |
| `coinbaseMaturity` | consensus | `100` · **optional** · blocks. [SRC] Definition `src/consensus/consensus.h:71–75`; initialization `src/consensus/consensus.h:75`. Model parameter for a consensus constant, no CLI. | [SRC] 100 blocks (go-chaincfg v1.6.2 at `198ccf650e914b1ece818553ade71512760e0eaf`, `params.go:279`, required by `go.mod:15` and selected by `settings/settings.go:102`). | receiveTx, applyTx and connectBlock check coinbase maturity; activateBestChain rechecks it. [SRC] `src/validation.cpp:2617–2625; src/txmempool.cpp:987–1009`. |
| `confiscationMaturity` | consensus | `1000` · **optional** · blocks. [SRC] Definition `src/consensus/consensus.h:76–79`; initialization `src/consensus/consensus.h:79`. The maturity predicate is separate from operator-list membership; model constant, no CLI. | [SRC] - No matching setting in `settings/settings.go:103–136,715–742`; no reference default is assigned to this oracle. | receiveTx, applyTx and connectBlock check confiscation-output maturity; activateBestChain rechecks it. [SRC] `src/validation.cpp:2628–2636; src/txmempool.cpp:987–1009`. |
| `maxFutureBlockTimeSeconds` | consensus | `7200` · **optional** · seconds. [SRC] Definition `src/block_index.h:28–31`; initialization `src/block_index.h:31`. Model parameter for a consensus constant, no CLI. | [SRC] - No matching setting in `settings/settings.go:103–136,715–742`; no reference default is assigned to this oracle. | receiveHeader compares the header time to the explicitly supplied adjusted now. [SRC] `src/validation.cpp:5956–5959,6187`. |
| `medianTimeSpan` | consensus | `11` · **optional** · headers. [SRC] Definition `src/block_index.h:720`; initialization `src/block_index.h:720`. Model parameter for a consensus constant, no CLI; must be positive. | [SRC] - No matching setting in `settings/settings.go:103–136,715–742`; no reference default is assigned to this oracle. | receiveHeader, receiveTx and connectBlock derive median time past for their time predicates. [SRC] `src/block_index.h:722–737; src/validation.cpp:5950–5953,6026–6028,6048`. |
| `maxBlockSigOpsPerMbBeforeGenesis` | consensus | `20000` · **optional** · sigops per rounded-up decimal MB. [SRC] Definition `src/consensus/consensus.h:33–37`; initialization `src/consensus/consensus.h:37`. Model parameter for a consensus constant, no CLI. | [SRC] - No matching setting in `settings/settings.go:103–136,715–742`; no reference default is assigned to this oracle. | acceptBlock and connectBlock cap the pre-Genesis block sigop sum. [SRC] `src/config.cpp:831–834; src/validation.cpp:3480,5853–5866`. |
| `genesisGracefulPeriod` | policy | `72` · **optional** · blocks on each side of activation. [SRC] Definition `src/policy/policy.h:121–128`; initialization `src/configscriptpolicy.cpp:54`. Range 0 to 7200; this changes relay handling, never the activation rule. | [SRC] - No matching setting in `settings/settings.go:103–136,715–742`; no reference default is assigned to this oracle. | receiveTx selects the Genesis grace re-check. [SRC] `src/validation.cpp:1040–1052,2730`. |
| `chronicleGracefulPeriod` | policy | `72` · **optional** · blocks on each side of activation. [SRC] Definition `src/policy/policy.h:130–133`; initialization `src/configscriptpolicy.cpp:55`. Range 0 to 7200; this changes relay handling, never the activation rule. | [SRC] - No matching setting in `settings/settings.go:103–136,715–742`; no reference default is assigned to this oracle. | receiveTx selects the Chronicle grace re-check. [SRC] `src/validation.cpp:1362–1392,2731`. |
| `chainRequireStandard` | policy | `true` · **optional** · switch. [SRC] Definition `src/chainparams.h:86`; initialization `src/chainparams.cpp:1121`. Distinct from inherited requireStandard, which controls the admission refusal. `NodeConfig.withNetwork` (#69) projects the chosen network value; mainnet true, test networks false. #69 projects the chosen network value; mainnet true, test networks false. | [SRC] No separate flag-word switch in `settings/settings.go:123`; RequireStandard is false. The script adapter contract is recorded in §3. | receiveTx selects the relay flag word using the chain default. [SRC] `src/validation.cpp:795–801`. |
| `assumeValidMinWorkTimeSeconds` | policy (node setting) | `1209600` · **optional** · proof-equivalent seconds. [SRC] Definition `src/validation.cpp:3511–3514`; initialization `src/validation.cpp:3514`. Model parameter for a local setting constant, no CLI; two weeks. | [SRC] - No matching setting in `settings/settings.go:103–136,715–742`; no reference default is assigned to this oracle. | connectBlock requires more than this depth before the assumevalid shortcut. [SRC] `src/validation.cpp:3482–3518`. |
| `rollingFeeUpdateIntervalSeconds` | policy | `10` · **optional** · seconds. [SRC] Definition `src/txmempool.cpp:2629`; initialization `src/txmempool.cpp:2629`. Model parameter for a local constant, no CLI; the comparison is strict. | [SRC] - No matching setting in `settings/settings.go:103–136,715–742`; no reference default is assigned to this oracle. | receiveTx and advanceTime gate rolling-fee decay. [SRC] `src/txmempool.cpp:2624–2647`. |
| `rollingFeeLowUsageDivisor` | policy | `4` · **optional** · divisor. [SRC] Definition `src/txmempool.cpp:2631–2632`; initialization `src/txmempool.cpp:2631–2632`. Model parameter for a local constant, no CLI; must be positive. | [SRC] - No matching setting in `settings/settings.go:103–136,715–742`; no reference default is assigned to this oracle. | receiveTx and advanceTime shorten the fee half-life below this fraction of pool capacity. [SRC] `src/txmempool.cpp:2624–2647`. |
| `rollingFeeMediumUsageDivisor` | policy | `2` · **optional** · divisor. [SRC] Definition `src/txmempool.cpp:2633–2634`; initialization `src/txmempool.cpp:2633–2634`. Model parameter for a local constant, no CLI; must be positive. | [SRC] - No matching setting in `settings/settings.go:103–136,715–742`; no reference default is assigned to this oracle. | receiveTx and advanceTime shorten the fee half-life at medium pool usage. [SRC] `src/txmempool.cpp:2624–2647`. |
| `maxTxnValidatorAsyncTasksRunDuration` | policy | `10000` · **optional** · milliseconds. [SRC] Definition `src/txn_validator.h:82–85`; initialization `src/config.cpp:66`. Scheduling and budget expiration remain explicit non-judging observations (#71). | [SRC] - No matching setting in `settings/settings.go:103–136,715–742`; no reference default is assigned to this oracle. | receiveTx and advanceTime cap an asynchronous validation round. [SRC] `src/txn_validator.cpp:355–357`. |
| `txnValidationAsyncRunFrequencyMs` | policy | `10` · **optional** · milliseconds. [SRC] Definition `src/txn_validator.h:80–81`; initialization `src/txn_validator.cpp:24–26`. Scheduling completion remains an explicit event (#71). | [SRC] - No matching setting in `settings/settings.go:103–136,715–742`; no reference default is assigned to this oracle. | advanceTime schedules the pending validation queue. [SRC] `src/txn_validator.cpp:329–355`. |
| `txnValidationQueueMaxMemory` | policy | `2147483648` · **optional** · bytes. [SRC] Definition `src/txn_validator.h:86–87`; initialization `src/txn_validator.cpp:42–46`. 2048 MiB, resolved to bytes; separate from accepted mempool accounting. | [SRC] - No matching setting in `settings/settings.go:103–136,715–742`; no reference default is assigned to this oracle. | receiveTx bounds pending validation queue memory. [SRC] `src/txn_validator.cpp:716–723`. |
| `maxStdTxnsPerThreadRatio` | policy | `1000` · **optional** · transactions per worker. [SRC] Definition `src/txn_validation_config.h:32–33`; initialization `src/txn_validator.cpp:345–349`. Worker counts and completion order are explicit scheduling inputs (#71), never inferred host facts. | [SRC] - No matching setting in `settings/settings.go:103–136,715–742`; no reference default is assigned to this oracle. | advanceTime bounds the standard work selected for a validation round. [SRC] `src/txn_validator.cpp:375–422`. |
| `maxNonStdTxnsPerThreadRatio` | policy | `1000` · **optional** · transactions per worker. [SRC] Definition `src/txn_validation_config.h:34–35`; initialization `src/txn_validator.cpp:350–353`. Worker counts and completion order are explicit scheduling inputs (#71). | [SRC] - No matching setting in `settings/settings.go:103–136,715–742`; no reference default is assigned to this oracle. | advanceTime bounds the non-standard work selected for a validation round. [SRC] `src/txn_validator.cpp:375–422`. |
| `maxBlockConnectionBatch` | policy (node setting) | `32` · **optional** · blocks. [SRC] Definition `src/validation.cpp:4675–4694`; initialization `src/validation.cpp:4677`. Model parameter for a local batching constant, no CLI; must be positive. | [SRC] - No matching setting in `settings/settings.go:103–136,715–742`; no reference default is assigned to this oracle. | activateBestChain bounds a forward connection batch. [SRC] `src/validation.cpp:4675–4694`. |
| `nonFinalRecentlyRemovedCapacity` | policy | `10000` · **optional** · entries. [SRC] Definition `src/time_locked_mempool.h:213–214`; initialization `src/time_locked_mempool.h:214`. Model parameter for the separate rolling filter; its state is `Mempool.nonFinalRecentlyRemoved` (ideal members and insertion count), read by the inventory test (`knownElsewhere`). Its own wipe-free bound is 15,000 insertions at the defaults (three generations of 5,000, `default_removed_wipe_free_bound`; [SRC] `src/time_locked_mempool.h:214`; `src/bloom.cpp:222–225,265–281`), independent of the reject filter's 180,000; a false positive is a declared input (`InventoryObservation.removedFalsePositive`). An inventory reading is judged only when both filters are exact (`inventoryJudgment`, fix-71); other readings are non-judging. | [SRC] - No matching setting in `settings/settings.go:103–136,715–742`; no reference default is assigned to this oracle. | receiveTx can consult the recently removed non-final filter through its submission path. [SRC] `src/time_locked_mempool.cpp:217–221`. |
| `nonFinalRecentlyRemovedFalsePositiveRate` | policy | `(1, 1000000)` · **optional** · probability numerator and denominator. [SRC] Definition `src/time_locked_mempool.h:213–214`; initialization `src/time_locked_mempool.h:214`. Model parameter for the separate rolling filter; its state is `Mempool.nonFinalRecentlyRemoved` (ideal members and insertion count), read by the inventory test (`knownElsewhere`). Its own wipe-free bound is 15,000 insertions at the defaults (three generations of 5,000, `default_removed_wipe_free_bound`; [SRC] `src/time_locked_mempool.h:214`; `src/bloom.cpp:222–225,265–281`), independent of the reject filter's 180,000; a false positive is a declared input (`InventoryObservation.removedFalsePositive`). An inventory reading is judged only when both filters are exact (`inventoryJudgment`, fix-71); other readings are non-judging. | [SRC] - No matching setting in `settings/settings.go:103–136,715–742`; no reference default is assigned to this oracle. | receiveTx can consult the recently removed non-final filter through its submission path. [SRC] `src/time_locked_mempool.cpp:217–221`. |
| `ptvTaskScheduleStrategy` | policy (node setting) | `PTVTaskScheduleStrategy.topoSort` · **optional** · scheduler choice. [SRC] Definition `src/txn_validation_config.h:47–48`; initialization `src/config.cpp:68; src/init.cpp:2903–2909`. | [SRC] - No matching setting in `settings/settings.go:103–136,715–742`; no reference default is assigned to this oracle. | receiveTx selects the PTV task scheduler. The constructor topoSort represents TOPO_SORT; chainDetector represents CHAIN_DETECTOR. [SRC] `src/txn_validator.cpp:595`. |
| `blockValidationTxBatchSize` | policy (node setting) | `10` · **optional** · transactions. [SRC] Definition `src/validation.h:107–108`; initialization `src/config.cpp:102; src/init.cpp:2646`. | [SRC] - No matching setting in `settings/settings.go:103–136,715–742`; no reference default is assigned to this oracle. | connectBlock groups transactions for parallel validation; the batch size must be positive. [SRC] `src/validation.cpp:3566–3572`. |
| `scriptValidationMaxBatchSize` | policy (node setting) | `128` · **optional** · script checks. [SRC] Definition `src/validation.h:216–217`; initialization `src/config.cpp:60; src/init.cpp:2411`. | [SRC] - No matching setting in `settings/settings.go:103–136,715–742`; no reference default is assigned to this oracle. | Block validation initializes the maximum script-check batch size. [SRC] `src/validation.cpp:2964`. |
| `maxParallelBlocks` | policy (node setting) | `4` · **optional** · blocks. [SRC] Definition `src/validation.h:214–215`; initialization `src/config.cpp:57; src/init.cpp:2408`. | [SRC] - No matching setting in `settings/settings.go:103–136,715–742`; no reference default is assigned to this oracle. | activateBestChain bounds concurrent sibling validations and initializes the script-check pool. [SRC] `src/validation.cpp:2961,5013–5015`. |
| `stopAtHeight` | policy (node setting) | `0` · **optional** · block height. [SRC] Definition `src/validation.h:211–212`; initialization `src/config.cpp:91; src/init.cpp:2457`. | [SRC] - No matching setting in `settings/settings.go:103–136,715–742`; no reference default is assigned to this oracle. | activateBestChain requests shutdown at or above the selected height; zero disables this observation. [SRC] `src/validation.cpp:5116–5119`. |
| `detectSelfishMining` | policy (node setting) | `false` · **optional** · switch. [SRC] Definition `src/validation.h:221–222`; initialization `src/config.cpp:191; src/init.cpp:3167`. | [SRC] - No matching setting in `settings/settings.go:103–136,715–742`; no reference default is assigned to this oracle. | connectBlock observes a potentially selfishly mined block while updating the pool; it does not reject the block. [SRC] `src/txmempool.cpp:1123–1128`. |
| `minBlockMempoolTimeDifferenceSelfish` | policy (node setting) | `60` · **optional** · seconds. [SRC] Definition `src/policy/policy.h:164–166`; initialization `src/config.cpp:190; src/init.cpp:3171–3174`. | [SRC] - No matching setting in `settings/settings.go:103–136,715–742`; no reference default is assigned to this oracle. | The selfish-mining observation compares the last retained mempool transaction time with the last block transaction time. [SRC] `src/txmempool.cpp:1180–1186`. |
| `selfishTxPercentThreshold` | policy (node setting) | `10` · **optional** · percent. [SRC] Definition `src/policy/policy.h:168–172`; initialization `src/config.cpp:192; src/init.cpp:3181–3184`. | [SRC] - No matching setting in `settings/settings.go:103–136,715–742`; no reference default is assigned to this oracle. | The selfish-mining observation compares the percentage of omitted transactions above the block fee rate with this threshold. [SRC] `src/txmempool.cpp:1239–1242`. |
| `maxPrimaryPromotionVisits` | policy | `1000` · **optional** · visited transactions. [SRC] Definition and initialization `src/txmempool.h:423` at `6504a3af`; model parameter for a fixed constant, no CLI. | [SRC] Unmapped here; no counterpart default is asserted. | receiveTx propagates primary-pool promotion while the visited count is at most the bound; a whole group can cross it. [SRC] `src/txmempool.cpp:481–565`. |
| `maxTxSigOpsCountConsensusBeforeGenesis` | consensus | `20000` · **optional** · sigops. [SRC] Definition and initialization `src/consensus/consensus.h:46–47` at `6504a3af`; fixed getter `src/config.cpp:2417–2420`, no CLI. | Unmapped here; no counterpart default is asserted. | receiveTx passes the getter into the regular gate and its Genesis grace check. [SRC] `src/validation.cpp:1032–1035,1043–1046`. |
| `maxTxSizeConsensusBeforeGenesis` | consensus | `1000000` · **optional** · bytes. [SRC] Definition and initialization `src/consensus/consensus.h:12–15,26–27` at `6504a3af`; fixed getter `src/configscriptpolicy.cpp:397–405`, no CLI. | Unmapped here; no counterpart default is asserted. | receiveTx passes the getter into the regular gate and its Genesis grace check. [SRC] `src/validation.cpp:1032–1035,1043–1046`. |
| `maxTxSizeConsensusAfterGenesis` | consensus | `1000000000` · **optional** · bytes. [SRC] Definition and initialization `src/consensus/consensus.h:12–17,28–29` at `6504a3af`; fixed getter `src/configscriptpolicy.cpp:408–412`, no CLI. | Unmapped here; no counterpart default is asserted. | receiveTx passes the getter into the regular gate and its Genesis grace check. [SRC] `src/validation.cpp:1032–1035,1043–1046`. |
<!-- chain-node-config:end -->

The extra rows beyond DESIGN-S6 §4.2 make explicit the maturity/time/sigop
constants, grace periods, independent chain flag-word setting, assumevalid
work-time threshold, rolling-fee update and occupancy factors, asynchronous
queue budgets, connection batch size, the non-final recently-removed
filter, the PTV strategy, validation batch sizes, parallel-block cap, stop height
and selfish-mining observation settings. #71 must retain that filter's state beside the recent-reject filter;
both probability ratios specify requested probabilities, with conversion and
observation limits to be stated there. Thread counts and completion order are
explicit scheduling observations; no host clock, worker count or network read
is performed by this record. Network tables are inventoried in §8.3; finality
encodings remain the cited work of #60. The regular gate reuses `BsvScript.TxRules`
with the three consensus getter limits now present above, as #62 requires. The
fixed defaults are consensus constants; exposing them as fields does not make them policy.

**The operator-list data (#70; [M] 2026-10-14).** The frozen-output
records and the confiscation whitelist are the explicit `OperatorLists` input
(`lean/BsvChain/Frozen.lean`), installed by the freeze RPCs and recorded without
opinion. Every row below is the operator-list mechanism, a policy parameter
(rule 13): the reference's list named "consensus" (`Blacklist::Consensus`) is an
operator list that the node also applies at block connection, and the name is the
reference's label for it, not a consensus rule of the chain. The default of every
list is empty (a fresh database, `src/frozentxo_db.cpp:14–37`). The connection
derives the effective projection per attempt (`connectionFrozenLists`,
`lean/BsvChain/Chain.lean`) from the records, the connecting block's explicit soft
consensus freeze and the two depth settings in the census above. All `[SRC]` at
`6504a3aff65ba97c0f6c80962b033e35ecbfed4b`.

| datum | kind | default and presence `[SRC]` | installed by `[SRC]` | read at `[SRC]` |
|---|---|---|---|---|
| policy-only record: an outpoint | policy (operator list) | empty · optional. Record `src/frozentxo_db.h:205–211`. | `addToPolicyBlacklist` `src/rpc/frozentxo_rpc.cpp:320–344` → `FreezeTXOPolicyOnly` `src/frozentxo_db.cpp:299–326`; removed by `removeFromPolicyBlacklist` `src/rpc/frozentxo_rpc.cpp:380–402` → `src/frozentxo_db.cpp:373–396` | admission only, at the tip's successor: `src/frozentxo.cpp:63–75`, `IsFrozenOnPolicy` `src/frozentxo_db.h:323–348`; verdict `bad-txns-inputs-frozen`, code 0x10, `src/validation.cpp:2594–2607` |
| ranged record: an outpoint, its `enforceAtHeight` half-open intervals [start, stop) (an absent stop is 2147483647; an interval with start ≥ stop is ignored) and `policyExpiresWithConsensus` | policy (operator list; the reference's "consensus" list) | empty · optional. Record `src/frozentxo_db.h:194–202,226–308`. | `addToConsensusBlacklist` `src/rpc/frozentxo_rpc.cpp:346–378` (intervals `:29–55`) → `FreezeTXOConsensus` `src/frozentxo_db.cpp:328–371` | block path at the block's height inside an interval: `IsFrozenOnConsensus` `src/frozentxo_db.h:353–377`, `src/frozentxo.cpp:52–62`, verdict code 0x13 (`REJECT_SOFT_CONSENSUS_FREEZE`) with the soft consensus freeze `src/validation.cpp:3402–3407`; admission: the policy predicate, which ends at the highest stop only when `policyExpiresWithConsensus` |
| confiscation record: an outpoint a whitelisted transaction confiscates | policy (operator list) | empty · optional. Record `src/frozentxo_db.h:213–218`. | moved there by `addToConfiscationTxidWhitelist` (`src/frozentxo_db.cpp:763–768`); moved back by `clearConfiscationWhitelist` `src/rpc/frozentxo_rpc.cpp:766–797` → `src/frozentxo_db.cpp:838–888` | both paths at every height: `src/frozentxo_db.h:325–328,355–359`; a confiscation transaction's own inputs skip the check, `src/validation.cpp:2594–2611` |
| whitelist entry: a confiscation transaction's id, its `enforceAtHeight`, its confiscated outputs | policy (operator list) | empty · optional. Record `src/frozentxo_db.h:589–616`. | `addToConfiscationTxidWhitelist` `src/rpc/frozentxo_rpc.cpp:632–764` → `WhitelistTx` `src/frozentxo_db.cpp:720–800` (valid contents `:638–717`; every input frozen on the ranged predicate at the enforce height) | both paths at heights ≥ `enforceAtHeight`: `src/frozentxo.cpp:133–141`; verdicts `bad-ctx-invalid` and `bad-ctx-not-whitelisted`, code 0x10, `src/validation.cpp:2562–2586`; maturity of its outputs `confiscationMaturity` (census above), `src/validation.cpp:2627–2636` |
| the connecting block's explicit soft consensus freeze | state of the block index (a count, absent is -1) | absent. `src/block_index.h:390–398,569–574`. | set at a refused connection with `softConsensusFreezeDuration` (census above), `src/validation.cpp:3402–3407,3720–3740` | the block path's frozen check is a no-op for that block: `src/frozentxo.cpp:39–42` |
| the depth waiver | policy (node setting; the census rows `enableAssumeWhitelistedBlockDepth`, `assumeWhitelistedBlockDepth`) | `false`, `6` (census above) | launch options, `src/config.cpp:97–98` | block path only: the whitelist check passes for a block at least the depth under the most-work target or the best header, `src/validation.cpp:3529–3555`, `src/frozentxo.cpp:158–165` |

The model's operator calls are the five database effects named in the table
(`OperatorLists.freezePolicyOnly`, `freezeConsensus`, `unfreezePolicyOnly`,
`whitelistTx`, `clearWhitelist`). `clearBlacklists` (`src/rpc/frozentxo_rpc.cpp:501–606`)
and the RPC handlers' mempool sweeps (`src/rpc/frozentxo_rpc.cpp:250–279`) are not
modeled as transitions in this cut; a scenario starts from a fresh database.

**Correction to the design inventory [SRC].** `minRelayTxFee` is initialized to
zero (`src/config.cpp:32`; `src/init.cpp:3093–3099`), and the former option is
removed. The named 250-sat/kB constant at `src/validation.h:77` is not the
initialized fee-estimate setting. The receive floor remains the rolling fee
and debug floor. Also, the CPFP memory cap is calculated from RAM
(`src/validation.cpp:838–843`), although the policy header describes total pool
size. The row records the calculation that the transition will consume.

The maintainers' S6-1 ruling requires the executable machine plus #65's
header-and-path inclusion theorem in disjunction form. The census supplies
the header-validation, eligibility and script-check settings that its execution
paths read; it adds no axiom, hash-injectivity flag or trusted-inclusion switch.
The theorem, path-shape conditions and collision witness are #65's work.
Build, kernel audit, deliberate RED mutations and restored GREEN are recorded
in [the #59 census record](records/20261012-023741-s6-59-census.md).

### 8.3 Per-network chain parameters

[SRC] `CreateChainParams` defines mainnet, testnet, STN and regtest only
(`src/chainparams.cpp:1589–1607` at §8's bitcoin-sv pin). `BsvChain.ChainParams`
in `lean/BsvChain/Params.lean` records these values; #69 adds their use in
transitions, checkpoint tables and proofs. The data and census are completed here.

[M] 2026-10-13, #69: the transitions now read these parameters
through `lean/BsvChain/Eras.lean`. `bip30Enforced` (the two height-and-hash
exceptions, `bip34Height` with `bip34Hash`, the resolved `disableBip30Checks`)
is the default of `ChainContext.connectionChecks` through `eraConnectionChecks`
and fills `prepareBlockConnection`'s BIP30 hook; `checkBlockVersion` names the
`bip34Height`/`bip66Height`/`bip65Height` floors of `contextualCheckBlockHeader`;
`nextWorkPath` names the `powNoRetargeting`/`daaHeight` branch of
`getNextWorkRequired`; `blockFinalityCutoff` (#60) switches at `csvHeight`;
`uahfHeight` is read only by the block script word (`ordinaryScriptFlags`), no
block size rule reads it at the pin, and `LEGACY_MAX_BLOCK_SIZE` survives as the
`excessiveBlockSize` setter's floor (`excessiveBlockSizeAdmissible`).
`NetworkData` (mainnet, testnet, STN, regtest) adds each network's checkpoint
table, BIP30 permission, standardness and the `minimumChainWork`/`assumeValid`
defaults, which `NodeConfig.withNetwork` applies; these are network data read
through settings, not consensus fields, so the 17-field census above is unchanged.
The theorems are DESIGN-S6 §4.4's #69 paragraph [SRC] at §8's pin.

[M] This separate record has 17 fields, all consensus parameters: 9 activation
heights, 1 subsidy interval, 5 proof-of-work parameters and 2 block hashes;
4 networks × 17 fields = 68 cited cells. These are not additional NodeConfig fields.
[D] Presence is **optional** in the launch-input sense used above. `none` instead
means an absent source assignment, not an optional consensus rule or a zero height.
The STN constructor omits BIP65, BIP66 and CSV (`src/chainparams.cpp:1195–1304`);
the declarations have no field initializers (`src/consensus/params.h:23–28`),
and the containing member has none (`src/chainparams.h:115`). The Lean record
uses `Option Nat` for those fields on every network; `toScript?` returns `none`
when a height is absent. No numeric STN value or executable STN verdict is inferred.

[SRC] Values below are raw source thresholds: script-flag reads compare some
against `height + 1` (`src/verify_script_flags.cpp:42–52`), and the DAA path reads
the parent height (`src/pow.cpp:111–113`). Genesis and Chronicle node overrides
are separate (`src/init.cpp:2609–2616`). Time values are seconds, heights and
subsidy intervals are blocks, hashes and powLimit are unsigned integers, and
flags are booleans. [D] `14 * 24 * 60 * 60 = 1209600` and `10 * 60 = 600`.

<!-- chain-network-config:start -->
| value | mainnet [SRC] | testnet [SRC] | STN [SRC] | regtest [SRC] |
|---|---|---|---|---|
| `bip34Height` | `227931` [SRC] `src/chainparams.cpp:1038`. | `21111` [SRC] `src/chainparams.cpp:1334`. | `100000000` [SRC] `src/chainparams.cpp:1212`. | `100000000` [SRC] `src/chainparams.cpp:1463`. |
| `bip65Height` | `some 388381` [SRC] `src/chainparams.cpp:1042`. | `some 581885` [SRC] `src/chainparams.cpp:1338`. | `none` [SRC] `src/chainparams.cpp:1195–1304`. | `some 1351` [SRC] `src/chainparams.cpp:1466`. |
| `bip66Height` | `some 363725` [SRC] `src/chainparams.cpp:1044`. | `some 330776` [SRC] `src/chainparams.cpp:1340`. | `none` [SRC] `src/chainparams.cpp:1195–1304`. | `some 1251` [SRC] `src/chainparams.cpp:1468`. |
| `csvHeight` | `some 419328` [SRC] `src/chainparams.cpp:1046`. | `some 770112` [SRC] `src/chainparams.cpp:1342`. | `none` [SRC] `src/chainparams.cpp:1195–1304`. | `some 576` [SRC] `src/chainparams.cpp:1470`. |
| `uahfHeight` | `478558` [SRC] `src/chainparams.cpp:1065`. | `1155875` [SRC] `src/chainparams.cpp:1361`. | `15` [SRC] `src/chainparams.cpp:1225`. | `0` [SRC] `src/chainparams.cpp:1487`. |
| `daaHeight` | `504031` [SRC] `src/chainparams.cpp:1068`. | `1188697` [SRC] `src/chainparams.cpp:1364`. | `2200` [SRC] `src/chainparams.cpp:1228`. | `0` [SRC] `src/chainparams.cpp:1490`. |
| `genesisHeight` | `620538` [SRC] `src/chainparams.cpp:18,1071`. | `1344302` [SRC] `src/chainparams.cpp:20,1367`. | `100` [SRC] `src/chainparams.cpp:19,1231`. | `10000` [SRC] `src/chainparams.cpp:21,1493`. |
| `chronicleHeight` | `943816` [SRC] `src/chainparams.cpp:23,1074`. | `1713168` [SRC] `src/chainparams.cpp:25,1370`. | `250` [SRC] `src/chainparams.cpp:24,1234`. | `15000` [SRC] `src/chainparams.cpp:26,1496`. |
| `p2shHeight` | `173805` [SRC] `src/chainparams.cpp:28,1076`. | `519` [SRC] `src/chainparams.cpp:30,1372`. | `1` [SRC] `src/chainparams.cpp:29,1236`. | `1` [SRC] `src/chainparams.cpp:31,1498`. |
| `subsidyHalvingInterval` | `210000` [SRC] `src/chainparams.cpp:1037`. | `210000` [SRC] `src/chainparams.cpp:1333`. | `210000` [SRC] `src/chainparams.cpp:1211`. | `150` [SRC] `src/chainparams.cpp:1460`. |
| `powLimit` | `0x00000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffff` [SRC] `src/chainparams.cpp:1047–1048`. | `0x00000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffff` [SRC] `src/chainparams.cpp:1343–1344`. | `0x00000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffff` [SRC] `src/chainparams.cpp:1214`. | `0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff` [SRC] `src/chainparams.cpp:1471–1472`. |
| `powTargetTimespan` | `1209600` [SRC] `src/chainparams.cpp:1050`. | `1209600` [SRC] `src/chainparams.cpp:1346`. | `1209600` [SRC] `src/chainparams.cpp:1215`. | `1209600` [SRC] `src/chainparams.cpp:1474`. |
| `powTargetSpacing` | `600` [SRC] `src/chainparams.cpp:1051`. | `600` [SRC] `src/chainparams.cpp:1347`. | `600` [SRC] `src/chainparams.cpp:1216`. | `600` [SRC] `src/chainparams.cpp:1475`. |
| `powAllowMinDifficultyBlocks` | `false` [SRC] `src/chainparams.cpp:1052`. | `true` [SRC] `src/chainparams.cpp:1348`. | `false` [SRC] `src/chainparams.cpp:1218`. | `true` [SRC] `src/chainparams.cpp:1476`. |
| `powNoRetargeting` | `false` [SRC] `src/chainparams.cpp:1053`. | `false` [SRC] `src/chainparams.cpp:1349`. | `false` [SRC] `src/chainparams.cpp:1219`. | `true` [SRC] `src/chainparams.cpp:1477`. |
| `bip34Hash` | `0x000000000000024b89b42a942fe0d9fea3bb44ab7bd1b19115dd6a759c0808b8` [SRC] `src/chainparams.cpp:1039–1040`. | `0x0000000023b3a96d3484e5abb3755c413e7d41500f8e2a5c3f0dd01299cd8ef8` [SRC] `src/chainparams.cpp:1335–1336`. | `0` [SRC] `src/chainparams.cpp:1213`. | `0` [SRC] `src/chainparams.cpp:1464`. |
| `hashGenesisBlock` | `0x000000000019d6689c085ae165831e934ff763ae46a2a6c172b3f1b60a8ce26f` [SRC] `src/chainparams.cpp:1096–1099`. | `0x000000000933ea01ad0ee984209779baaec3ced90fa3f408719526f8d77f4943` [SRC] `src/chainparams.cpp:1387–1390`. | `0x000000000933ea01ad0ee984209779baaec3ced90fa3f408719526f8d77f4943` [SRC] `src/chainparams.cpp:1206–1209`. | `0x0f9188f13cb7b2c71f2a335e3a4fc328bf5beb436012afca590b1a11466e2206` [SRC] `src/chainparams.cpp:1512–1515`. |
<!-- chain-network-config:end -->

[SRC] The comparison uses go-chaincfg v1.6.2 at
`198ccf650e914b1ece818553ade71512760e0eaf`, selected by the pinned second oracle
(§1a of PROVENANCE). `params.go` below is that file at that pin. Unmapped cells
state only what this read establishes; service equivalence remains #74's work.

<!-- chain-network-comparison:start -->
| value | kind | presence and definition [SRC] | second oracle, by network [SRC] | read at [SRC] |
|---|---|---|---|---|
| `bip34Height` | consensus | **optional**. [SRC] `src/consensus/params.h:20–21`. | [SRC] Mainnet 227931 (`go-chaincfg/params.go:265`); testnet 21111 (`go-chaincfg/params.go:545`); STN 100000000 (`go-chaincfg/params.go:383`); regtest 100000000 (`go-chaincfg/params.go:464`). | [SRC] `src/validation.cpp:5965,6085–6092`. |
| `bip65Height` | consensus | **optional**. [SRC] `src/consensus/params.h:23–24`. | [SRC] Mainnet 388381 (`go-chaincfg/params.go:266`); testnet 581885 (`go-chaincfg/params.go:546`); STN 1351 (`go-chaincfg/params.go:384`), assigned there despite the reference omission; regtest 1351 (`go-chaincfg/params.go:465`). | [SRC] `src/validation.cpp:5967; src/verify_script_flags.cpp:46–48`. |
| `bip66Height` | consensus | **optional**. [SRC] `src/consensus/params.h:25–26`. | [SRC] Mainnet 363725 (`go-chaincfg/params.go:267`); testnet 330776 (`go-chaincfg/params.go:547`); STN 1251 (`go-chaincfg/params.go:385`), assigned there despite the reference omission; regtest 1251 (`go-chaincfg/params.go:466`). | [SRC] `src/validation.cpp:5966; src/verify_script_flags.cpp:42–44`. |
| `csvHeight` | consensus | **optional**. [SRC] `src/consensus/params.h:27–28`. | [SRC] Mainnet 419328 (`go-chaincfg/params.go:268`); testnet 770112 (`go-chaincfg/params.go:548`); STN 0 (`go-chaincfg/params.go:386`), assigned there despite the reference omission; regtest 576 (`go-chaincfg/params.go:467`). | [SRC] `src/validation.cpp:3465,6046–6049; src/verify_script_flags.cpp:50–52`. |
| `uahfHeight` | consensus | **optional**. [SRC] `src/consensus/params.h:29–30`. | [SRC] Mainnet 478558 (`go-chaincfg/params.go:271`); testnet 1155875 (`go-chaincfg/params.go:551`); STN 15 (`go-chaincfg/params.go:389`); regtest 0 (`go-chaincfg/params.go:470`). | [SRC] `src/verify_script_flags.cpp:54–59`. |
| `daaHeight` | consensus | **optional**. [SRC] `src/consensus/params.h:31–32`. | [SRC] Mainnet 504031 (`go-chaincfg/params.go:274`); testnet 1188697 (`go-chaincfg/params.go:554`); STN 2200 (`go-chaincfg/params.go:392`); regtest 0 (`go-chaincfg/params.go:473`). | [SRC] `src/pow.cpp:107–113; src/verify_script_flags.cpp:65–69`. |
| `genesisHeight` | consensus | **optional**. [SRC] `src/consensus/params.h:33–37`. | [SRC] Mainnet 620538 (`go-chaincfg/params.go:276`); testnet 1344302 (`go-chaincfg/params.go:556`); STN 100 (`go-chaincfg/params.go:394`); regtest 100 (`go-chaincfg/params.go:475`), different from the reference 10000. | [SRC] `src/protocol_era.cpp:21–46; src/init.cpp:2609–2612`. |
| `chronicleHeight` | consensus | **optional**. [SRC] `src/consensus/params.h:33–38`. | [SRC] Mainnet 943816 (`go-chaincfg/params.go:277`); testnet 1713168 (`go-chaincfg/params.go:557`); STN 250 (`go-chaincfg/params.go:395`); regtest 200 (`go-chaincfg/params.go:476`), different from the reference 15000. | [SRC] `src/protocol_era.cpp:21–46; src/init.cpp:2613–2616`. |
| `p2shHeight` | consensus | **optional**. [SRC] `src/consensus/params.h:39`. | [SRC] - No P2SH activation-height field in `go-chaincfg/params.go:145–158`; no reference height is assigned to this oracle. | [SRC] `src/verify_script_flags.cpp:38–40`. |
| `subsidyHalvingInterval` | consensus | **optional**. [SRC] `src/consensus/params.h:19`. | [SRC] Mainnet 210000 (`go-chaincfg/params.go:280`); testnet 210000 (`go-chaincfg/params.go:561`); STN 210000 (`go-chaincfg/params.go:397`); regtest 150 (`go-chaincfg/params.go:478`). | [SRC] `src/validation.cpp:2252–2262`. |
| `powLimit` | consensus | **optional**. [SRC] `src/consensus/params.h:42`. | [SRC] Mainnet and testnet 2^224 - 1 (`go-chaincfg/params.go:26–37,263,543`); STN 2^224 - 1 (`go-chaincfg/params.go:39–41,379`); regtest 2^255 - 1 (`go-chaincfg/params.go:30–32,460`). | [SRC] `src/pow.cpp:101–103,150–170`. |
| `powTargetTimespan` | consensus | **optional**. [SRC] `src/consensus/params.h:46–48`. | [SRC] - `TargetTimespan` is commented out at `go-chaincfg/params.go:171–175`; no initializer value is asserted. | [SRC] `src/pow.cpp:27–38,128–145`. |
| `powTargetSpacing` | consensus | **optional**. [SRC] `src/consensus/params.h:45`. | [SRC] Mainnet 600 seconds (`go-chaincfg/params.go:281`); testnet 600 (`go-chaincfg/params.go:562`); STN 600 (`go-chaincfg/params.go:398`); regtest 600 (`go-chaincfg/params.go:479`). | [SRC] `src/pow.cpp:44–49,267–269`. |
| `powAllowMinDifficultyBlocks` | consensus | **optional**. [SRC] `src/consensus/params.h:43`. | [SRC] `ReduceMinDifficulty`: mainnet false (`go-chaincfg/params.go:283`); testnet true (`go-chaincfg/params.go:564`); STN false (`go-chaincfg/params.go:400`); regtest true (`go-chaincfg/params.go:481`). | [SRC] `src/pow.cpp:44–61,267–270`. |
| `powNoRetargeting` | consensus | **optional**. [SRC] `src/consensus/params.h:44`. | [SRC] `NoDifficultyAdjustment`: mainnet false (`go-chaincfg/params.go:284`); testnet false (`go-chaincfg/params.go:565`); STN false (`go-chaincfg/params.go:401`); regtest true (`go-chaincfg/params.go:482`). | [SRC] `src/pow.cpp:106–109`. |
| `bip34Hash` | consensus | **optional**. [SRC] `src/consensus/params.h:20–22`. | [SRC] - The mainnet/testnet hashes are comments beside `go-chaincfg/params.go:265,545`; no BIP34 hash field is declared at `go-chaincfg/params.go:145–158`. | [SRC] `src/validation.cpp:3088–3095`. |
| `hashGenesisBlock` | consensus | **optional**. [SRC] `src/consensus/params.h:18`. | [SRC] Mainnet/testnet/STN use named hash objects (`go-chaincfg/params.go:262,542,378`); regtest assigns the reference hash literally (`go-chaincfg/params.go:459`). The other hash objects are unmapped in this read. | [SRC] `src/validation.cpp:3044,6152`. |
<!-- chain-network-comparison:end -->

**The per-network depth data** (`BsvChain.DepthNetwork`). Policy network data, separate from `NodeConfig`. Read sites: work floor and
assumed-valid launch reads [SRC] `src/init.cpp:2355–2382`; checkpoint launch read
[SRC] `src/init.cpp:2352–2353`, table reads [SRC] `src/checkpoints.cpp:14–36`
and `src/validation.cpp:5903–5930,6179–6184`.

| value | mainnet [SRC] | testnet [SRC] | STN [SRC] | regtest [SRC] |
|---|---|---|---|---|
| `nMinimumChainWork` | `0x…a0f3064330647e2f6c4828` `src/chainparams.cpp:1056–1057` | `0x…2a650f6ff7649485da` `:1352–1353` | `0` `:1222` | `0` `:1480` |
| `defaultAssumeValid` | `0x000000000000000000e45ad2fbcc5ff3e85f0868dd8f00ad4e92dffabe28f8d2` `:1061–1062` | `0x0000000000327972b8470c11755adf8f4319796bafae01f5a6650490b98a17db` `:1357–1358` | zero: no assignment in `CStnParams` (`:1195–1304`), the member's value (`src/consensus/params.h:51`) | `0` `:1484` |
| checkpoints | [M] 16, heights 11,111 to 530,359 `:1124–1160` | [M] 3, heights 546, 1,155,875 and 1,188,697 `:1419–1428` | [M] 11, heights 0 through 11 excluding 3 `src/chainparams.cpp:1274–1287` | [M] 1, the genesis block at height 0 `:1530–1533` |

### 8.4 Auxiliary safe-mode client switches (#73)

[D] 2026-10-14 02:04:12 UTC. The seven guarded depth and safe-mode
chain settings retain their canonical census in [§8.2](#82-the-added-chain-fields).
Per-network depth data is in [§8.3](#83-per-network-chain-parameters).
Definitions are in `lean/BsvChain/Depth.lean`; model theorem premises are in
`lean/BsvChain/Properties/Depth.lean`. Source readings and the scope of the
recorded `corpus/chain/depth/` observations are in the
[#73 record](records/20261014-013925-s6-73-regtest-s3.md).
[SRC] Reference pin `6504a3aff65ba97c0f6c80962b033e35ecbfed4b`.

| client switch | kind | presence | default and source | launch/definition site [SRC] | read site [SRC] |
|---|---|---|---|---|---|
| `-disablesafemode` | policy (client setting) | optional; auxiliary `SafeModeClient.disableSafeMode`, outside `NodeConfig` | `false`, `src/init.cpp:96` | `src/init.cpp:1694–1696` | `src/init.cpp:326–332` |
| `-testsafemode` | policy (client setting) | optional; auxiliary `SafeModeClient.testSafeMode`, outside `NodeConfig` | `false`, `src/warnings.h:43` | `src/init.cpp:1699–1700` | `src/warnings.cpp:46–47` |
| `-safemodewebhookurl` | policy (client setting) | optional; unmodelled, outside `SafeModeClient` and `NodeConfig` | empty address/path, `src/config.cpp:182–184` | `src/init.cpp:2651–2655`; `src/config.cpp:1161–1194` | `src/safe_mode.cpp:370–380` |

[D] The guard still censuses 81 chain fields: this change adds zero `NodeConfig`
fields. It does not census `SafeModeClient` or the unmodelled webhook field.
Incorporation of the auxiliary client settings into `NodeConfig` remains debt;
a GREEN census does not discharge it.

[D] Source registration metadata: `safeModeRefusedCommands` retains 24 false-flag
names for a wallet-enabled build. All 21 wallet entries, including
`fundrawtransaction`, and the wallet registrar's safe `generate` entry are absent
from the wallet-less node of record. [SRC] `src/init.cpp:3083–3087`,
`src/rpc/rawtransaction.cpp:2624–2626`, `src/wallet/rpcwallet.cpp:3514–3554`.
Measured command coverage is scoped in the linked record.

### 8.5 Auxiliary Miner ID settings (#83)

[D] 2026-10-15 11:28 UTC. Nothing of Miner ID is consensus (cited in
`lean/BsvChain/Views/MinerId.lean`'s header). The six modelled settings are the fields of
the auxiliary `MinerIdConfig` in `lean/BsvChain/Views/MinerId.lean` (section 6), outside
`NodeConfig`; the setters' bounds are `MinerIdConfig.valid`. Scope and corpus are in the
[#83 record](records/20261015-110731-s7-83-minerid-s1.md).
[SRC] Reference pin `6504a3aff65ba97c0f6c80962b033e35ecbfed4b`.

| node setting | kind | presence | default and source | launch/definition site [SRC] | read site [SRC] |
|---|---|---|---|---|---|
| `-minerid` | policy (node setting) | optional; auxiliary `MinerIdConfig.enabled`, outside `NodeConfig` | `false`, `src/miner_id/miner_id_db_defaults.h:18` | `src/init.cpp:3030–3035`, `src/config.cpp:2071–2075` | `src/init.cpp:4095–4109` |
| `-mineridcachesize` | policy (node setting) | optional; auxiliary `MinerIdConfig.cacheSize`, outside `NodeConfig` | 1 MiB (`1 << 20`), at most 16 MiB (`1 << 24`), `src/miner_id/miner_id_db_defaults.h:21–22` | `src/init.cpp:3036–3040`, `src/config.cpp:2082–2095` | [M] no reader outside `src/config.cpp` at the pin (`git grep -n GetMinerIdCacheSize 6504a3af -- src`: the getter's definition and declarations only) |
| `-mineridnumtokeep` | policy (node setting) | optional; auxiliary `MinerIdConfig.numToKeep`, outside `NodeConfig` | 10, at least 2, `src/miner_id/miner_id_db_defaults.h:25` | `src/init.cpp:3041–3045`, `src/config.cpp:2101–2114` | `src/miner_id/miner_id_db.cpp:1307` |
| `-mineridreputation_m` | policy (node setting) | optional; auxiliary `MinerIdConfig.reputationM`, outside `NodeConfig` | 28, from 1 to N, `src/miner_id/miner_id_db_defaults.h:32–33` | `src/init.cpp:3046–3050`, `src/config.cpp:2120–2141` | `src/miner_id/miner_id_db.cpp:900,1341` |
| `-mineridreputation_n` | policy (node setting) | optional; auxiliary `MinerIdConfig.reputationN`, outside `NodeConfig` | 2016, from M to 26208, `src/miner_id/miner_id_db_defaults.h:28–29` | `src/init.cpp:3051–3055`, `src/config.cpp:2147–2168` | `src/miner_id/miner_id_db.cpp:386,499,1370` |
| `-mineridreputation_mscale` | policy (node setting) | optional; auxiliary `MinerIdConfig.mScaleNum / mScaleDen`, outside `NodeConfig` | 1.5, at least 1, `src/miner_id/miner_id_db_defaults.h:36` | `src/init.cpp:3056–3060`, `src/config.cpp:2174–2186` | `src/miner_id/miner_id_db.cpp:1064` |
| `-mineridgeneratorurl` | policy (node setting) | optional; unmodelled, outside `MinerIdConfig` and `NodeConfig` (the node's own mining service) | unset (read only when set) | `src/init.cpp:3061–3067`, `src/config.cpp:2193` | `src/rpc/client_config.cpp:166–170` |
| `-mineridgeneratoralias` | policy (node setting) | optional; unmodelled, outside `MinerIdConfig` and `NodeConfig` (the node's own mining service) | empty string, `src/init.cpp:3068` | `src/init.cpp:3068–3071`, `src/config.cpp:2240` | `src/net/net_processing.cpp:2062,2108` |

[D] The guard still censuses 81 chain fields: #83 adds zero `NodeConfig` fields;
incorporation of `MinerIdConfig` into `NodeConfig` remains debt; a GREEN census does
not discharge it.

### 8.6 Auxiliary P2P relay settings (#78)

[D] 2026-10-15 12:2x UTC. Nothing of the P2P layer is a block-validity
rule: it decides what a node hears and when, never what is valid. The payload caps
are the inputs of `CapInputs` in `lean/BsvChain/Wire/P2P.lean` (section 6), outside
`NodeConfig`; the transaction-size bound and the block size they read are the census
rows `maxTxSizeConsensusAfterGenesis` and `excessiveBlockSize` above, named here and
never restated. The relay machine's settings are the fields of the auxiliary
`RelayConfig` in `lean/BsvChain/Wire/Relay.lean` (section 1), outside `NodeConfig`;
`RelayConfig.broadcastMax`, the items one inventory flush takes, is derived from
the census row `excessiveBlockSize` (`INVENTORY_BROADCAST_MAX_PER_MB` = 7 * 5 per
megabyte, `src/validation.h:165,170`; `src/net/net_processing.cpp:515–518`), 35
for the scenario's 1000001 bytes. [SRC] Reference pin `6504a3aff65ba97c0f6c80962b033e35ecbfed4b`.

| node setting | kind | presence | default and source | launch/definition site [SRC] | read site [SRC] |
|---|---|---|---|---|---|
| `-maxprotocolrecvpayloadlength` | policy (node setting) | optional; auxiliary `CapInputs.maxRecvPayload`, outside `NodeConfig` | 2 MiB (`2 * 1024 * 1024`), from 1 MiB to one gigabyte, `src/protocol.h:33,40,45` | `src/init.cpp:1566,3326–3331`, `src/config.cpp:78,2286–2307` | `src/protocol.cpp:88–93` (every command neither `protoconf`, `tx`, `datareftx`, `getblocktxn` nor block-like); the header's cap `src/net/net_message.cpp:22–26` |
| `-banscore` | policy (node setting) | optional; auxiliary `RelayConfig.banScore`, outside `NodeConfig` | 100, at least 1, `src/validation.h:191` | `src/init.cpp:646–650,2703–2706`, `src/config.cpp:118,1449–1462` | `src/net/net_processing.cpp:621–628`; the `version` user-agent ban `:1753–1757` |
| `-bantime` | policy (node setting) | optional; auxiliary `RelayConfig.banTime`, outside `NodeConfig` | 86400 seconds, `src/net/net.h:152` | `src/init.cpp:651–653` | `src/net/net.cpp:545–549` |
| `-blocksonly` | policy (node setting) | optional; auxiliary `RelayConfig.blocksOnly`, outside `NodeConfig` | `false`, `src/net/net.h:121`; also sets `-whitelistrelay` false softly, `src/init.cpp:2018–2021` | `src/init.cpp:361–364,3691` | `src/net/net_processing.cpp:2463–2469,3356–3364` |
| `-whitelistrelay` | policy (node setting) | optional; auxiliary `RelayConfig.whitelistRelay`, outside `NodeConfig` | `true`, `src/validation.h:71` | `src/init.cpp:851–855,2712–2714` | `src/net/net_processing.cpp:2467–2469,3358–3359` |
| `-whitelistforcerelay` | policy (node setting) | optional; auxiliary `RelayConfig.whitelistForceRelay`, outside `NodeConfig` | `true`, `src/validation.h:73`; sets `-whitelistrelay` true softly, `src/init.cpp:2027–2030` | `src/init.cpp:856–860,2715–2717` | `src/net/net_processing.cpp:3399–3406`; `src/validation.cpp:2053–2081` (read from the arguments there, not the config) |
| `-broadcastdelay` | policy (node setting) | optional; auxiliary `RelayConfig.invBroadcastDelayMs`, outside `NodeConfig`; recorded, not read (time abstracted) | 150 ms, at most 50000, `src/net/net_processing.h:15–17` | `src/init.cpp:703–706,3618–3623` | `src/net/net_processing.cpp:602–608,5601–5606` |
| `-txnpropagationfreq` | policy (node setting) | optional; auxiliary `RelayConfig.propagationFreqMs`, outside `NodeConfig`; recorded, not read (time abstracted) | 250 ms, `src/txn_propagator.h:70` | `src/txn_propagator.cpp:17–19` | `src/txn_propagator.cpp:143–153` |
| `-recvinvqueuefactor` | policy (node setting) | optional; read through `RelayConfig.askForCap` (174762 at the defaults, `askForCap_default`), outside `NodeConfig` | 3, from 1 to 100, `src/protocol.h:57,62–63` | `src/init.cpp:1571–1575,3334–3338` | `src/net/net.cpp:3271–3280` |

[D] The constant caps beside the setting: `protoconf` at 1 MiB (`src/protocol.cpp:65–69`),
`tx` and `datareftx` at the consensus transaction-size bound (`:70–75`), `getblocktxn`
at the block size over 215 times 6 plus its header (`:76–87`), the block-like commands
(`block`, `cmpctblock`, `blocktxn`, `hdrsen`, `:55–61`) at the block size (`:94–98`).
A header over its command's cap is a ban without a misbehavior increment
(`src/net/net_message.cpp:22–26`, `src/net/association.cpp:396–401`); the ban's causes are
`BanCause` in `lean/BsvChain/Wire/Relay.lean`.

[D] The guard still censuses 81 chain fields: #78 adds zero `NodeConfig` fields;
incorporation of `CapInputs` and `RelayConfig` into `NodeConfig` remains debt; a GREEN
census does not discharge it.

### 8.7 Auxiliary persistence setting (#81)

[D] 2026-10-15: numbered 8.6 on its branch; renumbered 8.7 at the stack, after #78's 8.6 landed before it.

[D] 2026-10-15. `-persistmempool` decides whether a node writes its two pools to the data
directory at shutdown and reads them back at its next start; it is a node setting, policy, never consensus.
It is the field of the auxiliary `PersistConfig` in `lean/BsvChain/Persist.lean`, outside `NodeConfig`; the
transitions it gates are `Persist.shutdown` and `Persist.start`, and their laws are
`lean/BsvChain/Properties/Persist.lean`. Scope and run are in the #81 record (`docs/records/*-s7-81-persist-s1.md`).
[SRC] Reference pin `6504a3aff65ba97c0f6c80962b033e35ecbfed4b`.

| node setting | kind | presence | default and source | launch/definition site [SRC] | read site [SRC] |
|---|---|---|---|---|---|
| `-persistmempool` | policy (node setting) | optional; auxiliary `PersistConfig.persistMempool`, outside `NodeConfig` | `true` (on), `src/validation.h:197-198`; a wallet build soft-sets it off under `-zapwallettxes` (`src/wallet/wallet.cpp:4301-4306`); the node of record has no wallet | `src/init.cpp:495-498` (the help text) | `src/init.cpp:237-240` (the dump at shutdown, also gated by the start's completed load, `:158,1904`), `src/init.cpp:1901-1905` (the load after the best chain's activation), `src/init.cpp:3548` → `src/txmempool.cpp:3030-3038` (the transaction database's launch cross-check: with the setting off it is opened cleared), `src/init.cpp:3549-3551` (the sanity check resumed at once when off) |

[D] The load reads two settings already in the census at their launch values: `mempoolExpiry` (§8.2,
`src/txmempool.cpp:3163,3209`) and `mempoolNonFinalExpiry` (§8.2, `src/time_locked_mempool.cpp:325,400-405`).
With the setting off a start reads nothing and a shutdown writes nothing, so an earlier run's files stay in the
data directory and a later start with the setting reads them (`stale_file_after_run_without`).

[SRC] Teranode v0.16.0 (`4edb60a40c6628ff0ef60231c2628efd7103fde5`) has no such setting and no pool file: a
validated transaction is written to the UTXO store with `unmined_since` set when it carries no mined block
(`stores/utxo/sql/sql.go:468-471`, the backend of the instance of record), and block assembly reloads the
store's unmined transactions at every start (`services/blockassembly/BlockAssembler.go:1299-1323`,
`loadUnminedTransactions` at `:3199`), with the parent-chain check on by default
(`settings/blockassembly_settings.go:50`, `blockassembly_onRestartValidateParentChain`) and the removal of
transactions it finds invalid off by default (`:52`, `blockassembly_onRestartRemoveInvalidParentChainTxs`);
`utxostore_unminedTxRetention` (144 blocks, `settings/utxostore_settings.go:12`) is the window after which
pruning preserves an unmined transaction's parents for its resubmission; it removes nothing at a restart. Survival across a restart is the store's durability there, not a
switch.

[D] The guard still censuses 81 chain fields: #81 adds zero `NodeConfig` fields; incorporation of
`PersistConfig` into `NodeConfig` remains debt; a GREEN census does not discharge it.

### 8.8 Auxiliary pruning settings (#82)

[D] 2026-10-15: numbered 8.6 on its branch; renumbered 8.8 at the stack, after #78's 8.6 and #81's 8.7.

[D] 2026-10-15 13:1x UTC. Nothing of pruning is consensus: it decides which of a node's own
block and undo files stay on disk, never which blocks are valid. The modelled settings are the fields of the
auxiliary `Config` in `lean/BsvChain/Views/Prune.lean` (section 1), outside `NodeConfig`, with
`minBlocksToKeep` the same setting as §8.2's `NodeConfig.minBlocksToKeep`; the setters' bounds are
`Config.valid`. The retention function is `manualSet` and `autoSet` over the block files `Store.addBlock`
builds; scope and corpus are in the [#82 record](records/20261015-130232-s7-82-prune-s1.md).
[SRC] Reference pin `6504a3aff65ba97c0f6c80962b033e35ecbfed4b`.

| node setting or data | kind | presence | default and source | launch/definition site [SRC] | read site [SRC] |
|---|---|---|---|---|---|
| `-prune` | policy (node setting) | optional; auxiliary `Config.mode` (`modeOfArg`), outside `NodeConfig` | 0, off; 1 the RPC only (the target the largest `uint64_t`); n of 550 or more an automatic target of n MiB; a negative value or 2 to 549 refuses to launch, `src/init.cpp:2815-2838`, `src/validation.h:305`; the same on every network (a global constant, no chainparams member) | `src/init.cpp:2815-2838`, `src/validation.cpp:98,101` | `src/validation.cpp:3840-3846`, `src/blockfileinfostore.cpp:177-300`, `src/rpc/blockchain.cpp:1826-1830` |
| `-pruneminblockstokeep` | policy (node setting) | optional; §8.2's `NodeConfig.minBlocksToKeep`, mirrored by `Config.minBlocksToKeep` | 288, at least 6, `src/validation.h:272,274`, `src/config.cpp:100,1209-1226`; the same on every network (a global constant, no chainparams member) | `src/init.cpp:2841-2843` | `src/blockfileinfostore.cpp:189-194,248-250`, `src/rpc/blockchain.cpp:1867-1871` |
| `-prunehysteresis` | policy (node setting) | optional; auxiliary `Config.hysteresis`, outside `NodeConfig` | 25, from 0 to 99, `src/validation.h:280`, `src/config.cpp:101,1228-1244`; the same on every network (a global constant, no chainparams member) | `src/init.cpp:2846-2848` | `src/blockfileinfostore.cpp:261` |
| `-preferredblockfilesize` | policy (node setting) | optional; auxiliary `Config.preferredBlockFileSize`, outside `NodeConfig` | 0x8000000 (128 MiB), `src/validation.h:99`, `src/config.cpp:34`; the same on every network (a global constant, no chainparams member) | `src/init.cpp:2473-2475` | `src/blockfileinfostore.cpp:29-38` |
| `-maxmerkletreememcachesize` | policy (node setting) | optional; unmodelled, decides `Held.treeHeld` | 64 bytes per 4,000 bytes of the lesser of the block size and mempool limits, `src/merkletree.h:64-70` over `src/init.cpp:3298`; per network through the block size default (`src/chainparams.cpp:1174,1288,1435,1543` `defaultBlockSizeParams`) and the mempool limit, not measured | `src/init.cpp:3307-3311` | `src/merkletreestore.cpp:577-602` |
| `-maxmerkletreediskspace` | policy (node setting) | optional; unmodelled, decides `Held.treeHeld` | 288 times the preferred tree size, divided by 20, `src/merkletree.h:72-76` over `src/init.cpp:3298`; per network through the block size default (`src/chainparams.cpp:1174,1288,1435,1543` `defaultBlockSizeParams`) and the mempool limit, not measured | `src/init.cpp:3313-3324` | `src/merkletreestore.cpp:128-200` |
| `nPruneAfterHeight` | per-network data (policy) | `PruneNetwork.pruneAfterHeight` (the four records `PruneNetwork.mainnet`, `.stn`, `.testnet`, `.regtest`), outside `ChainParams` | mainnet 100,000 `src/chainparams.cpp:1092`; STN 1,000 `:1252`; testnet 1,000 `:1383`; regtest 1,000 `:1509` | `src/chainparams.h:87,119` | `src/validation.cpp:3845-3846`, `src/blockfileinfostore.cpp:240`, `src/rpc/blockchain.cpp:1860` |

[X] 2026-10-15: the four regtest instances of the record ran `-prune=1` with `-preferredblockfilesize=4096`,
`-pruneminblockstokeep=2000`, no `-prune`, and `-prune=550`; `-prune=549` and `-prune=-1` refused to launch
with the messages `modeOfArg` gives. The automatic selection's two inputs that a regtest run does not reach
(usage at a 550 MiB target, the coins database's flushed height) are the function's arguments, not measured.

[D] The guard still censuses 81 chain fields: #82 adds zero `NodeConfig` fields; incorporation of the
auxiliary `Config` into `NodeConfig` remains debt; a GREEN census does not discharge it.
### 8.9 The second oracle's chain-selection settings (#93)

[D] 2026-10-15: numbered 8.6 on its branch; renumbered 8.9 at the stack, after #78's 8.6, #81's 8.7 and #82's 8.8.

[D] 2026-10-15. Nothing here is consensus: each is a Teranode node setting the
second oracle's chain selection reads, recorded beside the reference's machine, never as its
rule (DESIGN-S6 §5.2). The three are the fields of the auxiliary `ChainSettings` in
`lean/BsvChain/Teranode/Chain.lean` (section 2), outside `NodeConfig`; the reference has no
counterpart (it validates a block in full before it can become the tip,
`src/validation.cpp:4561-4824` at `6504a3af`). Optimistic mining's obligation is the module's
`Validated` (every stored row validated in full), which `addBlock_validated_at_defaults` discharges
at the defaults. [SRC] Teranode v0.16.0 at `4edb60a40c6628ff0ef60231c2628efd7103fde5`.

| node setting | kind | presence | default and source | read site [SRC] |
|---|---|---|---|---|
| `blockvalidation_optimistic_mining` | policy (node setting) | optional; auxiliary `ChainSettings.optimisticMining`, outside `NodeConfig` | `true`, `settings/settings.go:375`, `settings/blockvalidation_settings.go:56` | `services/blockvalidation/BlockValidation.go:2166-2176` |
| `blockvalidation_optimistic_mining_peer_blocks` | policy (node setting) | optional; auxiliary `ChainSettings.optimisticMiningPeerBlocks`, outside `NodeConfig` | `false`, `settings/settings.go:376`, `settings/blockvalidation_settings.go:57` | `services/blockvalidation/BlockValidation.go:2166-2176`, `services/blockvalidation/Server.go:1656-1666` |
| `utxostore_unminedTxRetention` | policy (node setting) | optional; auxiliary `ChainSettings.unminedTxRetention`, outside `NodeConfig` | `global_blockHeightRetention / 2`, 144 blocks at the defaults, `settings/settings.go:33,480`, `settings/utxostore_settings.go:12` | `stores/utxo/aerospike/longest_chain.go:77`, `stores/utxo/sql/sql.go:4937` |

[D] Optimistic mining runs only when both flags are on, and never on the legacy, catch-up or
revalidation paths; `settings.conf` at the tag sets neither key, so the instance of record runs
with it off on every path (`optimistic_off_at_defaults`). With it on, a block is stored, and can
be the best header, before its merkle root, coinbase, duplicate, ordering, parent-spend and
old-block-ID checks have run (`BlockValidation.go:2238-2401`; the witness
`optimistic_best_pending`). The census of 81 chain fields is unchanged: #93 adds zero
`NodeConfig` fields.
### 8.10 The authority over the operator lists (#94)

[D] 2026-10-15: numbered 8.6 on its branch; renumbered 8.10 at the stack, after #78's 8.6, #81's 8.7, #82's 8.8 and #93's 8.9.

[D] 2026-10-15 13:3x UTC. Who may change the frozen-output list, the confiscation
whitelist, a block's validity mark and the ban list is **a node setting, policy**, on both nodes:
it decides who writes the lists, never what a list does to a spend, and never which block is valid
for a node with the same lists. **The parameter set is the same; the trust root differs.** The
reference takes the lists from its RPC server, under the credential the operator configures;
Teranode takes them from its in-process alert service, under signed alert messages. The actions
and their agreement are `lean/BsvChain/Teranode/Alert.lean` (the theorem
`trust_root_changes_who_not_what`, [D] by construction: whichever authority admits a request, the
gate applies the same action; whether the two nodes' actions agree is the module's §4 and §5); the
lists themselves stay the operator-list mechanism of §8.2 (#70). The rows are auxiliary, outside
`NodeConfig`, like §8.5's. [SRC] Reference pin `6504a3aff65ba97c0f6c80962b033e35ecbfed4b`; Teranode
pin `4edb60a40c6628ff0ef60231c2628efd7103fde5`; the alert library go-alert-system v0.1.17 (Teranode's
`go.mod:197`, its module sum in Teranode's `go.sum`), read from the module proxy on
2026-10-15T13:16:16Z, the sum matching (the read and its URLs: `docs/PROVENANCE.md` §6).

| node | setting | kind | default and source [SRC] | what it authorizes [SRC] |
|---|---|---|---|---|
| reference | `-rpcuser` / `-rpcpassword` | policy (node setting) | unset: an empty `-rpcpassword` selects cookie authentication, a random credential written to the data directory (`src/httprpc.cpp:344-366`) | every RPC, the frozen-TXO table among them: `addToPolicyBlacklist`, `addToConsensusBlacklist`, `removeFromPolicyBlacklist`, `queryBlacklist`, `clearBlacklists`, `addToConfiscationTxidWhitelist`, `clearConfiscationWhitelist`, `queryConfiscationTxidWhitelist` (`src/rpc/frozentxo_rpc.cpp:897-915`), `invalidateblock` (`src/rpc/blockchain.cpp:2732-2760,3822`) and `setban` (`src/rpc/net.cpp:669-757,897`); a request without the credential is refused 401 (`src/httprpc.cpp:278-310`, the check `RPCAuthorized` `:130-154`) |
| reference | `-rpcauth` | policy (node setting) | unset (`src/httprpc.cpp:83-128`) | further user and salted-hash pairs admitted by the same check (`multiUserAuthorized`, `:85`) |
| reference | `-bantime` | policy (node setting) | `DEFAULT_MISBEHAVING_BANTIME`, 86400 s (`src/net/net.h:152`) | the ban length of a `setban add` with no time (`src/net/net.cpp:545-549`); the standalone alert system passes none (go-alert-system v0.1.17 `app/config/node.go:65-68`) |
| Teranode | `alert_genesis_keys` | policy (node setting) | the setting's default is the empty list (`settings/settings.go:198`); the shipped `settings.conf:184` lists five public keys | the keys the alert service stores as active at its genesis alert (go-alert-system `app/models/genesis_alert.go:25-40`); an alert carries three 65-byte signatures (`app/models/alert_message.go:288-314`), each checked against the active keys (`AreSignaturesValid`, `:159-204`; the active keys `app/models/public_key.go:68-93`), which a signed set-keys alert replaces (`app/models/alert_message_set_keys.go`); the service refuses to start with none (`services/alert/server.go:369-370`) |
| Teranode | `alert_topic_name` | policy (node setting) | `bitcoin_alert_system` (`settings/settings.go:202`; `settings.conf:201`), read on mainnet only: off mainnet the topic is `bitcoin_alert_system_<network>` whatever the setting (`services/alert/server.go:332-337`) | the P2P topic on which the node takes alerts |
| Teranode | `alert_protocol_id` | policy (node setting) | `/bitcoin/alert-system/1.0.0` (`settings/settings.go:200`) | the libp2p protocol of the alert network |
| Teranode | `startAlert` | policy (node setting) | `true` in the base context (`settings.conf:1299`), `false` in `docker.m` and `operator` (:1300-1301) | whether the service runs; the node interface it drives is `services/alert/node.go` (`InvalidateBlock` :160, `BanPeer` :189, `UnbanPeer` :229, `AddToConsensusBlacklist` :274, `AddToConfiscationTransactionWhitelist` :397) |
| Teranode | `utxostore_reassignedUtxoSpendableAfterBlocks` | policy (node setting) | 1000 (`settings/settings.go:528`), read by the SQL backend only (`settings/utxostore_settings.go:54`) | the delay before a reassigned output is spendable (`stores/utxo/sql/alert_system.go:172-177`); Aerospike uses the constant `ReAssignedUtxoSpendableAfterBlocks` (`stores/utxo/Interface.go:46-48`) |

[D] The same alert reaches the reference through the standalone alert system, which calls the
node's RPC with the operator's credential (go-alert-system v0.1.17 `app/config/node.go:58-91`), so
on the reference the alert's keys stand behind the RPC credential and the node checks only the
credential. Where the two nodes then differ is in the actions, not the authority: the witnesses of
`lean/BsvChain/Teranode/Alert.lean` §5 (an unfreeze that keeps or drops the policy freeze, an
interval's start and stop, confiscation by reassignment with a 1,000-block gate in place of a
transaction whitelist, the ban's length). The scenario that freezes an output on both nodes is
`corpus/scenarios/2026-10-15-alert-freeze-output.md`, its node column owed to #66's cut 2.

### 8.11 Auxiliary compact-block settings (#79)

[D] 2026-10-15 16:3x UTC. Nothing of compact blocks is a block-validity rule: the
encoding decides how a node receives a block it may partly hold, never whether the block is valid;
the reconstruction ends in the reference's `CheckBlock`, which is #63's `checkBlock` and the judge
here as everywhere. The settings and constants the procedure reads are the fields of the auxiliary
`CompactConfig` in `lean/BsvChain/Wire/CompactBlocks.lean` (section 4), outside `NodeConfig`, each
policy or a relay constant; the block size `InitData` reads is the census row `excessiveBlockSize`
above, named here and never restated. [SRC] Reference pin `6504a3aff65ba97c0f6c80962b033e35ecbfed4b`.

| node setting or constant | kind | presence | default and source | launch/definition site [SRC] | read site [SRC] |
|---|---|---|---|---|---|
| `-maxblocktxnpercent` | policy (node setting) | optional; auxiliary `CompactConfig.maxBlockTxnPercent`, outside `NodeConfig` | 99, at most 100, `src/net/net.h:137` | `src/init.cpp:736-740,2706`, `src/config.cpp:1469-1486` | `src/net/net_processing.cpp:2744-2758`: a `getblocktxn` for more of the block's transactions is answered with the whole block |
| `-blockreconstructionextratxn` | policy (node setting) | optional; auxiliary `CompactConfig.extraTxnCap`, outside `NodeConfig` | 100, `src/orphan_txns.h:52` | `src/init.cpp:1425-1428`, `src/txn_validator.cpp:30-34` | the ring of extra transactions `InitData` also matches (`src/orphan_txns.cpp:406-417`; `src/blockencodings.cpp:201-234`) |
| `MAX_CMPCTBLOCK_DEPTH` | relay constant | auxiliary `CompactConfig.cmpctDepth` | 5, `src/validation.h:132` | (a constant) | `src/net/net_processing.cpp:1336-1340`: a deeper block asked for as a compact block is sent whole |
| `MAX_BLOCKTXN_DEPTH` | relay constant | auxiliary `CompactConfig.blockTxnDepth` | 10, `src/validation.h:136` | (a constant) | `src/net/net_processing.cpp:2818-2830`: a deeper block's `getblocktxn` is answered with the whole block |
| the bucket bound | relay constant (an implementation's) | auxiliary `CompactConfig.bucketCap`; the Lean function takes the outcome as the input `crowded` | 12 entries in one bucket of the standard library's table, `src/blockencodings.cpp:157-160` | (a constant) | the same lines: a crowded bucket fails the message (FAILED, the whole block requested) |

[D] `extraTxnCap`, `cmpctDepth`, `blockTxnDepth` and `bucketCap` are carried for the census and
read by no function in `lean/BsvChain/Wire/CompactBlocks.lean`: the depth answers and the ring are
outside the model, the bucket bound an input; only `maxBlockTxnPercent` is read
(`answerGetBlockTxn`, whose integer comparison agrees with the source's `double` at the default 99
and differs at some other settings (p = 7, k = 7, n = 100), its docstring's `[D]`).

[D] The guard still censuses 81 chain fields: #79 adds zero `NodeConfig` fields; incorporating
`CompactConfig` with #78's `CapInputs` and `RelayConfig` into `NodeConfig` remains the debt named in
section 8.6; a GREEN census does not discharge it.

### 8.12 Auxiliary double-spend notification settings (#80)

[D] 2026-10-15 18:40 UTC: renumbered from 8.11 at the stacking rebase (#79's compact-block
settings landed earlier as 8.11 in stack P); the records written before it cite 8.11 and stand.

[D] 2026-10-15 16:3x UTC. **A notification is never a verdict.** Every row here is
a **policy (node setting)**: it decides whom a node tells about a double spend it refused, or
where it posts a peer's report of blocks carrying one, never whether a transaction or a block
is valid. The settings are the fields of the auxiliary `DSConfig` in
`lean/BsvChain/Wire/DoubleSpend.lean` (section 4), outside `NodeConfig`; the handler's
constants beside them are fixed in the source, not settings. The refusal itself is #62's
machine; the ban score a failed script check applies is §8.6's `-banscore`, and the fork
distance a `dsdetected` message is held to is the census row `safeModeMaxForkDistance` (§8.2),
named here and never restated; the handler's own script check runs under the census row
`maxNonStdTxnValidationDuration` (§8.2; src/double_spend/dsattempt_handler.cpp:165), its expiry the check's `cancelled`. [SRC] Reference pin `6504a3aff65ba97c0f6c80962b033e35ecbfed4b`.

| node setting | kind | presence | default and source | launch/definition site [SRC] | read site [SRC] |
|---|---|---|---|---|---|
| `-dsnotifylevel` | policy (node setting) | optional; auxiliary `DSConfig.level`, outside `NodeConfig` | 0, no notifications (`DEFAULT_NOTIFY_LEVEL`, `src/double_spend/dsattempt_handler.h:39-44,63`); 1 standard inputs only, 2 every input; outside 0 to 2 refused (`src/config.cpp:1703-1717`) | `src/init.cpp:1577-1581,2955-2958` | `src/double_spend/dsattempt_handler.cpp:40-48,92-95,365` |
| `-dsendpointfasttimeout` | policy (node setting) | optional; auxiliary `DSConfig.fastTimeout`, outside `NodeConfig` | 5 s, above 0 (`src/rpc/client_config.h:25`; `src/config.cpp:1723-1736`) | `src/init.cpp:1582-1585,2961-2963` | `src/double_spend/dsattempt_handler.cpp:563-564` |
| `-dsendpointslowtimeout` | policy (node setting) | optional; auxiliary `DSConfig.slowTimeout`, outside `NodeConfig` | 60 s, above 0 (`src/rpc/client_config.h:26`; `src/config.cpp:1742-1755`) | `src/init.cpp:1586-1589,2967-2969` | `src/double_spend/dsattempt_handler.cpp:669-670` |
| `-dsendpointslowrateperhour` | policy (node setting) | optional; auxiliary `DSConfig.slowRatePerHour`, outside `NodeConfig`; recorded, its leaky bucket an input (`Env.slowEndpoint`) | 3 timeouts an hour, from 1 to 60 (`src/double_spend/dsattempt_handler.h:54`; `src/config.cpp:1761-1774`) | `src/init.cpp:1590-1595,2972-2974` | `src/double_spend/dsattempt_handler.cpp:528-536` |
| `-dsendpointport` | policy (node setting) | optional; auxiliary `DSConfig.endpointPort`, outside `NodeConfig`; a debug-help option | 80, from 1 to 65535 (`src/rpc/client_config.h:24`; `src/config.cpp:1780-1793`); the callback message carries no port | `src/init.cpp:1597-1600,2978-2981` | `src/rpc/client_config.cpp:95-96` |
| `-dsendpointblacklistsize` | policy (node setting) | optional; auxiliary `DSConfig.blacklistSize`, outside `NodeConfig`; a debug-help option | 1000 endpoints, above 0 (`src/double_spend/dsattempt_handler.h:49`; `src/config.cpp:1818-1831`) | `src/init.cpp:1601-1604,2983-2985` | `src/double_spend/dsattempt_handler.cpp:82`; the limit `src/double_spend/time_limited_blacklist.h:26-28` |
| `-dsendpointskiplist` | policy (node setting) | optional; auxiliary `DSConfig.skipList`, outside `NodeConfig` | empty (`src/config.cpp:1837-1849`, a comma-separated list) | `src/init.cpp:1606-1610,2988-2990` | `src/double_spend/dsattempt_handler.cpp:566-567,606-609` |
| `-dsendpointmaxcount` | policy (node setting) | optional; auxiliary `DSConfig.maxEndpoints`, outside `NodeConfig` | 3 addresses a notification, above 0 (`src/double_spend/dsattempt_handler.h:56`; `src/config.cpp:1855-1868`) | `src/init.cpp:1611-1614,2992-2994` | `src/double_spend/dsattempt_handler.cpp:574-579` |
| `-dsattempttxnremember` | policy (node setting) | optional; auxiliary `DSConfig.txnRemember`, outside `NodeConfig` | 1000 transactions, above 0 (`src/double_spend/dsattempt_handler.h:47`; `src/config.cpp:1799-1812`) | `src/init.cpp:1615-1619,2997-2999` | `src/double_spend/dsattempt_handler.cpp:81,404-414,769-777` |
| `-dsattemptnumfastthreads` | policy (node setting) | optional; auxiliary `DSConfig.fastThreads`, outside `NodeConfig`; recorded, not read (scheduling abstracted) | 2, from 1 to 64 (`src/double_spend/dsattempt_handler.h:51,59`; `src/config.cpp:1874-1888`) | `src/init.cpp:1620-1624,3002-3004` | `src/double_spend/dsattempt_handler.cpp:40-48,83` |
| `-dsattemptnumslowthreads` | policy (node setting) | optional; auxiliary `DSConfig.slowThreads`, outside `NodeConfig`; recorded, not read (scheduling abstracted) | 2, from 1 to 64 (`src/double_spend/dsattempt_handler.h:52,59`; `src/config.cpp:1894-1908`) | `src/init.cpp:1625-1629,3007-3009` | `src/double_spend/dsattempt_handler.cpp:40-48,84` |
| `-dsattemptqueuemaxmemory` | policy (node setting) | optional; auxiliary `DSConfig.queueMaxMemory`, outside `NodeConfig` | 4096 MiB, above 0 (`src/double_spend/dsattempt_handler.h:61`; `src/config.cpp:1914-1927`; read in MiB, `src/init.cpp:3012-3014`) | `src/init.cpp:1630-1634,3012-3014` | `src/double_spend/dsattempt_handler.cpp:127-134` |
| `-dsdetectedwebhookurl` | policy (node setting) | optional; auxiliary `DSConfig.webhook`, outside `NodeConfig` | unset: no post; an `http` URL only, its port 80 when absent (`src/config.cpp:1985-2017`; `src/rpc/webhook_client_defaults.h:27`) | `src/init.cpp:1636-1639,3017-3022` | `src/net/net_processing.cpp:4668-4677`; `src/rpc/client_config.cpp:140-159` |
| `-dsdetectedwebhookmaxtxnsize` | policy (node setting) | optional; auxiliary `DSConfig.webhookMaxTxnSize`, outside `NodeConfig` | 100 MiB, above 0; a larger transaction is posted by its id (`src/double_spend/dsdetected_defaults.h:16`; `src/config.cpp:2032-2045`; read in MiB, `src/init.cpp:3024-3027`) | `src/init.cpp:1640-1645,3024-3027` | `src/double_spend/dsdetected_message.cpp:131-134`; `src/merkleproof.cpp:51-59` |

[D] The handler's constants, not settings (`src/double_spend/dsattempt_handler.cpp` at the pin):
an endpoint's blacklist term `ENDPOINT_BLACKLIST_DURATION` 3600 s (:28), the supported protocol
version 1 (:31), the response header `x-bsv-dsnt` (:34), two attempts at a proof
(`MAX_PROOF_SUBMIT_ATTEMPTS`, :37), and the suspension score of a peer whose double spends time
out validating (`SUSPENSION_SCORE_MAX` 100, `SUSPENSION_SCORE_INCREASE` 10,
`SUSPENSION_DURATION` 600 s, :20-25); the webhook client's three attempts (`NumHTTPRetries`,
`src/rpc/webhook_client.cpp:13`) and its four threads (`-rpcwebhookclientnumthreads`,
`src/rpc/webhook_client_defaults.h:23`, a setting of the webhook client recorded and not
modelled); the `dsdetected` duplicate cache of 1000 messages and its penalty 10
(`src/net/net_processing.cpp:4580,4602-4603`).

[D] The guard still censuses 81 chain fields: #80 adds zero `NodeConfig` fields; incorporation
of `DSConfig` into `NodeConfig` remains debt, beside §8.6's `CapInputs` and `RelayConfig`.
