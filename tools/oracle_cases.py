#!/usr/bin/env python3
"""#76: wrapper-call inputs from #61's public script fixtures.

This emits inputs only. oraclecheck --record measures the spec column [M].
The ordinary agreement family is the existing cpp-sigopcount (six rows);
this supplement supplies call schedules and exact resource-selector contexts
absent from its columns. No node measurement is claimed.
[SRC] src/validation.cpp:1328-1347,1411-1423,705-717,2693-2707,2738-2837
at 6504a3aff65ba97c0f6c80962b033e35ecbfed4b.
"""
from __future__ import annotations

import argparse
from copy import deepcopy
import hashlib
import json
from pathlib import Path

import utxo_cases as utxo

ROOT = Path(__file__).resolve().parents[1]
PIN = '6504a3aff65ba97c0f6c80962b033e35ecbfed4b'
SOURCE = ('[SRC] src/validation.cpp:1328-1347,1411-1423,705-717,2693-2707,2738-2837 '
          'at ' + PIN)
CORPUS = ROOT / 'corpus/chain/oracle/oracle.jsonl'


def request(word='block', consensus=True, stage='input', excluded=0, flags=0):
    return dict(word=word, consensus=consensus, stage=stage, excluded=excluded, flags=flags)


def adapt(row, name=None, req=None, column=None):
    cfg = deepcopy(row['config'])
    cfg['maxScriptNumLengthPolicy'] = 10000
    ctx = row['context']
    if req is None:
        req = request('explicit' if ctx['flags'] is not None else
                      ('block' if ctx['blockWord'] else 'relay'),
                      ctx['consensus'], flags=ctx['flags'] or 0)
    return dict(id='oracle/' + (name or row['id']), family='chain/oracle', source=SOURCE,
                material=row['id'], tx=row['tx'], utxo=deepcopy(row['utxo']),
                config=cfg, context=deepcopy(ctx), input=0, request=req,
                column=column or ('spec' if req['consensus'] else 'spec-mempool'))


def fresh(name, locking, *, version=1, height=20):
    row = utxo.base(name, 'oracle', [utxo.coin(locking=locking, height=height)])
    row['transaction']['version'] = version
    row['tx'] = utxo.txhex(row.pop('transaction'))
    return row


def inline(row, prefix=None, message=None, *, code=0x40, genesis=False, chronicle=False, retry=False):
    expected = dict(status='ok') if prefix is None else dict(
        status='rejected', code=code, reason=f'{prefix} ({message})')
    row['inline'] = dict(genesisGrace=genesis, chronicleGrace=chronicle,
                         requiresRecheck=retry, expected=expected)
    return row


def rows():
    source = [json.loads(line) for line in
              (ROOT / 'corpus/chain/utxo/utxo.jsonl').read_text().splitlines()]
    result = [adapt(row) for row in source if row['id'].startswith('scripts/')]
    # Literal rejection mappings are [D] from the cited wrapper; only the
    # script verdict and effective parameters are measured by --record.
    base = fresh('minimal-push', '4c01015187')
    result.append(inline(adapt(base, 'relay/minimal-push', request('relay', False)),
                         'non-mandatory-script-verify-flag', 'Data push larger than necessary', retry=True))
    result.append(adapt(base, 'relay/minimal-push-recheck',
                        request('relay', False, 'modified-mandatory'), 'spec-mempool'))
    result.append(inline(adapt(base, 'relay/exclude-minimaldata', request('relay', False, excluded=1 << 6))))
    # SIGPUSHONLY is re-added by InputScriptVerifyFlags after exclusions.
    result.append(inline(adapt(base, 'relay/exclude-before-input',
                               request('relay', False, excluded=(1 << 6) | (1 << 5)))))
    result.append(inline(adapt(base, 'outer/mandatory', request('mandatory', False))))
    sized = fresh('size-selector', '515187')
    sized['config']['maxScriptSizePolicy'] = 1
    result.append(inline(adapt(sized, 'limits/block-word-policy', request('block', False)),
                         'non-mandatory-script-verify-flag', 'Script is too big', retry=True))
    result.append(adapt(sized, 'limits/modified-mandatory',
                        request('block', False, 'modified-mandatory'), 'spec-mempool'))
    result.append(inline(adapt(sized, 'limits/block-word-consensus', request('block', True))))
    bad = fresh('false', '00')
    result.append(inline(adapt(bad, 'relay/mandatory-failure', request('relay', False)),
                         'mandatory-script-verify-flag-failed',
                         'Script evaluated without error but finished with a false/empty top stack element',
                         code=0x10, retry=True))
    result.append(adapt(bad, 'relay/mandatory-failure-recheck',
                        request('relay', False, 'modified-mandatory'), 'spec-mempool'))
    grace = fresh('genesis-grace', '516a', height=9)
    grace['context']['height'] = 10
    grace['context']['tipHeight'] = 9
    result.append(inline(adapt(grace, 'grace/genesis', request('relay', False)),
                         'genesis-script-verify-flag-failed', 'OP_RETURN was encountered', genesis=True, retry=True))
    result.append(adapt(grace, 'grace/genesis-mandatory',
                        request('relay', False, 'modified-mandatory'), 'spec-mempool'))
    result.append(adapt(grace, 'grace/genesis-inverse',
                        request('relay', False, 'inverse-genesis'), 'spec-mempool'))
    # Full prevout context and separate input keys on one multi-input spend.
    pair = utxo.base('two-inputs', 'oracle', [utxo.coin(1, locking='51', height=20),
                                            utxo.coin(2, locking='00', height=20)])
    pair['tx'] = utxo.txhex(pair.pop('transaction'))
    result.append(adapt(pair, 'multi/input-0'))
    row = adapt(pair, 'multi/input-1'); row['input'] = 1; result.append(row)
    return result


def manifest():
    data = CORPUS.read_bytes()
    recorded = [json.loads(line) for line in data.splitlines()]
    seed = rows()
    for expected, actual in zip(seed, recorded, strict=True):
        stripped = {k: v for k, v in actual.items() if k not in ('label', 'effective', 'expect', 'node')}
        if expected != stripped or actual['label'] != '[M]':
            raise SystemExit('oracle inputs differ from generator')
    return dict(corpus='chain/oracle', file='oracle.jsonl', count=len(recorded),
                sha256=hashlib.sha256(data).hexdigest(),
                generator='tools/oracle_cases.py; oraclecheck --record',
                source_pin=PIN, material='corpus/chain/utxo/utxo.jsonl script rows and wrapper variants',
                columns=['spec', 'spec-mempool'], verdict_label='[M]',
                evaluator='BsvChain.evalOracle via BsvScript.Eval.verifyScript',
                oracle_source_sha256=hashlib.sha256((ROOT / 'lean/BsvChain/Oracle.lean').read_bytes()).hexdigest(),
                key='column + structural transaction + all prevouts + input + coinHeight + spendHeight + exact EvalParams',
                node=('pending #66' if all('node' not in r for r in recorded) else 'per-row [X] observations in oracle.jsonl'), inline_expectations='[D] pinned source rejection mapping')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, help='write deterministic unrecorded call inputs')
    parser.add_argument('--manifest', action='store_true', help='index the measured corpus')
    parser.add_argument('--check', action='store_true', help='check inputs and measured manifest')
    args = parser.parse_args()
    if args.output:
        args.output.write_text(''.join(json.dumps(r, sort_keys=True, separators=(',', ':')) + '\n' for r in rows()))
        print(f'oracle inputs: {len(rows())} rows [D]')
    elif args.manifest:
        CORPUS.with_name('manifest.json').write_text(json.dumps(manifest(), indent=2) + '\n')
        print(f'oracle manifest: {len(rows())} measured rows [M]')
    elif args.check:
        if json.loads(CORPUS.with_name('manifest.json').read_text()) != manifest():
            raise SystemExit('oracle manifest: stale')
        print(f'oracle corpus: GREEN ({len(rows())} inputs and measured manifest)')
    else:
        parser.error('choose --output, --manifest or --check')


if __name__ == '__main__':
    main()
