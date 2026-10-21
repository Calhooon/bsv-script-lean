#!/usr/bin/env python3
"""tools/teranode_absences.py: the absence ledger's page (#96, S8, 2026-10-14).

Reads `corpus/teranode/absences.json` (one object per absence: what Teranode v0.16.0 lacks that bitcoin-sv v1.2.3
has, and what the reference lacks that Teranode has) and writes `spec/teranode-absences.md`, deterministically: the
page is a function of the table alone, so two runs write the same bytes and `tools/specgen.py --check` (the spec leg)
reads it stale when the table moves without it.

The table is checked before it renders: unique ids, a direction of the two, a proposed ruling of the four words of
#96, a `breaks` entry on every `gap` row (the done-bar: each gap linked to the view it breaks in #67 or #84), a
present-side citation and an absent-side listing and search on every row, a `map_id` (#87's row id) on every row
and `-l` in every search's flags (the search's file list is read from `git grep -l`).

The maintainers' rule (#96, 2026-10-15): the table's `ruling_rule` (the rule's sentences, who ruled, the date and the
record) heads the page; a row ruled by it carries `ruling.owner.by = "ruling_rule"`, and a row whose ruled word
differs from its proposal carries `ruling.owner_reason`, rendered on its card and named in the page's head.

The design (#140, 2026-10-16): a row may carry `section` (a key of the table's `sections`), `design`
(`reason`, `cites`, `client`; each cite a `repo`, `path`, `lines`, `anchor` and a `label` of `[LIT]` or `[SRC]`) and
`measured` (`reference` and `teranode`, each a `label` with an `answer`, a `record` and `receipts`, or an `owed`); a
section-3 row ruled `gap` must carry `design`. The card prints all three; `--verify` re-reads every design cite and every
cite of the table's `contract` at the pins; tools/node_contract.py renders spec/node-client-contract.md from the same
table.

Usage:
  tools/teranode_absences.py            write spec/teranode-absences.md
  tools/teranode_absences.py --check    exit 1 when the page differs from the table's rendering
  tools/teranode_absences.py --verify   re-read at the pins (docs/PROVENANCE.md section 1a) every citation's anchor
                                        inside its lines, every listing and every search's file list; `git show`,
                                        `git ls-tree` and `git grep` at the commit, never a working tree; needs the
                                        clones (section 1a's `reference.clone` and `teranode.clone`), so it runs on a
                                        maintainers' host, not in the Modal container
"""
import json
import os
import re
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TABLE = os.path.join(ROOT, "corpus", "teranode", "absences.json")
PAGE = os.path.join(ROOT, "spec", "teranode-absences.md")
MAP = os.path.join(ROOT, "corpus", "teranode", "map.json")
DIRECTIONS = ("Teranode-lacks", "reference-lacks")
# The words the page prints for a row's `direction` (#96's data keeps its value): the Teranode side reads as the
# contract page does (#140's lens, 2026-10-16).
SIDE = {"Teranode-lacks": "not carried by Teranode"}
SHORT = 8


def load():
    with open(TABLE) as f:
        return json.load(f)


def validate(data):
    errs = []
    rulings = data["rulings"]
    seen = set()
    for row in data["rows"]:
        rid = row.get("id")
        if rid in seen:
            errs.append(f"{rid}: duplicate id")
        seen.add(rid)
        if not row.get("map_id"):
            errs.append(f"{rid}: no map_id (#87's row id)")
        if row.get("direction") not in DIRECTIONS:
            errs.append(f"{rid}: direction {row.get('direction')!r}")
        prefix = "tl." if row.get("direction") == "Teranode-lacks" else "rl."
        if not rid.startswith(prefix):
            errs.append(f"{rid}: id prefix does not match the direction")
        ruling = row.get("ruling", {})
        if ruling.get("proposed") not in rulings:
            errs.append(f"{rid}: proposed ruling {ruling.get('proposed')!r}")
        if ruling.get("owner") is not None and ruling["owner"].get("word") not in rulings:
            errs.append(f"{rid}: ruling {ruling['owner']!r}")
        owner = ruling.get("owner")
        if owner and owner.get("by") == "ruling_rule" and not data.get("ruling_rule"):
            errs.append(f"{rid}: ruled by ruling_rule, the table has none")
        if owner and owner.get("word") != ruling.get("proposed") and not ruling.get("owner_reason"):
            errs.append(f"{rid}: the ruled word differs from the proposal with no owner_reason")
        if not ruling.get("reason"):
            errs.append(f"{rid}: no reason")
        effective = (ruling.get("owner") or {}).get("word") or ruling.get("proposed")
        if effective == "gap" and not row.get("breaks"):
            errs.append(f"{rid}: a gap with no view it breaks (#67 or #84)")
        for b in row.get("breaks", []):
            if b.get("where") not in ("#67", "#84"):
                errs.append(f"{rid}: breaks names {b.get('where')!r}, not #67 or #84")
        if not row.get("present"):
            errs.append(f"{rid}: no present-side citation")
        absent = row.get("absent", {})
        if absent.get("listing") not in data["listings"] or not absent.get("searches"):
            errs.append(f"{rid}: absent side needs a listing and a search")
        present_repo = "bitcoin-sv" if row.get("direction") == "Teranode-lacks" else "teranode"
        for c in row.get("present", []):
            if c["repo"] != present_repo:
                errs.append(f"{rid}: present citation in {c['repo']}, expected {present_repo}")
        for s in absent.get("searches", []):
            if s["repo"] == present_repo:
                errs.append(f"{rid}: absent search in the present side's repository")
            if "l" not in s["flags"].lstrip("-"):
                errs.append(f"{rid}: search flags need -l")
        errs += validate_design(data, row)
    return errs


LABELS = ("[LIT]", "[SRC]")
MEASURE_LABELS = ("[M]", "[X]")


def validate_cites(where, data, cites):
    errs = []
    for c in cites:
        if c.get("repo") not in data["pins"] or not c.get("path") or not c.get("anchor") or len(c.get("lines", [])) != 2:
            errs.append(f"{where}: a cite needs a pinned repo, a path, two lines and an anchor: {c!r}")
        if c.get("label") not in LABELS:
            errs.append(f"{where}: a cite's label {c.get('label')!r} is not one of {LABELS}")
    return errs


def validate_design(data, row):
    """#140's fields: `section`, `design` and `measured` (absent on a table that predates them)."""
    rid = row.get("id")
    errs = []
    sections = data.get("sections")
    if "section" in row and (not sections or row["section"] not in sections):
        errs.append(f"{rid}: section {row.get('section')!r} is not a key of the table's sections")
    if sections and "section" not in row:
        errs.append(f"{rid}: the table names sections, the row carries none")
    if row.get("section") == "3" and effective(row) == "gap" and not row.get("design"):
        errs.append(f"{rid}: a section-3 gap row with no design")
    design = row.get("design")
    if design is not None:
        for key in ("reason", "cites", "client"):
            if not design.get(key):
                errs.append(f"{rid}: design without {key}")
        errs += validate_cites(f"{rid} design", data, design.get("cites", []))
    for side, m in (row.get("measured") or {}).items():
        if side not in ("reference", "teranode"):
            errs.append(f"{rid}: measured side {side!r}")
        elif "owed" in m:
            if not m["owed"]:
                errs.append(f"{rid}: measured {side} owed without its reason")
        elif m.get("label") not in MEASURE_LABELS or not m.get("answer") or not m.get("record"):
            errs.append(f"{rid}: measured {side} needs a label of {MEASURE_LABELS}, an answer and a record")
        else:
            for path in [m["record"]] + m.get("receipts", []):
                if not os.path.exists(os.path.join(ROOT, path)):
                    errs.append(f"{rid}: measured {side}: {path} absent from the tree")
    return errs


def lines_str(c):
    a, b = c["lines"]
    return f"{a}" if a == b else f"{a}-{b}"


def short(data, repo):
    return data["pins"][repo]["commit"][:SHORT]


def cite(data, c):
    return f"`{c['path']}:{lines_str(c)}` at {repo_name(c['repo'])} `{short(data, c['repo'])}`"


def repo_name(repo):
    return "Teranode" if repo == "teranode" else "bitcoin-sv"


def clone_hint(repo):
    return "<teranode clone>" if repo == "teranode" else "<bitcoin-sv clone>"


def search_cmd(data, s):
    paths = " ".join(f"'{p}'" for p in s.get("paths", []))
    tail = f" -- {paths}" if paths else ""
    return f"git -C {clone_hint(s['repo'])} grep {s['flags']} '{s['pattern']}' {short(data, s['repo'])}{tail}"


def search_result(s):
    files = s.get("files", [])
    if not files:
        return "no file"
    noun = "file" if len(files) == 1 else "files"
    return f"{len(files)} {noun}: " + ", ".join(f"`{f}`" for f in files)


def listing_cmd(data, key):
    l = data["listings"][key]
    d = "-d " if l.get("dirs_only") else ""
    return f"git -C {clone_hint(l['repo'])} ls-tree {d}--name-only {short(data, l['repo'])} {l['tree']}/"


def esc(text):
    return text.replace("|", "\\|")


def render(data=None):
    data = data or load()
    errs = validate(data)
    if errs:
        raise SystemExit("teranode_absences: the table is invalid: " + "; ".join(errs))
    rulings = data["rulings"]
    rows = data["rows"]
    tl = [r for r in rows if r["direction"] == "Teranode-lacks"]
    rl = [r for r in rows if r["direction"] == "reference-lacks"]
    owner_ruled = [r for r in rows if r["ruling"].get("owner")]
    proposed = {w: sum(1 for r in rows if r["ruling"]["proposed"] == w) for w in rulings}
    ruled = {w: sum(1 for r in owner_ruled if r["ruling"]["owner"]["word"] == w) for w in rulings}
    differ = [r for r in owner_ruled if r["ruling"]["owner"]["word"] != r["ruling"]["proposed"]]
    gaps = [r for r in rows if effective(r) == "gap"]
    t, b = data["pins"]["teranode"], data["pins"]["bitcoin-sv"]
    out = [
        "# Teranode absences: what each implementation does not carry, and a ruling for each (#96)",
        "",
        f"**Generated by `tools/teranode_absences.py` from `corpus/teranode/absences.json` (#96); never edited by hand.** "
        f"[D] {data['date']}"
        + (f"; the rulings [M] {data['ruling_rule']['when']}" if data.get("ruling_rule") else "")
        + f". Teranode {t['tag']} `{t['commit'][:SHORT]}` against bitcoin-sv {b['tag']} "
        f"`{b['commit'][:SHORT]}` (`docs/PROVENANCE.md` section 1a). Every present side is cited at file and line [SRC]; "
        "every absent side is a directory listed at the tag and the searches that found nothing, or only the hits "
        "named, each quoted as the command that reproduces it in a clone of the repository (`<teranode clone>`, `<bitcoin-sv clone>`: "
        "`teranode.clone` and `reference.clone` of `docs/PROVENANCE.md` section 1a) [SRC]. `tools/teranode_absences.py --verify` re-reads "
        "every citation, listing and search at the pins. The module map of #87 (`corpus/teranode/map.json`, which lands "
        "with #87) keys the same surfaces by its `id`; each absence here carries that `id` (`map_id`) and #87's issue "
        "word in the #87 column, and every map row whose mechanism is `absent` has a row here.",
        "",
    ]
    out += rule_head(data, rows, owner_ruled, differ)
    out += [
        "Nothing on this page is a rule of validity: the rows are surfaces, events and policies; an absence of a "
        "notification, a pool or a transport is node behavior, and a policy setting is never consensus.",
        "",
        "| word | ruling |",
        "|---|---|",
    ]
    for w, text in rulings.items():
        out.append(f"| `{w}` | {text} |")
    out += [
        "",
        f"Counts [M]: {len(rows)} absences, {len(tl)} {SIDE['Teranode-lacks']} and {len(rl)} the reference lacks; proposed "
        + ", ".join(f"{proposed[w]} `{w}`" for w in rulings)
        + f"; ruled by the maintainers {len(owner_ruled)} of {len(rows)}"
        + ("" if not owner_ruled else ": " + ", ".join(f"{ruled[w]} `{w}`" for w in rulings))
        + f"; {len(gaps)} gap rows, each linked to the view it breaks in #67 or #84.",
        "",
        "| id | direction | #87 row | surface | proposed | ruled | the view it breaks |",
        "|---|---|---|---|---|---|---|",
    ]
    for r in rows:
        owner = r["ruling"].get("owner")
        owner_s = f"`{owner['word']}` ({owner['date']})" if owner else "awaiting the card"
        breaks = "; ".join(f"{x['where']}: {x['view']}" for x in r.get("breaks", [])) or "none"
        out.append(f"| [`{r['id']}`](#{anchor(r['id'])}) | {SIDE.get(r['direction'], r['direction'])} | `{r['map_id']}` ({r['map_row']}) | {esc(r['surface'])} | "
                   f"`{r['ruling']['proposed']}` | {owner_s} | {esc(breaks)} |")
    out += ["", "## Corrections to the issues' source lines [SRC]", ""]
    for c in data.get("corrections", []):
        line = f"- **{c['of']}.** {c['finding']}"
        if "search" in c:
            line += f" The search: `{search_cmd(data, c['search'])}` returns {search_result(c['search'])}."
        if "cite" in c:
            line += f" The citation: {cite(data, c['cite'])}."
        out.append(line)
    for title, group in (("What Teranode does not carry", tl), ("What the reference lacks", rl)):
        out += ["", f"## {title}", ""]
        for r in group:
            out += render_row(data, r)
    out += [
        "",
        "## The listings [SRC]",
        "",
    ]
    for key, l in data["listings"].items():
        out.append(f"- `{key}`: `{listing_cmd(data, key)}` lists {len(l['entries'])} entries: "
                   + ", ".join(f"`{e}`" for e in l["entries"]) + ".")
    out.append("")
    return "\n".join(out)


def effective(r):
    return (r["ruling"].get("owner") or {}).get("word") or r["ruling"]["proposed"]


def rule_head(data, rows, owner_ruled, differ):
    rule = data.get("ruling_rule")
    if not rule:
        return ["**The rulings are the maintainers'.** Each row carries a proposal and its reason; the maintainers' ruling "
                "replaces it on the card and in the table.", ""]
    out = [
        f"**The rulings are the maintainers', by the rule of {rule['when']}.** {rule['by'][0].upper() + rule['by'][1:]} "
        f"ruled {len(owner_ruled)} of {len(rows)} rows by one rule ({rule['on']}):",
        "",
    ]
    out += [f"> {s}" for s in rule["rule"]]
    out.append("")
    if differ:
        out.append("The rows whose ruling differs from the proposal: "
                   + "; ".join(f"[`{r['id']}`](#{anchor(r['id'])}), proposed `{r['ruling']['proposed']}`, ruled "
                               f"`{r['ruling']['owner']['word']}`: {r['ruling']['owner_reason']}" for r in differ)
                   + " Every other row is ruled as proposed.")
        out.append("")
    return out


def owner_line(ruling):
    owner = ruling.get("owner")
    if not owner:
        return "**The maintainers' ruling:** awaiting the card."
    by = ", by the maintainers' rule" if owner.get("by") == "ruling_rule" else ""
    line = f"**The maintainers' ruling:** `{owner['word']}` ({owner['date']}{by})."
    if owner["word"] != ruling["proposed"]:
        line += f" It differs from the proposal: {ruling['owner_reason']}"
    return line


def anchor(rid):
    return re.sub(r"[^a-z0-9 -]", "", rid.lower()).replace(" ", "-")


def render_row(data, r):
    ruling = r["ruling"]
    out = [
        f"### {r['id']}",
        "",
        f"**{r['surface'][0].upper() + r['surface'][1:]}.** {SIDE.get(r['direction'], r['direction'])}; the #87 row: `{r['map_id']}` ({r['map_row']}).",
        "",
        r["what"],
        "",
        "Present [SRC]:",
        "",
    ]
    for c in r["present"]:
        out.append(f"- {cite(data, c)}: {c['note']} (at `{c['anchor']}`)")
    out += ["", f"Absent [SRC]: `{listing_cmd(data, r['absent']['listing'])}` (the listing below); then", ""]
    for s in r["absent"]["searches"]:
        note = f" ({s['note']})" if s.get("note") else ""
        out.append(f"- `{search_cmd(data, s)}` returns {search_result(s)}{note}")
    out += ["", f"The other side's nearest: {r['counterpart']}"]
    if r.get("counterpart_cites"):
        out.append("[SRC] " + "; ".join(cite(data, c) for c in r["counterpart_cites"]) + ".")
    out += ["", "What depends on it today:", ""]
    for d in r["depends"]:
        out.append(f"- {d}")
    out += [
        "",
        f"**Proposed ruling [D]: `{ruling['proposed']}`, {data['rulings'][ruling['proposed']]}.** {ruling['reason']}",
        "",
        owner_line(ruling),
        "",
    ]
    out += design_lines(data, r)
    if r.get("breaks"):
        out.append("The view it breaks:")
        out.append("")
        for b in r["breaks"]:
            link = f" ([page]({b['link']}))" if b.get("link") else ""
            out.append(f"- {b['where']}: {b['view']}{link}")
        out.append("")
    return out


def design_cite(data, c):
    return f"{c['label']} {cite(data, c)}"


def design_lines(data, r):
    """#140's fields on the card: the section, the design with its cites, the client sentence, the measured answers."""
    out = []
    if r.get("section"):
        out += [f"**Section {r['section']}** (#140): {data['sections'][r['section']]}.", ""]
    d = r.get("design")
    if d:
        out += [f"**The design:** {d['reason']} " + "; ".join(design_cite(data, c) for c in d["cites"]) + ".", "",
                f"**A client:** {d['client']}", ""]
    for side in ("reference", "teranode"):
        m = (r.get("measured") or {}).get(side)
        if m is None:
            continue
        name = "the reference" if side == "reference" else "Teranode"
        if "owed" in m:
            out += [f"**Measured, {name}:** owed: {m['owed']}", ""]
            continue
        receipts = "".join(f"; receipt `{x}`" for x in m.get("receipts", []))
        out += [f"**Measured, {name}** {m['label']}: {m['answer']} (record `{m['record']}`{receipts}).", ""]
    return out


# --verify: the reads at the pins

def clones():
    text = open(os.path.join(ROOT, "docs", "PROVENANCE.md")).read()
    block = re.search(r"```pins\n(.*?)```", text, re.S).group(1)
    kv = {}
    for line in block.splitlines():
        m = re.match(r"\s*([\w.]+)\s*=\s*(\S+)", line)
        if m:
            kv[m.group(1)] = os.path.expanduser(m.group(2))
    return kv


def git(clone, *args):
    return subprocess.run(["git", "-C", clone, *args], capture_output=True, text=True)


def verify(data):
    kv = clones()
    fails = []
    skipped = []
    n_cite = n_search = n_list = 0
    repos = {}
    for repo, pin in data["pins"].items():
        clone = kv.get(pin["clone_key"])
        if kv.get(pin["clone_key"].replace(".clone", ".commit")) != pin["commit"]:
            fails.append(f"{repo}: the table's commit is not section 1a's")
        if not clone or not os.path.isdir(clone):
            print(f"  {repo}: clone {clone} absent: SKIPPED BY NAME, never a pass")
            skipped.append(repo)
            continue
        repos[repo] = (clone, pin["commit"])

    def check_cite(where, c):
        nonlocal n_cite
        if c["repo"] not in repos:
            return
        clone, commit = repos[c["repo"]]
        r = git(clone, "show", f"{commit}:{c['path']}")
        if r.returncode:
            fails.append(f"{where}: {c['path']} absent at the pin")
            return
        lines = r.stdout.split("\n")
        a, b = c["lines"]
        if b > len(lines) or a < 1:
            fails.append(f"{where}: {c['path']}:{a}-{b} beyond the file")
            return
        if c["anchor"] not in "\n".join(lines[a - 1:b]):
            fails.append(f"{where}: anchor {c['anchor']!r} not in {c['path']}:{a}-{b}")
            return
        n_cite += 1

    def check_search(where, s):
        nonlocal n_search
        if s["repo"] not in repos:
            return
        clone, commit = repos[s["repo"]]
        r = git(clone, "grep", s["flags"], "-e", s["pattern"], commit, "--", *s.get("paths", []))
        if r.returncode not in (0, 1):
            fails.append(f"{where}: git grep failed: {r.stderr.strip()}")
            return
        got = sorted({ln.split(":", 1)[1] for ln in r.stdout.splitlines() if ":" in ln})
        if got != sorted(s.get("files", [])):
            fails.append(f"{where}: search {s['pattern']!r} found {got}, the table says {sorted(s.get('files', []))}")
            return
        n_search += 1

    for key, l in data["listings"].items():
        if l["repo"] not in repos:
            continue
        clone, commit = repos[l["repo"]]
        args = ["ls-tree"] + (["-d"] if l.get("dirs_only") else []) + ["--name-only", commit, l["tree"] + "/"]
        r = git(clone, *args)
        got = sorted(x.split("/", 1)[1] if "/" in x else x for x in r.stdout.split())
        if got != sorted(l["entries"]):
            fails.append(f"listing {key}: {got} against the table's {sorted(l['entries'])}")
        else:
            n_list += 1
    for c in data.get("corrections", []):
        if "search" in c:
            check_search(f"correction {c['of']}", c["search"])
        if "cite" in c:
            check_cite(f"correction {c['of']}", c["cite"])
    for row in data["rows"]:
        for c in row["present"] + row.get("counterpart_cites", []) + (row.get("design") or {}).get("cites", []):
            check_cite(row["id"], c)
        for s in row["absent"]["searches"]:
            check_search(row["id"], s)
    contract = data.get("contract") or {}
    for star in (contract.get("north_stars") or {}).values():
        for c in star.get("cites", []):
            check_cite("contract north star", c)
    for surface in contract.get("client_surfaces", []):
        for c in surface.get("teranode_cites", []):
            check_cite(f"contract surface {surface['surface']}", c)
    map_note = "map.json absent (lands with #87): its absent rows not checked"
    if os.path.exists(MAP):
        with open(MAP) as f:
            map_rows = json.load(f)["rows"]
        ids = {r["id"] for r in map_rows}
        ours = {r["map_id"] for r in data["rows"]}
        for r in data["rows"]:
            if r["map_id"] not in ids:
                fails.append(f"{r['id']}: map_id {r['map_id']!r} is not a map.json id")
        absent = sorted(r["id"] for r in map_rows if r.get("mechanism") == "absent")
        for mid in absent:
            if mid not in ours:
                fails.append(f"map.json's absent row {mid!r} has no row here")
        map_note = f"{len(absent)} absent map.json rows each have a row"
    for f in fails:
        print(f"  {f}")
    verdict = "GREEN" if not fails else "RED"
    skip = f"; skipped by name: {', '.join(skipped)}" if skipped else ""
    print(f"teranode_absences --verify: {verdict} [X]: {n_cite} citations anchored, {n_list} listings and "
          f"{n_search} searches equal at the pins; {map_note}; {len(fails)} failures{skip}")
    return not fails


def main():
    data = load()
    if "--verify" in sys.argv:
        errs = validate(data)
        for e in errs:
            print(f"  {e}")
        sys.exit(0 if verify(data) and not errs else 1)
    page = render(data)
    if "--check" in sys.argv:
        ok = os.path.exists(PAGE) and open(PAGE).read() == page
        print(f"teranode_absences --check: {'OK' if ok else 'STALE'} ({len(data['rows'])} absences)")
        sys.exit(0 if ok else 1)
    os.makedirs(os.path.dirname(PAGE), exist_ok=True)
    with open(PAGE, "w") as f:
        f.write(page)
    print(f"teranode_absences: wrote {os.path.relpath(PAGE, ROOT)} ({len(data['rows'])} absences)")


if __name__ == "__main__":
    main()
