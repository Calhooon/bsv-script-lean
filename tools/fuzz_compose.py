#!/usr/bin/env python3
"""tools/fuzz_compose.py: one batch's corpus for tools/fuzz_campaign.sh (S3, lane fuzz-cut2, 2026-10-15; item 5 of the
bsv-fuzz house read, docs/records/20261015-134833-fuzz-house-read-s3.md section 5).

The batch's corpus is three parts, in this order, in $FZ_B/corpus/seed.jsonl:
  1. smoke:  the bench leg's fuzz smoke's own leading cases (tools/bench_leg.sh: seed_gen under the seed taken from the
             tree's commit), so the tripwire's smoke and every batch share cases;
  2. replay: every past witness row of the campaign ($FZ_REPLAY/*.jsonl, read only), one case per distinct spend (its
             tx, prevouts and params), so a fixed divergence is seen to stay fixed and a returning one is seen the day it
             returns;
  3. fresh:  one seed_gen stream per family under its own salted seed ($FZ_SEGMENTS names each), so a family's cases
             never move when another family is added or re-weighted.
Every entry keeps its spend byte for byte; its id gains the part's name (`smoke-seed-000001`, `arith-seed-000001`,
`replay-<the row's id>`), and a replayed row keeps only seed_gen's own bsv-rs verdict in `expect`; a row whose spend is
a smoke case rides on that case. $FZ_B/segments.json
maps every id to its part, its seed, its count and the id seed_gen gave it, and every replayed case to the rows it
replays (each row's engine, column and class). Prints the parts' counts on one line.
THE RESOURCE SET (lane fix2-fuzz-cut3, 2026-10-16; tools/fuzz_campaign.sh's watchdog): every entry of $FZ_RESOURCE/*.jsonl
(the entries a killed evaluator process left without a verdict) is replayed after the witness replay, one case per
distinct spend, as the part `resource` (id `resource-<its id>-<the spend's sha256, 8 hex>`), or flagged on the case
already carrying that spend; a fresh case whose spend is already a `resource` case (a batch retried at the same seeds
after a fresh kill) is not composed again, so its family counts one fewer; every case of a resource spend is flagged
`resource` in segments.json (its file, its id, its spend's sha256) and written to corpus/resource.jsonl, every other case to corpus/light.jsonl (seed.jsonl holds all).
Environment: FZ_B (the batch's directory; seed_gen's outputs in gen/<part>/seed.jsonl), FZ_SEGMENTS
("<part>:<seed>:<count> ...", the part `smoke` placed ahead of the replay, the families after it in order), FZ_REPLAY (the witness rows' directory),
FZ_RESOURCE (the resource set's directory, $FUZZ_STATE/resource).
"""
import glob, hashlib, json, os

e = os.environ
b = e["FZ_B"]


def spend_key(x):
    return hashlib.sha256(json.dumps({k: x.get(k) for k in ("tx", "prevouts", "params")}, sort_keys=True).encode()).hexdigest()


def cell_of(w):
    """The (engine, column) a witness row diverges in: its `fuzz` fields, else its divergence's two keys."""
    f, d = w.get("fuzz") or {}, w.get("divergence") or {}
    if "column" in f:
        return f.get("engine", "sv-node"), f["column"]
    b_name, a_name = d.get("b", "").split("@")[0], d.get("a", "").split("@")[0]
    if b_name.endswith("-default"):
        return b_name[: -len("-default")], "default/" + a_name
    if b_name.endswith("-mempool"):
        return b_name[: -len("-mempool")], "spec-mempool"
    return b_name, "spec"


segments = [s.split(":") for s in e["FZ_SEGMENTS"].split()]
ids, parts, rows, placed, lines, res_keys = {}, {}, [], {}, [], {}
with open(f"{b}/corpus/seed.jsonl", "w") as out:
    def put(x, part, new_id, meta):
        placed.setdefault(spend_key(x), new_id)
        x["id"] = new_id
        ids[new_id] = dict(meta, part=part)
        out.write(json.dumps(x, sort_keys=True) + "\n")
        lines.append((spend_key(x), new_id, json.dumps(x, sort_keys=True) + "\n"))
        parts[part] = parts.get(part, 0) + 1

    def generated(part, seed, count):
        path = f"{b}/gen/{part}/seed.jsonl"
        for l in open(path) if os.path.exists(path) else []:
            if l.strip():
                x = json.loads(l)
                k = spend_key(x)
                if k in res_keys and ids[placed[k]]["part"] == "resource":
                    continue  # the same spend, already a `resource` case (a batch retried after a fresh kill): once only
                put(x, part, f"{part}-{x['id']}", {"seed": seed, "count": int(count), "orig_id": x["id"]})

    for seg in segments:
        if seg[0] == "smoke":
            generated(*seg)
    parts["replay"] = 0
    replay = {}
    for p in sorted(glob.glob(os.path.join(e["FZ_REPLAY"], "*.jsonl"))):
        for l in open(p):
            if not l.strip():
                continue
            w = json.loads(l)
            engine, column = cell_of(w)
            row = {"row": w["id"], "file": os.path.basename(p), "engine": engine, "column": column,
                   "class": (w.get("divergence") or {}).get("rule", "")}
            rows.append(row)
            k = spend_key(w)
            if k in placed:
                ids[placed[k]].setdefault("rows", []).append(row)
                continue
            if k not in replay:
                x = {kk: v for kk, v in w.items() if kk not in ("id", "expect", "divergence", "fuzz")}
                x["expect"] = {kk: v for kk, v in (w.get("expect") or {}).items() if kk.startswith("bsv-rs@")}
                rid = f"replay-{w['id']}"
                if rid in ids or any(r["id"] == rid for r in replay.values()):
                    rid += "-" + k[:8]
                replay[k] = {"id": rid, "entry": x, "rows": []}
            replay[k]["rows"].append(row)
    for k, r in replay.items():
        put(r["entry"], "replay", r["id"], {"rows": r["rows"]})
    # the resource set (tools/fuzz_campaign.sh's watchdog, $FZ_RESOURCE/*.jsonl): every spend once, after the replay; a
    # spend already placed is flagged on the case it rides on, every other is a case of the part `resource`
    for p in sorted(glob.glob(os.path.join(e.get("FZ_RESOURCE", "/nonexistent"), "*.jsonl"))):
        for l in open(p):
            if not l.strip():
                continue
            x = json.loads(l)
            k = spend_key(x)
            if k in res_keys:
                continue
            res_keys[k] = {"file": os.path.basename(p), "orig_id": x["id"], "key": k}
            if k not in placed:
                put(x, "resource", f"resource-{x['id']}-{k[:8]}", {})
    for seg in segments:
        if seg[0] != "smoke":
            generated(*seg)
# the spec stage reads the corpus as two files: resource.jsonl (every case whose spend is in the resource set, flagged
# `resource` in segments.json, one process each) and light.jsonl (the rest, in chunks)
with open(f"{b}/corpus/resource.jsonl", "w") as res, open(f"{b}/corpus/light.jsonl", "w") as light:
    for k, i, l in lines:
        if k in res_keys:
            ids[i]["resource"] = res_keys[k]
        (res if k in res_keys else light).write(l)
json.dump({"segments": [{"part": p, "seed": s, "count": int(c)} for p, s, c in segments], "parts": parts,
           "replay_rows": rows, "ids": ids}, open(f"{b}/segments.json", "w"), sort_keys=True)
print(" ".join(f"{p}:{n}" for p, n in parts.items()))
