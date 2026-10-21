#!/usr/bin/env python3
"""tools/column.py (bsv-script-lean #124; S3, lane column-124, 2026-10-14): one implementation's column on one release,
in one command. `make column IMPL=<impl> PIN=<version or tag>` runs it through tools/column.sh.

What it does, in order:
  1. reads the pins block of docs/PROVENANCE.md section 1a (the same reader as tools/check_pins.py) and the
     implementation's current pin;
  2. PIN equal to the current pin is a DRY RUN: no site moves, and nothing under corpus/ is written. PIN different
     is a PIN MOVE: the implementation's sites (the ones section 1a names and `make check-pins` reads) move to PIN in
     this worktree, and the new verdicts are recorded into the corpora as the bump records of 2026-10-12 did;
  3. builds or installs the implementation at the pin as harness/README.md prescribes (cargo for bsv-rs, `make
     gosdk-build`, `make tssdk-install`, `make gobdk-build`); sv-node and teranode are the owner's instances: this
     command names the instance it needs and never starts one;
  4. re-runs every corpus the column records (the keys of its witness manifest, corpus/witnesses/[<impl>/]manifest.json)
     through the existing drivers: spec_recorded with the corpus's recorded spec configuration, then run_bsvrs and
     run_diff (bsv-rs), run_engine (go-sdk, ts-sdk, gobdk, with the recorded words) or run_svnode (sv-node);
     a dry run drives them with --record on a scratch copy of each corpus under harness/target/column/;
  5. compares the run with the committed column: per corpus the entries, the agreements per comparison column, the
     classified rows by class and the unexplained ones; per entry the implementation's own verdict keys (the moved
     rows, by id);
     a move re-stamps a corpus manifest's sha256, count and the implementation's own row, and `verdicts` and
     `provenance` where the runner writes them (run_bsvrs.rs:230, :34-47 restamp_provenance); where the corpus
     generator owns the tally (xsig-144, the reference's, tools/xsig_witness.py restamp_manifest) it keeps both as
     committed ([M] 2026-10-17, #148's lens: the 0.7.0 move had replaced xsig-144's reference tally with bsv-rs's
     own; #148's second lens: the seven corpora whose `verdicts` is bsv-rs's own keep the runner's);
  6. writes the record docs/records/<stamp>-column-<impl>-<pin>-s3.md with its .json and .txt (the commands, their
     UTC times, start loads and exits), and prints the verdict line `column: ...`.

Exit: 0 when the dry run reproduces the recorded column or the move measured every corpus GREEN; 1 when a dry run
differs or a driver is RED (a classifier stop: the move is measured, never landed past it); 2 a usage or setup stop
(a missing instance, clone, toolchain or commit), never a verdict; 3 when the 1-minute load stayed at 20 or above.
"""
import argparse
import datetime
import gzip
import hashlib
import io
import json
import os
import re
import shlex
import shutil
import socket
import subprocess
import sys
import time

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
HARNESS = os.path.join(ROOT, "harness")
PROVENANCE = os.path.join(ROOT, "docs", "PROVENANCE.md")
LOAD_LIMIT = 20.0  # CLAUDE.md rule 17: nothing starts above a 1-minute load of 20
MOVING = False  # set when a pin move has started writing sites: a stop then names the recovery

# The columns. `names` are the per-entry verdict keys (`<name>@<version>`) the implementation's driver records;
# `witness` its witness manifest; `pin` the section 1a key whose value the PIN argument is compared with.
IMPLS = {
    "bsv-rs": {"pin": "bsv-rs.crate", "names": ["bsv-rs"], "witness": "corpus/witnesses/manifest.json",
               "driver": "run_diff", "prefix": ""},
    "go-sdk": {"pin": "go-sdk.version", "names": ["go-sdk", "go-sdk-mempool"], "witness": "corpus/witnesses/go-sdk/manifest.json",
               "driver": "run_engine", "engine": "gosdk", "prefix": ""},
    "ts-sdk": {"pin": "ts-sdk.version", "names": ["ts-sdk", "ts-sdk-mempool", "ts-sdk-default"],
               "witness": "corpus/witnesses/ts-sdk/manifest.json", "driver": "run_engine", "engine": "tssdk", "prefix": ""},
    "gobdk": {"pin": "gobdk.pseudo_version", "names": ["gobdk", "gobdk-mempool"], "witness": "corpus/witnesses/gobdk/manifest.json",
              "driver": "run_engine", "engine": "gobdk", "prefix": ""},
    "sv-node": {"pin": "reference.tag", "names": ["sv-node", "sv-node-mempool"], "witness": "corpus/witnesses/sv-node/manifest.json",
                "driver": "run_svnode", "prefix": ""},
    "teranode": {"pin": "teranode.tag", "names": [], "witness": None, "driver": "run_teranode", "prefix": ""},
}


# ---------------------------------------------------------------- the receipt
KEEP = re.compile(r"^(spec_recorded: |run_bsvrs --record: |(run_diff|run_engine|run_svnode|run_bsvrs): (GREEN|RED)|  agree: |  witnesses: )")


class Receipt:
    def __init__(self):
        self.lines = []
        self.steps = []

    def note(self, text):
        print(text, flush=True)
        self.lines.append(text)

    def run(self, cmd, cwd=ROOT, env=None, capture=True, check=False, stdout_path=None):
        wait_load(self)
        start = utc()
        load0 = load1()
        t0 = time.time()
        shown = " ".join(shlex.quote(c) for c in cmd).replace(ROOT, "$ROOT")
        self.note(f"$ {shown}    [cwd {os.path.relpath(cwd, ROOT) or '.'}; start {start}; load1 {load0}]")
        out_f = open(stdout_path, "wb") if stdout_path else None
        r = subprocess.run(cmd, cwd=cwd, env=env or os.environ.copy(), stdout=out_f or subprocess.PIPE,
                           stderr=subprocess.STDOUT if not out_f else subprocess.PIPE)
        if out_f:
            out_f.close()
        text = (r.stdout.decode(errors="replace") if not out_f else "") + (r.stderr.decode(errors="replace") if out_f and r.stderr else "")
        for line in text.splitlines():
            # the receipt keeps the drivers' own verdict and count lines; their rule tables, citations and tier-2 notes stay
            # in the scratch witness files (the committed witness manifests already carry them)
            if capture and KEEP.match(line):
                self.lines.append("  " + line[:600].replace(ROOT, "$ROOT"))
        verdicts = [l for l in text.splitlines() if re.match(r"^(run_diff|run_engine|run_bsvrs|run_svnode|spec_recorded)(:| --record:)", l)]
        for v in verdicts:
            print("  " + v[:400], flush=True)
        self.lines.append(f"  exit {r.returncode}; end {utc()}; {time.time() - t0:.1f} s")
        self.steps.append({"cmd": shown, "cwd": os.path.relpath(cwd, ROOT) or ".", "start": start, "load1": load0,
                           "exit": r.returncode, "seconds": round(time.time() - t0, 1)})
        if check and r.returncode != 0:
            stop(self, 2, f"`{shown}` exited {r.returncode}: {text.strip().splitlines()[-1] if text.strip() else ''}")
        return r.returncode, text


def utc():
    return datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def load1():
    try:
        return float(subprocess.run(["sysctl", "-n", "vm.loadavg"], capture_output=True, text=True).stdout.split()[1])
    except Exception:
        return os.getloadavg()[0]


def wait_load(rec):
    """Nothing starts at a 1-minute load of 20 or above (rule 17): wait in 30 s steps, up to COLUMN_LOAD_WAIT seconds."""
    budget = int(os.environ.get("COLUMN_LOAD_WAIT", "1800"))
    waited = 0
    while load1() >= LOAD_LIMIT:
        if waited >= budget:
            stop(rec, 3, f"the 1-minute load stayed at {LOAD_LIMIT:.0f} or above for {waited} s (rule 17); nothing started")
        if waited == 0:
            rec.note(f"column: the 1-minute load is {load1():.2f}, at or above {LOAD_LIMIT:.0f}: waiting (rule 17)")
        time.sleep(30)
        waited += 30


def stop(rec, code, why):
    word = {2: "SETUP STOP (no verdict was reached)", 3: "WALLED BY LOAD"}.get(code, "STOP")
    rec.note(f"column: {word}: {why}")
    if MOVING:
        rec.note("column: the tree may be half-moved; git checkout -- . && git clean -fd corpus/ restores the commit the run started from")
    sys.exit(code)


# ---------------------------------------------------------------- the pins block
def read(path):
    with open(os.path.join(ROOT, path), encoding="utf-8") as f:
        return f.read()


def write(path, text):
    with open(os.path.join(ROOT, path), "w", encoding="utf-8") as f:
        f.write(text)


def pins_block():
    m = re.search(r"```pins\n(.*?)```", read("docs/PROVENANCE.md"), re.S)
    pins = {}
    for line in m.group(1).splitlines():
        line = line.split("#", 1)[0].strip()
        if line:
            k, _, v = line.partition("=")
            pins[k.strip()] = v.strip()
    return pins


def set_pin(key, value, moves):
    """Move one value of the pins block, keeping the line's alignment and its comment."""
    text = read("docs/PROVENANCE.md")
    a, b = text.index("```pins\n"), text.index("```", text.index("```pins\n") + 8)
    block = text[a:b]
    pat = re.compile(r"^(" + re.escape(key) + r"\s*=\s*)(\S+)(.*)$", re.M)
    m = pat.search(block)
    if not m:
        raise SystemExit(f"column: the pins block has no {key}")
    if m.group(2) != value:
        moves.append(("docs/PROVENANCE.md §1a " + key, m.group(2), value))
        block = block[:m.start(2)] + value + block[m.end(2):]
        write("docs/PROVENANCE.md", text[:a] + block + text[b:])


def sub_site(path, pattern, value, moves, label=None):
    """Move one site: `pattern` has one group, the value; the site must exist exactly once."""
    text = read(path)
    found = list(re.finditer(pattern, text, re.M))
    if len(found) != 1:
        raise SystemExit(f"column: {path}: {len(found)} matches for the site {pattern!r} (one expected)")
    m = found[0]
    if m.group(1) != value:
        moves.append((label or f"{path} ({pattern})", m.group(1), value))
        write(path, text[:m.start(1)] + value + text[m.end(1):])
    return m.group(1)


def home(p):
    return os.path.expanduser(p)


def git(clone, *args):
    r = subprocess.run(["git", "-C", clone] + list(args), capture_output=True, text=True)
    return r.returncode, r.stdout.strip()


def tag_commit(clone, tag):
    if not os.path.exists(os.path.join(home(clone), ".git")):
        return None
    rc, out = git(home(clone), "rev-parse", f"{tag}^{{commit}}")
    return out if rc == 0 else None


# ---------------------------------------------------------------- the site moves (a PIN MOVE only)
def move_sites(impl, pin, args, rec, pins):
    """Move the implementation's sites to `pin`. Returns the list of (site, before, after). PLAN lists, writes nothing."""
    moves = []
    if impl == "bsv-rs":
        commit = args.commit or tag_commit(pins["bsv-rs.clone"], "v" + pin)
        if not commit:
            stop(rec, 2, f"bsv-rs v{pin}: no commit (the clone {pins['bsv-rs.clone']} lacks the tag; pass COMMIT=<sha>, read from the public tag)")
        sub_site("harness/Cargo.toml", r'^bsv-rs\s*=\s*(?:\{\s*version\s*=\s*)?"=([^"]+)"', pin, moves)
        rec.run(["cargo", "update", "-p", "bsv-rs", "--precise", pin], cwd=HARNESS, check=True)
        lock = read("harness/Cargo.lock")
        m = re.search(r'name = "bsv-rs"\nversion = "([^"]+)"\nsource = "[^"]+"\nchecksum = "([0-9a-f]+)"', lock)
        if not m or m.group(1) != pin:
            stop(rec, 2, "harness/Cargo.lock does not carry bsv-rs " + pin + " after cargo update")
        sub_site("harness/src/lib.rs", r'pub const BSV_RS_VERSION: &str = "([^"]+)"', pin, moves)
        sub_site("harness/src/lib.rs", r'pub const BSV_RS_KEY: &str = "bsv-rs@([^"]+)"', pin, moves)
        for k, v in [("bsv-rs.crate", pin), ("bsv-rs.checksum", m.group(2)), ("bsv-rs.tag", "v" + pin), ("bsv-rs.commit", commit)]:
            set_pin(k, v, moves)
        moves.append(("harness/Cargo.lock bsv-rs", pins["bsv-rs.crate"] + " " + pins["bsv-rs.checksum"], pin + " " + m.group(2)))
    elif impl == "go-sdk":
        commit = args.commit or tag_commit(pins["go-sdk.clone"], pin)
        if not commit:
            stop(rec, 2, f"go-sdk {pin}: no commit (the clone {pins['go-sdk.clone']} lacks the tag; pass COMMIT=<sha>)")
        mod = pins["go-sdk.module"]
        gdir = os.path.join(HARNESS, "engines", "go")
        rec.run(["go", "get", f"{mod}@{pin}"], cwd=gdir, check=True)
        rec.run(["go", "mod", "tidy"], cwd=gdir, check=True)
        sums = read("harness/engines/go/go.sum").splitlines()
        s = next((l.split()[2] for l in sums if l.startswith(f"{mod} {pin} ")), None)
        gs = next((l.split()[2] for l in sums if l.startswith(f"{mod} {pin}/go.mod ")), None)
        if not (s and gs):
            stop(rec, 2, f"harness/engines/go/go.sum lacks {mod} {pin}'s two sums after go get")
        moves.append(("harness/engines/go/go.mod, go.sum", pins["go-sdk.version"], pin))
        sub_site("harness/src/engines.rs", r'pub const GO_SDK_VERSION: &str = "([^"]+)"', pin, moves)
        for k, v in [("go-sdk.version", pin), ("go-sdk.commit", commit), ("go-sdk.sum", s), ("go-sdk.gomod_sum", gs)]:
            set_pin(k, v, moves)
    elif impl == "ts-sdk":
        tdir = os.path.join(HARNESS, "engines", "ts")
        rec.run(["npm", "install", "--save-exact", "--package-lock-only", "--ignore-scripts", "--no-audit", "--no-fund",
                 f"{pins['ts-sdk.package']}@{pin}"], cwd=tdir, check=True)
        pl = json.loads(read("harness/engines/ts/package-lock.json"))
        node = pl.get("packages", {}).get("node_modules/" + pins["ts-sdk.package"], {})
        if node.get("version") != pin:
            stop(rec, 2, f"harness/engines/ts/package-lock.json does not carry {pins['ts-sdk.package']} {pin}")
        moves.append(("harness/engines/ts/package.json, package-lock.json", pins["ts-sdk.version"], pin))
        clone = home(pins["ts-sdk.clone"])
        rc, _ = git(clone, "cat-file", "-e", f"{args.commit}^{{commit}}")
        if rc != 0:
            stop(rec, 2, f"@bsv/sdk {pin}: the ts-stack clone {pins['ts-sdk.clone']} lacks the commit {args.commit} (tools/check_pins.py reads it there)")
        rc, out = git(clone, "show", f"{args.commit}:packages/sdk/package.json")
        sv = json.loads(out).get("version") if rc == 0 else None
        if sv != pin:
            stop(rec, 2, f"@bsv/sdk {pin}: packages/sdk/package.json at {args.commit} says {sv} (tools/check_pins.py compares it with the pin)")
        sub_site("harness/src/engines.rs", r'pub const TS_SDK_VERSION: &str = "([^"]+)"', pin, moves)
        for k, v in [("ts-sdk.version", pin), ("ts-sdk.integrity", node["integrity"]), ("ts-sdk.commit", args.commit)]:
            set_pin(k, v, moves)
    elif impl == "sv-node":
        commit = tag_commit(pins["reference.clone"], pin)
        if not commit:
            stop(rec, 2, f"bitcoin-sv {pin}: the reference clone {pins['reference.clone']} lacks the tag (fetch the public tag there)")
        binary = f"~/bsv/targets/sv-{pin}/bin/bitcoind"
        if not os.path.exists(home(binary)):
            stop(rec, 2, f"bitcoin-sv {pin}: no built node at {binary}; the node is the owner's build (docs/PROVENANCE.md §1, the reference row; "
                         "harness/README.md, Prerequisites, sv-node); this command never builds or starts one")
        line0 = subprocess.run([home(binary), "-version"], capture_output=True, text=True).stdout.splitlines()[0]
        vs = re.match(r"Bitcoin SV version (\S+)", line0).group(1)
        old = pins["reference.tag"]
        for path, pat in [("harness/src/bin/run_svnode.rs", r'pub const SV_NODE_KEY: &str = "sv-node@([^"]+)"'),
                          ("harness/src/bin/run_svnode.rs", r'pub const SV_NODE_MEMPOOL_KEY: &str = "sv-node-mempool@([^"]+)"'),
                          ("harness/src/txroad.rs", r'pub const SV_NODE_KEY: &str = "sv-node@([^"]+)"'),
                          ("harness/src/txroad.rs", r'pub const SV_NODE_MEMPOOL_KEY: &str = "sv-node-mempool@([^"]+)"')]:
            sub_site(path, pat, pin, moves)
        # the adapters' subversion gates, their manifest rows and the scenario binaries read this one constant
        sub_site("harness/src/lib.rs", r'pub const SV_NODE_TAG: &str = "([^"]+)"', pin, moves)
        sub_site("harness/src/bin/run_svnode.rs", r'pub const SV_NODE_VERSION_STRING: &str = "([^"]+)"', vs, moves)
        sub_site("harness/src/scenarios/core.rs", r'const VERSION: &str = "([^"]+)"', vs, moves)
        sub_site("harness/src/scenarios/core.rs", r'const PIN: &str = "([^"]+)"', commit, moves)
        sub_site("harness/oracle/spec-node.sh", r'SV_BIN:=\$HOME/bsv/targets/sv-([^/]+)/bin/bitcoind', pin, moves)
        # the vendored reference vectors (check_pins compares them with `git show <tag>:src/test/data/<f>`)
        for f, d in [("script_tests.json", "reference"), ("tx_valid.json", "reference"), ("tx_invalid.json", "reference"), ("sighash.json", "sighash")]:
            r = subprocess.run(["git", "-C", home(pins["reference.clone"]), "show", f"{pin}:src/test/data/{f}"], capture_output=True)
            if r.returncode != 0:
                stop(rec, 2, f"git show {pin}:src/test/data/{f} failed in the reference clone")
            new = f"corpus/{d}/bitcoin-sv-{pin}-{f}"
            with open(os.path.join(ROOT, new), "wb") as fh:
                fh.write(r.stdout)
            moves.append((new, f"corpus/{d}/bitcoin-sv-{old}-{f}", "written from the tag"))
            if old != pin and os.path.exists(os.path.join(ROOT, f"corpus/{d}/bitcoin-sv-{old}-{f}")):
                os.remove(os.path.join(ROOT, f"corpus/{d}/bitcoin-sv-{old}-{f}"))
                moves.append((f"corpus/{d}/bitcoin-sv-{old}-{f}", "present", "removed"))
        for f in ["tools/check.sh", "Makefile"]:
            t = read(f)
            if f"bitcoin-sv-{old}-" in t:
                write(f, t.replace(f"bitcoin-sv-{old}-", f"bitcoin-sv-{pin}-"))
                moves.append((f + ": the vendored vector names", old, pin))
        for k, v in [("reference.tag", pin), ("reference.commit", commit), ("reference.version_string", vs), ("reference.binary", binary)]:
            set_pin(k, v, moves)
    elif impl == "teranode":
        commit = tag_commit(pins["teranode.clone"], pin)
        if not commit:
            stop(rec, 2, f"Teranode {pin}: the clone {pins['teranode.clone']} is absent or lacks the tag (docs/PROVENANCE.md §1, the Teranode row: "
                         "every citation is read with `git show <tag>:<path>`)")
        rc, gomod = git(home(pins["teranode.clone"]), "show", f"{pin}:go.mod")
        rc2, gosum = git(home(pins["teranode.clone"]), "show", f"{pin}:go.sum")
        req = lambda mod: re.search(r"^\s*" + re.escape(mod) + r"\s+(\S+)", gomod, re.M).group(1)
        summ = lambda mod, v, suffix: next(l.split()[2] for l in gosum.splitlines() if l.startswith(f"{mod} {v}{suffix} "))
        gv, cv = req(pins["gobdk.module"]), req(pins["go-chaincfg.module"])
        bdk_commit = None
        if os.path.exists(os.path.join(home(pins["gobdk.clone"]), ".git")):
            rc3, bdk_commit = git(home(pins["gobdk.clone"]), "rev-parse", gv.rsplit("-", 1)[-1] + "^{commit}")
        cfg_commit = tag_commit(pins["go-chaincfg.clone"], cv)
        if not bdk_commit or not cfg_commit:
            stop(rec, 2, f"Teranode {pin} requires gobdk {gv} and go-chaincfg {cv}; the GoBDK clone {pins['gobdk.clone']} and the go-chaincfg clone "
                         f"{pins['go-chaincfg.clone']} must hold them (absent or missing here)")
        for path in ["harness/engines/gobdk/go.mod"]:
            sub_site(path, r"^require\s+" + re.escape(pins["gobdk.module"]) + r"\s+(\S+)", gv, moves)
        t = read("harness/engines/gobdk/go.sum")
        t = "\n".join(l for l in t.splitlines() if not l.startswith(pins["gobdk.module"] + " ")) + "\n"
        t += f"{pins['gobdk.module']} {gv} {summ(pins['gobdk.module'], gv, '')}\n{pins['gobdk.module']} {gv}/go.mod {summ(pins['gobdk.module'], gv, '/go.mod')}\n"
        write("harness/engines/gobdk/go.sum", t)
        sub_site("harness/src/bin/run_teranode.rs", r'const PIN: &str = "([^"]+)"', commit, moves)
        sub_site("harness/src/bin/run_teranode.rs", r'const TAG: &str = "([^"]+)"', pin, moves)
        sub_site("harness/src/engines.rs", r'pub const GOBDK_VERSION: &str = "([^"]+)"', bdk_commit[:8], moves)
        for k, v in [("teranode.tag", pin), ("teranode.commit", commit), ("gobdk.commit", bdk_commit), ("gobdk.pseudo_version", gv),
                     ("gobdk.sum", summ(pins["gobdk.module"], gv, "")), ("gobdk.gomod_sum", summ(pins["gobdk.module"], gv, "/go.mod")),
                     ("go-chaincfg.version", cv), ("go-chaincfg.commit", cfg_commit),
                     ("go-chaincfg.sum", summ(pins["go-chaincfg.module"], cv, "")), ("go-chaincfg.gomod_sum", summ(pins["go-chaincfg.module"], cv, "/go.mod"))]:
            set_pin(k, v, moves)
        rec.note("column: gobdk.reference_tag and gobdk.reference_commit are read from the linked archives' version block (`strings`), "
                 "never from a tag; they stay until that read (docs/PROVENANCE.md §1, the BDK row)")
    return moves


VECTORS = [("corpus/numbers/bsv-rs-{v}.jsonl", "num_vectors", "1000"), ("corpus/sighash/bsv-rs-{v}.jsonl", "sighash_vectors", "500"),
           ("corpus/arith/bsv-rs-{v}.jsonl", "arith_vectors", "10000"), ("corpus/crypto/ecdsa-bsv-rs-{v}.jsonl", "ecdsa_vectors", "200")]


def move_vectors(old, new, binr, rec, env):
    """bsv-rs's four vector files are named by the pin (check-pins reads the names): regenerate each with the new
    crate, compare with the old file, then rename the tripwire's references and remove the old file."""
    moves = []
    rec.run(["cargo", "build", "--release", "--locked", "--quiet"] + sum((["--bin", b] for _, b, _ in VECTORS), []), cwd=HARNESS, env=env, check=True)
    for pattern, binname, count in VECTORS:
        a, b = pattern.format(v=old), pattern.format(v=new)
        rc, _ = rec.run([os.path.join(binr, binname), "--count", count], cwd=HARNESS, env=env, stdout_path=os.path.join(ROOT, b))
        if rc != 0:
            stop(rec, 2, f"{binname} exited {rc}")
        same = open(os.path.join(ROOT, a), "rb").read() == open(os.path.join(ROOT, b), "rb").read()
        moves.append((b, a, "byte-identical" if same else "CHANGED (the vector's own leg judges it)"))
        os.remove(os.path.join(ROOT, a))
    for f in ["tools/check.sh", "Makefile"]:
        t = read(f)
        if f"bsv-rs-{old}" in t:
            write(f, t.replace(f"bsv-rs-{old}", f"bsv-rs-{new}"))
            moves.append((f + ": the vector names", old, new))
    return moves


def plan_sites(impl, pins):
    """The PLAN listing: every site a move would touch, with the value found there now (the readers are the move's)."""
    rows = []

    def site(path, pattern):
        found = re.findall(pattern, read(path), re.M)
        rows.append((path, pattern, found[0] if len(found) == 1 else f"<{len(found)} matches>"))
    keys = {"bsv-rs": ["bsv-rs.crate", "bsv-rs.checksum", "bsv-rs.tag", "bsv-rs.commit"],
            "go-sdk": ["go-sdk.version", "go-sdk.commit", "go-sdk.sum", "go-sdk.gomod_sum"],
            "ts-sdk": ["ts-sdk.version", "ts-sdk.integrity", "ts-sdk.commit"],
            "gobdk": ["gobdk.pseudo_version", "gobdk.commit"],
            "sv-node": ["reference.tag", "reference.commit", "reference.version_string", "reference.binary"],
            "teranode": ["teranode.tag", "teranode.commit", "gobdk.commit", "gobdk.pseudo_version", "gobdk.sum", "gobdk.gomod_sum",
                         "go-chaincfg.version", "go-chaincfg.commit", "go-chaincfg.sum", "go-chaincfg.gomod_sum"]}[impl]
    for k in keys:
        rows.append(("docs/PROVENANCE.md §1a", k, pins[k]))

    def rewritten(path):
        rows.append((path, "rewritten", "<present>" if os.path.exists(os.path.join(ROOT, path)) else "<absent>"))

    def names(old):
        for f in ["tools/check.sh", "Makefile"]:
            rows.append((f, f"the vector names {old}", f"<{read(f).count(old)} occurrences>"))
    if impl == "bsv-rs":
        site("harness/Cargo.toml", r'^bsv-rs\s*=\s*(?:\{\s*version\s*=\s*)?"=([^"]+)"')
        site("harness/Cargo.lock", r'name = "bsv-rs"\nversion = "([^"]+)"')
        site("harness/src/lib.rs", r'pub const BSV_RS_VERSION: &str = "([^"]+)"')
        site("harness/src/lib.rs", r'pub const BSV_RS_KEY: &str = "bsv-rs@([^"]+)"')
        for pattern, _, _ in VECTORS:
            rewritten(pattern.format(v=pins["bsv-rs.crate"]))
        names("bsv-rs-" + pins["bsv-rs.crate"])
    elif impl == "go-sdk":
        site("harness/engines/go/go.mod", r"^require\s+" + re.escape(pins["go-sdk.module"]) + r"\s+(\S+)")
        rewritten("harness/engines/go/go.sum")
        site("harness/src/engines.rs", r'pub const GO_SDK_VERSION: &str = "([^"]+)"')
    elif impl == "ts-sdk":
        site("harness/engines/ts/package.json", r'"@bsv/sdk": "([^"]+)"')
        rewritten("harness/engines/ts/package-lock.json")
        site("harness/src/engines.rs", r'pub const TS_SDK_VERSION: &str = "([^"]+)"')
    elif impl == "sv-node":
        site("harness/src/bin/run_svnode.rs", r'pub const SV_NODE_KEY: &str = "sv-node@([^"]+)"')
        site("harness/src/bin/run_svnode.rs", r'pub const SV_NODE_MEMPOOL_KEY: &str = "sv-node-mempool@([^"]+)"')
        site("harness/src/bin/run_svnode.rs", r'pub const SV_NODE_VERSION_STRING: &str = "([^"]+)"')
        site("harness/src/txroad.rs", r'pub const SV_NODE_KEY: &str = "sv-node@([^"]+)"')
        site("harness/src/txroad.rs", r'pub const SV_NODE_MEMPOOL_KEY: &str = "sv-node-mempool@([^"]+)"')
        site("harness/src/lib.rs", r'pub const SV_NODE_TAG: &str = "([^"]+)"')
        site("harness/src/scenarios/core.rs", r'const VERSION: &str = "([^"]+)"')
        site("harness/src/scenarios/core.rs", r'const PIN: &str = "([^"]+)"')
        site("harness/oracle/spec-node.sh", r'SV_BIN:=\$HOME/bsv/targets/sv-([^/]+)/bin/bitcoind')
        for f, d in [("script_tests.json", "reference"), ("tx_valid.json", "reference"), ("tx_invalid.json", "reference"), ("sighash.json", "sighash")]:
            rewritten(f"corpus/{d}/bitcoin-sv-{pins['reference.tag']}-{f}")
        names(f"bitcoin-sv-{pins['reference.tag']}-")
    elif impl in ("teranode", "gobdk"):
        site("harness/engines/gobdk/go.mod", r"^require\s+" + re.escape(pins["gobdk.module"]) + r"\s+(\S+)")
        rewritten("harness/engines/gobdk/go.sum")
        site("harness/src/engines.rs", r'pub const GOBDK_VERSION: &str = "([^"]+)"')
        if impl == "teranode":
            site("harness/src/bin/run_teranode.rs", r'const PIN: &str = "([^"]+)"')
            site("harness/src/bin/run_teranode.rs", r'const TAG: &str = "([^"]+)"')
    return rows


# ---------------------------------------------------------------- the corpora
def corpus_path(rel):
    """A witness manifest's `corpus` field is relative to harness/; a corpus committed gzipped is `<file>.gz` beside it."""
    p = os.path.normpath(os.path.join(HARNESS, rel))
    if os.path.exists(p):
        return p, False
    if os.path.exists(p + ".gz"):
        return p, True
    raise SystemExit(f"column: the corpus {rel} is neither plain nor gzipped here")


def corpus_manifest(path):
    d = os.path.dirname(path)
    name = os.path.basename(path)
    for m in ["manifest.json", "cases-manifest.json"]:
        mp = os.path.join(d, m)
        if os.path.exists(mp) and f'"{name}"' in open(mp, encoding="utf-8").read():
            return mp
    raise SystemExit(f"column: no manifest beside {path} names it")


def spec_config(manifest_path):
    m = json.load(open(manifest_path))
    row = next((i for i in m.get("implementations", []) if i.get("name") == "spec"), None)
    return (row or {}).get("config", {}).get("config", "sv-mainnet-default")


def plain_bytes(path, gz):
    with open(path + (".gz" if gz else ""), "rb") as f:
        raw = f.read()
    return gzip.decompress(raw) if gz else raw


def store_gz(path):
    """The gzip storage form of the committed corpora: level 9, empty file name, mtime 0 (reproduces every .gz byte for byte)."""
    plain = open(path, "rb").read()
    buf = io.BytesIO()
    with gzip.GzipFile(filename="", mode="wb", compresslevel=9, fileobj=buf, mtime=0) as g:
        g.write(plain)
    with open(path + ".gz", "wb") as f:
        f.write(buf.getvalue())
    os.remove(path)


def entry_keys(raw, names):
    """Per entry id: {name: (version, verdict object)} for the implementation's own keys."""
    out = {}
    for line in raw.splitlines():
        if not line.strip():
            continue
        e = json.loads(line)
        got = {}
        for k, v in e.get("expect", {}).items():
            n, _, ver = k.partition("@")
            if n in names:
                got[n] = (ver, v)
        out[e["id"]] = got
    return out


def other_keys(raw, names):
    """Per entry id: every field but the implementation's own verdict keys, canonical (the object audit of a move)."""
    out = {}
    for line in raw.splitlines():
        if line.strip():
            e = json.loads(line)
            e["expect"] = {k: v for k, v in e.get("expect", {}).items() if k.partition("@")[0] not in names}
            out[e["id"]] = json.dumps(e, sort_keys=True)
    return out


def committed_bytes(path, gz):
    rel = os.path.relpath(path, ROOT) + (".gz" if gz else "")
    r = subprocess.run(["git", "-C", ROOT, "show", f"HEAD:{rel}"], capture_output=True)
    if r.returncode != 0:
        raise SystemExit(f"column: git show HEAD:{rel} failed")
    return gzip.decompress(r.stdout) if gz else r.stdout


def public_counts(c):
    """The counts as the record states them: classified runs per column, the class rows' number and the SHA-256 of their
    sorted (column, class, entries) list; the comparison itself is by class ID and count (`equal`)."""
    classified, unexplained = {}, {}
    for col, rule, n in c["rules"]:
        bucket = unexplained if rule == "unexplained" else classified
        bucket[col] = bucket.get(col, 0) + n
    digest = hashlib.sha256(json.dumps(c["rules"], sort_keys=True).encode()).hexdigest()
    return {"entries": c["entries"], "agree": c["agree"], "classified_runs": classified, "unexplained_runs": unexplained,
            "class_rows": len(c["rules"]), "class_rows_sha256": digest, "undecided": c["undecided"],
            "aborts_as_witnesses": c["aborts_as_witnesses"], "witnesses": c["witnesses"]}


def counts_of(impl, w):
    """One corpus's counts from a witness manifest row, in one shape for every driver."""
    if impl == "bsv-rs":
        agree = {"spec": w.get("agree_block"), "spec-mempool": w.get("agree_mempool")}
        undecided = w.get("undecided")
    else:
        agree = dict(w.get("agree", {}))
        undecided = w.get("undecided_runs")
    rules = sorted((r["column"], r["rule"], r["entries"]) for r in w.get("rules", []))
    return {"entries": w.get("entries"), "agree": agree, "rules": rules, "undecided": undecided,
            "aborts_as_witnesses": w.get("aborts_as_witnesses"), "witnesses": w.get("witnesses")}


# ---------------------------------------------------------------- the run
def main():
    ap = argparse.ArgumentParser(description="one implementation's column on one release (#124)")
    ap.add_argument("--impl", required=True, choices=sorted(IMPLS))
    ap.add_argument("--pin", required=True)
    ap.add_argument("--commit", default="")
    ap.add_argument("--plan", action="store_true", help="list the sites a move would touch, with their values now; write nothing")
    ap.add_argument("--corpus", action="append", default=[], help="restrict to these corpora (by name); the record says so")
    a = ap.parse_args()
    rec = Receipt()
    impl, spec = a.impl, IMPLS[a.impl]
    pins = pins_block()
    current = pins[spec["pin"]]
    dry = a.pin == current
    stamp = datetime.datetime.now(datetime.timezone.utc).strftime("%Y%m%d-%H%M%S")
    t_start = time.time()
    started = utc()
    load_start = load1()
    head = subprocess.run(["git", "-C", ROOT, "rev-parse", "HEAD"], capture_output=True, text=True).stdout.strip()
    branch = subprocess.run(["git", "-C", ROOT, "rev-parse", "--abbrev-ref", "HEAD"], capture_output=True, text=True).stdout.strip()
    host = socket.gethostname().split(".")[0]
    dirty = len([l for l in subprocess.run(["git", "-C", ROOT, "status", "--porcelain"], capture_output=True, text=True).stdout.splitlines() if l.strip()])
    mode = "dry run on the current pin" if dry else f"pin move {current} -> {a.pin}"
    rec.note(f"column: {impl} at {a.pin} ({mode}); tree {head[:12]} on {branch}; host {host}; start {started}; load1 {load_start:.2f}")

    if a.plan:
        rec.note(f"column: PLAN for {impl} (nothing is written): the sites a move to {a.pin} touches, with their values now")
        for path, what, val in plan_sites(impl, pins):
            rec.note(f"  {path}  {what}  = {val}")
        return 0

    # the refusals that need no build: the instances are named, never started (sv-node and teranode are the owner's)
    if impl == "gobdk" and not dry:
        stop(rec, 2, "GoBDK's pin is the module Teranode's go.mod requires at its tag (docs/PROVENANCE.md §1, the BDK row): it moves "
                     "with Teranode, `make column IMPL=teranode PIN=<tag>`, never alone")
    if impl == "ts-sdk" and not dry and not a.commit:
        stop(rec, 2, f"@bsv/sdk {a.pin}: pass COMMIT=<sha>, the ts-stack commit of the publish (ts-stack carries no release tag; "
                     "docs/PROVENANCE.md §1, the ts-sdk row)")
    if impl == "teranode" and dry:
        stop(rec, 2, "the Teranode column runs on the owner's instance (docs/PROVENANCE.md §1, the instance's host row: "
                     "harness/engines/instance41/instance.py start --validator, one corpus chunk at a time by "
                     "harness/engines/instance41/seed_chunk.zsh under the box leg lock); this command never starts it")
    if impl == "sv-node" and not (os.environ.get("SV_RPC") and os.environ.get("SV_COOKIE")):
        stop(rec, 2, "the sv-node column needs the owner's two regtest instances of bitcoin-sv " + (pins["reference.tag"] if dry else a.pin)
                     + " (harness/oracle/README.md: the consensus instance and the policy instance, started by "
                     "harness/oracle/spec-node.sh local start and policy start): pass SV_RPC, SV_COOKIE, SV_RPC_MEMPOOL and "
                     "SV_COOKIE_MEMPOOL; this command never starts one")
    if a.corpus and not dry:
        stop(rec, 2, "a pin move re-records every corpus of the column; CORPUS= is for a dry run")
    if not dry and branch in ("main", "HEAD"):
        stop(rec, 2, "a pin move is a landing of its own: run it on a lane branch, never on main")
    if not dry and subprocess.run(["git", "-C", ROOT, "status", "--porcelain"], capture_output=True, text=True).stdout.strip():
        stop(rec, 2, "a pin move starts from a clean tree (the record names the commit it measured)")

    global MOVING
    moves = []
    rows, moved, reds, skipped = [], [], [], []
    adapter = ""
    scratch = os.path.join(HARNESS, "target", "column", f"{stamp}-{impl}")

    def finish(word=None, line=None):
        """The verdict and the record (.md, .json, .txt); `word` and `line` override them for a stop that still records."""
        cols = sorted({c for r in rows for c in r["run"]["agree"]})
        tot = lambda key, c: sum((r[key]["agree"].get(c) or 0) for r in rows)
        entries = sum(r["run"]["entries"] or 0 for r in rows)
        unexplained = sum(sum(r["run"]["unexplained_runs"].values()) for r in rows)
        differ = [r["corpus"] for r in rows if not r["equal"]]
        agree_txt = "; ".join(f"{c} {tot('run', c):,} (recorded {tot('recorded', c):,})" for c in cols)
        if word:
            ok = False
        elif dry:
            ok = not differ and not moved and not reds and not unexplained
            word = "REPRODUCED" if ok else "DIFFERS"
        else:
            ok = not reds and not unexplained
            word = "MEASURED" if ok else "RED (a classifier stop: the move is measured, not landable)"
        wall = int(time.time() - t_start)
        line = line or (f"column: {impl} {a.pin} ({mode}): {len(rows)} corpora, {entries:,} entries; agree {agree_txt}; "
                        f"corpora differing {len(differ)}; moved rows {len(moved)}; RED {len(reds)}; unexplained {unexplained}"
                        f"{'; skipped by name ' + str(len(skipped)) if skipped else ''}; wall {wall} s: {word}")
        out_md = os.path.join(ROOT, "docs", "records", f"{stamp}-column-{impl}-{a.pin}-s3")
        data = {"command": f"make column IMPL={impl} PIN={a.pin}" + (f" COMMIT={a.commit}" if a.commit else "")
                           + (" CORPUS=" + ",".join(a.corpus) if a.corpus else ""),
                "mode": mode, "tree": head, "uncommitted_paths_at_start": dirty, "branch": branch, "host": host, "started": started, "ended": utc(), "wall_s": wall,
                "load1_start": load_start, "load1_end": load1(), "pin": pin_facts(impl, pins), "adapter": adapter,
                "sites_moved": [{"site": s, "before": b, "after": n} for s, b, n in moves], "corpora": rows,
                "skipped": [{"corpus": n, "why": w} for n, w in skipped], "red": [{"corpus": n, "line": l} for n, l in reds],
                "moved_rows": moved, "differing": differ, "verdict": line, "scratch": os.path.relpath(scratch, ROOT)}
        with open(out_md + ".json", "w", encoding="utf-8") as f:
            json.dump(data, f, indent=1, sort_keys=True)
            f.write("\n")
        with open(out_md + ".txt", "w", encoding="utf-8") as f:
            f.write(f"tools/column.py receipt ({data['command']}); every command with its cwd, UTC start, 1-minute load and exit\n")
            f.write("\n".join(rec.lines) + "\n")
        write_md(out_md + ".md", data, impl, a.pin, dry, cols, tot)
        rec.note(f"record: {os.path.relpath(out_md, ROOT)}.md (.json, .txt)")
        print(line, flush=True)
        return 0 if ok else 1

    if not dry:
        MOVING = True
        moves = move_sites(impl, a.pin, a, rec, pins)
        pins = pins_block()
        if impl == "teranode":
            for site, before, after in moves:
                rec.note(f"  moved {site}: {before} -> {after}")
            finish("SITES MOVED; the column runs on the owner's instance",
                   f"column: teranode {a.pin} ({mode}): sites moved {len(moves)}; column not run (the owner's instance, "
                   "harness/engines/instance41/README.md): SETUP STOP")
            MOVING = False  # every site moved: the stop below is the design, not a half-move
            stop(rec, 2, "the sites moved; the Teranode column runs on the owner's instance, rebuilt at the new tag by its recipe "
                         "(harness/engines/instance41/README.md); this command never builds or starts it")

    # the GoBDK shim builds from its clone: checked before any build
    if impl == "gobdk":
        clone = os.environ.get("GOBDK_CLONE") or home(pins["gobdk.clone"])
        if not os.path.exists(os.path.join(clone, ".git")):
            stop(rec, 2, f"gobdk SKIPPED BY NAME: the GoBDK shim builds from the clone {pins['gobdk.clone']} at {pins['gobdk.commit']} "
                         "(harness/README.md, Prerequisites, gobdk), absent on this machine")

    # the build, as harness/README.md prescribes
    env = os.environ.copy()
    env["CARGO_BUILD_JOBS"] = env.get("CARGO_BUILD_JOBS", "4")
    rec.run(["cargo", "build", "--release", "--locked", "--quiet", "--bin", "spec_recorded", "--bin", spec["driver"]]
            + (["--bin", "run_bsvrs"] if impl == "bsv-rs" else []), cwd=HARNESS, env=env, check=True)
    target = env.get("CARGO_TARGET_DIR") or os.path.join(HARNESS, "target")
    binr = os.path.join(target, "release")
    if impl == "bsv-rs" and not dry:
        moves += move_vectors(current, a.pin, binr, rec, env)
    if impl == "go-sdk":
        rec.run(["make", "-C", ROOT, "gosdk-build"], check=True)
        adapter = "$ROOT/harness/target/engines/gosdk-runner, built by make gosdk-build at the pin"
    elif impl == "ts-sdk":
        rc, nb = rec.run([os.path.join(ROOT, "tools", "node_bin.sh")])
        nb = nb.strip().splitlines()[-1] if nb.strip() else ""
        rc2, nv = rec.run([nb, "--version"]) if nb else (1, "")
        if not nb or not nv.strip().startswith("v" + pins["node.major"] + "."):
            stop(rec, 2, f"the ts-sdk adapter runs on Node {pins['node.major']} (tools/node_bin.sh found {nb or 'none'} {nv.strip()})")
        env["NODE_BIN"] = nb
        if not dry or not os.path.isdir(os.path.join(HARNESS, "engines", "ts", "node_modules", "@bsv", "sdk")):
            rec.run(["make", "-C", ROOT, "tssdk-install"], check=True)
        adapter = f"@bsv/sdk installed in harness/engines/ts/node_modules on {nb} {nv.strip()}"
    elif impl == "gobdk":
        rec.run(["make", "-C", ROOT, "gobdk-build"], check=True)
        adapter = "$ROOT/harness/target/engines/gobdk-runner, built by make gobdk-build at the pin"

    # the corpora the column records
    wpath = os.path.join(ROOT, spec["witness"])
    recorded = json.load(open(wpath))
    names = sorted(recorded)
    if a.corpus:
        unknown = [c for c in a.corpus if c not in recorded]
        if unknown:
            stop(rec, 2, f"the {impl} column records no corpus named {', '.join(unknown)}")
        names = [n for n in names if n in a.corpus]
    os.makedirs(os.path.join(scratch, "spec"), exist_ok=True)
    wdir = os.path.join(scratch, "witnesses") if dry else os.path.join(ROOT, "corpus", "witnesses")
    os.makedirs(wdir, exist_ok=True)
    for name in names:
        src, gz = corpus_path(recorded[name]["corpus"])
        mpath = corpus_manifest(src)
        config = spec_config(mpath)
        if impl == "sv-node" and config != "sv-mainnet-default":
            skipped.append((name, f"its spec column is {config}: the instances of the test's own chain (tools/cpp_era_run.sh), not the standing pair"))
            rec.note(f"column: {name}: SKIPPED BY NAME ({skipped[-1][1]})")
            continue
        if dry:
            d = os.path.join(scratch, "corpora", name)
            os.makedirs(d, exist_ok=True)
            run_file = os.path.join(d, os.path.basename(src))
            with open(run_file, "wb") as f:
                f.write(plain_bytes(src, gz))
            shutil.copy(mpath, os.path.join(d, os.path.basename(mpath)))
            run_manifest = os.path.join(d, os.path.basename(mpath))
        else:
            run_file, run_manifest = src, mpath
            if gz:
                with open(src, "wb") as f:
                    f.write(plain_bytes(src, True))
        rel = os.path.relpath(run_file, HARNESS)
        spec_file = os.path.join(scratch, "spec", name + ".jsonl")
        rc, out = rec.run([os.path.join(binr, "spec_recorded"), "--corpus", rel, "--out", spec_file, "--config", config], cwd=HARNESS, env=env)
        if rc != 0:
            reds.append((name, "spec_recorded refused: " + (out.strip().splitlines() or [""])[-1]))
            if gz and not dry:
                store_gz(src)
            continue
        if impl == "bsv-rs":
            rc, out = rec.run([os.path.join(binr, "run_bsvrs"), "--corpus", os.path.dirname(rel), "--manifest",
                               os.path.basename(run_manifest), "--record"], cwd=HARNESS, env=env)
            if rc != 0:
                reds.append((name, "run_bsvrs --record exited " + str(rc)))
                if gz and not dry:
                    store_gz(src)
                continue
            cmd = [os.path.join(binr, "run_diff"), "--corpus", rel, "--spec", spec_file, "--witnesses", os.path.relpath(wdir, HARNESS), "--record"]
        elif impl == "sv-node":
            cmd = [os.path.join(binr, "run_svnode"), "--corpus", rel, "--spec", spec_file, "--witnesses", os.path.relpath(wdir, HARNESS),
                   "--words-from", wpath, "--rpc", env["SV_RPC"], "--cookie", env["SV_COOKIE"], "--record"]
            if env.get("SV_RPC_MEMPOOL"):
                cmd += ["--rpc-mempool", env["SV_RPC_MEMPOOL"], "--cookie-mempool", env.get("SV_COOKIE_MEMPOOL", "")]
        else:
            cmd = [os.path.join(binr, "run_engine"), "--engine", spec["engine"], "--corpus", rel, "--spec", spec_file,
                   "--witnesses", os.path.relpath(wdir, HARNESS), "--words-from", wpath, "--record"]
        rc, out = rec.run(cmd, cwd=HARNESS, env=env)
        verdict = next((l for l in reversed(out.splitlines()) if re.match(r"^(run_diff|run_engine|run_svnode): (GREEN|RED)", l)), "")
        if rc != 0 or "GREEN" not in verdict:
            reds.append((name, verdict or f"exit {rc}, no verdict line"))
        # the run's counts against the committed column
        man = os.path.join(wdir, "manifest.json") if impl == "bsv-rs" else os.path.join(wdir, IMPLS[impl]["witness"].split("/")[-2], "manifest.json")
        live = json.load(open(man)).get(name, {})
        now, was = counts_of(impl, live), counts_of(impl, recorded[name])
        # the moved rows: the implementation's own verdict per entry, the run's against the committed corpus
        new = entry_keys(open(run_file, "rb").read(), spec["names"])
        old = entry_keys(committed_bytes(src, gz), spec["names"])
        mv = []
        for eid, got in new.items():
            for n in spec["names"]:
                o, nw = old.get(eid, {}).get(n), got.get(n)
                if (o[1] if o else None) != (nw[1] if nw else None):
                    keep = lambda v: {k: v.get(k) for k in ("verdict", "code", "input")} if v else None
                    mv.append({"corpus": name, "id": eid, "key": n, "was": keep(o[1] if o else None), "now": keep(nw[1] if nw else None)})
        moved += mv
        # the object audit: every other field of every entry, the spec's keys and the other implementations' included,
        # equals the committed corpus's (a driver that rewrote anything else is RED, never landed)
        base = other_keys(committed_bytes(src, gz), spec["names"])
        changed = [i for i, v in other_keys(open(run_file, "rb").read(), spec["names"]).items() if v != base.get(i)]
        if changed:
            reds.append((name, f"{len(changed)} entries changed outside the column's own keys (from {changed[0]})"))
        if not dry:
            if gz:
                store_gz(src)
            restore_other_rows(mpath, spec["names"] + (["spec", "spec-mempool"] if impl == "bsv-rs" else []))
        rows.append({"corpus": name, "file": os.path.relpath(src, ROOT) + (".gz" if gz else ""), "config": config,
                     "run": public_counts(now), "recorded": public_counts(was), "equal": now == was, "moved": len(mv), "verdict": verdict})

    # ---------------------------------------------------------------- the verdict and the record
    return finish()


# the corpora whose manifest `verdicts` the corpus generator writes, not the runner (tools/xsig_witness.py:641)
GENERATOR_VERDICTS = {"xsig-144"}


def restore_other_rows(mpath, own):
    """A move keeps every other implementation's row of the corpus manifest as committed (the drivers' --record
    re-serializes the manifest; the bump record's section 3 restored the other rows from the base the same way)."""
    rel = os.path.relpath(mpath, ROOT)
    base = json.loads(subprocess.run(["git", "-C", ROOT, "show", f"HEAD:{rel}"], capture_output=True, text=True).stdout)
    now = json.load(open(mpath))
    rows = []
    for row in base.get("implementations", []):
        if row.get("name") in own:
            rows.append(next((r for r in now.get("implementations", []) if r.get("name") == row.get("name")), row))
        else:
            rows.append(row)
    for r in now.get("implementations", []):
        if r.get("name") in own and r.get("name") not in [x.get("name") for x in rows]:
            rows.append(r)
    base["implementations"] = rows
    # `verdicts` (and the provenance clause naming its version) is the runner's tally (run_bsvrs.rs:230) except
    # where the corpus generator owns it (xsig-144's is the reference's, tools/xsig_witness.py restamp_manifest):
    # there a move keeps it as committed (#148's lenses, 2026-10-17)
    corpus = os.path.basename(os.path.dirname(rel))
    for k in ("sha256", "count") + (() if corpus in GENERATOR_VERDICTS else ("verdicts", "provenance")):
        if k in now:
            base[k] = now[k]
    with open(mpath, "w", encoding="utf-8") as f:
        f.write(json.dumps(base, indent=2, ensure_ascii=False) + "\n")


def pin_facts(impl, pins):
    keys = {"bsv-rs": ["bsv-rs.crate", "bsv-rs.tag", "bsv-rs.commit", "bsv-rs.checksum"],
            "go-sdk": ["go-sdk.version", "go-sdk.commit", "go-sdk.sum", "go-sdk.gomod_sum"],
            "ts-sdk": ["ts-sdk.version", "ts-sdk.commit", "ts-sdk.integrity"],
            "gobdk": ["gobdk.pseudo_version", "gobdk.commit", "gobdk.sum"],
            "sv-node": ["reference.tag", "reference.commit", "reference.version_string"],
            "teranode": ["teranode.tag", "teranode.commit"]}[impl]
    return {k: pins[k] for k in keys}


def write_md(path, d, impl, pin, dry, cols, tot):
    L = []
    L.append(f"# The {impl} column at {pin} ({'dry run' if dry else 'pin move'}; S3, `make column`, #124)")
    L.append("")
    L.append(f"[M] {d['started'][:10]}. Written by `tools/column.py` from `{d['command']}`; {d['mode']}. "
             f"Tree `{d['tree'][:12]}` ({d['uncommitted_paths_at_start']} uncommitted paths at the start) on `{d['branch']}`, host `{d['host']}`, started {d['started']}, ended {d['ended']}, "
             f"wall {d['wall_s']} s, 1-minute load {d['load1_start']:.2f} at the start and {d['load1_end']:.2f} at the end. "
             f"The [receipt]({os.path.basename(path)[:-3]}.txt) carries every command with its working directory, UTC start, "
             f"start load and exit; the [JSON]({os.path.basename(path)[:-3]}.json) every count, every moved row and the pin.")
    L.append("")
    L.append("## 1. The pin")
    L.append("")
    for k, v in d["pin"].items():
        L.append(f"- `{k}` = `{v}`")
    if d["adapter"]:
        L.append(f"- the adapter: {d['adapter']}")
    L.append("")
    L.append("## 2. The sites moved")
    L.append("")
    if not d["sites_moved"]:
        L.append("None: a dry run moves no site and writes nothing under `corpus/`; the drivers recorded into scratch copies under "
                 f"`{d['scratch']}` (outside the record, ignored by git).")
    else:
        L.append("| site | before | after |")
        L.append("|---|---|---|")
        for s in d["sites_moved"]:
            L.append(f"| {s['site']} | `{s['before']}` | `{s['after']}` |")
        L.append("")
        L.append("The prose rows of `docs/PROVENANCE.md` §1, the state page, `corpus/INDEX.md` and the recon entry are the landing's "
                 "own words (the funnel rule); this command writes none of them.")
    L.append("")
    L.append("## 3. The column [X]")
    L.append("")
    if not d["corpora"]:
        L.append("No corpus was run by this command (the verdict line below names why).")
        L.append("")
    head = ("| corpus | entries | " + " | ".join(f"agree {c} (recorded)" for c in cols)
            + " | classified runs per column (recorded) | class rows | unexplained | moved rows | equal |")
    L.append(head)
    L.append("|---|---:|" + "---:|" * len(cols) + "---|---:|---:|---:|---|")
    for r in d["corpora"]:
        cr, cw = r["run"]["classified_runs"], r["recorded"]["classified_runs"]
        cl = ", ".join(f"{c} {cr.get(c, 0):,} ({cw.get(c, 0):,})" for c in sorted(set(cr) | set(cw))) or "none"
        un = sum(r["run"]["unexplained_runs"].values())
        ag = " | ".join(f"{(r['run']['agree'].get(c) or 0):,} ({(r['recorded']['agree'].get(c) or 0):,})" for c in cols)
        L.append(f"| `{r['corpus']}` | {r['run']['entries'] or 0:,} | {ag} | {cl} | {r['run']['class_rows']} | {un} | {r['moved']} | {'yes' if r['equal'] else 'NO'} |")
    tot_entries = sum(r["run"]["entries"] or 0 for r in d["corpora"])
    L.append("| **total** | **" + f"{tot_entries:,}" + "** | " + " | ".join(f"**{tot('run', c):,} ({tot('recorded', c):,})**" for c in cols) + " | | | **" + str(sum(sum(r["run"]["unexplained_runs"].values()) for r in d["corpora"])) + "** | **" + str(len(d["moved_rows"])) + "** | |")
    L.append("")
    tc = {}
    for r in d["corpora"]:
        for c, n in r["run"]["classified_runs"].items():
            tc[c] = tc.get(c, 0) + n
    L.append("Classified runs in total: " + (", ".join(f"{c} {n:,}" for c, n in sorted(tc.items())) or "none") + ". "
             "Equal means the run's entries, agreements per column, classified rows by class ID and count, undecided runs, "
             "aborts filed as witnesses and witness count are the committed witness manifest's (`" + (IMPLS[impl]["witness"] or "")
             + "`, where the classes are named with their citations); the JSON carries each corpus's class-row digest.")
    for s in d["skipped"]:
        L.append(f"- SKIPPED BY NAME: `{s['corpus']}`: {s['why']}")
    for s in d["red"]:
        L.append(f"- RED: `{s['corpus']}`: {s['line']}")
    L.append("")
    L.append("## 4. The moved rows")
    L.append("")
    if not d["moved_rows"]:
        L.append("None: every entry's own verdict keys (" + ", ".join(f"`{n}`" for n in IMPLS[impl]["names"]) + ") equal the committed corpus's.")
    else:
        L.append("| corpus | id | key | was | now |")
        L.append("|---|---|---|---|---|")
        for m in d["moved_rows"][:500]:
            verdict = lambda v: "absent" if not v else f"{v.get('verdict')}" + (f" {v.get('code')}" if v.get("code") else "")
            L.append(f"| `{m['corpus']}` | `{m['id']}` | `{m['key']}` | {verdict(m['was'])} | {verdict(m['now'])} |")
        if len(d["moved_rows"]) > 500:
            L.append(f"\nThe remaining {len(d['moved_rows']) - 500:,} rows are in the JSON.")
    L.append("")
    L.append("## 5. The verdict line")
    L.append("")
    L.append("```text")
    L.append(d["verdict"])
    L.append("```")
    L.append("")
    with open(path, "w", encoding="utf-8") as f:
        f.write("\n".join(L))


if __name__ == "__main__":
    sys.exit(main())
