#!/bin/zsh -f
# One chunk of the seed run against the issue-41 instance, in the foreground:
# the box leg lock, then a Lean slot under it (as tools/check_box.sh's remote
# part takes them), the instance started by instance.py, the adapter over
# corpus lines [FROM, FROM+COUNT), the instance stopped, both locks released.
# The EXIT trap names every release and the stop, so a signal or a failure
# leaves no instance and no lock behind.
#   zsh -f harness/engines/instance41/seed_chunk.zsh FROM COUNT RUNROOT
# Another corpus: CORPUS=corpus/flow (and MANIFEST=cases-manifest.json where the
# corpus names its manifest so); another chain: INSTANCE41_DATA=<its directory>,
# read by instance.py and the adapter alike. The defaults are the seed run's.
set -u
FROM=$1 COUNT=$2 ROOT=$3
CORPUS=${CORPUS:-corpus/seed} MANIFEST=${MANIFEST:-manifest.json}
W=${0:A:h:h:h:h}; cd "$W" || exit 2
E=$W/harness/engines/instance41
BIN=$HOME/bsv/targets/spec-lane-harness-b-41/release/run_teranode
say() { print -r -- "seed_chunk $(date -u +%H:%M:%SZ): $*"; }
# nothing starts above a 1-minute load of 20: wait for it, in the foreground, up to 20 minutes
for i in {1..40}; do
  load=$(sysctl -n vm.loadavg | awk '{print $2}')
  (( ${load%.*} < 20 )) && break
  say "1-minute load $load: waiting"; sleep 30
done
(( ${load%.*} < 20 )) || { say "STOP: 1-minute load $load"; exit 2; }
# a stopped node's loopback ports stay bound for some seconds after it exits;
# instance.py's start refuses a bound port, so wait for them, up to 2 minutes
python3 - <<'PY' || { say "STOP: the instance's ports stay bound"; exit 2; }
import socket, sys, time
ports = (8000, 8081, 8082, 8084, 8085, 8086, 8087, 8088, 8090, 8833, 8834, 9091, 9292)
for _ in range(60):
    try:
        for port in ports:
            with socket.socket() as probe:
                probe.bind(("127.0.0.1", port))
        sys.exit(0)
    except OSError:
        time.sleep(2)
sys.exit(1)
PY
# the shared helpers' paths, as tools/check_box.sh reads them: the owner's host file (withheld from the public edition, #46)
[ -f tools/host_private.sh ] || { say "STOP: tools/host_private.sh (the owner's host file) is absent"; exit 2; }
. tools/host_private.sh
source "$LEAN_LOCK_SH" || exit 2
export BOX_LEG_POLL=5
source "$BOX_LEG_LOCK_SH" || exit 2
setopt POSIX_TRAPS
trap 'exit 130' INT; trap 'exit 143' TERM; trap 'exit 129' HUP
trap 'python3 "$E/instance.py" stop >/dev/null 2>&1; box_leg_release; lean_lock_release' EXIT
box_leg_take harness-b-41 box "zsh -f harness/engines/instance41/seed_chunk.zsh $FROM $COUNT ($CORPUS)" "issue 41: $CORPUS against the instance" || exit 3
lean_lock_take harness-b-41 || exit 3
say "locks taken; load $load; $CORPUS; data ${INSTANCE41_DATA:-default}; start"
python3 "$E/instance.py" start --validator || { say "STOP: start"; exit 4; }
say "tip $(python3 "$E/instance.py" rpc getmininginfo | python3 -c 'import json,sys; d=json.load(sys.stdin); d=d.get("result",d); print(d["blocks"])')"
out=$ROOT/chunk-$(printf %05d $FROM)
"$BIN" --corpus "$CORPUS" --manifest "$MANIFEST" --from $FROM --limit $COUNT --out "$out"; rc=$?
python3 "$E/instance.py" stop; say "adapter rc $rc; instance stopped"
exit $rc
