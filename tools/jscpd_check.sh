#!/usr/bin/env bash
# The copy-paste leg (#138, S3, lane gate-138, 2026-10-14): jscpd over harness/ and tools/ with the threshold and the ignore
# list of tools/jscpd/.jscpd.json (its paths relative to that file). jscpd is pinned exactly in tools/jscpd/package.json and its lock (npm ci, the lock's
# integrity), and installed by this leg when absent into the toolchains directory: $JSCPD_HOME when set, else
# ~/bsv/targets/spec-box/toolchains/jscpd-<version> where that directory exists (the box), else
# harness/target/toolchains/jscpd-<version> inside the tree (the Studio's worktrees; gitignored); the Modal container sets $JSCPD_HOME to /cache/jscpd, installed by the bake.
# jscpd 5 is a Rust binary behind a Node shim, so the leg needs node and npm: without them it prints SKIPPED BY NAME with
# the reason, never a silent pass. Lean is not scanned: jscpd 5.4.1's `--list` has no Lean format (docs/LINT.md §1).
# The verdict line is the leg's own (RULES-TREE (28)): `jscpd: GREEN [X] ...`, `jscpd: RED ...` or `jscpd: SKIPPED BY NAME ...`.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PKG="$ROOT/tools/jscpd"
VER="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["dependencies"]["jscpd"])' "$PKG/package.json")"
if [ -n "${JSCPD_HOME:-}" ]; then HOME_DIR="$JSCPD_HOME"
elif [ -d "$HOME/bsv/targets/spec-box/toolchains" ]; then HOME_DIR="$HOME/bsv/targets/spec-box/toolchains/jscpd-$VER"
else HOME_DIR="$ROOT/harness/target/toolchains/jscpd-$VER"; fi
NODE="$(bash "$ROOT/tools/node_bin.sh" 2>/dev/null)" || NODE=
if [ -z "$NODE" ]; then
  echo "jscpd: SKIPPED BY NAME: no node on this host (tools/node_bin.sh found none; set NODE_BIN); the copy-paste leg did not run, which is not a pass"
  exit 0
fi
NPM="$(dirname "$NODE")/npm"; [ -x "$NPM" ] || NPM="$(command -v npm || true)"
installed() {
  [ -f "$HOME_DIR/node_modules/jscpd/package.json" ] && cmp -s "$PKG/package-lock.json" "$HOME_DIR/package-lock.json" \
    && [ "$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["version"])' "$HOME_DIR/node_modules/jscpd/package.json")" = "$VER" ]
}
if ! installed; then
  if [ -z "$NPM" ]; then
    echo "jscpd: SKIPPED BY NAME: jscpd $VER is not installed in $HOME_DIR and no npm is on this host to install it; the copy-paste leg did not run, which is not a pass"
    exit 0
  fi
  echo "jscpd: installing jscpd $VER into $HOME_DIR (npm ci at tools/jscpd/package-lock.json)"
  # into a directory of this process's own, then moved into place: two installs at once (a `make jscpd` outside the
  # box's one slot beside a tripwire) each fill their own directory (lens-138's NIT); the swap below is not atomic
  TMP_DIR="$HOME_DIR.tmp.$$"
  rm -rf "$TMP_DIR"; mkdir -p "$TMP_DIR"
  cp "$PKG/package.json" "$PKG/package-lock.json" "$TMP_DIR/"
  ( cd "$TMP_DIR" && PATH="$(dirname "$NODE"):$PATH" "$NPM" ci --no-audit --no-fund --ignore-scripts > npm-ci.log 2>&1 ) \
    || { echo "jscpd: RED: npm ci of jscpd $VER into $TMP_DIR failed (its log: $TMP_DIR/npm-ci.log)"; exit 1; }
  if installed; then rm -rf "$TMP_DIR"; else rm -rf "$HOME_DIR"; mv "$TMP_DIR" "$HOME_DIR"; fi
  installed || { echo "jscpd: RED: jscpd $VER is not at $HOME_DIR after npm ci"; exit 1; }
fi
OUT="$(mktemp -d)"
trap 'rm -rf "$OUT"' EXIT
start=$(date +%s)
set +e
( cd "$ROOT" && "$NODE" "$HOME_DIR/node_modules/jscpd/run-jscpd.js" -c tools/jscpd/.jscpd.json -r json -o "$OUT" --no-tips --no-colors > "$OUT/run.log" 2>&1 )
rc=$?
set -e
wall=$(( $(date +%s) - start ))
python3 - "$ROOT" "$ROOT/tools/jscpd/.jscpd.json" "$OUT/jscpd-report.json" "$OUT/run.log" "$rc" "$VER" "$wall" <<'PY'
import json, os, sys
root, cfg_path, rep_path, log_path, rc, ver, wall = sys.argv[1:8]
rel = lambda n: n[len(root) + 1:] if n.startswith(root + "/") else n
rc = int(rc)
cfg = json.load(open(cfg_path))
thr = float(cfg["threshold"])
try:
    rep = json.load(open(rep_path))
except (OSError, ValueError):
    print("jscpd: RED: jscpd %s wrote no report (exit %d); its output:" % (ver, rc))
    print(open(log_path).read().strip()[-2000:])
    sys.exit(1)
t = rep["statistics"]["total"]
fmts = sorted(rep["statistics"].get("formats", {}))
what = ("%.3f%% duplicated lines (%d of %d) in %d files of %s (%s), %d clones; the threshold %.2f%% (tools/jscpd/.jscpd.json); jscpd %s; %s s"
        % (t["percentage"], t["duplicatedLines"], t["lines"], t["sources"], " and ".join(os.path.relpath(os.path.join(os.path.dirname(cfg_path), p), root) + "/" for p in cfg["path"]),
           ", ".join(fmts) or "no format", t["clones"], thr, ver, wall))
if t["sources"] == 0:
    print("jscpd: RED: the scan analyzed no file (the paths, formats or ignore list of tools/jscpd/.jscpd.json match nothing): " + what)
    sys.exit(1)
if rc != 0 or t["percentage"] > thr:
    print("jscpd: RED: " + what + " (jscpd exit %d); the largest clones:" % rc)
    for d in sorted(rep["duplicates"], key=lambda d: -d["lines"])[:10]:
        a, b = d["firstFile"], d["secondFile"]
        print("  %d lines: %s:%d-%d = %s:%d-%d" % (d["lines"], rel(a["name"]), a["start"], a["end"], rel(b["name"]), b["start"], b["end"]))
    sys.exit(1)
print("jscpd: GREEN [X] " + what)
PY
