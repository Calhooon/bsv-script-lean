[export: 3 lines withheld by tools/export_public.py, the sibling trees' lines; the original is in the private history]
# The tripwire's own soundness under `pipefail`: the `| grep -q` and `grep -qi sorry` audit of the check scripts (S3, set 4 sitting 2, 2026-09-27 08:55 UTC)

[withheld at export: a sibling tree's line]
[withheld at export: a sibling tree's line]
goes FALSE RED when the output exceeds the pipe buffer (`grep -q` exits at its match, the writer dies of SIGPIPE, the
pipeline returns 141), and the twin `… | grep -E … | grep -qi sorry && fail || true` MASKS A SORRY (141 skips the `&&`,
`|| true` swallows it). This record is the audit of this repo's check scripts for both shapes, `tools/check.sh` and its
twenty-one legs first, at `4f1e085` (the tree of the landing commit's tripwire). **Result: no site of either shape; nothing
to change** `[X]`. **Re-verified before landing** (2026-09-27 12:00 UTC, S3's restarted context on Opus 5.5, the scan
widened from four trees to every tracked shell script): the verdict holds; the first draft's counts were short by one
script and one site (§1) and its second guard was stated wider than the axiom leg reaches (§2); both corrected here
before the record's first commit.

## 1. The scans (read-only, at `4f1e085`)

- **The scripts scanned**: every tracked shell script outside `corpus/`, `spec/` and `docs/` (the `.sh` files, the
  Makefile, and every file whose first line is a shell `#!`): fourteen, `Makefile`, `eval/bsvs`,
  `harness/engines/gobdk/build.sh`, `harness/oracle/spec-node.sh`, `tools/block.sh`, `tools/check.sh`,
  `tools/check_route.sh`, `tools/hooks/git/{commit-msg,pre-commit,pre-push}`, `tools/mechanism_check.sh`,
  `tools/mini_lock.sh`, `tools/node_bin.sh`, `tools/witness.sh`. The Python legs (`tools/*.py`) run no shell pipeline
  (no `shell=True`, no `grep -q`).
- **Every shell script that sets `pipefail`**: eight, `tools/check.sh:29`, `tools/check_route.sh:13`,
  `tools/witness.sh:15`, `tools/mechanism_check.sh:9`, `tools/node_bin.sh:6`, `eval/bsvs:10`,
  `harness/oracle/spec-node.sh:28`, `harness/engines/gobdk/build.sh:15` (each `set -euo pipefail`; the first draft's
  scan of four trees missed the eighth). The Makefile's recipes run under `/bin/sh` without it (no `SHELL` or
  `.SHELLFLAGS` in the Makefile).
- **Every `grep -q` in the fourteen** (`grep -nE 'grep[[:space:]]+(-[a-zA-Z]+[[:space:]]+)*-[a-zA-Z]*q'`, and the piped
  form `\|[[:space:]]*grep … -q`): four sites, below (the first draft said three: it missed `tools/block.sh:95`).
- **Every other early-exit reader under `pipefail`** (the same failure through another reader: `| head`, `| grep -m`,
  `| sed -n …q`, `| awk … exit`) in the eight scripts: none (`harness/engines/gobdk/build.sh:75`'s
  `go version | awk '{print $3, $4}'` reads to the end of its input).
- **Every `sorry` test in a shell script** (`grep -n sorry` over the fourteen): one, the Lean leg's, below.

## 2. The four `grep -q` sites

| site | shape | under `pipefail`? | verdict |
|---|---|---|---|
| `tools/check.sh:81` (the Lean leg's sorry test) | `if grep -q -E "declaration uses 'sorry'\|sorry" "$log"; then … exit 1` | yes (`check.sh:29`) | SOUND: grep reads a FILE, no pipe, so no SIGPIPE; the log exists before the build writes it (`log="$(mktemp)"`, `:79`) and the build's own pipeline `lake build 2>&1 \| tee "$log"` (`:80`) has no early-exiting reader; a failed build or a failed `tee` fails that pipeline under `pipefail` into "lake build FAILED" (RED), so the test never reads a truncated log as clean |
| `tools/block.sh:87` (W0's, the block writer's lane lookup) | `head -1 "$f" \| grep -qw -- "$TAG"` | no (`set -u` only, `:24`) | outside the failure mode: without `pipefail` the pipeline's status is `grep`'s; the input is one line |
| `tools/block.sh:95` (W0's, the block writer's pastes test) | `if grep -q '^## The pastes' "$LANE"; then` | no (`set -u` only, `:24`) | outside the failure mode twice over: grep reads a FILE, no pipe |
| `tools/hooks/git/pre-push:83` (W0's, the push hook's own-block test) | `printf '%s' "$h" \| cut -c1-80 \| grep -qw -- "$t"` | no (`set -u` only, `:18`) | outside the failure mode, the same reason; the input is at most 80 characters |

A second guard stands behind the Lean leg's text test FOR THE LISTED THEOREMS: the axiom leg (`tools/axiom_check.py` over
`lean/AxiomCheck.lean`, 387 theorems at `4f1e085`) admits only `propext`, `Classical.choice`, `Quot.sound`, so a listed
theorem that uses a `sorry`, or depends on a declaration that does, shows `sorryAx` and the leg is RED whatever the build
log says. A `sorry` in a declaration no listed theorem reaches is caught by the text test alone (the first draft said
"a theorem that uses `sorry`", wider than the list reaches).

## 3. So

No check of `make check`'s twenty-one legs can go false RED by SIGPIPE or pass a sorry by the two shapes `[X]`; no edit
to `tools/check.sh` is made (a fix with no failing case to fix would be a change for its own sake). The two PIPED sites
[withheld at export: a sibling tree's line]
only because their scripts do not set `pipefail`; a later `set -o pipefail` there would need the here-string form
(`grep -qw -- "$TAG" <<< "$(head -1 "$f")"`).
