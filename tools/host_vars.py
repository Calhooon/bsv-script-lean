"""tools/host_vars.py: the maintainers' host values (#177), read once for every Python tool.

A value of docs/PROVENANCE.md section 1a's pins block written `$NAME` (a clone or a built binary) is a path on a
maintainers' host: NAME from the environment, else the `NAME="value"` line of tools/host_private.sh (`$HOME`
expanded; the file is withheld from the public edition), else unresolved. A gate that meets an unresolved value
skips it by name (`path` returns None); any other tool stops with one line and exit 2 (`need`).
harness/src/host.rs is the same reader for the harness. A shell script calls the command-line form,
`python3 tools/host_vars.py NAME [TOOL]`: the value on stdout, else the one line (TOOL's, default host_vars) on
stderr and exit 2."""
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
HOST_FILE = os.path.join(ROOT, "tools", "host_private.sh")


def value(name):
    """NAME from the environment, else from tools/host_private.sh; None when neither holds it."""
    if os.environ.get(name):
        return os.environ[name]
    try:
        src = open(HOST_FILE, encoding="utf-8").read()
    except OSError:
        return None
    m = re.search(r"^" + re.escape(name) + r'="([^"]*)"$', src, re.M)
    return m.group(1).replace("$HOME", os.path.expanduser("~")) if m and m.group(1) else None


def name_of(p):
    """The NAME of a `$NAME` value, else None."""
    m = re.fullmatch(r"\$([A-Z][A-Z0-9_]*)", (p or "").strip())
    return m.group(1) if m else None


def path(p):
    """A pins value as a path: `$NAME` resolved (None when unresolved); any other value with `~` expanded."""
    n = name_of(p)
    return value(n) if n else os.path.expanduser(p)


def refusal(tool, name):
    return f"{tool}: a maintainers' route; {name} is unset and tools/host_private.sh is absent (tools/README.md)"


def need(p, tool):
    """A pins value as a path, or the one line and exit 2."""
    v = path(p)
    if v is None:
        print(refusal(tool, name_of(p)))
        sys.exit(2)
    return v


if __name__ == "__main__":
    if len(sys.argv) not in (2, 3) or not re.fullmatch(r"[A-Z][A-Z0-9_]*", sys.argv[1]):
        print("usage: python3 tools/host_vars.py NAME [TOOL]", file=sys.stderr)
        sys.exit(2)
    v = value(sys.argv[1])
    if v is None:
        print(refusal(sys.argv[2] if len(sys.argv) == 3 else "host_vars", sys.argv[1]), file=sys.stderr)
        sys.exit(2)
    print(v)
