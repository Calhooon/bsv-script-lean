#!/usr/bin/env python3
"""Compare the ordered NodeConfig census with Lean, and enforce the library boundary.

Run directly or through tools/check.sh parameters; the pins leg also runs this.
The chain record uses literal field defaults and Kind/Default/Presence docstrings.
The visible Markdown rows are checked, with no separately maintained manifest.
"""
from __future__ import annotations

import argparse
from pathlib import Path
import re
import sys
import tomllib


class Drift(ValueError):
    pass


def require(condition: bool, message: str) -> None:
    if not condition:
        raise Drift(message)


def lean_code(text: str) -> str:
    """Blank nested Lean comments and strings, preserving line boundaries."""
    out = []
    i = depth = 0
    string = False
    while i < len(text):
        pair = text[i:i + 2]
        ch = text[i]
        if depth:
            if pair == "/-":
                depth += 1
                out.extend("  ")
                i += 2
                continue
            if pair == "-/":
                depth -= 1
                out.extend("  ")
                i += 2
                continue
            out.append("\n" if ch == "\n" else " ")
        elif string:
            if ch == "\\" and i + 1 < len(text):
                out.extend("  ")
                i += 2
                continue
            if ch == '"':
                string = False
            out.append("\n" if ch == "\n" else " ")
        elif pair == "/-":
            depth = 1
            out.extend("  ")
            i += 2
            continue
        elif pair == "--":
            end = text.find("\n", i)
            end = len(text) if end < 0 else end
            out.extend(" " * (end - i))
            i = end
            continue
        elif ch == '"':
            string = True
            out.append(" ")
        elif ch == "«":
            # Escaped identifiers may contain comment/string delimiters.
            end = text.find("»", i + 1)
            require(end >= 0, "unterminated Lean identifier escape")
            out.append(text[i:end + 1])
            i = end + 1
            continue
        else:
            out.append(ch)
        i += 1
    require(depth == 0 and not string, "unterminated Lean comment or string")
    return "".join(out)


def record(text: str, label: str, structure: str = "NodeConfig") -> tuple[str, list[str]]:
    match = re.search(r"^structure " + re.escape(structure) + r"\b[^\n]* where\n(.*?)^  deriving\b", text, re.M | re.S)
    require(match is not None, f"{label}: {structure} record not found")
    body = match.group(1)
    code = lean_code(body)
    names = re.findall(r"^  (\w+)\s*:", code, re.M)
    require(names and len(names) == len(set(names)), f"{label}: empty or duplicate fields")
    return body, names


def table(markdown: str, marker: str) -> list[list[str]]:
    start, end = f"<!-- {marker}:start -->", f"<!-- {marker}:end -->"
    require(markdown.count(start) == markdown.count(end) == 1, f"{marker}: missing or duplicate census markers")
    body = markdown.split(start)[1].split(end)[0]
    rows = []
    for line in body.splitlines():
        if not line.startswith("| `"):
            continue
        cells = [c.strip() for c in re.split(r"(?<!\\)\|", line)[1:-1]]
        require(len(cells) == 5, f"{marker}: expected five cells: {line}")
        require(re.fullmatch(r"`\w+`", cells[0]) is not None, f"{marker}: malformed field name")
        cells[0] = cells[0][1:-1]
        rows.append(cells)
    require(rows and len({r[0] for r in rows}) == len(rows), f"{marker}: empty or duplicate rows")
    return rows


def normalized(value: str) -> str:
    return re.sub(r"\s+", "", value)


def cell_default(cell: str, label: str) -> str:
    match = re.match(r"`([^`]+)`", cell)
    require(match is not None, f"{label}: default must open the cell in backticks")
    return normalized(match.group(1))


def cell_presence(cell: str, label: str) -> str:
    words = re.findall(r"\b(?:mandatory|optional)\b", cell)
    require(len(words) == 1, f"{label}: expected exactly one presence word")
    return words[0]


def script_defaults(text: str, name: str) -> dict[str, str]:
    match = re.search(r"def NodeConfig\." + name + r" : NodeConfig :=\s*\{(.*?)\}", lean_code(text), re.S)
    require(match is not None, f"script {name}: default record not found")
    pairs = re.findall(r"(\w+)\s*:=\s*([\w.]+)", match.group(1))
    require(len(pairs) == len(dict(pairs)), f"script {name}: duplicate defaults")
    return dict(pairs)


def imports(text: str) -> list[tuple[str, ...]]:
    # Module headers allow whitespace-separated imports, including newlines.
    # Stop at another command, rather than treating later namespace names as imports.
    # Decode each escaped component, retaining whole module names. Bare
    # components deliberately include Unicode and primes: an unfamiliar legal
    # identifier must not terminate the scan before a later import-list entry.
    component = r'''(?:«[^»]*»|[^\s.«»(){}\[\]:,;"`]+)'''
    module = re.compile(component + r"(?:\." + component + r")*\.?")
    tokens = re.findall(module.pattern + r"|[^\s]", lean_code(text))
    commands = {"module", "prelude", "import", "public", "private", "meta", "namespace",
                "open", "section", "end", "def", "theorem", "lemma", "example", "opaque",
                "abbrev", "instance", "structure", "inductive", "class", "variable",
                "noncomputable", "set_option", "attribute", "export", "universe"}
    modules = []
    for i, token in enumerate(tokens):
        if token != "import":
            continue
        for name in tokens[i + 1:]:
            if name in commands or not module.fullmatch(name):
                break
            if name != "all":
                parts = re.findall(component, name)
                # A dot inside an escape is part of a filename, not a path
                # separator (Lean.Util.Path.modToFilePath at Lean v4.34.0).
                modules.append(tuple(p[1:-1] if p.startswith("«") else p for p in parts))
    return modules


def network_config(markdown: str, chain: str) -> tuple[int, int]:
    """Compare every network assignment, including explicit source omissions."""
    body, names = record(chain, "BsvChain", "ChainParams")
    rows = table(markdown, "chain-network-config")
    comparison = table(markdown, "chain-network-comparison")
    require([r[0] for r in rows] == [r[0] for r in comparison] == names,
            "ChainParams: census field names/order differ from record")
    docs = re.findall(r"/--((?:(?!/--).)*?)-/\s*\n  (\w+)\s*:", body, re.S)
    require([name for _, name in docs] == names, "ChainParams: every field needs metadata")
    for (doc, name), (_, kind, presence, second, use) in zip(docs, comparison):
        require(kind == "consensus" and "Kind: consensus." in doc, f"ChainParams.{name}: kind mismatch")
        require(cell_presence(presence, f"ChainParams.{name}") == "optional" and "Presence: optional." in doc,
                f"ChainParams.{name}: presence mismatch")
        require("[SRC]" in doc and "at `6504a3af`" in doc and all("[SRC]" in c for c in (presence, second, use)),
                f"ChainParams.{name}: definition, second-oracle or read citation missing")
    networks = ("mainnet", "testnet", "stn", "regtest")
    records = re.findall(r"^def ChainParams\.(\w+) : ChainParams :=\s*\{(.*?)^  \}", lean_code(chain), re.M | re.S)
    require([network for network, _ in records] == list(networks), "ChainParams: network names/order differ")
    for column, (network, values) in enumerate(records, 1):
        pairs = re.findall(r"^\s+(\w+)\s*:=\s*([^\n]+)", values, re.M)
        require([name for name, _ in pairs] == names, f"ChainParams.{network}: field names/order differ")
        for (name, value), row in zip(pairs, rows):
            require(normalized(value) == cell_default(row[column], name),
                    f"ChainParams.{network}.{name}: value mismatch")
            require("[SRC]" in row[column] and "src/chainparams.cpp:" in row[column],
                    f"ChainParams.{network}.{name}: initialization citation missing")
    return len(names), len(networks)


def check(root: Path) -> str:
    md = (root / "docs/PARAMETERS.md").read_text()
    script = (root / "lean/BsvScript/Params.lean").read_text()
    chain = (root / "lean/BsvChain/Params.lean").read_text()
    _, script_names = record(script, "BsvScript")
    inherited = table(md, "script-node-config")
    require([r[0] for r in inherited] == script_names, "BsvScript: census field names/order differ from NodeConfig")
    sv = script_defaults(script, "svMainnetDefault")
    tn = script_defaults(script, "teranodeDefault")
    require(set(sv) == set(tn) == set(script_names), "BsvScript: missing or extra default fields")
    consensus_fields = {"chain", "maxStackMemoryUsageConsensus", "genesisActivationHeight", "chronicleActivationHeight"}
    for name, kind, sv_cell, tn_cell, use in inherited:
        expected = "consensus" if name in consensus_fields else "policy"
        require(kind.split(",")[0] == expected, f"BsvScript.{name}: kind differs from script census classification")
        require(cell_default(sv_cell, name) == normalized(sv[name]), f"BsvScript.{name}: reference default differs")
        require(cell_default(tn_cell, name) == normalized(tn[name]), f"BsvScript.{name}: second-oracle default differs")
        # [SRC] bitcoin-sv 6504a3af src/bitcoind.cpp:140–157 requires this
        # inherited launch input; the other inherited fields are optional.
        presence = "mandatory" if name == "maxStackMemoryUsageConsensus" else "optional"
        require(cell_presence(sv_cell, f"BsvScript.{name}") == presence,
                f"BsvScript.{name}: presence mismatch")
        require("[SRC]" in sv_cell and use, f"BsvScript.{name}: source or use missing")

    require("structure NodeConfig extends BsvScript.Params.NodeConfig where" in lean_code(chain),
            "BsvChain.NodeConfig must extend BsvScript.Params.NodeConfig")
    body, names = record(chain, "BsvChain")
    census = table(md, "chain-node-config")
    require([r[0] for r in census] == names, "BsvChain: census field names/order differ from NodeConfig")
    fields = re.findall(r"/--((?:(?!/--).)*?)-/\s*\n  (\w+)\s*:\s*([^\n]+?)\s*:=\s*([^\n]+)", body, re.S)
    require([f[1] for f in fields] == names, "BsvChain: every field needs a docstring and a literal default")
    cons = pol = 0
    for (doc, name, _, value), (_, kind, sv_cell, tn_cell, use) in zip(fields, census):
        metadata = re.search(r"Kind: (.+?)\.\s+Default:\s+`([^`]+)`\.\s+Presence: (mandatory|optional)\.", doc)
        require(metadata is not None, f"BsvChain.{name}: malformed Kind/Default/Presence metadata")
        doc_kind, doc_default, presence = metadata.groups()
        require(kind == doc_kind, f"BsvChain.{name}: kind mismatch: census {kind!r}, record {doc_kind!r}")
        require(kind.startswith(("consensus", "policy")), f"BsvChain.{name}: unknown kind {kind!r}")
        require(normalized(value) == normalized(doc_default) == cell_default(sv_cell, name),
                f"BsvChain.{name}: default mismatch: census {cell_default(sv_cell, name)!r}, record {value.strip()!r}, doc {doc_default!r}")
        require(cell_presence(sv_cell, f"BsvChain.{name}") == presence, f"BsvChain.{name}: presence mismatch")
        require("[SRC] Definition:" in doc and "initialization:" in doc and "at `6504a3af`" in doc,
                f"BsvChain.{name}: definition/initialization/pin citation missing")
        require("[SRC]" in sv_cell and "[SRC]" in use and tn_cell,
                f"BsvChain.{name}: source, transition or second-oracle cell missing")
        cons += kind.startswith("consensus")
        pol += kind.startswith("policy")
    # The instance uses the field defaults; an override here must not evade the census.
    code = lean_code(chain)
    require(re.search(r"def NodeConfig\.defaults : NodeConfig :=\s*\{\s*toNodeConfig := BsvScript\.Params\.NodeConfig\.svMainnetDefault\s*\}", code) is not None,
            "BsvChain.defaults must use the documented field defaults and script projection")
    require(re.search(r"instance instInhabitedNodeConfig : Inhabited NodeConfig := ⟨NodeConfig.defaults⟩", code) is not None,
            "BsvChain: default instance differs from NodeConfig.defaults")
    network_fields, networks = network_config(md, chain)
    pins = (root / "docs/PROVENANCE.md").read_text()
    require(re.search(r"^reference.commit\s*=\s*6504a3aff65ba97c0f6c80962b033e35ecbfed4b\s*$", pins, re.M) is not None,
            "reference pin moved: re-read the census citations")
    require(re.search(r"^teranode.commit\s*=\s*4edb60a40c6628ff0ef60231c2628efd7103fde5\s*$", pins, re.M) is not None,
            "second-oracle pin moved: re-read the census cells")

    lake = tomllib.loads((root / "lean/lakefile.toml").read_text())
    libs = {lib["name"]: lib for lib in lake["lean_lib"]}
    require("BsvScript" in libs and libs.get("BsvChain", {}).get("roots") == ["BsvChain"],
            "Lake must declare BsvScript and BsvChain with its library root")
    require("BsvChain" in lake["defaultTargets"], "default Lake build must include BsvChain")
    require(("BsvChain", "Params") in imports((root / "lean/BsvChain.lean").read_text()), "BsvChain root must import its parameters")
    require(("BsvScript", "Params") in imports(chain), "BsvChain.Params must depend on BsvScript.Params")
    pending = [root / "lean/BsvScript.lean", *sorted((root / "lean/BsvScript").rglob("*.lean"))]
    visited = set()
    while pending:
        path = pending.pop()
        if path in visited:
            continue
        visited.add(path)
        for module in imports(path.read_text()):
            local = Path(str(root.joinpath("lean", *module)) + ".lean").resolve()
            chain_dir = (root / "lean/BsvChain").resolve()
            require(module[0] != "BsvChain" and chain_dir not in local.parents
                    and local != (root / "lean/BsvChain.lean").resolve(),
                    f"library boundary: {path.relative_to(root)} imports {'.'.join(module)}")
            if local.is_file():
                pending.append(local)
    for path in [root / "lean/BsvChain.lean", *sorted((root / "lean/BsvChain").rglob("*.lean"))]:
        require(re.search(r"\b(?:sorry|axiom)\b", lean_code(path.read_text())) is None,
                f"{path.relative_to(root)}: proof placeholder or domain axiom")
    return (f"check-parameters: GREEN ({len(script_names)} inherited fields; {len(names)} chain fields: "
            f"{cons} consensus / {pol} policy including node settings; names, order, kinds, defaults, presence; "
            f"{network_fields} network fields / {networks} networks / {network_fields * networks} cells; import direction)")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parent.parent)
    args = parser.parse_args()
    try:
        print(check(args.root))
    except (Drift, OSError, ValueError, KeyError) as error:
        print(f"check-parameters: RED: {error}")
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
