#!/usr/bin/env bash
# #64: the source-derived chain column; #66 adds the node scenario leg.
set -euo pipefail
cd "$(dirname "$0")/.."
if [[ -n "${GIT_DIR:-}" ]]; then
  echo 'chaincheck: refuse Lake under GIT_DIR' >&2
  exit 1
fi
if [[ ! -f tools/host_private.sh ]]; then
  echo 'chaincheck: refuse build; host file absent; LEAN_LOCK_SH required' >&2
  exit 2
fi
source tools/host_private.sh
if [[ -z "${LEAN_LOCK_SH:-}" ]]; then
  echo 'chaincheck: refuse build; LEAN_LOCK_SH required' >&2
  exit 2
fi
source "$LEAN_LOCK_SH"
trap lean_lock_release EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
lean_lock_take s6-64
python3 - <<'PY'
import os, time
while os.getloadavg()[0] >= 20:
    print('chaincheck: waiting for load below 20:', os.getloadavg()[0], flush=True)
    time.sleep(15)
print('chaincheck: load1 before build:', os.getloadavg()[0], flush=True)
PY
(cd lean && lake build BsvChain chaincheck)
lean/.lake/build/bin/chaincheck corpus/chain/chain/chain.jsonl
