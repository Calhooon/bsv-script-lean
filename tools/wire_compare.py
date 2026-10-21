#!/usr/bin/env python3
"""The wire views' conformance comparison (#86, lane wire-86, 2026-10-15).

  tools/wire_compare.py --corpus corpus/wire --spec SPEC.jsonl --engine bsv-rs=RS.jsonl --engine go-sdk=GO.jsonl \
      --engine ts-sdk=TS.jsonl [--json OUT.json] [--columns-out PREFIX]

The spec column (lean/Test/WireCheck.lean, the evaluator: CLAUDE.md rule 3) against each engine's column
(harness/src/bin/run_wire.rs, harness/engines/go/wire, harness/engines/ts/wire.mjs), row by row. A row of an
engine AGREES when none of these differ, and is a witness of the earliest class, in this order, that does:

  codec    the engine's reader takes the bytes and the spec's codec refuses them, or the reverse
  objects  both read the bytes; the projections differ (txids, roots, heights, offsets, spent outputs, entries)
  bytes    both read the bytes; the engine's writer does not give the input back (the spec's always does:
           the serialize-after-parse theorems of lean/BsvChain/Views/Wire; this tool also checks it per row);
           the view is still compared and the detail says whether it agrees
  view     both read the bytes; the engine's own structural check and the spec's view checks disagree

A TSC row has no engine codec: the engines read the BUMP WhatsOnChain serves for the same transaction, and the
row agrees when the root they compute for the subject is the root the spec computes from the TSC proof
(class `root` otherwise); a TSC row the spec's codec refuses is counted `spec-only`. The spec's verdict line
also counts the TSC rows whose proof verifies against its target (`verify`, verifyTsc of #75).
Every witness carries the spec's line and the engine's line for its row whole (`spec_line`, `engine_line`;
CLAUDE.md rule 4). `--columns-out PREFIX` writes each column as PREFIX-<name>.jsonl in the same compact form the
witnesses use: a hex field longer than 65536 characters (three rows carry a 3 MB transaction) becomes its length in
bytes, its sha256, and, when it differs from the row's input in a window of at most 4096 hex characters, that window
of both (every byte outside it equal); a field equal to the row's input says so.
Views, never rules: a witness here is a difference between client codecs, never a consensus or policy finding.
"""
import argparse, hashlib, json, os, sys
from collections import Counter, defaultdict

FORMATS = ["ef", "bump", "beef", "atomic-beef", "tsc"]


def load(path):
    with open(path) as fh:
        return {r["id"]: r for r in (json.loads(l) for l in fh if l.strip())}


def norm_bump(o):
    return {"height": o.get("height"),
            "txids": sorted((t.get("offset"), t.get("txid"), t.get("root")) for t in o.get("txids") or [])}


def norm_entry(t):
    mined = t.get("mined")
    if isinstance(mined, dict):
        mined = (mined.get("height"), mined.get("index"), mined.get("root"))
    return (t.get("txid"), t.get("kind"), t.get("bump"), mined)


def norm_beef(o, unordered):
    txs = [norm_entry(t) for t in o.get("txs") or []]
    out = {"version": o.get("version"), "bumps": [(b.get("height"), b.get("root")) for b in o.get("bumps") or []],
           "txs": sorted(txs, key=repr) if unordered else txs}
    if "subject" in o:
        out["subject"] = o.get("subject")
    return out


def objects(fmt, o, unordered=False):
    if fmt == "ef":
        return {"txid": o.get("txid"), "tx": o.get("tx"), "spent": o.get("spent")}
    if fmt == "bump":
        return norm_bump(o)
    return norm_beef(o, unordered)


LONG, WINDOW = 65536, 4096


def compact(line, hexin):
    """A column line with every hex field over LONG characters replaced by its digest (and its differing window)."""
    if line is None:
        return None
    out = {}
    for k, v in line.items():
        if not (isinstance(v, str) and len(v) > LONG):
            out[k] = v
            continue
        d = {"bytes": len(v) // 2, "sha256": hashlib.sha256(bytes.fromhex(v)).hexdigest()}
        if v == hexin:
            d["equals_input"] = True
        elif len(v) == len(hexin):
            i = next(j for j in range(len(v)) if v[j] != hexin[j]) // 2 * 2
            e = len(v) - next(j for j in range(1, len(v) + 1) if v[-j] != hexin[-j]) // 2 * 2
            e = min(len(v), -(-(e + 1) // 2) * 2)
            if e - i <= WINDOW:
                d.update({"differs_in_bytes": [i // 2, e // 2], "window": v[i:e], "input_window": hexin[i:e]})
        out[k] = {"elided": d}
    return out


def first_difference(a, b):
    for k in sorted(set(a) | set(b)):
        if a.get(k) != b.get(k):
            return k
    return None


def classify(row, spec, eng):
    fmt = row["format"]
    if fmt == "tsc":
        if not spec.get("codec"):
            return "spec-only", "the spec's codec refuses the row; no engine reads the TSC form"
        if eng.get("read_bump_root") == spec.get("root"):
            return "agree", ""
        return "root", f"engine {eng.get('read_bump_root')} spec {spec.get('root')}"
    sc, ep = bool(spec.get("codec")), bool(eng.get("parse"))
    if sc != ep:
        return "codec", f"engine reads={ep} spec codec={sc}" + (f" (panic: {eng['panic']})" if "panic" in eng else "")
    if not sc:
        return "agree", ""
    unordered = eng.get("order") == "unordered"
    so, eo = objects(fmt, spec, unordered), objects(fmt, eng, unordered)
    if not spec.get("accept"):
        # the spec's view refuses: compare only what the codec determines
        so.pop("bumps", None); eo.pop("bumps", None)
    k = first_difference(so, eo)
    if k is not None:
        return "objects", f"field `{k}`: engine {json.dumps(eo.get(k))[:160]} spec {json.dumps(so.get(k))[:160]}"
    ev = eng.get("valid")
    view_ok = ev is None or bool(ev) == bool(spec.get("accept"))
    if eng.get("reencode") != row["hex"]:
        return "bytes", "the engine's writer does not give the input back" + (
            "" if eng.get("reencode") is not None else " (the writer refused)") + (
            "; view agrees" if view_ok else f"; view differs (engine valid={ev} spec view={spec.get('accept')})")
    if not view_ok:
        return "view", f"engine valid={ev} spec view={spec.get('accept')}"
    return "agree", ""


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--corpus", default="corpus/wire")
    ap.add_argument("--spec", required=True)
    ap.add_argument("--engine", action="append", default=[], help="NAME=PATH")
    ap.add_argument("--json")
    ap.add_argument("--columns-out")
    a = ap.parse_args()
    rows = {}
    for f in FORMATS:
        rows.update(load(os.path.join(a.corpus, f + ".jsonl")))
    spec = load(a.spec)
    missing = sorted(set(rows) - set(spec))
    sanity = [i for i, s in spec.items() if s.get("codec") and s.get("reencode") != rows[i]["hex"]]
    tsc = [i for i, r in rows.items() if r["format"] == "tsc" and spec.get(i, {}).get("codec")]
    print(f"wire spec: {len(spec)} rows of {len(rows)}; codec reads {sum(1 for s in spec.values() if s.get('codec'))}; "
          f"serialize-after-parse holds on {sum(1 for s in spec.values() if s.get('codec')) - len(sanity)} of them "
          f"({'GREEN' if not sanity and not missing else 'RED'}: {len(sanity)} re-encodings differ, {len(missing)} rows absent); "
          f"TSC verify holds on {sum(1 for i in tsc if spec[i].get('verify') is True)} of {len(tsc)}")
    table, witnesses = {}, []
    for spec_arg in a.engine:
        name, path = spec_arg.split("=", 1)
        eng = load(path)
        counts = defaultdict(Counter)
        for i, row in rows.items():
            e = eng.get(i)
            cls, detail = ("absent", "no line") if e is None or i not in spec else classify(row, spec[i], e)
            counts[row["format"]][cls] += 1
            if cls not in ("agree", "spec-only"):
                witnesses.append({"engine": name, "id": i, "format": row["format"], "shape": row["shape"],
                                  "label": row["label"], "class": cls, "detail": detail,
                                  "spec_line": compact(spec.get(i), row["hex"]),
                                  "engine_line": compact(e, row["hex"])})
        table[name] = {f: dict(counts[f]) for f in FORMATS}
        tot = sum((counts[f] for f in FORMATS), Counter())
        print(f"wire {name}: {sum(tot.values())} rows, agree {tot['agree']}, codec {tot['codec']}, bytes {tot['bytes']}, "
              f"objects {tot['objects']}, view {tot['view']}, root {tot['root']}, spec-only {tot['spec-only']}, absent {tot['absent']}; "
              f"bytes rows whose view agrees {sum(1 for w in witnesses if w['engine'] == name and w['class'] == 'bytes' and w['detail'].endswith('view agrees'))}")
    if a.columns_out:
        for name, path in [("spec", a.spec)] + [tuple(x.split("=", 1)) for x in a.engine]:
            col = load(path)
            with open(f"{a.columns_out}-{name}.jsonl", "w") as fh:
                for i in sorted(col):
                    fh.write(json.dumps(compact(col[i], rows[i]["hex"] if i in rows else ""), sort_keys=True) + "\n")
    if a.json:
        with open(a.json, "w") as fh:
            json.dump({"table": table, "witnesses": witnesses, "spec_sanity": sanity, "spec_missing": missing}, fh,
                      indent=1, sort_keys=True)
    return 1 if sanity or missing else 0


if __name__ == "__main__":
    sys.exit(main())
