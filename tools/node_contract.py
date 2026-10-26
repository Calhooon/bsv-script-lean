#!/usr/bin/env python3
"""tools/node_contract.py: the node's client contract page (#140, S8, 2026-10-16).

Reads `corpus/teranode/absences.json` (#96's ledger, with #140's `section`, `design`, `measured` and `contract`),
`corpus/teranode/obligations.json` (#88's obligation list as data, emitted by `chaincheck --obligations-json` from
`lean/BsvChain/Teranode/Refinement.lean`; section 5, 2026-10-17) and the files its `contract` names (the column projections and records of #66's cut 2, `harness/rules/second-oracle-scenarios.json`,
`corpus/rpc/contract.json` of #85, `corpus/merkle/subtree-vectors.jsonl` of #89, `corpus/wire/` of #86 and
`spec/theorems.md`), and writes `spec/node-client-contract.md`, deterministically: the page is a function of those files
alone, so `tools/specgen.py --check` (the spec leg) reads it stale when one moves without it.

What it checks before it renders (a failure stops the render): the ledger is valid (`teranode_absences.validate`); a
whole run's figures equal its projection's totals; a chunked run's figures and the reference column's sentence occur in
their records; every diverge class a whole run names is in the rules file and has a reading here, or the row is a
withheld one (matched by the sha256 of its id, so neither the ledger nor the page names it); every theorem the ledger
names has its entry in `spec/theorems.md`; every RPC method a client surface names is in the RPC contract; every row
the machines' table below names is a section-3 row of the ledger; every obligation row's ledger ids are ledger rows keyed
to that map row with the word the ledger rules, every landed leg's record exists by its path (never opened: the legs'
records are withheld from the public edition by name), and every name of a `theorem` row has its entry in
`spec/theorems.md`. `tools/teranode_absences.py --verify` re-reads every
cite at the pins (it runs where the clones are, never in the Modal container).

The page's words (#140's charter as the maintainers re-cut it on 2026-10-16): section 3 never reads as a complaint list; a
section-3 row "does not carry" a surface "by design", or is "replaced by" its carrier.

Usage:
  tools/node_contract.py            write spec/node-client-contract.md
  tools/node_contract.py --check    exit 1 when the page differs from the rendering
"""
import hashlib
import json
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import teranode_absences as ta  # noqa: E402

ROOT = ta.ROOT
PAGE = os.path.join(ROOT, "spec", "node-client-contract.md")
FIGURES = ("measured", "agree", "diverge", "non-judging", "no-verdict", "rpc-precheck", "unrealizable")

# The machines of BSV-NORTH-STAR.md section 5 (the page the ledger's `contract.north_stars.bsv.stack_page` names, lines
# 38-48, the sha256 in the ledger's contract): the sections each may rely on, the section-3 rows that would have bitten it on SV-node, and why.
# [D] #140's reading (2026-10-16) of each machine's line against the ledger's rows.
MACHINES = [
    ("the node", ["1", "2"], ["tl.soft-freeze"],
     "it is section 1 and gives section 2; the one section-3 row that moves the tip a node follows is the soft freeze, "
     "an operator list applied at block connection, where two alert-following nodes hold the same tip while the "
     "reference's hold lasts and can hold different tips once it lapses (the row's ruling)"),
    ("headers and proofs", ["1", "2"], ["tl.zmq-announce", "tl.dsdetected", "tl.soft-freeze"],
     "it holds 80 bytes per block and checks every proof against the active header, which both nodes serve; the tip "
     "push changes carrier (ZMQ on the reference, the WebSocket on Teranode), a block carrying a double spend is read by "
     "headers rather than announced, and a proof into a block a soft freeze holds is not on the active chain"),
    ("the broadcaster", ["2"], ["tl.ds-attempt-callback", "tl.zmq-removal", "tl.pool-size", "tl.nonfinal-pool",
                                "tl.invalidtx-sinks", "tl.dsdetected"],
     "it couriers the node's verdict, which both nodes give; each of these rows is a push or a hold a broadcaster on "
     "SV-node could relay as a status, and none of them is evidence"),
    ("the transaction tracker", ["2"], ["tl.zmq-removal", "tl.pool-size", "tl.nonfinal-pool", "tl.dsdetected"],
     "one word per transaction from evidence, the verdict and the proof; these rows are the removal event, the "
     "eviction, the hold and the double-spend push that #67's views read on SV-node"),
    ("the wallet", ["2"], ["tl.nonfinal-pool", "tl.pool-size", "tl.ds-attempt-callback", "tl.orphan-pool"],
     "a coin is spendable when the chain says so: it broadcasts a time-locked transaction once final, rebroadcasts "
     "when no proof has come by its own deadline, submits parents before children and depends on no callback endpoint"),
    ("the SDK", ["2"], [],
     "it builds and verifies and reads the status word, never the code: the verdict on a broadcast is section 2 on "
     "both nodes, and Teranode's one validation-refusal code with the reason in the message is the case that rule covers"),
    ("the overlay", ["2", "2b"], ["tl.zmq-announce", "tl.zmq-removal"],
     "it settles on verdicts and admits on proof; an overlay that followed ZMQ topics takes the push its node "
     "offers, as a hint"),
    ("the app layer", ["2", "2b"], ["tl.zmq-announce", "tl.dsdetected"],
     "it derives per chain event: the event is a header and a proof, and the push that announces it is a hint on "
     "either node"),
    ("message box and auth", [], [],
     "its signatures and nonces are its own; it relies on no node section, and the node's authenticated peer "
     "handshake (row `tl.miner-id`) is a peer surface, not a client's"),
]


def read_json(rel):
    with open(os.path.join(ROOT, rel)) as f:
        return json.load(f)


def read_text(rel):
    with open(os.path.join(ROOT, rel)) as f:
        return f.read()


def jsonl(rel):
    with open(os.path.join(ROOT, rel)) as f:
        return [json.loads(line) for line in f if line.strip()]


def esc(text):
    return text.replace("|", "\\|")


def at(data, c):
    return ta.design_cite(data, c)


def run_figures(data, run):
    """A whole run's figures from its projection; a chunked run's from its record's row (checked to occur)."""
    rows = data["contract"]["consensus"]["column_rows"]
    if run.get("projection"):
        t = read_json(run["projection"])["totals"]
        got = {k: t.get(k, 0) for k in FIGURES[:-1]}
        got["unrealizable"] = rows - t["measured"] - t["no-verdict"] - t.get("rpc-precheck", 0) - t.get("pending", 0)
        if got != run["figures"]:
            raise SystemExit(f"node_contract: {run['name']}: the ledger's figures {run['figures']} are not the projection's {got}")
    elif run["row_text"] not in read_text(run["record"]):
        raise SystemExit(f"node_contract: {run['name']}: the record {run['record']} does not carry the row the ledger quotes")
    return run["figures"]


def diverges(data, run):
    """The diverge rows and steps of a whole run, each with its class (from the projection) and its reading."""
    cons = data["contract"]["consensus"]
    rules = read_json(cons["rules_file"])["classes"]
    withheld = {w["row_sha256"]: w["group"] for w in cons.get("withheld", [])}
    corpus_timing = timing_rows()
    out = []
    proj = read_json(run["projection"])
    for family, rows in sorted(proj["families"].items()):
        for r in rows:
            if r.get("verdict") != "diverge":
                continue
            rid = f"{r['id']}` ({family}"
            if hashlib.sha256(r["id"].encode()).hexdigest() in withheld:
                out.append(f"(a class under a still-private advisory: withheld, {withheld[hashlib.sha256(r['id'].encode()).hexdigest()]})")
                continue
            cls = (r.get("adjudication") or {}).get("class")
            if r["id"] in corpus_timing:
                out.append(f"`{rid}): timing-sensitive, marked so in the corpus (#140); its whole runs differ")
            elif cls:
                if cls not in rules or cls not in cons["class_readings"]:
                    raise SystemExit(f"node_contract: {run['name']}: class {cls!r} has no rule or no reading")
                out.append(f"`{rid}): `{cls}` (ruling {rules[cls]['ruling']}): {cons['class_readings'][cls]}")
            else:
                raise SystemExit(f"node_contract: {run['name']}: diverge row {rid} carries no class and no timing mark")
    for s in proj.get("scenarios", []):
        for step in s["steps"]:
            if step["verdict"] == "diverge":
                if (s["scenario"], step["id"]) not in timing_steps():
                    raise SystemExit(f"node_contract: {run['name']}: scenario {s['scenario']} step {step['id']} diverges unmarked")
                out.append(f"scenario `{s['scenario']}` step `{step['id']}`: timing-sensitive, marked so in the corpus (#140)")
    return out


WORDS = ("no", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine")


def unexplained(run):
    """The diverge rows of a whole run whose class is the projection's `unexplained`."""
    return [r["id"] for rows in read_json(run["projection"])["families"].values() for r in rows
            if r.get("verdict") == "diverge" and (r.get("adjudication") or {}).get("class") == "unexplained"]


def timing_rows():
    ids = set()
    for fam in ("chain", "mempool", "block", "finality", "utxo"):
        for r in jsonl(f"corpus/chain/{fam}/{fam}.jsonl"):
            if r.get("timing_sensitive"):
                ids.add(r["id"])
    return ids


def timing_steps():
    steps = set()
    folder = os.path.join(ROOT, "corpus", "scenarios")
    for name in sorted(os.listdir(folder)):
        if not name.startswith("2026") or not name.endswith(".md"):
            continue
        raw = read_text(f"corpus/scenarios/{name}")
        if raw.count("```json\n") != 1:
            continue
        fence = json.loads(raw.split("```json\n")[1].split("\n```")[0])
        for key in ("steps", "variants"):
            for step in fence.get(key, []) if isinstance(fence.get(key), list) else []:
                if isinstance(step, dict) and step.get("timing_sensitive"):
                    steps.add((name[:-3], step.get("id")))
    return steps


def theorem_entries(data, key="theorems", theorems_text=None):
    # specgen passes the theorems page it is rendering in the same run (#149: a theorem the run adds has no entry on
    # the page on disk yet); run alone, the page on disk
    text = theorems_text if theorems_text is not None else read_text("spec/theorems.md")
    out = []
    consensus = data["contract"]["consensus"]
    for t in (consensus[key] if key == "theorems" else consensus.get(key, [])):
        m = re.search(r"^### `" + re.escape(t["name"]) + r"` \(`([^`]+)`\)$", text, re.M)
        if not m:
            raise SystemExit(f"node_contract: theorem {t['name']} has no entry in spec/theorems.md")
        out.append((t, m.group(1)))
    return out


def handlers():
    return {h["method"]: h for h in read_json("corpus/rpc/contract.json")["handlers"]}


def evidence(data, kind, check5):
    counts = read_json(check5["projection"])["counts"]
    if kind.startswith("family:"):
        fam = kind.split(":", 1)[1]
        c = counts[fam]
        return (f"cut 2's {fam} family in {check5['name']}: {c['measured']} rows measured on both nodes, {c['agree']} agree, "
                f"{c['diverge']} diverge, {c['non-judging']} non-judging [M] (`{check5['record']}`)")
    if kind == "column":
        b, ch = counts["block"], counts["chain"]
        return (f"the column's block and chain rows read blocks and tips through these calls: in {check5['name']}, block "
                f"{b['measured']} measured and {b['agree']} agree, chain {ch['measured']} measured and {ch['agree']} agree [M] "
                f"(`{check5['record']}`; section 1 names their diverges)")
    if kind == "contract":
        return "the handler's arguments, fields and errors at both pins: the RPC contract of #85 (`corpus/rpc/contract.json`, docs/CONFORMANCE-RPC-CONTRACT.md) [SRC]"
    if kind == "merkle":
        v = jsonl("corpus/merkle/subtree-vectors.jsonl")
        agree = sum(1 for x in v if x.get("agree"))
        rest = ", ".join(f"`{x['id']}`" for x in v if not x.get("agree"))
        return (f"#89's vectors (`corpus/merkle/subtree-vectors.jsonl`, transcriptions of both pins' code, `corpus/INDEX.md`): "
                f"{len(v)} block bodies, {agree} with the vector's verdict agree, the others ({rest}) each a body shape or an "
                f"infeasible id the vector's own note names [D]; the theorem `subtreeRoot_eq_blockMerkleRoot` (section 1)")
    raise SystemExit(f"node_contract: evidence kind {kind!r}")


# The page names each obligation's owner by its area, never by the owner value the list carries (#177).
AREA = {"S1": "the Lean semantics", "S2": "the Lean families", "S3": "the harness", "S4b": "the engines",
        "T3": "the engine upstream", "W0": "the plan"}


def area(o):
    return AREA.get(o, o)


def section_rows(data, sec):
    return [r for r in data["rows"] if r.get("section") == sec]


def owner_word(r):
    o = r["ruling"]["owner"]
    return f"`{o['word']}` (the maintainers' ruling, {o['date']}: {o['word'] and ta_rulings[o['word']]})"


ta_rulings = {}


def measured_lines(r):
    out = []
    for side, name in (("reference", "the reference"), ("teranode", "Teranode")):
        m = (r.get("measured") or {}).get(side)
        if m is None:
            continue
        if "owed" in m:
            out.append(f"  - **Measured, {name}:** owed: {m['owed']}")
        else:
            rec = ", ".join(f"`{x}`" for x in [m["record"]] + m.get("receipts", []))
            out.append(f"  - **Measured, {name}** {m['label']}: {m['answer']} ({rec}).")
    return out


def render(data=None, theorems_text=None):
    data = data or ta.load()
    errs = ta.validate(data)
    if errs:
        raise SystemExit("node_contract: the ledger is invalid: " + "; ".join(errs))
    if "contract" not in data or "sections" not in data:
        raise SystemExit("node_contract: the ledger carries no contract or sections (#140)")
    ta_rulings.clear()
    ta_rulings.update(data["rulings"])
    con = data["contract"]
    stars = con["north_stars"]
    cons = con["consensus"]
    t, b = data["pins"]["teranode"], data["pins"]["bitcoin-sv"]
    tsh, bsh = t["commit"][:ta.SHORT], b["commit"][:ta.SHORT]
    rows_by_id = {r["id"]: r for r in data["rows"]}
    sec3 = section_rows(data, "3")
    sec2b = section_rows(data, "2b")
    for name, _, bit, _ in MACHINES:
        for rid in bit:
            if rows_by_id.get(rid, {}).get("section") != "3":
                raise SystemExit(f"node_contract: machine {name!r} names {rid}, not a section-3 row")
    runs = cons["runs"]
    check5 = next(r for r in runs if r["name"] == "check 5")
    out = [
        "# The node's client contract: what a node that replaces SV-node gives a client (#140)",
        "",
        "**Generated by `tools/node_contract.py` from `corpus/teranode/absences.json` (#96, with #140's sections, designs and "
        "measurements) and the files its `contract` names; never edited by hand.** [D] 2026-10-16, on the "
        "maintainers' re-cut of #140 of 2026-10-16. Teranode "
        f"{t['tag']} `{tsh}` beside bitcoin-sv {b['tag']} `{bsh}` (`docs/PROVENANCE.md` section 1a). Teranode's documentation is "
        "cited `[LIT]` and its source `[SRC]`, each at the pin's file and lines; `tools/teranode_absences.py --verify` re-reads "
        "the ledger's cites and `tools/rpc_contract.py --verify` the RPC handlers' cites of section 2, at the pins. A figure carries its label and its record. Sections 2b and 3 are design, "
        "never a finding: they say what each node carries and why, in its own terms; nothing on this page is a rule of "
        "validity except where section 1 says so.",
        "",
        "## 0. The two north stars",
        "",
        f"**BSV's protocol is set in stone.** Teranode's own page of network consensus rules opens: \"{stars['bsv']['quote']}\" "
        + "; ".join(at(data, c) for c in stars["bsv"]["cites"]) + ". "
        f"The chain's north star page (`{stars['bsv']['stack_page']['path']}`, sha256 `{stars['bsv']['stack_page']['sha256']}` "
        f"as read at {stars['bsv']['stack_page']['read_utc']}, its commit `{stars['bsv']['stack_page']['commit']}`) says it "
        "from the whitepaper's side [LIT]:",
        "",
    ]
    out += [f"- {x}" for x in stars["bsv"]["stack_page"]["reads"]]
    tc = stars["teranode"]["cites"]
    out += [
        "",
        f"**Teranode's north star is scale.** Horizontal scaling across machines ({at(data, tc[0])}), over a million "
        f"transactions a second ({at(data, tc[1])}), subtrees broadcast about every second ({at(data, tc[2])}), and, in its "
        f"system design's comparison table, the mempool row: \"{stars['teranode']['quote']}\" "
        f"({at(data, tc[stars['teranode']['quote_cite']])}).",
        "",
        "[D] Read together: the protocol does not move, and the design decisions Teranode made to scale it decide which of "
        "SV-node's surfaces beyond the protocol it carries. So this page has four parts, each a key of the ledger's "
        "`sections`:",
        "",
    ]
    for key, text in data["sections"].items():
        out.append(f"- **{key}**: {text}.")
    # section 1
    out += [
        "",
        "## 1. Consensus, set in stone",
        "",
        f"[D] {data['sections']['1'][0].upper() + data['sections']['1'][1:]}. The evidence for the two implementations at "
        f"the pins is #66's cut 2 column of {cons['column_rows']} rows, run against Teranode under the quarantine rule (no "
        "model read the instance's text), and the theorems below; every diverge of a whole run is named with its class, "
        "and none is ruled yet.",
        "",
        "| run | shape | measured | agree | diverge | non-judging | no-verdict | rpc-precheck | unrealizable | record |",
        "|---|---|---|---|---|---|---|---|---|---|",
    ]
    for run in runs:
        f = run_figures(data, run)
        out.append(f"| {run['name']} | {run['shape']} | " + " | ".join(f"{f[k]} [M]" for k in FIGURES) + f" | `{run['record']}` |")
    rc = cons["reference_column"]
    if rc["row_text"] not in read_text(rc["record"]):
        raise SystemExit("node_contract: the reference column's sentence is not in its record")
    out += [
        "",
        f"The reference's own column, the spec judged against SV-node: {rc['row_text']} (`{rc['record']}`).",
        "",
        f"Every diverge of the two whole runs, with its class from `{cons['rules_file']}` (each ruling is the maintainers' to "
        "make, rule 15):",
        "",
    ]
    for run in runs:
        if not run.get("projection"):
            continue
        ds = diverges(data, run)
        steps = sum(1 for x in ds if x.startswith("scenario "))
        head = f"{WORDS[len(ds) - steps]} row diverges" + (f" and {WORDS[steps]} scenario step" + "s" * (steps > 1) if steps else "")
        out.append(f"- {run['name']}: {head}: " + "; ".join(ds) + ".")
        un = read_json(run["projection"])["totals"].get("diverge-unexplained", 0)
        if un:
            rows = unexplained(run)
            if len(rows) != un or not set(rows) <= timing_rows():
                raise SystemExit(f"node_contract: {run['name']}: diverge-unexplained {un} is not the timing-marked rows {rows}")
            out.append(f"  {run['name'][0].upper() + run['name'][1:]}'s projection counts {WORDS[un]} `diverge-unexplained` [M] "
                       f"(`totals[\"diverge-unexplained\"]`): the timing-marked row" + "s" * (un > 1) + " "
                       + ", ".join(f"`{x}`" for x in rows) + ".")
    out += ["", "The theorems that state the equalities (`spec/theorems.md`; sorry-free, `#print axioms` in `lean/AxiomCheck.lean`):", ""]
    for th, loc in theorem_entries(data, theorems_text=theorems_text):
        out.append(f"- `{th['name']}` ({th['issue']}, `{loc}`): {th['says']}.")
    # #149 (2026-10-17): the signer's digest, what a signer hashes for a node that follows the reference
    signer = theorem_entries(data, "signer_theorems", theorems_text)
    if signer:
        out += ["", "The theorems that state what a signer hashes, on the executable semantics (`spec/theorems.md`; "
                "sorry-free, `#print axioms` in `lean/AxiomCheck.lean`), each beside its `[SRC]` at bitcoin-sv `6504a3af`:", ""]
        for th, loc in signer:
            out.append(f"- `{th['name']}` ({th['issue']}, `{loc}`): {th['says']}. [SRC] {th['src']}.")
    # section 2
    hs = handlers()
    out += [
        "",
        "## 2. The protocol's client contract",
        "",
        f"[D] {data['sections']['2'][0].upper() + data['sections']['2'][1:]}. Each surface below names the call on each "
        "node at its pin and the measurement behind it.",
        "",
    ]
    for s in con["client_surfaces"]:
        parts = []
        for m in s["methods"]:
            h = hs.get(m)
            if h is None:
                raise SystemExit(f"node_contract: {m} is not in the RPC contract")
            tera = h["teranode"]
            tera_s = (f"`{tera['handler']}` at Teranode `{tsh}`" if tera["class"] == "implemented"
                      else "on Teranode served by its Asset Service over HTTP rather than by RPC (below)" if s.get("teranode_cites")
                      else f"on Teranode not an RPC (the RPC contract's class `{tera['class']}`)")
            parts.append(f"`{m}` (`{h['source']}` at bitcoin-sv `{bsh}`; {tera_s})")
        line = f"- **{s['surface'][0].upper() + s['surface'][1:]}** [SRC]: " + "; ".join(parts)
        if s.get("teranode_cites"):
            line += "; " + "; ".join(at(data, c) for c in s["teranode_cites"])
        line += "."
        if s.get("note"):
            line += f" [D] {s['note'][0].upper() + s['note'][1:]}."
        line += f" Evidence: {evidence(data, s['evidence'], check5)}."
        out.append(line)
    wire = sorted(n for n in os.listdir(os.path.join(ROOT, "corpus", "wire")) if n.endswith(".jsonl") and n != "reads.jsonl")
    out += [
        f"- **The client formats of #86** [M]: EF, BUMP, BEEF, Atomic BEEF and the TSC proof are client encodings that no "
        "consensus or policy rule of a node reads (`spec/wire-views.md`), so a client's encoding is the same whichever node "
        "it talks to; the corpus: " + ", ".join(f"`corpus/wire/{n}` {len(jsonl('corpus/wire/' + n))} vectors" for n in wire) + ".",
    ]
    # the chain-level design row a client sees on the best tip (#92's row f4, the maintainers' `92: design` on card Z10)
    obl_divs = {d["id"]: d for d in read_json(OBLIGATIONS)["divergences"]}
    parked = obl_divs.get("premature-block-parked")
    if parked is None or parked["class"] != "design":
        raise SystemExit("node_contract: the design row premature-block-parked is not in the obligation list")
    out += [
        f"- **The best tip, for a window** [SRC]: `getbestblockhash` on both nodes (the Blocks line above). [D] Teranode validates "
        "a block's spends where the outputs live, at its UTXO store's spend gate (`stores/utxo/sql/sql.go:2477-2478` at "
        f"Teranode `{tsh}`) (the Aerospike store's twin: `stores/utxo/aerospike/teranode.lua:325-326` at `{tsh}`), and has no block-context maturity check of its own at the pin; the reference refuses a block "
        "spending an immature coinbase at its block-context check (`COINBASE_MATURITY = 100`, `src/consensus/consensus.h:75`; "
        f"`src/validation.cpp:2617-2625` at bitcoin-sv `{bsh}`). So for a window Teranode's best-tip answer can name a block "
        "the reference refuses, until a valid branch overtakes it: " + "; ".join(leg_line(w) for w in parked["witnesses"])
        + ", the row's window 4 s with 0 blocks built on the parked block (#92's closing comment 6240676983). The hold is policy, a design row by the maintainers' "
        f"ruling of 2026-10-17 on card Z10 (`{parked['id']}`, {parked['issue']}, section 5); the maturity rule is consensus "
        "(section 1). A client reads a coinbase spend's block by its depth on the chain both nodes follow, never by one "
        "node's best-tip answer alone.",
        "",
        "## 2b. Surfaces one implementation adds",
        "",
        f"[D] {data['sections']['2b'][0].upper() + data['sections']['2b'][1:]}. Each is a ledger row ruled `new`.",
        "",
    ]
    for r in sec2b:
        out.append(f"- **`{r['id']}`: {esc(r['surface'])}.** {r['what']} [SRC] "
                   + "; ".join(ta.cite(data, c) for c in r["present"]) + f". Ruled {owner_word(r)}.")
    # section 3
    gaps = [r for r in sec3 if ta.effective(r) == "gap"]
    others = [r for r in sec3 if ta.effective(r) != "gap"]
    out += [
        "",
        "## 3. Beyond the protocol",
        "",
        f"[D] {data['sections']['3'][0].upper() + data['sections']['3'][1:]}. Each line is a ledger row: the surface, the "
        "maintainers' ruling (by the rule of 2026-10-15, `ruling_rule` in the ledger), the design reason with its cites, the "
        "measured answers where a run has them, and what a client does instead, in two groups: the client-facing "
        "surfaces, then the operator and peer surfaces. The ruling words are the ledger's: `gap` marks a difference a "
        "client feels when it moves from one node to the other, `dropped` a surface whose information reaches a client by "
        "another carrier or that only an operator or a peer uses; neither word says that either node is wrong.",
        "",
        "### The client-facing surfaces",
        "",
    ]
    for group in (gaps, others):
        if group is others:
            out += ["", "### The operator and peer surfaces", ""]
        for r in group:
            d = r["design"] if r.get("design") else None
            out.append(f"- **`{r['id']}`: {esc(r['surface'])}.** Ruled {owner_word(r)}.")
            if d:
                out.append(f"  - **By design.** {d['reason']} " + "; ".join(at(data, c) for c in d["cites"]) + ".")
            out += measured_lines(r)
            if d:
                out.append(f"  - **The client.** {d['client']}")
    out += [
        "",
        "**Build on section 2, never on section 3.** A client that takes its verdicts from the broadcast, its blocks and "
        "headers from the chain and its proofs from the node, and checks each proof against its own headers, runs the "
        "same on SV-node and on Teranode; a surface of section 3 is a convenience of one node, and a client that needs it "
        "needs that node.",
        "",
        "## 4. For the stack's machines",
        "",
        "[D] One line per machine of the chain's north star page, section 5 ("
        f"`{data['contract']['north_stars']['bsv']['stack_page']['path']}`, the sha256 in section 0): the sections it may rely on, the section-3 rows that would have bitten it had it been "
        "built on SV-node's conveniences, and why.",
        "",
        "| machine | may rely on | section-3 rows that would have bitten it | why |",
        "|---|---|---|---|",
    ]
    for name, secs, bit, why in MACHINES:
        rely = ", ".join(f"section {s}" for s in secs) or "no node section"
        rows = ", ".join(f"`{x}`" for x in bit) or "none"
        out.append(f"| {name} | {rely} | {rows} | {esc(why)} |")
    n_cites = sum(len((r.get("design") or {}).get("cites", [])) for r in data["rows"])
    out += [
        "",
        f"Counts [M]: {len(data['rows'])} ledger rows, {len(sec2b)} in section 2b and {len(sec3)} in section 3 ({len(gaps)} "
        f"ruled `gap`, {len(others)} ruled `dropped`); {sum(1 for r in data['rows'] if r.get('design'))} designs with "
        f"{n_cites} cites; {sum(1 for r in data['rows'] if r.get('measured'))} rows measured.",
    ]
    out += refinement(data, theorems_text)
    return "\n".join(out)


OBLIGATIONS = os.path.join("corpus", "teranode", "obligations.json")
KIND_ORDER = ("theorem", "witness", "design", "chain-split", "report", "open")


def theorem_loc(name, text):
    """The `spec/theorems.md` entry of a fully qualified theorem: its short name under the namespace's directory."""
    parts = name.split(".")
    prefix = "lean/" + "/".join(parts[:-1])
    for m in re.finditer(r"^### `" + re.escape(parts[-1]) + r"` \(`([^`]+)`\)$", text, re.M):
        if m.group(1).startswith(prefix):
            return m.group(1)
    raise SystemExit(f"node_contract: theorem {name} has no entry in spec/theorems.md under {prefix}")


def withheld_at_export(path):
    """True when tools/export_withheld.txt names the path (the public edition lacks it by the owner's word)."""
    import export_public  # the sibling tool; its lists are the export's
    try:
        rules = export_public.load_withheld(export_public.WITHHELD)
    except (OSError, SystemExit):
        return False
    return export_public.group_of(rules, path) is not None


def short(name):
    return name.split(".")[-1]


def leg_line(lg):
    where = f"`{lg['record']}`" if lg["landed"] else f"`{lg['record']}` (on its branch, not on `main` at this commit)"
    return f"{lg['issue']}'s leg, {lg['rows']}: {lg['counts']} [M] ({where})"


def refinement(data, theorems_text):
    """Section 5: the refinement relation's obligation list (#88), one line per row of #87's map."""
    obl = read_json(OBLIGATIONS)
    text = theorems_text if theorems_text is not None else read_text("spec/theorems.md")
    ledger = {r["id"]: r for r in data["rows"]}
    divs = {d["id"]: d for d in obl["divergences"]}
    for row in obl["rows"]:
        for e in row["ledger"]:
            r = ledger.get(e["id"])
            if r is None or r["map_id"] != row["row"] or ta.effective(r) != e["word"]:
                raise SystemExit(f"node_contract: obligation {row['row']}: ledger row {e['id']} is not keyed to it with {e['word']!r}")
        for lg in row["legs"]:
            if lg["landed"] and not os.path.exists(os.path.join(ROOT, lg["record"])):
                if withheld_at_export(lg["record"]):
                    # the public edition: the record is on the withheld list (tools/export_withheld.txt), so its absence
                    # is the export's, said by name (the hosted gate of 2026-10-26); never a pass, never a stop
                    print(f"node_contract: obligation {row['row']}: the leg's record {lg['record']} is withheld at export: "
                          "SKIPPED BY NAME (the private history holds it)")
                    continue
                raise SystemExit(f"node_contract: obligation {row['row']}: the leg's record {lg['record']} is absent")
        if row["kind"] == "theorem":
            for n in row["names"]:
                theorem_loc(n, text)
    c = obl["counts"]
    out = [
        "",
        "## 5. The refinement: every row of the module map, one obligation each (#88)",
        "",
        "**Generated from `corpus/teranode/obligations.json`, which `chaincheck --obligations-json` emits from "
        "`lean/BsvChain/Teranode/Refinement.lean` and `chaincheck --refinement` compares with the list, the map "
        "(`corpus/teranode/map.json`, #87) and this ledger.** [M] 2026-10-17 (#88's close).",
        "",
        "[D] The relation, in words: Teranode's state as the components model it (the store's records with their marks, the "
        "blocks table with its best header and tips, the current-chain read, block assembly, the FSM state, the alert "
        "service's store and ban list, the Kafka events) is mapped onto the reference machine's state and its derived status "
        "(`observe`, `abstractStatus`), and `Refines` holds when every transaction's observed state is the reference's status "
        "read through #74's column, the two candidate sets correspond, the current-chain read agrees with the rows' ancestry and "
        "the FSM is RUNNING. Each Teranode transition is a stutter of the relation (the reference unmoved), suspends "
        "observation, keeps the frozen projection agreeing, simulates a named reference step (owed, with its owner), or leaves "
        "the relation by a divergence: " + ", ".join(
            f"`{f['family']}` " + {"stutter": "a stutter", "suspends": "suspends", "agrees outside the relation": "agrees outside the relation",
                                   "owed": f"owed ({area(f.get('owner'))})", "departs": "departs"}[f["rel"]]
            + (f" with `{f['divergence']}`" if f["divergence"] else "")
            for f in obl["families"]) + ".",
        "",
        f"Counts [M]: {c['rows']} rows: " + ", ".join(f"{c[k]} {k}" for k in KIND_ORDER) + f"; {len(obl['divergences'])} "
        f"divergences ({sum(1 for d in obl['divergences'] if d['class'] == 'chain-split')} chain-split, "
        f"{sum(1 for d in obl['divergences'] if d['class'] == 'design')} design); "
        f"{sum(1 for r in obl['rows'] if r['rerun'])} rows for #95's per-release re-run. The kinds: "
        + "; ".join(f"`{k}`, {obl['kinds'][k]}" for k in KIND_ORDER) + ".",
        "",
        "### The chain-split rows: the two nodes decide the same blocks differently (consensus)",
        "",
    ]
    for cls, head in (("chain-split", None), ("design", "### The design rows from the measured legs: Teranode's reason before the difference (policy)")):
        if head:
            out += ["", head, ""]
        for d in obl["divergences"]:
            if d["class"] != cls:
                continue
            rows = [r["row"] for r in obl["rows"] if d["id"] in r["divergences"]]
            model = ", ".join(f"`{short(n)}`" for n in d["model"]) or "none (the leg alone)"
            label = d["label"] if d.get("rule_label", d["label"]) == d["label"] else f"{d['label']} for the hold, the rule {d['rule_label']}"
            out.append(f"- **`{d['id']}` ({d['issue']}; map row " + ", ".join(f"`{r}`" for r in rows) + f"; {label}).** {d['reason']}.")
            for w in d["witnesses"]:
                out.append(f"  - **Witness.** {leg_line(w)}.")
            out.append(f"  - **Model.** {model}.")
    out += [
        "",
        "The ledger's design rows (section 3 and section 2b above carry each one's reason and cites): "
        + "; ".join(f"`{r['row']}` (" + ", ".join(f"`{e['id']}` `{e['word']}`" for e in r["ledger"]) + ")"
                    for r in obl["rows"] if r["kind"] == "design" and r["ledger"] and not r["divergences"]) + ".",
        "",
        "### The list",
        "",
        "| row | issue | label | kind | obligation | re-run by #95 |",
        "|---|---|---|---|---|---|",
    ]
    for r in obl["rows"]:
        k = r["kind"]
        if k == "theorem":
            ob = ", ".join(f"`{short(n)}`" for n in r["names"])
            if r["premises"]:
                ob += f", {r['premises']}"
            if r["legs"]:
                ob += "; measured: " + "; ".join(f"{lg['issue']} {lg['rows']}" for lg in r["legs"])
            if r["model_witnesses"]:
                ob += "; model witnesses " + ", ".join(f"`{short(n)}`" for n in r["model_witnesses"])
        elif k == "witness":
            ob = "; ".join(leg_line(lg) for lg in r["legs"])
        elif k in ("design", "chain-split"):
            parts = [f"`{x}` ({divs[x]['issue']})" for x in r["divergences"]]
            parts += [f"ledger `{e['id']}` ruled `{e['word']}`" for e in r["ledger"]]
            if r["page"]:
                parts.append(f"`{r['page']}`")
            ob = "; ".join(parts)
            if r["names"]:
                ob += "; support " + ", ".join(f"`{short(n)}`" for n in r["names"])
        elif k == "report":
            ob = "the per-release divergence gate (#95)"
        else:
            ob = f"{r['statement']} (" + ("waits on the maintainers' ruling" if r["owner"] == "the owner" else f"owed: {area(r['owner'])}") + ")"
            if r["legs"]:
                ob += "; measured: " + "; ".join(f"{lg['issue']} {lg['rows']}" for lg in r["legs"])
        if r["owed_halves"]:
            ob += "; owed: " + "; ".join(f"{h['statement']} ({area(h['owner'])})" for h in r["owed_halves"])
        out.append(f"| `{r['row']}` | {r['issue']} | {r['label']} | {k} | {esc(ob)} | {'yes' if r['rerun'] else 'no'} |")
    opened = [r for r in obl["rows"] if r["kind"] == "open"]
    owners = sorted({r["owner"] for r in opened})
    out += [
        "",
        "**For #95's gate.** A re-run on a new release re-measures the rows marked yes: the report rows on the column, and every "
        "row a leg measured, on that leg's scenario; a row whose answer moves is a new witness for its kind.",
        "",
        "**Open.** " + "; ".join(f"{area(o)}: " + ", ".join(f"`{r['row']}`" for r in opened if r["owner"] == o) for o in owners)
        + ". The owed halves on theorem and design rows: "
        + "; ".join(f"`{r['row']}` ({area(h['owner'])})" for r in obl["rows"] for h in r["owed_halves"]) + ".",
        "",
    ]
    return out


def main():
    page = render()
    if "--check" in sys.argv:
        ok = os.path.exists(PAGE) and open(PAGE).read() == page
        print(f"node_contract --check: {'OK' if ok else 'STALE'}")
        sys.exit(0 if ok else 1)
    with open(PAGE, "w") as f:
        f.write(page)
    print(f"node_contract: wrote {os.path.relpath(PAGE, ROOT)}")


if __name__ == "__main__":
    main()
