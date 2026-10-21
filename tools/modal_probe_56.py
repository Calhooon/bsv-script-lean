# tools/modal_probe_56.py: THE PROBE FOR #56 (bsv-script-lean, S3, lane modal-56, 2026-10-06). A diagnostic, never a verdict.
#
# WHY. The Modal route's image build of 2026-10-06 10:55 UTC (app ap-Ay6hvDfJrtUBEq73XgH1Un, image im-po15yARNyfY5Mb4W4L4YRa)
# died SILENTLY about four minutes into the bake's `make check-local`: the app log shows `lake exe cache get` (rc 0, 124 s)
# and `npm ci` (rc 0) succeed at 10:57 UTC, then at 11:01 the build's step 0 starts over with no output, saves an empty
# layer in 1.7 s and the client raises ImageBuildError. The bake sends `make check-local`'s output to /proj/bake.log
# inside the build container, which dies with it, so nothing says which leg was running or why the container went.
#
# WHAT THIS DOES. The bake's three steps (tools/modal_check.py `bake`) as an ORDINARY function on the same base image
# with the same layer (the base definition below is copied verbatim so Modal reuses the built base image), cpu 16 and
# the memory given (PROBE_MEM_GIB, default 32), with `make check-local`'s output STREAMED line by line and a sampler
# printing every 15 s the container's memory (/proc/meminfo, the cgroup's current and peak), the free disk under /proj
# and the four largest processes by RSS. A function's death carries Modal's own reason (a build step's does not), and
# the last streamed lines name the leg. `--stage tools` stops after the toolchain versions and the layer's listing.
#
# PRICE (the rates of tools/modal_check.py [M]): cpu 16 / 32 GiB · timeout 3,000 s ⇒ ≤ 3,000 × (16 × 0.00001314 +
# 32 × 0.00000222) ≈ $0.84 worst case; at 64 GiB ≤ $1.06; retries 0; single-use. Profile <modal-name>. Every run is named
# with its price in docs/records/<stamp>-modal-56.md.
#
# USAGE (from the repo root): MODAL_PROFILE=<modal-name> [PROBE_MEM_GIB=64] modal run tools/modal_probe_56.py --stage bake|tools
import os
import re
import shutil
import subprocess
import threading
import time
from pathlib import Path

import modal

APP_NAME = "<modal-name>"
RUST_IMAGE = "rust:1.95-bookworm"
GO_VERSION = "1.27.0"
NODE_VERSION = "22.18.0"
COST_PER_CPU_S = 0.00001314
COST_PER_GIB_S = 0.00000222
CPU = 16.0
MEM_GIB = int(os.environ.get("PROBE_MEM_GIB", "32"))
MEM_MIB = MEM_GIB * 1024
TIMEOUT = 3000
ROOT = Path(__file__).resolve().parent.parent
LAYER_DIR = str(ROOT)
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
       "NODE_BIN": "/usr/local/node/bin/node", "npm_config_cache": "/cache/npm"}


def _sources() -> set:
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


def _price(secs: float) -> float:
    return secs * (CPU * COST_PER_CPU_S + MEM_GIB * COST_PER_GIB_S)


def _exports() -> str:
    return " ".join("%s=%r" % (k, v) for k, v in ENV.items())


def _sh(cmd: str, cwd: str, timeout: int) -> tuple:
    p = subprocess.run(["/bin/bash", "--noprofile", "--norc", "-c", "export %s; %s" % (_exports(), cmd)], cwd=cwd,
                       capture_output=True, text=True, timeout=timeout,
                       env={k: v for k, v in {**os.environ, **ENV}.items() if k != "BASH_ENV"})
    return p.returncode, (p.stdout or "") + (p.stderr or "")


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
    " && PATH=/usr/local/node/bin:$PATH npm --version"
).format(v=NODE_VERSION)

# the base of tools/modal_check.py, verbatim (the same definition hashes to the same built image: no rebuild)
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
        "mkdir -p /cache/target /cache/go-build /cache/gomod /cache/npm",
    )
    .env({**ENV, "SPEC_LEAN_TOOLCHAIN": LEAN_TOOLCHAIN, "SPEC_RUST_CHANNEL": RUST_CHANNEL})
)

probe_image = base.add_local_dir(LAYER_DIR, "/proj", copy=True, ignore=_ignore)


def _cat(path: str) -> str:
    try:
        return open(path).read().strip()
    except Exception:
        return "-"


def _sampler(stop: threading.Event):
    while not stop.is_set():
        mem = {}
        try:
            for line in open("/proc/meminfo"):
                k, v = line.split(":", 1)
                mem[k] = int(v.split()[0]) // 1024
        except Exception:
            pass
        try:
            free_mib = shutil.disk_usage("/proj").free // 2 ** 20
        except Exception:
            free_mib = -1
        top = subprocess.run(["/bin/bash", "-c", "ps -eo rss,comm --sort=-rss | awk 'NR>1 && NR<6 {printf \"%s:%dM \", $2, $1/1024}'"],
                             capture_output=True, text=True).stdout.strip()
        print("sample %s UTC: MemTotal %dM, MemAvailable %dM, used~%dM; cgroup current %s peak %s; /proj free %dM; top rss: %s"
              % (time.strftime("%H:%M:%S", time.gmtime()), mem.get("MemTotal", -1), mem.get("MemAvailable", -1),
                 mem.get("MemTotal", 0) - mem.get("MemAvailable", 0), _cat("/sys/fs/cgroup/memory.current"),
                 _cat("/sys/fs/cgroup/memory.peak"), free_mib, top), flush=True)
        stop.wait(15)


@app.function(image=probe_image, cpu=CPU, memory=MEM_MIB, timeout=TIMEOUT, retries=0, single_use_containers=True)
def probe(stage: str = "bake") -> dict:
    t0 = time.time()
    print("probe #56: cpu %.0f / %d GiB, timeout %d s, stage %s" % (CPU, MEM_GIB, TIMEOUT, stage), flush=True)
    head = ("nproc; head -3 /proc/meminfo; echo cgroup memory.max: $(cat /sys/fs/cgroup/memory.max 2>/dev/null || echo -);"
            " df -m /proj / | tail -2; lean --version; lake --version; cargo --version; rustc --version; go version;"
            " node --version; npm --version; git --version; echo '--- /proj ---'; ls -la /proj; du -sm /proj/* 2>/dev/null | sort -n | tail -12;"
            " ls -la /proj/tools/host_private.sh; find /proj -type f | wc -l")
    rc, log = _sh(head, "/proj", 300)
    print("the toolchain and the layer (rc %d):\n%s" % (rc, log), flush=True)
    if stage == "tools":
        wall = time.time() - t0
        print("probe: stage tools rc=%d wall=%.0fs ≈ $%.3f" % (rc, wall, _price(wall)), flush=True)
        return {"rc": rc, "wall_s": round(wall, 1), "price": round(_price(wall), 3)}
    rc, log = _sh("cd lean && lake exe cache get 2>&1 | tail -5; rm -rf /root/.cache/mathlib", "/proj", 1800)
    print("lake exe cache get (rc %d, %.0f s):\n%s" % (rc, time.time() - t0, log), flush=True)
    rc, log = _sh("cd harness/engines/ts && npm ci --no-audit --no-fund --ignore-scripts 2>&1 | tail -3", "/proj", 900)
    print("npm ci at the ts pin (rc %d):\n%s" % (rc, log), flush=True)
    stop = threading.Event()
    th = threading.Thread(target=_sampler, args=(stop,), daemon=True)
    th.start()
    t1 = time.time()
    p = subprocess.Popen(["/bin/bash", "--noprofile", "--norc", "-c", "export %s; make check-local 2>&1" % _exports()], cwd="/proj",
                         stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True,
                         env={k: v for k, v in {**os.environ, **ENV, "CHECK_RECORD_NOTE": "probe #56, a diagnostic, never a verdict"}.items()
                              if k != "BASH_ENV"})
    n = 0
    for line in p.stdout:
        n += 1
        print("| " + line.rstrip(), flush=True)
    rc = p.wait()
    stop.set()
    th.join(timeout=20)
    wall = time.time() - t0
    print("probe: make check-local rc=%d (%d lines, %.0f s); total wall=%.0fs ≈ $%.3f at cpu %.0f / %d GiB"
          % (rc, n, time.time() - t1, wall, _price(wall), CPU, MEM_GIB), flush=True)
    return {"rc": rc, "wall_s": round(wall, 1), "price": round(_price(wall), 3), "lines": n}


@app.local_entrypoint()
def main(stage: str = "bake"):
    r = probe.remote(stage)
    print("probe #56 returned:", r)
