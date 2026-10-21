#!/usr/bin/env python3
"""Byte-compare canonical per-row verdict sets in independently recorded runs."""
import hashlib
import json
import pathlib
import sys

def verdicts(path):
    receipt = json.loads(pathlib.Path(path).read_text())
    rows = []
    for family, values in receipt['families'].items():
        for row in values:
            verdict = row.get('verdict')
            if verdict is None:
                verdict = 'unrealizable' if 'unrealizable' in row else 'needs-peer'
            rows.append([family, row['id'], verdict])
    for scenario in receipt['scenarios']:
        for row in scenario['steps']:
            rows.append([scenario['scenario'], row['id'], row['verdict']])
    return (json.dumps(sorted(rows), separators=(',', ':')) + '\n').encode(), len(rows)

if __name__ == '__main__':
    before, count = verdicts(sys.argv[1])
    after, after_count = verdicts(sys.argv[2])
    if '--existing' in sys.argv[3:]:
        old_rows = json.loads(before)
        keys = {tuple(row[:2]) for row in old_rows}
        new_rows = json.loads(after)
        assert len({tuple(row[:2]) for row in new_rows}) == len(new_rows), 'duplicate row ids'
        retained = [row for row in new_rows if tuple(row[:2]) in keys]
        after = (json.dumps(sorted(retained), separators=(',', ':')) + '\n').encode()
        print(f'additional classifications: [M] {after_count-count}; retained rows checked independently [X]')
    assert before == after, 'per-row verdict sets differ'
    print(f'verdict-set: byte-identical [X] ([M] {count} rows; SHA256 {hashlib.sha256(after).hexdigest()})')
