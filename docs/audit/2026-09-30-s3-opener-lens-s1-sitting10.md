[export: 4 lines withheld by tools/export_public.py, the sibling trees' lines; the original is in the private history]
# S1 opener review, Codex GPT-6.1-Sol

Existing read-only review, run [LIT] `9e949b66`, completed before the pause. Imported unchanged from its final report; no review was launched in this sitting. Original report SHA256 [D] `cce14aab18493368579bec1dd9d1d08dcb673142e0800d44ff8b52ccacad6855`.

**HELD: the independent stranger receipt supports accepting the recorded seed dry run described in the brief [D].** Direct comparison with issue [SRC] #31’s exact checklist is **UNVERIFIABLE**: the tracker REST request failed to connect, and the REST endpoint was inaccessible through the browser tool.

Reviewed model: [SRC] **Codex GPT-6-Astra**, sitting [SRC] **10**. Fresh lens: [SRC] **Codex GPT-6.1-Sol**, effort max, identifier [SRC] `S3-lens-s1-c57`.

[withheld at export: a sibling tree's line]

**Execution and re-derivation**

[withheld at export: a sibling tree's line]

```sh
harness/run --impl bsv-rs --corpus seed --spec recorded --out /tmp/codex-s1-c56/report
```

It ran from the detached source worktree, built `run_diff` and `spec_recorded`, and returned [SRC] exit `0` after [SRC] `11.391` seconds. The recorded environment specifies [SRC] `CARGO_BUILD_JOBS=4`, `CARGO_NET_OFFLINE=true`, and the isolated target directory. The ledger contains [M] **22** commands, with [M] **zero** nonzero exits. Offline dependency fetch and wrapper help each returned [SRC] exit `0`.

I independently parsed the pinned seed and decompressed retained output, then ran the retained verifier in memory. All allowed source files matched the pin; all [M] **12** retained artifact files matched their `origin/main` bytes.

| Quantity | Re-derived result | Assessment |
|---|---:|---|
| Seed rows / unique IDs | [M] 10,000 / [M] 10,000 | HELD |
| Export rows / unique IDs | [M] 10,000 / [M] 10,000 | HELD |
| Missing / extra IDs | [D] 0 / [D] 0 | HELD |
| Missing recorded keys | [M] 0 | HELD |
| Changed normalized exported objects | [M] 0 | HELD |
| Verdict cells | [D] 20,000 | HELD |
| `spec` valid / invalid | [M] 5,502 / [M] 4,498 | HELD |
| `spec-mempool` valid / invalid | [M] 5,342 / [M] 4,658 | HELD |
| Reported agreements, each column | [SRC] 10,000 | HELD as emitted counts |
| Undecided / abort witnesses | [SRC] 0 / [SRC] 0 | HELD as emitted counts |
| Classification rows | [M] 0 | HELD |
| Witness rows / bytes | [M] 0 / [M] 0 | HELD |
| GREEN / RED / skipped corpora | [SRC] 1 / [SRC] 0 / [SRC] 0 | HELD |
| Decompressed spec bytes | [M] 1,991,763 | HELD |
| Retained gzip bytes | [M] 35,969 | HELD |
| Retained verifier | GREEN, exit [M] 0 | HELD |

[withheld at export: a sibling tree's line]

Implementation [SRC] `bsv-rs 0.3.30` matches both Cargo pins. Every export carries [SRC] commit `8fde74b` and configuration `sv-mainnet-default`.

The hashes re-derived exactly:

| Content | Hash |
|---|---|
| Pinned README | [D] `5befd578ed1fa4c658dccfcadf0d9f638e58fc6ed0788454c7c46a1de5da4189` |
| Source seed | [D] `34b1dbbc9a3120253dbdddcae6d6e9b5e1555df2ddc09157e5792f6014d51f65` |
| Decompressed spec output | [D] `1cc694d9446d17cedf784bd404d1727e54b225ac7a4d43ee4caec34070d26607` |
| Empty witness | [D] `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` |

All recomputed validation fields matched except the physical-file hash inventory: the retained verifier inventories `.jsonl.gz`; the original validation inventories the uncompressed `.jsonl`. Decompressed content matches exactly [D].

[withheld at export: a sibling tree's line]

**Other claim assessments**

| Claim | Status and evidence |
|---|---|
| Receipt landed on main | **HELD.** Receipt commit [SRC] `89e52ff` is an ancestor of observed `origin/main`, check exit [M] `0`. |
| Source was merged by the receipt | **NOT HELD; not claimed by the receipt.** Source-pin ancestry check against the receipt returned [M] `1`. |
| Runtime paths unchanged; artifacts unchanged by rebase | **HELD as recorded checks.** Landing record gives [SRC] exit `0` for each diff. |
| Corpus and detached tree stayed clean during execution | **HELD as recorded evidence.** Ledger contains clean status and corpus-diff exit [SRC] `0` before and after. |
| Prepared-box instructions were sufficient | **HELD.** Documented option combination built and ran successfully. Clean-machine provisioning remains untested. |
| Broad sitting-wide absence of other actions | **PARTIAL.** Foreground recipe supports the stated execution scope; it is not a complete session-access log. |
| Rust/Cargo version | **HELD:** [SRC] `1.95.0` is recorded. Agreement with the toolchain file is **UNVERIFIABLE**, because that file is outside scope. |
| Entire records index preserved, inherited WIP preserved, existing Lean history retained | **UNVERIFIABLE by scope.** No inherited artifact or index was opened. |
| Current remote report/build availability | **UNVERIFIABLE by scope.** No remote inspection was performed. |
| Latest-block-only intake compliance | **NOT HELD by the author’s disclosure.** The allowed block admits earlier extracted-handoff and inherited-material reads. Further access-history claims remain **UNVERIFIABLE**. |
| Exact tracker criterion and current issue disposition | **UNVERIFIABLE.** Tracker reads failed. |

The recorded machine gate is consistent: load [SRC] `3.40`, memory-pressure free percentage [SRC] `89%`, swap used [SRC] `1006.88M`; thresholds are load below [SRC] `20` and free percentage at least [SRC] `50%`. Gate acceptance follows [D]. Post-run readings are load [SRC] `4.66`, free percentage [SRC] `89%`, and swap [SRC] `1006.88M`.

The block’s handback timestamp, uptime, status and disk snapshot match the landing record verbatim [D]. They describe that recorded snapshot.

**LOAD-BEARING corrections and qualifications**

There are [M] **zero** numerical corrections to the independent receipt.

| Sentence or claim | Site | Corrected wording or scope |
|---|---|---|
| “nothing more” in the implementation prerequisites | Pinned README line [SRC] **27**; wrapper lines [SRC] **75–76** | [SRC] The wrapper requires Cargo for builds and `python3`. The brief reports this corrected in checked code at [SRC] `d675b6f`. |
| Recorded words universally come from a witness manifest through `--words-from` | Pinned README lines [SRC] **33–34**; mirrored wrapper header lines [SRC] **11–12** | [SRC] For `bsv-rs`, words are derived locally per input. The `spec` column honours explicit flags or `params.consensus`; the mempool column uses the standard word. Wrapper line [SRC] **162** supplies no `--words-from`. The brief reports the README correction at [SRC] `d675b6f`. |
| “They are preserved” and “kept the parent’s entire records index” | Quoted block lines [SRC] **1074** and [SRC] **1085** | [SRC] Author-reported preservation. Independent preservation verification is **UNVERIFIABLE by scope**. This is a required qualification, not evidence of lost work. |

The historical documentation observations are supported at the execution pin. The parent’s later fixes are accepted as [SRC] context from the brief; this lens did not audit that later code or adjudicate held patches.

**COSMETIC correction**

At block line [SRC] **1079**, “The README’s `bsv-rs` seed command” could read “The `bsv-rs` seed option combination documented by the README” [SRC]. The README documents the options, but contains [M] **zero** literal `bsv-rs` command examples. This does not alter the execution verdict.

**Block parser header shape**

The observed input is a blockquoted level-three heading [SRC]:

```text
> ### S1 END BLOCK (2026-09-30T00:55:36Z)
```

Its shape is `> ### S1 END BLOCK (<UTC timestamp>)` [SRC]. The sitting number appears in the body. Parser implementation and acceptance behaviour are **UNVERIFIABLE**, because no parser source is allowed.

This report supplies the assigned fresh lens. No repository file was edited, no harness build or second execution was performed, and no tracker mutation or additional lens was launched.