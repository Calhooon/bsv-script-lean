#!/usr/bin/env bash
# tools/gate_leg.sh (bsv-script-lean #116, S3, lane gate-116, 2026-10-18): one job of the hosted gate
# (.github/workflows/gate.yml) runs its legs through this script, and the dry run on the box runs the same lines.
# Each leg is the step of tools/check.sh that `tools/check.sh all` runs, never a re-implementation:
#   <step>   tools/check.sh <step> (pins, fmt, clippy, cite, jscpd, deny, secrets, lean, axioms, numbers, flow, sighash,
#            arith, stack, crypto, seed, scripttests, txtests, flags, spec, bytes, versiongate, eras, witnesses, eval,
#            tslint, harness)
#   chain    tools/chain_leg.sh --built, as `all` calls it (the lean leg has built the six check executables)
#   bench    tools/bench_leg.sh --log <this job's log>, as `all` calls it with its own log (BENCH_ELAPSED the job's wall)
# Every leg's output goes to the job's log (the argument before the legs), which the record job concatenates and hands to
# `tools/check.sh record` (the same verdict-line table and the same writer as `all`). After each leg one line of this
# script's own names the leg, its exit and its wall: `gate: leg <name> exit <rc>, wall <s> s`. The job stops at the
# leg that exits non-zero, as `all` does (set -e there).
# Usage: tools/gate_leg.sh <log> <leg> [<leg>...]
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
log="${1:?the job log}"; shift
[ "$#" -gt 0 ] || { echo "gate: no leg named"; exit 2; }
mkdir -p "$(dirname "$log")"; touch "$log"
JOB_START="${GATE_JOB_START:-$(date +%s)}"
for leg in "$@"; do
  t0=$(date +%s); rc=0
  case "$leg" in
    chain) cmd=("$ROOT/tools/chain_leg.sh" --built) ;;
    bench) cmd=("$ROOT/tools/bench_leg.sh" --log "$log") ;;
    *) cmd=("$ROOT/tools/check.sh" "$leg") ;;
  esac
  # the callers' rule (RULES-TREE (28)): no BASH_ENV, no profile, no rc file reaches a leg
  set +e
  /usr/bin/env -u BASH_ENV BENCH_ELAPSED=$(( t0 - JOB_START )) bash --noprofile --norc "${cmd[@]}" 2>&1 | tee -a "$log"
  rc=${PIPESTATUS[0]}
  set -e
  echo "gate: leg $leg exit $rc, wall $(( $(date +%s) - t0 )) s" | tee -a "$log"
  [ "$rc" -eq 0 ] || exit "$rc"
done
