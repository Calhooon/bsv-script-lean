# The citation pass of 2026-10-15 (#43), S3

[M] 2026-10-15 03:37 UTC, the citation lane of #43 (Claude Opus 5.5, on the Studio; its branch named in the commit subjects), under the owner's words of 2026-10-14 23:2xZ. The pass the lenses of #90 and #97 deferred to the landing: `python3 tools/cite_check.py --propose --write` over the active pages, so that every citation the tool resolves to one pinned file of `docs/PROVENANCE.md` §1a at the pin has a row of the table in `tools/cite_check.py`, or a hold by name (`HELD`, `HELD_PASS`, and since the fix lane `HELD_DISCRETION`), and a moved line turns the cite leg RED.

- Base: `origin/main` at `77a68cba`.
- The table's commit: `d76304b0` (S4b's file, S4b's tag): 3,639 rows proposed and written (2,990 `text`, 649 `sym`), 507 orphan rows dropped (rows whose citation had left its page; none of them a closed-history site: the tool's count of excluded rows reads 0), 4,541 rows after (1,409 before); a hold list `HELD_PASS` of 270 (site, citation) pairs beside the existing `HELD` of 11, one shared reason, read by `--propose` exactly as `HELD` is.
- The fix lane after the lens (lane fix-anchor-cite, commit `96868e9c`, S4b's tag): 84 further (site, citation) pairs held by name in `HELD_DISCRETION`, one reason, "held under the node team's discretion request" (64 by the lane brief's cited-line test, 20 more by its anchor-word test), their 84 rows removed (77 written by the pass, 7 from before it): 4,457 rows after.
- The closed history the tool skips by name before opening (`docs/records/`, `docs/audit/`, `docs/BLOCKS-ARCHIVE.md`, `docs/security/`, `docs/recon.md`): 356 files at d76304b0 (357 at 76cded76, this record among them), not opened, not written.
- No page, Lean file or docstring changed: the pass writes only the table, so `spec/` is unchanged and no Lean build is owed.

## The leg, before and after [X]

Before, at `77a68cba`:

    cite_check: excluded files [D] 356; closed to model turns, not opened; excluded anchor rows [D] 0 (retained, not scanned)
    cite_check: 7062 citations found in lean/ and docs/ (7049 `file:line` shapes, a `/`-list counted per line); anchored and holding at the pin 1198, MOVED 0; not anchored (reported, never RED): unanchored 5061, beyond-eof 1, unresolved 0, ambiguous 31, unpinned 0, other-version 156, self 521, history 0, absent 94, orphan rows 507; skipped 0; sources absent here: predecessor-lean: clone absent: $PREDECESSOR_LEAN_CLONE
    cite_check: GREEN (every checked active anchor holds at the pin; closed history is not checked)

After, at `d76304b0` (the same lines at this record's commit):

    cite_check: excluded files [D] 356; closed to model turns, not opened; excluded anchor rows [D] 0 (retained, not scanned)
    cite_check: 7062 citations found in lean/ and docs/ (7049 `file:line` shapes, a `/`-list counted per line); anchored and holding at the pin 5765, MOVED 0; not anchored (reported, never RED): unanchored 494, beyond-eof 1, unresolved 0, ambiguous 31, unpinned 0, other-version 156, self 521, history 0, absent 94, orphan rows 0; skipped 0; sources absent here: predecessor-lean: clone absent: $PREDECESSOR_LEAN_CLONE
    cite_check: GREEN (every checked active anchor holds at the pin; closed history is not checked)

After the fix lane, at `96868e9c` (2026-10-15 10:43 UTC, exit 0):

    cite_check: excluded files [D] 357; closed to model turns, not opened; excluded anchor rows [D] 0 (retained, not scanned)
    cite_check: 7062 citations found in lean/ and docs/ (7049 `file:line` shapes, a `/`-list counted per line); anchored and holding at the pin 5627, MOVED 0; not anchored (reported, never RED): unanchored 632, beyond-eof 1, unresolved 0, ambiguous 31, unpinned 0, other-version 156, self 521, history 0, absent 94, orphan rows 0; skipped 0; sources absent here: predecessor-lean: clone absent: $PREDECESSOR_LEAN_CLONE
    cite_check: GREEN (every checked active anchor holds at the pin; closed history is not checked)

`--propose` at `96868e9c`: `0 rows proposed (Counter()), 0 orphan rows dropped, 4457 rows after`; findings 365 `held` (11 + 270 + 84), 102 `near-miss`, 1 `beyond-eof`.

After the third fix lane (the ruling on N3), on the S4b commit beside this record (2026-10-15 11:06 UTC, exit 0, the Studio at a 1-minute load near 25 for one sub-minute run):

    cite_check: excluded files [D] 357; closed to model turns, not opened; excluded anchor rows [D] 0 (retained, not scanned)
    cite_check: 7062 citations found in lean/ and docs/ (7049 `file:line` shapes, a `/`-list counted per line); anchored and holding at the pin 5605, MOVED 0; not anchored (reported, never RED): unanchored 654, beyond-eof 1, unresolved 0, ambiguous 31, unpinned 0, other-version 156, self 521, history 0, absent 94, orphan rows 0; skipped 0; sources absent here: predecessor-lean: clone absent: $PREDECESSOR_LEAN_CLONE
    cite_check: GREEN (every checked active anchor holds at the pin; closed history is not checked)

`--propose` there: `0 rows proposed (Counter()), 0 orphan rows dropped, 4439 rows after`; 102 `held` findings under the discretion reason, no `held entry spent`.

`python3 tools/cite_check.py --propose` after the pass: `0 rows proposed (Counter()), 0 orphan rows dropped, 4541 rows after`; findings 281 `held` (11 + 270), 102 `near-miss`, 1 `beyond-eof` (`lean/BsvChain/Teranode/Spend.lean:889` cites `batcher.go:743-790` and the file has 733 lines at the pin: the page owner's to re-cut). A near-miss row is written at the lines as its page states them, so it holds and catches a move; the page's range may still sit a few lines off its symbol (the class #43's Why names), the page owners' worklist by `--propose`.

## Per directory (citation occurrences, a `/`-list counted per line) [X]

The "held" columns count the class (the last two at `96868e9c`, after the fix lane) the leg prints as anchored and holding at the pin.

| directory | found | held before | held after | unanchored before | unanchored after | held after the fix | unanchored after the fix |
|---|---|---|---|---|---|---|---|
| `docs` (the top-level pages) | 3041 | 397 | 2535 | 2432 | 294 | 2519 | 310 |
| `docs/history` | 210 | 0 | 5 | 7 | 2 | 5 | 2 |
| `docs/lanes` | 404 | 83 | 117 | 68 | 34 | 116 | 35 |
| `lean` (the root files) | 9 | 0 | 0 | 0 | 0 | 0 | 0 |
| `lean/BsvChain` | 2042 | 0 | 1925 | 1956 | 31 | 1817 | 139 |
| `lean/BsvScript` | 1068 | 593 | 927 | 451 | 117 | 921 | 123 |
| `lean/Bsvs` | 78 | 19 | 68 | 56 | 7 | 67 | 8 |
| `lean/Test` | 210 | 106 | 188 | 91 | 9 | 182 | 15 |
| total | 7062 | 1198 | 5765 | 5061 | 494 | 5627 | 632 |

## The held list: 270 citations left unanchored, with the reason [D]

The pass held, by name in `HELD_PASS`, every proposed row whose cited lines, path or citing sentence matched the lane brief's closed-topic filter; the leg counts each `unanchored` (reported, never RED). The filter is conservative: a held citation may well be unrelated, and its owner writes its row by `--propose` once the hold is lifted. The matched text was not read by this lane. Reason codes ({'S': 89, 'L': 84, 'W': 47, 'I': 50}):

- W: the cited file is the source file whose earlier rows the public edition withholds (tools/export_rewrite.txt, group d8-node-team-discretion)
- L: the cited lines' text or path matched the pass's closed-topic filter
- S: the citing sentence (the page line and its neighbours) matched the pass's closed-topic filter
- I: a cited range carrying a 64-bit integer line of bitcoin-sv's src/config.cpp, src/configscriptpolicy.cpp, src/script/, src/policy/policy.h or src/validation.cpp, or of go-sdk's script/interpreter/, held with the closed topics

The 11 entries of `HELD` (from 2026-09-29 and #54) stand as they were.

The fix lane's 84 (`HELD_DISCRETION`, [M] 2026-10-15 10:43 UTC): held under the node team's discretion request, named in `tools/cite_check.py` and not repeated here; the leg counts each `unanchored`. After it, a script over the table finds no row whose cited lines meet the brief's line test and no anchor carrying the words the brief's word test names (0 and 0).

**The criterion, ruled.** The captain's ruling on the second lens's N3 (2026-10-15 11:1xZ), applied by the third fix lane ([M] 2026-10-15 11:08 UTC): the hold's criterion is file-independent. Every row whose cited line range overlaps a v1.2.2 to v1.2.3 hunk of its file is held under the discretion request by name in `HELD_DISCRETION` (tools/cite_check.py), whatever the file and whether or not the brief's list of 15 files named it; `src/config.cpp` and `src/hash.h` are no exception. The 18 rows the second lens found outside the brief's list are held the way the 84 were (the same set, the same reason string, their 18 rows removed: 4,439 rows after), and `HELD_DISCRETION` goes from 84 to 102 pairs (counted from the set). The brief's list of 15 files, and the cited-line test of the third bullet above that read it, stay here as history, superseded by the file-independent criterion.

**The criterion, re-cut.** The captain withdrew ruling N3b (its commits 482b7ef1 and 29d7133d reverted by the fifth fix lane, [M] 2026-10-15 11:18 UTC) because it held every citation lying inside a held row's range, which is containment, not overlap with the change, and took 255 pairs with no relation to it. The criterion stands as ruled in N3: a row is held under the discretion request if its cited line range overlaps a hunk of the change between bitcoin-sv v1.2.2 and v1.2.3 in its file, read from the hunk headers alone, or if the brief's word test held it. The repo-wide pass [X] (the box, on this branch at the second revert): of the 190 files the two tags differ in, 30 are cited by the table; its 1,862 bitcoin-sv rows in those files were tested against the new-side ranges, and the rows pinned at v1.2.2 against the old side as well; 0 rows overlap either way, so 0 rows are held, the table stays at 4,439 rows and `HELD_DISCRETION` stays at 102 pairs (counted from the set). As a check on the test itself, it reports an overlap for 82 of the 102 held pairs (the brief's 64 by its cited-line test and the ruling's 18); the other 20 are the fix lane's anchor-word holds (above), held under the brief's word test, which neither ruling withdrew. The row `lean/BsvScript/Hash/Sha256.lean` citing `src/hash.h:24` does not overlap and stays anchored.

**The two tests, counted.** The captain's ruling on W2 of the second lens's round two, applied by the sixth fix lane ([M] 2026-10-15 11:29 UTC): the 20 anchor-word holds are not lifted; the brief's word test is a documented second criterion of the pass. The 102 pairs of `HELD_DISCRETION` stand under two tests: the overlap test 82 (the fix lane's 64 and the ruling's 18) and the word test 20 (the fix lane's), none under both and none under neither. The overlap test is now a script in the tree, `tools/discretion_overlap.py` (hunk headers only; counts only, the held pairs' ids not repeated in a record), its output the record [20261015-112926-discretion-overlap-s3.txt](20261015-112926-discretion-overlap-s3.txt) [X] (the Studio, at 81ccbf90): each pair's path and range read from the row it replaced (the fix lane's 84, by its set at 96868e9c, from 76cded76's table; the ruling's 18 from b06ceb2f's), 82 overlap and 20 do not, the same 82 with pure insertion and deletion points left out; the 20 are all the fix lane's, 1 pinned at v1.2.2, and their id list's digest equals the second lens's list of 20. Its table pass reproduces the paragraph above: 1,862 rows in 30 files, 195 pinned at v1.2.2, 0 overlapping. 81 against 82: the fifth fix lane's check is not in the tree and left no output, so the one pair it did not flag cannot be named; the script here and the second lens's own test (four readings) both give 82, and the 20 equal the word test's count and lie inside the fix lane's 84, so the 81 was a pair that check missed, not a pair held with no reason. The fix lane tagged no pair by test, so the 20's match to the word test is by count and by set (the lens's list), not by a tag.

Same span, held at one site and anchored at another (the filter works per citation; the lens's list, for the topic's owner; none of these anchors carries a 64-bit integer line): `configscriptpolicy.cpp:65–69` on docs/CONFORMANCE-ASSOCIATION-v122.md (held as `src/configscriptpolicy.cpp:65–69`, anchored as `configscriptpolicy.cpp:65–69`); `configscriptpolicy.cpp:397–412` (held at DESIGN-S6.md and Block.lean, anchored at BLOCK-CONSENSUS.md); `script.cpp:30–128` (held at docs/lanes/lean.md, anchored at TxRules.lean); `config.cpp:232–251` and `232-245` (held, while `225–250`, `230-247` at PROVENANCE and `232–246` at DESIGN-S6 are anchored); `config.cpp:2391-2418` (held, while `2410-2425` is anchored); `config.cpp:831–834` (held, while `825-834` is anchored); `script.cpp:102–115` (TxPolicy.lean) and `:102–116` (SigOps.lean) anchored, while `script.cpp:83–117` is held at docs/lanes/harness.md.

Weak anchors: 52 of the pass's 2,990 text rows anchor a line with no letter, digit or underscore at both ends (51 of the 2,914 standing after the fix; the lens counted 55 by its own test); a move onto a like line holds; the owners' worklist by `--propose` with a sym anchor. Some sym anchors come from a neighbouring citation's words (`script/interpreter/engine.go:60–96` anchors `WithFlags`, `thread.go:484–533` anchors `UTXO`).

| site | citation | reason |
|---|---|---|
| `docs/BLOCK-CONSENSUS.md` | `script/interpreter.cpp:2166–2202` | S |
| `docs/CONFORMANCE-2026-09-27.md` | `BigNumber.ts:625–629` | S |
| `docs/CONFORMANCE-2026-09-27.md` | `CHANGELOG.md:62–64` | S |
| `docs/CONFORMANCE-2026-09-27.md` | `CHANGELOG.md:70` | S |
| `docs/CONFORMANCE-2026-09-27.md` | `CHANGELOG.md:86` | L |
| `docs/CONFORMANCE-2026-09-27.md` | `Spend.ts:1048–1093` | S |
| `docs/CONFORMANCE-2026-09-27.md` | `Spend.ts:1191–1202` | S |
| `docs/CONFORMANCE-2026-09-27.md` | `Spend.ts:1710–1715` | S |
| `docs/CONFORMANCE-2026-09-27.md` | `Spend.ts:319–321` | S |
| `docs/CONFORMANCE-2026-09-27.md` | `Spend.ts:327–329` | S |
| `docs/CONFORMANCE-2026-09-27.md` | `Spend.ts:395–403` | L |
| `docs/CONFORMANCE-2026-09-27.md` | `Spend.ts:539–562` | S |
| `docs/CONFORMANCE-2026-09-27.md` | `Spend.ts:595–603` | S |
| `docs/CONFORMANCE-2026-09-27.md` | `Spend.ts:839` | S |
| `docs/CONFORMANCE-2026-09-27.md` | `Transaction.ts:548–553` | S |
| `docs/CONFORMANCE-2026-09-27.md` | `consensus.h:62–66` | L |
| `docs/CONFORMANCE-2026-09-27.md` | `flags.rs:493-512` | S |
| `docs/CONFORMANCE-2026-09-27.md` | `int_serialization.h:61–118` | W |
| `docs/CONFORMANCE-2026-09-27.md` | `interpreter.cpp:1741–1778` | S |
| `docs/CONFORMANCE-2026-09-27.md` | `interpreter.cpp:2259–2262` | S |
| `docs/CONFORMANCE-2026-09-27.md` | `interpreter.cpp:304–306` | S |
| `docs/CONFORMANCE-2026-09-27.md` | `interpreter.cpp:629–635` | S |
| `docs/CONFORMANCE-2026-09-27.md` | `module/gobdk/bdkcgo/version_cgo.h:22–23` | S |
| `docs/CONFORMANCE-2026-09-27.md` | `script/interpreter/config.go:22–31` | L |
| `docs/CONFORMANCE-2026-09-27.md` | `script/interpreter/config.go:34–40` | I |
| `docs/CONFORMANCE-2026-09-27.md` | `script/interpreter/number.go:184–195` | I |
| `docs/CONFORMANCE-2026-09-27.md` | `script/interpreter/operations.go:1071–1079` | S |
| `docs/CONFORMANCE-2026-09-27.md` | `script/interpreter/operations.go:2626–2651` | S |
| `docs/CONFORMANCE-2026-09-27.md` | `script/interpreter/options.go:176–194` | S |
| `docs/CONFORMANCE-2026-09-27.md` | `script/interpreter/stack.go:189–209` | I |
| `docs/CONFORMANCE-2026-09-27.md` | `script/interpreter/stack.go:35–63` | S |
| `docs/CONFORMANCE-2026-09-27.md` | `script/interpreter/thread.go:482–490` | S |
| `docs/CONFORMANCE-2026-09-27.md` | `script_num.cpp:303–317` | L |
| `docs/CONFORMANCE-2026-09-27.md` | `script_num.cpp:80–91` | L |
| `docs/CONFORMANCE-2026-09-27.md` | `spend.rs:499-505` | S |
| `docs/CONFORMANCE-2026-09-27.md` | `spend.rs:523–529` | S |
| `docs/CONFORMANCE-ASSOCIATION-v122.md` | `src/configscriptpolicy.cpp:65–69` | I |
| `docs/DESIGN-S6.md` | `config.cpp:2417–2420` | I |
| `docs/DESIGN-S6.md` | `configscriptpolicy.cpp:397–412` | I |
| `docs/DESIGN-S6.md` | `src/validation.cpp:2557–2559` | L |
| `docs/DESIGN-S6.md` | `txmempool.h:423` | L |
| `docs/DESIGN.md` | `int_serialization.h:154–208` | W |
| `docs/DESIGN.md` | `int_serialization.h:61–118` | W |
| `docs/DESIGN.md` | `interpreter.cpp:1718–1721` | S |
| `docs/DESIGN.md` | `script_num.cpp:166–167` | L |
| `docs/DESIGN.md` | `script_num.cpp:230` | L |
| `docs/DESIGN.md` | `script_num.cpp:311–314` | L |
| `docs/DESIGN.md` | `script_num.cpp:371` | L |
| `docs/DESIGN.md` | `script_num.cpp:406–417` | L |
| `docs/DESIGN.md` | `script_num.cpp:452–457` | L |
| `docs/DESIGN.md` | `script_num.cpp:53–91` | L |
| `docs/DESIGN.md` | `script_num.cpp:72–90` | L |
| `docs/DESIGN.md` | `script_num.cpp:80–91` | L |
| `docs/DESIGN.md` | `validation.cpp:78` | S |
| `docs/HYPOTHESES.md` | `int_serialization.h:61–118` | W |
| `docs/HYPOTHESES.md` | `script_num.cpp:80–91` | L |
| `docs/PARAMETERS.md` | `configscriptpolicy.cpp:47` | S |
| `docs/PARAMETERS.md` | `init.cpp:3158–3160` | S |
| `docs/PARAMETERS.md` | `int_serialization.h:61–118` | W |
| `docs/PARAMETERS.md` | `interpreter.cpp:1708–1721` | L |
| `docs/PARAMETERS.md` | `rpc/misc.cpp:697–702` | S |
| `docs/PARAMETERS.md` | `rpc/misc.cpp:855–856` | S |
| `docs/PARAMETERS.md` | `script_num.cpp:80–91` | L |
| `docs/PARAMETERS.md` | `settings/settings.go:104` | S |
| `docs/PARAMETERS.md` | `settings/settings.go:115` | L |
| `docs/PARAMETERS.md` | `sighash.rs:878` | S |
| `docs/PARAMETERS.md` | `src/config.cpp:232–251` | I |
| `docs/PARAMETERS.md` | `src/config.cpp:2417–2420` | I |
| `docs/PARAMETERS.md` | `src/config.cpp:2602–2610` | I |
| `docs/PARAMETERS.md` | `src/config.cpp:831–834` | I |
| `docs/PARAMETERS.md` | `src/config.cpp:872–879` | I |
| `docs/PARAMETERS.md` | `src/configscriptpolicy.cpp:397–405` | I |
| `docs/PARAMETERS.md` | `src/configscriptpolicy.cpp:45` | S |
| `docs/PARAMETERS.md` | `src/configscriptpolicy.cpp:46` | L |
| `docs/PARAMETERS.md` | `src/configscriptpolicy.cpp:47` | S |
| `docs/PARAMETERS.md` | `src/policy/policy.h:147` | I |
| `docs/PARAMETERS.md` | `src/policy/policy.h:156` | L |
| `docs/PARAMETERS.md` | `src/policy/policy.h:187` | S |
| `docs/PARAMETERS.md` | `src/policy/policy.h:93` | S |
| `docs/PARAMETERS.md` | `src/script/standard.h:46` | I |
| `docs/PARAMETERS.md` | `src/txmempool.h:423` | L |
| `docs/PARAMETERS.md` | `src/validation.cpp:1328–1348` | S |
| `docs/PARAMETERS.md` | `validation.cpp:2701` | S |
| `docs/PROVENANCE.md` | `Spend.ts:1174–1179` | S |
| `docs/PROVENANCE.md` | `Spend.ts:2026–2052` | S |
| `docs/PROVENANCE.md` | `Spend.ts:2058–2109` | S |
| `docs/PROVENANCE.md` | `Spend.ts:261–317` | S |
| `docs/PROVENANCE.md` | `Spend.ts:319–321` | S |
| `docs/PROVENANCE.md` | `Spend.ts:327–374` | S |
| `docs/PROVENANCE.md` | `Spend.ts:395–403` | L |
| `docs/PROVENANCE.md` | `config.go:25–40` | L |
| `docs/PROVENANCE.md` | `int_serialization.h:61–118` | W |
| `docs/PROVENANCE.md` | `interpreter.cpp:1807–1809` | L |
| `docs/PROVENANCE.md` | `script_num.cpp:80–91` | L |
| `docs/PROVENANCE.md` | `src/config.cpp:232-245` | I |
| `docs/PROVENANCE.md` | `src/config.cpp:2391-2418` | I |
| `docs/PROVENANCE.md` | `src/config.cpp:2440-2465` | I |
| `docs/PROVENANCE.md` | `src/config.cpp:2440-2475` | I |
| `docs/PROVENANCE.md` | `src/config.cpp:2440-2490` | I |
| `docs/PROVENANCE.md` | `src/config.cpp:2440-2505` | I |
| `docs/PROVENANCE.md` | `src/config.cpp:2520-2552` | I |
| `docs/PROVENANCE.md` | `src/config.cpp:411-421` | I |
| `docs/PROVENANCE.md` | `src/configscriptpolicy.cpp:164-308` | I |
| `docs/PROVENANCE.md` | `src/configscriptpolicy.cpp:390-415` | I |
| `docs/PROVENANCE.md` | `src/configscriptpolicy.cpp:397-419` | I |
| `docs/PROVENANCE.md` | `src/configscriptpolicy.cpp:415-440` | I |
| `docs/PROVENANCE.md` | `transaction/ScriptVerificationBackend.ts:9–27` | S |
| `docs/STATE-OF-THE-WORLD.md` | `chainparams.cpp:1038` | S |
| `docs/STATE-OF-THE-WORLD.md` | `chainparams.cpp:1463` | S |
| `docs/STATE-OF-THE-WORLD.md` | `int_serialization.h:61–118` | W |
| `docs/STATE-OF-THE-WORLD.md` | `policy.h:175–244` | S |
| `docs/STATE-OF-THE-WORLD.md` | `script_num.cpp:163–167` | L |
| `docs/STATE-OF-THE-WORLD.md` | `script_num.cpp:250–374` | L |
| `docs/STATE-OF-THE-WORLD.md` | `script_num.cpp:311–318` | L |
| `docs/STATE-OF-THE-WORLD.md` | `script_num.cpp:80–91` | L |
| `docs/STATE-OF-THE-WORLD.md` | `validation.cpp:2693–2701` | S |
| `docs/STATE-OF-THE-WORLD.md` | `validation.cpp:2859` | S |
| `docs/STATE-OF-THE-WORLD.md` | `validation.cpp:6038–6046` | S |
| `docs/WRITE-UP.md` | `bdk/module/gobdk/script/scripterror.go:86` | S |
| `docs/WRITE-UP.md` | `int_serialization.h:61–118` | W |
| `docs/WRITE-UP.md` | `script_num.cpp:80–91` | L |
| `docs/WRITE-UP.md` | `src/chainparams.cpp:1195–1304` | S |
| `docs/WRITE-UP.md` | `src/chainparams.cpp:28` | S |
| `docs/WRITE-UP.md` | `src/consensus/params.h:15–28` | S |
| `docs/WRITE-UP.md` | `src/script/script_error.cpp:100` | S |
| `docs/WRITE-UP.md` | `src/script/script_error.h:80` | S |
| `docs/WRITE-UP.md` | `src/validation.cpp:2524–2544` | S |
| `docs/WRITE-UP.md` | `src/validation.cpp:2973–2982` | S |
| `docs/WRITE-UP.md` | `src/validation.cpp:3473` | I |
| `docs/WRITE-UP.md` | `src/verify_script_flags.cpp:38` | S |
| `docs/WRITE-UP.md` | `src/verify_script_flags.cpp:39` | S |
| `docs/history/lens-03-spec-pages-2026-09-25.md` | `spend.rs:57` | S |
| `docs/lanes/harness.md` | `init.cpp:2339` | S |
| `docs/lanes/harness.md` | `int_serialization.h:61–118` | W |
| `docs/lanes/harness.md` | `policy.h:247–255` | S |
| `docs/lanes/harness.md` | `script.cpp:83–117` | S |
| `docs/lanes/harness.md` | `src/script/int_serialization.h:61–118` | W |
| `docs/lanes/harness.md` | `validation.cpp:1242` | S |
| `docs/lanes/harness.md` | `validation.cpp:1244` | S |
| `docs/lanes/harness.md` | `validation.cpp:462–493` | I |
| `docs/lanes/harness.md` | `validation.cpp:5983–5988` | S |
| `docs/lanes/lean.md` | `policy.h:175–244` | S |
| `docs/lanes/lean.md` | `policy.h:177–189` | S |
| `docs/lanes/lean.md` | `script.cpp:30–128` | I |
| `docs/lanes/lean.md` | `script.cpp:47–69` | S |
| `docs/lanes/lean.md` | `script.h:202–224` | S |
| `docs/lanes/lean.md` | `script_num.cpp:152–206` | L |
| `docs/lanes/lean.md` | `script_num.cpp:246` | L |
| `docs/lanes/lean.md` | `script_num.cpp:53–91` | L |
| `docs/lanes/lean.md` | `validation.cpp:2693–2701` | S |
| `docs/lanes/lean.md` | `validation.cpp:462–493` | I |
| `docs/lanes/lean.md` | `validation.cpp:526–568` | S |
| `lean/BsvChain/Block.lean` | `src/config.cpp:831–834` | I |
| `lean/BsvChain/Block.lean` | `src/configscriptpolicy.cpp:397–412` | I |
| `lean/BsvChain/Block.lean` | `src/script/script.cpp:228–245` | I |
| `lean/BsvChain/Eras.lean` | `src/config.cpp:232–246` | I |
| `lean/BsvChain/Mempool.lean` | `src/config.cpp:2417–2420` | I |
| `lean/BsvChain/Mempool.lean` | `src/configscriptpolicy.cpp:397–412` | I |
| `lean/BsvChain/Mempool.lean` | `src/txmempool.h:423` | L |
| `lean/BsvChain/Params.lean` | `src/config.cpp:232–251` | I |
| `lean/BsvChain/Params.lean` | `src/config.cpp:2417–2420` | I |
| `lean/BsvChain/Params.lean` | `src/config.cpp:2602–2610` | I |
| `lean/BsvChain/Params.lean` | `src/config.cpp:831–834` | I |
| `lean/BsvChain/Params.lean` | `src/config.cpp:872–879` | I |
| `lean/BsvChain/Params.lean` | `src/configscriptpolicy.cpp:397–405` | I |
| `lean/BsvChain/Params.lean` | `src/txmempool.h:423` | L |
| `lean/BsvChain/Teranode/Subtree.lean` | `model/subtree_body_shape.go:45-57` | S |
| `lean/BsvChain/Teranode/Subtree.lean` | `src/consensus/merkle.cpp:263-271` | S |
| `lean/BsvChain/Teranode/Subtree.lean` | `src/consensus/merkle.cpp:312-319` | S |
| `lean/BsvScript/Flags.lean` | `config.cpp:2584–2590` | I |
| `lean/BsvScript/Numbers.lean` | `int_serialization.h:110–114` | W |
| `lean/BsvScript/Numbers.lean` | `int_serialization.h:117` | W |
| `lean/BsvScript/Numbers.lean` | `int_serialization.h:120–152` | W |
| `lean/BsvScript/Numbers.lean` | `int_serialization.h:124–127` | W |
| `lean/BsvScript/Numbers.lean` | `int_serialization.h:131–150` | W |
| `lean/BsvScript/Numbers.lean` | `int_serialization.h:134–137` | W |
| `lean/BsvScript/Numbers.lean` | `int_serialization.h:139–144` | W |
| `lean/BsvScript/Numbers.lean` | `int_serialization.h:144–146` | W |
| `lean/BsvScript/Numbers.lean` | `int_serialization.h:154–208` | W |
| `lean/BsvScript/Numbers.lean` | `int_serialization.h:162–166` | W |
| `lean/BsvScript/Numbers.lean` | `int_serialization.h:170–174` | W |
| `lean/BsvScript/Numbers.lean` | `int_serialization.h:177–180` | W |
| `lean/BsvScript/Numbers.lean` | `int_serialization.h:183–186` | W |
| `lean/BsvScript/Numbers.lean` | `int_serialization.h:189–193` | W |
| `lean/BsvScript/Numbers.lean` | `int_serialization.h:195–198` | W |
| `lean/BsvScript/Numbers.lean` | `int_serialization.h:205–207` | W |
| `lean/BsvScript/Numbers.lean` | `int_serialization.h:61–118` | W |
| `lean/BsvScript/Numbers.lean` | `int_serialization.h:75–107` | W |
| `lean/BsvScript/Numbers.lean` | `int_serialization.h:75–117` | W |
| `lean/BsvScript/Numbers.lean` | `int_serialization.h:80–114` | W |
| `lean/BsvScript/Numbers.lean` | `int_serialization.h:80–117` | W |
| `lean/BsvScript/Numbers.lean` | `int_serialization.h:80–81` | W |
| `lean/BsvScript/Numbers.lean` | `int_serialization.h:83–117` | W |
| `lean/BsvScript/Numbers.lean` | `int_serialization.h:83–84` | W |
| `lean/BsvScript/Numbers.lean` | `int_serialization.h:86–117` | W |
| `lean/BsvScript/Numbers.lean` | `int_serialization.h:86–92` | W |
| `lean/BsvScript/Numbers.lean` | `int_serialization.h:94–107` | W |
| `lean/BsvScript/Numbers.lean` | `int_serialization.h:94–117` | W |
| `lean/BsvScript/Numbers.lean` | `interpreter.cpp:1807–1809` | L |
| `lean/BsvScript/Numbers.lean` | `script_num.cpp:147` | L |
| `lean/BsvScript/Numbers.lean` | `script_num.cpp:177` | L |
| `lean/BsvScript/Numbers.lean` | `script_num.cpp:207` | L |
| `lean/BsvScript/Numbers.lean` | `script_num.cpp:396–422` | L |
| `lean/BsvScript/Numbers.lean` | `script_num.cpp:465–483` | L |
| `lean/BsvScript/Numbers.lean` | `script_num.cpp:53–91` | L |
| `lean/BsvScript/Numbers.lean` | `script_num.cpp:62–87` | L |
| `lean/BsvScript/Numbers.lean` | `script_num.cpp:72–90` | L |
| `lean/BsvScript/Numbers.lean` | `script_num.cpp:80–91` | L |
| `lean/BsvScript/Numbers.lean` | `script_num.cpp:84–87` | L |
| `lean/BsvScript/Numbers/History.lean` | `int_serialization.h:80–81` | W |
| `lean/BsvScript/Numbers/History.lean` | `int_serialization.h:83–84` | W |
| `lean/BsvScript/Ops/Arith.lean` | `int_serialization.h:61–118` | W |
| `lean/BsvScript/Ops/Arith.lean` | `script_num.cpp:166–167` | L |
| `lean/BsvScript/Ops/Arith.lean` | `script_num.cpp:196–197` | L |
| `lean/BsvScript/Ops/Arith.lean` | `script_num.cpp:216–217` | L |
| `lean/BsvScript/Ops/Arith.lean` | `script_num.cpp:465–483` | L |
| `lean/BsvScript/Ops/Arith.lean` | `script_num.cpp:53–91` | L |
| `lean/BsvScript/Ops/Bitwise.lean` | `script_num.cpp:400–420` | L |
| `lean/BsvScript/Ops/Expansion.lean` | `int_serialization.h:61–118` | W |
| `lean/BsvScript/Ops/Expansion.lean` | `interpreter.cpp:1807–1809` | L |
| `lean/BsvScript/Ops/Expansion.lean` | `interpreter.cpp:622–625` | L |
| `lean/BsvScript/Ops/Expansion.lean` | `script_num.cpp:306–319` | L |
| `lean/BsvScript/Ops/Expansion.lean` | `script_num.cpp:367–372` | L |
| `lean/BsvScript/Ops/Expansion.lean` | `script_num.cpp:396–422` | L |
| `lean/BsvScript/Ops/Expansion.lean` | `script_num.cpp:53–91` | L |
| `lean/BsvScript/Ops/Expansion.lean` | `script_num.cpp:62–87` | L |
| `lean/BsvScript/Ops/Splice.lean` | `interpreter.cpp:1708–1736` | L |
| `lean/BsvScript/Ops/Splice.lean` | `interpreter.cpp:1718–1719` | L |
| `lean/BsvScript/Ops/Splice.lean` | `interpreter.cpp:1718–1721` | S |
| `lean/BsvScript/Params.lean` | `config.cpp:2391–2415` | I |
| `lean/BsvScript/Params.lean` | `config.cpp:2422–2430` | I |
| `lean/BsvScript/Properties/KernelSample.lean` | `script_num.cpp:246` | L |
| `lean/BsvScript/Properties/Resources.lean` | `script_num.cpp:144–222` | L |
| `lean/BsvScript/Properties/Resources.lean` | `script_num.cpp:166–167` | L |
| `lean/BsvScript/Properties/Resources.lean` | `script_num.cpp:196–197` | L |
| `lean/BsvScript/Properties/Resources.lean` | `script_num.cpp:216–217` | L |
| `lean/BsvScript/Properties/VersionGate.lean` | `int_serialization.h:120–152` | W |
| `lean/BsvScript/Properties/VersionGate.lean` | `script_num.cpp:53–91` | L |
| `lean/BsvScript/Properties/Widths.lean` | `script_num.cpp:311–314` | L |
| `lean/BsvScript/Properties/Widths.lean` | `script_num.cpp:367–372` | L |
| `lean/BsvScript/SigOps.lean` | `config.cpp:2391–2415` | I |
| `lean/BsvScript/SigOps.lean` | `int_serialization.h:86–117` | W |
| `lean/BsvScript/SigOps.lean` | `script.cpp:110–116` | L |
| `lean/BsvScript/SigOps.lean` | `script.cpp:141–150` | S |
| `lean/BsvScript/SigOps.lean` | `script.cpp:30–128` | S |
| `lean/BsvScript/SigOps.lean` | `script.cpp:33` | I |
| `lean/BsvScript/SigOps.lean` | `script.cpp:75–123` | S |
| `lean/BsvScript/SigOps.lean` | `script.cpp:89–95` | L |
| `lean/BsvScript/SigOps.lean` | `script.h:333` | S |
| `lean/BsvScript/SigOps.lean` | `script_num.cpp:413–419` | L |
| `lean/BsvScript/Sighash.lean` | `script.h:175–193` | L |
| `lean/BsvScript/Sighash.lean` | `script.h:176` | S |
| `lean/BsvScript/TxPolicy.lean` | `config.cpp:2391–2415` | I |
| `lean/BsvScript/TxPolicy.lean` | `config.cpp:2422–2430` | I |
| `lean/BsvScript/TxPolicy.lean` | `script.cpp:89–95` | L |
| `lean/BsvScript/TxRules.lean` | `script.h:176` | S |
| `lean/BsvScript/TxRules.lean` | `script.h:198–199` | S |
| `lean/Bsvs/SelfTest.lean` | `big_int.cpp:250–260` | L |
| `lean/Bsvs/SelfTest.lean` | `big_int.cpp:577–594` | L |
| `lean/Bsvs/SelfTest.lean` | `policy.h:177–181` | S |
| `lean/Bsvs/SelfTest.lean` | `script_num.cpp:245–246` | L |
| `lean/Bsvs/SelfTest.lean` | `script_num.cpp:80–83` | L |
| `lean/Test/ReaderCheck.lean` | `int_serialization.h:61–118` | W |
| `lean/Test/ReaderCheck.lean` | `interpreter.cpp:622–681` | L |
| `lean/Test/ReaderCheck.lean` | `script_num.cpp:62–87` | L |
| `lean/Test/ScriptNotation.lean` | `src/script/script.cpp:228–245` | I |
| `lean/Test/VersionGateCheck.lean` | `int_serialization.h:120–152` | W |
| `lean/Test/VersionGateCheck.lean` | `int_serialization.h:136–141` | W |
| `lean/Test/VersionGateCheck.lean` | `policy.h:188` | S |
| `lean/Test/VersionGateCheck.lean` | `script_num.cpp:53–91` | L |

## What else the pass moved (the S3 commit beside this record) [M]

- `tools/export_rewrite.txt`: 24 of its 33 `tools/cite_check.py` blocks named orphan rows the write dropped (the public edition's withheld rows at the old reference commit `879fc8b42168`, whose page citations are gone); a block whose old text occurs zero times stops the export, so the 24 are removed. The 9 left each occur exactly once in the new file (checked by script).
- `tools/wording_allow.txt`: seven phrases quoted from pinned source lines that new rows carry (the ordinal word in reference and Teranode comments and code), under the list's own heading for upstream text. The export gate's pointer and wording legs, replayed on the rewritten `tools/cite_check.py` alone with the gate's own pattern and allow lists: 0 hits before, 12 wording hits after the write, 0 after the phrases. The full export gate was not run: its mechanism leg reads the sibling trees, closed to this lane.
- `tools/jscpd/.jscpd.json`: `maxSize` `4mb`. jscpd 5.4.1 skips a file above 1mb by default; the table grew `tools/cite_check.py` from 429,427 bytes to about 1.4 MB, the file left the scan and the leg read RED: `jscpd: RED: 5.412% duplicated lines (2987 of 55191) in 151 files`, against `GREEN [X] 5.246% duplicated lines (3002 of 57228) in 152 files` at `77a68cba`. With the bound: `jscpd: GREEN [X] 4.951% duplicated lines (3002 of 60639) in 152 files of harness/ and tools/ (bash, go, javascript, python, rust), 281 clones; the threshold 5.34%`. The threshold is re-cut with the bound (the fix lane, below), so a copied block of 70 lines still turns the leg RED. `docs/LINT.md` §1a says so.
- The fix lane's allow list: all seven phrases stand (each still occurs in a row the fix lane did not hold; the export gate's wording leg replayed on `tools/cite_check.py` with its own matching: 0 hits with the seven, 6 without three of them); each of the 9 export rewrite blocks still occurs exactly once in `tools/cite_check.py`, checked by script.
- The second fix lane's export block (the second lens's N4, the captain's call): `tools/export_rewrite.txt` gains a tenth `tools/cite_check.py` block in the shape of the file's `d8-node-team-discretion` blocks, replacing the body of `HELD_DISCRETION` with `HELD_DISCRETION = set()` under the line `# WITHHELD: d8-node-team-discretion held citation pairs.`, so the public edition does not list the 84 pairs. A scratch export of that one file (`load_rewrites` and `rewrite` of tools/export_public.py on a copy, the full export not run): all 10 blocks match exactly once, the copy parses, 0 of the 84 pairs remain, and the export gate's pointer and wording legs replayed on the copy with the gate's own lists read 0 and 0. In the public edition the 84 citations therefore count as not anchored rather than held [D]; the leg stays GREEN there, since an unanchored citation is reported, never RED.
- The fix lane's jscpd re-cut [X] (the Studio, 1-minute load under 6, jscpd 5.4.1 from an installed copy whose lock the leg checked, on this branch's tree at `96868e9c` plus the threshold change): without a copy `jscpd: GREEN [X] 4.950% duplicated lines (3002 of 60647) in 152 files ... the threshold 5.06%`; a probe file of 69 lines copied from tools/cite_check.py read `GREEN [X] 5.058% (3071 of 60716)`, 70 lines `RED: 5.060% (3072 of 60717)`, 72 lines `RED: 5.063% (3074 of 60719)`; the probe removed after. The value written is 5.059 (printed 5.06 %): the lens's 5.06 turns at 71 lines on this tree, whose denominator is 8 lines larger than the lens's, and at the unmoved 5.34 % the turn would have been 250 lines. The stack with dup-138 re-measures once more.
- The third fix lane's export block (the captain's ruling on N3): the tenth `tools/cite_check.py` block of `tools/export_rewrite.txt` carries the enlarged body of `HELD_DISCRETION` (102 pairs) as its old text. A scratch export of that one file (`load_rewrites` and `rewrite` of tools/export_public.py on a copy, the full export not run): all 10 blocks match exactly once, the copy parses, the copy reads `HELD_DISCRETION = set()`, and 0 of the 102 pairs remain (the pair-shaped lines of the file: 372 before, 270 in the copy).

## Not checked here

- The box tripwire on this tree (the cite, jscpd and secrets legs were run alone on the Studio; the rest of the 29 legs read no file this pass changed).
- The full export gate (above).
