#!/usr/bin/env python3
"""specgen (#17): the specification document, generated from the Lean sources.

Reads, never hand-copies:
  * the opcode table `lean/BsvScript/Opcodes.lean` (every `def OP_X : Nat := 0x..`
    and `Op.hasCase`'s ranges);
  * every docstring of `lean/{BsvScript,BsvChain}/**/*.lean` and `lean/Bsvs/Trace.lean`
    (`/-- ... -/` before a declaration, `/-! ... -/` for a module), with the
    `[SRC]` lines they cite (a bare `NNN` or `NNN–MMM` in backticks is a line of the
    module's default file, `src/script/interpreter.cpp` unless the module docstring says
    "Bare line numbers are `<file>`"; a `:NNN` continues the file the docstring last named;
    a bare single digit or a number with a leading zero is a value; `file:line` otherwise, labelled with its release when
    the docstring cites it at another release, "at 0.3.24"; `cites_of`);
  * the rule vocabulary of `corpus/INDEX.md` §2 and the `rule` of every entry
    of the generated corpora (`corpus/{seed,flow,arith,stack,crypto,bytes}`, the
    hand-built `corpus/eras` (#20/#23), #26's generator families `corpus/gen` and the constructed
    `corpus/witnesses/policy-defaults.jsonl`, #21);
  * the witnesses' manifest `corpus/witnesses/manifest.json` (#15).

Carries by hand, NOT read from any page (#32's final lens on Lean B, NEW-5): the
opcode families (`FAMILIES`, the module, issue and citation per byte range) and
the era history (`history_of`), transcribed in this file from `docs/DESIGN.md` §3;
a change to §3 or to a family's module is copied here by hand, and no leg compares
the two.

Writes `spec/` (deterministic; `make spec` regenerates, `make check`'s `spec`
leg refuses a stale tree): `README.md` (the index), `opcodes/OP_X.md` (one page
per opcode: byte, family module, era history, the semantics from the docstrings
that name it with their citations, the corpus entries by rule, the witnesses),
`rules.md` (every rule with its citation and its corpus count; a rule without an
entry FLAGGED: #26's input), `theorems.md` (every theorem, with its explainer where it has one, and for each
chain-layer theorem its quantification line read from its statement, #77: `chain_quantification`),
`modules.md` (the module docstrings), `flags.md`, `errors.md`; and `teranode-map.md` (#87), rendered by
`tools/teranode_map.py` from `corpus/teranode/map.json` (the table, not the Lean sources); `teranode-absences.md` (#96) and
`node-client-contract.md` (#140), rendered by `tools/teranode_absences.py` and `tools/node_contract.py` from
`corpus/teranode/absences.json`.

Run from the repo root: tools/specgen.py [--out spec] [--check]
"""
import glob, json, os, re, sys
from collections import OrderedDict, defaultdict

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PIN = "bitcoin-sv v1.2.3 `6504a3af` (`docs/PROVENANCE.md`)"

# ---------------------------------------------------------------- the opcode table
def read_opcodes():
    src = open(f"{ROOT}/lean/BsvScript/Opcodes.lean").read()
    ops = OrderedDict()
    for m in re.finditer(r"^def (OP_[A-Z0-9_]+) : Nat := (0x[0-9a-f]+)$", src, re.M):
        name, val = m.group(1), int(m.group(2), 16)
        if name in ("OP_FALSE", "OP_TRUE", "OP_INVALIDOPCODE"):
            continue
        ops[name] = val
    return ops

# the case-label map, transcribed by hand from DESIGN §3 (the family module and the issue per byte range; never read from the page)
FAMILIES = [
    ((0x00, 0x4e), "push", "BsvScript.Machine", "#8", "the pushes: `473–481`; minimality `331–358`"),
    ((0x4f, 0x4f), "push", "BsvScript.Machine", "#8", "`488–507`"),
    ((0x50, 0x50), "reserved", "BsvScript.Machine", "#8", "the `default:` `1795`; not counted `466`"),
    ((0x51, 0x60), "push", "BsvScript.Machine", "#8", "`488–507`"),
    ((0x61, 0x6a), "flow", "BsvScript.Machine", "#8", "§2.4 of DESIGN"),
    ((0x6b, 0x7d), "stack", "BsvScript.Ops.Stack", "#10", "`876–1055`"),
    ((0x7e, 0x82), "splice", "BsvScript.Ops.Splice", "#10", "`1687–1792`, `1057–1064`"),
    ((0x83, 0x88), "bitwise", "BsvScript.Ops.Bitwise", "#9", "`1069–1217`"),
    ((0x89, 0x8a), "reserved", "BsvScript.Machine", "#8", "the `default:` `1795`"),
    ((0x8b, 0x92), "arithmetic (unary)", "BsvScript.Ops.Arith", "#9", "`1222–1275`"),
    ((0x93, 0x97), "arithmetic (binary)", "BsvScript.Ops.Arith", "#9", "`1277–1378`"),
    ((0x98, 0x99), "bitwise (shifts)", "BsvScript.Ops.Bitwise", "#9", "`1121–1187`, `65–117`"),
    ((0x9a, 0xa4), "arithmetic (binary)", "BsvScript.Ops.Arith", "#9", "`1277–1378`"),
    ((0xa5, 0xa5), "arithmetic (ternary)", "BsvScript.Ops.Arith", "#9", "`1380–1399`"),
    ((0xa6, 0xaa), "crypto (hashes)", "BsvScript.Ops.Crypto", "#11", "`1402–1443`"),
    ((0xab, 0xab), "crypto (separator)", "BsvScript.Machine", "#11", "`1445–1448`"),
    ((0xac, 0xaf), "crypto (signatures)", "BsvScript.Ops.Crypto", "#11", "`1450–1682`"),
    ((0xb0, 0xb0), "expansion (NOP)", "BsvScript.Machine", "#8", "`765–771`"),
    ((0xb1, 0xb2), "expansion (lock time)", "BsvScript.Machine", "#22", "`519–597`"),
    ((0xb3, 0xb7), "expansion (Chronicle)", "BsvScript.Ops.Expansion", "#18", "`609–764`"),
    ((0xb8, 0xb9), "expansion (NOP)", "BsvScript.Machine", "#8", "`765–771`"),
]

def family_of(val):
    for (lo, hi), fam, mod, issue, src in FAMILIES:
        if lo <= val <= hi:
            return fam, mod, issue, src
    return "undefined", "BsvScript.Machine", "#18", "the `default:` `1795`"

# the era history, transcribed by hand from DESIGN §3 (the three UTXO eras and the spending era's gate; never read from the page)
def history_of(name, val):
    rows = []
    if val <= 0x4e:
        rows.append("pre-Genesis UTXO: a push above 520 bytes is `SCRIPT_ERR_PUSH_SIZE` (`455–456`, `script.h:29`); post-Genesis: the memory budget only (`limitedstack.cpp:194–207`)")
        rows.append("under MINIMALDATA and the version gate the push must be the minimal form (`CheckMinimalPush` `331–358`, `474–479`; MINIMALDATA is a POLICY flag, never in a block word)")
    if name in ("OP_2MUL", "OP_2DIV"):
        rows.append("disabled unless the UTXO era is post-Chronicle (`IsOpcodeDisabled` `360–375`); pre-Genesis it fails even unexecuted (`470–471`)")
    if name == "OP_RETURN":
        rows.append("pre-Genesis UTXO: `SCRIPT_ERR_OP_RETURN` (`867–869`); post-Genesis: a top-level `OP_RETURN` ends the script as success (`858–861`), inside a conditional nothing executes but the balance is enforced (`865`, `482`)")
    if name in ("OP_VER", "OP_VERIF", "OP_VERNOTIF"):
        rows.append("pre-Chronicle UTXO era: `SCRIPT_ERR_BAD_OPCODE` (`OP_VER` `598–608`; `OP_VERIF`/`OP_VERNOTIF` `773–781`, even unexecuted pre-Genesis); post-Chronicle: the version push / the version comparison (`603–606`, `806–812`)")
    if name == "OP_ELSE":
        rows.append("post-Genesis a second `OP_ELSE` for the same `OP_IF` is unbalanced (`conditional_tracker.cpp:51–55`, `829–831`); pre-Genesis every further `OP_ELSE` toggles again (`61–64`)")
    if name in ("OP_CHECKLOCKTIMEVERIFY", "OP_CHECKSEQUENCEVERIFY"):
        rows.append("live for pre-Genesis UTXOs under the flag (`520`, `563`); a NOP for post-Genesis UTXOs, discouraged under DISCOURAGE_UPGRADABLE_NOPS (policy)")
    if name in ("OP_NOP1", "OP_NOP9", "OP_NOP10"):
        rows.append("a no-op; `SCRIPT_ERR_DISCOURAGE_UPGRADABLE_NOPS` under the policy flag (`765–771`)")
    if name in ("OP_SUBSTR", "OP_LEFT", "OP_RIGHT", "OP_LSHIFTNUM", "OP_RSHIFTNUM"):
        landed = os.path.exists(f"{ROOT}/lean/BsvScript/Ops/Expansion.lean")
        tail = "in the evaluator since #18 (`lean/BsvScript/Ops/Expansion.lean`); at v1.2.3 `6504a3af`, `OP_SUBSTR`/`OP_LEFT`/`OP_RIGHT` use the fixed-width reader: at most eight bytes read as sign-magnitude; nine require a pure sign byte and a magnitude below 2^63, or exactly 2^63 with a negative sign; longer operands refuse `SCRIPT_ERR_SCRIPTNUM_OVERFLOW` (`int_serialization.h:61–118`, `script_num.cpp:80–91`, `interpreter.cpp:1807–1809`). The previous pin's reading and measurements are retained in material withheld from the public edition at the maintainers' request (group `d8-node-team-discretion`)" if landed else "**not yet in the evaluator (#18)**"
        rows.append(f"pre-Chronicle UTXO era: a no-op (discouraged under the policy flag); post-Chronicle: executes (`609–764`); {tail}")
    if 0x6b <= val <= 0xaf or val in (0x4f,) or 0x51 <= val <= 0x60:
        if val >= 0x61:
            rows.append("counts against `MaxOpsPerScript` executed or not (`466–467`): 500 pre-Genesis, unbounded post-Genesis at consensus (`docs/PARAMETERS.md` §1)")
    if name in ("OP_CHECKSIG", "OP_CHECKSIGVERIFY", "OP_CHECKMULTISIG", "OP_CHECKMULTISIGVERIFY"):
        rows.append("the version gate: LOW_S (`285`), NULLFAIL (`1493`, `1643`), NULLDUMMY (`1666`) bind only when `EnforceNonMalleability` (`40–44`) holds, i.e. pre-Chronicle or version ≤ 1; the strict DER shape and the hash-type rules are ungated (`275–280`, `291–307`)")
        rows.append("post-Chronicle a check executing in the unlocking script signs the unlock from the last separator plus the locking script (`1474–1481`)")
    if name in ("OP_IF", "OP_NOTIF"):
        rows.append("MINIMALIF (never set by the node at the pin) under the version gate (`796–804`)")
    if 0x8b <= val <= 0xa5:
        rows.append("operands read as `CScriptNum` with the era's width (4 pre-Genesis, 750,000 post-Genesis, 32,000,000 post-Chronicle) and, under MINIMALDATA with the gate, the minimal check (`script_num.cpp:53–89`)")
    if val >= 0xba:
        rows.append("`FIRST_UNDEFINED_OP_VALUE` `0xba` (`opcodes.h:152`): `SCRIPT_ERR_BAD_OPCODE` when executed (`1795`); counts against the op limit (`466`)")
    return rows

# ---------------------------------------------------------------- docstrings
# a docstring never runs across its own `-/`: a docstring on a constructor or a field (followed by no declaration
# keyword) matches nothing, where `.*?` once ran on to the next declaration's (#32's lens 1, part A: the `OP_RETURN`
# page rendered `StepR`'s constructor docstrings under `HookR` and `NodeConfig`'s fields under `defaultSpendHeight`)
DECL = re.compile(r"/--((?:(?!-/).)*?)-/\s*(?:@\[[^\]]*\]\s*)*(?:private\s+|protected\s+|noncomputable\s+)?(theorem|def|structure|inductive|abbrev|partial def|instance|example|opaque)\s+([\w.'!?]+)", re.S)
MODDOC = re.compile(r"/-!(.*?)-/", re.S)
# a theorem declaration at a line's start, behind attributes or a modifier (the grep of theorem_counts)
THM = re.compile(r"^[ \t]*(?:@\[[^\]]*\]\s*)*(?:private\s+|protected\s+)?theorem\s+([\w.'!?]+)", re.M)
# a module's own rule for its bare line numbers, e.g. "Bare line numbers are `src/validation.cpp` at the pin"
BAREDEF = re.compile(r"Bare line numbers are `([^`]+)`")

def clean(doc):
    lines = [l.rstrip() for l in doc.strip("\n").split("\n")]
    # drop a common leading indentation
    return "\n".join(lines).strip()

def public_sources():
    """Public spec inputs exclude the separately tested, withheld history module."""
    history = f"{ROOT}/lean/BsvScript/Numbers/History.lean"
    return [p for p in sorted(glob.glob(f"{ROOT}/lean/BsvScript/**/*.lean", recursive=True)
                             + glob.glob(f"{ROOT}/lean/BsvChain/**/*.lean", recursive=True))
            if p != history] + [f"{ROOT}/lean/Bsvs/Trace.lean"]

def lean_code(src):
    """Mask comments and quoted literals, retaining source offsets and line numbers."""
    out = list(src)
    i, depth = 0, 0
    while i < len(src):
        start = i
        if depth:
            if src.startswith("/-", i):
                depth += 1
                i += 2
            elif src.startswith("-/", i):
                depth -= 1
                i += 2
            else:
                i += 1
        elif src.startswith("/-", i):
            depth = 1
            i += 2
        elif src.startswith("--", i):
            end = src.find("\n", i)
            i = len(src) if end < 0 else end
        elif src[i] == '"':
            i += 1
            while i < len(src):
                if src[i] == "\\":
                    i = min(i + 2, len(src))
                elif src[i] == '"':
                    i += 1
                    break
                else:
                    i += 1
        elif src[i] == "'" and (char := re.match(r"'(?:\\.|[^'\\])'", src[i:])):
            i += len(char.group())
        else:
            i += 1
            continue
        out[start:i] = ["\n" if c == "\n" else " " for c in src[start:i]]
    return "".join(out)

def read_docs():
    files = public_sources()
    decls, mods = [], []
    for f in files:
        src = open(f).read()
        code = lean_code(src)
        rel = os.path.relpath(f, ROOT)
        module = rel[len("lean/"):-len(".lean")].replace("/", ".")
        bare = "interpreter.cpp"
        for m in MODDOC.finditer(src):
            mods.append((module, rel, clean(m.group(1))))
            dm = BAREDEF.search(" ".join(m.group(1).split()))
            if dm:
                bare = os.path.basename(dm.group(1))
        documented = set()
        for m in DECL.finditer(src):
            if code[m.start(2):m.end(2)] != m.group(2):
                continue
            decls.append({"module": module, "file": rel, "kind": m.group(2), "name": m.group(3), "doc": clean(m.group(1)),
                          "line": src[:m.start()].count("\n") + 1, "bare": bare, "sig": statement(code, m.end(3))})
            if m.group(2) == "theorem":
                documented.add(m.group(3))
        # a theorem with no docstring of its own is still a theorem of the spec: listed, and marked (rule 7)
        for m in THM.finditer(code):
            if m.group(1) not in documented:
                decls.append({"module": module, "file": rel, "kind": "theorem", "name": m.group(1), "doc": "",
                              "line": src[:m.start()].count("\n") + 1, "bare": bare, "undocumented": True,
                              "sig": statement(code, m.end(1))})
    return decls, mods

# ---------------------------------------------------------------- the quantification of a chain theorem (#77)
OPEN, CLOSE = "([{⟨⦃", ")]}⟩⦄"

def statement(code, start):
    """A declaration's statement in the masked code: from the end of its name to the `:=` (or a `|` arm, or
    `where`) at bracket depth 0, whitespace collapsed."""
    depth, i = 0, start
    while i < len(code):
        c = code[i]
        if c in OPEN:
            depth += 1
        elif c in CLOSE:
            depth -= 1
        elif depth == 0 and (code.startswith(":=", i) or re.match(r"\n\s*\|", code[i:i + 80])
                             or re.match(r"\swhere\b", code[i:i + 7])):
            break
        i += 1
    return " ".join(code[start:i].split())

def binders(sig, conclusion=True):
    """The statement's binder groups `(a b : T)`, `{a : T}`, `[a : T]`, `⦃a : T⦄` before its conclusion, and its
    conclusion (after the earliest `:` at depth 0): ([(names, type)], conclusion)."""
    groups, depth, i, begin = [], 0, 0, None
    while i < len(sig):
        c = sig[i]
        if c in OPEN:
            if depth == 0:
                begin = i + 1
            depth += 1
        elif c in CLOSE:
            depth -= 1
            if depth == 0 and begin is not None:
                inner, d, j = sig[begin:i], 0, 0
                for j, ch in enumerate(inner):
                    d += ch in OPEN
                    d -= ch in CLOSE
                    if ch == ":" and d == 0 and not inner.startswith(":=", j):
                        groups.append((inner[:j].split(), inner[j + 1:].strip()))
                        break
                begin = None
        elif depth == 0 and c == ":" and conclusion:
            return groups, sig[i + 1:].strip()
        i += 1
    return groups, ""

# the four inputs #77 names, the type each is bound at; a bundle is a structure of the chain layer carrying any of them
SLOTS = ("params", "cfg", "oracle", "now")
SLOT_TYPE = {"params": "ChainParams", "cfg": "NodeConfig", "oracle": "ScriptOracle"}
# a constant the statement may fix a slot to: a network's record (`ChainParams.regtest`, `.regtest`, the network tables
# `NetworkData`/`DepthNetwork`), the census defaults `NodeConfig.defaults`, the evaluator as the oracle, a literal `now`
NETWORKS = r"(?:mainnet|testnet|stn|regtest)"
FIXES = {
    "params": re.compile(r"(?<![\w.])(?:(?:BsvChain\.)?(?:ChainParams|NetworkData|DepthNetwork))?\.(" + NETWORKS + r")\b"),
    "cfg": re.compile(r"(?<![\w.])(?:BsvChain\.)?NodeConfig\.(defaults)\b"),
    "oracle": re.compile(r"(?<![\w.])(evalOracle)\b"),
    "now": re.compile(r"(?<![\w.])now := (-?\d+)\b"),
}

def plain_type(t):
    t = t.strip()
    return t[len("BsvChain."):] if t.startswith("BsvChain.") else t

def chain_bundles():
    """[M] The chain layer's structures and the slots their fields carry, read from `lean/BsvChain/**` (a field
    `params : ChainParams`, `cfg : NodeConfig`, an oracle field `: ScriptOracle`, a field named `now`)."""
    out = {}
    for f in sorted(glob.glob(f"{ROOT}/lean/BsvChain/**/*.lean", recursive=True)):
        code = lean_code(open(f).read())
        for m in re.finditer(r"^structure (\w+)(?:[^\n]*)\n((?:[ \t]+[^\n]*\n|\n)*)", code, re.M):
            slots = set()
            for fm in re.finditer(r"^  (\w+) : ([\w.]+)", m.group(2), re.M):
                name, typ = fm.group(1), plain_type(fm.group(2))
                slots.update(s for s, t in SLOT_TYPE.items() if typ == t)
                if name == "now":
                    slots.add("now")
            if slots:
                out[m.group(1)] = slots
    # an inductive predicate whose constructors bind a slot or a bundle (`Reachable`: every step's `ctx` and
    # oracle are the constructor's arguments) quantifies those slots in a statement that names it
    for f in sorted(glob.glob(f"{ROOT}/lean/BsvChain/**/*.lean", recursive=True)):
        code = lean_code(open(f).read())
        for m in re.finditer(r"^inductive (\w+)[^\n]*\n((?:[ \t]+[^\n]*\n|\n)*)", code, re.M):
            slots = set()
            for names, typ in binders(" ".join(m.group(2).split()), conclusion=False)[0]:
                t = plain_type(typ)
                slots.update(s for s, st in SLOT_TYPE.items() if t == st)
                for b, bs in list(out.items()):
                    if t == b:
                        slots |= bs
                if "now" in names:
                    slots.add("now")
            if slots:
                out[m.group(1)] = slots
    return out

def fixture_fixes(decls):
    """[M] The constants each chain-layer definition's statement and body fix, closed under the definitions it names
    (`staleRunContext` fixes the network, the configuration and `now`; a run built on it inherits them). A default
    argument or a structure field's default is not a definition's body and is left to `tools/chain_lint.py`."""
    bodies = {}
    for f in sorted(glob.glob(f"{ROOT}/lean/BsvChain/**/*.lean", recursive=True)):
        if f.endswith("/Params.lean"):
            continue
        code = lean_code(open(f).read())
        for m in re.finditer(r"^(?:@\[[^\]]*\]\s*)*(?:private\s+|protected\s+|noncomputable\s+)*(?:def|abbrev)\s+([\w.'!?]+)", code, re.M):
            sig = statement(code, m.end(1))
            rest = code[m.end(1) + len(sig):]
            body = re.split(r"\n(?=\S)", rest, maxsplit=1)[0]
            bodies[m.group(1)] = (binders(sig)[1] if ":" in sig else "") + " " + body
    fixed = {name: {s: set(p.findall(text)) for s, p in FIXES.items()} for name, text in bodies.items()}
    changed = True
    while changed:
        changed = False
        seeds = [n for n, v in fixed.items() if any(v.values())]
        for name, text in bodies.items():
            for other in seeds:
                if other != name and re.search(r"(?<![\w.])" + re.escape(other) + r"(?![\w'!?])", text):
                    for s in SLOTS:
                        if not fixed[other][s] <= fixed[name][s]:
                            fixed[name][s] |= fixed[other][s]
                            changed = True
    return {n: v for n, v in fixed.items() if any(v.values())}

def quantification(d, bundles, fixtures):
    """[M] Per slot: `bound` (a binder of its type, or of a bundle carrying it, quantifies it), `fixed` (the statement
    or a definition it names fixes it to a constant), or absent (no function of the statement takes it). A slot both
    bound and fixed is fixed: a hypothesis `ctx.params = .regtest` narrows the binder to the network."""
    groups, _ = binders(d["sig"])
    bound = defaultdict(list)
    for names, typ in groups:
        t = plain_type(typ)
        for s, st in SLOT_TYPE.items():
            if t == st:
                bound[s] += names
        for b, slots in bundles.items():
            if t == b:
                for s in slots:
                    bound[s] += [f"{n} : {b}" for n in names]
        if "now" in names:
            bound["now"].append("now")
    # a predicate binding the slots in its constructors, named anywhere in the statement (`Reachable s`)
    for b, slots in bundles.items():
        if re.search(r"(?<![\w.])" + re.escape(b) + r"(?![\w'!?])", d["sig"]) and not any(plain_type(t) == b for _, t in groups):
            for s in slots:
                bound[s].append(f"the constructors : {b}")
    fixed = defaultdict(set)
    for s, p in FIXES.items():
        fixed[s].update(p.findall(d["sig"]))
    for name, fx in fixtures.items():
        if re.search(r"(?<![\w.])" + re.escape(name) + r"(?![\w'!?])", d["sig"]):
            for s in SLOTS:
                fixed[s] |= fx[s]
    return {s: ("fixed", sorted(fixed[s])) if fixed[s] else ("bound", bound[s]) if bound[s] else ("absent", [])
            for s in SLOTS}

def quant_class(q):
    if any(v[0] == "fixed" for v in q.values()):
        return "fixed"
    return "quantified" if any(v[0] == "bound" for v in q.values()) else "free"

FIXED_WORD = {"mainnet": "mainnet's record", "testnet": "testnet's record", "stn": "STN's record",
              "regtest": "regtest's record", "defaults": "the census defaults `NodeConfig.defaults`",
              "evalOracle": "the evaluator `evalOracle`"}

def quant_line(d, q, general):
    """The theorem's quantification in plain words, generated from its statement (never typed by hand)."""
    every = [s for s in SLOTS if q[s][0] == "bound"]
    fixed = [s for s in SLOTS if q[s][0] == "fixed"]
    absent = [s for s in SLOTS if q[s][0] == "absent"]
    def words(xs):
        xs = [f"`{x}`" for x in xs]
        return xs[0] if len(xs) == 1 else ", ".join(xs[:-1]) + " and " + xs[-1]
    parts = []
    for s in fixed:
        vals = [FIXED_WORD.get(v, f"`{v}`" if s != "now" else f"the literal `{v}`") for v in q[s][1]]
        parts.append(f"`{s}` fixed to " + (vals[0] if len(vals) == 1 else ", ".join(vals[:-1]) + " and " + vals[-1]))
    if every:
        # a structure is named only beside the slots it carries (`AdmissionContext` carries `params` and `now`, never
        # a `cfg` bound beside it)
        via = defaultdict(list)
        for s in every:
            for v in sorted({b.split(" : ")[1] for b in q[s][1] if " : " in b}):
                via[v].append(s)
        if not via:
            tail = ""
        elif all(ss == every for ss in via.values()):
            tail = f" (through {', '.join(f'`{v}`' for v in sorted(via))})"
        else:
            tail = " (" + "; ".join(f"{words(ss)} through `{v}`" for v, ss in sorted(via.items())) + ")"
        parts.append(f"for every {words(every)}" + tail)
    if absent:
        parts.append(f"{words(absent)} {'is not an argument' if len(absent) == 1 else 'are not arguments'} of the statement")
    line = "**Quantification** [M] (read from the statement by `tools/specgen.py`, #77): " + "; ".join(parts) + "."
    if fixed:
        kind, names = general
        line += {"general": f" General form: {words(names)}, quantified; this theorem is its instance.",
                 "general-free": f" General form: {words(names)}, free of the four inputs (general over the values it takes); this theorem is its instance.",
                 "concrete": f" A statement about the concrete run {words(names)} (closed definitions of `{d['file']}`): network-specific by design.",
                 "design": " Network-specific by design (the explainer states the reason).",
                 "flagged": " **FLAGGED: no general form named and no reason stated** (#77)."}[kind]
    return line

# a fixed theorem's explainer names its general form in a sentence "The general form (or equivalence) is `name`"
GENERAL = re.compile(r"[Gg]eneral (?:form|equivalence|statement)s? (?:is|are) ((?:`[\w.'!?]+`(?:,? (?:and )?)?)+)")

def chain_quantification(decls):
    """[M] Every chain-layer theorem with its slots, its class and, for one that fixes a slot, its warrant: the
    general form its explainer names (a chain-layer theorem that fixes no slot: quantified, or free of the four), the concrete run it states (the
    closed fixture definitions of its Properties file it names), the explainer's "by design", or FLAGGED."""
    bundles, fixtures = chain_bundles(), fixture_fixes(decls)
    thms = [d for d in decls if d["kind"] == "theorem" and d["module"].startswith("BsvChain")]
    qs = {d["name"]: quantification(d, bundles, fixtures) for d in thms}
    closed = {d["name"]: d["file"] for d in decls if d["kind"] in ("def", "abbrev")
              and d["module"].startswith("BsvChain.Properties") and not binders(d.get("sig", ""))[0]}
    out = []
    for d in thms:
        q = qs[d["name"]]
        warrant = None
        if quant_class(q) == "fixed":
            named = [g for m in GENERAL.finditer(" ".join(d["doc"].split())) for g in re.findall(r"`([\w.'!?]+)`", m.group(1))]
            general = [g for g in named if g in qs and g != d["name"] and quant_class(qs[g]) != "fixed"]
            concrete = [c for c, f in closed.items() if f == d["file"] and re.search(r"(?<![\w.])" + re.escape(c) + r"(?![\w'!?])", d["sig"])]
            kind = "general" if all(quant_class(qs[g]) == "quantified" for g in general) else "general-free"
            warrant = ((kind, general) if general else ("concrete", concrete) if concrete else
                       ("design", []) if "by design" in d["doc"] else ("flagged", []))
        out.append((d, q, quant_class(q), warrant))
    return out

def quant_summary(rows):
    """[M] The counts the index page quotes: every chain-layer theorem by its class."""
    c = defaultdict(int)
    for _, _, cls, warrant in rows:
        c[cls if cls != "fixed" else "fixed-" + warrant[0]] += 1
    every = sum(1 for _, q, _, _ in rows if all(v[0] == "bound" for v in q.values()))
    fixed = sum(v for k, v in c.items() if k.startswith("fixed"))
    return (f"{len(rows)} chain-layer theorems (`lean/BsvChain/**`) by the quantification read from each statement (#77): "
            f"{c['quantified']} quantify every parameter they take (`params`, `cfg`, the oracle, `now`, directly, through a context structure or through a predicate whose steps bind them), "
            f"{every} of them all four; {c['free']} take none of the four; {fixed} fix one to a network's record, the census "
            f"defaults, the evaluator or a literal time: {c['fixed-general']} instances of a named quantified general form, "
            f"{c['fixed-general-free']} of a named general form free of the four inputs, "
            f"{c['fixed-concrete']} statements about a concrete run (network-specific by design)"
            + (f", {c['fixed-design']} network-specific by design by their explainers" if c['fixed-design'] else "")
            + f"; {c['fixed-flagged']} flagged. A slot read through a default (a default argument, such as "
            "`medianTimePast`'s span default at `Finality.lean:107`, or a structure field's default: `Mempool`'s two "
            "filters at `Mempool.lean:214,216`, carried by `ChainState.mempool := {}` at `Chain.lean:345` into "
            "`Reachable.empty` and `staleWitnessState`) is not seen by this reading and shows as `·`. [M] 2026-10-14: "
            "every call under `lean/BsvChain` passes the span explicitly, and `Reachable`'s `pool` step admits any pool.")

# a `[SRC]` citation in a docstring: `NNN`, `NNN–MMM`, `:NNN`, `file.ext:NNN[–MMM]`
CITE = re.compile(r"`((?:[\w/]+\.(?:cpp|h|hpp|rs|go|c))?:?\d+(?:[–-]\d+)?(?:, ?\d+(?:[–-]\d+)?)*)`")

def cites_of(doc, bare="interpreter.cpp"):
    """The `[SRC]` citations of a docstring, in order. A `file.ext:NNN` names its file; a `:NNN` continues the file
    the docstring last named (else the module's default); a bare `NNN` or `NNN–MMM` is a line of the module's default
    file (`interpreter.cpp` unless the module docstring says "Bare line numbers are `<file>`"); a bare single digit is
    a value (`0`, `1`), never a line (the files' first lines are licence text; #32's lens 1, parts B and D), and so
    is a number with a leading zero, a byte written `03` (#32's second re-lens, N-1). A
    citation the docstring places at another release, "at 0.3.24" in the same clause (up to the next `;` or
    `)`), keeps that release on its `[SRC]` line, "(at 0.3.24)" (#32's re-lens, part D: a release's lines printed
    bare read as the pin's)."""
    out, last = [], None
    for m in CITE.finditer(doc):
        c = m.group(1)
        clause = re.split(r"[;)]", doc[m.end():], maxsplit=1)[0]
        rel = re.search(r"\bat v?(\d+\.\d+\.\d+)\b", clause)
        if re.fullmatch(r":\d+(?:[–-]\d+)?(?:, ?\d+(?:[–-]\d+)?)*", c):
            c = (last or bare) + c
        elif re.fullmatch(r"\d+(?:[–-]\d+)?(?:, ?\d+(?:[–-]\d+)?)*", c):
            if re.fullmatch(r"\d|0\d+", c):   # a single digit or a leading zero: a value, never a line
                continue
            c = bare + ":" + c
        else:
            last = c.split(":")[0]
        if rel:
            c = f"{c} (at {rel.group(1)})"
        if c not in out:
            out.append(c)
    return out

# ---------------------------------------------------------------- the corpora and the rules
def read_rule_rows():
    text = open(f"{ROOT}/corpus/INDEX.md").read()
    sec = text.split("## 2. The rule vocabulary")[1].split("## 3.")[0]
    rows = []
    for line in sec.split("\n"):
        if not line.startswith("| `"):
            continue
        cells = [c.strip() for c in line.strip().strip("|").split(" | ")]
        if len(cells) < 4:
            continue
        head = re.sub(r"\s*\([^)]*\)\s*$", "", cells[0]).strip()
        ids = [i.strip("` ") for i in re.split(r"\s*·\s*", head.strip("`"))]
        # `num.arith.add · sub · mul` : the later ids share the prefix of the first
        full = []
        for i in ids:
            i = i.strip("` ")
            if "." not in i and full:
                pre = full[0].rsplit(".", 1)[0]
                full.append(f"{pre}.{i}")
            else:
                full.append(i)
        rows.append({"ids": full, "what": cells[1], "src": cells[2], "entries": cells[3]})
    return rows

def read_corpus_rules():
    counts, families = defaultdict(int), defaultdict(set)
    for path in ["seed/seed.jsonl", "flow/flow.jsonl", "arith/cases.jsonl", "stack/cases.jsonl", "crypto/cases.jsonl",
                 "bytes/cases.jsonl", "eras/eras.jsonl", "gen/gen.jsonl", "tx/tx.jsonl", "witnesses/policy-defaults.jsonl"]:
        p = f"{ROOT}/corpus/{path}"
        if not os.path.exists(p):
            continue
        for line in open(p):
            if not line.strip():
                continue
            e = json.loads(line)
            counts[e["rule"]] += 1
            families[e["rule"]].add("witnesses/policy-defaults" if path.startswith("witnesses/") else path.split("/")[0])
    return counts, families

def read_witnesses():
    p = f"{ROOT}/corpus/witnesses/manifest.json"
    if not os.path.exists(p):
        return {}
    man = json.load(open(p))
    by_rule = defaultdict(list)
    for corpus, m in man.items():
        for r in m.get("rules", []):
            by_rule[r["rule"]].append((corpus, r["column"], r["entries"], r["ruling"], r["witness"]))
    return by_rule

# the opcodes a rule id names, by its tail (the text of the row may name more)
RULE_OPS = {
    "num.arith": {"add": ["OP_ADD"], "sub": ["OP_SUB"], "mul": ["OP_MUL"], "div": ["OP_DIV"], "mod": ["OP_MOD"], "min": ["OP_MIN"], "max": ["OP_MAX"],
                  "1add": ["OP_1ADD"], "1sub": ["OP_1SUB"], "negate": ["OP_NEGATE"], "abs": ["OP_ABS"], "2mul": ["OP_2MUL"], "2div": ["OP_2DIV"],
                  "div0": ["OP_DIV"], "mod0": ["OP_MOD"]},
    "num.cmp": {"lessthan": ["OP_LESSTHAN"], "greaterthan": ["OP_GREATERTHAN"], "numequal": ["OP_NUMEQUAL"], "numnotequal": ["OP_NUMNOTEQUAL"],
                "numequalverify": ["OP_NUMEQUALVERIFY"], "within": ["OP_WITHIN"]},
    "num.encoding": {"nonminimal": ["OP_1ADD"]},
    "splice": {"cat": ["OP_CAT"], "split": ["OP_SPLIT"], "bin2num": ["OP_BIN2NUM"], "num2bin": ["OP_NUM2BIN", "OP_BIN2NUM"], "substr": ["OP_SUBSTR", "OP_LEFT", "OP_RIGHT"]},
    "bitwise": {"andorxor": ["OP_AND", "OP_OR", "OP_XOR"], "operand-size": ["OP_AND", "OP_OR", "OP_XOR"], "invert": ["OP_INVERT"], "shift": ["OP_LSHIFT", "OP_RSHIFT"], "equal": ["OP_EQUAL", "OP_EQUALVERIFY"]},
    "flow": {"if": ["OP_IF"], "notif": ["OP_NOTIF"], "nesting": ["OP_IF", "OP_NOTIF", "OP_ELSE", "OP_ENDIF"], "else": ["OP_ELSE"], "unbalanced": ["OP_IF", "OP_NOTIF", "OP_ELSE", "OP_ENDIF"],
             "verify": ["OP_VERIFY"], "return": ["OP_RETURN"], "nop": ["OP_NOP", "OP_NOP1", "OP_NOP9", "OP_NOP10"], "reserved": ["OP_RESERVED", "OP_RESERVED1", "OP_RESERVED2"],
             "unknown-opcode": [], "ver": ["OP_VER"], "verif": ["OP_VERIF", "OP_VERNOTIF"]},
    "stack": {"ops": [], "alt": ["OP_TOALTSTACK", "OP_FROMALTSTACK"], "pick": ["OP_PICK"], "roll": ["OP_ROLL"], "depth": ["OP_DEPTH"], "final": []},
    "elem": {"size": ["OP_SIZE"]},
    "push": {"minimal": [], "constant": ["OP_1NEGATE"], "truncated": ["OP_PUSHDATA1", "OP_PUSHDATA2", "OP_PUSHDATA4"]},
    "crypto": {"hash": ["OP_RIPEMD160", "OP_SHA1", "OP_SHA256", "OP_HASH160", "OP_HASH256"], "checksig": ["OP_CHECKSIG", "OP_CHECKSIGVERIFY"],
               "checkmultisig": ["OP_CHECKMULTISIG", "OP_CHECKMULTISIGVERIFY"], "codeseparator": ["OP_CODESEPARATOR"]},
    "sighash": {"*": ["OP_CHECKSIG", "OP_CHECKSIGVERIFY", "OP_CHECKMULTISIG", "OP_CHECKMULTISIGVERIFY"]},
    "tx": {"locktime": ["OP_CHECKLOCKTIMEVERIFY"], "sequence": ["OP_CHECKSEQUENCEVERIFY"], "rules": []},
    # the eras corpus (#20, #23): the opcodes whose era rule each id exercises
    "eras.utxo": {"pre-genesis": ["OP_RETURN", "OP_CHECKLOCKTIMEVERIFY", "OP_CHECKSEQUENCEVERIFY", "OP_ELSE", "OP_2MUL", "OP_VERIF", "OP_VER", "OP_SUBSTR", "OP_CAT", "OP_1ADD", "OP_CHECKMULTISIG", "OP_NOP"],
                  "post-genesis": ["OP_RETURN", "OP_CHECKLOCKTIMEVERIFY", "OP_CHECKSEQUENCEVERIFY", "OP_ELSE", "OP_2MUL", "OP_VERIF", "OP_VER", "OP_SUBSTR", "OP_LSHIFTNUM", "OP_RSHIFTNUM", "OP_CAT", "OP_1ADD", "OP_CHECKMULTISIG", "OP_NOP"],
                  "post-chronicle": ["OP_2MUL", "OP_VERIF", "OP_VER", "OP_SUBSTR", "OP_LSHIFTNUM", "OP_RSHIFTNUM", "OP_1ADD", "OP_CAT"]},
    "eras.spend": {"genesis": ["OP_ADD"], "chronicle": ["OP_ADD", "OP_CHECKSIG", "OP_NOT"]},
    "eras.height": {"p2sh": ["OP_HASH160", "OP_EQUAL"], "dersig": ["OP_CHECKSIG", "OP_NOT"], "cltv": ["OP_CHECKLOCKTIMEVERIFY"], "csv": ["OP_CHECKSEQUENCEVERIFY"],
                    "uahf": ["OP_CHECKSIG", "OP_NOT"], "daa": ["OP_CHECKSIG", "OP_NOT"]},
    "p2sh": {"grandfathered": ["OP_HASH160", "OP_EQUAL"], "disabled": ["OP_HASH160", "OP_EQUAL"], "pushonly": ["OP_HASH160", "OP_EQUAL"]},
    "p2sh.output": {"post-genesis": ["OP_HASH160", "OP_EQUAL"]},
}

def opcodes_of_rule(rule_id, ops):
    parts = rule_id.split(".")
    out = set()
    for k in range(len(parts) - 1, 0, -1):
        head, tail = ".".join(parts[:k]), parts[k]
        table = RULE_OPS.get(head)
        if table is None:
            continue
        if "*" in table:
            out.update(table["*"])
        if tail in table:
            out.update(table[tail])
        break
    if rule_id.startswith("stack.ops"):
        out.update(n for n, v in ops.items() if 0x6b <= v <= 0x7d)
    if rule_id.startswith("push.minimal") or rule_id.startswith("push.constant"):
        out.update(n for n, v in ops.items() if v <= 0x4e or 0x4f <= v <= 0x60)
    if rule_id.startswith("flow.unknown-opcode"):
        out.update(n for n, v in ops.items() if v >= 0xba)
    return out

def rules_naming(name, val, rule_rows, ops):
    names = opcode_mentions(name, val)
    out = []
    for r in rule_rows:
        by_text = any(re.search(r"(?<![A-Z0-9_])" + re.escape(n) + r"(?![A-Z0-9_])", r["what"]) for n in names)
        by_id = any(name in opcodes_of_rule(i, ops) for i in r["ids"])
        if by_text or by_id:
            out.append(r)
    return out

def implemented(name, val):
    """Whether the evaluator decides the opcode: every family module that exists
    on disk; the expansion opcodes wait on their module (#18)."""
    fam, mod, _, _ = family_of(val)
    if mod == "BsvScript.Ops.Expansion":
        return os.path.exists(f"{ROOT}/lean/BsvScript/Ops/Expansion.lean")
    return True

# ---------------------------------------------------------------- rendering
def opcode_mentions(name, val):
    """The names a docstring may use for this opcode."""
    names = {name}
    aliases = {"OP_0": ["OP_FALSE"], "OP_1": ["OP_TRUE"], "OP_CHECKLOCKTIMEVERIFY": ["CLTV", "OP_NOP2"], "OP_CHECKSEQUENCEVERIFY": ["CSV", "OP_NOP3"]}
    names.update(aliases.get(name, []))
    if 0x51 <= val <= 0x60:
        names.add("OP_1`–`OP_16")
    if val in (0x4c, 0x4d, 0x4e):
        names.add("OP_PUSHDATA1/2/4")
    return names

def render_opcode(name, val, decls, rule_rows, counts, witnesses, ops):
    fam, mod, issue, src = family_of(val)
    names = opcode_mentions(name, val)
    # docstrings naming the opcode, family-module docstrings first
    related = []
    for d in decls:
        text = d["doc"]
        if not d["module"].startswith("BsvChain.") and any(
                re.search(r"(?<![A-Z0-9_])" + re.escape(n) + r"(?![A-Z0-9_])", text) for n in names):
            related.append(d)
    related.sort(key=lambda d: (0 if d["module"] == mod else 1, d["module"], d["line"]))
    # the rules naming the opcode (by the row's text or by the rule id's tail)
    rules = rules_naming(name, val, rule_rows, ops)
    lines = [f"# `{name}` (`0x{val:02x}`)", ""]
    lines.append(f"**Family** {fam} · **module** `{mod}` · **landed at** {issue} · **the switch** {src} · the reference {PIN}.")
    lines.append("")
    h = history_of(name, val)
    if h:
        lines.append("## History and eras")
        lines.append("")
        for r in h:
            lines.append(f"- {r}")
        lines.append("")
    lines.append("## Semantics (the Lean docstrings that name it)")
    lines.append("")
    if not implemented(name, val):
        lines.append("**Not yet in the evaluator** (`Verdict.unimplemented`, the build-time state of an opcode no family has written; #18). The rule below carries the reading the module will follow.")
        lines.append("")
    if not related:
        if val >= 0xba or name in ("OP_RESERVED", "OP_RESERVED1", "OP_RESERVED2"):
            lines.append("No opcode-level definition: the switch's `default:` case (`Op.hasCase` in `BsvScript.Opcodes`), `SCRIPT_ERR_BAD_OPCODE` when executed (`1795`).")
        elif implemented(name, val):
            lines.append(f"Decided by its family module `{mod}` (no docstring names it individually; the family's docstrings are in [`modules.md`](../modules.md)).")
        lines.append("")
    for d in related:
        cites = cites_of(d["doc"], d.get("bare", "interpreter.cpp"))
        lines.append(f"### `{d['name']}` ({d['kind']}, `{d['file']}:{d['line']}`)")
        lines.append("")
        lines.append(d["doc"])
        lines.append("")
        if cites:
            lines.append("`[SRC]` " + ", ".join(f"`{c}`" for c in cites))
            lines.append("")
    lines.append("## The corpus entries that exercise it (by rule)")
    lines.append("")
    if not rules:
        lines.append("**No rule of `corpus/INDEX.md` §2 names this opcode: FLAGGED** (#26's input).")
    else:
        lines.append("| rule | corpus entries | `[SRC]` |")
        lines.append("|---|---|---|")
        for r in rules:
            n = sum(counts.get(i, 0) for i in r["ids"])
            ids = ", ".join(f"`{i}`" for i in r["ids"])
            flag = "" if n > 0 else f" **(no generated entry: {r['entries']})**"
            lines.append(f"| {ids} | {n}{flag} | {r['src']} |")
    lines.append("")
    ws = []
    for r in rules:
        for i in r["ids"]:
            for w in witnesses.get(i, []):
                ws.append((i,) + w)
    # rules that are named by the witness manifest with a suffix (flags.version-gate.nullfail)
    for wr, lst in witnesses.items():
        for r in rules:
            for i in r["ids"]:
                if wr != i and wr.startswith(i + "."):
                    for w in lst:
                        ws.append((wr,) + w)
    if ws:
        lines.append(f"## Witnesses (the differential against bsv-rs {bsvrs_pin()}, #15; the classes are data since D83c, `harness/rules/bsv-rs.json`)")
        lines.append("")
        lines.append("| rule | corpus | column | entries | ruling | witness |")
        lines.append("|---|---|---|---|---|---|")
        for (rule, corpus, col, n, ruling, wid) in sorted(set(ws)):
            lines.append(f"| `{rule}` | {corpus} | {col} | {n} | {ruling} | `{wid}` |")
        lines.append("")
    return "\n".join(lines) + "\n"

def render_rules(rule_rows, counts, fams, witnesses):
    lines = ["# The rules and their corpus entries", "",
             "The rule vocabulary of `corpus/INDEX.md` §2 with the number of entries of the generated corpora (`corpus/seed`, `flow`, `arith`, `stack`, `crypto`, `bytes`, the hand-built `eras`, #26's generator families `gen` and the transaction-level `tx` (D97, 2026-09-26), and the constructed `witnesses/policy-defaults`) that carry each id. **A rule without a generated entry is flagged**: #26's input (the reference's own vectors and the harness's witness families are named in the last column, never counted here).", ""]
    lines.append("| rule | what it exercises | `[SRC]` | generated entries | corpora | flagged |")
    lines.append("|---|---|---|---|---|---|")
    flagged = []
    for r in rule_rows:
        for i in r["ids"]:
            n = counts.get(i, 0)
            f = ", ".join(sorted(fams.get(i, [])))
            flag = "" if n > 0 else f"**FLAGGED** ({r['entries']})"
            if n == 0:
                flagged.append(i)
            what = r["what"]
            if len(what) > 220:
                what = what[:217] + "…"
            lines.append(f"| `{i}` | {what} | {r['src']} | {n} | {f} | {flag} |")
    lines.append("")
    lines.append(f"**Flagged ({len(flagged)}):** " + (", ".join(f"`{i}`" for i in flagged) if flagged else "none") + ".")
    lines.append("")
    # rules the corpora carry that the vocabulary lacks
    known = {i for r in rule_rows for i in r["ids"]}
    extra = sorted(i for i in counts if i not in known)
    if extra:
        lines.append("**Rule ids in the corpora that `corpus/INDEX.md` §2 does not list:** " + ", ".join(f"`{i}` ({counts[i]})" for i in extra) + ".")
        lines.append("")
    if witnesses:
        lines.append("## Witness rules (#15)")
        lines.append("")
        lines.append("| rule | corpus | column | entries | ruling | witness |")
        lines.append("|---|---|---|---|---|---|")
        for rule in sorted(witnesses):
            for (corpus, col, n, ruling, wid) in witnesses[rule]:
                lines.append(f"| `{rule}` | {corpus} | {col} | {n} | {ruling} | `{wid}` |")
        lines.append("")
    return "\n".join(lines) + "\n", flagged

def render_theorems(decls):
    quant = {d["name"]: (q, w) for d, q, _, w in chain_quantification(decls)}
    lines = ["# The theorems, with their explainers", "",
             "Every `theorem` of the Lean sources, each with its docstring (the explainer: what it says, what it assumes, why it matters) where it has one of its own; a theorem without one is listed and marked. A `[SRC]` line reads a bare line number in the module's default file (`interpreter.cpp` unless the module says otherwise) and a `:NNN` in the file the docstring last named. `lean/AxiomCheck.lean` lists the main theorems; `tools/axiom_check.py` shows each depends on Lean's three axioms only.",
             "",
             "Each `BsvChain` theorem carries its **quantification** line (#77), read from its statement: for each of `params`, `cfg`, the oracle and `now`, whether a binder quantifies it (directly, through a context structure such as `ChainContext`, or through a predicate whose steps bind it such as `Reachable`), the statement fixes it to a constant (a network's record, the census defaults `NodeConfig.defaults`, the evaluator, a literal time), or it is not an argument of the statement. A theorem that fixes one names its general form (quantified, or free of the four inputs), or states a concrete run. The counts, and the slots this reading does not see (a default argument or a structure field's default), are on [`README.md`](README.md).", ""]
    by_mod = defaultdict(list)
    for d in decls:
        if d["kind"] == "theorem":
            by_mod[d["module"]].append(d)
    for mod in sorted(by_mod):
        lines.append(f"## `{mod}`")
        lines.append("")
        for d in by_mod[mod]:
            lines.append(f"### `{d['name']}` (`{d['file']}:{d['line']}`)")
            lines.append("")
            if d["module"].startswith("BsvChain") and d["name"] in quant:
                lines.append(quant_line(d, *quant[d["name"]]))
                lines.append("")
            if d.get("undocumented"):
                lines.append("*No explainer of its own* (CLAUDE.md rule 7: an explainer per theorem).")
                lines.append("")
                continue
            lines.append(d["doc"])
            cites = cites_of(d["doc"], d.get("bare", "interpreter.cpp"))
            if cites:
                lines.append("")
                lines.append("`[SRC]` " + ", ".join(f"`{c}`" for c in cites))
            lines.append("")
    return "\n".join(lines) + "\n"

def render_modules(mods):
    lines = ["# The modules", "", "The module docstrings of `lean/BsvScript/**`, `lean/BsvChain/**` and `lean/Bsvs/Trace.lean`, in module order.", ""]
    for module, rel, doc in mods:
        lines.append(f"## `{module}` (`{rel}`)")
        lines.append("")
        lines.append(doc)
        lines.append("")
    return "\n".join(lines) + "\n"

def render_flags(decls):
    lines = ["# The flags model", "", "From `lean/BsvScript/Params.lean` (`Flags`, its fields) and `lean/BsvScript/Flags.lean` (`FlagBit`, `Params.derive`); the census is `docs/PARAMETERS.md` §2 and §6.", ""]
    src = open(f"{ROOT}/lean/BsvScript/Params.lean").read()
    lines.append("| field | the bit and its kind (from the field docstring) |")
    lines.append("|---|---|")
    for m in re.finditer(r"/-- (bit \d+, .*?) -/\s*\n\s*(\w+) : Bool", src, re.S):
        lines.append(f"| `{m.group(2)}` | {' '.join(m.group(1).split())} |")
    lines.append("")
    for d in decls:
        if d["module"] == "BsvScript.Flags" and d["kind"] in ("def", "theorem", "inductive"):
            lines.append(f"### `{d['name']}` ({d['kind']}, `{d['file']}:{d['line']}`)")
            lines.append("")
            lines.append(d["doc"])
            lines.append("")
    return "\n".join(lines) + "\n"

def render_errors():
    src = open(f"{ROOT}/lean/BsvScript/Opcodes.lean").read()
    names = dict(re.findall(r"\|\s*(\w+) => \"(SCRIPT_ERR_\w+)\"", src))
    msgs = dict(re.findall(r"\|\s*(\w+) => \"((?!SCRIPT_ERR)[^\"]*)\"", src))
    lines = ["# The error vocabulary", "", "`ScriptError` (`lean/BsvScript/Opcodes.lean`) = `src/script/script_error.h:12–87` without `OK`; the message is `ScriptErrorString` (`script_error.cpp`). The corpus's `code` field carries the name.", "",
             "| constructor | `SCRIPT_ERR_*` | message |", "|---|---|---|"]
    for c, n in names.items():
        lines.append(f"| `{c}` | `{n}` | {msgs.get(c, '')} |")
    return "\n".join(lines) + "\n"

def theorem_counts(decls):
    """The three theorem counts, each by its instrument (C3's lens 3, C7; S2, 2026-09-26). They differ by design and
    every page that quotes one names its instrument: (1) `theorem` declarations that carry a docstring of their own
    (theorems.md renders every theorem and marks the others); (2) the `#print axioms` lines of lean/AxiomCheck.lean, the axiom list the tripwire's axiom
    leg checks on every run (its count of record is that leg's line in docs/records/<stamp>-make-check.txt, never
    read here: a record is written after the spec leg runs); (3) `theorem` declarations after masking comments and
    quoted literals in the files this
    generator reads (an undocumented theorem counts here and nowhere else), a declaration behind attributes or a
    `private`/`protected` modifier included (the `@[csimp] theorem` lines of #45 and of the transaction decoder were
    missed by the pattern anchored on a bare `theorem` until 2026-09-27: 20 at that commit)."""
    n_doc = sum(1 for d in decls if d["kind"] == "theorem" and not d.get("undocumented"))
    ax = open(f"{ROOT}/lean/AxiomCheck.lean").read()
    n_list = sum(1 for l in ax.splitlines() if l.strip().startswith("#print axioms"))
    files = public_sources()
    n_grep = sum(len(THM.findall(lean_code(open(f).read()))) for f in files)
    return n_doc, n_list, n_grep

def bsvrs_pin():
    """bsv-rs's version as the witness manifest records it: the pin of the differential the witness tables quote
    (the heading said "0.3.24" by hand until 2026-09-26: C3's lens 3, C7)."""
    try:
        m = json.load(open(f"{ROOT}/corpus/witnesses/manifest.json"))
        vs = sorted({v.get("bsv-rs") for v in m.values() if isinstance(v, dict) and v.get("bsv-rs")})
        return ", ".join(vs) if vs else "?"
    except Exception:
        return "?"

def render_index(ops, decls, counts, rule_rows, flagged, witnesses):
    lines = ["# The BSV script and chain specification, generated from the Lean sources", "",
             f"**Generated by `tools/specgen.py` (#17); never edited by hand.** The reference is {PIN}; a `[SRC]` line reads a bare line number in its module's default file (`src/script/interpreter.cpp` unless the module docstring says \"Bare line numbers are `<file>`\"), a `:NNN` in the file the docstring last named, and marks a line cited at another release than the pin with that release. The evaluator is `eval/bsvs`; the semantics is `lean/BsvScript` and `lean/BsvChain`; the corpora and witnesses are `corpus/`.", "",
             "- [`modules.md`](modules.md): the BsvScript and BsvChain module docstrings (including chain parameters and finality), and the trace",
             "- [`opcodes/`](opcodes/): one page per opcode (below)",
             "- [`rules.md`](rules.md): the rule vocabulary with its corpus counts and the flagged rules",
             "- [`theorems.md`](theorems.md): every BsvScript and BsvChain theorem, with its explainer where it has one; [chain finality and fee properties](theorems.md#bsvchainpropertiesfinality)",
             "- [`flags.md`](flags.md): the flag word, the derivation, the version gate",
             "- [`errors.md`](errors.md): the error vocabulary",
             "- [`status-views.md`](status-views.md): [D] 2026-10-13 transaction status vocabularies as views, never rules",
             "- [`merkle-proof.md`](merkle-proof.md): [M] 2026-10-13 the proof surface (#75): getmerkleproof, getmerkleproof2, the TSC proof codec and its projection to the merkle path, views never rules",
             "- [`wire-views.md`](wire-views.md): [M] 2026-10-15 the client wire formats (#86): EF, BUMP, BEEF, Atomic BEEF and the TSC proof, codecs with both round trips and their projections to the machine's objects, views never rules",
             "- [`teranode-map.md`](teranode-map.md): [D] 2026-10-14 the module map (#87): every S6 and S7 rule with the reference's function, Teranode's service and the mechanism, rendered by `tools/teranode_map.py` from `corpus/teranode/map.json`",
             "- [`teranode-absences.md`](teranode-absences.md): [D] 2026-10-14 the absence ledger (#96): what Teranode v0.16.0 lacks and what the reference lacks, each with a proposed ruling and the maintainers' ruling (19 of 19, 2026-10-15)",
             "- [`node-client-contract.md`](node-client-contract.md): [D] 2026-10-16 the node's client contract (#140): what a node that replaces SV-node gives a client, in four sections (consensus set in stone, the protocol's client contract, the surfaces one implementation adds, and what is beyond the protocol by design, each with Teranode's design reason cited at the pin), rendered by `tools/node_contract.py` from `corpus/teranode/absences.json`, and a fifth since 2026-10-17 (#88): the refinement's obligation list, every row of the module map pointing at one theorem, witness, design row, chain-split row, report row or open obligation, from `corpus/teranode/obligations.json`", ""]
    n_doc, n_list, n_grep = theorem_counts(decls)
    lines.append(f"Counts [M]: {len(ops)} opcodes in the table; the theorems by three instruments, which differ by design (every page that quotes a theorem count names its instrument): {n_doc} `theorem` declarations with a docstring of their own (`theorems.md` renders every theorem and marks the rest), {n_list} `#print axioms` lines on `lean/AxiomCheck.lean` (the axiom list; the tripwire's axiom leg checks it on every run and its count of record is that leg's line in `docs/records/<stamp>-make-check.txt`), {n_grep} `theorem` declarations after masking comments and quoted literals over `lean/{{BsvScript,BsvChain}}/**/*.lean` and `lean/Bsvs/Trace.lean`; {sum(counts.values())} generated corpus entries over {len([r for rr in rule_rows for r in rr['ids']])} rule ids, {len(flagged)} flagged; {sum(len(v) for v in witnesses.values())} witness rows.")
    lines.append("")
    lines.append("Quantification [M]: " + quant_summary(chain_quantification(decls)) + " Each theorem's line is on [`theorems.md`](theorems.md).")
    lines.append("")
    lines.append("| opcode | byte | family | module | landed | [M] docstrings naming it | [M] rules naming it |")
    lines.append("|---|---|---|---|---|---|---|")
    for name, val in ops.items():
        fam, mod, issue, _ = family_of(val)
        names = opcode_mentions(name, val)
        nd = sum(1 for d in decls if not d["module"].startswith("BsvChain.") and any(
            re.search(r"(?<![A-Z0-9_])" + re.escape(n) + r"(?![A-Z0-9_])", d["doc"]) for n in names))
        nr = len(rules_naming(name, val, rule_rows, ops))
        status = "" if implemented(name, val) else " **(unimplemented, #18)**"
        flag = "" if nr > 0 else " **flagged**"
        lines.append(f"| [`{name}`](opcodes/{name}.md) | `0x{val:02x}` | {fam} | `{mod}` | {issue}{status} | {nd} | {nr}{flag} |")
    lines.append("")
    return "\n".join(lines) + "\n"

def render_status_views(decls):
    """[D] 2026-10-13: render executable row/column/obstruction data from Lean."""
    source = open(f"{ROOT}/lean/BsvChain/Views/Status.lean").read()
    rows_block = source.split('def rows : List String :=', 1)[1].split('/--', 1)[0]
    rows = re.findall(r'"([^"]+)"', rows_block)
    columns_block = source.split('def columns : List (String × Vocabulary) :=', 1)[1].split('/--', 1)[0]
    columns = re.findall(r'\("([^"]+)", \.(\w+)\)', columns_block)
    reasons_block = source.split('def extraState : Vocabulary → String', 1)[1].split('/--', 1)[0]
    reasons = dict(re.findall(r'\| \.(\w+) => "([^"]+)"', reasons_block))
    witness_prefix = re.search(r'⟨extraState v, "([^"]+)" \+\+ row⟩', source).group(1)
    assert rows and columns and set(key for _, key in columns) == set(reasons)
    assert 'def nodeRejectView : View (Option (NodeReject × String)) := .function nodeView' in source
    partial_block = source.split('def partialCells :', 1)[1].split('/--', 1)[0]
    partial = {(r, k): (word, cite) for r, k, word, cite in re.findall(
        r'\("([^"]+)", \.(\w+), "([^"]+)", "([^"]+)"\)', partial_block)}
    assert partial and all(r in rows and k in reasons for r, k in partial)
    # #74 (2026-10-15): the Teranode node column's cells and its recorded no-function cells, from Lean data
    tera_block = source.split('def teranodeCells :', 1)[1].split('/--', 1)[0]
    tera = {r: (word, cite, witness) for r, word, cite, witness in re.findall(
        r'\("([^"]+)", "([^"]+)", "([^"]+)", "([^"]+)"\)', tera_block)}
    tera_none_block = source.split('def teranodeNoFunction :', 1)[1].split('/--', 1)[0]
    tera_none = {r: (reason, witness) for r, reason, witness in re.findall(
        r'\("([^"]+)", ⟨"([^"]+)", "([^"]+)"⟩\)', tera_none_block)}
    tera_record = re.search(r'def teranodeWitnessRecord : String := "docs/records/([^"]+)"', source).group(1)
    assert 'teranodeNode' in reasons and set(tera) | set(tera_none) == set(rows) and not set(tera) & set(tera_none)
    functions = len(rows) + len(partial) + len(tera)
    lines = ['# Status vocabularies as views', '',
             '[D] 2026-10-13. Generated from `lean/BsvChain/Status.lean` and '
             '`lean/BsvChain/Views/Status.lean`. Every cell describes a view, never a rule. '
             'Partial functions return a source word where Status determines its predicate, undefined elsewhere. '
             'Stored asynchronous reports separately need producer history. '
             'The node column is an Option extension of the completed rejection vocabulary: '
             '`none` is a derivation, never a literal RPC word.', '',
             f'[M] Table shape: {len(rows)} rows by {len(columns)} columns; '
             f'{functions} function cells including {len(partial)} partial cells; '
             f'{len(rows) * len(columns) - functions} no-function cells.', '',
             '| derived status [D] | ' + ' | '.join(name for name, _ in columns) + ' |',
             '|---|' + '---|' * len(columns)]
    for row in rows:
        cells = []
        for _, key in columns:
            if key == 'teranodeNode':
                link = f'[{tera_record[:-3]}](../docs/records/{tera_record}#the-status-witnesses)'
                if row in tera:
                    word, cite, witness = tera[row]
                    cells.append(f'function: `{word}` [SRC] {cite}; witness: {witness}; {link}')
                else:
                    reason, witness = tera_none[row]
                    cells.append(f'no function: {reason}; witness: {witness}; {link}')
            elif key == 'node':
                cells.append('function: `nodeWord code`, exact reason (RPC namespace retained)' if row == 'rejected'
                             else 'function: `none` (derived status has no rejection output)')
            elif (row, key) in partial:
                word, cite = partial[row, key]
                wid = witness_prefix + row
                qualification = reasons[key]
                if key == 'arcade' and row == 'onStaleBranch':
                    qualification += '; stored reorg_unmined SEEN_ON_NETWORK / reorg_reanchor MINED events (:326-331 at 1ae1208e)'
                if key == 'arcade' and row == 'rejected':
                    qualification += '; stored transition restrictions (:227-237 at 1ae1208e)'
                cells.append(f'function (partial): `{word}` [SRC] {cite}; separate stored-report obstruction: {qualification}; [{wid}](../corpus/scenarios/{wid}.md)')
            else:
                wid = witness_prefix + row
                cells.append(f'no function: {reasons[key]}; [{wid}](../corpus/scenarios/{wid}.md)')
        lines.append('| `' + row + (' h' if row == 'minedActive' else ' code reason' if row == 'rejected' else '')
                     + '` | ' + ' | '.join(cells) + ' |')
    lines += ['', '[D] No-function witnesses vary declared producer context while leaving the '
              'node state unchanged. Source predicates reject incompatible contexts, including '
              'signed noSend for the input-empty rejected fixture and validator OK without a valid response for structurally valid bytes. '
              'They do not measure Arcade, wallet-toolbox or Teranode. '
              'A shared word alone would not refute a function from Status; the missing input '
              'and equal-status context boundary are the obstruction.', '',
              '[D] The Teranode node column (#74) is Teranode v0.16.0\'s own transaction state in its UTXO store and block '
              'assembly, a partial function of the derived status from the map\'s sections 1, 5 and 6 '
              '([docs/CONFORMANCE-TERANODE-MACHINE.md](../docs/CONFORMANCE-TERANODE-MACHINE.md)). Its witnesses are the steps '
              'of one measured instance run, not producer contexts; a function cell whose step did not reach its value says so. '
              'A refusal keeps the class only: Teranode\'s code and words are its own namespace. The second oracle\'s '
              'defaults are never the rule.', '']
    for d in decls:
        if d['module'] == 'BsvChain.Views.Status' and d['kind'] == 'theorem':
            lines += [f"## `{d['name']}`", '', d['doc'], '']
    module = MODDOC.search(source).group(1)
    lines += ['## Pinned sources [SRC]', '', clean(module), '']
    return '\n'.join(lines).rstrip() + '\n'

def render_merkle_proof(decls, mods):
    """[D] 2026-10-13, #75: the proof surface page: the RPC contract from the view module's docstring, the
    TSC structures and codec, and the theorems with their explainers. Views, never rules."""
    view = "BsvChain.Views.MerkleProof"
    props = "BsvChain.Properties.MerkleProof"
    module_doc = next(doc for module, _, doc in mods if module == view)
    # the module's own title line is this page's title
    module_doc = '\n'.join(l for l in module_doc.split('\n') if not l.startswith('# '))
    lines = ['# The proof surface: getmerkleproof, getmerkleproof2 and the TSC proof format (#75)', '',
             '[M] 2026-10-13. Generated from `lean/BsvChain/Views/MerkleProof.lean` and '
             '`lean/BsvChain/Properties/MerkleProof.lean`. Every definition is a view of #65\'s '
             '`(leaf, path, index, root)`, never a rule; verification is `verifyPath`; inclusion keeps '
             '#65\'s premises. The scenario of record is '
             '[2026-10-13-tsc-proof-surface](../corpus/scenarios/2026-10-13-tsc-proof-surface.md).', '',
             '## The RPC contract and the format [SRC] [LIT]', '', module_doc, '',
             '## The structures, the codec and the projection', '']
    for d in decls:
        if d['module'] == view and d['kind'] != 'theorem':
            lines += [f"### `{d['name']}` ({d['kind']})", '', d['doc'], '']
    n = 0
    lines += ['## The theorems', '']
    for d in decls:
        if d['module'] == props and d['kind'] == 'theorem':
            n += 1
            lines += [f"### `{d['name']}`", '', d['doc'] or '*(no docstring of its own)*', '']
    lines.insert(8, f'[M] {n} theorems on this page; `#print axioms` lists every one in `lean/AxiomCheck.lean`.')
    lines.insert(9, '')
    return '\n'.join(lines).rstrip() + '\n'

WIRE_MODULES = ["BsvChain.Views.Wire.Bytes", "BsvChain.Views.Wire.EF", "BsvChain.Views.Wire.BUMP",
                "BsvChain.Views.Wire.BEEF", "BsvChain.Views.Wire.AtomicBEEF", "BsvChain.Views.Wire.TSC"]

def render_wire_views(decls, mods):
    """[D] 2026-10-15, #86: the client wire formats as views: per module (EF, BUMP, BEEF, Atomic BEEF,
    TSC and their shared byte layer) its docstring with the BRC citations, its definitions and its theorems with
    their explainers. Views, never rules."""
    lines = ['# Client wire formats as views: EF, BUMP, BEEF, Atomic BEEF and the TSC proof (#86)', '',
             '[M] 2026-10-15. Generated from `lean/BsvChain/Views/Wire/*.lean`. Every codec here is a client '
             'encoding, never a rule: no consensus or policy rule of the node reads any of these formats. Each '
             'format has a codec, two round trips (parse after serialize on well-formed values, serialize after '
             'parse on byte-valued input) and a function to the machine\'s objects. The corpus is '
             '[`corpus/wire/`](../corpus/wire/) (mainnet-derived, read only); the engines\' runs and their '
             'witnesses are in the conformance record named by `corpus/INDEX.md`.', '']
    n = 0
    for view in WIRE_MODULES:
        doc = next((d for module, _, d in mods if module == view), '')
        doc = '\n'.join(l for l in doc.split('\n') if not l.startswith('# '))
        lines += [f'## `{view}`', '', doc, '', '### Definitions', '']
        for d in decls:
            if d['module'] == view and d['kind'] != 'theorem':
                lines += [f"#### `{d['name']}` ({d['kind']})", '', d['doc'] or '*(no docstring of its own)*', '']
        lines += ['### Theorems', '']
        for d in decls:
            if d['module'] == view and d['kind'] == 'theorem':
                n += 1
                lines += [f"#### `{d['name']}`", '', d['doc'] or '*(no docstring of its own)*', '']
    lines.insert(2, f'[M] {n} theorems on this page; `#print axioms` lists every one in `lean/AxiomCheck.lean`.')
    lines.insert(3, '')
    return '\n'.join(lines).rstrip() + '\n'

def main():
    out = f"{ROOT}/spec"
    check = "--check" in sys.argv
    if "--out" in sys.argv:
        out = sys.argv[sys.argv.index("--out") + 1]
    ops = read_opcodes()
    decls, mods = read_docs()
    rule_rows = read_rule_rows()
    counts, fams = read_corpus_rules()
    witnesses = read_witnesses()
    files = {}
    for name, val in ops.items():
        files[f"opcodes/{name}.md"] = render_opcode(name, val, decls, rule_rows, counts, witnesses, ops)
    rules_md, flagged = render_rules(rule_rows, counts, fams, witnesses)
    files["rules.md"] = rules_md
    files["theorems.md"] = render_theorems(decls)
    files["modules.md"] = render_modules(mods)
    files["flags.md"] = render_flags(decls)
    files["errors.md"] = render_errors()
    files["status-views.md"] = render_status_views(decls)
    files["merkle-proof.md"] = render_merkle_proof(decls, mods)
    files["wire-views.md"] = render_wire_views(decls, mods)
    # #87's module map (2026-10-14): the table's own renderer, so this leg's byte-identity check covers it
    sys.path.insert(0, os.path.join(ROOT, "tools"))
    import teranode_map
    files["teranode-map.md"] = teranode_map.render()
    # #96 (2026-10-14): the absence ledger's page, rendered from corpus/teranode/absences.json by its own generator
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    import teranode_absences
    files["teranode-absences.md"] = teranode_absences.render()
    # #140 (2026-10-16): the node's client contract, rendered from the same ledger by its own generator
    import node_contract
    files["node-client-contract.md"] = node_contract.render(theorems_text=files["theorems.md"])
    files["README.md"] = render_index(ops, decls, counts, rule_rows, flagged, witnesses)
    if check:
        stale = []
        for rel, content in files.items():
            p = os.path.join(out, rel)
            if not os.path.exists(p) or open(p).read() != content:
                stale.append(rel)
        existing = {os.path.relpath(p, out) for p in glob.glob(f"{out}/**/*.md", recursive=True)}
        extra = sorted(existing - set(files))
        if stale or extra:
            print(f"specgen --check: STALE ({len(stale)} files differ, {len(extra)} unexpected): {stale[:5]} {extra[:5]}; run `make spec`")
            sys.exit(1)
        print(f"specgen --check: OK ({len(files)} files up to date; {len(flagged)} rules flagged)")
        return
    os.makedirs(f"{out}/opcodes", exist_ok=True)
    for rel, content in files.items():
        with open(os.path.join(out, rel), "w") as f:
            f.write(content)
    print(f"specgen: {len(files)} files written to {out}; {len(ops)} opcode pages; {len(flagged)} rules flagged: {', '.join(flagged)}")

if __name__ == "__main__":
    main()
