#!/usr/bin/env python3
"""The discretion hold's overlap test (#43), as a script.

[M] 2026-10-15, lane fix6-anchor (S3). The criterion of the captain's ruling on N3: a bitcoin-sv row is held under the
node team's discretion request if its cited line range overlaps a hunk of the change between v1.2.2 and v1.2.3 in its
file. This script reads the hunk HEADERS alone (`git diff --unified=0 v1.2.2 v1.2.3 -- <file> | grep '^@@'`), never a
hunk's lines, and prints counts only: the held pairs' row ids are named in tools/cite_check.py and not repeated in a
record, so the pass prints a digest of the ids it did not find overlapping, and the ids themselves under `--ids`.

Two passes:
  held   every pair of `HELD_DISCRETION` (tools/cite_check.py), its path and range read from the row it replaced:
         the fix lane's pairs from the table at TABLE_BEFORE_FIX, the ruling's pairs from the table at TABLE_BEFORE_RULING
  table  every bitcoin-sv row of the table at HEAD in a file the two tags differ in

Overlap is tested on the row's own commit's side (old for a v1.2.2 row, new for a v1.2.3 row) and, for a v1.2.2 row,
on the new side as well. A hunk of count 0 (a pure insertion or deletion point after line s) overlaps a range
[lo, hi] when lo <= s < hi under the default reading; `--no-points` leaves such hunks out.

Usage: python3 tools/discretion_overlap.py [--no-points] [--ids] [--clone PATH]
"""
import argparse
import ast
import hashlib
import json
import os
import re
import subprocess
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import host_vars  # noqa: E402  tools/host_vars.py, the maintainers' host values (#177)

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CITE_CHECK = "tools/cite_check.py"
OLD_TAG, NEW_TAG = "v1.2.2", "v1.2.3"
OLD_SHA, NEW_SHA = "879fc8b4", "6504a3af"
TABLE_BEFORE_FIX = "76cded76"     # the pass's table, before the fix lane removed its 84 rows
TABLE_BEFORE_RULING = "b06ceb2f"  # the table before the ruling on N3 removed its 18 rows
FIX_LANE = "96868e9c"             # the fix lane's commit: its HELD_DISCRETION is the 84
HUNK = re.compile(r"^@@ -(\d+)(?:,(\d+))? \+(\d+)(?:,(\d+))? @@")
BEGIN = "# --- ANCHORS BEGIN"


def git(*args, cwd=ROOT):
    return subprocess.run(["git", *args], cwd=cwd, check=True, capture_output=True, text=True).stdout


def table_rows(rev):
    text = git("show", f"{rev}:{CITE_CHECK}")
    body = text[text.rindex("\n" + BEGIN):]
    return [json.loads(l.strip()[2:]) for l in body.split("\n") if l.strip().startswith("# {")]


def held_pairs(rev="HEAD"):
    text = git("show", f"{rev}:{CITE_CHECK}")
    m = re.search(r"^HELD_DISCRETION = (\{.*?^\})", text, re.S | re.M)
    return ast.literal_eval(m.group(1))


def hunks(clone, path, cache={}):
    """[(old_start, old_count, new_start, new_count)] from the headers; [] if the file does not differ."""
    if path not in cache:
        out = subprocess.run(f"git diff --unified=0 {OLD_TAG} {NEW_TAG} -- '{path}' | grep '^@@'", shell=True,
                             cwd=clone, capture_output=True, text=True).stdout
        hs = []
        for line in out.splitlines():
            m = HUNK.match(line)
            if m:
                a, b, c, d = m.groups()
                hs.append((int(a), 1 if b is None else int(b), int(c), 1 if d is None else int(d)))
        cache[path] = hs
    return cache[path]


def meets(lo, hi, start, count, points):
    if count == 0:
        return points and lo <= start < hi
    return lo <= start + count - 1 and start <= hi


def overlaps(row, clone, points):
    hs = hunks(clone, row["path"])
    old = row["commit"].startswith(OLD_SHA)
    for a, b, c, d in hs:
        if old and meets(row["first"], row["last"], a, b, points):
            return True
        if meets(row["first"], row["last"], c, d, points):
            return True
    return False


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--no-points", action="store_true", help="leave pure insertion and deletion points out")
    ap.add_argument("--ids", action="store_true", help="print the held pairs' row ids that do not overlap")
    ap.add_argument("--clone", default=None, help="the reference clone (default $BSV_SPEC_REFERENCE_CLONE, #177)")
    a = ap.parse_args()
    a.clone = a.clone or host_vars.need("$BSV_SPEC_REFERENCE_CLONE", "discretion_overlap")
    points = not a.no_points
    for tag, sha in ((OLD_TAG, OLD_SHA), (NEW_TAG, NEW_SHA)):
        got = git("rev-parse", f"{tag}^{{commit}}", cwd=a.clone)
        if not got.startswith(sha):
            sys.exit(f"discretion_overlap: {tag} is {got[:12]} in the clone, not {sha}")
    head = git("rev-parse", "--short=8", "HEAD").strip()
    print(f"discretion_overlap: HEAD {head}; {OLD_TAG} = {OLD_SHA}, {NEW_TAG} = {NEW_SHA}; hunk headers only; "
          f"insertion points {'counted' if points else 'not counted'}")

    # the held pass
    pairs = sorted(held_pairs())
    fix_lane = held_pairs(FIX_LANE)
    tables = {TABLE_BEFORE_FIX: table_rows(TABLE_BEFORE_FIX), TABLE_BEFORE_RULING: table_rows(TABLE_BEFORE_RULING)}
    hit, miss, unfound = [], [], []
    for site, cite in pairs:
        src = TABLE_BEFORE_FIX if (site, cite) in fix_lane else TABLE_BEFORE_RULING
        rows = [r for r in tables[src] if r["site"] == site and r["cite"] == cite]
        if not rows:
            unfound.append((site, cite))
            continue
        (hit if any(overlaps(r, a.clone, points) for r in rows) else miss).append((site, cite, src, rows[0]["commit"][:8]))
    print(f"held: {len(pairs)} pairs in HELD_DISCRETION ({len(fix_lane & set(pairs))} the fix lane's at {FIX_LANE}, "
          f"{len(set(pairs) - fix_lane)} the ruling's); overlap {len(hit)}; no overlap {len(miss)}; "
          f"no row found {len(unfound)}")
    for name, group in (("overlap", hit), ("no overlap", miss)):
        by = {}
        for _, _, src, _ in group:
            by[src] = by.get(src, 0) + 1
        print(f"held: {name} by source table: " + ", ".join(f"{k} {v}" for k, v in sorted(by.items())))
    ids = json.dumps(sorted([site, cite] for site, cite, _, _ in miss), ensure_ascii=False)
    print(f"held: no overlap ids sha256 {hashlib.sha256(ids.encode()).hexdigest()} (the sorted [site, cite] list as "
          f"JSON); pinned at {OLD_TAG} {sum(1 for m in miss if m[3].startswith(OLD_SHA))}")
    for site, cite, src, commit in (miss if a.ids else []):
        print(f"held: no overlap: ({site!r}, {cite!r}) row from {src}, pinned {commit}")
    for site, cite in unfound:
        print(f"held: no row found: ({site!r}, {cite!r})")

    # the table pass
    rows = [r for r in table_rows("HEAD") if r.get("repo") == "bitcoin-sv"]
    differ = [r for r in rows if hunks(a.clone, r["path"])]
    over = [r for r in differ if overlaps(r, a.clone, points)]
    files = {r["path"] for r in differ}
    old = sum(1 for r in differ if r["commit"].startswith(OLD_SHA))
    print(f"table: {len(rows)} bitcoin-sv rows at HEAD; {len(differ)} in {len(files)} files the tags differ in "
          f"({old} pinned at {OLD_TAG}); overlap {len(over)}")
    for r in over:
        print(f"table: overlap: ({r['site']!r}, {r['cite']!r}) pinned {r['commit'][:8]}")


if __name__ == "__main__":
    main()
