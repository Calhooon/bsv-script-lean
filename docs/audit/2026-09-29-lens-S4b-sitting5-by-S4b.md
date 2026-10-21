[export: 2 lines withheld by tools/export_public.py, the sibling trees' lines; the original is in the private history]
**Lens report: S4b END BLOCK (2026-09-29T06:31:57Z), set 4 sitting 5**

## 1. Header

- **Block:** `### S4b END BLOCK (2026-09-29T06:31:57Z)` on `docs/lanes/harness.md`, lines 862–943. It landed at `a35b8b8` (pushed 06:32:28Z).
- **Read at:** `a35b8b8`, which was origin/main at the first fetch. During the lens, main moved to `2e0c10b`. That is S3's fold at 06:36:06Z: it applied the three patches, byte-identical to applying them at `a35b8b8` [X], and #51 and #52 were opened at 06:35:34Z. The block's page is unchanged at `2e0c10b` [X].
- **Lens model:** Opus (claude-opus-5-5), fresh context, read-only.
- **Reads:** 2026-09-29T06:33:58Z to 07:01:05Z.
- **What was executed:**
  - `cite_check.py` and `specgen.py --check`, read-only, in a scratch worktree with lazy fetch disabled (`remote.origin.promisor=false`, `GIT_ALLOW_PROTOCOL=file`). No pack, FETCH_HEAD or loose object was written in any partial clone [M].
  - `git apply --check`.
- **Not run:** `check_pins.py`, because it runs `cargo test`.
- The scratch worktree was removed. The advisories were read for state fields only.

## 2. Verdict

**HELD IN SUBSTANCE: 16 corrections (8 load-bearing, 8 cosmetic).**

## 3. Per-claim table

| # | claim | site | verdict | evidence |
|---|---|---|---|---|
[withheld at export: a sibling tree's line]
| 2 | branch cut from `5a34fc1` | header | HELD | `8c1c2ab`'s parent is `5a34fc1` [X] |
| 3 | no context compaction | header | HELD | transcript: 0 compact summaries, no compact boundary [M] |
| 4 | reads public or our advisories; nothing broadcast | header | HELD | reads.tsv has 59 lines, all GETs or public fetches. Besides reads, the run did only: pushes to our own repo, the #39 POST the paste asked for, and ssh reads of the box lock. No broadcast [M] |
| 5 | classified nothing, ruled nothing | header | HELD | `f155f43..a35b8b8` touches no harness/, corpus/, lean/ or parent file [X] |
| 6 | on main `f155f43..f601f19`, pushed 06:29:33 UTC | FOR THE PARENT | HELD | activity API: push `f155f43..f601f19` at 06:29:33Z [LIT] |
| 7 | leg of record GREEN at `df50b6d`, twenty-one legs, 689 s | FOR THE PARENT, (a) | HELD (as recorded; not re-run) | record: commit df50b6d, wall 689s, status GREEN. All 21 legs of `tools/check.sh`'s header have their verdict lines [X]. Run log: GREEN, rc 0 [M] |
| 8 | recon.md, record, index rows (STATE §3, records/README, PROVENANCE §6, lines added only), commit `590c386` | (a) | HELD | numstat 15/0, 1/0, 1/0; the STATE row is at :79, inside §3 [X] |
| 9 | cite_check.py's HISTORY_PREFIX gains docs/recon.md | (a) | HELD | diff +5/−3, docstring included [X] |
| 10 | -14's `go.mod:12` pins GoBDK `4eab3ac` | (a) trace | HELD | `v1.2.5-0.20260918043653-4eab3acdbbb9`; no replace directive for it [SRC] |
| 11 | "whose two archives carry the SV block" | (a) trace, :879 | PARTIAL | there are **three** archives; all three carry 1.2.2 · v1.2.2 · 879fc8b42 · 2026-04-28 07:23:20 +0100, twice each. sha256: darwin_arm64 30b386fe…, linux_x86_64 f5421d02… (both match the record), linux_aarch64 70f66d4d… [X] |
| 12 | CalculateFlags is the pin's line for line; reference parameters on every chain but STN | (a) :880 | HELD IN SUBSTANCE | the only diff is the local variable vs the member [X]. The constructor is at :333–337; the registry defers to `CreateChainParams` (chainparams_bdk.cpp:23–30) [SRC]. See correction 13 |
| 13 | mainnet heights unchanged | (a) | HELD | go-chaincfg params.go:252–277 is identical at all 7 tags from v1.5.8 to v1.7.0 [X]; 620,538 / 943,816 at :276–277 [SRC] |
| 14 | the wrapper's new branches route only non-verdicts | (a) | HELD | ScriptVerifierGoBDK.go +91/−6, lines 1–314 identical. ABI error, out-of-range DoS code and unknown domain now go to PROCESSING [X]. txerror.h at 4eab3ac says so [SRC] |
| 15 | maxscriptsizepolicy 100,000,000 from beta-12 (2026-08-31), policy only | (a) | HELD | settings.go: :102 at v0.15.9 and -1, :107 at -2 to -11 (500,000); :108 at -12 to -14 (100,000,000) [SRC]. beta-12 published 08:14:01Z [LIT]. configscriptpolicy.cpp:112–122 [SRC] |
| 16 | answer none until v0.16.0 is Latest | (a) | HELD | releases/latest is v0.15.9 [LIT] |
| 17 | GHSA-q2qf: triage, not accepted, updated = created = 2026-09-28T11:36:57Z, published_at null, global 404 | (a) | HELD | REST at 06:44:18Z: unchanged [LIT] |
| 18 | "no maintainer action in 18 h 1 min" | (a) | HELD | 05:38:17Z minus 11:36:57Z = 18 h 1 min 20 s [D] |
| 19 | npm latest still 2.8.10 | (a) | HELD | dist-tags.latest 2.8.10 [LIT] |
| 20 | PRIVATE stays; conformance.py needs no edit | (a) | HELD | go-sdk 8 classes, ts-sdk 1; unchanged from `27d93f7` to `a35b8b8` [X] |
| 21 | GHSA-rh54: draft (accepted 2026-09-25), unpublished, `<= 1.6.0` | (a) | HELD | draft, accepted true, created 18:26:42Z, updated 18:47:49Z on 09-25, published null, patched none [LIT]; the acceptance date is inferred from updated_at [D] |
| 22 | lock taken 06:12:45Z after 718 s in FIFO, released 06:24:14Z | (a) | HELD | run log lines 10 and 1019 [M]; 06:12:45 + 689 s = 06:24:14 [D] |
| 23 | main moved: S1's #35, S2's DESIGN, W0's pre-push, S3's `f155f43` | (a) | HELD | `27d93f7..f155f43`: 892eaff, a210516, d3a73e0, 1630e42, 8e2e6ba, 95356ae, f155f43, with those paths [X] |
| 24 | eighteen legs on S1's GREEN leg at `f3ded51`; `git diff --quiet` with the excludes exits 0 | (a) | HELD | exit 0 [X]. S1's record is GREEN, 172 s [X]. 21 − 3 = 18 [D]. No leg program read found for the excluded paths [X, grep] |
| 25 | spec, pins and cite legs GREEN locally at `2baa048` | (a) | PARTIAL | spec: "OK (117 files up to date; 0 rules flagged)" [X]. cite: the record's line reproduced exactly (4399, 1731 anchored, MOVED 0, unanchored 87, orphan rows 4) [X]. pins (75 sites): UNVERIFIABLE |
| 26 | `2baa048` is on origin/harness-b-recon-legtree | (a) | HELD | ls-remote [X] |
| 27 | comment 5884950025 at 06:31:13Z: two done, two owed, the STN Finding | (a) | HELD | REST [LIT] |
| 28 | bitcoin-sv: nothing after v1.2.2 | (b) | HELD | 32 releases, 33 tags, newest v1.2.2 = 879fc8b42; pushed_at 2026-04-28T07:04:50Z [LIT] |
| 29 | "bsv-rs: nothing after 0.3.30 (one open docs PR, #36)" | (b) :896 | PARTIAL | no release after 0.3.30 [LIT]. #36 was open at the read, merged 05:40:46Z, before the stamp; #37 merged 06:14:20Z [LIT] |
| 30 | Teranode Latest v0.15.9; -13/-14 move GoBDK; go-chaincfg v1.6.2 since -12 | (b) | HELD | [LIT], [SRC] |
| 31 | go-sdk v1.7.0 (2026-09-28): the signature hash moved at v1.6.0, the interpreter at v1.7.0 | (b) | HELD | signaturehash.go +113/−24; Chronicle 0x20 new; no interpreter file changed at v1.6.0; thread.go +25/−2 [X]. Dates [LIT] |
| 32 | @bsv/sdk 2.8.10; the engine moved only at 2.8.8, GHSA-622h's patch | (b) | HELD | the version-to-commit map reproduced. Only `6f3427e5b` touches the engine: Spend.ts +180/−66, TransactionSignature.ts +69/−7, ScriptResourceLimitError.ts +2/−2 [X]. GHSA-622h: published 2026-09-26T01:50:03Z, medium, `<= 2.8.7`, patched 2.8.8 [LIT] |
| 33 | STN gap: CStnParams never assigns BIP65/66/CSV heights at v1.2.2 | (b) | HELD | :1195–1304 assigns only :1212/:1225/:1228/:1231/:1234/:1236. params.h has no initializers; chainparams.h:115; `new CStnParams()` at :1603; no other non-test assignment [SRC] |
| 34 | "v0.16.0-beta" names no tag | (b) | HELD | 231 tags, none of that name [LIT] |
| 35 | done-bar: two done, two owed; entry 2 by 2026-10-29 | (b), (c) | HELD | issue body and comment 5800569085 [LIT]; +1 month [D] |
| 36 | #43 at `5a34fc1`: 81 unanchored, `--propose` 70 rows, 3 orphans | (c) | HELD | [X] |
| 37 | Standard.lean 31, Params.lean 14, CONFORMANCE 10, lean.md 9, TxPolicy.lean 7, and others; all other windows' citations | (c) | HELD | `--list` counts [X]; blame shows S3's and S1's commits [X] |
| 38 | "Ask 1's PARAMETERS patch adds 8 more" | (c) :913 | NOT HELD | nine; correction 1 [X] |
| 39 | go-chaincfg v1.6.2 regtest 100 / 200 | (c) | HELD | params.go:475–476 [SRC] |
| 40 | A16 waits on `35fc7bc` | (d) | HELD | not an ancestor of a35b8b8 or 2e0c10b; on origin/s3-a16 [X] |
| 41 | the three patches' sha256 | (e) | HELD | beea42ec…, 65eb9f27…, 4fcd55a0… reproduced from the fenced blocks [X] |
| 42 | `git apply --check` exit 0 at `5a34fc1` and `2baa048` | (e) | HELD | exit 0 at 5a34fc1, 69808ee, f155f43, 2baa048 and a35b8b8 [X] |
| 43 | `f155f43` re-cut two other §5 findings of PARAMETERS | (e) | HELD | two hunks, at :167 and :175, inside §5 (164–187) [X] |
| 44 | the cite leg stays GREEN with the docs patches applied | (e) | HELD | GREEN, MOVED 0 at 5a34fc1 and at a35b8b8 with the patches; other-version goes 71 → 72 [X] |
| 45 | ask 2's versions, dates, the §1 sites, unpublished at 05:52 | (e) | HELD | [LIT]; PROVENANCE:19–20 [X] |
| 46 | no Modal app of this window at 06:31; $0 | (f) | HELD | the run's own `block.sh` output at 06:31:25Z lists no S4b app [M] |
| 47 | uptime, git status, df, stamp; ≤ 20,000 characters | tail | HELD | uptime and stamp captured by the run's own command at 06:31:55Z [M]; df is identical now [M]; 9,408 characters [X] |
| 48 | record §2.1: develop `564af5c` (2026-01-08), dev `d9361a2` (2022-03-04) | record | HELD | [LIT] |
| 49 | record §2.2: go.mod table at every tag | record | HELD | [SRC] |
| 50 | record §2.2: the Policy block's "29 lines" | record :74 | PARTIAL | correction 4 [X] |
| 51 | record §2.2: TxValidator.go +141/−18; cdfa781 :903 and :1060 | record | HELD | [X], [SRC] |
| 52 | record §2.3: GoBDK @latest v1.2.4 (05-07); master `4eab3ac`; 61 commits, 170 files, +15,039/−1,155; BDK block c10755d; the pin's 1.2.4 · 85cf62c | record | HELD | [LIT] compare; [X] strings |
| 53 | record §2.3: cdfa781 CalculateFlags at `:575–597` | record :112 | NOT HELD | correction 5 [SRC] |
| 54 | record §2.4: go-chaincfg dates; v1.7.0 = 64143050…; params.go 5+/5−; 198ccf6 = v1.6.2; baee55b = v1.6.0; STN :384–386 = 1351/1251/0 | record | HELD | [LIT], [SRC] |
| 55 | record §2.5: "none yanked" | record :151 | NOT HELD | correction 8 [LIT] |
| 56 | record §2.6 and §2.7: shas, :2008 and :2285 in opcodeCheckSig and opcodeCheckMultiSig, the f810a16 quote, newest ts-stack tag | record | HELD | [LIT], [SRC], [X] |
| 57 | record §4a: the consumer lines; main, test and regtest assign all three | record | HELD | [SRC] |
| 58 | record §4a: the lint is suppressed at `:15` | record :282 | NOT HELD | correction 6 [SRC] |
| 59 | record §4d: "PARAMETERS §2's row" | record :321 | NOT HELD | correction 7 [SRC] |
| 60 | record §5 and §6: byte-identical at `69808ee`; the read list | record | HELD | exit 0 [X]; matches reads.tsv [M] |
| 61 | landing record items 3, 5 and 6; sampler 6.38 / 4.37; box totals 37 manifests, 68,080 entries, 4,147 divergent | landing and box records | HELD | [X], [M], [D] |
| 62 | D135: ts-stack's draft stays off main | D135 record | HELD | the draft's file exists only on origin/harness-b-d135 (names only, no content read) [X] |

## 4. Corrections

1. **"Ask 1's PARAMETERS patch adds 8 more, at the pins."** (block (c), :913). Also "the 8 new citations are mine to anchor" (ask 1's cost, :928) and "the STN finding's eight file:line citations" (record §5, :332).
   - Right value: **nine** unanchored citations (8 into bitcoin-sv v1.2.2, 1 into go-chaincfg v1.5.8), plus one other-version citation.
   - Evidence: unanchored 81 → 90 at 5a34fc1 and 88 → 97 at a35b8b8 with the patches applied [X].
   - **LOAD-BEARING.**

2. **"whose two archives carry the SV block"** (block :879) and "Both of its archives carry" (comment 5884950025).
   - Right value: `4eab3ac` ships **three** archives: darwin_arm64, linux_aarch64 and linux_x86_64 (darwin_x86_64 was dropped at c10755d). All three carry the SV block [X].
   - **LOAD-BEARING** (a count; the conclusion gets stronger).

3. **The block's own citation, "it came at v0.16.0-beta-12, 2026-08-31, `settings/settings.go:108`"** (block :926).
   - The cite leg reads it at the pin v0.15.9, where line 108 is `MaxStackMemoryUsageConsensus`, and counts it unanchored [X].
   - Right value: write "`settings/settings.go:108` at v0.16.0-beta-12" so the leg classifies it other-version.
   - **LOAD-BEARING.**

4. **"The `Policy` block's 29 lines (v0.15.9 `:92–120`, -14 `:98–126`)"** (record §2.2, :74).
   - Right value: **34 lines, `:92–125` and `:98–131`**. The whole block still differs in that one line alone [X].
   - **LOAD-BEARING.**

5. **"`cdfa781`'s (`:575–597`)"** (record §2.3, :112).
   - Right value: **`:575–598`** [SRC].
   - **LOAD-BEARING.**

6. **"the lint for exactly that is suppressed at `:15`"** (record §4a, :282).
   - Right value: the NOLINTNEXTLINE is at **`:16`**; the struct opens at :17; BIP65Height, BIP66Height and CSVHeight are at :24, :26 and :28 [SRC]. The range `15–28` (in recon.md, the Finding and PARAMETERS on main) is cosmetic; `16–28` would be tighter.
   - **LOAD-BEARING** (the `:15` citation).

7. **"`docs/PARAMETERS.md` §2's row already carries v1.6.2's values"** (record §4d, :321).
   - Right value: the row is **§3's**, line 158 at a35b8b8 [SRC].
   - **LOAD-BEARING.**

8. **"none yanked"** (record §2.5, :151).
   - Right value: **0.3.21 is yanked** (published 2026-09-09); none after it is [LIT].
   - **LOAD-BEARING** (the claim is wrong, but no answer changes).

9. **"(one open docs PR, #36)"** (block (b), :896).
   - True at the read (05:38:57Z). By the stamp, #36 had merged (05:40:46Z) and #37 had merged (06:14:20Z); main is `25165cd`; still no release [LIT].
   - **COSMETIC.**

10. **"the sequence locks (`:3466`, `:6001`)"** (comment 5884950025, the Finding).
    - `:6001` is BIP113's median-time-past lock time; only `:3466` is the sequence locks [SRC].
    - **COSMETIC.**

11. **"with the landing rule for the three rebases (`docs/records/20260929-061245-make-check-box.txt`)"** (FOR THE PARENT, :869).
    - The landing rule is in `20260929-062722-recon-landing-s4b.txt`; the cited record holds only the leg [X].
    - **COSMETIC.**

12. **"STN's `requireStandard` is now false (`:341`)"** (record :118).
    - It is now set explicitly; the value is unchanged. At the pin it came from CStnParams' `fRequireStandard = false` (chainparams.cpp:1271) [SRC].
    - **COSMETIC.**

13. **"the reference's own parameters on every chain but STN"** (block :880; record :242; recon.md step 3).
    - That holds for the reference's chains. BDK's two registered Teranode chains (teratestnet, tstn) use BDK's own tables (chainparams_bdk.cpp:23–30, 111–112). Mainnet is as stated [SRC].
    - **COSMETIC.**

14. **"scratch repositories … which borrow the shared clones' objects"** (PROVENANCE §6, :221).
    - Only four of the six borrow. go-chaincfg and BDK were cloned fresh [X].
    - **COSMETIC.**

15. **The comment's done-bar paraphrase "(the re-cut of 2026-09-23: … the recon log's entry 1; …)"** (comment 5884950025).
    - It drops the issue body's definition: "the pin's week: go-sdk 1.2.24 → 1.5.2, @bsv/sdk 2.7.1 → 2.8.0". Entry 1 carries the pin's week only by reference, in its Scope paragraph [LIT].
    - **COSMETIC.**

16. **"S4b's spend: $0 `[M]`"** (block (f), :938).
    - The [M] names no record, as RULES-SUB (4) requires. The landing record's "THE HOST AND THE MONEY" line carries $0 and could be cited [X].
    - **COSMETIC.**

## 5. Omissions

- **Parts and form:**
  - All six parts are present, with uptime, git status, df and the stamp. The block is 9,408 characters.
  - Many figures carry no label (689 s, 718 s, 18 h 1 min, 81/70/3, the per-site counts), although each comes from a named record (RULES-SUB (4)).
[withheld at export: a sibling tree's line]
- **(c) #43:** the block's own new unanchored citation (correction 3) is not listed.
- **The trace:** it read two of GoBDK's three archives. This lens read the third: same block.
- **The paste:**
  - Items (1) and (2) are answered in full.
  - The parked items are untouched. There was no `make check-modal`, no CLAUDE.md edit and no private text on main.
  - The #39 comment followed the landing (06:29:33Z, then 06:31:13Z).
- **Not verifiable by this lens:**
  - The pins leg's "75 sites" (it runs `cargo test`).
  - "effort max" (only the parent's note).
  - The box record's byte-identity with the box copy (no ssh).
