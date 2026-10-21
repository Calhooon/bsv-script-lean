#!/usr/bin/env python3
"""The Cargo transform, its source stop and the commit-read of the lists (#107); synthetic fixtures."""
from contextlib import redirect_stdout
import io
import os
from pathlib import Path
import subprocess
import tempfile
import tomllib
import unittest
from unittest.mock import patch

import export_gate as gate
import export_public as export

RULES = [('example-group', 'harness/src/bin/hidden.rs')]
MANIFEST = (b'# a fixture crate\n'
            b'[package]\nname = "fixture"\nversion = "0.0.1"\n\n'
            b'[[bin]]\nname = "kept"\npath = "src/bin/kept.rs"\n\n'
            b'# the hidden generator\n[[bin]]\nname = "hidden"\npath = "src/bin/hidden.rs"\n\n'
            b'[profile.release]\ndebug = 1\n')


class CargoTransformTests(unittest.TestCase):
    def test_withheld_bin_dropped_and_everything_else_byte_identical(self):
        public, dropped, spans = export.withhold_cargo_targets('harness/Cargo.toml', MANIFEST, RULES)
        self.assertEqual(dropped, [('bin', 'hidden')])
        head, body = public.split(b'\n', 1)
        self.assertTrue(head.startswith(b'# [export: 1 target table withheld by tools/export_public.py'))
        lines = body.decode().splitlines(keepends=True)
        for start, removed in spans:
            lines[start:start] = removed
        self.assertEqual(''.join(lines).encode(), MANIFEST)
        parsed = tomllib.loads(public.decode())
        self.assertEqual([b['name'] for b in parsed['bin']], ['kept'])
        self.assertEqual(parsed['profile'], {'release': {'debug': 1}})
        self.assertEqual(export.cargo_named_withheld('harness/Cargo.toml', public, RULES), [])
        self.assertEqual(export.cargo_named_withheld('harness/Cargo.toml', MANIFEST, RULES), ['harness/src/bin/hidden.rs'])

    def test_no_withheld_target_returns_the_same_bytes(self):
        self.assertEqual(export.withhold_cargo_targets('harness/Cargo.toml', MANIFEST, [])[0], MANIFEST)

    def test_repository_manifest_round_trips(self):
        data = (Path(export.ROOT) / 'harness/Cargo.toml').read_bytes()
        public, dropped, spans = export.withhold_cargo_targets('harness/Cargo.toml', data, RULES)
        self.assertEqual((public, dropped), (data, []))

    def test_repository_manifest_drops_gen(self):
        # the real manifest under the real list: the `gen` stanza dropped, and the spans restore it byte for byte
        data = (Path(export.ROOT) / 'harness/Cargo.toml').read_bytes()
        public, dropped, spans = export.withhold_cargo_targets('harness/Cargo.toml', data, export.load_withheld(export.WITHHELD))
        self.assertEqual(dropped, [('bin', 'gen')])
        lines = public.split(b'\n', 1)[1].decode().splitlines(keepends=True)
        for start, removed in spans:
            lines[start:start] = removed
        self.assertEqual(''.join(lines).encode(), data)

    def build(self, files):
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        for rel, text in files.items():
            (Path(tmp.name) / rel).parent.mkdir(parents=True, exist_ok=True)
            (Path(tmp.name) / rel).write_text(text)
        return tmp.name

    def test_stop_on_a_mod_naming_a_withheld_source(self):
        rules = [('example-group', 'harness/src/hidden.rs')]
        target = self.build({'harness/Cargo.toml': '[package]\nname = "f"\nversion = "0.0.1"\n',
                             'harness/src/lib.rs': 'pub mod kept;\npub mod hidden;\n',
                             'harness/src/kept.rs': ''})
        exported = [('harness/Cargo.toml', '')]
        with redirect_stdout(io.StringIO()) as out, self.assertRaises(SystemExit) as stop:
            export.cargo_transform(target, rules, ['harness/src/hidden.rs'], exported)
        self.assertIn('STOP: an exported source loads a withheld path: harness/src/lib.rs:2', str(stop.exception))
        self.assertIn('2 mod, #[path] and include lines; 1 name a withheld basename; 1 resolve', out.getvalue())

    def test_same_basename_elsewhere_is_named_but_not_a_stop(self):
        target = self.build({'harness/Cargo.toml': MANIFEST.decode(),
                             'harness/src/lib.rs': 'pub mod hidden;\n', 'harness/src/hidden.rs': '',
                             'harness/src/bin/kept.rs': 'include!("../../data.rs");\n'})
        exported = [('harness/Cargo.toml', '')]
        with redirect_stdout(io.StringIO()) as out:
            changes, counts = export.cargo_transform(target, RULES, ['harness/src/bin/hidden.rs'], exported)
        self.assertEqual(changes, [('harness/Cargo.toml', [('bin', 'hidden')])])
        self.assertEqual(counts, (3, 2, 1))
        self.assertNotEqual(exported[0][1], '')
        self.assertIn('0 resolve to a withheld path', out.getvalue())

    def test_stop_when_a_manifest_still_names_a_withheld_path(self):
        target = self.build({'harness/Cargo.toml': '[package]\nname = "f"\nversion = "0.0.1"\nbuild = "src/bin/hidden.rs"\n'})
        with redirect_stdout(io.StringIO()), self.assertRaises(SystemExit) as stop:
            export.cargo_transform(target, RULES, [], [('harness/Cargo.toml', '')])
        self.assertIn('STOP: the exported harness/Cargo.toml still names 1 withheld path(s)', str(stop.exception))


MAKEFILE = (b'.PHONY: check hiddencases keptcases\n'
            b'check:\n\ttools/check.sh all\n'
            b'# Regenerate the hidden family\n# (two comment lines)\n'
            b'hiddencases:\n\tcd harness && cargo run --release --bin hidden -- \\\n\t  --out ../corpus/hidden\n\n'
            b'# Regenerate the kept family\nkeptcases:\n\tcd harness && cargo run --release --bin kept\n')


class MakefileTransformTests(unittest.TestCase):
    def test_target_running_a_dropped_binary_is_dropped_and_everything_else_byte_identical(self):
        public, targets, spans, phony = export.withhold_make_targets('Makefile', MAKEFILE, ['hidden'])
        self.assertEqual(targets, ['hiddencases'])
        head, body = public.split(b'\n', 1)
        self.assertTrue(head.startswith(b'# [export: 1 target withheld by tools/export_public.py'))
        lines = body.decode().splitlines(keepends=True)
        self.assertEqual(lines[0], '.PHONY: check keptcases\n')
        for i, line in phony.items():
            lines[i] = line
        for start, removed in spans:
            lines[start:start] = removed
        self.assertEqual(''.join(lines).encode(), MAKEFILE)
        self.assertNotIn(b'--bin hidden', public)
        self.assertIn(b'keptcases:\n\tcd harness && cargo run --release --bin kept\n', public)
        self.assertEqual(export.make_still_names(public, ['hidden'], targets), [])

    def test_no_dropped_binary_returns_the_same_bytes(self):
        self.assertEqual(export.withhold_make_targets('Makefile', MAKEFILE, [])[0], MAKEFILE)
        self.assertEqual(export.withhold_make_targets('Makefile', MAKEFILE, ['absent'])[0], MAKEFILE)

    def test_repository_makefile_drops_only_the_generator_target(self):
        data = (Path(export.ROOT) / 'Makefile').read_bytes()
        public, targets, _, _ = export.withhold_make_targets('Makefile', data, ['gen'])
        self.assertEqual(targets, ['gencases'])
        self.assertEqual(export.make_still_names(public, ['gen'], targets), [])

    def test_stop_when_a_makefile_still_names_a_dropped_binary_or_target(self):
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        text = MAKEFILE.decode() + 'all: hiddencases\n# a note: cargo run --bin hidden\n'
        Path(tmp.name, 'Makefile').write_text(text)
        exported = [('Makefile', '')]
        with redirect_stdout(io.StringIO()), self.assertRaises(SystemExit) as stop:
            export.make_transform(tmp.name, [('harness/Cargo.toml', [('bin', 'hidden')])], exported)
        self.assertIn('STOP: the exported Makefile still names a dropped binary or target at line(s) 8, 9',
                      str(stop.exception))

    def test_walk_rewrites_the_exported_copy_and_its_hash(self):
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        Path(tmp.name, 'Makefile').write_bytes(MAKEFILE)
        exported = [('Makefile', 'private')]
        with redirect_stdout(io.StringIO()) as out:
            changes, found = export.make_transform(tmp.name, [('harness/Cargo.toml', [('bin', 'hidden')])], exported)
        self.assertEqual((changes, found), ([('Makefile', ['hiddencases'])], 1))
        self.assertNotEqual(exported[0][1], 'private')
        self.assertNotIn(b'--bin hidden', Path(tmp.name, 'Makefile').read_bytes())
        self.assertIn('1 Makefiles, 1 targets dropped (dropped binaries: hidden)', out.getvalue())


class CommitReadTests(unittest.TestCase):
    def setUp(self):
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        self.root = tmp.name
        run = lambda *a: subprocess.run(['git', '-C', self.root, *a], check=True, capture_output=True)
        run('init', '-q')
        os.makedirs(os.path.join(self.root, 'tools'))
        for rel in export.LISTS:
            Path(self.root, rel).write_text('{}\n' if rel.endswith('.json') else '## example-group: a fixture\nkept/\n')
        run('add', '.')
        run('-c', 'user.name=t', '-c', 'user.email=<address>', 'commit', '-qm', 'fixture')
        self.commit = run('rev-parse', 'HEAD').stdout.decode().strip()
        Path(self.root, 'tools/export_withheld.txt').write_text('## example-group: edited\nedited/\n')

    def test_lists_are_read_at_the_commit_and_drift_is_named(self):
        with patch.object(export, 'ROOT', self.root), patch.object(export, 'LIST_COMMIT', self.commit):
            rules = export.load_withheld(os.path.join(self.root, 'tools/export_withheld.txt'))
            drift = export.list_drift(self.commit)
        self.assertEqual(rules, [('example-group', 'kept/')])
        self.assertEqual(drift, ['tools/export_withheld.txt'])
        with patch.object(export, 'ROOT', self.root):
            self.assertEqual(export.load_withheld(os.path.join(self.root, 'tools/export_withheld.txt')),
                             [('example-group', 'edited/')])


class BuildLegTests(unittest.TestCase):
    def test_missing_crate_is_named(self):
        stderr = ('error: no matching package named `absent-crate` found\n'
                  'error: failed to download `other-crate v1.2.3`\n')
        self.assertEqual(gate.missing_crates(stderr), ['absent-crate', 'other-crate v1.2.3'])


if __name__ == '__main__':
    unittest.main()
