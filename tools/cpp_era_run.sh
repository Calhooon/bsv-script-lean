#!/bin/zsh -f
# tools/cpp_era_run.sh (S3, lane cpp-era-49, 2026-10-06; #49's `txvalidationcache` rows at their own era): the four
# differentials on the `CheckInputs` calls of `corpus/cpp/txvalidationcache_tests.jsonl.gz` AT THE TEST'S OWN ERA, on the lane's
# own two SV-node instances over a chain of the reference's unit-test fixture, one group of calls per node configuration.
#
#   zsh -f tools/cpp_era_run.sh [<the file's corpus name, default cpp-txvalidationcache>]
#
# THE GROUPS come from the file's ledger (`tools/cpp_replay.py project`: `groups`, one corpus per (tip, Genesis height,
# Chronicle height), the heights the test's config carried at each call). THE CHAIN is the fixture's (`tools/cpp_era_chain.py`:
# `TestChain100Setup`'s hundred blocks, their coinbases paying the fixture's key, then block 101 carrying the opening loop's spend
# as `txvalidationcache_tests.cpp:394` does), mined on BOTH instances by `submitblock`, under the opening configuration of each tip
# (a pre-Genesis one at that height: block 101's P2SH outputs are a pre-Genesis block's). THE INSTANCES are the oracle's two
# settings (`harness/oracle/bitcoin.conf`, the consensus instrument; `bitcoin-policy.conf`, the node's default policy) on
# this lane's datadirs and ports under $ERA_HOME, started per group with `-genesisactivationheight=<G>
# -chronicleactivationheight=<C>` on the command line (as the test's `SetGenesisActivationHeight`/`SetChronicleActivationHeight`
# move them in place, `txvalidationcache_tests.cpp:117–125`) and `-checklevel=0` (the start-up self-check re-validates the tip
# blocks under the CURRENT heights, `init.cpp:3805–3806`, `CheckBlock` → `CheckRegularTransaction` with the block's era,
# `validation.cpp:5833`; block 101 is a pre-Genesis block the test's in-place change never re-checked), and STOPPED before the
# next group and at exit. Per group: the corpus's coins checked against both instances' UTXO sets (`gettxout`: script, value,
# height, the coinbase flag); (1) the spec, `eval/bsvs corpus --config sv-regtest --genesis-height G --chronicle-height C`;
# (2) bsv-rs, `run_diff --record`; (3) `run_svnode --record --spec-config sv-regtest --genesis-height G --chronicle-height C
# --txo-from-chain` against both instances (the coins read from the chain). Then `tools/cpp_replay.py judge` over the groups.
# Nothing runs above a 1-minute load of 20; loopback RPC, no peer (CLAUDE.md rule 10); the box leg lock is not taken (these
# are the lane's own instances, never the oracle's); eval/bsvs is run, not built, here (the build takes a Lean slot).
# The log of each step is $ERA_HOME/logs/<corpus>-*; the datadirs under $ERA_HOME are WIPED at the start (a fresh chain) unless
# ERA_FRESH=0 (a later call continues on the chain the opening call mined); ERA_GROUPS="<tag> …" runs those groups alone (a sitting
# splits the groups over calls that each fit a foreground window); ERA_JUDGE=0 skips the judge (run it with the last call).
set -u
NAME="${1:-cpp-txvalidationcache}"
W="$(cd "$(dirname "$0")/.." && pwd)"
cd "$W" || exit 2
LED="corpus/cpp/replay/$NAME/ledger.json"
: "${ERA_HOME:=$HOME/bsv/targets/spec-cpp-era-49}"
: "${CARGO_TARGET_DIR:=$HOME/bsv/targets/spec-cpp-era-49}"
export CARGO_TARGET_DIR CARGO_BUILD_JOBS=4 ENGINE_ADAPTER_TIMEOUT_S=60
: "${SV_BIN:=$HOME/bsv/targets/sv-v1.2.2/bin/bitcoind}"
: "${SV_CLI:=$HOME/bsv/targets/sv-v1.2.2/bin/bitcoin-cli}"
LOCAL="$ERA_HOME/local-data"; POLICY="$ERA_HOME/policy-data"; LOGS="$ERA_HOME/logs"
LRPC=18583; LP2P=18584; PRPC=18585; PP2P=18586
BIN="$CARGO_TARGET_DIR/release"
say() { echo "cpp_era_run: $(date -u +%H:%M:%SZ) $*"; }
load1() { sysctl -n vm.loadavg | awk '{print int($2)}'; }
[ "$(load1)" -lt 20 ] || { say "STOP: the 1-minute load is $(load1), not under 20"; exit 3; }
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE
[ -x "$SV_BIN" ] && [ -x "$SV_CLI" ] || { say "STOP: the pinned build ($SV_BIN, $SV_CLI; harness/oracle/spec-node.sh names it)"; exit 2; }
for b in run_diff run_svnode; do [ -x "$BIN/$b" ] || { say "STOP: $BIN/$b is not built (cd harness && cargo build --release --locked --bin $b)"; exit 2; }; done
[ -f "$LED" ] || { say "STOP: no $LED (tools/cpp_replay.py project)"; exit 2; }
[ -x eval/bsvs ] || { say "STOP: eval/bsvs"; exit 2; }
pgrep -f "datadir=$ERA_HOME" >/dev/null && { say "STOP: an instance of this lane is already running"; exit 2; }
: "${ERA_FRESH:=1}"; : "${ERA_GROUPS:=}"; : "${ERA_JUDGE:=1}"
if [ "$ERA_FRESH" = 1 ]; then rm -rf "$LOCAL" "$POLICY"; fi
mkdir -p "$LOGS" "$LOCAL" "$POLICY"
say "$([ "$ERA_FRESH" = 1 ] && echo "a fresh chain: $LOCAL and $POLICY wiped" || echo "the chain of the earlier call kept under $ERA_HOME"); disk $(df -h "$HOME" | tail -1 | awk '{print $4}') free; load $(load1)"

cli() {
  local which="$1"; shift
  if [ "$which" = local ]; then "$SV_CLI" -regtest -conf="$W/harness/oracle/bitcoin.conf" -datadir="$LOCAL" -rpcport=$LRPC "$@"
  else "$SV_CLI" -regtest -conf="$W/harness/oracle/bitcoin-policy.conf" -datadir="$POLICY" -rpcport=$PRPC "$@"; fi
}
node_start() {
  local which="$1" g="$2" c="$3" conf dd rpc p2p
  if [ "$which" = local ]; then conf="$W/harness/oracle/bitcoin.conf"; dd="$LOCAL"; rpc=$LRPC; p2p=$LP2P
  else conf="$W/harness/oracle/bitcoin-policy.conf"; dd="$POLICY"; rpc=$PRPC; p2p=$PP2P; fi
  # -daemon is refused by this build on macOS (spec-node.sh); the console is discarded, stderr kept
  nohup "$SV_BIN" -regtest -conf="$conf" -datadir="$dd" -rpcport=$rpc -port=$p2p \
    -genesisactivationheight="$g" -chronicleactivationheight="$c" -checklevel=0 > /dev/null 2> "$dd/bitcoind.err" &
  for _ in $(seq 1 90); do cli "$which" getblockcount >/dev/null 2>&1 && return 0; sleep 1; done
  say "STOP: the $which instance did not answer within 90 s (stderr $dd/bitcoind.err)"; tail -3 "$dd/bitcoind.err"; return 1
}
nodes_stop_wait() {
  cli local stop >/dev/null 2>&1; cli policy stop >/dev/null 2>&1
  for _ in $(seq 1 90); do pgrep -f "datadir=$ERA_HOME" >/dev/null || return 0; sleep 1; done
  say "an instance is still running"; pgrep -fl "datadir=$ERA_HOME"; return 1
}
nodes_restart() {
  nodes_stop_wait || return 1
  node_start local "$1" "$2" || return 1
  node_start policy "$1" "$2" || return 1
  say "both instances at -genesisactivationheight=$1 -chronicleactivationheight=$2 -checklevel=0: height local $(cli local getblockcount), policy $(cli policy getblockcount); $(cli local getnetworkinfo | grep -o '"subversion": "[^"]*"')"
}
setopt POSIX_TRAPS
trap 'exit 130' INT; trap 'exit 143' TERM; trap 'exit 129' HUP
trap 'nodes_stop_wait' EXIT

# the groups, tip ascending; within a tip the activation heights descending (a pre-Genesis configuration at that tip: the
# chain is mined under it), so block 101 (P2SH outputs) is mined as the test mined it, before Genesis
GROUPS="$(python3 - "$LED" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
for tag, g in sorted(d.get("groups", {}).items(), key=lambda kv: (kv[1]["tip_height"], -kv[1]["genesis_height"], -kv[1]["chronicle_height"])):
    print(tag, g["corpus"], g["tip_height"], g["genesis_height"], g["chronicle_height"], g["entries"])
PY
)"
[ -n "$GROUPS" ] || { say "STOP: the ledger names no groups"; exit 2; }
# the fixture's facts from the tip-100 groups' corpora: the key's P2PK (the coinbase's lock), the coinbase at height 1 the opening
# loop spends, and that spend (block 101's transaction); every tip-100 entry carries the same transaction and prevout
FACTS="$(python3 - "$LED" <<'PY'
import gzip, json, os, sys
d = json.load(open(sys.argv[1])); base = os.path.dirname(sys.argv[1]) + "/.."
txs, prevs = set(), set()
for tag, g in d["groups"].items():
    if g["tip_height"] != 100: continue
    p = f"{base}/{g['corpus']}/cases.jsonl"
    op = gzip.open if not os.path.exists(p) else open
    for line in op(p if os.path.exists(p) else p + ".gz", "rt"):
        e = json.loads(line); txs.add(e["tx"]); prevs.add((e["prevouts"][0]["txid"], e["prevouts"][0]["vout"], e["prevouts"][0]["script"]))
assert len(txs) == 1 and len(prevs) == 1, (len(txs), len(prevs))
(txid, vout, script), = prevs
assert vout == 0 and script[:2] == "21" and script[-2:] == "ac", script
print(script[2:-2], txid, next(iter(txs)))
PY
)" || { say "STOP: the tip-100 groups do not share one spend and one coinbase"; exit 2; }
set -- ${=FACTS}; PUB="$1"; CB1="$2"; SPEND_TX="$3"
say "the fixture's key $PUB, the coinbase at height 1 $CB1, block 101's spend $(echo -n "$SPEND_TX" | shasum -a 256 | cut -c1-16)…"
NODES=(--node "http://127.0.0.1:$LRPC" "$LOCAL/regtest/.cookie" --node "http://127.0.0.1:$PRPC" "$POLICY/regtest/.cookie")
while IFS= read -r line; do
  set -- ${=line}; tag="$1"; corpus="$2"; tip="$3"; g="$4"; c="$5"; n="$6"
  if [ -n "$ERA_GROUPS" ] && [[ " $ERA_GROUPS " != *" $tag "* ]]; then continue; fi
  DIR="corpus/cpp/replay/$corpus"
  if [ ! -f "$DIR/cases.jsonl" ]; then
    [ -f "$DIR/cases.jsonl.gz" ] && gzip -dc "$DIR/cases.jsonl.gz" > "$DIR/cases.jsonl" || { say "STOP: no $DIR/cases.jsonl"; exit 2; }
  fi
  say "== group $tag: $n entries, the tip $tip, -genesisactivationheight=$g -chronicleactivationheight=$c"
  nodes_restart "$g" "$c" || exit 4
  h="$(cli local getblockcount)"
  if [ "$h" -lt "$tip" ]; then
    if [ "$tip" -eq 100 ]; then
      python3 tools/cpp_era_chain.py mine --pubkey "$PUB" --to 100 --coinbase1-txid "$CB1" "${NODES[@]}" > "$LOGS/mine-to-100.json" || { say "STOP: mining to 100"; cat "$LOGS/mine-to-100.json"; exit 4; }
      say "mined: $(python3 -c "import json; d=json.load(open('$LOGS/mine-to-100.json')); print(d['mined'], 'blocks to', d['to'], 'best', d['best'][:16], 'coinbase1', d['coinbase1_txid'][:16])")"
    elif [ "$tip" -eq 101 ]; then
      python3 tools/cpp_era_chain.py mine --pubkey "$PUB" --to 101 --tx "$SPEND_TX" "${NODES[@]}" > "$LOGS/mine-to-101.json" || { say "STOP: mining block 101"; cat "$LOGS/mine-to-101.json"; exit 4; }
      say "mined: $(python3 -c "import json; d=json.load(open('$LOGS/mine-to-101.json')); print(d['mined'], 'block(s) to', d['to'], 'best', d['best'][:16], 'txs', [t[:16] for t in d['txs_in_last_block']])")"
    else
      say "STOP: a tip of $tip is not the fixture's (100 or 101)"; exit 4
    fi
  fi
  [ "$(cli local getblockcount)" -eq "$tip" ] && [ "$(cli policy getblockcount)" -eq "$tip" ] || { say "STOP: the chain is at local $(cli local getblockcount) / policy $(cli policy getblockcount), the group's tip is $tip"; exit 4; }
  python3 tools/cpp_era_chain.py check --corpus "$DIR/cases.jsonl" "${NODES[@]}" > "$LOGS/$corpus-check.json" || { say "STOP: the corpus's coins are not the chain's"; cat "$LOGS/$corpus-check.json"; exit 4; }
  say "coins: $(python3 -c "import json; d=json.load(open('$LOGS/$corpus-check.json')); print(d['distinct_prevouts'], 'distinct prevouts;', '; '.join(f\"{i['rpc'].rsplit(':',1)[1]}: tip {i['tip']}, ok {i['ok']}, coinbase {i['coinbase']}, heights {i['heights']}\" for i in d['instances']))")"
  SPEC="$ERA_HOME/spec-$corpus.jsonl"
  say "(1) eval/bsvs corpus $DIR/cases.jsonl --config sv-regtest --genesis-height $g --chronicle-height $c"
  eval/bsvs corpus "$DIR/cases.jsonl" --out "$SPEC" --config sv-regtest --genesis-height "$g" --chronicle-height "$c" > "$LOGS/$corpus-spec.log" 2>&1 || { say "STOP: eval/bsvs (log $LOGS/$corpus-spec.log)"; tail -3 "$LOGS/$corpus-spec.log"; exit 4; }
  tail -1 "$LOGS/$corpus-spec.log"
  say "(2) run_diff --record"
  ( cd harness && "$BIN/run_diff" --corpus "../$DIR/cases.jsonl" --spec "$SPEC" --witnesses ../corpus/witnesses --record ) > "$LOGS/$corpus-run_diff.log" 2>&1
  echo "run_diff rc $?"; grep -E "^run_diff|agree:" "$LOGS/$corpus-run_diff.log" | cut -c1-400
  say "(3) run_svnode --record against local ($LRPC) and policy ($PRPC), --spec-config sv-regtest --genesis-height $g --chronicle-height $c --txo-from-chain"
  ( cd harness && "$BIN/run_svnode" --corpus "../$DIR/cases.jsonl" --spec "$SPEC" --witnesses ../corpus/witnesses --record \
      --rpc "http://127.0.0.1:$LRPC" --cookie "$LOCAL/regtest/.cookie" --rpc-mempool "http://127.0.0.1:$PRPC" --cookie-mempool "$POLICY/regtest/.cookie" \
      --spec-config sv-regtest --genesis-height "$g" --chronicle-height "$c" --txo-from-chain ) > "$LOGS/$corpus-run_svnode.log" 2>&1
  echo "run_svnode rc $?"; grep -E "^run_svnode|agree" "$LOGS/$corpus-run_svnode.log" | cut -c1-400
done <<< "$GROUPS"
nodes_stop_wait || exit 5
say "both instances stopped"
if [ "$ERA_JUDGE" = 1 ]; then
  say "judge"
  python3 tools/cpp_replay.py judge "corpus/cpp/replay/$NAME" | tee "$LOGS/judge.log"
fi
say "done: $NAME${ERA_GROUPS:+ (groups: $ERA_GROUPS)} (the chain's blocks: $LOGS/mine-to-100.json, $LOGS/mine-to-101.json; the coins: $LOGS/*-check.json)"
