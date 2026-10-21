#!/usr/bin/env bash
# tools/column.sh (bsv-script-lean #124; S3, lane column-124, 2026-10-14): ONE IMPLEMENTATION'S COLUMN ON ONE RELEASE, IN
# ONE COMMAND. The recon's duty (CLAUDE.md rule 18) re-runs the harness on new pins the week a release lands; this is that
# re-run as a mechanism. `make column IMPL=<impl> PIN=<version or tag> [COMMIT=<sha>] [PLAN=1] [CORPUS=<name,...>]`.
#
#   IMPL   bsv-rs | go-sdk | ts-sdk | gobdk | sv-node | teranode
#   PIN    the release: equal to the pin of docs/PROVENANCE.md section 1a, a DRY RUN (no site moves, nothing under corpus/
#          written: the drivers record into scratch copies under harness/target/column/ and the run is compared with the
#          committed column); different, a PIN MOVE (the sites `make check-pins` reads move in this worktree, the
#          implementation is built or installed at the pin, every corpus the column records is re-recorded). A pin move is
#          a landing of its own: it refuses main and an unclean tree, and writes no prose page (the funnel rule is the lander's).
#   COMMIT the release's source commit when no local clone resolves the tag (ts-sdk always: ts-stack carries no release tag)
#   PLAN=1 lists every site a move would touch with its value now; writes nothing
#   CORPUS restricts the run to the named corpora (comma-separated); the record names the restriction
#
# sv-node and teranode are the owner's instances: the command names the instance it needs and never starts one (sv-node runs
# on the instances SV_RPC/SV_COOKIE and SV_RPC_MEMPOOL/SV_COOKIE_MEMPOOL name; teranode's chunked runs are
# harness/engines/instance41's recipe). The record is docs/records/<stamp>-column-<impl>-<pin>-s3.{md,json,txt}: the counts
# per corpus, the agreements per column against the committed ones, the moved rows by id, the pin's commit and checksum, the
# host, the wall; the last line printed is the verdict line `column: ...`. tools/column.py carries the mechanism.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
impl="${1:-}"; pin="${2:-}"
if [ -z "$impl" ] || [ -z "$pin" ]; then
  sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//' >&2
  exit 2
fi
args=(--impl "$impl" --pin "$pin")
[ -n "${COMMIT:-}" ] && args+=(--commit "$COMMIT")
[ -n "${PLAN:-}" ] && args+=(--plan)
if [ -n "${CORPUS:-}" ]; then
  IFS=, read -r -a cs <<< "$CORPUS"
  for c in "${cs[@]}"; do args+=(--corpus "$c"); done
fi
# The executables are this tree's, built at this pin: a target directory shared between lanes can hold another lane's
# build of another pin, so the column builds into its own (COLUMN_TARGET_DIR names another).
export CARGO_TARGET_DIR="${COLUMN_TARGET_DIR:-$ROOT/harness/target}"
export CARGO_BUILD_JOBS="${CARGO_BUILD_JOBS:-4}"   # the shared machine (the paste of 2026-09-23)
exec python3 "$ROOT/tools/column.py" "${args[@]}"
