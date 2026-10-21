#!/usr/bin/env python3
"""Compare node-column inputs against main, accounting for the recorded R2 amendment."""
import json
import pathlib
import re
import subprocess

BASE = 'origin/main'
NODE = re.compile(r'("node"\s*:\s*)"(?:[^"\\]|\\.)*"')
MARK = re.compile(r'measured (?:agree|diverge) \[X\] docs/records/[A-Za-z0-9-]+\.md')

def original(path):
    return subprocess.check_output(['git', 'show', f'{BASE}:{path}'], text=True)

def triggers(raw):
    result = []
    for match in re.finditer(r'"trigger"\s*:\s*', raw):
        start = match.end()
        value, length = json.JSONDecoder().raw_decode(raw[start:])
        result.append((start, start + length, value))
    return result

for path in pathlib.Path('corpus/chain').glob('*/*.jsonl'):
    if path.parent.name not in ('finality', 'utxo', 'block', 'mempool', 'chain', 'oracle'):
        continue
    before, after = original(path), path.read_text()
    # Oracle previously had no node key. A new terminal node member is metadata.
    if path.parent.name == 'oracle':
        after = re.sub(r',"node":"(?:[^"\\]|\\.)*"(?=}\n)', '', after)
    assert NODE.sub(r'\1"<node>"', before) == NODE.sub(r'\1"<node>"', after), path
for path in pathlib.Path('corpus/scenarios').glob('2026*.md'):
    before, after = original(path), path.read_text()
    old, new = triggers(before), triggers(after)
    assert len(old) == len(new)
    for (start, end, value), (a, b, historical) in reversed(list(zip(new, old))):
        assert historical['type'] == 'oracleInstrumentation'
        assert value['type'] == 'rpc' and value['rpc'] == 'sendrawtransactions'
        assert value['transactions'] == ['sweep0', 'sweep1']
        assert 'no auxiliary admission' in value['effects']['accepted_pool']
        after = after[:start] + before[a:b] + after[end:]
    after = MARK.sub('pending #66', after)
    after = after.replace('`action.trigger` RPC batch', '`action.trigger` oracle event')
    assert NODE.sub(r'\1"<node>"', before) == NODE.sub(r'\1"<node>"', after), path
print('preservation against origin/main: GREEN [X] (all non-node JSONL bytes unchanged; intake bytes unchanged except authorized R2 trigger objects and its prose name; node markers normalized)')

# The inherited exception must not allow new edits to fixture inputs in this lane.
BASE = '3732ad0'
for path in list(pathlib.Path('corpus/chain').glob('*/*.jsonl')) + list(pathlib.Path('corpus/scenarios').glob('2026*.md')):
    if path.suffix == '.jsonl' and path.parent.name not in ('finality', 'utxo', 'block', 'mempool', 'chain', 'oracle'):
        continue
    before, after = original(path), path.read_text()
    before, after = (MARK.sub('<node-verdict>', v) for v in (before, after))
    assert NODE.sub(r'\1"<node>"', before) == NODE.sub(r'\1"<node>"', after), path
print('lane preservation: GREEN [X] (against 3732ad0; zero new non-node input changes)')
