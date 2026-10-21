#!/usr/bin/env python3
"""Build the native RPC client from the existing tagged source and module cache.

The build directory is outside the repository. No upstream source is changed
and GOPROXY=off prevents a network fetch. The module files are the pin's own,
with a different main-module name and a local replacement for that pin.
"""
import os
from pathlib import Path
import shutil
import subprocess
import sys

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
import instance

instance.headroom()
if os.getloadavg()[0] >= 20:
    raise SystemExit("1-minute load is at least 20")
if instance.command("git", "-C", str(instance.SOURCE), "rev-parse", "HEAD") != instance.PIN:
    raise SystemExit("source HEAD differs from the pin")
# INSTANCE41_NATIVE_DIR puts the build elsewhere (a lane keeps its build output in its worktree);
# the contract (harness/engines/teranode/contract.rs) reads the client from the same variable.
target = Path(os.environ.get("INSTANCE41_NATIVE_DIR") or instance.BASE / "native-client")
target.mkdir(parents=True, exist_ok=True)
text = (instance.SOURCE / "go.mod").read_text().replace(
    "module github.com/bsv-blockchain/teranode", "module instance41-native", 1)
text += f"\nrequire github.com/bsv-blockchain/teranode v0.0.0\nreplace github.com/bsv-blockchain/teranode => {instance.SOURCE}\n"
(target / "go.mod").write_text(text)
shutil.copyfile(instance.SOURCE / "go.sum", target / "go.sum")
shutil.copyfile(Path(__file__).with_name("main.go"), target / "main.go")
env = dict(os.environ, GOPROXY="off", GOSUMDB="off", GOTOOLCHAIN="local", GOMAXPROCS="4", CGO_ENABLED="1")
go = Path.home() / "bsv/targets/spec-box/toolchains/go/bin/go"
subprocess.run([str(go), "build", "-mod=readonly", "-p=4", "-trimpath", "-o", "client", "."], cwd=target, env=env, check=True)
print(f"instance41 native client: {target / 'client'} sha256 {instance.sha256(target / 'client')}")
