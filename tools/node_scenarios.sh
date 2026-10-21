#!/usr/bin/env bash
# [D] 2026-10-13: executable lane replay entrypoint.
# Live node measurement is separate from the node-free chain leg.
set -euo pipefail
cd "$(dirname "$0")/.."
export CARGO_BUILD_JOBS=4
export CARGO_TARGET_DIR="${CARGO_TARGET_DIR:-$PWD/harness/target}"
python3 - <<'PY'
import os, time
while os.getloadavg()[0] >= 20:
    print('node-scenarios: waiting for load below 20', flush=True)
    time.sleep(15)
PY
uptime
cargo build --manifest-path harness/Cargo.toml --locked --bin run_scenarios
exec "$CARGO_TARGET_DIR/debug/run_scenarios" "$@"
