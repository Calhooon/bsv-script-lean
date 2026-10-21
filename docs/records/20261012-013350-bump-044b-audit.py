#!/usr/bin/env python3
"""Read-only object audit of lane bump-044b against main after #99 and bump-044.

Run from any directory: python3 <this-file> > <audit.json>.
The two baseline commits must be available locally. No worktree is changed.
"""
import gzip
import hashlib
import io
import itertools
import json
import os
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[2]
MAIN = '34e36b5fa84025bf244a49a556c278634d430a31'
BUMP = 'ad4216120db0363a845fb9d34ae59c27ce9f8e38'
ORIGINAL = json.loads((ROOT / 'docs/records/20261012-011846-bump-bsv-rs-0.4.4-s3.json').read_text())
GO_KEYS = ('go-sdk@v1.7.2', 'go-sdk-mempool@v1.7.2')


def blob(rev, path):
    return subprocess.check_output(['git', 'show', f'{rev}:{path}'], cwd=ROOT)


def sha(data):
    return hashlib.sha256(data).hexdigest()


def rows(data, compressed):
    source = gzip.GzipFile(fileobj=io.BytesIO(data)) if compressed else io.BytesIO(data)
    with source:
        for line in source:
            if line.strip():
                yield json.loads(line)


def main():
    load1 = os.getloadavg()[0]
    assert load1 < 20, f'load1 {load1}: start refused'
    active = json.loads((ROOT / 'corpus/witnesses/manifest.json').read_text())
    old_witnesses = json.loads(blob(MAIN, 'corpus/witnesses/manifest.json'))
    original_witnesses = json.loads(blob(BUMP, 'corpus/witnesses/manifest.json'))
    results = []
    for c in ORIGINAL['corpora']:
        path = Path(c['file'])
        current_bytes = (ROOT / path).read_bytes()
        before_bytes, bump_bytes = blob(MAIN, path), blob(BUMP, path)
        compressed = path.suffix == '.gz'
        before_digest, after_digest = hashlib.sha256(), hashlib.sha256()
        count, histogram = 0, {}
        for before, after, original in itertools.zip_longest(
                rows(before_bytes, compressed), rows(current_bytes, compressed), rows(bump_bytes, compressed)):
            assert before is not None and after is not None and original is not None
            assert before['id'] == after['id'] == original['id'], 'row identity/order changed'
            native = after['expect']['bsv-rs@0.4.4']
            assert native == original['expect']['bsv-rs@0.4.4'] == before['expect']['bsv-rs@0.3.33']
            histogram[native['verdict']] = histogram.get(native['verdict'], 0) + 1
            for entry, digest in [(before, before_digest), (after, after_digest)]:
                projection = {'id': entry['id'], 'expect': {k: entry['expect'][k] for k in GO_KEYS}}
                digest.update((json.dumps(projection, sort_keys=True, separators=(',', ':')) + '\n').encode())
                entry['expect'] = {k: v for k, v in entry['expect'].items() if not k.startswith('bsv-rs@')}
            assert before == after, ('non-bsv-rs object changed', before['id'])
            count += 1
        assert count == c['entries'] and before_digest.digest() == after_digest.digest()
        manifest_path = path.parent / ('cases-manifest.json' if path.name.startswith('cases.') else 'manifest.json')
        manifest = json.loads((ROOT / manifest_path).read_text())
        old_manifest = json.loads(blob(MAIN, manifest_path))
        plain = gzip.decompress(current_bytes) if compressed else current_bytes
        assert manifest['sha256'] == sha(plain)
        assert manifest['count'] == count and manifest['verdicts'] == histogram
        assert [i for i in manifest['implementations'] if i['name'] != 'bsv-rs'] == [i for i in old_manifest['implementations'] if i['name'] != 'bsv-rs']
        assert [i['version'] for i in manifest['implementations'] if i['name'] == 'bsv-rs'] == ['0.4.4']
        measured, expected, old = active[c['corpus']], original_witnesses[c['corpus']], old_witnesses[c['corpus']]
        for k in ('agree_block', 'agree_mempool', 'undecided', 'witnesses', 'rules', 'unknown_messages',
                  'aborts_as_witnesses', 'entries', 'spec', 'spec_config', 'engine_config'):
            assert measured[k] == expected[k], (c['corpus'], k)
        assert measured['history'] == old.get('history', []) + [{k: v for k, v in old.items() if k != 'history'}]
        assert sha((ROOT / 'corpus/witnesses' / measured['file']).read_bytes()) == measured['sha256']
        assert all(r['rule'] != 'unexplained' for r in measured['rules'])
        results.append({'corpus': c['corpus'], 'entries': count, 'go_sdk_objects': count * 2,
                        'go_sdk_before_sha256': before_digest.hexdigest(), 'go_sdk_after_sha256': after_digest.hexdigest(),
                        'changed_go_sdk_objects': 0, 'changed_other_fields': 0, 'changed_native_verdicts': 0,
                        'plain_sha256': manifest['sha256'], 'stored_sha256': sha(current_bytes),
                        'agree_block': measured['agree_block'], 'agree_mempool': measured['agree_mempool']})
    protected = subprocess.check_output(['git', 'ls-tree', '-r', '--name-only', MAIN, '--', 'harness/rules',
        'corpus/witnesses/go-sdk', 'corpus/witnesses/ts-sdk', 'corpus/witnesses/gobdk', 'corpus/witnesses/sv-node'], cwd=ROOT, text=True).splitlines()
    for path in protected:
        assert (ROOT / path).read_bytes() == blob(MAIN, path), path
    for vector in ORIGINAL['vectors']:
        current = (ROOT / vector['file']).read_bytes()
        assert current == blob(BUMP, vector['file']) and sha(current) == vector['sha256']
    assert subprocess.check_output(['git', 'diff', '--name-only', MAIN, '--', 'lean/'], cwd=ROOT) == b''
    go = json.loads((ROOT / 'corpus/witnesses/go-sdk/manifest.json').read_text())
    totals = {'entries': sum(r['entries'] for r in results),
              'go_sdk_objects': sum(r['go_sdk_objects'] for r in results),
              'bsv_rs_block_agree': sum(r['agree_block'] for r in results),
              'bsv_rs_mempool_agree': sum(r['agree_mempool'] for r in results),
              'go_sdk_block_agree': sum(r['agree']['spec'] for r in go.values()),
              'go_sdk_mempool_agree': sum(r['agree']['spec-mempool'] for r in go.values())}
    assert totals == {'entries': 276063, 'go_sdk_objects': 552126, 'bsv_rs_block_agree': 122704,
                      'bsv_rs_mempool_agree': 27885, 'go_sdk_block_agree': 276002, 'go_sdk_mempool_agree': 275986}
    print(json.dumps({'main': MAIN, 'original_bump': BUMP, 'load1': load1, 'status': 'GREEN',
                      'totals': totals, 'corpora': results, 'class_rows_moved': 0, 'unexplained': 0,
                      'protected_files_unchanged': len(protected), 'vectors_identical': 4,
                      'tracked_lean_unchanged': True}, indent=2))


if __name__ == '__main__':
    main()
