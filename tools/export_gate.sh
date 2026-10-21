#!/usr/bin/env bash
# The grep gate on the public edition (bsv-script-lean #46; NORTH-STAR constitution 05).
# Legs: (a) tools/mechanism_check.sh's two legs over the export, (b) the pointer patterns of
# tools/export_pointers.txt, (c) the wording leg with tools/wording_allow.txt, and (d) with
# --build only (#107; the flip day's FULL gate passes it): the exported harness built as a
# stranger would, `cargo build --release --locked --offline` then `cargo test ... --no-run`,
# CARGO_BUILD_JOBS=4, a cold target under ~/bsv/targets/spec-export/.cargo/, never a fetch; see
# tools/export_gate.py. Exit 0 clean, 1 on any hit or a RED build, 2 when a sibling tree is absent here.
# Usage: tools/export_gate.sh <export-dir> [--rows <file>] [--build]
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
exec python3 "$ROOT/tools/export_gate.py" "$@"
