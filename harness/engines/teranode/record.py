#!/usr/bin/env python3
"""The tables of the Teranode column's record from its JSON (S4b, lane tera-74, 2026-10-14).

  python3 harness/engines/teranode/record.py docs/records/<stamp>-s6-74-second-oracle-s4b.json

Prints the counts per family in the SV-node aggregate's shape (measured, and beside it
rpc-precheck, pending and unrealizable), every row id per class (measured agree,
diverge, non-judging; rpc-precheck; pending and unrealizable grouped by the cited
reason) and the status witnesses with their observed value. The record's prose is
written around it.
"""

import json
import sys
from collections import defaultdict

FAMILIES = ["block", "utxo", "chain", "finality", "mempool", "oracle"]


def main(path):
    d = json.load(open(path))
    out = []
    keys = ("rows", "measured", "agree", "diverge", "non-judging", "rpc-precheck", "pending", "unrealizable")
    out.append("| family | " + " | ".join(f"{k} [M]" for k in keys) + " |")
    out.append("|---|" + "---:|" * len(keys))
    total = defaultdict(int)
    for f in FAMILIES:
        c = d["counts"][f]
        out.append(f"| {f} | " + " | ".join(str(c[k]) for k in keys) + " |")
        for k in keys:
            total[k] += c[k]
    out.append("| six-family total | " + " | ".join(str(total[k]) for k in keys) + " |")
    w = d["status_witnesses"]["counts"]
    out.append(f"| status witnesses (#67) | {w['steps']} | {w['steps']} | {w['agree']} | {w['diverge']} | {w['non-judging']} | 0 | 0 | 0 |")
    out.append("")
    out.append("### The realized rows (measured, and rpc-precheck beside them)")
    out.append("")
    out.append("| row | verdict | expected [D] | observed on Teranode [M] |")
    out.append("|---|---|---|---|")
    for f in FAMILIES:
        for r in d["families"][f]:
            if "verdict" not in r:
                continue
            o = r["observed"]
            seen = o["status"] + (f" -25 {o.get('word')}" if o["status"] == "rejected" else "")
            e = r["expected"]
            exp = e["status"] + (f" {e['reason']}" if e.get("reason") else "") + f" (stage {e['stage']})"
            q = f" ({r['qualifier']})" if r.get("qualifier") else ""
            out.append(f"| `{f}/{r['id']}` | {r['verdict']}{q} | {exp} | {seen} |")
    out.append("")
    for cls in ("pending", "unrealizable"):
        out.append(f"### The {cls} rows, by reason")
        out.append("")
        for f in FAMILIES:
            groups = defaultdict(list)
            for r in d["families"][f]:
                if cls in r:
                    groups[r[cls]].append(r["id"])
            for reason, ids in groups.items():
                out.append(f"- **{f}, {len(ids)}**: {reason}. Ids: " + ", ".join(f"`{i}`" for i in ids) + ".")
        out.append("")
    out.append("### The status witnesses")
    out.append("")
    out.append("| witness | established by | expected (the SV witness's value) | observed (Teranode's reading) [M] | verdict |")
    out.append("|---|---|---|---|---|")
    for s in d["status_witnesses"]["steps"]:
        ob = s["observed"]
        seen = ob["value"] + (f" {ob['height']}" if "height" in ob else "") + (f" -25 {ob.get('word')}" if ob["value"] == "rejected" else "")
        ex = s["expected"]["value"] + (f" {s['expected']['height']}" if "height" in s["expected"] else "")
        q = f" ({s['qualifier']})" if s.get("qualifier") else ""
        out.append(f"| {s['witness']} (`{s['txid'][:16]}...`) | {s['establish']} | {ex} | {seen} | {s['verdict']}{q} |")
    print("\n".join(out))


if __name__ == "__main__":
    main(sys.argv[1])
