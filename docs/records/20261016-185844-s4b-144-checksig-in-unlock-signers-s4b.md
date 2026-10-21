# #144: a CHECKSIG executing in the unlocking script after Chronicle: the signers, the verifiers, the witness (S4b, lane xsig-144)

[M] 2026-10-16, lane xsig-144 (S4b with S3's commits), Claude Opus 5.5, on the box. Base `origin/main` at `e08acd20`.
The full witness (every transaction's hex, the funding transactions, the reference's verdict fields, the byte checks):
[`20261016-185844-s4b-144-witness.json`](20261016-185844-s4b-144-witness.json). The corpus: `corpus/xsig-144/xsig-144.jsonl` (12 entries,
every column recorded), its manifest `corpus/xsig-144/manifest.json` (moved from `corpus/crypto/` by lane fix-xsig-144, the bytes
unchanged, so the four witness manifests carry it as `xsig-144`; see the checks). The tool: `tools/xsig_witness.py`, with
`tools/xsig/gosign` (go-sdk's signer side) and `tools/xsig/tssign.mjs` (@bsv/sdk's). Measured under ALL|FORKID (BIP143); the
OTDA digest selected by the CHRONICLE hash-type bit carries the same scriptCode at the source and was not measured here
(go-sdk's test runs both, `chronicle_scriptsig_checksig_test.go:57-60`).

## The question (the owner, 2026-10-16, from feedback he received, verbatim from #144)

> "SDK builds the wrong receipt digest: BSV's Chronicle path appends the spent locking script when CHECKSIG executes inside the unlocking script. The SDK omits those bytes."

## The pins

- The reference: bitcoin-sv v1.2.3 `6504a3af` (docs/PROVENANCE.md §1a), source read with `git -C ~/bsv/bitcoin-sv show v1.2.3:<path>`;
  the binary `~/bsv/targets/sv-v1.2.3/bin/bitcoind` (`/Bitcoin SV:1.2.3/`).
- go-sdk v1.7.2 (`2ca481c5`), read in the module cache `~/go/pkg/mod/github.com/bsv-blockchain/go-sdk@v1.7.2` (the box's
  `~/bsv/go-sdk` clone describes as `v1.7.2`); the helper built offline (`GOPROXY=off GOTOOLCHAIN=local`, go1.27.0 from
  `~/bsv/targets/spec-box/toolchains/go/bin`) against the adapter's own `go.sum`.
- @bsv/sdk 3.0.0: the box holds no ts-stack clone; the source read is the published package's own (`dist/esm/src/**/*.js.map`,
  `sourcesContent`) in the ts adapter's `node_modules`, copied from `~/bsv/worktrees/spec-box-cap-l2/harness/engines/ts`
  after `cmp` found its `package-lock.json` byte-equal to the tree's (integrity `sha512-smQn/gxU...`). The line numbers
  below are that source's; `Spend.ts:1686-1691` is the line the captain cited from the clone, so the two agree there.
- The spec: `lean/` at the tree of `e08acd20` (tree `39acc6f8`); `eval/bsvs` is the binary built by the box's
  `spec-box-cap-l2` worktree for the same `lean` tree (`git rev-parse HEAD:lean` equal), its `.lake` copied, the wrapper's
  up-to-date check passed; no Lean build ran in this lane. Recorded as `spec@fb3558f2`.
- The engines: bsv-rs 0.5.0, the go-sdk adapter (`make gosdk-build`, offline), the ts adapter on node v22 (`tools/node_bin.sh`).

## What the reference does `[SRC]`

- `interpreter.cpp:1471-1481` (v1.2.3): the scriptCode is `{pbegincodehash, pend}`, the current script from its last
  OP_CODESEPARATOR; `if(checksigData && IsChronicle(flags))` it gets `*checksigData` appended. `1567-1577` is the same for
  CHECKMULTISIG. `VerifyScript` passes `&scriptPubKey` as `checksigData` when it evaluates the scriptSig (`2338-2342`), and
  nothing when it evaluates the scriptPubKey. Then `CleanupScriptCode` (`255-263`: no FindAndDelete under FORKID) and the
  digest (`SignatureHash`, `2112-2124`; BIP143 `2034-2083` for ALL|FORKID).
- `IsChronicle(flags)` is `SCRIPT_CHRONICLE`, set from the SPEND's block era (`verify_script_flags.cpp:77-78`), not the coin's.
- The scriptSig must be push-only after Genesis and before Chronicle for every version, and after Chronicle for version <= 1
  (`2321-2334`; `IsMalleableTxnVersion` is `version > 1`, `34-38`). The gate reads `SCRIPT_GENESIS`, `SCRIPT_CHRONICLE` and the
  version, not the SIGPUSHONLY bit alone, and the reference sets that bit only under Genesis in both words
  (`verify_script_flags.cpp:71-75`; `policy/policy.h:229-231`, `InputScriptVerifyFlags`). So a CHECKSIG in the unlock is
  reachable before Chronicle only before Genesis, and after Chronicle only in a transaction of version 2 or higher.
- The spec models it: `lean/BsvScript/Machine.lean:178-179` (`checksigData`), `lean/BsvScript/Impl/Crypto.lean:24-27`
  (`scriptCodeOfI`: `codeSep ++ lock` when `flags.chronicle`, else `codeSep`).

## The witness `[M]`

A fresh regtest instance of the reference (harness/oracle/bitcoin.conf's lines, regtest's activation heights replaced by
`genesisactivationheight=115`, `chronicleactivationheight=130`, and `maxgenesisgracefulperiod=0`,
`maxchroniclegracefulperiod=0`; RPC 127.0.0.1:18571, `listen=0`, no peer), started and stopped by the tool, its datadir
removed (`stopped_and_removed: true`). The regtest defaults are 10,000 and 15,000 (`chainparams.cpp:21, 26`), past
regtest's 150-block subsidy halving (`consensus.nSubsidyHalvingInterval = 150`, `chainparams.cpp:1460` at v1.2.3), so the heights were moved. 101 blocks to a P2PKH of the funder key, then:
three funding transactions (heights 102, 121, 132), each coin 100,000 sat, each spend version 2 paying 99,000 sat back.

Shape A (go-sdk's `chronicle_scriptsig_checksig_test.go:26-50, 62-66`): lock `<utxoPub> OP_CHECKSIG`; unlock
`<utxoSig> <sig0> OP_CODESEPARATOR <pub0> OP_CHECKSIGVERIFY`. The reference's scriptCode for sig0 is
`<pub0> OP_CHECKSIGVERIFY` ++ lock.

Shape B (the test's mainnet replay `:91-105`: the unlock ends `OP_CODESEPARATOR OP_CHECKSIGVERIFY OP_ENDIF`): lock
P2PKH(utxo); unlock `<utxoSig> <utxoPub> <P> OP_1 OP_IF <signer> <G> OP_CODESEPARATOR OP_CHECKSIGVERIFY OP_ENDIF`, where
`<signer>` computes in script the d = 1, k = 1 signature over hash256(P) (r = Gx, s = z + Gx mod n, DER, 0x41): the
OP_PUSH_TX pattern, valid exactly when P is the preimage the node hashes. The reference's scriptCode is
`OP_CHECKSIGVERIFY OP_ENDIF` ++ lock. The mainnet transaction's 1,265-byte covenant itself was not rebuilt; this shape keeps
its unlock's tail and its OP_PUSH_TX mechanism.

The four signing methods per shape: (a) go-sdk v1.7.2's `p2pkh.Unlock(key, nil).Sign` (A: its signature) and
`CalcInputPreimage` (B: its preimage), the input's source output set by `SetSourceTxOutput` to the real coin;
(b) @bsv/sdk 3.0.0's `new P2PKH().unlock(key).sign` with the input's `sourceTransaction` attached (A) and
`TransactionSignature.format({subscript: lock})` as that template passes it (B); (c) the reference's scriptCode, the
BIP143 preimage and the ECDSA signature computed in `tools/xsig_witness.py` (RFC 6979, low S); (d) the reference's
scriptCode passed by hand as `subscript` to @bsv/sdk's `TransactionSignature.format`, signed by `PrivateKey.sign` as the
template signs (A), or that preimage pushed (B).

The byte checks `[M]` (every coin of the eight, `checks` in the witness JSON): ALL EQUAL:
go-sdk's and @bsv/sdk's preimage over the lock equal the hand BIP143 preimage over the lock; @bsv/sdk's `format` with the
reference's scriptCode as `subscript` equals the hand preimage over it; go-sdk's `CalcInputPreimage` and
`CalcInputSignatureHash` after `SetSourceTxOutput` with the reference's scriptCode in place of the lock equal the hand
preimage and its hash256; @bsv/sdk's P2PKH template given the scriptCode in `unlock()`'s fifth parameter (`lockingScript`,
no `sourceTransaction`) produced the same signature as (d).

## The table `[M]`

Columns: the regtest chain (`sendrawtransaction`, then one block; an accepted spend confirmed by `getrawtransaction` with
its block hash), the reference through `verifyscript` (`run_svnode --record` on a fresh instance of the oracle's own
`bitcoin.conf`, mainnet heights; the entries place each coin at a mainnet height of its era: 967,896 post-Chronicle,
900,000 post-Genesis, 600,000 pre-Genesis), the spec (`eval/bsvs corpus`), go-sdk v1.7.2 and @bsv/sdk 3.0.0 under the
spec's block word (`run_engine --record`), @bsv/sdk's default mode (no word), bsv-rs 0.5.0 under the per-input words
(`run_bsvrs --record`, the manifest's `words: per-input`). The block-word cells; the mempool-word cells agree with them on every row.

| entry | shape | signing | regtest chain | reference (verifyscript) | spec | go-sdk | ts-sdk | ts-sdk default | bsv-rs |
|---|---|---|---|---|---|---|---|---|---|
| xsig-00001 | A | `pre-genesis/unlock-only` | accepted, mined h103 | valid | valid | valid | invalid SIG_NULLFAIL | invalid CHECKSIGVERIFY | undecided (pre-Genesis out of scope) |
| xsig-00002 | A | `pre-genesis/unlock+lock` | rejected: Signature must be zero for failed CHECK(MULTI)SIG operation | invalid SIG_NULLFAIL | invalid SIG_NULLFAIL | invalid SIG_NULLFAIL | valid | valid | undecided (pre-Genesis out of scope) |
| xsig-00003 | A | `pre-chronicle/unlock-only` | rejected: Only non-push operators allowed in signatures | invalid SIG_PUSHONLY | invalid SIG_PUSHONLY | invalid SIG_PUSHONLY | invalid SIG_PUSHONLY | invalid CHECKSIGVERIFY | invalid (push-only) |
| xsig-00004 | A | `pre-chronicle/unlock+lock` | rejected: Only non-push operators allowed in signatures | invalid SIG_PUSHONLY | invalid SIG_PUSHONLY | invalid SIG_PUSHONLY | invalid SIG_PUSHONLY | valid | invalid (push-only) |
| xsig-00005 | A | `a:go-sdk-lock-only` | rejected: Script failed an OP_CHECKSIGVERIFY operation | invalid CHECKSIGVERIFY | invalid CHECKSIGVERIFY | invalid CHECKSIGVERIFY | invalid CHECKSIGVERIFY | invalid CHECKSIGVERIFY | invalid (CHECKSIGVERIFY) |
| xsig-00006 | A | `b:ts-sdk-template-lock-only` | rejected: Script failed an OP_CHECKSIGVERIFY operation | invalid CHECKSIGVERIFY | invalid CHECKSIGVERIFY | invalid CHECKSIGVERIFY | invalid CHECKSIGVERIFY | invalid CHECKSIGVERIFY | invalid (CHECKSIGVERIFY) |
| xsig-00007 | A | `c:correct-scriptcode` | accepted, mined h133 | valid | valid | valid | valid | valid | valid |
| xsig-00008 | A | `d:ts-sdk-format-correct-subscript` | accepted, mined h133 | valid | valid | valid | valid | valid | valid |
| xsig-00009 | B | `a:go-sdk-lock-only` | rejected: Script failed an OP_CHECKSIGVERIFY operation | invalid CHECKSIGVERIFY | invalid CHECKSIGVERIFY | invalid CHECKSIGVERIFY | invalid CHECKSIGVERIFY | invalid CHECKSIGVERIFY | invalid (CHECKSIGVERIFY) |
| xsig-00010 | B | `b:ts-sdk-template-lock-only` | rejected: Script failed an OP_CHECKSIGVERIFY operation | invalid CHECKSIGVERIFY | invalid CHECKSIGVERIFY | invalid CHECKSIGVERIFY | invalid CHECKSIGVERIFY | invalid CHECKSIGVERIFY | invalid (CHECKSIGVERIFY) |
| xsig-00011 | B | `c:correct-scriptcode` | accepted, mined h133 | valid | valid | valid | valid | valid | valid |
| xsig-00012 | B | `d:ts-sdk-format-correct-subscript` | accepted, mined h133 | valid | valid | valid | valid | valid | valid |

Read across: on the eight post-Chronicle spends every verifier column agrees with the chain: the signatures (A) and
preimages (B) over the locking script alone, from either SDK's standard signing path, are refused
(`Script failed an OP_CHECKSIGVERIFY operation`), and the ones over the reference's scriptCode, by hand or through
@bsv/sdk's `format` with the scriptCode as `subscript`, are accepted and mined (block
`684e84716fb05f475dc99721b5f8ea006ba4344961295a6c6f202b34d324c6d0`, height 133). The spend must be version 2 or higher: after
Chronicle a version-1 transaction's unlocking script must still be push-only (`interpreter.cpp:2326-2327`), and both SDKs build
version 1 by default (go-sdk `transaction.go:40`, @bsv/sdk `Transaction.ts:582`). Every witness here is version 2.

## The pre-Chronicle gate `[M]`

- After Genesis and before Chronicle (xsig-00003/00004, the coin at 121, the spend at 122): every column judged under the
  reference's word (the chain, `verifyscript`, the spec, go-sdk, @bsv/sdk under the word, bsv-rs) refuses the non-push unlock
  before any signature is read (`SIG_PUSHONLY`, `interpreter.cpp:2321-2334`; the chain's text "Only non-push operators allowed
  in signatures" is the node's own description). @bsv/sdk's default mode, which reads the era from the version, judges these
  version-2 spends as after Chronicle: xsig-00004 valid, xsig-00003 `CHECKSIGVERIFY` (class `eras.default-mode.no-era`).
  @bsv/sdk's unconditional append is unobservable in this era under the word.
- Before Genesis (xsig-00001/00002, the coin at 102, the spend at 103): no SIGPUSHONLY and no SCRIPT_CHRONICLE in the word.
  The chain ACCEPTED the spend signed over the unlock alone (mined at 103) and refused the one signed over unlock ++ lock
  (NULLFAIL); the reference's `verifyscript`, the spec and go-sdk (`subScriptForChecksig`, `thread.go:1123-1125`, gated on
  `scriptflag.Chronicle`) say the same. @bsv/sdk under the word says the opposite on both rows: it appends the locking script
  in every era (`Spend.ts:1681-1692`; the CHRONICLE flag is read by `#enforceNonMalleability`, `343-345`, not by the
  append). Filed as the class `crypto.checksig.unlock.ungated` (impl-wrong) in `harness/rules/ts-sdk.json`. bsv-rs declares
  pre-Genesis out of scope (undecided: "pre-Genesis block rules are not implemented by this interpreter", bsv-rs 0.5.0
  `src/script/flags.rs:508`; the class `engine.word-out-of-scope` of `harness/rules/bsv-rs.json`).
- @bsv/sdk's default mode (no word: the era from the version, a v2 spend judged as after Chronicle) gives the
  post-Chronicle verdict on all four era rows (class `eras.default-mode.no-era`).

## The signer-side reading `[SRC]`

go-sdk v1.7.2, the signer. Every digest entry point takes an input index and a hash type, never a scriptCode:
`CalcInputSignatureHash` (`transaction/signaturehash.go:37`), `...Full` (`:60`), `...WithForkIDEnabled` (`:85`),
`...WithCache` (`:152`), `CalcInputPreimage` (`:175`), `...WithCache` (`:183`), `...Full` (`:195`), the legacy pair (`:308`,
`:321`). The BIP143 preimage embeds `scriptCode := *in.SourceTxScript()` (`:277`), the legacy one `subscript :=
in.SourceTxScript()` (`:367`); `SourceTxScript` is the source output's locking script (`transaction/input.go:53-59`), read from
`SourceTransaction` when one is attached and otherwise from the output set by `SetSourceTxOutput` (`:43-51`, `:231-233`). The
templates: `p2pkh.Sign` calls `CalcInputSignatureHash` (`transaction/template/p2pkh/p2pkh.go:85`; its struct carries the
comment "optionally could support a code separator index", `:58`), `pushdrop` the same (`pushdrop/pushdrop.go:213`). So no
documented entry point accepts a caller's scriptCode. The one exported function that takes a caller's script,
`BytesWithClearedInputs(index, lockingScript)` (`transaction/transaction.go:368-371`), serializes the signing input without its
outpoint and sequence (`:456-458`) and without a hash type, so it yields neither preimage; no non-test code of the module calls
it. The digest reads `SourceTxOutput().LockingScript`; set it to the scriptCode (via `SetSourceTxOutput` with no
`SourceTransaction`, as the helper here does, measured above: equal bytes, or by swapping the field in place as go-sdk's own
test signer does, `script/interpreter/chronicle_sighash_test.go:32-43`) and call `CalcInputSignatureHash`/`CalcInputPreimage`.
go-sdk's own verifier does the same on a `ShallowClone`, which drops `SourceTransaction` and copies the output
(`transaction/transaction.go:405-421`; `script/interpreter/operations.go:2140-2145`: `sourceTxOut.LockingScript = scriptCode`,
then `CalcInputSignatureHashWithForkIDEnabled`).

go-sdk v1.7.2, the verifier: `subScriptForChecksig` (`script/interpreter/thread.go:1123-1147`) appends the locking script
when the unlocking script is executing (`scriptIdx == 0`) and `scriptflag.Chronicle` is set (`:1125`); `checkSigScriptCode`
(`operations.go:2211`) applies CleanupScriptCode. It agrees with the reference on all twelve rows.

@bsv/sdk 3.0.0, the signer. `TransactionSignature.format(params)` (`primitives/TransactionSignature.ts:425`) hashes the
caller's `params.subscript` (`formatBip143`, `:394-396`; `formatOTDA`, `:262`): a caller's scriptCode is accepted. The
templates pass the source output's locking script: `P2PKH.unlock(privateKey, signOutputs, anyoneCanPay, sourceSatoshis?,
lockingScript?)` (`script/templates/P2PKH.ts:77-82`) resolves it through `resolveSourceDetails` (`SignatureUtils.ts:140-158`)
and hands it to `format` as `subscript` (`:209`); the fifth parameter replaces it only when no `sourceTransaction` is attached
(a different one beside an attached source output throws, `:146-152`). `PushDrop.unlock` has the same parameter
(`PushDrop.ts:217-232`); `RPuzzle.unlock` has none and requires the source transaction (`RPuzzle.ts:86-100`). So the default
call of every template signs over the locking script alone; `format` with the scriptCode, or P2PKH/PushDrop's fifth
parameter without a source transaction, produces the reference's digest (rows xsig-00008, xsig-00012).

@bsv/sdk 3.0.0, the verifier: `Spend.ts:1681-1692` appends the locking script whenever the context is the unlocking script;
after Chronicle that is the reference's scriptCode (all eight post-Chronicle rows agree); before Chronicle it is not
(xsig-00001/00002, above).

What a contract toolkit must do today to sign a shape-A or shape-B spend: compute the scriptCode itself (the unlocking
script from its last executed OP_CODESEPARATOR to its end, then the whole locking script) and pass it: with go-sdk, as the
`LockingScript` of an output given by `SetSourceTxOutput` with no `SourceTransaction` attached, then `CalcInputSignatureHash`
or `CalcInputPreimage`; with @bsv/sdk, as `subscript` to `TransactionSignature.format`, or as the fifth parameter of
`P2PKH.unlock`/`PushDrop.unlock` with no `sourceTransaction`. For OP_PUSH_TX (shape B) the pushed preimage is that
`format`/`CalcInputPreimage` output. The spend must be version 2 or higher: after Chronicle a version-1 transaction's unlocking
script must still be push-only (`interpreter.cpp:2326-2327`), and both SDKs build version 1 by default (go-sdk
`transaction.go:40`, @bsv/sdk `Transaction.ts:582`). Every witness here is version 2.

## An observation on the reference's mempool path `[M]` `[SRC]`

With the regtest heights a few blocks apart and the default grace periods (72, `policy/policy.h:128, 133`), the refused
spends' reply was `An exception thrown in txn processing: Can't create inverse of era for: Genesis` (and `...: Chronicle` on the
pre-Genesis row) instead of the script's error: inside a grace period (`validation.cpp:2729-2731`) the diagnosis of a failed
script asks `GetInverseProtocolEra` of the coin's era (`2768-2770`, `2792-2794`), which throws for a post-Chronicle coin under
Genesis and for a pre-Genesis coin under Chronicle (`protocol_era.cpp:49-86`). The verdict is the same refusal; the reason is
lost. It needs a spend inside one activation's grace window with a coin from outside the eras that activation pairs: mainnet's
heights (620,538 and 943,816) are 323,278 blocks apart, so the reading here is a regtest configuration's, recorded and not
carried further. The runs of record set both grace periods to 0 (`init.cpp:3244-3263`).

## The witness transactions (hex)

- xsig-00001 (A, `pre-genesis/unlock-only`): txid `1a0e27c1e03697c62d2ad0417c1624265b9b6beb466828866a1a9ed26e23926d` block `012d45e60ce0511505796105e7e86e4790c982c09c90e629b747b2e28e0f399f`; the coin `6cc298d10ea86c44d1dd56e77e6e1bc5df83c40195de0a5fcc2938d30ee9a76d:0` (regtest height 102, 100000 sat, lock `2102b1362bb654abcf1772fd7aea23ef20b19c5b27e3b75e44de8560261d93edfc72ac`); the reference's scriptCode for the in-unlock CHECKSIG `2103e17b319aacad4ebf081e68883efbe884cc22673cf7892cf05a5eb5dd3914a770ad`

  `02000000016da7e90ed33829cc5f0ade9501c483dfc51b6e7ee756ddd1446ca80ed198c26c00000000b54830450221008199966c59c9dd87d96f0448e2bbbc7b08256d5bde8e5e8364d6d3a29e1e7d34022041bea593e982b688ed27c7b0021affb1640fa871af1cf4650d455ff60c87099c41473044022078d247d1417565d62d758175e94e8bffed1314883a5c25010c4787bbf2f8bb1502202c387de13a1cc06aa81780ebb31edd56491b26667c023947ad3d2687b619c7c141ab2103e17b319aacad4ebf081e68883efbe884cc22673cf7892cf05a5eb5dd3914a770adffffffff01b8820100000000001976a9141bd7273f6f30b0562860e983100050cdc6e2f9cd88ac00000000`

- xsig-00002 (A, `pre-genesis/unlock+lock`): txid `b60c9c36098060bd26c47c5573dfe3398dcb2a52e9aad7533744b9f64d3e59c9`; the coin `6cc298d10ea86c44d1dd56e77e6e1bc5df83c40195de0a5fcc2938d30ee9a76d:1` (regtest height 102, 100000 sat, lock `2102b1362bb654abcf1772fd7aea23ef20b19c5b27e3b75e44de8560261d93edfc72ac`); the reference's scriptCode for the in-unlock CHECKSIG `2103e17b319aacad4ebf081e68883efbe884cc22673cf7892cf05a5eb5dd3914a770ad2102b1362bb654abcf1772fd7aea23ef20b19c5b27e3b75e44de8560261d93edfc72ac`

  `02000000016da7e90ed33829cc5f0ade9501c483dfc51b6e7ee756ddd1446ca80ed198c26c01000000b447304402200ca94c9da38483077ca19fda1aac8ea91e31bffafbb9d3ef6054889079a04397022037deb885464a12865da15c3215a11991aca89474ea6d04b518eda46e3bc92d904147304402202724f90d4b54c00b7a17fd4b2e9da64835fcdfaf3ef927d3166f2e7638ddf777022058a2de0d3c257b2bab9766928923dbf31dce8cdde20035c03b9a8e134198fb4e41ab2103e17b319aacad4ebf081e68883efbe884cc22673cf7892cf05a5eb5dd3914a770adffffffff01b8820100000000001976a9141bd7273f6f30b0562860e983100050cdc6e2f9cd88ac00000000`

- xsig-00003 (A, `pre-chronicle/unlock-only`): txid `1893886ca539d53d7aec656f93b4cbca9a929383d41da816f44f3c67821f0dc2`; the coin `ca5de238686d8d8fbe91c5de47567cf10f6d6ca29712bcc8867056cca0515efd:0` (regtest height 121, 100000 sat, lock `2102b1362bb654abcf1772fd7aea23ef20b19c5b27e3b75e44de8560261d93edfc72ac`); the reference's scriptCode for the in-unlock CHECKSIG `2103e17b319aacad4ebf081e68883efbe884cc22673cf7892cf05a5eb5dd3914a770ad`

  `0200000001fd5e51a0cc567086c8bc1297a26c6d0ff17c5647dec591be8f8d6d6838e25dca00000000b5473044022078abc978e2b43e8ad14bf1235fc23b4996ff9fe499d2644052d63833e2a63903022029dffb15513871fa4e1bc493270e45957ab7e87637f3027b75d92da75807e72341483045022100b45b66fd386c7b6e0520f449bfd87aeecf09146b14abff754f94c60ee454f38a0220391225e6de1434d47cd5a26149457d4d110ef7eb78fb9396107bc17d780bf43b41ab2103e17b319aacad4ebf081e68883efbe884cc22673cf7892cf05a5eb5dd3914a770adffffffff01b8820100000000001976a9141bd7273f6f30b0562860e983100050cdc6e2f9cd88ac00000000`

- xsig-00004 (A, `pre-chronicle/unlock+lock`): txid `b7309863ecdacd56ddd81fa01a87258d7c9464bc2676c47355721dee4efb7f98`; the coin `ca5de238686d8d8fbe91c5de47567cf10f6d6ca29712bcc8867056cca0515efd:1` (regtest height 121, 100000 sat, lock `2102b1362bb654abcf1772fd7aea23ef20b19c5b27e3b75e44de8560261d93edfc72ac`); the reference's scriptCode for the in-unlock CHECKSIG `2103e17b319aacad4ebf081e68883efbe884cc22673cf7892cf05a5eb5dd3914a770ad2102b1362bb654abcf1772fd7aea23ef20b19c5b27e3b75e44de8560261d93edfc72ac`

  `0200000001fd5e51a0cc567086c8bc1297a26c6d0ff17c5647dec591be8f8d6d6838e25dca01000000b5483045022100b0a1afdafea5bb22114bb815798990d8010ccc51cc3353997fba13cdd167983502201e238384a00f2abe14bccf2d0cfa3808ffa6509ed979469e4d551eaac02b342241473044022023fb792699fd4892abf5ff51f342645de68475b3437dbecebf2b74dba0d080bf02201b5658bc3f0d7b2600cbdb1768a0f5b019807fe323f99d1547ff1e68113bba8941ab2103e17b319aacad4ebf081e68883efbe884cc22673cf7892cf05a5eb5dd3914a770adffffffff01b8820100000000001976a9141bd7273f6f30b0562860e983100050cdc6e2f9cd88ac00000000`

- xsig-00005 (A, `a:go-sdk-lock-only`): txid `6ebe789cfcb1003f0d305cc67c857d40a415e64a094ab89d9adf78353691329b`; the coin `ffb28848824bdb85a9feff8bfed5cac59a811223295ef8ba337de5fefde680c1:0` (regtest height 132, 100000 sat, lock `2102b1362bb654abcf1772fd7aea23ef20b19c5b27e3b75e44de8560261d93edfc72ac`); the reference's scriptCode for the in-unlock CHECKSIG `2103e17b319aacad4ebf081e68883efbe884cc22673cf7892cf05a5eb5dd3914a770ad2102b1362bb654abcf1772fd7aea23ef20b19c5b27e3b75e44de8560261d93edfc72ac`

  `0200000001c180e6fdfee57d33baf85e292312819ac5cad5fe8bfffea985db4b824888b2ff00000000b6483045022100ba1736c5c2c25393b2cb2b831fbaf73b593119b82c7c063671645ad4fb247778022077c4468f027234f0b43525cb89cad82173bef7cafee1de0cce50820e83f8e44a41483045022100fc433989a7999ab9b7fa176f21e8f12f7b73794e353dde4e0233d3b00879e035022040b775dab84e9eaabf9257862f842f474c1df0655fbb0fc43229e4bb855b987941ab2103e17b319aacad4ebf081e68883efbe884cc22673cf7892cf05a5eb5dd3914a770adffffffff01b8820100000000001976a9141bd7273f6f30b0562860e983100050cdc6e2f9cd88ac00000000`

- xsig-00006 (A, `b:ts-sdk-template-lock-only`): txid `dca6a1d3a3680c927e6dd8d5027a742ad060474f7cad4152d56e409192e187bc`; the coin `ffb28848824bdb85a9feff8bfed5cac59a811223295ef8ba337de5fefde680c1:1` (regtest height 132, 100000 sat, lock `2102b1362bb654abcf1772fd7aea23ef20b19c5b27e3b75e44de8560261d93edfc72ac`); the reference's scriptCode for the in-unlock CHECKSIG `2103e17b319aacad4ebf081e68883efbe884cc22673cf7892cf05a5eb5dd3914a770ad2102b1362bb654abcf1772fd7aea23ef20b19c5b27e3b75e44de8560261d93edfc72ac`

  `0200000001c180e6fdfee57d33baf85e292312819ac5cad5fe8bfffea985db4b824888b2ff01000000b6483045022100ffe1dc79ee2f00d7a9550837c368de6647efdab9e8be5aa26d75dca38f03e7b6022008a8bcfd185ab45d600361a2a3502221b8213111ac53a944267435ecfa45f4fe41483045022100b21148fbc6df39b619a170b4049a17a404cb1e2a13c72ae756c04ad924735513022020664c46472cd94d95714a4560a5365a5c9ddd43261765d6ffc71b1317291d9f41ab2103e17b319aacad4ebf081e68883efbe884cc22673cf7892cf05a5eb5dd3914a770adffffffff01b8820100000000001976a9141bd7273f6f30b0562860e983100050cdc6e2f9cd88ac00000000`

- xsig-00007 (A, `c:correct-scriptcode`): txid `ee8c21c272498ddfd4ea31ce3da2a2f97910b4da8ece2ef544627800a2181531` block `684e84716fb05f475dc99721b5f8ea006ba4344961295a6c6f202b34d324c6d0`; the coin `ffb28848824bdb85a9feff8bfed5cac59a811223295ef8ba337de5fefde680c1:2` (regtest height 132, 100000 sat, lock `2102b1362bb654abcf1772fd7aea23ef20b19c5b27e3b75e44de8560261d93edfc72ac`); the reference's scriptCode for the in-unlock CHECKSIG `2103e17b319aacad4ebf081e68883efbe884cc22673cf7892cf05a5eb5dd3914a770ad2102b1362bb654abcf1772fd7aea23ef20b19c5b27e3b75e44de8560261d93edfc72ac`

  `0200000001c180e6fdfee57d33baf85e292312819ac5cad5fe8bfffea985db4b824888b2ff02000000b64830450221009d2b13cd930c10d8980e235d915b9902769abafa65ddace3265b0bfa2ab3f83a02200ad6c8358c7288dac288b69c29d8db02dfe2db35b5549e05943a97546e60dd5441483045022100c5c6654e6ed1d07e26600c661a979564b28d1e5ca9a497816e187e06e7f71e9302207946cd1e9f0ee6cb843f2a8955384836fdde6f0c26a3f1412d62bb8430904def41ab2103e17b319aacad4ebf081e68883efbe884cc22673cf7892cf05a5eb5dd3914a770adffffffff01b8820100000000001976a9141bd7273f6f30b0562860e983100050cdc6e2f9cd88ac00000000`

- xsig-00008 (A, `d:ts-sdk-format-correct-subscript`): txid `3fa107305af3c71ddf2ecfa2a91bb324aeddd84fe40710855494d94eda7b6439` block `684e84716fb05f475dc99721b5f8ea006ba4344961295a6c6f202b34d324c6d0`; the coin `ffb28848824bdb85a9feff8bfed5cac59a811223295ef8ba337de5fefde680c1:3` (regtest height 132, 100000 sat, lock `2102b1362bb654abcf1772fd7aea23ef20b19c5b27e3b75e44de8560261d93edfc72ac`); the reference's scriptCode for the in-unlock CHECKSIG `2103e17b319aacad4ebf081e68883efbe884cc22673cf7892cf05a5eb5dd3914a770ad2102b1362bb654abcf1772fd7aea23ef20b19c5b27e3b75e44de8560261d93edfc72ac`

  `0200000001c180e6fdfee57d33baf85e292312819ac5cad5fe8bfffea985db4b824888b2ff03000000b6483045022100ecf6f3deda295b9e1cbce6c32bedbed32a8dca67c69a7447bd462477cc99abff02202da7078585d0a0f7315b9ad5df51401402f55f512a1ccf346042c122cbfd517441483045022100c0da1bd6859797ac1a90585fae63486e7fb286741589fb0844d5f71b8bdfcf1802205415c85d7f76e158226d5fc4ef49bc32fb5ad0ff8797de19d1b2f7bcdbb33b9241ab2103e17b319aacad4ebf081e68883efbe884cc22673cf7892cf05a5eb5dd3914a770adffffffff01b8820100000000001976a9141bd7273f6f30b0562860e983100050cdc6e2f9cd88ac00000000`

- xsig-00009 (B, `a:go-sdk-lock-only`): txid `2efcf5a3833fb39bca8cae059173a457d8de5da869c2cfb4bc36398777092a4d`; the coin `ffb28848824bdb85a9feff8bfed5cac59a811223295ef8ba337de5fefde680c1:4` (regtest height 132, 100000 sat, lock `76a914a9495f0d80fd41f57ec2507c5cc1c059a31b815488ac`); the reference's scriptCode for the in-unlock CHECKSIG `ad6876a914a9495f0d80fd41f57ec2507c5cc1c059a31b815488ac`

  `0200000001c180e6fdfee57d33baf85e292312819ac5cad5fe8bfffea985db4b824888b2ff04000000fdd50248304502210082bfa444113d5377ef0c7ab4ecacea8eb9a9e8fc867554b8c9bf8f201034227c022034cd7312399ba1130c305ab7b6bdffac171e0c24c3834b4158d96b748e413df7412102b1362bb654abcf1772fd7aea23ef20b19c5b27e3b75e44de8560261d93edfc724cb602000000253627635e8660f2c9acde4f83ccda87deb1372b8ab7f0ddd048a730914e2f2e3bb13029ce7b1f559ef5e747fcac439f1455a2ec7c5f09b72290795e70665044c180e6fdfee57d33baf85e292312819ac5cad5fe8bfffea985db4b824888b2ff040000001976a914a9495f0d80fd41f57ec2507c5cc1c059a31b815488aca086010000000000ffffffff0c8f1dd8fefeed311a9da0e71e6cc2af68316cda52b99769c25d1ef3e5e30de800000000410000005163aa517f517f517f517f517f517f517f517f517f517f517f517f517f517f517f517f517f517f517f517f517f517f517f517f517f517f517f517f517f517f517f7c7e7c7e7c7e7c7e7c7e7c7e7c7e7c7e7c7e7c7e7c7e7c7e7c7e7c7e7c7e7c7e7c7e7c7e7c7e7c7e7c7e7c7e7c7e7c7e7c7e7c7e7c7e7c7e7c7e7c7e7c7e01007e81209817f8165b81f259d928ce2ddbfc9b02070b87ce9562a055acbbdcf97e66be799321414136d08c5ed2bf3ba048afe6dcaebafeffffffffffffffffffffffffffffff0097827c012180517f517f517f517f517f517f517f517f517f517f517f517f517f517f517f517f517f517f517f517f517f517f517f517f517f517f517f517f517f517f517f517f7c7e7c7e7c7e7c7e7c7e7c7e7c7e7c7e7c7e7c7e7c7e7c7e7c7e7c7e7c7e7c7e7c7e7c7e7c7e7c7e7c7e7c7e7c7e7c7e7c7e7c7e7c7e7c7e7c7e7c7e7c7e7c7e7801217c947f77787c7e01027c7e22022079be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f817987c7e7c0124937c7e01307c7e01417e210279be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798abad68ffffffff01b8820100000000001976a9141bd7273f6f30b0562860e983100050cdc6e2f9cd88ac00000000`

- xsig-00010 (B, `b:ts-sdk-template-lock-only`): txid `bfea4efe5348ca4482e28e7686eed3aa7d8485aa38ab618daf8b41015ec5e83e`; the coin `ffb28848824bdb85a9feff8bfed5cac59a811223295ef8ba337de5fefde680c1:5` (regtest height 132, 100000 sat, lock `76a914a9495f0d80fd41f57ec2507c5cc1c059a31b815488ac`); the reference's scriptCode for the in-unlock CHECKSIG `ad6876a914a9495f0d80fd41f57ec2507c5cc1c059a31b815488ac`

  `0200000001c180e6fdfee57d33baf85e292312819ac5cad5fe8bfffea985db4b824888b2ff05000000fdd502483045022100afcaae094597ff78f739c5799195aa646dfdc2fcc10f0012cf9282a26f8efd800220107a3a064d2c25e14c53f9eb9f6b1fd2a3ef29386a6e5f08eecc79f6fa071aa5412102b1362bb654abcf1772fd7aea23ef20b19c5b27e3b75e44de8560261d93edfc724cb60200000063b7a729dcedde2865c2f4d521f9d62d289dcf4f613a28a33c008c019ba454623bb13029ce7b1f559ef5e747fcac439f1455a2ec7c5f09b72290795e70665044c180e6fdfee57d33baf85e292312819ac5cad5fe8bfffea985db4b824888b2ff050000001976a914a9495f0d80fd41f57ec2507c5cc1c059a31b815488aca086010000000000ffffffff0c8f1dd8fefeed311a9da0e71e6cc2af68316cda52b99769c25d1ef3e5e30de800000000410000005163aa517f517f517f517f517f517f517f517f517f517f517f517f517f517f517f517f517f517f517f517f517f517f517f517f517f517f517f517f517f517f517f7c7e7c7e7c7e7c7e7c7e7c7e7c7e7c7e7c7e7c7e7c7e7c7e7c7e7c7e7c7e7c7e7c7e7c7e7c7e7c7e7c7e7c7e7c7e7c7e7c7e7c7e7c7e7c7e7c7e7c7e7c7e01007e81209817f8165b81f259d928ce2ddbfc9b02070b87ce9562a055acbbdcf97e66be799321414136d08c5ed2bf3ba048afe6dcaebafeffffffffffffffffffffffffffffff0097827c012180517f517f517f517f517f517f517f517f517f517f517f517f517f517f517f517f517f517f517f517f517f517f517f517f517f517f517f517f517f517f517f517f7c7e7c7e7c7e7c7e7c7e7c7e7c7e7c7e7c7e7c7e7c7e7c7e7c7e7c7e7c7e7c7e7c7e7c7e7c7e7c7e7c7e7c7e7c7e7c7e7c7e7c7e7c7e7c7e7c7e7c7e7c7e7c7e7801217c947f77787c7e01027c7e22022079be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f817987c7e7c0124937c7e01307c7e01417e210279be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798abad68ffffffff01b8820100000000001976a9141bd7273f6f30b0562860e983100050cdc6e2f9cd88ac00000000`

- xsig-00011 (B, `c:correct-scriptcode`): txid `6c275be1c5f9e106f81d33e5adf2cb6ed01127fd8ff16c2c0e62341abf950ed5` block `684e84716fb05f475dc99721b5f8ea006ba4344961295a6c6f202b34d324c6d0`; the coin `ffb28848824bdb85a9feff8bfed5cac59a811223295ef8ba337de5fefde680c1:6` (regtest height 132, 100000 sat, lock `76a914a9495f0d80fd41f57ec2507c5cc1c059a31b815488ac`); the reference's scriptCode for the in-unlock CHECKSIG `ad6876a914a9495f0d80fd41f57ec2507c5cc1c059a31b815488ac`

  `0200000001c180e6fdfee57d33baf85e292312819ac5cad5fe8bfffea985db4b824888b2ff06000000fdd702483045022100ef3b70cf38ae432678809e6bcb181b52ebbfee3f5481812f496ffc8a1a439ade0220216e538875185ae048fc64a95c70da6e213efd3edbaff455a837b8c55ff3aa68412102b1362bb654abcf1772fd7aea23ef20b19c5b27e3b75e44de8560261d93edfc724cb8020000003bf327d5d05c62ce8494932a7ed591245360e188fb9295997635f61f63ac56ae3bb13029ce7b1f559ef5e747fcac439f1455a2ec7c5f09b72290795e70665044c180e6fdfee57d33baf85e292312819ac5cad5fe8bfffea985db4b824888b2ff060000001bad6876a914a9495f0d80fd41f57ec2507c5cc1c059a31b815488aca086010000000000ffffffff0c8f1dd8fefeed311a9da0e71e6cc2af68316cda52b99769c25d1ef3e5e30de800000000410000005163aa517f517f517f517f517f517f517f517f517f517f517f517f517f517f517f517f517f517f517f517f517f517f517f517f517f517f517f517f517f517f517f7c7e7c7e7c7e7c7e7c7e7c7e7c7e7c7e7c7e7c7e7c7e7c7e7c7e7c7e7c7e7c7e7c7e7c7e7c7e7c7e7c7e7c7e7c7e7c7e7c7e7c7e7c7e7c7e7c7e7c7e7c7e01007e81209817f8165b81f259d928ce2ddbfc9b02070b87ce9562a055acbbdcf97e66be799321414136d08c5ed2bf3ba048afe6dcaebafeffffffffffffffffffffffffffffff0097827c012180517f517f517f517f517f517f517f517f517f517f517f517f517f517f517f517f517f517f517f517f517f517f517f517f517f517f517f517f517f517f517f517f7c7e7c7e7c7e7c7e7c7e7c7e7c7e7c7e7c7e7c7e7c7e7c7e7c7e7c7e7c7e7c7e7c7e7c7e7c7e7c7e7c7e7c7e7c7e7c7e7c7e7c7e7c7e7c7e7c7e7c7e7c7e7c7e7801217c947f77787c7e01027c7e22022079be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f817987c7e7c0124937c7e01307c7e01417e210279be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798abad68ffffffff01b8820100000000001976a9141bd7273f6f30b0562860e983100050cdc6e2f9cd88ac00000000`

- xsig-00012 (B, `d:ts-sdk-format-correct-subscript`): txid `450118402cd0196cb2d8015e1acf698e207476e424b42f9bd60e33143fd942ed` block `684e84716fb05f475dc99721b5f8ea006ba4344961295a6c6f202b34d324c6d0`; the coin `ffb28848824bdb85a9feff8bfed5cac59a811223295ef8ba337de5fefde680c1:7` (regtest height 132, 100000 sat, lock `76a914a9495f0d80fd41f57ec2507c5cc1c059a31b815488ac`); the reference's scriptCode for the in-unlock CHECKSIG `ad6876a914a9495f0d80fd41f57ec2507c5cc1c059a31b815488ac`

  `0200000001c180e6fdfee57d33baf85e292312819ac5cad5fe8bfffea985db4b824888b2ff07000000fdd702483045022100c100bdef8d878537b877f910ee2fa6579e3b38c0a90e12a7313e3aabdfa70129022067dd8081f4e5be8b0c87ede44a55e13225314e4c32edcd39d7a799da356f88a1412102b1362bb654abcf1772fd7aea23ef20b19c5b27e3b75e44de8560261d93edfc724cb802000000d14588688f4768a5b878de94327b2904b4d915c1b38e86648c1a2d55b7f895993bb13029ce7b1f559ef5e747fcac439f1455a2ec7c5f09b72290795e70665044c180e6fdfee57d33baf85e292312819ac5cad5fe8bfffea985db4b824888b2ff070000001bad6876a914a9495f0d80fd41f57ec2507c5cc1c059a31b815488aca086010000000000ffffffff0c8f1dd8fefeed311a9da0e71e6cc2af68316cda52b99769c25d1ef3e5e30de800000000410000005163aa517f517f517f517f517f517f517f517f517f517f517f517f517f517f517f517f517f517f517f517f517f517f517f517f517f517f517f517f517f517f517f7c7e7c7e7c7e7c7e7c7e7c7e7c7e7c7e7c7e7c7e7c7e7c7e7c7e7c7e7c7e7c7e7c7e7c7e7c7e7c7e7c7e7c7e7c7e7c7e7c7e7c7e7c7e7c7e7c7e7c7e7c7e01007e81209817f8165b81f259d928ce2ddbfc9b02070b87ce9562a055acbbdcf97e66be799321414136d08c5ed2bf3ba048afe6dcaebafeffffffffffffffffffffffffffffff0097827c012180517f517f517f517f517f517f517f517f517f517f517f517f517f517f517f517f517f517f517f517f517f517f517f517f517f517f517f517f517f517f517f517f7c7e7c7e7c7e7c7e7c7e7c7e7c7e7c7e7c7e7c7e7c7e7c7e7c7e7c7e7c7e7c7e7c7e7c7e7c7e7c7e7c7e7c7e7c7e7c7e7c7e7c7e7c7e7c7e7c7e7c7e7c7e7c7e7801217c947f77787c7e01027c7e22022079be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f817987c7e7c0124937c7e01307c7e01417e210279be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798abad68ffffffff01b8820100000000001976a9141bd7273f6f30b0562860e983100050cdc6e2f9cd88ac00000000`


## The checks

- `python3 tools/cite_check.py` at `60fcbb6f`: `cite_check: GREEN (every checked active anchor holds at the pin; closed history is not checked)`,
  9,947 citations, 5,620 anchored and holding, MOVED 0 (docs/records are history to this leg: this record's lines were re-read at
  the pins by hand, each range above opened with `git show v1.2.3:<path>` or in the module cache and the package's source).
- `tools/check_pins.py`: `check-pins: GREEN (94 sites agree with docs/PROVENANCE.md §1a; 7 skipped by name ...)`.
- `tools/secrets_scan.sh --tree`: `secrets: GREEN [X] (engine gitleaks 8.28.0 ...; findings 0)`.
- `tools/jscpd_check.sh`: `jscpd: GREEN [X] 3.167% duplicated lines (2525 of 79721) ...; the threshold 3.81%`.
- `tools/wording_gate.sh`: 12 hits, every one on a top-level page this lane did not touch (`docs/PLAN-2026-10-05-SPEC-ALONE.md`,
  `docs/PARAMETERS.md`, `docs/LINT.md`, `docs/PLAN-2026-10-14-*.md`): no new hit; docs/records is outside its page set.
- No U+2014 in any touched file; `git diff --check` clean; the Go helper `go vet` and `gofmt -l` clean; no Rust touched
  (the fmt and clippy legs not affected).
- The Finding: comment `6222686767` on #144 (posted 2026-10-16 19:02 UTC, one word reworded 19:03 UTC; corrected in place after
  the lens by lane fix-xsig-144 at 19:24 UTC, the replaced sentences gone and a dated correction line at its end).
- `run_svnode`: GREEN, agree spec 12, spec-mempool 12. `run_engine --engine gosdk`: GREEN, agree spec 12, spec-mempool 12.
  `run_engine --engine tssdk`: GREEN, agree spec 10, spec-mempool 10, default 9 and 9, every divergence under a cited class
  (`crypto.checksig.unlock.ungated` 2 per word column, `eras.default-mode.no-era` 3 per default column). `run_diff` (bsv-rs):
  GREEN, agree 10 and 10, 2 undecided (pre-Genesis). `run_bsvrs --smoke` on the corpus: GREEN, 12 of 12.
  `rules_check`: GREEN (96 corpus x engine manifests, 856,019 entries replayed, 154,491 divergent runs classified).
  Those 96 manifests did not list this corpus: `rules_check` replays only the corpora of the four witness manifests
  (`harness/src/bin/rules_check.rs:9-15`), so the class's counts then stood on this lane's runs alone (the lens on the branch).
- Lane fix-xsig-144 (the fix after the lens, 2026-10-16 19:20 UTC, on the box): the corpus moved to `corpus/xsig-144/`
  (`git mv`, the bytes unchanged) because the drivers key a corpus by its directory's name (`harness/src/differential.rs:79-82`)
  and the bsv-rs replay finds only a `manifest.json` or `cases-manifest.json` beside the corpus (`rules_check.rs:695-703`);
  under `corpus/crypto/` a `manifest.json` would also displace `cases-manifest.json` for `crypto` (`tools/check_pins.py:163-165`).
  Recorded in place with each runner's `--record` (the spec column from the recorded keys, `spec_recorded`; the words from the
  lane's witness manifests, `--words-from`; `run_svnode` on a fresh regtest instance at 127.0.0.1:18571, stopped and its datadir
  removed): `run_engine --engine gosdk` GREEN, agree spec 12, spec-mempool 12; `run_engine --engine tssdk` GREEN, agree spec 10,
  spec-mempool 10, default 9 and 9; `run_diff` GREEN, agree 10 and 10, 2 undecided; `run_bsvrs --smoke` GREEN, 12 of 12;
  `run_svnode` GREEN, agree spec 12, spec-mempool 12. Every `--record` left the corpus's sha256 at `f4ca9693...` (the recorded
  keys reproduce byte for byte). The four witness manifests gained the key `xsig-144` and its witness file, then
  `rules_check: GREEN (... 100 corpus × engine manifests, 856067 entries replayed, 154501 divergent runs classified; 5 s)`,
  with `ts-sdk on xsig-144: 12 entries replayed ...; 10 divergent runs in 4 classes; EQUAL to the manifest` and the go-sdk,
  sv-node and bsv-rs lines on `xsig-144` EQUAL with 0 divergent runs. The binaries were the box's lane target built at 19:11 UTC
  (no Rust source touched here); a cargo build of them is the box tripwire's to verify.
- Not run by this lane: the Lean build (no slot), a full `make check` (the parent's tripwire of record).
- Lane fix2-xsig-144 (the fix after the relens, 2026-10-16 19:34 UTC, on the box): the ts-sdk witnesses were recorded by
  33dee80c before 795a3e8a rewrote the class, so `corpus/witnesses/ts-sdk/xsig-144.jsonl` and the manifest's `xsig-144`
  block still carried the old class text (the old corpus path, `interpreter.cpp:1474–1481`/`1570–1577`). Re-recorded with
  `run_engine --engine tssdk --record` (`spec_recorded`, `--words-from corpus/witnesses/ts-sdk/manifest.json`): GREEN, agree
  spec 10, spec-mempool 10, default 9 and 9; witness sha256 `ec700b84...`; the corpus's sha256 still `f4ca9693...`. Both
  witnesses' `decided_by`, `ruling` and note now carry `harness/rules/ts-sdk.json`'s class text. Then `rules_check: GREEN (...
  100 corpus × engine manifests, 856067 entries replayed, 154501 divergent runs classified; 6 s)`, xsig-144 EQUAL on all four
  engines (ts-sdk 10 divergent runs in 4 classes). `tools/xsig/gosign/main.go` checks the key (32 bytes, scalar in
  [1, n-1]): go-sdk's `PrivateKeyFromBytes` returns `(*PrivateKey, *PublicKey)` and no error (`privatekey.go:46`, v1.7.2).
  The helper was rebuilt offline with go1.27.0. A regtest-free self-check fed the eight post-Chronicle rows' requests from
  `20261016-185844-s4b-144-witness.json` to it: `gosign self-check: 8/8 development rows equal (preimage_lock, preimage_sub,
  sighash_sub); zero key refused: True`. The binaries were the box's lane target (no Rust touched).
