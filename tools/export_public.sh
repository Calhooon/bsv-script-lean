#!/usr/bin/env bash
# The public edition's export (bsv-script-lean #46; NORTH-STAR constitution 05; docs/PROVENANCE.md §4).
# Writes the tree of a named commit, less tools/export_withheld.txt's paths, into an empty
# directory under $HOME/bsv/targets/spec-export/ (the only place it writes), with the manifest
# EXPORT-MANIFEST.txt. No history is carried and nothing is published: the fresh public
# repository's own commit is the owner's act. Then run tools/export_gate.sh on the target.
# Three declared changes touch the exported copy only (the owner's rulings of 2026-10-06): the
# rewrite list tools/export_rewrite.txt (C2: exact text blocks replaced, each block matched exactly
# once or the export stops; since #169 CLAUDE.md is replaced whole by CLAUDE.public.md) and the records transform (C3: in docs/records/
# and docs/audit/ every line a pattern of tools/export_pointers.txt matches becomes the marker
# `[withheld at export: a sibling tree's line]`, and the file gains one header line with the count).
# The entry list tools/export_withheld_entries.txt replaces named JSONL fields with a marker,
# preserving other fields and recording private/public hashes and per-group counts in manifests.
# The D8 metadata list replaces named historical descriptions only in the exported JSON copy.
# The Cargo transform (#107) drops from every exported Cargo.toml each [[bin]], [[test]], [[bench]]
# and [[example]] table whose source is withheld, and stops the export if a manifest or a source
# still names a withheld path. Every list is read from the named commit, never the working tree.
# Usage: tools/export_public.sh [<commit> [<target-dir>]]   (defaults: HEAD, .../spec-export/<UTC stamp>)
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BASE="$HOME/bsv/targets/spec-export"
COMMIT="${1:-HEAD}"
TARGET="${2:-$BASE/$(date -u +%Y%m%d-%H%M%S)}"
mkdir -p "$BASE"
case "$(cd "$(dirname "$TARGET")" 2>/dev/null && pwd)/" in
  "$BASE"/*) ;;
  *) echo "export: the target must sit under $BASE (got $TARGET)"; exit 2 ;;
esac
exec python3 "$ROOT/tools/export_public.py" "$TARGET" "$COMMIT"
