# PROVENANCE: the reference pins, what crosses, what never enters

Issue numbers on this page are the archived tracker's ([docs/GLOSSARY.md](GLOSSARY.md), "archived #n").

**Rule:** the reference is a pinned tag; every rule cites file and line at that
pin. Patterns cross from the predecessors with a header and a mechanism check.
Nothing of the private programs enters.

*Pinned 2026-09-22 (#2). Re-pin only by an issue that re-reads every `[SRC]`
line the move invalidates; the old pin stays in this file's history.*

## 1. The pins

| source | pin | how it was read | what it is |
|---|---|---|---|
| **bitcoin-sv (SV-node), the reference** | tag **`v1.2.3`** = commit `6504a3aff65ba97c0f6c80962b033e35ecbfed4b`, tagged 2026-10-05T06:31:58Z; GitHub release published 2026-10-06T09:09:04Z (archived #57) `[LIT]` | local public clone `<the maintainers' build host>:bitcoin-sv`, the tag fetched and checked out detached; node built on the Studio and copied to the box, [build record](records/20261006-144350-node-v1.2.3-build.md) | the C++ interpreter and flag, activation and limit logic (§2); v1.2.2 pin values retained in §6 |
| **Earlier reference measurements** | The reading of record at v1.2.3 is a defined refusal ([SRC] `int_serialization.h:61–118`, `script_num.cpp:80–91` at `6504a3af`); the previous pin's reading and its measurements are recorded in material withheld from the public edition at the maintainers' request (group `d8-node-team-discretion`). | withheld material | historical measurements |
| **Teranode** | tag **`v0.16.0`** = commit `4edb60a40c6628ff0ef60231c2628efd7103fde5` (the tagged commit's time 2026-09-30T16:56:33Z by the Go proxy; GitHub's stable release published 2026-10-05T08:16:41Z, the recon's entry 2) `[LIT]`; the tag's commit read at `https://api.github.com/repos/bsv-blockchain/teranode/git/ref/tags/v0.16.0` on 2026-10-06T01:16:54Z (#54; `v0.15.9` = `04022a51db3a836ee2a4a4600903566ee4ccb607` from 2026-09-22 until then) | on the Studio the local clone `<the maintainers' build host>:teranode` with the tag fetched, every citation read with `git show v0.16.0:<path>`, never the working tree; on the box (#54) a shallow clone `<the maintainers' build host>:targets/spec-54/teranode` at the commit (the Studio's clone must hold the tag; the default `maxscriptsizepolicy` is 100,000,000 at v0.16.0, `settings/settings.go:113`, and 500,000 at v0.15.9 `settings.go:102`, the recon's entry 2) | script validation is **delegated to GoBDK**: `go.mod:12` `github.com/bitcoin-sv/bdk/module/gobdk v1.2.5-0.20260918043653-4eab3acdbbb9`; `services/validator/TxValidator.go:115` constructs `newScriptVerifierGoBDK`; the adapter is `services/validator/ScriptVerifierGoBDK.go` (443 lines at v0.16.0: `substituteUnconfirmedHeights` 54–82, construction 147–243, `ValidateTransaction` 274–313 with the call at 297, `bdkCause` 336–349, the policy/consensus error mapping `mapBDKValidationError` 351–434 (since v0.16.0 an ABI error, a DoS code outside the build's range and an error of no known domain are processing errors, node faults, never a verdict: 362–373, 385–397, 429–431), `bdkPolicyRelatedScriptError` 436–443). No other script engine exists in `services/validator/` at the tag `[SRC]` |
| **BDK (GoBDK)**, Teranode's engine | commit **`4eab3acdbbb971724f37e886e836daa1ed444a7f`** (2026-09-18T04:36:53Z, the proxy's time for the pseudo-version), the module Teranode v0.16.0 pins (#54, 2026-10-06; `cdfa7814ee5da7b899e7301f058710002baaea40` of 2026-05-26, Teranode v0.15.9's, until then) | on the Studio the local clone `<the maintainers' build host>:bdk` at the commit; on the box a shallow clone `<the maintainers' build host>:targets/spec-54/bdk` at the commit (`GOBDK_CLONE`) | a CMake build of bitcoin-sv's own `src/script/*` (`cmake/modules/FindBSVSourceHelper.cmake:35–83`: the SV source tree is found or cloned; `core/txvalidator.cpp` wraps `VerifyScript` (`CTxValidator::VerifyScript` 781, `bsvVerifyScript` 911–914); the flags are computed in Go by `module/gobdk/script/txvalidator.go:89 CalculateFlags`; the chain parameters by name, except STN, which takes GoBDK's own table, `core/txvalidator.cpp:271–321`, `:324–337`). The prebuilt archives Teranode links at `4eab3acd`, `module/gobdk/bdkcgo/libGoBDK_{darwin_arm64,linux_aarch64,linux_x86_64}.a` (three; `cdfa7814` carried a fourth, darwin_x86_64), carry the SV version block `1.2.2` · `v1.2.2` · **`879fc8b42`** · `2026-04-28 07:23:20 +0100` (`strings`, twice per archive, in all three) `[X]` (#54, 2026-10-06): the 9-hex prefix and the committer date of the pinned commit `879fc8b42168dd0e608dafd51b39c6dabad37d4d` (whose `git log --date=iso` is `2026-04-28 07:23:20 +0100`). These are the `CGO_BSV_GIT_COMMIT_HASH` / `_DATETIME` values (`bdkcgo/version_cgo.h:22–23`). The block that follows, `master` · `c10755d` · `2026-09-18 10:30:27 +0700` (BDK 1.3.0, Go binding 1.3.2, by the shim's banner), is BDK's own version block, not SV's (`85cf62c` · `1.2.4` · `2026-05-22` at `cdfa7814`). **Teranode's engine is bitcoin-sv v1.2.2 at the pinned commit, identified byte-level**; #28's shim reads `gobdk.BSV_GIT_COMMIT_HASH()` at every spawn and gets the 9-hex prefix `879fc8b42` (the linked library's `CGO_BSV_GIT_COMMIT_HASH`, `bdkcgo/version_cgo.h:22`, carries the prefix, never the 40-hex string `[X]` 2026-09-26, `docs/records/20260926-210253-gobdk-shim-s4b.md`, and again at `4eab3acd` on 2026-10-06; the sentence "reads the full 40-hex string by linking as a formality" stood here until 2026-09-26) |
| **go-chaincfg**, the chain parameters Teranode reads (pinned 2026-09-27, S3; S4b's ask A7; moved by #54 on 2026-10-06) | **`v1.6.2`** = commit `198ccf650e914b1ece818553ade71512760e0eaf` (the tag object `c7306e45…` dereferenced; the proxy's `.info` names the same commit, 2026-08-12T12:11:55Z): the version Teranode v0.16.0 requires at the tag (`go.mod:15`; `go.sum:132–133` the two sums, equal to sum.golang.org's) `[SRC]`; `v1.5.8` = `d81fcaba4049af2dccb589c134fea89d6fd1f2f6` (Teranode v0.15.9's) until then | on the Studio the local clone `<the maintainers' build host>:go-chaincfg` with the tag (`git show v1.6.2:params.go`, never the checkout); on the box a shallow clone `<the maintainers' build host>:targets/spec-54/go-chaincfg` at the commit | the chain parameters by network name that `settings/settings.go:21` selects and `ScriptVerifierGoBDK.go:158–165` pushes into GoBDK: mainnet Genesis 620,538 and Chronicle 943,816 at `params.go:276–277` (the same lines at v1.5.8); **regtest 100 / 200** at `params.go:475–476` (10,000 / 15,000 at v1.5.8: a consensus parameter of regtest that moved); tstn's genesis block `scalingTeraTestNetGenesisBlock` at `params.go:719–720` (`genesis.go:193–274`; at v1.5.8 tstn reused testnet's genesis block); the script engine never reads them, the era does |
| **go-safe-conversion**, the integer conversions Teranode's GoBDK call uses (pinned 2026-10-14 for #91, at its lens's item 4) | **`v1.2.0`** = commit `ebbf2d452e66904f70ac6ee772721b026322f3b9`: the version Teranode v0.16.0's `go.mod:203` requires (`go.sum:138–139` the two sums) `[SRC]` | on the Studio the local clone `<the maintainers' build host>:upstream/bsv-blockchain/go-safe-conversion` with the tag (`git show v1.2.0:safe_conversion.go`); read from that clone, no network read for the pin | `Uint32ToInt32`, the int32 bound of every height at the GoBDK call (`safe_conversion.go:234–240`, `value > math.MaxInt32` refused; called by `uint2int` and `bdkBlockHeight` in `services/validator/ScriptVerifierGoBDK.go`), transcribed as `int32Max` and `uint32ToInt32` in `lean/BsvChain/Teranode/Sentinel.lean` |
| **the Teranode instance's host** (#41, #28; 2026-10-06) | the box, by its roster name `box`; the instance's own tag, commit and binary sha256 are in its build record `docs/records/20261006-000348-instance41-build-v0160.md` and in every run manifest's header | data `<the maintainers' build host>:targets/spec-teranode/data` (the running regtest chain; a fresh chain for the Genesis-to-Chronicle era beside it, `data-fresh-tx-*`), evidence `<the maintainers' build host>:targets/spec-teranode/evidence/` (the v0.16.0 build's under `evidence/v0.16.0/`), run journals `<the maintainers' build host>:targets/spec-teranode/runs/` (each named by sha256 in its manifest under `harness/engines/instance41/runs/`); outside this repository | started and stopped by `harness/engines/instance41/instance.py` (`start --validator`, `status`, `stop`; `INSTANCE41_DATA` names another chain), one run or chunk under the box leg lock and a Lean slot by `harness/engines/instance41/seed_chunk.zsh` (and #74's column by `harness/engines/teranode/column.zsh`; the one exception, #74's column run of 2026-10-14T21:55:08Z, took the box leg lock only, a run of about 12 s while the box's one slot was held by StaleRun builds, named in `docs/records/20261014-215508-s6-74-second-oracle-s4b.md`); regtest only, every listener on the loopback interface only, p2p, alert and legacy off, never left running between runs; nothing broadcast |
| **bsv-rs** | crates.io **`0.7.0`**, checksum `a4bd3df9f2d8d2277dc3965692de93e4dc5f669e736c7c89937b4a805601b71d`, tag **`v0.7.0`** = commit `5841f98c839859658c0661dd034722f63d545e2f`; published `2026-10-17T01:53:11.632810Z` by the release workflow (trusted publishing, run `38992048173`, sha `5841f98c…`), not yanked (since #148, 2026-10-17; 0.5.0 = `d06ea0dd…`, published `2026-10-12T03:43:45.692527Z`, until then) | public tagged CHANGELOG and crates.io version API (read 2026-10-17T01:55:17Z); the local clone's fetched tag names the same commit; [column record](records/20261017-015602-column-bsv-rs-0.7.0-s3.md); [0.5.0 bump record](records/20261012-124552-bump-bsv-rs-0.5.0-s3.md) | implementation under measurement: `Spend::new(SpendParams)` with `work_limit: None`, plus the primitive vector APIs; 27 corpora re-recorded at 0.7.0 by `make column` with no row moved; as a signer (`make check-signer`) its templates, `SigningContext` (with 0.7.0's `with_script_code`) and the dispatched digest; streaming APIs and `OutputRef` are unused |
| **go-sdk** (adopted at #29; re-pinned at #99, 2026-10-12) | **`v1.7.2`** = `2ca481c5931b987a0c8f48bb341c70b7477b6b07`; annotated tag `7ab43c0ff9f302386d92cc7766bb90799b73e557`, tagged 2026-10-09T04:54:16Z, release published 2026-10-09T05:08:55Z. Sum `h1:AKJaeDOzcIqcLgEG/i5ksi6/StQsFEsGSZrIgHBRMzc=`, go.mod sum `h1:NtCYkU9NX/D8wzdN+9zGUtl2Rpdp+Zk5Uhyd0Aww+/c=` `[X]`. Tag-object [read](https://api.github.com/repos/bsv-blockchain/go-sdk/git/tags/7ab43c0ff9f302386d92cc7766bb90799b73e557) at 2026-10-12T00:06:00Z; public advisory GHSA-rh54-8fpg-8wwf and CHANGELOG at the tag, §6. | The runner links the Go module cache at v1.7.2 through `harness/engines/go/go.mod` and `go.sum`, without a replace directive. Studio clone `<the maintainers' build host>:go-sdk` is detached at the commit; the box clone at that path already held it. The pins leg verifies the tag resolution, not the clone checkout. | Native Go engine `[SRC]` at v1.7.2: `script/interpreter/engine.go:60–96` (`Execute`); `options.go:152–174` (`WithFlags`, exact supplied word and explicit UTXO era), `options.go:176–194` (`WithMaxStackMemory`); `scriptflag/scriptflag.go:87–111` (separate spend-era flags), `scriptflag/heights.go:7–91` (activation tables and block-word derivation); `thread.go:484–533` (spend and coin eras, version gate), `thread.go:764–818` (signature type checks); `config.go:25–40` (32,000,000-byte Chronicle number width and 100,000,000-byte default stack budget, a policy default); `transaction/signaturehash.go:71–108` (digest selection using the engine FORKID flag); `spv/verify.go:564–594` (P2SH-shaped coin era). The adapter `harness/engines/go/main.go` maps the supplied reference word, including Genesis and Chronicle, and measures the SDK stack default on both columns; it calls `Engine.Execute`, not `spv.Verify`. |
| **ts-sdk** (adopted at #29; re-pinned at #52, 2026-10-05, then at #55, 2026-10-05) | npm **`@bsv/sdk` 3.0.0**, integrity `sha512-smQn/gxUy10/RrudCch/aPozqTngXIAATv7atuGjOI7G1XxWO+5Kug6g8mCIFozBITNJJQK7ivkMUG5UwOGv+w==` `[LIT]`. #55 moves 2.8.10 to the newest release at recon entry 2, published 2026-10-03T14:42:41.030Z (the registry's `time`). ts-stack has no 3.0.0 tag and the registry document has no `gitHead`; the source commit is **`4d0ea63c85a836e3509291babb0d8e0c784b70a0`** in `bsv-blockchain/ts-stack`, the newest commit touching `packages/sdk/` before the publish, whose `packages/sdk/package.json` says 3.0.0 and whose `src/script/Spend.ts` has the installed source map's sha256 `[X]`. The major version's changelog heading (`packages/sdk/CHANGELOG.md`, Unreleased, "Removed (3.0.0 candidate)") removes the `identity/DIDTokenValidation` module; the package's `dist/esm` `script/` and `transaction/` trees (except `transaction/http/`) and `mod.js` are byte-identical to 2.8.10's, and its `exports` map only adds four `primitives/` subpaths `[X]`. | `npm ci` at the lock's integrity. The installed package's `dist/esm/src/script/Spend.js.map` carries `Spend.ts` in `sourcesContent`, 2,321 lines, sha256 `f4337015bc583cdf1c96ebba07940df89e2528a70e54590b2fc8e86a51c099a4`, the same as at 2.8.10. Studio clone `<the maintainers' build host>:ts-stack` must hold the commit with `packages/sdk/package.json` version 3.0.0. The SDK and runner require node ≥ 22. | A native TypeScript engine `[SRC]` at 3.0.0, re-read 2026-10-05 from the installed source map (byte-identical to 2.8.10's, so every line below holds): `Spend.ts:261–317` (constructor), `Spend.ts:319–321` (`#isRelaxed`, version above 1 or caller override), `Spend.ts:327–374` (17 flag names: CHECKLOCKTIMEVERIFY and CHRONICLE added, GENESIS unused; coin eras at 331–341; version gate at 343–345 for MINIMALDATA, LOW_S, NULLDUMMY, SIGPUSHONLY and CLEANSTACK), `Spend.ts:1174–1179,1710–1715,1844–1849` (MINIMALIF and NULLFAIL gated under explicit names, absent in default mode). `Spend.ts:395–403` gives explicit numeric reads the coin-era consensus width, with no policy width input; the default mode has no width. `Spend.ts:2026–2052` dispatches to a registered backend, else `Spend.ts:2058–2109` runs the interpreter; the adapter registers none (`transaction/ScriptVerificationBackend.ts:9–27`). The adapter is `harness/engines/ts/runner.mjs`, explicit word and default mode. |
| **the Association's protocol documentation** (a documentation upstream, #139; added 2026-10-14) | https://protocol.bsvblockchain.org/ (a GitBook; the index `/llms.txt`, every page's Markdown twin at its URL plus `.md`); every specification page names bitcoin-sv **v1.2.2** = `879fc8b42168dd0e608dafd51b39c6dabad37d4d` as its ground truth, one release before this spec's node of record `[LIT]`; read 2026-10-14T21:24:24Z to 21:24:39Z and again from 22:04:18Z (byte-identical), 19 pages, each page's sha256 in [the record](records/20261014-213924-xread-139-s4b.md) | public reads by `curl -sL` (rule 10); the recon (rule 18, `docs/recon.md`) re-reads the index and every page's twin at each entry, records each specification page's named pin and sha256, and a moved pin or a changed page re-opens that page's rows of `docs/CONFORMANCE-ASSOCIATION-v122.md` | a second written reading of the same source, not an implementation and never an oracle: the cross-read page `docs/CONFORMANCE-ASSOCIATION-v122.md` (#139 parts 1 to 4) sets each sentence beside the spec's definition; a disagreement is routed by the maintainers, never filed |
| **bsv-blockchain/BRCs** (the client formats' documentation, views never rules; #75 and #86; added 2026-10-15) | `5333fd449c70fd5982029876376dcf1ed9c64ffe` (2026-03-09, #86's reads) and `793f18685803924e3c6433fa226ee0b5bac0dad0` (#75's read of 0074.md) | raw reads by URL, §6 | `0074.md` differs between them only at its Implementations link (line 392); every cited line is equal [X] (`git diff 5333fd4 ed1b015 -- transactions/0074.md` in the clone; `ed1b015`'s blob is #75's `2f0ed5ea`); 0030, 0062, 0095 and 0096 are identical at `5333fd4` and `ed1b015` [X] |
| **the toolchains** | Lean `leanprover/lean4:v4.34.0` + Mathlib `5ed29652…` (the joint re-pin R6 of the three programs, landed in the hour D124 on 2026-09-27; #35's road (a), A5; S2's `lean-b-repin`; `v4.33.0` + `db584cd6…` from #3 until then) · Rust **1.95.0** (`harness/rust-toolchain.toml`, #40) · Go **1.27** (the Studio's `go1.27.0`; the go-sdk module needs ≥ 1.26) · Node **22** (the pin is the major, `node.major`; `v22.18.0` in the Modal container, `tools/modal_check.py`; the box's nvm `v22.23.3` in the column records of 2026-10-14; @bsv/sdk's `engines`) · cargo-deny **0.19.0** (tools/cargo_deny.sh DENY_VERSION, #133) | `make check-pins` reads what is in use | the pins block §1a is the record; `tools/check_pins.py` the check |
| a predecessor harness of the maintainers' (a private tree) | `0fc5ced` (2026-09-16) | the maintainers' clone (the pins block's `$PREDECESSOR_HARNESS_CLONE`), `git show 0fc5ced:<path>` | the differential fuzz pattern (its fuzz binary, 1,334 lines) and the engine-harness pattern (its harness module, 95 lines); the wiring in its library root's `verify_tx` (line 458) and `sighash_preimage` (line 405) (pattern only; nothing else crosses, §3) |
| an earlier Lean research tree of the maintainers' (a private tree) | `f6e0455` (2026-09-16) | the maintainers' clone (the pins block's `$PREDECESSOR_LEAN_CLONE`), its Lean research directory | the Lean discipline only: toolchain `leanprover/lean4:v4.33.0`, mathlib `v4.33.0` = `db584cd6d46c92f209a44c0f1c829460d327499d` (the same pins here, #3); no code crosses |

### 1a. The pins, machine-readable (#40; `make check-pins` = `tools/check_pins.py`)

Every pin above, once, in the form the tripwire reads; the prose rows cite the same values. A change here is
a re-pin (the rule at the top of this page); the leg refuses every site that disagrees: the Lean toolchain
and manifest, `harness/rust-toolchain.toml`, `Cargo.toml`/`Cargo.lock`/`lib.rs` for bsv-rs, the corpus
manifests' recorded engine version and the vector files' names, `harness/engines/go/go.{mod,sum}`,
`harness/engines/ts/package{,-lock}.json`, the `--locked` discipline, the toolchains in use, and (on the
machine that holds them) the clones at their tags, the vendored reference vectors and the built node.

```pins
# reference: bitcoin-sv (SV-node), the newest release at the pin date (§1, #2)
reference.tag             = v1.2.3
reference.commit          = 6504a3aff65ba97c0f6c80962b033e35ecbfed4b
reference.clone           = ~/bsv/bitcoin-sv
reference.version_string  = v1.2.3.0-g6504a3aff-dev   # `bitcoind -version`'s first line, exact; `-dev` is the build's own suffix (an export without a repository)
reference.binary          = ~/bsv/targets/sv-v1.2.3/bin/bitcoind
# [M] 2026-10-13 (H6 road (b), a build of the wallet configuration): a second binary of the same pin configured with the wallet (BUILD_BITCOIN_WALLET=ON,
# Berkeley DB 5.3.28 from brew's berkeley-db@5; every other option the node of record's); not the node of record, not checked by this leg;
# version string equal to reference.version_string; bitcoind sha256 3c088faeaa87e29164280fcf7e5f5b33b52b560a88e47876b612df8f93c0ceae;
# record docs/records/20261013-234938-wallet-build-s3.md
# [M] 2026-10-14T05:07Z (#121, a build of the wallet rows): on the box too (sha256 equal; berkeley-db@5 5.3.28_1); measured rows: 4
# (4 agree); a corpus row selects it by "binary":"wallet" (harness/src/scenarios/core.rs Build); record docs/records/20261014-050737-s6-wallet-rows-regtest-s3.md
reference.binary_wallet   = ~/bsv/targets/sv-v1.2.3-wallet/bin/bitcoind
# [M] 2026-10-15 (#84, a build of the events configuration): another binary of the same pin configured with BUILD_BITCOIN_ZMQ=ON (libzmq from brew's
# zeromq 4.3.5_1; every other option the node of record's); not the node of record; read by this leg (tools/check_pins.py: its sha256
# against the one this comment names and its version string, skipped by name where absent); version string equal to
# reference.version_string; bitcoind sha256 bbdd56f3ce7bfbc340f4c96c622e3c19b67762bc029330361d4603a57922312d; selected by the events
# recipe (harness/src/scenarios/core.rs Build::Zmq; SV_ZMQ_BITCOIND overrides the path); record docs/records/20261015-035435-s7-84-events-s1.md
# source: git archive of reference.commit from reference.clone; configured 03:34:44Z to 03:35:02Z, built 03:37:52Z to 03:47:07Z on the Studio;
# copied to the path below by a build of 2026-10-15 at 11:13Z (sha256 equal, banner equal); on the Studio only, not on the box
reference.binary_zmq      = ~/bsv/targets/sv-v1.2.3-zmq/bin/bitcoind
# the crate facts the runners rely on are asserted by harness/tests/crate_pins.rs (the leg runs it): ProtocolEra::at_height
# is None below Genesis; ScriptFlags::block(era)/standard(era) carry both UTXO markers from the block's era; the script-number
# length limit under a word is the coin's era's consensus width on the block path and the policy default on the mempool path (flags.rs at 0.4.5: the same code as at v0.3.30 and v0.3.28, moved by 0.3.30's stack memory constants and budget and 0.3.31's doc comments)
# Teranode, whose script engine is GoBDK (§1)
teranode.tag              = v0.16.0
teranode.commit           = 4edb60a40c6628ff0ef60231c2628efd7103fde5
teranode.clone            = ~/bsv/teranode
# go-alert-system, the alert library Teranode's alert service imports (#94): v0.1.17, the version Teranode v0.16.0's go.mod:197
# requires, module sum h1:qWh/nnN3DiP2OahWbb0hdLBNKkKHXDToSDDnxEzjJ08= (go.sum); the tag's commit df18148deb98a3eef2f2d4741049ef1d258d2b53
# (the proxy's .info); read in <the maintainers' build host>:upstream/bsv-blockchain/go-alert-system at v0.1.17 (§6, the read of 2026-10-15); not a key this leg checks
gobdk.commit              = 4eab3acdbbb971724f37e886e836daa1ed444a7f
gobdk.clone               = ~/bsv/bdk
# the linked GoBDK archive remains a build of v1.2.2 when the node of record moves (#57)
gobdk.reference_tag       = v1.2.2
gobdk.reference_commit    = 879fc8b42168dd0e608dafd51b39c6dabad37d4d
# the shim's module pin (#28, harness/engines/gobdk; 2026-09-27; re-pinned by #54 on 2026-10-06): the pseudo-version Teranode
# v0.16.0's go.mod:12 requires and its go.sum:108–109's two sums; build.sh checks the clone's module/gobdk against the sums before it links
gobdk.module              = github.com/bitcoin-sv/bdk/module/gobdk
gobdk.pseudo_version      = v1.2.5-0.20260918043653-4eab3acdbbb9
gobdk.sum                 = h1:N50HOHr6u8UP3zfGByTG5+gYbwhSNRMkTr6O8TwodiM=
gobdk.gomod_sum           = h1:XxBr/Y+e+pMw3+e2xYECvEayfZM3RX3n0jVvOGC3krE=
# go-chaincfg, the chain parameters Teranode reads (settings/settings.go:21 at v0.16.0 selects them by network name and
# ScriptVerifierGoBDK.go:158–165 pushes the Genesis and Chronicle heights into GoBDK): the version Teranode's go.mod:15
# requires at the tag, the sums go.sum:132–133's (pinned 2026-09-27 at v1.5.8, S3; moved to v1.6.2 by #54 on 2026-10-06)
go-chaincfg.module        = github.com/bsv-blockchain/go-chaincfg
go-chaincfg.version       = v1.6.2
go-chaincfg.commit        = 198ccf650e914b1ece818553ade71512760e0eaf
go-chaincfg.sum           = h1:BoBm2eLvXioMyf39B5A6LxhddmTV/9VYArbzIr1KEJM=
go-chaincfg.gomod_sum     = h1:tmKOKZkvIZNhh5GwpcrKTYTXLac1+IGpSFRMSZt/8Gc=
go-chaincfg.clone         = ~/bsv/go-chaincfg
# go-safe-conversion, the integer conversions of Teranode's GoBDK call (Uint32ToInt32, the int32 bound of every height,
# safe_conversion.go:234–240): the version Teranode v0.16.0's go.mod:203 requires (pinned 2026-10-14 for #91, lens item 4)
go-safe-conversion.tag    = v1.2.0
go-safe-conversion.commit = ebbf2d452e66904f70ac6ee772721b026322f3b9
go-safe-conversion.clone  = ~/bsv/upstream/bsv-blockchain/go-safe-conversion
# bsv-rs (crates.io; the checksum is Cargo.lock's; the tag and commit are the crate's repository)
bsv-rs.crate              = 0.7.0
bsv-rs.checksum           = a4bd3df9f2d8d2277dc3965692de93e4dc5f669e736c7c89937b4a805601b71d
bsv-rs.tag                = v0.7.0
bsv-rs.commit             = 5841f98c839859658c0661dd034722f63d545e2f
bsv-rs.clone              = ~/bsv/bsv-rs
# go-sdk (the Go module proxy; re-pinned 2026-10-12 at #99 from v1.7.1)
# read 2026-10-12T00:06:00Z https://api.github.com/repos/bsv-blockchain/go-sdk/git/tags/7ab43c0ff9f302386d92cc7766bb90799b73e557
go-sdk.module             = github.com/bsv-blockchain/go-sdk
go-sdk.version            = v1.7.2
go-sdk.commit             = 2ca481c5931b987a0c8f48bb341c70b7477b6b07
go-sdk.sum                = h1:AKJaeDOzcIqcLgEG/i5ksi6/StQsFEsGSZrIgHBRMzc=
go-sdk.gomod_sum          = h1:NtCYkU9NX/D8wzdN+9zGUtl2Rpdp+Zk5Uhyd0Aww+/c=
go-sdk.clone              = ~/bsv/go-sdk
# ts-sdk (the npm registry; the source is the ts-stack monorepo at the commit; re-pinned 2026-10-05 at #52, from 2.8.0, and at #55, from 2.8.10)
ts-sdk.package            = @bsv/sdk
ts-sdk.version            = 3.0.0
ts-sdk.integrity          = sha512-smQn/gxUy10/RrudCch/aPozqTngXIAATv7atuGjOI7G1XxWO+5Kug6g8mCIFozBITNJJQK7ivkMUG5UwOGv+w==
ts-sdk.source_repo        = bsv-blockchain/ts-stack
ts-sdk.commit             = 4d0ea63c85a836e3509291babb0d8e0c784b70a0
ts-sdk.clone              = ~/bsv/ts-stack
# the Association's protocol documentation (#139; a documentation upstream, no site of the leg reads these keys; the recon
# re-reads the site at every entry, rule 18): the index, the release its specification pages name, the read
association-docs.index    = https://protocol.bsvblockchain.org/llms.txt
association-docs.reference_tag    = v1.2.2
association-docs.reference_commit = 879fc8b42168dd0e608dafd51b39c6dabad37d4d
association-docs.read     = 2026-10-14T21:24:24Z
# the toolchains
lean.toolchain            = leanprover/lean4:v4.34.0
lean.mathlib              = 5ed2965256430c3649e86755f9576b54eca72435
rust.toolchain            = 1.95.0
go.major                  = 1.27
node.major                = 22
cargo-deny.version        = 0.19.0  # the deny leg's gate tool (tools/cargo_deny.sh DENY_VERSION, #133)
# the pattern sources (§4): the commit must exist in the clone; the clones move on; a `$NAME` clone is a path the
# owner's host file names (withheld from the public edition, #46), absent there and skipped by name
predecessor-harness.commit = 0fc5ced
predecessor-harness.clone  = $PREDECESSOR_HARNESS_CLONE
predecessor-lean.commit    = f6e0455
predecessor-lean.clone     = $PREDECESSOR_LEAN_CLONE
```

**One consequence, booked as a finding on #2.** At these pins Teranode's script
semantics *is* bitcoin-sv v1.2.2's, compiled into GoBDK. Since the node pin moved to v1.2.3 on 2026-10-06 (#57), the fixed-width
operand reader and OP_SPLIT range guard differ from that embedded engine.
The wrapper also controls: how the flags are computed
(`txvalidator.go:89` at `4eab3acd`), how UTXO heights are mapped
(`ScriptVerifierGoBDK.go:54–82 substituteUnconfirmedHeights`, called at 283), which limits are
applied as policy vs consensus (the `consensus` boolean, and the error mapping
at 351–434 at v0.16.0), and which policy values Teranode sets (`settings/policy_settings.go`).
The independent implementations the harness can compare against the reference
are bsv-rs and go-sdk. Q4 (`docs/DESIGN.md` §9) is narrowed accordingly.

## 2. The files that define script evaluation in bitcoin-sv v1.2.3

Line numbers are at the pin `[SRC]`; every rule written at S1/S2 cites one of
these. "Named, not semantics" marks files the spec reads for context only.

| file | lines | what it defines |
|---|---|---|
| `src/script/interpreter.cpp` | 2,452 | **the interpreter.** 30–50 the anonymous namespace with the version gate: `IsMalleableTxnVersion(v) = (v > 1)` (34–38), `EnforceNonMalleability(flags, v) = !(IsChronicle(flags) && IsMalleableTxnVersion(v))` (40–44) and its four `static_assert`s (46–49) · 52–62 the shift masks, 65–117 `RShift`/`LShift` (65, 91) · 119–130 `CastToBool` · 132–164 the pubkey-encoding predicates · 177–245 `IsValidSignatureEncoding` (DER) · 247–253 `GetHashType` · 255–263 `CleanupScriptCode` (legacy `FindAndDelete` at 261) · 265–310 `CheckSignatureEncoding` (the LOW_S test 282–283 under the version gate at 285) · 312–329 `CheckPubKeyEncoding` · 331–358 `CheckMinimalPush` · 360–375 `IsOpcodeDisabled` · 377–380 `IsValidMaxOpsPerScript` · 382–386 `to_le` (the transaction version as 4 LE bytes, for `OP_VER` at 603–606 and `OP_VERIF`/`OP_VERNOTIF` at 809–812) · **388–1833 `EvalScript`**: the opcode switch; `MaxScriptSize` at 429, `requireMinimal` at 433 (the MINIMALDATA gate), `fExec` from the conditional tracker at 459, MINIMALIF gate 796–804, `OP_IF`/`OP_ELSE`/`OP_ENDIF` on the tracker 823–839 (the post-Genesis single-`ELSE` rule at 829), the NULLFAIL gates 1491–1497 and 1641–1647, the NULLDUMMY gate 1664–1670 · 1835–1982 the legacy sighash serializer `CTransactionSignatureSerializer` (1841) and `GetPrevoutHash`/`GetSequenceHash`/`GetOutputsHash` (1960/1968/1976) · 1984–2006 and 2010–2025 the two `EvalScript` wrappers · 2027–2032 `PrecomputedTransactionData`'s constructor · 2034–2084 `SignatureHashBIP143` · 2086–2110 `SignatureHashOriginal` · 2112–2124 `SignatureHash` (the dispatcher on the FORKID/CHRONICLE bits) · 2126–2130 `TransactionSignatureChecker::VerifySignature`, 2133–2164 `CheckSig` · 2166–2203 `CheckLockTime` · 2204–2253 `CheckSequence` · 2254–2258 `Version` · 2259–2302 `valid_flags` (2259), `utxo_era` (2269), `make_eval_script_params` (2282), `make_verify_script_params` (2295): where the limits enter, by UTXO era and the `consensus` boolean · **2304–2451 `VerifyScript`**: STRICTENC implied by FORKID (2315–2319), the SIGPUSHONLY gate (2321–2334), the two-phase evaluation (2338, 2358), the stack copy for P2SH (2354) and the P2SH block (2382–2424), the CLEANSTACK block (2430–2448: `VerifyCleanStack` at 2430, the version gate 2438–2445) |
| `src/script/interpreter.h` | 235 | declarations: `SignatureHash*` 37–49, `BaseSignatureChecker` 52, `eval_script_params` 136, `verify_script_params` 176, `EvalScript` 207/219 (the full form takes the `conditional_tracker` by reference, 217), `VerifyScript` 227 |
| `src/script/conditional_tracker.cpp` / `.h` | 77 / 26 | **the IF/ELSE/ENDIF state machine** `conditional_tracker` (h:12–26): `op_if` (cpp:37), `is_active` (46), `has_op_else` (51), `op_else` (57), `op_endif` (67), `empty` (32); a false-count over the condition and else vectors |
| `src/script/script_num.cpp` / `.h` | 484 / 157 | **the number type** `CScriptNum` (h:42–107; a `std::variant<int64_t, bsv::bint>` at 104): the byte constructor with the length limit (cpp:62) and the minimal-encoding check (67) (53–91), fixed-width conversion refusal (80–91), `<=>`/`==` (118–142), `+= -= *= /= %=` (144–250), `<<= >>=` (252–376), unary minus (378), `getint` (396), `getint64` (425), `to_size_t_limited` (446) |
| `src/big_int.h` / `.cpp` | 207 / 613 | `bsv::bint`, the arbitrary-precision integer (OpenSSL BIGNUM) behind `CScriptNum`; `serialize`/`deserialize` (h:172/179) |
| `src/script/int_serialization.h` | 210 | **the number encoding**: `bsv::serialize` (23–59) and the checked fixed-width `deserialize` (61–118), little-endian sign-magnitude; `IsMinimallyEncoded` (120–152); `MinimallyEncode` (154–208); failed fixed-width conversion becomes `SCRIPT_ERR_SCRIPTNUM_OVERFLOW` through `script_num.cpp:80–91` and `interpreter.cpp:1807–1809`. The reading of record at v1.2.3 is a defined refusal ([SRC] `int_serialization.h:61–118`, `script_num.cpp:80–91` at `6504a3af`); the previous pin's reading and its measurements are recorded in material withheld from the public edition at the maintainers' request (group `d8-node-team-discretion`). |
| `src/script/limitedstack.cpp` / `.h` | 364 / 175 | the post-Genesis stack with combined memory accounting: `LimitedVector` (h:27–76: `padRight` 59, `MinimallyEncode` 67, `IsMinimallyEncoded` 68), `LimitedStack` (79–151, its `push_back` templates 153–173: `getCombinedStackSize` 114) |
| `src/script/script_flags.h` / `.cpp` | 172 / 38 | **the flags**: the enum (13–115: bits 0–10, 13–16, 18–21; `SCRIPT_GENESIS` 98, `SCRIPT_UTXO_AFTER_GENESIS` 103, `SCRIPT_CHRONICLE` 107, `SCRIPT_UTXO_AFTER_CHRONICLE` 111, `SCRIPT_FLAG_LAST` = bit 22 at 114) and the predicates `IsChronicle`/`IsGenesis`/`IsUtxoAfterChronicle`/`IsUtxoAfterGenesis`/`IsDiscourageUpgradableNops`/`Verify*` (117–171) |
| `src/script/sighashtype.h` | 97 | `SIGHASH_ALL/NONE/SINGLE`, `SIGHASH_CHRONICLE` 0x20, `SIGHASH_FORKID` 0x40, `SIGHASH_ANYONECANPAY` 0x80 (14–22); `SigHashType` (39–95; `isDefined` 79) |
| `src/script/opcodes.h` / `.cpp` | 165 / 330 | the opcode enum (`OP_0` 13 … `OP_NOP10` 149, `FIRST_UNDEFINED_OP_VALUE` 152, `OP_INVALIDOPCODE` 160) and the names |
| `src/script/script.h` / `.cpp` | 352 / 294 | `CScript::GetOp`/`GetOp2` (h:140–201, the push parsing 176–196), `IsPushOnly` (h:248–249, cpp:209/224), `IsUnspendable(era)` (h:260), `GetSigOpCount` (h:238–244, cpp:30/130); the pre-Genesis constants `MAX_SCRIPT_ELEMENT_SIZE_BEFORE_GENESIS` 520 (29), `MAX_STACK_ELEMENTS_BEFORE_GENESIS` 1000 (32), `LOCKTIME_THRESHOLD` (36) |
| `src/script/instruction.h` / `instruction_iterator.h` | 64 / 161 | the second instruction-decode path (used by `GetSigOpCount` and the op counting), beside `GetOp2`: a divergence surface the corpus must cover |
| `src/script/script_error.h` / `.cpp` | 95 / 119 | `ScriptError` (12–87): the reason vocabulary the verdicts carry |
| `src/script/standard.h` / `.cpp` | 164 / 501 | **the mandatory (consensus) flag sets** `PRE_CHRONICLE_MANDATORY_SCRIPT_VERIFY_FLAGS` (55–60) and `POST_CHRONICLE_MANDATORY_SCRIPT_VERIFY_FLAGS` = P2SH · STRICTENC · ENABLE_SIGHASH_FORKID · NULLFAIL · LOW_S · CHRONICLE (62–68); `MandatoryScriptVerifyFlags(era)` (71); `DEFAULT_DATA_CARRIER_SIZE` (46); `IsStandardOutput` (cpp:353) and `IsStandardTx` (427): policy, named |
| `src/script/sigcache.cpp` / `.h` | 145 / 68 | `CachingTransactionSignatureChecker` (h:49), the `BaseSignatureChecker` the node path passes to `VerifyScript`; a cache in front of `TransactionSignatureChecker`, not a semantics change |
| `src/policy/policy.h` / `.cpp` | 293 / 198 | the policy defaults (66–156: `DEFAULT_MAX_SCRIPT_SIZE_POLICY_AFTER_GENESIS` 93, `DEFAULT_OPS_PER_SCRIPT_POLICY_AFTER_GENESIS` 147, `DEFAULT_PUBKEYS_PER_MULTISIG_POLICY_AFTER_GENESIS` 150, `DEFAULT_STACK_MEMORY_USAGE_POLICY_AFTER_GENESIS` 153, `DEFAULT_SCRIPT_NUM_LENGTH_POLICY` 156); the standard sets `ScriptVerifyFlags` (175–205); `StandardScriptVerifyFlags(era)` (208–222); `InputScriptVerifyFlags(era, utxoEra)` (225–244) |
| `src/verify_script_flags.h` / `.cpp` | 21 / 82 | **the flag derivation**: `GetScriptVerifyFlags(era, require_standard, …)` (cpp:11–30, the mempool flags) and `GetBlockScriptFlags(params, height, era)` (32–81, the block flags by height: P2SH 39, DERSIG 43, CLTV 47, CSV 51, UAHF → STRICTENC + FORKID 55–59, DAA → LOW_S + NULLFAIL 65–69, Genesis → `SCRIPT_GENESIS` + SIGPUSHONLY 71–75, Chronicle → `SCRIPT_CHRONICLE` 77–78) |
| `src/protocol_era.h` / `.cpp` | 60 / 128 | `ProtocolName` (19–24), `ProtocolEra` = Unknown (30) / PreGenesis / PostGenesis / PostChronicle (28–34), `GetProtocolEra` (36–41), `GetInverseProtocolEra`, `IsProtocolActive`, `InProtocolGracePeriod` |
| `src/configscriptpolicy.h` / `.cpp` | 92 / 496 | **the limits, by kind**: `ConfigScriptPolicy` (h:25–92); `ResetDefault` (cpp:43–63), `GetMaxOpsPerScript` (65–77), `GetMaxScriptNumLength` (79–110), `GetMaxScriptSize` (112–122), `GetMaxPubKeysPerMultiSig` (124–137), `GetMaxStackMemoryUsage` (139–154), the activation heights (156–162), the setters with their validation (164–446: `SetMaxOpsPerScriptPolicy` 164–190 … `SetMaxStackMemoryUsage` 269–308 … `SetChronicleActivationHeight` 353) |
| `src/consensus/consensus.h` | 94 | the consensus constants: `MAX_OPS_PER_SCRIPT_BEFORE_GENESIS` 500 (40) / `AFTER_GENESIS` UINT32_MAX (43), `MAX_PUBKEYS_PER_MULTISIG_*` 20 / UINT32_MAX (50/55), `MAX_SCRIPT_SIZE_*` 10,000 / UINT32_MAX (58/60), `MAX_SCRIPT_NUM_LENGTH_BEFORE_GENESIS` 4 (62) / `AFTER_GENESIS` 750 KB (64) / `AFTER_CHRONICLE` 32 MB (66), `DEFAULT_STACK_MEMORY_USAGE_CONSENSUS_AFTER_GENESIS` INT64_MAX (82), `MAX_TX_SIZE_CONSENSUS_*` (27/29), `MAX_COINBASE_SCRIPTSIG_SIZE` (69) |
| `src/consensus/params.h` | 55 | the activation heights: `BIP34Height` 21, `BIP65Height` 24, `BIP66Height` 26, `CSVHeight` 28, `uahfHeight` 30, `daaHeight` 32, `genesisHeight`/`chronicleHeight` 37–38 ("the height of the block where the new rules are active", 33–36), `p2shHeight` 39 |
| `src/chainparams.cpp` | 1,619 | **the mainnet values**: `GENESIS_ACTIVATION_MAIN` **620538** (18), `CHRONICLE_ACTIVATION_MAIN` **943816** (23), and per chain (STN/testnet/regtest 19–21 and 24–26); main: BIP34 227931 (1038), BIP65 388381 (1042), BIP66 363725 (1044), CSV 419328 (1046), uahf 478558 (1065), daa 504031 (1068), genesis (1071), chronicle (1074), p2sh (1076) |
| `src/config.h` / `.cpp` | 1,000 / 2,710 | the `Config` interface (h:30–215; the script limits as pure virtuals 35–41, `GetConfigScriptPolicy` 42) and `GlobalConfig` (h:416–998), delegating every script limit to `ConfigScriptPolicy` (cpp:454–466, 517–530, 683–685, 842–855, 2436–2438); the `-…policy` options and the activation-height overrides (`init.cpp:2613` reads `-chronicleactivationheight` with the chain default) |
| `src/validation.cpp` | 7,746 | where script verification is invoked: `GetScriptVerifyFlags(config, era)` (795–801), `CScriptCheck` (the constructor 2503–2521, `operator()` 2523–2543: `VerifyScript` at 2527 with `CachingTransactionSignatureChecker` at 2532), `GetBlockScriptFlags(config, tip)` (2972–2981: the era is that of `tip + 1`, 2980); the per-input composition with `InputScriptVerifyFlags` (the UTXO's era) in the input-check path: line-cited at #13/#20 |
| `src/primitives/transaction.h` / `.cpp` | 404 / 173 | `CTransaction`/`CTxIn`/`CTxOut` and their serialization (the bytes the sighash covers) |
| `src/hash.h` / `.cpp`, `src/crypto/sha256.cpp`, `sha1.cpp`, `ripemd160.cpp` | 306 / 273, 94, 225, 357 | the hash primitives behind `OP_SHA1`/`OP_SHA256`/`OP_RIPEMD160`/`OP_HASH160`/`OP_HASH256` (`CHash256` h:24, `CHash160` h:59): executable in the Lean (#11), so these are cross-checked, not trusted |
| `src/pubkey.cpp`, `src/key.cpp`, `src/secp256k1/` | – | ECDSA verification: **the trust boundary** (`docs/DESIGN.md` §4.1): every step an executable Lean definition (`lean/BsvScript/Crypto/Secp256k1.lean`, #11; Q9 ruled (A) on #38, `docs/HYPOTHESES.md`), no axiom, cross-checked against the 1,340 cases of `corpus/crypto/ecdsa-bsv-rs-0.7.0.jsonl` (200 signatures bsv-rs made through RustCrypto's `k256`, labelled by construction; the `crypto` leg), and against libsecp256k1 by the node oracle's recorded runs of `corpus/crypto` and `corpus/gen` (`docs/CONFORMANCE-2026-09-27.md`: at `spec@e78a043` and `spec@8389375`, before D-1's change to the lax parser; no tripwire leg runs the node; `docs/HYPOTHESES.md` §1; lean #32's re-lens, CN-1, and its re-lens 2, C2N-6) |
| `src/script/scriptcache.cpp` / `.h`, `src/script/sign.cpp`, `src/script/bitcoinconsensus.cpp` / `.h`, `src/script/ismine.*` | 75 / 36, 468, 195 / 119, – | a verification-result cache, signing, the C API (its header carries the public flag constants), the wallet's `IsMine`: named, not semantics |

## 3. What miners run today

- The reference release is **v1.2.3** (published 2026-10-06); it moves the
  fixed-width operand reader and OP_SPLIT guard (archived #57) `[LIT]`.
  The v1.2.2 release was an optional upgrade from v1.2.1 (`doc/release-notes.md:1–8` at v1.2.2) `[SRC]`, retained as history.
- **v1.2.0** (2026-01-07) is the Chronicle hard fork: "The scheduled MainNet
  activation height is 943,816 (Target is 12:00 midday 07-Apr-2026)"
  (`doc/release-notes.md:1–8` at v1.2.0; `src/chainparams.cpp:23` at v1.2.2)
  `[SRC]`. Its release note lists the version-gated restrictions: minimal
  encoding, low-S, NULLFAIL, NULLDUMMY, MINIMALIF, clean stack, push-only
  unlocking (v1.2.0 `doc/release-notes.md:24–37`: the governing paragraph 24–31, the seven restrictions 32–37).
- Mainnet is past the activation height: the public chain tip read on
  2026-09-22T15:48Z was **967,896** (WhatsOnChain `chain/info`, a read) `[M]`.
  So the branch in force on mainnet is **post-Chronicle**, and a version-2
  spend runs with the seven restrictions off (§2, the gate sites).
- Which release each miner actually runs is **not observable from source**.
  The observable is the `subver` string of peers seen by the node oracle
  (S3, #27: a read, never a broadcast); until then the spec's default context
  is "v1.2.3 rules, post-Chronicle era", labeled `[EST]` where it matters.
- Teranode v0.16.0 embeds v1.2.2's engine (§1); go-sdk and bsv-rs are the
  independent engines.

## 4. What crosses, what never enters

| crosses (with a header and a mechanism check) | never enters |
|---|---|
| the differential fuzz generator's structure (the PRNG, the verdict type, the mode differential, the mutation operators, the i128 reference model, the boundary operands, the generated families) | any transaction, txid, block, contract, script generator, design or issue text of the maintainers' other programs; the predecessor harness's five contract corpora (named in its own tree) and its "mainnet replay", and every builder they call |
| the engine harness pattern (`run_lock`: a synthetic source tx carrying the lock, a version-2 spend with one output, the unlock as pushes, the bsv-rs `Spend` wiring of `verify_tx`) | the predecessor harness's frozen artifacts and products; its library's transaction-introspection machinery |
| the crystallized number and encoding rules (as generator families and as corpus corners, re-cited at the pin before they become spec) | the predecessor harness's patent pages |

**The public edition (#46; constitution 05 at v1.0).** The public repository is a fresh tree cut from this one, never this repository's history (the maintainers' ruling of 2026-10-05 on the history's form). `tools/export_public.sh` (`make export-public`) writes the tree of a named commit into an empty directory under `<the maintainers' build host>:targets/spec-export/`, less the globs of one data file, `tools/export_withheld.txt` (grouped by ruling: `docs/sealed/` and `docs/security/`, #34's two D135 records, the private process pages, the gate's own pattern list and the rewrite list, and the maintainers' host file `tools/host_private.sh`, which names the mechanism check's vocabulary and the paths of the sibling trees, the predecessor clones and the shared helpers the routing tools source), with a manifest naming the source commit, every exported path with its sha256 and every withheld path by name; a withheld file is matched by name and never read. `tools/export_gate.sh` (`make export-gate`) then judges the export: the two legs of `tools/mechanism_check.sh` (exit 2, never a pass, where a sibling tree it needs is absent), the pointer patterns of `tools/export_pointers.txt` (withheld from the export itself) and the wording leg with `tools/wording_allow.txt`. The export runs at every tag, since rule 18 outlives v1.0. The dry run of `f7b9035` on the box: 829 paths exported, 159 withheld, 397 pointer and 766 wording hits, each a row to resolve, mechanism leg 2 not run there `[M]` (`docs/records/20261006-011505-export-dry-run-46.md`). The maintainers' rulings of 2026-10-06, about 02:0x UTC: C2 (2026-10-06): since #169 (2026-10-21) the export replaces `CLAUDE.md` whole with `CLAUDE.public.md` (`tools/export_public.py`, PUBLIC_PAGES) and the rewrite list `tools/export_rewrite.txt` (exact blocks, each matched once or the export stops, applied to the exported copy only) no longer carries a CLAUDE.md block. C3 (2026-10-06): in `docs/records/` and `docs/audit/` every line a pointer pattern matches becomes a marker line and the file gains one header line with the count; the wording leg counts that history without gating it, while the pointer leg still gates it; the two pause inventories of 2026-09-30 are withheld as process pages, since the transform would leave their JSON unreadable (the export lens, 2026-10-06). C4 (2026-10-06): the withheld list drops the model-closed record patterns and keeps the sealed, security, D135, process-page and pattern groups, so the 130 formerly withheld records pass through the transform and the gate. The dry run of `a88d0a1` after the rulings: 991 paths exported, 30 withheld, 162 records transformed (371 lines), 89 pointer hits on the pages and 0 in the history, 349 wording hits gated on the pages and 988 counted in the history `[M]` (`docs/records/20261006-015712-export-dry-run-46b.md`). **The license files (#34; the maintainers' derived ruling of 2026-10-05):** `LICENSE` carries the Open BSV License Version 5, the reference's own `LICENSE` at `879fc8b`, for the Lean spec and everything derived from the reference; `LICENSE-APACHE` the Apache License 2.0 for the separable tooling; `NOTICE` names which path is under which and names the VENDORED and transcribed headers of §5 as their own notice (the two public reads in §6; the dry run with them `docs/records/20261006-021213-export-dry-run-34.md`). **The Cargo and Makefile transforms and the build leg (2026-10-17, #107).** The export drops from every exported `Cargo.toml` each `[[bin]]`, `[[test]]`, `[[bench]]` and `[[example]]` table whose source is withheld (today the `gen` binary's), and from every exported `Makefile` each target whose recipe runs a binary so dropped (today `gencases`), with its comment lines and its `.PHONY` name; it stops if a manifest or a package source still names a withheld path or a Makefile still names a dropped binary or target, and reads every list from the named commit; `make export-gate BUILD=1` adds the leg that builds the exported harness offline and cold as a stranger would (`cargo build --release --locked --offline`, then `cargo test --no-run`). `[M]` at `80ca3222`: 1 table dropped (`bin gen`), the build exit 0 with 26 binaries and the test build exit 0 with 31 (`docs/records/20261017-141004-export-107-s3.md`). `[M]` at `b80c8d50`: 1 Makefile target dropped (`gencases`) (`docs/records/20261017-144602-s3-107-export-gate-s3.md`).

## 5. The header every copied file carries

```
// VENDORED from <repo> <path> @ <commit> on 2026-MM-DD (bsv-script-lean #<issue>).
// Mechanism check: <what was verified absent>. Modifications below are this repo's.
```

## 6. How the pins were read (the network reads performed)

**2026-10-17 (#148 (e), bsv-rs 0.5.0 → 0.7.0):** `make column IMPL=bsv-rs PIN=0.7.0` moved the
sites and ran `cargo update -p bsv-rs --precise 0.7.0`; the registry's version JSON was read once for the publish time;
the tag was fetched into the local clone, where the CHANGELOG was read. The [recon record](records/20261017-020538-recon-5-s3.md)
(entry 5 of `docs/recon.md`) and the [column record](records/20261017-015602-column-bsv-rs-0.7.0-s3.md) carry them.

| UTC read (#148) | public URL | result |
|---|---|---|
| 2026-10-17T01:55:17Z | https://crates.io/api/v1/crates/bsv-rs/0.7.0 | 0.7.0; created_at `2026-10-17T01:53:11.632810Z`; checksum `a4bd3df9f2d8d2277dc3965692de93e4dc5f669e736c7c89937b4a805601b71d`; not yanked; trustpub run `38992048173`, sha `5841f98c839859658c0661dd034722f63d545e2f` |
| 2026-10-17T01:55:20Z | https://github.com/Calhooon/bsv-rs | `git fetch origin tag v0.7.0` into `<the maintainers' build host>:bsv-rs`: the tag names `5841f98c839859658c0661dd034722f63d545e2f` |
| 2026-10-17T01:56:02Z | https://index.crates.io/bs/v-/bsv-rs | `cargo update -p bsv-rs --precise 0.7.0` (start time of the command, 1.2 s, exit 0); Cargo.lock's checksum agrees with crates.io |

**2026-10-12 (#59) [SRC] [M]:**
The chain census reads bitcoin-sv v1.2.3 `6504a3af` and second-oracle settings
at `4edb60a4`, with go-chaincfg v1.6.2 `198ccf65`. Each request's URL and UTC
start time stands here; returned identities also stand in the
[census record](records/20261012-023741-s6-59-census.md).
[M] The original 46 timed receipts, 20 fix-round timed receipts and 3 known
untimed read categories are listed below. The earlier exploratory listing,
issue body and comment reads have **unverified times**; a repeated request's
receipt establishes only that repeated request's time. The corrected census
has 77 added NodeConfig fields (6 consensus / 71 policy) and a separate
17-field network record across 4 networks; the record re-derives all counts.
These source receipts and library checks do not claim transition/oracle agreement.

[SRC] Original receipts, mirrored individually:

| original UTC request start | URL | result / blob / decoded lines |
|---|---|---|
| `2026-10-12T02:28:34Z` | [bitcoin-sv/bitcoin-sv: src/config.cpp](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/config.cpp?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | 200; `c81ff74c06b3430e8a01b5af381508a06f476811`; 2710 lines |
| `2026-10-12T02:28:34Z` | [bitcoin-sv/bitcoin-sv: src/validation.cpp](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/validation.cpp?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | 200; `f2f5fa101028f0f73955b06b339c37570c57251a`; 7746 lines |
| `2026-10-12T02:28:34Z` | [bitcoin-sv/bitcoin-sv: src/txmempool.cpp](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/txmempool.cpp?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | 200; `a2021721d358c49fd0692d25fb8dd5c52fa36130`; 3361 lines |
| `2026-10-12T02:28:34Z` | [bitcoin-sv/bitcoin-sv: src/policy/policy.h](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/policy/policy.h?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | 200; `284ff428efc916d36424564ea86c484781782eab`; 293 lines |
| `2026-10-12T02:28:34Z` | [bitcoin-sv/bitcoin-sv: src/consensus/consensus.h](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/consensus/consensus.h?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | 200; `dd1614388a060ec674e7aea13d001cf9171e66ed`; 94 lines |
| `2026-10-12T02:28:34Z` | [bitcoin-sv/bitcoin-sv: src/net_processing.cpp](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/net_processing.cpp?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | gh: Not Found (HTTP 404) |
| `2026-10-12T02:28:34Z` | [bitcoin-sv/bitcoin-sv: src/validation.h](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/validation.h?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | 200; `32c4acd90ece216a23b8b201ced0d1a983f2d3f4`; 1190 lines |
| `2026-10-12T02:28:34Z` | [bitcoin-sv/bitcoin-sv: src/txmempool.h](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/txmempool.h?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | 200; `929141d8eae6e9f7c410022a0a21af8a07dce428`; 1548 lines |
| `2026-10-12T02:28:34Z` | [bitcoin-sv/bitcoin-sv: src/time_locked_mempool.cpp](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/time_locked_mempool.cpp?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | 200; `2984a35270a270859fe330cef5ad7b10eb6219e5`; 664 lines |
| `2026-10-12T02:28:34Z` | [bitcoin-sv/bitcoin-sv: src/time_locked_mempool.h](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/time_locked_mempool.h?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | 200; `6c28689dd966a4a46fc86d421828b84726010f45`; 226 lines |
| `2026-10-12T02:28:35Z` | [bitcoin-sv/bitcoin-sv: src/orphan_txns.cpp](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/orphan_txns.cpp?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | 200; `0632b1c9e7fc7cbbad87f108973634aefe697423`; 440 lines |
| `2026-10-12T02:28:35Z` | [bitcoin-sv/bitcoin-sv: src/orphan_txns.h](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/orphan_txns.h?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | 200; `a8a81026723871aaf668cd6d801491426cf7fc99`; 151 lines |
| `2026-10-12T02:28:35Z` | [bitcoin-sv/bitcoin-sv: src/txn_validation_config.h](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/txn_validation_config.h?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | 200; `7f1563677308223aadcc55d10ccc8767ebc78f86`; 48 lines |
| `2026-10-12T02:28:35Z` | [bitcoin-sv/bitcoin-sv: src/txn_recent_rejects.cpp](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/txn_recent_rejects.cpp?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | 200; `68313f77a9c1ee29537d496541ff90127b12db22`; 27 lines |
| `2026-10-12T02:28:35Z` | [bitcoin-sv/bitcoin-sv: src/bitcoind.cpp](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/bitcoind.cpp?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | 200; `97d94d4267fa7a41abdcdae131f846d9ddf2863f`; 254 lines |
| `2026-10-12T02:28:35Z` | [bitcoin-sv/bitcoin-sv: src/init.cpp](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/init.cpp?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | 200; `9847ebd55b62f959e2b28d664120472c896c6125`; 4177 lines |
| `2026-10-12T02:28:35Z` | [bitcoin-sv/bitcoin-sv: src/block_index.h](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/block_index.h?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | 200; `543097e796ad0fcc9f9b104f96030129e28dc569`; 1277 lines |
| `2026-10-12T02:28:35Z` | [bitcoin-sv/bitcoin-sv: src/chainparams.cpp](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/chainparams.cpp?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | 200; `4dcea2b5b3f1c77b9b16157dc850f68d5e88d5b3`; 1619 lines |
| `2026-10-12T02:28:35Z` | [bitcoin-sv/bitcoin-sv: src/consensus/params.h](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/consensus/params.h?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | 200; `9da13771c872d82bce60205bedbf40e8f0e59d53`; 55 lines |
| `2026-10-12T02:28:35Z` | [bitcoin-sv/bitcoin-sv: src/config.h](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/config.h?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | 200; `46a5504f4e87e2dc7a0cf5adb9dc1dc4f4514d8d`; 1000 lines |
| `2026-10-12T02:28:35Z` | [bitcoin-sv/bitcoin-sv: src/rpc/rawtransaction.cpp](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/rpc/rawtransaction.cpp?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | 200; `c1c713dbd71fcc741473f0395209e9e98d119478`; 2637 lines |
| `2026-10-12T02:28:35Z` | [bitcoin-sv/bitcoin-sv: src/protocol_era.cpp](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/protocol_era.cpp?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | 200; `aa01141bbb08d9e7b285a666c7c376a491f7aaee`; 128 lines |
| `2026-10-12T02:28:35Z` | [bitcoin-sv/bitcoin-sv: src/txn_validator.cpp](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/txn_validator.cpp?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | 200; `c05c72729a24b9276136a8b00bc6c45abc6cc032`; 801 lines |
| `2026-10-12T02:28:35Z` | [bitcoin-sv/bitcoin-sv: src/amount.h](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/amount.h?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | 200; `b6865905ee31a390dd719e05dc391e4b1b278cae`; 178 lines |
| `2026-10-12T02:28:36Z` | [bitcoin-sv/bitcoin-sv: src/frozentxo.h](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/frozentxo.h?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | 200; `366599ba4e123a32eb4c4b152e330ee1da0f009e`; 141 lines |
| `2026-10-12T02:28:36Z` | [bsv-blockchain/teranode: settings/settings.go](https://api.github.com/repos/bsv-blockchain/teranode/contents/settings/settings.go?ref=4edb60a40c6628ff0ef60231c2628efd7103fde5) | 200; `2baec9f11f12d2e1305d1285f7c20af07e903d8e`; 858 lines |
| `2026-10-12T02:28:36Z` | [bsv-blockchain/teranode: settings/policy_settings.go](https://api.github.com/repos/bsv-blockchain/teranode/contents/settings/policy_settings.go?ref=4edb60a40c6628ff0ef60231c2628efd7103fde5) | 200; `3f77fc0d54c1aaebce6a1f7ae0b0cc4b855a41da`; 272 lines |
| `2026-10-12T02:28:36Z` | [bsv-blockchain/teranode: settings/legacy_settings.go](https://api.github.com/repos/bsv-blockchain/teranode/contents/settings/legacy_settings.go?ref=4edb60a40c6628ff0ef60231c2628efd7103fde5) | 200; `a50172e8c16a9a0f87d3e46777603db9eb92d930`; 41 lines |
| `2026-10-12T02:30:27Z` | [bitcoin-sv/bitcoin-sv: src/net/net.cpp](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/net/net.cpp?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | 200; `aa52706836fc7fe1a61c21e622cb1dda71abe277`; 3658 lines |
| `2026-10-12T02:30:27Z` | [bitcoin-sv/bitcoin-sv: src/configscriptpolicy.cpp](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/configscriptpolicy.cpp?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | 200; `340acde9a9bfea32e12ac959ee5fa5685f033696`; 496 lines |
| `2026-10-12T02:30:28Z` | [bitcoin-sv/bitcoin-sv: src/safe_mode.cpp](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/safe_mode.cpp?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | 200; `1aa6b7a37d498e50b4f3698df388c95dbe2d93fd`; 588 lines |
| `2026-10-12T02:30:28Z` | [bitcoin-sv/bitcoin-sv: src/chainparams.h](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/chainparams.h?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | 200; `4fba65bd7ebcac36f38b8e607a9dbede4d55c725`; 163 lines |
| `2026-10-12T02:30:28Z` | [bitcoin-sv/bitcoin-sv: src/txn_validator.h](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/txn_validator.h?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | 200; `4bca1de679cb6714b074acc67232b907c7869ddd`; 327 lines |
| `2026-10-12T02:30:29Z` | [bitcoin-sv/bitcoin-sv: src/primitives/transaction.h](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/primitives/transaction.h?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | 200; `38516745ff8e95eceda775ea1b40074509d1eb66`; 404 lines |
| `2026-10-12T02:30:29Z` | [bitcoin-sv/bitcoin-sv: src/policy/policy.cpp](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/policy/policy.cpp?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | 200; `809611b82283ca8b918acc3c82d9d93dd8e0a60e`; 198 lines |
| `2026-10-12T02:30:29Z` | [bsv-blockchain/teranode: services/legacy/blockchain/validate.go](https://api.github.com/repos/bsv-blockchain/teranode/contents/services/legacy/blockchain/validate.go?ref=4edb60a40c6628ff0ef60231c2628efd7103fde5) | gh: Not Found (HTTP 404) |
| `2026-10-12T02:30:30Z` | [bsv-blockchain/teranode: services/legacy/blockchain/chain.go](https://api.github.com/repos/bsv-blockchain/teranode/contents/services/legacy/blockchain/chain.go?ref=4edb60a40c6628ff0ef60231c2628efd7103fde5) | 200; `5e506b840b30eaccc929202aed822f8d751b9b21`; 56 lines |
| `2026-10-12T02:30:30Z` | [bsv-blockchain/teranode: services/legacy/netsync/manager.go](https://api.github.com/repos/bsv-blockchain/teranode/contents/services/legacy/netsync/manager.go?ref=4edb60a40c6628ff0ef60231c2628efd7103fde5) | 200; `d7226e87dda96f0be0aa03a6d321d5ba6854b157`; 4102 lines |
| `2026-10-12T02:30:30Z` | [bsv-blockchain/teranode: services/validator/TxValidator.go](https://api.github.com/repos/bsv-blockchain/teranode/contents/services/validator/TxValidator.go?ref=4edb60a40c6628ff0ef60231c2628efd7103fde5) | 200; `16c18eea53e9eaffee25c0f1b0f1981a5eb8408a`; 457 lines |
| `2026-10-12T02:38:16Z` | [bsv-blockchain/go-chaincfg: params.go](https://api.github.com/repos/bsv-blockchain/go-chaincfg/contents/params.go?ref=198ccf650e914b1ece818553ade71512760e0eaf) | 200; `8350f3a5c765d93ff6bfc6c18cbda9bc930844cf`; 1037 lines |
| `2026-10-12T02:38:16Z` | [bsv-blockchain/teranode: services/blockchain/Server.go](https://api.github.com/repos/bsv-blockchain/teranode/contents/services/blockchain/Server.go?ref=4edb60a40c6628ff0ef60231c2628efd7103fde5) | 200; `af65f6ec725bbb1a229d482fe7d13321441659f0`; 3895 lines |
| `2026-10-12T02:38:17Z` | [Calgooon/bsv-script-lean: issue #59](https://api.github.com/repos/Calgooon/bsv-script-lean/issues/59) | 200; issue JSON |
| `2026-10-12T02:38:17Z` | [Calgooon/bsv-script-lean: issue #59 newest comment](https://api.github.com/repos/Calgooon/bsv-script-lean/issues/59/comments?per_page=100) | 200; issue JSON |
| `2026-10-12T02:49:45Z` | [bsv-blockchain/teranode: services/legacy/blockchain (directory; repeated receipt)](https://api.github.com/repos/bsv-blockchain/teranode/contents/services/legacy/blockchain?ref=4edb60a40c6628ff0ef60231c2628efd7103fde5) | 200; `chain.go`, `mediantime.go`, `mediantime_test.go`, `merkle.go` |
| `2026-10-12T02:51:09Z` | [bsv-blockchain/teranode: go.mod](https://api.github.com/repos/bsv-blockchain/teranode/contents/go.mod?ref=4edb60a40c6628ff0ef60231c2628efd7103fde5) | 200; `d337c5951fbb4f2015a7efd2d32b57b72d3fdb55`; 471 lines |
| `2026-10-12T02:51:10Z` | [bitcoin-sv/bitcoin-sv: src/script/standard.h](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/script/standard.h?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | 200; `240122bf39163a80c17aa262b6c9f3d598836fcc`; 164 lines |
| unverified UTC time | [exploratory directory listing](https://api.github.com/repos/bsv-blockchain/teranode/contents/services/legacy/blockchain?ref=4edb60a40c6628ff0ef60231c2628efd7103fde5) | Original untimed read; the timed repeat does not recover its time. |
| unverified UTC time | [earlier issue body](https://api.github.com/repos/Calgooon/bsv-script-lean/issues/59) | Original untimed read; the timed repeat does not recover its time. |
| unverified UTC time | [earlier issue comments](https://api.github.com/repos/Calgooon/bsv-script-lean/issues/59/comments?per_page=100) | Original untimed reads; the timed repeat does not recover their times. |

[SRC] Fix-round receipts (local cached line inspections use these retrieved bytes):

| fix-round UTC request start | URL | result / blob / decoded lines |
|---|---|---|
| `2026-10-12T03:50:54Z` | [origin fetch](https://github.com/Calgooon/bsv-script-lean.git) | fetched; reviewed branch remained `1165f70` |
| `2026-10-12T03:52:04Z` | [pinned source request](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/txn_validation_config.h?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | 200; `7f1563677308223aadcc55d10ccc8767ebc78f86`; 48 lines |
| `2026-10-12T03:52:04Z` | [pinned source request](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/validation.h?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | 200; `32c4acd90ece216a23b8b201ced0d1a983f2d3f4`; 1190 lines |
| `2026-10-12T03:52:04Z` | [pinned source request](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/config.cpp?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | 200; `c81ff74c06b3430e8a01b5af381508a06f476811`; 2710 lines |
| `2026-10-12T03:52:04Z` | [pinned source request](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/validation.cpp?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | 200; `f2f5fa101028f0f73955b06b339c37570c57251a`; 7746 lines |
| `2026-10-12T03:52:04Z` | [pinned source request](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/txn_validator.cpp?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | 200; `c05c72729a24b9276136a8b00bc6c45abc6cc032`; 801 lines |
| `2026-10-12T03:52:04Z` | [pinned source request](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/txmempool.cpp?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | 200; `a2021721d358c49fd0692d25fb8dd5c52fa36130`; 3361 lines |
| `2026-10-12T03:52:04Z` | [pinned source request](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/policy/policy.h?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | 200; `284ff428efc916d36424564ea86c484781782eab`; 293 lines |
| `2026-10-12T03:52:05Z` | [pinned source request](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/init.cpp?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | 200; `9847ebd55b62f959e2b28d664120472c896c6125`; 4177 lines |
| `2026-10-12T03:52:05Z` | [pinned source request](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/chainparams.cpp?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | 200; `4dcea2b5b3f1c77b9b16157dc850f68d5e88d5b3`; 1619 lines |
| `2026-10-12T03:52:05Z` | [pinned source request](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/consensus/params.h?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | 200; `9da13771c872d82bce60205bedbf40e8f0e59d53`; 55 lines |
| `2026-10-12T03:52:05Z` | [pinned source request](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/pow.cpp?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | 200; `989f483079930d539677ef30695f194ccc76310b`; 297 lines |
| `2026-10-12T03:52:05Z` | [pinned source request](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/protocol_era.cpp?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | 200; `aa01141bbb08d9e7b285a666c7c376a491f7aaee`; 128 lines |
| `2026-10-12T03:52:05Z` | [pinned source request](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/script/verify_script_flags.cpp?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | HTTP 404; no source evidence; replaced by src/verify_script_flags.cpp below |
| `2026-10-12T03:52:05Z` | [pinned source request](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/bitcoind.cpp?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | 200; `97d94d4267fa7a41abdcdae131f846d9ddf2863f`; 254 lines |
| `2026-10-12T03:52:05Z` | [pinned source request](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/amount.h?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | 200; `b6865905ee31a390dd719e05dc391e4b1b278cae`; 178 lines |
| `2026-10-12T03:52:05Z` | [pinned source request](https://api.github.com/repos/bsv-blockchain/teranode/contents/settings/settings.go?ref=4edb60a40c6628ff0ef60231c2628efd7103fde5) | 200; `2baec9f11f12d2e1305d1285f7c20af07e903d8e`; 858 lines |
| `2026-10-12T03:52:05Z` | [pinned source request](https://api.github.com/repos/bsv-blockchain/go-chaincfg/contents/params.go?ref=198ccf650e914b1ece818553ade71512760e0eaf) | 200; `8350f3a5c765d93ff6bfc6c18cbda9bc930844cf`; 1037 lines |
| `2026-10-12T03:52:53Z` | [pinned source request](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/chainparams.h?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | 200; `4fba65bd7ebcac36f38b8e607a9dbede4d55c725`; 163 lines |
| `2026-10-12T03:52:53Z` | [pinned source request](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/verify_script_flags.cpp?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | 200; `29674d406ad9eb70019bebbbf608f72c9d0b4f05`; 82 lines |

**2026-10-12 (#99 continuation) [X]:** on the box at
rebased source `764dab8`, the harness built at **00:33:27–00:33:45 UTC** and
the Go module runner built at **00:33:45–00:33:46 UTC**, with Go 1.27.0 and
`GOFLAGS=-mod=mod go build -p 4`. Runner SHA-256:
`1df5a81ffe032cb71699c2682b182db1d27d3f257e96f843ae0e75c2005a91d4`. The v1.7.2 module sums in §1a are unchanged.
The seed smoke ran **00:35:47–00:35:49 UTC**, 10,000 agreements per column;
the completed 26-corpus retally ran **00:35:49–00:40:09 UTC** against recorded
`spec@cb7e46e` / `spec-mempool@cb7e46e`. Block / mempool: **276,002 / 275,986**
agreements, **58 / 75** classified runs, **3 / 2** unclassified runs,
zero unknown names, aborts or undecided runs. The tx word table is its
saved SDK table; road's two missing words were read at **00:39:52 UTC**
from an existing guarded evaluator with the same Lean tree, without a
build. Per-corpus configurations, executable identities, command times,
load samples and preservation checks are in the [record](records/20261012-002025-repin-gosdk-172-s4b.md)
and its [retally data](records/20261012-002025-repin-gosdk-172-s4b.json); the measured data commit is `85026f9d512ead74a8aebe6a68f8d47c992c5abf`. The report generator ran at
**00:40:50 UTC** and refused the five unclassified runs; the report's old
tables are explicitly retained as history. The box pins leg ran at
**00:40:50 UTC** (GREEN, 76 sites, 9 named skips); citation receipts are in
the record. No other engine or node column was re-run and no transaction
was broadcast.

**2026-10-12 (#99):** public reads of go-sdk v1.7.2, its release/CHANGELOG and its published advisory **GHSA-rh54-8fpg-8wwf**; ts-stack PR #878 and the npm publication record. The annotated tag `7ab43c0ff9f302386d92cc7766bb90799b73e557` resolves to `2ca481c5931b987a0c8f48bb341c70b7477b6b07`; release publication is 2026-10-09T05:08:55Z. The Studio clone was detached at that commit; the box clone already named it. The module proxy's source files used for this review match the clone. The `go mod download -x` URL times below are the start time of that foreground command; browser cache misses supplied no body. The [record](records/20261012-002025-repin-gosdk-172-s4b.md) separates the source read from execution evidence. No transaction was broadcast.

| UTC read time | public URL | result |
|---|---|---|
| 2026-10-12T00:05:33Z | https://api.github.com/repos/bsv-blockchain/go-sdk/git/ref/tags/v1.7.2 | GitHub REST read, exit 0 |
| 2026-10-12T00:05:33Z | https://api.github.com/repos/bsv-blockchain/go-sdk/releases/tags/v1.7.2 | GitHub REST read, exit 0 |
| 2026-10-12T00:05:34Z | https://api.github.com/repos/bsv-blockchain/go-sdk/releases/latest | GitHub REST read, exit 0 |
| 2026-10-12T00:05:34Z | https://api.github.com/repos/bsv-blockchain/ts-stack/pulls/878 | GitHub REST read, exit 0 |
| 2026-10-12T00:05:42Z | https://github.com/bsv-blockchain/go-sdk/releases/tag/v1.7.2 | browser cache miss; no body |
| 2026-10-12T00:05:42Z | https://raw.githubusercontent.com/bsv-blockchain/go-sdk/v1.7.2/CHANGELOG.md | browser cache miss; no body |
| 2026-10-12T00:06:00Z | https://api.github.com/repos/bsv-blockchain/go-sdk/git/tags/7ab43c0ff9f302386d92cc7766bb90799b73e557 | HTTPS GET successful |
| 2026-10-12T00:06:00Z | https://raw.githubusercontent.com/bsv-blockchain/go-sdk/v1.7.2/CHANGELOG.md | HTTPS GET successful |
| 2026-10-12T00:06:01Z | https://api.github.com/repos/bsv-blockchain/go-sdk/security-advisories/GHSA-rh54-8fpg-8wwf | HTTPS GET successful |
| 2026-10-12T00:06:01Z | https://registry.npmjs.org/@bsv%2Fsdk | HTTPS GET successful |
| 2026-10-12T00:08:00Z | https://github.com/bsv-blockchain/go-sdk.git | fetch refs/tags/v1.7.2 |
| 2026-10-12T00:08:57Z | https://proxy.golang.org/github.com/bsv-blockchain/go-sdk/@v/v1.7.2.info | go mod download request; start time of command |
| 2026-10-12T00:08:57Z | https://proxy.golang.org/github.com/bsv-blockchain/go-sdk/@v/v1.7.2.mod | go mod download request; start time of command |
| 2026-10-12T00:08:57Z | https://proxy.golang.org/sumdb/sum.golang.org/supported | go mod download request; start time of command |
| 2026-10-12T00:08:57Z | https://sum.golang.org/lookup/github.com/bsv-blockchain/go-sdk@v1.7.2 | go mod download request; start time of command |
| 2026-10-12T00:08:57Z | https://sum.golang.org/tile/8/0/x257/246 | go mod download request; start time of command |
| 2026-10-12T00:08:57Z | https://sum.golang.org/tile/8/3/000.p/4 | go mod download request; start time of command |
| 2026-10-12T00:08:57Z | https://sum.golang.org/tile/8/1/x001/043.p/86 | go mod download request; start time of command |
| 2026-10-12T00:08:57Z | https://sum.golang.org/tile/8/1/x001/004 | go mod download request; start time of command |
| 2026-10-12T00:08:57Z | https://sum.golang.org/tile/8/0/x267/094.p/255 | go mod download request; start time of command |
| 2026-10-12T00:08:57Z | https://sum.golang.org/tile/8/2/004.p/19 | go mod download request; start time of command |
| 2026-10-12T00:08:57Z | https://sum.golang.org/tile/8/2/003 | go mod download request; start time of command |
| 2026-10-12T00:08:57Z | https://sum.golang.org/tile/8/0/x263/155 | go mod download request; start time of command |
| 2026-10-12T00:08:57Z | https://sum.golang.org/tile/8/1/x001/027 | go mod download request; start time of command |
| 2026-10-12T00:08:57Z | https://proxy.golang.org/github.com/bsv-blockchain/go-sdk/@v/v1.7.2.zip | go mod download request; start time of command |
| 2026-10-12T00:11:45Z | https://github.com/bsv-blockchain/go-sdk/releases/tag/v1.7.2 | HTTPS 200; 203700 bytes |

**2026-10-12 (bsv-rs 0.3.33 → 0.4.4):** Exact Cargo pin and locked fetch; all seven intervening tagged changelogs read. The [record](records/20261012-011846-bump-bsv-rs-0.4.4-s3.md) names the API review and measured retally. The classifiers remain byte-identical to the work's base. Reads and SHA-256 receipts are also in its JSON companion.

| UTC read | public URL | result |
|---|---|---|
| 2026-10-12T01:13:33.396811+00:00 | https://raw.githubusercontent.com/Calhooon/bsv-rs/v0.3.34/CHANGELOG.md | tagged CHANGELOG read; API dependencies audited |
| 2026-10-12T01:13:33.553896+00:00 | https://raw.githubusercontent.com/Calhooon/bsv-rs/v0.3.35/CHANGELOG.md | tagged CHANGELOG read; API dependencies audited |
| 2026-10-12T01:13:33.699471+00:00 | https://raw.githubusercontent.com/Calhooon/bsv-rs/v0.4.0/CHANGELOG.md | tagged CHANGELOG read; API dependencies audited |
| 2026-10-12T01:13:33.854503+00:00 | https://raw.githubusercontent.com/Calhooon/bsv-rs/v0.4.1/CHANGELOG.md | tagged CHANGELOG read; API dependencies audited |
| 2026-10-12T01:13:33.993628+00:00 | https://raw.githubusercontent.com/Calhooon/bsv-rs/v0.4.2/CHANGELOG.md | tagged CHANGELOG read; API dependencies audited |
| 2026-10-12T01:13:34.148913+00:00 | https://raw.githubusercontent.com/Calhooon/bsv-rs/v0.4.3/CHANGELOG.md | tagged CHANGELOG read; API dependencies audited |
| 2026-10-12T01:13:34.196912+00:00 | https://raw.githubusercontent.com/Calhooon/bsv-rs/v0.4.4/CHANGELOG.md | tagged CHANGELOG read; API dependencies audited |
| 2026-10-12T01:13:34.438142+00:00 | https://crates.io/api/v1/crates/bsv-rs/0.4.4 | 0.4.4; checksum `a1e259211cb7002ff74656c0b0347e6159209238df43760e2a24d87ce9da6621`; not yanked |
| 2026-10-12T01:13:34.675100+00:00 | https://api.github.com/repos/Calhooon/bsv-rs/git/ref/tags/v0.4.4 | tag names `5c15528e0742beb124555d33881393ffa56f8778` |
| 2026-10-12T01:14Z | https://index.crates.io/bs/v-/bsv-rs | `cargo update -p bsv-rs --precise 0.4.4`; `cargo fetch --locked`; the package was cached |
**2026-10-12 (#58, the S6 design note):**
38 files of bitcoin-sv at `6504a3af` read by the GitHub contents API (`gh api repos/bitcoin-sv/bitcoin-sv/contents/<path>?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b`, the `content` field base64-decoded; 00:01 to 00:05 UTC; each path with its line count and blob sha in `docs/DESIGN-S6.md` §9); Teranode v0.16.0 read in the Studio's clone with `git show v0.16.0:<path>`; the tracker's issues #58 to #99 and the milestones by REST. Reads only; no upstream checkout changed; nothing broadcast.
**2026-10-12 (#58, the S6 design note):** 38 files of bitcoin-sv at `6504a3af` read by the GitHub contents API (`gh api repos/bitcoin-sv/bitcoin-sv/contents/<path>?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b`, the `content` field base64-decoded; 00:01 to 00:05 UTC; each path with its line count and blob sha in `docs/DESIGN-S6.md` §9); Teranode v0.16.0 read in the Studio's clone with `git show v0.16.0:<path>`; the tracker's issues #58 to #99 and the milestones by REST. Reads only; no upstream checkout changed; nothing broadcast. The lens's fixes (00:49 UTC): the same API re-read 25 of those files (blob shas unchanged) and four more (`src/coins.cpp`, `src/time_locked_mempool.cpp`, `src/bitcoind.cpp`, `src/rawtxvalidator.cpp`), and read Teranode's `settings/settings.go` at `4edb60a4` by `gh api repos/bsv-blockchain/teranode/contents/<path>?ref=4edb60a40c6628ff0ef60231c2628efd7103fde5`; the rows in `docs/DESIGN-S6.md` §9. Reads only.
**2026-10-12 (#58, the S6 design note):** 38 files of bitcoin-sv at `6504a3af` read by the GitHub contents API (`gh api repos/bitcoin-sv/bitcoin-sv/contents/<path>?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b`, the `content` field base64-decoded; 00:01 to 00:05 UTC; each path with its line count and blob sha in `docs/DESIGN-S6.md` §9); Teranode v0.16.0 read in the Studio's clone with `git show v0.16.0:<path>`; the tracker's issues #58 to #99 and the milestones by REST. Reads only; no upstream checkout changed; nothing broadcast. The lens's fixes (00:49 UTC): the same API re-read 25 of those files (blob shas unchanged) and four more (`src/coins.cpp`, `src/time_locked_mempool.cpp`, `src/bitcoind.cpp`, `src/rawtxvalidator.cpp`), and read Teranode's `settings/settings.go` at `4edb60a4` by `gh api repos/bsv-blockchain/teranode/contents/<path>?ref=4edb60a40c6628ff0ef60231c2628efd7103fde5`; the rows in `docs/DESIGN-S6.md` §9. Reads only. The second lens's fixes (01:31 to 01:32 UTC): the same API re-read 14 of those files (blob shas unchanged) and five more (`src/init.cpp`, `src/orphan_txns.cpp`, `src/utiltime.cpp`, `src/timedata.cpp`, `src/amount.h`); the rows in `docs/DESIGN-S6.md` §9; the tracker's #58 to #77 by REST. Reads only.

**2026-10-07 (bsv-rs 0.3.32 → 0.3.33):** `cargo search bsv-rs --limit 1` reported 0.3.33; after the exact Cargo.toml pin moved, `cargo update -p bsv-rs --precise 0.3.33` and `cargo fetch --locked` completed. Cargo.lock’s checksum agrees with crates.io; the registry copy’s VCS commit agrees with the GitHub tag and the local clone’s tag. All reads were public; the browser tag request returned no body, so the GitHub API was read directly over HTTPS. No upstream checkout changed.

| UTC read time (bsv-rs 0.3.33) | public URL | result |
|---|---|---|
| 2026-10-07T01:56Z | https://crates.io/api/v1/crates?q=bsv-rs&per_page=1 | `cargo search`: 0.3.33 |
| 2026-10-07T01:56Z | https://index.crates.io/bs/v-/bsv-rs | `cargo update`: 0.3.32 → 0.3.33; locked fetch completed; the registry copy already present |
| 2026-10-07T01:56Z | https://api.github.com/repos/Calhooon/bsv-rs/git/ref/tags/v0.3.33 | browser inaccessible; no body |
| 2026-10-07T01:56Z | https://github.com/Calhooon/bsv-rs.git | `git ls-remote`: `a395c72fe5a7e5ca7a625b1c1bebfe755435620d` |
| 2026-10-07T01:57:07Z | https://crates.io/api/v1/crates/bsv-rs/0.3.33 | published 2026-10-07T01:51:49.020699Z; not yanked; checksum `dcb878969c663f4aad400775420e1308239af7f253b714748b03f988d8832efb` |
| 2026-10-07T01:57:07Z | https://api.github.com/repos/Calhooon/bsv-rs/git/ref/tags/v0.3.33 | tag directly names commit `a395c72fe5a7e5ca7a625b1c1bebfe755435620d` |
| 2026-10-07T01:57:07Z | https://api.github.com/repos/Calhooon/bsv-rs/issues/41 | closed at 2026-10-07T01:53:07Z |
| 2026-10-07T02:01:21Z to 02:01:39Z | https://index.crates.io/bs/v-/bsv-rs and https://static.crates.io/crates/bsv-rs/bsv-rs-0.3.33.crate | box release build: registry index read and locked 0.3.33 crate downloaded |
| 2026-10-07T02:10:47Z to 02:11:38Z | https://github.com/Calhooon/bsv-rs.git | box foreground validation: fetched tag `v0.3.33`; pins leg verified `a395c72fe5a7e5ca7a625b1c1bebfe755435620d` |


Public source repositories were cloned or fetched to read them (bitcoin-sv,
bdk, the Teranode tag `v0.15.9`, and at #54 the tag `v0.16.0`); GitHub's release metadata and crates.io's
index were queried for "newest release"; one public chain-tip read (§3).

**2026-09-22T18:30Z (#12, the mainnet sighash vectors):** WhatsOnChain
`block/height/400000` and `block/height/950000` (the transaction lists), then
`tx/{txid}/hex` for three transactions of each block and for every prevout
transaction of their inputs (`tools/mainnet_read.py`; the entries
`corpus/sighash/mainnet.jsonl`, `corpus/INDEX.md` §3). Reads only, of public
transactions from 2016 and 2026-05; none is a transaction of the private
programs (block 950,000 precedes their mainnet activity; `tools/mechanism_check.sh`
run over `corpus/sighash`).

**2026-09-23 (the bump to bsv-rs 0.3.27, on the maintainers' R4):** crates.io's sparse index was read (`cargo update -p bsv-rs`) and the crate `bsv-rs 0.3.27` downloaded (`cargo fetch`) into the local registry; its `src/script/{spend,flags,script}.rs` are byte-identical to the local clone's tag `v0.3.27` (`diff`; the crate's `Cargo.toml` differs only by crates.io's normalization). A read of a public registry, as the earlier pins were read.

**2026-10-06 02:1x UTC (the bump to bsv-rs 0.3.32; the pin's fourth move, R1.6, straight from 0.3.30):** crates.io's sparse index was read (`cargo search bsv-rs --limit 1`: `bsv-rs = "0.3.32"`; `cargo update -p bsv-rs --precise 0.3.32` after `harness/Cargo.toml` moved to `=0.3.32`) and the crate `bsv-rs 0.3.32` downloaded (`cargo fetch --locked`) into the local registry; the lock's checksum `e6fc1a51…` is the index's; the crate's `.cargo_vcs_info.json` names commit `c05edf5`, which is the tag `v0.3.32` in the box's clone (fetched there by another read during the bump; the bump itself fetched nothing; `docs/records/20261006-022032-bump-bsv-rs-0.3.32-s3.md`). A read of a public registry, as the earlier pins were read.

**2026-09-27 16:4x UTC (the bump to bsv-rs 0.3.30, S3 in set 4; the pin's third move, #47, straight from 0.3.28):** crates.io's sparse index was read (`cargo update -p bsv-rs --precise 0.3.29` at 13:2x UTC for the move first prepared at 0.3.29, then `--precise 0.3.30` after `harness/Cargo.toml` moved to `=0.3.30`) and the crate `bsv-rs 0.3.30` downloaded into the local registry; its `src/script/{spend,flags,script,script_num,evaluation_error}.rs` are byte-identical to the local clone's tag `v0.3.30` = `c7ff2c3` (`cmp`), and the lock's checksum `83c0a8a5…` is crates.io's (T3's release record `docs/records/20260927-152550-release-bsv-rs-0.3.30-t3.md`). A read of a public registry, as the earlier pins were read.

**2026-09-24 02:34 UTC (the bump to bsv-rs 0.3.28, S3 in set 3; the pin's second move):** crates.io's sparse index was read (`cargo update -p bsv-rs` after `harness/Cargo.toml` moved to `=0.3.28`) and the crate `bsv-rs 0.3.28` downloaded (`cargo fetch`) into the local registry; its `src/script/{spend,flags,script,script_num}.rs` are byte-identical to the local clone's tag `v0.3.28` = `a97b9b6` (`cmp`). A read of a public registry, as the earlier pins were read. **The same day (S3): the tripwire's Modal route** (`tools/modal_check.py`, D17/D17b): the container's image build and bake read, all pinned and all reads, Modal itself, crates.io (the locked crate set), elan.lean-lang.org and releases.lean-lang.org (elan, the Lean toolchain of `lean/lean-toolchain`), GitHub and Mathlib's cache server (`lake exe cache get` at the manifest's rev), go.dev (the Go 1.27.0 tarball, verified against go.dev's sha256 list), proxy.golang.org and sum.golang.org (go-sdk at v1.5.2, go.sum-verified), nodejs.org (the node 22.18.0 tarball, verified against its SHASUMS256.txt) and registry.npmjs.org (@bsv/sdk 2.8.0 at the lock's integrity); the runs' logs live on the Modal Volume `<modal-name>`, their records in `docs/records/`. Nothing of any private program enters the container (the tree shipped is this repo's).

**2026-09-23 (S3, #40/#29, the engine pins):** the npm registry (`npm view @bsv/sdk`: the versions, their
publish times, the 2.8.0 tarball's integrity; `npm install` of that one tarball into
`harness/engines/ts/node_modules`, uncommitted), the Go module proxy (`go mod download`
`github.com/bsv-blockchain/go-sdk@v1.2.24` and `@v1.5.2`, then `go mod tidy` for the adapter's transitive
modules, `harness/engines/go/go.sum`), GitHub (`git fetch --tags` of the `go-sdk` and `ts-stack` clones; the
`ts-sdk` repository's archived flag through the REST API). Registry and repository reads of public packages;
no chain, no node.

**2026-09-28 11:46:17 to 11:49:40 UTC (#26's carried replay reading, the C2 audit's S.G10):**
WhatsOnChain
`block/height/173805`, then `tx/{txid}/hex` for the block's 106 transactions and for the transaction of every one of their 256
inputs' prevouts, 336 requests (`tools/replay_p2sh.py`; the answer `docs/records/20260928-115150-replay-173805-s3.md`: no P2SH-shaped output is spent
in the block). Reads only, of public transactions of 2012-04-01; none is a transaction of the private programs.

**2026-09-29 05:29:32 to 05:52:34 UTC (#39, the recon's entry 1):**

| UTC read time (entry 1) | public URL |
| --- | --- |
| 2026-09-29T05:29:32Z | https://api.github.com/repos/bitcoin-sv/bitcoin-sv/releases?per_page=100 |
| 2026-09-29T05:29:33Z | https://api.github.com/repos/bitcoin-sv/bitcoin-sv/tags?per_page=100 |
| 2026-09-29T05:29:34Z | https://api.github.com/repos/bsv-blockchain/teranode/releases?per_page=100 |
| 2026-09-29T05:29:35Z | https://api.github.com/repos/bsv-blockchain/teranode/tags?per_page=100 |
| 2026-09-29T05:29:36Z | https://api.github.com/repos/bitcoin-sv/bdk/releases?per_page=100 |
| 2026-09-29T05:29:36Z | https://api.github.com/repos/bitcoin-sv/bdk/tags?per_page=100 |
| 2026-09-29T05:29:37Z | https://api.github.com/repos/bsv-blockchain/go-chaincfg/releases?per_page=100 |
| 2026-09-29T05:29:37Z | https://api.github.com/repos/bsv-blockchain/go-chaincfg/tags?per_page=100 |
| 2026-09-29T05:29:38Z | https://api.github.com/repos/Calhooon/bsv-rs/releases?per_page=100 |
| 2026-09-29T05:29:38Z | https://api.github.com/repos/Calhooon/bsv-rs/tags?per_page=100 |
| 2026-09-29T05:29:39Z | https://api.github.com/repos/bsv-blockchain/go-sdk/releases?per_page=100 |
| 2026-09-29T05:29:40Z | https://api.github.com/repos/bsv-blockchain/go-sdk/tags?per_page=100 |
| 2026-09-29T05:29:40Z | https://api.github.com/repos/bsv-blockchain/ts-stack/releases?per_page=100 |
| 2026-09-29T05:29:41Z | https://api.github.com/repos/bsv-blockchain/ts-stack/tags?per_page=100 |
| 2026-09-29T05:29:53Z | https://api.github.com/repos/bitcoin-sv/bitcoin-sv/branches?per_page=100 |
| 2026-09-29T05:29:54Z | https://api.github.com/repos/bitcoin-sv/bitcoin-sv |
| 2026-09-29T05:30:00Z | https://api.github.com/repos/bitcoin-sv/bitcoin-sv/commits/develop |
| 2026-09-29T05:30:01Z | https://api.github.com/repos/bitcoin-sv/bitcoin-sv/commits/dev |
| 2026-09-29T05:30:02Z | https://api.github.com/repos/bitcoin-sv/bitcoin-sv/commits/master |
| 2026-09-29T05:31:08Z | https://registry.npmjs.org/@bsv%2fsdk |
| 2026-09-29T05:31:08Z | https://crates.io/api/v1/crates/bsv-rs |
| 2026-09-29T05:31:09Z | https://index.crates.io/bs/v-/bsv-rs |
| 2026-09-29T05:31:09Z | https://proxy.golang.org/github.com/bsv-blockchain/go-sdk/@v/list |
| 2026-09-29T05:31:10Z | https://proxy.golang.org/github.com/bsv-blockchain/go-sdk/@latest |
| 2026-09-29T05:31:10Z | https://proxy.golang.org/github.com/bsv-blockchain/go-chaincfg/@v/list |
| 2026-09-29T05:31:12Z | https://proxy.golang.org/github.com/bsv-blockchain/go-chaincfg/@latest |
| 2026-09-29T05:31:12Z | https://proxy.golang.org/github.com/bitcoin-sv/bdk/module/gobdk/@v/list |
| 2026-09-29T05:31:13Z | https://proxy.golang.org/github.com/bitcoin-sv/bdk/module/gobdk/@latest |
| 2026-09-29T05:31:13Z | https://proxy.golang.org/github.com/bsv-blockchain/teranode/@v/list |
| 2026-09-29T05:31:34Z | https://github.com/bsv-blockchain/teranode.git |
| 2026-09-29T05:31:35Z | https://github.com/bsv-blockchain/go-sdk.git |
| 2026-09-29T05:31:35Z | https://github.com/bsv-blockchain/go-chaincfg.git |
| 2026-09-29T05:31:36Z | https://github.com/Calhooon/bsv-rs.git |
| 2026-09-29T05:31:36Z | https://github.com/bitcoin-sv/bdk.git |
| 2026-09-29T05:31:53Z | https://github.com/bsv-blockchain/go-chaincfg.git |
| 2026-09-29T05:31:53Z | https://github.com/bitcoin-sv/bdk.git |
| 2026-09-29T05:32:45Z | https://github.com/bitcoin-sv/bdk/blob/4eab3acdbbb971724f37e886e836daa1ed444a7f/module/gobdk/bdkcgo/libGoBDK_darwin_arm64.a |
| 2026-09-29T05:32:45Z | https://github.com/bitcoin-sv/bdk/blob/4eab3acdbbb971724f37e886e836daa1ed444a7f/module/gobdk/bdkcgo/libGoBDK_linux_x86_64.a |
| 2026-09-29T05:36:23Z | https://github.com/bsv-blockchain/teranode.git |
| 2026-09-29T05:36:30Z | https://github.com/bsv-blockchain/teranode.git |
| 2026-09-29T05:37:36Z | https://github.com/bsv-blockchain/ts-stack.git |
| 2026-09-29T05:38:56Z | https://api.github.com/repos/Calhooon/bsv-rs |
| 2026-09-29T05:38:57Z | https://api.github.com/repos/Calhooon/bsv-rs/branches?per_page=100 |
| 2026-09-29T05:38:57Z | https://api.github.com/repos/Calhooon/bsv-rs/pulls?state=all&per_page=10&sort=updated&direction=desc |
| 2026-09-29T05:39:24Z | https://api.github.com/repos/bsv-blockchain/teranode/releases/latest |
| 2026-09-29T05:39:24Z | https://api.github.com/repos/bitcoin-sv/bitcoin-sv/releases/latest |
| 2026-09-29T05:39:25Z | https://api.github.com/repos/bsv-blockchain/go-sdk/releases/latest |
| 2026-09-29T05:39:25Z | https://api.github.com/repos/bsv-blockchain/go-chaincfg/releases/latest |
| 2026-09-29T05:39:26Z | https://api.github.com/repos/Calhooon/bsv-rs/releases/latest |

- GitHub REST on the public repositories: the releases, tags, branches, `releases/latest` and head commits of
  `bitcoin-sv/bitcoin-sv`, `bsv-blockchain/teranode`, `bitcoin-sv/bdk`, `bsv-blockchain/go-chaincfg`,
  `Calhooon/bsv-rs`, `bsv-blockchain/go-sdk` and `bsv-blockchain/ts-stack`; and, as the reporter, the two repositories'
  security advisories.
- The npm registry (`@bsv/sdk`'s document), crates.io (`bsv-rs`'s API page and its sparse-index file) and the Go module
  proxy (`@v/list` and `@latest` for go-sdk, go-chaincfg, GoBDK and Teranode).
- `git fetch` of public tags and branches into scratch repositories outside every tree, which borrow the shared clones'
  objects and never write them: Teranode v0.15.9 and v0.16.0-beta-1 to -14; go-sdk v1.2.24, v1.5.2, v1.6.0 and v1.7.0;
  every go-chaincfg and BDK tag, with BDK's `master`; bsv-rs v0.3.30 and `main`; ts-stack's `main`. Two GoBDK archives
  at `4eab3ac` were read with `strings`.

Every read with its time is in `docs/records/20260929-054539-recon-1-s4b.md` §6 and
`docs/records/20260929-055242-d135-ghsa-state-s4b.md`; the entry is `docs/recon.md`. Reads only.

**2026-10-05 (#39, the recon's entry 2):**
Public release, tag, registry and source reads; [entry record](records/20261005-220818-recon-2.md) §6.

| UTC read time (entry 2) | public URL |
| --- | --- |
| 2026-10-05T21:54:06Z | https://api.github.com/repos/bsv-blockchain/go-sdk/releases/tags/v1.6.0 |
| 2026-10-05T21:54:06Z | https://api.github.com/repos/bsv-blockchain/go-sdk/releases/tags/v1.7.0 |
| 2026-10-05T21:54:06Z | https://registry.npmjs.org/@bsv%2fsdk |
| 2026-10-05T21:54:06Z | https://api.github.com/repos/bsv-blockchain/ts-stack/tags?per_page=100 |
| 2026-10-05T21:54:28Z | https://api.github.com/repos/bsv-blockchain/ts-stack/contents?ref=main |
| 2026-10-05T21:54:28Z | https://api.github.com/repos/bsv-blockchain/ts-stack/contents/packages/sdk/CHANGELOG.md?ref=main |
| 2026-10-05T21:55:07Z | https://api.github.com/repos/bsv-blockchain/ts-stack/contents/packages/sdk?ref=main |
| 2026-10-05T21:56:40Z | https://api.github.com/repos/bitcoin-sv/bitcoin-sv/releases?per_page=100 |
| 2026-10-05T21:56:40Z | https://api.github.com/repos/bitcoin-sv/bitcoin-sv/tags?per_page=100 |
| 2026-10-05T21:56:40Z | https://api.github.com/repos/bsv-blockchain/teranode/releases?per_page=100 |
| 2026-10-05T21:56:40Z | https://api.github.com/repos/bsv-blockchain/teranode/tags?per_page=100 |
| 2026-10-05T21:56:41Z | https://api.github.com/repos/bitcoin-sv/bdk/releases?per_page=100 |
| 2026-10-05T21:56:41Z | https://api.github.com/repos/bitcoin-sv/bdk/tags?per_page=100 |
| 2026-10-05T21:56:41Z | https://api.github.com/repos/Calhooon/bsv-rs/releases?per_page=100 |
| 2026-10-05T21:56:41Z | https://api.github.com/repos/Calhooon/bsv-rs/tags?per_page=100 |
| 2026-10-05T21:56:41Z | https://api.github.com/repos/bsv-blockchain/go-sdk/releases?per_page=100 |
| 2026-10-05T21:56:41Z | https://api.github.com/repos/bsv-blockchain/go-sdk/tags?per_page=100 |
| 2026-10-05T21:56:42Z | https://proxy.golang.org/github.com/bitcoin-sv/bdk/module/gobdk/@latest |
| 2026-10-05T21:56:42Z | https://proxy.golang.org/github.com/bitcoin-sv/bdk/module/gobdk/@v/list |
| 2026-10-05T21:56:42Z | https://proxy.golang.org/github.com/bsv-blockchain/go-chaincfg/@latest |
| 2026-10-05T21:56:42Z | https://proxy.golang.org/github.com/bsv-blockchain/go-chaincfg/@v/list |
| 2026-10-05T21:56:42Z | https://api.github.com/repos/bsv-blockchain/go-chaincfg/releases?per_page=100 |
| 2026-10-05T21:56:42Z | https://api.github.com/repos/bsv-blockchain/go-chaincfg/tags?per_page=100 |
| 2026-10-05T21:56:42Z | https://proxy.golang.org/github.com/bsv-blockchain/go-sdk/@latest |
| 2026-10-05T21:56:42Z | https://proxy.golang.org/github.com/bsv-blockchain/go-sdk/@v/list |
| 2026-10-05T21:56:42Z | https://proxy.golang.org/github.com/bsv-blockchain/teranode/@latest |
| 2026-10-05T21:56:42Z | https://proxy.golang.org/github.com/bsv-blockchain/teranode/@v/list |
| 2026-10-05T21:56:42Z | https://api.github.com/repos/bsv-blockchain/ts-stack/releases?per_page=100 |
| 2026-10-05T21:56:43Z | https://crates.io/api/v1/crates/bsv-rs |
| 2026-10-05T21:56:43Z | https://index.crates.io/bs/v-/bsv-rs |
| 2026-10-05T21:58:12Z | https://api.github.com/repos/bsv-blockchain/teranode/releases/tags/v0.16.1-beta-1 |
| 2026-10-05T21:58:12Z | https://api.github.com/repos/bsv-blockchain/teranode/contents/go.mod?ref=v0.16.1-beta-1 |
| 2026-10-05T21:58:12Z | https://api.github.com/repos/bsv-blockchain/teranode/git/ref/tags/v0.16.1-beta-1 |
| 2026-10-05T21:58:12Z | https://api.github.com/repos/bsv-blockchain/teranode/compare/v0.15.9...v0.16.0?per_page=100 |
| 2026-10-05T21:58:12Z | https://api.github.com/repos/bsv-blockchain/teranode/contents/go.mod?ref=v0.15.9 |
| 2026-10-05T21:58:12Z | https://api.github.com/repos/bsv-blockchain/teranode/releases/tags/v0.16.0 |
| 2026-10-05T21:58:12Z | https://api.github.com/repos/bsv-blockchain/teranode/contents/go.mod?ref=v0.16.0 |
| 2026-10-05T21:58:12Z | https://api.github.com/repos/bsv-blockchain/teranode/git/ref/tags/v0.16.0 |
| 2026-10-05T21:58:13Z | https://api.github.com/repos/Calhooon/bsv-rs/compare/v0.3.30...v0.3.31 |
| 2026-10-05T21:58:13Z | https://static.crates.io/crates/bsv-rs/bsv-rs-0.3.30.crate |
| 2026-10-05T21:58:13Z | https://static.crates.io/crates/bsv-rs/bsv-rs-0.3.31.crate |
| 2026-10-05T21:58:13Z | https://api.github.com/repos/Calhooon/bsv-rs/releases/tags/v0.3.31 |
| 2026-10-05T21:58:13Z | https://api.github.com/repos/Calhooon/bsv-rs/git/ref/tags/v0.3.31 |
| 2026-10-05T21:58:13Z | https://api.github.com/repos/Calhooon/bsv-rs/commits/v0.3.31 |
| 2026-10-05T21:58:13Z | https://api.github.com/repos/bsv-blockchain/teranode/contents/settings/policy_settings.go?ref=v0.15.9 |
| 2026-10-05T21:58:13Z | https://api.github.com/repos/bsv-blockchain/teranode/contents/settings/policy_settings.go?ref=v0.16.0 |
| 2026-10-05T21:58:14Z | https://api.github.com/repos/Calhooon/bsv-rs/contents/Cargo.toml?ref=v0.3.31 |
| 2026-10-05T21:58:14Z | https://api.github.com/repos/Calhooon/bsv-rs/contents/CHANGELOG.md?ref=v0.3.30 |
| 2026-10-05T21:58:14Z | https://api.github.com/repos/Calhooon/bsv-rs/contents/CHANGELOG.md?ref=v0.3.31 |
| 2026-10-05T21:58:14Z | https://api.github.com/repos/bsv-blockchain/go-chaincfg/compare/v1.5.8...v1.7.0 |
| 2026-10-05T21:58:14Z | https://api.github.com/repos/bsv-blockchain/go-chaincfg/contents/params.go?ref=v1.7.0 |
| 2026-10-05T21:58:14Z | https://api.github.com/repos/bsv-blockchain/go-chaincfg/contents/params.go?ref=v1.5.8 |
| 2026-10-05T21:58:14Z | https://api.github.com/repos/bsv-blockchain/go-sdk/releases/tags/v1.7.1 |
| 2026-10-05T22:00:08Z | https://api.github.com/repos/bitcoin-sv/bdk/compare/cdfa7814ee5da7b899e7301f058710002baaea40...4eab3acdbbb9 |
| 2026-10-05T22:00:08Z | https://api.github.com/repos/bitcoin-sv/bdk/git/trees/cdfa7814ee5da7b899e7301f058710002baaea40?recursive=1 |
| 2026-10-05T22:00:08Z | https://proxy.golang.org/github.com/bitcoin-sv/bdk/module/gobdk/@v/v1.2.5-0.20260918043653-4eab3acdbbb9.info |
| 2026-10-05T22:00:08Z | https://proxy.golang.org/github.com/bitcoin-sv/bdk/module/gobdk/@v/v1.2.5-0.20260918043653-4eab3acdbbb9.mod |
| 2026-10-05T22:00:09Z | https://api.github.com/repos/bitcoin-sv/bdk/git/trees/4eab3acdbbb9?recursive=1 |
| 2026-10-05T22:00:09Z | https://api.github.com/repos/bsv-blockchain/go-chaincfg/contents/params.go?ref=v1.6.2 |
| 2026-10-05T22:00:09Z | https://api.github.com/repos/bsv-blockchain/teranode/compare/v0.16.0...v0.16.1-beta-1 |
| 2026-10-05T22:00:09Z | https://api.github.com/repos/bsv-blockchain/teranode/git/trees/04022a51db3a836ee2a4a4600903566ee4ccb607?recursive=1 |
| 2026-10-05T22:00:09Z | https://api.github.com/repos/bsv-blockchain/teranode/git/trees/4edb60a40c6628ff0ef60231c2628efd7103fde5?recursive=1 |
| 2026-10-05T22:00:10Z | https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/configscriptpolicy.cpp?ref=v1.2.2 |
| 2026-10-05T22:00:10Z | https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/bitcoind.cpp?ref=v1.2.2 |
| 2026-10-05T22:00:10Z | https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/policy/policy.h?ref=v1.2.2 |
| 2026-10-05T22:00:10Z | https://api.github.com/repos/Calhooon/bsv-rs/git/trees/28a64032d2e8365e742a99ac4c0e3b6e8ed8446d?recursive=1 |
| 2026-10-05T22:00:47Z | https://api.github.com/repos/Calhooon/bsv-rs/tarball/28a64032d2e8365e742a99ac4c0e3b6e8ed8446d |
| 2026-10-05T22:00:47Z | https://registry.npmjs.org/@bsv/sdk/-/sdk-2.8.10.tgz |
| 2026-10-05T22:00:47Z | https://registry.npmjs.org/@bsv/sdk/-/sdk-3.0.0.tgz |
| 2026-10-05T22:02:09Z | https://api.github.com/repos/bitcoin-sv/bdk/contents/core/txvalidator.cpp?ref=cdfa7814ee5da7b899e7301f058710002baaea40 |
| 2026-10-05T22:02:09Z | https://api.github.com/repos/bitcoin-sv/bdk/contents/core/txvalidator.cpp?ref=4eab3acdbbb9 |
| 2026-10-05T22:02:09Z | https://api.github.com/repos/bitcoin-sv/bdk/contents/core/setting-bitcoin.cmake?ref=cdfa7814ee5da7b899e7301f058710002baaea40 |
| 2026-10-05T22:02:09Z | https://api.github.com/repos/bitcoin-sv/bdk/contents/core/setting-bitcoin.cmake?ref=4eab3acdbbb9 |
| 2026-10-05T22:02:09Z | https://api.github.com/repos/bitcoin-sv/bdk/contents/module/gobdk/script/txvalidator.go?ref=cdfa7814ee5da7b899e7301f058710002baaea40 |
| 2026-10-05T22:02:09Z | https://api.github.com/repos/bitcoin-sv/bdk/contents/module/gobdk/script/txvalidator.go?ref=4eab3acdbbb9 |
| 2026-10-05T22:02:09Z | https://api.github.com/repos/bsv-blockchain/teranode/contents/model/Block.go?ref=v0.15.9 |
| 2026-10-05T22:02:09Z | https://api.github.com/repos/bsv-blockchain/teranode/contents/model/Block.go?ref=v0.16.0 |
| 2026-10-05T22:02:09Z | https://api.github.com/repos/bsv-blockchain/teranode/contents/services/validator/ScriptVerifierGoBDK.go?ref=v0.15.9 |
| 2026-10-05T22:02:09Z | https://api.github.com/repos/bsv-blockchain/teranode/contents/services/validator/ScriptVerifierGoBDK.go?ref=v0.16.0 |
| 2026-10-05T22:02:09Z | https://api.github.com/repos/bsv-blockchain/teranode/contents/settings/settings.go?ref=v0.15.9 |
| 2026-10-05T22:02:09Z | https://api.github.com/repos/bsv-blockchain/teranode/contents/settings/settings.go?ref=v0.16.0 |
| 2026-10-05T22:02:10Z | https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/consensus/consensus.h?ref=v1.2.2 |
| 2026-10-05T22:02:10Z | https://api.github.com/repos/bsv-blockchain/teranode/contents/services/legacy/txscript/opcode.go?ref=v0.15.9 |
| 2026-10-05T22:02:10Z | https://api.github.com/repos/bsv-blockchain/teranode/contents/services/legacy/txscript/opcode.go?ref=v0.16.0 |
| 2026-10-05T22:04:46Z | https://api.github.com/repos/bitcoin-sv/bdk/contents/cmake/BDKInit.cmake?ref=cdfa7814ee5da7b899e7301f058710002baaea40 |
| 2026-10-05T22:04:46Z | https://api.github.com/repos/bitcoin-sv/bdk/contents/cmake/BDKInit.cmake?ref=4eab3acdbbb9 |
| 2026-10-05T22:04:46Z | https://api.github.com/repos/bitcoin-sv/bdk/contents/cmake/modules/FindBSVSourceHelper.cmake?ref=cdfa7814ee5da7b899e7301f058710002baaea40 |
| 2026-10-05T22:04:46Z | https://api.github.com/repos/bitcoin-sv/bdk/contents/cmake/modules/FindBSVSourceHelper.cmake?ref=4eab3acdbbb9 |
| 2026-10-05T22:04:47Z | https://api.github.com/repos/bitcoin-sv/bdk/contents/core/txvalidator.hpp?ref=4eab3acdbbb9 |
| 2026-10-05T22:04:47Z | https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/script/interpreter.cpp?ref=v1.2.2 |
| 2026-10-05T22:04:47Z | https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/consensus/tx_verify.cpp?ref=v1.2.2 |
| 2026-10-05T22:05:54Z | https://api.github.com/repos/bitcoin-sv/bdk/contents/.github/workflows/build_bdk.yaml?ref=cdfa7814ee5da7b899e7301f058710002baaea40 |
| 2026-10-05T22:05:54Z | https://api.github.com/repos/bitcoin-sv/bdk/contents/.github/workflows/build_bdk.yaml?ref=4eab3acdbbb9 |

**2026-10-05 (#51 and #52):**
REST reads of issues 51 and 52 and comments 5897916282 and 5897916561 supply the done-bars and the study figures. `make gosdk-build` reads the v1.7.0 module through the Go proxy/cache with go.sum verification; `make tssdk-install` reads @bsv/sdk 2.8.10 through npm at the lock's integrity. Source citations above were re-read from the installed module and the npm source map. Commands, measured results and source hashes: `docs/records/20261005-231710-repin51-52-s2.md` (the second record; it checked the earlier run and re-read the cited lines). Reads only.

**2026-10-05 (#55):**
the REST read of issue 55 supplies the done-bar. `go get github.com/bsv-blockchain/go-sdk@v1.7.1` and `go mod tidy` read the module through the Go proxy, verified by `go.sum` and the checksum database as `go` consults it; `npm install --save-exact @bsv/sdk@3.0.0` and `npm ci` read the package at the lock's integrity; `npm pack @bsv/sdk@2.8.10` read the previous release for the comparison of the two builds; the ts-stack REST reads found the 3.0.0 source commit (no tag exists) and checked `Spend.ts` there against the installed source map. Record: `docs/records/20261006-005415-repin55.md`. Reads only.

| UTC read time (#55) | public URL |
| --- | --- |
| 2026-10-05T23:41:00Z | https://proxy.golang.org/github.com/bsv-blockchain/go-sdk/@v/v1.7.1.info |
| 2026-10-05T23:41:00Z | https://proxy.golang.org/github.com/bsv-blockchain/go-sdk/@v/v1.7.1.mod |
| 2026-10-05T23:41:00Z | https://proxy.golang.org/github.com/bsv-blockchain/go-sdk/@v/v1.7.1.zip |
| 2026-10-05T23:41:00Z | https://proxy.golang.org/github.com/davecgh/go-spew/@v/v1.1.1.zip |
| 2026-10-05T23:41:34Z | https://registry.npmjs.org/@bsv%2fsdk |
| 2026-10-05T23:41:34Z | https://registry.npmjs.org/@bsv/sdk/-/sdk-3.0.0.tgz |
| 2026-10-05T23:41:44Z | https://api.github.com/repos/bsv-blockchain/ts-stack/contents/packages/sdk/CHANGELOG.md?ref=main (#55) |
| 2026-10-05T23:41:55Z | https://registry.npmjs.org/@bsv/sdk/-/sdk-2.8.10.tgz (#55, the comparison copy, unpacked under /tmp) |
| 2026-10-05T23:45:38Z | https://registry.npmjs.org/@bsv%2fsdk (`npm view`: `dist.integrity`, `repository`, no `gitHead`) |
| 2026-10-05T23:45:45Z | https://registry.npmjs.org/@bsv%2fsdk (`npm view time`) |
| 2026-10-05T23:45:45Z | https://api.github.com/repos/bsv-blockchain/ts-stack/commits?path=packages/sdk/package.json&per_page=15 |
| 2026-10-05T23:45:45Z | https://api.github.com/repos/bsv-blockchain/ts-stack/tags?per_page=30 |
| 2026-10-05T23:45:50Z | https://api.github.com/repos/bsv-blockchain/ts-stack/contents/packages/sdk/package.json?ref=4d0ea63c85a836e3509291babb0d8e0c784b70a0 |
| 2026-10-05T23:45:50Z | https://api.github.com/repos/bsv-blockchain/ts-stack/contents/packages/sdk/package.json?ref=20c761568599ccc1e8e7cc1d18eedd38ad607703 |
| 2026-10-05T23:45:50Z | https://api.github.com/repos/bsv-blockchain/ts-stack/contents/packages/sdk/package.json?ref=e48e6d1f5906b7ef1884f6610a5a221539162f6f |
| 2026-10-05T23:45:50Z | https://api.github.com/repos/bsv-blockchain/ts-stack/commits?sha=main&since=2026-10-02T19:00:00Z&until=2026-10-03T15:00:00Z&per_page=30 |
| 2026-10-05T23:45:57Z | https://api.github.com/repos/bsv-blockchain/ts-stack/commits?path=packages/sdk&since=2026-10-01T00:00:00Z&until=2026-10-05T23:59:00Z&per_page=30 |
| 2026-10-05T23:45:57Z | https://api.github.com/repos/bsv-blockchain/ts-stack/tags?per_page=100 (#55) |
| 2026-10-05T23:46:03Z | https://api.github.com/repos/bsv-blockchain/ts-stack/contents/packages/sdk/src/script/Spend.ts?ref=4d0ea63c85a836e3509291babb0d8e0c784b70a0 |
| 2026-10-05T23:46:03Z | https://api.github.com/repos/bsv-blockchain/ts-stack/contents/packages/sdk/src/script/Spend.ts?ref=5a4053223692b020372f5a8e20f59bf9c82cc968 |

**2026-10-06 01:16 to 01:23 UTC (#54, on the box):**
GitHub REST `git/ref/tags/v0.16.0` of `bsv-blockchain/teranode` (01:16:54Z: commit `4edb60a4…`) and `git/ref/tags/v1.6.2` of `bsv-blockchain/go-chaincfg` (01:16:54Z: the annotated tag `c7306e45…`); the Go module proxy's `.info` for go-chaincfg v1.6.2 (01:16:54Z: `198ccf65…`), for GoBDK `v1.2.5-0.20260918043653-4eab3acdbbb9` (01:16:55Z: `4eab3acd…`) and for Teranode v0.16.0 (01:16:55Z); `raw.githubusercontent.com` for Teranode's `go.mod` and `go.sum` at `4edb60a4…` (01:16:56Z); shallow fetches from GitHub of the three repositories at the pinned commits and at the old ones (`d81fcaba…`, `04022a51…`, `cdfa7814…`) into `<the maintainers' build host>:targets/spec-54/` (01:17:04Z to 01:17:25Z); `sum.golang.org/lookup` for both modules (01:23:08Z). The record is `docs/records/20261006-014513-repin54.md`.

**2026-10-06T02:10:44Z (#34, the license texts):**
one GET each, copied verbatim into `LICENSE` (below its copyright line) and `LICENSE-APACHE`.

| time (UTC) | URL | sha256 of the text |
|---|---|---|
| 2026-10-06T02:10:44Z | https://raw.githubusercontent.com/bitcoin-sv/bitcoin-sv/879fc8b42168dd0e608dafd51b39c6dabad37d4d/LICENSE | `d869a62568556cc7f61304b768074b40d7511ddb414f4e546101f860ee0ea853` |
| 2026-10-06T02:10:44Z | https://www.apache.org/licenses/LICENSE-2.0.txt | `cfc7749b96f63bd31c3c42b5c471bf756814053e847c10f3eb003417bc523d30` |

**2026-10-18 (#34):**
the copyright line above the text in `LICENSE` dropped on the maintainers' decision (the holder is named in `NOTICE` line 2); `LICENSE` is now the read above whole, sha256 `d869a62568556cc7f61304b768074b40d7511ddb414f4e546101f860ee0ea853`, equal to `corpus/cpp/LICENSE` (the reference's file at `6504a3a`) [M].

**2026-10-06 13:54 to 14:08 UTC (the official x86-64 release binary measured; the record `docs/records/20261006-141025-r1-x86.md`):**
GitHub REST `repos/bitcoin-sv/bitcoin-sv/releases/tags/v1.2.2` (13:54:56Z: the release's metadata, `"assets": []`; 13:55:15Z: its body); the download host's indexes `https://download.bitcoinsv.io/bitcoinsv/1.2.2/` and `https://download.bitcoinsv.io/bitcoinsv/` (13:55:18Z; the parent lists `1.2.3/` dated 06-Oct-2026, newer than the pin, not opened: the recon's); `https://download.bitcoinsv.io/bitcoinsv/1.2.2/SHA256SUMS.asc` (13:56:48Z at home, sha256 `f4f5a1de…`; 14:06:47Z and 14:08:08Z in the containers) and `https://download.bitcoinsv.io/bitcoinsv/1.2.2/bitcoin-sv-1.2.2-x86_64-linux-gnu.tar.gz` (13:58:36Z at home; 14:06:50Z and 14:08:08Z in the containers; 31,396,795 bytes, sha256 `d8b181c8…` at every read). Public reads; the container's two regtest instances listened on the loopback only with empty chains; nothing was broadcast.

Nothing was broadcast; no node was contacted. CLAUDE.md rule 10 concerns the
blockchain network; this section exists so that the reads are on the record.

**2026-10-06 (#39, recon entry 3):** bitcoin-sv
v1.2.3's public release, annotated tag/commit, source comparison and changed
script sources, plus the official download indexes and checksum text.
[Entry](recon.md#entry-3--2026-10-06) and
[record](records/20261006-143018-recon-3.md) carry the classification and the pin move
owed under archived #57. Other upstreams were not re-read; section 1a's
pins are unchanged. 21 upstream reads/attempts, 16 live text bodies. The
browser result was stale or inaccessible; the 14:20:51Z times are snapshot
save times immediately after receipt, and the checksum-header attempt has
minute precision. The record section 6 explains the time basis. No archive,
binary, chain data or signing key was fetched.

| UTC read time (entry 3) | public URL | result |
| --- | --- | --- |
| 2026-10-06T14:18:56Z to 14:18:57Z | https://api.github.com/repos/bitcoin-sv/bitcoin-sv/releases/tags/v1.2.3 | browser inaccessible; no response body |
| 2026-10-06T14:18:56Z to 14:18:57Z | https://api.github.com/repos/bitcoin-sv/bitcoin-sv/git/ref/tags/v1.2.3 | browser inaccessible; no response body |
| 2026-10-06T14:18:56Z to 14:18:57Z | https://download.bitcoinsv.io/bitcoinsv/ | browser cached listing, marked crawled two months ago; omits 1.2.3 |
| 2026-10-06T14:18:56Z to 14:18:57Z | https://download.bitcoinsv.io/bitcoinsv/1.2.3/ | browser inaccessible; no response body |
| 2026-10-06T14:19:34Z | https://download.bitcoinsv.io/bitcoinsv/1.2.3/ | HTTPS 200 text |
| 2026-10-06T14:19:34Z | https://download.bitcoinsv.io/bitcoinsv/ | HTTPS 200 text |
| 2026-10-06T14:19:34Z | https://api.github.com/repos/bitcoin-sv/bitcoin-sv/releases/tags/v1.2.3 | HTTPS 200 text |
| 2026-10-06T14:19:34Z | https://api.github.com/repos/bitcoin-sv/bitcoin-sv/git/ref/tags/v1.2.3 | HTTPS 200 text |
| 2026-10-06T14:19:35Z | https://api.github.com/repos/bitcoin-sv/bitcoin-sv/commits/v1.2.3 | HTTPS 200 text |
| 2026-10-06T14:20:51Z | https://api.github.com/repos/bitcoin-sv/bitcoin-sv/git/tags/0d3b366fdf2b38d4c389321c953722931fce1b6c | HTTPS 200 text; snapshot save time |
| 2026-10-06T14:20:51Z | https://api.github.com/repos/bitcoin-sv/bitcoin-sv/compare/v1.2.2...v1.2.3?per_page=100 | HTTPS 200 text; snapshot save time |
| 2026-10-06T14:20:51Z | https://raw.githubusercontent.com/bitcoin-sv/bitcoin-sv/6504a3aff65ba97c0f6c80962b033e35ecbfed4b/src/script/interpreter.cpp | HTTPS 200 text; snapshot save time |
| 2026-10-06T14:20:51Z | https://raw.githubusercontent.com/bitcoin-sv/bitcoin-sv/6504a3aff65ba97c0f6c80962b033e35ecbfed4b/src/script/script_num.cpp | HTTPS 200 text; snapshot save time |
| 2026-10-06T14:20:51Z | https://raw.githubusercontent.com/bitcoin-sv/bitcoin-sv/6504a3aff65ba97c0f6c80962b033e35ecbfed4b/src/script/int_serialization.h | HTTPS 200 text; snapshot save time |
| 2026-10-06T14:20:51Z | https://raw.githubusercontent.com/bitcoin-sv/bitcoin-sv/879fc8b42168dd0e608dafd51b39c6dabad37d4d/src/script/int_serialization.h | HTTPS 200 text; snapshot save time |
| 2026-10-06T14:20:51Z | https://raw.githubusercontent.com/bitcoin-sv/bitcoin-sv/879fc8b42168dd0e608dafd51b39c6dabad37d4d/src/script/script_num.cpp | HTTPS 200 text; snapshot save time |
| 2026-10-06T14:20:51Z | https://raw.githubusercontent.com/bitcoin-sv/bitcoin-sv/6504a3aff65ba97c0f6c80962b033e35ecbfed4b/src/script/bitcoinconsensus.h | HTTPS 200 text; snapshot save time |
| 2026-10-06T14:20Z | https://download.bitcoinsv.io/bitcoinsv/1.2.3/SHA256SUMS.asc | header read only; MIME guard rejected before reading the body; retry below |
| 2026-10-06T14:22:29Z | https://download.bitcoinsv.io/bitcoinsv/1.2.3/SHA256SUMS.asc | HTTPS 200 text |
| 2026-10-06T14:23:35Z | https://raw.githubusercontent.com/bitcoin-sv/bitcoin-sv/6504a3aff65ba97c0f6c80962b033e35ecbfed4b/src/script/script_num.h | HTTPS 200 text |
| 2026-10-06T14:23:35Z | https://api.github.com/repos/bitcoin-sv/bitcoin-sv/compare/v1.2.2...v1.2.3?per_page=100&page=2 | HTTPS 200 text |

The authorized issue creation was one REST POST at 2026-10-06T14:25:52Z to `https://api.github.com/repos/Calgooon/bsv-script-lean/issues`, returning archived #57; it is separate from the 21 upstream reads/attempts.


**2026-10-07 (D178's official v1.2.3 x86-64 Linux release-binary measurement):** [Record](records/20261007-014131-x86-123.md); [smoke text](records/20261007-013737-x86-123-smoke.txt) / [JSON](records/20261007-013737-x86-123-smoke.json); [full text](records/20261007-013908-x86-123-full.txt) / [JSON](records/20261007-013908-x86-123-full.json). Every public read/attempt and its UTC interval is below. The archive is 31,676,537 bytes, sha256 `13f222f5b466fe4af2bb867628354e4ae9711a10019e89fc7bf018b90e30b3c8` at home and in both containers, equal to the published checksum line. `SHA256SUMS.asc` is 1,289 bytes, sha256 `0e0e67fd0eafb888125bea28c5d40badd0c1a706dcdaae176dbb4f6b67f04b9e` at all three reads. The browser attempts returned no bodies. Both containers reused the baked stack; no dependency download appeared in the build logs. Public reads only; loopback-only regtest instances, empty chains, nothing broadcast.

| UTC interval (v1.2.3 x86-64) | location | public URL | result |
|---|---|---|---|
| 2026-10-07T01:33:55Z to 01:33:56Z | browser attempt | https://api.github.com/repos/bitcoin-sv/bitcoin-sv/releases/tags/v1.2.3 | inaccessible/cache miss; no body |
| 2026-10-07T01:33:55Z to 01:33:56Z | browser attempt | https://download.bitcoinsv.io/bitcoinsv/1.2.3/ | inaccessible/cache miss; no body |
| 2026-10-07T01:33:55Z to 01:33:56Z | browser attempt | https://raw.githubusercontent.com/bitcoin-sv/bitcoin-sv/6504a3aff65ba97c0f6c80962b033e35ecbfed4b/contrib/verifybinaries/verify.sh | inaccessible/cache miss; no body |
| 2026-10-07T01:34:14Z to 01:34:14Z | home HTTPS GET | https://api.github.com/repos/bitcoin-sv/bitcoin-sv/releases/tags/v1.2.3 | HTTP 200; 7,017 bytes; sha256 `73e10d69d50deec574b62fb1d7f2ce335c4239735e8393665661d9e816873808` |
| 2026-10-07T01:34:14Z to 01:34:14Z | home HTTPS GET | https://raw.githubusercontent.com/bitcoin-sv/bitcoin-sv/6504a3aff65ba97c0f6c80962b033e35ecbfed4b/contrib/verifybinaries/verify.sh | HTTP 200; 4,452 bytes; sha256 `521445159ab1a89392be517502e9f6efd5a7f0068ebb0bf0eb7842087730e581` |
| 2026-10-07T01:34:14Z to 01:34:14Z | home HTTPS GET | https://download.bitcoinsv.io/bitcoinsv/1.2.3/ | HTTP 200; 785 bytes; sha256 `0af95d857c372ed594f3c3d8653c00a29781dd9f9df08e38f536a1cc0ffe34ad` |
| 2026-10-07T01:34:14Z to 01:34:14Z | home HTTPS GET | https://download.bitcoinsv.io/bitcoinsv/1.2.3/SHA256SUMS.asc | HTTP 200; 1,289 bytes; sha256 `0e0e67fd0eafb888125bea28c5d40badd0c1a706dcdaae176dbb4f6b67f04b9e` |
| 2026-10-07T01:34:14Z to 01:34:15Z | home HTTPS GET | https://download.bitcoinsv.io/bitcoinsv/1.2.3/bitcoin-sv-1.2.3-x86_64-linux-gnu.tar.gz | HTTP 200; 31,676,537 bytes; sha256 `13f222f5b466fe4af2bb867628354e4ae9711a10019e89fc7bf018b90e30b3c8` |
| 2026-10-07T01:37:17Z to 01:37:17Z | smoke container | https://download.bitcoinsv.io/bitcoinsv/1.2.3/SHA256SUMS.asc | curl rc 0; 1,289 bytes; sha256 `0e0e67fd0eafb888125bea28c5d40badd0c1a706dcdaae176dbb4f6b67f04b9e` |
| 2026-10-07T01:37:17Z to 01:37:19Z | smoke container | https://download.bitcoinsv.io/bitcoinsv/1.2.3/bitcoin-sv-1.2.3-x86_64-linux-gnu.tar.gz | curl rc 0; 31,676,537 bytes; sha256 `13f222f5b466fe4af2bb867628354e4ae9711a10019e89fc7bf018b90e30b3c8` |
| 2026-10-07T01:38:44Z to 01:38:45Z | full container | https://download.bitcoinsv.io/bitcoinsv/1.2.3/SHA256SUMS.asc | curl rc 0; 1,289 bytes; sha256 `0e0e67fd0eafb888125bea28c5d40badd0c1a706dcdaae176dbb4f6b67f04b9e` |
| 2026-10-07T01:38:45Z to 01:38:45Z | full container | https://download.bitcoinsv.io/bitcoinsv/1.2.3/bitcoin-sv-1.2.3-x86_64-linux-gnu.tar.gz | curl rc 0; 31,676,537 bytes; sha256 `13f222f5b466fe4af2bb867628354e4ae9711a10019e89fc7bf018b90e30b3c8` |

**2026-10-12 (bsv-rs 0.4.4 → 0.4.5) [M]:** The engine column moves under CLAUDE.md rule 18. The tagged CHANGELOG covers the offset-zero lone leaf and an opt-in local work budget inside an input. The harness adds `work_limit: None` to its sole `SpendParams` literal; resource declines remain `undecided`. No classifier rule changes. The [record](records/20261012-021029-bump-bsv-rs-0.4.5-s3.md) carries the API review, commands, 26-corpus retally, go-sdk object audit and vector comparisons.

| read at (UTC) | public URL | result |
|---|---|---|
| 2026-10-12T02:12:04.306486+00:00 | https://api.github.com/repos/Calhooon/bsv-rs/contents/CHANGELOG.md?ref=v0.4.5 | tagged CHANGELOG, base64-decoded; API migration reviewed |
| 2026-10-12T02:12:25.684743+00:00 | https://crates.io/api/v1/crates/bsv-rs/0.4.5 | 0.4.5; published `2026-10-12T01:36:14.486995Z`; checksum `3e0abc5bc3001271236a5da213ece6412e86612353aaa53b9adf2ecee1425c2a`; not yanked |
| 2026-10-12T02:12:25.684743+00:00 | https://api.github.com/repos/Calhooon/bsv-rs/git/ref/tags/v0.4.5 | tag names `77b56dcd985004630867cd06df9e9d1803dce116` |

**2026-10-12 (bsv-rs 0.4.5 → 0.5.0) [M]:** The engine column moves under CLAUDE.md rule 18 on the maintainers' `measure 0.5.0` of 12:31Z. This minor release extends the streaming reader's byte and contextual refusals, adds `OutputRef.at` and `mining_tip`, and declines unverifiable finality or coinbase maturity when the required context is absent. The runner and four vector generators use none of those streaming APIs; their 15 consumed source modules are byte-identical to 0.4.5. No caller migration or classifier change is needed. The [record](records/20261012-124552-bump-bsv-rs-0.5.0-s3.md) carries the CHANGELOG quote, API review, 26-corpus retally, 552,126-object go-sdk audit, vector comparisons and local legs.

| read at (UTC, bsv-rs 0.5.0) | public URL | result |
|---|---|---|
| 2026-10-12T12:46:20.709216+00:00 | https://api.github.com/repos/Calhooon/bsv-rs/contents/CHANGELOG.md?ref=v0.5.0 | tagged CHANGELOG, base64-decoded; minor-release migration reviewed |
| 2026-10-12T12:46:21.158116+00:00 | https://crates.io/api/v1/crates/bsv-rs/0.5.0 | 0.5.0; published `2026-10-12T03:43:45.692527Z`; checksum `72a8372f5500535f1d192765d88e123fc41c363b423516157a8fc7e5ae9326f0`; not yanked |
| 2026-10-12T12:46:21.432312+00:00 | https://api.github.com/repos/Calhooon/bsv-rs/git/ref/tags/v0.5.0 | tag names `d06ea0dd12afba8f1a5ced9daf7faa61ba97ea69` |
| 2026-10-12T12:47:12.680541+00:00 | https://api.github.com/repos/Calhooon/bsv-rs/compare/v0.4.5...v0.5.0 | six changed files; the two changed production modules are streaming reader and chain tracker |

[M] #60 finality (2026-10-12): 17 timed public API reads, 11 pinned source files and 6 issue/comment requests. Each UTC stamp is the request start. Contents were decoded from base64; line citations were checked against those saved bytes. The opening `git fetch origin main` read [origin](https://github.com/Calgooon/bsv-script-lean.git); its completion marker is [M] `2026-10-12T12:44:27.501438Z`, the worktree FETCH_HEAD modification time. Its request-start timestamp was not captured. Thus 18 read operations are logged, with request-start times for the 17 API calls. No reference clone was created.

| UTC request start | URL | result / blob / decoded lines |
|---|---|---|
| `2026-10-12T12:45:37Z` | [public read](https://api.github.com/repos/Calgooon/bsv-script-lean/issues/60) | 200; issue body or comment list |
| `2026-10-12T12:45:37Z` | [public read](https://api.github.com/repos/Calgooon/bsv-script-lean/issues/60/comments) | 200; issue body or comment list |
| `2026-10-12T12:45:37Z` | [public read](https://api.github.com/repos/Calgooon/bsv-script-lean/issues/61) | 200; issue body or comment list |
| `2026-10-12T12:45:37Z` | [public read](https://api.github.com/repos/Calgooon/bsv-script-lean/issues/62) | 200; issue body or comment list |
| `2026-10-12T12:45:37Z` | [public read](https://api.github.com/repos/Calgooon/bsv-script-lean/issues/66) | 200; issue body or comment list |
| `2026-10-12T12:45:37Z` | [public read](https://api.github.com/repos/Calgooon/bsv-script-lean/issues/76) | 200; issue body or comment list |
| `2026-10-12T12:45:52Z` | [public read](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/consensus/consensus.h?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | 200; `dd1614388a060ec674e7aea13d001cf9171e66ed`; 94 lines |
| `2026-10-12T12:45:52Z` | [public read](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/consensus/validation.h?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | 200; `b158eef0b97f0e39a5bea16d55ed3b58095d615e`; 142 lines |
| `2026-10-12T12:45:52Z` | [public read](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/primitives/transaction.h?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | 200; `38516745ff8e95eceda775ea1b40074509d1eb66`; 404 lines |
| `2026-10-12T12:45:52Z` | [public read](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/time_locked_mempool.cpp?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | 200; `2984a35270a270859fe330cef5ad7b10eb6219e5`; 664 lines |
| `2026-10-12T12:45:52Z` | [public read](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/validation.cpp?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | 200; `f2f5fa101028f0f73955b06b339c37570c57251a`; 7746 lines |
| `2026-10-12T12:45:53Z` | [public read](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/amount.h?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | 200; `b6865905ee31a390dd719e05dc391e4b1b278cae`; 178 lines |
| `2026-10-12T12:45:53Z` | [public read](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/block_index.h?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | 200; `543097e796ad0fcc9f9b104f96030129e28dc569`; 1277 lines |
| `2026-10-12T12:45:53Z` | [public read](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/validation.h?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | 200; `32c4acd90ece216a23b8b201ced0d1a983f2d3f4`; 1190 lines |
| `2026-10-12T12:45:53Z` | [public read](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/verify_script_flags.cpp?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | 200; `29674d406ad9eb70019bebbbf608f72c9d0b4f05`; 82 lines |
| `2026-10-12T12:46:38Z` | [public read](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/policy/policy.h?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | 200; `284ff428efc916d36424564ea86c484781782eab`; 293 lines |
| `2026-10-12T12:46:39Z` | [public read](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/protocol_era.cpp?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | 200; `aa01141bbb08d9e7b285a666c7c376a491f7aaee`; 128 lines |

[M] #61 UTXO (2026-10-12): [M] 32 timed public API reads, [M] 23 pinned source files and [M] 9 issue/comment requests. Each UTC stamp is the request start; source contents were base64-decoded, their Git blob hashes checked, and citations read against those bytes. The opening `git fetch origin main` read [origin](https://github.com/Calgooon/bsv-script-lean.git); its completion marker is [M] `2026-10-12T14:41:49.710453Z`, the worktree FETCH_HEAD modification time. Its request-start timestamp was not captured. Thus [M] 33 read operations are logged, with request-start times for [M] 32 API calls. Local Lake artifacts were reused from the permitted cache; no reference clone was created. The [UTXO record](records/20261012-151100-s6-61-utxo.md) contains the findings and validation.

| UTC request start | URL | [M] result / decoded blob / lines |
|---|---|---|
| `2026-10-12T14:43:12Z` | [public read](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/validation.cpp?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | 200; `f2f5fa101028f0f73955b06b339c37570c57251a`; 7746 lines |
| `2026-10-12T14:43:12Z` | [public read](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/coins.h?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | 200; `0aaa625f72dc9cf574439daa54e52a9895eb4917`; 915 lines |
| `2026-10-12T14:43:13Z` | [public read](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/coins.cpp?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | 200; `e348fafb311cb7dc3e0bc94789e981363d509362`; 568 lines |
| `2026-10-12T14:43:13Z` | [public read](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/undo.h?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | 200; `cca2d4beb38046c05a097eceb85435498ab29cf4`; 143 lines |
| `2026-10-12T14:43:14Z` | [public read](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/script/script.h?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | 200; `b73b27834e14641176bda4c8cf2ceae98e650c67`; 352 lines |
| `2026-10-12T14:43:14Z` | [public read](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/script/script.cpp?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | 200; `5dc4c57560717a50b77f0748ab14ec430cb5b165`; 294 lines |
| `2026-10-12T14:43:14Z` | [public read](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/consensus/consensus.h?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | 200; `dd1614388a060ec674e7aea13d001cf9171e66ed`; 94 lines |
| `2026-10-12T14:43:15Z` | [public read](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/frozentxo.h?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | 200; `366599ba4e123a32eb4c4b152e330ee1da0f009e`; 141 lines |
| `2026-10-12T14:43:15Z` | [public read](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/frozentxo.cpp?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | 200; `205039a429e1d6b359485be4a16588a4427bc055`; 176 lines |
| `2026-10-12T14:43:15Z` | [public read](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/primitives/transaction.h?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | 200; `38516745ff8e95eceda775ea1b40074509d1eb66`; 404 lines |
| `2026-10-12T14:43:16Z` | [public read](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/primitives/transaction.cpp?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | 200; `6a93f3615d36b9f64a4f0b5089c40bc3a4df0ff3`; 173 lines |
| `2026-10-12T14:43:16Z` | [public read](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/processing_block_index.cpp?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | 200; `87071187334e701a6de67fdd17e69ab6a221d846`; 96 lines |
| `2026-10-12T14:43:16Z` | [public read](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/consensus/validation.h?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | 200; `b158eef0b97f0e39a5bea16d55ed3b58095d615e`; 142 lines |
| `2026-10-12T14:43:17Z` | [public read](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/amount.h?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | 200; `b6865905ee31a390dd719e05dc391e4b1b278cae`; 178 lines |
| `2026-10-12T14:43:17Z` | [public read](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/policy/policy.h?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | 200; `284ff428efc916d36424564ea86c484781782eab`; 293 lines |
| `2026-10-12T14:43:17Z` | [public read](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/script/script_flags.h?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | 200; `399728e801d8af369e92a0b1db9b3b67999bd72f`; 172 lines |
| `2026-10-12T14:43:17Z` | [public read](https://api.github.com/repos/Calgooon/bsv-script-lean/issues/61) | 200; issue body or comment list |
| `2026-10-12T14:43:18Z` | [public read](https://api.github.com/repos/Calgooon/bsv-script-lean/issues/60) | 200; issue body or comment list |
| `2026-10-12T14:43:18Z` | [public read](https://api.github.com/repos/Calgooon/bsv-script-lean/issues/62) | 200; issue body or comment list |
| `2026-10-12T14:43:19Z` | [public read](https://api.github.com/repos/Calgooon/bsv-script-lean/issues/63) | 200; issue body or comment list |
| `2026-10-12T14:43:19Z` | [public read](https://api.github.com/repos/Calgooon/bsv-script-lean/issues/64) | 200; issue body or comment list |
| `2026-10-12T14:43:20Z` | [public read](https://api.github.com/repos/Calgooon/bsv-script-lean/issues/66) | 200; issue body or comment list |
| `2026-10-12T14:43:20Z` | [public read](https://api.github.com/repos/Calgooon/bsv-script-lean/issues/70) | 200; issue body or comment list |
| `2026-10-12T14:43:20Z` | [public read](https://api.github.com/repos/Calgooon/bsv-script-lean/issues/76) | 200; issue body or comment list |
| `2026-10-12T14:43:21Z` | [public read](https://api.github.com/repos/Calgooon/bsv-script-lean/issues/61/comments) | 200; issue body or comment list |
| `2026-10-12T14:44:47Z` | [public read](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/frozentxo_db.cpp?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | 200; `145f19d72706296dcaf420e6a05e4271a0689926`; 934 lines |
| `2026-10-12T14:44:48Z` | [public read](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/frozentxo_db.h?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | 200; `d7bb427e85ff60a8148861cde01546ffcf96b850`; 729 lines |
| `2026-10-12T14:44:48Z` | [public read](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/verify_script_flags.cpp?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | 200; `29674d406ad9eb70019bebbbf608f72c9d0b4f05`; 82 lines |
| `2026-10-12T14:44:49Z` | [public read](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/protocol_era.cpp?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | 200; `aa01141bbb08d9e7b285a666c7c376a491f7aaee`; 128 lines |
| `2026-10-12T14:44:50Z` | [public read](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/protocol_era.h?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | 200; `a614d54945fc1a0f951eb373f8a52a935a1ec302`; 60 lines |
| `2026-10-12T14:44:50Z` | [public read](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/script/interpreter.cpp?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | 200; `dfcd2a2b061400a5eafdfd8bab242e935ed72acf`; 2452 lines |
| `2026-10-12T14:44:51Z` | [public read](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/script/script_error.cpp?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | 200; `9dd3113d4a1681fa04a980d13ef226b170936efd`; 119 lines |

[M] #76 oracle (2026-10-12): [M] 18 timed API reads,
[M] 12 pinned reference files and [M] 6 issue bodies. Each time below is the
UTC request start; the content responses were base64-decoded and the Git blob
hashes and cited line ranges checked. The opening [origin fetch](https://github.com/Calgooon/bsv-script-lean.git)
has completion marker [M] `2026-10-12T16:25:37.849301Z` from this worktree's FETCH_HEAD;
its request-start time was not captured. Thus [M] 19 read operations are logged.
The permitted shared Lake package cache supplied dependencies without fetching.
The [oracle record](records/20261012-164313-s6-76-oracle.md) records the interface,
measurements and remaining scenario obligations.

| [M] UTC request start | URL | [M] result / decoded blob / lines |
|---|---|---|
| `2026-10-12T16:26:36Z` | [API read](https://api.github.com/repos/Calgooon/bsv-script-lean/issues/76) | success; issue body |
| `2026-10-12T16:26:37Z` | [API read](https://api.github.com/repos/Calgooon/bsv-script-lean/issues/68) | success; issue body |
| `2026-10-12T16:26:37Z` | [API read](https://api.github.com/repos/Calgooon/bsv-script-lean/issues/61) | success; issue body |
| `2026-10-12T16:26:37Z` | [API read](https://api.github.com/repos/Calgooon/bsv-script-lean/issues/62) | success; issue body |
| `2026-10-12T16:26:38Z` | [API read](https://api.github.com/repos/Calgooon/bsv-script-lean/issues/64) | success; issue body |
| `2026-10-12T16:26:38Z` | [API read](https://api.github.com/repos/Calgooon/bsv-script-lean/issues/66) | success; issue body |
| `2026-10-12T16:26:49Z` | [API read](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/validation.cpp?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | success; `f2f5fa101028f0f73955b06b339c37570c57251a`; 7746 lines |
| `2026-10-12T16:26:49Z` | [API read](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/script/interpreter.cpp?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | success; `dfcd2a2b061400a5eafdfd8bab242e935ed72acf`; 2452 lines |
| `2026-10-12T16:26:50Z` | [API read](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/script/interpreter.h?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | success; `e9db3683372cb4cdb83ea51669ef069a17671296`; 235 lines |
| `2026-10-12T16:26:50Z` | [API read](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/verify_script_flags.cpp?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | success; `29674d406ad9eb70019bebbbf608f72c9d0b4f05`; 82 lines |
| `2026-10-12T16:26:50Z` | [API read](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/policy/policy.h?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | success; `284ff428efc916d36424564ea86c484781782eab`; 293 lines |
| `2026-10-12T16:26:51Z` | [API read](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/txn_validation_data.h?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | success; `0fa48c8029f037526c698e9789baa184db221b4b`; 184 lines |
| `2026-10-12T16:26:51Z` | [API read](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/txn_validation_config.h?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | success; `7f1563677308223aadcc55d10ccc8767ebc78f86`; 48 lines |
| `2026-10-12T16:26:51Z` | [API read](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/consensus/validation.h?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | success; `b158eef0b97f0e39a5bea16d55ed3b58095d615e`; 142 lines |
| `2026-10-12T16:29:10Z` | [API read](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/protocol_era.cpp?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | success; `aa01141bbb08d9e7b285a666c7c376a491f7aaee`; 128 lines |
| `2026-10-12T16:29:10Z` | [API read](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/script/standard.h?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | success; `240122bf39163a80c17aa262b6c9f3d598836fcc`; 164 lines |
| `2026-10-12T16:29:10Z` | [API read](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/script/standard.cpp?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | success; `2c29df25c2050796ac6115303140a5e4e49fc0b8`; 501 lines |
| `2026-10-12T16:29:11Z` | [API read](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/script/script_error.cpp?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | success; `9dd3113d4a1681fa04a980d13ef226b170936efd`; 119 lines |

[M] #63 block validity, 2026-10-12: [M] 40 timed HTTP requests: [M] 26 pinned public-source requests (23 successful, 3 refused), [M] 6 issue/comment reads, and [M] 8 public WhatsOnChain/documentation requests. Every table time is the request start. A discovery search through `web.run` at [M] `2026-10-12T16:29:01Z` used the query `WhatsOnChain API get block headers bulk height count`; the official documentation URL subsequently read is listed below. The opening origin fetch is recorded by its [M] `2026-10-12T16:26:41.759169+00:00` FETCH_HEAD completion marker at [origin](https://github.com/Calgooon/bsv-script-lean.git); its request-start time was not captured. Thus [M] 42 read operations are accounted for, [M] 40 with individual HTTP request-start receipts. The cache helper reused local Lake packages. No reference clone or public-network node was started, and no transaction was broadcast. The [block record](records/20261012-164656-s6-63-block.md) records the source differences, interfaces and verdicts.

| UTC request start | URL | [M] result / decoded blob / lines or bytes |
|---|---|---|
| `2026-10-12T16:27:50Z` | [read](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/primitives/block.h?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | gh exit 0; `11c3b7c5ae39953c65a0329901c41b73dd4b0344`; 182 lines |
| `2026-10-12T16:27:50Z` | [read](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/primitives/block.cpp?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | gh exit 0; `5ad76fdc436115e4662a891e7efa4c5a5baa1910`; 104 lines |
| `2026-10-12T16:27:51Z` | [read](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/arith_uint256.cpp?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | gh exit 0; `b3e18858cc4837770533dd29162f419db42e793b`; 252 lines |
| `2026-10-12T16:27:52Z` | [read](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/arith_uint256.h?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | gh exit 0; `1dc4c1ab8648e3b63a90dc7ad5092ffaf2f67c95`; 312 lines |
| `2026-10-12T16:27:52Z` | [read](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/block_index.cpp?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | gh exit 0; `25fb1bde9384a6b3ebe5ddc7a59ef35b70478dd0`; 466 lines |
| `2026-10-12T16:27:53Z` | [read](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/block_index.h?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | gh exit 0; `543097e796ad0fcc9f9b104f96030129e28dc569`; 1277 lines |
| `2026-10-12T16:27:54Z` | [read](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/pow.cpp?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | gh exit 0; `989f483079930d539677ef30695f194ccc76310b`; 297 lines |
| `2026-10-12T16:27:54Z` | [read](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/consensus/merkle.cpp?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | gh exit 0; `ab89e2f1b6f2bc1a4afd18c2e6cb7319b4cae4a9`; 328 lines |
| `2026-10-12T16:27:55Z` | [read](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/validation.cpp?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | gh exit 0; `f2f5fa101028f0f73955b06b339c37570c57251a`; 7746 lines |
| `2026-10-12T16:27:56Z` | [read](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/validation.h?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | gh exit 0; `32c4acd90ece216a23b8b201ced0d1a983f2d3f4`; 1190 lines |
| `2026-10-12T16:27:56Z` | [read](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/consensus/tx_verify.cpp?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | gh exit 1 |
| `2026-10-12T16:27:57Z` | [read](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/consensus/tx_verify.h?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | gh exit 1 |
| `2026-10-12T16:27:57Z` | [read](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/consensus/consensus.h?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | gh exit 0; `dd1614388a060ec674e7aea13d001cf9171e66ed`; 94 lines |
| `2026-10-12T16:27:58Z` | [read](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/consensus/params.h?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | gh exit 0; `9da13771c872d82bce60205bedbf40e8f0e59d53`; 55 lines |
| `2026-10-12T16:27:59Z` | [read](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/chainparams.cpp?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | gh exit 0; `4dcea2b5b3f1c77b9b16157dc850f68d5e88d5b3`; 1619 lines |
| `2026-10-12T16:27:59Z` | [read](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/amount.h?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | gh exit 0; `b6865905ee31a390dd719e05dc391e4b1b278cae`; 178 lines |
| `2026-10-12T16:28:00Z` | [read](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/config.cpp?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | gh exit 0; `c81ff74c06b3430e8a01b5af381508a06f476811`; 2710 lines |
| `2026-10-12T16:28:01Z` | [read](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/serialize.h?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | gh exit 0; `7706a6cf2e3a0843d829e2fa5b74ebc8db7223af`; 1188 lines |
| `2026-10-12T16:28:01Z` | [read](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/script/script.h?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | gh exit 0; `b73b27834e14641176bda4c8cf2ceae98e650c67`; 352 lines |
| `2026-10-12T16:28:02Z` | [read](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/script/script_num.h?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | gh exit 0; `85254aed613b850a8c6e992ed844fddb7a857ebb`; 157 lines |
| `2026-10-12T16:28:02Z` | [read](https://api.github.com/repos/Calgooon/bsv-script-lean/issues/63) | gh exit 0 |
| `2026-10-12T16:28:03Z` | [read](https://api.github.com/repos/Calgooon/bsv-script-lean/issues/64) | gh exit 0 |
| `2026-10-12T16:28:03Z` | [read](https://api.github.com/repos/Calgooon/bsv-script-lean/issues/65) | gh exit 0 |
| `2026-10-12T16:28:04Z` | [read](https://api.github.com/repos/Calgooon/bsv-script-lean/issues/66) | gh exit 0 |
| `2026-10-12T16:28:04Z` | [read](https://api.github.com/repos/Calgooon/bsv-script-lean/issues/69) | gh exit 0 |
| `2026-10-12T16:28:04Z` | [read](https://api.github.com/repos/Calgooon/bsv-script-lean/issues/63/comments) | gh exit 0 |
| `2026-10-12T16:29:16Z` | [read](https://docs.taal.com/core-products/whatsonchain/block) | HTTP 200 |
| `2026-10-12T16:29:17Z` | [read](https://api.whatsonchain.com/v1/bsv/main/block/headers/resources) | HTTP 200 |
| `2026-10-12T16:29:19Z` | [read](https://api.whatsonchain.com/v1/bsv/main/chain/info) | HTTP 200 |
| `2026-10-12T16:30:01Z` | [read](https://api.whatsonchain.com/v1/bsv/main/block/headers/0_10000_headers.bin) | HTTP 200; 800080 bytes |
| `2026-10-12T16:30:03Z` | [read](https://api.whatsonchain.com/v1/bsv/main/block/headers/500001_510000_headers.bin) | HTTP 200; 800000 bytes |
| `2026-10-12T16:30:05Z` | [read](https://api.whatsonchain.com/v1/bsv/main/block/headers/610001_620000_headers.bin) | HTTP 200; 800000 bytes |
| `2026-10-12T16:30:07Z` | [read](https://api.whatsonchain.com/v1/bsv/main/block/headers/620001_630000_headers.bin) | HTTP 200; 800000 bytes |
| `2026-10-12T16:30:10Z` | [read](https://api.whatsonchain.com/v1/bsv/main/block/headers/latest) | HTTP 200; 60800 bytes |
| `2026-10-12T16:33:53Z` | [read](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/configscriptpolicy.cpp?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | gh exit 0; `340acde9a9bfea32e12ac959ee5fa5685f033696`; 496 lines |
| `2026-10-12T16:33:53Z` | [read](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/script/script.cpp?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | gh exit 0; `5dc4c57560717a50b77f0748ab14ec430cb5b165`; 294 lines |
| `2026-10-12T16:33:54Z` | [read](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/consensus/validation.h?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | gh exit 0; `b158eef0b97f0e39a5bea16d55ed3b58095d615e`; 142 lines |
| `2026-10-12T16:33:54Z` | [read](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/hash.h?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | gh exit 0; `afa713b97b7d700e533de3ed2847f94ff96792da`; 306 lines |
| `2026-10-12T16:33:55Z` | [read](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/block_validation_options.h?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | gh exit 1 |
| `2026-10-12T16:33:56Z` | [read](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/primitives/transaction.h?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | gh exit 0; `38516745ff8e95eceda775ea1b40074509d1eb66`; 404 lines |

[M] #63 lens repair and rebase, 2026-10-12: the opening [origin fetch](https://github.com/Calgooon/bsv-script-lean.git) completed at `2026-10-12T17:28:58.182572+00:00` (FETCH_HEAD modification time; request-start time was not captured). [M] One pinned public API read began at `2026-10-12T17:30:31Z`: [src/validation.cpp](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/validation.cpp?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b), gh exit [M] 0, decoded blob `f2f5fa101028f0f73955b06b339c37570c57251a`, [M] 7746 lines / 305668 bytes. The body-check order and contextual height range were verified at [SRC] `src/validation.cpp:5788–5791,5801–5815,5823–5827,5853–5866,5877–5889,6085–6099`, pin `6504a3aff65ba97c0f6c80962b033e35ecbfed4b`; [follow-up record](records/20261012-164656-s6-63-block.md#fix-63-follow-up-m-2026-10-12).

[M] #63 refreshed-base read on 2026-10-12: [origin fetch](https://github.com/Calgooon/bsv-script-lean.git) began at `2026-10-12T17:38:58Z`, git exit [M] 0. The fetched main tip was `11b3c4ed0956f2c60ea2e56572a7de22cca68fbc`; the work rebased cleanly and reran its requested legs on that base ([record](records/20261012-164656-s6-63-block.md#refreshed-base-validation)).
**2026-10-12, #62 [M].**
Public source reading for the mempool
policy machine at bitcoin-sv `6504a3aff65ba97c0f6c80962b033e35ecbfed4b`, plus
the requested issue bodies/amendment and the bsv-rs reader at
`d06ea0dd12afba8f1a5ced9daf7faa61ba97ea69`. The [record](records/20261012-172834-s6-62-mempool.md)
contains stage citations, qualified invariants, corpus measurements and the
stack mapping answer. These [M] 48 successful requests are recorded inside
§6's read area; the issue comment is a separately authorized write, not a read.

| UTC request time [M] | public read URL [SRC] | result [M] |
|---|---|---|
| `2026-10-12T17:28:34Z` | [src/validation.cpp](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/validation.cpp?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | exit 0; 7746 lines |
| `2026-10-12T17:28:34Z` | [src/validation.h](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/validation.h?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | exit 0; 1190 lines |
| `2026-10-12T17:28:34Z` | [src/txmempool.cpp](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/txmempool.cpp?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | exit 0; 3361 lines |
| `2026-10-12T17:28:34Z` | [src/txmempool.h](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/txmempool.h?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | exit 0; 1548 lines |
| `2026-10-12T17:28:34Z` | [src/consensus/validation.h](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/consensus/validation.h?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | exit 0; 142 lines |
| `2026-10-12T17:28:34Z` | [src/time_locked_mempool.cpp](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/time_locked_mempool.cpp?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | exit 0; 664 lines |
| `2026-10-12T17:28:35Z` | [src/time_locked_mempool.h](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/time_locked_mempool.h?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | exit 0; 226 lines |
| `2026-10-12T17:28:35Z` | [src/orphan_txns.cpp](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/orphan_txns.cpp?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | exit 0; 440 lines |
| `2026-10-12T17:28:35Z` | [src/orphan_txns.h](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/orphan_txns.h?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | exit 0; 151 lines |
| `2026-10-12T17:28:35Z` | [src/txn_validator.cpp](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/txn_validator.cpp?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | exit 0; 801 lines |
| `2026-10-12T17:28:35Z` | [src/txn_recent_rejects.h](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/txn_recent_rejects.h?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | exit 0; 59 lines |
| `2026-10-12T17:28:35Z` | [src/txn_recent_rejects.cpp](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/txn_recent_rejects.cpp?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | exit 0; 27 lines |
| `2026-10-12T17:28:35Z` | [src/txn_double_spend_detector.cpp](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/txn_double_spend_detector.cpp?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | exit 0; 138 lines |
| `2026-10-12T17:28:35Z` | [src/txn_double_spend_detector.h](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/txn_double_spend_detector.h?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | exit 0; 90 lines |
| `2026-10-12T17:28:35Z` | [src/txn_validation_data.h](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/txn_validation_data.h?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | exit 0; 184 lines |
| `2026-10-12T17:28:35Z` | [src/txn_validation_config.h](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/txn_validation_config.h?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | exit 0; 48 lines |
| `2026-10-12T17:28:35Z` | [src/net/net_processing.cpp](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/net/net_processing.cpp?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | exit 0; 5975 lines |
| `2026-10-12T17:28:35Z` | [src/net/net.cpp](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/net/net.cpp?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | exit 0; 3658 lines |
| `2026-10-12T17:28:35Z` | [src/policy/policy.cpp](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/policy/policy.cpp?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | exit 0; 198 lines |
| `2026-10-12T17:28:35Z` | [src/policy/policy.h](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/policy/policy.h?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | exit 0; 293 lines |
| `2026-10-12T17:28:35Z` | [src/amount.cpp](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/amount.cpp?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | exit 0; 50 lines |
| `2026-10-12T17:28:35Z` | [src/coins.cpp](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/coins.cpp?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | exit 0; 568 lines |
| `2026-10-12T17:28:36Z` | [src/coins.h](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/coins.h?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | exit 0; 915 lines |
| `2026-10-12T17:28:36Z` | [src/rpc/blockchain.cpp](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/rpc/blockchain.cpp?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | exit 0; 3839 lines |
| `2026-10-12T17:28:36Z` | [src/rpc/rawtransaction.cpp](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/rpc/rawtransaction.cpp?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | exit 0; 2637 lines |
| `2026-10-12T17:28:36Z` | [issues/62.txt](https://api.github.com/repos/Calgooon/bsv-script-lean/issues/62) | exit 0; 13 lines |
| `2026-10-12T17:28:36Z` | [issues/60.txt](https://api.github.com/repos/Calgooon/bsv-script-lean/issues/60) | exit 0; 13 lines |
| `2026-10-12T17:28:36Z` | [issues/61.txt](https://api.github.com/repos/Calgooon/bsv-script-lean/issues/61) | exit 0; 12 lines |
| `2026-10-12T17:28:36Z` | [issues/76.txt](https://api.github.com/repos/Calgooon/bsv-script-lean/issues/76) | exit 0; 12 lines |
| `2026-10-12T17:28:36Z` | [issues/66.txt](https://api.github.com/repos/Calgooon/bsv-script-lean/issues/66) | exit 0; 12 lines |
| `2026-10-12T17:28:36Z` | [issues/67.txt](https://api.github.com/repos/Calgooon/bsv-script-lean/issues/67) | exit 0; 12 lines |
| `2026-10-12T17:28:36Z` | [issues/70.txt](https://api.github.com/repos/Calgooon/bsv-script-lean/issues/70) | exit 0; 12 lines |
| `2026-10-12T17:28:36Z` | [issues/71.txt](https://api.github.com/repos/Calgooon/bsv-script-lean/issues/71) | exit 0; 12 lines |
| `2026-10-12T17:28:36Z` | [issues/62-comments.txt](https://api.github.com/repos/Calgooon/bsv-script-lean/issues/62/comments) | exit 0; 2 lines |
| `2026-10-12T17:30:13Z` | [src/txmempoolevictioncandidates.cpp](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/txmempoolevictioncandidates.cpp?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | exit 0; 193 lines |
| `2026-10-12T17:30:14Z` | [src/txmempoolevictioncandidates.h](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/txmempoolevictioncandidates.h?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | exit 0; 150 lines |
| `2026-10-12T17:30:14Z` | [src/leaky_bucket.h](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/leaky_bucket.h?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | exit 0; 104 lines |
| `2026-10-12T17:30:14Z` | [src/memusage.h](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/memusage.h?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | exit 0; 172 lines |
| `2026-10-12T17:30:15Z` | [src/protocol_era.cpp](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/protocol_era.cpp?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | exit 0; 128 lines |
| `2026-10-12T17:30:15Z` | [src/configscriptpolicy.cpp](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/configscriptpolicy.cpp?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | exit 0; 496 lines |
| `2026-10-12T17:30:15Z` | [src/script/standard.cpp](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/script/standard.cpp?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | exit 0; 501 lines |
| `2026-10-12T17:37:13Z` | [src/script/script.h](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/script/script.h?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | exit 0; 352 lines |
| `2026-10-12T17:37:15Z` | [src/script/standard.h](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/script/standard.h?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | exit 0; 164 lines |
| `2026-10-12T17:37:16Z` | [src/config.cpp](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/config.cpp?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | exit 0; 2710 lines |
| `2026-10-12T17:37:16Z` | [src/frozentxo.cpp](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/frozentxo.cpp?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | exit 0; 176 lines |
| `2026-10-12T17:41:19Z` | [src/script/script.cpp](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/script/script.cpp?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | exit 0; 294 lines |
| `2026-10-12T17:56:37Z` | [bsv-rs/src/transaction/beef_stream.rs](https://api.github.com/repos/Calhooon/bsv-rs/contents/src/transaction/beef_stream.rs?ref=d06ea0dd12afba8f1a5ced9daf7faa61ba97ea69) | exit 0 |
| `2026-10-12T17:56:37Z` | [bsv-rs/src/transaction/chain_tracker.rs](https://api.github.com/repos/Calhooon/bsv-rs/contents/src/transaction/chain_tracker.rs?ref=d06ea0dd12afba8f1a5ced9daf7faa61ba97ea69) | exit 0 |


### Fix-62 pinned public reads

[M] 33 successful public contents requests, decoded from the API's content field.
The numbered source was inspected for the lens's cited branches and table rows.
Each returned blob hash below is re-derived from its downloaded bytes.

| UTC request time [M] | public read URL [SRC] | result and blob [M] |
|---|---|---|
| `2026-10-12T18:49:38+00:00` | [src/validation.cpp](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/validation.cpp?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | exit 0; 7746 lines; `f2f5fa101028f0f73955b06b339c37570c57251a` |
| `2026-10-12T18:49:38+00:00` | [src/validation.h](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/validation.h?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | exit 0; 1190 lines; `32c4acd90ece216a23b8b201ced0d1a983f2d3f4` |
| `2026-10-12T18:49:38+00:00` | [src/txmempool.cpp](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/txmempool.cpp?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | exit 0; 3361 lines; `a2021721d358c49fd0692d25fb8dd5c52fa36130` |
| `2026-10-12T18:49:38+00:00` | [src/txmempool.h](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/txmempool.h?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | exit 0; 1548 lines; `929141d8eae6e9f7c410022a0a21af8a07dce428` |
| `2026-10-12T18:49:38+00:00` | [src/txn_validator.cpp](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/txn_validator.cpp?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | exit 0; 801 lines; `c05c72729a24b9276136a8b00bc6c45abc6cc032` |
| `2026-10-12T18:49:38+00:00` | [src/leaky_bucket.h](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/leaky_bucket.h?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | exit 0; 104 lines; `d4ab07929d14b033e6b149267ebd70544635cb6a` |
| `2026-10-12T18:49:38+00:00` | [src/time_locked_mempool.cpp](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/time_locked_mempool.cpp?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | exit 0; 664 lines; `2984a35270a270859fe330cef5ad7b10eb6219e5` |
| `2026-10-12T18:49:38+00:00` | [src/time_locked_mempool.h](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/time_locked_mempool.h?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | exit 0; 226 lines; `6c28689dd966a4a46fc86d421828b84726010f45` |
| `2026-10-12T18:49:38+00:00` | [src/orphan_txns.cpp](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/orphan_txns.cpp?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | exit 0; 440 lines; `0632b1c9e7fc7cbbad87f108973634aefe697423` |
| `2026-10-12T18:49:39+00:00` | [src/orphan_txns.h](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/orphan_txns.h?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | exit 0; 151 lines; `a8a81026723871aaf668cd6d801491426cf7fc99` |
| `2026-10-12T18:49:39+00:00` | [src/configscriptpolicy.cpp](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/configscriptpolicy.cpp?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | exit 0; 496 lines; `340acde9a9bfea32e12ac959ee5fa5685f033696` |
| `2026-10-12T18:49:39+00:00` | [src/configscriptpolicy.h](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/configscriptpolicy.h?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | exit 0; 92 lines; `58878ab660ebb8afa345fac0ab66be4294c49403` |
| `2026-10-12T18:49:39+00:00` | [src/consensus/consensus.h](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/consensus/consensus.h?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | exit 0; 94 lines; `dd1614388a060ec674e7aea13d001cf9171e66ed` |
| `2026-10-12T18:49:39+00:00` | [src/script/standard.cpp](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/script/standard.cpp?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | exit 0; 501 lines; `2c29df25c2050796ac6115303140a5e4e49fc0b8` |
| `2026-10-12T18:49:39+00:00` | [src/coins.cpp](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/coins.cpp?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | exit 0; 568 lines; `e348fafb311cb7dc3e0bc94789e981363d509362` |
| `2026-10-12T18:49:39+00:00` | [src/policy/policy.cpp](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/policy/policy.cpp?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | exit 0; 198 lines; `809611b82283ca8b918acc3c82d9d93dd8e0a60e` |
| `2026-10-12T18:49:39+00:00` | [src/amount.cpp](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/amount.cpp?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | exit 0; 50 lines; `8fbc88bccd0b3f9d619f7b99ac7a7e5aa05fd159` |
| `2026-10-12T18:49:39+00:00` | [src/txn_double_spend_detector.cpp](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/txn_double_spend_detector.cpp?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | exit 0; 138 lines; `ce149498be647c10de02ddb989ccebe04e2889ac` |
| `2026-10-12T18:49:39+00:00` | [src/txn_validation_data.h](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/txn_validation_data.h?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | exit 0; 184 lines; `0fa48c8029f037526c698e9789baa184db221b4b` |
| `2026-10-12T18:49:39+00:00` | [src/txn_recent_rejects.cpp](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/txn_recent_rejects.cpp?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | exit 0; 27 lines; `68313f77a9c1ee29537d496541ff90127b12db22` |
| `2026-10-12T18:49:39+00:00` | [src/txn_recent_rejects.h](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/txn_recent_rejects.h?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | exit 0; 59 lines; `f2cbb5cfef0b357f96b07cf66979056d80351e51` |
| `2026-10-12T18:49:39+00:00` | [src/net/net.cpp](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/net/net.cpp?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | exit 0; 3658 lines; `aa52706836fc7fe1a61c21e622cb1dda71abe277` |
| `2026-10-12T18:49:39+00:00` | [src/protocol_era.cpp](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/protocol_era.cpp?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | exit 0; 128 lines; `aa01141bbb08d9e7b285a666c7c376a491f7aaee` |
| `2026-10-12T18:49:39+00:00` | [src/verify_script_flags.cpp](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/verify_script_flags.cpp?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | exit 0; 82 lines; `29674d406ad9eb70019bebbbf608f72c9d0b4f05` |
| `2026-10-12T18:49:40+00:00` | [src/script/script_flags.h](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/script/script_flags.h?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | exit 0; 172 lines; `399728e801d8af369e92a0b1db9b3b67999bd72f` |
| `2026-10-12T18:50:51+00:00` | [src/config.cpp](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/config.cpp?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | exit 0; 2710 lines; `c81ff74c06b3430e8a01b5af381508a06f476811` |
| `2026-10-12T18:50:52+00:00` | [src/utiltime.cpp](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/utiltime.cpp?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | exit 0; 104 lines; `8c72ea0c97fb7ec621c17025ab16d2fe46962673` |
| `2026-10-12T18:50:52+00:00` | [src/utiltime.h](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/utiltime.h?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | exit 0; 47 lines; `987fb85eb2781250af344e1ebd589e275d785bc8` |
| `2026-10-12T18:58:42+00:00` | [src/script/interpreter.cpp](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/script/interpreter.cpp?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | exit 0; 2452 lines; `dfcd2a2b061400a5eafdfd8bab242e935ed72acf` |
| `2026-10-12T18:58:42+00:00` | [src/script/script_error.cpp](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/script/script_error.cpp?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | exit 0; 119 lines; `9dd3113d4a1681fa04a980d13ef226b170936efd` |
| `2026-10-12T18:58:43+00:00` | [src/consensus/validation.h](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/consensus/validation.h?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | exit 0; 142 lines; `b158eef0b97f0e39a5bea16d55ed3b58095d615e` |
| `2026-10-12T18:58:43+00:00` | [src/policy/policy.h](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/policy/policy.h?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | exit 0; 293 lines; `284ff428efc916d36424564ea86c484781782eab` |
| `2026-10-12T18:58:43+00:00` | [src/transaction/beef_stream.rs](https://api.github.com/repos/Calhooon/bsv-rs/contents/src/transaction/beef_stream.rs?ref=d06ea0dd12afba8f1a5ced9daf7faa61ba97ea69) | exit 0; 3468 lines; `cc8dbfe05e5fd27a7de27fc4bb594d9f42e8eb7b` |

[M] #64 chain transitions, 2026-10-12: [M] 23 public HTTP reads, each with its request-start UTC receipt below, comprising [M] 15 pinned source files and 8 issue/body/comment requests. The opening [origin fetch](https://github.com/Calgooon/bsv-script-lean.git) has [M] `2026-10-12T18:19:46.049155+00:00` as its FETCH_HEAD completion marker; its request-start time was not captured. The reference source was obtained only through the public contents API at [SRC] `6504a3aff65ba97c0f6c80962b033e35ecbfed4b`. Local compiled dependency artifacts were copied from the dependency's build. No node was started and no transaction was broadcast. The [chain record](records/20261012-190104-s6-64-chain.md) separates derived witnesses, spec-projection measurements and owed node observations.

| [M] UTC request start | public read | [M] result |
|---|---|---|
| `2026-10-12T18:21:26Z` | [src/validation.cpp](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/validation.cpp?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | exit 0; 7746 lines; blob `f2f5fa101028f0f73955b06b339c37570c57251a` |
| `2026-10-12T18:21:26Z` | [src/processing_block_index.cpp](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/processing_block_index.cpp?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | exit 0; 96 lines; blob `87071187334e701a6de67fdd17e69ab6a221d846` |
| `2026-10-12T18:21:26Z` | [src/txmempool.cpp](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/txmempool.cpp?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | exit 0; 3361 lines; blob `a2021721d358c49fd0692d25fb8dd5c52fa36130` |
| `2026-10-12T18:21:26Z` | [src/txmempool.h](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/txmempool.h?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | exit 0; 1548 lines; blob `929141d8eae6e9f7c410022a0a21af8a07dce428` |
| `2026-10-12T18:21:26Z` | [src/block_index.h](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/block_index.h?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | exit 0; 1277 lines; blob `543097e796ad0fcc9f9b104f96030129e28dc569` |
| `2026-10-12T18:21:26Z` | [src/block_index.cpp](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/block_index.cpp?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | exit 0; 466 lines; blob `25fb1bde9384a6b3ebe5ddc7a59ef35b70478dd0` |
| `2026-10-12T18:21:26Z` | [src/undo.h](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/undo.h?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | exit 0; 143 lines; blob `cca2d4beb38046c05a097eceb85435498ab29cf4` |
| `2026-10-12T18:21:26Z` | [src/coins.cpp](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/coins.cpp?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | exit 0; 568 lines; blob `e348fafb311cb7dc3e0bc94789e981363d509362` |
| `2026-10-12T18:21:26Z` | [src/rpc/blockchain.cpp](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/rpc/blockchain.cpp?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | exit 0; 3839 lines; blob `c8eafc6f5bfd05029247d750a67f8de68b266baa` |
| `2026-10-12T18:21:26Z` | [src/validation.h](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/validation.h?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | exit 0; 1190 lines; blob `32c4acd90ece216a23b8b201ced0d1a983f2d3f4` |
| `2026-10-12T18:21:26Z` | [src/chain.h](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/chain.h?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | exit 0; 99 lines; blob `1fe2cb7f773e89f18c81d16467539cd08dd3be77` |
| `2026-10-12T18:21:26Z` | [src/frozentxo.cpp](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/frozentxo.cpp?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | exit 0; 176 lines; blob `205039a429e1d6b359485be4a16588a4427bc055` |
| `2026-10-12T18:21:27Z` | [src/frozentxo.h](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/frozentxo.h?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | exit 0; 141 lines; blob `366599ba4e123a32eb4c4b152e330ee1da0f009e` |
| `2026-10-12T18:21:27Z` | [src/block_file_access.h](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/block_file_access.h?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | exit 0; 97 lines; blob `21bb222a1a7b3408c1ba6fe7186edfa124b1e637` |
| `2026-10-12T18:21:27Z` | [issue-64.txt](https://api.github.com/repos/Calgooon/bsv-script-lean/issues/64) | exit 0; 12 lines; blob `06a4d07c911a6f3e66bfcbffe5aad3a60e9296f1` |
| `2026-10-12T18:21:27Z` | [issue-65.txt](https://api.github.com/repos/Calgooon/bsv-script-lean/issues/65) | exit 0; 12 lines; blob `41f89a5a8e657c2ec951b2abbafde1adab4c398a` |
| `2026-10-12T18:21:27Z` | [issue-66.txt](https://api.github.com/repos/Calgooon/bsv-script-lean/issues/66) | exit 0; 12 lines; blob `5c047c4548ef1079993a4ac7eddf6d986cdb19e4` |
| `2026-10-12T18:21:27Z` | [issue-68.txt](https://api.github.com/repos/Calgooon/bsv-script-lean/issues/68) | exit 0; 12 lines; blob `24ebd30d4a86b2373ff8ab77aea1131f0b9a0335` |
| `2026-10-12T18:21:27Z` | [issue-69.txt](https://api.github.com/repos/Calgooon/bsv-script-lean/issues/69) | exit 0; 12 lines; blob `7a9eab46c0cb1aa3841a56d221dee78dc6ff70fa` |
| `2026-10-12T18:21:27Z` | [issue-70.txt](https://api.github.com/repos/Calgooon/bsv-script-lean/issues/70) | exit 0; 12 lines; blob `9233210a4210b5c326adcc49d7347c1700b2adc1` |
| `2026-10-12T18:21:27Z` | [issue-73.txt](https://api.github.com/repos/Calgooon/bsv-script-lean/issues/73) | exit 0; 12 lines; blob `e899b9628d0bb741ddaf5124a68c44a6c147b9cd` |
| `2026-10-12T18:21:27Z` | [issue-64-comments.txt](https://api.github.com/repos/Calgooon/bsv-script-lean/issues/64/comments) | exit 0; 2 lines; blob `5abd8fea17ccbc8a7524b2a80f52bf1eb631b626` |
| `2026-10-12T18:57:11Z` | [src/txn_validator.cpp](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/txn_validator.cpp?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | exit 0; 801 lines; blob `c05c72729a24b9276136a8b00bc6c45abc6cc032` |


### #64 pinned public reads

[M] 2026-10-12: 23 successful public contents requests at
[SRC] `6504a3aff65ba97c0f6c80962b033e35ecbfed4b`, base64-decoded and hashed.
The lens's finality, linkage, promotion, activation, failure, era-clear and
selected-target passages were read in the numbered source. The
[chain record](records/20261012-190104-s6-64-chain.md) records the corrections
and separates derived fixtures from #66's pending node column.

| [M] UTC request | pinned public source | [M] response |
|---|---|---|
| `2026-10-12T20:02:33.740503+00:00` | [src/validation.cpp](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/validation.cpp?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | exit 0; [M] 7746 lines; blob `f2f5fa101028f0f73955b06b339c37570c57251a` |
| `2026-10-12T20:02:34.287980+00:00` | [src/txmempool.cpp](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/txmempool.cpp?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | exit 0; [M] 3361 lines; blob `a2021721d358c49fd0692d25fb8dd5c52fa36130` |
| `2026-10-12T20:02:34.742102+00:00` | [src/txmempool.h](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/txmempool.h?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | exit 0; [M] 1548 lines; blob `929141d8eae6e9f7c410022a0a21af8a07dce428` |
| `2026-10-12T20:02:35.132745+00:00` | [src/block_index.h](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/block_index.h?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | exit 0; [M] 1277 lines; blob `543097e796ad0fcc9f9b104f96030129e28dc569` |
| `2026-10-12T20:02:35.511065+00:00` | [src/processing_block_index.cpp](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/processing_block_index.cpp?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | exit 0; [M] 96 lines; blob `87071187334e701a6de67fdd17e69ab6a221d846` |
| `2026-10-12T20:02:35.836712+00:00` | [src/undo.h](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/undo.h?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | exit 0; [M] 143 lines; blob `cca2d4beb38046c05a097eceb85435498ab29cf4` |
| `2026-10-12T20:02:36.189846+00:00` | [src/coins.cpp](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/coins.cpp?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | exit 0; [M] 568 lines; blob `e348fafb311cb7dc3e0bc94789e981363d509362` |
| `2026-10-12T20:02:36.528987+00:00` | [src/rpc/blockchain.cpp](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/rpc/blockchain.cpp?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | exit 0; [M] 3839 lines; blob `c8eafc6f5bfd05029247d750a67f8de68b266baa` |
| `2026-10-12T20:02:36.977093+00:00` | [src/leaky_bucket.h](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/leaky_bucket.h?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | exit 0; [M] 104 lines; blob `d4ab07929d14b033e6b149267ebd70544635cb6a` |
| `2026-10-12T20:02:37.306886+00:00` | [src/amount.cpp](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/amount.cpp?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | exit 0; [M] 50 lines; blob `8fbc88bccd0b3f9d619f7b99ac7a7e5aa05fd159` |
| `2026-10-12T20:02:37.653377+00:00` | [src/txn_validator.cpp](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/txn_validator.cpp?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | exit 0; [M] 801 lines; blob `c05c72729a24b9276136a8b00bc6c45abc6cc032` |
| `2026-10-12T20:20:41.050372+00:00` | [src/block_index.cpp](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/block_index.cpp?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | exit 0; [M] 466 lines; blob `25fb1bde9384a6b3ebe5ddc7a59ef35b70478dd0` |
| `2026-10-12T20:20:41.490456+00:00` | [src/validation.h](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/validation.h?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | exit 0; [M] 1190 lines; blob `32c4acd90ece216a23b8b201ced0d1a983f2d3f4` |
| `2026-10-12T20:20:41.868071+00:00` | [src/chain.h](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/chain.h?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | exit 0; [M] 99 lines; blob `1fe2cb7f773e89f18c81d16467539cd08dd3be77` |
| `2026-10-12T20:20:42.178621+00:00` | [src/frozentxo.cpp](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/frozentxo.cpp?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | exit 0; [M] 176 lines; blob `205039a429e1d6b359485be4a16588a4427bc055` |
| `2026-10-12T20:20:42.499124+00:00` | [src/frozentxo.h](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/frozentxo.h?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | exit 0; [M] 141 lines; blob `366599ba4e123a32eb4c4b152e330ee1da0f009e` |
| `2026-10-12T20:20:42.796001+00:00` | [src/block_file_access.h](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/block_file_access.h?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | exit 0; [M] 97 lines; blob `21bb222a1a7b3408c1ba6fe7186edfa124b1e637` |
| `2026-10-12T20:32:56.520622+00:00` | [src/amount.h](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/amount.h?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | exit 0; [M] 178 lines; blob `b6865905ee31a390dd719e05dc391e4b1b278cae` |
| `2026-10-12T20:32:56.966531+00:00` | [src/config.cpp](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/config.cpp?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | exit 0; [M] 2710 lines; blob `c81ff74c06b3430e8a01b5af381508a06f476811` |
| `2026-10-12T20:32:57.456685+00:00` | [src/configscriptpolicy.cpp](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/configscriptpolicy.cpp?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | exit 0; [M] 496 lines; blob `340acde9a9bfea32e12ac959ee5fa5685f033696` |
| `2026-10-12T20:32:57.899049+00:00` | [src/consensus/validation.h](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/consensus/validation.h?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | exit 0; [M] 142 lines; blob `b158eef0b97f0e39a5bea16d55ed3b58095d615e` |
| `2026-10-12T20:32:58.236917+00:00` | [src/primitives/block.h](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/primitives/block.h?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | exit 0; [M] 182 lines; blob `11c3b7c5ae39953c65a0329901c41b73dd4b0344` |
| `2026-10-12T20:32:58.546198+00:00` | [src/script/script.cpp](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/script/script.cpp?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | exit 0; [M] 294 lines; blob `5dc4c57560717a50b77f0748ab14ec430cb5b165` |



### Pin read log (#66, regtest), 2026-10-13

[M] Source reads use `git show` in `<the maintainers' build host>:bitcoin-sv` at [SRC] `6504a3aff65ba97c0f6c80962b033e35ecbfed4b`, never its working tree. The table records every pinned source consumed directly in this pass; repeated source entries are range rereads. The issue body/comments were read by REST from `https://api.github.com/repos/Calgooon/bsv-script-lean/issues/66` and its `/comments` endpoint during the opening read pass; exact request seconds were not captured. [Record](records/20261013-024612-s6-66-regtest-s3.md).

| UTC read | clone and source at pin [SRC] | precision |
|---|---|---|
| 2026-10-13T02:40:07.371744+00:00 | `<the maintainers' build host>:bitcoin-sv/src/rpc/blockchain.cpp` | request start captured |
| 2026-10-13T02:40:07.398215+00:00 | `<the maintainers' build host>:bitcoin-sv/src/rpc/mining.cpp` | request start captured |
| 2026-10-13T02:40:07.440811+00:00 | `<the maintainers' build host>:bitcoin-sv/src/rpc/rawtransaction.cpp` | request start captured |
| 2026-10-13T02:40:07.474524+00:00 | `<the maintainers' build host>:bitcoin-sv/src/rpc/misc.cpp` | request start captured |
| 2026-10-13T02:40:07.518876+00:00 | `<the maintainers' build host>:bitcoin-sv/src/config.cpp` | request start captured |
| 2026-10-13T02:40:07.560464+00:00 | `<the maintainers' build host>:bitcoin-sv/src/chainparams.cpp` | request start captured |
| 2026-10-13T02:40:07.603502+00:00 | `<the maintainers' build host>:bitcoin-sv/src/init.cpp` | request start captured |
| 2026-10-13T02:40:07.631244+00:00 | `<the maintainers' build host>:bitcoin-sv/src/bitcoind.cpp` | request start captured |
| 2026-10-13T02:40:07.665025+00:00 | `<the maintainers' build host>:bitcoin-sv/src/rpc/server.cpp` | request start captured |
| 2026-10-13T02:40:07.690596+00:00 | `<the maintainers' build host>:bitcoin-sv/src/httpserver.cpp` | request start captured |
| 2026-10-13T02:40:07.718078+00:00 | `<the maintainers' build host>:bitcoin-sv/src/rpc/protocol.cpp` | request start captured |
| 2026-10-13T02:40:07.751484+00:00 | `<the maintainers' build host>:bitcoin-sv/src/httprpc.cpp` | request start captured |
| 2026-10-13T02:40:07.788256+00:00 | `<the maintainers' build host>:bitcoin-sv/src/chainparamsbase.cpp` | request start captured |
| 2026-10-13T02:40:07.821867+00:00 | `<the maintainers' build host>:bitcoin-sv/src/txn_validator.cpp` | request start captured |
| 2026-10-13T02:40:07.855717+00:00 | `<the maintainers' build host>:bitcoin-sv/src/validation.cpp` | request start captured |
| 2026-10-13T02:46:30.115448+00:00 | `<the maintainers' build host>:bitcoin-sv/src/init.cpp` | request start captured |
| 2026-10-13T02:46:30.136636+00:00 | `<the maintainers' build host>:bitcoin-sv/src/httprpc.cpp` | request start captured |
| 2026-10-13T02:46:30.156697+00:00 | `<the maintainers' build host>:bitcoin-sv/src/httpserver.cpp` | request start captured |
| 2026-10-13T02:46:30.175190+00:00 | `<the maintainers' build host>:bitcoin-sv/src/chainparamsbase.cpp` | request start captured |
| 2026-10-13T02:46:30.192853+00:00 | `<the maintainers' build host>:bitcoin-sv/src/rpc/server.cpp` | request start captured |
| 2026-10-13T02:46:30.213718+00:00 | `<the maintainers' build host>:bitcoin-sv/src/validation.cpp` | request start captured |
| 2026-10-13T02:46:30.233469+00:00 | `<the maintainers' build host>:bitcoin-sv/src/consensus/consensus.h` | request start captured |
| 2026-10-13T02:46:30.251660+00:00 | `<the maintainers' build host>:bitcoin-sv/src/block_index.h` | request start captured |
| 2026-10-13T02:48:00Z | `<the maintainers' build host>:bitcoin-sv/src/rpc/mining.cpp` | UTC minute of local range read; seconds not captured |
| 2026-10-13T02:42:00Z | `<the maintainers' build host>:bitcoin-sv/src/rpc/rawtransaction.cpp` | UTC minute of local range read; seconds not captured |

[M] Read `2026-10-13T03:18:16.241799+00:00`: local pinned source [SRC] `src/config.cpp:232-245` at `6504a3aff65ba97c0f6c80962b033e35ecbfed4b`, git show exit [M] 0.

[M] Read `2026-10-13T03:18:16.301023+00:00`: local pinned source [SRC] `src/validation.cpp:847-946` at `6504a3aff65ba97c0f6c80962b033e35ecbfed4b`, git show exit [M] 0.

[M] Read `2026-10-13T03:18:16.377040+00:00`: local pinned source [SRC] `src/txn_validator.cpp:145-230,285-320,400-451` at `6504a3aff65ba97c0f6c80962b033e35ecbfed4b`, git show exit [M] 0.

[M] Read `2026-10-13T03:18:16.423165+00:00`: local pinned source [SRC] `src/test/mempool_limit_tests.cpp:200-490` at `6504a3aff65ba97c0f6c80962b033e35ecbfed4b`, git show exit [M] 0.

[M] Read `2026-10-13T03:18:35.261076+00:00`: local pinned source [SRC] `src/rpc/rawtransaction.cpp:1530-1672,1798-1860,2110-2240` at `6504a3aff65ba97c0f6c80962b033e35ecbfed4b`, git show exit [M] 0.

[M] Read `2026-10-13T03:18:35.284585+00:00`: local pinned source [SRC] `src/rawtxvalidator.cpp:1-85` at `6504a3aff65ba97c0f6c80962b033e35ecbfed4b`, git show exit [M] 0.

[M] Read `2026-10-13T03:18:35.313768+00:00`: local pinned source [SRC] `src/time_locked_mempool.cpp:240-244,320-350,611-663` at `6504a3aff65ba97c0f6c80962b033e35ecbfed4b`, git show exit [M] 0.

[M] Read `2026-10-13T03:18:35.343247+00:00`: local pinned source [SRC] `src/txmempool.cpp:3200-3235` at `6504a3aff65ba97c0f6c80962b033e35ecbfed4b`, git show exit [M] 0.

[M] Read `2026-10-13T03:18:35.364165+00:00`: local pinned source [SRC] `src/wallet/merkle_tx.cpp:88-111` at `6504a3aff65ba97c0f6c80962b033e35ecbfed4b`, git show exit [M] 0.

[M] Read `2026-10-13T03:18:35.383539+00:00`: local pinned source [SRC] `src/rpc/mining.cpp:826-843` at `6504a3aff65ba97c0f6c80962b033e35ecbfed4b`, git show exit [M] 0.

[M] Read `2026-10-13T03:18:44.647125+00:00`: local pinned source [SRC] `src/rawtxvalidator.cpp:1-139` at `6504a3aff65ba97c0f6c80962b033e35ecbfed4b`, git show exit [M] 0.

[M] Read `2026-10-13T03:18:44.691617+00:00`: local pinned source [SRC] `src/rpc/rawtransaction.cpp:2242-2340` at `6504a3aff65ba97c0f6c80962b033e35ecbfed4b`, git show exit [M] 0.

[M] Opening reads at 2026-10-13T03:17:36Z: local pinned `git grep -n LimitMempoolSize` across `src/` and repository REST issue #66 body/comments; exit [M] 0. Origin fetched and branch rebased before edits.

[M] REST read of repository issue #75 body at 2026-10-13T03:24Z (minute captured), exit [M] 0; single-transaction proof done-bar checked against the owned node.

[M] Read `2026-10-13T03:30:03.354069+00:00`: local pinned source [SRC] `src/rpc/misc.cpp:506-545,732-892` at `6504a3aff65ba97c0f6c80962b033e35ecbfed4b`, git show exit [M] 0.

[M] Read `2026-10-13T03:30:03.423355+00:00`: local pinned source [SRC] `src/configscriptpolicy.cpp:164-308` at `6504a3aff65ba97c0f6c80962b033e35ecbfed4b`, git show exit [M] 0.

[M] Read `2026-10-13T03:30:03.498827+00:00`: local pinned source [SRC] `src/init.cpp:2609-2616,2940-3010` at `6504a3aff65ba97c0f6c80962b033e35ecbfed4b`, git show exit [M] 0.

[M] REST read of repository issue #63 comments at 2026-10-13T03:33Z (minute captured), exit [M] 0; predecessor Finding ids located for R3 follow-ups.

[M] Read `2026-10-13T03:40:42.380084+00:00`: local pinned source [SRC] `src/configscriptpolicy.cpp:310-355` at `6504a3aff65ba97c0f6c80962b033e35ecbfed4b`, git show exit [M] 0.

[M] Read `2026-10-13T03:40:42.397929+00:00`: local pinned source [SRC] `src/init.cpp:2840-2870,3150-3168` at `6504a3aff65ba97c0f6c80962b033e35ecbfed4b`, git show exit [M] 0.

[M] Local pinned symbol grep at 2026-10-13T03:39:43Z: SetGenesisActivationHeight, maxstdtxvalidationduration, acceptnonstdoutputs, maxtxfee and acceptnonstdtxn in src/configscriptpolicy.cpp and src/init.cpp; git grep exit [M] 0.

[M] Read `2026-10-13T03:47:52.232842+00:00`: local pinned source [SRC] `src/validation.cpp:5736-5791` at `6504a3aff65ba97c0f6c80962b033e35ecbfed4b`, git show exit [M] 0.

[M] Read `2026-10-13T03:47:52.255756+00:00`: local pinned source [SRC] `src/init.cpp:2640-2690` at `6504a3aff65ba97c0f6c80962b033e35ecbfed4b`, git show exit [M] 0.

[M] REST read at 2026-10-13T04:19:08.943710+00:00: repository issue comment `6137350199` for lens-66 item 7; exit [M] 0.

[M] REST read at 2026-10-13T04:19:09.395895+00:00: repository issue comment `6137350348` for lens-66 item 7; exit [M] 0.

[M] REST read at 2026-10-13T04:19:09.922788+00:00: repository issue comment `6137350471` for lens-66 item 7; exit [M] 0.

[M] REST PATCH and response check at 2026-10-13T04:24:17.663315+00:00: comments `6137350199`, `6137350348`, `6137350471`, only the requested [SRC]/[D] label insertions; exact body equality checked [X].

[M] Pinned read at 2026-10-13T04:26:45.161072+00:00: [SRC] `src/rpc/rawtransaction.cpp:1550-1656` at `6504a3aff65ba97c0f6c80962b033e35ecbfed4b`, git show exit [M] 0; mempool recipe feasibility.

[M] Pinned read at 2026-10-13T04:26:45.177085+00:00: [SRC] `src/validation.cpp:1009-1037,1110-1167,1190-1245,1480-1540` at `6504a3aff65ba97c0f6c80962b033e35ecbfed4b`, git show exit [M] 0; mempool recipe feasibility.

[M] Pinned read at 2026-10-13T04:26:45.192475+00:00: [SRC] `src/init.cpp:2850-2869` at `6504a3aff65ba97c0f6c80962b033e35ecbfed4b`, git show exit [M] 0; mempool recipe feasibility.

[M] Pinned symbol grep at 2026-10-13T04:31:20.874321+00:00: `maxTxSigOpsCountPolicy` in `src/` at `6504a3aff65ba97c0f6c80962b033e35ecbfed4b`, exit [M] 0.

[M] Pinned symbol grep at 2026-10-13T04:31:20.906629+00:00: `maxTxSizeConsensusBeforeGenesis` in `src/` at `6504a3aff65ba97c0f6c80962b033e35ecbfed4b`, exit [M] 1.

[M] Pinned symbol grep at 2026-10-13T04:31:20.942217+00:00: `nonfinalreplacementrate` in `src/` at `6504a3aff65ba97c0f6c80962b033e35ecbfed4b`, exit [M] 1.

[M] Pinned symbol grep at 2026-10-13T04:31:20.975006+00:00: `limitancestorcount` in `src/` at `6504a3aff65ba97c0f6c80962b033e35ecbfed4b`, exit [M] 0.

[M] Pinned symbol grep at 2026-10-13T04:31:21.007969+00:00: `maxtxfee` in `src/` at `6504a3aff65ba97c0f6c80962b033e35ecbfed4b`, exit [M] 0.

[M] Pinned symbol grep at 2026-10-13T04:31:21.040508+00:00: `GetMaxTxSize` in `src/` at `6504a3aff65ba97c0f6c80962b033e35ecbfed4b`, exit [M] 0.

[M] Pinned grep at 2026-10-13T04:32:15.253379+00:00: `maxsigopscountpolicy` in `src/` at `6504a3aff65ba97c0f6c80962b033e35ecbfed4b`, exit [M] 1.

[M] Pinned grep at 2026-10-13T04:32:15.306254+00:00: `nonfinaltxnreplacement` in `src/` at `6504a3aff65ba97c0f6c80962b033e35ecbfed4b`, exit [M] 1.

[M] Pinned grep at 2026-10-13T04:32:15.354973+00:00: `limitsecondarymempoolancestorcount` in `src/` at `6504a3aff65ba97c0f6c80962b033e35ecbfed4b`, exit [M] 1.

[M] Pinned grep at 2026-10-13T04:32:15.410974+00:00: `fUseLimits` in `src/` at `6504a3aff65ba97c0f6c80962b033e35ecbfed4b`, exit [M] 0.

[M] Pinned read at 2026-10-13T04:32:15.438880+00:00: [SRC] `src/configscriptpolicy.cpp:397-419` at `6504a3aff65ba97c0f6c80962b033e35ecbfed4b`, git show exit [M] 0.

[M] Pinned read at 2026-10-13T04:32:15.462732+00:00: [SRC] `src/wallet/wallet.cpp:4404-4430` at `6504a3aff65ba97c0f6c80962b033e35ecbfed4b`, git show exit [M] 0.

[M] Pinned read at 2026-10-13T04:32:15.484926+00:00: [SRC] `src/rawtxvalidator.cpp:28-54` at `6504a3aff65ba97c0f6c80962b033e35ecbfed4b`, git show exit [M] 0.

[M] Pinned read at 2026-10-13T04:32:15.508266+00:00: [SRC] `src/txn_validator.cpp:148-185` at `6504a3aff65ba97c0f6c80962b033e35ecbfed4b`, git show exit [M] 0.

[M] Pinned read at 2026-10-13T04:32:15.528303+00:00: [SRC] `src/init.cpp:2530-2575,2755-2785` at `6504a3aff65ba97c0f6c80962b033e35ecbfed4b`, git show exit [M] 0.

[M] Pinned grep at 2026-10-13T04:32:30.704425+00:00: `SetMaxTxSigOpsCountPolicy` in `src/` at `6504a3aff65ba97c0f6c80962b033e35ecbfed4b`, exit [M] 0.

[M] Pinned grep at 2026-10-13T04:32:30.760398+00:00: `ReplacementRate` in `src/` at `6504a3aff65ba97c0f6c80962b033e35ecbfed4b`, exit [M] 0.

[M] Pinned grep at 2026-10-13T04:32:30.839515+00:00: `minrelaytxfee` in `src/` at `6504a3aff65ba97c0f6c80962b033e35ecbfed4b`, exit [M] 0.

[M] Pinned read at 2026-10-13T04:32:45.938718+00:00: [SRC] `src/init.cpp:3204-3223,3085-3103` at `6504a3aff65ba97c0f6c80962b033e35ecbfed4b`, git show exit [M] 0.

[M] Pinned read at 2026-10-13T04:32:45.968332+00:00: [SRC] `src/validation.h:70-84` at `6504a3aff65ba97c0f6c80962b033e35ecbfed4b`, git show exit [M] 0.

[M] Pinned read at 2026-10-13T04:32:45.988738+00:00: [SRC] `src/time_locked_mempool.cpp:390-433` at `6504a3aff65ba97c0f6c80962b033e35ecbfed4b`, git show exit [M] 0.

[M] Pinned read at 2026-10-13T04:32:46.008883+00:00: [SRC] `src/config.cpp:2391-2418,1150-1168` at `6504a3aff65ba97c0f6c80962b033e35ecbfed4b`, git show exit [M] 0.

[M] Pinned grep at 2026-10-13T04:32:56.485368+00:00: `minRelayTxFee` in `src/` at `6504a3aff65ba97c0f6c80962b033e35ecbfed4b`, exit [M] 0.

[M] Pinned read at 2026-10-13T04:41:14.996151+00:00: [SRC] `src/txn_validator.cpp:178-207` at `6504a3aff65ba97c0f6c80962b033e35ecbfed4b`, git show exit [M] 0; synchronous finalised-transaction revalidation.

[M] Pinned read at 2026-10-13T04:42:28.124773+00:00: [SRC] `src/rpc/rawtransaction.cpp:1649-1675` at `6504a3aff65ba97c0f6c80962b033e35ecbfed4b`, git show exit [M] 0; repeated-held RPC envelope.

[M] 2026-10-13: local pinned git show/grep reads at `6504a3aff65ba97c0f6c80962b033e35ecbfed4b`: [SRC] `src/validation.cpp:2252-2262,3655-3666,5634-5735,5736-6107,6140-6193`; `src/chainparams.cpp:1455-1535`; `src/config.cpp:230-247,825-838`; `src/pow.cpp:22-171`; `src/rpc/mining.cpp:820-952`; `src/rpc/misc.cpp:980-1010`; `src/init.cpp:2602-2622`; `src/arith_uint256.cpp:182-201`. Greps covered BIP34 activation, sigop getters and TTOR. Exit [M] 0; individual read-start times were not captured. The initial origin fetch succeeded; exact request-start time unverified. Local context reads and per-kind live RPC read receipts are indexed by [the record](records/20261013-045714-s6-66-blk-regtest-s3.md). No external node request occurred.

[M] Follow-up local reads, recorded at 2026-10-13T05:09:19.784479+00:00: [SRC] `src/validation.cpp:6390-6495`, `src/validation.h:338-374`, `src/utiltime.cpp:20-100` at `6504a3aff65ba97c0f6c80962b033e35ecbfed4b`; activation/retarget/subsidy override grep in `src/chainparams.cpp`, `src/init.cpp` and `src/rpc/`. Exit [M] 0; individual read-start times unverified.

[M] Local pinned grep, recorded at 2026-10-13T05:15:35.975954+00:00: [SRC] `src/consensus/consensus.h:37` and `src/config.cpp:825-834`, `MAX_BLOCK_SIGOPS_PER_MB_BEFORE_GENESIS` at `6504a3aff65ba97c0f6c80962b033e35ecbfed4b`; exit [M] 0.

[M] TTOR reachability reads, recorded at 2026-10-13T05:20:53.232945+00:00: [SRC] `src/rpc/blockchain.cpp:2732-2770`; `src/validation.cpp:2868-2910,3020-3075,4065-4143,5160-5265`; `src/processing_block_index.cpp:79-96` at `6504a3aff65ba97c0f6c80962b033e35ecbfed4b`. Local git show/grep exit [M] 0. Genesis skips undo creation and disconnect requires undo.

### Pin read log (#66, UTXO), 2026-10-13

[M] Local reads from the bitcoin-sv clone at `6504a3aff65ba97c0f6c80962b033e35ecbfed4b` via `git show` and `git grep`: `src/coins.cpp:45-75,548-565`; `src/script/script.h:250-282`; `src/validation.cpp:530-560,2248-2270,2552-2709,3060-3115,3326-3458`; `src/chainparams.cpp:1457-1502`; `src/consensus/consensus.h:69-82`; `src/init.cpp:2604-2640,2890-2935` and symbol searches for launch settings; `src/rpc/blockchain.cpp:1923-2029`; `src/txmempool.cpp:2033-2108`; frozen-list RPC symbol locations. Local inputs: the s6-66/s6-66b/s6-66c records, CLAUDE rules, DESIGN-S6 sections 3 and 5.1, scenario README, UTXO record/corpus/README/Lean checker, core runner and UTXO module, oracle README/conf and lock wrappers. No closed path or sibling tree opened. Exact observations and limitations are in the [record](records/20261013-045648-s6-66-utx-regtest-s3.md).

[M] Continuation: pinned local reads added `src/rpc/frozentxo_rpc.cpp:90-175,320-388,632-810`, `src/frozentxo_db.cpp:614-718`, `src/coins.cpp:75-135`, `src/coins.h:304-326`, `src/verify_script_flags.cpp:11-82`, `src/validation.cpp:2970-2985,3265-3326,3450-3545,3649-3720`, `src/config.cpp:2051-2073`, and launch/RPC searches for maturity, subsidy, BIP30, script verification and standardness selectors. The shared dependency-cache helper was read and used only to attach this package's matching cache; no sibling source was opened. Lean build held its slot [M] 2026-10-13T05:12:03Z through 05:13:16Z after waiting since 04:57:01Z, load [M] 5.27 at build launch; built utxocheck once.

[M] Additional pinned reads: `src/configscriptpolicy.cpp:218-244` for the script-size policy setter; `src/rpc/frozentxo_rpc.cpp:35-90` for half-open interval parsing. Operator calls preserve their exact requests, replies and handler ranges in the family receipt.

[M] REST Findings posted to this repository's #61 for `scripts/false` and `scripts/number-unequal`, using the measured receipt and pinned caller ranges `src/validation.cpp:3690-3715` and `src/rpc/mining.cpp:916-952`. Comment identifiers and URLs are retained in the [receipt](records/20261013-045648-s6-66-utx-regtest-s3.json).
[M] 2026-10-13: read the three s6-66/66b/66c regtest records, CLAUDE.md, DESIGN-S6 sections 3 and 5.1, corpus/scenarios/README.md, the s6-64 chain record, harness/src/scenarios/core.rs and chain.rs, lean/Test/chaincheck.lean, harness/oracle/README.md and scenarios.conf, tools/finality_check.sh and chain_check.sh, the runner driver, Makefile, scenario_preservation.py and cite_check.py. Local pin reads used git show/git grep at 6504a3aff65ba97c0f6c80962b033e35ecbfed4b: [SRC] src/validation.cpp:4036-4066,4640-4805; src/txn_validator.cpp:150-174; src/rawtxvalidator.cpp:1-105; src/txmempool.cpp:1345-1370; src/rpc/blockchain.cpp:1923-2029. These locate era clearing, RPC orphan exclusion, reorg scheduling and chain-only output observations. Host cache helper --help unexpectedly ran status and read configured checkout toolchain/manifest metadata; no implementation or transaction content was consumed. Subsequent share was scoped to this worktree. No network source read or closed evidence was opened. [Record](records/20261013-045905-s6-66-chn-regtest-s3.md).

[M] 2026-10-13: additional local pin reads via git show/git grep, all at 6504a3aff65ba97c0f6c80962b033e35ecbfed4b: [SRC] src/rpc/mining.cpp:830-955 (stored side-branch receipts), src/httpserver.cpp:251-258,356 and src/init.cpp:3565 (bind failure retry), src/rpc/blockchain.cpp:1923-2029 (coin metadata), src/validation.cpp:3021-3068,3290-3385,3530-3675,4640-4770,5965-5990,6260-6315, src/chainparams.cpp:1450-1525, src/block_index.h:1220-1278 and src/txmempool.cpp:947-1023. Read harness/src/block.rs's assembly/signing helpers and the chain fixture's rollback/reorg cases. [Record](records/20261013-045905-s6-66-chn-regtest-s3.md).

[M] 2026-10-13: read [SRC] src/processing_block_index.cpp:9-96 and src/validation.cpp:4065-4133 through git show at 6504a3aff65ba97c0f6c80962b033e35ecbfed4b, confirming reverse undo application, atomic publication and pool settlement boundaries for the recorded chain-only reorg projection.

[M] 2026-10-13: local pin grep over src/rpc/ for preciousblock, softrejectblock, submitheader and submitheaders; read [SRC] src/rpc/blockchain.cpp:2695-2733 and src/validation.cpp:5156-5230 through git show at 6504a3aff65ba97c0f6c80962b033e35ecbfed4b to refine the remaining operator/header receipt work. No header-submission RPC was found by that symbol search; no header-only row is promoted by this read.

[M] 2026-10-13: re-read [SRC] src/validation.cpp:6296-6345,3034-3052 and src/chainparams.cpp:1508-1519 using git show at 6504a3aff65ba97c0f6c80962b033e35ecbfed4b. These bind the unrequested-body prerequisite and the fixed regtest genesis hash to their individual chain row classifications.

[M] 2026-10-13: read [SRC] src/validation.cpp:2252-2264 at 6504a3aff65ba97c0f6c80962b033e35ecbfed4b with git show, checking the subsidy computation used with the regtest halving interval in the reward recipe.
[M] 2026-10-13: read CLAUDE.md; DESIGN-S6 sections 3 and 5.1; the s6-66, s6-66b, s6-66c and s6-60 records; corpus/scenarios/README.md; harness/oracle/README.md and scenarios.conf; scenarios/core.rs, mod.rs and finality.rs; lean/Test/finalitycheck.lean; corpus/chain/finality/{README.md,finality.jsonl}; tools/finality_check.sh, scenario_preservation.py and cite_check.py. Local pinned reads used `git show` and `git grep` in the bitcoin-sv clone at `6504a3aff65ba97c0f6c80962b033e35ecbfed4b`: src/validation.cpp (absolute and relative locks, admission, block cutoff), src/block_index.h (median), src/chainparams.cpp (regtest), src/policy/policy.h (flags), src/init.cpp, src/config.cpp and src/time_locked_mempool.cpp (setting locations). Read completion UTC: 2026-10-13T04:59:48.661496+00:00. The fetch read a review branch. Operational deviation: Lake automatically fetched its declared dependencies from GitHub while preparing the missing finality executable; this exceeded the network allowance. No private program inputs were consumed. The record indexes its artifacts; the shared aggregate indexes are maintained separately.

[M] 2026-10-13, continuation: local pinned reads of src/util.cpp (byte-unit parser), src/validation.cpp (regular structure, unavailable inputs, issuance and unspendable genesis), src/amount.h (MoneyRange), src/time_locked_mempool.cpp and .h (purge age, capacity, scheduled visit order), and src/scheduler.cpp and .h (real scheduler and millisecond interval) at `6504a3aff65ba97c0f6c80962b033e35ecbfed4b`, using git show/grep in the reference clone. These supplement the family recipe source citations.

[M] 2026-10-13, caller audit: local pinned git reads of src/txmempool.cpp (reorg flag selection), src/validation.h (default tip flag), src/wallet/finaltx.cpp and .h, src/wallet/rpcwallet.cpp (default-flag wallet calls and command registration), and src/rpc/server.cpp (absent command envelope) at `6504a3aff65ba97c0f6c80962b033e35ecbfed4b`. The owned build help omits wallet commands; the recipe checks getwalletinfo on an owned node before classifying the negative-flag row.

[M] 2026-10-13: REST read of https://api.github.com/repos/Calgooon/bsv-script-lean confirmed private=true; review completed 2026-10-13T05:43:17.602389+00:00. The user-authorized Finding for #60 row mempool/capacity-1 was posted by REST at 2026-10-13T05:43:16Z: archived #60, comment 6139104677. Its source is the owned regtest receipt and witness; no private-program input or D8 cause is quoted.

[M] 2026-10-13T05:00:23Z: read the s6-66/s6-66b/s6-66c records, CLAUDE.md, DESIGN-S6 sections 3 and 5.1, scenario README, s6-62 family record, mempoolcheck, oracle profile and README, finality lock wrapper, core instance/RPC/receipts/comparator and mempool recipes. Local pinned clone reads at `6504a3aff65ba97c0f6c80962b033e35ecbfed4b`: src/validation.cpp:1009-1496; src/txn_validator.cpp:150-190; src/rpc/rawtransaction.cpp:1555-1665; src/rpc/frozentxo_rpc.cpp:315-346; src/init.cpp:3240-3270; src/chainparams.cpp:1457-1498; src/config.cpp:2410-2425; src/configscriptpolicy.cpp:390-415; src/time_locked_mempool.cpp:390-410. Source-derived feasibility and live scripts receipts: [20261013-045854-s6-66-mem-regtest-s3.md](records/20261013-045854-s6-66-mem-regtest-s3.md). No network source read.

[M] 2026-10-13T05:06:49Z: continued local pin reads at `6504a3aff65ba97c0f6c80962b033e35ecbfed4b`: src/validation.cpp:350-407,515-640,842-882; src/txmempool.h:412-445; src/txmempool.cpp:194-248,480-570,2624-2649,2730-2802; src/init.cpp:2524-2565,3088-3148; src/config.cpp:2440-2465; src/leaky_bucket.h:35-104; src/utiltime.cpp:16-35; src/time_locked_mempool.cpp:30-98,160-220,447-479,490-590; src/txn_double_spend_detector.cpp:1-110; src/rpc/blockchain.cpp:2634-2674. Checked fixed promotion caps, serialized detector observations, separate clocks, relative-height boundary, ancestors and the launch minimum for later pending work. [SRC] ranges and per-row classifications remain in the record.

[M] 2026-10-13T05:39:43Z: additional local pin reads at `6504a3aff65ba97c0f6c80962b033e35ecbfed4b`: src/config.cpp:412-445,2440-2505; src/init.cpp:474-487,1038-1055,2380-2430,3182-3198,3211-3219; src/validation.cpp:721-780; src/time_locked_mempool.cpp:99-115,235-247,611-664; src/rpc/blockchain.cpp:502-552; src/txn_validator.cpp:296-318; src/wallet/wallet.cpp:4265-4295,4406-4427; src/rpc/server.cpp:562-574; src/rpc/rawtransaction.cpp:1996-2045. Symbol searches checked the fixed promotion getter, the wallet guard and both raw-RPC fee selectors; the nonexistent src/policy/feerate.cpp lookup supplied no evidence. The pinned binary help and wallet RPC probe checked effective selector availability. Repository REST read #62 and posted the fee-selector Findings (archived #62, comment 6138949697) with the two corrected high-fee rows and the withdrawn inherited equality claim. No D8 cause was read or disclosed. Final recipe and verification receipts are in [the record](records/20261013-045854-s6-66-mem-regtest-s3.md).

[M] Local pinned read at 2026-10-13T06:16:01.259656+00:00: [SRC] `src/validation.cpp:1119-1123,3690-3715` at `6504a3aff65ba97c0f6c80962b033e35ecbfed4b`, git show exit [M] 0; R6-R8 checks ([record](records/20261013-061601-s6-66-agg-regtest-s3.md)).

[M] Local pinned read at 2026-10-13T06:16:01.272225+00:00: [SRC] `src/time_locked_mempool.cpp:447-474` at `6504a3aff65ba97c0f6c80962b033e35ecbfed4b`, git show exit [M] 0; R6-R8 checks ([record](records/20261013-061601-s6-66-agg-regtest-s3.md)).

[M] Local pinned read at 2026-10-13T06:16:01.284238+00:00: [SRC] `src/primitives/transaction.h:35-50` at `6504a3aff65ba97c0f6c80962b033e35ecbfed4b`, git show exit [M] 0; R6-R8 checks ([record](records/20261013-061601-s6-66-agg-regtest-s3.md)).

[M] Local pinned read at 2026-10-13T06:17:59.297696+00:00: [SRC] `src/script/script.h:30-38` at `6504a3aff65ba97c0f6c80962b033e35ecbfed4b`, git show exit [M] 0; R6-R8 checks ([record](records/20261013-061601-s6-66-agg-regtest-s3.md)).

[M] REST reads recorded at 2026-10-13T06:30:51.653433+00:00: repository issues #60, #61, #62, #63, #66 and #75 comment collections; individual request-start timestamps were not captured. Findings were matched to the eight round records. REST follow-ups on #61 (scripts/false and scripts/number-unequal) and #60 (mempool/capacity-1) retain exact request-start times, response ids and checked bodies in the [aggregate receipt](records/20261013-061601-s6-66-agg-regtest-s3.json).

[M] Build exception recorded at 2026-10-13T06:33:16.854269+00:00: the initial unseeded Lake build logged 8 GitHub dependency clone starts and 7 completed checkouts before termination, outside the network boundary. The [aggregate receipt](records/20261013-061601-s6-66-agg-regtest-s3.json) retains the log and remediation; later builds use the local package cache with GIT_ALLOW_PROTOCOL=file.



[M] 2026-10-13T06:32:34Z: commit boundary read/replay. Read the s6-66-mem, s6-66b, s6-66 and s6-62 records; CLAUDE.md, DESIGN-S6 sections 3 and 5.1, scenario and oracle READMEs, mempoolcheck, core.rs, mempool.rs and the finality lock pattern. Local git show/grep at [SRC] `6504a3aff65ba97c0f6c80962b033e35ecbfed4b`: src/config.cpp:2440-2505; src/init.cpp:2340-2355,2360-2440,2563-2607; src/util.cpp:305-377; src/validation.cpp:840-947,1247-1296; src/time_locked_mempool.cpp:390-615; src/leaky_bucket.h:44-104; src/utiltime.cpp:16-35; src/txmempool.cpp:1350-1388,2090-2135,2600-2810; src/rpc/blockchain.cpp:2630-2675; src/rpc/rawtransaction.cpp:2050-2146; src/rawtxvalidator.cpp:20-139; src/txn_validator.cpp:145-334; src/txn_double_spend_detector.cpp:1-110; src/policy/policy.cpp:22-165. Symbols searched: memory setters, rolling fee, consolidation, batch submission and detector. [Record](records/20261013-061948-s6-66-mem2-regtest-s3.md); protected development details withheld (D8).

[M] 2026-10-13T06:34:24Z: eviction boundary read/replay. Read the s6-66-mem, s6-66b, s6-66 and s6-62 records; CLAUDE.md, DESIGN-S6 sections 3 and 5.1, scenario and oracle READMEs, mempoolcheck, core.rs, mempool.rs and the finality lock pattern. Local git show/grep at [SRC] `6504a3aff65ba97c0f6c80962b033e35ecbfed4b`: src/config.cpp:2440-2505; src/init.cpp:2340-2355,2360-2440,2563-2607; src/util.cpp:305-377; src/validation.cpp:840-947,1247-1296; src/time_locked_mempool.cpp:390-615; src/leaky_bucket.h:44-104; src/utiltime.cpp:16-35; src/txmempool.cpp:1350-1388,2090-2135,2600-2810; src/rpc/blockchain.cpp:2630-2675; src/rpc/rawtransaction.cpp:2050-2146; src/rawtxvalidator.cpp:20-139; src/txn_validator.cpp:145-334; src/txn_double_spend_detector.cpp:1-110; src/policy/policy.cpp:22-165. Symbols searched: memory setters, rolling fee, consolidation, batch submission and detector. [Record](records/20261013-061948-s6-66-mem2-regtest-s3.md); protected development details withheld (D8).

[M] 2026-10-13T06:34:56Z: decay boundary read/replay. Read the s6-66-mem, s6-66b, s6-66 and s6-62 records; CLAUDE.md, DESIGN-S6 sections 3 and 5.1, scenario and oracle READMEs, mempoolcheck, core.rs, mempool.rs and the finality lock pattern. Local git show/grep at [SRC] `6504a3aff65ba97c0f6c80962b033e35ecbfed4b`: src/config.cpp:2440-2505; src/init.cpp:2340-2355,2360-2440,2563-2607; src/util.cpp:305-377; src/validation.cpp:840-947,1247-1296; src/time_locked_mempool.cpp:390-615; src/leaky_bucket.h:44-104; src/utiltime.cpp:16-35; src/txmempool.cpp:1350-1388,2090-2135,2600-2810; src/rpc/blockchain.cpp:2630-2675; src/rpc/rawtransaction.cpp:2050-2146; src/rawtxvalidator.cpp:20-139; src/txn_validator.cpp:145-334; src/txn_double_spend_detector.cpp:1-110; src/policy/policy.cpp:22-165. Symbols searched: memory setters, rolling fee, consolidation, batch submission and detector. [Record](records/20261013-061948-s6-66-mem2-regtest-s3.md); protected development details withheld (D8).

[M] 2026-10-13T06:35:11Z: fee boundary read/replay. Read the s6-66-mem, s6-66b, s6-66 and s6-62 records; CLAUDE.md, DESIGN-S6 sections 3 and 5.1, scenario and oracle READMEs, mempoolcheck, core.rs, mempool.rs and the finality lock pattern. Local git show/grep at [SRC] `6504a3aff65ba97c0f6c80962b033e35ecbfed4b`: src/config.cpp:2440-2505; src/init.cpp:2340-2355,2360-2440,2563-2607; src/util.cpp:305-377; src/validation.cpp:840-947,1247-1296; src/time_locked_mempool.cpp:390-615; src/leaky_bucket.h:44-104; src/utiltime.cpp:16-35; src/txmempool.cpp:1350-1388,2090-2135,2600-2810; src/rpc/blockchain.cpp:2630-2675; src/rpc/rawtransaction.cpp:2050-2146; src/rawtxvalidator.cpp:20-139; src/txn_validator.cpp:145-334; src/txn_double_spend_detector.cpp:1-110; src/policy/policy.cpp:22-165. Symbols searched: memory setters, rolling fee, consolidation, batch submission and detector. [Record](records/20261013-061948-s6-66-mem2-regtest-s3.md); protected development details withheld (D8).

[M] 2026-10-13T06:36:26Z: detector boundary read/replay. Read the s6-66-mem, s6-66b, s6-66 and s6-62 records; CLAUDE.md, DESIGN-S6 sections 3 and 5.1, scenario and oracle READMEs, mempoolcheck, core.rs, mempool.rs and the finality lock pattern. Local git show/grep at [SRC] `6504a3aff65ba97c0f6c80962b033e35ecbfed4b`: src/config.cpp:2440-2505; src/init.cpp:2340-2355,2360-2440,2563-2607; src/util.cpp:305-377; src/validation.cpp:840-947,1247-1296; src/time_locked_mempool.cpp:390-615; src/leaky_bucket.h:44-104; src/utiltime.cpp:16-35; src/txmempool.cpp:1350-1388,2090-2135,2600-2810; src/rpc/blockchain.cpp:2630-2675; src/rpc/rawtransaction.cpp:2050-2146; src/rawtxvalidator.cpp:20-139; src/txn_validator.cpp:145-334; src/txn_double_spend_detector.cpp:1-110; src/policy/policy.cpp:22-165. Symbols searched: memory setters, rolling fee, consolidation, batch submission and detector. [Record](records/20261013-061948-s6-66-mem2-regtest-s3.md); protected development details withheld (D8).

[M] 2026-10-13T06:38:41Z: final local [SRC] reads at `6504a3aff65ba97c0f6c80962b033e35ecbfed4b`, src/validation.cpp:1138-1158,1480-1506 and conflict-state symbol grep in src/consensus/validation.h. The two CONFLICT paths share an RPC envelope; no final-stage claim is inferred. Supported-family regression judged [M] 90 unique rows [X]; [record](records/20261013-061948-s6-66-mem2-regtest-s3.md).

[M] 2026-10-13: read the predecessor chain pending-work record, the s6-66/66b recipes, CLAUDE.md, DESIGN-S6 sections 3 and 5.1, corpus/scenarios/README.md, the s6-64 chain record, harness/src/scenarios/core.rs and chain.rs, lean/Test/chaincheck.lean, harness/oracle/README.md and scenarios.conf, tools/finality_check.sh and chain_check.sh, Makefile, scenario_preservation.py and cite_check.py. Local pin reads by git show at 6504a3aff65ba97c0f6c80962b033e35ecbfed4b: [SRC] src/validation.cpp:3290-3448,3580-3677 for ordered dependent inputs and fee/reward checking. Operational exceptions to host-value output and build-network scope are recorded in the [record](records/20261013-061734-s6-66-chn2-regtest-s3.md); no closed source file was opened.

[M] 2026-10-13: local pin reads by git show/git grep at 6504a3aff65ba97c0f6c80962b033e35ecbfed4b: [SRC] src/txn_grouper.cpp:10-43; src/validation.cpp:3324-3338 for `reversed-inputs`. The chaincheck fixture and corresponding boundary expectation were read alongside the source. [Record](records/20261013-061734-s6-66-chn2-regtest-s3.md).

[M] 2026-10-13: local pin reads by git show/git grep at 6504a3aff65ba97c0f6c80962b033e35ecbfed4b: [SRC] src/validation.cpp:3304-3319,3415-3420,3564-3573,3679-3713; src/validation.h:108; src/config.cpp:102 for `queued-script`. The chaincheck fixture and corresponding boundary expectation were read alongside the source. [Record](records/20261013-061734-s6-66-chn2-regtest-s3.md).

[M] 2026-10-13: preparatory local pin reads through git show/git grep at 6504a3aff65ba97c0f6c80962b033e35ecbfed4b: [SRC] src/txn_grouper.cpp:1-110; src/config.cpp:102,517-518,819-821,2049-2071; src/configscriptpolicy.cpp:310-334; src/init.cpp:2509-2525,2609-2616,2646; src/validation.cpp:2252-2265,3021-3118,3460-3585,3675-3718,4065-4133,4640-4770,5662-5725,5968-6040; src/chainparams.cpp:1457-1469,1555-1556; src/txmempool.cpp:947-1023; src/txmempool.h:1455-1544; src/block_index.h:1225-1278; src/processing_block_index.cpp:1-96; src/rpc/blockchain.cpp:1923-2029,2580-2612. These support the pending batching, finality, tie and undo recipe assessments, not fresh verdicts. [Record](records/20261013-061734-s6-66-chn2-regtest-s3.md).

[M] 2026-10-13: local pin reads by git show/git grep at 6504a3aff65ba97c0f6c80962b033e35ecbfed4b: [SRC] src/validation.cpp:3304-3319,3415-3420,3564-3573,3648-3713; src/validation.h:108 for `reward-before-script`. The chaincheck fixture and corresponding boundary expectation were read alongside the source. [Record](records/20261013-061734-s6-66-chn2-regtest-s3.md).

[M] 2026-10-13, correction to the preceding preparatory read log: the processing_block_index.cpp read ended at the file end, line [M] 96, although the sed request extended to [D] 99. The supported citation is [SRC] src/processing_block_index.cpp:1-96 at 6504a3aff65ba97c0f6c80962b033e35ecbfed4b. [M] 2026-10-13, for #68: the earlier log now has its upper bound corrected in place to 96 under the rule-9 instruction.

[M] 2026-10-13: local pin reads by git show/git grep at 6504a3aff65ba97c0f6c80962b033e35ecbfed4b: [SRC] src/txmempool.cpp:947-1023; src/validation.cpp:5978-6037 for `retained-nonfinal-before-genesis`. The chaincheck fixture and corresponding boundary expectation were read alongside the source. [Record](records/20261013-061734-s6-66-chn2-regtest-s3.md).

[M] 2026-10-13: local pin reads by git show/git grep at 6504a3aff65ba97c0f6c80962b033e35ecbfed4b: [SRC] src/txmempool.cpp:947-1023; src/validation.cpp:5978-6037; src/init.cpp:2609-2616; src/configscriptpolicy.cpp:310-321 for `retained-nonfinal-after-genesis`. The chaincheck fixture and corresponding boundary expectation were read alongside the source. [Record](records/20261013-061734-s6-66-chn2-regtest-s3.md).

[M] 2026-10-13: local pin reads by git show/git grep at 6504a3aff65ba97c0f6c80962b033e35ecbfed4b: [SRC] src/validation.cpp:2252-2262,4640-4770; src/chainparams.cpp:1460; src/txmempool.h:1455-1544; src/rpc/mining.cpp:853-877 for `batching`. The chaincheck fixture and corresponding boundary expectation were read alongside the source. [Record](records/20261013-061734-s6-66-chn2-regtest-s3.md).

[M] 2026-10-13: local pin reads by git show/git grep at 6504a3aff65ba97c0f6c80962b033e35ecbfed4b: [SRC] src/processing_block_index.cpp:9-96; src/validation.cpp:4065-4133; src/rpc/blockchain.cpp:1923-2029,2732-2768; src/coins.cpp:546-565 for `undo`. The chaincheck fixture and corresponding boundary expectation were read alongside the source. [Record](records/20261013-061734-s6-66-chn2-regtest-s3.md).

[M] 2026-10-13: local pin reads by git show/git grep at 6504a3aff65ba97c0f6c80962b033e35ecbfed4b: [SRC] src/validation.cpp:3070-3117,4065-4133; src/processing_block_index.cpp:9-96; src/coins.cpp:546-565; src/init.cpp:2514-2520; src/config.cpp:2051-2067; src/chainparams.cpp:1555-1556 for `overwrite`. The chaincheck fixture and corresponding boundary expectation were read alongside the source. [Record](records/20261013-061734-s6-66-chn2-regtest-s3.md).

[M] 2026-10-13: local pin reads by git show/git grep at 6504a3aff65ba97c0f6c80962b033e35ecbfed4b: [SRC] src/rpc/blockchain.cpp:2820-2991; src/validation.cpp:5355-5450 for `soft-rejection`. The chaincheck fixture and corresponding boundary expectation were read alongside the source. [Record](records/20261013-061734-s6-66-chn2-regtest-s3.md).

[M] Pinned read at 2026-10-13T07:22:59.328113+00:00: [SRC] `src/config.cpp:411-421` at `6504a3aff65ba97c0f6c80962b033e35ecbfed4b`, local git show and line slice exit [M] 0; setter/peer-route citation repair.

[M] Pinned read at 2026-10-13T07:22:59.344728+00:00: [SRC] `src/txn_validator.cpp:163-177` at `6504a3aff65ba97c0f6c80962b033e35ecbfed4b`, local git show and line slice exit [M] 0; setter/peer-route citation repair.

[M] Pinned read at 2026-10-13T07:22:59.357235+00:00: [SRC] `src/txn_validator.cpp:244-248` at `6504a3aff65ba97c0f6c80962b033e35ecbfed4b`, local git show and line slice exit [M] 0; setter/peer-route citation repair.

[M] Pinned read at 2026-10-13T07:22:59.369190+00:00: [SRC] `src/validation.cpp:1873-1915` at `6504a3aff65ba97c0f6c80962b033e35ecbfed4b`, local git show and line slice exit [M] 0; setter/peer-route citation repair.

[M] Pinned read at 2026-10-13T07:22:59.382455+00:00: [SRC] `src/validation.cpp:1896-1931` at `6504a3aff65ba97c0f6c80962b033e35ecbfed4b`, local git show and line slice exit [M] 0; setter/peer-route citation repair.

[M] Pinned read at 2026-10-13T07:22:59.395574+00:00: [SRC] `src/net/net_processing.cpp:930-952` at `6504a3aff65ba97c0f6c80962b033e35ecbfed4b`, local git show and line slice exit [M] 0; setter/peer-route citation repair.

[M] Pinned read at 2026-10-13T07:22:59.408632+00:00: [SRC] `src/net/net_processing.cpp:3379-3393` at `6504a3aff65ba97c0f6c80962b033e35ecbfed4b`, local git show and line slice exit [M] 0; setter/peer-route citation repair.

[M] Pinned read at 2026-10-13T07:22:59.421892+00:00: [SRC] `src/rpc/rawtransaction.cpp:1571-1594` at `6504a3aff65ba97c0f6c80962b033e35ecbfed4b`, local git show and line slice exit [M] 0; setter/peer-route citation repair.

[M] ([M] 2026-10-13T08:01:06Z): local git show/git grep reads at bitcoin-sv `6504a3aff65ba97c0f6c80962b033e35ecbfed4b`: [SRC] src/validation.cpp:834-889,1249-1268,1478-1498; src/validation.h:670-730; src/txmempool.cpp:370-435,1365-1383,1800-2004,2097-2140,2624-2805; src/config.cpp:2440-2490; src/txn_validator.cpp:218-327; src/txn_double_spend_detector.cpp:1-100; src/rpc/blockchain.cpp:280-440,2613-2674; src/rpc/mining.cpp:312-347. Required handoff records, CLAUDE.md, DESIGN-S6 sections 3 and 5.1, scenario/family/oracle READMEs, the family source record, core.rs, mempool.rs, mempoolcheck.lean and the host-sourced lock pattern were read locally. [Record](records/20261013-075032-s6-66-mem3-regtest-s3.md).

[M] ([M] 2026-10-13T08:05:13Z): detector follow-up local git grep at `6504a3aff65ba97c0f6c80962b033e35ecbfed4b` for ScriptsChecked across src/, and git show of [SRC] src/validation.cpp:1478-1498; src/txmempool.cpp:1942-2004; src/rpc/mining.cpp:312-347. Source-stage observability and the temporary fee-delta restoration are recorded in [the record](records/20261013-075032-s6-66-mem3-regtest-s3.md).

### Pin read log (chain, part 3), 2026-10-13

[M] Private chain continuation from `5864eb6`. Read the chn2 and aggregate records, the s6-66/s6-66b recipe records, CLAUDE.md, DESIGN-S6 sections 3 and 5.1, corpus/scenarios/README.md, the s6-64 chain record, chain corpus/README, harness/src/scenarios/core.rs and chain.rs, lean/Test/chaincheck.lean, harness/oracle/README.md, tools/finality_check.sh and tools/cite_check.py. [Record](records/20261013-074933-s6-66-chn3-regtest-s3.md). Host helper variable names and the cache share routine were inspected without emitting host values; Lean lock only through the sourced LEAN_LOCK_SH.

[SRC] Read with git show/grep in the pinned bitcoin-sv clone at `6504a3aff65ba97c0f6c80962b033e35ecbfed4b`: src/block_index.h:1225-1274; src/processing_block_index.cpp:9-96; src/validation.cpp:2937-2953,3021-3054,4065-4119,4249-4349,5156-5195,5662-5725,6238-6395,6433-6526; src/rpc/mining.cpp:820-952; src/rpc/blockchain.cpp:2695-2731; src/txmempool.h:1455-1544; src/config.cpp:2440-2465. The parent-tip row's asserted pointer cannot be supplied through RPC [X].

[SRC] Additional pin reads: src/txmempool.cpp:1080-1088,1150-1173; src/rpc/blockchain.cpp:316-440,2617-2673; src/policy/policy.h:55-75,87; src/init.cpp:3093-3095. The removed minrelaytxfee option is not supplied; the live recipe uses the unchanged profile [X].

[SRC] Additional pin reads for invalid retry: src/validation.cpp:4413-4523,5528-5634; src/rpc/blockchain.cpp:93-166. Failure flags are directly exposed, so no failure-field projection is required [X].

[SRC] Additional pin reads for header delivery and precious selection: src/chainparams.cpp:1498-1508; src/version.h:11-53; src/net/net_processing.cpp:1666-1845,3409-3515,4730-4762; src/rpc/net.cpp:282-326; src/rpc/blockchain.cpp:884-1063,2695-2731; src/block_index.h:800-830,1065-1082. Header delivery is restricted to the owned loopback listener, with checksummed wire frames, a ping/pong barrier and a data-flag RPC observation [X].

### Final fold, 2026-10-13T08:33:02Z

[M] Folded mem3, chn3 and the short-leg work; recomputed all primary node-column counts from corpus files. Read the required CLAUDE rules, OWNERS, DESIGN-S6 sections 5.1 and 6, scenario format, aggregate and per-part records, and both supplied lens reports. No fresh source claim was added. Local pin/citation checks used the disclosed closed-path exclusions. [X] Every incoming section 6 line is retained in fold order. [Verification and conflict ledger](records/20261013-082500-fix-66b-verification-s3.md).

[M] 2026-10-13: public read-only historical
mainnet corpus for #65, blocks below height 200000, each deeper than 100000
at the read. Only HTTP GET; nothing broadcast. The block endpoint supplies
header fields and the ordered body identifiers; header hex is serialized
locally [D]. The suggested header subresource returned HTTP 404, logged
below; successful block endpoint reads replace it. Every hash below is
SHA256 of the exact HTTP response body, including the failed read.
[Corpus index](../corpus/INDEX.md), [replay record](records/20261013-141426-s6-65-regtest-s3.md).

| UTC request start [M] | exact public URL [SRC] | HTTP [M] | response sha256 [M] |
|---|---|---:|---|
| 2026-10-13T14:37:20Z | [public read](https://api.whatsonchain.com/v1/bsv/main/block/height/100000) | 200 | `5f5e0c989ee4a152cbf200512f89009643d3b77de53db727b2e603a74b908b34` |
| 2026-10-13T14:37:20Z | [public read](https://api.whatsonchain.com/v1/bsv/main/block/height/100002) | 200 | `31aca434e0ffc15f5bf042cb7df36daa74e1df8af9a63d08c55bda7931c64b5e` |
| 2026-10-13T14:37:54Z | [public read](https://api.whatsonchain.com/v1/bsv/main/block/hash/000000000003ba27aa200b1cecaad478d2b00432346c3f1f3986da1afd33e506/header) | 404 | `b16e15764b8bc06c5c3f9f19bc8b99fa48e7894aa5a6ccdad65da49bbf564793` |
| 2026-10-13T14:38:09Z | [public read](https://api.whatsonchain.com/v1/bsv/main/block/hash/000000000003ba27aa200b1cecaad478d2b00432346c3f1f3986da1afd33e506) | 200 | `5f5e0c989ee4a152cbf200512f89009643d3b77de53db727b2e603a74b908b34` |
| 2026-10-13T14:38:10Z | [public read](https://api.whatsonchain.com/v1/bsv/main/tx/fff2525b8931402dd09222c50775608f75787bd2b87e56995a7bdd30f79702c4/proof/tsc) | 200 | `51263681816497451853f1cabf6636056f5172a6286ca599dad59282d483a4f7` |
| 2026-10-13T14:38:10Z | [public read](https://api.whatsonchain.com/v1/bsv/main/tx/fff2525b8931402dd09222c50775608f75787bd2b87e56995a7bdd30f79702c4/hex) | 200 | `4d97d28b601360f889d5e249c0e3ffd7e7dbdebc2b844ad441e0887b2b291edd` |
| 2026-10-13T14:39:31Z | [public read](https://api.whatsonchain.com/v1/bsv/main/tx/6359f0868171b1d194cbee1af2f16ea598ae8fad666d9b012c8ed2b79a236ec4/proof/tsc) | 200 | `e5bca4ffde992bcce685d222347191dedebb43e8003e1cb58e182e9c4329d445` |
| 2026-10-13T14:39:32Z | [public read](https://api.whatsonchain.com/v1/bsv/main/tx/6359f0868171b1d194cbee1af2f16ea598ae8fad666d9b012c8ed2b79a236ec4/hex) | 200 | `bb9c9b1d6ebf854f259e75bb076a42affe52b12bdf2581a40ac8de8a8b75113e` |
| 2026-10-13T14:39:32Z | [public read](https://api.whatsonchain.com/v1/bsv/main/block/hash/0000000000013b8ab2cd513b0261a14096412195a72a0c4827d229dcc7e0f7af) | 200 | `9c31dae1ec588bcbcfd8027958646399dc065e566161a531fad753440f9e3308` |
| 2026-10-13T14:39:32Z | [public read](https://api.whatsonchain.com/v1/bsv/main/tx/74d681e0e03bafa802c8aa084379aa98d9fcd632ddc2ed9782b586ec87451f20/proof/tsc) | 200 | `ee20284dbfe42c8f47ebdbe06441e157f525bd7c0a3fbf8c15c9e444affbab0e` |
| 2026-10-13T14:39:33Z | [public read](https://api.whatsonchain.com/v1/bsv/main/tx/74d681e0e03bafa802c8aa084379aa98d9fcd632ddc2ed9782b586ec87451f20/hex) | 200 | `7c288ec1f46a3a9efd59583c4f5f46060e0a69b062977e422556a00aeaa29d72` |

[M] The #65 contract was read with gh api before implementation; that
read's exact start time/body hash was not captured. A repeated read-only REST
receipt is logged here: UTC 2026-10-13T14:51:33Z, URL
[issue #65](https://api.github.com/repos/Calgooon/bsv-script-lean/issues/65),
sha256 of the raw gh response bytes `069e6aa21be1ca02e2a76cc5a1f7f301547065980ccc8e5de98e2d48dbd2defa`.

[M] The opening origin fetch and this worktree's own Lake dependency
checkouts have completion markers below. Request-start times and HTTP body
hashes were not captured for git transport; revisions identify these reads.
No dependency cache was copied from a sibling tree.

| UTC completion marker [M] | public git URL | fetched revision [M] |
|---|---|---|
| 2026-10-13T14:36:07Z | [origin fetch](https://github.com/Calhooon/bsv-script-lean.git) (the private repository's origin until 2026-10-23) | `origin/main eb05cf2a7082205a0b43d0cbdda5e6764d20e3ef; a review branch 981cc5fc94effebaa4a05a625ece21d213adfd47` |
| 2026-10-13T14:43:17Z | [Cli](https://github.com/leanprover/lean4-cli) | `e92c9f15fdfacc8536f31cfb3b7ad26c3c8cd204` |
| 2026-10-13T14:43:12Z | [LeanSearchClient](https://github.com/leanprover-community/LeanSearchClient) | `ddf04cf3949fa556442341e87d47f9f6e6074707` |
| 2026-10-13T14:43:14Z | [Qq](https://github.com/leanprover-community/quote4) | `6a489d9af5d0c47e5b259e2e8bcdfc1811b5a259` |
| 2026-10-13T14:43:14Z | [aesop](https://github.com/leanprover-community/aesop) | `355695d523e41d0554926416cba2a2b3544fbbc9` |
| 2026-10-13T14:43:17Z | [batteries](https://github.com/leanprover-community/batteries) | `f2effa3d803fda822b1f97b806c47cf2adfbcbc2` |
| 2026-10-13T14:43:12Z | [importGraph](https://github.com/leanprover-community/import-graph) | `e928b72544873815af278d38681b31c0293588e3` |
| 2026-10-13T14:43:10Z | [mathlib](https://github.com/leanprover-community/mathlib4) | `5ed2965256430c3649e86755f9576b54eca72435` |
| 2026-10-13T14:43:11Z | [plausible](https://github.com/leanprover-community/plausible) | `118aa17ee84656b8bd727fef7c458ee8c833385c` |
| 2026-10-13T14:43:13Z | [proofwidgets](https://github.com/leanprover-community/ProofWidgets4) | `106ff4fafc74ef4ac99d81dbf3ab399118f497a5` |

### Status vocabulary reads, 2026-10-13

[M] Public read-only issue/contents requests and pinned local git show reads. No producer was run. [SRC] Source words describe views, never rules. Hashes are blob ids except the issue-body SHA256 hashes.

| UTC read | URL [SRC] | sha [M] | scope |
|---|---|---|---|
| 2026-10-13T13:57:12Z | https://api.github.com/repos/Calgooon/bsv-script-lean/issues/67 | `f69af6ed9ffa6727f80aa95491e2418658beeddecc9bd704c734439dc0f59d5a` | issue body SHA256 |
| 2026-10-13T13:57:13Z | https://api.github.com/repos/Calgooon/bsv-script-lean/issues/58 | `9496ece0974228ba5da9ee1280575c3a2dead62183440877c0f56b0a96b52b12` | issue body SHA256 |
| 2026-10-13T13:57:14Z | https://github.com/bsv-blockchain/arcade/blob/1ae1208e/models/transaction.go | `23286ca41f7bdf05cf5d4b5d58b490a8fd92774d` | Arcade, blob; lines 87-247,329-333 |
| 2026-10-13T13:57:14Z | https://github.com/bsv-blockchain/ts-stack/blob/edf6e03d/packages/wallet/wallet-toolbox/src/sdk/types.ts | `94e7a8f0ce8ce31987cc3c3b25f8447bac7d7afd` | wallet, blob; lines 19-84 |
| 2026-10-13T13:57:15Z | https://github.com/bitcoin-sv/bitcoin-sv/blob/6504a3aff65ba97c0f6c80962b033e35ecbfed4b/src/consensus/validation.h | `b158eef0b97f0e39a5bea16d55ed3b58095d615e` | local pinned git show; blob |
| 2026-10-13T13:57:15Z | https://github.com/bitcoin-sv/bitcoin-sv/blob/6504a3aff65ba97c0f6c80962b033e35ecbfed4b/src/validation.cpp | `f2f5fa101028f0f73955b06b339c37570c57251a` | local pinned git show; blob |
| 2026-10-13T13:57:15Z | https://github.com/bitcoin-sv/bitcoin-sv/blob/6504a3aff65ba97c0f6c80962b033e35ecbfed4b/src/txn_validator.cpp | `c05c72729a24b9276136a8b00bc6c45abc6cc032` | local pinned git show; blob |
| 2026-10-13T13:57:16Z | https://github.com/bitcoin-sv/bitcoin-sv/blob/6504a3aff65ba97c0f6c80962b033e35ecbfed4b/src/rpc/rawtransaction.cpp | `c1c713dbd71fcc741473f0395209e9e98d119478` | local pinned git show; blob |
| 2026-10-13T13:57:16Z | https://github.com/bsv-blockchain/teranode/blob/4edb60a40c6628ff0ef60231c2628efd7103fde5/services/validator/validator_api/validator_api.proto | `ae5d073b22ca12315b47984db6910e619c317fd2` | local pinned git show; blob |
| 2026-10-13T13:57:16Z | https://github.com/bsv-blockchain/teranode/blob/4edb60a40c6628ff0ef60231c2628efd7103fde5/services/propagation/propagation_api/propagation_api.proto | `35db31440113e54460eb1d0f3afe3c173e502ea8` | local pinned git show; blob |
| 2026-10-13T13:57:16Z | https://github.com/bsv-blockchain/teranode/blob/4edb60a40c6628ff0ef60231c2628efd7103fde5/services/validator/Server.go | `f9f223ad1f0ec8255da3c8c5f790c58ecc471618` | local pinned git show; blob |
| 2026-10-13T13:57:16Z | https://github.com/bsv-blockchain/teranode/blob/4edb60a40c6628ff0ef60231c2628efd7103fde5/services/validator/Validator.go | `05df09b0f1a1eec6370231c79d8164ac762ac753` | local pinned git show; blob |
| 2026-10-13T13:57:16Z | https://github.com/bsv-blockchain/teranode/blob/4edb60a40c6628ff0ef60231c2628efd7103fde5/services/propagation/Server.go | `9e4cd1d5e0b4f43f41ff295add3d887315b6e350` | local pinned git show; blob |
| 2026-10-13T14:16:58Z | https://github.com/bitcoin-sv/bitcoin-sv/blob/6504a3aff65ba97c0f6c80962b033e35ecbfed4b/src/chainparams.cpp | `4dcea2b5b3f1c77b9b16157dc850f68d5e88d5b3` | local pinned git show; loopback/orphan and sweep observables |
| 2026-10-13T14:16:58Z | https://github.com/bitcoin-sv/bitcoin-sv/blob/6504a3aff65ba97c0f6c80962b033e35ecbfed4b/src/net/net.cpp | `aa52706836fc7fe1a61c21e622cb1dda71abe277` | local pinned git show; loopback/orphan and sweep observables |
| 2026-10-13T14:16:58Z | https://github.com/bitcoin-sv/bitcoin-sv/blob/6504a3aff65ba97c0f6c80962b033e35ecbfed4b/src/rpc/blockchain.cpp | `c8eafc6f5bfd05029247d750a67f8de68b266baa` | local pinned git show; loopback/orphan and sweep observables |
| 2026-10-13T14:16:59Z | https://github.com/bitcoin-sv/bitcoin-sv/blob/6504a3aff65ba97c0f6c80962b033e35ecbfed4b/src/rawtxvalidator.cpp | `933e98647fa732323338daeeda65db4e09710905` | local pinned git show; loopback/orphan and sweep observables |

[SRC] 2026-10-13 (#68): public reads of bitcoin-sv at `6504a3aff65ba97c0f6c80962b033e35ecbfed4b` by `gh api repos/bitcoin-sv/bitcoin-sv/contents/<path>?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b` (the `content` field, base64-decoded; the box holds no pinned clone), the blob sha `git hash-object` of the decoded bytes; nothing was vendored or broadcast (rule 10). Lines read for the five theorems, G2, G3 and G4: `src/coins.cpp:555-566`, `src/undo.h:105-113`, `src/processing_block_index.cpp:45-96`, `src/validation.cpp:2480-2495,3322-3332,3368-3374,3436-3444,3652-3668,4413-4450,5228-5260,5768-5782`, `src/consensus/merkle.cpp:280-312`, `src/block_index.h:1225-1240`, `src/chainparams.cpp:33-90,1458-1478,1509-1516`, `src/serialize.h:70-130,240-250,290-345,805-840`, `src/primitives/transaction.h:232-256` and the class and READWRITE lines of `COutPoint`, `CTxIn`, `CTxOut` (`:51-66,89-157,175-194`), `src/primitives/transaction.cpp:79-81`.

| UTC read time | path | lines | blob sha |
|---|---|---|---|
| 2026-10-13T21:06:44Z | [`src/coins.cpp`](https://github.com/bitcoin-sv/bitcoin-sv/blob/6504a3aff65ba97c0f6c80962b033e35ecbfed4b/src/coins.cpp) | 568 | `e348fafb311cb7dc3e0bc94789e981363d509362` |
| 2026-10-13T21:06:44Z | [`src/undo.h`](https://github.com/bitcoin-sv/bitcoin-sv/blob/6504a3aff65ba97c0f6c80962b033e35ecbfed4b/src/undo.h) | 143 | `cca2d4beb38046c05a097eceb85435498ab29cf4` |
| 2026-10-13T21:06:45Z | [`src/processing_block_index.cpp`](https://github.com/bitcoin-sv/bitcoin-sv/blob/6504a3aff65ba97c0f6c80962b033e35ecbfed4b/src/processing_block_index.cpp) | 96 | `87071187334e701a6de67fdd17e69ab6a221d846` |
| 2026-10-13T21:06:45Z | [`src/validation.cpp`](https://github.com/bitcoin-sv/bitcoin-sv/blob/6504a3aff65ba97c0f6c80962b033e35ecbfed4b/src/validation.cpp) | 7746 | `f2f5fa101028f0f73955b06b339c37570c57251a` |
| 2026-10-13T21:06:45Z | [`src/consensus/merkle.cpp`](https://github.com/bitcoin-sv/bitcoin-sv/blob/6504a3aff65ba97c0f6c80962b033e35ecbfed4b/src/consensus/merkle.cpp) | 328 | `ab89e2f1b6f2bc1a4afd18c2e6cb7319b4cae4a9` |
| 2026-10-13T21:06:59Z | [`src/block_index.h`](https://github.com/bitcoin-sv/bitcoin-sv/blob/6504a3aff65ba97c0f6c80962b033e35ecbfed4b/src/block_index.h) | 1277 | `543097e796ad0fcc9f9b104f96030129e28dc569` |
| 2026-10-13T21:43:51Z | [`src/chainparams.cpp`](https://github.com/bitcoin-sv/bitcoin-sv/blob/6504a3aff65ba97c0f6c80962b033e35ecbfed4b/src/chainparams.cpp) | 1619 | `4dcea2b5b3f1c77b9b16157dc850f68d5e88d5b3` |
| 2026-10-13T21:51:12Z | [`src/serialize.h`](https://github.com/bitcoin-sv/bitcoin-sv/blob/6504a3aff65ba97c0f6c80962b033e35ecbfed4b/src/serialize.h) | 1188 | `7706a6cf2e3a0843d829e2fa5b74ebc8db7223af` |
| 2026-10-13T21:51:13Z | [`src/primitives/transaction.h`](https://github.com/bitcoin-sv/bitcoin-sv/blob/6504a3aff65ba97c0f6c80962b033e35ecbfed4b/src/primitives/transaction.h) | 404 | `38516745ff8e95eceda775ea1b40074509d1eb66` |
| 2026-10-13T21:51:13Z | [`src/primitives/transaction.cpp`](https://github.com/bitcoin-sv/bitcoin-sv/blob/6504a3aff65ba97c0f6c80962b033e35ecbfed4b/src/primitives/transaction.cpp) | 173 | `6a93f3615d36b9f64a4f0b5089c40bc3a4df0ff3` |
| 2026-10-13T21:51:13Z | [`src/primitives/block.h`](https://github.com/bitcoin-sv/bitcoin-sv/blob/6504a3aff65ba97c0f6c80962b033e35ecbfed4b/src/primitives/block.h) | 182 | `11c3b7c5ae39953c65a0329901c41b73dd4b0344` |

## Downstream consumers of the witnesses (2026-09-23)

The corpus witnesses of #15 (bsv-rs 0.3.24 enforced relay-only restrictions at transaction version ≤ 1; no NULLFAIL; NULLDUMMY regardless of version; fixed in 0.3.26 and, with the five residual rules, 0.3.27, the spec's pin since 2026-09-23) are regression tests for the crate's other users, each at its own engine pin (the fix upstream: `Calhooon/bsv-rs#10`). A witness added here is a test they inherit.

**2026-10-06 (#57):** the reference pin moved from tag `v1.2.2`, commit `879fc8b42168dd0e608dafd51b39c6dabad37d4d`, version string `v1.2.2.0-g879fc8b42-dev`, binary `<the maintainers' build host>:targets/sv-v1.2.2/bin/bitcoind`, clone `<the maintainers' build host>:bitcoin-sv`, to tag `v1.2.3`, commit `6504a3aff65ba97c0f6c80962b033e35ecbfed4b`, version string `v1.2.3.0-g6504a3aff-dev`, binary `<the maintainers' build host>:targets/sv-v1.2.3/bin/bitcoind`, with the same clone. [Build and binary identity](records/20261006-144350-node-v1.2.3-build.md). The previous pin's reading and its measurements are withheld from the public edition at the maintainers' request (group `d8-node-team-discretion`). GoBDK's linked archive remains at v1.2.2, hence its distinct `gobdk.reference_commit` pin. Public reads: issue #57's REST body at about 14:39 UTC, tag fetch from `https://github.com/bitcoin-sv/bitcoin-sv.git` at 14:41 to 14:42 UTC; source citations read with `git show 6504a3aff65ba97c0f6c80962b033e35ecbfed4b:<path>`. The base `f9ccae6` carries recon entries 1/2, not entry 3. New recordings and citation recuts are recorded by this change; the Lean reader's move is the sibling half of #57.


[M] #60 lens correction (2026-10-12): 5 pinned public source
reads by `gh api ... --jq .content | base64 -d`, each UTC request start below;
the decoded bytes were hashed locally, and the validation and block-index blobs match DESIGN-S6 §9. The caller, signed
parameter, full-width block cutoff and median return type were checked in
these bytes, along with the chain parameter citations newly rendered in `spec/`; the [record](records/20261012-130619-s6-60-finality.md) carries
the witness and the validation results.

| UTC request start | URL | [M] decoded blob / lines |
|---|---|---|
| `2026-10-12T13:41:33Z` | [public source read](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/validation.cpp?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | `f2f5fa101028f0f73955b06b339c37570c57251a`; 7746 lines |
| `2026-10-12T13:41:34Z` | [public source read](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/block_index.h?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | `543097e796ad0fcc9f9b104f96030129e28dc569`; 1277 lines |
| `2026-10-12T13:49:46Z` | [public source read](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/chainparams.cpp?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | `4dcea2b5b3f1c77b9b16157dc850f68d5e88d5b3`; 1619 lines |
| `2026-10-12T13:49:46Z` | [public source read](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/consensus/params.h?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | `9da13771c872d82bce60205bedbf40e8f0e59d53`; 55 lines |
| `2026-10-12T13:49:46Z` | [public source read](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/chainparams.h?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | `4fba65bd7ebcac36f38b8e607a9dbede4d55c725`; 163 lines |

[M] The opening origin fetch and Lake's dependency checkout reads are also
logged below: 10 completion markers from this worktree's `FETCH_HEAD` and
the checked-out dependency `.git/HEAD` modification times, respectively.
Individual request-start times for these reads were not captured. Together
with the 5 timed reference API reads above, this logs 15 read operations.

| [M] UTC completion marker | public URL | operation / revision |
|---|---|---|
| `2026-10-12T13:40:10.905416Z` | [origin fetch](https://github.com/Calgooon/bsv-script-lean.git) | `git fetch origin`; `FETCH_HEAD` marker |
| `2026-10-12T13:44:19.303846Z` | [mathlib](https://github.com/leanprover-community/mathlib4) | Lake checkout `5ed2965256430c3649e86755f9576b54eca72435`; `.git/HEAD` marker |
| `2026-10-12T13:44:22.003235Z` | [plausible](https://github.com/leanprover-community/plausible) | Lake checkout `118aa17ee84656b8bd727fef7c458ee8c833385c`; `.git/HEAD` marker |
| `2026-10-12T13:44:22.461194Z` | [LeanSearchClient](https://github.com/leanprover-community/LeanSearchClient) | Lake checkout `ddf04cf3949fa556442341e87d47f9f6e6074707`; `.git/HEAD` marker |
| `2026-10-12T13:44:22.984458Z` | [importGraph](https://github.com/leanprover-community/import-graph) | Lake checkout `e928b72544873815af278d38681b31c0293588e3`; `.git/HEAD` marker |
| `2026-10-12T13:44:23.639365Z` | [proofwidgets](https://github.com/leanprover-community/ProofWidgets4) | Lake checkout `106ff4fafc74ef4ac99d81dbf3ab399118f497a5`; `.git/HEAD` marker |
| `2026-10-12T13:44:24.676842Z` | [aesop](https://github.com/leanprover-community/aesop) | Lake checkout `355695d523e41d0554926416cba2a2b3544fbbc9`; `.git/HEAD` marker |
| `2026-10-12T13:44:25.153617Z` | [Qq](https://github.com/leanprover-community/quote4) | Lake checkout `6a489d9af5d0c47e5b259e2e8bcdfc1811b5a259`; `.git/HEAD` marker |
| `2026-10-12T13:44:32.366789Z` | [batteries](https://github.com/leanprover-community/batteries) | Lake checkout `f2effa3d803fda822b1f97b806c47cf2adfbcbc2`; `.git/HEAD` marker |
| `2026-10-12T13:44:32.833000Z` | [Cli](https://github.com/leanprover/lean4-cli) | Lake checkout `e92c9f15fdfacc8536f31cfb3b7ad26c3c8cd204`; `.git/HEAD` marker |

[M] 2026-10-13: public pinned source reads via
GitHub contents REST (local bitcoin-sv clone absent). No public transaction
or block was read, and nothing was broadcast. Issue bodies #65 and #75 were
read by gh api, read-only. BRCs branch HEAD was resolved by commits/HEAD
before the pinned BRC-74 contents request. The hashes below identify content;
the [M] line counts were counted from decoded bytes. [SRC] bitcoin-sv pin
6504a3aff65ba97c0f6c80962b033e35ecbfed4b.

| UTC read [M] | public source [SRC]/[LIT] | lines [M] | blob sha [M] |
|---|---|---:|---|
| 2026-10-13T13:54:07Z | [src/consensus/merkle.cpp](https://github.com/bitcoin-sv/bitcoin-sv/blob/6504a3aff65ba97c0f6c80962b033e35ecbfed4b/src/consensus/merkle.cpp) | 328 | `ab89e2f1b6f2bc1a4afd18c2e6cb7319b4cae4a9` |
| 2026-10-13T13:54:07Z | [src/merkletree.cpp](https://github.com/bitcoin-sv/bitcoin-sv/blob/6504a3aff65ba97c0f6c80962b033e35ecbfed4b/src/merkletree.cpp) | 358 | `e1b2d79946804829117a3f6fcd25844f5ee223f2` |
| 2026-10-13T13:54:07Z | [src/rpc/rawtransaction.cpp](https://github.com/bitcoin-sv/bitcoin-sv/blob/6504a3aff65ba97c0f6c80962b033e35ecbfed4b/src/rpc/rawtransaction.cpp) | 2637 | `c1c713dbd71fcc741473f0395209e9e98d119478` |
| 2026-10-13T13:54:09Z | [BRCs transactions/0074.md at 793f18685803924e3c6433fa226ee0b5bac0dad0](https://github.com/bsv-blockchain/BRCs/blob/793f18685803924e3c6433fa226ee0b5bac0dad0/transactions/0074.md) | 394 | `2f0ed5eaabefba1b2626204f1e333b46ffca40bd` |
| 2026-10-13T14:13:49Z | [src/rpc/blockchain.cpp](https://github.com/bitcoin-sv/bitcoin-sv/blob/6504a3aff65ba97c0f6c80962b033e35ecbfed4b/src/rpc/blockchain.cpp) | 3839 | `c8eafc6f5bfd05029247d750a67f8de68b266baa` |

[M] 2026-10-13: the [fresh regtest record](records/20261013-141426-s6-65-regtest-s3.md)
measures commit `117ae14a73cab880d3ca4839d76659749ba81ac3`; [M] 5 scenario steps agree [X].
The [intake replay](records/20261013-141521-s6-65-intake-regtest-s3.md) measures the same
commit; [M] 10 steps agree [X]. Synthetic loopback instances only, no public
block/transaction reads and no broadcasts. The failed missing-handler attempt,
lock/load ledger, skipped checks and theorem qualifications are in the record.
### Source-step rereads, 2026-10-13

[D] Public read-only contents API and pinned local git-show reads for lens #67.
The new TransactionStatus obstruction uses explicit failed-row recovery, rather
than uncited signing/proof claims. UTC stamps below came from date -u after each read.

| pinned source [SRC] | blob SHA256 [M] | read UTC [M] |
|---|---|---|
| [models/transaction.go at 1ae1208e](https://github.com/bsv-blockchain/arcade/blob/1ae1208e/models/transaction.go) | `a3169200f7b7ce35ff5e5601e50fdb47ec394953a69ab053eb38aa72ddb23bfc` | `2026-10-13T15:06:20Z` |
| [packages/wallet/wallet-toolbox/src/sdk/types.ts at edf6e03d](https://github.com/bsv-blockchain/ts-stack/blob/edf6e03d/packages/wallet/wallet-toolbox/src/sdk/types.ts) | `a7aa5d0b3c1d8e64d66e19de8d6082ed197ff9cd078a8efd6c94d5cab724d6b4` | `2026-10-13T15:06:20Z` |
| [packages/wallet/wallet-toolbox/src/storage/methods/processAction.ts at edf6e03d](https://github.com/bsv-blockchain/ts-stack/blob/edf6e03d/packages/wallet/wallet-toolbox/src/storage/methods/processAction.ts) | `f8587e1f45f4a04a83d12cc30e5b6d8fa0aebaf29ef8c00beaad1de0d01c9737` | `2026-10-13T15:06:20Z` |
| [packages/wallet/wallet-toolbox/src/monitor/tasks/TaskFailAbandoned.ts at edf6e03d](https://github.com/bsv-blockchain/ts-stack/blob/edf6e03d/packages/wallet/wallet-toolbox/src/monitor/tasks/TaskFailAbandoned.ts) | `a3d4d13816f16eb3ab5066c39484a7347f61085c1b92e7a1c36a32b27185080b` | `2026-10-13T15:06:20Z` |
| [packages/wallet/wallet-toolbox/src/storage/methods/ListActionsSpecOp.ts at edf6e03d](https://github.com/bsv-blockchain/ts-stack/blob/edf6e03d/packages/wallet/wallet-toolbox/src/storage/methods/ListActionsSpecOp.ts) | `2d0c4952401d20edd7cd111aef195d74ba2d42dba880bd2e3b7d4cce26823cbe` | `2026-10-13T15:06:20Z` |
| [services/validator/http_options_guard.go at v0.16.0](https://github.com/bsv-blockchain/teranode/blob/4edb60a40c6628ff0ef60231c2628efd7103fde5/services/validator/http_options_guard.go) | `1f94214e167b300d35cf465ee1bcaf8e652acacdaccf5fa8b41d3e7cd4c261b7` | `2026-10-13T15:06:22Z` |
| [errors/Error_types.go at v0.16.0](https://github.com/bsv-blockchain/teranode/blob/4edb60a40c6628ff0ef60231c2628efd7103fde5/errors/Error_types.go) | `b44ce6d0b6e0bd69d3885dd79ad99a77649ff0a492110dcdfc60df909a32e876` | `2026-10-13T15:06:22Z` |
| [services/validator/Server.go at v0.16.0](https://github.com/bsv-blockchain/teranode/blob/4edb60a40c6628ff0ef60231c2628efd7103fde5/services/validator/Server.go) | `3404f1b135068a947ae343e47e4273bd6da7f4da3b623cfce2a3e132246058c9` | `2026-10-13T15:09:10Z` |
| [services/validator/validator_api/validator_api.proto at v0.16.0](https://github.com/bsv-blockchain/teranode/blob/4edb60a40c6628ff0ef60231c2628efd7103fde5/services/validator/validator_api/validator_api.proto) | `305f89250d4a7e8069e2ba06d6349c40f1251f8cd7bca804b924e6c9793ed929` | `2026-10-13T15:09:10Z` |
| [services/propagation/Server.go at v0.16.0](https://github.com/bsv-blockchain/teranode/blob/4edb60a40c6628ff0ef60231c2628efd7103fde5/services/propagation/Server.go) | `8651c692036278354ba681ce371ca997e7976ce0512cdcdd7fda8abc659a045d` | `2026-10-13T15:09:10Z` |
| [services/validator/Validator.go at v0.16.0](https://github.com/bsv-blockchain/teranode/blob/4edb60a40c6628ff0ef60231c2628efd7103fde5/services/validator/Validator.go) | `e64de4298aaeca2a13f845d4d5dae01e069928bfb9245c4fe18f7322ef4f1e04` | `2026-10-13T15:30:12Z` |
| [services/validator/ScriptVerifierGoBDK.go at v0.16.0](https://github.com/bsv-blockchain/teranode/blob/4edb60a40c6628ff0ef60231c2628efd7103fde5/services/validator/ScriptVerifierGoBDK.go) | `1179c91389bc5291a757a7e345fff389aefbc70707801d86fadf1008f2404a72` | `2026-10-13T15:30:12Z` |
| [src/validation.cpp:526-527 at 6504a3af](https://github.com/bitcoin-sv/bitcoin-sv/blob/6504a3aff65ba97c0f6c80962b033e35ecbfed4b/src/validation.cpp#L526-L527) | `5597b16b84ecc0ce670fc2d0fffcbac8d1602cd28fd023534df0dc06d3b79be5` | `2026-10-13T15:46:42Z` |

### Pinned semantic cell read, 2026-10-13

[M] 2026-10-13T17:01:53Z (date -u after the public contents request):
[Arcade models/transaction.go at 1ae1208e](https://github.com/bsv-blockchain/arcade/blob/1ae1208e/models/transaction.go)
read in full, read-only. Blob `23286ca41f7bdf05cf5d4b5d58b490a8fd92774d`,
SHA256 `a3169200f7b7ce35ff5e5601e50fdb47ec394953a69ab053eb38aa72ddb23bfc`.
[SRC] REJECTED :104-105, MINED :110-111; stored transition restrictions
:227-237 and reorg markers :326-331 are separately qualified. [D] These support
stale-body MINED and narrow completed-receipt REJECTED partial semantic views.
No external producer was run and nothing was broadcast.
### [SRC] 2026-10-13: the peer executable instrument

| date / label | instrument | source / use |
|---|---|---|
| [SRC] 2026-10-13 | bitcoin-sv reference test framework, executable P2P instrument | `6504a3aff65ba97c0f6c80962b033e35ecbfed4b`, `test/functional/test_framework/mininode.py:48,2118-2690`, `transport.py`, `util.py:237-263,534-553` and `comptool.py:93-143`; imported directly from the pinned clone, never copied or vendored. Version 70016 and regtest magic are the reference's. |

[M] 2026-10-13: local pinned clone HEAD verified by git rev-parse. Framework
working files checked against the pin. Reads: orphan delivery in
`bsv-accept_max_sized_orphan.py`, body omission in `p2p-acceptblock.py`,
`bsv-soft-rejected-blocks.py`, and the `bsv-p2p-*.py` family. Node-side reads
used git show at the pin: `src/net/net.cpp:3558-3565`,
`src/net/net_processing.cpp:930-965,1173-1235,2454-2555,3347-3460,4050-4115`,
`src/orphan_txns.cpp:35-80,175-241`, `src/txn_validator.cpp:145-180,359-538,695-724`,
`src/rpc/rawtransaction.cpp:1580-1595`, `src/validation.cpp:1868-2055,4036-4053,6296-6335`,
`src/init.cpp:1429-1442,2432-2443,3688-3735`, `src/config.cpp:2520-2552`,
`src/configscriptpolicy.cpp:415-440`, `src/txmempool.cpp:1345-1363` and
`src/rpc/blockchain.cpp:2634-2693,3769-3786`. These are local source reads;
no source was fetched over HTTP. The harness README indexes the driver.

[SRC] 2026-10-13: additional pinned reads of
`src/config.cpp:2440-2475` (the resident-pool launch minimum and zero-resident
alternative), `src/txmempool.cpp:2777-2799` (a nonempty eviction survivor is
needed for a positive rolling fee), `src/rpc/blockchain.cpp:378-410,884-1038,3649-3688`
(verbose fee delta, header and activity observations), and
`src/txn_validator.cpp:101-112,775-801` (queue-count scope and the orphan-aware
completion wait). All are git show reads at `6504a3aff65ba97c0f6c80962b033e35ecbfed4b`.

[SRC] 2026-10-13: re-read `src/txmempool.cpp:947-1023`,
`src/time_locked_mempool.cpp:611-641`, and `src/validation.cpp:4036-4053,4073,4404`
at `6504a3aff65ba97c0f6c80962b033e35ecbfed4b`. The held pool is separate from
accepted-pool reorg cleanup; its periodic finality check depends on lock
height/time. This supplies a normal operator rollback setup for a retained
held entry at the predecessor of the 9999 era-clear row.


[M] 2026-10-13: the [20-row peer receipt](records/20261013-152446-s6-peer-66-regtest-s3.md) records the pinned executable framework, per-row steps, tokens and walls. Its run uses a fresh instance per row; no framework code is copied.

[SRC] 2026-10-13: the queued-orphan observation uses
`src/txn_validator.cpp:24-28,101-112,155-177,478-529` at
`6504a3aff65ba97c0f6c80962b033e35ecbfed4b`: a named five-second asynchronous
period and a completed synchronous invalid-transaction call fence the parent's
main-mutex scheduling cycle before reading the sole pending child. This is
an intermediate-state observation, with no configurable literal batch-size
claim. [SRC] The body-absence probe follows decoded getblock in
`test/functional/p2p-acceptblock.py:155-167` at the same pin.

[SRC] 2026-10-13: local git-show reads at bitcoin-sv `6504a3aff65ba97c0f6c80962b033e35ecbfed4b`: `src/orphan_txns.cpp:33-81,167-275`, `src/orphan_txns.h:109-118`, `src/validation.cpp:1283-1296,1900-1920`, and `src/policy/policy.h:64-70`. The explicit orphan eviction choice follows the salted unordered map selection at `orphan_txns.cpp:227-243`; no source was vendored and nothing was broadcast.

[M] 2026-10-13: [fresh loopback record](records/20261013-181932-s6-fix-peer-regtest-s3.md), framework `6504a3aff65ba97c0f6c80962b033e35ecbfed4b`; actual imported origins/blob bytes certified, no vendoring or broadcasts. [SRC] Additional local pin reads: src/orphan_txns.cpp:401-404; src/validation.cpp:834-892,938-945,1778-1820; src/validation.h:670-699; src/txn_validator.h:155-158; src/rpc/blockchain.cpp:3769-3785.

### Era reads, 2026-10-13

[M] Public read-only GitHub reads at bitcoin-sv `6504a3aff65ba97c0f6c80962b033e35ecbfed4b`
for #69 (the box has no clone). UTC stamps from `date -u` after each request; blob
SHAs are the contents API's git blob identifiers. No transaction, block or node
material was fetched and nothing was broadcast (rule 10).

| read UTC [M] | pinned source [SRC] | blob [M]; lines |
|---|---|---|
| `2026-10-13T23:26:59Z` | [src/pow.cpp](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/pow.cpp?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | `989f483079930d539677ef30695f194ccc76310b`; 297 lines |
| `2026-10-13T23:26:59Z` | [src/chainparams.cpp](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/chainparams.cpp?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | `4dcea2b5b3f1c77b9b16157dc850f68d5e88d5b3`; 1619 lines |
| `2026-10-13T23:27:00Z` | [src/validation.cpp](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/validation.cpp?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | `f2f5fa101028f0f73955b06b339c37570c57251a`; 7746 lines |
| `2026-10-13T23:27:00Z` | [src/consensus/consensus.h](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/consensus/consensus.h?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | `dd1614388a060ec674e7aea13d001cf9171e66ed`; 94 lines |
| `2026-10-13T23:27:01Z` | [src/consensus/params.h](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/consensus/params.h?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | `9da13771c872d82bce60205bedbf40e8f0e59d53`; 55 lines |
| `2026-10-13T23:27:01Z` | [src/verify_script_flags.cpp](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/verify_script_flags.cpp?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | `29674d406ad9eb70019bebbbf608f72c9d0b4f05`; 82 lines |
| `2026-10-13T23:27:02Z` | [src/block_index.h](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/block_index.h?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | `543097e796ad0fcc9f9b104f96030129e28dc569`; 1277 lines |
| `2026-10-13T23:28:52Z` | [source tarball](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/tarball/6504a3aff65ba97c0f6c80962b033e35ecbfed4b), read for the repository-wide searches below | archive SHA256 `6efc2c68c5982569490bb5f748200f922207973572780b9e41fdfa621e79d108`; 6863990 bytes |

[SRC] Lines read: `src/pow.cpp:15–297` in full; `src/chainparams.cpp:1033–1190,1195–1304,1329–1456,1456–1559`
(heights, proof-of-work flags, checkpoint tables, standardness, minimum work, assumevalid,
BIP30 permissions); `src/validation.cpp:2968–2984,3021–3120,3455–3475,5786–5830,5933–5976,6018–6107`;
`src/consensus/consensus.h:30–31,84–91`; `src/consensus/params.h:14–55`;
`src/verify_script_flags.cpp:28–82`; `src/block_index.h:326–340,856–857`. From the tarball: `src/config.cpp:225–250,2045–2070`,
`src/init.cpp:1295–1300,2350–2376,2510–2525`, `src/uint256.h:35`, `src/block_index.cpp:75–90`, `src/chainparams.h:86–118`, and the searches
for `LEGACY_MAX_BLOCK_SIZE`, `uahfHeight`, `IsUAHFenabled` and `SetDisableBIP30Checks`
over `src/` (no block check reads `uahfHeight`; the constant's one non-test reader is
the setter at `src/config.cpp:236`). The tarball stayed under `/tmp`; nothing from it
was copied into this repository.

[SRC] 2026-10-13 (#75): public reads of bitcoin-sv at `6504a3aff65ba97c0f6c80962b033e35ecbfed4b` by `gh api repos/bitcoin-sv/bitcoin-sv/contents/<path>?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b` (the `content` field, base64-decoded; the box holds no pinned clone), the blob sha `git hash-object` of the decoded bytes, equal to the API's `sha`; nothing was vendored or broadcast (rule 10). Lines read for the proof surface: `src/rpc/rawtransaction.cpp:2242-2339` (`getmerkleproof`), `:2342-2525` (`getmerkleproof2`, its handler; the issue's `src/rpc/client_utils.cpp:137` is the CLI's conversion row for `includeFullTx`), `:2527-2612` (`verifymerkleproof`), `:2620-2637` (the command table), `src/rpc/client_utils.cpp:120-160`, `src/merkletree.cpp:150-358` (the tree build, `CalculateMissingParentNode`, `GetMerkleRoot`, both `GetMerkleProof` overloads at `:275-291` and `:294-346`), `src/merkletree.h:177-187,234-239` (`MerkleProof`), `src/consensus/merkle.cpp:284-310`. [LIT] The TSC "Merkle Proof Standardised Format" document was read once by HTTP GET (a public read, rule 10): https://tsc.bsvblockchain.org/standards/merkle-proof-standardised-format/ at `2026-10-13T23:44:03Z`, HTTP 200, [M] 190341 bytes, sha256 `438f2ffb08a225769761934c40479ea7aa0e893e74eae780d7619b5c58c916e7`; the URL the source comments at `src/rpc/rawtransaction.cpp:2345` (tsc.bitcoinassociation.net) answered HTTP 403 at `2026-10-13T23:44:04Z` ([M] 5556 bytes, sha256 `4f8d963e82b60d7ccbbc42fa9d3ecda23702f02ae0301f1c89b94c44a1b1d770`, an error page, not the standard). [LIT] 2026-10-14, retained TSC read locators for section 6: Retained successful-read bytes: `<the maintainers' build host>:targets/spec-oracle-scenarios/s6-75-20261014-015319/tsc-261431.html`, [M] 190341 bytes, SHA256 `438f2ffb08a225769761934c40479ea7aa0e893e74eae780d7619b5c58c916e7`; retained HTTP 403 response: `<the maintainers' build host>:targets/spec-oracle-scenarios/s6-75-20261014-015319/tsc-9dd93f.html`, [M] 5556 bytes, SHA256 `4f8d963e82b60d7ccbbc42fa9d3ecda23702f02ae0301f1c89b94c44a1b1d770`. Both copied from the saved read files and rehashed at `2026-10-14T02:56:41Z`; the URL and read UTC above identify the original reads. The earlier API-read rows remain the record of those reads. The document's binary example (232 bytes) is the executed [LIT] vector of `lean/Test/ChainCheck.lean` `tscCases`. Issue #75 and the close comments of #65 and #68 were read by `gh api`, read-only.

| UTC read time (#75, the proof surface) | path | lines | blob sha |
|---|---|---|---|
| 2026-10-13T23:42:34Z | [`src/rpc/rawtransaction.cpp`](https://github.com/bitcoin-sv/bitcoin-sv/blob/6504a3aff65ba97c0f6c80962b033e35ecbfed4b/src/rpc/rawtransaction.cpp) | 2637 | `c1c713dbd71fcc741473f0395209e9e98d119478` |
| 2026-10-13T23:42:34Z | [`src/rpc/client_utils.cpp`](https://github.com/bitcoin-sv/bitcoin-sv/blob/6504a3aff65ba97c0f6c80962b033e35ecbfed4b/src/rpc/client_utils.cpp) | 342 | `246fa576215c38de1343370091ee61e0fbebb6c7` |
| 2026-10-13T23:42:35Z | [`src/merkletree.cpp`](https://github.com/bitcoin-sv/bitcoin-sv/blob/6504a3aff65ba97c0f6c80962b033e35ecbfed4b/src/merkletree.cpp) | 358 | `e1b2d79946804829117a3f6fcd25844f5ee223f2` |
| 2026-10-13T23:42:35Z | [`src/consensus/merkle.cpp`](https://github.com/bitcoin-sv/bitcoin-sv/blob/6504a3aff65ba97c0f6c80962b033e35ecbfed4b/src/consensus/merkle.cpp) | 328 | `ab89e2f1b6f2bc1a4afd18c2e6cb7319b4cae4a9` |
| 2026-10-13T23:42:36Z | [`src/merkletree.h`](https://github.com/bitcoin-sv/bitcoin-sv/blob/6504a3aff65ba97c0f6c80962b033e35ecbfed4b/src/merkletree.h) | 261 | `b509ce7d92867f1da5cc16d2e05b8ec6ea70c5f0` |

[SRC] 2026-10-14 (#75, the continuation of the 2026-10-13 reads): the same lines re-read (2026-10-14 00:49Z to 01:55Z by the local clock; this note written at `2026-10-14T02:03:56Z`) from the pinned clone on the box by `git -C <the maintainers' build host>:bitcoin-sv show 6504a3aff65ba97c0f6c80962b033e35ecbfed4b:<path>` (HEAD `6504a3af`, porcelain clean; a local read of the pinned blob, no row owed): `src/rpc/rawtransaction.cpp:2242-2340,2342-2530,2530-2637`, `src/merkletree.cpp:270-350`, `src/consensus/merkle.cpp:284-312`, `src/rpc/client_utils.cpp:130-142`, `src/primitives/transaction.cpp:79-81`, and `src/rpc/protocol.h:28-46` (the error codes: `RPC_INVALID_PARAMS = -32602` at :28, `RPC_INVALID_ADDRESS_OR_KEY = -5` at :42, `RPC_INVALID_PARAMETER = -8` at :46). Every `:line` citation of the two proof modules was checked against the clone's numbered text. The TSC document was not fetched again: the saved bytes of the 23:44:03Z read hash to the recorded sha256 (`shasum -a 256` of the saved file, [M] 190341 bytes). The record of the proof-surface run: [20261014-015319-s6-75-regtest-s3](records/20261014-015319-s6-75-regtest-s3.md). Nothing was vendored or broadcast (rule 10).

### Pin read log, 2026-10-13 (#73: validation depth and safe mode)

[M] 2026-10-13T23:51:48Z to 23:59:48Z, on the box (no local clone of the reference there). Every read is the GitHub contents API at the bitcoin-sv pin `6504a3aff65ba97c0f6c80962b033e35ecbfed4b`, public and read-only (rule 10): each file by two calls of the same URL, one for the blob sha (`--jq .sha`) and one for the bytes (`Accept: application/vnd.github.raw+json`), the bytes re-hashed locally with `git hash-object` and equal to the API's blob sha on every row. [M] 43 rows: 37 files, 2 directory listings, 1 recursive tree listing (used to enumerate the RPC registrars' files), 3 guessed paths absent at the pin. Nothing was vendored; the copies live outside the repository. The lines cited by `lean/BsvChain/Depth.lean`, `lean/BsvChain/Properties/Depth.lean`, `harness/src/scenarios/depth.rs`, `corpus/chain/depth/` and PARAMETERS §8.4 were read in these copies.

| read at (UTC) | path at the pin | result |
|---|---|---|
| `2026-10-13T23:51:48Z` | [src/validation.cpp](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/validation.cpp?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | exit 0; [M] 7746 lines; blob `f2f5fa101028f0f73955b06b339c37570c57251a` |
| `2026-10-13T23:51:50Z` | [src/validation.h](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/validation.h?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | exit 0; [M] 1190 lines; blob `32c4acd90ece216a23b8b201ced0d1a983f2d3f4` |
| `2026-10-13T23:51:51Z` | [src/chainparams.cpp](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/chainparams.cpp?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | exit 0; [M] 1619 lines; blob `4dcea2b5b3f1c77b9b16157dc850f68d5e88d5b3` |
| `2026-10-13T23:51:51Z` | [src/checkpoints.cpp](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/checkpoints.cpp?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | exit 0; [M] 38 lines; blob `a493d4ce0880266067894e276052859cc7e4b346` |
| `2026-10-13T23:51:52Z` | [src/init.cpp](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/init.cpp?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | exit 0; [M] 4177 lines; blob `9847ebd55b62f959e2b28d664120472c896c6125` |
| `2026-10-13T23:51:53Z` | [src/safe_mode.cpp](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/safe_mode.cpp?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | exit 0; [M] 588 lines; blob `1aa6b7a37d498e50b4f3698df388c95dbe2d93fd` |
| `2026-10-13T23:51:54Z` | [src/safe_mode.h](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/safe_mode.h?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | exit 0; [M] 165 lines; blob `c372867a11e765edfe49e8f93cf3889f79820056` |
| `2026-10-13T23:51:54Z` | [src/rpc/safe_mode.cpp](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/rpc/safe_mode.cpp?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | exit 0; [M] 211 lines; blob `8206167e13edd343a7c9e0223ba63a182de94730` |
| `2026-10-13T23:51:55Z` | [src/config.cpp](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/config.cpp?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | exit 0; [M] 2710 lines; blob `c81ff74c06b3430e8a01b5af381508a06f476811` |
| `2026-10-13T23:51:56Z` | [src/config.h](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/config.h?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | exit 0; [M] 1000 lines; blob `46a5504f4e87e2dc7a0cf5adb9dc1dc4f4514d8d` |
| `2026-10-13T23:51:56Z` | [src/pow.cpp](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/pow.cpp?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | exit 0; [M] 297 lines; blob `989f483079930d539677ef30695f194ccc76310b` |
| `2026-10-13T23:51:57Z` | [src/rpc/server.cpp](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/rpc/server.cpp?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | exit 0; [M] 649 lines; blob `96c66d962e01fb3285ae5db243ad614e9d146443` |
| `2026-10-13T23:51:58Z` | [src/rpc/protocol.h](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/rpc/protocol.h?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | exit 0; [M] 124 lines; blob `fffe613ad38cf5803d4cd6f5f285620f63bd74d9` |
| `2026-10-13T23:51:58Z` | [src/block_index.h](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/block_index.h?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | exit 0; [M] 1277 lines; blob `543097e796ad0fcc9f9b104f96030129e28dc569` |
| `2026-10-13T23:52:00Z` | [src/consensus/params.h](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/consensus/params.h?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | exit 0; [M] 55 lines; blob `9da13771c872d82bce60205bedbf40e8f0e59d53` |
| `2026-10-13T23:52:17Z` | [src/ (directory listing)](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | exit 0; [M] 270 entries |
| `2026-10-13T23:52:18Z` | [src/block_index.cpp](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/block_index.cpp?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | exit 0; [M] 466 lines; blob `25fb1bde9384a6b3ebe5ddc7a59ef35b70478dd0` |
| `2026-10-13T23:52:19Z` | [src/block_index_store.h](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/block_index_store.h?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | exit 0; [M] 213 lines; blob `eb2e5a5503b7134733ee47a1a18fb7587ae4d550` |
| `2026-10-13T23:52:20Z` | [src/block_index_store.cpp](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/block_index_store.cpp?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | 404: no such path at the pin (a guessed name; nothing read) |
| `2026-10-13T23:52:20Z` | [src/rpc/blockchain.cpp](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/rpc/blockchain.cpp?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | exit 0; [M] 3839 lines; blob `c8eafc6f5bfd05029247d750a67f8de68b266baa` |
| `2026-10-13T23:52:21Z` | [src/rpc/misc.cpp](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/rpc/misc.cpp?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | exit 0; [M] 1346 lines; blob `48afb1091b622330f49cd03a31c978de8b1d8763` |
| `2026-10-13T23:52:22Z` | [src/httprpc.cpp](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/httprpc.cpp?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | exit 0; [M] 396 lines; blob `5f9ac1a757fc848527f6be58e99f13bac2257006` |
| `2026-10-13T23:54:39Z` | [src/rpc/ (directory listing)](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/rpc?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | exit 0; [M] 37 entries |
| `2026-10-13T23:54:40Z` | [src/warnings.cpp](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/warnings.cpp?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | exit 0; [M] 97 lines; blob `5594a1b9c77ceb6c2d497d02161cdea9d18fdc9a` |
| `2026-10-13T23:54:40Z` | [src/rpc/mining.cpp](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/rpc/mining.cpp?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | exit 0; [M] 974 lines; blob `634344e06e6fa1ed1ae6482c2c679c650367bb75` |
| `2026-10-13T23:54:41Z` | [src/rpc/net.cpp](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/rpc/net.cpp?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | exit 0; [M] 908 lines; blob `7445c62cc1346eab7c2bc6fb1c1f398d8253268b` |
| `2026-10-13T23:54:42Z` | [src/rpc/rawtransaction.cpp](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/rpc/rawtransaction.cpp?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | exit 0; [M] 2637 lines; blob `c1c713dbd71fcc741473f0395209e9e98d119478` |
| `2026-10-13T23:54:43Z` | [src/rpc/abc.cpp](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/rpc/abc.cpp?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | exit 0; [M] 117 lines; blob `765a1314dff29ce2c0e533ec8b2b7ef9935cc94d` |
| `2026-10-13T23:54:43Z` | [src/rpc/frozentxo.cpp](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/rpc/frozentxo.cpp?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | 404: no such path at the pin (a guessed name; nothing read) |
| `2026-10-13T23:54:44Z` | [src/rpc/minerid.cpp](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/rpc/minerid.cpp?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | 404: no such path at the pin (a guessed name; nothing read) |
| `2026-10-13T23:54:44Z` | [src/rpc/server.h](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/rpc/server.h?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | exit 0; [M] 304 lines; blob `f1cf894e5bdf37f49ad79f086a8a5bee177ad2b9` |
| `2026-10-13T23:54:45Z` | [src/wallet/rpcwallet.cpp](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/wallet/rpcwallet.cpp?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | exit 0; [M] 3563 lines; blob `6c50aace93bb95c2109c044d143ee0452c7adaeb` |
| `2026-10-13T23:54:45Z` | [src/wallet/rpcdump.cpp](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/wallet/rpcdump.cpp?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | exit 0; [M] 1401 lines; blob `09642d06ed33819438e0602a0e860eb81cf90665` |
| `2026-10-13T23:54:46Z` | [src/chain.h](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/chain.h?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | exit 0; [M] 99 lines; blob `1fe2cb7f773e89f18c81d16467539cd08dd3be77` |
| `2026-10-13T23:54:47Z` | [src/chain.cpp](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/chain.cpp?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | exit 0; [M] 78 lines; blob `043fcd6ff3894f6894907bc454459a41c6ffc1c0` |
| `2026-10-13T23:58:30Z` | [src/warnings.h](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/warnings.h?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | exit 0; [M] 45 lines; blob `46f72eb3c6e370242fa0915fc1ac5cdb8a6a1df6` |
| `2026-10-13T23:59:29Z` | [git tree, recursive](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/git/trees/6504a3aff65ba97c0f6c80962b033e35ecbfed4b?recursive=1) | exit 0; [M] 1983 blobs |
| `2026-10-13T23:59:29Z` | [src/arith_uint256.h](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/arith_uint256.h?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | exit 0; [M] 312 lines; blob `1dc4c1ab8648e3b63a90dc7ad5092ffaf2f67c95` |
| `2026-10-13T23:59:30Z` | [src/rpc/frozentxo_rpc.cpp](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/rpc/frozentxo_rpc.cpp?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | exit 0; [M] 915 lines; blob `6011e748bef9de98306e279f0636d1d6bf1bb55e` |
| `2026-10-13T23:59:31Z` | [src/rpc/miner_info.cpp](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/rpc/miner_info.cpp?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | exit 0; [M] 1077 lines; blob `460ca2ea802a97b983d42fa9b58bff7f56895f39` |
| `2026-10-13T23:59:31Z` | [src/rpc/mining-fbb.cpp](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/rpc/mining-fbb.cpp?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | exit 0; [M] 392 lines; blob `ec1511eb432856b9c23bc59afa630a0704d39786` |
| `2026-10-13T23:59:32Z` | [src/wallet/rpcwallet.h](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/wallet/rpcwallet.h?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | exit 0; [M] 27 lines; blob `4c9e7ba0fb9c778df80e9ffe4ebaf9a9218e4bee` |
| `2026-10-13T23:59:48Z` | [src/rpc/register.h](https://api.github.com/repos/bitcoin-sv/bitcoin-sv/contents/src/rpc/register.h?ref=6504a3aff65ba97c0f6c80962b033e35ecbfed4b) | exit 0; [M] 46 lines; blob `09e8041e9abefdc4fd003c4e413e7d03c1736b62` |

### Operator-list reads, 2026-10-14

[M] 2026-10-14 02:15 to 02:50 UTC (#70): local `git show` reads of the
clone `<the maintainers' build host>:bitcoin-sv` at `6504a3aff65ba97c0f6c80962b033e35ecbfed4b` (HEAD at the pin,
porcelain clean); no network read, nothing fetched or broadcast (rule 10). Blob ids
from `git rev-parse <pin>:<path>`.

| pinned source [SRC] | blob [M]; lines | spans read |
|---|---|---|
| `src/frozentxo.h` | `366599ba4e123a32eb4c4b152e330ee1da0f009e`; 141 | 1–141 |
| `src/frozentxo.cpp` | `205039a429e1d6b359485be4a16588a4427bc055`; 176 | 1–176 |
| `src/frozentxo_db.h` | `d7bb427e85ff60a8148861cde01546ffcf96b850`; 729 | 1–729 |
| `src/frozentxo_db.cpp` | `145f19d72706296dcaf420e6a05e4271a0689926`; 934 | 14–40, 299–400, 600–800, 838–890 |
| `src/rpc/frozentxo_rpc.cpp` | `6011e748bef9de98306e279f0636d1d6bf1bb55e`; 915 | 20–300, 320–500, 501–606, 632–764, 766–797, 822–910 |
| `src/validation.cpp` | `f2f5fa101028f0f73955b06b339c37570c57251a`; 7746 | 690–705, 1316–1330, 2455–2475, 2552–2640, 2994–3020, 3395–3412, 3522–3560, 3718–3745, 4261–4262, 5562–5580 |
| `src/block_index.h` | `543097e796ad0fcc9f9b104f96030129e28dc569`; 1277 | 390–440, 536–585, 1128–1150 |
| `src/block_index_store.h` | `eb2e5a5503b7134733ee47a1a18fb7587ae4d550`; 213 | the `mBestHeader` lines 23, 63–75, 131–149, 202 |
| `src/txmempool.cpp` | `a2021721d358c49fd0692d25fb8dd5c52fa36130`; 3361 | 1247–1345 |
| `src/univalue/include/univalue.h` | `d0efd3dc7e99158016d6d863d87991ea03a57bf0`; 315 | 37–43, 120–146 |

Searches over `src/` at the pin: `IsConfiscationTx`, `CheckConfiscationTxWhitelisted`,
`RemoveInvalidCTXs`, `RemoveFrozen`, `mostWorkBlockHeight`, `GetBestHeader`.

### Association reads, 2026-10-14 (#139)

[M] 2026-10-14 21:24:24Z to 21:35:46Z (#139): 29 public reads of https://protocol.bsvblockchain.org/
by `curl -sL` (the index `/llms.txt`, the 19 Markdown twins, nine HTML pages for their section ids); 2026-10-14
22:04:18Z to 22:04:26Z (#139): 21 more (the 19 twins again, each body byte-identical, and the
HTML of `/concepts/transaction-templates` and `/specification/opcodes` for their section ids); every one HTTP 200;
each read's UTC time, URL, bytes and sha256 in [the record](records/20261014-213924-xread-139-s4b.md) §1. Local
`git show` reads of `<the maintainers' build host>:bitcoin-sv` at v1.2.3 and v1.2.2 (the record's §2). Nothing broadcast (rule 10).

### Subtree merkle reads, 2026-10-14 (#89)

[M] 2026-10-14 (#89), on the box, which has no Teranode clone:
public reads of Teranode's pinned commit `4edb60a40c6628ff0ef60231c2628efd7103fde5`
by `raw.githubusercontent.com` (rule 10: reads only, nothing broadcast). The reads
the proofs were written from were stamped only after them, at 21:22:54Z (`model/Block.go`,
`model/subtree_meta_reader.go`, `settings/settings.go`, `go.mod`) and 21:29:38Z (the
rest); every file was read again with its own stamp below, its sha256 equal to the
earlier copy. Two directory listings by
`api.github.com/repos/bsv-blockchain/teranode/contents/<dir>?ref=4edb60a4…`
(`model`, `services/blockassembly/subtreeprocessor`) fell between those two stamps.

| URL path under `raw.githubusercontent.com/bsv-blockchain/teranode/4edb60a40c6628ff0ef60231c2628efd7103fde5/` | UTC [M] | sha256 [M] |
|---|---|---|
| `model/Block.go` | 2026-10-14T21:55:16Z | `36708e7e491fa251feb817729e098c24ce07c32ab4825486e77a90befc9dd38a` |
| `model/subtree_body_shape.go` | 2026-10-14T21:55:16Z | `2d4d78cbc1735a7fa672355d13c692a59a0580277ce6b6610856cea2c1da3b5b` |
| `model/subtree_meta_reader.go` | 2026-10-14T21:55:16Z | `2d48ce0480b3c02d096009a64a569e57f77192a83f5c8d04a13f8e085e6a9345` |
| `settings/settings.go` | 2026-10-14T21:55:16Z | `b1eeaeef724504675b5ef2ca9747d8e69122dea95af61ec6a2c2bb6e446fe09e` |
| `services/blockassembly/subtreeprocessor/SubtreeProcessor.go` | 2026-10-14T21:55:16Z | `66f5b463d9fc78ffc50fde7ff91385fdb3a7d7b3105ad83029b7f466ef27baff` |
| `go.mod` | 2026-10-14T21:55:17Z | `16e063b8c317cd1c74b4c2355db81a061c564112cab340c776cbfd0485338e35` |
| `go.sum` | 2026-10-14T21:55:17Z | `94eb46a3cef12f279c3177a39d6f6a033dcacfc73e046f21c53a2ca6a8bdc6b2` |

go-subtree `v1.5.1` (`go.mod:17` at the commit) read from the box's Go module
cache, no fetch: its zip's dirhash `h1:l/Qui+HT+yQKXIoCW4zAyBlD2St9iLjC9ydvzcr9YSM=`
equals `go.sum:142` at the commit; files `merkle_tree.go`, `subtree.go`,
`power_of_two.go`, `coinbase_placeholder.go`. The reference by local `git show` of
`<the maintainers' build host>:bitcoin-sv` at `6504a3aff65ba97c0f6c80962b033e35ecbfed4b`:
`src/consensus/merkle.cpp` (blob `ab89e2f1b6f2bc1a4afd18c2e6cb7319b4cae4a9`) and `src/binary_counter.h` (blob `c747f85018be8f0ea1016085521b9676f9fd0156`).

### Teranode reads, 2026-10-14 (#74)

[M] 2026-10-14 (#74), public reads of the pinned Teranode source on the box (rule 10: reads only, nothing broadcast):

| UTC | URL | what was read |
|---|---|---|
| `2026-10-14T21:23:44Z` (the clone's reflog) | `https://github.com/bsv-blockchain/teranode.git` | a clone into `<the maintainers' build host>:targets/spec-teranode/src-v0.16.0`, `checkout v0.16.0`, HEAD `4edb60a40c6628ff0ef60231c2628efd7103fde5`, `git status` empty: the instance's rebuild (`docs/records/20261014-215508-s6-74-second-oracle-s4b.md`) and the map's citations |
| `2026-10-14T22:15:25Z` to `22:15:28Z` (a review's correction) | `https://github.com/bsv-blockchain/teranode.git` | a shallow fetch (`--depth 1`) of commit `4edb60a40c6628ff0ef60231c2628efd7103fde5` into an untracked source directory, HEAD the pin: a review's corrections re-read (`settings/settings.go`, `services/rpc/handlers.go`, `services/rpc/Server.go`, `services/validator/Validator.go`, `util/lock_time.go`) |

### Wire-view reads, 2026-10-15 (#86)

[M] 2026-10-15: public reads only (rule 10: nothing broadcast). The four BRCs and BRC-96 at
`bsv-blockchain/BRCs` commit `5333fd449c70fd5982029876376dcf1ed9c64ffe` by raw URL (each body equal to the local
clone's `git show 5333fd4:<path>` by sha256):

| UTC [M] | URL path under `raw.githubusercontent.com/bsv-blockchain/BRCs/5333fd449c70fd5982029876376dcf1ed9c64ffe/` | bytes | sha256 [M] |
|---|---|---:|---|
| `2026-10-15T03:25:54Z` | `transactions/0030.md` | 9663 | `395fa0566fcae8e2c5478a03b8a500034553fbce634f48c6df114c8c828dab44` |
| `2026-10-15T03:25:54Z` | `transactions/0062.md` | 15674 | `7fdee54fa863a3787143ba86a076e1b790d9d9d0584059aa156214fea828a313` |
| `2026-10-15T03:25:54Z` | `transactions/0074.md` | 18597 | `0cd56c0f9e6b31a2500899b1791abcf15b216cb4aeb7576608b3cc19942d6aad` |
| `2026-10-15T03:25:55Z` | `transactions/0095.md` | 6801 | `e5ceb51ecbfd9b3715227e65891503908e485eb09d1a0bfd8060d99b2e13026e` |
| `2026-10-15T03:27:47Z` | `transactions/0096.md` | 4635 | `9b4b11fdb28c5ec66332cb3260716f82d61318e9dc376aba730fef903a577283` |

Mainnet material from `https://api.whatsonchain.com/v1/bsv/main` (read only): nine probe GETs between
`2026-10-15T03:49:55Z` and `03:51:30Z` (`/tx/<id>/proof/bump`, `/tx/<id>/beef`, `/tx/<id>/proof/tsc`, `/tx/hash/<id>`
for block 100000's index 1; `/chain/info`; `/block/height/900000`; `/block/<hash>/header` for block 100000), then
`tools/wire_corpus.py fetch`: 197 GETs from `2026-10-15T03:52:55Z` to `03:55:13Z`, every one HTTP 200 (48 `/tx/<id>/hex`,
48 `/tx/hash/<id>`, 48 `/tx/<id>/proof/bump`, 22 `/tx/<id>/beef`, 22 `/tx/<id>/proof/tsc`, 7 `/block/<hash>/header`,
2 `/block/height/<h>`). The 144 the corpus cites are listed one per line, with URL, UTC time, status, bytes and sha256,
in [`corpus/wire/reads.jsonl`](../corpus/wire/reads.jsonl); the 53 others (the parents' `/tx/hash/<id>` and BUMPs
the build did not use) are uncited. Package registries: `npm ci` in `harness/engines/ts` at its lockfile's integrity
(registry.npmjs.org, `2026-10-15T04:0xZ`); the go-sdk module came from the local module cache at the pin's sums, no fetch.
The engines' sources were read locally at their pins: bsv-rs 0.5.0 from the cargo registry's unpacked crate (the clone
`<the maintainers' build host>:bsv-rs` is not at the tag), go-sdk at `2ca481c5` in `<the maintainers' build host>:go-sdk`, ts-stack at `4d0ea63c` and `edf6e03d`
in `<the maintainers' build host>:ts-stack` (`Beef.ts`, `BeefTx.ts`, `MerklePath.ts`, `Transaction.ts` byte-identical at the two commits [X]).

### go-alert-system reads, 2026-10-15 (#94)

[M] 2026-10-15: public reads only (rule 10: nothing broadcast). The module Teranode v0.16.0's
`go.mod:197` requires, `github.com/bsv-blockchain/go-alert-system` v0.1.17, was downloaded by `go mod download`
into the reading worktree's own module cache (`GOMODCACHE` = `<the #94 worktree>/scratch/gomod`). The times are
the cache files' modification times read in the follow-up (`stat`, UTC) [M]; the parameters page records the
command at `2026-10-15T13:16:16Z`.

| UTC [M] | URL | what was read |
|---|---|---|
| `2026-10-15T13:16:17Z` | `https://proxy.golang.org/github.com/bsv-blockchain/go-alert-system/@v/v0.1.17.info` | the version's origin: git `https://github.com/bsv-blockchain/go-alert-system`, `refs/tags/v0.1.17`, commit `df18148deb98a3eef2f2d4741049ef1d258d2b53`, time `2026-07-28T16:33:56Z` |
| `2026-10-15T13:16:17Z` to `13:16:18Z` | `https://sum.golang.org/lookup/github.com/bsv-blockchain/go-alert-system@v0.1.17` and its twelve tiles (`/tile/8/0/x227/566`, `/tile/8/0/x269/769`, `.../x269/769.p/49`, `.../x270/046.p/86`, `/tile/8/1/888`, `/tile/8/1/x001/053`, `.../x001/053.p/201`, `.../x001/054.p/222`, `/tile/8/2/003`, `.../2/004.p/29`, `.../2/004.p/30`, `/tile/8/3/000.p/4`), directly or through the proxy's `sumdb/sum.golang.org/` path (the cache does not record which) | the checksum database's record (tree index 58257141): `h1:qWh/nnN3DiP2OahWbb0hdLBNKkKHXDToSDDnxEzjJ08=` and the `go.mod` sum `h1:5ui29gal23sCi7eOfRQ6bGucOisunkaBI2PzdRBFxrc=`, both equal to Teranode's `go.sum` at `4edb60a4` |
| `2026-10-15T13:16:18Z` | `https://proxy.golang.org/github.com/bsv-blockchain/go-alert-system/@v/v0.1.17.mod` | the module's `go.mod` (9282 bytes) |
| `2026-10-15T13:16:18Z` | `https://proxy.golang.org/github.com/bsv-blockchain/go-alert-system/@v/v0.1.17.zip` | the module (451654 bytes, sha256 `07e1c7df1d21638f1e5dbacbb8da69816de27df0be7d46402ec04ff44c575be6`); its h1 sum recomputed in the follow-up over its 197 files: `h1:qWh/nnN3DiP2OahWbb0hdLBNKkKHXDToSDDnxEzjJ08=`, equal to the `go.sum` line [X] |

The files the module, `docs/PARAMETERS.md` §8.10 and the scenario cite, at v0.1.17: `app/models/alert_message_freeze_utxo.go`,
`app/models/alert_message_unfreeze_utxo.go`, `app/models/alert_message_confiscate_utxo.go`, `app/models/alert_message.go`,
`app/models/alert_message_set_keys.go`, `app/models/genesis_alert.go`, `app/models/public_key.go` and `app/config/node.go`.
**Where the copy is kept:** the unpacked module in the reading worktree (`scratch/gomod/github.com/bsv-blockchain/go-alert-system@v0.1.17`,
a scratch directory a worktree's removal deletes) and, durably, the local clone `<the maintainers' build host>:upstream/bsv-blockchain/go-alert-system`,
whose tag `v0.1.17` resolves to `df18148deb98a3eef2f2d4741049ef1d258d2b53`: every one of the eight files is byte-identical
between the clone's `git show v0.1.17:<path>` and the proxy's copy (`cmp`, 2026-10-15 15:0x UTC) [X]. The
citations into them are read there; `tools/cite_check.py` does not reach this module.

### Compact-block reads, 2026-10-15 (#79)

[M] 2026-10-15, on the box: public reads only (rule 10: nothing broadcast). The reference and
Teranode were read by `git show` at their pins (`6504a3af`, `4edb60a4`) from the box's clones, no network read.
One network read: BIP152, the document the reference's compact blocks implement.

| UTC [M] | URL | what the #79 reads covered |
|---|---|---|
| `2026-10-15T16:01:41Z` | `https://raw.githubusercontent.com/bitcoin/bips/master/bip-0152.mediawiki` | BIP152 (261 lines, sha256 `b710fa0a4ab9ec92d84884adc77df25b974add79dbc23b8158bf3a791e47cd85`); cited by line in `lean/BsvChain/Wire/CompactBlocks.lean` and `docs/CONFORMANCE-P2P-RELAY.md` section 7 |

go-wire v1.2.11, the wire codec Teranode's `go.mod:205` requires (not a pin of section 1a, #98's Finding), was
read from the box's existing module cache (`~/go/pkg/mod/github.com/bsv-blockchain/go-wire@v1.2.11`, its zip's h1
sum `h1:jVbatioBZ21ebK7rrt9IY768VPVTMpk0KSPC2fm0lS0=` equal to Teranode's `go.sum` line at `4edb60a4`), no network read: `message.go` (sha256
`e7b1a0a57e9fa3deb27f1ac732f340ed5b19481afde76583bd6e7ea1f1c3ea1a`; `CmdSendcmpct` at `:87`, `makeEmptyMessage` at
`:120` with its `CmdSendcmpct` case at `:220-221` and its unhandled-command default at `:229-230`, no constant or case
for `cmpctblock`, `getblocktxn` or `blocktxn`; the lines read in the #79 follow-up, 2026-10-15) and `msg_send_cmpct.go` (sha256
`4cd7250ecd1070f64daffa6f580ae8e2a2541d60abecdcc97162c4c93e31e077`). `tools/cite_check.py` does not reach it.
