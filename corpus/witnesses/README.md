# corpus/witnesses: every divergence, as a transaction with its rule

**Constitution 04: a disagreement is a witness transaction, never a sentence.**
This directory is written by `make diff` (#15): for each generated corpus the
spec's evaluator (`eval/bsvs corpus`) and the pinned bsv-rs (0.3.32 since
2026-10-06, R1.6; 0.3.30 from 2026-09-27, #47; 0.3.28 from 2026-09-24; 0.3.27 on 2026-09-23; live, in-process) are run on every entry, and every tier-1
disagreement (validity) is classified by a rule of `corpus/INDEX.md` §2 from
the entry's own rule and the shapes of its scripts: THE CLASSIFIER IS DATA since 2026-09-26 (D83c, #31), the rows and the
class records in `harness/rules/bsv-rs.json` (the SDK engines' in `go-sdk.json` and `ts-sdk.json`), read through
`harness/src/rules.rs` by the drivers in one call each (`run_diff.rs` made its call at S2's `58f05a3`, from S3's patch, whose file was deleted once applied, 2026-09-27;
its code arms are gone, transcribed into the table row by row); `rules_check` (the tripwire's harness leg) replays the
go-sdk, ts-sdk and gobdk manifests offline from their recorded verdicts and runs bsv-rs live in-process on the corpora its manifests name, and is RED unless the tables reproduce
those four engines' manifests; the sv-node and policy-defaults manifests are replayed by no leg. One witness per corpus × column × rule
is filed here: the smallest divergent entry, its `expect` carrying both verdicts,
and a `divergence` record (`docs/DESIGN.md` §6): the rule, the two keys, both
verdicts, the citation that decides, the ruling (`impl-wrong` · `spec-wrong` ·
`open`) and a note with the count. A divergence no rule explains is
`unexplained`, ruled `open`, and the run is RED: the tripwire (`make check`, the
harness leg) runs the seed differential on every check.

Two columns, each with bsv-rs run under the node's own word for the entry's
era (`Spend::set_flags`, since 0.3.26: the reference's derivations transcribed in
the crate's `flags.rs`): **like-for-like** compares bsv-rs under the STANDARD
word (`ScriptFlags::standard(era)`, `0x3D47FF` post-Chronicle) with the spec
under the mempool word of SV-node's mainnet defaults; **block path** compares
bsv-rs under the BLOCK word (`ScriptFlags::block(era)`, `0x3D462F`) with the
spec under the entry's own `params` (what a mining node decides). Until 0.3.26
bsv-rs had no flag word and both columns ran its default mode, which gated the
relay restrictions on the version (`spend.rs:190–192` at 0.3.24): the rules
`flags.policy-as-consensus`, `flags.version-gate.*`, `flags.sigpushonly` and
`flags.discourage-upgradable-nops` were that mode's (bsv-rs#10), and the five
consensus rules of `push.truncated`, `flow.unknown-opcode`, `flow.else`,
`flow.ver`/`num.arith.2mul`/`2div`/`expansion.as-nop`, `flow.return`,
`sighash.scriptcode.findanddelete` and `crypto.checksig.unlock` were 0.3.24's
(bsv-rs#12, fixed in 0.3.27); the witnesses of those rules are the crate's
tests (`tests/script_flags_witnesses.rs`, `tests/script_residual_witnesses.rs`)
and this directory carries what remains. The bsv-rs message → `SCRIPT_ERR_*` table is `harness/src/bsvrs_codes.rs`,
a cited table; a message outside it makes the run RED so the table grows and
never guesses. A bsv-rs RESOURCE abort (its local memory budget: 32,000,000 bytes through 0.3.29; since 0.3.30 the node's policy
default 100,000,000 under a word, block path included, where the reference's block budget is `INT64_MAX`: the Finding
on #47) on an entry the spec decides is a witness under `engine.resource-abort` since 2026-09-24 (D15, #42; an entry
is a witness or undecided, never both); `undecided` remains for a pre-Genesis input and an entry without a spec
verdict. No candidate family is left: `corpus/stack`'s two aborts closed at 0.3.30 and their entries were relabelled
`splice/num2bin/memory` on 2026-09-28 (#26).

`manifest.json` carries, per corpus, the counts per column and rule, the
witness file's sha256, the spec's key (`spec@<commit>`), the engine
configuration. `corpus/INDEX.md` §4 is the index (the funnel rule). Nothing
from the private programs (`tools/mechanism_check.sh`); every outpoint is
synthetic.

**The policy-default witnesses (#21).** `policy-defaults.jsonl` (and the
regenerated, uncommitted `policy-defaults-large.jsonl`; `policy-defaults-manifest.json`)
are not differential witnesses: they exhibit the policy-default differences
between bitcoin-sv v1.2.2 and Teranode v0.15.9 that a transaction can (the defaults they read
are the same at v0.16.0, the pin since #54)
(`docs/PARAMETERS.md` §5, §7), constructed by `harness/src/bin/policy_witnesses.rs`
(`make policywitnesses`). Each carries bsv-rs's executed script verdict and a
`divergence` record with the two nodes' mempool verdicts read from source
(`[D]`, `ruling: open`: a policy difference; a block carrying any of them is valid on both nodes' block paths, though a default SV-node's mempool refuses them); no node
runner has measured them (#27 and #30 closed without a run of them), and
`tools/witness.sh` refuses them by name (no driver writes the two nodes'
columns). The one executed check is `lean/Test/WitnessCheck.lean` (`make
witnesscheck`, a leg of `make check`), which decides the spec's own verdict for every
input under both nodes' derived parameters, block and mempool, and checks the
record: the stack-memory witness reproduces it on the spec; the two
transaction-level witnesses (`dust`, `tx-size`) are valid under all four, the
standardness gate deciding outside the script semantics (DESIGN §5.5).
