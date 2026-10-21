#!/usr/bin/env python3
"""Start, inspect and stop the local instance for issue 41.

[SRC] Teranode v0.16.0 at 4edb60a40c6628ff0ef60231c2628efd7103fde5:
daemon/test_daemon.go:518-529 (services), daemon/daemon.go:577-600 (flags).
The config loader is go.mod:41's gocore v1.1.0, config.go:140-175,
223-312 and 553-572 (binary-adjacent files and variable substitution).

The alert recipe (--alert, #94's store half): the alert service on, its own
libp2p listener bound 0.0.0.0 on ALERT_P2P_PORT (services/alert/server.go
loadConfig; settings.go:209). It needs alert_genesis_keys in the caller's
overlay.conf (services/alert/server.go loadConfig answers ErrNoGenesisKeys
without it) and alert_p2p_allow_private_ips true for loopback peers
(settings.go:205); the DHT bootstrap peers it dials at start are the go-alert
system's own defaults.
"""

import argparse
import base64
import fcntl
import hashlib
import json
import os
from pathlib import Path
import shutil
import signal
import socket
import subprocess
import sys
import time
import urllib.error
import urllib.request


TAG = "v0.16.0"
PIN = "4edb60a40c6628ff0ef60231c2628efd7103fde5"
# [M] The recipe build on box, recorded in this directory's README.
BINARY_SHA256 = "dedd0003386ac5ee7969ab1beaab9db91b0291baf70e066717a3c8e85b3f9ee8"
BASE = Path.home() / "bsv/targets/spec-teranode"
SOURCE = BASE / f"src-{TAG}"
# INSTANCE41_DATA names another chain's directory (a fresh regtest chain for the
# Genesis-to-Chronicle era, heights 100 to 199); the default is the running chain.
DATA = Path(os.environ["INSTANCE41_DATA"]) if os.environ.get("INSTANCE41_DATA") else BASE / "data"
RUNTIME = DATA / "runtime"
BINARY = RUNTIME / "teranode.run"
STATE = DATA / "instance.json"
LOG = DATA / "instance.log"
RPC_URL = "http://127.0.0.1:9292"
PORTS = (8000, 8082, 8084, 8085, 8086, 8087, 8088, 8090, 8833, 9091, 9292)
# The second recipe (#66 cut 2): the legacy bridge's P2P and gRPC listeners, both
# on 127.0.0.1 by legacy.conf (LEGACY_P2P_PORT; LEGACY_GRPC_PORT, settings.conf:103 at PIN).
LEGACY_PORTS = (18590, 8099)
# The alert recipe (#94's store half, lane hz-94s): the alert service's own libp2p
# listener. [SRC] at PIN it binds 0.0.0.0 (services/alert/server.go loadConfig, its
# P2PConfig.IP), on the port of the ALERT_P2P_PORT setting (settings.go:209, default
# 9908); the wildcard bind is the service's own, so the listener check allows exactly it.
ALERT_PORT = 9908
ALERT_WILDCARD = f"0.0.0.0:{ALERT_PORT}"
SERVICES = [
    "-all=0", "-blockchain=1", "-subtreevalidation=1", "-blockvalidation=1",
    "-blockassembly=1", "-asset=1", "-propagation=1", "-rpc=1",
    "-p2p=0", "-alert=0", "-legacy=0",
]


def utc():
    return time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())


def step(name, started, code, **numbers):
    """lane tera-97e2 (#97): one line of the column's steps file (ORACLE_STEPS, set by
    harness/engines/teranode/column.zsh beside the quarantine directory): the step's name,
    UTC stamps, exit code and numbers only, never a line of the instance's output."""
    path = os.environ.get("ORACLE_STEPS")
    if path:
        with open(path, "a") as out:
            out.write(json.dumps({"step": name, "started": started, "ended": utc(), "exit": code, **numbers}) + "\n")


def command(*args, **kwargs):
    return subprocess.check_output(args, text=True, **kwargs).strip()


def sha256(path):
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def headroom():
    if shutil.disk_usage(Path.home()).free < 12 * 1024**3:
        raise RuntimeError("disk free space is below 12 GiB")


def identity(pid):
    result = subprocess.run(
        ["ps", "-p", str(pid), "-o", "lstart=", "-o", "stat=", "-o", "comm="],
        capture_output=True, text=True, env={"PATH": "/usr/bin:/bin", "LC_ALL": "C"},
    )
    if result.returncode or not result.stdout.strip():
        return None
    fields = result.stdout.split()
    if fields[5].startswith("Z"):
        return None
    return {"started": " ".join(fields[:5]), "executable": " ".join(fields[6:])}


def saved_state():
    if not STATE.exists():
        return None
    state = json.loads(STATE.read_text())
    current = identity(state["pid"])
    if current is None:
        STATE.unlink()
        return None
    if current != state["identity"] or current["executable"] != str(BINARY):
        raise RuntimeError("recorded PID has another identity; refusing to signal it")
    return state


def listeners(pid, alert=False):
    result = subprocess.run(
        ["lsof", "-nP", "-a", "-p", str(pid), "-iTCP", "-sTCP:LISTEN", "-Fn"],
        capture_output=True, text=True,
    )
    if result.returncode:
        raise RuntimeError("cannot inspect the instance's TCP listeners")
    addresses = sorted({line[1:] for line in result.stdout.splitlines() if line.startswith("n")})
    # lsof prints the alert service's wildcard bind as "*:9908" on this host
    # (seen at 2026-10-17T20:25Z, the recipe's initial start); normalize it to the
    # canonical form so the allowed-set check below matches either spelling.
    if alert:
        addresses = [ALERT_WILDCARD if address == f"*:{ALERT_PORT}" else address for address in addresses]
    # The alert recipe's one wildcard listener (ALERT_WILDCARD) is the service's own.
    allowed = {ALERT_WILDCARD} if alert else set()
    others = [address for address in addresses if address not in allowed]
    if not addresses or any(not address.startswith("127.0.0.1:") for address in others):
        raise RuntimeError(f"unexpected listener address: {addresses}")
    if alert and ALERT_WILDCARD not in addresses:
        raise RuntimeError("alert listener is absent")
    if "127.0.0.1:9292" not in addresses:
        raise RuntimeError("RPC listener is absent")
    return addresses


def rpc(method, params):
    # [SRC] settings.conf:1273-1280 at PIN: local RPC URL and test credentials.
    body = json.dumps({"jsonrpc": "1.0", "id": "instance41", "method": method, "params": params}).encode()
    auth = base64.b64encode(b"bitcoin:bitcoin").decode()
    request = urllib.request.Request(RPC_URL, body, {"Content-Type": "application/json", "Authorization": f"Basic {auth}"})
    opener = urllib.request.build_opener(urllib.request.ProxyHandler({}))
    try:
        response = opener.open(request, timeout=5)
    except urllib.error.HTTPError as error:
        response = error
    with response:
        return json.load(response)


def exited(state):
    # After our SIGTERM, ps reports an exiting process with a changed identity
    # (seen at 2026-10-05T23:20Z: the node had stopped gracefully, yet the
    # poll raised). Any identity other than the saved one counts as exited here;
    # the saved state is removed and nothing further is signalled.
    current = identity(state["pid"])
    if current is not None and current == state["identity"]:
        return False
    STATE.unlink(missing_ok=True)
    return True


def stop(state):
    if state is None:
        return {"running": False}
    pid = state["pid"]
    try:
        os.kill(pid, signal.SIGTERM)
    except ProcessLookupError:
        pass
    deadline = time.monotonic() + 60
    while time.monotonic() < deadline:
        if exited(state):
            return {"running": False, "pid": pid, "signal": "SIGTERM"}
        time.sleep(0.2)
    # Signal only a process whose saved identity still matches; a state found
    # gone here means the process has exited and its PID may be reused.
    if exited(state):
        return {"running": False, "pid": pid, "signal": "SIGTERM"}
    os.kill(pid, signal.SIGKILL)
    raise RuntimeError(f"PID {pid} needed SIGKILL after 60 seconds; inspect {LOG}")


def halt(proc):
    # The start path's guard: the saved state when it was written, else the child.
    state = saved_state()
    if state is not None:
        stop(state)
    elif proc.poll() is None:
        proc.terminate()
        try:
            proc.wait(timeout=60)
        except subprocess.TimeoutExpired:
            proc.kill()
    proc.wait(timeout=5)


def start(enable_validator=False, enable_legacy=False, enable_pruner=False, enable_alert=False):
    if saved_state() is not None:
        raise RuntimeError("instance is already running; stop it before another start")
    headroom()
    if os.getloadavg()[0] >= 20:
        raise RuntimeError("1-minute load is at least 20")
    if command("git", "-C", str(SOURCE), "rev-parse", "HEAD") != PIN:
        raise RuntimeError("source HEAD differs from the pin")
    built = SOURCE / "teranode.run"
    if sha256(built) != BINARY_SHA256:
        raise RuntimeError("binary differs from the recorded recipe build")
    ports = (PORTS + ((8081, 8834) if enable_validator else ())
             + (LEGACY_PORTS if enable_legacy else ()) + ((8096,) if enable_pruner else ())
             + ((ALERT_PORT,) if enable_alert else ()))
    services = SERVICES + (["-validator=1"] if enable_validator else []) + (["-pruner=1"] if enable_pruner else [])
    if enable_legacy:
        # [SRC] daemon/daemon.go:577-600: the same flag the recipe of record sets to 0.
        services = [flag if flag != "-legacy=0" else "-legacy=1" for flag in services]
    if enable_alert:
        # [SRC] daemon/daemon.go:577-600; the alert service needs alert_genesis_keys set
        # (services/alert/server.go loadConfig answers ErrNoGenesisKeys without it), a policy
        # parameter of the caller's overlay.conf.
        services = [flag if flag != "-alert=0" else "-alert=1" for flag in services]
    # lane cut2-66q4: a start seconds after a stop (the settings restarts of #66 cut 2, or the
    # next run) can meet the stopped instance's connections in TIME_WAIT on these ports, which
    # refuse the probe's bind; each port gets up to 120 s, then the refusal stands.
    deadline = time.monotonic() + 120
    for port in ports:
        while True:
            try:
                with socket.socket() as probe:
                    probe.bind(("127.0.0.1", port))
                break
            except OSError:
                if time.monotonic() >= deadline:
                    raise
                time.sleep(1)

    RUNTIME.mkdir(parents=True, exist_ok=True)
    shutil.copy2(built, BINARY)
    defaults = subprocess.check_output(["git", "-C", str(SOURCE), "show", f"{PIN}:settings.conf"])
    (RUNTIME / "settings.conf").write_bytes(defaults)
    (RUNTIME / "settings_test.conf").write_text("# No additional test overrides.\n")
    local = Path(__file__).with_name("settings_local.conf").read_bytes()
    if enable_legacy:
        # The second recipe: legacy.conf after the local settings, one file, hashed below.
        local += b"\n" + Path(__file__).with_name("legacy.conf").read_bytes()
    # lane cut2-66q4 (#66 cut 2, the settings restarts): a caller's overlay.conf in the data
    # directory (one reference setting's Teranode key per line, written by the runner before a
    # restart on the same data) goes after them, in the same hashed file.
    overlay = DATA / "overlay.conf"
    if overlay.exists():
        local += b"\n" + overlay.read_bytes()
    (RUNTIME / "settings_local.conf").write_bytes(local)
    settings_sha256 = hashlib.sha256(local).hexdigest()
    (RUNTIME / "tmp").mkdir(exist_ok=True)
    # A clean environment prevents caller settings and proxies overriding this run.
    env = {
        "HOME": str(Path.home()), "PATH": "/usr/bin:/bin:/usr/sbin:/sbin", "LC_ALL": "C",
        "SETTINGS_CONTEXT": "test", "SETTINGS_ENV_FILE": "/dev/null", "DATADIR": str(DATA),
        "TMPDIR": str(RUNTIME / "tmp"), "GOMAXPROCS": "4", "GOMEMLIMIT": "6GiB",
    }
    # The guard is in place before the launch. SIGINT and SIGTERM are only
    # noted until the child and its saved state exist, then raised inside the
    # try. Handlers, unlike a blocked mask, are not inherited across exec.
    proc = None
    noted = []
    previous = {signum: signal.signal(signum, lambda n, f: noted.append(n))
                for signum in (signal.SIGINT, signal.SIGTERM)}
    try:
        try:
            with LOG.open("ab") as log:
                proc = subprocess.Popen([str(BINARY), *services], cwd=RUNTIME, env=env,
                                        stdin=subprocess.DEVNULL, stdout=log, stderr=log, start_new_session=True)
            state = {"pid": proc.pid, "identity": identity(proc.pid), "sha256": BINARY_SHA256,
                     "ports": list(ports), "services": services, "environment": env,
                     "recipe": ("legacy" if enable_legacy else "of record")
                     + (" alert" if enable_alert else ""),
                     "alert": enable_alert, "settings_local_sha256": settings_sha256}
            STATE.write_text(json.dumps(state) + "\n")
            STATE.chmod(0o600)
        finally:
            for signum, handler in previous.items():
                signal.signal(signum, handler)
        if noted:
            raise RuntimeError(f"start interrupted by signal {noted[0]}")
        deadline = time.monotonic() + 120
        waited, waited_from = time.monotonic(), utc()
        while time.monotonic() < deadline:
            headroom()
            if proc.poll() is not None:
                step("readiness_wait", waited_from, proc.returncode, seconds=round(time.monotonic() - waited, 1))
                raise RuntimeError(f"instance exited {proc.returncode}; inspect {LOG}")
            try:
                answer = rpc("getblockchaininfo", [])
            except (urllib.error.URLError, TimeoutError, ConnectionError):
                time.sleep(0.5)
                continue
            if answer.get("error") is None and answer.get("result", {}).get("chain") == "regtest":
                addresses = listeners(proc.pid, alert=enable_alert)
                expected = {f"127.0.0.1:{port}" for port in ports}
                if enable_alert:
                    expected = (expected - {f"127.0.0.1:{ALERT_PORT}"}) | {ALERT_WILDCARD}
                if set(addresses) == expected:
                    step("readiness_wait", waited_from, 0, seconds=round(time.monotonic() - waited, 1))
                    return {"running": True, "pid": proc.pid, "sha256": BINARY_SHA256,
                            "listeners": addresses, "rpc": answer, "services": services,
                            "recipe": ("legacy" if enable_legacy else "of record")
                            + (" alert" if enable_alert else ""),
                            "settings_local_sha256": settings_sha256}
            time.sleep(0.5)
        seen = listeners(proc.pid, alert=enable_alert) if proc.poll() is None else []
        step("readiness_wait", waited_from, 1, seconds=round(time.monotonic() - waited, 1), listening=len(seen))
        raise RuntimeError(f"RPC and service listeners were not ready within 120 seconds (listening {seen}); inspect {LOG}")
    except BaseException:
        if proc is not None:
            halt(proc)
        raise


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=("start", "stop", "status", "rpc"))
    parser.add_argument("method", nargs="?")
    parser.add_argument("params", nargs="?", default="[]", help="RPC parameter array as JSON")
    parser.add_argument("--validator", action="store_true", help="serve the native validator on loopback for the block-context path")
    parser.add_argument("--legacy", action="store_true", help="the second recipe: the legacy P2P bridge on, its listeners on loopback (legacy.conf)")
    parser.add_argument("--pruner", action="store_true", help="start the pruning service on loopback (its gRPC port 8096; needs a pruner overlay in the data directory)")
    parser.add_argument("--alert", action="store_true", help="the alert recipe: the alert service on, its own libp2p listener (alert_genesis_keys required in overlay.conf)")
    args = parser.parse_args()
    DATA.mkdir(parents=True, exist_ok=True, mode=0o700)
    with (DATA / "control.lock").open("a") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        if args.action == "start":
            def interrupted(signum, frame):
                raise RuntimeError(f"start interrupted by signal {signum}")
            signal.signal(signal.SIGTERM, interrupted)
            signal.signal(signal.SIGINT, interrupted)
            # INSTANCE41_RECIPE=legacy selects the second recipe for a caller that cannot pass the flag.
            started = utc()
            try:
                answer = start(args.validator,
                               args.legacy or os.environ.get("INSTANCE41_RECIPE") == "legacy",
                               args.pruner,
                               args.alert or os.environ.get("INSTANCE41_RECIPE") == "alert-legacy")
            except BaseException:
                step("instance_start", started, 1)
                raise
            step("instance_start", started, 0)
        else:
            state = saved_state()
            if args.action == "stop":
                answer = stop(state)
            elif args.action == "status":
                answer = {"running": state is not None, "state": state}
                if state:
                    answer["listeners"] = listeners(state["pid"], alert=state.get("alert", False))
            else:
                if state is None or args.method is None:
                    raise RuntimeError("rpc needs a running instance and a method")
                params = json.loads(args.params)
                if not isinstance(params, list):
                    raise RuntimeError("RPC parameters must be a JSON array")
                answer = rpc(args.method, params)
        print(json.dumps(answer, sort_keys=True))


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, RuntimeError, subprocess.SubprocessError) as error:
        print(f"instance41: {error}", file=sys.stderr)
        sys.exit(1)
