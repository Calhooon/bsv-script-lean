#!/usr/bin/env python3
"""The withheld legs of the hosted gate, read from tools/withheld_legs.txt (bsv-script-lean #116, S3, lane gate-116).

  withheld_legs.py --declare          the hosted gate's `withheld-legs` job: print every row (what, why, where it runs)
                                      and match its families against the groups of tools/export_withheld.txt; a family
                                      the list names and the file lacks is printed as a warning line. Exit 0 always:
                                      the job declares, the box's status `box/withheld-legs` is the only gate.
  withheld_legs.py --judge <record>   tools/box_status.sh: read a tripwire record of the box (tools/check.sh's writer)
                                      and print one line per row: `ran` (every evidence line present, none refused),
                                      `on-demand` (no step of make check), or `MISSING` (a line absent, or the box itself
                                      skipped the read); the last line is the verdict. Exit 0 when no row is MISSING
                                      and the record says `status: GREEN` on host box, else 1.
"""
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LIST = os.path.join(ROOT, "tools", "withheld_legs.txt")
EXPORT = os.path.join(ROOT, "tools", "export_withheld.txt")


def rows():
    out = []
    for n, line in enumerate(open(LIST, encoding="utf-8"), 1):
        line = line.rstrip("\n")
        if not line.strip() or line.startswith("#"):
            continue
        f = [x.strip() for x in line.split(" | ")]
        if len(f) != 5:
            sys.exit(f"withheld_legs: {LIST}:{n}: {len(f)} fields, five expected (name | families | evidence | refused | why)")
        name, fam, ev, ref, why = f
        out.append({
            "name": name,
            "families": [] if fam == "-" else [x.strip() for x in fam.split(",")],
            "evidence": None if ev == "on-demand" else [x.strip() for x in ev.split("&&")],
            "refused": None if ref == "-" else ref,
            "why": why,
        })
    return out


def declare():
    rs = rows()
    groups = None
    if os.path.isfile(EXPORT):
        groups = set(re.findall(r"^## ([A-Za-z0-9-]+):", open(EXPORT, encoding="utf-8").read(), re.M))
    print(f"withheld legs: {len(rs)} rows of tools/withheld_legs.txt, run on the box and posted as the commit status "
          f"box/withheld-legs (tools/box_status.sh); this job runs none of them")
    stale = 0
    for r in rs:
        where = "the box's tripwire record" if r["evidence"] else "on demand on the box (no step of make check)"
        print(f"  {r['name']}: {r['why']} [{where}]")
        for fam in r["families"]:
            if groups is None:
                print(f"    family {fam}: not matched (tools/export_withheld.txt is absent from this tree)")
            elif fam in groups:
                print(f"    family {fam}: a group of tools/export_withheld.txt")
            else:
                stale += 1
                print(f"::warning::withheld legs: the family {fam} of row {r['name']} is no group of tools/export_withheld.txt")
    print(f"withheld legs: DECLARED ({len(rs)} rows; {stale} family name(s) unmatched); the gate on them is the status "
          f"box/withheld-legs, which this job never posts")
    return 0


def judge(path):
    text = open(path, encoding="utf-8").read()
    lines = text.splitlines()
    host = next((l.split(":", 1)[1].strip() for l in lines if l.startswith("host:")), "")
    status = next((l.split(":", 1)[1].strip() for l in lines if l.startswith("status:")), "")
    commit = next((l.split(":", 1)[1].split()[0] for l in lines if l.startswith("commit:")), "")
    bad = 0
    ran = []
    for r in rows():
        if r["evidence"] is None:
            print(f"withheld leg {r['name']}: on-demand (no step of make check; not covered by this status)")
            continue
        missing = [e for e in r["evidence"] if not any(re.search(e, l) for l in lines)]
        refused = []
        if r["refused"]:
            words = {re.match(r"\^\s*([^\s:]+)", e).group(1) for e in r["evidence"]}
            refused = [l.strip()[:160] for l in lines
                       if any(l.startswith("  " + w) for w in words) and re.search(r["refused"], l)]
        if missing or refused:
            bad += 1
            why = "; ".join([f"absent: {m}" for m in missing] + [f"skipped on the box: {x}" for x in refused[:2]])
            print(f"withheld leg {r['name']}: MISSING ({why})")
        else:
            ran.append(r["name"])
            print(f"withheld leg {r['name']}: ran")
    ok = bad == 0 and status == "GREEN" and host.split(";")[0].strip() == "box"
    print(f"withheld legs: {'GREEN' if ok else 'RED'} (record {os.path.basename(path)}, commit {commit}, host "
          f"{host.split(';')[0] or '?'}, status {status or '?'}; ran {len(ran)}: {', '.join(ran) or 'none'}; missing {bad})")
    return 0 if ok else 1


if __name__ == "__main__":
    if sys.argv[1:2] == ["--declare"]:
        sys.exit(declare())
    if sys.argv[1:2] == ["--judge"] and len(sys.argv) == 3:
        sys.exit(judge(sys.argv[2]))
    sys.exit(__doc__)
