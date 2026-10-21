#!/usr/bin/env bash
# tools/cargo_deny.sh (bsv-script-lean #133, S3, lane gate-133, 2026-10-14 [M]): the deny leg of tools/check.sh, the wrapper
# rule's wrapper. It runs `cargo deny --manifest-path harness/Cargo.toml check` against harness/deny.toml (advisories,
# licenses, bans, sources) with cargo-deny at its pin, and prints ONE verdict line of its own:
#   cargo-deny: GREEN [X] (...)               every check ok; exit 0
#   cargo-deny: RED (exit N; ...)             a check failed, the diagnostics above it; exit 1
#   cargo-deny: SKIPPED BY NAME (...)         cargo-deny at the pin is absent and its install failed, the reason named; exit 0
#                                             (the record shows the line: a skip is never a pass)
#   a failed advisory fetch is RED by design (the cached copy is read only under CARGO_DENY_FETCH=0)
# THE PIN: cargo-deny 0.19.0 (DENY_VERSION below). A cargo-deny on PATH at that version is used; else the one in the
# toolchain directory; else it is installed there by `cargo install --locked --version 0.19.0` (crates.io, a public read,
# rule 10), with the harness's pinned Rust (harness/rust-toolchain.toml). The toolchain directory: $DENY_TOOLCHAINS when set;
# else ~/bsv/targets/spec-box/toolchains where it exists (the box's, tools/check_box.sh step 2); else harness/target/toolchains
# inside this tree. The advisory database is fetched from RustSec (a public read) unless CARGO_DENY_FETCH=0, which reads the
# cached copy and says so on the verdict line.
# `tools/cargo_deny.sh` alone runs the leg; `tools/check.sh deny` runs it as `all` does.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DENY_VERSION=0.19.0
MANIFEST="${DENY_MANIFEST:-$ROOT/harness/Cargo.toml}"
if [ -n "${DENY_TOOLCHAINS:-}" ]; then TC="$DENY_TOOLCHAINS"
elif [ -d "$HOME/bsv/targets/spec-box/toolchains" ]; then TC="$HOME/bsv/targets/spec-box/toolchains"
else TC="$ROOT/harness/target/toolchains"; fi
have_pin() { [ -x "$1" ] && [ "$("$1" --version 2>/dev/null | awk '{print $2}')" = "$DENY_VERSION" ]; }
DENY=
if have_pin "$(command -v cargo-deny 2>/dev/null)"; then DENY="$(command -v cargo-deny)"
elif have_pin "$TC/cargo-deny-$DENY_VERSION/bin/cargo-deny"; then DENY="$TC/cargo-deny-$DENY_VERSION/bin/cargo-deny"
else
  echo "deny: cargo-deny $DENY_VERSION is absent: cargo install --locked into $TC/cargo-deny-$DENY_VERSION"
  mkdir -p "$TC"
  if ( cd "$ROOT/harness" && CARGO_TARGET_DIR="$TC/cargo-deny-build" cargo install --locked --quiet --version "$DENY_VERSION" \
        --root "$TC/cargo-deny-$DENY_VERSION" cargo-deny ) && have_pin "$TC/cargo-deny-$DENY_VERSION/bin/cargo-deny"; then
    rm -rf "$TC/cargo-deny-build"
    DENY="$TC/cargo-deny-$DENY_VERSION/bin/cargo-deny"
  else
    echo "cargo-deny: SKIPPED BY NAME (cargo-deny $DENY_VERSION is absent and its install into $TC failed; the four checks did not run)"
    exit 0
  fi
fi
FETCH_ARGS=(); FETCH_NOTE="fetched"
if [ "${CARGO_DENY_FETCH:-1}" = 0 ]; then FETCH_ARGS=(--disable-fetch); FETCH_NOTE="the cached copy, no fetch"; fi
OUT="$(mktemp)"
# cargo-deny reads cargo's own metadata of the locked tree (--locked: the lock file may not move)
"$DENY" --manifest-path "$MANIFEST" --locked check ${FETCH_ARGS[@]+"${FETCH_ARGS[@]}"} --config "$(dirname "$MANIFEST")/deny.toml" \
  advisories bans licenses sources > "$OUT" 2>&1
rc=$?
grep -E '^(error|warning)\[' "$OUT" | sort | uniq -c; grep -v '^ *$' "$OUT" | tail -40
SUMMARY="$(grep -oE '(advisories|bans|licenses|sources) (ok|FAILED)' "$OUT" | paste -sd, - | sed 's/,/, /g')"
DB="$(for d in "${CARGO_HOME:-$HOME/.cargo}"/advisory-dbs/advisory-db-*/; do git -C "$d" rev-parse --short=12 HEAD 2>/dev/null && break; done)"
rm -f "$OUT"
WHERE="cargo-deny $DENY_VERSION at $DENY; the RustSec database at ${DB:-an unread commit} ($FETCH_NOTE)"
if [ "$rc" = 0 ]; then
  echo "cargo-deny: GREEN [X] (${SUMMARY:-the four checks ok}; $WHERE)"
else
  echo "cargo-deny: RED (exit $rc; ${SUMMARY:-no summary line}; $WHERE)"
  exit 1
fi
