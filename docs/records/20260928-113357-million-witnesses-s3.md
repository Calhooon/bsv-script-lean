[export: 1 line withheld by tools/export_public.py, the sibling trees' lines; the original is in the private history]
# The audit's item (f), the Studio half: the 10^6 run's four witnesses as `corpus/million`, re-run on the spec's own two instances (S3, set 4 sitting 3, continued, on Opus 5.5; 2026-09-28 11:13 to 11:32 UTC)

[withheld at export: a sibling tree's line]
instances on the Studio then re-run THE WITNESSES (never the million) after D137, and only that re-run's verdicts are the ones of
record". The container half is `docs/records/20260927-183819-seed1m-s3.md` (seed `0x5EED5C7197F00001`, 1,000,000 entries: the
verified official release agrees with the spec on all of them in both columns; bsv-rs 0.3.30 has 6 resource aborts in the block
column, the Finding on #47, 5860579463; its §5 carries the four witness lines).

## 1. The corpus

- `corpus/million/witnesses.jsonl`: the four entries, ids `million-seed-191539`, `-352758`, `-662511`, `-969309` (the million's
  positions), each `OP_NUM2BIN` to 2^31 − 1 or 1,660,977,152 bytes in a post-Chronicle spend (families `mutation/lock` 3 and
  `mutation/unlock` 1, rule `mutation`); sha256 `5ba4d48f094aa3c05f3727f5914e4005c88d3e49ec2d23013287b76130efee75` after the
  recordings below. The million regenerates from its seed with `seed_gen` (its sha256 `632da599…` in the container record).
- `corpus/million/manifest.json`: harness/src/corpus.rs's Manifest fields; the implementations the generator's own manifest
  recorded for bsv-rs (the standard word `0x3D47FF`), then the spec's and the node's as the runs recorded them.

## 2. The runs `[X]`

| step | where, when | result |
|---|---|---|
| the spec, both columns | the tripwire's container (`million_spec_modal.py`, the parent's scratch; `a4df442` with the corpus laid over it by `modal_check._ship`; app `ap-QhY8VKxqO3HgNeUOOIUYaP`, cpu 16 / 32 GiB, 481.9 s, ~$0.136 `[D]`; `lake build bsvs` 208 s, then the four entries one at a time, 84 / 64 / 56 / 68 s) | keyed `spec@a4df442`: block column `SCRIPT_ERR_INVALID_STACK_OPERATION`, valid, `SCRIPT_ERR_SCRIPTNUM_OVERFLOW`, `SCRIPT_ERR_EVAL_FALSE` (the container record's `spec@c7e1f05` verdicts, unmoved); mempool column `SCRIPT_ERR_STACK_SIZE` on all four (the policy's 100,000,000-byte budget) |
| `run_bsvrs --corpus ../corpus/million --record` | the Studio, 11:30:47 | bsv-rs 0.3.30 under the recorded configuration (the standard word): invalid on all four, "Stack size limit exceeded" (like-for-like with the spec's mempool column); undecided 0 |
| `run_diff --record` | 11:30:48 | GREEN: agree `spec-mempool` 4; the block column's four are the crate's RESOURCE aborts at 100,000,000 bytes (`spend.rs:96–101` at 0.3.30, `WORD_MEMORY_LIMIT`), filed under `engine.resource-abort` (ruled impl-wrong; D15): `corpus/witnesses/million.jsonl`, 1 line (`million-seed-969309`), sha256 `d51bcac749403a5644108b7a409386575daf2405ea629529b7cdfed490fd377e` |
| `run_svnode --record` (verifyscript: the consensus instance, 18563; the policy instance, 18565, `--rpc-mempool`) | 11:30:48 | **GREEN: the spec's own two instances agree with the spec on 4 of 4 in both columns**, verdict and code (`sv-node@v1.2.2`: the block column as the spec's; `sv-node-mempool@v1.2.2`: `SCRIPT_ERR_STACK_SIZE` on all four). These are the verdicts of record (A27). `corpus/witnesses/sv-node/million.jsonl` empty |
| `rules_check` | 11:30:48 to 11:32:11 | GREEN: 36 corpus × engine manifests (the new `million` row among them), 54,568 entries replayed, 4,147 divergent runs classified; "bsv-rs on million: 4 entries run live under the two words ... 4 divergent runs in 1 classes; EQUAL to the manifest" |

## 3. What did not go as planned (kept, never replaced)

- **The spec on the Studio (11:15:47 to 11:17 UTC), STOPPED by the parent.** `eval/bsvs corpus corpus/million/witnesses.jsonl` in the
  landing worktree reached 5 to 6.5 GB resident with the system's compressor at 17 GiB and pages swapping out (the load 4.3): the
  evaluator holds an element as boxed scalars, so a 2^31-byte element is some 16 GiB. A heavy row belongs in the container
  (CLAUDE.md rule 17), where it ran.
- **The first Studio run (11:28:55 UTC), RESET.** The first cut of the witness writer copied each witness line's `bsv-rs@0.3.30`
  key, which is the BLOCK column's abort; a corpus's bsv-rs key is the standard word's verdict (every corpus's recorded
  configuration). `run_diff` read "RED (0 unexplained divergences, 0 messages outside the table, 4 recorded bsv-rs verdicts
  disagreeing)"; its node run was GREEN already. The outputs were kept in the parent's scratch, the tree reset to `982f10c`, the
  writer corrected (no bsv-rs key copied; the generator's recorded configuration in the manifest; `run_bsvrs --record` writes the
  key), and the steps above re-run.

- **The class's text re-cut, then the one witness line re-recorded (11:4x UTC).** `harness/rules/bsv-rs.json`'s `engine.resource-abort` said 0.3.29's mechanism (`DEFAULT_MEMORY_LIMIT` 32,000,000 in every mode, at 0.3.29's lines), which the conformance report quotes beside these witnesses; at 0.3.30 a word's budget is the node's policy default on the block path too (`spend.rs:445–451`, `96–101`, charged at `check_node_budget` 2385–2400). The text now says 0.3.30's, the older lines named by release; `run_diff --record` re-wrote the witness line's copy of it (the corpus's sha256 unmoved) and `rules_check` is GREEN again (36 manifests, 54,568 entries, 85 s).

## 4. The Finding it carries

The four are the committed witnesses of the Finding on #47 (5860579463, relayed to T3): bsv-rs 0.3.30 applies the node's POLICY
stack budget (100,000,000 bytes) under the BLOCK word, where the block path's figure is `INT64_MAX` (`consensus.h:82`); the node's
own instances decide all four on the block path (`million-seed-352758` valid with a 2^31 − 1-byte element). The class
`engine.resource-abort` stays impl-wrong until T3's release; the spec's pin moves under its own bump then.
