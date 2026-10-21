#!/usr/bin/env python3
"""#146: negative controls for the fixture verdict/receipt contract, no builds."""
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

import fixtures_proof as proof


class Contract(unittest.TestCase):
    def exercise(self, fault=None):
        with tempfile.TemporaryDirectory(dir=os.environ['TMPDIR']) as directory:
            root = Path(directory)
            out = root / 'out'
            out.mkdir()
            (root / 'harness/engines/ts/node_modules/@bsv/sdk').mkdir(parents=True)
            (root / 'harness/engines/go').mkdir(parents=True)
            (root / 'harness/engines/ts/package-lock.json').write_text('{}')
            (root / 'harness/engines/ts/fixtures.mjs').write_text('')
            (root / 'harness/engines/ts/node_modules/@bsv/sdk/package.json').write_text('{"version":"3.0.0"}')
            files = {'go-sdk/node_vectors.json': {'results': 1}, 'go-sdk/script_tests.json': {'rows': 1},
                     'go-sdk/evaluation.json': {'node-sighash': 1},
                     'go-sdk/signer/node_vectors.json': {'results': 1},
                     'ts-sdk/evaluation.json': {'node-sighash': 1, 'node-transaction': 1},
                     'ts-sdk/signer/evaluation.json': {'node-transaction': 1}}
            for name, info in files.items():
                path = root / 'corpus/fixtures' / name
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text('{}')
                info['sha256'] = hashlib.sha256(b'{}').hexdigest()
            (root / 'corpus/fixtures/manifest.json').write_text(json.dumps({'files': files, 'pins': {}, 'node': 'test'}))
            names = []

            def child(command, **kwargs):
                name = Path(kwargs['stdout'].name).stem
                names.append(name)
                text, code = '', 0
                if name == 'node-path':
                    text = 'node'
                elif name == 'node-version':
                    text = 'v20.0.0' if fault == 'old-node' else 'v22.0.0'
                elif name.endswith('.rules'):
                    (out / 'classes.tsv').touch()
                    text = 'rules_check: GREEN (controlled)'
                elif name in ('go', 'ts'):
                    labels = ['go-sdk/node_vectors.json', 'go-sdk/script_tests.json', 'go-sdk/evaluation.json', 'go-sdk/signer/node_vectors.json'] if name == 'go' else ['ts-sdk/evaluation.json node-sighash', 'ts-sdk/evaluation.json node-transaction', 'ts-sdk/signer/evaluation.json node-transaction']
                    text = '\n'.join(f'SUMMARY {label}: 1 rows, agree 1, divergent by class 0 [], RED 0' for label in labels)
                if fault == 'cargo-exit' and name == 'go-sdk.rules':
                    text, code = 'rules_check: RED (controlled exit 7)', 7
                if fault == 'cargo-red' and name == 'go-sdk.rules':
                    text = 'rules_check: RED (controlled exit 0)'
                if fault == 'silent-cargo' and name == 'go-sdk.rules':
                    text = ''
                if fault == 'silent-' + name:
                    text = ''
                if fault == 'zero-rows' and name == 'go':
                    text = text.replace('1 rows, agree 1', '0 rows, agree 0')
                if fault == 'missing-summary' and name == 'ts':
                    text = text.splitlines()[0]
                if fault == 'go-exit' and name == 'go':
                    code = 9
                kwargs['stdout'].write(text + '\n')
                return subprocess.CompletedProcess(command, code)

            receipt = {'commands': []}
            env = dict(os.environ, TS_ADAPTER_DIR=str(root / 'harness/engines/ts'), RULES_CHECK_BIN='rules_check')
            with patch.dict(os.environ, env, clear=True), patch.object(proof.shutil, 'which', side_effect=lambda n: None if fault == 'missing-go' and n == 'go' else n), patch.object(proof.subprocess, 'run', side_effect=child), patch.object(proof.os, 'getloadavg', return_value=(1, 1, 1)):
                try:
                    proof.run(root, out, receipt)
                except proof.Failure as error:
                    return error, names
            return None, names

    def test_complete_output(self):
        error, _ = self.exercise()
        self.assertIsNone(error)

    def test_classifier_failures_stop_proofs(self):
        for fault in ('cargo-exit', 'cargo-red', 'silent-cargo'):
            with self.subTest(fault=fault):
                error, names = self.exercise(fault)
                self.assertIsNotNone(error)
                self.assertNotIn('go', names)
                self.assertNotIn('ts', names)
                if fault == 'cargo-exit':
                    self.assertEqual(error.code, 7)

    def test_missing_and_empty_summaries(self):
        for fault in ('silent-go', 'silent-ts', 'zero-rows', 'missing-summary'):
            with self.subTest(fault=fault):
                error, _ = self.exercise(fault)
                self.assertIsNotNone(error)

    def test_child_status_preserved(self):
        error, _ = self.exercise('go-exit')
        self.assertEqual(error.code, 9)

    def test_absent_tool_named(self):
        error, names = self.exercise('missing-go')
        self.assertTrue(error.skipped)
        self.assertEqual(str(error), 'go unavailable')
        self.assertNotIn('go-sdk.rules', names)

    def test_wrong_node_version_named(self):
        error, names = self.exercise('old-node')
        self.assertTrue(error.skipped)
        self.assertEqual(error.code, 2)
        self.assertEqual(str(error), 'Node 22 required')
        self.assertNotIn('go-sdk.rules', names)
        self.assertNotIn('go', names)
        self.assertNotIn('ts', names)

    def test_absent_node_discovery_named(self):
        # Exercise the unmodified resolver: no node on PATH or nvm candidates.
        # HOME stays unchanged; ls alone models the absent nvm installation.
        with tempfile.TemporaryDirectory(dir=os.environ['TMPDIR']) as directory:
            root = Path(directory)
            bin_dir = root / 'bin'
            bin_dir.mkdir()
            for name in ('bash', 'date', 'sort'):
                path = shutil.which(name)
                self.assertIsNotNone(path)
                (bin_dir / name).symlink_to(path)
            (bin_dir / 'python3').symlink_to(sys.executable)
            make = shutil.which('make')
            self.assertIsNotNone(make)
            for name, code in (('git', 0), ('ls', 1), ('go', 99), ('rules_check', 99)):
                path = bin_dir / name
                path.write_text(f'#!/bin/sh\nexit {code}\n')
                path.chmod(0o755)
            env = dict(os.environ, PATH=str(bin_dir), GO_BIN='go', RULES_CHECK_BIN='rules_check',
                       CARGO_TARGET_DIR=str(root / 'target'), GOCACHE=str(root / 'go-cache'),
                       FIXTURES_PROOF_OUT=str(root / 'receipts'), PYTHONDONTWRITEBYTECODE='1')
            env.pop('NODE_BIN', None)
            result = subprocess.run([make, 'fixtures-proof', f'PATH={bin_dir}'],
                                    cwd=Path(proof.__file__).resolve().parent.parent,
                                    env=env, text=True, stdout=subprocess.PIPE,
                                    stderr=subprocess.STDOUT, check=False, timeout=10)
            self.assertEqual(result.returncode, 2, result.stdout)
            verdict = 'fixtures-proof: SKIPPED BY NAME (node unavailable)'
            self.assertIn(verdict, result.stdout)
            receipts = list((root / 'receipts').glob('*/receipt.json'))
            self.assertEqual(len(receipts), 1)
            receipt = json.loads(receipts[0].read_text())
            self.assertEqual(receipt['verdict'], verdict)
            self.assertEqual(receipt['exit'], 2)
            self.assertEqual([step['name'] for step in receipt['commands']],
                             ['commit', 'status', 'node-path'])
            resolver = receipt['commands'][-1]
            self.assertEqual(resolver['exit'], 1)
            self.assertIn('no node found', Path(resolver['log']).read_text())


if __name__ == '__main__':
    unittest.main()
