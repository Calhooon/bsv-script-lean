#!/usr/bin/env python3
"""Validate scenario provenance and witness shape, never semantic judgments."""
import argparse
import hashlib
import json
from pathlib import Path
import re
from receipt_trim import oversized

# [D] 2026-10-13 S3, lane trim-c1: the guard applies to every committed receipt.
failures = list(oversized(Path('docs/records')))
assert not failures, f'oversized committed receipts: {failures}'
print('receipt size: GREEN [X] (10 MB guard applies to every committed receipt)')

RECORD = r'docs/records/[A-Za-z0-9_-]+\.md'
TOKEN = re.compile(r'(?:pending #66|(?:measured .+|unrealizable: .+|needs-peer #71|rpc-precheck: -?\d+ .+ \(src/[A-Za-z0-9_/.]+:\d+-\d+\)) \[X\] '+RECORD+r')')

def node_tokens(value):
    if isinstance(value, dict):
        for key, child in value.items():
            if key == 'node' and isinstance(child, str):
                yield child
            else:
                yield from node_tokens(child)
    elif isinstance(value, list):
        for child in value:
            yield from node_tokens(child)

def expectations(value):
    if isinstance(value, dict):
        if value.get('expected') is not None:
            assert value.get('expected_label') == '[D]', 'unlabelled receipt expectation'
            yield 1
        for child in value.values():
            yield from expectations(child)
    elif isinstance(value, list):
        for child in value:
            yield from expectations(child)

def fence(path):
    raw = path.read_text()
    assert raw.count('```json\n') == 1, path
    return json.loads(raw.split('```json\n')[1].split('\n```')[0])

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--write-index', action='store_true', help='regenerate scenario corpus hashes')
args = parser.parse_args()
index_path = Path('corpus/INDEX.md')
index = index_path.read_text()
if args.write_index:
    for family in ('finality', 'utxo', 'block', 'mempool', 'chain', 'oracle', 'eras'):
        path = Path(f'corpus/chain/{family}/{family}.jsonl')
        lines = index.splitlines(keepends=True)
        index = ''.join(re.sub(r'[0-9a-f]{64}', hashlib.sha256(path.read_bytes()).hexdigest(), line)
                        if f'`{path}`' in line else line for line in lines)
    index_path.write_text(index)
readme = Path('corpus/scenarios/README.md').read_text()
rows = []
# [D] 2026-10-13, lane s6-69: the era-boundary rows (#69) join the token and hash checks.
# [D] 2026-10-14 S3, lane s6-73: the #73 depth family joins the guarded rows.
# [D] 2026-10-14, lane s6-70: the operator-list rows (#70) join them.
for family in ('finality', 'utxo', 'block', 'mempool', 'chain', 'oracle', 'eras', 'depth', 'frozen'):
    path = Path(f'corpus/chain/{family}/{family}.jsonl')
    rows.extend(json.loads(line) for line in path.read_text().splitlines())
    line = next(line for line in index.splitlines() if f'`{path}`' in line)
    assert hashlib.sha256(path.read_bytes()).hexdigest() in line, path
# [D] 2026-10-16, lane ns-140: a scenario page with no JSON fence (#80's prose page, its receipt under corpus/p2p/) is
# skipped BY NAME, never a pass; before this the check stopped at it (main since b0379b9f).
skipped = []
for path in sorted(Path('corpus/scenarios').glob('2026*.md')):
    if path.read_text().count('```json\n') == 0:
        skipped.append(path.name)
        continue
    rows.append(fence(path))
print(f'scenario pages without a fence: {len(skipped)} skipped by name: {", ".join(skipped) or "none"}')
count = 0
for row in rows:
    if row.get('action') == 'p2pTrace' and row.get('expected', {}).get('nonJudging'):
        if not row.get('budgetCell'):
            for step in row['expected']['nonJudging']:
                assert row.get('nonJudgingReasons', {}).get(str(step)), row['id']
        if row['node'].startswith('measured '):
            assert row['node'].startswith('measured non-judging:'), row['id']
    for token in node_tokens(row):
        assert TOKEN.fullmatch(token), token
        count += 1
print(f'node metadata: GREEN [X] ([M] {count} exact-shaped tokens; eight INDEX hashes)')

witnesses = list(Path('corpus/scenarios/witnesses').glob('*.md'))
for path in witnesses:
    witness = fence(path)
    assert {'id', 'class', 'witness', 'initial_chain', 'steps', 'replay'} <= witness.keys(), path
    assert witness['input_label'] == '[D]', path
    assert witness['initial_chain']['complete_rpc_history'].endswith('.json'), path
    assert Path(witness['initial_chain']['complete_rpc_history']).is_file(), path
    for step in witness['steps']:
        assert {'id', 'action', 'kind', 'rules', 'expected_observations', 'label', 'node'} <= step.keys(), path
        assert step['label'] == '[D]' and step['rules'], path
        assert TOKEN.fullmatch(step['node']), path
    assert path.name in readme and path.name in index, path
    line = next(line for line in index.splitlines() if path.name in line)
    assert 'as data' in line and '[X]' in line and witness['replay']['record'] in line, path
print(f'witness schema/index: GREEN [X] ([M] {len(witnesses)} files)')

count = 0
paths = list(Path('docs/records').glob('2026101[34]-*-s6-73-regtest-s3.json')) + list(Path('docs/records').glob('20261013-*s6-66*-regtest-s3.json')) + list(Path('docs/records').glob('20261013-*-s6-pend-66-regtest-s3.json')) + list(Path('docs/records').glob('20261013-*-s6-fix-pend2-regtest-s3.json')) + list(Path('corpus/scenarios').glob('*.node.json'))
for path in paths:
    count += sum(expectations(json.loads(path.read_text())))
print(f'receipt expectation labels: GREEN [X] ([M] {count} expectations)')
