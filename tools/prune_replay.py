#!/usr/bin/env python3
"""#82's node-free regression: the Lean pruning function against the node's recorded answers.

[D] 2026-10-15, lane s7-82. `harness/src/scenarios/prune.rs` fed `chaincheck --prune` the node's own
block sizes in arrival order and compared every answer with the node (record
docs/records/20261015-130232-s7-82-prune-s1.md). Those inputs are corpus/chain/prune/2026-10-15-<instance>.json;
the node's answers are corpus/scenarios/2026-10-15-prune-retention.node.json. This replays the inputs and
checks the Lean output against the recorded answers, so a change to lean/BsvChain/Views/Prune.lean that
moves an answer turns the chain leg RED without a node.
"""
import json
import subprocess
import sys
import time

EXE = 'lean/.lake/build/bin/chaincheck'
start = time.monotonic()
node = {s['id']: s['observed'] for s in json.load(open('corpus/scenarios/2026-10-15-prune-retention.node.json'))['steps']}

def lean(name):
    out = subprocess.run([EXE, '--prune', f'corpus/chain/prune/2026-10-15-{name}.json'], capture_output=True, text=True)
    if out.returncode != 0:
        sys.exit(f'chaincheck prune: RED ({name}: {out.stderr.strip()})')
    return json.loads(out.stdout)

def reply(r):
    return {'error': r['error']} if 'error' in r else {'result': r['result']}

bad, checked = [], 0
def check(label, ok):
    global checked
    checked += 1
    if not ok:
        bad.append(label)

m = lean('manual')
for k, sid in enumerate(['s1', 's2', 's3', 's4', 's5', 's6']):
    check(f'{sid} reply', reply(m['replies'][k]['reply']) == node[sid]['reply'])
    if 'bits' in node[sid]:
        data = m['replies'][k]['data']
        check(f'{sid} retained', sum(data) == node[sid]['bits']['retained'] and len(data) == node[sid]['bits']['blocks'])
        check(f'{sid} files', node[sid]['files']['agree'] and len(node[sid]['files']['blk']) == m['replies'][k]['count'] - len({f for r in m['replies'][:k + 1] for f in r['removed']}))
check('s7 pruneheight', m['replies'][2]['pruneheight'] == node['s7']['pruneheight'])
for lp, np in zip(m['probes'], node['s8']['probes']):
    for q in np['requests']:
        a = lp['answers'][q['request']]
        o = q['observed']
        if a['kind'] == 'head-then-error':
            ok = o['kind'] == a['kind'] and f'"error":{{"code":{a["code"]},"message":"{a["message"]}"}}' in o['raw']
        else:
            ok = a['kind'] == o['kind'] and a.get('code') == o.get('code') and (a['kind'] != 'error' or a['message'] == o['message'])
        check(f"s8 {np['probe']} {q['request']}", ok)
check('s9', node['s9']['T']['kind'] == 'served' and {k: node['s9']['P'][k] for k in ('code', 'message')} == {k: m['probes'][0]['answers']['getmerkleproof'][k] for k in ('code', 'message')})
last = m['replies'][3]['data']
check('s10 tip', max(i for i, d in enumerate(last) if not d) == node['s10']['last_tip_height'])
k2 = lean('keep2000')
check('s11 reply', reply(k2['replies'][0]['reply']) == node['s11']['reply'])
check('s11 retained', sum(k2['replies'][0]['data']) == node['s11']['bits']['retained'])
off = lean('off')
check('s12 reply', reply(off['replies'][0]['reply']) == node['s12']['reply'])
la = lean('launch')
for l, r in zip(la['launch'], node['s13']['refusals']):
    check(f"s13 {r['arg']}", l['error'] == r['lean'] and l['error'] in r['stderr'])
au = lean('auto')
check('s14 retained', sum(au['replies'][0]['data']) == node['s14']['bits']['retained'])
check('s14 pruneheight', au['replies'][0]['pruneheight'] == node['s14']['pruneheight'])
check('s8 probes', len(m['probes']) == len(node['s8']['probes']) == 3 and all(len(p['requests']) == 10 for p in node['s8']['probes']))
check('s13 launches', len(la['launch']) == len(node['s13']['refusals']) == 2)
if checked != 54:
    sys.exit(f'chaincheck prune: RED [X] ({checked} checks, 54 expected)')
if bad:
    sys.exit(f'chaincheck prune: RED [X] ({len(bad)} of {checked} checks: {bad})')
print(f'chaincheck prune: GREEN [X] ([M] {checked} checks of the Lean pruning function against the node answers of docs/records/20261015-130232-s7-82-prune-s1.md, five instances replayed node-free)')
print(f'chain timing: prune_replay wall [M] {time.monotonic() - start:.6f}s')
