"""[X] 2026-10-13 S3: synthetic receipt projection and size boundary checks."""
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from tools import receipt_trim as trim  # noqa: E402


class ReceiptTrimTests(unittest.TestCase):
    def test_projections_tokens_retries_instances_and_rpc_summary(self):
        call = {'method': 'submitblock', 'params': ['ab' * 100],
                'instance_id': 'run/probe-0',
                'reply': {'result': {'status': 'ok', 'items': [{'hash': 'cd' * 32}]}},
                'source': 'pinned handler'}
        row = {'id': 'probe', 'case': 'boundary', 'label': '[X]',
               'token': 'measured agree [X] record.md', 'verdict': 'agree',
               'expected_label': '[D]', 'expected': {'height': 5},
               'observed': {'height': 5}, 'rpc': [call],
               'fixtures': {'transaction': {'txid': 'ab' * 32, 'hex': 'cd' * 100},
                            'failure_log': 'private log', 'completion': ['private log'],
                            'unsettled_attempts': [{'rpc': [call]}],
                            'datadir': '/host/spec-oracle-scenarios/run/probe-0'}}
        full = {'run_id': 'run', 'record': 'record.md', 'families': {'chain': [row]},
                'scenarios': [{'steps': [dict(row, node=row['token'])]}]}
        projected = trim.trim_receipt(full, '/run/receipt.json', 'ef' * 32, 500)
        saved = projected['families']['chain'][0]
        for key in ('id', 'case', 'label', 'token', 'expected', 'observed', 'verdict'):
            self.assertEqual(saved[key], row[key])
        self.assertEqual(saved['retry_count'], 1)
        self.assertEqual(saved['instance_id'], 'probe-0')
        self.assertEqual(saved['run_relative_paths'], ['probe-0'])
        self.assertEqual(saved['rpc'][0], {
            'method': 'submitblock',
            'instance_id': 'probe-0',
            'params_sha256': hashlib.sha256(trim.canonical(call['params'])).hexdigest(),
            'observed_fields': ['result', 'result.items', 'result.items[].hash', 'result.status'],
        })
        self.assertNotIn('transaction', saved['fixtures'])
        self.assertNotIn('failure_log', saved['fixtures'])
        self.assertNotIn('completion', saved['fixtures'])
        self.assertEqual(projected['scenarios'][0]['steps'][0]['token'], row['token'])
        self.assertEqual(full['families']['chain'][0]['rpc'][0], call)

    def test_wallet_build_identity_and_token_survive_projection(self):
        binary = {'lifecycle': 'binary', 'build': 'wallet build',
                  'binary': '~/bsv/targets/wallet/bin/bitcoind',
                  'sha256': 'ab' * 32,
                  'source': 'docs/PROVENANCE.md 1a reference.binary_wallet'}
        row = {'id': 'fee', 'build': 'wallet build', 'verdict': 'agree',
               'observed': {'status': 'accepted'}, 'rpc': [binary]}
        saved = trim.row_projection(row, 'docs/records/run.md', 'run')
        self.assertEqual(saved['build'], 'wallet build')
        self.assertEqual(saved['rpc'][0], binary)
        self.assertTrue(saved['token'].startswith('measured agree (wallet build): '))
        absent = dict(row, unrealizable='the wallet build is absent on this host: /absent')
        saved_absent = trim.row_projection(absent, 'docs/records/run.md', 'run')
        self.assertEqual(saved_absent['token'],
                         'unrealizable: the wallet build is absent on this host: /absent '
                         '[X] docs/records/run.md')

    def test_nested_histories_keep_each_rpc_owner_and_certificates(self):
        def call(instance):
            return {'method': 'probe', 'instance_id': 'run/' + instance,
                    'params': [], 'reply': {'result': True}}
        row = {'id': 'nested', 'fixtures': {'attempts': [{
            'rpc': [call('race.attempt-0')],
            'calibration': {'history': {'rpc': [call('calibration-0')]}},
            'stage_witness': {'checked': '1', 'stage': 'detector', 'marker': 'target'},
        }], 'unsettled_attempts': [{'history': [call('retry-0')]}],
            'undo_witness': {'before_edit': True, 'after_level3': False},
            'undo_edit': {'header_offset': 4166, 'payload_offset': 4174,
                          'new_checksum': 'ab' * 32, 'old_payload': 'cd' * 100,
                          'child_record': {'checksum_holds_against_A': True}}}}
        saved = trim.row_projection(row, 'r.md', 'run')
        self.assertIsNone(saved['instance_id'])
        self.assertEqual(saved['instance_ids'], ['calibration-0', 'race.attempt-0', 'retry-0'])
        self.assertEqual(saved['retry_count'], 1)
        fixtures = saved['fixtures']
        attempt = fixtures['attempts'][0]
        self.assertEqual(attempt['rpc'][0]['instance_id'], 'race.attempt-0')
        self.assertEqual(attempt['calibration']['history']['rpc'][0]['instance_id'], 'calibration-0')
        self.assertEqual(fixtures['unsettled_attempts'][0]['history'][0]['instance_id'], 'retry-0')
        self.assertEqual(attempt['stage_witness'], row['fixtures']['attempts'][0]['stage_witness'])
        self.assertEqual(fixtures['undo_witness'], row['fixtures']['undo_witness'])
        self.assertEqual(fixtures['undo_edit']['header_offset'], 4166)
        self.assertEqual(fixtures['undo_edit']['new_checksum'], 'ab' * 32)
        self.assertTrue(fixtures['undo_edit']['child_record']['checksum_holds_against_A'])
        self.assertNotIn('old_payload', fixtures['undo_edit'])
        historical = trim.project({'method': 'probe', 'reply': {'result': True}}, 'run')
        self.assertIsNone(historical['instance_id'])
        self.assertEqual(trim.row_projection({'fixtures': {'attempts': [{'rpc': [call('only-0')]}]}},
                                            'r.md', 'run')['instance_id'], 'only-0')

    def test_missing_instance_is_not_invented_and_hex_is_dropped_recursively(self):
        row = trim.row_projection({'id': 'x', 'fixtures': {
            'data': '00' * 33, 'hash': 'aa' * 32, 'logs': ['secret'],
            'values': ['0x' + 'ab' * 40, 42]}}, 'record.md', 'run')
        self.assertIsNone(row['instance_id'])
        self.assertEqual(row['instance_ids'], [])
        self.assertEqual(row['retry_count'], 0)
        self.assertNotIn('fixtures', row)
        self.assertEqual(trim.project({'hash': 'aa' * 32, 'values': ['ab' * 40, 42]}),
                         {'hash': 'aa' * 32, 'values': [42]})

    def test_historical_token_qualifiers_and_nonmeasured_verdicts(self):
        row = {'verdict': 'agree', 'observed': {'b': 2, 'a': 1}, 'qualifier': 'instrument'}
        self.assertEqual(trim.token(row, 'r.md'),
                         'measured agree: {"a":1,"b":2} [instrument] [X] r.md')
        self.assertEqual(trim.token({'unrealizable': 'no surface'}, 'r.md'),
                         'unrealizable: no surface [X] r.md')
        self.assertEqual(trim.token({'needs_peer': True}, 'r.md'), 'needs-peer #71 [X] r.md')

    def test_list_fixtures_keep_retry_and_rpc_metadata_without_raw_snapshots(self):
        row = {'id': 'list-fixture', 'fixtures': [
            {'unsettled_attempts': [{'rpc': [{'method': 'probe', 'params': [],
                                             'reply': {'result': True}}]}]},
            {'observed_rpc_body': {'large': 'payload'}, 'datadir': 'run/probe-0'}],
               'shutdown_rpc': {'result': None}}
        saved = trim.row_projection(row, 'r.md', 'run')
        self.assertEqual(saved['retry_count'], 1)
        self.assertEqual(saved['instance_id'], 'probe-0')
        self.assertNotIn('shutdown_rpc', saved)
        self.assertNotIn('observed_rpc_body', saved['fixtures'][1])
        self.assertEqual(saved['fixtures'][0]['unsettled_attempts'][0]['rpc'][0]['method'], 'probe')

    def test_judged_long_hex_preserves_distinctions_and_token_commitment(self):
        row = {'id': 'script-projection', 'expected': {'script': 'aa' * 100},
               'observed': {'script': 'bb' * 100}, 'verdict': 'diverge'}
        saved = trim.row_projection(row, 'r.md', 'run')
        self.assertNotEqual(saved['expected'], saved['observed'])
        for key in ('expected', 'observed'):
            self.assertEqual(saved[key]['script']['sha256'],
                             hashlib.sha256(row[key]['script'].encode()).hexdigest())
            self.assertEqual(saved[key]['script']['bytes'], 200)
        self.assertNotIn('bb' * 100, saved['token'])
        self.assertEqual(saved['token_sha256'],
                         hashlib.sha256(trim.token(row, 'r.md').encode()).hexdigest())

    def test_cli_full_digest_size_and_strict_limit(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            full = root / 'receipt.json'
            saved = root / 'docs/records/saved.json'
            record = root / 'docs/records/saved.md'
            raw = b'{"run_id":"run","families":{},"scenarios":[]}\n'
            full.write_bytes(raw)
            command = [sys.executable, 'tools/receipt_trim.py']
            result = subprocess.run(command + [str(full), str(saved), '--record', str(record)],
                                    capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            digest = hashlib.sha256(raw).hexdigest()
            self.assertEqual(json.loads(saved.read_bytes())['full_receipt']['sha256'], digest)
            self.assertIn(str(len(raw)), record.read_text())
            self.assertIn(digest, record.read_text())
            self.assertEqual(full.read_bytes(), raw)
            self.assertEqual(subprocess.run(command + ['--check', str(saved)],
                                           capture_output=True).returncode, 0)
            saved.write_bytes(b'"' + b'a' * (trim.LIMIT - 2) + b'"')
            self.assertEqual(list(trim.oversized(saved)), [])
            saved.write_bytes(saved.read_bytes() + b'\n')
            self.assertEqual(subprocess.run(command + ['--check', str(saved)],
                                           capture_output=True).returncode, 1)
            result = subprocess.run(command + [str(full), str(full)], capture_output=True)
            self.assertNotEqual(result.returncode, 0)
            result = subprocess.run(command + [str(full), str(saved), '--record', str(full)],
                                    capture_output=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertEqual(full.read_bytes(), raw)

    def test_oversized_receipts_are_rejected_at_every_location(self):
        # [X] 2026-10-13 S3, lane trim-c1: no inherited size exemption remains.
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            receipt = root / '20261013-045648-s6-66-utx-regtest-s3.json'
            raw = b'"' + b'a' * (trim.LIMIT - 1) + b'"'
            receipt.write_bytes(raw)
            nested = root / 'nested'
            nested.mkdir()
            copy = nested / receipt.name
            copy.write_bytes(raw)
            self.assertEqual(list(trim.oversized(receipt)), [(receipt, len(raw))])
            self.assertEqual(list(trim.oversized(root)),
                             [(receipt, len(raw)), (copy, len(raw))])


if __name__ == '__main__':
    unittest.main()
