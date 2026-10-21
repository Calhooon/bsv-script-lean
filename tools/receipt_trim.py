#!/usr/bin/env python3
"""[D] 2026-10-13 S3: reference projection for committed scenario receipts.

Parameters are hashed as sorted, compact UTF-8 JSON (ensure_ascii=False).
RPC observed_fields contains sorted, unique dotted field paths; array indexes
are represented by []. No RPC bodies or parameter values enter the projection.
Missing historical instance pointers remain null rather than being inferred.
Nested RPCs retain their owned instance ids. Compact undo/stage certificates
retain precondition facts; other fixture scalars and raw snapshots are omitted.
Long hex inside judged projections is represented by its UTF-8 sha256 and
byte size. Tokens redact only the hex substring and also retain a full-token
sha256. This preserves distinctions without committing script or body blobs.
"""
import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess

LIMIT = 10_000_000
LONG_HEX = re.compile(r'(?:0x)?[0-9a-fA-F]{65,}')
DROP = object()
RAW_KEYS = {'raw', 'hex', 'frame_hex', 'request', 'response', 'reply', 'replies',
            'params', 'body', 'bodies', 'rawtransaction', 'raw_transaction',
            'rpc_receipt', 'log', 'logs', 'completion', 'earlier_launch_errors'}
# [D] 2026-10-13 S3, lane fix-pend3: compact precondition/stage certificates.
CERTIFICATES = {'undo_witness', 'undo_edit', 'stage_witness'}
PAYLOAD_KEYS = {'old_payload', 'new_payload', 'removed'}
ROW_FIELDS = {
    'id', 'case', 'label', 'token', 'node', 'build', 'expected', 'expected_label',
    'observed', 'verdict', 'projection_verdict', 'qualifier', 'classification',
    'comparison_scope', 'unobservable_reason_detail', 'declared_expected',
    'isolated_stage_expected', 'observation_basis', 'recipe', 'remap',
    'spec_only', 'spec_only_fields', 'unrealizable', 'needs_peer',
    'rpc_precheck', 'rpc_judgment', 'client_label', 'scope',
}


def canonical(value):
    return json.dumps(value, sort_keys=True, separators=(',', ':'),
                      ensure_ascii=False).encode('utf-8')


def observed_fields(value, prefix=''):
    fields = set()
    if isinstance(value, dict):
        for key, child in value.items():
            path = f'{prefix}.{key}' if prefix else key
            fields.add(path)
            fields.update(observed_fields(child, path))
    elif isinstance(value, list):
        for child in value:
            fields.update(observed_fields(child, prefix + '[]'))
    return fields


def relative_path(value, run_id):
    marker = 'spec-oracle-scenarios/'
    if marker in value:
        value = value.split(marker, 1)[1]
    if run_id and value.startswith(run_id + '/'):
        return value[len(run_id) + 1:]
    if value == run_id:
        return '.'
    return value


def raw_key(key):
    return (key in RAW_KEYS or key.endswith(('_log', '_logs', '_reply', '_replies'))
            or key.startswith('raw_'))


def fixture_metadata(value, run_id):
    """Retain nested RPC summaries and instance/retry metadata, never snapshots."""
    if isinstance(value, dict):
        if isinstance(value.get('method'), str):
            return project(value, run_id)
        if value.get('lifecycle') == 'binary':
            return project({key: value[key] for key in
                            ('lifecycle', 'build', 'binary', 'sha256', 'source')
                            if key in value}, run_id)
        result = {}
        for key, child in value.items():
            if raw_key(key):
                continue
            if key in CERTIFICATES:
                trimmed = certificate(child, run_id)
            elif key in ('instance_id', 'datadir', 'path', 'file', 'lifecycle',
                       'startup_attempts', 'retry_count', 'attempt'):
                trimmed = project(child, run_id)
            else:
                trimmed = fixture_metadata(child, run_id)
            if trimmed is not DROP:
                result[key] = trimmed
        return result if result else DROP
    if isinstance(value, list):
        result = [trimmed for child in value
                  if (trimmed := fixture_metadata(child, run_id)) is not DROP]
        return result if result else DROP
    return DROP


def certificate(value, run_id):
    """Keep compact facts and hex commitments; raw edit payloads stay archived."""
    if isinstance(value, dict):
        return {key: certificate(child, run_id) for key, child in value.items()
                if not raw_key(key) and key not in PAYLOAD_KEYS}
    if isinstance(value, list):
        return [certificate(child, run_id) for child in value]
    return project(value, run_id, commitments=True)


def project(value, run_id='', commitments=False):
    if isinstance(value, dict):
        if isinstance(value.get('method'), str):
            return {
                'method': value['method'],
                'instance_id': (relative_path(value['instance_id'], run_id)
                                if isinstance(value.get('instance_id'), str) else None),
                'params_sha256': hashlib.sha256(canonical(value.get('params'))).hexdigest(),
                'observed_fields': sorted(observed_fields(
                    value.get('reply', value.get('response', {})))),
            }
        result = {}
        for key, child in value.items():
            if not commitments and (raw_key(key) or LONG_HEX.search(key)):
                continue
            trimmed = (fixture_metadata(child, run_id) if key == 'fixtures'
                       else project(child, run_id, commitments or key in (
                           'expected', 'observed', 'declared_expected', 'isolated_stage_expected')))
            if trimmed is not DROP:
                result[key] = trimmed
        return result
    if isinstance(value, list):
        return [trimmed for child in value
                if (trimmed := project(child, run_id, commitments)) is not DROP]
    if isinstance(value, str):
        if LONG_HEX.search(value):
            if not commitments:
                return DROP
            if LONG_HEX.fullmatch(value):
                raw = value.encode('utf-8')
                return {'omitted': 'hex', 'sha256': hashlib.sha256(raw).hexdigest(),
                        'bytes': len(raw), 'encoding': 'utf-8'}
            return LONG_HEX.sub(lambda match: (
                f"[hex sha256={hashlib.sha256(match[0].encode('utf-8')).hexdigest()} "
                f"bytes={len(match[0].encode('utf-8'))}]"), value)
        return relative_path(value, run_id)
    return value


def token(row, record):
    """Preserve supplied tokens; reproduce the runner's historical row token."""
    if 'token' in row or 'node' in row:
        return row.get('token', row.get('node'))
    if 'unrealizable' in row:
        return f"unrealizable: {row['unrealizable']} [X] {record}"
    if 'needs_peer' in row:
        return f'needs-peer #71 [X] {record}'
    if row.get('verdict') == 'rpc-precheck':
        pre = row['rpc_precheck']
        return f"rpc-precheck: {pre['code']} {pre['message']} ({pre['handler']}) [X] {record}"
    build = f" ({row['build']})" if row.get('build') else ''
    if row.get('classification') == 'observation limit (reason detail)':
        return (f"measured agree{build}: rejected {row['observed']['reason']} "
                f'(detail not surfaced by submitblock: src/validation.cpp:3690-3715) [X] {record}')
    if row.get('classification') == 'scope limit':
        return (f'measured agree{build}: rejected 259 non-final-pool-full '
                f'(scope: full admission; the isolated stage says heldNonFinal) [X] {record}')
    if 'verdict' not in row:
        return None
    qualifier = f" [{row['qualifier']}]" if row.get('qualifier') else ''
    observed = canonical(row.get('observed')).decode('utf-8')
    return f"measured {row['verdict']}{build}: {observed}{qualifier} [X] {record}"


def pointers(value, run_id):
    found = set()
    if isinstance(value, dict):
        for key, child in value.items():
            if key in ('datadir', 'instance', 'instance_id', 'path', 'file') and isinstance(child, str):
                found.add(relative_path(child, run_id))
            elif key not in ('params', 'reply', 'response'):
                found.update(pointers(child, run_id))
    elif isinstance(value, list):
        for child in value:
            found.update(pointers(child, run_id))
    return found


def row_projection(row, record, run_id):
    result = project({key: child for key, child in row.items() if key in ROW_FIELDS}, run_id)
    metadata = fixture_metadata(row, run_id)
    if metadata is not DROP:
        for key, child in metadata.items():
            result.setdefault(key, child)
    for key in ('id', 'case', 'label', 'expected', 'observed', 'verdict'):
        result.setdefault(key, None)
    original_token = token(row, record)
    saved_token = project(original_token, run_id, commitments=True)
    result['token'] = None if saved_token is DROP else saved_token
    result['token_sha256'] = (hashlib.sha256(original_token.encode('utf-8')).hexdigest()
                              if isinstance(original_token, str) else None)
    def retries(value):
        if isinstance(value, dict):
            return sum(len(child) if key == 'unsettled_attempts' and isinstance(child, list)
                       else retries(child) for key, child in value.items()
                       if key not in ('params', 'reply', 'response'))
        if isinstance(value, list):
            return sum(retries(child) for child in value)
        return 0
    result['retry_count'] = row.get('retry_count', retries(row.get('fixtures', {})))
    paths = sorted(pointers(row, run_id))
    result['run_relative_paths'] = paths
    # [D] 2026-10-13 S3: nested attempts, calibration and retries own RPCs too.
    # Datadir and instance-id pointers identify instances; files alone do not.
    def owners(value):
        if isinstance(value, dict):
            for key, child in value.items():
                if key in ('datadir', 'instance_id') and isinstance(child, str):
                    yield relative_path(child, run_id)
                elif key not in ('params', 'reply', 'response'):
                    yield from owners(child)
        elif isinstance(value, list):
            for child in value:
                yield from owners(child)
    instances = sorted(set(owners(row)))
    result['instance_ids'] = instances
    result['instance_id'] = instances[0] if len(instances) == 1 else None
    return result


def trim_receipt(value, full_path, full_sha256, full_bytes):
    run_id = value.get('run_id', '')
    result = project({key: child for key, child in value.items()
                      if key not in ('families', 'scenarios')}, run_id)
    record = value.get('record', '')
    result['families'] = {
        family: [row_projection(row, record, run_id) for row in rows]
        for family, rows in value.get('families', {}).items()
    }
    result['scenarios'] = []
    for original in value.get('scenarios', []):
        trimmed = project({key: child for key, child in original.items()
                           if key in ('counts', 'record', 'scenario', 'source_pin', 'scope')}, run_id)
        launches = fixture_metadata(original.get('launches', []), run_id)
        if launches is not DROP:
            trimmed['launches'] = launches
        trimmed['steps'] = [row_projection(row, original.get('record', record), run_id)
                            for row in original.get('steps', [])]
        result['scenarios'].append(trimmed)
    result['receipt_shape'] = 'trimmed-s3-v1'
    result['projection_encoding'] = 'long hex: sha256 and size of original UTF-8 string'
    result['full_receipt'] = {'path': str(full_path), 'sha256': full_sha256,
                              'bytes': full_bytes, 'label': '[M]'}
    return result


def oversized(path):
    paths = sorted(path.rglob('*.json')) if path.is_dir() else [path]
    for candidate in paths:
        size = candidate.stat().st_size
        if size <= LIMIT:
            continue
        yield candidate, size


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('full', nargs='?', type=Path)
    parser.add_argument('trimmed', nargs='?', type=Path)
    parser.add_argument('--check', type=Path)
    parser.add_argument('--record', type=Path)
    args = parser.parse_args()
    if args.check:
        failures = list(oversized(args.check))
        for path, size in failures:
            print(f'receipt size: RED [X] {path}: {size} bytes > {LIMIT}')
        if not failures:
            print(f'receipt size: GREEN [X] ({args.check}; limit {LIMIT} bytes)')
        return int(bool(failures))
    if not args.full or not args.trimmed:
        parser.error('supply FULL TRIMMED, or --check PATH')
    if args.full.resolve() == args.trimmed.resolve():
        parser.error('full and trimmed paths must differ')
    if args.record and (args.record.suffix != '.md' or args.record.resolve() in (
            args.full.resolve(), args.trimmed.resolve())):
        parser.error('record must be a separate Markdown path')
    raw = args.full.read_bytes()
    digest = hashlib.sha256(raw).hexdigest()
    value = json.loads(raw)
    projected = trim_receipt(value, args.full, digest, len(raw))
    output = canonical(projected) + b'\n'
    if len(output) > LIMIT:
        parser.error(f'trimmed receipt exceeds {LIMIT} bytes: {len(output)}')
    args.trimmed.parent.mkdir(parents=True, exist_ok=True)
    temp = args.trimmed.with_suffix('.json.tmp')
    temp.write_bytes(output)
    temp.replace(args.trimmed)
    if args.record:
        dated = subprocess.check_output(['date', '-u', '+%Y-%m-%dT%H:%M:%SZ'], text=True).strip()
        sentence = (f'[M] {dated}, S3: the committed JSON is the trimmed projection; '
                    f'the full receipt is `{args.full}`, sha256 `{digest}`, {len(raw)} bytes.\n')
        previous = args.record.read_text() if args.record.exists() else '# Scenario receipt\n'
        args.record.write_text(previous.rstrip() + '\n\n' + sentence)
    print(f'receipt trim: [M] sha256 {digest}; full {len(raw)} bytes; trimmed {len(output)} bytes')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
