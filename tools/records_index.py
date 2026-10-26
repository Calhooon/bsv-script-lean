#!/usr/bin/env python3
"""tools/records_index.py: the index of docs/records/ (#175), docs/records/INDEX.md, generated.

One row per record the public edition carries (a record that is a directory is one row, its files unread; the tracked files of docs/records/ that tools/export_withheld.txt does
not withhold, matched by tools/export_public.py's own matcher, so a withheld record is absent by construction and its
contents are never opened): its UTC stamp (from the file name), its kind (from the file name), the commit its header
names (a 7-to-40 hex word after "at " or "commit" in its opening ten lines), its verdict (a line of its opening forty or
closing five that begins GREEN, RED, CLEAN, HELD or NOT HELD, after an optional `status:`, `verdict:` or `make check:`),
and the public pages that cite it by file name. One table per month, the newest at the top. Only each file's opening forty lines
and closing five are read.

A tripwire record (kind make-check, make-check-box, make-check-modal) newer than every row of the committed index is
written by a run after the index; `--check` names those and does not count them stale, so a run's own record never
turns the next run RED. Any other difference is stale.

Usage: tools/records_index.py            writes docs/records/INDEX.md
       tools/records_index.py --check    exit 1 when docs/records/INDEX.md is stale
"""
import os, re, subprocess, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, 'tools'))
import export_public  # noqa: E402  (the export's withheld list and its matcher, never a second copy)

INDEX = 'docs/records/INDEX.md'
TRIPWIRE = ('make-check', 'make-check-box', 'make-check-modal')
STAMP = re.compile(r'^(\d{4})(\d{2})(\d{2})-(\d{2})(\d{2})(\d{2})?-')
COMMIT = re.compile(r'(\bat\s+|\bcommit\b[\s:`(]*)`?([0-9a-f]{7,40})\b')
VERDICT = re.compile(r'^[\s*#>`|-]*(?:(?:status|verdict|the verdict|make check)\s*:\s*)?[*`]*(NOT HELD|GREEN|RED|CLEAN|HELD)\b')
MONTHS = ('January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October',
          'November', 'December')


def tracked(*prefixes):
    out = subprocess.run(['git', '-C', ROOT, 'ls-files', '--', *prefixes], check=True, capture_output=True,
                         text=True).stdout
    return [p for p in out.split('\n') if p]


def kind(name):
    n = name.lower()
    if re.search(r'-make-check-box\.', n):
        return 'make-check-box'
    if re.search(r'-make-check-modal\.', n):
        return 'make-check-modal'
    if re.search(r'-make-check(-[a-z]+)?\.', n):
        return 'make-check'
    for k, words in (('lens', ('lens',)), ('recon', ('recon',)), ('filing', ('filed', 'filing')),
                     ('verify', ('verify',)), ('replay', ('replay',)),
                     ('measurement', ('column', 'bench', 'measure', 'regtest', 'census', 'wall', 'probe', 'gate-report',
                                      'fuzz', 'diff', 'x86', 'timing', 'million'))):
        if any(w in n for w in words):
            return k
    return 'other'


def head_tail(path):
    """The opening forty lines and the closing five (each line cut at 64 KiB), never the whole of a large file."""
    with open(path, 'rb') as f:
        head = [f.readline(65536) for _ in range(40)]
        size = f.seek(0, 2)
        f.seek(max(0, size - 16384))
        tail = f.read().split(b'\n')
    dec = lambda b: b.decode('utf-8', 'replace').rstrip('\r\n')
    head = [dec(b) for b in head if b]
    tail = [dec(b) for b in tail]
    while tail and not tail[-1].strip():
        tail.pop()
    return head, tail[-5:]


def commit_of(head):
    for line in head[:10]:
        for m in COMMIT.finditer(line):
            # after "at " a date or a count is all digits; a hash word there needs a letter
            if m.group(1).startswith('commit') or re.search('[a-f]', m.group(2)):
                return m.group(2)
    return ''


def verdict_of(head, tail):
    for line in head:
        m = VERDICT.match(line)
        if m:
            return m.group(1)
    for line in reversed(tail):
        m = VERDICT.match(line)
        if m:
            return m.group(1)
    return ''


def rows(rules):
    pages = [p for p in tracked('README.md', 'CHANGELOG.md', 'harness/README.md', 'lean/README.md', 'docs', 'spec')
             if re.fullmatch(r'(README|CHANGELOG)\.md|harness/README\.md|lean/README\.md|docs/[^/]+\.md|spec/[^/]+\.md', p)
             and export_public.group_of(rules, p) is None]
    texts = {}
    for p in pages:
        try:
            texts[p] = open(os.path.join(ROOT, p), encoding='utf-8', errors='replace').read()
        except OSError:
            pass
    out, dirs = [], {}
    for rel in tracked('docs/records'):
        if rel == INDEX or export_public.group_of(rules, rel) is not None:
            continue
        name = rel.split('/')[2]
        if rel.count('/') > 2:
            dirs.setdefault(name, None)   # a record that is a directory: one row, its files not read
            continue
        head, tail = head_tail(os.path.join(ROOT, rel))
        out.append((name, commit_of(head), verdict_of(head, tail)))
    out += [(name + '/', '', '') for name in dirs]
    rows = []
    for name, commit, verdict in out:
        m = STAMP.match(name)
        stamp = (f'{m[1]}-{m[2]}-{m[3]} {m[4]}:{m[5]}' + (f':{m[6]}' if m[6] else '')) if m else ''
        cited = [p for p in pages if name.rstrip('/') in texts.get(p, '')]
        rows.append((stamp, name, kind(name.rstrip('/')), commit, verdict, cited))
    out = rows
    out.sort(key=lambda r: (r[0], r[1]), reverse=True)
    return out


def render(rs):
    lines = [
        '# docs/records/: the index',
        '',
        'Every record of this directory, one row each, the newest at the top: its UTC stamp, its kind (read from its file name), '
        'the commit its header names, its verdict line\'s word, and the public pages that cite it. This page is '
        'generated by `tools/records_index.py`; never edit it by hand, and `python3 tools/records_index.py --check` (the '
        'seed leg of `make check`) refuses a stale copy. A record names the commit of the private history it was '
        'written at; the public history is fresh, so a commit named here is a name, not a link.',
        '',
        'An issue written "archived #n" in a record, and a link to the issue tracker of the repository before 2026-10-26, '
        'names the private history and does not resolve for a reader of the public edition; `docs/GLOSSARY.md` defines the form.\n\n'
        'Kinds: make-check, make-check-box and make-check-modal are the tripwire\'s records (`tools/check.sh`), by where '
        'it ran; replay, verify, lens, recon, filing and measurement as the file name says; other for the rest.',
    ]
    month = None
    for stamp, name, k, commit, verdict, cited in rs:
        key = stamp[:7] if stamp else 'undated'
        if key != month:
            month = key
            title = f'{MONTHS[int(key[5:7]) - 1]} {key[:4]}' if stamp else 'Undated'
            lines += ['', f'## {title}', '', '| stamp (UTC) | record | kind | commit | verdict | cited by |',
                      '|---|---|---|---|---|---|']
        cite = ', '.join(f'`{p}`' for p in cited)
        lines.append(f'| {stamp} | [{name}]({name}) | {k} | {commit} | {verdict} | {cite} |')
    return '\n'.join(lines) + '\n'


def main():
    rules = export_public.load_withheld(export_public.WITHHELD)
    rs = rows(rules)
    path = os.path.join(ROOT, INDEX)
    if sys.argv[1:] == ['--check']:
        try:
            old = open(path, encoding='utf-8').read()
        except OSError:
            old = ''
        listed = set(re.findall(r'^\| [^|]* \| \[([^\]]+)\]', old, re.M))
        newest = max((r[0] for r in rs if r[1] in listed), default='')
        later = [r for r in rs if r[1] not in listed and r[2] in TRIPWIRE and r[0] > newest]
        text = render([r for r in rs if r not in later])
        if old != text:
            print(f'seedcheck records index: RED: {INDEX} is stale (regenerate: python3 tools/records_index.py)')
            sys.exit(1)
        note = f'; {len(later)} tripwire record(s) newer than the index not yet listed' if later else ''
        print(f'seedcheck records index: GREEN [X]: {INDEX} is current, {len(rs) - len(later)} records{note}')
    elif not sys.argv[1:]:
        with open(path, 'w', encoding='utf-8') as f:
            f.write(render(rs))
        print(f'records_index: wrote {INDEX}, {len(rs)} records')
    else:
        sys.exit(__doc__)


if __name__ == '__main__':
    main()
