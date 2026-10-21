#!/usr/bin/env python3
"""#146: synchronous fixture proof with checked child verdicts and a retained receipt.

RULES_CHECK_BIN selects an already-built classifier; otherwise cargo builds it offline.
GO_BIN selects Go. TS_ADAPTER_DIR may select a lockfile-equal installed adapter; its
dependencies are used with a scratch copy of this tree's proof, never its older code.
FIXTURES_PROOF_OUT selects the receipt parent. No package installer is invoked.
"""
import hashlib
import json
import os
from pathlib import Path
import re
import shlex
import shutil
import subprocess
import sys
import tempfile


class Failure(Exception):
    def __init__(self, reason, code=1, skipped=False):
        super().__init__(reason)
        self.code = code
        self.skipped = skipped


SUMMARY = re.compile(r'^SUMMARY (.+): (\d+) rows, agree (\d+), divergent by class (\d+) \[(.*)\], RED (\d+)$')


def checked_summaries(text, expected):
    found = {}
    for line in text.splitlines():
        if not line.startswith('SUMMARY '):
            continue
        match = SUMMARY.fullmatch(line)
        if not match:
            raise Failure('malformed proof summary')
        name, rows, agree, divergent, classes, red = match.groups()
        rows, agree, divergent, red = map(int, (rows, agree, divergent, red))
        class_count = sum(int(p.rsplit(' ', 1)[1]) for p in classes.split('; ') if p)
        if name in found or rows <= 0 or rows != expected.get(name) or red != 0 or agree + divergent != rows or class_count != divergent:
            raise Failure(f'{name}: empty, duplicate, RED or inconsistent summary')
        found[name] = line
    if found.keys() != expected.keys():
        raise Failure('missing required proof summaries')
    return list(found.values())


def executable(name):
    path = shutil.which(name)
    if path is None:
        raise Failure(f'{name} unavailable', 2, True)
    return path


def run(root, out, receipt):
    env = dict(os.environ, GOPROXY='off', GOTOOLCHAIN='local', GOFLAGS='-mod=readonly',
               CARGO_BUILD_JOBS='4', CARGO_NET_OFFLINE='true', PYTHONDONTWRITEBYTECODE='1')
    env.setdefault('CARGO_TARGET_DIR', str(Path.home() / 'bsv/targets/fix-fixtures-146'))
    env.setdefault('TMPDIR', str(Path.home() / 'bsv/targets/fix-fixtures-146/tmp'))
    env.setdefault('GOCACHE', str(Path(env['CARGO_TARGET_DIR']) / 'go-cache'))
    env.setdefault('GOTMPDIR', env['TMPDIR'])
    Path(env['TMPDIR']).mkdir(parents=True, exist_ok=True)
    receipt['environment'] = {k: env[k] for k in ('GOPROXY', 'GOTOOLCHAIN', 'GOFLAGS', 'GOCACHE', 'GOTMPDIR', 'CARGO_BUILD_JOBS', 'CARGO_TARGET_DIR', 'TMPDIR')}

    def child(name, command, cwd=root):
        log = out / f'{name}.txt'
        step = {'name': name, 'command': shlex.join(map(str, command)), 'cwd': str(cwd), 'log': str(log)}
        receipt['commands'].append(step)
        with log.open('w') as stream:
            result = subprocess.run(command, cwd=cwd, env=env, stdout=stream, stderr=subprocess.STDOUT, check=False)
        step['exit'] = result.returncode
        text = log.read_text()
        step['verdicts'] = [s for s in text.splitlines() if s.startswith(('rules_check: GREEN', 'rules_check: RED', 'SUMMARY ', 'fixtures: RED', 'NEW FINDING ', 'RED '))]
        for line in step['verdicts']:
            print(line, flush=True)
        if result.returncode:
            raise Failure(f'{name} exited {result.returncode}; see {log}', result.returncode if result.returncode > 0 else 128 - result.returncode)
        return text

    git = executable('git')
    receipt['reviewed_commit'] = child('commit', [git, 'rev-parse', 'HEAD']).strip()
    receipt['worktree_status'] = child('status', [git, 'status', '--short']).splitlines()
    receipt['source_sha256'] = {
        name: hashlib.sha256((root / name).read_bytes()).hexdigest()
        for name in ('Makefile', 'tools/fixtures_proof.py', 'harness/engines/go/fixtures/main.go',
                     'harness/engines/ts/fixtures.mjs') if (root / name).is_file()
    }
    manifest = json.loads((root / 'corpus/fixtures/manifest.json').read_text())
    receipt['pins'] = manifest['pins']
    receipt['node'] = manifest['node']
    receipt['files'] = manifest['files']
    receipt['manifest_sha256'] = hashlib.sha256((root / 'corpus/fixtures/manifest.json').read_bytes()).hexdigest()
    files = manifest['files']
    expectations = {
        'go': {'go-sdk/node_vectors.json': files['go-sdk/node_vectors.json']['results'],
               'go-sdk/script_tests.json': files['go-sdk/script_tests.json']['rows'],
               'go-sdk/evaluation.json': files['go-sdk/evaluation.json']['node-sighash'],
               'go-sdk/signer/node_vectors.json': files['go-sdk/signer/node_vectors.json']['results']},
        'ts': {f'{name} {kind}': info[kind] for name, info in files.items()
               if name.startswith('ts-sdk/') for kind in ('node-sighash', 'node-transaction') if kind in info},
    }
    if any(type(n) is not int or n <= 0 for group in expectations.values() for n in group.values()):
        raise Failure('empty or invalid manifest coverage')
    for name, info in files.items():
        if hashlib.sha256((root / 'corpus/fixtures' / name).read_bytes()).hexdigest() != info['sha256']:
            raise Failure(f'{name}: manifest sha256 mismatch')

    classifier = os.environ.get('RULES_CHECK_BIN')
    classifier = [executable(classifier)] if classifier else [executable('cargo'), 'run', '--offline', '--release', '--locked', '--quiet', '--bin', 'rules_check', '--']
    go = executable(os.environ.get('GO_BIN', 'go'))
    bash = executable('bash')
    try:
        node = executable(child('node-path', [bash, str(root / 'tools/node_bin.sh')]).strip())
    except Failure as error:
        raise Failure('node unavailable', 2, True) from error
    if not child('node-version', [node, '--version']).strip().startswith('v22.'):
        raise Failure('Node 22 required', 2, True)
    child('go-version', [go, 'version'])
    adapter = Path(os.environ.get('TS_ADAPTER_DIR', root / 'harness/engines/ts')).resolve()
    if (adapter / 'package-lock.json').read_bytes() != (root / 'harness/engines/ts/package-lock.json').read_bytes():
        raise Failure('TS_ADAPTER_DIR lockfile differs')
    modules = adapter / 'node_modules'
    if not (modules / '@bsv/sdk/package.json').is_file():
        raise Failure('@bsv/sdk node_modules unavailable', 2, True)
    if json.loads((modules / '@bsv/sdk/package.json').read_text())['version'] != '3.0.0':
        raise Failure('@bsv/sdk 3.0.0 required')
    receipt['ts_dependencies'] = str(modules)
    receipt['adapter_lock_sha256'] = hashlib.sha256((adapter / 'package-lock.json').read_bytes()).hexdigest()
    work = out / 'adapter'
    work.mkdir()
    (work / 'node_modules').symlink_to(modules, target_is_directory=True)
    shutil.copy2(root / 'harness/engines/ts/fixtures.mjs', work / 'fixtures.mjs')

    # Both classifier invocations finish successfully before either SDK proof starts.
    env['RULES_CHECK_LIST'] = str(out / 'classes.tsv')
    for engine in ('go-sdk', 'ts-sdk'):
        if len(classifier) > 1:
            receipt['uptime'] = child(f'{engine}-uptime', ['uptime']).strip()
            if os.getloadavg()[0] >= 20:
                raise Failure('build load must be under 20')
        text = child(f'{engine}.rules', classifier + ['--root', str(root), '--engine', engine], root / 'harness')
        greens = [s for s in text.splitlines() if s.startswith('rules_check: GREEN')]
        if len(greens) != 1 or re.search(r'\bRED\b', text):
            raise Failure(f'{engine} classifier GREEN verdict missing or RED present')
    if not (out / 'classes.tsv').is_file():
        raise Failure('classifier did not write classes.tsv (rebuild rules_check)')

    receipt['uptime'] = child('go-uptime', ['uptime']).strip()
    if os.getloadavg()[0] >= 20:
        raise Failure('build load must be under 20')
    texts = {'go': child('go', [go, 'run', './fixtures', '--root', str(root), '--classes', str(out / 'classes.tsv')], root / 'harness/engines/go'),
             'ts': child('ts', [node, str(work / 'fixtures.mjs'), str(root), str(out / 'classes.tsv')])}
    receipt['summaries'] = [line for name, text in texts.items() for line in checked_summaries(text, expectations[name])]


def main():
    root = Path(__file__).resolve().parent.parent
    parent = Path(os.environ.get('FIXTURES_PROOF_OUT', '<lanes-volume>/out/bsv-script-lean/fixtures-proof' if Path('<lanes-volume>').is_dir() else str(Path.home() / 'bsv/targets/fixtures-proof')))
    parent.mkdir(parents=True, exist_ok=True)
    stamp = subprocess.check_output(['date', '-u', '+%Y%m%d-%H%M%SZ'], text=True).strip()
    out = Path(tempfile.mkdtemp(prefix=stamp + '-', dir=parent))
    receipt = {'utc': stamp, 'commands': []}
    code = 0
    try:
        run(root, out, receipt)
        verdict = f'fixtures-proof: GREEN [X] ({len(receipt["summaries"])} summaries checked; RED 0)'
    except Failure as error:
        code = error.code
        verdict = f'fixtures-proof: {"SKIPPED BY NAME" if error.skipped else "RED"} ({error})'
    except (OSError, ValueError, KeyError, TypeError) as error:
        code = 1
        verdict = f'fixtures-proof: RED ({error})'
    receipt.update(verdict=verdict, exit=code)
    path = out / 'receipt.json'
    path.write_text(json.dumps(receipt, indent=2) + '\n')
    print(verdict)
    print(f'record: {path}')
    return code


if __name__ == '__main__':
    sys.exit(main())
