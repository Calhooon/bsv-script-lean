# corpus/fuzz: the standing fuzz campaign's witness rows

Written by `tools/fuzz_campaign.sh` (S3, lane fuzz-campaign, 2026-10-15) in the campaign's own worktree, landed by the
captain's lanes; indexed in [`corpus/INDEX.md`](../INDEX.md) by `tools/fuzz_daily.sh` (CLAUDE.md rule 12). A file
exists only for a day with a new witness row: a day on which the spec, the node and the SDKs agree on every decided
cell, or diverge only where a row already stands, leaves no file, only its count lines in the campaign's log and in
`DAILY.txt` outside the repository.

Since lane fuzz-cut2 (2026-10-15; items 1 and 5 of the bsv-fuzz house read,
[`docs/records/20261015-134833-fuzz-house-read-s3.md`](../../docs/records/20261015-134833-fuzz-house-read-s3.md) section 5;
the record [`docs/records/20261015-150411-fuzz-cut2-s3.md`](../../docs/records/20261015-150411-fuzz-cut2-s3.md)) a batch's
corpus is three parts (`tools/fuzz_compose.py`): the bench leg's fuzz smoke's leading 1,000 cases at the campaign tree's
commit, the replay of every row of this directory (one case per distinct spend), and 50,000 fresh cases in one
`seed_gen --family` stream per family under a salted seed. Every spend is compared in the node's two columns
(`run_svnode`) and in each SDK's columns (`run_engine`: go-sdk's `spec` and `spec-mempool`, ts-sdk's those two and its
`default` run against both); an SDK whose runner is absent on the host is SKIPPED BY NAME on the batch line, never a pass.
A cell whose spend and column already hold a row here is counted and never written again.

`<date>.jsonl` (UTC date), one JSON object per new divergent cell of the node's columns, and `<date>-<engine>.jsonl`
(`go-sdk`, `ts-sdk`), one per new divergence class of that SDK's columns (a column and a rule of
`harness/rules/<engine>.json`: one row at `run_engine`'s own witness entry of the class, its smallest, the class's cell
count and its leading entry ids under `fuzz` (when that entry's spend already holds a row, the class's smallest new cell); a class this directory already holds is counted, never written again,
except `unexplained`, whose every new spend is written, 20 a batch at most), both in the harness's witness shape: a corpus Entry at the top
level (`harness/src/corpus.rs` `Entry`, as `run_svnode` writes its witnesses), so a reader that takes a corpus file
replays it:

| field | what |
|---|---|
| `id` | `fuzz-<batch>-<entry id>-<column>` (the node's), `fuzz-<batch>-<entry id>-<engine>-<column>` (an SDK's, `/` as `-`); the entry id is `<part>-<seed_gen's id>` (`smoke-seed-000340`, `arith-seed-000123`) or `replay-<a row's id>` |
| `tx`, `prevouts`, `params`, `family`, `rule` | the whole generated spend, as `seed_gen` wrote it (each prevout with its `height`) |
| `expect` | bsv-rs's verdict as `seed_gen` recorded it, and the two keys of the cell: the spec's (`spec@<commit>`, or `spec-mempool@<commit>` in the `spec-mempool` and `default/spec-mempool` columns) and the other side's (`sv-node@v1.2.3` or `sv-node-mempool@v1.2.3`; `<engine>@<version>`, `<engine>-mempool@<version>` or `ts-sdk-default@<version>`), each `verdict`, its `SCRIPT_ERR_*` `code` (the node's mapped back by `harness/src/svnode_codes.rs`, an SDK's by `gosdk_codes.rs`/`tssdk_codes.rs`) and, for the node or the SDK, its own words as `reason` |
| `divergence` | `rule` (the class the column's classifier, `harness/rules/sv-node.json` or `harness/rules/<engine>.json`, filed the cell under, `unexplained` when no row matches), `a`/`b` (the two keys), `a_verdict`/`b_verdict`, `decided_by` (empty: undecided), `ruling` `open` (the loop never judges a divergence, rule 4), `note` (the batch, the seed, the count, the record, the tree and how to reproduce) |
| `fuzz` | the campaign's fields: `batch`, `seed` (`0x` + the leading 16 hex digits of sha256(`spec-fuzz-campaign batch <batch>`)), `count` (the fresh cases), `entry_id`, `part` (`smoke`, `replay` or the family), `part_seed` and `part_count` (`seed_gen [--family <part>] --seed <part_seed> --count <part_count>` regenerates the part byte for byte; a family's seed is the batch seed xor `0x` + the leading 16 hex digits of sha256(`spec-fuzz-campaign family <part>`), the smoke's `0x` + the campaign tree's commit's leading 16 hex digits), `orig_id` (the id `seed_gen` gave the case), `replays` (a replayed case: the rows it replays), `engine` (`sv-node`, `go-sdk`, `ts-sdk`), `column` (`spec`: the block word, on the consensus instance for the node; `spec-mempool`: the relay word, on the policy instance at the node's defaults; `default/spec`, `default/spec-mempool`: ts-sdk's own derivation from the version against the two), `class` and `class_ruling` (the ruling the classifier gives that class), for the node `version` and `node_version`, for an SDK `cells`, `entry_ids`, `class_decided_by`, `engine_key`, `run_engine_witnesses` and `run_engine_outputs`, then `record` (`docs/records/<yyyymmdd>-fuzz-campaign-divergences.jsonl`), `found`, `tree` (the campaign worktree's commit), `driver`, `binaries_sha256` (bitcoind, seed_gen, run_svnode, bsvs, run_engine and the go-sdk runner when present) |

A batch that writes a node row also keeps `run_svnode`'s own witnesses of it (its layout:
`<witnesses>/sv-node/corpus.jsonl`), the smallest entry per column and class with the classifier's `decided_by` and
ruling, as `<date>-batch-<n>-sv-node.jsonl`; a batch that writes an SDK row keeps `run_engine`'s per-class witnesses
(`engines/<engine>/corpus.jsonl`, the smallest entry per column and class with the classifier's `decided_by`, ruling and
note) as `<date>-batch-<n>-<engine>.jsonl` and its manifest under `kept/batch-<n>/` of the state directory.

The spends are synthetic: their outpoints are sha256 of the entry id (`seed_gen`), never a real transaction's, and
nothing of the private programs enters (`tools/mechanism_check.sh`).
