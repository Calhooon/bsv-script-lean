#!/usr/bin/env bash
# [D] 2026-10-13: executable lane replay entrypoint.
# S6 spec projection only. No node, wallet or network operation belongs here.
set -euo pipefail
built=false
full=false
for arg in "$@"; do
  case "$arg" in
    --built) built=true ;;
    --full) full=true ;;
    *) echo "chain: unknown argument $arg" >&2; exit 2 ;;
  esac
done
cd "$(dirname "$0")/.."
[[ -z "${GIT_DIR:-}" ]] || { echo 'chain: refuse Lake under GIT_DIR' >&2; exit 1; }
if [[ "$built" != true ]]; then
  [[ -f tools/host_private.sh ]] || { echo 'chain: host file absent; LEAN_LOCK_SH required' >&2; exit 2; }
  source tools/host_private.sh
  [[ -n "${LEAN_LOCK_SH:-}" ]] || { echo 'chain: LEAN_LOCK_SH required' >&2; exit 2; }
  source "$LEAN_LOCK_SH"
  trap lean_lock_release EXIT
  trap 'exit 130' INT
  trap 'exit 143' TERM
  lean_lock_take s6-66-leg
  python3 - <<'PY'
import os, time
while os.getloadavg()[0] >= 20:
    print('chain: waiting for load below 20', flush=True)
    time.sleep(15)
PY
  uptime
  (cd lean && lake build finalitycheck utxocheck oraclecheck blockcheck mempoolcheck chaincheck)
  lean_lock_release
  trap - EXIT
  if [[ "$full" == true ]]; then
    bash tools/chain_leg.sh --built --full
  else
    bash tools/chain_leg.sh --built
  fi
  exit
fi
# [D] 2026-10-14, lane fix-merkle-89: the #89 generator against its file, so a changed generator with a stale
# file turns the leg RED (the lens on lane merkle-89); node-free, no Lean.
python3 tools/subtree_vectors.py --check
# [D] 2026-10-15, lane s7-82: #82's pruning function against the node answers of its record, node-free.
python3 tools/prune_replay.py
python3 - "$full" <<'PYTHON'
import os, subprocess, sys, time
start = time.monotonic()
commands = [(f'{f}check', [f'corpus/chain/{f}/{f}.jsonl']) for f in ('finality', 'utxo', 'mempool')]
if sys.argv[1] == 'true':
    commands.append(('chaincheck', ['corpus/chain/chain/chain.jsonl', '--rows']))
commands.append(('chaincheck', ['--scenarios']))
commands.append(('chaincheck', ['--status-views']))
# [D] 2026-10-13, lane s6-69: the era-boundary rows (#69), node-free.
commands.append(('chaincheck', ['--eras', 'corpus/chain/eras/eras.jsonl']))
# [D] 2026-10-14, lane s6-73: the #73 validation-depth and safe-mode rows.
commands.append(('chaincheck', ['--depth', 'corpus/chain/depth/depth.jsonl']))
# [D] 2026-10-14, lane s6-70: the operator-list rows (#70), node-free.
commands.append(('chaincheck', ['--frozen', 'corpus/chain/frozen/frozen.jsonl']))
# [D] 2026-10-14, lane merkle-89: the #89 subtree merkle vectors through the Lean definitions, node-free.
commands.append(('chaincheck', ['--subtree', 'corpus/merkle/subtree-vectors.jsonl']))
# [D] 2026-10-15, lane minerid-83: the #83 Miner ID check (mainnet coinbase documents, read only; synthetic 0.3 fixtures), node-free.
commands.append(('chaincheck', ['--minerid', 'corpus/minerid/coinbase-docs.jsonl']))
# [D] 2026-10-15, lane s7-78: the #78 relay machine over the two-node receipt (three-way projection) and its
# 37 frames read back through the Lean codec, node-free.
commands.append(('chaincheck', ['--p2p', 'corpus/p2p/2026-10-15-relay-two-node.receipt.json']))
# [D] 2026-10-15, lane fix-s7-78: the run's 37 frames alone through the Lean codec (`--p2p-frames`), node-free.
commands.append(('chaincheck', ['--p2p-frames', 'corpus/p2p/2026-10-15-relay-frames.jsonl']))
# [D] 2026-10-15, lane s7-79: #79's compact blocks over the two-node receipt (the frames, the Lean sender's message,
# the reconstruction against B's log and counters, the SipHash vectors), node-free.
commands.append(('chaincheck', ['--compact', 'corpus/p2p/2026-10-15-compact-two-node.receipt.json']))
# [D] 2026-10-15, lane s7-80: #80's double-spend notifications over the two-node receipt (the codecs, #62's
# detector, the handler's requests, the dsdetected relay and its webhook JSON), node-free.
commands.append(('chaincheck', ['--dsnt', 'corpus/p2p/2026-10-15-double-spend-two-node.receipt.json']))
# [M] 2026-10-17, lane close-88: #88's obligation list against the map, the ledger and its JSON (`corpus/teranode/obligations.json`,
# the input of the contract page's section 5 and of #95's gate), node-free.
commands.append(('chaincheck', ['--refinement']))
commands += [('oraclecheck', ['corpus/cpp/replay/cpp-sigopcount/cases.jsonl', 'corpus/chain/oracle/oracle.jsonl']), ('blockcheck', ['corpus/chain/headers/mainnet.jsonl', 'corpus/chain/block/block.jsonl'])]
# [M] 2026-10-14, lane attr-o3b: the executables read their corpus files and write nothing, so they run
# three at a time, the longest measured parts submitted ahead; each one's output is printed in the order
# above after all have finished, and a non-zero exit stops the leg there, as before.
from concurrent.futures import ThreadPoolExecutor
jobs = min(3, os.cpu_count() or 1)
lead = {'--rows': 0, '--depth': 1, '--scenarios': 2, '--status-views': 3, '--eras': 4}
def run(command):
    exe, args = command
    before = time.monotonic()
    if '--status-views' in args:
        result = subprocess.run([f'lean/.lake/build/bin/{exe}', *args], capture_output=True, text=True)
        out = result.stderr
    else:
        result = subprocess.run([f'lean/.lake/build/bin/{exe}', *args], stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
        out = result.stdout
    return result.returncode, out, time.monotonic() - before
order = sorted(range(len(commands)), key=lambda i: min([lead.get(a, 9) for a in commands[i][1]] + [9]))
with ThreadPoolExecutor(max_workers=jobs) as pool:
    futures = {i: pool.submit(run, commands[i]) for i in order}
parts = 0.0
for i, (exe, args) in enumerate(commands):
    code, out, wall = futures[i].result()
    parts += wall
    print(out, end='', flush=True)
    if code != 0:
        raise SystemExit(f'chain: {exe} {" ".join(args)} exited {code}')
    if '--status-views' in args and ('status views: GREEN [X]' not in out or 'predicates checked; failures 0' not in out):
        raise SystemExit('chain: status fixture verdict absent')
    print(f'chain timing: {exe} {"rows " if "--rows" in args else "scenarios " if "--scenarios" in args else "status views " if "--status-views" in args else "eras " if "--eras" in args else "depth " if "--depth" in args else "frozen " if "--frozen" in args else "subtree " if "--subtree" in args else "minerid " if "--minerid" in args else "p2p " if "--p2p" in args else "p2p frames " if "--p2p-frames" in args else "compact " if "--compact" in args else "dsnt " if "--dsnt" in args else "refinement " if "--refinement" in args else ""}wall [M] {wall:.6f}s', flush=True)
print(f'chain: GREEN [X] (spec projection; replay wall [M] {time.monotonic()-start:.6f}s, {jobs} executables at a time, parts summed [M] {parts:.6f}s; node excluded)')
PYTHON
