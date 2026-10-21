#!/bin/zsh -f
# The Teranode column of #74 in one foreground command (S4b, lane tera-74, 2026-10-14;
# lane fix-tera-74 after the lens): the box leg lock, a Lean slot (the instance host's
# row, docs/PROVENANCE.md 1a: one run under the box leg lock and a Lean slot) and the
# 1-minute load under 20, run_scenarios --teranode (which starts the instance of #41 on a
# fresh data directory by instance.py and stops it), both locks released in the EXIT
# trap, which also stops any instance the run left.
#   zsh -f harness/engines/teranode/column.zsh docs/records/<stamp>-s6-74-second-oracle-s4b.md <run-id>
set -u
RECORD=$1 RUN=$2
W=${0:A:h:h:h:h}; cd "$W" || exit 2
BIN=$W/harness/target/release/run_scenarios   # the worktree's own build (CARGO_TARGET_DIR=$W/harness/target)
DATA=$HOME/bsv/targets/spec-teranode/runs-74/$RUN/data
# #66 cut 2 (S3, lane cut2-66, 2026-10-15): a cut-2 record runs the instance's second recipe
# (the legacy bridge on, harness/engines/instance41/legacy.conf) in runs-66.
if [[ $RECORD == *-s6-66-cut2-second-oracle-s3.md ]]; then
  DATA=$HOME/bsv/targets/spec-teranode/runs-66/$RUN/data
  export INSTANCE41_RECIPE=legacy
fi
# lane cut2-66q (2026-10-15, the quarantine rule): ORACLE_QUARANTINE names the run's
# directory under ~/bsv/targets/spec-oracle-quarantine; the instance's data (its log
# included) lives there, and run_scenarios writes the record's JSON as its projection.
[[ -n ${ORACLE_QUARANTINE:-} ]] && DATA=$ORACLE_QUARANTINE/data
say() { print -r -- "column $(date -u +%H:%M:%SZ): $*"; }
# lane tera-97e2 (2026-10-15, #97): with ORACLE_QUARANTINE set, the steps file
# ${ORACLE_QUARANTINE}.steps.json sits beside the quarantine directory, outside it: one JSON
# object per line (jq reads the stream), {step, started, ended, exit} and a step's numbers,
# written by this script and by instance.py (ORACLE_STEPS: instance_start, readiness_wait);
# step names, UTC stamps and numbers only, never a line of any process's output.
# lane fix-tera-97e2: every exit after client_check writes a step naming it; after the
# EXIT trap is set, its `exit` line is the last.
STEPS=${ORACLE_QUARANTINE:+$ORACLE_QUARANTINE.steps.json}
[[ -n $STEPS ]] && export ORACLE_STEPS=$STEPS
# and the contract's fault lines (client.rs `fault`: the scenario call's source location and time)
# beside it, ${ORACLE_QUARANTINE}.faults.jsonl, unless the caller named another file.
[[ -n $STEPS && -z ${TERA_FAULT_LOG:-} ]] && export TERA_FAULT_LOG=$ORACLE_QUARANTINE.faults.jsonl
utc() { date -u +%Y-%m-%dT%H:%M:%SZ; }
step() {  # step <name> <started> <exit> [<more json members>]
  [[ -n $STEPS ]] || return 0
  print -r -- "{\"step\":\"$1\",\"started\":\"$2\",\"ended\":\"$(utc)\",\"exit\":$3${4:+,$4}}" >>"$STEPS"
}
# lane tera-97g (2026-10-15, #97): before any lock, the native client the contract spawns
# (contract.rs `native_client`: $INSTANCE41_NATIVE_DIR/client, else the recipe's default path)
# is present and its sha256 is the recipe's (harness/engines/instance41/README.md, the native
# client's line; the build's sum depends on its directory, so a build elsewhere fails here).
NATIVE_SHA256=6bd3536ca88028aa4c2338d558b6c5cf714054d609367ba2f5f7d3fd1ae7c251
# an empty INSTANCE41_NATIVE_DIR is refused: contract.rs reads it as the relative path ./client
[[ -n ${INSTANCE41_NATIVE_DIR-x} ]] || { step client_check $(utc) 2; say "STOP: INSTANCE41_NATIVE_DIR is set and empty"; exit 2; }
CLIENT=${INSTANCE41_NATIVE_DIR:-$HOME/bsv/targets/spec-teranode/native-client}/client
t=$(utc)
sum=$([[ -f $CLIENT ]] && shasum -a 256 "$CLIENT" | awk '{print $1}')
if [[ $sum != $NATIVE_SHA256 ]]; then
  step client_check $t 2
  say "STOP: the native client at $CLIENT is absent or not the recipe's build (python3 harness/engines/instance41/native/build.py)"
  exit 2
fi
step client_check $t 0
# nothing starts above a 1-minute load of 20: wait for it, in the foreground, up to 20 minutes
t=$(utc)
for i in {1..40}; do
  load=$(sysctl -n vm.loadavg | awk '{print $2}')
  (( ${load%.*} < 20 )) && break
  say "1-minute load $load: waiting"; sleep 30
done
(( ${load%.*} < 20 )); step load_gate $t $? "\"load\":$load"
(( ${load%.*} < 20 )) || { step stop_load $(utc) 2; say "STOP: 1-minute load $load"; exit 2; }
[ -f tools/host_private.sh ] || { step stop_host_file $(utc) 2; say "STOP: tools/host_private.sh (the owner's host file) is absent"; exit 2; }
. tools/host_private.sh
export BOX_LEG_POLL=5
source "$BOX_LEG_LOCK_SH" || { step stop_box_leg_lib $(utc) 2; exit 2; }
source "$LEAN_LOCK_SH" || { step stop_lean_lock_lib $(utc) 2; exit 2; }
setopt POSIX_TRAPS
trap 'exit 130' INT; trap 'exit 143' TERM; trap 'exit 129' HUP
# The EXIT trap's steps: its stop, its two releases, and the exit code it returns.
trap 'x=$?; t=$(utc); INSTANCE41_DATA=$DATA ORACLE_STEPS= python3 harness/engines/instance41/instance.py stop >/dev/null 2>&1; step instance_stop $t $?
t=$(utc); box_leg_release; step box_leg_release $t $?; t=$(utc); lean_lock_release; step lean_lock_release $t $?; step exit $(utc) $x' EXIT
t=$(utc); box_leg_take ${RUN%%-2*} box "zsh -f harness/engines/teranode/column.zsh $RECORD $RUN" "issue 74: the Teranode column"; r=$?
step box_leg_take $t $r; (( r == 0 )) || exit 3
t=$(utc); lean_lock_take ${RUN%%-2*}; r=$?; step lean_lock_take $t $r; (( r == 0 )) || exit 3
t=$(utc); load=$(sysctl -n vm.loadavg | awk '{print $2}')
(( ${load%.*} < 20 )); step load_gate_locked $t $? "\"load\":$load"
(( ${load%.*} < 20 )) || { step stop_load_locked $(utc) 2; say "STOP: 1-minute load $load under the lock"; exit 2; }
say "leg lock and Lean slot taken; 1-minute load $load; run $RUN"
t=$(utc); "$BIN" --teranode --record "$RECORD" --run-id "$RUN"; rc=$?
step run_scenarios $t $rc
say "run_scenarios rc $rc"
exit $rc
