"""Signer inputs for fixtures_export; all signing is offline and synchronous.

The immutable #145 control columns supply judgments, not the signer classes as
verifier expectations. Regeneration checks every reference and SDK txid against
those columns, and every site digest against the measured trace.
"""
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile


RECORD_COMMIT = '019a4a9c435cd1bdb60da6228fae891e230ee6d5'
RECORD_PREFIX = 'docs/records/20261016-203024-s3-145d-signer-column-'
RECORD_HASHES = {
    'go-sdk': '2bb90c850a526d1b27137dd7643e822caf609d64c9bd62f168dc70f7058a82bb',
    'ts-sdk': '2242c57b81cf887a9d104dc15055886b80b925a84f24a8b81afb6264d1fc0edb',
}
FINDINGS = {'sighash.scriptcode.in-unlock.lock-only', 'sighash.single.out-of-range.one'}


def require(condition, message):
    if not condition:
        raise ValueError('fixtures_export signer: ' + message)


def run(command, root):
    result = subprocess.run(list(map(str, command)), cwd=root, text=True, capture_output=True,
                            env=dict(os.environ, PYTHONDONTWRITEBYTECODE='1', GOPROXY='off',
                                     GOSUMDB='off', GOTOOLCHAIN='local'))
    require(result.returncode == 0, f'{command[0]} exited {result.returncode}: {result.stderr.strip()}')
    return result.stdout


def jsonl(path):
    return [json.loads(line) for line in path.read_text().splitlines() if line.strip()]


def txid(tx):
    return hashlib.sha256(hashlib.sha256(bytes.fromhex(tx)).digest()).digest()[::-1].hex()


def record(root, engine):
    name = RECORD_PREFIX + engine + '-s3.json'
    # Before stack BB lands these files exist only at this local Git object.
    # No fetch, branch checkout or mutable remote-tracking reference is used.
    data = (root / name).read_bytes() if (root / name).is_file() else subprocess.check_output(
        ['git', 'show', f'{RECORD_COMMIT}:{name}'], cwd=root)
    require(hashlib.sha256(data).hexdigest() == RECORD_HASHES[engine], f'{name}: record changed')
    value = json.loads(data)
    require(value['engine'] == engine and value['red'] == 0 and 'GREEN' in value['verdict_line'],
            f'{name}: no GREEN measured column')
    return name, value


def sdk_rows(root, scratch, engine, rows):
    source, target = scratch / 'unsigned.jsonl', scratch / f'{engine}.jsonl'
    source.write_text(''.join(json.dumps(row) + '\n' for row in rows))
    build = Path(os.environ.get('CARGO_TARGET_DIR', root / 'harness/target'))
    if engine == 'go-sdk':
        binary = os.environ.get('GOSDK_SIGNER_BIN', str(build / 'engines/gosdk-signer'))
        run([binary, '--corpus', source, '--out', target], root)
    else:
        adapter = Path(os.environ.get('TS_ADAPTER_DIR', root / 'harness/engines/ts'))
        require((adapter / 'package-lock.json').read_bytes() ==
                (root / 'harness/engines/ts/package-lock.json').read_bytes(), 'TypeScript lock differs')
        modules = (adapter / 'node_modules').resolve()
        require((modules / '@bsv/sdk/package.json').is_file(),
                f'@bsv/sdk node_modules unavailable under {adapter} (npm ci there, or link a sibling worktree\'s)')
        require(json.loads((modules / '@bsv/sdk/package.json').read_text())['version'] == '3.0.0',
                'TypeScript package pin differs')
        (scratch / 'node_modules').symlink_to(modules, target_is_directory=True)
        shutil.copy2(root / 'harness/engines/ts/signer.mjs', scratch / 'signer.mjs')
        node = run(['bash', root / 'tools/node_bin.sh'], root).strip()
        require(run([node, '--version'], root).startswith('v22.'), 'Node 22 required')
        run([node, scratch / 'signer.mjs', '--corpus', source, '--out', target], root)
    result = {}
    for row in jsonl(target):
        key = row['id'], row['method']
        require(key not in result, f'duplicate adapter result {key}')
        result[key] = row
    return result


def build(ctx):
    # Imported here to keep fixtures_export's shape/withholding helpers authoritative.
    from fixtures_export import common_skip, names_of, KNOWN_BITS

    root = Path(ctx.root)
    sources, rows = {}, {}
    for path in sorted((root / 'corpus/signer').glob('*.jsonl')):
        for line, row in enumerate(jsonl(path), 1):
            require(row['id'] not in rows, f'duplicate corpus id {row["id"]}')
            sources[row['id']] = str(path.relative_to(root)), line
            rows[row['id']] = row
    require(bool(rows), 'empty signer corpus')
    records = {engine: record(root, engine) for engine in RECORD_HASHES}
    for name, _ in records.values():
        require(ctx.withheld(name, {}) is None, f'withheld record {name}')
    result, stats = {}, {}
    with tempfile.TemporaryDirectory(prefix='fixtures-signer-') as tmp:
        scratch = Path(tmp)
        binary = os.environ.get('SIGNER_GEN_BIN', str(Path(os.environ.get(
            'CARGO_TARGET_DIR', root / 'harness/target')) / 'release/signer_gen'))
        signed, digests = scratch / 'reference.jsonl', scratch / 'digests.jsonl'
        run([binary, '--sign', root / 'corpus/signer', '--out', signed, '--digests', digests], root)
        controls = {row['id']: row for row in jsonl(signed)}
        sites = {row['id']: row for row in jsonl(digests)}
        require(controls.keys() == rows.keys() == sites.keys(), 'reference coverage differs from corpus')
        spec = None

        for engine, (name, measured) in records.items():
            indexed = {}
            for m in measured['results']:
                require((m['id'], m['method']) not in indexed, 'duplicate measured result')
                indexed[m['id'], m['method']] = m
            # Preserve row/method identity, even when two methods emit identical bytes.
            refused = [m for m in measured['results'] if any(
                trace.get('class') in FINDINGS and trace['divergent']
                for col in m.get('columns', []) for trace in col['inputs'])]
            stored = {(w['id'], w['method']): w['tx_hex'] for w in measured['witnesses'].values()}
            regenerated = sdk_rows(root, scratch, engine, list(rows.values())) if any(
                not m.get('tx_hex') and (m['id'], m['method']) not in stored for m in refused) else {}
            nv, nt = [], []
            count = {'reference_rows': 0, 'reference_node_rows': 0, 'reference_spec_rows': 0,
                     'sdk_refused_rows': 0, 'sighash_rows': 0, 'nonzero_amount_sites': 0,
                     'sdk_refused_input_judgments': 0, 'reference_input_judgments': 0,
                     'excluded_rows': 0, 'finding_classes': {}}

            def emit(row, tx, method, columns, provenance, finding_classes=()):
                rel, line = sources[row['id']]
                require(common_skip(ctx, engine, rel, dict(row, tx=tx)) is None,
                        f'{row["id"]}: signer fixture cannot be exported')
                vid = f'bsl:signer:{row["id"]}:{method}'
                source = (f'bsv-script-lean {rel} {row["id"]}; {provenance}; '
                          f'{RECORD_PREFIX}s3.md at {RECORD_COMMIT}; method {method}; '
                          f'signer finding classes {",".join(finding_classes) or "none"}; '
                          'synthetic prevouts; script judgment only, not mempool admission')
                results = []
                for col in columns:
                    traces = col['inputs']
                    require('spec_verdict' in col or sorted(t['index'] for t in traces) == list(range(len(row['prevouts']))),
                            f'{vid}: incomplete input verdicts')
                    words = {col['flags']} if 'spec_verdict' in col else {t['flags'] for t in traces}
                    require(len(words) == 1 and not next(iter(words)) & ~KNOWN_BITS, f'{vid}: unsupported words')
                    word = next(iter(words))
                    verdicts = [col['spec_verdict']] if 'spec_verdict' in col else [t['verdict'] for t in traces]
                    require(all(v['verdict'] in ('valid', 'invalid') for v in verdicts), f'{vid}: undecided')
                    invalid = next((v for v in verdicts if v['verdict'] == 'invalid'), None)
                    code = invalid['code'] if invalid else ''
                    require(not invalid or code.startswith('SCRIPT_ERR_'), f'{vid}: unknown refusal token')
                    valid = invalid is None
                    results.append({'word': f'0x{word:x}', 'consensus': col['column'] == 'block',
                                    'valid': valid, 'nodeError': code,
                                    'inputVerdicts': traces})
                    nt.append({'id': vid + ':' + col['column'], 'description': source,
                               'input': {'fixture_type': 'node-transaction', 'sources': ['bitcoin-sv'],
                                         'source_file': f'bsv-script-lean:{rel}', 'source_index': line,
                                         'source_id': row['id'], 'signer_method': method,
                                         'input_verdicts': traces,
                                         'tx_hex': tx, 'flag_strings': [','.join(names_of(word))],
                                         'prevouts': [{'txid': p['txid'], 'vout': p['vout'],
                                                       'script_pubkey_hex': p['script'],
                                                       'amount_satoshis': p['satoshis']} for p in row['prevouts']]},
                               'expected': {'valid': valid, 'node_error': code},
                               'tags': ['signer', method, col['column'], *finding_classes], 'notes': source})
                require({c['column'] for c in columns} == {'block', 'relay'}, f'{vid}: missing column')
                nv.append({'id': vid, 'name': row['family'], 'source': source, 'tx': tx,
                           'locks': [p['script'] for p in row['prevouts']],
                           'sats': [p['satoshis'] for p in row['prevouts']],
                           'coinHeights': [p['height'] for p in row['prevouts']],
                           'spend': row['params']['spend_height'], 'results': results})

            for rid, row in rows.items():
                rel, _ = sources[rid]
                if ctx.withheld(rel, row, engine):
                    count['excluded_rows'] += 1
                    continue
                reference = controls[rid]
                own_sites = {(i['index'], s['site']): s for i in sites[rid]['inputs'] for s in i['sites']}
                expected_sites = {(i['index'], j): code for i in row['signing']['inputs']
                                  for j, code in enumerate(i['scriptcode_hex'])}
                require({k: s['scriptcode_hex'] for k, s in own_sites.items()} == expected_sites,
                        f'{rid}: reference scriptCode changed')
                count['nonzero_amount_sites'] += sum(row['prevouts'][i]['satoshis'] != 0 for i, _ in own_sites)
                # Neither pinned node-sighash loader consumes amount_satoshis. All
                # current sites have a nonzero amount, including original-digest sites.
                require(all(row['prevouts'][i]['satoshis'] != 0 for i, _ in own_sites),
                        f'{rid}: zero-amount site needs a sighash fixture implementation')
                candidates = [m for m in measured['results'] if m['id'] == rid and m.get('columns')]
                if not candidates:
                    # The same signing and evaluator path as signer_selfcheck.py.
                    # Aggregate spec judgments are never represented as node/input measurements.
                    if spec is None:
                        spec_path = scratch / 'spec.jsonl'
                        run([root / 'eval/bsvs', 'corpus', signed, '--out', spec_path], root)
                        spec = {r['id']: r for r in jsonl(spec_path)}
                    columns = []
                    for col, key in [('block', 'spec'), ('relay', 'spec-mempool')]:
                        words = {w['word'] for w in measured['words'] if w['consensus'] == (col == 'block')
                                 and w['spend_height'] == row['params']['spend_height']
                                 and all(p['height'] == w['utxo_height'] for p in row['prevouts'])}
                        require(len(words) == 1, f'{rid}: no flag word for spec fallback')
                        columns.append({'column': col, 'inputs': [], 'flags': words.pop(),
                                        'spec_verdict': spec[rid][key]})
                    emit(row, reference['tx'], 'reference', columns,
                         'spec verdict via tools/signer_selfcheck.py signing/evaluator path; no node verdict of record')
                    count['reference_rows'] += 1
                    count['reference_spec_rows'] += 1
                    continue
                control_columns = None
                for m in candidates:
                    require(txid(reference['tx']) == m['control_txid'], f'{rid}: reference txid differs')
                    projected = []
                    for col in m['columns']:
                        inputs = []
                        for trace in col['inputs']:
                            for d in trace['digests']:
                                require(own_sites[trace['index'], d['control']['site']] == d['control'],
                                        f'{rid}: reference digest differs')
                            inputs.append({'index': trace['index'], 'flags': trace['flags'],
                                           'verdict': trace['control']})
                        projected.append({'column': col['column'], 'inputs': inputs})
                    require(control_columns is None or control_columns == projected, f'{rid}: conflicting controls')
                    control_columns = projected
                require(all(all(t['verdict']['verdict'] == 'valid' for t in c['inputs']) ==
                            (row['reference']['expect'] == 'valid') for c in control_columns),
                        f'{rid}: control disagrees with corpus contract')
                emit(row, reference['tx'], 'reference', control_columns, f'node control verdicts from {name}')
                count['reference_rows'] += 1
                count['reference_node_rows'] += 1
                count['reference_input_judgments'] += sum(len(c['inputs']) for c in control_columns)

            for m in refused:
                row = rows[m['id']]
                if ctx.withheld(sources[m['id']][0], row, engine):
                    continue
                sdk = regenerated.get((m['id'], m['method']))
                tx = m.get('tx_hex') or stored.get((m['id'], m['method'])) or (sdk or {}).get('tx_hex')
                require(bool(tx) and txid(tx) == m['txid'], f'{m["id"]}/{m["method"]}: SDK txid differs')
                if sdk:
                    require(sdk['tx_hex'] == tx, f'{m["id"]}: stored SDK hex differs from regeneration')
                columns, findings = [], set()
                for col in m['columns']:
                    traces = []
                    for trace in col['inputs']:
                        if trace['divergent']:
                            require(trace['class'] in FINDINGS, f'{m["id"]}: unexpected signer class')
                            findings.add(trace['class'])
                            count['sdk_refused_input_judgments'] += 1
                        if sdk:
                            sdk_sites = {(s['index'], s['site']): s for s in sdk['inputs']}
                            for d in trace['digests']:
                                actual = sdk_sites[trace['index'], d['sdk']['site']]
                                require({k: actual.get(k) for k in d['sdk']} == d['sdk'],
                                        f'{m["id"]}: SDK trace differs')
                        traces.append({'index': trace['index'], 'flags': trace['flags'], 'verdict': trace['node']})
                    require(any(t['verdict']['verdict'] == 'invalid' for t in traces), 'finding without refusal')
                    columns.append({'column': col['column'], 'inputs': traces})
                emit(row, tx, m['method'], columns, f'node SDK verdicts from {name}; recorded txid {m["txid"]}', sorted(findings))
                count['sdk_refused_rows'] += 1
                for finding in findings:
                    count['finding_classes'][finding] = count['finding_classes'].get(finding, 0) + 1
            result[engine], stats[engine] = (nv, nt), count
    return result, stats, sorted({rel for rel, _ in sources.values()} | {name for name, _ in records.values()})
