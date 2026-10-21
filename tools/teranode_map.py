#!/usr/bin/env python3
"""tools/teranode_map.py: the module map of #87 (S8), `spec/teranode-map.md` generated from `corpus/teranode/map.json`.

Written 2026-10-14. The table is the source; this file renders it, refuses a malformed row, and
resolves every citation at the two pins. #17's pattern: the page is never edited by hand, and `tools/specgen.py`
imports `render()` so the spec leg's byte-identity check (`specgen.py --check`) covers this page with the others.

Usage:
  tools/teranode_map.py            write spec/teranode-map.md (the same bytes `make spec` writes)
  tools/teranode_map.py --check    exit 1 when spec/teranode-map.md differs from a regeneration
  tools/teranode_map.py --verify   resolve every citation at the pins of docs/PROVENANCE.md section 1a with
                                   `git show <commit>:<path>` (never a working tree): the lines exist and the row's
                                   anchor occurs in them; every Lean name is declared in its file; the table's pins
                                   equal section 1a's. A clone absent here (the Modal container) is SKIPPED BY NAME and
                                   counted, never a pass; TERANODE_MAP_REQUIRE_CLONES=1 turns a skip into RED. The cite
                                   leg of tools/check.sh runs it.

The row keys are documented in the table's own `about` lines: the keys of record, which the absence ledger (#96) uses.
"""
import json
import os
import re
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TABLE = os.path.join(ROOT, "corpus", "teranode", "map.json")
PAGE = os.path.join(ROOT, "spec", "teranode-map.md")

KEYS = {"id", "layer", "rule", "lean", "reference", "teranode", "mechanism", "obligation", "note", "ledger"}
REQUIRED_KEYS = KEYS - {"ledger"}
MECHANISMS = ("same", "different", "absent")
OBLIGATIONS = {
    "#88": "the refinement relation",
    "#89": "subtree merkle equivalence",
    "#90": "spend order and conflicts",
    "#91": "the sentinel height and the flag word",
    "#92": "record lifetimes",
    "#93": "chain selection and reorg",
    "#94": "the alert system",
    "#95": "the per-release divergence report",
    "#96": "the absence ledger",
    "#97": "the observation contract",
    "#98": "the legacy bridge",
}
# the rows the issue names (#87's deliverable) and the S7 surfaces the issue's brief names, each with the ids that carry it
REQUIRED_ROWS = [
    ("transaction validation", ["tx-receive", "tx-gate"]),
    ("script word selection", ["script-word"]),
    ("UTXO spend", ["utxo-spend"]),
    ("conflicts", ["conflicts"]),
    ("unmined lifetime", ["unmined-lifetime"]),
    ("block structure", ["block-structure"]),
    ("merkle root", ["merkle-root"]),
    ("block validation", ["block-check", "block-connect"]),
    ("chain selection", ["chain-selection"]),
    ("reorg", ["reorg"]),
    ("difficulty", ["difficulty"]),
    ("invalidation", ["invalidation"]),
    ("freeze and confiscation", ["freeze-confiscation"]),
    ("relay", ["tx-relay"]),
    ("event surface", ["event-surface"]),
    ("observation surface", ["observation-rpc"]),
    ("pruning and persistence", ["pruning", "pool-persistence", "block-persistence"]),
    ("miner ID (S7)", ["miner-id"]),
    ("wire formats (S7)", ["wire-tx", "wire-block"]),
]
ID = re.compile(r"^[a-z0-9]+(?:-[a-z0-9]+)*$")
DECL = re.compile(r"^\s*(?:@\[[^\]]*\]\s*)?(?:private\s+|protected\s+|noncomputable\s+|partial\s+|unsafe\s+)*"
                  r"(?:def|abbrev|structure|inductive|theorem|class|opaque)\s+([\w.']+)")
# a `file:line` or `file:from-to` in a note: it must be one of the row's citations, so --verify resolves it at the pin
NOTE_REF = re.compile(r"([\w./]+\.(?:go|cpp|h)):(\d+)(?:-(\d+))?")


def load():
    with open(TABLE) as f:
        table = json.load(f)
    errors = []
    rows = table.get("rows", [])
    seen = set()
    for i, r in enumerate(rows):
        where = r.get("id", f"row {i}")
        extra, missing = set(r) - KEYS, REQUIRED_KEYS - set(r)
        if extra or missing:
            errors.append(f"{where}: keys {sorted(extra)} not in the schema, {sorted(missing)} missing")
            continue
        if not ID.match(r["id"]) or r["id"] in seen:
            errors.append(f"{where}: the id is not kebab-case or not unique")
        seen.add(r["id"])
        if r["layer"] not in ("S6", "S7"):
            errors.append(f"{where}: layer {r['layer']!r}")
        if r["mechanism"] not in MECHANISMS:
            errors.append(f"{where}: mechanism {r['mechanism']!r}")
        if r["obligation"] not in OBLIGATIONS:
            errors.append(f"{where}: obligation {r['obligation']!r} is not one of #88 to #98")
        absent = [side for side in ("reference", "teranode") if r[side].get("absent")]
        if len(absent) > 1 or (r["mechanism"] == "absent") != (len(absent) == 1):
            errors.append(f"{where}: mechanism {r['mechanism']} with absent sides {absent}")
        if r["mechanism"] == "absent" and r["obligation"] != "#96":
            errors.append(f"{where}: an absent row is the ledger's (#96)")
        for side in ("reference", "teranode"):
            cell = r[side]
            if cell.get("absent") and not cell.get("where"):
                errors.append(f"{where}: {side} absent without `where`")
            if not cell.get("absent") and not cell.get("function"):
                errors.append(f"{where}: {side} without `function`")
            if side == "teranode" and not cell.get("service"):
                errors.append(f"{where}: teranode without `service`")
            cites = cell.get("cites") or []
            if not cites:
                errors.append(f"{where}: {side} carries no citation")
            for c in cites:
                lines = c.get("lines")
                if set(c) != {"file", "lines", "anchor"} or not (isinstance(lines, list) and len(lines) == 2
                                                                  and 1 <= lines[0] <= lines[1]) or not c["anchor"]:
                    errors.append(f"{where}: {side} citation {c} is malformed")
        for d in r["lean"]:
            if set(d) != {"name", "file"} or not d["file"].startswith("lean/"):
                errors.append(f"{where}: Lean entry {d} is malformed")
        free = [r["rule"], r["note"]] + [r[s].get(k, "") for s in ("reference", "teranode")
                                         for k in ("function", "where", "service")]
        for text in free:
            if "\n" in text or "\u2014" in text or "|" in text:
                errors.append(f"{where}: {text[:40]!r}: free text must be one line, with no long dash and no table bar")
        row_cites = [c for s in ("reference", "teranode") for c in r[s].get("cites") or []]
        for m in NOTE_REF.finditer(r["note"]):
            a = int(m.group(2))
            b = int(m.group(3) or a)
            if not any(c.get("file", "").endswith(m.group(1)) and c.get("lines") == [a, b] for c in row_cites):
                errors.append(f"{where}: the note's {m.group(0)} is not one of the row's citations (--verify would not resolve it)")
    for name, ids in REQUIRED_ROWS:
        for i in ids:
            if i not in seen:
                errors.append(f"the issue's row {name!r} wants id {i!r}, absent from the table")
    if errors:
        raise SystemExit("teranode_map: the table is refused:\n  " + "\n  ".join(errors))
    return table


def cite(c):
    a, b = c["lines"]
    span = f"{a}" if a == b else f"{a}-{b}"
    return f"`{c['file']}:{span}` ({c['anchor']})"


def cell(side):
    cites = "; ".join(cite(c) for c in side["cites"])
    if side.get("absent"):
        svc = f" in `{side['service']}`" if side.get("service") else ""
        return f"**absent**{svc}: {side['where']}; where it would be: {cites}"
    svc = f"`{side['service']}`: " if side.get("service") else ""
    return f"{svc}{side['function']}; {cites}"


def render(table=None):
    t = table or load()
    rows = t["rows"]
    pr, pt = t["pins"]["reference"], t["pins"]["teranode"]
    by_mech = {m: sum(1 for r in rows if r["mechanism"] == m) for m in MECHANISMS}
    by_layer = {l: sum(1 for r in rows if r["layer"] == l) for l in ("S6", "S7")}
    absent_t = sum(1 for r in rows if r["teranode"].get("absent"))
    absent_r = sum(1 for r in rows if r["reference"].get("absent"))
    n_cites = sum(len(r[s]["cites"]) for r in rows for s in ("reference", "teranode"))
    by_obl = {o: [r["id"] for r in rows if r["obligation"] == o] for o in OBLIGATIONS}
    out = [
        "# The module map: every S6 and S7 rule against Teranode (#87)",
        "",
        f"**Generated by `tools/teranode_map.py` from `corpus/teranode/map.json`; never edited by hand** (`make spec` "
        f"writes it with the other pages and the spec leg refuses a stale copy; `tools/teranode_map.py --verify` resolves "
        f"every citation at the pins in the cite leg). [D] {t['date']}.",
        "",
        f"The pins `[SRC]`: the reference is {pr['name']} {pr['tag']} `{pr['commit'][:8]}`; Teranode is {pt['tag']} "
        f"`{pt['commit'][:8]}` (`docs/PROVENANCE.md` section 1a). Every citation names a file and lines at its pin and "
        f"the text the verifier finds there. A reference citation reads bitcoin-sv's tree; a Teranode citation reads "
        f"Teranode's.",
        "",
        "**The mechanism column is a reading `[D]`, never a measurement.** `same`: the same decision procedure over the "
        "same inputs, read at the two tags; `different`: another structure, stage, trigger or trust root implements the "
        "rule; `absent`: one side has no implementation at its tag, and the absent cell cites where it would be. Each row "
        "points at exactly one obligation: the refinement relation (#88) discharges it by a theorem or a witness scenario "
        "of #66; a `same` row is judged by the per-release divergence report (#95); an `absent` row is ruled in the "
        "absence ledger (#96). Policy stays policy: a row about a node's setting names it so (rule 1).",
        "",
        f"Counts [M]: {len(rows)} rows ({by_layer['S6']} S6, {by_layer['S7']} S7); {by_mech['same']} same, "
        f"{by_mech['different']} different, {by_mech['absent']} absent ({absent_t} absent in Teranode, {absent_r} absent "
        f"in the reference); {n_cites} citations.",
        "",
        "## The issue's rows",
        "",
        "| the issue names | the rows |",
        "|---|---|",
    ]
    for name, ids in REQUIRED_ROWS:
        out.append(f"| {name} | " + ", ".join(f"[`{i}`](#{i})" for i in ids) + " |")
    out += ["", "## The obligations", "", "| issue | what discharges the row | rows |", "|---|---|---|"]
    for o, what in OBLIGATIONS.items():
        ids = by_obl[o]
        out.append(f"| {o} | {what} | " + (", ".join(f"`{i}`" for i in ids) if ids else "none") + " |")
    for layer, title in (("S6", "S6: the transaction state machine"), ("S7", "S7: the node beyond the chain")):
        out += ["", f"## {title}", "",
                "| row | rule | Lean | reference `[SRC]` | Teranode `[SRC]` | mechanism `[D]` | obligation | note |",
                "|---|---|---|---|---|---|---|---|"]
        for r in rows:
            if r["layer"] != layer:
                continue
            lean = ", ".join(f"`{d['name']}`" for d in r["lean"]) or "none yet"
            out.append(f"| <a id=\"{r['id']}\"></a>`{r['id']}` | {r['rule']} | {lean} | {cell(r['reference'])} | "
                       f"{cell(r['teranode'])} | {r['mechanism']} | {r['obligation']} | {r['note']} |")
    return "\n".join(out) + "\n"


def provenance_pins():
    """docs/PROVENANCE.md section 1a through the cite leg's own reader (its fenced `pins` block, a `$NAME` clone resolved
    by tools/host_private.sh), so this check finds the clones where tools/cite_check.py finds them on every host."""
    sys.path.insert(0, os.path.join(ROOT, "tools"))
    import cite_check
    flat = cite_check.pins()
    out = {}
    for side in ("reference", "teranode"):
        out[side] = {k: flat.get(f"{side}.{k}") for k in ("commit", "tag")}
        out[side]["clone"] = cite_check.host_path(flat.get(f"{side}.clone", ""))
    return out


def declared(src):
    """The full names a Lean file declares: each declaration's name under the `namespace ... end` blocks open at its line
    (a `section` or a `mutual` opens a block that adds no component), so `A.B.f` passes only when `f` is declared inside `A.B`."""
    names, stack = set(), []
    for line in src.split("\n"):
        m = re.match(r"^\s*(namespace|section|mutual)\b\s*(\S*)", line)
        if m:
            stack.append(m.group(2) if m.group(1) == "namespace" else "")
            continue
        if re.match(r"^\s*end\b", line) and stack:
            stack.pop()
            continue
        m = DECL.match(line)
        if m:
            names.add(".".join([c for c in stack if c] + [m.group(1)]))
    return names


def verify(table):
    prov = provenance_pins()
    red, ok, skipped, lean_ok = [], 0, {}, 0
    for side in ("reference", "teranode"):
        pin = table["pins"][side]
        for k in ("commit", "tag"):
            if prov.get(side, {}).get(k) != pin[k]:
                red.append(f"the table's {side} {k} {pin[k]} differs from docs/PROVENANCE.md's {prov.get(side, {}).get(k)}")
    cache = {}
    for r in table["rows"]:
        for side in ("reference", "teranode"):
            pin = table["pins"][side]
            clone = prov[side]["clone"]
            for c in r[side]["cites"]:
                if not os.path.isdir(clone):
                    skipped[side] = skipped.get(side, 0) + 1
                    continue
                key = (clone, c["file"])
                if key not in cache:
                    p = subprocess.run(["git", "-C", clone, "show", f"{pin['commit']}:{c['file']}"],
                                       capture_output=True, text=True, errors="replace")
                    cache[key] = p.stdout.split("\n") if p.returncode == 0 else None
                text = cache[key]
                a, b = c["lines"]
                if text is None:
                    red.append(f"{r['id']}: {side} {c['file']} does not exist at {pin['commit'][:8]}")
                elif b > len(text):
                    red.append(f"{r['id']}: {side} {c['file']}:{a}-{b} beyond the file's {len(text)} lines")
                elif not any(c["anchor"] in line for line in text[a - 1:b]):
                    red.append(f"{r['id']}: {side} {c['file']}:{a}-{b} does not contain {c['anchor']!r} at {pin['commit'][:8]}")
                else:
                    ok += 1
        for d in r["lean"]:
            path = os.path.join(ROOT, d["file"])
            src = open(path).read() if os.path.isfile(path) else ""
            if src and d["name"] in declared(src):
                lean_ok += 1
            else:
                red.append(f"{r['id']}: Lean {d['name']} is not declared in {d['file']}")
    skip = "; ".join(f"{n} {s} citations SKIPPED BY NAME (the clone is absent here; not a pass)" for s, n in skipped.items())
    if skipped and os.environ.get("TERANODE_MAP_REQUIRE_CLONES") == "1":
        red.append("TERANODE_MAP_REQUIRE_CLONES=1 and a clone is absent")
    for line in red:
        print(f"  RED {line}")
    verdict = "RED" if red else "GREEN"
    print(f"cite_check teranode-map: {verdict} ({ok} citations anchored at the pins, {lean_ok} Lean names declared, "
          f"{len(red)} failures{'; ' + skip if skip else ''}; corpus/teranode/map.json, {len(table['rows'])} rows)")
    return not red


def main():
    table = load()
    page = render(table)
    if "--verify" in sys.argv:
        sys.exit(0 if verify(table) else 1)
    if "--check" in sys.argv:
        same = os.path.isfile(PAGE) and open(PAGE).read() == page
        print(f"teranode_map --check: {'OK' if same else 'STALE'} (spec/teranode-map.md, {len(table['rows'])} rows)")
        sys.exit(0 if same else 1)
    with open(PAGE, "w") as f:
        f.write(page)
    print(f"teranode_map: spec/teranode-map.md written ({len(table['rows'])} rows)")


if __name__ == "__main__":
    main()
