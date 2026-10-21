> Original: the planning repository's C3 audit lens 03 of the spec's pages; its path is withheld under the export's pointer rule
> Date: 2026-09-25. Author: a fresh-context read-only lens run by the planning window (C3)
> [M] Moved into the spec's tree on 2026-10-12 under the uplift the owner ruled on 2026-10-11; cut per the hazard lane's verdict table of 2026-10-12 (kept outside the tree) and the owner's ruling `cut them` of 2026-10-12 09:48Z; checked by lane lens-chk on 2026-10-12 with additional cuts and wording corrections; every cut is marked in place and dated
> [LIT] 2026-10-12: this page is history: an audit of the spec's pages as they stood on 2026-09-25, since superseded; its findings are not the spec, and the pages it names carry what was acted on
> [M] 2026-10-12 cut markers in place: private program [M] 8, account [M] 0, machine [M] 7, command [M] 0, funding [M] 0, planning process [M] 41, D8 [M] 10; total [M] 66

# C3 audit 03-spec-pages (a fresh-context read-only lens, 2026-09-25 ≈ 01:00 UTC; its readings are the lens's; [redacted 2026-10-12: planning process])

**C3 lens, surface 3: the spec's pages.** Read at `origin/main` = `325581d` (fetched 2026-09-25; the tip after S3's sighash family `0cbee92` and the two OWNERS commits). Tracker facts verified by REST GET today: 44 issues, 27 closed, 17 open; milestones S0 6/6, S1 12/12, S2 6/9 (open #24, #25, #35), S3 3/9 (open #26, #27, #28, #30, #31, #43), S4 0/6 (#32, #33, #34, #39, #41, #44), S5 0/2 (#36, #37), "Someday" open with 0 issues. The graph's 17 open / 11 blocked / 6 unblocked (#26, #28, #35, #36, #39, #43) matches the tracker; [redacted 2026-10-12: planning process] says lean #25 blocks **5** ([redacted 2026-10-12: private program], lean #32, lean #44), not six. Nothing edited, nothing written, no tracker write.

What HELD (so the report is not only holes): every record file under `docs/records/` is indexed in its README (22/22, S1's 191222 included); the two records that stand for the tip (`20260924-152539-make-check.txt` at `0cbee92`, `…-121122-…` at `eaba4af`) say twenty legs GREEN, check-pins 58 sites, the axiom check 206; PROVENANCE §1a's pins block is at bsv-rs 0.3.28 and the Makefile/check.sh vector names agree; D15/D15a and D72 are folded at DESIGN §2.1 (:162-168), §1.2 (:74-85), §9 (:584-603), INDEX §2/§4/§4b, STATE :56-57, `Numbers.lean:199-243`, `Ops/Expansion.lean:14-26`; D83/D83b landed in `docs/OWNERS:3-4` with the stamp check in `tools/hooks/git/commit-msg:23-40`; the harness gotchas page states the four-places-by-name rule and the stale-binary trap.

---

## (1) COHERENCE: contradictions, both sentences verbatim, which is right

**C1. The ECDSA "axiom" after Q9 (A), six sites against DESIGN §4.1.**
`NORTH-STAR.md:64-66`: "Signature verification (secp256k1 ECDSA) is an axiomatized predicate in the Lean and a trusted library in the evaluator; that trust boundary is named on every page that touches it."
`CLAUDE.md:33-34`: "(`#print axioms` shows only `[propext, Classical.choice, Quot.sound]` plus the declared signature-verification hypothesis)". Same sentence at `lean/BsvScript.lean:44-46`, `docs/HYPOTHESES.md:3-6`, `lean/AXIOMS-ALLOWED:2-3` ("The declared signature-verification hypothesis is added here by #11"), `docs/PROVENANCE.md:125` ("named, axiomatized in the Lean, linked in the evaluator").
vs `docs/DESIGN.md:297-298`: "**Every step is an executable Lean definition and the spec carries no axiom beyond Lean's three**" and `docs/HYPOTHESES.md:20-22` (its own §1): "**the spec carries no axiom beyond Lean's three**".
Right: DESIGN/HYPOTHESES §1-§2 (Q9 ruled (A) on #38, closed; `lean/AXIOMS-ALLOWED:4-6` lists three; the record `20260924-152539-make-check.txt` line "axiom check: OK (206 theorem(s); allowed = ['Classical.choice', 'Quot.sound', 'propext'])"). The constitution page, the rules page, the library root docstring and the provenance table still carry the pre-Q9 reading.

**C2. The dates.**
`NORTH-STAR.md:75-76`: "the calendar re-dated on measured velocity, never on a claim"; `docs/PLAN.md:16-17`: "The calendar is re-dated on measured velocity, never on a claim."; `docs/PLAN.md:43-44`: "[redacted 2026-10-12: planning process] proposes re-dates from the measured rate, the owner rules, the milestones move."; `docs/PLAN.md:64`: "the fan-out machine; re-date, never cut".
vs `HANDOFF.md:9`: "THE DATES DO NOT MOVE (the owner, ≈ 19:02 UTC): S2 11-09, S3 11-30, S4 12-14, S5 12-31" and [redacted 2026-10-12: planning process] (a pole is answered with capacity, never a re-date, never a cut).
Right: the owner's ruling of 2026-09-23 (later, constitutional). The spec's founding pages still carry the 2026-09-21 re-date rule at four sites.

**C3. The reviewer, inside one page.**
`docs/PLAN.md:19-20`: "**Money.** A laptop, a node host, a Lean reviewer at S4."
vs `docs/PLAN.md:52`: "| the reviewer | none: the three-lens swarm is the review, the public is the audit after v1.0 (owner, 2026-09-23) | ruled |".
Right: :52 (NORTH-STAR §5:56-58, #32's title "no external reviewer").

**C4. The tracker's shape.**
`README.md:44`: "Six GitHub milestones (S0 → S4, then Someday), 37 issues"; `docs/PLAN.md:88-95` (the map ends "Someday | #35–#37"); `HANDOFF.md:371`: "S2 #18–#25 · S3 #26–#31 · S4 #32–#34 · Someday #35–#37".
vs the tracker (44 issues; S5 exists; #35 in S2 by D44, #36/#37 in S5 by D22, #38-#44 exist) and `docs/STATE-OF-THE-WORLD.md:69`: "7 milestones (S0–S5, Someday), 44 issues".
Right: the tracker. (`HANDOFF.md:9` itself lists HANDOFF §2's "Someday #35–#37" among the sentences "[redacted 2026-10-12: planning process]"; it stands.)

**C5. The calendar without S5.**
`HANDOFF.md:403-409` (the table's last row): "| S4 · Review and release | 2026-12-14 | 2027-09-21 |" and `docs/PLAN.md:33-39` (the same five rows).
vs `HANDOFF.md:9`: "S5 12-31" and the tracker's milestone 7 "S5 · Beyond the script verdict" due 2026-12-31.
Right: the tracker (D22). Neither calendar carries S5.

[withheld: D8]

[withheld: D8]

**C8. "The eight gate sites", the sentence the C2 block named, still standing.**
`corpus/INDEX.md:34` (and `spec/rules.md:28`, generated from it): "`interpreter.cpp:40–44` and the eight gate sites (285, 433, 796–804, 1491–1497, 1641–1647, 1664–1670, 2321–2334, 2438–2445)".
vs `docs/DESIGN.md:414-419`: "Seven restrictions hang on it, at seven `EnforceNonMalleability` sites plus one inlined read ... (corrected 2026-09-23, #19's lens: the earlier "eight sites" counted the inlined read as a call)" and `docs/STATE-OF-THE-WORLD.md:13`.
Right: DESIGN (#19's exhaustive grep; the Correction on #2, 5804164251). The eight numbers are the eight READ sites (seven calls plus the inlined `IsMalleableTxnVersion` read at 2321-2334); the sentence needs that qualifier, as `HANDOFF.md:9` already lists it among the strikes owed.

**C9. The SV-node runner's timeouts.**
`docs/DESIGN.md:533-535`: "the per-script (3 ms, CPU clock) and total (100 ms) validation timeouts are pinned by the runner and a `timeout` or `skipped` is `undecided`".
vs `harness/oracle/README.md:56-58`: "The pinned wall: a script is cancelled after `maxstdtxvalidationduration` (`:870–876`; five minutes here) and the call after the runner's `totalTimeout` (60,000 ms by default; `:600–609`)" and `corpus/INDEX.md:286`: "`totalTimeout` 60,000 ms".
Right: the oracle README/INDEX §4c (the record run's configuration, `20260924-030828-svnode-record-s3.md`; #27's comment 5808583457 "within the RPC's 60,000-ms `totalTimeout`"). DESIGN §7 carries the design-time numbers, unlabeled.

**C10. DESIGN §7 against the harness that exists.**
`docs/DESIGN.md:520-521`: "**bsv-rs** in-process (`engine.rs`, done; its `Native`/`V1Strict`/`V2MinimalOnly` modes are the mode differential)." vs `HANDOFF.md:187-189`: "The runner under the node's word (`harness/src/engine.rs`: `EngineConfig.flags` through `Spend::set_flags`; the default = the standard word of a post-Chronicle block `0x3D47FF`". Right: HANDOFF (the record's `run_bsvrs` line shows `flags: Some(ScriptFlags(0x3d47ff …`).
`docs/DESIGN.md:522-524`: "**SV-node** (#27): ... on the node oracle ([redacted 2026-10-12: private program]) configured with **mainnet activation heights**" vs `harness/oracle/README.md:1-8`: "the spec's own SV-node instance ... a private regtest instance with an EMPTY chain is the whole oracle". Right: the oracle README ([redacted 2026-10-12: machine], the record [redacted 2026-10-12: machine]; [redacted 2026-10-12: planning process] already lists "the node oracle ([redacted 2026-10-12: private program])" as [redacted 2026-10-12: planning process]).
`docs/DESIGN.md:549`: "**go-sdk** in-process if adopted (#29)." vs `HANDOFF.md:231-233`: "beside two out-of-process adapters over JSON lines, `harness/engines/go/main.go` and `harness/engines/ts/runner.mjs`". Right: HANDOFF (#29 closed; ts-sdk absent from DESIGN §7 altogether).
`docs/DESIGN.md:528-529`: "whether that is the consensus *path* is Q6" and §9:580-583 "Answered from source, not assumed" (without the answer) vs `harness/oracle/README.md:43-56` (Q6 answered: the consensus limits on the policy path). Right: the oracle README; DESIGN §9 should carry the one-line answer.

**C11. Who owes `tools/cite_check.py` (three owners named, no file).**
`docs/DESIGN.md:638-641`: "S1 adds `tools/cite_check.py`: every `file:line` citation ... and `make check` fails when a pattern moves."; `docs/lanes/sidecar.md:7`: "S1 adds `tools/cite_check.py`"; `docs/lanes/sidecar.md:13`: "`tools/cite_check.py` (S1's DESIGN §10 item) is still owed".
vs `docs/OWNERS:10`: "S4b harness/engines tools/cite_check.py ..." and `docs/lanes/harness.md:9`: "#43's records half (done in the writer; `cite_check.py` is S4b's)" and #43 (lane: harness, sidecar).
Right: OWNERS/#43 (S1 is closed without it; the file does not exist at origin/main; the tree has no `run_gobdk.rs`/`run_teranode.rs` either).

**C12. PARAMETERS on bsv-rs's number width, inside one page.**
`docs/PARAMETERS.md:111` (the `SCRIPT_UTXO_AFTER_CHRONICLE` row, bsv-rs column): "the number width is unbounded there (no `MaxScriptNumLength`)".
vs `docs/PARAMETERS.md:36`: "since 0.3.28 the reference's limit under a word: 750,000 / 32,000,000 by the coin's era on the block path, the policy default 10,000 on the mempool path" and `corpus/INDEX.md:104`: "the 2 `limits.maxscriptnumlength` witnesses of 0.3.27 are the crate's tests since 0.3.28".
Right: :36/INDEX (bsv-rs#17; eras-00041 invalid at 0.3.28, INDEX:9). Also `:89` "the last column is its 0.3.27 behaviour, with the 0.3.24 knob in parentheses" vs `:91` "bsv-rs 0.3.28 (0.3.24 in parentheses)".

**C13. PARAMETERS §1's bsv-rs citations are 0.3.24's lines under a 0.3.28 header.**
`docs/PARAMETERS.md:39`: "**32,000,000 per stack** (main and alt separately, no per-element overhead) `spend.rs:54, 291–294, 1642`" (and `:38` "`spend.rs:57`", `:40` "`spend.rs:51, 338`").
vs `docs/PROVENANCE.md:17`: "`MAX_SCRIPT_ELEMENT_SIZE` 1 GiB at 69, `DEFAULT_MEMORY_LIMIT` 32,000,000 at 72, `MAX_MULTISIG_KEY_COUNT` at 75" (3,612 lines at 0.3.28) and `corpus/INDEX.md:146`: "`spend.rs:72` `DEFAULT_MEMORY_LIMIT` 32,000,000".
Right: PROVENANCE/INDEX (re-cited at the bump commit `e78a043`; PARAMETERS §1's column header says "bsv-rs 0.3.28" over 0.3.24 line numbers).

**C14. The state page's SV-node row contradicts itself and the tracker.**
`docs/STATE-OF-THE-WORLD.md:64`: "no verdict recorded yet (the run is one command when #26 opens)" and, in the same row, "the verdicts recorded as `sv-node@v1.2.2` / `sv-node-mempool@v1.2.2` with both instances' settings in the manifests". Right: the record (INDEX:9 "SV-node's verdicts ... recorded"); rule 9 (the old sentence gone) not applied.
`docs/STATE-OF-THE-WORLD.md:64` (the row's title): "(#27; the done-bar: every corpus, re-run as #26's families land)" vs #27's body: "**Done-bar.** The seed corpus run end to end with verdicts recorded; the runner documented." Right: the tracker is the fact source (rule 2), [redacted 2026-10-12: planning process]; the page anticipates a done-bar the tracker does not carry. By #27's own text the bar is met (`docs/records/20260924-030828-svnode-record-s3.md`, `harness/oracle/README.md`); what keeps it open is the `Depends on. #26` edge.

**C15. The state page's seed row against the index.**
`docs/STATE-OF-THE-WORLD.md:23`: "sha256 `98470be82501dab3…` ... bsv-rs 0.3.24 verdicts invalid 4,579, valid 5,421 ... `[X]`".
vs `corpus/INDEX.md:9`: "`642ff4f1b8255dbfa159c901789f977ab8144a28997501f2653ec9671fea72ea` (re-stamped 2026-09-24 at the bump to bsv-rs 0.3.28 ...) | `bsv-rs@0.3.28` ...: invalid 4,658, valid 5,342".
Right: INDEX (the manifest; the pins leg GREEN at 0.3.28). "The only page a number may be quoted from" (:3) is three re-stamps behind on the seed.

**C16. The state page's pin rows.**
`docs/STATE-OF-THE-WORLD.md:62`: "bsv-rs `0.3.27` with Cargo.lock's checksum" vs `docs/PROVENANCE.md:50`: "bsv-rs.crate = 0.3.28". `docs/STATE-OF-THE-WORLD.md:65`: "Teranode v0.15.9 and bsv-rs 0.3.24, every cell `[SRC]`" vs `docs/PARAMETERS.md:9`: "and bsv-rs **0.3.28** (the spec's pin since 2026-09-24". `docs/STATE-OF-THE-WORLD.md:69`: "44 issues, 26 closed (REST, 2026-09-24 02:25 UTC)" vs the tracker (27 closed; #42 at 12:22 UTC; [redacted 2026-10-12: planning process] "27/44"). Right: PROVENANCE, PARAMETERS, the tracker.

**C17. The top block's theorem count against the tip's record.**
`HANDOFF.md:17`: "**204 theorems** axiom-clean `[X]` (the `lean/AxiomCheck.lean` list at d66ded6, the record `docs/records/20260923-193441-make-check.txt`" (and `HANDOFF.md:9` "204 theorems on the axiom list").
vs `docs/records/20260924-152539-make-check.txt`: "axiom check: OK (206 theorem(s)" and `HANDOFF.md:345`: "`AxiomCheck.lean` 226 lines with 206 `#print axioms` lines" (my count of `#print axioms` lines at origin/main: 206).
Right: the record (206 since D72's T8 re-statement).

**C18. The top block's "zero witnesses" against the differential at 0.3.28.**
`HANDOFF.md:26-27`: "the seed corpus 10,000 agree at bsv-rs 0.3.27 in both columns ... with **zero witnesses left** at 0.3.27".
vs `corpus/INDEX.md:105`: `corpus/gen` "**10** (5 classes × 2 columns ...)" and `:102`: stack "**2** (`engine.resource-abort` × 2 columns".
Right: INDEX (the records 110732 and 150154). True of the seed alone; the top block never mentions `corpus/gen` (1,008 entries), the SV-node record (§4c) or the crate's four classes.

**C19. `docs/OWNERS` against [redacted 2026-10-12: planning process], and against CLAUDE.md's lanes table.**
`docs/OWNERS:7`: "S1 lean/BsvScript/Properties lean/BsvScript/VersionGate* lean/Test docs/lanes/lean.md"; `:8` S2's globs (Flags.lean, Eras, P2SH, ErasCheck, run_diff.rs, specgen.py, spec, DESIGN, INDEX, lean.md); no line names `lean/BsvScript/Numbers.lean`, `Machine.lean`, `Sighash.lean`, `Ops/*`, `Hash/*`, `Crypto/*`, `Eval.lean`, `Tx*.lean`, `Params.lean`, `Opcodes.lean`, `lean/AxiomCheck.lean`, `lean/AXIOMS-ALLOWED`, the lakefile/manifest/toolchain, `eval/`, `docs/HYPOTHESES.md`, `NORTH-STAR.md`, `docs/PLAN.md`, `docs/lanes/sidecar.md`.
vs `tools/hooks/git/pre-commit:60`: "owned by nobody (no docs/OWNERS line matches it); add a line, [redacted 2026-10-12: planning process]" (exit 1).
vs `docs/lanes/harness.md:57` (to S1/S2): "`lean/BsvScript/Sighash.lean:31–36` ... the sentence is yours to strike (rule 9)" and `:33` (to S1): "Your bump commit reduces to `docs/lanes/lean.md:15/:39` and `docs/HYPOTHESES.md:31/:54`".
Right: the hook (the code). [redacted 2026-10-12: planning process] Also `lean/BsvScript/VersionGate*` matches no file (the module is `lean/BsvScript/Properties/VersionGate.lean`).
`CLAUDE.md:86-88`: "| **lean** | `lean/`, `eval/`, `spec/` ... | **harness** | `harness/`, `corpus/` ... | **sidecar** | the state page, the provenance pins, the consensus-vs-policy census, the spec index" and `docs/lanes/README.md:3`: "Each lane (lean · harness · sidecar) writes docs/lanes/<lane>.md" vs OWNERS's seats [redacted 2026-10-12: planning process] (`spec` a S2/S3 tie; PROVENANCE, PARAMETERS, INDEX S3's; `eval/` nobody's; `docs/lanes/block.md` named at :11, absent). Right: OWNERS (in force, the hook reads it).

**C20. #28's host after D14.**
`docs/lanes/harness.md:21`: "#28 Teranode (the host is the owner's register)" vs `HANDOFF.md:9`: "D14 the GoBDK shim (#28), the instance a dated leg (#41, local on [redacted 2026-10-12: machine], D37)" and #28's body: "no instance is needed for the script verdict". Right: D14. (`harness.md:21` is the 2026-09-23 Next, superseded by `:9`, still standing beside it.)

**C21. Inside HANDOFF §0's S3 block: the D8 count and the bypass count.**
[withheld: D8]
`HANDOFF.md:347`: "THE HOOK: the family's commit was made with `--no-verify` for three paths" vs [redacted 2026-10-12: planning process]: "eleven paths the hook refused (the three named plus `docs/DESIGN.md` and seven `spec/` pages)". Right: the lens's count ([redacted 2026-10-12: planning process]).
`HANDOFF.md:351` (4)(b): "unless [redacted 2026-10-12: planning process] adds `corpus/INDEX.md` to S3's line (surfaced, not decided)" vs `docs/OWNERS:3`: "S3's line gains `corpus/INDEX.md`" (D83, 15:50 UTC). Right: OWNERS.

**C22. The corpus index's §1 against its own §4 and the file (the sighash family's 52 entries).**
`corpus/INDEX.md:16`: "| `corpus/gen/gen.jsonl` | 956 (954 applicable to bsv-rs ...) | ... | `61c0ab5206de9399af2ccc543e28377a5397810768f48aa5496cebcf7ad445a6`".
vs `corpus/INDEX.md:105`: "1,008 (1,000 applicable to bsv-rs ...; 956 until the sighash family)" and the file at origin/main: 1,008 lines, sha256 `bc16ec575439f547…`; `corpus/gen/manifest.json`: `count 1008`, `sha256 bc16ec57…`.
Right: the file/manifest/§4. §1's row (S3's since D83) was not re-cut at the family: the funnel rule's own page is stale on the count and the sha. `[redacted 2026-10-12: planning process]` ("gen 956") the same.

**C23. The window model in CLAUDE.md.**
`CLAUDE.md:8`: "this program runs in its own window, [redacted 2026-10-12: planning process] in `[redacted 2026-10-12: machine]`" vs `HANDOFF.md:47`: "since 2026-09-23 the windows are the lane worktrees ([redacted 2026-10-12: planning process]; rule 15 ...)". Right: HANDOFF/OWNERS.
`CLAUDE.md:97`: "harness/run --corpus corpus/seed --impl bsv-rs   # once seeded" vs the tree (no `harness/run`; it is #31's Deliverable) and `harness/README.md:29` (`run_bsvrs --corpus ../corpus/seed --smoke`). Right: harness/README.

**C24. The hooks' README against the hooks.**
`tools/hooks/git/README.md:20-25` (commit-msg described as the closing-keyword check only) and `:33-37` (pre-commit described without the longest-matching-glob rule) vs `tools/hooks/git/commit-msg:23-26` ("THE STAMP CHECK (2026-09-24 ...)") and `tools/hooks/git/pre-commit:9-12` ("the longest matching glob wins, 2026-09-24"). Right: the code (`docs/OWNERS:2`). The README only carries the pre-push re-key (:49).

**C25. The tracker against the rulings (cross-program).** lean #35's body carries "Depends on #23 (landed)" in its re-cut paragraph and "**Depends on.** #25." below it, "a gate for the siblings, not a someday" and "**Done-bar.** Not a gate." (D40 ruled "gates, staffed"); [redacted 2026-10-12: private program] [redacted 2026-10-12: private program] ([redacted 2026-10-12: planning process]) where D22/D44 pointed the consumers at #35 ([redacted 2026-10-12: planning process]). Right: D22/D40/D44.

---

## (2) STALE AND RETIRED: superseded rulings and figures, with the sites

**The reference pin (bsv-rs 0.3.24 / 0.3.27 sentences that read as current):** `docs/HYPOTHESES.md:31` ("`corpus/crypto/ecdsa-bsv-rs-0.3.24.jsonl`: 1,340 cases signed by bsv-rs 0.3.24") and `:54` ("bsv-rs 0.3.24's verdicts and signatures"); `corpus/README.md:9` ("10,000 entries with bsv-rs 0.3.24's verdicts"); `docs/PARAMETERS.md:89, :111, :38-40` (C12/C13), `:257` (the witnesses table's header "bsv-rs 0.3.24 (script only)"), `:259` ("the same at 0.3.27"); `docs/STATE-OF-THE-WORLD.md:23, :33` ("vs bsv-rs 0.3.24"), `:62, :65`; `HANDOFF.md:26-27, :374` ("`corpus/seed` 10,000 entries (bsv-rs 0.3.24 verdicts ...) ... `corpus/witnesses` (... 36 witnesses, #15)"); `docs/lanes/lean.md:15` ("`ecdsa-bsv-rs-0.3.24.jsonl`"; "Q9 owner-owed") and `:5` (T8's "`_undefined`", gone at D72); `lean/Bsvs/SelfTest.lean:16-17` ("bsv-rs enforces the relay restrictions, `spend.rs:190–192`", 0.3.24's lines; dead guards per `lean.md:27`); `tools/specgen.py:349` (the latent heading "the differential against bsv-rs 0.3.24, #15"); `docs/PROVENANCE.md:196` (the downstream note at 0.3.27, "the spec's pin since 2026-09-23"). The bump's S1 half (`harness.md:33`: `lean.md:15/:39`, `HYPOTHESES:31/:54`, the eleven generator headers) is unlanded.

**The sighash family's 52 entries:** `corpus/INDEX.md:16` (956, the old sha: C22); `[redacted 2026-10-12: planning process]` ("gen 956"); `docs/lanes/harness.md:5` (the "State" paragraph stops at the initial cut; the family only in Next at :9); `docs/lanes/harness.md:59-61` ([redacted 2026-10-12: planning process]: "TWENTY Explanation keys ... twenty DISTINCT classes"; twenty-four keys since `0cbee92`, [redacted 2026-10-12: planning process]) and `:63-65` ([redacted 2026-10-12: planning process]: "the crate's two classes"); `HANDOFF.md:351` (C21); `HANDOFF.md:9` (the C2 block: "S2 at 6/8", "26 of 43 issues", "55 sites", "204 theorems", "The spec has NO Modal tripwire route", all pre-dating the route, the pin, the family and #42; the block says it is re-cut at C3).

**The classifier (D83):** every page still describes it as code: `corpus/witnesses/README.md:7-8` ("classified by a rule of `corpus/INDEX.md` §2 from the entry's own rule and the shapes of its scripts (`harness/src/bin/run_diff.rs`)"), `corpus/INDEX.md:165-166`, `docs/lanes/harness.md:61` ("the classification of an engine's divergences lives in `run_engine.rs`'s `explain`/`rule_record`"), `docs/lanes/harness.md:3` ("never edits S2's `run_diff.rs`", edited three times by S3 under bypass). The ruling lives only in `docs/OWNERS:3` and #31's comment 5817882090; no page names the table's file, format or the reader's one touch, and #31's body/done-bar was not re-cut. [redacted 2026-10-12: planning process].

**The hook rule (D60/D60b/D83b):** `tools/hooks/git/README.md:20-37` (C24); `docs/lanes/harness.md:7` last sentence ("`lean/` is S1/S2's ([redacted 2026-10-12: planning process])": `lean/Bsvs` is S3's since D83, and D83b ends the per-family bypass); `HANDOFF.md:347` ("three paths") and `:351(b)` ("surfaced, not decided"); `CLAUDE.md:82-89` (the three-lane table); `docs/lanes/README.md:3`.

[withheld: D8]

**The ECDSA axiom (Q9 (A)):** C1's six sites; also #11's title (closed, historical).

**The dates and the reviewer:** C2, C3, C5; `NORTH-STAR.md:71-76` (§7 Rulings carries only the birth ruling: no D8, D13, D14, D15, D22, D38, D72, D83, no "the node oracle substitutes for the block", no "the dates do not move").

**The windows and lanes:** `CLAUDE.md:8` ([redacted 2026-10-12: planning process]), `:30-31` ("At S0 it fails loudly"), `:97` (`harness/run`); `README.md:3` ("[redacted 2026-10-12: planning process]"; [redacted 2026-10-12: planning process]; README.md is unchanged since C2 by `git diff c4b932a origin/main`); `docs/lanes/sidecar.md:1, :7` (stamped 2026-09-22; a Next of #13/#17/#21, all closed; "S1 adds `tools/cite_check.py`"); `docs/lanes/harness.md:21-23` (two older Nexts standing under the live one: "#28 Teranode (the host is the owner's register)", "#15 the initial differential run"); `lean/README.md:3` ("Empty at birth"); `docs/PLAN.md:26` ("do not have ... a pinned reference source"), `:77-78` ("CI runs it": the workflow was deleted at `5ac873f`); `tools/check.sh:3-12` (the header names ten of the twenty legs).

**The tracker map and the calendar:** C4, C5; `HANDOFF.md:373` (the module list without VersionGate/Eras/P2SH; "`Numbers` with 33 theorems" vs STATE:33 "75 `theorem` declarations"); `HANDOFF.md:375` ("`make check` GREEN (seventeen legs ...)"); `docs/STATE-OF-THE-WORLD.md:34, :44` (1,058 flow entries, 682 arith, 36 witnesses, dated rows presented in the current table).

---

## (3) LABELS: numbers without a label, or with an unsupported one

- `README.md:44` "Six GitHub milestones ... 37 issues" and `:54-72` (the whole Check paragraph: "1,340 ECDSA cases", "eight mainnet inputs", "every byte", no label anywhere; [redacted 2026-10-12: planning process]).
- `HANDOFF.md:373-375` (the code, corpus and tripwire rows of §2: every count unlabeled and most stale: "33 theorems", "1,058", "682", "262", "64 signature cases", "36 witnesses", "seventeen legs").
[withheld: D8]
- `docs/DESIGN.md:533-534` "3 ms, CPU clock" and "100 ms": unlabeled and contradicted (C9).
- `docs/PLAN.md:3` "Every number `[E]`" and `:50-51` `[E]`: a label outside the vocabulary (`README.md:81-82`, `CLAUDE.md:35-36` define `[EST]`); `docs/PLAN.md:26` "1,143,318 executions, 0 divergences" carries no label there (STATE:22 labels it `[M]`); the "conservative estimate" columns at `docs/PLAN.md:33-39` and `HANDOFF.md:403-409` carry no `[EST]`.
- `docs/PARAMETERS.md:38-40` bsv-rs cells: `[SRC]`-style cites (`spend.rs:57`, `:54`, `:51, 338`) to the wrong pin (C13).
- `docs/STATE-OF-THE-WORLD.md:23` (`[X]` on a superseded sha and split: C15), `:62` (`[X] 2026-09-23` naming 0.3.27 beside a 58-site record at 0.3.28), `:65` (`[SRC]` on "bsv-rs 0.3.24"), `:69` (`[M]` dated 02:25 UTC, 26 closed; 27 since 12:22 UTC), `:59` (the tripwire row labeled `[X] 2026-09-23` while its text runs to the 2026-09-24 records).
- `docs/HYPOTHESES.md:22` "(53 at #10, more at #11)": "more" is not a count.
- `spec/README.md:12` "111 opcodes ...; 181 theorems; 13728 generated corpus entries over 109 rule ids, 5 flagged; 12 witness rows": the generator's counts, no label, and three different "theorem" counts across pages with no reconciliation sentence (181 with a docstring, 206 on the axiom list, 75 by `grep` in Numbers alone: `HANDOFF.md:160` explains the three counts once, no current page does).
- `corpus/README.md:9` "10,000 entries with bsv-rs 0.3.24's verdicts": no label, stale.
- `docs/lanes/harness.md:61` "≈ 15–20 min cold [EST]": fine; `HANDOFF.md:355` the `[D]`/`[M]` pairs: fine (the model to keep).

---

## (4) THE NORTH STAR: the charter against what is built, decided or owed

**The charter sentence names three implementations; the harness runs five.** `README.md:4-6`, `[redacted 2026-10-12: planning process]`, `NORTH-STAR.md:54-55` and `docs/PLAN.md:7-9` say "against SV-node, Teranode and bsv-rs". Built: three engines (bsv-rs in-process; go-sdk v1.5.2 and @bsv/sdk 2.8.0 out of process, #29 closed) and one oracle recorded on two instances (SV-node, `corpus/INDEX.md` §4c); Teranode is the shim (#28, D14, not started) plus the instance leg (#41, D37). The pins: #40 closed, 58 sites. No charter page names the SDKs or [withheld: D8]; the tuple's row 2 (`NORTH-STAR.md:34`, "every divergence with any other implementation reported with a witness") covers them only implicitly.

**The owner's ruling "the node oracle substitutes for the block"** is stated at `docs/DESIGN.md:595-596`, `docs/STATE-OF-THE-WORLD.md:57` and `harness/oracle/README.md:43-56` (Q6), and is absent from `NORTH-STAR.md` §6-§7 (the constitution page still says only "the chain follows SV-node until the humans decide", :67-69).

**Promises without an issue:** (a) [withheld: D8]; (b) the classifier table (D83: a comment on #31, no deliverable line in #31's body); (c) the `tx.*` transaction-level oracle-mode note on #27 ([redacted 2026-10-12: planning process]; no issue line); (d) D80, the bake as a Modal function (`docs/lanes/harness.md:9`; no spec issue); (e) [redacted 2026-10-12: machine] policy instance ("the record run's next step when [redacted 2026-10-12: machine] is used", `harness/oracle/README.md:31-32`, `HANDOFF.md:349`; no issue); (f) the tuple's row 4 (`NORTH-STAR.md:36`: "termination under the parameters" as a machine-checked property) against `docs/DESIGN.md:627-631` ("Determinism and termination are by construction ... listed as definitional facts, not theorems"; `verifyScript_deterministic` IS on the axiom list, `AxiomCheck.lean:49`, termination is not a theorem) with #25 naming neither; (g) `docs/BLOCK-CONSENSUS.md` and `docs/SECOND-FORMALIZATION.md` (named as S5w's files at `docs/OWNERS:11`, absent, and #36/#37 have no page sentence beyond "#36/#37 in S5 (12-31)" at `HANDOFF.md:9`); (h) the "Someday" milestone still exists, empty, and `README.md:44` names it as a phase.

**Issues without a page sentence:** #36, #37 (S5: no PLAN §2 row, no HANDOFF §6 row, no page); #41 (only `HANDOFF.md:9`); #44 (35b: no page); #39 (the monthly recon's rule and log: only "#39 outlives" at `harness.md:9/:21` and the initial data point at `:18`); #28 (S4b was cut at D46 but has no HANDOFF block, no lane-page state, and its OWNERS files `run_gobdk.rs`/`run_teranode.rs` do not exist); #43's cite_check half (three owners, C11); #25 (below).

**The cross-program dependency, lean #25.** The graph: #25 blocks [redacted 2026-10-12: private program], lean #32, lean #44 ([redacted 2026-10-12: planning process]: 5); #25 waits on #24, #24 on #26. What #25 needs by its body: #18 (closed), #24 (D13: "the full corpus" = after #26's families), "Properties/ at full scope", "spec/ v2 with no rule unexercised by the corpus (or flagged)", done-bar "Sorry-free; the flagged list empty or explained" (five flagged today: `tx.locktime`, `tx.sequence`, `tx.rules`, `splice.num2bin.memory`, `params.policy.maxtxsizepolicy`, `spec/rules.md:37, :56-58, :74`). Do the pages say it? No page defines "full scope" (which theorems over which opcodes: DESIGN §9 stops at #16's initial theorems; `docs/lanes/lean.md:31` says only "#25 with S2 (set 3's)"); #25 has 0 comments; no page states what the siblings consume from #25 rather than #35 (D22/D44 made #35a the vendoring interface; [redacted 2026-10-12: private program]). The dates: #24 and #25 sit in S2 (due 2026-11-09) behind #26 (S3, due 2026-11-30); `HANDOFF.md:353` states it ("#24 (S2, 11-09) still depends on #26 (S3, 11-30)") and [redacted 2026-10-12: planning process] surfaced "#24 moves to S3's milestone or #26 lands early; the date stays"; the tracker is unchanged, so the graph cannot meet S2's date unless the remaining families land by early November, and no page names that as the plan. The unlabeled [redacted 2026-10-12: private program] question for the sibling consumers therefore rests on an issue whose content is unwritten.

---

## (5) THE HARNESS: what `make check` covers, what #30 needs, the order and the blockers

**The twenty legs today** (`tools/check.sh:253`, `Makefile:7`, `tools/check_route.sh:6`): pins (58 sites, `check_pins.py`), lean (sorry-free), axioms (206), numbers, flow, sighash (+ `sighash_verify`), arith, stack, crypto, seed, scripttests, txtests, flags, spec (`specgen --check`), bytes, versiongate, eras, witnesses, eval (`bsvs --self-test`), harness (`run_bsvrs --smoke` on the seed, `run_diff` on the seed, `run_engine` gosdk + tssdk on the seed). Routed local under load 20, Modal above (the container skips the clones and the built node BY NAME). The pages state this consistently (STATE:59, harness.md:5, [redacted 2026-10-12: planning process], CLAUDE rule 17).

**Outside the tripwire, by design and stated:** `run_svnode` (never a leg, `tools/check_route.sh:11-12`); `make diff` and `make enginesdiff` on the seven non-seed corpora (records per family, not legs: `harness.md:7` names the stale-binary trap the D72 chain hit); the GoBDK shim and the Teranode instance (absent); `tools/cite_check.py` (absent; C11). Not stated anywhere: that a family's four differentials are guarded by no leg after their record (only the seed re-runs on every check).

**What the conformance report #30 needs** (body: "Depends on. #26, #27, #29 (closed); Teranode's column is added when #28's shim lands (D14)"; deliverable `docs/CONFORMANCE-<date>.md`; done-bar "every witness reproducible by one command"): #26's remaining families (the five flagged rules; random scripts and mutators; the C++ unit tables; the 173,805 replay read; the deliverable in #26's body still says `harness/gen/` and a mutator, where what exists is `harness/src/bin/gen.rs` writing `corpus/gen`); #27's re-run per family (the record run is done on every existing corpus: `20260924-030828-…`, #27's comments 5808583457/5817143091; its done-bar is met by its own text and it stays open on the `Depends on. #26` edge, C14); #28's shim (no window, no page state: the only place the shim gates #30 is #30's own Depends clause, [redacted 2026-10-12: planning process], while D14's wording is "the Teranode column is added when the shim lands": whether #28 gates the report or only its column is undecided on any page).

**The order the pages state** (`docs/lanes/harness.md:9`, the live Next): #26 families (`tx.*` with a transaction-level oracle mode, then `splice.num2bin.memory`, `params.policy.*`, random scripts and mutators, the C++ tables) → #27's re-run → #43's records half → #30 → #31; S4b (`HANDOFF.md:9`): #28 → #41 (with #43's `cite_check.py`). The graph: #24 ← #26; #27 ← #26; #30 ← #26, #27, #28; #31 ← #30; #32 ← #25, #30; the unblocked six are #26, #28, #35, #36, #39, #43. Agreement: the S3 order matches the graph except that no S3 page names #28 in #30's chain and no page gives #28 a state; [redacted 2026-10-12: planning process]

---

## (6) The ten most important fixes for the spec's pages before new lanes open, ranked

1. Re-cut `HANDOFF.md` §0's top block at C3 as `HANDOFF.md:9` promises: 206 theorems (:17), 27/44 and S2 6/9 (:9), the eighth corpus at 1,008 with the SV-node record and the crate's four classes (:26-32), [withheld: D8], the Modal route (:9 "NO Modal tripwire route"), [withheld: D8], the eleven-path bypass (:347).
2. Re-cut `HANDOFF.md` §2 and §6 (:371, :373-375, :401-409) and `README.md:3, :44, :54-72`, `docs/PLAN.md:88-95`: 7 milestones / 44 issues, #35 in S2, #36/#37 in S5, #38-#44, the eight corpora at 0.3.28, twenty legs, the S5 row at 12-31 in both calendars.
3. Close the ownership holes in `docs/OWNERS:7-12` (the core semantics under `lean/BsvScript/`, `lean/AxiomCheck.lean`, `lean/AXIOMS-ALLOWED`, the lakefile trio, `eval/`, `docs/HYPOTHESES.md`, `NORTH-STAR.md`, `docs/PLAN.md`, `docs/lanes/sidecar.md` match no line and the hook refuses every window at `pre-commit:60`; the dead glob `lean/BsvScript/VersionGate*`), then re-cut `CLAUDE.md:82-89` and `docs/lanes/README.md:3` to the seats OWNERS names, [redacted 2026-10-12: planning process].
4. Strike the "axiomatized ECDSA predicate / declared signature-verification hypothesis" at `NORTH-STAR.md:64-66`, `CLAUDE.md:33-34`, `lean/BsvScript.lean:44-46`, `docs/HYPOTHESES.md:3-6`, `lean/AXIOMS-ALLOWED:2-3`, `docs/PROVENANCE.md:125` (Q9 (A); DESIGN:297-298 is the sentence).
5. Strike the re-date rule at `NORTH-STAR.md:75-76`, `docs/PLAN.md:16-17, :43-44, :64` for the owner's "THE DATES DO NOT MOVE" (HANDOFF:9), fix `docs/PLAN.md:19-20` against `:52` (no reviewer), and add to `NORTH-STAR.md` §7 the rulings that now bind (the oracle substitutes for the block, no external reviewer, Apache-2.0 direction at S4, the dates).
6. Land the D72/measurement strikes at their sites: `lean/Bsvs/Run.lean:22-24`, `eval/README.md:43`, `harness/oracle/README.md:78-80`, `lean/BsvScript/Sighash.lean:31-33` (then `make spec` for `spec/modules.md:757`), `HANDOFF.md:388-390`, and the "eight gate sites" qualifier at `corpus/INDEX.md:34` (then `spec/rules.md:28`).
7. Finish the 0.3.28 pin on the pages: `docs/HYPOTHESES.md:31, :54`, `corpus/README.md:9`, `docs/PARAMETERS.md:38-40` (re-cite at 0.3.28's `spend.rs` as PROVENANCE:17 does), `:89, :111, :257, :259`, `docs/STATE-OF-THE-WORLD.md:23, :33, :62, :65, :69`, `docs/lanes/lean.md:5, :15`, `tools/specgen.py:349`, `lean/Bsvs/SelfTest.lean:16-17`, and `corpus/INDEX.md:16` (1,008 entries, sha `bc16ec57…`) with `[redacted 2026-10-12: planning process]`.
8. Re-cut `docs/DESIGN.md` §7 (:517-553) to the harness that exists (the runner under the node's word, the spec's own two instances with the 60,000-ms / five-minute walls, go-sdk and ts-sdk out of process, the GoBDK shim per D14, Q6's one-line answer in §9:580-583) and §10 (:638-641) to name #43 and its owner once (with `docs/lanes/sidecar.md:7, :13` and `docs/OWNERS:10` agreeing).
9. Make the tracker and the pages agree on #27, #25 and #35 by REST: #27's done-bar re-cut to "every corpus, re-run as #26's families land" or #27 closed on its record (STATE:64's own "no verdict recorded yet" struck); #25's body given the scope no page defines (the property list, termination's status, what "spec v2" adds, the consumers' interface at #35 not #25, and the S2-behind-S3 date question decided); #35's two Depends lines and "Not a gate" reconciled to D22/D40/D44; a decision stated on whether #28 gates #30 or only its column.
10. Re-stamp the operational residue so a fresh lane reads true: `CLAUDE.md:8, :30-31, :97`, `docs/lanes/sidecar.md` (dead since 2026-09-22) and `docs/lanes/harness.md:21-23` (the superseded Nexts), `tools/hooks/git/README.md:20-37` (the stamp check and the longest-glob rule), `tools/check.sh:3-12`, `lean/README.md:3`, `docs/PLAN.md:26, :77-78`, and give the classifier table (D83), D80, [redacted 2026-10-12: machine] policy instance and [withheld: D8] a home on an open issue and one page sentence each.

[redacted 2026-10-12: planning process]
