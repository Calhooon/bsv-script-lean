#!/usr/bin/env python3
"""tools/teranode_gate.py (bsv-script-lean #95; S3, lane gate-95, 2026-10-17): the per-release divergence report,
the writer behind `make teranode-gate`.

One page for a Teranode release against the reference pin: this Teranode (docs/PROVENANCE.md section 1a,
`teranode.tag`/`teranode.commit`) against this bitcoin-sv (`reference.tag`/`reference.commit`), on the script corpus's
column and the scenario corpus's column (#66), read through #88's obligation list (corpus/teranode/obligations.json):
the counts per corpus and per obligation kind, EVERY divergence as a witness row (its id, both verdicts, its class in
the list's vocabulary, its citation, where its ruling stands) and THE DELTA from the previous gate record. The report
cites rulings and never makes one (CLAUDE.md rule 15): a difference no ruling names is `open`.

The vocabulary is the obligation list's six kinds (`kinds` in obligations.json), read from the file and never
extended: theorem, witness, design (an architecture decision of Teranode's in the protocol's service, its reason cited,
policy), chain-split (the two nodes decide the same blocks differently, consensus), report, open. The owner's framing
rule of 2026-10-17 (docs/PLAN-2026-10-05-SPEC-ALONE.md section 6, card Z8): every difference is read against Teranode's
north star, scale without a protocol change.

THE INPUTS (each named with its sha256 in the record):
  docs/PROVENANCE.md section 1a          the two pins (tools/check_pins.py's reader)
  corpus/teranode/obligations.json       #88's list: the 54 rows, their kinds, the 20 rows marked `rerun`, the
                                         divergences with their reasons and legs (the legs' records named, never opened)
  corpus/teranode/absences.json          #96's ledger: the words and rulings of the rows the design rows name
  harness/rules/teranode-gate.json       the gate's data: the scenario row to obligation row index, the ruling sources
  harness/rules/second-oracle-scenarios.json   the scenario column's classes and their citations
  the scenario column                    docs/records/<stamp>-*-second-oracle-*.json covering the whole column, each row
                                         with the reference's verdict (`reference_token`) and Teranode's (`verdict`,
                                         `observed`)
  the script column, Teranode            harness/engines/instance41/runs/<stamp>-<name>/[<corpus>/]chunk-*.manifest.json
                                         (run_teranode; its runs since 2026-10-15 read through the observation contract
                                         of #97, harness/src/bin/run_teranode.rs:11; the runs before that date did not)
  the script column, the reference       corpus/witnesses/sv-node/manifest.json (the committed column of tools/column.py)
  the previous gate record               the newest docs/records/<stamp>-s8-95-gate-report-s3.json older than this one
                                         (a live run prefers the newest live record and says when it falls back to a
                                         dry one); the delta's head names the previous record's mode

THE RECORD (the captain's ruling of 2026-10-17 on the lens of lane gate-95): docs/records/<stamp>-s8-95-gate-report-s3.md
and .json, PUBLIC by #95's charter (a page either team reads). It carries verdict words and codes, the obligation
list's classes, row ids, hashes and counts, and never a node's message text: an observed or reference value is printed
field by field, a string field only when it is a code (CODE below), any other string as `(text: the step log)`. The
nodes' own text is in the steps' raw log, docs/records/<SINCE>-s8-95-gate-teranode-log-s4b.txt, which
tools/teranode_gate.sh writes and names in tools/export_withheld.txt (group hz-95-teranode-gate-logs), so the export
never carries it and an ordinary lane never opens it.

Usage:
  tools/teranode_gate.py --dry-run [--out-dir DIR] [--previous PATH|none] [--scenario PATH] [--obligations PATH]
  tools/teranode_gate.py --live --since <YYYYmmdd-HHMMSS>   (tools/teranode_gate.sh calls it after the measuring steps)
  tools/teranode_gate.py --chunks [N]   the scenario column's chunks, one `ORACLE_ROWS=<ids>` line each (the plan prints
                                        them); N by default from the newest whole column's wall (CHUNK_SECONDS a chunk)
A dry run builds the report from the records on disk and starts nothing; its head says so. Exit 0 written, 1 a source
whose counts disagree with themselves or a text the wording rule refuses, 2 a usage or setup stop.
"""
import argparse
import datetime
import glob
import hashlib
import json
import os
import re
import socket
import subprocess
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
sys.path.insert(0, os.path.join(ROOT, "tools"))
RECORDS = os.path.join(ROOT, "docs", "records")
OBLIGATIONS = "corpus/teranode/obligations.json"
ABSENCES = "corpus/teranode/absences.json"
GATE_RULES = "harness/rules/teranode-gate.json"
SCENARIO_RULES = "harness/rules/second-oracle-scenarios.json"
SV_MANIFEST = "corpus/witnesses/sv-node/manifest.json"
SCENARIO_FAMILIES = ["block", "chain", "finality", "mempool", "oracle", "utxo"]
TERANODE_RUNS = "harness/engines/instance41/runs"
KINDS = ["theorem", "witness", "design", "chain-split", "report", "open"]
VERDICTS = ["agree", "diverge", "non-judging", "no-verdict", "rpc-precheck", "pending", "unrealizable"]
# a string field of an observed or reference value printed in the record: a code, never a message
CODE = re.compile(r"^[A-Za-z0-9_.:/+-]{0,64}$")
GATE_SUFFIX = "-s8-95-gate-report-s3"
LOG_SUFFIX = "-s8-95-gate-teranode-log-s4b.txt"
# the scenario column's whole wall is 2,017.7 s (20261016-001926's `wall_seconds`, 137 realizable rows); a chunk is sized
# to about 400 s so that the instance's start and stop and a restart row fit under a call's 600 s
CHUNK_SECONDS = 400
# CLAUDE.md rule 13 and tools/wording_gate.sh's forms, written with a character class so this file carries none of
# them, plus the word the framing rule retires for a design row
REFUSED = re.compile(r"\b(conforman[t]\w*|bug[s]?|firs[t]|nove[l]|unprecedente[d])\b|\u2014|&mdash;", re.I)


class Stop(Exception):
    def __init__(self, code, text):
        super().__init__(text)
        self.code = code


def rel(path):
    return os.path.relpath(os.path.abspath(path), ROOT)


def load(path):
    with open(os.path.join(ROOT, path) if not os.path.isabs(path) else path, encoding="utf-8") as f:
        return json.load(f)


def sha256(path):
    h = hashlib.sha256()
    with open(os.path.join(ROOT, path) if not os.path.isabs(path) else path, "rb") as f:
        h.update(f.read())
    return h.hexdigest()


def pins():
    import check_pins
    p = check_pins.pins_block()
    return {"reference": {"name": "bitcoin-sv", "tag": p["reference.tag"], "commit": p["reference.commit"]},
            "teranode": {"name": "Teranode", "tag": p["teranode.tag"], "commit": p["teranode.commit"]}}


def stamp_of(path):
    m = re.match(r"(\d{8}-\d{6})", os.path.basename(path))
    return m.group(1) if m else ""


# ---------------------------------------------------------------- the sources
def corpus_ids():
    """The scenario corpus's row ids per family (corpus/chain/<family>/<family>.jsonl, the rows #66's runner reads)."""
    out = {}
    for fam in SCENARIO_FAMILIES:
        with open(os.path.join(ROOT, "corpus", "chain", fam, f"{fam}.jsonl"), encoding="utf-8") as f:
            out[fam] = [json.loads(line)["id"] for line in f if line.strip()]
    return out


def column_ids(path):
    try:
        fams = load(path).get("families")
    except (OSError, ValueError):
        return None
    if not isinstance(fams, dict):
        return None
    return {f: [r["id"] for r in rows] for f, rows in fams.items()}


def newest_scenario(since=""):
    """The newest JSON under docs/records covering every row of the scenario corpus; with `since`, every chunk JSON
    written since then, which together must cover each row once."""
    want = corpus_ids()
    found = sorted(p for p in glob.glob(os.path.join(RECORDS, "*-second-oracle-*.json")) if stamp_of(p) >= since)
    if since:
        if not found:
            raise Stop(2, f"no scenario column JSON under docs/records written since {since} (STEP=scenario-teranode writes it)")
        return [rel(p) for p in found]
    for p in reversed(found):
        ids = column_ids(p)
        if ids is not None and all(len(ids.get(f, [])) == len(want[f]) for f in want):
            return [rel(p)]
    raise Stop(2, "no whole scenario column under docs/records (a *-second-oracle-*.json with as many rows per family "
                  "as corpus/chain's six families)")


def newer_partials(read, since=""):
    """The scenario column JSONs newer than the newest one read that the report did not read (a partial re-run, or a
    whole column when --scenario names an older one): [(path, whole or partial, [row ids])]."""
    top = max(stamp_of(p) for p in read)
    want = corpus_ids()
    out = []
    for p in sorted(glob.glob(os.path.join(RECORDS, "*-second-oracle-*.json"))):
        if rel(p) in read or stamp_of(p) <= top or stamp_of(p) < since:
            continue
        ids = column_ids(p) or {}
        whole = all(len(ids.get(f, [])) == len(want[f]) for f in want)
        out.append((rel(p), "whole" if whole else "partial", [i for f in sorted(ids) for i in ids[f]]))
    return out


def chunks(n=None):
    """The scenario column's chunks over every corpus row once: the rows the newest whole column found realizable dealt
    evenly over n chunks in corpus order, the unrealizable rows (no node call) likewise; n by default the newest whole
    column's wall over CHUNK_SECONDS, rounded up. [(n realizable, [ids])]."""
    want = corpus_ids()
    whole = newest_scenario()[0]
    v = load(whole)
    unreal = {r["id"] for rows in v["families"].values() for r in rows if "unrealizable" in r}
    if n is None:
        wall = (v.get("wall_seconds") or {}).get("value") or CHUNK_SECONDS
        n = max(1, -(-int(wall) // CHUNK_SECONDS))
    ids = [i for f in SCENARIO_FAMILIES for i in want[f]]
    real = [i for i in ids if i not in unreal]
    rest = [i for i in ids if i in unreal]
    out = [[] for _ in range(n)]
    counts = [0] * n
    for group, is_real in ((real, True), (rest, False)):
        size = -(-len(group) // n) if group else 0
        for k in range(n):
            part = group[k * size:(k + 1) * size]
            out[k] += part
            if is_real:
                counts[k] = len(part)
    return whole, v.get("wall_seconds"), [(counts[k], out[k]) for k in range(n) if out[k]]


def reference_column(since="", only=None):
    """The reference's scenario column: per family the newest docs/records/*-regtest-s3.json holding that family's
    whole row set (run_scenarios --family), or the named JSONs alone. {family: path}."""
    want = corpus_ids()
    paths = only or sorted(p for p in glob.glob(os.path.join(RECORDS, "*-regtest-s3.json")) if stamp_of(p) >= since)
    out = {}
    for p in paths:
        ids = column_ids(p)
        if not ids:
            continue
        for fam, rows in ids.items():
            if fam in want and len(rows) == len(want[fam]):
                out[fam] = rel(p)
    missing = [f for f in want if f not in out]
    if missing:
        raise Stop(2, "no reference scenario column for the families " + ", ".join(missing)
                      + " (a *-regtest-s3.json with the family's whole row set" + (f", written since {since}" if since else "") + ")")
    return out


def read_reference(fams):
    counts = {}
    for fam, path in sorted(fams.items()):
        v = load(path)
        c = {k: 0 for k in ["rows"] + VERDICTS}
        for r in v["families"][fam]:
            verdict = r.get("verdict") or ("unrealizable" if r.get("unrealizable") else "pending")
            c["rows"] += 1
            c[verdict] = c.get(verdict, 0) + 1
        own = v["counts"][fam]
        for k in ["rows"] + VERDICTS:
            if own.get(k, 0) != c.get(k, 0):
                raise Stop(1, f"{path}: family {fam}: {k} counted {c.get(k, 0)} from its rows, {own.get(k, 0)} in its counts")
        counts[fam] = {"record": path, "version": v.get("version"), "base_commit": (v.get("base_commit") or "")[:8], **c}
    return counts


def teranode_script_runs(since="", only=None):
    """The newest run per corpus under harness/engines/instance41/runs (or the named run directories alone):
    {corpus: (run dir, [manifest paths])}."""
    out = {}
    dirs = [os.path.join(ROOT, d) for d in only] if only else sorted(glob.glob(os.path.join(ROOT, TERANODE_RUNS, "*")))
    for run in dirs:
        if not os.path.isdir(run) or stamp_of(run) < since:
            continue
        direct = sorted(glob.glob(os.path.join(run, "chunk-*.manifest.json")))
        groups = {}
        for m in direct:
            groups.setdefault(load(m)["corpus"]["name"], []).append(m)
        for sub in sorted(glob.glob(os.path.join(run, "*", "chunk-*.manifest.json"))):
            groups.setdefault(load(sub)["corpus"]["name"], []).append(sub)
        # the native shape seed_chunk.zsh leaves (run_teranode --out makes a directory per chunk; the run's
        # manifests may be kept that way before any lane folds them into the file shape above)
        for sub in sorted(glob.glob(os.path.join(run, "*", "chunk-*", "manifest.json"))):
            groups.setdefault(load(sub)["corpus"]["name"], []).append(sub)
        for corpus, ms in groups.items():
            out[corpus] = (rel(run), [rel(m) for m in ms])
    if not out:
        raise Stop(2, f"no Teranode script run under {TERANODE_RUNS}" + (f" since {since}" if since else ""))
    return out


def previous_record(stamp, explicit, live=False):
    """(path, its mode, a note): the newest gate record older than `stamp`; for a live run the newest live one, else
    the newest dry run with a note saying so."""
    if explicit == "none":
        return None, None, ""
    if explicit:
        return explicit, load(explicit).get("mode"), ""
    older = sorted(p for p in glob.glob(os.path.join(RECORDS, f"*{GATE_SUFFIX}.json")) if stamp_of(p) < stamp)
    if not older:
        return None, None, ""
    if live:
        lv = [p for p in older if load(p).get("mode") == "live"]
        if lv:
            return rel(lv[-1]), "live", ""
        return (rel(older[-1]), load(older[-1]).get("mode"),
                "no live gate record under docs/records yet, so the newest dry run stands as the previous")
    return rel(older[-1]), load(older[-1]).get("mode"), ""


def codes_only(v):
    """A value as the record may print it: numbers, booleans and code strings kept, any other string replaced."""
    if isinstance(v, dict):
        return {k: codes_only(x) for k, x in v.items()}
    if isinstance(v, list):
        return [codes_only(x) for x in v]
    if isinstance(v, str) and not CODE.match(v):
        return "(text: the step log)"
    return v


# ---------------------------------------------------------------- the reading
def obligation_row(rules, family, rid):
    for r in rules.get(family, []):
        if rid in r.get("id_in", []) or ("prefix" in r and rid.startswith(r["prefix"])):
            return r["row"]
    raise Stop(1, f"scenario row {family}:{rid}: no rule of {GATE_RULES} matches it")


def parse_token(token):
    """`measured agree: <json> [X] docs/records/...` to (verdict, value, citation)."""
    m = re.match(r"^([a-z][a-z -]*?): (.*)$", token or "", re.S)
    if not m:
        return token or "", None, ""
    verdict, rest = m.group(1), m.group(2)
    try:
        value, end = json.JSONDecoder().raw_decode(rest)
        return verdict, value, rest[end:].strip()
    except ValueError:
        return verdict, rest, ""


def compact(v):
    return json.dumps(v, sort_keys=True, separators=(",", ":")) if not isinstance(v, str) else v


def read_scenarios(paths, gate, classes, obl_rows, list_class):
    """The scenario column from one JSON or several chunks: every corpus row once, each chunk's own totals re-added
    from its rows."""
    rows, recount, divs, seen, heads = [], {}, [], {}, []
    for path in paths:
        v = load(path)
        heads.append(v)
        own_count = {}
        for fam, frows in sorted(v["families"].items()):
            c = recount.setdefault(fam, {k: 0 for k in ["rows"] + VERDICTS})
            oc = own_count.setdefault(fam, {k: 0 for k in ["rows"] + VERDICTS})
            for r in frows:
                if r["id"] in seen:
                    raise Stop(2, f"scenario row {r['id']} is in both {seen[r['id']]} and {path}: name the chunks of "
                                  "record with --scenario")
                seen[r["id"]] = path
                verdict = r.get("verdict", "unrealizable" if "unrealizable" in r else "pending")
                for acc in (c, oc):
                    acc["rows"] += 1
                    acc[verdict] = acc.get(verdict, 0) + 1
                row = obligation_row(gate["scenario_rows"], fam, r["id"])
                if row not in obl_rows:
                    raise Stop(1, f"{GATE_RULES}: scenario row {r['id']} names {row}, not a row of {OBLIGATIONS}")
                rows.append({"family": fam, "id": r["id"], "verdict": verdict, "row": row})
                if verdict != "diverge":
                    continue
                ref_verdict, ref_value, ref_cite = parse_token(r.get("reference_token", ""))
                adj = r.get("adjudication") or {}
                cls = adj.get("class", "unexplained")
                meta = classes.get(cls, {})
                div_id = gate.get("class_divergence", {}).get(cls)
                divs.append({
                    "key": f"scenario:{r['id']}", "source": "scenario column", "row": row,
                    "row_kind": obl_rows[row]["kind"], "id": r["id"],
                    "reference": f"{ref_verdict}: {compact(codes_only(ref_value))}" if ref_value is not None else ref_verdict,
                    "teranode": "diverge: " + compact(codes_only(r.get("observed", {})))
                                + (f" (fields {', '.join(r['diverging_fields'])})" if r.get("diverging_fields") else "")
                                + (f" (stage {r['stage']})" if r.get("stage") else ""),
                    "class": list_class.get(div_id, "open") if div_id else "open",
                    "detail": cls,
                    "citation": meta.get("decided_by", "none: unexplained, a Finding owed with its witness hash (rule 4)"),
                    "ruling": (f"{gate['scenario_ruling']}: `{adj.get('ruling', meta.get('ruling', 'open'))}`"
                               + (f"; the same difference as the list's `{div_id}`" if div_id else "")
                               + ("; on a theorem row: its premises or the index row owed a reading"
                                  if obl_rows[row]["kind"] == "theorem" else "")),
                    "reference_record": ref_cite,
                })
        for fam, oc in own_count.items():
            own = v["counts"].get(fam, {})
            for k in ["rows"] + VERDICTS:
                if own.get(k, 0) != oc.get(k, 0):
                    raise Stop(1, f"{path}: family {fam}: {k} counted {oc.get(k, 0)} from its rows, {own.get(k, 0)} in its counts")
    want = corpus_ids()
    coverage = []
    for fam, ids in want.items():
        got = {r["id"] for r in rows if r["family"] == fam}
        if len(got) != len(ids):
            raise Stop(2, f"the scenario column has {len(got)} rows of family {fam}, the corpus {len(ids)}: name the "
                          "chunks of record with --scenario")
        for x in sorted(set(ids) - got):
            coverage.append(f"corpus row `{x}` ({fam}) is not in the column (renamed or added since it ran)")
        for x in sorted(got - set(ids)):
            coverage.append(f"column row `{x}` ({fam}) is not in the corpus at this commit (renamed or removed since)")
    return heads, rows, recount, divs, coverage


def read_script(runs, sv):
    tera, divs = {}, []
    for corpus, (run, manifests) in sorted(runs.items()):
        t = {}
        for m in manifests:
            mv = load(m)
            for path, c in mv["counts"].items():
                acc = t.setdefault(path, {})
                for k, n in c.items():
                    acc[k] = acc.get(k, 0) + n
            if mv["counts"].get("block", {}).get("disagreeing", 0) or mv["counts"].get("mempool", {}).get("disagreeing", 0):
                divs.append({
                    # keyed by the chunk's name, never the run directory: the same witness matches across releases
                    "key": f"script:{corpus}:{os.path.basename(m)}", "source": "script column", "row": "script-verdict",
                    "row_kind": None, "id": f"{corpus} ({rel(m)})",
                    "reference": "the corpus's recorded verdict",
                    "teranode": "disagreeing " + ", ".join(f"{p} {c.get('disagreeing', 0)}" for p, c in mv["counts"].items()),
                    "class": "open", "detail": "a script-column witness, unclassified",
                    "citation": f"the run's witnesses.jsonl, sha256 {mv.get('artifacts_sha256', {}).get('witnesses.jsonl', 'unknown')}",
                    "ruling": "none yet: the classifier is S3's data (D83); open", "reference_record": rel(m)})
        cps = {(load(m)["corpus"]["path"], load(m)["corpus"]["sha256"]) for m in manifests}
        moved = []
        for path, h in sorted(cps):
            now = sha256(path) if os.path.exists(os.path.join(ROOT, path)) else "absent"
            if now != h:
                moved.append(f"{path} moved since the run ({h[:12]} then, {now[:12]} now)")
        commits = sorted({(load(m).get("instance") or {}).get("commit") or "unknown" for m in manifests})
        tera[corpus] = {"run": run, "manifests": manifests, "paths": t, "corpus_moved": moved, "instance_commits": commits}
    ref = {}
    for corpus, e in sorted(sv.items()):
        ref[corpus] = {"entries": e.get("entries"), "agree": e.get("agree", {}), "witnesses": e.get("witnesses", 0),
                       "node": e.get("node")}
    return tera, ref, divs


def list_divergences(obl, gate):
    out = []
    for d in obl["divergences"]:
        rows = [r["row"] for r in obl["rows"] if d["id"] in r.get("divergences", [])]
        legs = "; ".join(f"{w['rows']}: {w['record']} ({w['lane']}, {w['issue']}; {w['counts']})" for w in d["witnesses"])
        out.append({
            "key": f"list:{d['id']}", "source": "the obligation list", "row": ", ".join(rows),
            "row_kind": d["class"], "id": d["id"],
            "reference": "the leg's row, named: " + legs,
            "teranode": "the same leg's row (its record withheld by name; the counts are the public ones)",
            "class": d["class"], "detail": f"{d['label']}, {d['issue']}",
            "citation": d["reason"], "ruling": gate["rulings"].get(d["id"], "none named in " + GATE_RULES),
            "reference_record": "",
        })
    return out


def ledger_words(absences):
    return {r["id"]: r for r in absences["rows"]}


# ---------------------------------------------------------------- the report
def build(a, stamp):
    gate = load(GATE_RULES)
    obl = load(a.obligations)
    if set(obl["kinds"]) != set(KINDS):
        raise Stop(1, f"{a.obligations}: its kinds {sorted(obl['kinds'])} are not the gate's {sorted(KINDS)}")
    absences = load(ABSENCES)
    classes = load(SCENARIO_RULES)["classes"]
    obl_rows = {r["row"]: r for r in obl["rows"]}
    kind_counts = {k: sum(1 for r in obl["rows"] if r["kind"] == k) for k in KINDS}
    for k in KINDS:
        if kind_counts[k] != obl["counts"][k]:
            raise Stop(1, f"{a.obligations}: kind {k} counted {kind_counts[k]} from its rows, {obl['counts'][k]} in its counts")
    if len(obl["rows"]) != obl["counts"]["rows"]:
        raise Stop(1, f"{a.obligations}: {len(obl['rows'])} rows, {obl['counts']['rows']} in its counts")
    since = a.since if a.live else ""
    scen_paths = a.scenario or newest_scenario(since)
    partials = newer_partials(scen_paths, since)
    runs = teranode_script_runs(since, a.script_runs)
    list_class = {x["id"]: x["class"] for x in obl["divergences"]}
    heads, scen_rows, scen_counts, scen_divs, coverage = read_scenarios(scen_paths, gate, classes, obl_rows, list_class)
    tera, ref, script_divs = read_script(runs, load(SV_MANIFEST))
    ref_fams = reference_column(since, a.reference)
    col = sorted(p for p in glob.glob(os.path.join(RECORDS, "*-column-sv-node-*-s3.json")) if stamp_of(p) >= since)
    sv_column = {"record": rel(col[-1]), "verdict": load(col[-1]).get("verdict")} if col else None
    ref_counts = read_reference(ref_fams)
    divs = list_divergences(obl, gate) + scen_divs + script_divs
    for d in divs:
        if d["class"] not in KINDS:
            raise Stop(1, f"divergence {d['key']}: class {d['class']} is outside the list's vocabulary")
    per_row = {}
    for r in scen_rows:
        c = per_row.setdefault(r["row"], {})
        c[r["verdict"]] = c.get(r["verdict"], 0) + 1
    sources = [a.obligations, ABSENCES, GATE_RULES, SCENARIO_RULES, *scen_paths, *sorted(set(ref_fams.values())), SV_MANIFEST]
    sources += sorted({m for t in tera.values() for m in t["manifests"]})
    if sv_column:
        sources.append(sv_column["record"])
    prev_path, prev_mode, prev_note = previous_record(stamp, a.previous, a.live)
    data = {
        "gate": "#95", "stamp": stamp, "mode": "dry-run" if a.dry_run else "live", "pins": pins(),
        "commit": git_head(), "host": socket.gethostname().split(".")[0],
        "sources": {s: sha256(s) for s in sources},
        "scenario": {"records": scen_paths, "run_ids": [h.get("run_id") for h in heads],
                     "base_commits": sorted({(h.get("base_commit") or "")[:8] for h in heads}),
                     "instance_pins": sorted({(h.get("instance") or {}).get("pin") or "unknown" for h in heads}),
                     "counts": scen_counts, "coverage": coverage, "reference": ref_counts,
                     "newer_not_read": [{"record": x, "kind": k, "rows": ids} for x, k, ids in partials]},
        "script": {"teranode": tera, "reference": ref, "reference_column": sv_column},
        "obligations": {"counts": kind_counts, "rows": {r["row"]: {"kind": r["kind"], "label": r["label"],
                                                                     "rerun": r["rerun"]} for r in obl["rows"]}},
        "divergences": divs,
        "previous": prev_path, "previous_mode": prev_mode, "previous_note": prev_note,
    }
    data["delta"] = delta(load(prev_path) if prev_path else None, data)
    md = render(data, obl, obl_rows, per_row, ledger_words(absences), gate)
    return data, md


def git_head():
    try:
        return subprocess.run(["git", "-C", ROOT, "rev-parse", "--short=8", "HEAD"], capture_output=True, text=True,
                              check=True).stdout.strip()
    except (OSError, subprocess.CalledProcessError):
        return "unknown"


def delta(prev, cur):
    """The lines that moved since the previous gate record: pins, obligation kinds, divergences by key."""
    if prev is None:
        return ["no previous gate record under docs/records: this record is the baseline"]
    lines = []
    for side in ("reference", "teranode"):
        a, b = prev["pins"][side], cur["pins"][side]
        if (a["tag"], a["commit"]) != (b["tag"], b["commit"]):
            lines.append(f"pin moved: {b['name']} {a['tag']} ({a['commit'][:8]}) -> {b['tag']} ({b['commit'][:8]})")
    pr, cr = prev["obligations"]["rows"], cur["obligations"]["rows"]
    for row in sorted(set(pr) | set(cr)):
        if row not in cr:
            lines.append(f"obligation row gone: {row} (was {pr[row]['kind']})")
        elif row not in pr:
            lines.append(f"obligation row new: {row} ({cr[row]['kind']})")
        elif pr[row]["kind"] != cr[row]["kind"]:
            lines.append(f"obligation row moved kind: {row}: {pr[row]['kind']} -> {cr[row]['kind']}")
    pd = {d["key"]: d for d in prev["divergences"]}
    cd = {d["key"]: d for d in cur["divergences"]}
    for k in sorted(set(pd) | set(cd)):
        if k not in pd:
            lines.append(f"new divergence: {k} ({cd[k]['class']}; {cd[k]['detail']}; obligation row {cd[k]['row']})")
        elif k not in cd:
            lines.append(f"resolved: {k} (was {pd[k]['class']}; {pd[k]['detail']}): no longer a divergence in this record's sources")
        else:
            for f, word in (("class", "moved class"), ("detail", "moved class detail"), ("row", "moved obligation row")):
                if pd[k][f] != cd[k][f]:
                    lines.append(f"{word}: {k}: {pd[k][f]} -> {cd[k][f]}")
    for fam in sorted(set(prev["scenario"]["counts"]) | set(cur["scenario"]["counts"])):
        a, b = prev["scenario"]["counts"].get(fam, {}), cur["scenario"]["counts"].get(fam, {})
        moved = [f"{k} {a.get(k, 0)} -> {b.get(k, 0)}" for k in ["rows"] + VERDICTS if a.get(k, 0) != b.get(k, 0)]
        if moved:
            lines.append(f"scenario family {fam}: " + ", ".join(moved))
    return lines or [f"nothing moved since {os.path.basename(cur['previous'])}"]


def cell(text):
    return str(text).replace("|", "\\|").replace("\n", " ")


def render(d, obl, obl_rows, per_row, ledger, gate):
    p = d["pins"]
    sc = d["scenario"]
    srcs = (list(sc["records"]) + sorted({c["record"] for c in sc["reference"].values()})
            + sorted({t["run"] for t in d["script"]["teranode"].values()}) + [SV_MANIFEST, OBLIGATIONS])
    L = [f"# The Teranode gate (#95): Teranode {p['teranode']['tag']} against bitcoin-sv {p['reference']['tag']}", ""]
    when = f"{d['stamp'][:4]}-{d['stamp'][4:6]}-{d['stamp'][6:8]} {d['stamp'][9:11]}:{d['stamp'][11:13]} UTC"
    if d["mode"] == "dry-run":
        L.append(f"[M] {when}, `tools/teranode_gate.py --dry-run` at `{d['commit']}`: **dry run from the records of "
                 + ", ".join(f"`{s}`" for s in srcs) + "**. No node was started and nothing was measured by this run: "
                 "every count below is the named records' own, re-added from their rows and checked equal to their "
                 "own totals; this page claims no live run.")
    else:
        L.append(f"[M] {when}, `make teranode-gate` at `{d['commit']}`: a live run on `{d.get('host', 'unknown')}`; "
                 f"Teranode `{p['teranode']['tag']}` (`{p['teranode']['commit'][:8]}`) against bitcoin-sv "
                 f"`{p['reference']['tag']}` (`{p['reference']['commit'][:8]}`); "
                 "its measuring steps wrote the records "
                 + ", ".join(f"`{s}`" for s in srcs) + " (each step's own record names its instance and its commands).")
    L += ["", "The report cites rulings and makes none (CLAUDE.md rule 15). Its vocabulary is #88's obligation list's, "
          "six kinds: " + "; ".join(f"`{k}`, {obl['kinds'][k]}" for k in KINDS) + ". A difference no ruling names is "
          "`open`. Every difference is read against Teranode's north star, scale without a protocol change (the "
          "owner's framing rule, card Z8): a design row is an architecture decision with its reason cited, its "
          "divergence policy (the row keeps its rule's label); only the same blocks decided differently is a chain "
          "split.", ""]
    L += ["## The pins", "", "| side | tag | commit |", "|---|---|---|"]
    for side in ("teranode", "reference"):
        L.append(f"| {p[side]['name']} | `{p[side]['tag']}` | `{p[side]['commit']}` |")
    L += ["", "From `docs/PROVENANCE.md` section 1a. The scenario column's instance pin: "
          + ", ".join(f"`{x}`" for x in sc["instance_pins"]) + " (run " + ", ".join(f"`{x}`" for x in sc["run_ids"])
          + "; runner at " + ", ".join(f"`{x}`" for x in sc["base_commits"]) + ").", ""]
    if any(x != p["teranode"]["commit"] for x in sc["instance_pins"]):
        L += ["**The scenario column's instance is not at the Teranode pin above**: its rows are not this pin's.", ""]
    # the counts
    L += ["## The counts", "", "### The scenario corpus (#66), both oracles", "",
          "From " + ", ".join(f"`{x}`" for x in sc["records"]) + " (Teranode's verdict per row; the reference's verdict is each row's `reference_token`, "
          "the corpus's recorded measurement with its record).", "",
          "| family | rows | " + " | ".join(VERDICTS) + " |", "|---|" + "---|" * (len(VERDICTS) + 1)]
    tot = {k: 0 for k in ["rows"] + VERDICTS}
    for fam, c in sorted(sc["counts"].items()):
        L.append(f"| {fam} | {c['rows']} | " + " | ".join(str(c.get(k, 0)) for k in VERDICTS) + " |")
        for k in tot:
            tot[k] += c.get(k, 0)
    L.append(f"| **all** | **{tot['rows']}** | " + " | ".join(f"**{tot[k]}**" for k in VERDICTS) + " |")
    L += ["", "The column's row ids against the scenario corpus at this commit (`corpus/chain/<family>/<family>.jsonl`): "
          + ("every row once." if not sc["coverage"] else "; ".join(sc["coverage"]) + ".")]
    for kind in ("partial", "whole"):
        newer = [x for x in sc.get("newer_not_read", []) if x["kind"] == kind]
        if newer:
            L += ["", f"Newer {kind} column records not read: " + "; ".join(
                f"`{x['record']}` ({len(x['rows'])} rows"
                + (": " + ", ".join(f"`{i}`" for i in x["rows"]) if kind == "partial" else "") + ")"
                for x in newer) + ". A row this table counts may have been re-measured there; "
                "`--scenario` names the chunks of record."]
    L += ["", "The reference's own scenario column (run_scenarios on fresh regtest instances of the reference pin, each "
          "row against the spec's expected verdict):", "",
          "| family | record | version | rows | " + " | ".join(VERDICTS) + " |", "|---|---|---|---|" + "---|" * len(VERDICTS)]
    rt = {k: 0 for k in ["rows"] + VERDICTS}
    for fam, c in sorted(sc["reference"].items()):
        L.append(f"| {fam} | `{os.path.basename(c['record'])}` | {c['version']} | {c['rows']} | "
                 + " | ".join(str(c.get(k, 0)) for k in VERDICTS) + " |")
        for k in rt:
            rt[k] += c.get(k, 0)
    L.append(f"| **all** | | | **{rt['rows']}** | " + " | ".join(f"**{rt[k]}**" for k in VERDICTS) + " |")
    off = [f for f, c in sc["reference"].items() if p["reference"]["commit"][:9] not in (c["version"] or "")]
    if off:
        L += ["", "**The reference column's families " + ", ".join(off) + " report a version without the reference "
              "pin's commit**: their rows are not this pin's."]
    L += ["", "### The script corpus, Teranode (run_teranode, harness/engines/instance41; runs since 2026-10-15 read "
          "through the observation contract of #97)", "",
          "| corpus | run | path | entries | judged | agreeing | disagreeing | unfundable | undecided |",
          "|---|---|---|---|---|---|---|---|---|"]
    for corpus, t in sorted(d["script"]["teranode"].items()):
        for path, c in sorted(t["paths"].items()):
            L.append(f"| `{corpus}` | `{os.path.basename(t['run'])}` | {path} | {c.get('entries', 0)} | {c.get('judged', 0)} | "
                     f"{c.get('agreeing', 0)} | {c.get('disagreeing', 0)} | {c.get('unfundable', 0)} | {c.get('undecided', 0)} |")
    moved = [x for t in d["script"]["teranode"].values() for x in t["corpus_moved"]]
    off = sorted(c for c, t in d["script"]["teranode"].items() if t["instance_commits"] != [p["teranode"]["commit"]])
    if off:
        L += ["", "**The Teranode script runs of " + ", ".join(f"`{c}`" for c in off) + " name an instance commit other "
              "than the Teranode pin**: their rows are not this pin's."]
    L += ["", "Teranode's verdicts are compared with each corpus's recorded reference verdicts (the keys the run read); "
          "an entry the instance cannot fund or decide is counted, never judged. The corpora against their bytes at "
          "the run (each manifest's `corpus.sha256`): " + ("every corpus the same bytes." if not moved else
                                                           "; ".join(moved) + ": these corpora's rows are this run's "
                                                           "rows, never the corpus's rows now; the re-run is owed."), "",
          "### The script corpus, the reference (the committed column, `corpus/witnesses/sv-node/manifest.json`)", "",
          "| corpus | entries | agree (block word) | agree (mempool word) | witnesses | node |", "|---|---|---|---|---|---|"]
    for corpus, r in sorted(d["script"]["reference"].items()):
        ag = r["agree"]
        L.append(f"| `{corpus}` | {r['entries']} | {ag.get('spec', '')} | {ag.get('spec-mempool', '')} | {r['witnesses']} | `{r['node']}` |")
    sv_col = d["script"]["reference_column"]
    L += ["", "The reference's witnesses are the spec's own report against the reference (#30), each under its cited "
          "class; the gate carries their count and never re-rules them. The column's re-run at the pin "
          "(`make column IMPL=sv-node PIN=<reference tag>`): "
          + (f"`{sv_col['record']}`, its verdict line `{sv_col['verdict']}`." if sv_col else
             "no `*-column-sv-node-*` record on disk" + (" since the run's start" if d["mode"] == "live" else "")
             + "; the counts above are the committed manifest's."), ""]
    oc = d["obligations"]["counts"]
    rerun = [r for r in obl["rows"] if r["rerun"]]
    L += ["### The obligation list (#88)", "",
          f"{len(obl['rows'])} rows: " + ", ".join(f"{oc[k]} {k}" for k in KINDS)
          + f"; {len(rerun)} rows marked `rerun` (" + ", ".join(f"{sum(1 for r in rerun if r['kind'] == k)} {k}" for k in KINDS
                                                         if any(r['kind'] == k for r in rerun)) + ").", "",
          "| row | kind | label | rerun | the scenario column on it | its legs (records named, never opened here) |",
          "|---|---|---|---|---|---|"]
    for r in obl["rows"]:
        c = per_row.get(r["row"], {})
        col = ", ".join(f"{k} {c[k]}" for k in VERDICTS if c.get(k)) or "no row"
        legs = "; ".join(f"{g['issue']} `{os.path.basename(g['record'])}`: {g['counts']}" for g in r["legs"]) or ""
        L.append(f"| `{r['row']}` | {r['kind']} | {r['label']} | {'yes' if r['rerun'] else ''} | {cell(col)} | {cell(legs)} |")
    unmeasured = [r["row"] for r in rerun
                  if not any(per_row.get(r["row"], {}).get(k) for k in ("agree", "diverge", "non-judging")) and not r["legs"]]
    if unmeasured:
        L += ["", "Rows marked `rerun` with no judged scenario row and no leg (not re-measured by this gate): "
              + ", ".join(f"`{x}`" for x in unmeasured) + "."]
    L += ["", "How the gate applies the list: a `report` row is judged by the scenario column's rows on it (the index "
          f"`{GATE_RULES}`, `scenario_rows`, the lane's reading [D]); a row a leg measured is carried with its leg's "
          "public counts, and its re-measure at a release is its leg's runner, named by the leg's record; a `theorem` "
          "row is cited by its names, not re-run; a `design` row is carried with its reason; an `open` row is listed "
          "as open.", ""]
    # the divergences
    L += ["## Every divergence, a witness row", "",
          "| key | obligation row (kind) | the reference | Teranode | class | the class's detail | citation | the ruling's source |",
          "|---|---|---|---|---|---|---|---|"]
    for v in d["divergences"]:
        L.append(f"| `{v['key']}` | {cell(v['row'])} ({v['row_kind'] or 'n/a'}) | {cell(v['reference'])} | {cell(v['teranode'])} | "
                 f"**{v['class']}** | {cell(v['detail'])} | {cell(v['citation'])} | {cell(v['ruling'])} |")
    by = {}
    for v in d["divergences"]:
        by[(v["source"], v["class"])] = by.get((v["source"], v["class"]), 0) + 1
    L += ["", f"{len(d['divergences'])} divergences: " + "; ".join(f"{n} {c} from {s}" for (s, c), n in sorted(by.items())) + ".", ""]
    # the carried rows
    L += ["## The rows carried", "", "### Design and chain-split rows, with their reasons", ""]
    divs = {x["id"]: x for x in obl["divergences"]}
    for r in obl["rows"]:
        if r["kind"] not in ("design", "chain-split"):
            continue
        parts = [f"`{x}`: {divs[x]['reason']}" for x in r["divergences"]]
        for lg in r["ledger"]:
            row = ledger.get(lg["id"], {})
            why = (row.get("design") or {}).get("reason") or (row.get("ruling") or {}).get("reason", "")
            parts.append(f"ledger `{lg['id']}`, `{lg['word']}`: {why}")
        L.append(f"- `{r['row']}` ({r['kind']}, {r['label']}, {r['issue']}): " + " ".join(parts)
                 + f" Ruling: {gate['ledger_ruling'] if r['ledger'] else ''}"
                 + ("; " if r['ledger'] and r['divergences'] else "")
                 + "; ".join(gate["rulings"].get(x, "") for x in r["divergences"]) + ".")
    L += ["", "### Theorem and witness rows, cited (not re-run)", ""]
    for r in obl["rows"]:
        if r["kind"] in ("theorem", "witness"):
            names = ", ".join(f"`{n.split('.')[-1]}`" for n in r["names"]) or "its leg " + "; ".join(
                f"{g['issue']} `{os.path.basename(g['record'])}` ({g['counts']})" for g in r["legs"])
            L.append(f"- `{r['row']}` ({r['kind']}, {r['label']}, {r['issue']}): {names}"
                     + (f"; premises: {r['premises']}" if r["premises"] else "") + ".")
    L += ["", "### Open rows", ""]
    for r in obl["rows"]:
        if r["kind"] == "open":
            extra = gate.get("open_ruling", {}).get(r["row"])
            L.append(f"- `{r['row']}` ({r['label']}, {r['issue']}; owner {r['owner']}): {r['statement'] or 'stated, not discharged'}"
                     + (f" Ruling: {extra}." if extra else ""))
    L += ["", "## The delta", ""]
    if d["previous"]:
        what = {"dry-run": "a dry run", "live": "a live run"}.get(d.get("previous_mode"), "a record of unknown mode")
        L.append(f"Against `{d['previous']}` ({what})" + (f"; {d['previous_note']}" if d.get("previous_note") else "") + ":")
    else:
        L.append("Against no previous record:")
    L += [""] + [f"- {x}" for x in d["delta"]]
    L += ["", "## The sources", "", "| file | sha256 |", "|---|---|"]
    L += [f"| `{s}` | `{h}` |" for s, h in sorted(d["sources"].items())]
    L += ["", f"The record's data: `docs/records/{d['stamp']}{GATE_SUFFIX}.json` (the next gate's delta reads it). "
          "This page carries verdict words and codes, classes, row ids, hashes and counts; the nodes' own text is in the "
          f"steps' raw log `docs/records/<SINCE>{LOG_SUFFIX}`, withheld from the public edition "
          "(tools/export_withheld.txt, group hz-95-teranode-gate-logs).",
          "", f"teranode gate: {d['mode']} written: {len(obl['rows'])} obligation rows, {tot['rows']} scenario rows, "
          f"{len(d['divergences'])} divergences, {len(d['delta'])} delta lines"]
    return "\n".join(L) + "\n"


def refuse_words(md):
    bad = [(i + 1, m.group(0)) for i, line in enumerate(md.splitlines()) for m in REFUSED.finditer(line)]
    if bad:
        raise Stop(1, "the report carries words CLAUDE.md rule 13 refuses: "
                      + ", ".join(f"line {n} `{w}`" for n, w in bad[:10]))


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    mode = ap.add_mutually_exclusive_group(required=True)
    mode.add_argument("--chunks", nargs="?", type=int, const=0, help="print the scenario column's chunks and exit")
    mode.add_argument("--dry-run", action="store_true", help="build the report from the records on disk; start nothing")
    mode.add_argument("--live", action="store_true", help="read only the records written since --since")
    ap.add_argument("--since", default="", help="YYYYmmdd-HHMMSS: with --live, the measuring steps' start")
    ap.add_argument("--scenario", nargs="+", help="the scenario column's JSON, or its chunks (default: the newest whole column)")
    ap.add_argument("--reference", nargs="+", help="the reference's scenario column JSONs (default: the newest per family)")
    ap.add_argument("--script-runs", nargs="*", help="Teranode run directories to read (default: the newest per corpus)")
    ap.add_argument("--obligations", default=OBLIGATIONS)
    ap.add_argument("--previous", help="the previous gate record's JSON, or `none` (default: the newest older one)")
    ap.add_argument("--out-dir", default=RECORDS)
    ap.add_argument("--stamp", default=datetime.datetime.now(datetime.timezone.utc).strftime("%Y%m%d-%H%M%S"))
    a = ap.parse_args(argv)
    if a.chunks is not None:
        try:
            whole, wall, cs = chunks(a.chunks or None)
        except Stop as e:
            print(f"teranode gate: STOP ({e.code}): {e}", file=sys.stderr)
            return e.code
        print(f"# {len(cs)} chunks over every corpus row once; the realizable rows by `{whole}` "
              + (f"(wall {wall['value']:.1f} s whole)" if wall else "(its wall unrecorded)")
              + f", about {CHUNK_SECONDS} s a chunk")
        for n, ids in cs:
            print(f"ORACLE_ROWS={','.join(ids)}  # {len(ids)} rows, {n} realizable")
        return 0
    try:
        if a.live and not re.fullmatch(r"\d{8}-\d{6}", a.since):
            raise Stop(2, "--live needs --since YYYYmmdd-HHMMSS (the measuring steps' start)")
        data, md = build(a, a.stamp)
        refuse_words(md)
    except Stop as e:
        print(f"teranode gate: STOP ({e.code}): {e}", file=sys.stderr)
        return e.code
    os.makedirs(a.out_dir, exist_ok=True)
    base = os.path.join(a.out_dir, f"{a.stamp}{GATE_SUFFIX}")
    with open(base + ".md", "w", encoding="utf-8") as f:
        f.write(md)
    with open(base + ".json", "w", encoding="utf-8") as f:
        json.dump(data, f, indent=1, sort_keys=True)
        f.write("\n")
    print(f"record: {base}.md")
    for line in data["delta"]:
        print(f"  delta: {line}")
    print(md.rstrip().splitlines()[-1])
    return 0


if __name__ == "__main__":
    sys.exit(main())
