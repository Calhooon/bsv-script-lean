#!/usr/bin/env python3
"""Leg (2) of the mechanism check (CLAUDE.md rule 5): every hex string of at least
40 characters in the given corpus files, except the named public constants and
public header path rule in mechanism_allow.txt, must be absent from the sibling
repositories' git-tracked files. A fast exact scan (BSD grep -F with thousands
of patterns is quadratic on the siblings' large files): the 40-character prefix
of every pattern of every corpus file indexes ONE set, built before the siblings
are read; each sibling's tracked files are then read once (not once per corpus
file: the 2026-10-21 flip gate spent 2.5 hours re-reading three trees 198 times),
each file is scanned for hex runs and every 40-character window is looked up; a
prefix hit is confirmed by a prefix test on the run at that position. The verdict
per (corpus file, sibling file), the hit counts and the exit code are the one-tree-
per-file scan's; the output is per corpus file in argument order, the siblings in
their order; the pattern a FAIL line quotes can differ from the older scan's when
one sibling file holds two patterns of one corpus file (the older scan quoted whichever
candidate it found anywhere in the file, which varied with the hash seed).
Path rules are relative to the checked tree, with a filename-only glob.
Usage: mechanism_hex.py [--root <checked tree>] <sibling dir>... -- <corpus file>..."""
import fnmatch, re, subprocess, sys, os
from pathlib import Path
args = sys.argv[1:]
root = Path(__file__).resolve().parents[1]
if args[:1] == ['--root']:
    root = Path(args[1]).resolve()
    args = args[2:]
sep = args.index('--')
siblings, files = args[:sep], args[sep + 1:]
hexrun = re.compile(rb'[0-9a-f]{40,}')
allow = {}
path_allow = {}
source = None
for line in Path(__file__).with_name('mechanism_allow.txt').read_text().splitlines():
    line = line.strip()
    if line.startswith('#'):
        source = line[1:].strip()
    elif line.startswith('path '):
        pattern = Path(line[5:])
        if (not source or pattern.is_absolute() or '..' in pattern.parts
                or pattern.suffix != '.jsonl' or pattern.parts[0] != 'corpus'
                or any(c in str(pattern.parent) for c in '*?[') or pattern in path_allow):
            sys.exit('mechanism_hex: invalid or unnamed public path in mechanism_allow.txt')
        path_allow[pattern] = source.split(':', 1)[0]
        source = None
    elif line:
        value = line.encode('ascii')
        if not source or not hexrun.fullmatch(value) or value in allow:
            sys.exit('mechanism_hex: invalid or unnamed public constant in mechanism_allow.txt')
        allow[value] = source.split(':', 1)[0]
        source = None

# 1. every corpus file's patterns, and one prefix index over all of them
entries = []          # (f, header line, pats, degenerate count) or (f, exemption line, None, 0)
prefixes = {}         # 40-char prefix -> [(entry index, full pattern)]
for f in files:
    try:
        relative = Path(f).resolve().relative_to(root)
    except ValueError:
        relative = None
    exemption = next((reason for pattern, reason in path_allow.items()
                      if relative is not None and relative.parent == pattern.parent
                      and fnmatch.fnmatchcase(relative.name, pattern.name)), None)
    if exemption:
        entries.append((f, f"   {f}: path-allowlisted public data skipped by name: {exemption}", None, 0))
        continue
    data = open(f, 'rb').read()
    pats = set(m.group(0) for m in hexrun.finditer(data))
    allowed = pats & allow.keys()
    pats -= allowed
    header = (f"   {f}: {len(allowed)} allowlisted public constants skipped by name: "
              + (', '.join(allow[p] for p in sorted(allowed)) or 'none'))
    # a run of one or two distinct byte values (00…00, ff…ff7f, the width boundaries of a number
    # vector) is not content and occurs in any long hex blob: excluded, and counted
    degenerate = {p for p in pats if len(set(p[i:i+2] for i in range(0, len(p) - 1, 2))) <= 2}
    pats -= degenerate
    index = len(entries)
    entries.append((f, header, pats, len(degenerate)))
    for p in pats:
        prefixes.setdefault(p[:40], []).append((index, p))

# 2. the siblings, each tracked file read once; a hit is recorded per (corpus file, sibling file)
fails = {}            # (entry index, sibling index) -> [FAIL line] in tracked-file order
absent = {}           # sibling index -> its line
for s, sib in enumerate(siblings):
    if not os.path.isdir(sib):
        absent[s] = f"   (sibling {sib} not present; skipped)"; continue
    tracked = subprocess.run(['git', 'ls-files', '-z'], cwd=sib, capture_output=True, check=True).stdout.split(b'\0')
    for rel in tracked:
        if not rel: continue
        path = os.path.join(sib, rel.decode('utf-8', 'surrogateescape'))
        try:
            blob = open(path, 'rb').read()
        except (FileNotFoundError, IsADirectoryError, PermissionError):
            continue
        done = set()  # corpus files already failed on this sibling file
        for m in hexrun.finditer(blob):
            run = m.group(0)
            for i in range(0, len(run) - 39):
                cands = prefixes.get(run[i:i + 40])
                if not cands: continue
                for index, p in cands:
                    # every character of p is hex, so an occurrence of p in the file lies inside
                    # one maximal hex run; the window loop visits every start, and the check at
                    # this start is a prefix test on the run, never a search of the whole file
                    if index not in done and run.startswith(p, i):
                        fails.setdefault((index, s), []).append(
                            f"(2) FAIL: {path} contains a hex string of {entries[index][0]}: {p[:48].decode()}…")
                        done.add(index)

# 3. the report, per corpus file in argument order
fail = 0
for index, (f, header, pats, ndegenerate) in enumerate(entries):
    print(header)
    if pats is None:
        continue
    hits = 0
    for s in range(len(siblings)):
        if s in absent:
            print(absent[s]); continue
        for line in fails.get((index, s), []):
            print(line); hits += 1
    print(f"   {f}: {len(pats)} distinct hex strings (>= 40 chars) checked against {len(siblings)} sibling trees ({ndegenerate} degenerate runs of one or two byte values excluded): {hits} hit(s)")
    fail |= (hits != 0)
sys.exit(1 if fail else 0)
