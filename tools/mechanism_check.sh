#!/usr/bin/env bash
# The mechanism check (CLAUDE.md rule 5; docs/PROVENANCE.md §4–§5): nothing of the
# private programs enters. Two legs:
#   (1) the vendored/harness sources carry no covenant vocabulary, no builder, no
#       import of a predecessor crate, no 64-hex txid literal;
#   (2) every long hex string in the corpus (>= 40 hex chars: txids, scripts,
#       transactions) is absent from the sibling repositories' trees, except
#       the named public constants and public header path rule cited in
#       tools/mechanism_allow.txt.
# Exit 1 on any hit. Run: tools/mechanism_check.sh [corpus-dir ...]
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# the vocabulary (VOCAB) and the sibling trees (SIBLINGS) live in tools/host_private.sh, which names what this check
# searches for and where; it is withheld from the public edition (tools/export_withheld.txt), so there this check stops
[ -f "$ROOT/tools/host_private.sh" ] || { echo "mechanism check: tools/host_private.sh absent (the owner's host file): not run"; exit 2; }
. "$ROOT/tools/host_private.sh"
fail=0
echo "== (1) vocabulary and imports in harness/src =="
# `preimage` is not in the list: the signature-hash preimage is the reference's own vocabulary
# (`SignatureHash`, interpreter.cpp:2034–2084) and #12's sighash sources use it; the covenant
# introspection pattern of the predecessors is caught by PUSHTX/pushtx.
if grep -rn -E "$VOCAB" "$ROOT/harness/src" --include='*.rs' | grep -v -E "^[^:]+:[0-9]+:\s*//" ; then
  echo "(1) FAIL: private-program vocabulary or import in harness/src (comments are allowed only in the VENDORED headers)"; fail=1
else
  echo "(1) ok: no private-program vocabulary outside the provenance headers"
fi
if grep -rn -E "[0-9a-f]{64}" "$ROOT/harness/src" --include='*.rs'; then
  echo "(1) FAIL: a 64-hex literal in harness/src"; fail=1
else
  echo "(1) ok: no 64-hex literal in harness/src"
fi
echo "== (2) corpus hex strings against the siblings' trees =="
FILES=()
for dir in "${@:-$ROOT/corpus/seed}"; do
  for f in "$dir"/*.jsonl; do [ -f "$f" ] && FILES+=("$f"); done
done
# tools/mechanism_hex.py: an exact scan (BSD grep -F with thousands of patterns is quadratic on large files)
python3 "$ROOT/tools/mechanism_hex.py" --root "$ROOT" "${SIBLINGS[@]}" -- "${FILES[@]}" || fail=1
if [ "$fail" = "0" ]; then echo "mechanism check: CLEAN"; else echo "mechanism check: FAILED"; exit 1; fi
