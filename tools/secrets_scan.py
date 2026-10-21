#!/usr/bin/env python3
"""tools/secrets_scan.py (S3, lane gate-135, #135; [M] 2026-10-14): the secrets scan's Python engine.

tools/secrets_scan.sh is the entry point; it runs gitleaks at its pin where present and this engine elsewhere. Both read
the rules of tools/secrets_patterns.txt and the exceptions of tools/secrets_allow.txt, and nothing else.

MODES
  --tree             every tracked file of the working tree (`git ls-files`; a walk of the tree where git is absent,
                     the cargo targets, the Lean caches, node_modules and scratch skipped by name)
  --staged           the lines the index adds over HEAD (`git diff --cached`), the pre-commit hook's scan
  --range A..B       the lines each commit of A..B adds (`git log -p A..B`), the pre-push hook's scan
  --paths F...       the named files whole (the failure case's dry run on a scratch file)
  --self-test        every rule fires on a fake sample assembled here from fragments, and a clean line fires none
  --gitleaks-config OUT   writes the gitleaks config of the same rules and exceptions (the default rule set OFF)
OUTPUT: one line per finding, `<path>:<line>: <rule-id> (<4 characters>... , <length> characters; redacted)`, never the
value; then the verdict line `secrets: GREEN [X] ...` or `secrets: RED [X] ...`. Exit 0 on GREEN, 1 on RED, 2 on a setup
error (a missing patterns file, a regex that does not compile, git failing).
"""
import fnmatch
import os
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PATTERNS = ROOT / "tools" / "secrets_patterns.txt"
ALLOW = ROOT / "tools" / "secrets_allow.txt"
SKIP_DIRS = {".git", ".lake", "target", "node_modules", "scratch", "__pycache__"}
MAX_BYTES = 64 * 1024 * 1024


def die(msg):
    print(f"secrets: setup error: {msg}")
    sys.exit(2)


def load_rules():
    if not PATTERNS.is_file():
        die(f"{PATTERNS.relative_to(ROOT)} is missing")
    rules = []
    for n, line in enumerate(PATTERNS.read_text(encoding="utf-8").splitlines(), 1):
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        parts = line.split("\t")
        if len(parts) not in (2, 3) or not parts[0] or not parts[1]:
            die(f"tools/secrets_patterns.txt:{n}: not `<rule-id><TAB><regex>[<TAB><keywords>]`")
        kws = tuple(k for k in (parts[2].split(",") if len(parts) == 3 else []) if k)
        try:
            rules.append((parts[0], re.compile(parts[1]), kws))
        except re.error as e:
            die(f"tools/secrets_patterns.txt:{n}: {parts[0]}: {e}")
    if not rules:
        die("tools/secrets_patterns.txt holds no rule")
    return rules


def load_allow():
    allow = []
    if ALLOW.is_file():
        for n, line in enumerate(ALLOW.read_text(encoding="utf-8").splitlines(), 1):
            if not line.strip() or line.lstrip().startswith("#"):
                continue
            parts = line.split("\t")
            if len(parts) != 3 or not parts[0] or not parts[1] or not parts[2].strip():
                die(f"tools/secrets_allow.txt:{n}: not `<rule-id><TAB><path glob or match:<regex>><TAB><the reason>`")
            if parts[1].startswith("match:"):
                try:
                    allow.append((parts[0], None, re.compile(parts[1][6:])))
                except re.error as e:
                    die(f"tools/secrets_allow.txt:{n}: {e}")
            else:
                allow.append((parts[0], parts[1], None))
    return allow


def allowed(allow, rule, path, value):
    return any((r == "*" or r == rule) and (fnmatch.fnmatch(path, g) if g is not None else rx.search(value))
               for r, g, rx in allow)


def redact(value):
    return f"{value[:4]}... , {len(value)} characters; redacted"


def scan_text(rules, allow, path, text, findings, first_line=1):
    # each rule runs over the whole text (no rule's class admits a newline, so no hit spans two lines); the line number
    # is counted only for a hit
    low = text.lower() if any(k for _, _, k in rules) else text
    for rule, rx, kws in rules:
        if kws and not any(k in low for k in kws):
            continue
        for m in rx.finditer(text):
            if not allowed(allow, rule, path, m.group(0)):
                lineno = first_line + text.count("\n", 0, m.start())
                findings.append(f"{path}:{lineno}: {rule} ({redact(m.group(0))})")


def read_text(p):
    try:
        if p.is_symlink() or not p.is_file() or p.stat().st_size > MAX_BYTES:
            return None
        data = p.read_bytes()
    except OSError:
        return None
    if b"\0" in data[:8192]:
        return None   # a binary file (the gzip corpora): gitleaks skips them too
    return data.decode("utf-8", errors="replace")


def tracked_files():
    try:
        out = subprocess.run(["git", "-C", str(ROOT), "ls-files", "-z"], capture_output=True, check=True).stdout
        return [f for f in out.decode().split("\0") if f], "git ls-files"
    except (OSError, subprocess.CalledProcessError):
        files = []
        for d, dirs, names in os.walk(ROOT):
            dirs[:] = [x for x in dirs if x not in SKIP_DIRS]
            files += [os.path.relpath(os.path.join(d, n), ROOT) for n in names]
        return sorted(files), "a walk of the tree (no git)"


def scan_files(rules, allow, files, findings):
    n = 0
    for rel in files:
        text = read_text(ROOT / rel if not os.path.isabs(rel) else Path(rel))
        if text is None:
            continue
        n += 1
        scan_text(rules, allow, rel, text, findings)
    return n


def scan_diff(rules, allow, cmd, findings):
    # the added lines of `git diff --cached` (the index) or of `git log -p A..B` (every commit's own diff, as gitleaks
    # reads a range: a line one commit adds and a later one removes is still in the history, and still refused)
    try:
        out = subprocess.run(["git", "-C", str(ROOT), *cmd, "-U0", "--no-color", "--no-ext-diff", "--no-renames",
                              "--diff-filter=d"], capture_output=True, check=True).stdout
    except (OSError, subprocess.CalledProcessError) as e:
        die(f"git {' '.join(cmd)} failed: {e}")
    return scan_diff_text(rules, allow, out.decode("utf-8", errors="replace"), findings)


def scan_diff_text(rules, allow, text, findings):
    # `+++ ` and `--- ` are file headers only between a `diff --git ` line and the next `@@` hunk header: an added line
    # whose content starts with `++ ` prints as `+++ ...` inside a hunk and is scanned, never taken for a header (lens
    # gate-135's WRONG item: it reset the path and left the file's later added lines unscanned)
    path, lineno, files, added, commit, in_hdr = None, 0, set(), 0, "", False
    hunk = re.compile(r"^@@ -\d+(?:,\d+)? \+(\d+)(?:,\d+)? @@")
    for raw in text.split("\n"):
        if raw.startswith("commit ") and len(raw) == 47:
            commit, path, in_hdr = raw[7:16], None, False
            continue
        if raw.startswith("diff --git "):
            in_hdr, path = True, None
            continue
        if in_hdr and raw.startswith("+++ "):
            path = raw[6:] if raw.startswith("+++ b/") else None
            continue
        if in_hdr and (raw.startswith("--- ") or raw.startswith("Binary files ")):
            continue
        m = hunk.match(raw)
        if m:
            lineno, in_hdr = int(m.group(1)), False
            continue
        if in_hdr:
            continue
        if path and raw.startswith("+"):
            files.add(path)
            added += 1
            n0 = len(findings)
            scan_text(rules, allow, path, raw[1:], findings, lineno)
            if commit:
                findings[n0:] = [f"{f} (commit {commit})" for f in findings[n0:]]
            lineno += 1
    return len(files), added


def self_test(rules):
    # the fake samples, joined from fragments so no literal sample stands in this file; none is a credential
    a, d, h = "A" * 64, "7" * 64, "0123456789abcdef" * 4
    samples = {
        "private-key-block": "-----" + "BEGIN EC " + "PRIVATE KEY" + "-----",
        "aws-access-key-id": "AK" + "IA" + "Z" * 16,
        "github-token": "gh" + "p_" + a[:36],
        "github-fine-grained-token": "github" + "_pat_" + a[:60],
        "anthropic-key": "sk-" + "ant-" + "api" + "03-" + a[:40],
        "openai-key": "sk-" + "proj-" + a[:40],
        "openai-legacy-key": "sk-" + a[:48],
        "slack-token": "xo" + "xb-" + d[:12],
        "slack-webhook": "https://hooks." + "slack.com/services/" + "T" + "ZZZZ" + "/B" + "ZZZZ" + "/" + a[:24],
        "google-api-key": "AI" + "za" + a[:35],
        "stripe-live-key": "sk" + "_live_" + a[:24],
        "npm-token": "np" + "m_" + a[:36],
        "telegram-bot-token": d[:9] + ":" + "AA" + a[:33],
        "jwt": "ey" + "J" + a[:12] + ".ey" + "J" + a[:12] + "." + a[:12],
        "crates-io-token": "ci" + "o" + a[:32],
        "modal-token": "a" + "s-" + a[:22],
        "taal-api-key": "main" + "net_" + h[:32],
        "wif-private-key": "K" + "z" * 51,
        "extended-private-key": "xp" + "rv" + "z" * 108,
        "url-credentials": "postgres" + "://user:" + "hunter2hunter2" + "@db.example",
        "secret-assignment": "API" + "_KEY=" + a[:30],
    }
    ids = [r for r, _, _ in rules]
    bad = [r for r in ids if r not in samples] + [r for r in samples if r not in ids]
    if bad:
        print(f"secrets --self-test: RED: rules and samples differ: {', '.join(bad)}")
        return 1
    miss = [r for r, rx, kws in rules if not rx.search(samples[r]) or (kws and not any(k in samples[r].lower() for k in kws))]
    clean = "let x = 0x" + d[:40] + "; // OP_CHECKSIG over " + h[:32] + " then the token budget"
    noisy = [r for r, rx, _ in rules if rx.search(clean)]
    if miss or noisy:
        print(f"secrets --self-test: RED: no hit on the sample of {miss}; a hit on the clean line by {noisy}")
        return 1
    # the diff parser: an added line `++ x` prints as `+++ x` inside a hunk; it is content, and the sample after it fires
    diff = ("diff --git a/c.txt b/c.txt\nnew file mode 100644\nindex 0000000..1111111\n--- /dev/null\n+++ b/c.txt\n"
            "@@ -0,0 +1,2 @@\n+++ x\n+" + samples["github-token"] + "\n")
    got = []
    scan_diff_text(rules, [], diff, got)
    if len(got) != 1 or not got[0].startswith("c.txt:2: github-token "):
        print(f"secrets --self-test: RED: the diff case (`++ x` then a sample) gave {got}, not one hit at c.txt:2")
        return 1
    print(f"secrets --self-test: GREEN: {len(rules)} rules, each fires on its fake sample; the clean line fires none; "
          "a `++ x` added line is content, and the sample after it fires")
    return 0


def glob_regex(g):
    # fnmatch's glob as an anchored RE2 regex over a repo-relative path (`*` crosses `/`, as in allowed())
    return "^(\\./)?" + "".join(".*" if c == "*" else "." if c == "?" else re.escape(c) for c in g) + "$"


def gitleaks_config(rules, allow, out):
    q = lambda x: "'''" + x + "'''"
    lines = ["# generated by tools/secrets_scan.py --gitleaks-config from tools/secrets_patterns.txt and",
             "# tools/secrets_allow.txt; never edited by hand, never committed", 'title = "bsv-script-lean secrets scan"']
    for rule, rx, kws in rules:
        lines += ["", "[[rules]]", f'id = "{rule}"', f"regex = {q(rx.pattern)}"]
        if kws:
            lines.append("keywords = [" + ", ".join(f'"{k}"' for k in kws) + "]")
        for r, g, arx in allow:
            if r not in ("*", rule):
                continue
            lines.append("[[rules.allowlists]]")
            lines.append(f"paths = [{q(glob_regex(g))}]" if g is not None else f'regexTarget = "match"\nregexes = [{q(arx.pattern)}]')
    Path(out).write_text("\n".join(lines) + "\n", encoding="utf-8")
    return 0


def main(argv):
    rules = load_rules()
    if argv[:1] == ["--self-test"]:
        return self_test(rules)
    allow = load_allow()
    if argv[:1] == ["--gitleaks-config"] and len(argv) == 2:
        return gitleaks_config(rules, allow, argv[1])
    findings = []
    if argv[:1] == ["--tree"]:
        files, how = tracked_files()
        n = scan_files(rules, allow, files, findings)
        scope = f"the tree: {n} text files of {len(files)} ({how})"
    elif argv[:1] == ["--staged"]:
        nf, nl = scan_diff(rules, allow, ["diff", "--cached"], findings)
        scope = f"the staged lines: {nl} added lines in {nf} files"
    elif argv[:1] == ["--range"] and len(argv) == 2 and ".." in argv[1]:
        a, b = argv[1].split("..", 1)
        nf, nl = scan_diff(rules, allow, ["log", "-p", "--format=commit %H", f"{a}..{b}"], findings)
        short = re.sub(r'([0-9a-f]{9})[0-9a-f]+', r'\1', argv[1])
        scope = f"the range {short}: {nl} added lines in {nf} files"
    elif argv[:1] == ["--paths"] and len(argv) > 1:
        n = scan_files(rules, allow, argv[1:], findings)
        scope = f"{n} named files"
    else:
        print(__doc__)
        return 2
    for f in findings:
        print(f"  {f}")
    word = "RED" if findings else "GREEN"
    print(f"secrets: {word} [X] (engine python, {len(rules)} rules of tools/secrets_patterns.txt, {len(allow)} reviewed "
          f"exceptions; {scope}; findings {len(findings)})")
    return 1 if findings else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
