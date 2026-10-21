#!/usr/bin/env python3
"""A failed subprocess or disappearing export cannot satisfy the gate."""
from contextlib import redirect_stdout
import io
from pathlib import Path
import re
import tempfile
import unittest
from unittest.mock import patch

import export_gate as gate


class GateFailureTests(unittest.TestCase):
    def run_fixture(self, script, manifest=True):
        with tempfile.TemporaryDirectory() as tmp:
            base = Path(tmp)
            target, tools = base / 'export', base / 'tools'
            (target / 'corpus').mkdir(parents=True)
            (target / 'corpus/sample.jsonl').write_text('{"id":"sample"}\n')
            if manifest:
                (target / gate.MANIFEST).write_text('source-commit sample\n')
            tools.mkdir()
            for name in ('export_pointers.txt', 'wording_allow.txt'):
                (tools / name).write_text('')
            (tools / 'export_withheld_metadata.json').write_text('{}')
            (tools / 'mechanism_hex.py').write_text(script)
            output = io.StringIO()
            with (patch.object(gate, 'TOOLS', str(tools)),
                  patch.object(gate, 'mechanism_lists', return_value=(re.compile(r'(?!)'), [str(base)])),
                  patch.object(gate, 'rule_entry_counts', return_value={}),
                  patch.object(gate, 'check_withheld_rules', return_value=([], [])),
                  patch.object(gate, 'check_rule_removal_counts', return_value=([], [])),
                  patch.object(gate.sys, 'argv', ['export_gate.py', str(target)]),
                  redirect_stdout(output)):
                try:
                    gate.main()
                    code = 0
                except SystemExit as error:
                    code = error.code
            return code, output.getvalue()

    def test_failed_hex_subprocess_is_never_clean(self):
        for code in (1, 2, 7):
            with self.subTest(exit=code):
                result, output = self.run_fixture(f'raise SystemExit({code})\n')
                self.assertEqual(result, 1)
                verdict = f'export gate: FAILED (mechanism leg 2 failed: exit {code}, 0 counted hit(s))'
                self.assertEqual(output.splitlines()[-1], verdict)
                self.assertNotIn('export gate: CLEAN', output)

    def test_hex_exception_after_a_hit_is_a_failed_leg(self):
        script = ('import sys\n'
                  'print("(2) FAIL: sample contains a hex string of " + sys.argv[-1] + ": sample")\n'
                  'raise RuntimeError("forced failure")\n')
        code, output = self.run_fixture(script)
        self.assertEqual(code, 1)
        self.assertIn('mechanism leg 2 failed: exit 1, 1 counted hit(s); stderr present', output)
        self.assertNotIn('export gate: CLEAN', output)

    def test_counted_hex_hit_still_fails_the_gate(self):
        script = ('import sys\n'
                  'print("(2) FAIL: sample contains a hex string of " + sys.argv[-1] + ": sample")\n'
                  'raise SystemExit(1)\n')
        code, output = self.run_fixture(script)
        self.assertEqual(code, 1)
        self.assertIn('(mechanism) 1 hit(s)', output)
        self.assertEqual(output.splitlines()[-1], 'export gate: FAILED')

    def test_manifest_removed_by_leg_is_never_clean(self):
        script = ('import pathlib, sys\n'
                  'root = pathlib.Path(sys.argv[-1]).parents[1]\n'
                  '(root / "EXPORT-MANIFEST.txt").unlink()\n')
        code, output = self.run_fixture(script)
        self.assertEqual(code, 1)
        self.assertEqual(output.strip(), 'export gate: FAILED (export manifest disappeared during mechanism leg 2)')

    def test_missing_manifest_is_a_failed_verdict(self):
        code, output = self.run_fixture('', manifest=False)
        self.assertEqual(code, 1)
        self.assertEqual(output.strip(), 'export gate: FAILED (missing export manifest)')

    def test_completed_leg_can_be_clean(self):
        code, output = self.run_fixture('raise SystemExit(0)\n')
        self.assertEqual(code, 0)
        self.assertEqual(output.splitlines()[-1], 'export gate: CLEAN')

    def test_hex_leg_receives_export_root_for_path_rules(self):
        script = ('import pathlib, sys\n'
                  'assert sys.argv[1] == "--root"\n'
                  'assert pathlib.Path(sys.argv[2]) == pathlib.Path(sys.argv[-1]).parents[1]\n')
        code, output = self.run_fixture(script)
        self.assertEqual(code, 0)
        self.assertEqual(output.splitlines()[-1], 'export gate: CLEAN')


if __name__ == '__main__':
    unittest.main()
