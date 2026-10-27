#!/usr/bin/env python3
"""The private overlay of a public edition (THE FLIP RULE, HANDOFF.md §0; the docket's I1 on archived #113):
"the withheld paths a private overlay the harness mounts".

The overlay of a commit C against its export E is every tracked path of C whose exported copy is absent or differs
from C's blob: the withheld whole files, and the private originals of the paths the export transformed (the
records with pointer substitutions, the corpus files with withheld entries, the classifier data with withheld
rules, the lakefile and the Cargo manifests with dropped targets). Mounting the overlay over a checkout of the
public edition (tools/overlay_mount.sh) gives C's tree byte for byte, so every tool of the private tree runs
unchanged on a public checkout: the tripwire, the hooks, the host script, the withheld legs.

The decision is made from E's manifest (EXPORT-MANIFEST.txt: a sha256 per exported path) and C's blobs, never
from the withheld lists, so the overlay cannot drift from what the export did. The manifest's source-commit must
be C. The overlay directory must not exist or must be empty; it is written under $HOME/bsv/targets/ only.

The overlay carries OVERLAY-MANIFEST.txt: source-commit, the export it pairs with, the public edition commit when
--public names it, the counts, and one line `<sha256>  <path>  <overlay|public>` for EVERY tracked path of C,
so a mount verifies the whole mounted tree against C without the private repository (tools/overlay_mount.sh
--verify).

Usage: tools/export_overlay.py <commit> <export-dir> <overlay-dir> [--public <sha>]
Exit 0 written; 2 a refusal (bad arguments, the manifest's source-commit is not <commit>, a non-empty target).
"""
import hashlib
import os
from pathlib import Path
import subprocess
import sys

MANIFEST = 'EXPORT-MANIFEST.txt'
OVERLAY_MANIFEST = 'OVERLAY-MANIFEST.txt'


def refuse(msg):
    print(f'export_overlay: {msg}', file=sys.stderr)
    sys.exit(2)


def git(*args, root='.'):
    return subprocess.run(['git', '-C', root, *args], capture_output=True, check=True).stdout


def read_manifest(export):
    """The export's header fields and {path: sha256}."""
    text = (Path(export) / MANIFEST).read_text(encoding='utf-8', errors='surrogateescape')
    fields, shas = {}, {}
    for line in text.splitlines():
        if not line or line.startswith('#'):
            continue
        if len(line) > 66 and line[64:66] == '  ' and all(c in '0123456789abcdef' for c in line[:64]):
            shas[line[66:]] = line[:64]
            continue
        key, _, value = line.partition(' ')
        fields.setdefault(key, value)
    return fields, shas


def tree_entries(commit, root='.'):
    """[(mode, blob, path)] of every tracked path at the commit."""
    out = git('ls-tree', '-r', '-z', commit, root=root).decode('utf-8', 'surrogateescape')
    entries = []
    for item in out.split('\0'):
        if not item:
            continue
        meta, path = item.split('\t', 1)
        mode, _, blob = meta.split()
        entries.append((mode, blob, path))
    return entries


def blob_bytes(blob, root='.'):
    return git('cat-file', 'blob', blob, root=root)


def build_overlay(commit, export, target, public=None, root='.'):
    """Write the overlay; return (fields, rows) where rows = [(sha256, path, 'overlay'|'public')]."""
    fields, exported = read_manifest(export)
    source = fields.get('source-commit', '')
    full = git('rev-parse', commit, root=root).decode().strip()
    if source != full:
        refuse(f'the export {export} is of {source[:12] or "?"}, not of {full[:12]}: name the export of this commit')
    target = Path(target)
    if target.exists() and any(target.iterdir()):
        refuse(f'{target} is not empty')
    rows, absent, restored = [], 0, 0
    for mode, blob, path in tree_entries(full, root):
        data = blob_bytes(blob, root)
        if mode == '120000':
            digest = hashlib.sha256(b'symlink ' + data).hexdigest()
        else:
            digest = hashlib.sha256(data).hexdigest()
        public_sha = exported.get(path)
        if public_sha == digest:
            rows.append((digest, path, 'public'))
            continue
        if public_sha is None:
            absent += 1
        else:
            restored += 1
        rows.append((digest, path, 'overlay'))
        dest = target / path
        dest.parent.mkdir(parents=True, exist_ok=True)
        if mode == '120000':
            os.symlink(data.decode('utf-8', 'surrogateescape'), dest)
        else:
            dest.write_bytes(data)
            if mode == '100755':
                os.chmod(dest, 0o755)
    stamp = subprocess.run(['date', '-u', '+%Y-%m-%d %H:%M:%S UTC'], capture_output=True, text=True).stdout.strip()
    head = [
        '# The private overlay of a public edition of bsv-script-lean (tools/export_overlay.py); see its docstring.',
        f'source-commit {full}',
        f'export {Path(export).name}',
        f'export-exported-at {fields.get("exported-at", "?")}',
        f'public-commit {public or "unnamed"}',
        f'generated-at {stamp}',
        f'paths-tracked {len(rows)}',
        f'paths-overlay {absent + restored}',
        f'paths-withheld-whole {absent}',
        f'paths-restored-private-original {restored}',
        f'paths-public-identical {len(rows) - absent - restored}',
        '# one line per tracked path of the source commit: sha256 (a symlink: sha256 of "symlink " + its target), path, where the mounted copy comes from',
    ]
    body = [f'{sha}  {path}  {where}' for sha, path, where in rows]
    target.mkdir(parents=True, exist_ok=True)
    (target / OVERLAY_MANIFEST).write_text('\n'.join(head + body) + '\n', encoding='utf-8', errors='surrogateescape')
    return fields, rows, absent, restored


def main(argv):
    args = [a for a in argv if not a.startswith('--')]
    public = None
    if '--public' in argv:
        public = argv[argv.index('--public') + 1]
        args = [a for a in args if a != public]
    if len(args) != 3:
        refuse('usage: tools/export_overlay.py <commit> <export-dir> <overlay-dir> [--public <sha>]')
    commit, export, target = args
    targets = Path(os.path.expanduser('~/bsv/targets')).resolve()
    if not Path(target).resolve().is_relative_to(targets):
        refuse(f'the overlay directory must sit under {targets}')
    if not (Path(export) / MANIFEST).is_file():
        refuse(f'{export} carries no {MANIFEST}')
    _, rows, absent, restored = build_overlay(commit, export, target, public)
    print(f'export_overlay: {absent + restored} paths written to {target} ({absent} withheld whole, {restored} private '
          f'originals of transformed paths; {len(rows) - absent - restored} of {len(rows)} tracked paths public and '
          f'byte-identical); manifest {Path(target) / OVERLAY_MANIFEST}')


if __name__ == '__main__':
    main(sys.argv[1:])
