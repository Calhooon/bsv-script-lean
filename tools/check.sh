#!/usr/bin/env bash
# The tripwire (`CONTRIBUTING.md`, "The gate"): `make check` must stay GREEN. TWENTY-NINE legs, in the order `all` runs them
# (the count TWENTY-NINE since 2026-10-14, when the clippy leg of #132 joined; the fmt (#134), tslint (#136), jscpd (#138),
# deny (#133), bench (#137) and secrets (#135) legs joined the same day, the cite leg (#43) on 2026-09-26; the count's
# dated re-cuts are in the history of this file):
#   pins         tools/check_pins.py: every pin of docs/PROVENANCE.md §1a agrees with every site (#40);
#                tools/check_parameters.py: the script/chain census and library import direction (#59);
#                tools/chain_lint.py: pure chain semantics and explicit time inputs (#77);
#                tools/test_teranode_gate.py: the Teranode gate's writer (#95; the delta, the vocabulary, the dry run on disk)
#   fmt          `cargo fmt --manifest-path Cargo.toml --all -- --check` in harness/ (the pinned toolchain's rustfmt, harness/rustfmt.toml;
#                #134): a file rustfmt would rewrite is RED, named; a toolchain without rustfmt is given it by rustup, else
#                the leg says SKIPPED BY NAME, never a pass; before rustfmt, tools/make_help_check.py: every .PHONY target
#                of the Makefile has its `## ` help line and its group (#174)
#   clippy       `cargo clippy --manifest-path Cargo.toml --locked --keep-going --all-targets -- -D warnings` in harness/ (the pinned toolchain;
#                #132): the lint table of harness/Cargo.toml denies unwrap_used, expect_used and panic (tests exempt by
#                harness/clippy.toml, every other allow on its function with its reason, docs/LINT.md section 1b); a toolchain
#                without clippy is given it by rustup, else the leg says SKIPPED BY NAME, never a pass
#   cite         tools/cite_check.py: every anchored file:line citation of lean/ and docs/ still holds at the pin (#43, S4b;
#                the clones absent in the Modal container are SKIPPED BY NAME, never a pass); then tools/teranode_map.py
#                --verify: every citation of #87's module map (corpus/teranode/map.json) at both pins, every Lean name declared; then
#                tools/teranode_absences.py --verify: every citation, listing and search of #96's ledger at both pins
#   jscpd        tools/jscpd_check.sh: copy-paste over harness/ and tools/ under tools/jscpd/.jscpd.json's threshold (#138; jscpd pinned in
#                tools/jscpd/, installed by the leg when absent; no node means SKIPPED BY NAME, never a pass)
#   deny         tools/cargo_deny.sh: cargo-deny 0.19.0 on harness/Cargo.toml against harness/deny.toml (advisories, licenses,
#                bans, sources; #133); cargo-deny installed at its pin into the toolchain directory when absent, or the leg
#                SKIPPED BY NAME with the reason, never a pass
#   secrets      tools/secrets_scan.sh --tree: every tracked file against tools/secrets_patterns.txt and its reviewed
#                exceptions, gitleaks at its pin (installed into the box's toolchain directory when absent there) or the
#                Python engine of the same rules, the engine named on the verdict line (#135, 2026-10-14)
#   lean         `lake build BsvScript BsvChain Bsvs` and the six check executables (finalitycheck utxocheck oraclecheck
#                blockcheck mempoolcheck chaincheck) in lean/, not a bare `lake build` (it would build StaleRunCheck, #120);
#                sorry-free (the build log may not mention sorry)
#   axioms       tools/axiom_check.py on the theorems listed in lean/AxiomCheck.lean, after `lake build StaleRunCheck`
#                (#120: the kernel-checked stale run is outside `lake build BsvChain`; this leg builds it, sorry-free)
#   numbers      the Numbers module's executable against the bsv-rs vectors (#7)
#   flow         the machine against the hand-written flow corpus with bsv-rs's verdicts (#8), then the kernel sample
#                through the compiled evaluator (lean/BsvScript/Properties/KernelSample.lean, docs/HYPOTHESES.md §3)
#   sighash      the digests against bsv-rs's vectors, the reference's sighash.json and the mainnet signatures (#12)
#   arith        the arithmetic and bitwise families: the value vectors and the engine cases (#9)
#   stack        the stack and splice families through bsv-rs's engine (#10)
#   crypto       the hash vectors, the ECDSA vectors, the mainnet inputs and the signature cases (#11)
#   seed         the seed corpus through the evaluator (#4, #14); before it, tools/records_index.py --check: docs/records/INDEX.md
#                is current (#175; a tripwire record newer than the index is named, not stale)
#   scripttests  the reference's script_tests.json at the pin, verdict and error code (#18)
#   txtests      the reference's tx_valid.json and tx_invalid.json under every flag word (#22)
#   flags        both branches under Params.derive's block and mempool words against bsv-rs (#13)
#   spec         the generated specification document is up to date (tools/specgen.py --check, #17); then
#                tools/rpc_contract.py --check: #85's generated interface harness/src/scenarios/rpc_contract.rs and the page's
#                generated sections equal a regeneration from corpus/rpc/contract.json, the probe record's replies fit the
#                contract; then tools/rpc_contract.py --verify: every contract citation holds at both pins (a clone absent
#                here is SKIPPED BY NAME and counted, never a pass; no node, no built reference)
#   bytes        every byte 0x00–0xff under both versions against bsv-rs (#18)
#   versiongate  the four version-gated restrictions of #19 at every read site, four cells each
#   eras         the era boundaries, the activation heights and P2SH of #20/#23, two cells each (and the corpus/eras rows the leg wrote)
#   witnesses    the policy-default witnesses under both nodes' derived parameters (#21)
#   eval         the evaluator's self-test (eval/bsvs --self-test, real since #14)
#   tslint       strict tsc (`tsc --noEmit -p tsconfig.json`, checkJs) and eslint (`eslint --max-warnings 0 .`, the flat
#                configuration: ESLint's and typescript-eslint's recommended sets, the type-checked one included) over the
#                ts-sdk adapter in harness/engines/ts; the tools pinned exactly in its package.json and lockfile, `npm ci`
#                when an installed version differs from the lockfile; no node is SKIPPED BY NAME, never a pass (#136)
#   harness      run_bsvrs --smoke on corpus/seed, run_diff on the seed, run_engine gosdk and tssdk on the seed (#4, #15, #29),
#                rules_check: the classifier tables replayed against the go-sdk, ts-sdk, gobdk and bsv-rs witness manifests (D83c, #31;
#                2026-09-26; the sv-node and policy-defaults manifests are replayed by no leg, #32 A-B6)
#   chain        tools/chain_leg.sh --built: the two intake seed scenarios' spec projection and the five adjacent
#                family executables (#66), plus predicate-checked node-free status fixtures (#67),
#                #89's subtree vectors, #83's Miner ID check, #78's relay projection and its frames (`chaincheck --subtree`,
#                `--minerid`, `--p2p`, `--p2p-frames`), #79's compact blocks (`--compact`), #80's double-spend
#                notifications (`--dsnt`), and #82's pruning function against its record's node answers
#                (`tools/prune_replay.py`, `chaincheck --prune`);
#                full derived chain rows remain in `make chain-check`
#   bench        tools/bench_leg.sh --log: the chain, flow and harness replay walls of this run and the export gate's walls
#                of its newest record against tools/bench_baseline.json (more than 1.5 times a baseline and 0.5 s above it
#                is RED; the box's baseline, other hosts SKIPPED BY NAME), and a 50000-case seed_gen fuzz smoke (#137); the
#                cold-run rule (2026-10-15, #137): a chain executable rebuilt since the previous box record, or
#                one whose baseline is under the floor, is run again by the leg and the second run judged; every wall
#                line names its rule, and a RED quotes the load sampler's newest line
# The route (D17/D17b as D156 amended it): tools/check_route.sh runs this locally under a 1-minute load of 20 and on the box
# above it (tools/check_box.sh), on Modal (tools/modal_check.py) only when MAKE_CHECK=modal; every run writes
# docs/records/<stamp>-make-check[-box|-modal].txt through record_run below.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
step="${1:-all}"
# The record (#43): a full run writes docs/records/<stamp>-make-check.txt naming the commit, the legs' verdict lines,
# the wall, the load before and after, and the exit status; the pages quote records, never counts from before a rebase.
# The same writer serves every home of the tripwire (D17b, 2026-09-24, as D156 amended it): on the Studio (`make check-local`,
# or `make check` under a 1-minute load below 20), on the box (`tools/check_box.sh` runs `make check-local` there and brings
# the file home as <stamp>-make-check-box.txt) and, only when MAKE_CHECK=modal, in the container on Modal
# (`tools/modal_check.py`, which sets CHECK_RECORD_NOTE to the app id, the container's size and its `uptime`, and brings the
# file home as <stamp>-make-check-modal.txt).
# Set 3's corrections of the writer (S1's and S2's pastes, 2026-09-24): the crypto leg's line is captured (its verdict
# lines begin `crypto:`, not `cryptocheck`), no line is cut (the 300-character cut truncated seedcheck's and run_diff's),
# and the uncommitted count is read at the START of the run and labeled so (it was read at exit under a start label).
REC_DIR="$ROOT/docs/records"
load1() { if [ -r /proc/loadavg ]; then cut -d' ' -f1 /proc/loadavg; else sysctl -n vm.loadavg | awk '{print $2}'; fi; }
record_run() {
  local status=$1
  local end; end=$(date +%s)
  if [ -n "${REC_SAMPLER:-}" ]; then kill "$REC_SAMPLER" 2>/dev/null || true; wait "$REC_SAMPLER" 2>/dev/null || true; fi
  local wall=$(( end - REC_START ))
  local commit; commit="$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null || echo unknown)"
  local dirty_end; dirty_end="$(git -C "$ROOT" status --porcelain 2>/dev/null | grep -c . || true)"
  local out="$REC_DIR/$REC_STAMP-make-check${REC_SUFFIX:-}.txt"   # REC_SUFFIX: `-hosted` for the hosted gate's record (#116)
  mkdir -p "$REC_DIR"
  {
    echo "make check record (tools/check.sh; #43)"
    echo "commit: $commit ($REC_DIRTY0 uncommitted paths at the start of the run, $dirty_end at its end)"
    echo "started: $REC_STAMP UTC; wall: ${wall}s ($((wall / 60)) min $((wall % 60)) s)"
    echo "host: $(hostname -s); load at start: $REC_LOAD0; load at end: $(uptime | sed 's/.*load averages*: //')"
    if [ -n "${CHECK_RECORD_NOTE:-}" ]; then echo "where: $CHECK_RECORD_NOTE"; fi
    echo "status: $([ "$status" = 0 ] && echo GREEN || echo "RED (exit $status)")"
    echo "legs (the verdict lines, in order):"
    grep -E '^(chain lint:|status views:|refinement:|subtree vectors:|compact blocks:|chain:|chain timing:|chaincheck scenarios:|finalitycheck|utxocheck|oraclecheck|blockcheck|mempoolcheck|chaincheck|fmt:|clippy:|check-pins|check-parameters|cite_check|teranode_absences|jscpd:|cargo-deny|secrets:|rules_check|lean:|axiom check|numcheck|flowcheck|sighash|sighash_verify|arithcheck|stackcheck|crypto:|cryptocheck|seedcheck|scripttests|txtests|flagscheck|specgen|rpc_contract|bytescheck|versiongatecheck|erascheck|witnesscheck|bsvs|eval/bsvs|tslint:|  fixed vectors|  two inputs|  a coinbase|  [a-z0-9-]+\.jsonl: |run_bsvrs|run_diff|run_engine|harness:|harness timing:|bench:|bench fuzz:|gate: (leg|job) |make check)' "$REC_LOG" | sed 's/^/  /'
    if [ -s "$REC_LOG.samples" ]; then
      echo "the load while it ran (every 10 s: the 1-minute average and every process over 5 % CPU):"
      cat "$REC_LOG.samples"
    fi
  } > "$out"
  rm -f "$REC_LOG.samples"
  echo "record: $out"
}
export CARGO_BUILD_JOBS="${CARGO_BUILD_JOBS:-4}"   # the shared machine (the paste of 2026-09-23)
# THE LEGS' OWN LINES (RULES-TREE (28), the maintainers' ruling of 2026-09-28, from a review's Finding: a caller's
# ~/.zshenv with `setopt NO_EXEC`, or a BASH_ENV file with `set -n`, makes a leg read without running and exit 0 silent, so
# an exit code alone reads GREEN): `all` ends only after every leg's OWN verdict line (printed by the leg's program, never
# by this script) stands in the log; a leg with no line is RED, named. The callers start this script under
# `env -u BASH_ENV bash --noprofile --norc` (the Makefile, tools/check_route.sh, tools/check_box.sh, tools/modal_check.py).
# `tools/check.sh lines <log>` runs the requirement alone on a log (its own test).
require_leg_lines() {
  local log=$1 missing= tries=0 leg pat
  while :; do
    missing=
    while IFS='|' read -r leg pat; do
      [ -n "$leg" ] || continue
      grep -Eq -- "$pat" "$log" || missing="$missing $leg"
    done <<'TABLE'
pins|^ *check-pins: GREEN
pins (the parameter census)|^ *check-parameters: GREEN
pins (the chain lint)|^ *chain lint: GREEN \[X\]
fmt|^ *fmt: (GREEN \[X\]|SKIPPED BY NAME)
fmt (make help, #174)|^ *fmt: make help: GREEN \[X\]
clippy|^ *clippy: (GREEN \[X\]|SKIPPED BY NAME)
cite|^ *cite_check: GREEN
cite (the module map, #87)|^ *cite_check teranode-map: GREEN
cite (the absence ledger, #96)|^ *teranode_absences --verify: GREEN
jscpd|^ *jscpd: (GREEN \[X\]|SKIPPED BY NAME)
deny|^ *cargo-deny: (GREEN \[X\]|SKIPPED BY NAME) \(
secrets|^ *secrets: GREEN \[X\] \(engine [a-z]
lean|^ *lean: build OK
axioms|^ *axiom check: OK \(
numbers|^ *numcheck: .*: 0 mismatch
flow|^ *flowcheck: [0-9]+ entries; .*mismatch 0
flow (the kernel sample)|^ *flowcheck: the kernel sample
flow (the large lock, the array machine)|^ *flowcheck: the large lock \(lean #48\): the array machine .*: valid in [0-9]+ ms, the budget [0-9]+ ms$
flow (the large lock, the list machine)|^ *flowcheck: the large lock \(lean #48\): the list machine .*: valid in [0-9]+ ms, the budget [0-9]+ ms$
sighash|^ *sighash: GREEN
sighash (the ECDSA leg)|^ *sighash_verify: .* 0 failures
arith (the values)|^ *arithcheck: [0-9]+ operand pairs.*: 0 mismatch
arith (the engine cases)|^ *arithcheck: [0-9]+ engine cases; .*mismatch 0
stack|^ *stackcheck: [0-9]+ engine cases; .*mismatch 0
crypto|^ *crypto: [0-9]+ engine cases; .*mismatch 0
crypto (the hash vectors)|^ *crypto: hash vectors .*: 0 mismatches$
crypto (the ECDSA vectors)|^ *crypto: ECDSA vectors from bsv-rs .*: [0-9]+ cases, 0 mismatches$
crypto (the mainnet inputs)|^ *crypto: [0-9]+ mainnet P2PKH inputs verify .*: 0 failures$
crypto (the curve's facts)|^ *crypto: the curve's facts .*: 0 mismatches$
crypto (the lax sequence length)|^ *crypto: the lax parser's sequence length .*: 0 mismatches$
seed|^ *seedcheck: [0-9]+ entries: agree [0-9]+, mismatch 0
seed (the records index, #175)|^ *seedcheck records index: GREEN \[X\]
scripttests|^ *scripttests: [0-9]+ rows .*mismatch 0
txtests (valid)|^ *txtests .*tx_valid\.json: .*mismatch 0
txtests (invalid)|^ *txtests .*tx_invalid\.json: .*mismatch 0
flags (flow)|^ *flagscheck flow\.jsonl: .*mismatch 0
flags (seed)|^ *flagscheck seed\.jsonl: .*mismatch 0
spec|^ *specgen --check: OK
spec (the RPC contract, #85)|^ *rpc_contract: GREEN \[X\]: [0-9]+ handlers
spec (the RPC contract's citations, #85)|^ *rpc_contract verify: (GREEN \[X\]|SKIPPED BY NAME): [0-9]+ citations read at the pins, 0 that do not hold
bytes|^ *bytescheck: [0-9]+ entries .*mismatch 0
versiongate|^ *versiongatecheck: .* 0 differ
eras|^ *erascheck: .* 0 mismatches
witnesses|^ *witnesscheck: [0-9]+ witness transactions .* 0 mismatches
eval|^ *bsvs --self-test: GREEN
tslint|^ *tslint: GREEN \[X\]
harness (the smoke)|^ *run_bsvrs --smoke: GREEN
harness (the differential)|^ *run_diff: GREEN
harness (the rules)|^ *rules_check: GREEN
chain|^ *chain: GREEN \[X\] \(spec projection;
chain (the seed scenarios)|^ *chaincheck scenarios: \[M\] [0-9]+ declared steps agree \[X\]
chain (status fixtures)|^ *status views: GREEN \[X\].*predicates checked; failures 0
chain (finality)|^ *finalitycheck: GREEN \[X\]
chain (UTXO)|^ *utxocheck: GREEN \[X\]
chain (mempool)|^ *mempoolcheck: GREEN \[X\]
chain (oracle)|^ *oraclecheck: GREEN
chain (headers)|^ *blockcheck: headers GREEN \[X\]
chain (block boundaries)|^ *blockcheck: boundaries GREEN \[X\]
chain (compact blocks, #79)|^ *compact blocks: GREEN \[X\]
bench|^ *bench: GREEN \[X\]
bench (the fuzz smoke)|^ *bench fuzz: (GREEN \[X\]|SKIPPED BY NAME)
TABLE
    [ "$(grep -Ec -- '^ *run_engine: GREEN' "$log")" -ge 2 ] || missing="$missing harness(the two SDK engines)"
    [ -z "$missing" ] && break
    tries=$((tries + 1)); [ "$tries" -ge 10 ] && break   # the log is written through tee: a line may land a moment late
    sleep 1
  done
  if [ -n "$missing" ]; then
    echo "make check: RED: a leg printed no verdict line of its own:$missing (RULES-TREE (28): a leg with no line is RED)"
    return 1
  fi
  echo "the legs' own verdict lines: every leg's present (RULES-TREE (28))"
}
fmt_check() {
  # #134 (2026-10-14): rustfmt at the door. Run inside harness/ so rustup selects the pinned toolchain
  # (harness/rust-toolchain.toml; from the root it would pick the caller's default and judge by another rustfmt); the
  # style is rustfmt's defaults at the crate's edition (harness/rustfmt.toml), the same the pre-commit hook judges.
  echo "== fmt: cargo fmt --check on the harness crate (the pinned toolchain's rustfmt; harness/rustfmt.toml; #134) =="
  # #174: every .PHONY target of the Makefile carries its `## ` help line and its group (`make help`, the default goal)
  python3 "$ROOT/tools/make_help_check.py" || exit 1
  local ch; ch="$(sed -n 's/^channel = "\(.*\)"$/\1/p' "$ROOT/harness/rust-toolchain.toml")"
  if ! ( cd "$ROOT/harness" && cargo fmt --version ) > /dev/null 2>&1; then
    # the toolchain's profile is minimal (the Modal image's install): rustfmt is its own component, a public read
    echo "fmt: rustfmt is absent from the toolchain $ch: rustup component add rustfmt --toolchain $ch"
    rustup component add rustfmt --toolchain "$ch" > /dev/null 2>&1 || true
  fi
  if ! ( cd "$ROOT/harness" && cargo fmt --version ) > /dev/null 2>&1; then
    echo "fmt: SKIPPED BY NAME: rustfmt is absent from the toolchain $ch and rustup could not add it on this host (not a pass)"
    return 0
  fi
  local ver n out; ver="$(cd "$ROOT/harness" && rustfmt --version | awk '{print $2}')"
  n="$(cd "$ROOT/harness" && find src tests -name '*.rs' | grep -c .)"
  out="$(mktemp)"
  if ( cd "$ROOT/harness" && cargo fmt --manifest-path Cargo.toml --all -- --check --color never ) > "$out" 2>&1; then
    rm -f "$out"
    echo "fmt: GREEN [X]: cargo fmt --all -- --check under harness/ at rustfmt $ver (toolchain $ch): $n .rs files, 0 differ"
  else
    local bad; bad="$(grep -E '^Diff in ' "$out" | sed -E 's/^Diff in (.*):[0-9]+:$/\1/; s|.*/harness/|harness/|' | sort -u)"
    { grep -v '^Diff in ' "$out" | head -40; } || true
    if [ -n "$bad" ]; then
      echo "fmt: RED: $(printf '%s\n' "$bad" | grep -c .) file(s) differ from rustfmt $ver's style: $(printf '%s ' $bad)(fix: cargo fmt --all in harness/)"
    else
      echo "fmt: RED: cargo fmt --check failed and named no file (rustfmt's own error is above)"
    fi
    rm -f "$out"
    exit 1
  fi
}
cite_check() {
  echo "== cite: tools/cite_check.py: every anchored file:line citation of lean/ and docs/ at the pin (#43); then tools/teranode_map.py --verify (#87's module map at both pins) =="
  python3 "$ROOT/tools/cite_check.py"
  python3 "$ROOT/tools/teranode_map.py" --verify
  python3 "$ROOT/tools/teranode_absences.py" --verify
}
deny_check() {
  echo "== deny: tools/cargo_deny.sh: cargo-deny on harness/Cargo.toml against harness/deny.toml (advisories, licenses, bans, sources; #133) =="
  bash "$ROOT/tools/cargo_deny.sh"
}
secrets_check() {
  echo "== secrets: tools/secrets_scan.sh --tree: every tracked file against tools/secrets_patterns.txt, gitleaks at its pin or the Python engine (#135) =="
  bash "$ROOT/tools/secrets_scan.sh" --tree
}
pins_check() {
  parameters_check
  python3 "$ROOT/tools/chain_lint.py"
  echo "== pins: tools/check_pins.py: docs/PROVENANCE.md §1a against every site (the toolchains, the engines, the manifests, --locked) =="
  python3 "$ROOT/tools/check_pins.py"
  echo "== pins: tools/test_teranode_gate.py: the Teranode gate's writer (#95), node-free =="
  python3 "$ROOT/tools/test_teranode_gate.py"
}
jscpd_check() {
  echo "== jscpd: tools/jscpd_check.sh: copy-paste over harness/ and tools/ under the threshold of tools/jscpd/.jscpd.json (#138) =="
  bash "$ROOT/tools/jscpd_check.sh"
}
parameters_check() {
  echo "== parameters: script and chain NodeConfig census; library import direction (#59) =="
  python3 "$ROOT/tools/check_parameters.py"
}
lean_build() {
  echo "== lean: lake build (lean/) =="
  local log; log="$(mktemp)"
  ( cd "$ROOT/lean" && lake build BsvScript BsvChain Bsvs finalitycheck utxocheck oraclecheck blockcheck mempoolcheck chaincheck 2>&1 | tee "$log" ) || { echo "lean: lake build FAILED"; exit 1; }
  if grep -q -E "declaration uses 'sorry'|sorry" "$log"; then
    echo "lean: a sorry is in the build log; main must be sorry-free"; exit 1
  fi
  echo "lean: build OK, sorry-free"
}
axioms() {
  echo "== axioms: tools/axiom_check.py (its parser's self-test first: a wrapped axiom list must be judged, 2026-09-27) =="
  # #120 (2026-10-14): the stale run (lean/BsvChain/Properties/StaleRun.lean) is the Lake library StaleRunCheck, which
  # `lake build BsvChain` and the lean leg do not build; AxiomCheck.lean imports it, so it is built here before the check.
  local log; log="$(mktemp)"
  ( cd "$ROOT/lean" && lake build StaleRunCheck 2>&1 | tee "$log" ) || { echo "axioms: lake build StaleRunCheck FAILED"; exit 1; }
  if grep -q -E "declaration uses 'sorry'|sorry" "$log"; then
    echo "axioms: a sorry is in the StaleRunCheck build log; main must be sorry-free"; exit 1
  fi
  python3 "$ROOT/tools/axiom_check.py" --self-test
  python3 "$ROOT/tools/axiom_check.py"
}
numbers_check() {
  echo "== numbers: lean/Test/NumbersCheck.lean against corpus/numbers =="
  if [ -f "$ROOT/corpus/numbers/bsv-rs-0.7.0.jsonl" ] && [ -f "$ROOT/lean/Test/NumbersCheck.lean" ]; then
    ( cd "$ROOT/lean" && lake build numcheck 2>&1 | grep -v "^trace:" | tail -1 && .lake/build/bin/numcheck ../corpus/numbers/bsv-rs-0.7.0.jsonl )
  else
    echo "numbers: STUB (until #7): the vectors or the check are not seeded. This line is a stub, not a pass."
  fi
}
flow_check() {
  echo "== flow: lean/Test/FlowCheck.lean against corpus/flow =="
  if [ -f "$ROOT/corpus/flow/flow.jsonl" ] && [ -f "$ROOT/lean/Test/FlowCheck.lean" ]; then
    ( cd "$ROOT/lean" && lake build flowcheck 2>&1 | grep -v "^trace:" | tail -1 && .lake/build/bin/flowcheck ../corpus/flow/flow.jsonl | grep -v "^  flow-" )
  else
    echo "flow: STUB (until #8): the flow corpus or the check is not seeded. This line is a stub, not a pass."
  fi
}
arith_check() {
  echo "== arith: lean/Test/ArithCheck.lean against corpus/arith (bsv-rs value vectors · the engine cases) =="
  if [ -f "$ROOT/corpus/arith/bsv-rs-0.7.0.jsonl" ] && [ -f "$ROOT/corpus/arith/cases.jsonl" ] && [ -f "$ROOT/lean/Test/ArithCheck.lean" ]; then
    ( cd "$ROOT/lean" && lake build arithcheck 2>&1 | grep -v "^trace:" | tail -1 && .lake/build/bin/arithcheck ../corpus/arith/bsv-rs-0.7.0.jsonl ../corpus/arith/cases.jsonl | grep -v "^  arith-candidate" )
  else
    echo "arith: STUB (until #9): the arithmetic vectors or the check are not seeded. This line is a stub, not a pass."
  fi
}
stack_check() {
  echo "== stack: lean/Test/StackCheck.lean against corpus/stack (the engine cases) =="
  if [ -f "$ROOT/corpus/stack/cases.jsonl" ] && [ -f "$ROOT/lean/Test/StackCheck.lean" ]; then
    ( cd "$ROOT/lean" && lake build stackcheck 2>&1 | grep -v "^trace:" | tail -1 && .lake/build/bin/stackcheck ../corpus/stack/cases.jsonl | grep -v "^  stack-candidate" )
  else
    echo "stack: STUB (until #10): the stack cases or the check are not seeded. This line is a stub, not a pass."
  fi
}
crypto_check() {
  echo "== crypto: lean/Test/CryptoCheck.lean (hash vectors · ECDSA vectors from bsv-rs · mainnet inputs through the evaluator · the signature cases) =="
  if [ -f "$ROOT/corpus/crypto/cases.jsonl" ] && [ -f "$ROOT/lean/Test/CryptoCheck.lean" ]; then
    ( cd "$ROOT/lean" && lake build cryptocheck 2>&1 | grep -v "^trace:" | tail -1 && .lake/build/bin/cryptocheck ../corpus/crypto/ecdsa-bsv-rs-0.7.0.jsonl ../corpus/sighash/mainnet.jsonl ../corpus/crypto/cases.jsonl | grep -v "^  crypto-candidate" )
  else
    echo "crypto: STUB (until #11): the crypto corpora or the check are not seeded. This line is a stub, not a pass."
  fi
}
seed_check() {
  echo "== seed: lean/Test/SeedCheck.lean: the seed corpus through the evaluator (deferred families reported) =="
  # #175: docs/records/INDEX.md is current (tools/records_index.py --check; under a second, no build)
  python3 "$ROOT/tools/records_index.py" --check || exit 1
  if [ -f "$ROOT/corpus/seed/seed.jsonl" ] && [ -f "$ROOT/lean/Test/SeedCheck.lean" ]; then
    ( cd "$ROOT/lean" && lake build seedcheck 2>&1 | grep -v "^trace:" | tail -1 && .lake/build/bin/seedcheck ../corpus/seed/seed.jsonl )
  else
    echo "seed: STUB (until #9): the seed corpus or the check is not seeded. This line is a stub, not a pass."
  fi
}
scripttests_check() {
  echo "== scripttests: lean/Test/ScriptTestsCheck.lean: the reference's script_tests.json at the pin (rows an unwritten opcode blocks are skipped and counted) =="
  if [ -f "$ROOT/corpus/reference/bitcoin-sv-v1.2.3-script_tests.json" ] && [ -f "$ROOT/lean/Test/ScriptTestsCheck.lean" ]; then
    ( cd "$ROOT/lean" && lake build scripttests 2>&1 | grep -v "^trace:" | tail -1 && .lake/build/bin/scripttests ../corpus/reference/bitcoin-sv-v1.2.3-script_tests.json )
  else
    echo "scripttests: STUB (until #9): the reference vectors or the check are not seeded. This line is a stub, not a pass."
  fi
}
sighash_check() {
  echo "== sighash: lean/Test/SighashCheck.lean against corpus/sighash (bsv-rs vectors · the reference's sighash.json · mainnet signatures) =="
  if [ -f "$ROOT/corpus/sighash/mainnet.jsonl" ] && [ -f "$ROOT/lean/Test/SighashCheck.lean" ]; then
    ( cd "$ROOT/lean" && lake build sighashcheck 2>&1 | grep -v "^trace:" | tail -1 \
      && .lake/build/bin/sighashcheck ../corpus/sighash/bsv-rs-0.7.0.jsonl ../corpus/sighash/bitcoin-sv-v1.2.3-sighash.json ../corpus/sighash/mainnet.jsonl > .lake/sighash.out \
      && grep -v "^MAINNET" .lake/sighash.out )
    ( cd "$ROOT/harness" && cargo build --release --quiet --locked --bin sighash_verify \
      && grep "^MAINNET" "$ROOT/lean/.lake/sighash.out" | "${CARGO_TARGET_DIR:-target}/release/sighash_verify" ../corpus/sighash/mainnet.jsonl )   # the binary where cargo put it: CARGO_TARGET_DIR is set in the Modal container (the third launch's finding)
  else
    echo "sighash: STUB (until #12): the sighash corpora or the check are not seeded. This line is a stub, not a pass."
  fi
}
flags_check() {
  echo "== flags: lean/Test/FlagsCheck.lean: both branches under Params.derive's block and mempool words against bsv-rs (corpus/flow, corpus/seed) =="
  if [ -f "$ROOT/corpus/seed/seed.jsonl" ] && [ -f "$ROOT/lean/Test/FlagsCheck.lean" ]; then
    ( cd "$ROOT/lean" && lake build flagscheck 2>&1 | grep -v "^trace:" | tail -1 && .lake/build/bin/flagscheck ../corpus/flow/flow.jsonl ../corpus/seed/seed.jsonl )
  else
    echo "flags: STUB (until #13): the corpora or the check are not seeded. This line is a stub, not a pass."
  fi
}
bytes_check() {
  echo "== bytes: lean/Test/BytesCheck.lean: every byte 0x00–0xff under both versions against bsv-rs =="
  if [ -f "$ROOT/corpus/bytes/cases.jsonl" ] && [ -f "$ROOT/lean/Test/BytesCheck.lean" ]; then
    ( cd "$ROOT/lean" && lake build bytescheck 2>&1 | grep -v "^trace:" | tail -1 && .lake/build/bin/bytescheck ../corpus/bytes/cases.jsonl | grep -v "^  bytes-candidate" )
  else
    echo "bytes: STUB (until #18): the byte corpus or the check is not seeded. This line is a stub, not a pass."
  fi
}
versiongate_check() {
  echo "== versiongate: lean/Test/VersionGateCheck.lean: MINIMALDATA, CLEANSTACK, SIGPUSHONLY, LOW_S at every read site, four cells each (version 1 and 2, the block and mempool words), verdict and error code (#19) =="
  if [ -f "$ROOT/lean/Test/VersionGateCheck.lean" ]; then
    ( cd "$ROOT/lean" && lake build versiongatecheck 2>&1 | grep -v "^trace:" | tail -1 && .lake/build/bin/versiongatecheck )
  else
    echo "versiongate: STUB (until #19): the check is not seeded. This line is a stub, not a pass."
  fi
}
eras_check() {
  echo "== eras: lean/Test/ErasCheck.lean: the coin's era, the spend's height and era (every activation flag under the tip's-height convention), P2SH grandfathered and disabled, two cells each with the error code (#20, #23); corpus/eras is the same table =="
  if [ -f "$ROOT/lean/Test/ErasCheck.lean" ]; then
    ( cd "$ROOT/lean" && lake build erascheck 2>&1 | grep -v "^trace:" | tail -1 && .lake/build/bin/erascheck )
  else
    echo "eras: STUB (until #20): the check is not seeded. This line is a stub, not a pass."
  fi
}
witness_check() {
  echo "== witnesses: lean/Test/WitnessCheck.lean: the policy-default witnesses under both nodes' derived parameters (corpus/witnesses) =="
  if [ -f "$ROOT/corpus/witnesses/policy-defaults.jsonl" ] && [ -f "$ROOT/lean/Test/WitnessCheck.lean" ]; then
    ( cd "$ROOT/lean" && lake build witnesscheck 2>&1 | grep -v "^trace:" | tail -1 && .lake/build/bin/witnesscheck )
  else
    echo "witnesses: STUB (until #21): the witnesses or the check are not seeded. This line is a stub, not a pass."
  fi
}
txtests_check() {
  echo "== txtests: lean/Test/TxTestsCheck.lean: the reference's tx_valid.json and tx_invalid.json at the pin =="
  if [ -f "$ROOT/corpus/reference/bitcoin-sv-v1.2.3-tx_valid.json" ] && [ -f "$ROOT/lean/Test/TxTestsCheck.lean" ]; then
    ( cd "$ROOT/lean" && lake build txtests 2>&1 | grep -v "^trace:" | tail -1 && .lake/build/bin/txtests ../corpus/reference/bitcoin-sv-v1.2.3-tx_valid.json ../corpus/reference/bitcoin-sv-v1.2.3-tx_invalid.json )
  else
    echo "txtests: STUB (until #22): the transaction vectors or the check are not seeded. This line is a stub, not a pass."
  fi
}
spec_check() {
  echo "== spec: tools/specgen.py --check: the generated specification document is byte-identical to a regeneration from the Lean sources, the corpora and the witnesses (#17); then tools/rpc_contract.py --check and --verify (#85's RPC contract) =="
  local rc=0
  if [ -f "$ROOT/tools/specgen.py" ] && [ -f "$ROOT/spec/rules.md" ]; then
    python3 "$ROOT/tools/specgen.py" --check || rc=1
  else
    echo "spec: STUB (until #17): the generator or the document is not seeded. This line is a stub, not a pass."
  fi
  # #85 (2026-10-15): the generated interface harness/src/scenarios/rpc_contract.rs and the generated
  # sections of docs/CONFORMANCE-RPC-CONTRACT.md byte-identical to a regeneration from corpus/rpc/contract.json (the
  # harness's pinned rustfmt, run inside harness/), the probe record's replies against the contract's types and codes;
  # then every citation of the contract at both pins of docs/PROVENANCE.md section 1a (`git show`, never a working tree).
  # Every step runs and prints its own verdict line before the leg turns RED on any of them. Neither step needs the
  # node or the built reference; --verify reads the reference and Teranode clones, and a clone absent here (the Modal
  # container, the box's Teranode) is SKIPPED BY NAME and counted on its verdict line, never a pass.
  python3 "$ROOT/tools/rpc_contract.py" --check || rc=1
  python3 "$ROOT/tools/rpc_contract.py" --verify || rc=1
  [ "$rc" -eq 0 ] || { echo "spec: RED (a step above printed RED or STALE)"; return 1; }
}
eval_selftest() {
  echo "== eval: eval/bsvs --self-test (the fixed vectors with their citations, the flow and seed corpora through the CLI's runner against bsv-rs, determinism executed) =="
  if [ -x "$ROOT/eval/bsvs" ] && [ -f "$ROOT/lean/Bsvs/Main.lean" ]; then
    ( cd "$ROOT/lean" && lake build bsvs 2>&1 | grep -v "^trace:" | tail -1 ) && "$ROOT/eval/bsvs" --self-test
  else
    echo "eval: STUB (until #14): eval/bsvs is not seeded; the self-test is not run. This line is a stub, not a pass."
  fi
}
# the harness leg's replay walls (#137): each binary built before its clock starts, so a wall is the replay, never a compile
hnow() { python3 -c 'import time; print("%.6f" % time.time())'; }
htime() { python3 -c "print('harness timing: $1 wall [M] %.6fs' % ($(hnow) - $2))"; }
tslint_check() {
  echo "== tslint: strict tsc and eslint over the ts-sdk adapter (harness/engines/ts; tsconfig.json, eslint.config.mjs; #136) =="
  local d="$ROOT/harness/engines/ts" nb bin want have
  # the node the adapter runs on (tools/node_bin.sh: \$NODE_BIN, the newest nvm v22, node on PATH; the box's tripwire puts its
  # toolchains' node on PATH, tools/check_box.sh); npm beside it. None found: the leg says so by name and prints no GREEN
  # line, so a full run is RED at the verdict table (RULES-TREE (28)), never a silent pass.
  nb="$("$ROOT/tools/node_bin.sh" 2>/dev/null)" || { echo "tslint: SKIPPED BY NAME: no node found (tools/node_bin.sh: set NODE_BIN); this line is a skip, not a pass"; return 0; }
  bin="$(dirname "$nb")"
  [ -x "$bin/npm" ] || { echo "tslint: SKIPPED BY NAME: no npm beside $nb; this line is a skip, not a pass"; return 0; }
  # the install step: every package the lockfile names at its locked version, else `npm ci` (the lockfile, never latest)
  want="$(cd "$d" && PATH="$bin:$PATH" "$nb" -e '
    const fs = require("fs"); const lock = JSON.parse(fs.readFileSync("package-lock.json", "utf8")); let bad = 0
    for (const [k, v] of Object.entries(lock.packages)) {
      if (k === "" || !k.startsWith("node_modules/")) continue
      let have = null; try { have = JSON.parse(fs.readFileSync(k + "/package.json", "utf8")).version } catch (e) {}
      if (have !== v.version) bad++
    }
    console.log(bad)')"
  if [ "$want" != 0 ]; then
    echo "tslint: $want installed packages differ from harness/engines/ts/package-lock.json: npm ci --no-audit --no-fund --ignore-scripts"
    ( cd "$d" && PATH="$bin:$PATH" "$bin/npm" ci --no-audit --no-fund --ignore-scripts 2>&1 | tail -3 ) || { echo "tslint: RED: npm ci failed in harness/engines/ts"; exit 1; }
  fi
  have="tsc $(PATH="$bin:$PATH" "$nb" "$d/node_modules/typescript/bin/tsc" --version | awk '{print $2}'), eslint $(cd "$d" && PATH="$bin:$PATH" "$nb" node_modules/eslint/bin/eslint.js --version | tr -d v), typescript-eslint $("$nb" -p "require('$d/node_modules/typescript-eslint/package.json').version"), node $("$nb" --version)"
  ( cd "$d" && PATH="$bin:$PATH" "$nb" node_modules/typescript/bin/tsc --noEmit -p tsconfig.json ) || { echo "tslint: RED: tsc --noEmit -p tsconfig.json (strict, checkJs) reports errors in harness/engines/ts ($have)"; exit 1; }
  ( cd "$d" && PATH="$bin:$PATH" "$nb" node_modules/eslint/bin/eslint.js --max-warnings 0 . ) || { echo "tslint: RED: eslint --max-warnings 0 . reports problems in harness/engines/ts ($have)"; exit 1; }
  echo "tslint: GREEN [X] (harness/engines/ts: tsc --noEmit strict checkJs, 0 errors; eslint --max-warnings 0, 0 problems; $have)"
}
harness_smoke() {
  echo "== harness: smoke run on corpus/seed against bsv-rs; the differential of the spec against bsv-rs on the seed (every divergence a cited rule, #15); the same differential against go-sdk and ts-sdk at their pins (#29); the classifier tables replayed against the go-sdk, ts-sdk, gobdk and bsv-rs witness manifests (rules_check, D83c) =="
  if [ -f "$ROOT/harness/Cargo.toml" ] && [ -f "$ROOT/corpus/seed/manifest.json" ]; then
    ( cd "$ROOT/harness" && cargo build --release --quiet --locked --bin run_bsvrs --bin run_diff --bin run_engine --bin rules_check )
    local ht; ht=$(hnow)
    ( cd "$ROOT/harness" && cargo run --release --quiet --locked --bin run_bsvrs -- --corpus ../corpus/seed --smoke )
    htime "run_bsvrs --smoke" "$ht"
    if [ -x "$ROOT/eval/bsvs" ] && [ -f "$ROOT/harness/src/bin/run_diff.rs" ]; then
      # the evaluator's corpus run is its own guard (#32 D-P15): a failing evaluator fails the step with its stderr shown,
      # never a step that goes on to the SDK runs on a stale spec-seed.jsonl and exits 0
      rm -f "$ROOT/lean/.lake/spec-seed.jsonl"
      "$ROOT/eval/bsvs" corpus "$ROOT/corpus/seed/seed.jsonl" --out "$ROOT/lean/.lake/spec-seed.jsonl" || { echo "harness: the evaluator's corpus run on the seed failed (no differential): RED"; exit 1; }
      ht=$(hnow)
      ( cd "$ROOT/harness" && cargo run --release --quiet --locked --bin run_diff -- --corpus ../corpus/seed/seed.jsonl --spec ../lean/.lake/spec-seed.jsonl --witnesses ../lean/.lake/witnesses | grep -v "^|" )
      htime "run_diff" "$ht"
    fi
    # the SDK engines (#29): the go-sdk adapter is built at its pin (the Go build cache makes it seconds), the
    # ts-sdk adapter runs the installed package (a missing install is RED with the command that fixes it)
    if [ -f "$ROOT/harness/src/bin/run_engine.rs" ] && [ -f "$ROOT/lean/.lake/spec-seed.jsonl" ]; then
      ( cd "$ROOT/harness/engines/go" && GOFLAGS=-mod=mod go build -p 4 -o ../../target/engines/gosdk-runner . ) || { echo "harness: the go-sdk adapter does not build"; exit 1; }
      [ -d "$ROOT/harness/engines/ts/node_modules/@bsv/sdk" ] || { echo "harness: the ts-sdk adapter's package is not installed: run make tssdk-install (npm ci at the pin)"; exit 1; }
      for e in gosdk tssdk; do
        ht=$(hnow)
        ( cd "$ROOT/harness" && cargo run --release --quiet --locked --bin run_engine -- --engine $e --corpus ../corpus/seed/seed.jsonl --spec ../lean/.lake/spec-seed.jsonl --witnesses ../lean/.lake/witnesses | grep -v "^|" | grep -v "^  word:" )
        htime "run_engine $e" "$ht"
      done
      # THE CLASSIFIER AS DATA (D83c, #31; 2026-09-26): the tables under harness/rules/ replayed against the recorded witness
      # manifests of four engines (go-sdk, ts-sdk and gobdk offline from the corpora's recorded verdicts, bsv-rs run live
      # in-process); the sv-node and policy-defaults manifests are replayed by no leg: EQUAL or RED
      ht=$(hnow)
      ( cd "$ROOT/harness" && cargo run --release --quiet --locked --bin rules_check ) || { echo "harness: the classifier tables do not reproduce the recorded classifications (D83c): RED"; exit 1; }
      htime "rules_check" "$ht"
    fi
  else
    echo "harness: STUB (until #4/#15): harness/ or corpus/seed is not seeded; the smoke run is not run. This line is a stub, not a pass."
  fi
}
# THE CLIPPY LEG (#132, 2026-10-14): the harness crate under its own lint table (harness/Cargo.toml
# `[workspace.lints.clippy]`: unwrap_used, expect_used and panic denied; harness/clippy.toml exempts tests), every other
# clippy warning denied by -D warnings. Run inside harness/ so rustup selects the pinned toolchain (as fmt_check); clippy is
# its own component of the minimal profile, added by rustup where absent, else the leg says SKIPPED BY NAME, never a pass.
clippy_check() {
  echo "== clippy: cargo clippy --locked --keep-going --all-targets -- -D warnings on the harness crate (the lint table denies unwrap, expect and panic; #132) =="
  local ch; ch="$(sed -n 's/^channel = "\(.*\)"$/\1/p' "$ROOT/harness/rust-toolchain.toml")"
  if ! ( cd "$ROOT/harness" && cargo-clippy --version ) > /dev/null 2>&1; then
    echo "clippy: clippy is absent from the toolchain $ch: rustup component add clippy --toolchain $ch"
    rustup component add clippy --toolchain "$ch" > /dev/null 2>&1 || true
  fi
  if ! ( cd "$ROOT/harness" && cargo-clippy --version ) > /dev/null 2>&1; then
    echo "clippy: SKIPPED BY NAME: clippy is absent from the toolchain $ch and rustup could not add it on this host (not a pass)"
    return 0
  fi
  local t0 out n; t0=$(date +%s); out="$(mktemp)"
  if ( cd "$ROOT/harness" && cargo clippy --manifest-path Cargo.toml --locked --keep-going --all-targets -- -D warnings ) > "$out" 2>&1; then
    rm -f "$out"
    echo "clippy: GREEN [X]: cargo clippy --locked --keep-going --all-targets -- -D warnings under harness/ (toolchain $ch): 0 warnings; unwrap_used, expect_used, panic denied by harness/Cargo.toml; $(( $(date +%s) - t0 )) s"
  else
    grep -E '^(error|warning)(\[|:)|^ +--> ' "$out" | head -60
    # --keep-going: every target whose dependencies compile is linted; a finding in the library hides the binaries and tests that link it, so the count is a floor (a site in a binary and its test build counts once)
    n="$(grep -A1 -E '^error(\[|:)' "$out" | grep -E '^ +--> ' | sort -u | grep -c . || true)"
    echo "clippy: RED: $n findings (at least; a library finding hides its dependents) under -D warnings (cargo clippy --locked --keep-going --all-targets on harness/; the full log $out)"
    exit 1
  fi
}
case "$step" in
  pins) pins_check ;;
  fmt) fmt_check ;;
  clippy) clippy_check ;;
  parameters) parameters_check ;;
  cite) cite_check ;;
  jscpd) jscpd_check ;;
  deny) deny_check ;;
  secrets) secrets_check ;;
  lean) lean_build ;;
  axioms) axioms ;;
  numbers) numbers_check ;;
  flow) flow_check ;;
  sighash) sighash_check ;;
  arith) arith_check ;;
  stack) stack_check ;;
  crypto) crypto_check ;;
  seed) seed_check ;;
  scripttests) scripttests_check ;;
  txtests) txtests_check ;;
  flags) flags_check ;;
  spec) spec_check ;;
  bytes) bytes_check ;;
  versiongate) versiongate_check ;;
  eras) eras_check ;;
  witnesses) witness_check ;;
  eval) eval_selftest ;;
  tslint) tslint_check ;;
  harness) harness_smoke ;;
  chain) bash "$ROOT/tools/chain_leg.sh" ;;
  bench) bash "$ROOT/tools/bench_leg.sh" ;;
  lines) require_leg_lines "${2:?the log to read}" ;;
  record)
    # THE HOSTED GATE'S RECORD (#116, 2026-10-18): .github/workflows/gate.yml runs the legs as separate jobs
    # (tools/gate_leg.sh); its record job concatenates their logs and hands them here, so the record is written by the SAME
    # writer as `all` and the run is judged by the SAME verdict-line table (RULES-TREE (28)): `tools/check.sh record <log>
    # <jobs' rc>` writes docs/records/<stamp>-make-check-hosted.txt and exits non-zero when a job failed or a leg's own line
    # is absent. GATE_STARTED (epoch seconds) is the earliest job's start; CHECK_RECORD_NOTE names the run.
    REC_LOG="${2:?the concatenated job logs}"; jobs_rc="${3:-0}"
    REC_START="${GATE_STARTED:-$(date +%s)}"; REC_STAMP="$(date -u -r "$REC_START" +%Y%m%d-%H%M%S 2>/dev/null || date -u -d "@$REC_START" +%Y%m%d-%H%M%S)"
    REC_LOAD0="$(uptime | sed 's/.*load averages*: //')"; REC_DIRTY0="$(git -C "$ROOT" status --porcelain 2>/dev/null | grep -c . || true)"
    REC_SUFFIX="${REC_SUFFIX:--hosted}"
    rc=0; [ "$jobs_rc" = 0 ] || { rc=1; echo "make check: RED: a job of the hosted gate exited $jobs_rc" | tee -a "$REC_LOG"; }
    if require_leg_lines "$REC_LOG" > "$REC_LOG.lines" 2>&1; then :; else rc=1; fi
    cat "$REC_LOG.lines"; cat "$REC_LOG.lines" >> "$REC_LOG"; rm -f "$REC_LOG.lines"
    [ "$rc" = 0 ] && echo "make check: GREEN (the hosted gate; stubs are listed above by name; a stub is not a pass)" | tee -a "$REC_LOG"
    record_run "$rc"; exit "$rc" ;;
  all)
    REC_START=$(date +%s); REC_STAMP="$(date -u +%Y%m%d-%H%M%S)"; REC_LOG="$(mktemp)"; REC_LOAD0="$(uptime | sed 's/.*load averages*: //')"
    REC_DIRTY0="$(git -C "$ROOT" status --porcelain 2>/dev/null | grep -c . || true)"
    exec > >(tee -a "$REC_LOG") 2>&1
    # The load sampler (a depth-sampler pattern; #20's corrections, S2): every 10 s the 1-minute average and
    # every process over 5 % CPU, written into the record by record_run (load1 reads /proc/loadavg in the container, sysctl on the Studio).
    # It names only this repository's own processes and the generic tools the legs run; every other process over 5 % is
    # summed as a count and a CPU share (`NORTH-STAR.md` §2, constitution 05: a sibling program's binary name is its design text, and the
    # records carried such names until 2026-09-27; a review's ask of 2026-09-27).
    SAMPLE_OWN='^(lean|lake|leanc|clang|ld|ld64|cc|cargo|rustc|rustdoc|bsvs|numcheck|flowcheck|sighashcheck|arithcheck|seedcheck|scripttests|stackcheck|cryptocheck|txtests|flagscheck|bytescheck|witnesscheck|versiongatecheck|erascheck|run_bsvrs|run_diff|run_engine|run_svnode|run_gobdk|rules_check|sighash_verify|gosdk-runner|gobdk-runner|bitcoind|node|go|python3|python|bash|sh|git|make)$'
    ( while true; do printf '  sample %s UTC: load1 %s; over 5%% cpu: %s\n' "$(date -u +%H:%M:%S)" "$(load1)" "$(ps -Ao %cpu,rss,comm | awk -v own="$SAMPLE_OWN" 'NR>1 && $1>5 {n=$3; sub(/.*\//, "", n); if (n ~ own) printf "%s %.0f%% %.1fGB; ", n, $1, $2/1048576; else {k++; c+=$1}} END {if (k) printf "other programs: %d processes, %.0f%% cpu; ", k, c; if (NR<2) printf "none"}')"; sleep 10; done ) > "$REC_LOG.samples" 2>/dev/null &
    REC_SAMPLER=$!
    trap 'record_run $?' EXIT
    pins_check; fmt_check; clippy_check; cite_check; jscpd_check; deny_check; secrets_check; lean_build; axioms; numbers_check; flow_check; sighash_check; arith_check; stack_check; crypto_check; seed_check; scripttests_check; txtests_check; flags_check; spec_check; bytes_check; versiongate_check; eras_check; witness_check; eval_selftest; tslint_check; harness_smoke; bash "$ROOT/tools/chain_leg.sh" --built; BENCH_ELAPSED=$(( $(date +%s) - REC_START )) bash "$ROOT/tools/bench_leg.sh" --log "$REC_LOG"; require_leg_lines "$REC_LOG"; echo "make check: GREEN (stubs are listed above by name; a stub is not a pass)";;
  *) echo "unknown step $step"; exit 2 ;;
esac
