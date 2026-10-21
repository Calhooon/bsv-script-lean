#!/usr/bin/env python3
"""Public header path rules retain the hex gate on every other corpus path."""
import hashlib
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest


SCRIPT = Path(__file__).with_name('mechanism_hex.py').resolve()


class PublicHeaderPathTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.base = Path(self.tmp.name)
        self.root = self.base / 'export'
        self.root.mkdir()
        self.comparison = self.base / 'comparison'
        self.comparison.mkdir()
        self.hex_value = hashlib.sha256(b'mechanism path exemption negative control').hexdigest()
        (self.comparison / 'fixture.txt').write_text(self.hex_value + '\n')
        subprocess.run(['git', 'init', '-q', str(self.comparison)], check=True, capture_output=True)
        subprocess.run(['git', 'add', 'fixture.txt'], cwd=self.comparison, check=True, capture_output=True)

    def corpus_file(self, relative, root=None):
        path = (root or self.root) / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text('{"hex":"' + self.hex_value + '"}\n')
        return path

    def scan(self, *files):
        return subprocess.run([sys.executable, str(SCRIPT), '--root', str(self.root),
                               str(self.comparison), '--', *(str(path) for path in files)],
                              capture_output=True, text=True)

    def test_header_family_is_exempt_by_path_with_reason(self):
        result = self.scan(self.corpus_file('corpus/chain/headers/mainnet.jsonl'),
                           self.corpus_file('corpus/chain/headers/another-window.jsonl'))
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.count('public data skipped by name: Public chain headers'), 2)
        self.assertNotIn('(2) FAIL:', result.stdout)

    def test_same_hex_in_another_corpus_file_still_fails(self):
        header = self.corpus_file('corpus/chain/headers/mainnet.jsonl')
        other = self.corpus_file('corpus/seed/planted.jsonl')
        result = self.scan(header, other)
        self.assertEqual(result.returncode, 1, result.stderr)
        self.assertIn(f'contains a hex string of {other}:', result.stdout)
        self.assertNotIn(f'contains a hex string of {header}:', result.stdout)
        self.assertIn('1 hit(s)', result.stdout)

    def test_nearby_and_nested_paths_are_checked(self):
        for relative in ('corpus/chain/header/mainnet.jsonl',
                         'corpus/chain/headers-extra/mainnet.jsonl',
                         'corpus/chain/headers/nested/mainnet.jsonl',
                         'corpus/chain/headers/mainnet.jsonl.bak',
                         'corpus/chain/headers/mainnet.json',
                         'corpus/other/corpus/chain/headers/mainnet.jsonl',
                         'other/corpus/chain/headers/mainnet.jsonl'):
            with self.subTest(path=relative):
                result = self.scan(self.corpus_file(relative))
                self.assertEqual(result.returncode, 1, result.stderr)
                self.assertIn('(2) FAIL:', result.stdout)
                self.assertNotIn('public data skipped', result.stdout)

    def test_matching_suffix_outside_checked_tree_is_checked(self):
        result = self.scan(self.corpus_file('corpus/chain/headers/mainnet.jsonl', self.base / 'outside'))
        self.assertEqual(result.returncode, 1, result.stderr)
        self.assertIn('(2) FAIL:', result.stdout)
        self.assertNotIn('public data skipped', result.stdout)


if __name__ == '__main__':
    unittest.main()
