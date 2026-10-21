<!-- S2'S OWN LENS ON ITS SITTING-4 END BLOCK (LANE F, set 4 sitting 4; S2 the Lean B sub-agent; 2026-09-27). A fresh-context, READ-ONLY lens: a Claude Code subagent of S2's session on Opus 5.5 (the Agent tool, general-purpose, model opus: the paste's rule (6) names fable, and D118 runs the lanes on Opus 5.5 until Fable returns), launched 23:27 UTC, its wall 1,443 s [M] (the tool's usage line: 1,442,562 ms, 118 tool uses). Its brief: the paste's rule (6) ("verify every claim against origin/main and the tracker by REST; HELD / NOT HELD / PARTIAL / UNVERIFIABLE per claim with the evidence; re-derive every number; the corrections as a numbered list with the sentence, the site and the right value with its label") with the read-only rules, the sites and ten named checks, read against origin/main 013f93c. The report below is verbatim as the lens returned it (the one character-level change: its "<14 paths>" and "< 18" arrived HTML-escaped). Its corrections are all S2's and landed in the commit that files this report (the block's sentences on docs/lanes/lean.md, the Next line, S2's two rows of docs/records/README.md, the ff record's appended Correction, lean/AxiomCheck.lean's comment, the new record docs/records/20260927-235531-legs-s2.txt for correction 6) and as a **Correction.** comment on #25 for correction 2; correction 8's precision rides this block, the ask itself already relayed by the parent at 310a837. Before landing correction 1 S2 re-read its reason at the pin and found why the node says scriptpubkey and not dust: the 20,002-byte script is unspendable before Genesis (script.h:271-273), so its dust threshold is 0 (transaction.h:203-212); that reading is in the ff record's Correction. The lens's guard-hook refusal (a git init in its own scratch directory, refused before it ran) and its reading of the session transcript are its must-knows. -->

HELD IN SUBSTANCE. The fix stops exactly where the pin's `GetSigOpCount` stops on the pre-Genesis, `fAccurate = false` path, and counts what it counts. T-TX11 has no hypothesis and depends only on Lean's three axioms. The witness, the before and after verdicts, the 74 cells, the local leg, the landing diff and the lock times all re-derive. Eight corrections; the one of substance: under mainnet's default policy the node's mempool refuses the witness as non-standard (`scriptpubkey`), so "the witness decides as the node does" holds only at the consensus gate.

## Per claim

**(1) Semantics.**
- **The pin: HELD.**
  - `script.cpp:40–41` breaks on `OP_INVALIDOPCODE`.
  - `instruction_iterator.h` returns `{false, OP_INVALIDOPCODE}` for a push that fails to decode (the returns at 32, 41, 47, 55, 59, 68, 72) and `{true, 0xff}` for a literal `0xff` (26–27).
  - With `fAccurate` false before Genesis, no scope is tracked (43), CHECKSIG/CHECKSIGVERIFY add 1 (67–70), and a multisig takes the else branch 115–118 and adds 20 (`consensus.h:50`).
  - `Machine.getOpTail` (Machine.lean:29–50) matches `decode_instruction` case by case: OP_0; 0x01–0x4b; PUSHDATA1, 2 and 4, short and long; anything above 0x4e.
  - The new `sigOpCountPreGenesis` (TxRules.lean:50–61) returns 0 on `none` and on `op = 0xff`, and otherwise counts 1 or 20 and recurses.
- **T-TX11 (TxRules.lean:686): HELD.** `(s : Bytes) : SigOps.sigOpCount false false s = some (sigOpCountPreGenesis s)`, with no hypothesis.
  - The tripwire record's line 12: `axiom check: OK (531 theorem(s); allowed = ['Classical.choice','Quot.sound','propext'])`.
  - The raw console output (`make-check-ff.txt:699–703`) prints all five new theorems as `['propext','Classical.choice','Quot.sound']`.
- **The other new theorems: HELD.** T-TX12 (713), `replicate_checksig` (692), `invalidop` (179), `h5` (186–190), `sigOpWalk_legacy_eq_all` (636).
- **No `sorry`, `native_decide` or `bv_decide` in TxRules.lean: HELD** (0 matches).

**(2) Rules 1, 9 and 13.**
- **Rule 1.** Calling it "consensus gate" is right: `MAX_TX_SIGOPS_COUNT_BEFORE_GENESIS` = 20,000 (`consensus.h:47`) and the config getter returns that constant (`config.cpp:2340–2343`). HELD. (b)'s node claim is PARTIAL (correction 1).
- **Rule 9: HELD.**
  - At the pin, `67–70` is the CHECKSIG branch and `74–114` is the accurate and post-Genesis multisig branches.
  - `66–69` → `67–70` at 3 sites and `70–114` → `74–114` at 1 site (diff of `616008e`).
  - The old strings are gone from `lean/` and `spec/`; only the block's own history mentions them.
- **Rule 13: HELD.** "first" appears 4 times, all ordinal. No "conformant", no U+2014.

**(3) Commits and ownership: HELD.**
- `616008e`, `ed8fe2b`, `013f93c`, `799751b` and `9639635` are ancestors of `origin/main`.
- `c15a735` is `refs/heads/fallback/s2-set4-sitting4-tripwire-c15a735`.
- Paths touched: TxRules.lean, AxiomCheck.lean, 8 `spec/` pages, `docs/records` (shared) and `docs/lanes/lean.md`, all on S2's OWNERS line or shared.
- AxiomCheck.lean gained 7 lines: 2 comment lines and the 5 `#print axioms` lines, taking the count from 526 to 531.
- Subjects are 196/196/168/138 characters. Every commit was made by pathspec. The 1,238-character refusal at 23:24:35 was re-cut to 168 characters (session log).

**(4) The landing rule: HELD.**
- I re-ran `git diff --quiet c15a735 616008e -- <14 paths>`: exit 0.
- It crossed S3's four commits:
  - `e7ff672`: HANDOFF.md, harness.md, `seed1m-s3.md`, records README
  - `ee73896`: HANDOFF.md, harness.md
  - `e294605`: CLAUDE.md
  - `336860d`: HANDOFF.md
- The ff record states both shas and the exit code, as RULES-SUB requires.

**(5) D142, the lock and the loads: HELD, with one run disclosed above 20.**

| run | lock slot (task log) | 1-minute load at start |
|---|---|---|
| before-build | waited from 22:53:08; slot1 22:55:08–22:57:32 (`b8g1ipnzp`) | 15.50 |
| before-run | not a Lean run | 14.75 (22:57:53) |
| after-build | waited from 22:59:01 behind S3; slot1 23:11:47–23:13:37 (`b5wd1v903`) | 10.17 |
| first after-run | none | **25.55** (files' mtime 23:14:31; disclosed in the block) |
| after-run of record | none | 16.62 at 23:15:09 (gate `< 18`) |
| tripwire | slot1 23:15:10–23:22:17 (`bg0ufzf68`) | 16.01 (14.17 at the end) |

- The two after-runs match line for line (`diff`).
- Runs with no load read at their start:
  - two `lake env lean TxRules.lean` checks, 22:58:02 and 22:58:35–22:58:47, under the lock but with no load gate;
  - the `spec/` regeneration at 23:13:55, while the load was rising from 10.17 toward 25.55;
  - the cite and spec re-run at 23:22:52, bracketed by 14.17 (23:22:17) and 10.00 (23:24:15) `[M]`.

**(6) Finding 5860806541 on #25: HELD.** Posted 23:25:42Z and never edited. It matches the records on bytes, verdicts, the 37 entries and 74 cells, T-TX11, the list of 531 and 427 s. #25 was closed 23:07:59Z. Its "accepts it" needs the same scope fix (correction 2).

**(7) Labels: PARTIAL.** The node's count sits under `[X local]` (corrections 1 and 2). "eight pages", the loads and "exits 0" carry no label; I re-derived each (`[M]` or `[X]`).

**(8) The six parts and the machine line: HELD.**
- Uptime 19:26 EDT is 23:26 UTC (2:26 at 23:24:15, 2:28 at the block).
- `df` equals the session's 23:24:15 read.
- HEAD is `013f93c` on `lean-b`, upstream `origin/main`, clean.
- The stamp 23:26:43Z is the session's own `date -u`.

**(9) The asks: HELD, with correction 8.** Both carry cost and purpose. Ask 1's quote matches TxPolicy.lean:421–422 exactly. S3 relayed ask 1 verbatim at `310a837` (23:37 UTC).

**(10) The two supported-by-execution claims.**
- **"S1's TxPolicy proofs build unchanged": HELD.** `616008e` leaves TxPolicy.lean byte-identical. It was rebuilt in the after-build (listed among the 16 rebuilt modules, rc 0, 17901 jobs) and again in the tripwire's lean leg.
- **"A divergence closed": HELD IN SUBSTANCE.** The node's side rests on the source reading, which I re-read and agree with. The spec's side is the local run plus T-TX11. No node-oracle run was made; the record says so and ask 2 proposes one.

**Other claims, re-derived.**
- **The paste of 22:43 UTC: HELD** (`harness.md:400`; `paste.py S2 --print`).
- **Model, worktree, branch: HELD** (session log: claude-opus-5-5, spec-lean-b, lean-b).
- **Lean v4.34.0 at `799751b`: HELD.**
- **The package re-key: HELD.** "RE-KEYED … 19f4cd8b0b34 → c30ba59fba28" at 22:49:50; the link's mtime is 22:49:41; the first lake ran at 22:55:08. The part about S1's link is NOT HELD (correction 3).
- **The witness: HELD.** I re-ran the committed generator against main's `tx.jsonl`:
  - 20,002 and 20,064 bytes for the witness, 20,001 and 20,063 for the control;
  - sha256 `87027316…d830`, identical to the committed file and to the raw file;
  - version 2, empty scriptSig, OP_1 coin at 605,000, spend at 610,000, one output of 0 satoshis.
- **The corpus: HELD.** 37 lines identical except `commit`. 74 cells (script verdict and code), 0 moved, in each of the before run, the first after-run and the run of record.
- **The tripwire record: HELD.**
  - 21 legs, as `check.sh`'s header lists them; 427 s (23:15:10 to 23:22:17).
  - 71 sites, 1 skipped by name.
  - The cite leg at `c15a735`, which I re-ran: 2,792 citations, 1,790 anchored and holding, MOVED 0. This matches the record exactly.
  - 531; txtests 93 and 57 + 11, the same as the `185804` record.
  - specgen 117 files, 2 flagged, also at `799751b`, so "as before" holds.
  - rules_check 35.
- **(c) and (d): HELD.** #24, #26 and #32 are open; the flagged ids come from specgen's output.
- **(f) no Modal: HELD.** No `modal run`, `check-modal` or `modal_check.py` call in the session between 22:43 and 23:40.
- **Next line: HELD except correction 4.** `9639635` is "THE HOUR D124", the parent's half of the re-pin landing.

## Corrections
1. **(b), lean.md:271.** As written: "EXECUTED: the consensus gate's pre-Genesis sigop count is the node's on every script (T-TX11, no hypothesis), a divergence closed; the witness decides as the node does `[X local]`." Should say:
   - the count equals `SigOps.sigOpCount false false`, S1's model of `GetSigOpCount` at the pin, on every script (T-TX11) `[X local]`;
   - the witness decides at the consensus gate as the node's source does: the spec's gate is valid in both columns at `c15a735`, landed as `616008e` `[X local]`, and the node counts 0 `[SRC]`;
   - under mainnet defaults the node's mempool refuses it `scriptpubkey` `[SRC]` (`standard.cpp:471–474`, `493–497`; `validation.cpp:1074`, `1081–1089`; `configscriptpolicy.cpp:468–471`; `chainparams.cpp:1121`), a standardness policy the spec's mempool gate does not model (D123, S3's Finding 5860811662 on #27).
2. **The node's count and "accepts it".** As written: "where the node counts 0" at lean.md:269 and README.md:116, labeled `[X local]`. Should be `[SRC]`. As written: "the node counts 0 and accepts it `[SRC]`" at the ff record :7 and in Finding 5860806541. Should say "accepts it in the block (consensus) column; its mempool refuses it `scriptpubkey`" `[SRC]`. Records are never edited, and the tracker takes a `**Correction.**`.
3. **(a), lean.md:269.** As written: "S1's `spec-lean-a` still links `19f4cd8b0b34`". Should say it linked that key at 22:49:15 UTC and was re-linked to `c30ba59fba28` at 22:51:57 UTC `[M]` (the link's mtime; `lean_cache.py status` now shows `c30ba59fba28`).
4. **Next line, lean.md:39.** As written: "#47's four citations at `f4fc99a` ride the parent's stack". Should say they ride it as `c3886aa` on `origin/s3-pin-0330-r2` (`b9112d1`), the rebase of `f4fc99a` (same patch-id `e6fbb03a…`); `f4fc99a` itself is on `s3-pin-0329-r` `[M]`.
5. **ff record :21 and README.md:117.** As written: "the sampler's peak 16.01 over 44 samples". Should be 43 samples `[M]` (the record's lines 101–143). The 44 came from `grep -c 'sample '`, which also counted line 15, the flow leg's "kernel sample" line.
6. **lean.md:269, ff record :21, README.md:117.** As written: "the cite and spec legs re-ran GREEN on the landed tree". True in fact (the session ran them at 23:22:52–23:23:00), but no record file names `616008e` for them (rule 17) and their start load was not read. My re-run at `616008e` `[X]`: cite GREEN, 2,830 citations, 1,792 anchored, MOVED 0; specgen OK, 117 files, 2 flagged.
7. **AxiomCheck.lean:572 and the gen.py record companion :1.** As written: "set 4 sitting 3". Should be "set 4 sitting 4" (the paste's heading and the commit subjects).
8. **Ask 1, lean.md:277.** As written: the hypotheses "'without a literal `0xff`' at `:305`, `:369`, `:418`, `:436`". Line `:436` reads "none of whose scripts has a literal `0xff`" (T-SO11), and `:305` is a sentence in the module docstring, not a hypothesis. This ask already went to S1 verbatim at `310a837`.

## Must-knows
- **Ask 2.** If S3 runs the node oracle on the witness pair, expect the mempool column to disagree through D123's standardness gap (`scriptpubkey`), not through the sigop count. The block column should accept.
- **The session transcript.** To check runs that have no record file, I read the S2 session transcript read-only (`…/17d39f23-….jsonl`): the hook refusal, the re-key, the cite and spec re-run, and the absence of Modal calls.
- **Still-false sentences.** T-SO10's false sentence stands in `TxPolicy.lean:421–422` and `spec/theorems.md:3101–3102` until S1 fixes it and `make spec` runs. Separately, `STATE-OF-THE-WORLD.md:41` still says TxRules has "3 theorems" (stale since 2026-09-22; T-TX1 to T-TX12 exist).
- **"Keeps TxRules self-contained".** The definition is self-contained, but TxRules.lean now imports `BsvScript.SigOps`. There is no import cycle.
- **My guard-hook refusal.** In my scratch dir only, I tried `git init` plus `git add -A` so `cite_check` could list its own files. The guard hook refused the command before it ran and nothing was created. I used `/private/tmp/claude-501/lens-s2-sitting4/cc_wrap.py`, which feeds `cite_check` the `git ls-tree` file list, instead.
- **Nothing written in the repo.** The worktree HEAD is unchanged at `013f93c`.
