#!/usr/bin/env bash
# tools/check_box.sh (bsv-script-lean, S3 the harness, 2026-09-28; D156, the owner: "Modal only when we have to, when it's
# blocking"; RULES-TREE (27)): THE TRIPWIRE ON THE BOX, the lane's route above the Studio's load gate and for the tripwire of
# record. Run from the Studio (the box never reaches the Studio: the Studio drives it over `ssh box`), for the caller's HEAD,
# which must be clean and on a pushed branch (the box fetches it):
#   1. the box's clone ($BSV_SPEC_BOX_CLONE) fetches; the CALLER's own box worktree $BSV_SPEC_BOX_WORKTREE_PREFIX<caller> (made once,
#      detached; <caller> the Studio worktree's name without its `spec-`) checks out HEAD. One worktree per caller since the
#      collision of 2026-09-29 01:25 to 01:53 UTC (a Finding on #35): with one worktree for every caller, a second caller's checkout
#      moved the tree under a first caller's run that was still waiting for its locks, and the locks carried S3's tag for everyone;
#   2. the toolchains the pins pin (docs/PROVENANCE.md §1a: go.major 1.27, node.major 22; Rust 1.95.0 by rustup from
#      harness/rust-toolchain.toml) in $BSV_SPEC_BOX_TOOLCHAINS, Go and Node from go.dev and nodejs.org verified against
#      their own sha256 lists (the pattern of tools/modal_check.py's layer 1); nothing installed system-wide;
#   3. the box leg lock by the house's ONE helper (D158: the shared tools/box_leg_lock.sh, `$BOX_LEG_LOCK_SH` in tools/host_private.sh, sourced under
#      /bin/zsh -f), in its FIFO queue holding no Lean slot, and THEN a Lean lock slot (D149's cap) under it; RULES-TREE (33)'s
#      the traps (INT, TERM, HUP and EXIT) set once before every take, POSIX_TRAPS on, the EXIT trap releasing both;
#   4. the spec's Lean packages under a Lean slot BEFORE the queue (the slot given back after them): `lean_cache.py share` when the box holds the key, else
#      `lean_cache.py fetch` (Lake's own road, public reads, 10 to 20 minutes on a box without them); `make tssdk-install` when absent;
#   5. `make check-local` there: the twenty-nine legs, the clones the box lacks SKIPPED BY NAME by the pins and cite legs (never a
#      pass), as in the container;
#   6. the record brought home unchanged as docs/records/<stamp>-make-check-box.txt, and removed from the box's worktree.
# Its exit code is the tripwire's (2 for a setup stop, the Studio's fetch included, 3 for a lock that stayed held an hour or a
# take that failed), 255 passed through from ssh when the connection itself fails, and 1 for an rc 0 that came back without
# the box's own GREEN (RULES-TREE (28), below), with a record naming another commit than the caller's HEAD, or with a record
# that did not copy home.
# THE HOST (#177): a maintainers' route. The box's ssh name and its paths (each relative to the box user's home) come from
# the environment or from tools/host_private.sh (withheld from the public edition): BSV_SPEC_BOX (the ssh host),
# BSV_SPEC_BOX_CLONE (the box's clone), BSV_SPEC_BOX_WORKTREE_PREFIX (a caller's worktree is the prefix and the caller's name),
# BSV_SPEC_BOX_TOOLCHAINS (the pinned toolchains), BSV_SPEC_BOX_TARGET (the legs' cargo target) and BSV_SPEC_BOX_TAG_CLONES (the clones whose tags are fetched, spaces between);
# without them it stops with one line and exit 2.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
HOST_ROUTE=check_box
host_var() {  # NAME: from the environment, else tools/host_private.sh (#177), else one line and exit 2
  local v="$1"
  if [ -z "${!v:-}" ] && [ -f "$ROOT/tools/host_private.sh" ]; then
    printf -v "$v" %s "$(bash -c '. "$1" >/dev/null 2>&1; printf %s "${!2:-}"' _ "$ROOT/tools/host_private.sh" "$v")"
  fi
  [ -n "${!v:-}" ] || [ "${2:-}" = optional ] || { echo "$HOST_ROUTE: a maintainers' route; it needs tools/host_private.sh or $v (tools/README.md)"; exit 2; }
}
for v in BSV_SPEC_BOX BSV_SPEC_BOX_CLONE BSV_SPEC_BOX_WORKTREE_PREFIX BSV_SPEC_BOX_TOOLCHAINS BSV_SPEC_BOX_TARGET; do host_var "$v"; done
host_var BSV_SPEC_BOX_TAG_CLONES optional
BOX="$BSV_SPEC_BOX"; BOX_WT="$BSV_SPEC_BOX_WORKTREE_PREFIX"
C="$(git -C "$ROOT" rev-parse HEAD)"; SHORT="$(git -C "$ROOT" rev-parse --short HEAD)"
[ -z "$(git -C "$ROOT" status --porcelain)" ] || { echo "check_box: uncommitted paths: the box runs a pushed commit"; exit 2; }
git -C "$ROOT" fetch -q origin || { echo "check_box: the fetch of origin failed: the pushed check below cannot be read"; exit 2; }
[ -n "$(git -C "$ROOT" branch -r --contains "$C" 2>/dev/null)" ] || { echo "check_box: $SHORT is on no pushed branch: push it first (the box fetches it)"; exit 2; }
# the caller: the Studio worktree's name without its `spec-` (spec-lean-b -> lean-b), the box worktree's suffix and the locks' tag
CALLER="$(basename "$ROOT" | sed 's/^spec-//; s/[^A-Za-z0-9._-]/_/g')"
echo "check: BOX (the caller's HEAD $SHORT, for $CALLER, on the box over ssh; D156)"
OUT="$(mktemp -t check-box)"
set +e
ssh -o ConnectTimeout=15 -o BatchMode=yes "$BOX" /bin/zsh -f -s -- "$C" "$CALLER" "$BSV_SPEC_BOX_CLONE" "$BOX_WT" "$BSV_SPEC_BOX_TOOLCHAINS" "$BSV_SPEC_BOX_TAG_CLONES" "$BSV_SPEC_BOX_TARGET" <<'REMOTE' 2>&1 | tee "$OUT"
set -u -o pipefail
C="$1"; CALLER="$2"; TAG="check-box:$CALLER"
say() { echo "[box $(date -u +%H:%M:%SZ) load1 $(sysctl -n vm.loadavg | awk '{print $2}')] $*"; }
CL="$HOME/$3"; W="$HOME/$4$CALLER"; TC="$HOME/$5"; TAGCL="$6"; BT="$HOME/$7"
GOV=1.27.0; NODEV=22.18.0
git -C "$CL" fetch -q origin || { say "STOP: the clone's fetch"; exit 2; }
# the pinned clones the box holds read their tags at the pin (the pins leg: a present clone without its tag is a DRIFT, the
# third run of 2026-09-28 at bsv-rs v0.3.30): fetched here, a read; an absent clone stays absent (skipped by name)
for d in ${=TAGCL}; do d="$HOME/$d"; [ -d "$d/.git" ] && { git -C "$d" fetch -q --tags origin || say "the tags of $d did not fetch"; }; done
[ -d "$W" ] || git -C "$CL" worktree add -q --detach "$W" "$C" || { say "STOP: the worktree"; exit 2; }
cd "$W" || exit 2
[ -z "$(git status --porcelain)" ] || { say "STOP: the box worktree is dirty"; git status --short | head; exit 2; }
git checkout -q --detach "$C" || { say "STOP: the checkout of $C"; exit 2; }
say "the box worktree $W at $(git rev-parse --short HEAD)"
mkdir -p "$TC"
if [ "$("$TC/go/bin/go" version 2>/dev/null | awk '{print $3}')" != "go$GOV" ]; then
  say "Go $GOV from go.dev, verified against go.dev's sha256 list"
  ( cd "$TC" && curl -sSfL 'https://go.dev/dl/?mode=json&include=all' -o godl.json \
    && SHA=$(python3 -c "import json; d=json.load(open('godl.json')); print(next(f['sha256'] for r in d for f in r['files'] if f['filename']=='go$GOV.darwin-arm64.tar.gz'))") \
    && curl -sSfL "https://go.dev/dl/go$GOV.darwin-arm64.tar.gz" -o go.tgz && echo "$SHA  go.tgz" | shasum -a 256 -c - \
    && rm -rf go && tar -xzf go.tgz && rm -f go.tgz godl.json ) || { say "STOP: Go"; exit 2; }
fi
if [ "$("$TC/node/bin/node" --version 2>/dev/null)" != "v$NODEV" ]; then
  say "Node $NODEV from nodejs.org, verified against its SHASUMS256.txt"
  ( cd "$TC" && curl -sSfL "https://nodejs.org/dist/v$NODEV/SHASUMS256.txt" -o SHASUMS256.txt \
    && curl -sSfL "https://nodejs.org/dist/v$NODEV/node-v$NODEV-darwin-arm64.tar.xz" -o node.tar.xz \
    && grep " node-v$NODEV-darwin-arm64.tar.xz\$" SHASUMS256.txt | sed "s| node-v$NODEV-darwin-arm64.tar.xz| node.tar.xz|" | shasum -a 256 -c - \
    && rm -rf node && mkdir node && tar -C node --strip-components=1 -xJf node.tar.xz && rm -f node.tar.xz SHASUMS256.txt ) || { say "STOP: Node"; exit 2; }
fi
export PATH="$TC/go/bin:$TC/node/bin:$PATH"
say "the toolchains: $(go version | awk '{print $3}'), node $(node --version)"
# the shared helpers' paths: the maintainers' host file in the checked-out tree (withheld from the public edition, #46)
[ -f tools/host_private.sh ] || { say "STOP: tools/host_private.sh (the maintainers' host file) is absent"; exit 2; }
. tools/host_private.sh
source "$LEAN_LOCK_SH" || { say "STOP: lean_lock.sh"; exit 2; }
# THE BOX LEG LOCK BY THE HOUSE'S ONE HELPER (D158; the owner's plan's continue 35 of 2026-09-29: one helper, one owner, the shared
# tools/box_leg_lock.sh (`$BOX_LEG_LOCK_SH`, tools/host_private.sh), sourced by every leg of every program; zsh only, so this remote part runs
# under /bin/zsh -f): box_leg_take at the script's level, box_leg_release at the leg's end and in the EXIT trap at the script's
# level (never inside a function). zsh's `trap ... EXIT` and lean_lock.sh's TRAPEXIT are ONE trap (each replaces the other), so the
# one trap here names both releases: the leg lock's by the helper, the Lean slot's by lean_lock.sh.
BLL="$BOX_LEG_LOCK_SH"
grep -q "THE FORM (D158)" "$BLL" 2>/dev/null || { say "STOP: $BLL is absent or not D158's symlink form"; exit 2; }
# the helper polls every BOX_LEG_POLL s (30 by default); 5 is the owner's plan's stopgap until its wake-on-release lands (continue
# 36, 2026-09-29 05:2x UTC: "export it in your recipes too"), set before the sourcing, which keeps a value already set
export BOX_LEG_POLL=5
source "$BLL" || { say "STOP: the box leg lock's helper"; exit 2; }
# THE TRAPS, SET ONCE BEFORE EVERY TAKE (RULES-TREE (33) and its addenda; the owner's plan's continue 43 of 2026-09-29 11:2x UTC:
# the shared helper defines no trap since its owner's retirement of it, so nothing replaces these at a take): POSIX_TRAPS keeps
# the EXIT trap the shell's, never a function's; INT, TERM and HUP do nothing but exit (130, 143, 129: an explicit exit from a
# signal trap runs the EXIT trap; a HUP, the ssh session's end, would otherwise leave the locks beside a live child); the EXIT
# trap names every release this script owes.
setopt POSIX_TRAPS
trap 'exit 130' INT; trap 'exit 143' TERM; trap 'exit 129' HUP
trap 'box_leg_release; lean_lock_release' EXIT
say "the box shell's pid is $$: to stop this run, kill -TERM it on the box (during the legs its trap stops them within seconds; in a lock's wait, once the current sleep ends; then the EXIT trap releases both locks)"
# THE PACKAGES FIRST (the second run of 2026-09-28 held the leg lock through the spec's first fetch): a Lean slot, and under it
# alone the Lean packages and the ts-sdk packages; the slot is given back before the queue below.
lean_lock_take "$TAG" || { say "STOP: the Lean lock"; exit 3; }
python3 "$LEAN_CACHE_PY" share "$W" 2>&1 | tail -1 || say "lean_cache.py share failed (the packages check below decides)"
if [ ! -e lean/.lake/packages/mathlib ]; then
  [ -e lean/.lake/packages ] && [ ! -L lean/.lake/packages ] && { say "STOP: a partial lean/.lake/packages (not a link) is here; remove it by hand"; exit 2; }
  say "the spec's Lean key is absent on the box: lean_cache.py fetch (Lake's own road, public reads), under the Lean slot only"
  python3 "$LEAN_CACHE_PY" fetch "$W" 2>&1 | tail -3
  [ -e lean/.lake/packages/mathlib ] || { say "STOP: the Lean packages"; exit 2; }
fi
TS_WANT=$(python3 -c 'import json; print(json.load(open("harness/engines/ts/package-lock.json"))["packages"]["node_modules/@bsv/sdk"]["version"])') || exit 2
TS_HAVE=$(python3 -c 'import json; print(json.load(open("harness/engines/ts/node_modules/@bsv/sdk/package.json"))["version"])' 2>/dev/null) || TS_HAVE=absent
[ "$TS_HAVE" = "$TS_WANT" ] || { say "make tssdk-install at $TS_WANT"; make tssdk-install > /dev/null 2>&1 || { say "STOP: npm ci"; exit 2; }; }
# THE QUEUE (the shared helper since 2026-09-29: box_leg_take registers a FIFO ticket before its first read, and a
# take at a free lock yields to an older live ticket). A read loop without a ticket lost its place to every ticketed waiter (the
# runs of 2026-09-29 waited 22 to 47 minutes), and a slot re-taken before the take stood idle in its wait (871 s, continue 35's owed
# fix). So the slot is given back before the queue, box_leg_take waits in its order holding nothing, and the Lean slot is taken
# under the leg lock. The order leg lock, then Lean slot is this route's; a lane that holds a Lean slot while it queues for the
# leg lock can deadlock against it until an hour's cap: the house's one order is asked of the owner's plan.
lean_lock_release
box_leg_take "$TAG" "box" "zsh -f tools/check_box.sh (the spec's tripwire at ${C:0:7} for $CALLER)" "the spec's tripwire of record (D156)" || { say "STOP: the box leg lock"; exit 3; }
lean_lock_take "$TAG" || { say "STOP: the Lean lock"; exit 3; }
# the tree under both locks is the caller's commit, checked again here (the collision of 2026-09-29: a checkout before the locks)
[ "$(git rev-parse HEAD)" = "$C" ] && [ -z "$(git status --porcelain)" ] || { say "STOP: the box worktree is not at $C, clean, under the locks"; exit 2; }
say "the box leg lock and a Lean slot taken; the worktree at ${C:0:7}, clean"
say "make check-local"
# THE HEAVY STEP IN ITS OWN SESSION (RULES-TREE (33) addendum 2, corrected by execution, the owner's plan's continue 39 of
# 2026-09-29 06:5x UTC): zsh runs a trapped signal only when the foreground child returns, so a foreground make check-local held
# both locks until it ended; and without a terminal a backgrounded child shares the script's group. So the step starts in ITS OWN
# session (python3 backgrounded, never a shell function), the script waits on it, and both signal traps kill its group, wait,
# and exit: the EXIT trap then releases the locks after the child is dead (rows run on the Studio and the box: TERM rc 143 and
# INT rc 130 within 0.03 s, the stand-in child dead before the release; a normal run rc 0). The rule's executed rows since: the
# child's SIGPIPE and SIGINT restored to their defaults at the spawn (F3; the INT caveat), HUP forwarded like TERM (F2), the
# wait guarded (F1).
python3 -c 'import os, signal, sys; signal.signal(signal.SIGPIPE, signal.SIG_DFL); signal.signal(signal.SIGINT, signal.SIG_DFL); os.setsid(); os.execvp(sys.argv[1], sys.argv[1:])' env CARGO_TARGET_DIR="$BT" CARGO_BUILD_JOBS=4 make check-local & child=$!
trap 'kill -TERM -- -$child 2>/dev/null || kill -TERM $child 2>/dev/null; wait $child; exit 143' TERM
trap 'kill -TERM -- -$child 2>/dev/null || kill -TERM $child 2>/dev/null; wait $child; exit 130' INT
trap 'kill -TERM -- -$child 2>/dev/null || kill -TERM $child 2>/dev/null; wait $child; exit 129' HUP
rc=0; wait $child || rc=$?
trap 'exit 130' INT; trap 'exit 143' TERM; trap 'exit 129' HUP
box_leg_release || say "box_leg_release returned non-zero (the EXIT trap releases again)"
REC="$(git status --porcelain --untracked-files=all | awk '$1=="??" && $2 ~ /^docs\/records\/.*-make-check\.txt$/ {print $2}' | tail -1)"
echo "CHECK_BOX_RECORD=$REC"
say "make check-local rc $rc"
exit $rc
REMOTE
RC=${PIPESTATUS[0]}
set -e
REC="$(sed -n 's/^CHECK_BOX_RECORD=//p' "$OUT" | tail -1)"
GREENLINE=0; grep -q '^make check: GREEN' "$OUT" && GREENLINE=1
rm -f "$OUT"
HOME_REC=
if [ -n "$REC" ]; then
  HOME_REC="$ROOT/${REC%-make-check.txt}-make-check-box.txt"
  if scp -q "$BOX:$BOX_WT$CALLER/$REC" "$HOME_REC"; then
    ssh -o BatchMode=yes "$BOX" "rm -f ~/$BOX_WT$CALLER/$REC" || echo "check_box: the record stays on the box too (its removal failed)"
    echo "the record ${HOME_REC#$ROOT/} (written by tools/check.sh on the box, brought home unchanged; commit it with the run's page line)"
  else
    echo "check_box: RED: the record $REC did not copy home (scp failed); it stays in the box worktree $BOX_WT$CALLER"
    HOME_REC=; RC=1
  fi
else
  echo "check_box: no record came back (rc $RC): the setup stopped before make check-local, or check.sh did not reach record_run"
fi
# THE RECORD'S COMMIT (the collision of 2026-09-29, a Finding on #35): the record names the tree the legs ran, and it must be the
# caller's HEAD; a record naming another commit is RED, whatever its status.
if [ -n "$HOME_REC" ]; then
  RCOMMIT="$(sed -n 's/^commit: \([0-9a-f]*\).*/\1/p' "$HOME_REC" | head -1)"
  case "$C" in
    "$RCOMMIT"*) [ -n "$RCOMMIT" ] || { echo "check_box: RED: the record names no commit"; RC=1; } ;;
    *) echo "check_box: RED: the record names $RCOMMIT, not the caller's HEAD $SHORT: the legs ran another tree"; RC=1 ;;
  esac
fi
# THE BOX'S OWN GREEN (RULES-TREE (28)): ssh runs the remote command through the box user's login zsh, which reads ~/.zshenv
# before anything (no -f reaches it): a NO_EXEC there would run nothing and return 0. So rc 0 counts only with the box's own
# evidence: the "make check: GREEN" line check.sh prints after every leg's own line stood, a record brought home, and that
# record's "status: GREEN"; without all three the route reads RED.
if [ "$RC" = 0 ]; then
  if [ "$GREENLINE" != 1 ] || [ -z "$HOME_REC" ] || ! grep -q '^status: GREEN' "$HOME_REC" 2>/dev/null; then
    echo "check_box: RED: the box returned rc 0 without its own GREEN (the 'make check: GREEN' line $([ "$GREENLINE" = 1 ] && echo present || echo ABSENT), a record $([ -n "$HOME_REC" ] && echo present || echo ABSENT)); RULES-TREE (28)"
    RC=1
  fi
fi
exit "$RC"
