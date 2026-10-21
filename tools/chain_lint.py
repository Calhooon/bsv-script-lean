#!/usr/bin/env python3
"""[M] 2026-10-13: #77 static purity and explicit-time lint for BsvChain.

This is a lexical check, not Lean elaboration. Comments and strings are blanked
with line positions preserved. A projection ending in .now must be rooted in
an argument of the definition; bare now must be an explicit signature binder.

[M] 2026-10-14 (#77, lane s6-77b): the parameters the same way. A definition,
abbreviation, instance or structure (its body, its default arguments and its
fields' defaults) outside lean/BsvChain/Params.lean that names a network's
record (`ChainParams.mainnet`, `.regtest`, the network tables) or the census
defaults (`NodeConfig.defaults`) is a hit unless the allowlist gives the
reason. Theorems are not linted here: a theorem that fixes a network is
classified on spec/theorems.md by tools/specgen.py (its quantification line).
"""
from __future__ import annotations

import argparse
from pathlib import Path
import re
import sys

try:
    from tools.check_parameters import lean_code
except ModuleNotFoundError:
    from check_parameters import lean_code

# (repository-relative path, kind) -> reason. Every exemption needs a reason.
ALLOWLIST: dict[tuple[str, str], str] = {
    ("lean/BsvChain/Mempool.lean", "fixed NodeConfig.defaults in structure Mempool"):
        "the empty pool's two filter fields are sized at the census defaults; every transition takes the "
        "pool as an argument, so a configured pool is an input (lean/Test/MempoolCheck.lean builds it with "
        "rejectFilter cfg and removedNonFinalFilter cfg) and no transition re-reads the defaults",
    ("lean/BsvChain/Finality.lean", "fixed NodeConfig.defaults in def medianTimePast"):
        "a default argument only: every call under lean/BsvChain passes cfg.medianTimeSpan explicitly [M] "
        "2026-10-14 (Chain.lean, Finality.lean, Pow.lean)",
    ("lean/BsvChain/Properties/StaleRun.lean", "fixed .regtest in def staleRunContext"):
        "the context of #68's kernel-checked concrete regtest run, a fixture of the theorems about that run "
        "(spec/theorems.md: a statement about a concrete run, network-specific by design)",
    ("lean/BsvChain/Properties/StaleRun.lean", "fixed NodeConfig.defaults in def staleRunContext"):
        "the same fixture: the run's configuration is the census defaults",
}
# [M] 2026-10-14 (#77): a network's record or the census defaults, named outside Params.lean
NETWORK = re.compile(r"(?<![\w.'!?»])(?:(?:BsvChain\.)?(?:ChainParams|NetworkData|DepthNetwork)\.(?:mainnet|testnet|stn|regtest)"
                     r"|(?:BsvChain\.)?NodeConfig\.defaults|\.(?:mainnet|testnet|stn|regtest))(?![\w'!?])")
PARAM_COMMANDS = {"def", "abbrev", "instance", "structure"}
IDENT = r"(?:«[^»]+»|[^\W\d][\w'!?]*)"
TOKEN = re.compile(IDENT + r"(?:\." + IDENT + r")*")
BANNED = {"IO", "BaseIO", "EIO", "unsafe", "opaque", "Std.Time",
          "IO.monoMsNow", "IO.monoNanosNow", "IO.getRandomBytes", "IO.getEnv",
          "getCurrentTime"}
COMMAND = re.compile(
    r"^(?P<indent> *)(?:@\[[^\]\n]*\]\s*)*(?:(?:private|protected|noncomputable|partial|public)\s+)*"
    r"(?P<command>def|theorem|lemma|example|abbrev|instance|structure|inductive|"
    r"class|namespace|section|end|variable|attribute|set_option|open|export|"
    r"initialize|syntax|macro|elab)\b", re.M)
BINDER = re.compile(r"[({\[]\s*([^:(){}\[\]]+)\s*:")


def binder_names(signature: str) -> set[str]:
    return {m.group(0).removeprefix("«").removesuffix("»") for group in BINDER.finditer(signature)
            for m in TOKEN.finditer(group.group(1))}


def body_offset(declaration: str) -> int | None:
    """Find a body delimiter outside signature binders/default values."""
    depth = 0
    for i, ch in enumerate(declaration):
        if ch in "({[":
            depth += 1
        elif ch in ")}]":
            depth -= 1
        elif depth == 0:
            if declaration[i:i + 2] == ":=":
                return i
            if ch == "|" and not declaration[declaration.rfind("\n", 0, i) + 1:i].strip():
                return i
    return None


def hits(text: str, relative: str = "") -> list[tuple[int, str]]:
    code = lean_code(text)
    found: list[tuple[int, str]] = []

    def add(offset: int, kind: str) -> None:
        found.append((code.count("\n", 0, offset) + 1, kind))

    for token in TOKEN.finditer(code):
        name = token.group(0)
        parts = [p.removeprefix("«").removesuffix("»") for p in re.findall(IDENT, name)]
        # Qualified and escaped forms cannot hide a banned identifier.
        kinds = [kind for kind in BANNED
                 if kind in parts or kind.split(".") == parts[:len(kind.split("."))]]
        if kinds:
            add(token.start(), "forbidden " + sorted(kinds, key=lambda k: (-len(k), k))[0])
    for attr in re.finditer(r"@\[\s*(?:extern|implemented_by)(?![\w'!?])", code):
        add(attr.start(), "forbidden " + re.sub(r"\s+", "", attr.group(0)))

    commands = list(COMMAND.finditer(code))
    if not relative.endswith("lean/BsvChain/Params.lean"):
        for index, command in enumerate(commands):
            if command.group("command") not in PARAM_COMMANDS:
                continue
            end = next((c.start() for c in commands[index + 1:]
                        if len(c.group("indent")) <= len(command.group("indent"))), len(code))
            head = re.match(r"\s*(" + IDENT + r"(?:\." + IDENT + r")*)", code[command.end():end])
            name = head.group(1) if head else "?"
            # the declared name is skipped: a network table's own declaration (`def NetworkData.mainnet`) is not a read
            for fixed in NETWORK.finditer(code, command.end() + (head.end() if head else 0), end):
                add(fixed.start(), f"fixed {fixed.group(0)} in {command.group('command')} {name}")
    for index, command in enumerate(commands):
        if command.group("command") != "def":
            continue
        end = next((c.start() for c in commands[index + 1:]
                    if len(c.group("indent")) <= len(command.group("indent"))), len(code))
        declaration = code[command.end():end]
        # := bodies and equation-style definitions (a line beginning with |).
        split = body_offset(declaration)
        if split is None:
            continue
        signature = declaration[:split]
        arguments = binder_names(signature)
        body_start = command.end() + split + (2 if declaration[split:split + 2] == ":=" else 1)
        body = code[body_start:end]
        for token in TOKEN.finditer(body):
            parts = [p.removeprefix("«").removesuffix("»")
                     for p in re.findall(IDENT, token.group(0))]
            if parts[-1] != "now":
                continue
            # Record field assignment is a label, not a read.
            if re.match(r"\s*:=", body[token.end():]):
                continue
            if (len(parts) == 1 and "now" in arguments or
                    len(parts) > 1 and parts[0] in arguments):
                continue
            add(command.start(), "free now in def " + signature.split()[0])
            break
    return sorted(found)


def check(root: Path) -> tuple[int, list[str]]:
    files = [root / "lean/BsvChain.lean", *sorted((root / "lean/BsvChain").rglob("*.lean"))]
    reports = []
    for path in files:
        relative = path.relative_to(root).as_posix()
        for line, kind in hits(path.read_text(), relative):
            reason = ALLOWLIST.get((relative, kind))
            if reason is not None:
                if not reason.strip():
                    raise ValueError("allowlist entry needs a reason")
                continue
            reports.append(f"{relative}:{line}: {kind}")
    return len(files), reports


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parent.parent)
    args = parser.parse_args()
    try:
        count, reports = check(args.root)
    except (OSError, ValueError) as error:
        print(f"chain lint: RED [X] ({error})")
        return 1
    if reports:
        print("\n".join(reports))
        print(f"chain lint: RED [X] ({count} files, {len(reports)} hits)")
        return 1
    print(f"chain lint: GREEN [X] ({count} files, 0 clock, IO or network reads under lean/BsvChain; "
          f"0 network records or census defaults named by a definition outside Params.lean, "
          f"{len(ALLOWLIST)} allowlisted with reasons)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
