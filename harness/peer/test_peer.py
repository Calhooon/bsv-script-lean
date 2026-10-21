#!/usr/bin/env python3
"""[X] 2026-10-13: reject unsafe endpoints and a mismatched instrument pin.
These subprocess tests send no P2P messages and start no node.
"""
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
DRIVER = ROOT / 'harness/peer/peer.py'
sys.path.insert(0, str(ROOT / 'tools'))
import host_vars  # noqa: E402

# the reference clone (docs/PROVENANCE.md 1a `$BSV_SPEC_REFERENCE_CLONE`, #177): a test that reaches peer.py's default
# framework or names the clone is skipped by name when it is unresolved
REFERENCE_CLONE = host_vars.value('BSV_SPEC_REFERENCE_CLONE')
needs_clone = unittest.skipIf(REFERENCE_CLONE is None, host_vars.refusal('test_peer', 'BSV_SPEC_REFERENCE_CLONE'))

class PeerBoundaryTests(unittest.TestCase):
    @needs_clone
    def test_non_loopback_and_unreserved_ports_are_refused_before_transport(self):
        for request in ({'op': 'connect', 'host': '192.0.2.1', 'port': 18572},
                        {'op': 'connect', 'host': '127.0.0.1', 'port': 18563}):
            with self.subTest(request=request), tempfile.TemporaryDirectory() as directory:
                path = Path(directory) / 'receipt.jsonl'
                result = subprocess.run(['python3', str(DRIVER), '--receipt', str(path)],
                                        input=json.dumps(request) + '\n', text=True,
                                        capture_output=True, timeout=10, cwd=ROOT)
                self.assertEqual(result.returncode, 0, result.stderr)
                reply = json.loads(result.stdout)
                self.assertFalse(reply['ok'])
                self.assertEqual(reply['source_pin'], '6504a3aff65ba97c0f6c80962b033e35ecbfed4b')
                events = [json.loads(line) for line in path.read_text().splitlines()]
                self.assertFalse(any(event['direction'] in ('send', 'receive') for event in events))

    @needs_clone
    def test_connect_without_scenario_clock_is_refused_before_transport(self):
        # [X] 2026-10-13 (#72): the advertised time is the scenario's, never the host's.
        for request in ({'op': 'connect', 'host': '127.0.0.1', 'port': 18572},
                        {'op': 'connect', 'host': '127.0.0.1', 'port': 18572, 'time': 0},
                        {'op': 'connect', 'host': '127.0.0.1', 'port': 18572, 'time': 1.5}):
            with self.subTest(request=request), tempfile.TemporaryDirectory() as directory:
                path = Path(directory) / 'receipt.jsonl'
                result = subprocess.run(['python3', str(DRIVER), '--receipt', str(path)],
                                        input=json.dumps(request) + '\n', text=True,
                                        capture_output=True, timeout=10, cwd=ROOT)
                self.assertEqual(result.returncode, 0, result.stderr)
                reply = json.loads(result.stdout)
                self.assertFalse(reply['ok'])
                self.assertIn('scenario mock time', reply['error'])
                events = [json.loads(line) for line in path.read_text().splitlines()]
                self.assertFalse(any(event['direction'] in ('send', 'receive') for event in events))

    def test_wrong_clone_pin_stops_before_import_and_receipt_creation(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'receipt.jsonl'
            result = subprocess.run(['python3', str(DRIVER), '--framework', str(ROOT / 'harness/peer'),
                                     '--receipt', str(path)], text=True, capture_output=True,
                                    timeout=10, cwd=ROOT)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn('reference HEAD differs from pin', result.stderr)
            self.assertFalse(path.exists())

    @needs_clone
    def test_noncanonical_framework_is_refused_before_receipt(self):
        clone = Path(REFERENCE_CLONE)
        for framework in (clone / 'test/alternative', clone / 'src/test/functional'):
            with self.subTest(framework=framework), tempfile.TemporaryDirectory() as directory:
                path = Path(directory) / 'receipt.jsonl'
                result = subprocess.run(['python3', str(DRIVER), '--framework', str(framework),
                                         '--receipt', str(path)], capture_output=True, text=True,
                                        timeout=10, cwd=ROOT)
                self.assertNotEqual(result.returncode, 0)
                self.assertIn('framework root is not canonical', result.stderr)
                self.assertFalse(path.exists())

    def test_untracked_source_is_refused_before_import_and_receipt(self):
        import os
        with tempfile.TemporaryDirectory() as directory:
            base = Path(directory)
            framework = base / 'clone/test/functional'
            framework.mkdir(parents=True)
            git = base / 'git'
            git.write_text("#!/bin/sh\ncase \"$3\" in\nrev-parse) if [ \"$4\" = --show-toplevel ]; then echo \"$2\"; else echo 6504a3aff65ba97c0f6c80962b033e35ecbfed4b; fi;;\nstatus) echo '?? test/functional/test_framework/shadow.py';;\nesac\n")
            git.chmod(0o755)
            path = base / 'receipt.jsonl'
            result = subprocess.run(['python3', str(DRIVER), '--framework', str(framework),
                                     '--receipt', str(path)], capture_output=True, text=True,
                                    timeout=10, cwd=ROOT,
                                    env={**os.environ, 'PATH': str(base) + os.pathsep + os.environ['PATH']})
            self.assertNotEqual(result.returncode, 0)
            self.assertIn('framework source is dirty or untracked', result.stderr)
            self.assertFalse(path.exists())

    @needs_clone
    def test_imported_origin_is_refused_before_receipt(self):
        import os
        with tempfile.TemporaryDirectory() as directory:
            base = Path(directory)
            (base / 'sitecustomize.py').write_text(
                "import sys, types\n"
                "for name in ('test_framework', 'test_framework.mininode', 'test_framework.transport'):\n"
                "    module = types.ModuleType(name)\n"
                "    module.__file__ = __file__\n"
                "    module.Connection = module.NetworkThread = object\n"
                "    sys.modules[name] = module\n")
            path = base / 'receipt.jsonl'
            result = subprocess.run(['python3', str(DRIVER), '--receipt', str(path)],
                                    capture_output=True, text=True, timeout=10, cwd=ROOT,
                                    env={**os.environ, 'PYTHONPATH': str(base)})
            self.assertNotEqual(result.returncode, 0)
            self.assertIn('imported framework module is outside pinned source', result.stderr)
            self.assertFalse(path.exists())

if __name__ == '__main__':
    unittest.main()
