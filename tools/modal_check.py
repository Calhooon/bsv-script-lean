# tools/modal_check.py: THE TRIPWIRE ON MODAL (bsv-script-lean, S3 the harness, 2026-09-24; D17/D17b; a sibling program's
# recipe for the same container, ported).
#
# WHY. One shared machine carries every window; the regime since 2026-09-24 02:11 UTC (the owner's hosts page, D17b) is
# that a tripwire runs locally when the 1-minute load is under 20; since D156 (2026-09-28) it runs on the box above it and in
# this container on Modal only when MAKE_CHECK=modal (tools/check_route.sh), the verdict LINES byte-identical on every home. The pattern: a base image with the toolchains, a CONTENT-KEYED sources layer
# baked by running the legs once (a cache, never a verdict), and a check function that ships the CURRENT tree (a shallow
# clone of HEAD plus the working tree's changes, so `git rev-parse` in the container names the SAME commit the record
# names at home) over the baked tree and runs `make check-local` = tools/check.sh all, the SAME writer as a local run:
# the record file (the commit, the wall, the load before and after, every leg's verdict line, the sampler) is written
# in the container with a `where:` line (the app id, the container's size, its `uptime`) and brought home as
# docs/records/<stamp>-make-check-modal.txt. An unchanged tree is a run of the legs' own runtimes; a changed tree
# rebuilds what changed against the baked caches (cargo's target dir, Lake's oleans, the Go build and module caches,
# the ts adapter's node_modules).
#
# WHAT NEVER ENTERS THE CONTAINER: the node oracle (`run_svnode` is not a leg of `make check`), the built SV-node, the
# clones of the reference, Teranode, GoBDK, bsv-rs, go-sdk, ts-stack and the two predecessor pattern sources: the pins leg SKIPS
# those sites BY NAME (tools/check_pins.py prints each skip and counts it; a skip is never a pass), so the container's
# `check-pins` line reads fewer sites than the Studio's and says which. Nothing here is faked to make the count match.
#
# THE NETWORK (all reads, all pinned but the one marked unpinned, named once): Modal itself; crates.io (the locked crate set of harness/Cargo.lock);
# elan.lean-lang.org and GitHub releases (elan and the Lean toolchain of lean/lean-toolchain); GitHub and Mathlib's
# cache server (`lake exe cache get` for the manifest's Mathlib rev); go.dev (the Go toolchain tarball, verified against
# go.dev's own sha256 list); proxy.golang.org and sum.golang.org (go-sdk at its pin, go.sum-verified); nodejs.org (the
# node tarball, verified against its SHASUMS256.txt); registry.npmjs.org (@bsv/sdk and jscpd at their pins, the locks' integrity);
# crates.io again for cargo-deny 0.19.0 (tools/cargo_deny.sh, --locked) and GitHub for the RustSec advisory database
# (unpinned: the deny leg's verdict line names the database commit it read).
# Nothing reaches a peer (CLAUDE.md rule 10: the container holds this repo's tree and nothing of any private program).
#
# COST DISCIPLINE (this repo's PLAN §4): tier, expected wall, a wall-sized hard timeout, `retries=0`,
# `single_use_containers=True`, the price here before it runs. Rates [M] (`modal billing rates`, read 2026-09-23 on the
# maintainers' account): $0.0473 per core-hour = $0.00001314 per core·s; $0.008 per GiB-hour = $0.00000222 per GiB·s. Profile
# MODAL_PROFILE=<modal-name>, never another. The standing green light covers containers ≤ 128 GiB and ≤ $25 a run.
#
#   the base   (an image build, once per toolchain change) rust:1.95-bookworm + rustup 1.95.0 (harness/rust-toolchain.toml)
#              + elan + Lean v4.34.0 (lean/lean-toolchain, read at launch: the layer rebuilds by itself when the toolchain moves; v4.33.0 until the re-pin of 2026-09-27) + Go 1.27.0 + Node 22.18.0 (docs/PROVENANCE.md §1a: the
#              Studio's versions [M]) + Debian's make, clang, procps
#   the bake   (an image build step, once per change of the shipped tree, keyed on its content): the tree copied in,
#              `lake exe cache get` for Mathlib's oleans BOUNDED to LAKE_CACHE_TIMEOUT s (≈ 5 GB [EST] at the pinned
#              rev; a cache fetch, never a build of Mathlib), `npm ci` at the ts pin and at jscpd's, then `make check-local` at cpu 16
#              / 32 GiB · expected ≈ 25–45 min cold [EST] (the Lean modules and the seven check executables, the
#              harness crate on bsv-rs, the Go adapter) · timeout 7,200 s ⇒ ≤ 7,200 × (16 × 0.00001314 + 32 ×
#              0.00000222) ≈ $2.03 worst case · a cache, never a verdict (a red bake is logged and the layer kept; the
#              check reports it) · measured 2026-10-06 [M]: 778 s ≈ $0.22 cold at 974ba38 (app ap-hwcV1BTJupKurDhoCQBrll)
#              THE BUILDER'S DEATH (#56, 2026-10-06 10:55 UTC, app ap-Ay6hvDfJrtUBEq73XgH1Un): the build step's container died
#              about four minutes into `make check-local` with no exception from the bake (the client's `ImageBuildError`
#              names the build logs and no exception; the step restarted and failed within 89 s). The same bake re-run at
#              12:00 UTC was GREEN, and tools/modal_probe_56.py ran the bake's body as a function at 32 GiB with a 3.2 GB
#              peak RSS in 416 s: the death was the builder's, not the tree's. Since then the bake streams its legs' headers
#              and verdict lines into the build log (a death names the leg), and tools/check_route.sh re-launches ONCE on
#              that exact no-exception shape after reading the meter again.
#   the check  cpu 16 / 32 GiB · expected ≈ 4 to 8 min on a tree the layer holds (the legs' own runtimes), longer on
#              a tree it does not (cargo and Lake rebuild what changed) · timeout 4,800 s ⇒ ≤ $1.35 worst case ·
#              retries 0 · single-use containers · ≈ $0.10 [D] at 6 min · the verdict: tools/check.sh's own lines, the
#              record file it wrote, the full log on the Volume `<modal-name>`
#
# USAGE (from the repo root; `make check` = tools/check_route.sh routes here by itself above load 20, `make check-modal`
# or MAKE_CHECK=modal forces it):
#   MODAL_PROFILE=<modal-name> modal run tools/modal_check.py::check                # the working tree
#   MODAL_PROFILE=<modal-name> modal run tools/modal_check.py::check --committed    # the tree of HEAD alone
#   MODAL_PROFILE=<modal-name> modal run tools/modal_check.py::warm                 # bake without a verdict
#   SPEC_CHECK_LAYER_DIR=<dir> …                                                # the layer copied from an export of a commit
#                                                                               # instead of the working tree (see LAYER_DIR)
import io
import os
import re
import shutil
import socket
import subprocess
import sys
import tarfile
import tempfile
import threading
import time
from pathlib import Path

import modal

APP_NAME = "<modal-name>"
VOLUME_NAME = "<modal-name>"
RUST_IMAGE = "rust:1.95-bookworm"          # the pinned major.minor of docs/PROVENANCE.md §1a rust.toolchain
GO_VERSION = "1.27.0"                      # §1a go.major 1.27; the Studio runs go1.27.0 [M]
NODE_VERSION = "22.18.0"                   # §1a node.major 22; the Studio runs v22.18.0 [M]
COST_PER_CPU_S = 0.00001314
COST_PER_GIB_S = 0.00000222
CPU, MEM_MIB = 16.0, 32768
TIMEOUT = 4800                             # the check's hard wall
BAKE_TIMEOUT = 7200                        # the bake's hard wall (a cold Lean build of the project inside it)
LAKE_CACHE_TIMEOUT = 1800                  # `lake exe cache get`: Mathlib's oleans at the pinned rev, ≈ 5 GB [EST]; a fetch, never a build
ROOT = Path(__file__).resolve().parent.parent
# The sources layer is copied from LAYER_DIR: the working tree by default, or an export of a commit given as
# SPEC_CHECK_LAYER_DIR (`git archive HEAD | tar -x -C <dir>`), so a window may keep editing while the layer uploads (the
# second launch's finding, 2026-09-24: a file edited during the upload aborts the build) and the layer matches a
# `--committed` ship. Either way the layer is a cache, never a verdict.
LAYER_DIR = os.environ.get("SPEC_CHECK_LAYER_DIR", str(ROOT)) if modal.is_local() else str(ROOT)
# read at home; in the container the module lives beside no tree, so the values ride in the image's env
if modal.is_local():
    LEAN_TOOLCHAIN = (ROOT / "lean" / "lean-toolchain").read_text().strip()
    _m = re.search(r'channel\s*=\s*"([^"]+)"', (ROOT / "harness" / "rust-toolchain.toml").read_text())
    RUST_CHANNEL = _m.group(1) if _m else "1.95.0"
else:
    LEAN_TOOLCHAIN = os.environ.get("SPEC_LEAN_TOOLCHAIN", "")
    RUST_CHANNEL = os.environ.get("SPEC_RUST_CHANNEL", "1.95.0")
ENV = {"PATH": "/root/.elan/bin:/usr/local/cargo/bin:/usr/local/go/bin:/usr/local/node/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin",
       "ELAN_HOME": "/root/.elan", "CARGO_TARGET_DIR": "/cache/target", "CARGO_BUILD_JOBS": "16",
       "CARGO_HOME": "/usr/local/cargo", "RUSTUP_HOME": "/usr/local/rustup", "RUST_BACKTRACE": "1",
       "GOCACHE": "/cache/go-build", "GOMODCACHE": "/cache/gomod", "GOTOOLCHAIN": "local", "GOFLAGS": "-mod=mod",
       "NODE_BIN": "/usr/local/node/bin/node", "npm_config_cache": "/cache/npm", "JSCPD_HOME": "/cache/jscpd", "DENY_TOOLCHAINS": "/cache/toolchains"}


def _sources() -> set:
    """the files the layer carries = the files a ship carries: every tracked file and every untracked file git does not
    ignore (never the cargo target dirs, the Lean cache (a 13-GB symlink to the shared cache), .git, node_modules, the
    20 MB policy-defaults-large witness, scratch, logs); their parent directories are kept so the walk descends"""
    if not modal.is_local():
        return set()
    out = subprocess.run(["git", "ls-files", "-z", "--cached", "--others", "--exclude-standard"], cwd=ROOT,
                         capture_output=True, check=True).stdout
    keep = set()
    for f in out.split(b"\0"):
        if not f:
            continue
        rel = Path(f.decode())
        keep.add(rel.as_posix())
        for parent in rel.parents:
            keep.add(parent.as_posix())
    keep.discard(".")
    return keep


SOURCES = _sources()


def _ignore(p) -> bool:
    if LAYER_DIR != str(ROOT):
        # an export of a commit (`git archive`) carries exactly the commit's tracked files: nothing to drop, and the
        # working tree's file list must not decide for it (the third launch's finding: four vector files renamed in
        # the working tree were dropped from the export's layer, and its bake read them as absent)
        return Path(p).name in ("__pycache__", ".DS_Store")
    rel = Path(p)
    if rel.is_absolute():
        try:
            rel = rel.relative_to(LAYER_DIR)
        except ValueError:
            return True
    s = rel.as_posix()
    if s in ("", "."):
        return False
    return s not in SOURCES


app = modal.App(APP_NAME)
records = modal.Volume.from_name(VOLUME_NAME, create_if_missing=True)


def _price(secs: float) -> float:
    return secs * (CPU * COST_PER_CPU_S + (MEM_MIB / 1024) * COST_PER_GIB_S)


def _sh(cmd: str, cwd: str, timeout: int, extra_env=None) -> tuple:
    """a plain (non-login) shell: a login shell sources /etc/profile, which resets PATH and hides rustup, cargo, go and
    lake from the legs (a launch finding); the environment is exported in the command as well"""
    env = {**ENV, **(extra_env or {})}
    exports = " ".join("%s=%r" % (k, v) for k, v in env.items())
    # a clean bash (RULES-TREE (28), 2026-09-28: a BASH_ENV with `set -n` reads a script without running it and exits 0)
    p = subprocess.run(["/bin/bash", "--noprofile", "--norc", "-c", "export %s; %s" % (exports, cmd)], cwd=cwd, capture_output=True,
                       text=True, timeout=timeout, env={k: v for k, v in {**os.environ, **env}.items() if k != "BASH_ENV"})
    return p.returncode, (p.stdout or "") + (p.stderr or "")


# --- layer 1: the toolchains ------------------------------------------------------------------------
GO_INSTALL = (
    "cd /tmp && curl -sSfL 'https://go.dev/dl/?mode=json&include=all' -o godl.json"
    " && SHA=$(python3 -c \"import json,sys; d=json.load(open('godl.json')); print(next(f['sha256'] for r in d for f in r['files']"
    " if f['filename']=='go{v}.linux-amd64.tar.gz'))\")"
    " && curl -sSfL https://go.dev/dl/go{v}.linux-amd64.tar.gz -o go.tgz"
    " && echo \"$SHA  go.tgz\" | sha256sum -c -"
    " && tar -C /usr/local -xzf go.tgz && rm -f go.tgz godl.json && /usr/local/go/bin/go version"
).format(v=GO_VERSION)
NODE_INSTALL = (
    "cd /tmp && curl -sSfL https://nodejs.org/dist/v{v}/SHASUMS256.txt -o SHASUMS256.txt"
    " && curl -sSfL https://nodejs.org/dist/v{v}/node-v{v}-linux-x64.tar.xz -o node.tar.xz"
    " && grep ' node-v{v}-linux-x64.tar.xz$' SHASUMS256.txt | sed 's| node-v{v}-linux-x64.tar.xz| node.tar.xz|' | sha256sum -c -"
    " && mkdir -p /usr/local/node && tar -C /usr/local/node --strip-components=1 -xJf node.tar.xz"
    " && rm -f node.tar.xz SHASUMS256.txt && /usr/local/node/bin/node --version"
    " && PATH=/usr/local/node/bin:$PATH npm --version"   # npm is a script under `#!/usr/bin/env node`: the build step's PATH must carry node
).format(v=NODE_VERSION)

base = (
    modal.Image.from_registry(RUST_IMAGE, add_python="3.11")
    .apt_install("curl", "git", "ca-certificates", "make", "clang", "python3", "xz-utils", "procps", "hostname")
    .run_commands(
        "rustup toolchain install %s --profile minimal" % RUST_CHANNEL,
        "curl -sSf https://elan.lean-lang.org/elan-init.sh -o /tmp/elan-init.sh"
        " && sh /tmp/elan-init.sh -y --default-toolchain none",
        "/root/.elan/bin/elan toolchain install %s" % LEAN_TOOLCHAIN,
        GO_INSTALL,
        NODE_INSTALL,
        "mkdir -p /cache/target /cache/go-build /cache/gomod /cache/npm /cache/jscpd /cache/toolchains",
    )
    .env({**ENV, "SPEC_LEAN_TOOLCHAIN": LEAN_TOOLCHAIN, "SPEC_RUST_CHANNEL": RUST_CHANNEL})
)

VERDICT_PREFIXES = ("check-pins:", "lean:", "axiom check", "numcheck:", "flowcheck:", "sighash:", "sighash_verify:",
                    "arithcheck:", "stackcheck:", "crypto:", "seedcheck:", "scripttests:", "txtests", "flagscheck",
                    "specgen", "rpc_contract", "bytescheck:", "versiongatecheck:", "erascheck:", "witnesscheck:", "bsvs --self-test",
                    "run_bsvrs", "run_diff:", "run_engine:", "harness:", "make check:", "record:")


def _verdicts(log: str) -> list:
    return [l for l in log.splitlines() if l.startswith(VERDICT_PREFIXES)]


def _stream(cmd: str, cwd: str, timeout: int, logfile: str) -> tuple:
    """`_sh` with the output STREAMED: every line goes to `logfile`, and the legs' headers (`== leg: … ==`) and verdict
    lines are printed as they come, so the build log names the leg a dying container was in (#56, 2026-10-06: the
    builder's container died about four minutes into a bake whose whole `make check-local` log lived in that container;
    the client saw only `ImageBuildError` with no exception, and nothing said where). Returns (rc, the line count); a
    timeout kills the process and returns rc 124."""
    env = {**ENV}
    exports = " ".join("%s=%r" % (k, v) for k, v in env.items())
    p = subprocess.Popen(["/bin/bash", "--noprofile", "--norc", "-c", "export %s; %s" % (exports, cmd)], cwd=cwd,
                         stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True,
                         env={k: v for k, v in {**os.environ, **env}.items() if k != "BASH_ENV"})
    timer = threading.Timer(timeout, p.kill)
    timer.start()
    n = 0
    try:
        with open(logfile, "w") as f:
            for line in p.stdout:
                n += 1
                f.write(line)
                if line.startswith("== ") or line.startswith(VERDICT_PREFIXES):
                    print(line.rstrip(), flush=True)
        rc = p.wait()
    finally:
        timed_out = not timer.is_alive()
        timer.cancel()
    if timed_out and rc != 0:
        print("the command was killed at its timeout of %d s" % timeout, flush=True)
        rc = 124
    return rc, n


def bake():
    """cpu 16 / 32 GiB · timeout 7,200 s · ≤ $2.03 worst case · once per change of the shipped tree. Fetches Mathlib's
    oleans (bounded), installs the ts adapter's package at its pin, then runs the legs so the layer carries cargo's
    target dir, Lake's oleans and the check executables, the Go caches and node_modules. A cache, never a verdict: on
    a red the log's tail is printed and the layer kept (the check reports the red on the real tree). The legs' headers
    and verdict lines stream into the build log as they come (#56); the whole log is /proj/bake.log in the layer."""
    t0 = time.time()
    rc, log = _sh("cd lean && lake exe cache get 2>&1 | tail -3; rm -rf /root/.cache/mathlib", "/proj", LAKE_CACHE_TIMEOUT)
    print("lake exe cache get (rc %d, %.0f s):\n%s" % (rc, time.time() - t0, log), flush=True)
    rc, log = _sh("cd harness/engines/ts && npm ci --no-audit --no-fund --ignore-scripts 2>&1 | tail -3", "/proj", 900)
    print("npm ci at the ts pin (rc %d):\n%s" % (rc, log), flush=True)
    # jscpd at its pin into $JSCPD_HOME under /cache, which the check keeps: the jscpd leg reads no registry at check time
    rc, log = _sh("mkdir -p $JSCPD_HOME && cp tools/jscpd/package.json tools/jscpd/package-lock.json $JSCPD_HOME/"
                  " && cd $JSCPD_HOME && npm ci --no-audit --no-fund --ignore-scripts 2>&1 | tail -3", "/proj", 900)
    print("npm ci at the jscpd pin (rc %d):\n%s" % (rc, log), flush=True)
    rc, n = _stream("make check-local 2>&1", "/proj", BAKE_TIMEOUT - LAKE_CACHE_TIMEOUT - 1200, "/proj/bake.log")
    if rc != 0:
        _, tail = _sh("echo '--- the last 60 lines of bake.log ---'; tail -60 /proj/bake.log", "/proj", 60)
        print(tail, flush=True)
    print("bake: rc=%d wall=%.0fs ≈ $%.2f (%d lines in /proj/bake.log)%s" % (rc, time.time() - t0, _price(time.time() - t0), n,
                                                                            "" if rc == 0 else "  (the bake is RED at this tree; the check will say where)"), flush=True)


def _sources_image() -> modal.Image:
    img = base.add_local_dir(LAYER_DIR, "/proj", copy=True, ignore=_ignore)
    return img.run_function(bake, cpu=CPU, memory=MEM_MIB, timeout=BAKE_TIMEOUT)


stack = _sources_image()


def _tree_name(committed: bool) -> str:
    """the commit the tree stands at, and whether the working tree differs from it (the record names it)"""
    head = subprocess.run(["git", "rev-parse", "--short", "HEAD"], cwd=ROOT, capture_output=True, text=True, check=True).stdout.strip()
    if committed:
        return head + " (the committed tree: the shallow clone of HEAD alone)"
    dirty = subprocess.run(["git", "status", "--porcelain", "-uall"], cwd=ROOT, capture_output=True, text=True, check=True).stdout.splitlines()
    return head + ("" if not dirty else " + %d uncommitted path(s)" % len(dirty))


def _ship(committed: bool = False) -> bytes:
    """the tree as a tar.gz that carries its own `.git`: a depth-1 clone of HEAD (so `git rev-parse --short HEAD` in the
    container is the commit the record names at home, and eval/bsvs stamps `spec@<that commit>`, with `+dirty` when the
    changes laid over it touch `lean/`; lean #32's re-lens, BN-3), and unless `committed`
    the working tree's changes laid over it (every modified, added or deleted path and every untracked file git does not
    ignore), so `git status --porcelain` in the container counts what it counts at home"""
    with tempfile.TemporaryDirectory(prefix="spec-ship-") as tmp:
        dst = Path(tmp) / "tree"
        subprocess.run(["git", "clone", "--depth", "1", "--no-local", "--quiet", "file://" + str(ROOT), str(dst)], check=True,
                       capture_output=True)
        if not committed:
            out = subprocess.run(["git", "status", "--porcelain=v1", "-z", "-uall"], cwd=ROOT, capture_output=True, check=True).stdout
            toks = [t.decode() for t in out.split(b"\0")]
            i = 0
            while i < len(toks):
                t = toks[i]
                i += 1
                if len(t) < 4:
                    continue
                status, path = t[:2], t[3:]
                if status[0] in "RC":
                    old = toks[i] if i < len(toks) else None   # the rename's source follows; it is gone at home
                    i += 1
                    if old and (dst / old).exists():
                        (dst / old).unlink()
                src = ROOT / path
                target = dst / path
                if src.is_file() or src.is_symlink():
                    target.parent.mkdir(parents=True, exist_ok=True)
                    if target.exists() or target.is_symlink():
                        target.unlink()
                    shutil.copy2(src, target, follow_symlinks=False)
                elif target.exists() or target.is_symlink():
                    target.unlink()
        buf = io.BytesIO()
        with tarfile.open(fileobj=buf, mode="w:gz") as tar:
            tar.add(str(dst), arcname=".", recursive=True)
        return buf.getvalue()


@app.function(image=stack, cpu=CPU, memory=MEM_MIB, timeout=TIMEOUT, retries=0, single_use_containers=True,
              volumes={"/rec": records})
def check_remote(tree_tgz: bytes, label: str, tree_name: str = "", app_id: str = "", shipped_from: str = "") -> dict:
    """cpu 16 / 32 GiB · timeout 4,800 s · ≤ $1.35 worst case · single use. The shipped tree replaces the baked one at
    the same path (cargo's fingerprints and Lake's traces are keyed on paths and contents); the caches stay: /cache
    (cargo, go, npm, jscpd), lean/.lake and harness/engines/ts/node_modules under /proj. Then `make check-local` runs: the
    verdict is tools/check.sh's own lines and the record file it wrote."""
    t0 = time.time()
    work = "/proj"
    sweep = ("find /proj -mindepth 1 -maxdepth 1 ! -name lean ! -name harness -exec rm -rf {} +;"
             " find /proj/lean -mindepth 1 -maxdepth 1 ! -name .lake -exec rm -rf {} +;"
             " find /proj/harness -mindepth 1 -maxdepth 1 ! -name engines -exec rm -rf {} +;"
             " find /proj/harness/engines -mindepth 1 -maxdepth 1 ! -name ts -exec rm -rf {} +;"
             " find /proj/harness/engines/ts -mindepth 1 -maxdepth 1 ! -name node_modules -exec rm -rf {} +")
    _sh(sweep, "/", 300)
    with tarfile.open(fileobj=io.BytesIO(tree_tgz), mode="r:gz") as tar:
        try:
            tar.extractall(work, filter="fully_trusted")
        except TypeError:
            tar.extractall(work)
    _sh("git config --global --add safe.directory /proj; git -C /proj rev-parse --short HEAD", work, 60)
    _, up = _sh("uptime", work, 30)
    note = ("Modal (tools/modal_check.py, app %s, label %s): cpu %.0f / %d GiB, retries 0, single-use; the container's uptime: %s;"
            " the tree shipped from %s as %s" % (app_id or "?", label, CPU, MEM_MIB // 1024, up.strip(), shipped_from or "?", tree_name or "unnamed"))
    rc, log = _sh("make check-local 2>&1", work, TIMEOUT - 300, extra_env={"CHECK_RECORD_NOTE": note})
    wall = time.time() - t0
    lines = log.splitlines()
    verdict = _verdicts(log)
    rec_line = next((l for l in lines if l.startswith("record: ")), "")
    rec_path = rec_line[len("record: "):].strip()
    rec_text = ""
    rec_name = ""
    if rec_path and os.path.exists(rec_path):
        rec_text = open(rec_path, encoding="utf-8", errors="replace").read()
        rec_name = os.path.basename(rec_path)
    stamp = time.strftime("%Y%m%d-%H%M%S", time.gmtime())
    log_path = "/rec/%s-make-check-modal-%s.log" % (stamp, label)
    with open(log_path, "w") as f:
        f.write("# make check on Modal (bsv-script-lean, tools/modal_check.py): the tree at %s; %s UTC is the run's END time; %s; rc %d, wall %.0f s, ≈ $%.3f\n"
                % (tree_name or "unnamed", stamp, note, rc, wall, _price(wall)))
        f.write(log)
    records.commit()
    # THE CONTAINER'S OWN GREEN (RULES-TREE (28)): rc 0 counts only with the "make check: GREEN" line check.sh prints after
    # every leg's own verdict line stood; without it the run is RED whatever its exit code
    green = any(l.startswith("make check: GREEN") for l in lines)
    if rc == 0 and not green:
        verdict = list(verdict) + ["modal check: RED: rc 0 without the 'make check: GREEN' line (RULES-TREE (28))"]
    return {"ok": rc == 0 and green, "rc": rc, "wall_s": round(wall, 1), "price": round(_price(wall), 3), "verdict": verdict,
            "tail": lines[-30:], "stamp": stamp, "log": log_path, "tree": tree_name, "record_name": rec_name,
            "record_text": rec_text, "uptime": up.strip()}


def _report(r: dict) -> bool:
    for l in r["verdict"]:
        print(l)
    if not r["ok"]:
        print("--- the tail ---")
        for l in r["tail"]:
            print("  |", l)
    print("modal check: %s (rc %d) in %s s on cpu %.0f / %d GiB ≈ $%.3f [D] at the [M] rates; the container's uptime: %s; the log %s on the Volume %s"
          % ("GREEN" if r["ok"] else "RED", r["rc"], r["wall_s"], CPU, MEM_MIB // 1024, r["price"], r.get("uptime", "?"), r["log"], VOLUME_NAME))
    if r.get("record_text"):
        name = r["record_name"].replace("-make-check.txt", "-make-check-modal.txt")
        out = ROOT / "docs" / "records" / name
        out.write_text(r["record_text"])
        print("the record %s (written by tools/check.sh in the container, brought home unchanged; commit it with the run's page line)" % out.relative_to(ROOT))
    else:
        print("no record file came back (tools/check.sh did not reach record_run): the log on the Volume is the evidence")
    return r["ok"]


@app.local_entrypoint()
def check(label: str = "tree", committed: bool = False):
    """The tripwire on Modal on the CURRENT working tree (or, with --committed, on the tree of HEAD alone): exit 0 iff
    `make check-local` is GREEN there. The record names the commit; its stamp is the run's start time in the container."""
    name = _tree_name(committed)
    app_id = getattr(app, "app_id", None) or ""
    ok = _report(check_remote.remote(_ship(committed), label, name, app_id, socket.gethostname()))
    sys.exit(0 if ok else 1)


@app.local_entrypoint()
def warm():
    """Force the bake (the sources layer) without a verdict run."""
    print("the sources layer is baked when this returns:", check_remote.remote.__doc__ is not None)
