#!/usr/bin/env python3
"""Regression checks for pointer redaction, accounting and portable launch paths (#101)."""
import io
import os
import plistlib
import re
import subprocess
import unittest
from pathlib import Path

import export_public as public
import export_gate as gate


class PointerTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.groups = public.load_substitutions(public.POINTERS)
        cls.pointers = public.load_pointers(public.POINTERS)
        cls.grouped = gate.load_groups(public.POINTERS, re.I)
        cls.home = '/' + 'Users' + '/sample'
        cls.lanes = '/' + 'Volumes' + '/Lanes'
        cls.modal = 'spec' + '-check-records'
        cls.profile = 'cal' + 'gooon'
        # The six inventoried forms, the modal prefix, and app/volume contexts.
        cls.profile_spellings = [
            ('--profile ', '', None),
            ('profile ', '. Every run is named', None),
            ('profile `', '`', None),
            ('Modal profile **`', '`**', None),
            ('MODAL_PROFILE=', ' modal run', None),
            ('modal ', '', None),
            ('https://modal.com/apps/', '/main/ap-example', None),
        ]
        for app in ('spec' + '-check', 'spec' + '-x86-node', cls.modal,
                    'spec' + '-check-probe-56', 'spec' + '-gobdk-teranode'):
            cls.profile_spellings.extend(('', sep + app, app) for sep in (' ', '/', ':'))
        cls.address = 'sample' + '@' + 'example.test'

    def test_modal_profile_spellings_replace_only_names(self):
        for prefix, suffix, app in self.profile_spellings:
            for uppercase in (False, True):
                with self.subTest(prefix=prefix, suffix=suffix, uppercase=uppercase):
                    text = prefix + self.profile + suffix + '\r\n'
                    if uppercase:
                        text = text.upper()
                    name = self.profile.upper() if uppercase else self.profile
                    expected = text.replace(name, '<modal-name>')
                    if app:
                        expected = expected.replace(app.upper() if uppercase else app, '<modal-name>')
                    original = text.encode()
                    output, counts = public.substitute_pointers('docs/example.md', original, original, self.groups)
                    self.assertTrue(output == expected.encode(), 'Modal context or surrounding bytes changed')
                    self.assertEqual(counts, {'local-paths': 0, 'modal-names': 2 if app else 1, 'addresses': 0})
                    self.assertTrue(any(p.search(text) for g, p in self.grouped if g == 'modal-names'))
                    self.assertFalse(any(p.search(output.decode()) for g, p in self.grouped if g == 'modal-names'))

    def test_modal_profile_record_spellings_are_removed_and_counted(self):
        for prefix, suffix, app in self.profile_spellings:
            with self.subTest(prefix=prefix, suffix=suffix):
                original = (prefix + self.profile + suffix + '\r\nkeep\r\n').encode()
                output, lines = public.transform(original, self.pointers)
                result, counts = public.substitute_pointers('docs/records/example.md', output, original, self.groups)
                self.assertEqual(lines, 1)
                self.assertTrue(result == output, 'record transform header or markers changed')
                self.assertTrue(result.endswith((f'{public.MARKER}\r\nkeep\r\n').encode()))
                self.assertEqual(counts, {'local-paths': 0, 'modal-names': 2 if app else 1, 'addresses': 0})

    def test_github_organisation_urls_and_paths_stay_intact(self):
        for template in ('https://api.github.com/repos/{}/bsv-script-lean/issues/64',
                         'https://github.com/{}/bsv-script-lean',
                         'repos/{}/bsv-script-lean', '{}/bsv-script-lean',
                         'profile {}/bsv-script-lean'):
            for uppercase in (False, True):
                with self.subTest(template=template, uppercase=uppercase):
                    text = template.format(self.profile)
                    if uppercase:
                        text = text.upper()
                    original = (text + '\n').encode()
                    output, counts = public.substitute_pointers('docs/example.md', original, original, self.groups)
                    self.assertTrue(output == original, 'public organisation URL or path changed')
                    self.assertFalse(any(counts.values()))
                    self.assertFalse(any(p.search(text) for g, p in self.grouped if g == 'modal-names'))
                    output, lines = public.transform(original, self.pointers)
                    self.assertTrue(output == original, 'public URL record line changed')
                    self.assertEqual(lines, 0)
                    _, counts = public.substitute_pointers('docs/records/example.md', output, original, self.groups)
                    self.assertFalse(any(counts.values()))
        # A Modal app literal remains gated even when it is also a repository name.
        for prefix in ('https://github.com/', 'https://api.github.com/repos/', 'repos/'):
            original = (prefix + self.profile + '/' + self.modal).encode()
            output, counts = public.substitute_pointers('docs/example.md', original, original, self.groups)
            self.assertTrue(output == (prefix + self.profile + '/<modal-name>').encode())
            self.assertEqual(counts['modal-names'], 1)

    def test_bare_profile_prose_and_similar_names_stay_intact(self):
        for template in ('{}', 'Published by {}.', 'notprofile {}', 'modalish {}',
                         'profile {}-other', 'profile {}.other', 'MODAL_PROFILE={}other'):
            with self.subTest(template=template):
                original = (template.format(self.profile) + '\n').encode()
                output, counts = public.substitute_pointers('docs/example.md', original, original, self.groups)
                self.assertTrue(output == original, 'bare organisation name or another profile changed')
                self.assertFalse(any(counts.values()))
                self.assertFalse(any(p.search(original.decode()) for g, p in self.grouped if g == 'modal-names'))

    def test_substrings_and_literal_precedence(self):
        original = (f'{self.home}/docs {self.home.upper()}/tools {self.lanes}/lane '
                    f'{self.modal.upper()} {self.address}; @bsv/sdk @[M] @\r\n').encode() + b'\xff\n'
        output, counts = public.substitute_pointers('docs/example.md', original, original, self.groups)
        expected = b'~/docs ~/tools <lanes-volume>/lane <modal-name> <address>; @bsv/sdk @[M] @\r\n\xff\n'
        self.assertTrue(output == expected, 'surrounding bytes or replacements changed')
        self.assertEqual(counts, {'local-paths': 3, 'modal-names': 1, 'addresses': 1})
        for pattern in self.groups.values():
            self.assertFalse(pattern.search(output.decode('utf-8', 'surrogateescape')))

    def test_records_keep_line_removal_and_occurrence_counts(self):
        original = (f'{self.home}/one {self.home}/two {self.modal} {self.address}\r\n'
                    'keep @bsv/sdk @[M] and @\r\n').encode()
        output, lines = public.transform(original, self.pointers)
        result, counts = public.substitute_pointers('docs/audit/example.txt', output, original, self.groups)
        self.assertEqual(lines, 1)
        self.assertTrue(result == output, 'record marker changed')
        self.assertTrue(result.endswith(b'keep @bsv/sdk @[M] and @\r\n'))
        self.assertEqual(counts, {'local-paths': 2, 'modal-names': 1, 'addresses': 1})

    def test_absolute_path_starts_and_bare_home_prefix(self):
        bare = '/' + 'Users' + '/'
        for prefix in ('', ' ', '\t', '\n', '"', "'", '`', '[', '(', '{', '<', '=', ':', ';', ',', '|', '&', '@'):
            for path, replacement in ((self.home + '/file', '~/file'),
                                      (self.lanes + '/file', '<lanes-volume>/file'), (bare, '~')):
                original = (prefix + path + '\n').encode()
                output, counts = public.substitute_pointers('docs/example.md', original, original, self.groups)
                self.assertTrue(output == (prefix + replacement + '\n').encode(), 'path boundary changed')
                self.assertEqual(counts['local-paths'], 1)
                self.assertTrue(any(p.search(original.decode()) for g, p in self.grouped if g == 'local-paths'))
        original = (bare + '\r\n').encode()
        output, count = public.transform(original, self.pointers)
        self.assertEqual(count, 1)
        self.assertTrue(output.endswith((public.MARKER + '\r\n').encode()))

    def test_relative_path_counterexamples_stay_intact(self):
        home = '/' + 'Users' + '/example/file'
        volume = self.lanes + '/file'
        for path in ('docs' + home, '~' + home, 'docs' + volume, '~' + volume):
            original = (path + '\n').encode()
            output, counts = public.substitute_pointers('docs/example.md', original, original, self.groups)
            self.assertTrue(output == original, 'relative path changed')
            self.assertFalse(any(counts.values()))
            self.assertFalse(any(p.search(path) for g, p in self.grouped if g == 'local-paths'))
        for prefix in ('a', 'Z', '0', '9', '~', '.', '/', '-', '_', 'é'):
            self.assertFalse(self.groups['local-paths'].search(prefix + home))
            self.assertFalse(self.groups['local-paths'].search(prefix + volume))

    def test_json_record_stays_json_with_matched_strings_and_keys_withheld(self):
        # the hosted gate of 2026-10-26: a one-line JSON record whose line was withheld was not JSON (63 of 186)
        import json
        pointers = public.load_pointers(public.POINTERS)
        home = '~' + 'john' + 'calhoun' + '/bsv/x'
        one = json.dumps({'commit': 'abc1234', 'path': home, 'source_sha256': {home + '/a': '00', home + '/b': '11'},
                          'counts': {'go-sdk|gen|spec|splice.substr.' + 'negative-offset': 1, 'plain': 2}}) + '\n'
        out, n = public.transform_json(one.encode(), pointers)
        got = json.loads(out)
        self.assertEqual(n, 4)
        self.assertEqual(got['commit'], 'abc1234')
        self.assertEqual(got['path'], public.MARKER)
        self.assertEqual(sorted(got['source_sha256']), [f'{public.MARKER} (key 1)', f'{public.MARKER} (key 2)'])
        self.assertEqual(got['counts'], {f'{public.MARKER} (key 1)': 1, 'plain': 2})
        self.assertEqual(out.count(b'\n'), 1)  # one line in, one line out
        self.assertNotIn(b'calhoun', out)
        many = json.dumps({'path': home, 'k': [1, 2]}, indent=2).encode()
        out, n = public.transform_json(many, pointers)
        self.assertEqual(n, 1)
        self.assertEqual(json.loads(out)['path'], public.MARKER)
        self.assertGreater(out.count(b'\n'), 1)  # the indented shape kept
        clean = b'{"path": "relative/only", "n": 1}\n'
        self.assertEqual(public.transform_json(clean, pointers), (clean, 0))

    def test_agent_paths_withhold_record_lines_and_stay_out_of_substitution(self):
        account = '-' + 'Users' + '-sample-bsv-'
        scratch = '/' + 'private/tmp/claude-501/' + account + 'x/0000/scratchpad'
        for line in (f'SP={scratch}\n', f'memory (`~/.claude/projects/{account}x/memory/`) held\n'):
            original = line.encode()
            output, count = public.transform(original, self.pointers)
            self.assertEqual(count, 1, line)
            self.assertTrue(output.endswith((public.MARKER + '\n').encode()))
            result, counts = public.substitute_pointers('docs/example.md', original, original, self.groups)
            self.assertTrue(result == original, 'agent path substituted')
            self.assertFalse(any(counts.values()))
            self.assertTrue(any(p.search(line) for g, p in self.grouped if g == 'agent-paths'))
        bare = 'john' + 'calhoun'
        output, count = public.transform(f'local account `{bare}`, host x\n'.encode(), self.pointers)
        self.assertEqual(count, 1)
        output, count = public.transform(b'John and the harness\n', self.pointers)
        self.assertEqual(count, 0)
        for line in ('the Users table\n', 'Users-of-the-harness\n', '/private/tmp/other\n'):
            output, count = public.transform(line.encode(), self.pointers)
            self.assertEqual(count, 0, line)

    def test_other_pointer_groups_remain_gated(self):
        original = ('null' + 'ifier').encode()
        output, counts = public.substitute_pointers('docs/example.md', original, original, self.groups)
        self.assertTrue(output == original)
        self.assertFalse(any(counts.values()))
        self.assertTrue(any(p.search(output.decode()) for p in self.pointers))

    def test_generic_roster_words_stay(self):
        original = b'The Studio, box, mini, Mac-Studio and Mac mini are roles.\n'
        output, counts = public.substitute_pointers('docs/example.md', original, original, self.groups)
        self.assertTrue(output == original)
        self.assertFalse(any(counts.values()))
        self.assertFalse(any(p.search(original.decode()) for g, p in self.grouped if g == 'machine-hosts'))

    def test_manifest_and_zero_group_summary(self):
        changes = [('docs/example.md', {'local-paths': 2, 'modal-names': 1, 'addresses': 1}),
                   ('docs/records/example.md', {'local-paths': 3, 'modal-names': 0, 'addresses': 0})]
        manifest = io.StringIO()
        # This writer reports counts only; capture its summary for this check.
        from contextlib import redirect_stdout
        with redirect_stdout(io.StringIO()):
            public.write_pointer_manifest(manifest, changes, self.groups)
        text = manifest.getvalue()
        self.assertIn('pointer-group local-paths 5 occurrences; records 3; substitutions 2', text)
        self.assertIn('3  local-paths  records  docs/records/example.md', text)
        summary = gate.pointer_summary({}, self.grouped)
        for group in set(g for g, _ in self.grouped):
            self.assertIn(f'; {group} 0', summary)

    def test_remote_home_supplies_all_launch_paths(self):
        script = Path(public.ROOT, 'harness/oracle/spec-node.sh').read_text()
        definition = 'plist() {' + script.split('plist() {', 1)[1].split('\n}\n', 1)[0] + '\n}\n'
        env = {k: v for k, v in os.environ.items() if k not in ('BASH_ENV', 'ENV')}
        env.update(MINI_ROOT='bsv/spec-oracle', LABEL='sample.oracle',
                   SPEC_ORACLE_RPC_PORT='18563', SPEC_ORACLE_P2P_PORT='18564')
        remote_home = '/srv/remote home'
        result = subprocess.run(['/bin/bash', '--noprofile', '--norc', '-c',
                                 definition + 'plist "$1"', 'test', remote_home],
                                env=env, check=True, capture_output=True)
        row = plistlib.loads(result.stdout)
        self.assertEqual(row['ProgramArguments'][:4], [remote_home + '/bsv/oracle/bin/bitcoind',
                         '-regtest', '-conf=' + remote_home + '/bsv/spec-oracle/bitcoin.conf',
                         '-datadir=' + remote_home + '/bsv/spec-oracle/data'])
        self.assertEqual(row['StandardOutPath'], remote_home + '/bsv/spec-oracle/log/bitcoind.out')
        self.assertEqual(row['StandardErrorPath'], remote_home + '/bsv/spec-oracle/log/bitcoind.err')


if __name__ == '__main__':
    unittest.main()
