[export: 4 lines withheld by tools/export_public.py, the sibling trees' lines; the original is in the private history]
<!-- S3'S OWN LENS ON ITS SET-4 SITTING-3 END BLOCK (LANE F; S3 the lane parent; 2026-09-28; D127: one lens per block, its author's). A fresh-context, READ-ONLY lens: a Claude Code subagent of S3's session on Opus 5.5 (the Agent tool, general-purpose; D118), launched 13:19 UTC on the block as committed at `016fca5` on `origin/s3-endblock` (HANDOFF.md:38-71), its wall 1,354 s [M] (the tool's usage line: 1,353,991 ms, 103 tool uses). The report below is verbatim as the lens returned it. Its corrections landed in the commit that files it: the thirteen on the block; the fourteenth is on `016fca5`'s commit message ("HANDOFF §0 is 15,024 characters"; it was 15,158 [M]), named here because a pushed commit is never amended (A19). Its must-knows: 1, 4 and 6 on the block's (2), (3), (5) and (6); 7 as the block's ask A29 (the parent's dry run of `block_archive.py` read the same 29 moves [X]); 5 on `docs/lanes/harness.md` (the T3 paste heading of 22:43 UTC, rule 9); 2 answered by continue 27 before any ask was sent; 3 in the landing's record; 8 in package B's record; 9: the lens's copies in the parent's scratchpad, removed after the landing. -->

<!-- THE ONE FRESH LENS ON S3's SET-4 SITTING-3 END BLOCK (D127): a fresh-context, read-only sub-agent on Claude Opus 5.5 (claude-opus-5-5), started 2026-09-28 13:19:28 UTC (date -u); the block is HANDOFF.md:38-71 on origin/s3-endblock at 016fca5 -->

## 1. Verdict

**HELD IN SUBSTANCE.** I found 14 corrections: 1 LOAD-BEARING and 13 COSMETIC. One of the cosmetic ones is in 016fca5's commit message, not in the block. Item (1)'s Modal tripwire line is **PENDING**.

[withheld at export: a sibling tree's line]

These sentences do not hold as written:
- **(2) Package B** (load-bearing): "agreed with the node on all 13,514 in both columns". Two of those are false agreements.
- **(1)**:
  - "#47 ... behind the spec's tripwire at `e33e7cd`": the tripwire ran at `2eb4df6`.
  - "the differential on the FULL corpus ..., 13,184 of 13,257": 13,257 is only `make diff`'s eight corpora.
  - "their 971 MB of logs": these were the road's three logs, not the consensus instance's.
- **(3)**: "the 1-minute load 100 to 240".
- **(4)**: "(their text in §47)".
- **(5)**:
  - "about $0.30 `[D]`": the record says $0.298.
  - "the parent's four evening apps": there were five.
  - The $4.0494 and $4.9394 totals cannot be reconciled as written.
- **(6)**: (vii) the resident-size wording; (x) "the record's end count"; (xi) one record cited for two landings; (xii) "from 12:22 UTC ... to 48".
- **The commit message**: "HANDOFF §0 is 15,024 characters". It is 15,158.

## 2. Per claim

**Header and lane paragraph**
- **"last at 2026-09-28T13:17:14Z"**: HELD `[M]`. The parent's scratch `eb-iso.txt` reads that time, and 016fca5 was committed at 13:18:08 UTC.
- **"a new heading under D150"**: HELD `[X]` (RULES-TREE (24); continue 26). It stays on a branch until its push.
- **Worktrees** spec-harness, spec-harness-land and spec-harness-road: HELD `[M]` (`git worktree list`).
- **S1, S2, S4b and T3 (D77, D87)**: HELD `[X]` (CLAUDE.md's lane table).
- **"from 2026-09-27 11:52 UTC through ... continues 10 to 26"**: HELD `[X]`.
  - WINDOWS.md puts S3's continue 9 at 08:50 UTC, continue 10 at 14:13 UTC, and continue 26 at 13:10 UTC on 2026-09-28.
  - §47 says "from the restart of 11:52 UTC (D118)".
- **§47 "re-cut in place through 2026-09-28 12:4x UTC"**: HELD `[X]`.
  - §47's 81 lines match c374c08's old block byte for byte.
  - The last HANDOFF touch before 016fca5 is f3aeee7 (12:42:45 UTC).
- **"§54, §55 and §56"**: HELD `[X]`. Each is its fold paragraph verbatim: 1,210, 1,030 and 968 characters, all under D125's 1,500.

**(1)**
- **#47**: closed_at 2026-09-28T11:11:25Z. Comment 5868707284 (11:11:24Z) reads "LANDED AND CLOSED ... 0.3.30 on `main` at `e33e7cd`". HELD `[X]`.
  - "behind the spec's tripwire at `e33e7cd`": PARTIAL `[X]`. The record's commit line reads `2eb4df6`; `e33e7cd` is the landing commit that carries the record (C2).
- **#26**: closed_at 12:05:53Z; comment 5869484661 at 12:05:52Z. HELD `[X]`.
  - `5659619` (the num2bin relabel) and `b3d850c` (tx-00040 plus S2's pair) are main's hashes (commit-map record). `spec/rules.md:117` on main reads "Flagged (0): none." HELD `[X]`.
  - The replay (115150): 106 transactions, 256 inputs, 0 P2SH-shaped outputs spent or created. HELD `[X]`.
- **#27**: closed_at 12:06:13Z; comment 5869489470. HELD `[X]`.
  - 40 entries, 6 classified (4 standardness plus 2 finality), none unexplained (113333 §1–§2). HELD `[X]`.
  - The (f) item, 4 / 4 in both columns and the verdicts of record (113357 §2). HELD `[X]`.
- **#24**: closed_at 12:43:58Z; comment 5870065132. HELD `[X]`.
  - The counts are right (121537 §2: 42 + 5 + 26 = 73; §3: 26,514 of 26,514 cells unmoved). HELD `[X]`, with the scope point in C3.
  - The stamp 122810 is at `8917350`: GREEN, 739 s, load 19.65 at start. HELD `[X]`.
- **D123 and S1's ask 1**: `9873545`, `5924cf8` and `8d80e0d` are on main. HELD `[X]`.
- **D135 filed and private**: the 114104 record shows created 11:36:57Z, state triage, published_at null. HELD `[X]`.
- **`b720ad1` is S4b's A15 and A17**: HELD `[X]`.
- **A13 and A14**:
  - Continue 24 says "A13 and A14 RULED". HELD `[X]`.
  - #34's body carries the A14 line ("the line is S3's"), updated 12:13:18Z. HELD `[X]`.
- **Continue 25** (`bb650ab`, `6cefd45`, 131448): HELD `[X]`.
  - No `bitcoind -regtest` process is running at 13:3x UTC. HELD `[M]`.
  - 971 MB = 228 + 379 + 364. The sum HELDs `[X]`; the attribution is PARTIAL (C4).
  - The three logs now read 2,000,000 bytes each `[M]`.
- **Moving main (120344) and the commit map (121500)**: HELD `[X]`.
- **THE MODAL TRIPWIRE OF RECORD**: PENDING. The parent's `modal-record.log` shows app `ap-mi1hbXfEBuL93YoKXSeXct`, launched at load 60.06, past its bake step.

**(2)**
- **corpus/road and the third start's times**: 13,514 entries, 12:13:40Z to 13:01:45Z. HELD `[M]` (road-b3.log).
- **"the funding by an assembled block, `fb1dc6a`"**: HELD `[X]`. `fb1dc6a` is the range-diff twin of `822a66e`, which is the tree the run used.
- **"agreed ... on all 13,514 in both columns"**: PARTIAL `[M]` (C1, LOAD-BEARING).
- **"8 reasons"**: HELD `[M]` (5 + 1 wrapped reasons plus 2 "Missing inputs").
- **The four cites** `validation.cpp:2757–2761`, `2818–2824`, `script.h:258–275` and `coins.cpp:61–65`: HELD `[X]` at `879fc8b42`.
- **The fix at `a251aa4` and the fourth start waiting**: `a251aa4` is on `origin/s3-road-b2`; the fourth start was waiting at 13:16:51Z. HELD `[M]`, but overtaken since (§4 item 1).
- **A16 at `35fc7bc`**: HELD `[X]`.
- **The Finding on #47 (5860579463)**: posted 2026-09-27 22:51:54Z. HELD `[X]`.
- **The relay since 13:08 UTC**: HELD `[X]` (continue 26).
- **Comment 5860811662**: at filing it named 3 entries. The count is 4 now (tx-00032, -00036, -00037, -00038), per 113333 §2 and #27's closing comment. HELD `[X]`.
- **T-SO10 in S1's paste**: it is item (4) of S1's sitting-4 paste (`docs/lanes/harness.md:383`, re-cut 12:00 UTC). HELD `[X]`.
- **"UNANSWERED on main"**: HELD `[X]`. No S1 commit exists on any ref after `c281e0d` (19:19 UTC), apart from `eb07311`'s twins.
- **`eb07311`**: author date 2026-09-27 16:25:19 UTC, committer date 22:57:12 UTC. HELD `[X]`.
  - Its twins: `757c7c3` (committer 16:25:19), `c3fedf1` (s3-pin-0330), `92f0d1a` (-r), `5d40fa1` (-r2, committer 22:57:12), and `eb07311` itself on -r3 and main.
  - It changes one line of `docs/lanes/lean.md` (:201).
- **S1's newest heading**: main's `docs/lanes/lean.md:240` is `### S1 END BLOCK (2026-09-27T18:15:33Z)`. HELD `[X]`.
- **#49 (5858114786)**: HELD `[X]`.

**(3)**
- The gate holding package B: HELD at 13:17 `[M]`.
- "100 to 240": PARTIAL `[M]` (C5).
- "nothing starts at 20 or more": HELD `[X]`.

**(4)**
- "None open" and "RULED or DONE": HELD `[X]`.
- "(their text in §47)": PARTIAL `[X]` (C6).

**(5)**
- **The dollar figures**: every one is the block's own meter read, and no record carries any of them. I could check none from the repo (I made no Modal call). Status: unverifiable, not FAILED.
- **$4.0494 at `8fde74b`**: `8fde74b:HANDOFF.md:90` reads "The spec-named apps today total $4.0494". HELD `[X]`.
- **The six app ids**: each is named by its record (seed1m run 2 and run 1, coverage, 174629, 113357, 121537). HELD `[X]`.
- **Estimate against meter**: run 2 is `[M]`/`[D]` = 0.6102/0.298 = 2.05x. The other five apps are 1.01x to 1.20x, and run 1 ran longer (1,109 s against 1,061 s). This is an outlier (§4 item 6).
- **Quote, count and totals**: see C7 (the quote), C8 (the app count) and C9 (the totals).
- **"S1, S2, S4b $0 today"**: consistent with the records of 2026-09-28. S2's 120740 and 130418 name no app; S4b's 114104 says "Money: $0"; S1 has no record.
- **$8.17**: unverifiable.

**(6)**
- **"11 GiB by 12:4x UTC"**: continue 25 reads "24 GiB to 11 GiB since 09:00 UTC". HELD `[X]`.
- **"#24's tripwire, 3 minutes"**: the launcher waited from 12:24:54Z to 12:28:10Z. HELD `[M]`.
- **hour-root and hour-layer**: hour-root is a detached worktree at `8fde74b`; hour-layer exists. HELD `[M]`.
- **The slips**:
  - (vii): HELD in substance `[X]`; wording in C10.
  - (viii): HELD `[X]` (113357 §3).
  - (ix): HELD by absence `[X]` (no `docs/CONFORMANCE-2026-09-28*` in any commit).
  - (x): PARTIAL `[M]` (C11).
  - (xi): HELD `[X]`. The stacked-landing record §1 has `e675ad1` stopped at S4b's 11:43–11:46 landing. `trip-land24.log` reads "Terminated: 15" at 12:20:47 at `798f8e1`. The record cite is PARTIAL (C12).
  - (xii): PARTIAL `[M]` (C13).

**D125 shape, wording, rule 5**
- **Live block**: 7,576 characters, within the 30,000 cap. HELD `[M]` (`block_archive.py --ref origin/s3-endblock`: "keep S3 2026-09-28 13:17 7,576 chars ok").
- **§0**: 15,158 characters `[M]`, within the 200,000 cap.
- **Pointers**: §47 and §54–§56 exist and hold what the block says. HELD `[X]`.
- **Commit message "15,024"**: FAILED `[M]` (C14).
- **Wording**:
  - U+2014 count: 0 in the block and in §0 `[M]`.
  - "first" appears once, as an ordinal ("(f)'s first Studio run"); earlier lenses ruled ordinals acceptable.
  - "conformant" does not appear.
  - "consensus" appears once, as "the consensus instance" (a node instance, not a policy limit).
  - HELD.
[withheld at export: a sibling tree's line]

## 3. Corrections

1. **LOAD-BEARING.** (2)
   - As it stands: "Its third start (12:13 to 13:0x UTC, the funding by an assembled block, `fb1dc6a`) agreed with the node on all 13,514 in both columns and read RED on 8 reasons outside the tables: two wrapped mempool reasons (`validation.cpp:2757–2761`, `2818–2824`) and two `OP_FALSE OP_RETURN` coins no chain can fund (`script.h:258–275`, `coins.cpp:61–65`)."
   - Replace with: "Its third start (12:13 to 13:0x UTC, at `822a66e`, the funding by an assembled block, rebuilt as `fb1dc6a` on `origin/s3-road-b2`) read RED on 8 reasons outside the tables, 0 unexplained: 6 refusals under two wrapped mempool reasons (5 `max-script-num-length-policy-limit-violated`, `validation.cpp:2757–2761`; 1 `max-script-num-overflow`, `2818–2824`) and 2 entries (`road-flow-00947`, `-00948`) whose `OP_FALSE OP_RETURN` coins no chain can fund (`script.h:258–275`, `coins.cpp:61–65`). The runner counted 13,514 agreements in both columns: 13,512 are verdicts; the two unfundable entries (the spec's `EVAL_FALSE` beside the node's `Missing inputs`) are a false agreement, never a verdict, and leave the corpus at `a251aa4`."
   - Evidence: the third start's output (`road-b3-red/road-b3-out.txt`) reads "agree: spec 13514, spec-mempool 13514". Its tier-2 notes read "spec SCRIPT_ERR_EVAL_FALSE vs the node bad-txns-inputs-missingorspent: 2" and "spec-mempool: ... (no row): 2". `a251aa4`'s message reads "a false agreement, never a verdict".

2. **COSMETIC.** (1) #47
   - As it stands: "bsv-rs 0.3.30 behind the spec's tripwire at `e33e7cd`".
   - Replace with: "bsv-rs 0.3.30 on `main` at `e33e7cd`, behind the local tripwire at `2eb4df6`".
   - Evidence: 110105's line "commit: 2eb4df6"; `e33e7cd`'s subject.

3. **COSMETIC.** (1) #24
   - As it stands: "the differential on the FULL corpus at `spec@8fde74b`, 13,184 of 13,257 agree in both columns, 73 not applicable, no spec verdict moved".
   - Replace with: "the differential on the FULL corpus at `spec@8fde74b`: 13,184 of the 13,257 entries of `make diff`'s eight corpora agree in both columns, 73 not applicable; bytes 512 of 512; million's four under a cited class; no spec verdict moved (26,514 of 26,514 cells)".
   - Evidence: 121537 §2–§3.

4. **COSMETIC.** (1) Continue 25
   - As it stands: "their 971 MB of logs cut to 2 MB each."
   - Replace with: "the road's three logs (the base snapshot's 228 MB, the block instance's 379 MB, the policy instance's 364 MB) cut to their last 2 MB each."
   - Evidence: 131448's last paragraph. `[M]`: `spec-oracle-block-base`, `-block-data` and `-policy-data` logs are 2,000,000 bytes each. The consensus instance's `spec-oracle-data` log is 43,375 bytes and was never among them.

5. **COSMETIC.** (3)
   - As it stands: "(the 1-minute load 100 to 240 from other windows since 13:0x UTC; ...)".
   - Replace with: "(the 1-minute load 83 to 256 from other windows, 13:06 to 13:17 UTC; ...)".
   - Evidence: road-b4.log reads 82.87 at 13:06:48Z and 256.15 at 13:14:51Z.

6. **COSMETIC.** (4)
   - As it stands: "(their text in §47)".
   - Replace with: "(§47 names where: A1 to A28 in the block at `f5d89e0`, S4b's A13 and A14 verbatim in its END BLOCK §(e) at `702d226`)".
   - Evidence: §47 (4).

7. **COSMETIC.** (5)
   - As it stands: "its record's "about $0.30 `[D]`"".
   - Replace with: "its record's "about $0.298 `[D]`"".
   - Evidence: seed1m §1.

8. **COSMETIC.** (5)
   - As it stands: "after that read, the parent's four evening apps:".
   - Replace with: "after that read, the parent's five evening apps:", and add the coverage's failed first launch `ap-dBIi4vtYVI8z275FCoFkOT` (17:59 UTC) with its figure from the same meter read.
   - Evidence: coverage record line 198: "Its cost is on the meter under its app id."

9. **COSMETIC.** (5)
[withheld at export: a sibling tree's line]
   - Add after the parenthesis: "(that read summed the spec-NAMED apps, S2's `spec-35-dryrun` and `spec-repin-s2`, $1.3687, among them: a different set)".
   - Evidence: 4.0494 + 1.3570 = 5.4064, which is more than 4.9394, and a day's meter only grows.

10. **COSMETIC.** (6)(vii)
    - As it stands: "so the 2^31-byte elements reached 5 to 6.5 GB resident".
    - Replace with: "so the evaluator reached 5 to 6.5 GB resident on elements of 2^31 − 1 bytes".
    - Evidence: 113357 §1 and §3.

11. **COSMETIC.** (6)(x)
    - As it stands: "(the record's end count reads 0 uncommitted)".
    - Replace with: "(the tripwire then running, at `e675ad1`, was stopped for (xi) and wrote no record; the one that stands, `…-115355-make-check.txt` at `3ff5327` from 11:53:55 UTC, reads 0 uncommitted at both ends)".

12. **COSMETIC.** (6)(xi)
    - As it stands: "Two landings used the moving-main rule instead (`docs/records/20260928-120344-moving-main-s3.txt`)."
    - Replace with: "... (`…-120344-moving-main-s3.txt`, the stacked landing; `…-131448-logcap-landing-s3.txt`, continue 25's)."

13. **COSMETIC.** (6)(xii)
    - As it stands: "The load gate held #24's tripwire from 12:22 UTC (other windows' builds; the 1-minute load to 48): started below 20 by a gated launcher, never above it."
    - Replace with: "The load gate held #24's tripwire from 12:24:54 to 12:28:10 UTC (the gated launcher's log; other windows' builds; the 1-minute load to 49.49): started at 19.65, never above 20."
    - Evidence: `trip-land24b.wait` / `.gate`. Also, "from 12:22" plus "3 minutes" contradicts the 12:28:10 start.

14. **COSMETIC** (016fca5's commit message, not the block).
    - As it stands: "HANDOFF §0 is 15,024 characters".
    - Correct value: 15,158 `[M]`. It was measured on the draft `endblock-new.md`, which was 134 characters shorter than the committed block. Name it in the landing's record.

## 4. Must-knows for the parent

1. **Things have moved on since 13:17.**
   - Package B's fourth start began at 13:23:12Z and stopped at once on `lake build bsvs` with "unknown short option '-j'" (rc 1).
   - `road_b5.sh` has been waiting for the gate since 13:25:09Z.
   - The "fourth start ... waiting" sentences in (2), (3) and (6) need re-cutting before the push.
2. **Your `eb-a29.py` (13:25 UTC) files A29 as URGENT, but W0 has already answered it.**
[withheld at export: a sibling tree's line]
   - File A29 as DONE, not open. The PATH filter in `road_b5.sh` now does nothing.
3. **The Modal tripwire is presumably running on `016fca5`** (spec-harness-land's HEAD).
   - A re-cut that touches only HANDOFF.md changes nothing any leg reads (131448's own exclusion list).
   - Put that identity diff in the Modal record.
4. **The Studio's free disk is down to 7.9 GiB** at 13:35 UTC (`df -h /`). The scratchpad holds 764 MB.
5. **Rule 9 on `docs/lanes/harness.md:428`.** On main, the T3 paste heading says "TYPED INTO T3'S PANE" (`e7ff672`, 2026-09-27 22:50 UTC). Continue 26 says T3 never received it. One of the two is wrong.
6. **(f) run 2's metered $0.6102 is 2.05x its estimate**, while the other five apps are 1.01x to 1.20x. Read that app's containers once before the figure stands.
7. **`block_archive.py` (W0's tool) re-archives pointers.**
   - §28 to §46 only point on to §1 to §19, and §48 to §52 point to §23 to §27, so every lookup takes two hops.
   - Its dry run on 016fca5 would move all 29 pointers again, as §57 to §85.
8. **Package B's record should name the third start's tree as `822a66e`** (its keys are `spec@822a66e`), not `fb1dc6a`.
9. **This lens shares your session scratchpad (`53e70a2d…`).**
   - It wrote `HANDOFF.md`, `block.txt`, `ARCH.md`, `s47.txt`, `lean.md` and `seed1m.md` at the top level, plus `lens-d127-s3eb/`, between 13:19 and 13:25 UTC. All are `git show` copies.
   - Any earlier file of yours with those names was overwritten.
   - No script of yours reads them (`eb-a29.py`, `endblock.py` and `handoff_final.py` read `<worktree>/HANDOFF.md`).
   - No git tree was touched.
