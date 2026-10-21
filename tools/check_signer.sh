#!/usr/bin/env bash
# [D] #145, #147: the signer column runs on demand, once per signer pin move.
# Every child is owned by this foreground command; no package install or Lean build.
# A maintainers' route (#177): the Go toolchain's bin directory (BSV_SPEC_GO_BIN) and, when CARGO_TARGET_DIR is unset, the
# column's target (BSV_SIGNER_TARGET_DIR) come from the environment or from tools/host_private.sh; without them it stops.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
HOST_ROUTE=check_signer
host_var() {  # NAME: from the environment, else tools/host_private.sh (#177), else one line and exit 2
  local v="$1"
  if [ -z "${!v:-}" ] && [ -f "$ROOT/tools/host_private.sh" ]; then
    printf -v "$v" %s "$(bash -c '. "$1" >/dev/null 2>&1; printf %s "${!2:-}"' _ "$ROOT/tools/host_private.sh" "$v")"
  fi
  [ -n "${!v:-}" ] || [ "${2:-}" = optional ] || { echo "$HOST_ROUTE: a maintainers' route; it needs tools/host_private.sh or $v (tools/README.md)"; exit 2; }
}
host_var BSV_SPEC_GO_BIN
[ -n "${CARGO_TARGET_DIR:-}" ] || host_var BSV_SIGNER_TARGET_DIR
export CARGO_TARGET_DIR="${CARGO_TARGET_DIR:-$BSV_SIGNER_TARGET_DIR}"
export CARGO_BUILD_JOBS=4 CARGO_NET_OFFLINE=true
export GOPROXY=off GOSUMDB=off GOTOOLCHAIN=local
export GOCACHE="$CARGO_TARGET_DIR/go-cache"
export GOSDK_SIGNER_BIN="$CARGO_TARGET_DIR/engines/gosdk-signer"
export PATH="$BSV_SPEC_GO_BIN:$PATH"
: "${TMPDIR:?TMPDIR must name external scratch storage}"
case "$CARGO_TARGET_DIR/" in "$ROOT/"*) echo 'signer: RED [X] (target must be outside checkout)' >&2; exit 2;; esac
test -x "${SIGNER_BSVS:-lean/.lake/build/bin/bsvs}" || { echo 'signer: RED [X] (matching prebuilt evaluator required)' >&2; exit 2; }
test -d harness/engines/ts/node_modules || { echo 'signer: RED [X] (copy the pinned node_modules before running)' >&2; exit 2; }
make gosdk-signer-build tssdk-signer-build GOSDK_GO="$BSV_SPEC_GO_BIN/go"
(cd harness/engines/go && go test -p 4 ./signer && go vet -p 4 ./signer)
(cd harness && cargo build --release --locked --bin signer_bsvrs --bin run_signer)
(cd harness && cargo test --locked --bin run_signer --bin signer_bsvrs)
"$CARGO_TARGET_DIR/release/run_signer" --check-rules
exec "$CARGO_TARGET_DIR/release/run_signer"
