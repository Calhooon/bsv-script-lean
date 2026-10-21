#!/usr/bin/env python3
"""Read-only object audit for the 0.5.0 engine-column measurement.

Run from any directory. The base commit must be available locally.
The companion JSON supplies the corpus/vector paths, not the verdicts.
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
RECORD = Path(__file__).with_name(Path(__file__).name.replace('-audit.py', '.json'))
GO_KEYS = ('go-sdk@v1.7.2', 'go-sdk-mempool@v1.7.2')


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
    evidence = json.loads(RECORD.read_text())
    base = evidence['base']

    def blob(path):
        return subprocess.check_output(['git', 'show', f'{base}:{path}'], cwd=ROOT)

    active = json.loads((ROOT / 'corpus/witnesses/manifest.json').read_text())
    old_witnesses = json.loads(blob('corpus/witnesses/manifest.json'))
    results = []
    for c in evidence['corpora']:
        path = Path(c['file'])
        current_bytes = (ROOT / path).read_bytes()
        before_bytes = blob(path)
        compressed = path.suffix == '.gz'
        before_digest, after_digest = hashlib.sha256(), hashlib.sha256()
        count, histogram = 0, {}
        for before, after in itertools.zip_longest(rows(before_bytes, compressed), rows(current_bytes, compressed)):
            assert before is not None and after is not None
            assert before['id'] == after['id'], 'row identity/order changed'
            native = after['expect']['bsv-rs@0.5.0']
            assert native == before['expect']['bsv-rs@0.4.5'], before['id']
            histogram[native['verdict']] = histogram.get(native['verdict'], 0) + 1
            for entry, digest in [(before, before_digest), (after, after_digest)]:
                projection = {'id': entry['id'], 'expect': {k: entry['expect'][k] for k in GO_KEYS}}
                digest.update((json.dumps(projection, sort_keys=True, separators=(',', ':')) + '\n').encode())
                entry['expect'] = {k: v for k, v in entry['expect'].items() if not k.startswith('bsv-rs@')}
            assert before == after, ('non-bsv-rs object changed', before['id'])
            count += 1
        assert count == c['entries'] and before_digest.digest() == after_digest.digest()
        manifest_path = Path(c['manifest'])
        manifest = json.loads((ROOT / manifest_path).read_text())
        old_manifest = json.loads(blob(manifest_path))
        plain = gzip.decompress(current_bytes) if compressed else current_bytes
        assert manifest['sha256'] == sha(plain) == c['after_sha256']
        assert manifest['count'] == count and manifest['verdicts'] == histogram
        assert [i for i in manifest['implementations'] if i['name'] != 'bsv-rs'] == [i for i in old_manifest['implementations'] if i['name'] != 'bsv-rs']
        assert [i['version'] for i in manifest['implementations'] if i['name'] == 'bsv-rs'] == ['0.5.0']
        measured, old = active[c['corpus']], old_witnesses[c['corpus']]
        assert measured['bsv-rs'] == '0.5.0'
        for k in ('agree_block', 'agree_mempool', 'undecided', 'witnesses', 'rules', 'unknown_messages',
                  'aborts_as_witnesses', 'entries', 'spec', 'spec_config', 'engine_config'):
            assert measured[k] == old[k], (c['corpus'], k)
        assert measured['history'] == old.get('history', []) + [{k: v for k, v in old.items() if k != 'history'}]
        assert sha((ROOT / 'corpus/witnesses' / measured['file']).read_bytes()) == measured['sha256']
        assert all(r['rule'] != 'unexplained' for r in measured['rules'])
        results.append({'corpus': c['corpus'], 'entries': count, 'go_sdk_objects': count * 2,
                        'go_sdk_before_sha256': before_digest.hexdigest(), 'go_sdk_after_sha256': after_digest.hexdigest(),
                        'changed_go_sdk_objects': 0, 'changed_other_fields': 0, 'changed_native_verdicts': 0,
                        'plain_sha256': manifest['sha256'], 'stored_sha256': sha(current_bytes),
                        'agree_block': measured['agree_block'], 'agree_mempool': measured['agree_mempool']})
    protected = subprocess.check_output(['git', 'ls-tree', '-r', '--name-only', base, '--', 'harness/rules',
        'corpus/witnesses/go-sdk', 'corpus/witnesses/ts-sdk', 'corpus/witnesses/gobdk', 'corpus/witnesses/sv-node'], cwd=ROOT, text=True).splitlines()
    for path in protected:
        assert (ROOT / path).read_bytes() == blob(path), path
    for vector in evidence['vectors']:
        current = (ROOT / vector['file']).read_bytes()
        assert current == blob(vector['before_file']) and sha(current) == vector['sha256']
    assert subprocess.check_output(['git', 'diff', '--name-only', base, '--', 'lean/'], cwd=ROOT) == b''
    go = json.loads((ROOT / 'corpus/witnesses/go-sdk/manifest.json').read_text())
    totals = {'entries': sum(r['entries'] for r in results),
              'go_sdk_objects': sum(r['go_sdk_objects'] for r in results),
              'bsv_rs_block_agree': sum(r['agree_block'] for r in results),
              'bsv_rs_mempool_agree': sum(r['agree_mempool'] for r in results),
              'go_sdk_block_agree': sum(r['agree']['spec'] for r in go.values()),
              'go_sdk_mempool_agree': sum(r['agree']['spec-mempool'] for r in go.values())}
    assert totals == {'entries': 276063, 'go_sdk_objects': 552126, 'bsv_rs_block_agree': 122704,
                      'bsv_rs_mempool_agree': 27885, 'go_sdk_block_agree': 276002, 'go_sdk_mempool_agree': 275986}
    print(json.dumps({'base': base, 'load1': load1, 'status': 'GREEN', 'totals': totals, 'corpora': results,
                      'class_rows_moved': 0, 'unexplained': 0, 'protected_files_unchanged': len(protected),
                      'vectors_identical': 4, 'tracked_lean_unchanged': True}, indent=2))


if __name__ == '__main__':
    main()
