#!/usr/bin/env python3
"""[D] Source-derived #62 witnesses, never captured node answers.

[SRC] bitcoin-sv 6504a3aff65ba97c0f6c80962b033e35ecbfed4b:
validation.cpp:895–946,1031–1494; txmempool.cpp:2201–2220,2704–2798;
time_locked_mempool.cpp:35–97,516–660; orphan_txns.cpp:168–350.
All transactions are synthetic. Byte-only accounting is an explicit abstraction;
node measurements, pointer ties and scheduler observations remain pending #66.
"""
from __future__ import annotations
import argparse
from copy import deepcopy
import hashlib
import json
from pathlib import Path
import struct

PIN = '6504a3aff65ba97c0f6c80962b033e35ecbfed4b'
SOURCE = f'https://github.com/bitcoin-sv/bitcoin-sv/blob/{PIN}/src/'
OUT = Path(__file__).resolve().parents[1] / 'corpus/chain/mempool/mempool.jsonl'
STAGES = ['regular', 'standard', 'finality', 'alreadyKnown', 'conflict', 'inputs', 'sequence',
          'inputStandard', 'sigops', 'fee', 'ancestors', 'scripts', 'detector', 'commit']
LINES = dict(zip(STAGES, ['1031-L1061', '1072-L1088', '1094-L1138', '1142-L1145', '1147-L1152',
                         '1157-L1193', '1199-L1203', '1206-L1233', '1235-L1246', '1249-L1294',
                         '1301-L1318', '1320-L1482', '1484-L1494', '895-L946']))


def varint(n):
    if n < 253:
        return bytes([n])
    if n < 65536:
        return b'\xfd' + struct.pack('<H', n)
    return b'\xfe' + struct.pack('<I', n)


def tx(inputs=None, outputs=None, lock=0, version=2):
    inputs = [(bytes([1])*32, 0, b'', 0xffffffff)] if inputs is None else inputs
    outputs = [(900, b'\x51')] if outputs is None else outputs
    raw = struct.pack('<I', version) + varint(len(inputs))
    for h, n, script, seq in inputs:
        raw += h + struct.pack('<I', n) + varint(len(script)) + script + struct.pack('<I', seq)
    raw += varint(len(outputs))
    for value, script in outputs:
        raw += struct.pack('<q', value) + varint(len(script)) + script
    return (raw + struct.pack('<I', lock)).hex()


def txid(raw):
    return hashlib.sha256(hashlib.sha256(bytes.fromhex(raw)).digest()).hexdigest()


def spend(parent, n=0, sequence=0xffffffff, **kw):
    return tx(inputs=[(bytes.fromhex(txid(parent)), n, b'', sequence)], **kw)


def entry(raw, **kw):
    return dict(tx=raw, **kw)


def coin(h='01'*32, **kw):
    return dict(hash=h, index=0, **kw)


def cases():
    rows = []
    base = tx()
    basecoin = [coin()]

    def row(name, stage='commit', status='accepted', code=None, reason=None, **kwargs):
        expected = dict(status=status)
        if kwargs.get('action', 'accept') == 'accept':
            expected.update(stage=stage, trace=STAGES[:STAGES.index(stage)+1])
        if code is not None:
            expected.update(code=code, reason=reason)
        expected.update(kwargs.pop('expect', {}))
        source = kwargs.pop('source', SOURCE + 'validation.cpp#L' + LINES.get(stage, '895-L946'))
        r = dict(id=name, label='[D]', node='pending #66', boundary=stage, source=source,
                 tx=base, utxo=basecoin, expected=expected)
        r.update(deepcopy(kwargs))
        rows.append(r)

    def reject(name, stage, code, reason, **kw):
        row(name, stage, 'rejected', code, reason, **kw)

    row('baseline-valid', expect={'accepted': [txid(base)], 'held': [], 'orphans': [], 'spentCount': 1})
    reject('regular-empty-inputs', 'regular', 0x10, 'bad-txns-vin-empty', tx=tx(inputs=[]))
    reject('regular-empty-outputs', 'regular', 0x10, 'bad-txns-vout-empty', tx=tx(outputs=[]))
    reject('regular-duplicate-input', 'regular', 0x10, 'bad-txns-inputs-duplicate',
           tx=tx(inputs=[(bytes([1])*32, 0, b'', 0xffffffff)]*2))
    reject('standard-output-disabled', 'standard', 0x40, 'scriptpubkey', cfg={'acceptNonStdOutputs': False})
    row('standard-output-enabled', cfg={'acceptNonStdOutputs': True})
    reject('standard-version', 'standard', 0x40, 'version', tx=tx(version=3))
    nonfinal = tx(inputs=[(bytes([1])*32, 0, b'', 0xfffffffe)], lock=201)
    row('nonfinal-held-height-equality', tx=nonfinal, expect={'accepted': [], 'held': [txid(nonfinal)]}, status='heldNonFinal')
    reject('nonfinal-disabled-pool', 'finality', 0x103, 'non-final-pool-full', tx=nonfinal,
           cfg={'maxMempoolNonFinal': 0})
    reject('nonfinal-pre-genesis', 'finality', 0x40, 'bad-txns-nonfinal', tx=nonfinal,
           context={'genesisHeight': 10000}, cfg={'requireStandard': False})
    reject('already-accepted', 'alreadyKnown', 0x101, 'txn-already-in-mempool', pool={'accepted': [entry(base)]})
    competitor = tx(outputs=[(800, b'\x51')])
    reject('accepted-spend-conflict', 'conflict', 0x102, 'txn-mempool-conflict', tx=competitor,
           pool={'accepted': [entry(base)]}, expect={'accepted': [txid(base)], 'spentCount': 1})
    final_by_height = tx(inputs=[(bytes([1])*32, 0, b'', 0xfffffffd)], lock=199)
    reject('held-lock-conflict', 'conflict', 0x102, 'txn-mempool-conflict', tx=final_by_height,
           pool={'nonFinal': [entry(nonfinal)]}, expect={'held': [txid(nonfinal)], 'accepted': []})
    row('held-finalising-update-queues', status='deferred', tx=competitor, pool={'nonFinal': [entry(nonfinal)]},
        expect={'held': [], 'accepted': [], 'pending': [txid(competitor)]})
    row('missing-input-orphan-retained', 'inputs', 'orphan', utxo=[], request={'orphanHandler': True},
        expect={'orphans': [txid(base)], 'accepted': []})
    row('missing-input-rpc-no-handler', 'inputs', 'orphan', utxo=[], expect={'orphans': [], 'accepted': []})
    reject('missing-input-known-output', 'inputs', 0x101, 'txn-already-known', utxo=[coin(txid(base))])
    reject('coins-cache-equality', 'inputs', 0x10, 'bad-txns-inputs-too-large',
           cfg={'maxCoinsViewCacheSize': 1}, request={'useLimits': True})
    row('coins-cache-below', cfg={'maxCoinsViewCacheSize': 2}, request={'useLimits': True, 'lowPriority': True})
    row('coins-cache-zero-unlimited', cfg={'maxCoinsViewCacheSize': 0}, request={'useLimits': True, 'lowPriority': True})
    seq = tx(inputs=[(bytes([1])*32, 0, b'', 201)])
    reject('sequence-pre-genesis-edge', 'sequence', 0x40, 'non-BIP68-final', tx=seq,
           context={'genesisHeight': 10000}, cfg={'requireStandard': False})
    row('sequence-disabled-after-genesis', tx=seq)
    row('inputs-budget-downgrade', 'inputStandard', 'deferred', request={'useLimits': True},
        context={'budget': 'inputs'}, expect={'accepted': [], 'pending': [txid(base)], 'pendingLow': True})
    row('inputs-budget-observation-ignored-without-limits', context={'budget': 'inputs'})
    row('inputs-low-skips-standardness', request={'useLimits': True, 'lowPriority': True})
    # A syntactically standard output isolates the input-standardness stage.
    pubkey = bytes.fromhex('0279be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798')
    standard = tx(outputs=[(900, bytes([33])+pubkey+b'\xac')])
    reject('inputs-nonstandard-refused', 'inputStandard', 0x40, 'bad-txns-nonstandard-inputs',
           tx=standard, cfg={'acceptNonStdOutputs': False})
    sigop = tx(outputs=[(900, b'\x51\xac')])
    two_sigops = tx(outputs=[(900, b'\x51\xac\xac')])
    reject('sigops-above-cap', 'sigops', 0x40, 'bad-txns-too-many-sigops', tx=two_sigops,
           cfg={'maxTxSigOpsCountPolicy': 1})
    row('sigops-at-cap', tx=sigop, cfg={'maxTxSigOpsCountPolicy': 1})
    reject('absurd-fee-above', 'fee', 0x100, 'absurdly-high-fee', request={'absurdFee': 99})
    row('absurd-fee-equality', request={'absurdFee': 100})
    row('absurd-fee-zero-disables', request={'absurdFee': 0}, cfg={'maxTxFee': 1})
    reject('absurd-fee-default-rpc', 'fee', 0x100, 'absurdly-high-fee', cfg={'maxTxFee': 99})
    row('absurd-fee-p2p-no-rpc-ceiling', cfg={'maxTxFee': 99}, request={'source': 'p2p'})
    # Base serialized size is 61, so 1000 sat/kB charges 61 sat exactly.
    fee_edge = tx(outputs=[(939, b'\x51')])
    row('rolling-fee-equality', tx=fee_edge, pool={'rollingRate': 1000})
    reject('rolling-fee-below', 'fee', 0x42, 'mempool min fee not met', tx=tx(outputs=[(940, b'\x51')]),
           pool={'rollingRate': 1000})
    reject('debug-fee-floor', 'fee', 0x42, 'mempool min fee not met', tx=tx(outputs=[(1000, b'\x51')]),
           cfg={'minDebugRejectionFee': 1})
    consolidation = tx(outputs=[(1000, b'\x51')])
    row('consolidation-fee-delta', tx=consolidation, pool={'rollingRate': 500},
        cfg={'minConsolidationFactor': 1, 'acceptNonStdConsolidationInput': True})
    reject('consolidation-disabled', 'fee', 0x42, 'mempool min fee not met', tx=consolidation,
           pool={'rollingRate': 500}, cfg={'minConsolidationFactor': 0, 'acceptNonStdConsolidationInput': True})
    child = spend(base, outputs=[(800, b'\x51')])
    parentpool = {'accepted': [entry(base)]}
    reject('ancestor-at-limit', 'ancestors', 0x40, 'too-long-mempool-chain', tx=child,
           pool=parentpool, cfg={'limitAncestorCount': 1})
    row('ancestor-below-limit', tx=child, pool=parentpool, cfg={'limitAncestorCount': 2},
        expect={'accepted': [txid(base), txid(child)]})
    row('root-zero-ancestor-limit', cfg={'limitAncestorCount': 0, 'limitSecondaryMempoolAncestorCount': 0})
    reject('secondary-ancestor-at-limit', 'ancestors', 0x40, 'too-long-mempool-chain', tx=child,
           pool={'accepted': [entry(base, primary=False, fee=0)]}, cfg={'limitSecondaryMempoolAncestorCount': 1})
    reject('script-input-value', 'scripts', 0x10, 'bad-txns-in-belowout', tx=tx(outputs=[(1001, b'\x51')]))
    reject('script-frozen-admission-list', 'scripts', 0x10, 'bad-txns-inputs-frozen', frozen=[coin()])
    reject('script-budget-low-invalid', 'scripts', 0x40, 'too-long-validation-time', context={'budget': 'relay'},
           request={'useLimits': True, 'lowPriority': True}, expect={'accepted': [], 'pending': []})
    reject('detector-final-insertion', 'detector', 0x12, 'txn-double-spend-detected', detectorValidating=[coin()])
    reject('detector-newly-committed', 'detector', 0x102, 'txn-mempool-conflict', detectorCommitted=[coin()])
    reject('earlier-fee-overrides-detector', 'fee', 0x100, 'absurdly-high-fee', request={'absurdFee': 99},
           detectorValidating=[coin()])
    row('commit-size-equality', cfg={'maxMempool': 61, 'maxMempoolSizeDisk': 0})
    reject('commit-size-over-cap', 'commit', 0x42, 'mempool full', cfg={'maxMempool': 60, 'maxMempoolSizeDisk': 0},
           expect={'accepted': [], 'spentCount': 0})
    row('held-size-equality', status='heldNonFinal', tx=nonfinal, cfg={'maxMempoolNonFinal': 61})
    reject('held-size-over-cap', 'commit', 0x103, 'non-final-pool-full', tx=nonfinal,
           cfg={'maxMempoolNonFinal': 60}, expect={'accepted': [], 'held': []})
    reject('held-repeat-not-update', 'commit', 0x10, 'bad-txn-update', tx=nonfinal,
           pool={'nonFinal': [entry(nonfinal)]})
    old = tx(inputs=[(bytes([1])*32, 0, b'', 0xfffffffc)], lock=201)
    update = tx(inputs=[(bytes([1])*32, 0, b'', 0xfffffffd)], lock=201)
    row('held-valid-update', status='heldNonFinal', tx=update, pool={'nonFinal': [entry(old)]},
        expect={'held': [txid(update)], 'accepted': []})
    reject('held-update-rate-over', 'finality', 0x45, 'non-final-txn-replacement-rate', tx=update,
           pool={'nonFinal': [entry(old, rateFill=1)]}, cfg={'nonFinalMaxReplacementRate': 1})
    row('held-update-rate-at', status='heldNonFinal', tx=update, pool={'nonFinal': [entry(old)]},
        cfg={'nonFinalMaxReplacementRate': 1})
    old_two = tx(inputs=[(bytes([1])*32, 0, b'', 0), (bytes([2])*32, 0, b'', 0)], lock=201)
    update_two = tx(inputs=[(bytes([1])*32, 0, b'', 0xffffffff), (bytes([2])*32, 0, b'', 0)], lock=201)
    row('held-unchanged-nonfinal-sequence-queues', status='deferred', tx=update_two,
        pool={'nonFinal': [entry(old_two)]}, utxo=[coin(), coin('02'*32)],
        expect={'held': [], 'accepted': [], 'pending': [txid(update_two)]})
    reject('script-eval-false', 'scripts', 0x10,
           'mandatory-script-verify-flag-failed (Script evaluated without error but finished with a false/empty top stack element)',
           utxo=[coin(script='00')])
    row('reject-parent-prevents-orphan-retention', 'inputs', 'orphan', utxo=[],
        pool={'recentRejects': ['01'*32]}, request={'source': 'p2p', 'orphanHandler': True},
        expect={'orphans': [], 'accepted': []})
    row('reject-filter-p2p-silence', pool={'recentRejects': [txid(base)]}, request={'source': 'p2p'},
        status='suppressed', expect={'stage': 'none', 'trace': [], 'accepted': []})
    row('reject-filter-rpc-retries', pool={'recentRejects': [txid(base)]})

    def maintenance(name, action, boundary, source, **kw):
        row(name, boundary, 'maintenance', action=action, source=SOURCE+source, **kw)
    expiry_source = 'txmempool.cpp#L2201-L2220'
    maintenance('expiry-equality-kept', 'expire', 'expiry', expiry_source,
                pool={'accepted': [entry(base, time=900)]}, cfg={'mempoolExpiry': 100}, expect={'accepted': [txid(base)]})
    maintenance('expiry-one-second-older', 'expire', 'expiry', expiry_source,
                pool={'accepted': [entry(base, time=899)]}, cfg={'mempoolExpiry': 100}, expect={'accepted': [], 'spentCount': 0})
    maintenance('expiry-younger-descendant', 'expire', 'expiry', expiry_source,
                pool={'accepted': [entry(base, time=899), entry(child, time=1000)]}, cfg={'mempoolExpiry': 100},
                expect={'accepted': [], 'spentCount': 0})
    independent = tx(inputs=[(bytes([2])*32, 0, b'', 0xffffffff)])
    trim_source = 'txmempool.cpp#L2704-L2798'
    pair = {'accepted': [entry(base, fee=1), entry(independent, fee=100)]}
    maintenance('trim-at-limit', 'trim', 'eviction', trim_source, pool=pair, limit=122,
                expect={'accepted': [txid(base), txid(independent)], 'rollingRate': 0, 'usage': 122})
    maintenance('trim-below-limit-raises-next-rate', 'trim', 'eviction', trim_source, pool=pair, limit=121,
                expect={'accepted': [txid(independent)], 'rollingRate': 2639, 'usage': 61})
    maintenance('trim-empty-retains-rolling-rate', 'trim', 'eviction', trim_source,
                pool={'accepted': [entry(base)], 'rollingRate': 5000}, limit=0,
                expect={'accepted': [], 'rollingRate': 5000, 'usage': 0})
    maintenance('trim-secondary-mining-cap', 'trim', 'eviction', trim_source,
                pool={'accepted': [entry(base, primary=False, fee=0), entry(independent, primary=False, fee=1)]}, limit=61,
                cfg={'blockMinTxFee': 500}, expect={'accepted': [txid(independent)], 'rollingRate': 500})
    maintenance('trim-leaf-before-low-fee-parent', 'trim', 'eviction', trim_source,
                pool={'accepted': [entry(base, fee=1), entry(child, fee=100)]}, limit=61,
                expect={'accepted': [txid(base)], 'rollingRate': 2639})
    maintenance('trim-group-demotes-parent', 'trim', 'eviction', trim_source,
                pool={'accepted': [entry(base, fee=0, cpfpGroup=txid(child)),
                                   entry(child, fee=100, cpfpGroup=txid(child))]}, limit=121,
                cfg={'blockMinTxFee': 500}, expect={'accepted': [txid(base)], 'primary': [], 'rollingRate': 500})
    nf_source = 'time_locked_mempool.cpp#L611-L660'
    maintenance('held-expiry-equality', 'nonFinalCheck', 'heldMaintenance', nf_source,
                pool={'nonFinal': [entry(nonfinal, time=900)]}, cfg={'mempoolNonFinalExpiry': 100},
                expect={'held': [], 'pending': []})
    maintenance('held-expiry-before', 'nonFinalCheck', 'heldMaintenance', nf_source,
                pool={'nonFinal': [entry(nonfinal, time=901)]}, cfg={'mempoolNonFinalExpiry': 100},
                expect={'held': [txid(nonfinal)], 'pending': []})
    maintenance('held-height-final-queues-before-expiry', 'nonFinalCheck', 'heldMaintenance', nf_source,
                pool={'nonFinal': [entry(nonfinal, time=0)]}, context={'tipHeight': 201}, cfg={'mempoolNonFinalExpiry': 1},
                expect={'held': [], 'accepted': [], 'pending': [txid(nonfinal)]})
    orphan_source = 'orphan_txns.cpp#L168-L244'
    opool = {'orphans': [entry(base, expiresAt=1000)], 'untrimmedBytes': 61}
    maintenance('orphan-expiry-equality', 'orphanSweep', 'orphanMaintenance', orphan_source,
                pool=opool, cfg={'maxOrphanTxSize': 100, 'orphanTrimHysteresisDivisor': 10}, expect={'orphans': []})
    maintenance('orphan-hysteresis-skips-expiry', 'orphanSweep', 'orphanMaintenance', orphan_source,
                pool={'orphans': [entry(base, expiresAt=1000)], 'untrimmedBytes': 0},
                cfg={'maxOrphanTxSize': 100, 'orphanTrimHysteresisDivisor': 10}, expect={'orphans': [txid(base)]})
    maintenance('orphan-parent-only-enqueues', 'retry', 'orphanRetry', 'orphan_txns.cpp#L256-L350',
                pool={'accepted': [entry(base)], 'orphans': [entry(child)]}, batchSize=0,
                expect={'accepted': [txid(base)], 'orphans': [txid(child)], 'pending': [txid(child)]})
    row('orphan-revalidation-accepts', 'orphanRetry', 'accepted', action='revalidate', tx=child,
        pool={'accepted': [entry(base)], 'orphans': [entry(child)]}, request={'orphanHandler': True},
        source=SOURCE+'validation.cpp#L1759-L1866', expect={'accepted': [txid(base), txid(child)], 'orphans': []})
    row('orphan-revalidation-can-refuse', 'orphanRetry', 'rejected', 0x10, 'bad-txns-in-belowout', action='revalidate',
        tx=spend(base, outputs=[(901, b'\x51')]), pool={'accepted': [entry(base)]},
        source=SOURCE+'validation.cpp#L1759-L1866', expect={'accepted': [txid(base)]})
    decay_source = 'txmempool.cpp#L2624-L2647'
    maintenance('rolling-decay-no-block-gate', 'decay', 'decay', decay_source,
                pool={'rollingRate': 8000, 'lastUpdate': 0}, context={'now': 43200}, expect={'rollingRate': 8000})
    maintenance('rolling-decay-interval-equality', 'decay', 'decay', decay_source,
                pool={'rollingRate': 8000, 'lastUpdate': 0, 'blockSinceBump': True}, context={'now': 10}, expect={'rollingRate': 8000})
    maintenance('rolling-decay-low-usage-half-life', 'decay', 'decay', decay_source,
                pool={'rollingRate': 8000, 'lastUpdate': 0, 'blockSinceBump': True}, context={'now': 10800}, expect={'rollingRate': 4000})
    # Regular C gate equality reaches the later, tighter P sigop cap.
    for count in (20000, 20001):
        raw = tx(outputs=[(900, b'\xac'*count)])
        reject(f'regular-pre-genesis-sigops-{count}', 'sigops' if count == 20000 else 'regular',
               0x40 if count == 20000 else 0x10,
               'bad-txns-too-many-sigops' if count == 20000 else 'bad-txn-sigops',
               tx=raw, context={'genesisHeight': 10000}, cfg={'requireStandard': False})
    for activation, reason in ((202, 'flexible-bad-txn-sigops'), (273, 'bad-txn-sigops')):
        reject(f'regular-genesis-grace-{activation}', 'regular', 0x10, reason,
               tx=tx(outputs=[(900, b'\xac'*20001)]), context={'genesisHeight': activation},
               cfg={'requireStandard': False})
    reject('regular-genesis-grace-opposite-also-fails', 'regular', 0x10, 'bad-txn-sigops',
           tx=tx(inputs=[(bytes([1])*32, 0, b'', 0xffffffff)]*2, outputs=[(900, b'\xac'*20001)]),
           context={'genesisHeight': 202}, cfg={'requireStandard': False})
    reject('regular-census-sigop-cap', 'regular', 0x10, 'bad-txn-sigops', tx=two_sigops,
           cfg={'maxTxSigOpsCountConsensusBeforeGenesis': 1, 'requireStandard': False},
           context={'genesisHeight': 10000})
    for genesis, field in ((10000, 'maxTxSizeConsensusBeforeGenesis'), (0, 'maxTxSizeConsensusAfterGenesis')):
        row(f'regular-census-size-equal-{genesis}', context={'genesisHeight': genesis},
            cfg={field: 61, 'requireStandard': False})
        reject(f'regular-census-size-over-{genesis}', 'regular', 0x10, 'bad-txns-oversize',
               context={'genesisHeight': genesis}, cfg={field: 60, 'requireStandard': False})
    # Standard parent and output allow high priority to reach the script budget.
    budget_tx = tx(inputs=[(bytes([1])*32, 0, b'\x01\x51', 0xffffffff)],
                   outputs=[(900, bytes([33])+pubkey+b'\xac')])
    redeem_hash = hashlib.new('ripemd160', hashlib.sha256(b'\x51').digest()).hexdigest()
    for budget in ('relay', 'block'):
        row(f'script-budget-high-{budget}', 'scripts', 'deferred', tx=budget_tx,
            utxo=[coin(script='a914'+redeem_hash+'87')], request={'useLimits': True},
            context={'budget': budget, 'genesisHeight': 100},
            expect={'accepted': [], 'pending': [txid(budget_tx)], 'pendingLow': True})
    # CLTV is absent from relay via the request exclusions and from mandatory.
    # The block word enables it at this height. Timeout at mandatory proves that
    # the outer fallback is actually reached, with time still an explicit input.
    fallback = dict(context={'genesisHeight': 10000, 'tipHeight': 1500},
                    cfg={'requireStandard': False}, utxo=[coin(script='51b17551')],
                    request={'skipScriptFlags': 640})
    row('outer-block-failure-mandatory-success', **fallback)
    limited = deepcopy(fallback)
    limited['request'].update(useLimits=True, lowPriority=True)
    limited['context']['budget'] = 'mandatory'
    reject('outer-mandatory-budget-low-invalid', 'scripts', 0x40, 'too-long-validation-time',
           expect={'accepted': [], 'pending': []}, **limited)
    reject('outer-relay-cltv-refusal', 'scripts', 0x40,
           'non-mandatory-script-verify-flag (Locktime requirement not satisfied)',
           context=fallback['context'], cfg=fallback['cfg'], utxo=fallback['utxo'])
    # Non-push scriptSig fails pre-Chronicle, but a version-2 spend allows it
    # under the inverse outer caller word. The input-only grace retry cannot.
    malleable = tx(inputs=[(bytes([1])*32, 0, b'\x51\x75', 0xffffffff)], version=2)
    for grace, prefix in ((0, ''), (72, 'flexible-')):
        reject(f'outer-chronicle-grace-{grace}', 'scripts', 0x40 if grace else 0x10,
               prefix+'mandatory-script-verify-flag-failed (Only non-push operators allowed in signatures)',
               tx=malleable, context={'chronicleHeight': 202},
               cfg={'requireStandard': False, 'chronicleGracefulPeriod': grace})
    # 7200 + 1 - (0.5 / 3600)*7200 = 7200; the zero-elapsed control is 7201.
    for nanos in (0, 500000000):
        kw = dict(tx=update, pool={'nonFinal': [entry(old, rateFill=7200, lastDrainNanos=0)]},
                  context={'bucketTimeNanos': nanos, 'now': 9999})
        if nanos:
            row('held-rate-fractional-half-second', status='heldNonFinal',
                expect={'held': [txid(update)]}, **kw)
        else:
            reject('held-rate-zero-elapsed', 'finality', 0x45, 'non-final-txn-replacement-rate', **kw)
    maintenance('rolling-block-resets-timestamp', 'blockThenDecay', 'decay', 'txmempool.cpp#L1170-L1171',
                pool={'rollingRate': 8000, 'lastUpdate': 0}, context={'now': 43200},
                expect={'rollingRate': 8000, 'lastUpdate': 43200, 'blockSinceBump': True})
    maintenance('limit-secondary-unsigned-underflow', 'limit', 'eviction', 'validation.cpp#L866-L873',
                pool={'accepted': [entry(base, primary=False, fee=0), entry(independent, primary=False, fee=0)]},
                cfg={'maxMempool': 61, 'maxMempoolSizeDisk': 0, 'mempoolMaxPercentCPFP': 10},
                expect={'accepted': [txid(base), txid(independent)], 'usage': 122})
    for cap in (134, 135):
        row(f'orphan-admission-aggregate-{cap}', 'inputs', 'orphan', tx=independent, utxo=[],
            pool={'orphans': [entry(base)]}, cfg={'maxOrphanTxSize': cap},
            request={'source': 'p2p', 'orphanHandler': True},
            expect={'orphans': ([txid(base)] if cap == 135 else [])+[txid(independent)], 'accepted': []},
            source=SOURCE+'orphan_txns.cpp#L168-L244')
    for cap in (60, 61):
        row(f'orphan-p2p-size-{cap}', 'inputs', 'orphan', utxo=[],
            cfg={'requireStandard': False, 'maxTxSizePolicy': cap},
            request={'source': 'p2p', 'orphanHandler': True},
            expect={'orphans': [txid(base)] if cap == 61 else [], 'accepted': []},
            source=SOURCE+'orphan_txns.cpp#L47-L68')
    for cap in (0, 1):
        maintenance(f'promotion-visit-cap-{cap}', 'promote', 'promotion', 'txmempool.cpp#L481-L565',
                    pool={'accepted': [entry(base, primary=False), entry(child, primary=False, ancestorCount=1)]},
                    cfg={'maxPrimaryPromotionVisits': cap}, queued=[txid(base)],
                    expect={'primary': [txid(base)]+([txid(child)] if cap else []),
                            'accepted': [txid(base), txid(child)]})
    row('orphan-selected-arrival-revalidation', 'orphanRetry', 'accepted', action='arrivalRevalidate',
        pool={'accepted': [entry(base)], 'orphans': [entry(child, request={'orphanHandler': True})]},
        source=SOURCE+'orphan_txns.cpp#L278-L301',
        expect={'accepted': [txid(base), txid(child)], 'orphans': [], 'pending': []})
    # [D] 2026-10-14, #71: ordered peer and RPC traces through the inventory
    # envelope of BsvChain.Rejects. Each inventory test names the tip label it
    # observes; `mine` and `invalidate` move the node's tip with empty blocks.
    # [SRC] net/net_processing.cpp:930-961,3351-3408; validation.cpp:1786-1836,
    # 2037-2048,2097-2136; txn_validator.cpp:633-641 at the pin.
    below = tx(outputs=[(1001, b'\x51')])
    second = bytes([2])*32
    below2 = tx(inputs=[(second, 0, b'', 0xffffffff)], outputs=[(1001, b'\x51')])
    stale_update = tx(inputs=[(bytes([1])*32, 0, b'', 0xfffffffe)], outputs=[(899, b'\x51')], lock=201)
    refused = 'rejected 16 bad-txns-in-belowout'

    def step(op, name=None, tip=None, **kw):
        s = dict(op=op)
        if name is not None:
            s['tx'] = name
        if tip is not None:
            s['tip'] = tip
        s.update(kw)
        return s

    def trace(name, source, txs, steps, answers, remembered, non_judging=(), **kw):
        r = dict(id=name, label='[D]', node='pending #66', boundary='rejects', source=SOURCE+source,
                 action='p2pTrace', txs=txs, utxo=kw.pop('utxo', basecoin), steps=steps,
                 expected=dict(status='trace', answers=answers, remembered=remembered,
                               nonJudging=list(non_judging)))
        r.update(deepcopy(kw))
        rows.append(r)

    trace('rejects-silence-until-reset', 'net/net_processing.cpp#L930-L961', {'T': below},
          [step('inv', 'T', 'aa'), step('tx', 'T', 'aa'), step('inv', 'T', 'aa'), step('tx', 'T', 'aa'),
           step('mine', tip='bb'), step('inv', 'T', 'bb'), step('tx', 'T', 'bb'), step('inv', 'T', 'bb')],
          ['request', refused, 'silence', 'suppressed', 'tip', 'request', refused, 'silence'], ['T'])
    trace('rejects-lazy-reset-tip-returns', 'net/net_processing.cpp#L930-L942', {'T': below},
          [step('inv', 'T', 'aa'), step('tx', 'T', 'aa'), step('inv', 'T', 'aa'), step('mine', tip='bb'),
           step('invalidate', tip='aa'), step('inv', 'T', 'aa'), step('mine', tip='cc'), step('inv', 'T', 'cc')],
          ['request', refused, 'silence', 'tip', 'tip', 'silence', 'tip', 'request'], [])
    trace('rejects-commit-refusal-not-remembered', 'validation.cpp#L1808-L1836',
          {'H': nonfinal, 'H2': stale_update, 'T': below2},
          [step('rpc', 'H'), step('tx', 'H2', 'aa'), step('inv', 'H2', 'aa'), step('tx', 'T', 'aa'),
           step('inv', 'T', 'aa')],
          ['heldNonFinal', 'rejected 16 bad-txn-update', 'request', refused, 'silence'], ['T'], non_judging=[1],
          utxo=[coin(), coin('02'*32)],
          nonJudgingReasons={'1': "step 1 is a limited validation whose outcome depends on the node's CPU validation clock ([SRC] src/validation.cpp:990-1006,1077-1078,1335-1355,1414-1430,1444-1464; src/init.cpp:2890-2895 at 6504a3af), under default validationclockcpu=1, maxstdtxvalidationduration=3, maxnonstdtxvalidationduration=1000, maxtxchainvalidationbudget=50"})
    trace('rejects-rpc-neither-reads-nor-writes', 'rpc/rawtransaction.cpp#L1586-L1594',
          {'T': below, 'T2': below2},
          [step('tx', 'T', 'aa'), step('rpc', 'T'), step('inv', 'T', 'aa'), step('rpc', 'T2'),
           step('inv', 'T2', 'aa'), step('tx', 'T2', 'aa'), step('inv', 'T2', 'aa')],
          [refused, refused, 'silence', refused, 'request', refused, 'silence'], ['T', 'T2'],
          utxo=[coin(), coin('02'*32)])
    trace('rejects-budget-low-timeout-remembered', 'txn_validator.cpp#L633-L641', {'X': base},
          [step('tx', 'X', 'aa', elapsedLow={'relay': 400000}), step('inv', 'X', 'aa'),
           step('mine', tip='bb'), step('inv', 'X', 'bb')],
          ['rejected 64 too-long-validation-time', 'silence', 'tip', 'request'], [], non_judging=[0],
          utxo=[coin(heavy=True)], budgetCell=True,
          cfg={'maxNonStdTxnValidationDuration': 10, 'maxTxnChainValidationBudget': 0})
    trace('rejects-budget-ample-accepted', 'validation.cpp#L990-L1006', {'X': base},
          [step('tx', 'X', 'aa', elapsedLow={'relay': 400000}), step('inv', 'X', 'aa')],
          ['accepted', 'silence'], [], non_judging=[0], utxo=[coin(heavy=True)], budgetCell=True,
          cfg={'maxTxnChainValidationBudget': 0})
    return rows


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    rows = cases()
    content = ''.join(json.dumps(row, separators=(',', ':'))+'\n' for row in rows)
    if args.check:
        if not OUT.exists() or OUT.read_text() != content:
            raise SystemExit('mempool-cases: STALE')
    else:
        OUT.parent.mkdir(parents=True, exist_ok=True)
        OUT.write_text(content)
    counts = {stage: sum(r['boundary'] == stage for r in rows) for stage in dict.fromkeys(r['boundary'] for r in rows)}
    print(f'mempool-cases: GREEN ({len(rows)} derived rows; node pending #66; counts {counts})')


if __name__ == '__main__':
    main()
