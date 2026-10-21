#!/usr/bin/env bash
# #60: the source-derived spec column; #66 adds the node scenario leg.
set -euo pipefail
cd "$(dirname "$0")/.."
if [[ -n "${GIT_DIR:-}" ]]; then
  echo 'finalitycheck: refuse Lake under GIT_DIR' >&2
  exit 1
fi
# A maintainers' route for its Lean lock (#177): LEAN_LOCK_SH from the environment or tools/host_private.sh, else it stops.
ROOT="$PWD"; HOST_ROUTE=finalitycheck
host_var() {  # NAME: from the environment, else tools/host_private.sh (#177), else one line and exit 2
  local v="$1"
  if [ -z "${!v:-}" ] && [ -f "$ROOT/tools/host_private.sh" ]; then
    printf -v "$v" %s "$(bash -c '. "$1" >/dev/null 2>&1; printf %s "${!2:-}"' _ "$ROOT/tools/host_private.sh" "$v")"
  fi
  [ -n "${!v:-}" ] || [ "${2:-}" = optional ] || { echo "$HOST_ROUTE: a maintainers' route; it needs tools/host_private.sh or $v (tools/README.md)"; exit 2; }
}
host_var LEAN_LOCK_SH
source "$LEAN_LOCK_SH"
trap lean_lock_release EXIT
lean_lock_take s6-60
python3 - <<'PY'
import os, time
while os.getloadavg()[0] >= 20:
    print('finalitycheck: waiting for load below 20:', os.getloadavg()[0], flush=True)
    time.sleep(15)
print('finalitycheck: load1 before build:', os.getloadavg()[0], flush=True)
PY
(cd lean && lake build finalitycheck)
lean/.lake/build/bin/finalitycheck corpus/chain/finality/finality.jsonl
