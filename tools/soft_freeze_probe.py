#!/usr/bin/env python3
"""[D] 2026-10-16, lane ns-140 (#140 item 3): the reference half of row `tl.soft-freeze`, measured on fresh regtest instances.

The ledger row (corpus/teranode/absences.json, `tl.soft-freeze`) says: a block that spends an output on the consensus
blacklist is held from selection for `-softconsensusfreezeduration` blocks (a setting, default 3; 0 holds it indefinitely)
and unfreezes when enough child blocks are mined after it ([SRC] bitcoin-sv 6504a3aff65ba97c0f6c80962b033e35ecbfed4b:
src/validation.cpp:3402-3406 the trigger, :3720 the freeze, src/block_index.h:283-285 the hold, src/validation.h:219 the
default, src/init.cpp:1214-1221 the setting; src/rpc/frozentxo_rpc.cpp:346-378 addToConsensusBlacklist). This probe drives
it: the node of record (`~/bsv/targets/sv-v1.2.3/bin/bitcoind`, version checked) on an owned instance whose RPC/P2P pair
is the lowest free pair in 18571..18590 (tools/rpc_probe.py's `Node`, the base configuration
harness/oracle/scenarios.conf), nothing reaching a peer and nothing broadcast (CLAUDE.md rule 10).

Why a tools/ script and not a scenario row: the frozen family's runner (harness/src/scenarios/frozen.rs, its RELEASE
recipe) measures the release's end state only, against a corpus row the Lean judge reads; this probe records the
per-height states #140 asks for and judges nothing. The blocks are built with the pinned functional-test framework
(test/functional/test_framework at the pin, its tree checked clean before import; `blocktools.create_block`,
`create_coinbase` with an OP_TRUE output and `create_tx`), so no key is needed: every output here is anyone-can-spend.

Per phase, on its own instance: the chain to 101 by submitblock (coinbase-only blocks, OP_TRUE outputs), F at 102 spending
block 1's coinbase, addToConsensusBlacklist of F:0 from height 0 with no stop, block A at 103 carrying T (F:0 to OP_TRUE),
then coinbase-only blocks on A one at a time. After each submitblock the state is read by `getbestblockhash`,
`getblockcount`, `getchaintips` and `getblock <A> 1` (its `confirmations` and the `status` object's validity and soft
consensus freeze flag where the reply carries it), projected to the blocks' names.

Phases: `default` (the setting unset: the default 3; four descendants), `zero` (`softconsensusfreezeduration=0`; five
descendants).

Output: `--out <file>.json`, every call (phase, method, params, HTTP status, the reply as the node wrote it) and every
launch, and `projection`: per phase and per submitted block, the names of the tip and the chain tips with their status,
A's confirmations and A's freeze flag. Exit 0 when every phase ran to its end.

Usage: tools/soft_freeze_probe.py --out docs/records/<stamp>-s8-140-soft-freeze-reference-s3.json --runs <dir>
"""
import argparse
import json
import os
from pathlib import Path
import subprocess
import sys
import time

sys.path.insert(0, str(Path(__file__).resolve().parent))
import rpc_probe  # noqa: E402

PIN = "6504a3aff65ba97c0f6c80962b033e35ecbfed4b"
VERSION = "v1.2.3.0-g6504a3aff-dev"
CLONE = Path(os.environ["HOME"]) / "bsv/bitcoin-sv"
FRAMEWORK = CLONE / "test/functional"


def framework():
    """The pinned framework: the clone at the pin, its test framework and the header cdefs reads unmodified."""
    head = subprocess.run(["git", "-C", str(CLONE), "rev-parse", "HEAD"], capture_output=True, text=True).stdout.strip()
    if head != PIN:
        raise SystemExit(f"soft_freeze_probe: the clone is at {head}, not the pin")
    dirty = subprocess.run(["git", "-C", str(CLONE), "status", "--porcelain", "--", "test/functional/test_framework",
                            "src/policy/policy.h"], capture_output=True, text=True).stdout
    if dirty.strip():
        raise SystemExit("soft_freeze_probe: the framework or src/policy/policy.h differs from the pin")
    os.environ["SRCDIR"] = str(CLONE)
    sys.path.insert(0, str(FRAMEWORK))
    from test_framework import blocktools, mininode  # noqa: E402
    return blocktools, mininode


def version_check():
    out = subprocess.run([str(rpc_probe.RECORD), "-version"], capture_output=True, text=True).stdout.splitlines()
    if not out or VERSION not in out[0]:
        raise SystemExit(f"soft_freeze_probe: the binary's version is not {VERSION}")


class Chain:
    def __init__(self, node, bt, mn, t0):
        self.n, self.bt, self.mn = node, bt, mn
        self.names = {}
        self.time = t0
        genesis = node.ok("getblockhash", [0])
        self.names[genesis] = "genesis"
        self.tip = int(genesis, 16)

    def block(self, height, prev, txs, name):
        self.time += 1
        cb = self.bt.create_coinbase(height)
        blk = self.bt.create_block(prev, cb, self.time)
        blk.nVersion = 4
        for tx in txs:
            blk.vtx.append(tx)
        blk.hashMerkleRoot = blk.calc_merkle_root()
        blk.solve()
        reply = self.n.call("submitblock", [self.mn.ToHex(blk)], f"block {name} at {height}")
        self.names[blk.hash] = name
        return blk, cb, reply

    def state(self, a_hash):
        best = self.n.ok("getbestblockhash", [])
        tips = self.n.ok("getchaintips", [])
        a = self.n.ok("getblock", [a_hash, 1])
        status = a.get("status") if isinstance(a.get("status"), dict) else None
        return {
            "best": self.names.get(best, "unnamed"),
            "block_count": self.n.ok("getblockcount", []),
            "chaintips": sorted(({"tip": self.names.get(t["hash"], "unnamed"), "height": t["height"],
                                  "branchlen": t["branchlen"], "status": t["status"]} for t in tips),
                                key=lambda x: (x["height"], x["tip"])),
            "A_confirmations": a.get("confirmations"),
            "A_status": None if status is None else {k: status.get(k) for k in ("validity", "soft consensus frozen")},
        }


def phase(name, extra, descendants, runs, log, bt, mn):
    n = rpc_probe.Node(name, rpc_probe.RECORD, runs, ["genesisactivationheight=10", "chronicleactivationheight=20"] + extra, log)
    steps = []
    try:
        c = Chain(n, bt, mn, int(time.time()) - 20000)
        prev = c.tip
        coinbases = []
        for h in range(1, 102):
            blk, cb, reply = c.block(h, prev, [], f"b{h}")
            if reply.get("result") is not None or reply.get("error") is not None:
                raise SystemExit(f"{name}: block {h}: {reply}")
            coinbases.append(cb)
            prev = blk.sha256
        f = bt.create_tx(coinbases[0], 0, coinbases[0].vout[0].nValue - 1000)
        blk, _, reply = c.block(102, prev, [f], "base")
        if reply.get("result") is not None or reply.get("error") is not None:
            raise SystemExit(f"{name}: funding block: {reply}")
        prev = blk.sha256
        listed = n.ok("addToConsensusBlacklist", [{"funds": [{"txOut": {"txId": f.hash, "vout": 0},
                                                               "enforceAtHeight": [{"start": 0}],
                                                               "policyExpiresWithConsensus": False}]}])
        if listed.get("notProcessed") != []:
            raise SystemExit(f"{name}: addToConsensusBlacklist: {listed}")
        t = bt.create_tx(f, 0, f.vout[0].nValue - 1000)
        a, _, reply = c.block(103, prev, [t], "A")
        steps.append({"submitted": "A", "submitted_height": 103, "submitblock": reply.get("result"),
                      "error": reply.get("error"), **c.state(a.hash)})
        prev = a.sha256
        for i in range(descendants):
            label = f"A+{i + 1}"
            blk, _, reply = c.block(104 + i, prev, [], label)
            steps.append({"submitted": label, "submitted_height": 104 + i, "submitblock": reply.get("result"),
                          "error": reply.get("error"), **c.state(a.hash)})
            prev = blk.sha256
        spent = n.call("gettxout", [f.hash, 0, False], "F:0 after the last block")
        return {"phase": name, "extra": extra, "names": {"F": f.hash, "T": t.hash, "A": a.hash},
                "steps": steps, "F0_unspent_at_end": spent.get("result") is not None}
    finally:
        n.stop()


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", required=True)
    ap.add_argument("--runs", required=True)
    args = ap.parse_args()
    runs = Path(args.runs).expanduser()
    runs.mkdir(parents=True, exist_ok=False)
    version_check()
    bt, mn = framework()
    log = []
    started = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
    projection = [phase("default", [], 4, runs, log, bt, mn),
                  phase("zero", ["softconsensusfreezeduration=0"], 5, runs, log, bt, mn)]
    out = {"tool": "tools/soft_freeze_probe.py", "pin": PIN, "binary": str(rpc_probe.RECORD).replace(os.environ["HOME"], "~"),
           "version": VERSION, "started_utc": started, "ended_utc": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
           "runs": str(runs).replace(os.environ["HOME"], "~"), "label": "[M]", "projection": projection, "calls": log}
    Path(args.out).write_text(json.dumps(out, indent=1) + "\n")
    for p in projection:
        print(p["phase"], [(s["submitted"], s["best"], s["A_confirmations"], (s["A_status"] or {}).get("soft consensus frozen"))
                           for s in p["steps"]], "F0 unspent at end:", p["F0_unspent_at_end"])


if __name__ == "__main__":
    main()
