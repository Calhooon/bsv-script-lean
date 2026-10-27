#!/usr/bin/env python3
"""The overlay generator and the mount (THE FLIP RULE's private overlay); a synthetic repository, export and
manifest in a temporary directory, never this tree's. Run by hand: python3 tools/test_export_overlay.py"""
import hashlib
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import export_overlay as overlay  # noqa: E402

MOUNT = HERE / 'overlay_mount.sh'


def git(root, *args):
    return subprocess.run(['git', '-C', str(root), *args], capture_output=True, text=True, check=True).stdout


def sha(data):
    return hashlib.sha256(data).hexdigest()


class OverlayTests(unittest.TestCase):
    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp(prefix='overlay-test-'))
        # the generator writes under ~/bsv/targets only; the test points that rule at the temp dir
        self.home = os.environ.get('HOME')
        os.environ['HOME'] = str(self.tmp)
        (self.tmp / 'bsv' / 'targets').mkdir(parents=True)
        self.priv = self.tmp / 'private'
        self.priv.mkdir()
        git(self.priv, 'init', '-q')
        git(self.priv, 'config', 'user.email', 'test@example.invalid')
        git(self.priv, 'config', 'user.name', 'test')
        self.files = {
            'README.md': b'public page\n',
            'docs/records/r1.md': b'a record naming a private host\n',
            'tools/secret.sh': b'#!/bin/sh\necho withheld\n',
            'corpus/a.jsonl': b'{"id":"x","tx":"deadbeef"}\n',
        }
        for path, data in self.files.items():
            f = self.priv / path
            f.parent.mkdir(parents=True, exist_ok=True)
            f.write_bytes(data)
        os.chmod(self.priv / 'tools/secret.sh', 0o755)
        git(self.priv, 'add', '-A')
        git(self.priv, 'commit', '-q', '-m', 'private tree')
        self.commit = git(self.priv, 'rev-parse', 'HEAD').strip()
        # the export: README identical, the record transformed, the secret withheld, the corpus row transformed
        self.export = self.tmp / 'bsv' / 'targets' / 'spec-export' / 'e1'
        self.exported = {
            'README.md': b'public page\n',
            'docs/records/r1.md': b'a record naming WITHHELD: host\n',
            'corpus/a.jsonl': b'{"id":"x","tx":"WITHHELD: d7 (see corpus/INDEX.md)"}\n',
        }
        for path, data in self.exported.items():
            f = self.export / path
            f.parent.mkdir(parents=True, exist_ok=True)
            f.write_bytes(data)
        lines = ['# export manifest', f'source-commit {self.commit}', 'exported-at 2026-10-27 00:00:00 UTC']
        lines += [f'{sha(data)}  {path}' for path, data in self.exported.items()]
        (self.export / overlay.MANIFEST).write_text('\n'.join(lines) + '\n')
        # the public edition: a git checkout of the export (what a stranger clones)
        self.public = self.tmp / 'public'
        subprocess.run(['cp', '-R', str(self.export), str(self.public)], check=True)
        git(self.public, 'init', '-q')
        git(self.public, 'config', 'user.email', 'test@example.invalid')
        git(self.public, 'config', 'user.name', 'test')
        git(self.public, 'add', '-A')
        git(self.public, 'commit', '-q', '-m', 'public edition')
        self.public_sha = git(self.public, 'rev-parse', 'HEAD').strip()
        self.target = self.tmp / 'bsv' / 'targets' / 'spec-overlay' / 'o1'

    def tearDown(self):
        os.environ['HOME'] = self.home
        subprocess.run(['rm', '-rf', str(self.tmp)])

    def generate(self):
        _, rows, absent, restored = overlay.build_overlay(self.commit, self.export, self.target, self.public_sha, root=str(self.priv))
        return rows, absent, restored

    def test_overlay_is_the_withheld_and_transformed_paths_only(self):
        rows, absent, restored = self.generate()
        self.assertEqual((absent, restored), (1, 2))
        where = {path: w for _, path, w in rows}
        self.assertEqual(where, {'README.md': 'public', 'docs/records/r1.md': 'overlay',
                                 'tools/secret.sh': 'overlay', 'corpus/a.jsonl': 'overlay'})
        self.assertFalse((self.target / 'README.md').exists())
        self.assertEqual((self.target / 'docs/records/r1.md').read_bytes(), self.files['docs/records/r1.md'])
        self.assertTrue(os.access(self.target / 'tools/secret.sh', os.X_OK))
        text = (self.target / overlay.OVERLAY_MANIFEST).read_text()
        self.assertIn(f'source-commit {self.commit}', text)
        self.assertIn(f'public-commit {self.public_sha}', text)
        self.assertIn('paths-overlay 3', text)
        self.assertIn(f'{sha(self.files["README.md"])}  README.md  public', text)

    def test_refuses_an_export_of_another_commit(self):
        man = self.export / overlay.MANIFEST
        man.write_text(man.read_text().replace(self.commit, '0' * 40))
        with self.assertRaises(SystemExit) as cm:
            self.generate()
        self.assertEqual(cm.exception.code, 2)

    def test_mount_reproduces_the_private_tree_keeps_status_clean_and_unmounts(self):
        self.generate()
        run = subprocess.run(['bash', str(MOUNT), str(self.target), str(self.public), '--verify'], capture_output=True, text=True)
        self.assertEqual(run.returncode, 0, run.stdout + run.stderr)
        self.assertIn('VERIFIED 4 paths = the tree of ' + self.commit, run.stdout)
        for path, data in self.files.items():
            self.assertEqual((self.public / path).read_bytes(), data, path)
        self.assertEqual(git(self.public, 'status', '--short'), '')
        exclude = (self.public / '.git' / 'info' / 'exclude').read_text()
        self.assertIn('/tools/secret.sh\n', exclude)
        self.assertNotIn('/docs/records/r1.md', exclude)  # tracked: skip-worktree instead
        self.assertIn('S docs/records/r1.md', git(self.public, 'ls-files', '-v', 'docs/records/r1.md'))
        # a pathspec add of a mounted path stages nothing
        subprocess.run(['git', '-C', str(self.public), 'add', 'tools/secret.sh', 'docs/records/r1.md'], capture_output=True)
        self.assertEqual(git(self.public, 'diff', '--cached', '--name-only'), '')
        # a public path that moved under the overlay is RED, not a pass
        (self.public / 'README.md').write_bytes(b'tampered\n')
        run = subprocess.run(['bash', str(MOUNT), str(self.target), str(self.public), '--verify'], capture_output=True, text=True)
        self.assertEqual(run.returncode, 1, run.stdout + run.stderr)
        self.assertIn('RED README.md differs', run.stdout)
        self.assertIn('RED 1 of 4 paths', run.stdout)
        git(self.public, 'checkout', '--', 'README.md')
        run = subprocess.run(['bash', str(MOUNT), str(self.target), str(self.public), '--unmount'], capture_output=True, text=True)
        self.assertEqual(run.returncode, 0, run.stdout + run.stderr)
        self.assertFalse((self.public / 'tools/secret.sh').exists())
        self.assertEqual((self.public / 'docs/records/r1.md').read_bytes(), self.exported['docs/records/r1.md'])
        self.assertEqual(git(self.public, 'status', '--short'), '')
        self.assertNotIn('/tools/secret.sh', (self.public / '.git' / 'info' / 'exclude').read_text())

    def test_mount_refuses_another_public_commit_unless_waived(self):
        self.generate()
        (self.public / 'NEW.md').write_text('later\n')
        git(self.public, 'add', 'NEW.md')
        git(self.public, 'commit', '-q', '-m', 'later')
        run = subprocess.run(['bash', str(MOUNT), str(self.target), str(self.public)], capture_output=True, text=True)
        self.assertEqual(run.returncode, 2)
        self.assertIn('pairs with the public edition', run.stderr)
        run = subprocess.run(['bash', str(MOUNT), str(self.target), str(self.public), '--any-public', '--verify'], capture_output=True, text=True)
        self.assertEqual(run.returncode, 0, run.stdout + run.stderr)


if __name__ == '__main__':
    unittest.main()
