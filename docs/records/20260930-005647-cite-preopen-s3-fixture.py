#!/usr/bin/env python3
"""Synthetic pre-open exclusion check, with an old-scanner control.

All scan roots are newly created temporary directories. The embedded functions
are extracted from the reviewed scanner and its proposed patch. --scanner can
check those functions from an applied scanner instead, without running its real
main, reading its table, or scanning its actual repository.
"""
import argparse
import ast
import builtins
import contextlib
import io
import json
import os
from pathlib import Path
import re
import sys
import tempfile
from collections import Counter
from unittest.mock import patch

OLD_FUNCTIONS = 'def scan_sites():\n    """Every citation in lean/ and docs/: (site, line number in the site, the citation text, path, [(first, last)])."""\n    found = []\n    for top, ext in SCAN:\n        base = os.path.join(ROOT, top)\n        for dirpath, dirnames, filenames in os.walk(base):\n            dirnames[:] = sorted(d for d in dirnames if d not in (".lake", "build", ".git"))\n            for fn in sorted(filenames):\n                if not fn.endswith(ext):\n                    continue\n                full = os.path.join(dirpath, fn)\n                site = os.path.relpath(full, ROOT)\n                text = open(full, encoding="utf-8", errors="replace").read()\n                for m in CITE.finditer(text):\n                    path = m.group(1)\n                    first = int(m.group(2))\n                    last = int(m.group(3)) if m.group(3) else first\n                    ranges = [(first, last)]\n                    for e in EXTRA.finditer(m.group(4) or ""):\n                        a = int(e.group(1))\n                        ranges.append((a, int(e.group(2)) if e.group(2) else a))\n                    lineno = text.count("\\n", 0, m.start()) + 1\n                    found.append({"site": site, "at": lineno, "cite": m.group(0), "path": path, "ranges": ranges,\n                                  "start": m.start(), "text": text})\n    return found\n\ndef key(site, cite, first, last):\n    return (site, cite, first, last)\n\ndef main():\n    args = sys.argv[1:]\n    pinmap = pins()\n    repins = [args[i + 1] for i, a in enumerate(args) if a == "--repin" and i + 1 < len(args)]\n    for r in repins:\n        k, _, v = r.partition("=")\n        if k not in pinmap or not v:\n            sys.exit(f"cite_check: --repin {r}: not a key of the pins block, or no value")\n        pinmap[k] = v\n    if repins and "--propose" in args:\n        sys.exit("cite_check: --repin never writes the table")\n    PINS.update(pinmap)\n    src = Sources(pinmap)\n    require = os.environ.get("CITE_CHECK_REQUIRE_CLONES") == "1"\n    rows = load_rows()\n    by_key = {key(r["site"], r["cite"], r["first"], r["last"]): r for r in rows}\n    cites = scan_sites()\n    counts = Counter()       # per (occurrence, range): every citation found lands in exactly one class\n    moved, findings, listing, proposed = [], [], [], []\n    used, checked, proposed_keys, held_hit = set(), {}, set(), set()\n    skipped = Counter()\n    n_ranges = 0\n    for c in cites:\n        kind, repo, fullpath = resolve(src, c)\n        for first, last in c["ranges"]:\n            n_ranges += 1\n            k = key(c["site"], c["cite"], first, last)\n            row = by_key.get(k)\n            where = f"{c[\'site\']}:{c[\'at\']} {c[\'cite\']}"\n            if row is not None and row["repo"] not in src.repo:\n                used.add(k)\n                counts["skipped"] += 1\n                skipped[row["repo"]] += 1\n                listing.append(f"SKIP       {where} -> {row[\'repo\']} ({src.absent.get(row[\'repo\'], \'absent\')})")\n                continue\n            if kind != "pinned":\n                counts[kind] += 1\n                listing.append(f"{kind:<10} {where}")\n                continue\n            if row is not None:\n                used.add(k)\n                if k not in checked:\n                    checked[k] = check_row(src, row)\n                why = checked[k]\n                if why:\n                    counts["moved"] += 1\n                    moved.append(f"{where}: {why}")\n                    listing.append(f"MOVED      {where}: {why}")\n                else:\n                    counts["anchored"] += 1\n                    listing.append(f"ok         {where} -> {row[\'repo\']}:{row[\'path\']}:{first}–{last} [{row[\'kind\']}: {row[\'anchor\'][:60]}]")\n                continue\n            lines = src.lines(repo, fullpath)\n            if lines is None or first < 1 or last < first or last > len(lines):\n                counts["beyond-eof"] += 1\n                n = "?" if lines is None else len(lines)\n                findings.append(f"beyond-eof: {where}: {repo}:{fullpath} has {n} lines at the pin")\n                listing.append(f"beyond-eof {where} -> {repo}:{fullpath} ({n} lines)")\n                continue\n            counts["unanchored"] += 1\n            listing.append(f"unanchored {where} -> {repo}:{fullpath}:{first}–{last}")\n            if "--propose" in args and k not in proposed_keys:\n                proposed_keys.add(k)\n                held = HELD.get((c["site"], c["cite"]))\n                if held:\n                    held_hit.add((c["site"], c["cite"]))\n                    findings.append(f"held: {where}: no row is proposed ({held})")\n                p = None if held else propose_row(src, c, repo, fullpath, first, last, findings)\n                if p:\n                    proposed.append(dict(site=c["site"], cite=c["cite"], first=first, last=last, repo=repo,\n                                         commit=src.repo[repo][1][:12], path=fullpath, **p))\n    seen = used | proposed_keys\n    orphans = [r for r in rows if key(r["site"], r["cite"], r["first"], r["last"]) not in seen]\n    counts["orphan"] = len(orphans)\n    if require and src.absent:\n        for name, why in src.absent.items():\n            moved.append(f"CITE_CHECK_REQUIRE_CLONES=1 and {name} is absent ({why})")\n\n    if "--list" in args:\n        print("\\n".join(listing))\n    if "--propose" in args:\n        for (site, cite), why in HELD.items():\n            if (site, cite) not in held_hit:\n                findings.append(f"held entry spent: {site} carries no unanchored {cite} any more; remove it from HELD "\n                                f"({why})")\n        # a proposal runs the near-miss scan over every pinned citation, the anchored ones included\n        for c in cites:\n            kind, repo, fullpath = resolve(src, c)\n            if kind != "pinned":\n                continue\n            for first, last in c["ranges"]:\n                if key(c["site"], c["cite"], first, last) in used:\n                    propose_row(src, c, repo, fullpath, first, last, findings)\n        kept = [r for r in rows if key(r["site"], r["cite"], r["first"], r["last"]) in used]\n        new_rows = sorted(kept + proposed, key=lambda r: (r["site"], r["cite"], r["first"], r["last"]))\n        print(f"cite_check --propose: {len(proposed)} rows proposed ({Counter(p[\'kind\'] for p in proposed)}), "\n              f"{len(orphans)} orphan rows dropped, {len(new_rows)} rows after")\n        for f in sorted(set(findings)):\n            print("  " + f)\n        if "--write" in args:\n            write_rows(new_rows)\n            print(f"cite_check --propose --write: the table in {os.path.relpath(SELF, ROOT)} rewritten ({len(new_rows)} rows)")\n        return 0\n\n    if repins:\n        print(f"cite_check --repin {\' \'.join(repins)} (in memory; the pins block is unchanged):")\n    for m in moved:\n        print("  MOVED " + m)\n    skip_line = "; ".join(f"{n} SKIPPED BY NAME ({src.absent.get(n)}), {k} rows" for n, k in skipped.items())\n    absent_line = "; ".join(f"{n}: {why}" for n, why in src.absent.items())\n    print(f"cite_check: {n_ranges} citations found in lean/ and docs/ ({len(cites)} `file:line` shapes, a `/`-list counted per line); anchored and holding at the pin {counts[\'anchored\']}, "\n          f"MOVED {counts[\'moved\']}; not anchored (reported, never RED): unanchored {counts[\'unanchored\']}, "\n          f"beyond-eof {counts[\'beyond-eof\']}, unresolved {counts[\'unresolved\']}, ambiguous {counts[\'ambiguous\']}, "\n          f"unpinned {counts[\'unpinned\']}, other-version {counts[\'other-version\']}, self {counts[\'self\']}, "\n          f"history {counts[\'history\']}, absent {counts[\'absent\']}, orphan rows {counts[\'orphan\']}; "\n          f"skipped {counts[\'skipped\']}" + (f" ({skip_line})" if skip_line else "") +\n          (f"; sources absent here: {absent_line}" if absent_line else ""))\n    if moved:\n        print("cite_check: RED (an anchored citation\'s anchor is no longer where the citation says, at the pin)")\n        return 1\n    print("cite_check: GREEN (every anchored citation holds at the pin)")\n    return 0'
CANDIDATE_FUNCTIONS = 'def scan_sites(excluded=None):\n    """Live citation sites only; append excluded history names without opening them."""\n    found = []\n    for top, ext in SCAN:\n        base = os.path.join(ROOT, top)\n        for dirpath, dirnames, filenames in os.walk(base):\n            dirnames[:] = sorted(d for d in dirnames if d not in (".lake", "build", ".git"))\n            for fn in sorted(filenames):\n                if not fn.endswith(ext):\n                    continue\n                full = os.path.join(dirpath, fn)\n                site = os.path.relpath(full, ROOT)\n                # History may hold owner-closed evidence. Name it, but never open it.\n                if site.startswith(HISTORY_PREFIX):\n                    if excluded is not None:\n                        excluded.append(site)\n                    continue\n                text = open(full, encoding="utf-8", errors="replace").read()\n                for m in CITE.finditer(text):\n                    path = m.group(1)\n                    first = int(m.group(2))\n                    last = int(m.group(3)) if m.group(3) else first\n                    ranges = [(first, last)]\n                    for e in EXTRA.finditer(m.group(4) or ""):\n                        a = int(e.group(1))\n                        ranges.append((a, int(e.group(2)) if e.group(2) else a))\n                    lineno = text.count("\\n", 0, m.start()) + 1\n                    found.append({"site": site, "at": lineno, "cite": m.group(0), "path": path, "ranges": ranges,\n                                  "start": m.start(), "text": text})\n    return found\n\ndef key(site, cite, first, last):\n    return (site, cite, first, last)\n\ndef main():\n    args = sys.argv[1:]\n    pinmap = pins()\n    repins = [args[i + 1] for i, a in enumerate(args) if a == "--repin" and i + 1 < len(args)]\n    for r in repins:\n        k, _, v = r.partition("=")\n        if k not in pinmap or not v:\n            sys.exit(f"cite_check: --repin {r}: not a key of the pins block, or no value")\n        pinmap[k] = v\n    if repins and "--propose" in args:\n        sys.exit("cite_check: --repin never writes the table")\n    PINS.update(pinmap)\n    src = Sources(pinmap)\n    require = os.environ.get("CITE_CHECK_REQUIRE_CLONES") == "1"\n    rows = load_rows()\n    by_key = {key(r["site"], r["cite"], r["first"], r["last"]): r for r in rows}\n    excluded = []\n    cites = scan_sites(excluded)\n    for site in excluded:\n        print(f"cite_check: [LIT] {site}: closed to model turns, not opened")\n    history_rows = [r for r in rows if r["site"].startswith(HISTORY_PREFIX)]\n    history_keys = {key(r["site"], r["cite"], r["first"], r["last"]) for r in history_rows}\n    print(f"cite_check: excluded files [D] {len(excluded)}; closed to model turns, not opened; "\n          f"excluded anchor rows [D] {len(history_rows)} (retained, not scanned)")\n    counts = Counter()       # per (occurrence, range): every citation found lands in exactly one class\n    moved, findings, listing, proposed = [], [], [], []\n    used, checked, proposed_keys, held_hit = set(), {}, set(), set()\n    skipped = Counter()\n    n_ranges = 0\n    for c in cites:\n        kind, repo, fullpath = resolve(src, c)\n        for first, last in c["ranges"]:\n            n_ranges += 1\n            k = key(c["site"], c["cite"], first, last)\n            row = by_key.get(k)\n            where = f"{c[\'site\']}:{c[\'at\']} {c[\'cite\']}"\n            if row is not None and row["repo"] not in src.repo:\n                used.add(k)\n                counts["skipped"] += 1\n                skipped[row["repo"]] += 1\n                listing.append(f"SKIP       {where} -> {row[\'repo\']} ({src.absent.get(row[\'repo\'], \'absent\')})")\n                continue\n            if kind != "pinned":\n                counts[kind] += 1\n                listing.append(f"{kind:<10} {where}")\n                continue\n            if row is not None:\n                used.add(k)\n                if k not in checked:\n                    checked[k] = check_row(src, row)\n                why = checked[k]\n                if why:\n                    counts["moved"] += 1\n                    moved.append(f"{where}: {why}")\n                    listing.append(f"MOVED      {where}: {why}")\n                else:\n                    counts["anchored"] += 1\n                    listing.append(f"ok         {where} -> {row[\'repo\']}:{row[\'path\']}:{first}–{last} [{row[\'kind\']}: {row[\'anchor\'][:60]}]")\n                continue\n            lines = src.lines(repo, fullpath)\n            if lines is None or first < 1 or last < first or last > len(lines):\n                counts["beyond-eof"] += 1\n                n = "?" if lines is None else len(lines)\n                findings.append(f"beyond-eof: {where}: {repo}:{fullpath} has {n} lines at the pin")\n                listing.append(f"beyond-eof {where} -> {repo}:{fullpath} ({n} lines)")\n                continue\n            counts["unanchored"] += 1\n            listing.append(f"unanchored {where} -> {repo}:{fullpath}:{first}–{last}")\n            if "--propose" in args and k not in proposed_keys:\n                proposed_keys.add(k)\n                held = HELD.get((c["site"], c["cite"]))\n                if held:\n                    held_hit.add((c["site"], c["cite"]))\n                    findings.append(f"held: {where}: no row is proposed ({held})")\n                p = None if held else propose_row(src, c, repo, fullpath, first, last, findings)\n                if p:\n                    proposed.append(dict(site=c["site"], cite=c["cite"], first=first, last=last, repo=repo,\n                                         commit=src.repo[repo][1][:12], path=fullpath, **p))\n    seen = used | proposed_keys | history_keys\n    orphans = [r for r in rows if key(r["site"], r["cite"], r["first"], r["last"]) not in seen]\n    counts["orphan"] = len(orphans)\n    if require and src.absent:\n        for name, why in src.absent.items():\n            moved.append(f"CITE_CHECK_REQUIRE_CLONES=1 and {name} is absent ({why})")\n\n    if "--list" in args:\n        print("\\n".join(listing))\n    if "--propose" in args:\n        for (site, cite), why in HELD.items():\n            if not site.startswith(HISTORY_PREFIX) and (site, cite) not in held_hit:\n                findings.append(f"held entry spent: {site} carries no unanchored {cite} any more; remove it from HELD "\n                                f"({why})")\n        # a proposal runs the near-miss scan over every pinned citation, the anchored ones included\n        for c in cites:\n            kind, repo, fullpath = resolve(src, c)\n            if kind != "pinned":\n                continue\n            for first, last in c["ranges"]:\n                if key(c["site"], c["cite"], first, last) in used:\n                    propose_row(src, c, repo, fullpath, first, last, findings)\n        kept = [r for r in rows if key(r["site"], r["cite"], r["first"], r["last"]) in used | history_keys]\n        new_rows = sorted(kept + proposed, key=lambda r: (r["site"], r["cite"], r["first"], r["last"]))\n        print(f"cite_check --propose: {len(proposed)} rows proposed ({Counter(p[\'kind\'] for p in proposed)}), "\n              f"{len(orphans)} orphan rows dropped, {len(new_rows)} rows after")\n        for f in sorted(set(findings)):\n            print("  " + f)\n        if "--write" in args:\n            write_rows(new_rows)\n            print(f"cite_check --propose --write: the table in {os.path.relpath(SELF, ROOT)} rewritten ({len(new_rows)} rows)")\n        return 0\n\n    if repins:\n        print(f"cite_check --repin {\' \'.join(repins)} (in memory; the pins block is unchanged):")\n    for m in moved:\n        print("  MOVED " + m)\n    skip_line = "; ".join(f"{n} SKIPPED BY NAME ({src.absent.get(n)}), {k} rows" for n, k in skipped.items())\n    absent_line = "; ".join(f"{n}: {why}" for n, why in src.absent.items())\n    print(f"cite_check: {n_ranges} citations found in lean/ and docs/ ({len(cites)} `file:line` shapes, a `/`-list counted per line); anchored and holding at the pin {counts[\'anchored\']}, "\n          f"MOVED {counts[\'moved\']}; not anchored (reported, never RED): unanchored {counts[\'unanchored\']}, "\n          f"beyond-eof {counts[\'beyond-eof\']}, unresolved {counts[\'unresolved\']}, ambiguous {counts[\'ambiguous\']}, "\n          f"unpinned {counts[\'unpinned\']}, other-version {counts[\'other-version\']}, self {counts[\'self\']}, "\n          f"history {counts[\'history\']}, absent {counts[\'absent\']}, orphan rows {counts[\'orphan\']}; "\n          f"skipped {counts[\'skipped\']}" + (f" ({skip_line})" if skip_line else "") +\n          (f"; sources absent here: {absent_line}" if absent_line else ""))\n    if moved:\n        print("cite_check: RED (an anchored citation\'s anchor is no longer where the citation says, at the pin)")\n        return 1\n    print("cite_check: GREEN (every checked active anchor holds at the pin; closed history is not checked)")\n    return 0'
HISTORY_PREFIX = ("docs/records/", "docs/audit/", "docs/BLOCKS-ARCHIVE.md",
                  "docs/security/", "docs/recon.md")
HISTORY_NAMES = ["docs/records/owner-closed-synthetic.md",
                 "docs/audit/owner-closed-synthetic.md",
                 "docs/security/owner-closed-synthetic.md",
                 "docs/BLOCKS-ARCHIVE.md", "docs/recon.md"]


def extract_functions(path):
    source = Path(path).read_text()
    tree = ast.parse(source)
    return "\n\n".join(ast.get_source_segment(source, node) for node in tree.body
                      if isinstance(node, ast.FunctionDef)
                      and node.name in {"scan_sites", "main", "key"})


def make_namespace(functions, root, rows, written, moved=False):
    class SyntheticSources:
        def __init__(self, pinmap):
            self.repo = {"fixture": ("synthetic", "fixture-pin")}
            self.absent = {}

        def lines(self, repo, path):
            return ["ANCHOR"]

    ns = {"os": os, "ROOT": str(root), "SELF": "synthetic-scanner.py",
          "SCAN": [("lean", ".lean"), ("docs", ".md")],
          "HISTORY_PREFIX": HISTORY_PREFIX, "Counter": Counter,
          "CITE": re.compile(r"(?<![\w/.@-])((?:[\w.@-]+/)*[\w.-]*\w\.rs):(\d+)(?:-(\d+))?((?:/:?\d+(?:-\d+)?)*)"),
          "EXTRA": re.compile(r"/:?(\d+)(?:-(\d+))?"),
          "sys": sys, "PINS": {}, "pins": lambda: {},
          "Sources": SyntheticSources, "load_rows": lambda: list(rows),
          "resolve": lambda src, cite: ("pinned", "fixture", "live.rs"),
          "check_row": lambda src, row: "synthetic anchor moved" if moved else None,
          "HELD": {(HISTORY_NAMES[0], "live.rs:1"): "synthetic retained history"},
          "propose_row": lambda *args: None,
          "write_rows": lambda replacement: written.extend(replacement)}
    exec(compile(functions, "<synthetic-scanner-functions>", "exec"), ns)
    return ns


def run_main(ns, guard, args):
    output = io.StringIO()
    with patch.object(builtins, "open", guard), patch.object(sys, "argv", ["synthetic", *args]), contextlib.redirect_stdout(output):
        rc = ns["main"]()
    return rc, output.getvalue()


def verify(candidate):
    with tempfile.TemporaryDirectory(prefix="s3-c57-cite-synthetic-") as temporary:
        root = Path(temporary)
        live = root / "docs/live.md"
        live.parent.mkdir(parents=True)
        live.write_text("fixture live.rs:1\n")
        for name in HISTORY_NAMES:
            target = root / name
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_text("synthetic history live.rs:1\n")
        # A build directory is still outside the scanner's read set.
        ignored = root / "lean/.lake/build/Ignored.lean"
        ignored.parent.mkdir(parents=True)
        ignored.write_text("fixture live.rs:1\n")
        real_open = builtins.open
        opened = []

        def track(path, *args, **kwargs):
            opened.append(Path(os.fspath(path)).relative_to(root).as_posix())
            return real_open(path, *args, **kwargs)

        def guard(path, *args, **kwargs):
            relative = Path(os.fspath(path)).relative_to(root).as_posix()
            if relative in HISTORY_NAMES:
                raise AssertionError("synthetic closed path opened: " + relative)
            return track(path, *args, **kwargs)

        old = make_namespace(OLD_FUNCTIONS, root, [], [])
        with patch.object(builtins, "open", track):
            old_sites = old["scan_sites"]()
        old_closed = sorted(set(opened) & set(HISTORY_NAMES))
        assert old_closed == sorted(HISTORY_NAMES)
        assert {site["site"] for site in old_sites} == {"docs/live.md", *HISTORY_NAMES}
        old_guard_failed = False
        try:
            with patch.object(builtins, "open", guard):
                old["scan_sites"]()
        except AssertionError:
            old_guard_failed = True
        assert old_guard_failed

        row = {"site": "docs/live.md", "cite": "live.rs:1", "first": 1,
               "last": 1, "repo": "fixture", "path": "live.rs", "kind": "sym",
               "anchor": "ANCHOR", "anchor_end": "", "commit": "fixture-pin"}
        histories = [dict(row, site=name) for name in HISTORY_NAMES]
        histories.append(dict(histories[0]))  # Duplicate keys still represent retained rows.
        orphan = dict(row, site="docs/vanished-live.md")
        rows = [row, *histories, orphan]
        written = []
        fixed = make_namespace(candidate, root, rows, written)
        opened.clear()
        excluded = []
        with patch.object(builtins, "open", guard):
            sites = fixed["scan_sites"](excluded)
        assert [site["site"] for site in sites] == ["docs/live.md"]
        assert sorted(excluded) == sorted(HISTORY_NAMES)
        assert opened == ["docs/live.md"]

        runs = []
        for args in ([], ["--list"], ["--propose", "--write"]):
            rc, output = run_main(fixed, guard, args)
            assert rc == 0
            for name in HISTORY_NAMES:
                assert output.count("[LIT] " + name + ": closed to model turns, not opened") == 1
            assert f"excluded files [D] {len(HISTORY_NAMES)}" in output
            assert f"excluded anchor rows [D] {len(histories)} (retained, not scanned)" in output
            assert "held entry spent" not in output
            if "--propose" not in args:
                assert "orphan rows 1" in output
                assert "cite_check: GREEN" in output
            runs.append({"args": args, "exit [X]": rc})
        assert {entry["site"] for entry in written} == {"docs/live.md", *HISTORY_NAMES}
        assert "docs/vanished-live.md" not in {entry["site"] for entry in written}
        retained = [entry for entry in written if entry["site"].startswith(HISTORY_PREFIX)]
        assert sorted(json.dumps(entry, sort_keys=True) for entry in retained) == sorted(
            json.dumps(entry, sort_keys=True) for entry in histories)
        failing = make_namespace(candidate, root, rows, [], moved=True)
        rc, output = run_main(failing, guard, [])
        assert rc == 1 and "cite_check: RED" in output
        assert not set(opened) & set(HISTORY_NAMES)
        return {"status [X]": "PASS", "old_control_closed_paths_opened [D]": len(old_closed),
                "old_control_guard_failed [X]": old_guard_failed,
                "candidate_closed_paths_opened [D]": 0,
                "excluded_names [LIT]": sorted(excluded),
                "live_citation_sites [D]": len(sites),
                "history_anchor_rows_retained [D]": len(retained),
                "live_orphan_rows_dropped [D]": 1,
                "active_anchor_failure_exit [X]": rc,
                "checked_modes [LIT]": runs}


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--scanner")
    args = parser.parse_args()
    functions = extract_functions(args.scanner) if args.scanner else CANDIDATE_FUNCTIONS
    print(json.dumps(verify(functions), indent=2))
