#!/usr/bin/env bash
# tools/fuzz_campaign.sh: the standing fuzz campaign on the box (S3, lane fuzz-campaign, 2026-10-15; the owner's word on
# card N1 road (a), "fuzz go"; tuple property 2, fidelity). The bench leg's fuzz smoke (tools/bench_leg.sh, #137) checks
# bsv-rs and the generator on 50,000 fresh seed_gen cases inside the tripwire; this loop runs the SPEC against the
# PINNED NODE on fresh cases, batch after batch, whenever the box is idle, with no model in it.
# OFF since 2026-10-16 16:5xZ by the owner's word (#141): kept as history, not run.
#
# ONE BATCH. Batch n (the counter file) has the seed S = 0x<the leading 16 hex digits of sha256("spec-fuzz-campaign batch n")>
# and FUZZ_BATCH fresh cases (50000, the bench smoke's count), so every batch's smoke and fresh parts are reproduced from
# its batch line alone (`seeds=`); its replay part is the rows of $FUZZ_REPLAY as they stood, and the line carries
# `replay_sha256=<sha256 of the replay part's lines>`
# (lane fuzz-cut2, 2026-10-15: items 1 and 5 of the bsv-fuzz house read, docs/records/20261015-134833-fuzz-house-read-s3.md):
#   1. the corpus, in three parts (tools/fuzz_compose.py): the SMOKE, the leading FUZZ_SMOKE (1000) cases of the bench leg's
#      fuzz smoke at the campaign tree's commit (seed_gen under 0x<the commit's leading 16 hex digits>, tools/bench_leg.sh),
#      so the tripwire's smoke and every batch share cases; the REPLAY, every past witness row of $FUZZ_REPLAY (the
#      campaign's corpus/fuzz, read only), one case per distinct spend; the FRESH cases, one seed_gen stream per family
#      (`--family F`: arith 55, nonmin 10, size 8, depth 6, num2bin 6, mutation 15 of each hundred, seed_gen's own mix)
#      under the family's salted seed S xor 0x<the leading 16 hex digits of sha256("spec-fuzz-campaign family F")>, so a
#      family's cases never move when another family is added or re-weighted; every seed on the batch line
#   2. eval/bsvs corpus                       (the spec's verdicts, both columns, the stamp spec@<commit>), in CHUNKS
#                                              (lane fuzz-cut3, 2026-10-16): the corpus cut by `split -l FUZZ_CHUNK`
#                                              (10000), one bsvs process per chunk in order, the outputs concatenated
#                                              in order into the one spec.jsonl the later stages read (bsvs keeps a
#                                              whole file's output lines until it writes them, lean/Bsvs/Main.lean
#                                              `corpusCmd`: a chunk bounds that); a chunk's non-zero exit fails the
#                                              batch as the whole call's did (exit 3 still the stale binary); the batch
#                                              line names `chunks=<n>`. [M] The chunks do NOT lower the stage's peak:
#                                              one 51,000-spend corpus peaked at 30.4 GB resident whole and chunked
#                                              alike, from two single mutation entries with OP_NUM2BIN (each some 30 GB
#                                              alone; docs/records/20261016-135453-fuzz-cut3-s3.md, the finding)
#      THE WATCHDOG (lane fix2-fuzz-cut3, 2026-10-16; #141's belt while #143, the elements' representation, is open; #142:
#      a legal post-Genesis spend with a 2 GB OP_NUM2BIN element costs the evaluator some 30 GB resident [M]). Every bsvs
#      process of the stage is the script's child, its resident memory read every FUZZ_SPEC_POLL (0.1) s by `ps -o rss=`;
#      past FUZZ_SPEC_RSS_MB (6144 MiB: ps's rss, KiB, over 1024) it gets TERM, then KILL after 5 s, logged `watchdog: killed bsvs at <MiB> ...`, and its
#      piece is BISECTED: split into FUZZ_BISECT (8) pieces (`watchdog: bisect ...`), each run under the same watchdog,
#      and so on down to the single entries that cost it. A single entry whose process is killed gets NO spec line: its
#      id goes to <batch>/resource.txt and its corpus line as composed is appended to $FUZZ_STATE/resource/<date>.jsonl
#      (THE RESOURCE SET, outside the repository, never printed); run_svnode and run_engine count it `without a spec
#      verdict`, so the batch line's `no_spec` holds it, never an agreement and never a divergence (tools/fuzz_batch.py's
#      header: `resource` is the campaign's own gap, not the spec's verdict). The batch line gains `resource=<n>` (fresh
#      such entries) and `resource_ms=<the wall of the killed runs and the bisect pieces>`. [D] 6144: a sixth of the
#      box's 36 GB, so the evaluator, the two nodes and a lane's build fit beside it. [D] 0.1 s, not 1 s: [M] entry 3551
#      of #142 alone stood at 3.8 GB resident 0.5 s in and 7.9 GB at 1.0 s (some 7.5 GB a second), so a 1 s read would
#      let it reach some 13 GB; at 0.1 s the kills of the belt's proof read 6,327 to 6,699 MiB, the process gone
#      some 0.1 s after TERM.
#      [D] The shape, eighths down to singles: [M] a 1-entry corpus costs bsvs 0.06 to 0.07 s wall (46 MB) through
#      eval/bsvs and a 1,250-entry light one 0.15 to 0.16 s (69 MB), some 0.07 s a process and 70 us a light entry, and a
#      costly entry is killed some 1 s after its start ([M] resource_ms=1001 for the one kill of the proof's second
#      batch); a 10,000 chunk with one costly entry costs [EST] some six kills (10,000, 1,250, 157, 20, 3, 1) and some
#      forty starts, near 9 s (at some 1 s a kill; [M] one kill cost 1,001 ms in the belt's batch 2 and 4,615 ms in lane fix3's proof)
#      ([M] resource_ms=8187 for the proof's five kills on 2,001), against 14 kills by halving
#      (near 17 s) and 1,250 single processes (some 200 s with the polling) by eighths then singles (docs/records/20261016-135453-fuzz-cut3-s3.md, item 8).
#      THE RESOURCE REPLAY: every batch replays the resource set's entries (tools/fuzz_compose.py: after the witness
#      replay, before the fresh part, one case per spend) under the watchdog, one process each, before the chunks; the
#      batch line gains `resource_replay=rows:<n>,cleared:<n>,still:<n>`, counted apart from `replay=`; an entry that now
#      runs through is REMOVED from the set and logged `resource cleared: <id> at spec@<commit>` (#143's landing proves
#      itself on the very entries that hurt), and the node and the SDKs judge it as any case
#   3. harness run_svnode --dump --cells      (the cells file feeds the signature, tools/fuzz_batch.py; verifyscript per spend on the campaign's two nodes, the spec's own words;
#                                              the `spec` column on the consensus instance, `spec-mempool` on the policy one)
#   4. harness run_engine --dump, per SDK of FUZZ_ENGINES (go-sdk ts-sdk), the runners as they stand (harness/README.md):
#      its outputs in its own layout under the batch's directory (engines/<engine>/corpus.jsonl and manifest.json); an
#      engine whose runner, adapter or node 22 is absent is SKIPPED BY NAME on the batch line, never a pass
# Every divergent cell of the node's dump whose spend and column hold no row yet becomes a WITNESS ROW in $FUZZ_TREE/corpus/fuzz/<date>.jsonl in the harness's
# witness shape (a corpus Entry at the top level, as run_svnode writes them: the whole spend, both keys' verdicts in
# `expect`, a `divergence` object with the class the classifier harness/rules/sv-node.json filed it under, ruling
# `open`; the campaign's fields under `fuzz`); a batch that writes a node row also keeps run_svnode's own per-class
# witnesses (<witnesses>/sv-node/corpus.jsonl) as $FUZZ_TREE/corpus/fuzz/<date>-batch-<n>-sv-node.jsonl (and a batch that
# writes an SDK row run_engine's as <date>-batch-<n>-<engine>.jsonl); a batch that writes any row writes one RECORD LINE in
# $FUZZ_TREE/docs/records/<yyyymmdd>-fuzz-campaign-divergences.jsonl. The started line and every record line name the
# sha256 of the executables present (bitcoind, seed_gen, run_svnode, bsvs, run_engine, the go-sdk runner); the batch line
# itself carries none. Nothing the node replies is ever printed by the loop. A witness
# is never judged here (CLAUDE.md rule 4: it is a Finding for the captain). The loop commits nothing: $FUZZ_TREE is the dedicated worktree (branch
# lane/fuzz-witnesses), and tools/fuzz_daily.sh indexes the day's files there (rule 12) for the captain's lanes to land.
# The SDK column's divergences are witness rows of the same shape in $FUZZ_TREE/corpus/fuzz/<date>-<engine>.jsonl, one
# per new class (every new spend of an `unexplained` one); a spend and column that already hold a row (a smoke or
# replayed case) are counted, never written again; tools/fuzz_batch.py says how (its header).
# Each batch's counts are one line of $FUZZ_STATE/log/<date>.log, outside the repository.
#
# THE NODE. Two fresh regtest instances of the pinned build (harness/oracle/README.md: the same binary, the same two
# confs as the oracle's consensus and policy instances), each on an empty datadir under $FUZZ_STATE and ports of its
# own in 18601 to 18620 (18601/18602 and 18603/18604 by default; the standing instances on 18563, 18565, 18567, the
# mini, the scenario runner's band 18571 to 18590 (harness/src/scenarios/core.rs, tools/rpc_probe.py) and
# cpp_era_run's 18583 to 18586 are never touched, and a port outside 18601..18620 is refused). Started by the loop, health-checked before every
# batch and restarted on a crash (on a fresh datadir: verifyscript reads no chain), stopped when STOP appears; their
# stdout and stderr go to $FUZZ_STATE/log/node-<instance>.{out,err}, never to a terminal.
#
# THE LOAD. Before every batch the loop waits for a 1-minute load under FUZZ_LOAD_MAX (12: lower than the lanes' 20 of
# CLAUDE.md rule 17, so the campaign yields to every lane), and for $FUZZ_STATE/STOP, which ends it. Beside it (lane
# fuzz-cut3, 2026-10-16) THE MEMORY GATE: it waits while the box's unused memory is under FUZZ_MEM_MIN_GB (8 GB), read as
# vm_stat's "Pages free" plus "Pages speculative" times vm_stat's page size (the pages top's PhysMem line calls
# "unused"; MemAvailable on Linux), logged once per wait as `waiting: unused memory ...`; and THE PAUSE FILE: while
# $FUZZ_STATE/PAUSE exists (the captain's hand during a fan-out on the box) it runs no batch and keeps its nodes, logged
# once as `paused` when the file appears and once as `resumed` when it goes.
#
# THE SATURATION STOPPING RULE (lane fuzz-cut3, 2026-10-16; the owner's question, "how long until we dont find something
# until we shut it off"). tools/fuzz_batch.py gives every node cell a SIGNATURE (its header: the family, the column, the
# spec's verdict and halt reason word, the node's verdict and reject reason as the classifier names it, the sorted set
# of distinct opcodes in the spend's scripts) and keeps $FUZZ_STATE/signatures.tsv; the batch line names `new_sigs=` and
# `sigs_total=`. The loop stops ITSELF when new_sigs=0 for FUZZ_SAT_BATCHES (20) consecutive batches at one TUPLE (the
# campaign tree's commit, the families line with the batch and smoke counts, the sha256 of the replay rows as they stand
# (the files of $FUZZ_REPLAY in order, the input the batch line's replay_sha256 is computed from; readable between
# batches without composing one), the sha256 of the resource set's files in order (lane fix2-fuzz-cut3: a cleared or a
# new resource entry moves it), the binaries' sha256 line): it writes $FUZZ_STATE/SATURATED holding the tuple and
# logs `saturated: <tuple> after batch <n>`; the streak is kept in $FUZZ_STATE/sat.streak across a restart. While
# SATURATED names the current tuple the loop runs no batch and sleeps FUZZ_IDLE_SLEEP between checks (its nodes stay
# up); the moment the tuple differs (the tree re-pointed and rebuilt, a new witness row in the replay, a pin moved, a
# family added) it logs `woken: <what moved>`, removes SATURATED and runs again. [D] 20: a million fresh spends (20 of
# 50,000) without one new signature, about an hour at the campaign's pace of 2026-10-15/16 [M] (554 batches in 23.7
# hours, a batch's median wall 23 s, the rest load waits and the evaluator's spikes); fewer would stop on a run of the
# mix's commonest cells, more re-proves the same classes for hours. THE BELT: FUZZ_DAY_MAX (200) completed batches per
# UTC day, after which the loop idles until the next day (logged once as `day cap`); [D] 200 is 10 million fresh spends a
# day, some 36 % of that pace's 560, so a tuple that never saturates still leaves the box to the lanes most of the day.
# `--once` runs one batch regardless of both (the dry run).
#
# THE DAILY RESTART (lane fuzz-cut3). Between batches an instance whose uptime passed 24 hours or whose resident memory
# passed FUZZ_NODE_RSS_MB (4096) is stopped and started again on a fresh datadir, logged as `node restarted (<instance>,
# <reason>)`; the health check already restarts a crashed one. [D] 4096: the consensus instance stood at 2.1 GB after
# 20 hours on 2026-10-16 [M], so the cap leaves it twice that before the uptime rule would anyway. It never builds:
# no `make axioms`, no StaleRunCheck, no Lean build, no cargo (the binaries are $FUZZ_TREE's own, built once by hand;
# a stale evaluator binary is refused by eval/bsvs with exit 3, and the loop logs it and waits FUZZ_FAIL_SLEEP).
#
# Usage: nohup tools/fuzz_campaign.sh >/dev/null 2>&1 &     (the standing loop; stop it with: touch $FUZZ_STATE/STOP)
#        tools/fuzz_campaign.sh --once                       (one batch end to end, then the nodes stopped: the dry run)
# Environment: FUZZ_STATE · FUZZ_TREE · FUZZ_BATCH (50000); FUZZ_STATE, FUZZ_TREE and BSV_SV_BIN_DIR (when SV_BIN or SV_CLI is unset)
#              from the environment or tools/host_private.sh: a maintainers' route, without them it stops (#177)
#              FUZZ_LOAD_MAX (12) · FUZZ_PORT (18601: four ports from it) · FUZZ_IDLE_SLEEP (60 s) · FUZZ_FAIL_SLEEP (1800 s)
#              SV_BIN, SV_CLI (the pinned build, $BSV_SV_BIN_DIR/bitcoind and bitcoin-cli) · FUZZ_SMOKE (1000) · FUZZ_ENGINES (go-sdk ts-sdk)
#              FUZZ_REPLAY ($FUZZ_TREE/corpus/fuzz) · GOSDK_RUNNER, NODE_BIN (as run_engine reads them)
#              FZ_ROW_CAP (20: unexplained SDK rows per engine, column and batch; tools/fuzz_batch.py)
#              FUZZ_CHUNK (10000: spends per bsvs process in the spec stage) · FUZZ_MEM_MIN_GB (8: the memory gate)
#              FUZZ_SAT_BATCHES (20) · FUZZ_DAY_MAX (200) · FUZZ_NODE_RSS_MB (4096)
#              FUZZ_SPEC_RSS_MB (6144: the watchdog's bar per bsvs process) · FUZZ_SPEC_POLL (0.1 s) · FUZZ_BISECT (8)
# A seed_gen stream that fails (a panic, a nondeterminism) is itself a fuzz finding: its gen/<part> and its output are
# kept under $FUZZ_STATE/kept/batch-<n>/ and the FAILED line says so (the batch is retried with the same seeds).
set -uo pipefail
DRIVER="$(cd "$(dirname "$0")/.." && pwd)"
ROOT="$DRIVER"; HOST_ROUTE=fuzz_campaign
host_var() {  # NAME: from the environment, else tools/host_private.sh (#177), else one line and exit 2
  local v="$1"
  if [ -z "${!v:-}" ] && [ -f "$ROOT/tools/host_private.sh" ]; then
    printf -v "$v" %s "$(bash -c '. "$1" >/dev/null 2>&1; printf %s "${!2:-}"' _ "$ROOT/tools/host_private.sh" "$v")"
  fi
  [ -n "${!v:-}" ] || [ "${2:-}" = optional ] || { echo "$HOST_ROUTE: a maintainers' route; it needs tools/host_private.sh or $v (tools/README.md)"; exit 2; }
}
host_var FUZZ_STATE
host_var FUZZ_TREE
[ -n "${SV_BIN:-}" ] && [ -n "${SV_CLI:-}" ] || host_var BSV_SV_BIN_DIR
: "${FUZZ_BATCH:=50000}"
: "${FUZZ_LOAD_MAX:=12}"
: "${FUZZ_PORT:=18601}"
: "${FUZZ_IDLE_SLEEP:=60}"
: "${FUZZ_FAIL_SLEEP:=1800}"
: "${SV_BIN:=$BSV_SV_BIN_DIR/bitcoind}"
: "${SV_CLI:=$BSV_SV_BIN_DIR/bitcoin-cli}"
: "${FUZZ_SMOKE:=1000}"
: "${FUZZ_ENGINES:=go-sdk ts-sdk}"
: "${FUZZ_REPLAY:=$FUZZ_TREE/corpus/fuzz}"
: "${FUZZ_CHUNK:=10000}"
: "${FUZZ_MEM_MIN_GB:=8}"
: "${FUZZ_SAT_BATCHES:=20}"
: "${FUZZ_DAY_MAX:=200}"
: "${FUZZ_NODE_RSS_MB:=4096}"
: "${FUZZ_SPEC_RSS_MB:=6144}"
: "${FUZZ_SPEC_POLL:=0.1}"
: "${FUZZ_BISECT:=8}"
# seed_gen's mix (harness/src/bin/seed_gen.rs `draw`), per hundred of the fresh cases
FAMILIES="arith:55 nonmin:10 size:8 depth:6 num2bin:6 mutation:15"
once=no
[ "${1:-}" = --once ] && once=yes
LOGDIR="$FUZZ_STATE/log"
STOP="$FUZZ_STATE/STOP"
mkdir -p "$LOGDIR" "$FUZZ_STATE/work" "$FUZZ_STATE/resource"
day() { date -u +%Y-%m-%d; }
utc() { date -u +%Y-%m-%dT%H:%M:%SZ; }
say() { echo "$(utc) $*" >> "$LOGDIR/$(day).log"; [ "$once" = yes ] && echo "fuzz: $*"; return 0; }

# the four ports: inside 18601..18620, never a standing instance's, the runner's or cpp_era_run's
for p in "$FUZZ_PORT" $((FUZZ_PORT + 3)); do
  if [ "$p" -lt 18601 ] || [ "$p" -gt 18620 ]; then
    echo "fuzz_campaign: FUZZ_PORT=$FUZZ_PORT puts a port outside 18601..18620 (the standing instances 18563 to 18568, the runner's band 18571 to 18590 and cpp_era_run's 18583 to 18586 are never used); refused" >&2
    exit 2
  fi
done
for f in "$SV_BIN" "$SV_CLI" "$FUZZ_TREE/eval/bsvs" "$FUZZ_TREE/harness/target/release/seed_gen" "$FUZZ_TREE/harness/target/release/run_svnode"; do
  [ -x "$f" ] || { echo "fuzz_campaign: $f is not an executable; build the harness in $FUZZ_TREE once by hand (CARGO_BUILD_JOBS=4 cargo build --release --locked --bin seed_gen --bin run_svnode, CARGO_TARGET_DIR unset) and clone a built lean/.lake there" >&2; exit 2; }
done
if [ -e "$FUZZ_STATE/loop.pid" ] && kill -0 "$(cat "$FUZZ_STATE/loop.pid")" 2>/dev/null; then
  echo "fuzz_campaign: a loop already runs (pid $(cat "$FUZZ_STATE/loop.pid")); refused" >&2
  exit 2
fi
echo $$ > "$FUZZ_STATE/loop.pid"
GOSDK_BIN="${GOSDK_RUNNER:-$FUZZ_TREE/harness/target/engines/gosdk-runner}"
bins_now() { for f in "$SV_BIN" "$FUZZ_TREE/harness/target/release/seed_gen" "$FUZZ_TREE/harness/target/release/run_svnode" "$FUZZ_TREE/lean/.lake/build/bin/bsvs" "$FUZZ_TREE/harness/target/release/run_engine" "$GOSDK_BIN"; do [ -e "$f" ] && printf '%s=%s ' "$(basename "$f")" "$(shasum -a 256 "$f" | cut -c1-64)"; done; }
BINS="$(bins_now)"
# THE TUPLE the saturation rule is kept at (the header): the tree's commit, the families line, the replay rows' sha256,
# the resource set's sha256, the binaries' sha256 line; one line of space-free key=value fields
tuple_now() {
  printf 'tree=%s families=%s,count:%s,smoke:%s replay=%s resource=%s bins=%s\n' "$(git -C "$FUZZ_TREE" rev-parse --short=8 HEAD)" \
    "$(echo $FAMILIES | tr ' ' ,)" "$FUZZ_BATCH" "$FUZZ_SMOKE" \
    "$(cat "$FUZZ_REPLAY"/*.jsonl 2>/dev/null | shasum -a 256 | cut -c1-64)" \
    "$(cat "$FUZZ_STATE"/resource/*.jsonl 2>/dev/null | shasum -a 256 | cut -c1-64)" "$(bins_now | sed 's/ $//; s/ /,/g')"
}
tuple_field() { printf ' %s' "$1" | tr ' ' '\n' | sed -n "s/^$2=//p"; }
tuple_moved() {
  local k w=""
  for k in tree families replay resource bins; do
    [ "$(tuple_field "$1" "$k")" = "$(tuple_field "$2" "$k")" ] || w="$w${w:+, }$k $(tuple_field "$1" "$k" | cut -c1-24) -> $(tuple_field "$2" "$k" | cut -c1-24)"
  done
  echo "${w:-nothing}"
}

# an SDK engine's readiness: prints nothing when run_engine can run it, else the reason it is SKIPPED BY NAME
engine_absent() {
  [ -x "$FUZZ_TREE/harness/target/release/run_engine" ] || { echo "run_engine is not built in the campaign tree"; return; }
  case "$1" in
    go-sdk) [ -x "$GOSDK_BIN" ] || echo "no go-sdk runner (make gosdk-build in the campaign tree)" ;;
    ts-sdk)
      [ -d "$FUZZ_TREE/harness/engines/ts/node_modules/@bsv/sdk" ] || { echo "no ts-sdk adapter install (make tssdk-install in the campaign tree)"; return; }
      local nb; nb="${NODE_BIN:-$("$FUZZ_TREE/tools/node_bin.sh" 2>/dev/null)}"
      case "$("$nb" --version 2>/dev/null)" in v22.*) ;; *) echo "no node 22 (tools/node_bin.sh, NODE_BIN)" ;; esac ;;
    *) echo "an engine the campaign does not run" ;;
  esac
}
engines_state() {
  local g w
  for g in $FUZZ_ENGINES; do
    w="$(engine_absent "$g")"
    if [ -z "$w" ]; then printf '%s ready; ' "$g"; else printf '%s SKIPPED BY NAME (%s); ' "$g" "$w"; fi
  done
}
# the family F's salted seed under the batch seed S
salted() { printf '0x%016x' $(( $2 ^ 0x$(printf 'spec-fuzz-campaign family %s' "$1" | shasum -a 256 | cut -c1-16) )); }

# instance name, conf, rpc port, p2p port
inst_conf() { [ "$1" = consensus ] && echo "$FUZZ_TREE/harness/oracle/bitcoin.conf" || echo "$FUZZ_TREE/harness/oracle/bitcoin-policy.conf"; }
inst_rpc() { [ "$1" = consensus ] && echo "$FUZZ_PORT" || echo $((FUZZ_PORT + 2)); }
inst_dir() { echo "$FUZZ_STATE/node-$1"; }
cli() { "$SV_CLI" -regtest -conf="$(inst_conf "$1")" -datadir="$(inst_dir "$1")" -rpcport="$(inst_rpc "$1")" "${@:2}"; }
up() { cli "$1" getblockcount >/dev/null 2>&1; }
node_start() {
  local i="$1" d; d="$(inst_dir "$1")"
  rm -rf "$d"; mkdir -p "$d"
  nohup "$SV_BIN" -regtest -conf="$(inst_conf "$i")" -datadir="$d" -rpcport="$(inst_rpc "$i")" -port=$(($(inst_rpc "$i") + 1)) \
    >> "$LOGDIR/node-$i.out" 2>> "$LOGDIR/node-$i.err" < /dev/null &
  echo $! > "$FUZZ_STATE/node-$i.pid"
  for _ in $(seq 1 60); do up "$i" && break; sleep 1; done
  if up "$i"; then say "node $i started: pid $(cat "$FUZZ_STATE/node-$i.pid"), rpc 127.0.0.1:$(inst_rpc "$i"), datadir $d"; return 0; fi
  say "node $i did not answer within 60 s (its stderr: $LOGDIR/node-$i.err)"; return 1
}
node_stop() {
  local i="$1" pid
  up "$i" && cli "$i" stop >/dev/null 2>&1
  pid="$(cat "$FUZZ_STATE/node-$i.pid" 2>/dev/null)"
  for _ in $(seq 1 60); do [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null || break; sleep 1; done
  [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null && kill "$pid" 2>/dev/null
  [ -n "$pid" ] && for _ in $(seq 1 10); do kill -0 "$pid" 2>/dev/null || break; sleep 1; done
  rm -f "$FUZZ_STATE/node-$i.pid"
}
nodes_ready() {
  local i
  for i in consensus policy; do
    up "$i" && continue
    [ -e "$FUZZ_STATE/node-$i.pid" ] && say "node $i does not answer: restarting it (crash restart)"
    node_stop "$i"; node_start "$i" || return 1
  done
}
finish() {
  [ -n "${SPEC_PID:-}" ] && kill -KILL "$SPEC_PID" 2>/dev/null
  node_stop consensus; node_stop policy
  rm -f "$FUZZ_STATE/loop.pid"
  say "stopped (${1:-STOP}): the nodes stopped"
}
trap 'finish signal; exit 0' INT TERM
# THE DAILY RESTART: an instance whose uptime passed 24 hours or whose resident memory passed FUZZ_NODE_RSS_MB is
# restarted between batches (on a fresh datadir, as the crash restart)
etime_s() { ps -o etime= -p "$1" | awk '{ t = $1; d = 0; if (index(t, "-")) { split(t, a, "-"); d = a[1]; t = a[2] }
  k = split(t, p, ":"); s = 0; for (i = 1; i <= k; i++) s = s * 60 + p[i]; print d * 86400 + s }'; }
nodes_refresh() {
  local i pid up rss why
  for i in consensus policy; do
    pid="$(cat "$FUZZ_STATE/node-$i.pid" 2>/dev/null)"
    [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null || continue
    up="$(etime_s "$pid")"; rss="$(ps -o rss= -p "$pid" | tr -d ' ')"; why=""
    [ "${up:-0}" -ge 86400 ] && why="uptime $((up / 3600)) h"
    [ $((${rss:-0} / 1024)) -ge "$FUZZ_NODE_RSS_MB" ] && why="${why:+$why, }resident $((rss / 1024)) MB"
    [ -n "$why" ] || continue
    node_stop "$i"
    node_start "$i" && say "node restarted ($i, $why)"
  done
}
load1() { if [ -r /proc/loadavg ]; then cut -d' ' -f1 /proc/loadavg; else sysctl -n vm.loadavg | awk '{print $2}'; fi; }
# the box's unused memory in MiB: vm_stat's free plus speculative pages times its page size (top's PhysMem "unused" is
# the same pages); MemAvailable on a Linux host
mem_free_mb() {
  if [ -r /proc/meminfo ]; then awk '/^MemAvailable:/ { print int($2 / 1024) }' /proc/meminfo; return; fi
  vm_stat | awk '/page size of/ { for (i = 1; i <= NF; i++) if ($i == "of") ps = $(i + 1) }
    /^Pages free:/ { f = $3 } /^Pages speculative:/ { s = $3 } END { gsub(/\./, "", f); gsub(/\./, "", s); print int((f + s) * ps / 1048576) }'
}

# THE WATCHDOG (the header): eval/bsvs corpus on the piece $1 into $2, the script's child, its resident memory read every
# FUZZ_SPEC_POLL seconds; past FUZZ_SPEC_RSS_MB it gets TERM, then KILL after 5 s, and WATCH_KILLED says so
ms_now() { perl -MTime::HiRes=time -e 'printf "%d\n", time * 1000'; }
SPEC_PID=""
spec_watch() { spec_watch_ "$@" 2>/dev/null; }   # the shell's own notice of a killed job, not bsvs's stderr (spec.out)
spec_watch_() {
  local k=0 r
  WATCH_KILLED=no; WATCH_RSS=0; WATCH_HOW=""
  "$FUZZ_TREE/eval/bsvs" corpus "$1" --out "$2" >> "$b/spec.out" 2>&1 &
  SPEC_PID=$!
  while kill -0 "$SPEC_PID" 2>/dev/null; do
    sleep "$FUZZ_SPEC_POLL"
    k="$(ps -o rss= -p "$SPEC_PID" 2>/dev/null | tr -d ' ')"
    [ $((${k:-0} / 1024)) -gt "$FUZZ_SPEC_RSS_MB" ] || continue
    WATCH_KILLED=yes; WATCH_RSS=$((k / 1024)); WATCH_HOW=TERM
    pkill -TERM -P "$SPEC_PID" 2>/dev/null; kill -TERM "$SPEC_PID" 2>/dev/null
    for _ in $(seq 1 50); do kill -0 "$SPEC_PID" 2>/dev/null || break; sleep 0.1; done
    if kill -0 "$SPEC_PID" 2>/dev/null; then
      pkill -KILL -P "$SPEC_PID" 2>/dev/null; kill -KILL "$SPEC_PID" 2>/dev/null; WATCH_HOW="TERM, then KILL after 5 s"
    fi
    break
  done
  wait "$SPEC_PID" 2>/dev/null; r=$?; SPEC_PID=""
  [ "$WATCH_KILLED" = yes ] && return 0
  return "$r"
}
# one piece of the spec stage under the watchdog ($2: resource or fresh; $3: top or sub, a bisect's piece): its spec lines
# appended to spec.jsonl, or, killed, BISECTED into FUZZ_BISECT pieces each run the same way, down to single entries;
# a killed single entry gets no spec line, its id goes to resource.txt and (a fresh one) its corpus line to the resource set
spec_piece() {
  local f="$1" o="$1.spec" ne r t1 p id per
  ne="$(grep -c . "$f")"; t1="$(ms_now)"
  spec_watch "$f" "$o"; r=$?
  if [ "$WATCH_KILLED" = no ]; then
    [ "$r" = 0 ] || return "$r"
    cat "$o" >> "$b/spec.jsonl"; rm -f "$f" "$o"
    [ "$3" = sub ] && RES_MS=$((RES_MS + $(ms_now) - t1))
    return 0
  fi
  RES_MS=$((RES_MS + $(ms_now) - t1)); rm -f "$o"
  say "watchdog: killed bsvs at $WATCH_RSS MiB resident (FUZZ_SPEC_RSS_MB $FUZZ_SPEC_RSS_MB) on piece $(basename "$f") of batch $n ($ne entries): $WATCH_HOW"
  if [ "$ne" -le 1 ]; then
    id="$(python3 -c 'import json, sys; print(json.loads(open(sys.argv[1]).readline())["id"])' "$f")"
    echo "$id" >> "$b/resource.txt"
    if [ "$2" = fresh ]; then
      cat "$f" >> "$FUZZ_STATE/resource/$(day).jsonl"
      say "watchdog: resource $id: no spec line; its entry appended to $FUZZ_STATE/resource/$(day).jsonl"
    else
      say "watchdog: resource $id (the resource set's replay): still killed, no spec line"
    fi
    rm -f "$f"; return 0
  fi
  per=$(( (ne + FUZZ_BISECT - 1) / FUZZ_BISECT ))
  split -a 4 -l "$per" "$f" "$f."; rm -f "$f"
  say "watchdog: bisect piece $(basename "$f") ($ne entries) into pieces of $per"
  for p in "$f".????; do
    spec_piece "$p" "$2" sub || return
  done
}

driver_commit() {
  local c; c="$(git -C "$DRIVER" rev-parse --short=8 HEAD 2>/dev/null || echo unknown)"
  [ -n "$(git -C "$DRIVER" status --porcelain -- tools/fuzz_campaign.sh tools/fuzz_batch.py tools/fuzz_compose.py 2>/dev/null)" ] && c="$c+dirty"
  echo "$c"
}
batch() {
  local n seed b rc t0 t walls tree
  n="$(cat "$FUZZ_STATE/counter" 2>/dev/null || echo 1)"
  seed="0x$(printf 'spec-fuzz-campaign batch %s' "$n" | shasum -a 256 | cut -c1-16)"
  b="$FUZZ_STATE/work/batch-$n"; rm -rf "$b"; mkdir -p "$b"
  t0=$(date +%s)
  tree="$(git -C "$FUZZ_TREE" rev-parse --short=8 HEAD)"
  local segs="" part share k left="$FUZZ_BATCH" smoke
  smoke="0x$(git -C "$FUZZ_TREE" rev-parse HEAD | cut -c1-16)"
  [ "$FUZZ_SMOKE" -gt 0 ] && segs="smoke:$smoke:$FUZZ_SMOKE"
  for part in $FAMILIES; do
    share="${part#*:}"; part="${part%%:*}"
    if [ "$part" = mutation ]; then k="$left"; else k=$((FUZZ_BATCH * share / 100)); left=$((left - k)); fi
    segs="$segs $part:$(salted "$part" "$seed"):$k"
  done
  for part in $segs; do
    IFS=: read -r k s c <<< "$part"
    [ "$c" -gt 0 ] || continue
    if ! (cd "$FUZZ_TREE/harness" && target/release/seed_gen --out "$b/gen/$k" --seed "$s" --count "$c" $([ "$k" = smoke ] || echo --family "$k")) > "$b/gen-$k.out" 2>&1; then
      mkdir -p "$FUZZ_STATE/kept/batch-$n"; rm -rf "$FUZZ_STATE/kept/batch-$n/gen-$k"
      cp -R "$b/gen/$k" "$FUZZ_STATE/kept/batch-$n/gen-$k" 2>/dev/null; cp "$b/gen-$k.out" "$FUZZ_STATE/kept/batch-$n/"
      say "batch=$n seed=$seed FAILED stage=seed_gen part=$k ($(tail -1 "$b/gen-$k.out")); a fuzz finding: gen/$k and its output kept in $FUZZ_STATE/kept/batch-$n"; return 1
    fi
  done
  mkdir -p "$b/corpus"
  if ! FZ_B="$b" FZ_SEGMENTS="${segs# }" FZ_REPLAY="$FUZZ_REPLAY" FZ_RESOURCE="$FUZZ_STATE/resource" python3 "$DRIVER/tools/fuzz_compose.py" > "$b/compose.out" 2>&1; then
    say "batch=$n seed=$seed FAILED stage=compose ($(tail -1 "$b/compose.out")); kept in $b"; return 1
  fi
  walls="gen:$(($(date +%s) - t0))"; t=$(date +%s)
  # the spec stage in chunks of FUZZ_CHUNK lines, one bsvs process each in order (bsvs holds a whole file's output lines)
  # under THE WATCHDOG (the header): the resource set's entries, one process each, then the rest in chunks
  local ch nch=0 failed_piece=; rm -rf "$b/chunks"; mkdir -p "$b/chunks"; : > "$b/spec.jsonl"; : > "$b/spec.out"; : > "$b/resource.txt"; rc=0
  RES_MS=0
  split -a 4 -l 1 "$b/corpus/resource.jsonl" "$b/chunks/r."
  for ch in "$b"/chunks/r.????; do
    [ -e "$ch" ] || continue
    spec_piece "$ch" resource top; rc=$?
    [ "$rc" = 0 ] || { failed_piece="$(basename "$ch")"; break; }
  done
  if [ "$rc" = 0 ]; then
    split -a 4 -l "$FUZZ_CHUNK" "$b/corpus/light.jsonl" "$b/chunks/c."
    for ch in "$b"/chunks/c.????; do
      [ -e "$ch" ] || continue
      nch=$((nch + 1))
      spec_piece "$ch" fresh top; rc=$?
      [ "$rc" = 0 ] || break
    done
  fi
  walls="$walls,spec:$(($(date +%s) - t))"; t=$(date +%s)
  if [ "$rc" != 0 ]; then
    say "batch=$n seed=$seed FAILED stage=eval/bsvs chunk=$nch${failed_piece:+ piece=$failed_piece} exit=$rc ($(tail -1 "$b/spec.out")); kept in $b"; return 1
  fi
  (cd "$FUZZ_TREE/harness" && BSV_SCRIPT_LEAN_ROOT="$FUZZ_TREE" target/release/run_svnode --corpus "$b/corpus/seed.jsonl" --spec "$b/spec.jsonl" \
    --rpc "http://127.0.0.1:$(inst_rpc consensus)" --cookie "$(inst_dir consensus)/regtest/.cookie" \
    --rpc-mempool "http://127.0.0.1:$(inst_rpc policy)" --cookie-mempool "$(inst_dir policy)/regtest/.cookie" \
    --witnesses "$b/w" --dump "$b/dump.jsonl" --cells "$b/cells.jsonl") > "$b/svnode.out" 2>&1; rc=$?
  if [ ! -e "$b/dump.jsonl" ]; then
    say "batch=$n seed=$seed FAILED stage=run_svnode exit=$rc (its output: $b/svnode.out, not quoted: it can carry the node's reply); kept in $b"; return 1
  fi
  walls="$walls,sv-node:$(($(date +%s) - t))"
  local eng why
  for eng in $FUZZ_ENGINES; do
    why="$(engine_absent "$eng")"
    t=$(date +%s)
    if [ -n "$why" ]; then echo "$why" > "$b/engine-$eng.skip"; continue; fi
    (cd "$FUZZ_TREE/harness" && BSV_SCRIPT_LEAN_ROOT="$FUZZ_TREE" GOSDK_RUNNER="$GOSDK_BIN" target/release/run_engine --engine "$eng" \
      --corpus "$b/corpus/seed.jsonl" --spec "$b/spec.jsonl" --witnesses "$b/engines" --dump "$b/engine-$eng.dump.jsonl") \
      > "$b/engine-$eng.out" 2>&1
    echo $? > "$b/engine-$eng.rc"
    walls="$walls,$eng:$(($(date +%s) - t))"; t=$(date +%s)
  done
  local line
  line="$(FZ_N="$n" FZ_CHUNKS="$nch" FZ_RESOURCE_MS="$RES_MS" FZ_SEED="$seed" FZ_COUNT="$FUZZ_BATCH" FZ_B="$b" FZ_TREE="$FUZZ_TREE" FZ_TREE_COMMIT="$tree" \
    FZ_DRIVER="$(driver_commit)" FZ_RC="$rc" FZ_WALL=$(($(date +%s) - t0)) FZ_WALLS="$walls" \
    FZ_DAY="$(day)" FZ_LOAD="$(load1)" FZ_BINS="$BINS" FZ_ENGINES="$FUZZ_ENGINES" FZ_STATE="$FUZZ_STATE" python3 "$DRIVER/tools/fuzz_batch.py"
)" || { say "batch=$n seed=$seed FAILED stage=parse; kept in $b"; return 1; }
  while read -r k; do [ -n "$k" ] && say "resource cleared: $k"; done < "$b/resource-cleared.txt"
  say "$line"
  echo $((n + 1)) > "$FUZZ_STATE/counter"
  rm -rf "$b"
  # the saturation streak: consecutive batches with new_sigs=0 at one tuple ($FUZZ_STATE/sat.streak: "<n> <tuple>")
  local ns streak old
  ns="$(printf '%s' "$line" | sed -n 's/.* new_sigs=\([0-9]*\) .*/\1/p')"
  old="$(cut -d' ' -f2- "$FUZZ_STATE/sat.streak" 2>/dev/null)"; streak="$(cut -d' ' -f1 "$FUZZ_STATE/sat.streak" 2>/dev/null)"
  if [ "$ns" = 0 ]; then
    [ "$old" = "$TUPLE" ] && streak=$((${streak:-0} + 1)) || streak=1
  else
    streak=0
  fi
  echo "$streak $TUPLE" > "$FUZZ_STATE/sat.streak"
  if [ "$streak" -ge "$FUZZ_SAT_BATCHES" ]; then
    echo "$TUPLE" > "$FUZZ_STATE/SATURATED"
    say "saturated: $TUPLE after batch $n ($streak batches in a row with new_sigs=0)"
  fi
  return 0
}

say "started: driver $DRIVER, tree $FUZZ_TREE at $(git -C "$FUZZ_TREE" rev-parse --short=8 HEAD), batch $FUZZ_BATCH, smoke $FUZZ_SMOKE, replay $FUZZ_REPLAY, load bar $FUZZ_LOAD_MAX, ports $FUZZ_PORT..$((FUZZ_PORT + 3)), next batch $(cat "$FUZZ_STATE/counter" 2>/dev/null || echo 1), engines: $(engines_state | sed 's/; $//'), binaries ${BINS% }"
fails=0; paused=no; satidle=no; memwait=no; capday=""
TUPLE="$(tuple_now)"
while [ ! -e "$STOP" ]; do
  if [ -e "$FUZZ_STATE/PAUSE" ]; then
    [ "$paused" = yes ] || { say "paused ($FUZZ_STATE/PAUSE exists)"; paused=yes; }
    sleep "$FUZZ_IDLE_SLEEP"; continue
  fi
  [ "$paused" = yes ] && { say "resumed ($FUZZ_STATE/PAUSE removed)"; paused=no; }
  mf="$(mem_free_mb)"
  case "$mf" in ''|*[!0-9]*) say "waiting: the unused memory could not be read ($mf)"; sleep "$FUZZ_IDLE_SLEEP"; continue;; esac
  if [ "$mf" -lt $((FUZZ_MEM_MIN_GB * 1024)) ]; then
    [ "$memwait" = yes ] || { say "waiting: unused memory $mf MiB is under $FUZZ_MEM_MIN_GB GB"; memwait=yes; }
    sleep "$FUZZ_IDLE_SLEEP"; continue
  fi
  memwait=no
  if [ "$once" = no ]; then
    TUPLE="$(tuple_now)"
    if [ -e "$FUZZ_STATE/SATURATED" ]; then
      sat="$(cat "$FUZZ_STATE/SATURATED")"
      if [ "$sat" = "$TUPLE" ]; then [ "$satidle" = yes ] || { say "idle: SATURATED names the current tuple"; satidle=yes; }; sleep "$FUZZ_IDLE_SLEEP"; continue; fi
      say "woken: $(tuple_moved "$sat" "$TUPLE")"; satidle=no
      rm -f "$FUZZ_STATE/SATURATED" "$FUZZ_STATE/sat.streak"
    fi
    nday="$(grep -c ' batch=[0-9]* seed=[^ ]* count=' "$LOGDIR/$(day).log" 2>/dev/null)"
    if [ "${nday:-0}" -ge "$FUZZ_DAY_MAX" ]; then
      [ "$capday" = "$(day)" ] || { say "day cap: $nday batches on $(day) (FUZZ_DAY_MAX $FUZZ_DAY_MAX); idle until the next UTC day"; capday="$(day)"; }
      sleep "$FUZZ_IDLE_SLEEP"; continue
    fi
  fi
  l="$(load1)"
  case "$l" in ''|*[!0-9.]*) say "waiting: the 1-minute load could not be read ($l)"; sleep "$FUZZ_IDLE_SLEEP"; continue;; esac
  if ! awk -v l="$l" -v m="$FUZZ_LOAD_MAX" 'BEGIN { exit !(l < m) }'; then
    [ "$once" = yes ] && say "waiting: 1-minute load $l is not under $FUZZ_LOAD_MAX"
    sleep "$FUZZ_IDLE_SLEEP"; continue
  fi
  BINS="$(bins_now)"; TUPLE="$(tuple_now)"
  nodes_refresh
  if nodes_ready && batch; then
    fails=0
    [ "$once" = yes ] && break
  else
    fails=$((fails + 1))
    if [ "$fails" -ge 3 ]; then
      say "three failures in a row: waiting $FUZZ_FAIL_SLEEP s (the batch's directory is kept)"
      [ "$once" = yes ] && break
      for _ in $(seq 1 $((FUZZ_FAIL_SLEEP / 60))); do [ -e "$STOP" ] && break; sleep 60; done; fails=0
    fi
  fi
done
finish "$([ -e "$STOP" ] && echo STOP || echo once)"
