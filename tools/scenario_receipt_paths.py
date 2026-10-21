#!/usr/bin/env python3
"""Normalize local instance pointers and the saved build diagnostic, byte otherwise exact."""
import json
from pathlib import Path
import re

PATTERN = re.compile(r'/(?:Users|Volumes)/[^"\s\\]*?/spec-oracle-scenarios/')
BUILD = re.compile(r'/(?:Users|Volumes)/[^"\s\\()]*?/bsv-script-lean-worktrees/[^/"\s\\()]+/')

HOST = re.compile(r'(at [0-9TZ:-]+ on )[A-Za-z0-9._-]+(?=;)')

def normalize(raw):
    return HOST.sub(r'\1<host>', BUILD.sub('', PATTERN.sub('', raw)))

def main():
    changed = 0
    for path in sorted(Path('docs/records').glob('20261013-*s6-66*-regtest-s3.json')):
        raw = path.read_text()
        cleaned = normalize(raw)
        json.loads(cleaned)
        assert not re.search(r'/(Users|Volumes)/', cleaned), path.name
        if raw != cleaned:
            path.write_text(cleaned)
            changed += 1
    print(f'receipt paths: GREEN [X] ([M] {changed} receipts normalized; other bytes retained)')

if __name__ == '__main__':
    main()
