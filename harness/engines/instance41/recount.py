#!/usr/bin/env python3
"""Re-derive a run's counts from its answers journals under run_teranode's `outcome`.

Usage: recount.py RUN_DIR MANIFEST_DIR [--write]

Each chunk's `answers.jsonl` holds the node's raw answer (`node_answer`) beside
the verdict the adapter derived when it ran. This mirrors `outcome` and `reason`
in harness/src/bin/run_teranode.rs (the innermost `NAME (n)` code decides; only
TX_INVALID, TX_CONSENSUS, TX_POLICY and TX_LOCK_TIME are verdicts), prints every
row whose verdict moves, and with --write re-cuts the committed manifests'
`counts` and `undecided`. The journals themselves are never rewritten.
"""
import hashlib
import json
import re
import sys
from pathlib import Path

VERDICT_CODES = {"TX_INVALID", "TX_CONSENSUS", "TX_POLICY", "TX_LOCK_TIME"}
CODE = re.compile(r"([A-Z_]+) \((\d+)\)")


def reason(n):
    for s in (n.get("transport_error"), (n.get("error") or {}).get("message")):
        if isinstance(s, str):
            return s
    r = n.get("result")
    if isinstance(r, dict):
        return r["reason"] if r.get("reason") else json.dumps(r, separators=(",", ":"))
    return "the instance returned no verdict"


def outcome(n):
    if n.get("transport_error") is not None:
        return "undecided"
    e = n.get("error")
    if e is None:
        r = n.get("result")
        if r is None:
            return "undecided"
        return "invalid" if isinstance(r, dict) and r.get("valid") is False else "valid"
    code = e.get("code")
    if isinstance(code, int) and code not in (-25, -26, -22):
        return "undecided"
    s = reason(n)
    if any(c in s for c in ("TX_MISSING_PARENT", "UTXO_NOT_FOUND", "NOT_FOUND (3)")):
        return "unfundable"
    codes = CODE.findall(s)
    return "invalid" if codes and codes[-1][0] in VERDICT_CODES else "undecided"


def main():
    run, manifests, write = Path(sys.argv[1]), Path(sys.argv[2]), "--write" in sys.argv
    moved = []
    for chunk in sorted(p for p in run.iterdir() if p.is_dir()):
        mpath = manifests / f"{chunk.name}.manifest.json"
        m = json.loads(mpath.read_text())
        counts, undecided, unfundable = {}, [], []
        for line in (chunk / "answers.jsonl").open():
            a = json.loads(line)
            was = a["node"]["verdict"]
            # Rows the adapter decided before any submission keep their verdict.
            now = was if a["submission"] is None and was == "undecided" else outcome(a["node_answer"])
            if now != was:
                moved.append((chunk.name, a["id"], a["path"], was, now, reason(a["node_answer"])))
            c = counts.setdefault(a["path"], dict.fromkeys(
                ["agreeing", "disagreeing", "entries", "judged", "no_reference", "undecided", "unfundable"], 0))
            c["entries"] += 1
            if now in ("undecided", "unfundable"):
                c[now] += 1
                (undecided if now == "undecided" else unfundable).append(
                    {"id": a["id"], "path": a["path"], "reason": a["node"].get("reason") or reason(a["node_answer"])})
                continue
            c["judged"] += 1
            ref = a["reference"]
            if ref and ref["verdict"] == now:
                c["agreeing"] += 1
            elif ref and ref["verdict"] in ("valid", "invalid"):
                c["disagreeing"] += 1
            else:
                c["no_reference"] += 1
        key = lambda r: (r["id"], r["path"])
        print(chunk.name, json.dumps(counts, sort_keys=True))
        if write and (counts != m["counts"] or sorted(undecided, key=key) != m["undecided"]):
            journal = hashlib.sha256((chunk / "answers.jsonl").read_bytes()).hexdigest()
            assert journal == m["artifacts_sha256"]["answers.jsonl"], chunk.name
            m["counts"] = counts
            m["undecided"] = sorted(undecided, key=key)
            m["unfundable"] = sorted(unfundable, key=key)
            m["recount"] = {
                "rule": "an engine fault is never a verdict: only the innermost codes TX_INVALID, TX_CONSENSUS, TX_POLICY, TX_LOCK_TIME (errors/error.proto:54-63 at the pin) are verdicts; UNKNOWN (0) and any unrecognized code are undecided",
                "tool": "harness/engines/instance41/recount.py over the unchanged answers.jsonl named in artifacts_sha256",
                "moved": [{"id": i, "path": p, "was": w, "now": n, "reason": r}
                          for (c, i, p, w, n, r) in moved if c == chunk.name],
            }
            mpath.write_text(json.dumps(m, indent=2, sort_keys=True) + "\n")
    for row in moved:
        print("moved", *row[:5], row[5], sep="\t")


if __name__ == "__main__":
    main()
