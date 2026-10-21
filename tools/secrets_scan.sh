#!/usr/bin/env bash
# tools/secrets_scan.sh (S3, lane gate-135, #135; [M] 2026-10-14): THE SECRETS SCAN, on commit, on push and over the tree.
#   tools/secrets_scan.sh --staged        the lines the index adds (tools/hooks/git/pre-commit runs it)
#   tools/secrets_scan.sh --range A..B    the lines each commit of A..B adds (tools/hooks/git/pre-push runs it per pushed ref)
#   tools/secrets_scan.sh --tree          every tracked file (the `secrets` leg of tools/check.sh)
#   tools/secrets_scan.sh --paths F...    the named files whole (the failure case's dry run on a scratch file)
#   tools/secrets_scan.sh --install       fetches gitleaks at the pin into the toolchain directory, sha256-verified
# THE RULES: tools/secrets_patterns.txt (shapes only, never a value) and the reviewed exceptions of tools/secrets_allow.txt;
# both engines read those two files and nothing else, so they judge the same rules.
# THE ENGINES: gitleaks at the pin GITLEAKS_VERSION below, found as $GITLEAKS, in the toolchain directory
# ($SECRETS_TOOLCHAINS, else ~/bsv/targets/spec-box/toolchains, the box's), or on PATH at exactly that version, run with the
# config tools/secrets_scan.py --gitleaks-config generates (the default rule set OFF, archives and decoding OFF); where none
# is found, tools/secrets_scan.py, the same rules in Python. The verdict line names the engine that judged; neither engine
# is a skip. --tree on a host whose toolchain directory exists and lacks the pin installs it there before the scan (the box: the leg
# installs what it lacks, D156's route); a failed install falls back to the Python engine and says so on the line. The
# hooks never fetch. Before any scan the Python self-test proves each rule fires on its fake sample (a rules file that
# matches nothing is RED, never a quiet GREEN).
# OUTPUT: one line per finding (`<path>:<line>: <rule-id>`, the value redacted), then `secrets: GREEN [X] (...)` or
# `secrets: RED [X] (...)`. Exit 0 GREEN, 1 RED, 2 a setup error.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GITLEAKS_VERSION=8.28.0
# the release's own sha256 list, gitleaks_8.28.0_checksums.txt at github.com/gitleaks/gitleaks/releases/tag/v8.28.0 [LIT]
GITLEAKS_SHA256_darwin_arm64=d942f3ad147250c9edbaab3fed9e482f98d3b59ba10ae97b8d75647e3ade492c
GITLEAKS_SHA256_linux_x64=a65b5253807a68ac0cafa4414031fd740aeb55f54fb7e55f386acb52e6a840eb
GITLEAKS_SHA256_linux_arm64=eff65261156100e5d94a6b3dec313d532fddfe19ae1590bf7a2b4f2699128356
TC="${SECRETS_TOOLCHAINS:-$HOME/bsv/targets/spec-box/toolchains}"
PY="$ROOT/tools/secrets_scan.py"
mode="${1:-}"; [ $# -gt 0 ] && shift

platform() {
  local os arch; os="$(uname -s | tr 'A-Z' 'a-z')"; arch="$(uname -m)"
  case "$arch" in x86_64|amd64) arch=x64 ;; aarch64|arm64) arch=arm64 ;; esac
  echo "${os}_${arch}"
}
pinned() { [ -x "$1" ] && [ "$("$1" version 2>/dev/null)" = "$GITLEAKS_VERSION" ]; }
find_gitleaks() {
  local c
  for c in "${GITLEAKS:-}" "$TC/gitleaks-$GITLEAKS_VERSION/gitleaks" "$(command -v gitleaks 2>/dev/null || true)"; do
    [ -n "$c" ] && pinned "$c" && { echo "$c"; return 0; }
  done
  return 1
}
install_gitleaks() {
  local p sum url dir tmp got
  p="$(platform)"; sum="$(eval echo "\${GITLEAKS_SHA256_$p:-}")"
  [ -n "$sum" ] || { echo "no pinned sha256 for $p"; return 1; }
  dir="$TC/gitleaks-$GITLEAKS_VERSION"; tmp="$(mktemp -d)"
  url="https://github.com/gitleaks/gitleaks/releases/download/v$GITLEAKS_VERSION/gitleaks_${GITLEAKS_VERSION}_$p.tar.gz"
  curl -fsSL --max-time 120 -o "$tmp/g.tgz" "$url" || { rm -rf "$tmp"; echo "the fetch of $url failed"; return 1; }
  got="$( (shasum -a 256 "$tmp/g.tgz" 2>/dev/null || sha256sum "$tmp/g.tgz") | cut -d' ' -f1)"
  [ "$got" = "$sum" ] || { rm -rf "$tmp"; echo "sha256 $got is not the pin's $sum"; return 1; }
  mkdir -p "$dir" && tar -xzf "$tmp/g.tgz" -C "$tmp" gitleaks && mv "$tmp/gitleaks" "$dir/gitleaks" && chmod +x "$dir/gitleaks"
  rm -rf "$tmp"
  pinned "$dir/gitleaks" || { echo "$dir/gitleaks does not report $GITLEAKS_VERSION"; return 1; }
  echo "installed $dir/gitleaks"
}

case "$mode" in
  --install) install_gitleaks; exit $? ;;
  --staged|--tree) [ $# -eq 0 ] || { echo "secrets: setup error: $mode takes no argument"; exit 2; } ;;
  --range) [ $# -eq 1 ] && [[ "$1" == *..* ]] || { echo "secrets: setup error: --range A..B"; exit 2; } ;;
  --paths) [ $# -ge 1 ] || { echo "secrets: setup error: --paths F..."; exit 2; } ;;
  *) sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'; exit 2 ;;
esac

python3 "$PY" --self-test >/dev/null || { python3 "$PY" --self-test; echo "secrets: RED [X] (the rules' self-test failed: no scan is judged by a rules file that does not fire)"; exit 1; }
note=
GL="$(find_gitleaks || true)"
if [ -z "$GL" ] && [ "$mode" = --tree ] && [ -d "$TC" ]; then
  if msg="$(install_gitleaks 2>&1)"; then GL="$(find_gitleaks || true)"; note="; $msg"; else note="; the install of gitleaks $GITLEAKS_VERSION into $TC failed: $msg"; fi
fi
if [ -z "$GL" ]; then
  [ -n "$note" ] || note="; gitleaks $GITLEAKS_VERSION is not present (\$GITLEAKS, $TC, PATH)"
  set +e; python3 "$PY" "$mode" "$@" | sed "s|^\(secrets: [A-Z]* \[X\] (engine python\)|\1$note|"; rc=${PIPESTATUS[0]}; exit $rc
fi

# THE GITLEAKS ENGINE: the generated config, the report as JSON, one line per finding (the value redacted)
work="$(mktemp -d "${TMPDIR:-/tmp}/secrets.XXXXXX")"; trap 'rm -rf "$work"' EXIT
python3 "$PY" --gitleaks-config "$work/config.toml" || exit 2
nrules="$(grep -c '^\[\[rules\]\]$' "$work/config.toml")"; nallow="$(grep -Evc '^(#|[[:space:]]*$)' "$ROOT/tools/secrets_allow.txt" || true)"
common=(--config "$work/config.toml" --no-banner --no-color --redact --exit-code 1 --report-format json --report-path "$work/report.json" --log-level error --max-decode-depth 0 --max-archive-depth 0)
set +e
case "$mode" in
  --staged) "$GL" git --staged --pre-commit "${common[@]}" "$ROOT" >"$work/log" 2>&1; rc=$?
            scope="the staged lines: $(git -C "$ROOT" diff --cached --numstat | awk '{n+=$1} END {print n+0}') added lines in $(git -C "$ROOT" diff --cached --name-only --diff-filter=d | grep -c .) files" ;;
  --range)  "$GL" git --log-opts="$1" "${common[@]}" "$ROOT" >"$work/log" 2>&1; rc=$?
            scope="the range $(echo "$1" | sed -E 's/([0-9a-f]{9})[0-9a-f]*/\1/g'): $(git -C "$ROOT" log --format=%H "$1" | grep -c .) commits" ;;
  --tree|--paths)
            # gitleaks reads a directory: the tracked files (or the named ones) copied into the scan directory, so the
            # paths it reports are the tree's own and nothing untracked or ignored (the Lean cache, the targets) is read
            mkdir -p "$work/tree"
            if [ "$mode" = --tree ]; then
              (cd "$ROOT" && git ls-files -z | tar --null -T - -cf - 2>/dev/null) | tar -xf - -C "$work/tree"
            else
              for f in "$@"; do mkdir -p "$work/tree/$(dirname "$f")"; cp "$f" "$work/tree/$f"; done
            fi
            nfiles="$(find "$work/tree" -type f | grep -c .)"
            (cd "$work/tree" && "$GL" dir "${common[@]}" .) >"$work/log" 2>&1; rc=$?
            if [ "$mode" = --tree ]; then scope="the tree: $nfiles tracked files (git ls-files)"; else scope="$nfiles named files"; fi ;;
esac
set -e
if [ "$rc" -gt 1 ] || [ ! -s "$work/report.json" ]; then
  cat "$work/log"; echo "secrets: setup error: gitleaks exited $rc with no report"; exit 2
fi
out="$(python3 - "$work/report.json" <<'PY'
import json, sys
rows = json.load(open(sys.argv[1]))
for r in rows:
    print(f"  {r['File'][2:] if r['File'].startswith('./') else r['File']}:{r['StartLine']}: {r['RuleID']} (redacted by gitleaks{', commit ' + r['Commit'][:9] if r.get('Commit') else ''})")
print(len(rows))
PY
)"
n="$(printf '%s\n' "$out" | tail -1)"; printf '%s\n' "$out" | sed '$d'
word=GREEN; [ "$n" = 0 ] || word=RED
echo "secrets: $word [X] (engine gitleaks $GITLEAKS_VERSION at $GL$note, $nrules rules of tools/secrets_patterns.txt, $nallow reviewed exceptions; $scope; findings $n)"
[ "$word" = GREEN ]
