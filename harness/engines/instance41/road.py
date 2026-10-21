#!/usr/bin/env python3
"""JSON-lines worker of the recipe for the Rust adapter: the attestation and the disk headroom.

The Rust adapter owns transactions, comparisons and witnesses, and reads the node
only through the observation contract (harness/engines/teranode/contract.rs, #97;
since lane trait-97, 2026-10-15, this worker makes no RPC call and no asset read).
This worker attests the running process (its source, binary, settings and
listeners) and checks the disk headroom. No corpus file is rewritten.
"""

import hashlib
import json
import socket
import subprocess
import sys
from pathlib import Path

import instance


def attest():
    state = instance.saved_state()
    if state is None:
        raise RuntimeError("the lane's instance is stopped")
    if instance.command("git", "-C", str(instance.SOURCE), "rev-parse", "HEAD") != instance.PIN:
        raise RuntimeError("source HEAD differs from the pin")
    if instance.sha256(instance.BINARY) != instance.BINARY_SHA256:
        raise RuntimeError("running binary differs from the receipt")
    addresses = instance.listeners(state["pid"])
    if "127.0.0.1:8081" not in addresses:
        raise RuntimeError("native validator is absent; start with --validator")
    files = {name: instance.sha256(instance.RUNTIME / name)
             for name in ("settings.conf", "settings_test.conf", "settings_local.conf")}
    if files["settings_local.conf"] != instance.sha256(Path(__file__).with_name("settings_local.conf")):
        raise RuntimeError("running local settings differ from this adapter's settings")
    defaults = subprocess.check_output(["git", "-C", str(instance.SOURCE), "show", f"{instance.PIN}:settings.conf"])
    if files["settings.conf"] != hashlib.sha256(defaults).hexdigest():
        raise RuntimeError("running defaults differ from the tagged defaults")
    settings = {"files": files, "environment": state.get("environment"), "services": state.get("services")}
    if settings["environment"] is None or settings["services"] is None:
        raise RuntimeError("restart the instance to record its effective environment and services")
    canonical = json.dumps(settings, sort_keys=True, separators=(",", ":")).encode()
    return {"tag": instance.TAG, "commit": instance.PIN,
            "binary_sha256": instance.BINARY_SHA256,
            "settings_hash": hashlib.sha256(canonical).hexdigest(),
            "settings_hash_definition": "sha256 of UTF-8 compact sorted-key JSON of settings",
            "settings": settings, "host": socket.gethostname(), "pid": state["pid"],
            "listeners": addresses, "rpc": instance.RPC_URL,
            "validator": "127.0.0.1:8081"}


def main():
    for line in sys.stdin:
        try:
            request = json.loads(line)
            if request.get("method") == "attest":
                answer = {"result": attest(), "error": None}
            elif request.get("method") == "headroom":
                instance.headroom()
                answer = {"result": {}, "error": None}
            else:
                answer = {"transport_error": f"{request.get('method')} is not a recipe call; the node is read through the contract",
                          "result": None, "error": None}
        except (OSError, ValueError, RuntimeError) as error:
            answer = {"transport_error": str(error), "result": None, "error": None}
        print(json.dumps(answer, sort_keys=True), flush=True)


if __name__ == "__main__":
    main()
