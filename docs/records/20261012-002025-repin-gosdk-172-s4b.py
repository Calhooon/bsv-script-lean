#!/usr/bin/env python3
"""#99 continuation: foreground go-sdk replay of the 26 recorded corpora.

Usage: python3 <this-file> <worktree> <scratch-directory> [<receipt.json>]
The scratch directory must be outside the checkout and is retained for audit.
The receipt supplies the measured road words absent from its node manifest.
No classifier or spec verdict is changed; an unexplained run remains RED.
"""
import copy
import datetime
import gzip
import hashlib
import json
import os
from pathlib import Path
import shlex
import shutil
import subprocess
import sys
import time

ROOT = Path(sys.argv[1]).resolve()
TMP = Path(sys.argv[2]).resolve()
TMP.mkdir(exist_ok=True)
if len(sys.argv) > 3:
    receipt = json.loads(Path(sys.argv[3]).read_text())
    (TMP / 'road-words.json').write_text(json.dumps(receipt['road_words'], indent=2) + '\n')
os.chdir(ROOT)
ENV = {**os.environ, 'ENGINE_ADAPTER_TIMEOUT_S': '60', 'SOURCE_DATE': '2026-10-12'}

def now():
    return datetime.datetime.now(datetime.timezone.utc).isoformat()

def write_json(path, obj):
    path.write_text(json.dumps(obj, indent=2) + '\n')

def digest(path):
    h = hashlib.sha256()
    with path.open('rb') as f:
        for block in iter(lambda: f.read(1024 * 1024), b''):
            h.update(block)
    return h.hexdigest()

def run(name, cmd, allowed=(0,)):
    started = now()
    uptime = subprocess.check_output(['uptime'], text=True).strip()
    load = os.getloadavg()
    print(started, name, uptime, flush=True)
    if load[0] >= 20:
        raise SystemExit('WALLED before ' + name)
    t0 = time.monotonic()
    with (TMP / (name + '.log')).open('w') as out:
        proc = subprocess.run(cmd, env=ENV, stdout=out, stderr=subprocess.STDOUT)
    row = {'name': name, 'command': cmd, 'cwd': str(ROOT),
           'env': {'ENGINE_ADAPTER_TIMEOUT_S': '60', 'SOURCE_DATE': '2026-10-12'},
           'start': started, 'end': now(), 'load': load, 'uptime': uptime,
           'seconds': time.monotonic() - t0, 'exit': proc.returncode}
    with (TMP / 'commands.jsonl').open('a') as out:
        out.write(json.dumps(row) + '\n')
    for line in (TMP / (name + '.log')).read_text().splitlines():
        if line.startswith(('run_engine:', 'spec_recorded:')):
            print(line, flush=True)
    print(name, 'exit', proc.returncode, 'seconds', round(row['seconds'], 2), flush=True)
    if proc.returncode not in allowed:
        raise SystemExit(f'{name} failed; see {TMP / (name + ".log")}')
    return row

def sdk_key(k):
    return k.startswith(('go-sdk@', 'go-sdk-mempool@', 'go-sdk-default@'))

def sdk_impl(row):
    return row['name'] in ('go-sdk', 'go-sdk-mempool', 'go-sdk-default')

def counts(row):
    if row is None:
        return None
    return {k: copy.deepcopy(row.get(k)) for k in (
        'engine', 'entries', 'agree', 'undecided_runs', 'aborts_as_witnesses',
        'timeouts', 'unknown_messages', 'unmapped_bits')} | {
        'rules': [{k: r[k] for k in ('column', 'rule', 'entries', 'witness', 'from') if k in r}
                  for r in row['rules']]}

base = subprocess.check_output(['git', 'rev-parse', 'HEAD'], text=True).strip()
baseline = TMP / 'baseline'
resuming = (TMP / 'audit.json').exists()
baseline.mkdir(exist_ok=True)
old_sdk = json.loads((TMP / 'baseline-sdk-manifest.json' if resuming else ROOT / 'corpus/witnesses/go-sdk/manifest.json').read_text())
plan = json.loads((ROOT / 'corpus/witnesses/manifest.json').read_text())
sv = json.loads((ROOT / 'corpus/witnesses/sv-node/manifest.json').read_text())
assert len(plan) == 26 and sum(r['entries'] for r in plan.values()) == 276063
assert set(plan) == set(sv)
word_sources = {}
for name in ['tx', 'road']:
    # These node manifests describe transaction-mode runs and have no word table.
    # Reuse only saved words at the identical configuration and parameter triple.
    sources = [('go-sdk/' + name, old_sdk[name])] if name in old_sdk else [
        ('sv-node/' + k, v) for k, v in sv.items() if v.get('words') and
        v['spec_config'] == sv[name]['spec_config']]
    if name == 'road' and (TMP / 'road-words.json').exists():
        measured = json.loads((TMP / 'road-words.json').read_text())
        sources = [('eval/bsvs@' + measured['source_commit'], {
            'spec_config': sv[name]['spec_config'], 'words': measured['words']})]
    words, origins = {}, {}
    for label, source in sources:
        assert source['spec_config'] == sv[name]['spec_config']
        for word in source['words']:
            triple = (word['spend_height'], word['utxo_height'], word['consensus'])
            assert triple not in words or words[triple] == word
            words[triple] = word
            origins.setdefault(str(triple), []).append(label)
    sv[name]['words'] = list(words.values())
    word_sources[name] = origins
write_json(TMP / 'saved-sv-node-manifest.json', sv)
write_json(TMP / 'baseline-sdk-manifest.json', old_sdk)
protected = [p for p in (ROOT / 'harness/rules').glob('*.json')]
protected += [ROOT / 'corpus/witnesses/manifest.json']
protected += [ROOT / f'corpus/witnesses/{n}/manifest.json' for n in ('sv-node', 'ts-sdk', 'gobdk')]
protected_hashes = {str(p.relative_to(ROOT)): digest(p) for p in protected}
audit = {'base': base, 'start': now(), 'runner_sha256': digest(ROOT / 'harness/target/engines/gosdk-runner'),
         'recorded_spec': 'spec@cb7e46e', 'recorded_spec_mempool': 'spec-mempool@cb7e46e',
         'protected_hashes': protected_hashes, 'corpora': []}
if resuming:
    audit = json.loads((TMP / 'audit.json').read_text())
    assert protected_hashes == audit['protected_hashes']
audit['saved_word_sources_for_tx_and_road'] = word_sources
if (TMP / 'road-words.json').exists():
    audit['road_words'] = json.loads((TMP / 'road-words.json').read_text())
write_json(TMP / 'audit.json', audit)

for key, row in plan.items():
    assert row['spec_config'] == sv[key]['spec_config']
    path = ROOT / row['corpus'].removeprefix('../')
    stored = path if path.exists() else Path(str(path) + '.gz')
    dest = baseline / stored.relative_to(ROOT)
    dest.parent.mkdir(parents=True, exist_ok=True)
    if not dest.exists():
        shutil.copy2(stored, dest)
    for n in ('manifest.json', 'cases-manifest.json'):
        p = path.parent / n
        if p.exists() and json.loads(p.read_text()).get('file') == path.name:
            if not (dest.parent / n).exists():
                shutil.copy2(p, dest.parent / n)

spec_seed = TMP / 'spec-seed.jsonl'
if 'smoke' not in audit:
    run('smoke-spec', ['harness/target/release/spec_recorded', '--corpus', 'corpus/seed/seed.jsonl',
                  '--out', str(spec_seed), '--config', 'sv-mainnet-default'])
    smoke = run('smoke', ['harness/target/release/run_engine', '--engine', 'gosdk', '--corpus',
             'corpus/seed/seed.jsonl', '--spec', str(spec_seed), '--words-from',
             str(TMP / 'saved-sv-node-manifest.json'), '--witnesses', str(TMP / 'smoke-witnesses')], (0, 1))
    audit['smoke'] = {'command': smoke, 'counts': counts(json.loads((TMP / 'smoke-witnesses/go-sdk/manifest.json').read_text())['seed'])}
write_json(TMP / 'audit.json', audit)

order = list(old_sdk) + [k for k in plan if k not in old_sdk]
for key in order:
    if key in {r['corpus'] for r in audit['corpora']}:
        continue
    row = plan[key]
    rel = row['corpus'].removeprefix('../')
    path = ROOT / rel
    stored = path if path.exists() else Path(str(path) + '.gz')
    zipped = stored.suffix == '.gz'
    original = baseline / stored.relative_to(ROOT)
    if zipped:
        with gzip.open(stored, 'rb') as src, path.open('wb') as dst:
            shutil.copyfileobj(src, dst)
    manifests = [p for p in [path.parent / 'manifest.json', path.parent / 'cases-manifest.json']
                 if p.exists() and json.loads(p.read_text()).get('file') == path.name]
    assert len(manifests) == 1, (key, manifests)
    manifest_path = manifests[0]
    original_manifest = json.loads((baseline / manifest_path.relative_to(ROOT)).read_text())
    assert digest(path) == original_manifest['sha256']
    spec_file = TMP / (key + '-spec.jsonl')
    run(key + '-spec', ['harness/target/release/spec_recorded', '--corpus', rel,
                        '--out', str(spec_file), '--config', row['spec_config']])
    command = run(key, ['harness/target/release/run_engine', '--engine', 'gosdk', '--corpus', rel,
                       '--spec', str(spec_file), '--words-from', str(TMP / 'saved-sv-node-manifest.json'),
                       '--witnesses', 'corpus/witnesses', '--record'], (0, 1))
    current_sdk = json.loads((ROOT / 'corpus/witnesses/go-sdk/manifest.json').read_text())
    current = current_sdk[key]
    assert current['engine'] == 'go-sdk@v1.7.2' and current['entries'] == row['entries']
    assert current['spec_config'] == row['spec_config'] and current['spec'] == 'spec@cb7e46e'
    if key in old_sdk:
        previous = copy.deepcopy(old_sdk[key])
        history = previous.pop('history', [])
        current['history'] = history + [previous]
    write_json(ROOT / 'corpus/witnesses/go-sdk/manifest.json', current_sdk)
    n = 0
    changes = {'go-sdk@v1.7.2': 0, 'go-sdk-mempool@v1.7.2': 0}
    newly_measured = {'go-sdk@v1.7.2': 0, 'go-sdk-mempool@v1.7.2': 0}
    validity_changes = {k: 0 for k in changes}
    stream = gzip.open(original, 'rt') if zipped else original.open()
    with stream as before, path.open() as after:
        import itertools
        for a, b in itertools.zip_longest(before, after):
            assert a is not None and b is not None, (key, 'entry count changed')
            a, b = json.loads(a), json.loads(b)
            assert a['id'] == b['id']
            old_keys = {k: v for k, v in a['expect'].items() if sdk_key(k)}
            new_keys = {k: v for k, v in b['expect'].items() if sdk_key(k)}
            assert set(new_keys) == set(changes), (key, a['id'], 'missing native key')
            for nk, v in new_keys.items():
                prefix = nk.split('@')[0] + '@'
                ov = [value for k, value in old_keys.items() if k.startswith(prefix)]
                assert len(ov) <= 1
                if not ov:
                    newly_measured[nk] += 1
                else:
                    changes[nk] += v != ov[0]
                    validity_changes[nk] += v['verdict'] != ov[0]['verdict']
            a['expect'] = {k: v for k, v in a['expect'].items() if not sdk_key(k)}
            b['expect'] = {k: v for k, v in b['expect'].items() if not sdk_key(k)}
            assert a == b, (key, a['id'], 'non-go-sdk field changed')
            n += 1
    assert n == row['entries']
    generated_manifest = json.loads(manifest_path.read_text())
    new_impl = [r for r in generated_manifest['implementations'] if sdk_impl(r)]
    assert len(new_impl) == 2 and all(r['version'] == 'v1.7.2' for r in new_impl)
    restored = copy.deepcopy(original_manifest)
    restored['sha256'] = digest(path)
    restored['implementations'] = [r for r in original_manifest['implementations'] if not sdk_impl(r)] + new_impl
    write_json(manifest_path, restored)
    if zipped:
        with path.open('rb') as src, stored.open('wb') as raw:
            with gzip.GzipFile(filename='', mode='wb', fileobj=raw, mtime=0, compresslevel=9) as dst:
                shutil.copyfileobj(src, dst)
        path.unlink()
    result = {'corpus': key, 'path': rel, 'stored': str(stored.relative_to(ROOT)),
              'entries': n, 'spec_config': row['spec_config'], 'command': command,
              'stored_sha256_before': digest(original), 'stored_sha256_after': digest(stored),
              'corpus_sha256_before': original_manifest['sha256'], 'corpus_sha256_after': restored['sha256'],
              'before': counts(old_sdk.get(key)), 'after': counts(current),
              'non_go_fields_equal': True, 'non_go_implementations_preserved': True,
              'native_object_changes': changes, 'native_validity_changes': validity_changes,
              'new_native_columns': newly_measured}
    audit['corpora'].append(result)
    write_json(TMP / 'audit.json', audit)
    print('AUDITED', key, 'agree', current['agree'], 'undecided', current['undecided_runs'],
          'aborts', current['aborts_as_witnesses'], flush=True)

assert protected_hashes == {str(p.relative_to(ROOT)): digest(p) for p in protected}
audit['end'] = now()
audit['all_protected_hashes_equal'] = True
write_json(TMP / 'audit.json', audit)
print('COMPLETE: 26 corpora; 276063 entries audited; classifier and other-engine manifests unchanged', flush=True)
