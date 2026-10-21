# #26: the two entries that exercise `splice.num2bin.memory`, relabelled (S3, set 4 sitting 3, continued, on Opus 5.5; 2026-09-28)

**What.** `corpus/stack`'s `stack-00227` and `stack-00228` (`1 40000000 OP_NUM2BIN OP_SIZE 40000000 OP_EQUAL OP_NIP`, versions 2 and 1,
a post-Chronicle coin) carried the family `stack-candidate/num2bin-memory` and the rule `splice.num2bin.width`. The rule was a
mislabel: the entries are exactly `corpus/INDEX.md` §2's `splice.num2bin.memory` (a width above bsv-rs's old local budget, within the
reference's), and `harness/rules/bsv-rs.json`'s `class_from` already mapped that id. The family was a label from the time bsv-rs
could not decide them: its local 32,000,000-byte budget aborted both through 0.3.29, and 0.3.30 decides them valid (bsv-rs#30;
`docs/records/20260927-174629-diff-bsv-rs-0.3.30-s3.md` §2). So `spec/rules.md` flagged the rule for want of a labelled entry
(S2's Findings on #25, 5850367387 and 5852144858: "the count moves when S3's family lands its INDEX §1 row").

**The change** (the generator and the committed corpus together, every recorded verdict key kept):
- `harness/src/bin/stack_cases.rs`: the case's family `splice/num2bin/memory`, its rule `splice.num2bin.memory`, its note re-cut to
  0.3.30's truth (the reference's consensus budget `INT64_MAX`, `consensus.h:82`, and policy default 100,000,000, `policy.h:153`,
  both read at the pin; bsv-rs's local budget aborted it through 0.3.29).
- `corpus/stack/cases.jsonl`: those two lines' `family`, `rule` and `note` rewritten as the generator now writes them (a scratch
  script that refused unless every other line re-serialized byte for byte); sha256 `2610cf45…` -> `42ee4201411dbb40de14e30345f96ffd1650a260284d08fc3724ca6e87d9edf7`.
- `corpus/stack/cases-manifest.json`: the sha256, the families (the two candidate names out, `splice/num2bin/memory` and `/v1` in),
  the rules (`splice.num2bin.width` 64 -> 62, `splice.num2bin.memory` 2), the provenance sentence.
- `corpus/INDEX.md` §1 row 12 and §2 row 57; `corpus/witnesses/README.md`'s candidate sentence (stale since #47: no candidate
  family is left); `spec/` regenerated.

**The measurements** `[X local]`, the Studio, this tree:
- `tools/specgen.py`: 1 rule flagged, `params.policy.maxtxsizepolicy` (2 before: `splice.num2bin.memory` is exercised by 2 entries).
- `tools/check.sh stack` under the Lean lock: `stackcheck: 262 engine cases; comparable 262: agree 262, mismatch 0, unimplemented 0;
  recorded (not counted) 0` (260 comparable before: the leg counted the candidate family's two as recorded).

**Left for #26's first item:** `params.policy.maxtxsizepolicy`, a transaction-level policy limit (the spec's mempool gate models the
size cap, `Bsvs.Run.txGate`), whose only entry (`witness-policy-00003`, 10,291,094 bytes) is regenerated, not committed, and not
counted. Its home is `corpus/tx` on the block road, after D123's policy instance lands (`origin/s3-road`): the node's mempool then
refuses a transaction over 10,000,000 bytes as `tx-size`, and its block instance mines it.
