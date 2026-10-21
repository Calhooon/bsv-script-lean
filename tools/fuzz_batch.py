#!/usr/bin/env python3
"""tools/fuzz_batch.py: one batch's reader for tools/fuzz_campaign.sh (S3, lane fuzz-campaign, 2026-10-15; the SDK
column and the seed discipline, lane fuzz-cut2, the same day).

Reads the batch directory the loop wrote (FZ_B: tools/fuzz_compose.py's corpus and segments.json, run_svnode's output
and --dump, and per SDK engine either run_engine's outputs in its own layout, engines/<engine>/corpus.jsonl and
engines/<engine>/manifest.json, with its --dump and its exit code, or the reason it was SKIPPED BY NAME). Then:
  - the node column, as before: every divergent cell a witness row of $FZ_TREE/corpus/fuzz/<date>.jsonl in the harness's
    witness shape (the corpus Entry at the top level with both keys' verdicts in `expect` and a `divergence` object, as
    run_svnode writes them; the campaign's fields under `fuzz`), ruling `open` (never judged here, CLAUDE.md rule 4);
  - the SDK column: every divergence class of an engine (a column and a rule of its classifier, harness/rules/<engine>.json)
    a witness row of $FZ_TREE/corpus/fuzz/<date>-<engine>.jsonl in the same shape, built from run_engine's --dump (every
    divergent cell's verdicts) at run_engine's own witness entry of the class (its smallest, by the tx's length,
    run_engine.rs's `smallest`; when that spend already holds a row, the class's smallest new cell), the class's cell count and
    leading entry ids under `fuzz`; a class the campaign already holds a row for is counted and not written again,
    except `unexplained`, whose every new spend is written (FZ_ROW_CAP, 20, per engine, column and batch; the rest
    counted);
  - a cell whose spend and column already hold a row (a smoke or replayed case) is counted, never written again; a held
    cell under a new class (a classifier change) is counted in `still`, never written;
  - the replay's tally: per replayed row, whether its own cell diverges again (`still`), agrees now (`fixed`) or was not
    run (`unrun`: its engine skipped or failed);
  - a batch that wrote a row appends its record line to $FZ_TREE/docs/records/<yyyymmdd>-fuzz-campaign-divergences.jsonl,
    keeps run_svnode's own witnesses (its layout: <witnesses>/sv-node/corpus.jsonl) as
    corpus/fuzz/<date>-batch-<n>-sv-node.jsonl when a node row was written, and for each engine with a row run_engine's
    own per-class witnesses (engines/<engine>/corpus.jsonl) as corpus/fuzz/<date>-batch-<n>-<engine>.jsonl, its outputs
    (the manifest beside them) in run_engine's own layout under $FZ_STATE/kept/batch-<n>/engines/;
and prints the batch's one-line count for the loop's log, with `replay_sha256=` (the sha256 of the replay part's lines of
the batch's corpus, the rows of $FZ_REPLAY as they stood: the smoke and fresh parts are reproduced from `seeds=`). Nothing the node or an SDK replies is printed. The environment
names every input (tools/fuzz_campaign.sh sets it).

THE SIGNATURE (lane fuzz-cut3, 2026-10-16; the saturation stopping rule of tools/fuzz_campaign.sh reads it). Every cell of
the node column (a spend and a column, `spec` or `spec-mempool`) has one signature: the family (the corpus part the
spend came from: smoke, replay or the seed_gen family), the column, the spec's verdict and its halt reason word (its
`code`, `-` when none), the node's verdict and its reject reason as the classifier names it (run_svnode's `node_code`,
the reason harness/src/svnode_codes.rs maps the node's description to, `-` when none; from run_svnode's `--cells` file),
and the sorted set of distinct opcodes in the spend's scripts (every input's unlocking script and every prevout's
locking script, each opcode as two lowercase hex digits, the direct pushes 0x01 to 0x4b as the one token `01-4b`, a push
that runs past its script's end as `trunc`). The signature is that text, space-separated, and holds no transaction bytes.
$FZ_STATE/signatures.tsv keeps one line per signature ever seen, `<signature><TAB><the batch that saw it earliest>`,
sorted and unique, outside the repository; the batch line gains `new_sigs=<signatures no earlier batch saw>
sigs_total=<lines of the file after it>`. A transaction the reader cannot frame adds the token tx-unparsed; without a
--cells file (an older run_svnode) the batch line names sig_cells=absent. [D] 2026-10-16 (the captain, lane
fix-fuzz-cut3): a cell of the `mutation` family has the signature WITHOUT the opcode set (the family, the column, the
spec's verdict and halt reason, the node's verdict and reject reason); every other family keeps the full signature. The
reason: a mutated script's opcode set is near-unique, so the cut's dry run counted new_sigs 8,492 then 5,687, of which
mutation 6,879 then 5,435 (docs/records/20261016-135453-fuzz-cut3-s3.md, item 4), and the saturation rule could not
fire while the family runs.

THE RESOURCE CELLS (lane fix2-fuzz-cut3, 2026-10-16; #141's belt while #143 is open). tools/fuzz_campaign.sh's watchdog
kills an evaluator process past FUZZ_SPEC_RSS_MB and bisects its piece down to the single entries that cost it; such an
entry has NO spec line, its id is a line of $FZ_B/resource.txt, and run_svnode and run_engine count it `without a spec
verdict` exactly as any entry without a spec line, so it is counted in the batch line's no_spec (spends without a spec
line; its two cells are neither agreements nor divergences), and the verdict word stays GREEN when nothing diverges. `resource` is the CAMPAIGN'S OWN GAP, [M] per
batch, not the spec's verdict. The batch line gains `resource=<the fresh such entries>` (those outside the resource set),
`resource_ms=<the wall the watchdog spent: its killed runs and its bisect pieces>` and `resource_replay=rows:<the cases of
the resource set's spends>,cleared:<those with a spec line now>,still:<those killed again>`; a cleared entry is removed
from its file of $FZ_STATE/resource/ and named in $FZ_B/resource-cleared.txt, which the loop logs as `resource cleared:
<id> at spec@<commit>`. A resource cell's signature reads `spec:resource:-`, and a witness row replayed on a resource
case counts as `unrun`.
"""
import hashlib, json, os, re, shutil, time

e = os.environ
b, tree, n = e["FZ_B"], e["FZ_TREE"], e["FZ_N"]
day = e["FZ_DAY"]
rec_rel = f"docs/records/{day.replace('-', '')}-fuzz-campaign-divergences.jsonl"
stamp = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
bins = dict(x.split("=") for x in e["FZ_BINS"].split())
seg = json.load(open(f"{b}/segments.json"))
ids = seg["ids"]
seeds = {s["part"]: s["seed"] for s in seg["segments"]}
corpus_path = f"{b}/corpus/seed.jsonl"
gen_sha = hashlib.sha256(open(corpus_path, "rb").read()).hexdigest()
entries, replay_lines = {}, []
for l in open(corpus_path):
    if l.strip():
        x = json.loads(l)
        entries[x["id"]] = x
        if ids.get(x["id"], {}).get("part") == "replay":
            replay_lines.append(l if l.endswith("\n") else l + "\n")
replay_sha = hashlib.sha256("".join(replay_lines).encode()).hexdigest()


def spend_key(x):
    return hashlib.sha256(json.dumps({k: x.get(k) for k in ("tx", "prevouts", "params")}, sort_keys=True).encode()).hexdigest()


def num(pattern, text):
    return int((re.search(pattern, text) or [0, 0])[1])


def reproduce(entry_id):
    """How to regenerate one entry: its part's seed_gen call, or the row it replays."""
    m = ids.get(entry_id, {})
    if m.get("part") == "replay":
        return f"replayed from {', '.join(r['file'] + ':' + r['row'] for r in m.get('rows', []))}"
    fam = "" if m.get("part") == "smoke" else f" --family {m.get('part')}"
    return f"seed_gen{fam} --seed {m.get('seed')} --count {m.get('count')}, its entry {m.get('orig_id')}"


# the cells the campaign already holds a row for: (engine, column, spend) and, for a ruled class, (engine, column, class)
held_cells = {(r["engine"], r["column"], spend_key(entries[i])) for i, m in ids.items() for r in m.get("rows", [])}
held_classes = {(r["engine"], r["column"], r["class"]) for r in seg["replay_rows"]}
divergent_cells = set()  # (engine, column, entry id) of this batch
by_part = {}


def fuzz_fields(entry_id, engine, column, cls, ruling, extra):
    m = ids.get(entry_id, {})
    f = {"campaign": "spec-fuzz", "batch": int(n), "seed": e["FZ_SEED"], "count": int(e["FZ_COUNT"]), "entry_id": entry_id,
         "part": m.get("part"), "part_seed": m.get("seed"), "part_count": m.get("count"), "orig_id": m.get("orig_id"),
         "engine": engine, "column": column, "class": cls, "class_ruling": ruling, "record": rec_rel, "found": stamp,
         "tree": e["FZ_TREE_COMMIT"], "driver": e["FZ_DRIVER"], "binaries_sha256": bins}
    if m.get("part") == "replay":
        f["replays"] = m.get("rows", [])
    f.update(extra)
    return f


def note(entry_id, column):
    return (f"the fuzz campaign's batch {n} (seed {e['FZ_SEED']}, {e['FZ_COUNT']} fresh cases), entry {entry_id}, the "
            f"{column} column; record {rec_rel}; tree {e['FZ_TREE_COMMIT']}; reproduce: {reproduce(entry_id)} "
            f"(tools/fuzz_campaign.sh)")


def witness_row(d, engine, a_key, b_key, b_verdict, b_code, cls, ruling, extra):
    """One divergent cell as a witness row: the whole spend, both keys' verdicts, the class, ruling `open`."""
    a_v = {"verdict": d["spec"]}
    if d["spec_code"] is not None:
        a_v["code"] = d["spec_code"]
    b_v = {"verdict": b_verdict}
    if b_code is not None:
        b_v["code"] = b_code
    if d["native"]:
        b_v["reason"] = d["native"]
    w = dict(entries[d["id"]])
    w["id"] = f"fuzz-{n}-{d['id']}-" + ("" if engine == "sv-node" else engine + "-") + d["column"].replace("/", "-")
    w["expect"] = dict(w.get("expect", {}))
    w["expect"][a_key] = a_v
    w["expect"][b_key] = b_v
    w["divergence"] = {"rule": cls, "a": a_key, "b": b_key, "a_verdict": a_v, "b_verdict": b_v,
                       "decided_by": "", "ruling": "open", "note": note(d["id"], ("" if engine == "sv-node" else engine + " ") + d["column"])}
    w["fuzz"] = fuzz_fields(d["id"], engine, d["column"], cls, ruling, extra)
    return json.dumps(w, sort_keys=True)


# the node column (run_svnode)
out = open(f"{b}/svnode.out", encoding="utf-8", errors="replace").read()
head = re.search(r"\((\d+) entries\) vs (\S+) \(([^)]*)\)", out)
spends = int(head.group(1)) if head else 0
node = head.group(3) if head else "unknown"
node_tag = "sv-node@v1.2.3(" + ((re.search(r"version (\d+)", node) or [None, "unknown"])[1]) + ")"
spec_key = (re.search(r"the spec at (spec@\S+)", out) or [None, "spec@unknown"])[1]
agree = {c: int(k) for c, k in re.findall(r"(spec(?:-mempool)?) (\d+)", (re.search(r"^  agree: ([^;]*)", out, re.M) or [None, ""])[1])}
undecided = num(r"undecided runs \(timeout/skipped\) (\d+)", out)
unknown = num(r"descriptions outside the table (\d+)", out)
drifts = num(r"flag-word drifts (\d+)", out)
no_spec = num(r"without a spec verdict (\d+)", out)
classes = [{"column": c, "class": r, "entries": int(k), "ruling": u} for c, r, k, u in
           re.findall(r"^\| (spec(?:-mempool)?) \| `([^`]+)` \| (\d+) \| ([^|]+?) \|", out, re.M)]
verdict = "GREEN" if re.search(r"^run_svnode: GREEN", out, re.M) else "RED"
dump = [json.loads(l) for l in open(f"{b}/dump.jsonl") if l.strip()]
rulings = {(c["column"], c["class"]): c["ruling"] for c in classes}
node_rows = []
for d in dump:
    divergent_cells.add(("sv-node", d["column"], d["id"]))
    part = ids.get(d["id"], {}).get("part", "unknown")
    by_part[part] = by_part.get(part, 0) + 1
    if ("sv-node", d["column"], spend_key(entries[d["id"]])) in held_cells:
        continue
    mp = d["column"] == "spec-mempool"
    a_key = ("spec-mempool@" + spec_key.split("@", 1)[1]) if mp else spec_key
    b_key = "sv-node-mempool@v1.2.3" if mp else "sv-node@v1.2.3"
    node_rows.append(witness_row(d, "sv-node", a_key, b_key, d["node"], d["node_code"], d["class"],
                                 rulings.get((d["column"], d["class"]), "open"), {"version": d["version"], "node_version": node}))
unexplained = sum(c["entries"] for c in classes if c["class"] == "unexplained")

# the SDK column (run_engine), each engine run, skipped by name, or failed
engine_lines, engine_rows, engine_counts = [], {}, {}
for eng in e.get("FZ_ENGINES", "").split():
    key = eng.replace("-", "_")
    skip = f"{b}/engine-{eng}.skip"
    if os.path.exists(skip):
        reason = re.sub(r"[^A-Za-z0-9.]+", "-", open(skip).read().strip()).strip("-")
        engine_lines.append(f"{key}=SKIPPED({reason})")
        engine_counts[eng] = {"status": "SKIPPED", "reason": open(skip).read().strip()}
        continue
    rc = open(f"{b}/engine-{eng}.rc").read().strip()
    man_p = f"{b}/engines/{eng}/manifest.json"
    eout = open(f"{b}/engine-{eng}.out", encoding="utf-8", errors="replace").read()
    ev = "GREEN" if re.search(r"^run_engine: GREEN", eout, re.M) else "RED" if re.search(r"^run_engine: RED", eout, re.M) else ""
    if not os.path.exists(man_p) or not ev:
        engine_lines.append(f"{key}=FAILED(exit-{rc})")
        engine_counts[eng] = {"status": "FAILED", "exit": rc, "output": f"{b}/engine-{eng}.out"}
        continue
    man = json.load(open(man_p))["corpus"]
    rules = man.get("rules", [])
    edump = [json.loads(l) for l in open(f"{b}/engine-{eng}.dump.jsonl") if l.strip()]
    for d in edump:
        divergent_cells.add((eng, d["column"], d["id"]))
        part = ids.get(d["id"], {}).get("part", "unknown")
        by_part[part] = by_part.get(part, 0) + 1
    ekey = man.get("engine", f"{eng}@unknown")
    ever = ekey.split("@", 1)[1]
    rows = []
    for r in rules:
        cells = [d for d in edump if d["column"] == r["column"] and d["classified"] == r["rule"]]
        fresh = [d for d in cells if (eng, r["column"], spend_key(entries[d["id"]])) not in held_cells]
        if r["rule"] != "unexplained":
            if (eng, r["column"], r["rule"]) in held_classes:
                continue
            fresh = [d for d in fresh if d["id"] == r["from"]] or sorted(fresh, key=lambda d: len(entries[d["id"]]["tx"]))[:1]
        else:
            fresh = fresh[: int(e.get("FZ_ROW_CAP", "20"))]
        mp = r["column"].endswith("spec-mempool")
        a_key = ("spec-mempool@" + spec_key.split("@", 1)[1]) if mp else spec_key
        b_key = f"{eng}-default@{ever}" if r["column"].startswith("default/") else f"{eng}-mempool@{ever}" if r["column"] == "spec-mempool" else ekey
        for d in fresh:
            rows.append(witness_row(d, eng, a_key, b_key, d["engine"], d["engine_code"], r["rule"], r["ruling"],
                                    {"class_decided_by": r.get("decided_by"), "cells": r["entries"],
                                     "entry_ids": [c["id"] for c in cells[:20]], "engine_key": ekey,
                                     "run_engine_witnesses": f"corpus/fuzz/{day}-batch-{n}-{eng}.jsonl",
                                     "run_engine_outputs": f"kept/batch-{n}/engines/{eng}/ under the campaign's state directory (run_engine's layout, its manifest; outside the repository)"}))
        if fresh:
            held_classes.add((eng, r["column"], r["rule"]))
    engine_rows[eng] = rows
    ag = sum(man.get("agree", {}).values())
    dv = sum(r["entries"] for r in rules)
    ux = sum(r["entries"] for r in rules if r["rule"] == "unexplained")
    engine_counts[eng] = {"status": ev, "entries": man.get("entries"), "agree": man.get("agree"), "divergent": dv,
                          "unexplained": ux, "undecided": man.get("undecided_runs"), "aborts": man.get("aborts_as_witnesses"),
                          "rules": rules, "rows": len(rows), "engine": man.get("engine")}
    engine_lines.append(f"{key}={ev},agree:{ag},divergent:{dv},unexplained:{ux},undecided:{man.get('undecided_runs')},"
                        f"aborts:{man.get('aborts_as_witnesses')},rows:{len(rows)}")

# the signatures (the header): every node cell's, against $FZ_STATE/signatures.tsv
def opcodes(script_hex):
    ops, sc, i = set(), bytes.fromhex(script_hex or ""), 0
    while i < len(sc):
        op = sc[i]
        i += 1
        if 0x01 <= op <= 0x4b:
            ops.add("01-4b")
            i += op
        else:
            ops.add(f"{op:02x}")
            if op in (0x4c, 0x4d, 0x4e):
                w = {0x4c: 1, 0x4d: 2, 0x4e: 4}[op]
                if i + w > len(sc):
                    ops.add("trunc")
                    break
                i += w + int.from_bytes(sc[i:i + w], "little")
        if i > len(sc):
            ops.add("trunc")
    return ops


def spend_ops(x):
    ops = set()
    for p in x.get("prevouts") or []:
        ops |= opcodes(p.get("script", ""))
    try:
        t, i = bytes.fromhex(x["tx"]), 4

        def varint():
            nonlocal i
            v = t[i]
            i += 1
            if v >= 0xfd:
                w = {0xfd: 2, 0xfe: 4, 0xff: 8}[v]
                v = int.from_bytes(t[i:i + w], "little")
                i += w
            return v
        for _ in range(varint()):
            i += 36
            ln = varint()
            ops |= opcodes(t[i:i + ln].hex())
            i += ln + 4
    except (IndexError, KeyError, ValueError):
        ops.add("tx-unparsed")
    return ops


res_p = f"{b}/resource.txt"
killed = {l.strip() for l in open(res_p)} - {""} if os.path.exists(res_p) else set()
spec_of = {}
for l in open(f"{b}/spec.jsonl"):
    if l.strip():
        x = json.loads(l)
        spec_of[x["id"]] = x
cells_p = f"{b}/cells.jsonl"
node_of = {}
if os.path.exists(cells_p):
    for l in open(cells_p):
        if l.strip():
            c = json.loads(l)
            node_of[(c["column"], c["id"])] = (c["node"], c["node_code"])
else:
    for d in dump:
        node_of[(d["column"], d["id"])] = (d["node"], d["node_code"])
sig_p = f"{e['FZ_STATE']}/signatures.tsv"
sigs = {}
if os.path.exists(sig_p):
    for l in open(sig_p, encoding="utf-8"):
        if "\t" in l:
            k, v = l.rstrip("\n").rsplit("\t", 1)
            sigs[k] = v
new_sigs = 0
for i, x in entries.items():
    ops = ",".join(sorted(spend_ops(x)))
    fam = ids.get(i, {}).get("part", "unknown")
    for column in ("spec", "spec-mempool"):
        sv = (spec_of.get(i) or {}).get(column) or {}
        # without a --cells file (an older run_svnode) an agreeing cell's node verdict is the spec's and its reason `?`
        nv, nc = node_of.get((column, i), ("none", None) if os.path.exists(cells_p) else (sv.get("verdict", "none"), "?"))
        sv_word = "resource:-" if i in killed else f"{sv.get('verdict', 'none')}:{sv.get('code') or '-'}"
        sig = f"{fam} {column} spec:{sv_word} node:{nv}:{nc or '-'}"
        if fam != "mutation":
            sig += f" ops:{ops}"
        if sig not in sigs:
            sigs[sig] = n
            new_sigs += 1
if new_sigs:
    with open(sig_p + ".tmp", "w", encoding="utf-8") as f:
        f.write("".join(f"{k}\t{v}\n" for k, v in sorted(sigs.items())))
    os.replace(sig_p + ".tmp", sig_p)

# the replay's tally: each replayed row's own cell
tally = {"rows": 0, "still": 0, "fixed": 0, "unrun": 0}
ran = {"sv-node"} | {k for k, v in engine_counts.items() if v["status"] in ("GREEN", "RED")}
for i, m in ids.items():
    for r in m.get("rows", []):
        tally["rows"] += 1
        tally["unrun" if r["engine"] not in ran or i in killed else "still" if (r["engine"], r["column"], i) in divergent_cells
              else "fixed"] += 1

# the resource set's tally (the header): a flagged case with a spec line is cleared and its spend leaves the set
res_ids = {i: m["resource"] for i, m in ids.items() if "resource" in m}
resource = len(killed - set(res_ids))
res_still = sorted(i for i in res_ids if i in killed)
res_cleared = sorted(i for i in res_ids if i not in killed and i in spec_of)
gone = {res_ids[i]["key"]: res_ids[i] for i in res_cleared}
cleared_lines = []
for fn in sorted({m["file"] for m in gone.values()}):
    fp = f"{e['FZ_STATE']}/resource/{fn}"
    if not os.path.exists(fp):
        continue
    keep = [l for l in open(fp) if l.strip() and spend_key(json.loads(l)) not in gone]
    with open(fp + ".tmp", "w") as f:
        f.write("".join(keep))
    os.replace(fp + ".tmp", fp)
    if not keep:
        os.remove(fp)
for k, m in gone.items():
    cleared_lines.append(f"{m['orig_id']} (resource/{m['file']}) at {spec_key}")
with open(f"{b}/resource-cleared.txt", "w") as f:
    f.write("".join(l + "\n" for l in sorted(set(cleared_lines))))
res_line = (f"resource={resource} resource_ms={e.get('FZ_RESOURCE_MS', '0')} "
            f"resource_replay=rows:{len(res_ids)},cleared:{len(res_cleared)},still:{len(res_still)}")

written = bool(node_rows) or any(engine_rows.values())
day_files = {}
if node_rows:
    day_files["sv-node"] = f"corpus/fuzz/{day}.jsonl"
for eng, rows in engine_rows.items():
    if rows:
        day_files[eng] = f"corpus/fuzz/{day}-{eng}.jsonl"
os.makedirs(f"{tree}/corpus/fuzz", exist_ok=True)
for who, rel in day_files.items():
    with open(f"{tree}/{rel}", "a") as f:
        f.write("\n".join(node_rows if who == "sv-node" else engine_rows[who]) + "\n")
kept_sv = None
if node_rows and os.path.exists(f"{b}/w/sv-node/corpus.jsonl"):
    kept_sv = f"corpus/fuzz/{day}-batch-{n}-sv-node.jsonl"
    shutil.copyfile(f"{b}/w/sv-node/corpus.jsonl", f"{tree}/{kept_sv}")
kept_eng = {}
for eng, rows in engine_rows.items():
    if rows and os.path.exists(f"{b}/engines/{eng}/corpus.jsonl"):
        kept_eng[eng] = f"corpus/fuzz/{day}-batch-{n}-{eng}.jsonl"
        shutil.copyfile(f"{b}/engines/{eng}/corpus.jsonl", f"{tree}/{kept_eng[eng]}")
if any(engine_rows.values()) and os.path.isdir(f"{b}/engines"):
    kept = f"{e['FZ_STATE']}/kept/batch-{n}"
    os.makedirs(kept, exist_ok=True)
    shutil.move(f"{b}/engines", f"{kept}/engines")
parts = seg["parts"]
order = [p for p in ("smoke",) if p in seeds] + ["replay"] + (["resource"] if parts.get("resource") else []) + [p for p in seeds if p != "smoke"]
fams = ",".join(f"{p}:{parts.get(p, 0)}" for p in order)
seed_list = ",".join(f"{s['part']}:{s['seed']}" for s in seg["segments"])
if written:
    os.makedirs(f"{tree}/docs/records", exist_ok=True)
    with open(f"{tree}/{rec_rel}", "a") as f:
        f.write(json.dumps({"stamp": stamp, "batch": int(n), "seed": e["FZ_SEED"], "count": int(e["FZ_COUNT"]), "parts": parts,
            "part_seeds": seeds, "spends": spends, "agree": agree, "divergent_cells": len(dump), "classes": classes,
            "verdict": verdict, "undecided": undecided, "no_spec": no_spec, "descriptions_outside_table": unknown,
            "flag_word_drifts": drifts, "engines": engine_counts, "replay": tally, "divergent_by_part": by_part,
            "spec": spec_key, "node": node, "tree": e["FZ_TREE_COMMIT"], "driver": e["FZ_DRIVER"],
            "witness_files": {k: (v, hashlib.sha256(open(f"{tree}/{v}", "rb").read()).hexdigest()) for k, v in day_files.items()},
            "batch_sha256": gen_sha, "binaries_sha256": bins, "sv_node_witnesses": kept_sv,
            "engine_witnesses": {k: (v, hashlib.sha256(open(f"{tree}/{v}", "rb").read()).hexdigest()) for k, v in kept_eng.items()},
            "replay_sha256": replay_sha, "resource": res_line}, sort_keys=True) + "\n")
print(f"batch={n} seed={e['FZ_SEED']} count={e['FZ_COUNT']} spends={spends} cells={2 * spends} "
      f"agree={sum(agree.values())} divergent={len(dump)} unexplained={unexplained} undecided={undecided} no_spec={no_spec} "
      f"unknown_descriptions={unknown} drifts={drifts} verdict={verdict} {' '.join(engine_lines)} "
      f"families={fams} seeds={seed_list} replay_sha256={replay_sha} replay=rows:{tally['rows']},still:{tally['still']},fixed:{tally['fixed']},unrun:{tally['unrun']}"
      + (f" divergent_by_family={','.join(f'{p}:{k}' for p, k in sorted(by_part.items()))}" if by_part else "")
      + f" chunks={e.get('FZ_CHUNKS', '1')} {res_line} new_sigs={new_sigs} sigs_total={len(sigs)}"
      + ("" if os.path.exists(cells_p) else " sig_cells=absent")
      + f" {spec_key} node={node_tag} tree={e['FZ_TREE_COMMIT']} driver={e['FZ_DRIVER']} batch_sha256={gen_sha} "
      f"load={e['FZ_LOAD']} wall={e['FZ_WALL']}s walls={e.get('FZ_WALLS', '')}"
      + (f" witnesses={'+'.join(day_files.values())} record={rec_rel}" if written else ""))
