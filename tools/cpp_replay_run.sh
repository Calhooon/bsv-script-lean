#!/bin/zsh -f
# tools/cpp_replay_run.sh (S3, #49 item 2; this repo's): the four differentials on ONE projected corpus/cpp file, on the box.
#
#   zsh -f tools/cpp_replay_run.sh <name>      # <name> = a directory of corpus/cpp/replay (tools/cpp_replay.py project)
#
# Under the box leg lock (the house's helper, as tools/check_box.sh takes it) and a Lean slot under it, both released by the
# EXIT trap: (1) the spec, `eval/bsvs corpus` (built from this tree); (2) bsv-rs, `run_diff --record` (the spec's keys written into
# the corpus, the witnesses and `corpus/witnesses/manifest.json`); (3) the two SV-node instances started on their cited confs
# (harness/oracle/bitcoin.conf, the consensus instrument; bitcoin-policy.conf, the node's default policy) with their datadirs under
# $ORACLE_HOME, `run_svnode --record` (the spec column on `local`, the mempool column on `policy`, the witnesses and
# `corpus/witnesses/sv-node/manifest.json`), and both instances STOPPED before the lock is released. Nothing runs above a 1-minute
# load of 20. The node is regtest on loopback with no peer (CLAUDE.md rule 10). The log of each step is $ORACLE_HOME/logs/<name>-*.
set -u
NAME="${1:?the corpus/cpp/replay directory name}"
W="$(cd "$(dirname "$0")/.." && pwd)"
cd "$W" || exit 2
DIR="corpus/cpp/replay/$NAME"
[ -f "$DIR/cases.jsonl" ] || { echo "cpp_replay_run: no $DIR/cases.jsonl (a corpus committed gzipped runs from its plain form: gzip -dc $DIR/cases.jsonl.gz > $DIR/cases.jsonl, then gzip -9 -n it back after the run)"; exit 2; }
: "${ORACLE_HOME:=$HOME/bsv/targets/spec-oracle-49}"
: "${CARGO_TARGET_DIR:=$HOME/bsv/targets/spec-lane-harness-49-replay}"
export CARGO_TARGET_DIR CARGO_BUILD_JOBS=4 ENGINE_ADAPTER_TIMEOUT_S=60
export SPEC_ORACLE_DATADIR="$ORACLE_HOME/local-data" SPEC_ORACLE_POLICY_DATADIR="$ORACLE_HOME/policy-data"
LOGS="$ORACLE_HOME/logs"; mkdir -p "$LOGS" "$SPEC_ORACLE_DATADIR" "$SPEC_ORACLE_POLICY_DATADIR"
SPEC="$ORACLE_HOME/spec-$NAME.jsonl"
BIN="$CARGO_TARGET_DIR/release"
: "${TAG:=harness-49-replay}"
say() { echo "cpp_replay_run: $(date -u +%H:%M:%SZ) $*"; }
load1() { sysctl -n vm.loadavg | awk '{print int($2)}'; }
[ "$(load1)" -lt 20 ] || { say "STOP: the 1-minute load is $(load1), not under 20"; exit 3; }
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE
# the shared helpers' paths: the owner's host file in this tree (withheld from the public edition, #46)
[ -f tools/host_private.sh ] || { say "STOP: tools/host_private.sh (the owner's host file) is absent"; exit 2; }
. tools/host_private.sh
source "$LEAN_LOCK_SH" || { say "STOP: lean_lock.sh"; exit 2; }
export BOX_LEG_POLL=5
source "$BOX_LEG_LOCK_SH" || { say "STOP: the box leg lock's helper"; exit 2; }
nodes_stop() {
  harness/oracle/spec-node.sh local stop >/dev/null 2>&1
  harness/oracle/spec-node.sh policy stop >/dev/null 2>&1
  for _ in $(seq 1 60); do pgrep -f "datadir=$ORACLE_HOME" >/dev/null || break; sleep 1; done
}
setopt POSIX_TRAPS
trap 'exit 130' INT; trap 'exit 143' TERM; trap 'exit 129' HUP
trap 'nodes_stop; box_leg_release; lean_lock_release' EXIT
box_leg_take "$TAG" "box" "zsh -f tools/cpp_replay_run.sh $NAME (#49's replay)" "#49 item 2, one corpus/cpp file" || exit 1
lean_lock_take "$TAG" || { say "STOP: the Lean lock"; exit 3; }
say "the box leg lock and a Lean slot taken; $DIR ($(wc -l < "$DIR/cases.jsonl" | tr -d ' ') entries); load $(load1)"
say "(1) eval/bsvs corpus $DIR/cases.jsonl --out $SPEC"
eval/bsvs corpus "$DIR/cases.jsonl" --out "$SPEC" > "$LOGS/$NAME-spec.log" 2>&1 || { say "STOP: eval/bsvs (log $LOGS/$NAME-spec.log)"; tail -3 "$LOGS/$NAME-spec.log"; exit 4; }
tail -1 "$LOGS/$NAME-spec.log"
say "(2) run_diff --corpus ../$DIR/cases.jsonl --spec $SPEC --witnesses ../corpus/witnesses --record"
( cd harness && "$BIN/run_diff" --corpus "../$DIR/cases.jsonl" --spec "$SPEC" --witnesses ../corpus/witnesses --record ) > "$LOGS/$NAME-run_diff.log" 2>&1
echo "run_diff rc $?"; grep -E "^run_diff|agree:" "$LOGS/$NAME-run_diff.log" | cut -c1-400
say "(3) the two instances: spec-node.sh local start, spec-node.sh policy start (datadirs under $ORACLE_HOME)"
harness/oracle/spec-node.sh local start 2>&1 | tail -2
harness/oracle/spec-node.sh policy start 2>&1 | tail -2
say "run_svnode --record against local (18563) and policy (18565)"
( cd harness && "$BIN/run_svnode" --corpus "../$DIR/cases.jsonl" --spec "$SPEC" --witnesses ../corpus/witnesses --record \
    --rpc http://127.0.0.1:18563 --cookie "$SPEC_ORACLE_DATADIR/regtest/.cookie" \
    --rpc-mempool http://127.0.0.1:18565 --cookie-mempool "$SPEC_ORACLE_POLICY_DATADIR/regtest/.cookie" ) > "$LOGS/$NAME-run_svnode.log" 2>&1
echo "run_svnode rc $?"; grep -E "^run_svnode|agree" "$LOGS/$NAME-run_svnode.log" | cut -c1-400
say "(4) both instances stopped"
nodes_stop
pgrep -fl "datadir=$ORACLE_HOME" && { say "a node is still running"; exit 5; }
say "done: $NAME"
