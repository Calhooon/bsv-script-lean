# The recon log (#39): the pinned upstreams, read at their sources every month

Public release metadata, consensus changes and policy defaults. Each entry's
record carries its source citations, public URLs and UTC read times.

[D] The signer column (`make check-signer`, #145) runs once per SDK pin move inside the recon, with every signed transaction judged by a fresh pinned regtest node and every disagreement recorded under a cited class; it is never a standing job or a leg of `make check`. At every bsv-rs pin move the bsv-rs fixtures (`corpus/fixtures/bsv-rs/`, #146) ride with the signer column: their loader proof (`corpus/fixtures/bsv-rs/README.md`) re-runs in a scratch tree at the new tag, and a shape change of `tests/sighash_tests.rs` re-cuts the generator.

The harness's re-run on a new pin (CLAUDE.md rule 18) is one command per implementation (#124): `make column IMPL=<bsv-rs|go-sdk|ts-sdk|gobdk|sv-node|teranode> PIN=<release>` (`tools/column.sh`, its header the manual). At the pin of `docs/PROVENANCE.md` §1a it is a dry run compared with the committed column; at another release it moves the sites `make check-pins` reads and re-records the column; sv-node and teranode name the maintainers' instances and never start one. Its record is `docs/records/<stamp>-column-<impl>-<pin>-s3.md`, and an entry that finds a pin move owed names that record. [M] 2026-10-14

The recon's Teranode release duty runs the per-release divergence gate (#95): after the Teranode column's pin move, `make teranode-gate` (the plan and its steps, `harness/README.md`'s runbook) writes `docs/records/<stamp>-s8-95-gate-report-s3.md` (a public page of codes, classes, row ids, hashes and counts; the steps' raw log apart, withheld from the public edition), the new release against the reference pin with every difference a witness row and the delta from the previous gate record, and the entry names that record. [D] 2026-10-17 (the live run of record [M], docs/records/20261017-234627-s8-95-gate-report-s3.md; the dry-run shape [M])

From 2026-10-14 (#139) the upstreams include one documentation source: the BSV Association's protocol
documentation (https://protocol.bsvblockchain.org/, `docs/PROVENANCE.md` §1 and §1a `association-docs.*`). Each entry
reads its `/llms.txt` and every listed page's Markdown twin, records each specification page's named bitcoin-sv pin
and each page's sha256, and names the pages that moved; a moved pin or page re-opens that page's rows of
`docs/CONFORMANCE-ASSOCIATION-v122.md`.

## The entries

| entry | date | by | the record |
| --- | --- | --- | --- |
| 1 | 2026-09-29 | harness | [record](records/20260929-054539-recon-1-s4b.md) |
| 2 | 2026-10-05 | harness | [record](records/20261005-220818-recon-2.md) |
| 3 | 2026-10-06 | harness | [record](records/20261006-143018-recon-3.md) |
| 4 | 2026-10-12 | harness | [record](records/20261012-002025-repin-gosdk-172-s4b.md) |
| 5 | 2026-10-17 | harness (#148) | [record](records/20261017-020538-recon-5-s3.md) |

## Entry 1 · 2026-09-29

Upstreams read: bitcoin-sv, Teranode and its required GoBDK module, bsv-rs,
go-sdk, @bsv/sdk and go-chaincfg. The public release reads ran from
2026-09-29T05:29:32Z to 2026-09-29T05:39:26Z. Sources and times: the entry's
[record §6](records/20260929-054539-recon-1-s4b.md#6-every-read-utc-the-name-the-url-the-bytes-received).

| upstream | pin at the read | newest release and date | consensus or policy default moved | harness answer |
| --- | --- | --- | --- | --- |
| bitcoin-sv | v1.2.2 | v1.2.2, 2026-04-28 | none | none |
| Teranode | v0.15.9 | stable v0.15.9, 2026-09-17; prerelease v0.16.0-beta-14, 2026-09-25 | a script-size policy default on the beta line; no mainnet consensus change recorded | none for the stable pin; revisit at a stable release |
| GoBDK | cdfa7814ee5da7b899e7301f058710002baaea40, required by Teranode v0.15.9 | Go module v1.2.4, 2026-05-07; GitHub archive release rustbdk-prebuilt, 2026-06-15 | STN activation parameters on the beta dependency line | follows Teranode's required module |
| go-chaincfg | v1.5.8, required by Teranode v0.15.9 | v1.7.0, 2026-09-09 | regtest activation parameters and a test-network genesis block; mainnet unchanged | follows Teranode's required module |
| bsv-rs | 0.3.30 | 0.3.30, 2026-09-27 | none released after the pin | none |

SDK release metadata published by the upstreams:

| upstream | newest release and date | upstream release-note heading |
| --- | --- | --- |
| go-sdk | v1.7.0, 2026-09-28 | Release v1.7.0; [Interpreter] Apply Chronicle signature rules to scriptSig checks and SIGHASH_CHRONICLE (#366) |
| @bsv/sdk | 2.8.10, 2026-09-27 | no versioned 2.8.10 heading in the upstream changelog; no release notes in the npm artifact |

detail withheld under a private advisory; see the withheld record

## Entry 2 · 2026-10-05

The week of bsv-rs 0.3.31's crates.io publication, also the monthly entry.
Upstreams read: bitcoin-sv, Teranode and its required GoBDK module, bsv-rs,
go-sdk, @bsv/sdk and go-chaincfg. Sources, the release trace and every read's
UTC time are in the [record](records/20261005-220818-recon-2.md); the same public URL/time
rows are in `docs/PROVENANCE.md` §6. Pins below are main at `8d38bf6`, read at
2026-10-05T22:05:15Z; this entry moves no pin.

| upstream | main's pin | newest release and date | consensus or policy default moved | harness answer |
| --- | --- | --- | --- | --- |
| bitcoin-sv | v1.2.2 | v1.2.2, 2026-04-28 | no release or tag after the pin | none |
| Teranode | v0.15.9 | stable v0.16.0, 2026-10-05; prerelease v0.16.1-beta-1, 2026-10-05 | stable release carries regtest activation changes and consensus-validation fixes; script-size policy default raised | stable v0.16.0 pin move owed with its required modules and harness rerun; beta requires no separate pin move |
| GoBDK | cdfa7814ee5da7b899e7301f058710002baaea40 | Go module v1.2.4, 2026-05-07; GitHub archive release rustbdk-prebuilt, 2026-06-15 | Teranode v0.16.0 requires 4eab3acdbbb9: explicit STN parameters, a spend-verification API and a widened ABI; the build recipe's reference pin is unchanged | move with Teranode to v1.2.5-0.20260918043653-4eab3acdbbb9; rerun the wrapper |
| go-chaincfg | v1.5.8 | v1.7.0, 2026-09-09 | regtest activation heights and the tstn genesis block changed; mainnet parameters unchanged | move with Teranode to its required v1.6.2, not the independent newest v1.7.0 |
| bsv-rs | 0.3.30 | crates.io 0.3.31, 2026-10-05; GitHub release remains v0.3.30, 2026-09-27 | documentation of the block path's stack budget; executable Rust source and declared dependency requirements unchanged; no policy-default move | none owed for behavior; the release trace is complete, with packaged-lockfile drift recorded |

SDK release metadata published by the upstreams:

| upstream | newest release and date | upstream release-note heading |
| --- | --- | --- |
| go-sdk | v1.7.1, 2026-09-29 | Release v1.7.1; feat(interpreter): default to after-Chronicle execution rules (#371); fix(interpreter): match node semantics for OP_LSHIFTNUM/OP_RSHIFTNUM (#370) |
| @bsv/sdk | 3.0.0, 2026-10-03 | Removed (3.0.0 candidate), under Unreleased in the upstream changelog |

Main's SDK pins are go-sdk v1.5.2 and @bsv/sdk 2.8.0. Their moves are in flight
under #51 and #52. The record's SDK assessments use published
release headings; no SDK implementation is read for this entry.

Informational: Lean 4.34.1 is newer than pin 4.34.0; Mathlib's pinned
5ed2965256430c3649e86755f9576b54eca72435 object exists; Rust 1.95.0, Go 1.27.0
and Node 22.18.0 are at the pins. Rule 18 owes no toolchain move.

## Entry 3 · 2026-10-06

The release week of bitcoin-sv v1.2.3, prompted by r1-x86's download-host
listing. Upstream read: bitcoin-sv alone. Local pins are this entry's base
`726edd0`; this entry moves no pin. The [record](records/20261006-143018-recon-3.md)
classifies every release-note item, traces the two changed opcode rules
and records the directory and checksum text.

| upstream | pin at this entry | newest release and date | consensus or policy default moved | harness answer |
| --- | --- | --- | --- | --- |
| bitcoin-sv | v1.2.2, `879fc8b42168dd0e608dafd51b39c6dabad37d4d` | stable v1.2.3, published 2026-10-06T09:09:04Z; tagger 2026-10-05T06:31:58Z | CONSENSUS: OP_SPLIT range guard and fixed-width operand decoding; no validation policy-default move established | reference tag/commit, node of record build and corpus node keys owed under archived #57 |
| Teranode | v0.16.0 | not re-read this entry | not re-read this entry | not re-read this entry |
| GoBDK | 4eab3acdbbb971724f37e886e836daa1ed444a7f, required by Teranode v0.16.0 | not re-read this entry | not re-read this entry | not re-read this entry |
| bsv-rs | 0.3.32 | not re-read this entry | not re-read this entry | not re-read this entry |
| go-sdk | v1.7.1 | not re-read this entry | not re-read this entry | not re-read this entry |
| @bsv/sdk | 3.0.0 | not re-read this entry | not re-read this entry | not re-read this entry |
| go-chaincfg | v1.6.2, required by Teranode v0.16.0 | not re-read this entry | not re-read this entry | not re-read this entry |

Tagged release: **v1.2.3 = `6504a3aff65ba97c0f6c80962b033e35ecbfed4b`**; annotated tagger time
**2026-10-05T06:31:58Z**, commit time **2026-10-05T06:27:47Z**, release
publication **2026-10-06T09:09:04Z**. The live parent listing dates `1.2.3/`
to **06-Oct-2026 09:15 UTC**. The five listed files and four published hash
lines, including the present `SHA256SUMS.asc`, are in the record section 2.

The `OP_SPLIT` position is bounded by `INT32_MAX` ([SRC] `interpreter.cpp:1718–1719` at `6504a3af`). The reading of record at v1.2.3 is a defined refusal ([SRC] `int_serialization.h:61–118`, `script_num.cpp:80–91` at `6504a3af`); the previous pin's reading and its measurements are recorded in material withheld from the public edition at the maintainers' request (group `d8-node-team-discretion`).
POLICY default: no validation/relay default move established. NEITHER:
performance, storage/connection/pruning settings, wallet RPC, tracing,
public libbitcoinconsensus API version 2 and the remaining safety/maintenance
items; each release-note item is separately classified in the record.

The harness owes **reference tag/commit in PROVENANCE section 1a, the node
of record's build, and re-run corpus `sv-node@` / `sv-node-mempool@` keys**,
under **archived #57**. That issue owns the move and the harness rerun;
the affected spec citations are due the following week, by 2026-10-13.
This entry records the obligation and leaves the pin at v1.2.2.

Public reads/attempts: **21**, including **16 live text bodies**, from
2026-10-06T14:18:56Z to 2026-10-06T14:23:35Z. Eight times below are snapshot
save times immediately after their reads; the header-only attempt has minute
precision. The browser cache/failures are retained as attempts, with no
absence claim drawn from them. Full hashes and the timing explanation:
[record section 6](records/20261006-143018-recon-3.md#6-every-public-read-with-its-own-utc-time).

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

Unverified: v1.2.3 runtime behavior, downloaded asset hashes/build linkage
and local signature verification; other upstreams not re-read this entry.
No build or binary download was performed.


## Entry 4 · 2026-10-12

The release week of go-sdk v1.7.2, under archived #99.
Upstreams read: go-sdk and @bsv/sdk. Base `69ff3463`; the
[record](records/20261012-002025-repin-gosdk-172-s4b.md) now includes the
box continuation, rebased source `764dab8`. [X] Both
builds and the seed smoke ran; all 26 corpora were measured at v1.7.2.
The measured result is **RED on five unclassified runs**. The report
generator refused those rows; their disposition and the landing
checks remain owed. The measured data commit is `85026f9`.
Every recorded execution start was below the rule 17 load gate.

| upstream | pin at this entry | newest release and date | consensus or policy default moved | harness answer |
|---|---|---|---|---|
| go-sdk | v1.7.1 → v1.7.2, `2ca481c5931b987a0c8f48bb341c70b7477b6b07` | v1.7.2, published 2026-10-09T05:08:55Z; tagger 2026-10-09T04:54:16Z | consensus-affecting implementation corrections: spend-era flags, height-based words, number length 32,000,000, flag-aware digest selection and P2SH-era handling; policy default: 100,000,000-byte post-Genesis stack memory, explicitly configurable; no new chain activation established | pin, sums and adapter updated; box builds and seed smoke executed; 26-corpus retally measured 276,002 / 275,986 agreements, with five unclassified runs; report regeneration refused; pins GREEN with named skips, citation outcome in the record |
| @bsv/sdk | 3.0.0 | npm latest 3.2.0, published 2026-10-07T03:03:21.671Z; 3.2.1 absent at the read | PR #878 merged 2026-10-07T18:04:15Z, after that package publication; reviewed as an interpreter update, not as evidence that 3.2.0 includes it | separate published-version pin review owed for 3.2.0; a package carrying PR #878 remains to be published and verified; no TypeScript pin move in this entry |
| bitcoin-sv | unchanged | not re-read this entry | not re-read this entry | not re-read this entry |
| Teranode | unchanged | not re-read this entry | not re-read this entry | not re-read this entry |
| GoBDK | unchanged | not re-read this entry | not re-read this entry | not re-read this entry |
| bsv-rs | unchanged | not re-read this entry | not re-read this entry | not re-read this entry |
| go-chaincfg | unchanged | not re-read this entry | not re-read this entry | not re-read this entry |

The go-sdk [CHANGELOG at the tag](https://github.com/bsv-blockchain/go-sdk/blob/v1.7.2/CHANGELOG.md)
says “Fixes GHSA-rh54-8fpg-8wwf” and
“A flag word passed through `WithFlags` is used exactly as given”.
**GHSA-rh54-8fpg-8wwf** is [go-sdk's published advisory](https://github.com/bsv-blockchain/go-sdk/security/advisories/GHSA-rh54-8fpg-8wwf).
Its CHANGELOG text is under `Unreleased`, despite being present in v1.7.2.
The Chronicle no-option default already existed at v1.7.1; it is not a
new default between these pins. The runner uses explicit words and now
maps the separate spend-era flags. Its new SDK stack budget is a policy
default on both supplied-word paths, not an unconditional consensus cap.

The spec-page audit is in record §5. Mainnet activations, separate spend
and coin eras, number length, configurable stack memory, digest selection
and the P2SH coinbase exception are already stated. **Findings:** the SDK
no-option API default, five non-era testnet activation values, and the
SPV mined-coinbase evidence convention are not stated in the reviewed spec
pages. They are reported on #99; no semantic page or classifier is edited.
The interpreter column does not test the `spv.Verify` API.

The v1.7.1 baseline is 13,915 entries over nine corpora: agreement
**13,873 / 12,424** (`spec` / `spec-mempool`), classified divergent runs
**42 / 1,491**, 27 class rows. The other 17 corpora have no earlier SDK
column. [X] On the same nine corpora, v1.7.2 agreement is **13,857 /
13,847**, classified runs **57 / 67**, unclassified **1 / 1**. Across all
26 corpora, agreement is **276,002 / 275,986**, classified **58 / 75**,
unclassified **3 / 2**; no aborts or undecided runs. On the original nine,
`flags.version-gate.absent` moves **25 / 1,472 → 0 / 0**,
`limits.maxscriptnumlength` **3 / 1 → 57 / 57**, and `engine.timeout`
**3 / 3 → 0 / 0**. Record §3 lists every changed row and the five witness
IDs. No classifier was edited. All other verdict fields and engine
manifests are preserved. The current report has a refusal notice and
retains its old measured tables; it was not relabelled as a new run.

[withheld at export: a sibling tree's line]
in both columns, and `million-seed-352758` in block. They are reported
without assigning a class; their disposition is the harness's. Record §5 also
completes the #99 page audit: SDK convenience options, cancellation,
SPV proof conventions and tracker memoization are not stated as APIs,
and the finality boundary page disclaims current-pin citation anchoring.
The interpreter retally does not execute `spv.Verify`.

[ts-stack PR #878](https://github.com/bsv-blockchain/ts-stack/pull/878) was
read at **2026-10-12T00:05:34Z**, merge commit
`fb1b2dad56d207b21aa5f763f0c56113cacedd5d`. The npm read was
**2026-10-12T00:06:01Z**. The release, tag, advisory, CHANGELOG, PR and
registry facts above are scoped to those reads.

Every public read/attempt follows; module-download URL times are the
command's start time, and browser cache misses supplied no body. The same
log is in PROVENANCE §6 and record §6.

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

## Entry 5 · 2026-10-17 (#148 (e))

The release week of bsv-rs 0.7.0, under archived #148.
Upstream read: bsv-rs only. Base `0b997779`; the [record](records/20261017-020538-recon-5-s3.md) carries
the reads and the measurements. The pin moved in the same change.

| upstream | pin at this entry | newest release and date | consensus or policy default moved | harness answer |
|---|---|---|---|---|
| bsv-rs | 0.5.0 → 0.7.0, tag `v0.7.0` = `5841f98c839859658c0661dd034722f63d545e2f`, checksum `a4bd3df9…` | 0.7.0, crates.io `created_at` 2026-10-17T01:53:11.632810Z (trusted publishing, sha `5841f98c…`); 0.6.0 (2026-10-14) and 0.6.1 (2026-10-15) between, by the CHANGELOG [LIT] | neither: 0.7.0's "The default signing digest is the node's" and "The identity token signatures (the review of 0.7.0)" change signing paths only; 0.6.0's "Chain primitives" makes its varint readers canonical (the node's `ReadCompactSize`); no node rule and no policy default moved | pin moved (`make column IMPL=bsv-rs PIN=0.7.0`: 27 corpora, 276,079 entries, moved rows 0, RED 0, MEASURED); `make check-signer`: bsv-rs `sighash.chronicle.bip143` and `sighash.single.out-of-range.one` 0, lock-only 108, go-sdk and ts-sdk unchanged; the wire views: `bump-030` (a non-canonical offset) now refused, agreeing with the spec |
| bitcoin-sv | unchanged | not re-read this entry | not re-read this entry | not re-read this entry |
| Teranode | unchanged | not re-read this entry | not re-read this entry | not re-read this entry |
| GoBDK | unchanged | not re-read this entry | not re-read this entry | not re-read this entry |
| go-sdk | unchanged | not re-read this entry | not re-read this entry | not re-read this entry |
| @bsv/sdk | unchanged | not re-read this entry | not re-read this entry | not re-read this entry |
| go-chaincfg | unchanged | not re-read this entry | not re-read this entry | not re-read this entry |
| BSV Association protocol documentation | unchanged | not re-read this entry | not re-read this entry | not re-read this entry |

The verdict lines, quoted from the runs:

- `column: bsv-rs 0.7.0 (pin move 0.5.0 -> 0.7.0): 27 corpora, 276,079 entries; agree spec 122,716 (recorded 122,716); spec-mempool 27,897 (recorded 27,897); corpora differing 0; moved rows 0; RED 0; unexplained 0; wall 50 s: MEASURED` ([record](records/20261017-015602-column-bsv-rs-0.7.0-s3.md))
- `signer: GREEN [X] (241 rows, 2346 traces judged, divergent by class [sighash.scriptcode.in-unlock.lock-only: 108], RED 0) engine=bsv-rs`; go-sdk 1,550 traces and ts-sdk 1,474 traces, as before ([record](records/20261017-020326-s3-147-signer-column-s3.md))

| UTC read time | public URL | result |
|---|---|---|
| 2026-10-17T01:55:17Z | https://crates.io/api/v1/crates/bsv-rs/0.7.0 | HTTPS 200 JSON: created_at 2026-10-17T01:53:11.632810Z, not yanked, checksum `a4bd3df9…`, trustpub sha `5841f98c…` |
| 2026-10-17T01:55:20Z | https://github.com/Calhooon/bsv-rs | `git fetch origin tag v0.7.0`: `v0.7.0` -> `5841f98c…` |
| 2026-10-17T01:56:02Z | https://index.crates.io/bs/v-/bsv-rs | `cargo update -p bsv-rs --precise 0.7.0` (start time of the command; the crate fetched) |
