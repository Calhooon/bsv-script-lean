#!/usr/bin/env bash
# #63: measured public headers and derived block boundaries; #66 adds the node leg.
set -euo pipefail
cd "$(dirname "$0")/.."
if [[ -n "${GIT_DIR:-}" ]]; then
  echo 'blockcheck: refuse Lake under GIT_DIR' >&2
  exit 1
fi
if [[ ! -f tools/host_private.sh ]]; then
  echo 'blockcheck: refuse build; host file absent; LEAN_LOCK_SH required' >&2
  exit 2
fi
source tools/host_private.sh
if [[ -z "${LEAN_LOCK_SH:-}" ]]; then
  echo 'blockcheck: refuse build; LEAN_LOCK_SH required' >&2
  exit 2
fi
source "$LEAN_LOCK_SH"
trap lean_lock_release EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
lean_lock_take s6-63
python3 - <<'PY'
import os, time
while os.getloadavg()[0] >= 20:
    print('blockcheck: waiting for load below 20:', os.getloadavg()[0], flush=True)
    time.sleep(15)
print('blockcheck: load1 before build:', os.getloadavg()[0], flush=True)
PY
(cd lean && lake build BsvChain blockcheck)
lean/.lake/build/bin/blockcheck corpus/chain/headers/mainnet.jsonl corpus/chain/block/block.jsonl
