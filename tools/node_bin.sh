#!/usr/bin/env bash
# The node the ts-sdk adapter runs on (bsv-script-lean #29/#40). @bsv/sdk's own `engines` field says
# node >= 22 (docs/PROVENANCE.md §1, the ts-sdk row), so the harness resolves, in order: $NODE_BIN,
# the newest nvm v22, a `node` on PATH. Prints the path; `make check-pins` checks its major against
# PROVENANCE §1a `node.major`. Never installs anything.
set -euo pipefail
if [ -n "${NODE_BIN:-}" ]; then echo "$NODE_BIN"; exit 0; fi
for d in $(ls -d "$HOME"/.nvm/versions/node/v22.* 2>/dev/null | sort -V -r); do
  if [ -x "$d/bin/node" ]; then echo "$d/bin/node"; exit 0; fi
done
command -v node || { echo "tools/node_bin.sh: no node found (set NODE_BIN)" >&2; exit 1; }
