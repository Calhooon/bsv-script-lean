#!/usr/bin/env bash
# tools/teranode_gate.sh (bsv-script-lean #95; S3, lane gate-95, 2026-10-17): THE PER-RELEASE DIVERGENCE GATE, the live
# half of `make teranode-gate`. One Teranode release against the reference pin, both of docs/PROVENANCE.md section 1a,
# on the scenario corpus (#66) and the script corpus, read through #88's obligation list; the page is written by
# tools/teranode_gate.py (its header names every input) as docs/records/<stamp>-s8-95-gate-report-s3.{md,json}, a public
# page of verdict words and codes, classes, row ids, hashes and counts (the captain's ruling of 2026-10-17). Every step's
# raw output (the nodes' own text) is appended to docs/records/<SINCE>-s8-95-gate-teranode-log-s4b.txt, never to the
# terminal, and the step names that file in tools/export_withheld.txt under the group hz-95-teranode-gate-logs, so the
# export never carries it and an ordinary lane never opens it; the terminal gets the step's exit code and the log's name.
#
#   make teranode-gate DRY_RUN=1 [OUT_DIR=<dir>]  the page from the records on disk; starts nothing (tools/teranode_gate.py
#                                                 --dry-run); the pair under docs/records, or under OUT_DIR
#   make teranode-gate                            this plan: every step's command with this run's stamp; starts nothing
#   make teranode-gate STEP=<step> SINCE=<stamp> [FAMILY=<f>] [CORPUS=<c> FROM=<n> COUNT=<n> MANIFEST=<m>] [ORACLE_ROWS=<ids>]
#
# THE STEPS, in order, each ONE foreground command meant to fit the 600 s a call may take (the scenario column in the
# chunks `tools/teranode_gate.py --chunks` prints: its whole wall 2,017.7 s, 20261016-001926's `wall_seconds`, in six
# chunks of at most about 400 s [EST] (2,017.7 s over 137 realizable rows, 23 a chunk; 400 s is the target, CHUNK_SECONDS;
# the land-w3w fold, 2026-10-17); the script-reference step per corpus, its wall now of record: the 20261017-234627 run
# re-measured 18 corpora, every one REPRODUCED, cpp-opcode's 144,324 entries in 36 s and cpp-script's 67,991 in 15 s), each
# writing its own
# record; SINCE is the stamp the plan printed, and every step's record carries it, so the report reads only this run's
# records:
#   scenario-teranode   harness/engines/teranode/column.zsh (run_scenarios --teranode, through the observation contract
#                       of #97): STARTS the Teranode instance of harness/engines/instance41 (its recipe `legacy`) on a fresh
#                       data directory and stops it; ORACLE_ROWS names a chunk's rows, a run of chunks covering every row once;
#                       the box leg lock and a Lean slot taken PER CHUNK by column.zsh (a chunk is one foreground call and
#                       the lock's holder is the calling process: holding it across calls would need a background holder,
#                       which the lanes' run rule forbids; per chunk also lets the FIFO queue interleave a tripwire leg)
#   scenario-reference  run_scenarios --family FAMILY: STARTS fresh regtest instances of the reference pin and stops them
#                       (harness/README.md, the chain-layer node runner); once per family of corpus/chain; the box leg
#                       lock and a Lean slot taken HERE (run_scenarios takes none), as column.zsh:67-79 takes them
#   script-teranode     harness/engines/instance41/seed_chunk.zsh FROM COUNT: STARTS the instance by instance.py, runs
#                       run_teranode over CORPUS's lines [FROM, FROM+COUNT), stops it; manifests under
#                       harness/engines/instance41/runs/SINCE-gate/<corpus>/; MANIFEST defaults to the corpus's own
#                       (cases-manifest.json where it carries one: arith, bytes, crypto, stack; else manifest.json)
#   script-reference    tools/column.sh sv-node <reference tag> [CORPUS=<c>]: the reference's script column re-run at the
#                       pin on the two instances SV_RPC/SV_COOKIE and SV_RPC_MEMPOOL/SV_COOKIE_MEMPOOL name (never started
#                       by it)
#   report              tools/teranode_gate.py --live --since SINCE --stamp SINCE: the page; refuses a source older than SINCE
# The rows a leg measured (#92, #93, #94, #140, #152) are re-run by their legs' runners, which their records name; the
# gate carries their public counts (corpus/teranode/obligations.json) and never opens a withheld record.
# Every step that starts a node is a hazard-class step and takes the box leg lock (~/bsv/box-leg.lock, $BOX_LEG_LOCK of the
# shared helper $BOX_LEG_LOCK_SH) and a Lean slot ($LEAN_LOCK_SH), both named by tools/host_private.sh: scenario-teranode
# and script-teranode in their sub-scripts (column.zsh, seed_chunk.zsh), scenario-reference here; nothing starts above a
# 1-minute load of 20 (CLAUDE.md rule 17). script-reference starts no node. No step reaches the network (rule 10).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
STEP="${STEP:-plan}"
SINCE="${SINCE:-}"
REF_TAG="$(sed -n 's/^reference\.tag *= *\([^ #]*\).*/\1/p' docs/PROVENANCE.md | head -1)"
TERA_TAG="$(sed -n 's/^teranode\.tag *= *\([^ #]*\).*/\1/p' docs/PROVENANCE.md | head -1)"
FAMILIES="block chain finality mempool oracle utxo"
# the corpora the Teranode script runs of #41 read (harness/engines/instance41/runs), and the reference's committed column's
SCRIPT_CORPORA="seed flow arith stack crypto bytes eras gen tx road"
REF_CORPORA="$(python3 -c 'import json; print(" ".join(sorted(json.load(open("corpus/witnesses/sv-node/manifest.json")))))')"
LOG_GROUP="## hz-95-teranode-gate-logs:"
stop() { echo "teranode gate: STOP ($1): $2" >&2; exit "$1"; }
need_since() { [[ "$SINCE" =~ ^[0-9]{8}-[0-9]{6}$ ]] || stop 2 "STEP=$STEP needs SINCE=<YYYYmmdd-HHMMSS>, the stamp \`make teranode-gate\` printed"; }
load_ok() {
  local l
  if [ -r /proc/loadavg ]; then l="$(cut -d' ' -f1 /proc/loadavg)"; else l="$(sysctl -n vm.loadavg | awk '{print $2}')"; fi
  awk -v l="$l" 'BEGIN { exit !(l < 20) }' || stop 3 "1-minute load $l: nothing starts at 20 or above (rule 17)"
}
manifest_of() { if [ -f "corpus/$1/cases-manifest.json" ]; then echo cases-manifest.json; else echo manifest.json; fi; }
# the plan's script-reference lines (the MISSING item of lane fix-hz-95's lens): road and tx refuse at startup, no
# words row for either in corpus/witnesses/sv-node/manifest.json, so their lines say so and their committed column
# stands; the case lives in this function because bash 3.2's heredoc scan closes a $() at the case's paren
plan_script_reference() {
  local c
  for c in $REF_CORPORA; do
    case "$c" in
      road|tx) echo "  make teranode-gate STEP=script-reference SINCE=$S CORPUS=$c   # refuses at startup: no words row for $c in corpus/witnesses/sv-node/manifest.json; its committed column stands" ;;
      *) echo "  make teranode-gate STEP=script-reference SINCE=$S CORPUS=$c" ;;
    esac
  done
}
# the step's raw log, named in tools/export_withheld.txt under its group (inserted once, after the group's last line)
log_open() {
  LOG="docs/records/$SINCE-s8-95-gate-teranode-log-s4b.txt"
  grep -q "^$LOG_GROUP" tools/export_withheld.txt || stop 2 "tools/export_withheld.txt has no group $LOG_GROUP"
  python3 -c '
import sys
log, head, p = sys.argv[1], sys.argv[2], "tools/export_withheld.txt"
lines = open(p, encoding="utf-8").read().split("\n")
if log not in lines:
    i = next(n for n, x in enumerate(lines) if x.startswith(head)) + 1
    while i < len(lines) and lines[i].strip() and not lines[i].startswith("## "):
        i += 1
    lines.insert(i, log)
    open(p, "w", encoding="utf-8").write("\n".join(lines))
' "$LOG" "$LOG_GROUP"
  printf '\n== %s STEP=%s %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$STEP" "$*" >> "$LOG"
}
# a step's command with its raw output appended to the log; the terminal gets its exit code and the log's name
logged() {
  local rc=0
  "$@" >> "$LOG" 2>&1 || rc=$?
  echo "teranode gate: STEP=$STEP rc $rc; its raw log appended to $LOG (withheld: tools/export_withheld.txt, $LOG_GROUP)"
  return "$rc"
}

case "$STEP" in
  plan)
    S="$(date -u +%Y%m%d-%H%M%S)"
    cat <<EOF
teranode gate: the plan for Teranode $TERA_TAG against bitcoin-sv $REF_TAG (docs/PROVENANCE.md section 1a); this printed
nothing but the plan and started nothing. This run's stamp: SINCE=$S. Run each line in the foreground, in order
(before them the build steps and the host file: harness/README.md, the gate's runbook, "Before the steps"):
$(python3 tools/teranode_gate.py --chunks | sed -e 's/^# /  # the scenario column: /' -e "s/^ORACLE_ROWS=\([^ ]*\)  # \(.*\)/  make teranode-gate STEP=scenario-teranode SINCE=$S ORACLE_ROWS='\1'   # \2/")
$(for f in $FAMILIES; do echo "  make teranode-gate STEP=scenario-reference SINCE=$S FAMILY=$f"; done)
  # the script column, Teranode, per corpus chunk (FROM and COUNT over the corpus's lines; each corpus with its manifest):
$(for c in $SCRIPT_CORPORA; do echo "  make teranode-gate STEP=script-teranode SINCE=$S CORPUS=$c MANIFEST=$(manifest_of "$c") FROM=<n> COUNT=<n>"; done)
  # the script column, the reference, per corpus (the 20261017-234627 run re-measured 18 corpora, every one REPRODUCED:
  # cpp-opcode's 144,324 entries in 36 s and cpp-script's 67,991 in 15 s, both under the 600 s a call may take; \`road\` and
  # \`tx\` refuse at startup, no words row for them in the committed words table):
$(plan_script_reference)
  make teranode-gate STEP=report SINCE=$S
The page: docs/records/$S-s8-95-gate-report-s3.md (public: codes, classes, row ids, hashes, counts); the steps' raw log:
docs/records/$S-s8-95-gate-teranode-log-s4b.txt (withheld: tools/export_withheld.txt, group hz-95-teranode-gate-logs).
The shape without a node: make teranode-gate DRY_RUN=1 OUT_DIR=<dir>
EOF
    ;;
  scenario-teranode)
    need_since; load_ok
    [ -n "${ORACLE_ROWS:-}" ] || stop 2 "STEP=scenario-teranode needs ORACLE_ROWS, one chunk line of the plan"
    run="gate95-$SINCE-$(date -u +%H%M%S)"
    rec="docs/records/$(date -u +%Y%m%d-%H%M%S)-s6-66-cut2-second-oracle-s3.md"
    log_open "ORACLE_ROWS=$ORACLE_ROWS"
    export ORACLE_ROWS
    ORACLE_QUARANTINE="${ORACLE_QUARANTINE:-$HOME/bsv/targets/spec-oracle-quarantine/teranode-$run}" \
      logged zsh -f harness/engines/teranode/column.zsh "$rec" "$run"
    ;;
  scenario-reference)
    need_since; load_ok
    [[ " $FAMILIES " == *" ${FAMILY:-} "* ]] || stop 2 "STEP=scenario-reference needs FAMILY, one of: $FAMILIES"
    [ -x harness/target/release/run_scenarios ] || stop 2 "harness/target/release/run_scenarios is not built (harness/README.md, the gate's runbook, \"Before the steps\")"
    [ -f tools/host_private.sh ] || stop 2 "tools/host_private.sh (the owner's host file, naming BOX_LEG_LOCK_SH and LEAN_LOCK_SH) is absent"
    rec="docs/records/$(date -u +%Y%m%d-%H%M%S)-s6-66-gate95-$FAMILY-regtest-s3.md"
    log_open "FAMILY=$FAMILY"
    # the box leg lock and a Lean slot, as harness/engines/teranode/column.zsh:67-79 takes them (the helper is zsh only);
    # the EXIT trap releases both; the load gate again under the lock
    # shellcheck disable=SC2016
    logged zsh -f -c '
      . tools/host_private.sh
      export BOX_LEG_POLL=5
      source "$BOX_LEG_LOCK_SH" || exit 2
      source "$LEAN_LOCK_SH" || exit 2
      setopt POSIX_TRAPS
      trap "exit 130" INT; trap "exit 143" TERM; trap "exit 129" HUP
      trap "box_leg_release; lean_lock_release" EXIT
      box_leg_take gate95 box "make teranode-gate STEP=scenario-reference FAMILY=$1" "issue 95: the scenario column of the reference" || exit 3
      lean_lock_take gate95 || exit 3
      load=$(sysctl -n vm.loadavg | awk "{print \$2}")
      (( ${load%.*} < 20 )) || { print -r -- "STOP: 1-minute load $load under the lock"; exit 2; }
      harness/target/release/run_scenarios --record "$2" --family "$1" --run-id "$3"
    ' gate95 "$FAMILY" "$rec" "gate95-$SINCE-$FAMILY"
    ;;
  script-teranode)
    need_since; load_ok
    [ -n "${CORPUS:-}" ] && [ -n "${FROM:-}" ] && [ -n "${COUNT:-}" ] || stop 2 "STEP=script-teranode needs CORPUS, FROM and COUNT"
    c="$(basename "$CORPUS")"
    out="harness/engines/instance41/runs/$SINCE-gate/$c"
    MANIFEST="${MANIFEST:-$(manifest_of "$c")}"
    [ -f "corpus/$c/$MANIFEST" ] || stop 2 "corpus/$c/$MANIFEST is absent"
    log_open "CORPUS=$c MANIFEST=$MANIFEST FROM=$FROM COUNT=$COUNT"
    export MANIFEST
    CORPUS="corpus/$c" logged zsh -f harness/engines/instance41/seed_chunk.zsh "$FROM" "$COUNT" "$out"
    ;;
  script-reference)
    need_since; load_ok
    log_open "CORPUS=${CORPUS:-every corpus}"
    CORPUS="${CORPUS:-}" logged tools/column.sh sv-node "$REF_TAG"
    ;;
  report)
    need_since
    python3 tools/teranode_gate.py --live --since "$SINCE" --stamp "$SINCE"
    ;;
  *)
    stop 2 "STEP=$STEP: one of plan, scenario-teranode, scenario-reference, script-teranode, script-reference, report"
    ;;
esac
