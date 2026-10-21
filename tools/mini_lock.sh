#!/bin/zsh
# tools/mini_lock.sh: THE MINI LOCK (D82, the owner's plan, 2026-09-24 16:19 UTC). VENDORED into bsv-script-lean on
# 2026-09-26 by S3 (set 4, LANE F) from a sibling program's lock helper of 2026-09-24, as the tree's
# rule 5 of set 4 asks ("every mini row and drill as ONE ssh session under `tools/mini_lock.sh take <tag>`"; the spec
# had no lock). PROVENANCE (CLAUDE.md rule 5): the pattern is mechanism-free, a directory taken by `mkdir`; the sibling's
# own reasons, its drivers' names and its workers' names are not carried; only the spec's workers stand in the idle
# check below. The LOCK DIRECTORY and the HOST are the sibling's exactly (`~/bsv/mini.lock`, host `mini`), so that a
# row of this program and a row of the sibling's on the same mini exclude each other: that is the point of the lock.
#
# WHY, for this repo: the spec's SV-node instance on the mini (`harness/oracle/spec-node.sh mini`; the consensus
# instance today, `harness/oracle/README.md`) serves a record run whose verdicts are the record; two windows' rows on
# one instance must never interleave, and a per-process check (`pgrep`) is a race by construction. A lock is not.
#
# THE LOCK: the directory `~/bsv/mini.lock` ON THE MINI, taken by `mkdir` (atomic: exactly one taker succeeds), holding
# the file `holder` with the taker's tag, pid, host, `date -u` stamp and command; released when the taker's shell exits
# (a `zshexit` hook; SIGINT and SIGTERM release it too); a STALE lock (its holder's pid dead: a crash, a `kill -9`, a
# lost ssh) is BROKEN by the next taker, who prints the broken holder's line (the run's record carries it). Off the mini
# (`hostname -s` is not $MINI_LOCK_HOST, default `mini`) every call is a printed no-op, so a driver that also runs on
# the Studio or on Modal needs no branch. A run driven FROM the Studio against the mini's RPC holds the lock through one
# ssh session for its whole duration (the `hold` form is the runner's, landed with the first mini row of set 4).
#
# USE, SOURCED (a driver, at its top, before its idle check):
#     source $ROOT/tools/mini_lock.sh
#     mini_lock_status || true              # one line: FREE, or HELD by <tag> pid <pid> (alive) since <stamp>, or STALE
#     mini_lock_take <tag>                  # waits up to MINI_LOCK_WAIT s (default 1800) on a live holder, breaks a dead
#                                           # one, exports MINI_LOCK_HELD=<tag>, arms the release at exit; nonzero = not taken
#     mini_idle_check <driver name>         # the regime's check: the lock line, then the pgrep line (real workers only)
#     mini_lock_release                     # explicit (the exit hook does it anyway)
# A driver that already holds it (MINI_LOCK_HELD in the env) takes nothing more.
# USE, AS A COMMAND (an ad-hoc row over ssh, one line):
#     zsh tools/mini_lock.sh status
#     zsh tools/mini_lock.sh take <tag> -- <command …>     # takes, runs the command, releases (the command's exit code)
#     zsh tools/mini_lock.sh break                          # breaks a STALE lock only (a live holder is never broken)
: ${MINI_LOCK_DIR:=$HOME/bsv/mini.lock}
: ${MINI_LOCK_HOST:=mini}
: ${MINI_LOCK_WAIT:=1800}
: ${MINI_LOCK_POLL:=30}

mini_lock_on_host() { [[ $(hostname -s) == $MINI_LOCK_HOST ]] }
mini_lock_holder_field() { sed -n "s/^$1=//p" $MINI_LOCK_DIR/holder 2>/dev/null | head -1 }

# 0 = FREE (or not on the mini), 1 = HELD by a live pid, 2 = STALE (held, the pid dead or missing)
mini_lock_status() {
  if ! mini_lock_on_host; then echo "mini lock: not on $MINI_LOCK_HOST (host $(hostname -s)): no lock"; return 0; fi
  if [[ ! -d $MINI_LOCK_DIR ]]; then echo "mini lock ($(date -u +%H:%M:%SZ)): FREE"; return 0; fi
  local tag=$(mini_lock_holder_field tag) pid=$(mini_lock_holder_field pid) since=$(mini_lock_holder_field taken)
  if [[ -n $pid ]] && kill -0 $pid 2>/dev/null; then
    echo "mini lock ($(date -u +%H:%M:%SZ)): HELD by ${tag:-?} pid $pid (alive) since ${since:-?}"; return 1
  fi
  echo "mini lock ($(date -u +%H:%M:%SZ)): HELD by ${tag:-?} pid ${pid:-none} (DEAD) since ${since:-?}: STALE"; return 2
}

mini_lock_release() {
  [[ -n ${MINI_LOCK_HELD:-} ]] || return 0
  if [[ -d $MINI_LOCK_DIR && $(mini_lock_holder_field pid) == $$ ]]; then
    rm -rf $MINI_LOCK_DIR
    echo "mini lock ($(date -u +%H:%M:%SZ)): RELEASED by $MINI_LOCK_HELD pid $$"
  else
    echo "mini lock ($(date -u +%H:%M:%SZ)): release by $MINI_LOCK_HELD pid $$: not the holder any more (broken as stale, or released already)"
  fi
  unset MINI_LOCK_HELD
}

mini_lock_take() {
  local tag=${1:?mini_lock_take <tag>}
  if ! mini_lock_on_host; then echo "mini lock: not on $MINI_LOCK_HOST (host $(hostname -s)): nothing taken for $tag"; return 0; fi
  if [[ -n ${MINI_LOCK_HELD:-} ]]; then echo "mini lock: already held by this driver ($MINI_LOCK_HELD): $tag rides it"; return 0; fi
  local t0=$(date +%s) st
  while true; do
    if mkdir $MINI_LOCK_DIR 2>/dev/null; then
      printf 'tag=%s\npid=%s\nhost=%s\ntaken=%s\ncmd=%s\n' "$tag" "$$" "$(hostname -s)" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "${ZSH_ARGZERO:-$0} $*" > $MINI_LOCK_DIR/holder
      export MINI_LOCK_HELD=$tag
      echo "mini lock ($(date -u +%H:%M:%SZ)): TAKEN by $tag pid $$ after $(( $(date +%s) - t0 )) s of waiting"
      # the release at exit: a zshexit hook (a `trap … EXIT` set inside a function fires when the FUNCTION returns in
      # zsh, so it cannot be used here); SIGINT and SIGTERM release too, then exit with the signal's code
      typeset -ga zshexit_functions
      (( ${zshexit_functions[(I)mini_lock_release]} )) || zshexit_functions+=(mini_lock_release)
      TRAPINT() { mini_lock_release; exit 130 }
      TRAPTERM() { mini_lock_release; exit 143 }
      return 0
    fi
    mini_lock_status; st=$?
    if (( st == 2 )); then
      echo "mini lock ($(date -u +%H:%M:%SZ)): STALE LOCK BROKEN by $tag: the holder was [$(tr '\n' ' ' < $MINI_LOCK_DIR/holder 2>/dev/null)]"
      rm -rf $MINI_LOCK_DIR
      continue
    fi
    if (( $(date +%s) - t0 >= MINI_LOCK_WAIT )); then
      echo "mini lock ($(date -u +%H:%M:%SZ)): NOT TAKEN by $tag after $MINI_LOCK_WAIT s: the holder is alive (label the row CONTENDED, or wait longer)"
      return 1
    fi
    sleep $MINI_LOCK_POLL
  done
}

# the regime's idle check with the lock read first: the lock's line, then the pgrep line (real workers only: this
# driver's name and any `zsh -c` wrapper quoting the pattern excluded); 0 = idle. The pattern names THIS program's
# workers on the mini (the node, its CLI, the harness's runners, a build); a sibling program's worker shows up under
# the lock, never under this pattern.
mini_idle_check() {
  local me=${1:-mini_idle_check}
  mini_lock_status || true
  local busy=$(pgrep -fl "cargo|lake|bitcoind|bitcoin-cli|run_svnode|run_engine|run_diff|bsvs" | grep -v "$me" | grep -v "zsh -c" | grep -v "mini_lock" | head -3)
  echo "idle check ($(date -u +%H:%M:%SZ)): pgrep -fl \"cargo|lake|bitcoind|bitcoin-cli|run_svnode|run_engine|run_diff|bsvs\" | grep -v <this driver> | grep -v \"zsh -c\" → ${busy:-(empty: no worker)}"
  [[ -z $busy ]]
}

# the command form (never when sourced: ZSH_EVAL_CONTEXT is `toplevel` only for a script run as one)
if [[ ${ZSH_EVAL_CONTEXT:-} == toplevel ]]; then
  case ${1:-status} in
    status) mini_lock_status; exit $? ;;
    break)
      mini_lock_status; st=$?
      if (( st == 2 )); then echo "mini lock: STALE LOCK BROKEN by hand: the holder was [$(tr '\n' ' ' < $MINI_LOCK_DIR/holder 2>/dev/null)]"; rm -rf $MINI_LOCK_DIR; exit 0; fi
      (( st == 1 )) && { echo "mini lock: the holder is alive: not broken"; exit 1 }
      exit 0 ;;
    take)
      tag=${2:?take <tag> -- <command …>}; shift 2
      [[ ${1:-} == -- ]] && shift
      (( $# )) || { echo "mini lock: take <tag> -- <command …> (a lock held by a command that exits is stale at once)"; exit 2 }
      mini_lock_take $tag || exit 1
      "$@"; rc=$?
      mini_lock_release
      exit $rc ;;
    *) echo "mini_lock.sh: status | take <tag> -- <command …> | break"; exit 2 ;;
  esac
fi
