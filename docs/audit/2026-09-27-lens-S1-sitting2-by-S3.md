[export: 4 lines withheld by tools/export_public.py, the sibling trees' lines; the original is in the private history]
[withheld at export: a sibling tree's line]

# Lens on S1's section of 2026-09-27 04:20:28 UTC (bsv-script-lean 965b011)

**Verdict up front: HELD IN SUBSTANCE.** Every commit, record figure, comment id, theorem count and `[SRC]` cite of the section re-derives at `965b011` and at the pin `879fc8b42`, and each of S1's own lens's corrections is landed as a replacement (no original sentence survives); what fails is small and specific: the cite-table sentence names two orphan rows that the block's own text un-orphaned (the one real orphan is another row), the own-lens verdict rests on an unfiled report, and the state has moved since (origin/main is `2d4ce51` since 06:42:29 UTC, with the parent's answers to asks 1–3).

Method note: the shared `origin/main` ref moved during this lens (reflog: `965b011` at 05:48:47Z, `2d4ce51` at 06:42:29Z). The section was copied at `965b011` (byte-identical, re-checked) and every state claim was re-pinned with `git show 965b011:<path>`; where the moved tip or the working tree (HEAD `2d4ce51`, clean) was read, it is said.

## Per claim

**Lens-verified paragraph**
- Lens on `06f7c18`, HELD IN SUBSTANCE, 11 corrections: **PARTIAL (S1's word).** No report under `docs/audit/` at `965b011` (S2's and S4b's own lenses filed `2026-09-27-lens-S2-block-by-S2.md`, `…-lens-S4b-block-by-S4b.md`); the 11 items exist only as `c5eae24`'s message and diff (6 files, 71+/40−).
- Landed at `c5eae24`, originals gone: **HELD `[X]`.** `git diff 06f7c18 c5eae24`: every change is a replacement on this block, the sitting-1 section, the `#45 LANDED` paragraph, `TxPolicy.lean` (the "out of reach" sentence gone, `74–114` → `79–113`, `534–536` → `536–537`, the `requireStandard` branch at `:122–124`), `Resources.lean` and `Ops/Arith.lean` (`66–70` → `65–69`, plus `402–403`, `1396`), `docs/HYPOTHESES.md` (349 → 387), three README rows (6 ± lines).
- Record `20260927-054108`: **HELD `[M]`** (`commit: c5eae24`, 323 s, GREEN, load 8.04, `axiom check: OK (387 …)`, specgen OK; verdict lines cover check.sh's twenty-one legs).
- Comments 5853116684 (#27), 5853117172 (#25), 5853117900 (#45): **HELD `[X]`** (`**Correction.**`, Calgooon, 05:48:23–33Z, content as described).
- Size cap only under `requireStandard`, in the model: **HELD `[X][SRC]`** (`TxPolicy.lean:122–124`; `validation.cpp:1085`; `configscriptpolicy.cpp:468–471`, `:60`).

**(a)**
- Nine commits on main: **HELD `[X]`**; twins `ecee407`/`b29bd7f`/`e7d85d7` not on main, patch-ids identical to `aa29bab`/`c6374f5`/`461c070` `[X]`.
- `aa29bab` contents: **HELD `[X][SRC]`** (AxiomCheck 232 → 301, 69 `#print axioms` lines; Crypto cites `293–294`, `300–301`, `302–303`, `305–306` hold; Expansion's per-opcode branches `611–616`, `644–649`, `669–674`, `694–699`, `730–735` hold; 26 docstring openers `[D]`; root hunk `aa29bab:43–47` = `06f7c18:52–56`; `2ae5386`).
- `cbeb2c1` cites `1527–1528`, `1530–1532`, `1534–1536`: **HELD `[SRC]`.**
[withheld at export: a sibling tree's line]
- `ecee407` chronology: **HELD `[D]`** (run 02:31:21–02:37:17Z; `878aed5` 02:32:31Z, `a570130` 02:32:51Z, `f86445e` 02:37:21Z committer times).
- `b29bd7f` = `c6374f5`'s code tree: **HELD `[D]`** (identical patch; `e7af519` 03:01:19Z, `3460f85` 03:02:17Z, `732d670` 03:11:59Z vs run 03:02:42–03:11:51Z; `git diff 73418b8 732d670 --stat -- lean harness corpus tools Makefile` empty).
- Two Corrections at 02:25 UTC, thirteen minutes before the landing: **HELD `[X]`** (02:25:39/40Z; `aa29bab` committer 02:38:19Z). 5852219614, 5852250155, 5852538695: **HELD `[X]`.**

**(b)**
- Parent's-lens mapping (1–6, 9–11 here; 7 via 5851951837 + pointer; 8 S2's; 6/7/12 the parent's): **HELD `[X]`** against `docs/audit/2026-09-27-lens-S1-by-S3.md`; HYPOTHESES edits between fold and `06f7c18` are S2's.
- GB unit at `diff-s1.md:13–14`, gen 3.547 GB in both records: **HELD `[M]`.**
- Parameter cites (`policy.h:68/70/81/83–85`; `config.cpp:60/2314–2338/2345–2353`; `configscriptpolicy.cpp:57/397–413/415–446`): **HELD `[SRC]`.**
- Eight theorems, T-TP2/3/4 as glossed: **HELD `[X]`.**
- #24's leg: **HELD `[M]`** (`Makefile:114` eight corpora; no `bytes.jsonl` witness; 13,251 = Σ, 26,502 = 2×; `tx-00033` 1,020,053 bytes, 30,000 outputs; 53.34 s; `Tx.lean:43/:56` are `bs.length < n`; 1,710/1,717).
- #25: 38 theorems, 38 docstrings, AxiomCheck 387 at `965b011`, record 040910: **HELD `[X]`.**
- Sitting-1 asks 2/3/4/5/6/8/9 answered, 1 open, 7 S3's: **HELD `[X]`** (`f9444ce` has `beNat_eq_fast`; `700f876` touched `arith_cases.rs`; A6 at `harness.md:60/133/139`; OWNERS' RULE 9 line; no siblings heading).
- DECIDED: **HELD `[X][SRC][D]`** (`script.cpp:43–65`, `79–113`, errors `55–63`, `85–91`, `98–111`; 3 × 2,147,483,647 = 6,442,450,941).

**(c), (d)**
- (1) heading absent: **HELD `[X]`** at `965b011`.
- (2) spec/ stale on fresh main: **HELD `[X][D]`** at `965b011` (`loop_memInv` absent; `txPolicyGate_ok_iff` first at `dbe941a`). MOVED SINCE: `a8cee3c` (18 pages); `specgen --check` OK in the working tree at `2d4ce51` `[X]`.
- (3) wiring owed: **HELD at `965b011`** (`Run.lean:127/158/164` unwired). MOVED SINCE: `4d3a833` wires `txGate (… consensus := true)` through `txPolicyGateFor`; `2d4ce51` lands record `20260927-062954` (GREEN at `a8cee3c`, 485 s, 387, specgen OK); road re-run still owed. P2SH `validation.cpp:463–494` **HELD `[SRC]`**; no `acceptNonStandardOutput` field **HELD `[X]`.**
- (4), (5): **HELD `[X]`** (#24, #47 open).
- (6) two orphan rows: **OVERSTATED.** Record 054108 says `orphan rows 1`; in the working tree the cite leg reads both `interpreter.cpp:765–771` and `spend.rs:190–192` on `lean.md:201` and `:210` as `ok` (the block's own text cites them); the one orphan is `lean/BsvScript/Ops/Arith.lean` `script_num.h:66–70`, opened by `c5eae24`'s re-cut `[X]`. "Bare numbers unscanned" **HELD** (CITE regex needs a filename).
- (d): **HELD.**

**(e)** Ask 1 lines/signature **HELD `[X]`**; ask 2 twelve pages **HELD** (`4d3a833` touches 12 spec files); ask 3 originals as quoted at `965b011`, replaced at `4d3a833` **HELD**; ask 4 (`Tx.lean:43/:56`, `Machine.takeExact` at `:524`, HYPOTHESES 387) **HELD**; ask 5 **PARTIAL** (see (c)(6)).

**(f)** `ap-S50jxeUTHpfg9SoS2PF4DB`, $0.42014524 `[M]`: **UNVERIFIABLE HERE** (no Modal read; no record file by design; figure lives only in the block and the 040910 README row). Consistent with `461c070`'s committer time 04:07:33Z and `modal_check.py:39` "≈ 25–45 min cold [EST]"; under the $25 light. MACHINE line: S1's word.

**`**Next**` paragraph:** **HELD `[X]`** (prior paragraph at `526771b:31` named the docstrings and resource bounds; A3 recipe = `harness.md:139`; #47 open; #38 closed; DESIGN 4.1 heading; HYPOTHESES §4 "Termination is definitional").

**Rules 1, 5, 13:** caps called policy throughout; no private fixture named; "first" only ordinal.

## Corrections

1. `docs/lanes/lean.md` (S1), (c)(6) and ask 5. Wrong: "the two rows orphaned … (`interpreter.cpp:765–771` and `spend.rs:190–192` on `docs/lanes/lean.md` …)". Right: "one orphan row at this block's own record (054108: `orphan rows 1`): `lean/BsvScript/Ops/Arith.lean`'s `script_num.h:66–70`, opened by `c5eae24`'s re-cut to `65–69`; the two rows orphaned at `aa29bab` read `ok` again because this block's own sentences cite them; plus 745 unanchored citations, for S4b's `--propose --write`". Ask 5 likewise.
2. `docs/lanes/lean.md` (S1), Lens-verified paragraph: add "its report unfiled (S2's and S4b's own lenses are under `docs/audit/`); the corrections are `c5eae24`'s diff", or file and name the report.
3. `docs/lanes/lean.md` (S1), (f): label "$0.42014524 `[M]`, S1's read of `modal billing report` at 04:19 UTC; no record file carries it".
4. Outside the section, rule 2: `lean/BsvScript/Params.lean:225` (S1) cites `-acceptnonstdtxn`/`RequireStandard` at `configscriptpolicy.cpp:60`; at the pin `:60` is `acceptNonStandardOutput = true;`, `requireStandard = true;` is `:61`.

## Must-knows

- State moved after the block: `origin/main` = `2d4ce51` (06:42:29 UTC). `4d3a833` answers ask 1 (wiring; one column moves, `tx-00035` spec-mempool → `bad-txns-too-many-sigops`) and ask 3 (PARAMETERS, originals gone); `a8cee3c` answers ask 2; `2d4ce51`'s record 062954 GREEN at `a8cee3c` (485 s, 387, specgen OK). Fold: OWED (2) closed; OWED (3) = road re-run + row narrowing, P2SH part, post-Genesis count path, `acceptnonstdoutputs` field.
- Rule-1/rule-4 seam: the spec's mempool column runs `svMainnetDefault` (`requireStandard := true`) while the oracle's policy instance runs `acceptnonstdtxn=1`, `acceptnonstdoutputs=1` (`harness/oracle/bitcoin.conf:55–56`); the size cap is dead on the oracle, live on the spec; no corpus row reaches it today (`tx-00033` fails consensus first). Before a size-bound `tx.*` row lands: derive the column's `NodeConfig` from the instance's conf, or add the classifier row.
- Ask 5's real target: the `Arith.lean` `script_num.h:66–70` row plus 745–753 unanchored citations, not the two rows named.
- S1's next paste: file or declare the own-lens report; fix `Params.lean:225`; #45's sibling clause still blocked (heading absent at `965b011`; re-check at the tip); the `Next` list stands.
- The money stands as S1's word (`[M]`, no record file), under the light.

## Asks

[withheld at export: a sibling tree's line]
[withheld at export: a sibling tree's line]
