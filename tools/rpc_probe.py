#!/usr/bin/env python3
"""[D] 2026-10-15, lane rpc-85 (#85): the RPC contract's probe on fresh regtest instances.

Drives the reference node of record (`~/bsv/targets/sv-v1.2.3/bin/bitcoind`) and its wallet build
(`~/bsv/targets/sv-v1.2.3-wallet/bin/bitcoind`) on owned instances whose RPC/P2P pair is the lowest free
pair in 18571..18590 (the runner's band, harness/src/scenarios/core.rs), every instance stopped by `stop`
and waited for. The base configuration is harness/oracle/scenarios.conf (regtest, txindex, loopback, no
peers); each phase adds its own lines. Nothing reaches a peer and nothing is broadcast (CLAUDE.md rule 10).

Six phases, each on its own instance: `wallet` (the wallet build: a key, the wallet handlers), `record`
(every handler of corpus/rpc/contract.json with an answer and one error each), `named` (getmerkleproof2's
named arguments), `safemode` (`-testsafemode=1`), `prune` (`-prune=1`, small block files, past regtest's
PruneAfterHeight) and `mocktime` (the scenario clock and the wall clock side by side).

Output: `--out <file>.json` gets every call (phase, method, params, HTTP status, the reply object as
the node wrote it, or the bytes on the socket when it is not one JSON reply) and every launch's configuration;
`--replies <file>.json` gets the replay projection for harness/tests/rpc_contract.rs (every success reply
of a handler of corpus/rpc/contract.json called with positional arguments, keyed by method). Exit 0 when every phase ran to its end, else 1 with the phase named.

Usage: tools/rpc_probe.py --out docs/records/<stamp>-s7-85-rpc-contract-s4b.json --replies corpus/rpc/replies.json
"""
import argparse
import base64
import http.client
import json
import os
from pathlib import Path
import socket
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parent.parent
HOME = Path(os.environ["HOME"])
RECORD = HOME / "bsv/targets/sv-v1.2.3/bin/bitcoind"
WALLET = HOME / "bsv/targets/sv-v1.2.3-wallet/bin/bitcoind"
T0 = 1_700_000_000
ZERO = "00" * 32


def free_pair():
    for port in range(18571, 18590):
        socks = []
        try:
            for p in (port, port + 1):
                s = socket.socket()
                s.bind(("127.0.0.1", p))
                socks.append(s)
            return port
        except OSError:
            continue
        finally:
            for s in socks:
                s.close()
    raise SystemExit("no free RPC/P2P pair in 18571..18590")


class Node:
    def __init__(self, phase, binary, runs, extra, log):
        self.phase, self.log = phase, log
        self.port = free_pair()
        self.dir = runs / phase
        self.dir.mkdir(parents=True, exist_ok=False)
        base = (ROOT / "harness/oracle/scenarios.conf").read_text()
        conf = f"{base}\nrpcport={self.port}\nport={self.port + 1}\nexcessiveblocksize=1000000000\n" + "".join(f"{x}\n" for x in extra)
        (self.dir / "bitcoin.conf").write_text(conf)
        self.proc = subprocess.Popen(
            [str(binary), f"-datadir={self.dir}", f"-conf={self.dir / 'bitcoin.conf'}"],
            stdout=open(self.dir / "console.log", "w"), stderr=open(self.dir / "bitcoind.err", "w"))
        log.append({"phase": phase, "launch": str(binary).replace(str(HOME), "~"), "rpcport": self.port, "extra": extra})
        cookie = self.dir / "regtest/.cookie"
        for _ in range(600):
            if self.proc.poll() is not None:
                raise SystemExit(f"{phase}: bitcoind exited {self.proc.returncode}: {(self.dir / 'bitcoind.err').read_text()[-400:]}")
            if cookie.exists():
                self.auth = base64.b64encode(cookie.read_bytes().strip()).decode()
                status, reply = self.raw("getblockcount", [])
                if status == 200:
                    return
            time.sleep(0.1)
        raise SystemExit(f"{phase}: RPC not ready")

    def raw(self, method, params):
        conn = http.client.HTTPConnection("127.0.0.1", self.port, timeout=120)
        body = json.dumps({"jsonrpc": "1.0", "id": "rpc-85", "method": method, "params": params})
        try:
            conn.request("POST", "/", body, {"Authorization": "Basic " + self.auth, "Content-Type": "application/json"})
            resp = conn.getresponse()
            text = resp.read().decode("utf-8", "replace")
        except (OSError, http.client.HTTPException) as e:
            return None, {"transport": str(e)}
        finally:
            conn.close()
        try:
            return resp.status, json.loads(text)
        except ValueError:
            return resp.status, {"unparsed_body": text[:2000]}

    def socket_read(self, method, params, note=""):
        """The bytes the node writes for one request, read until it closes or 10 s pass (a body cut short by the node)."""
        body = json.dumps({"jsonrpc": "1.0", "id": "rpc-85", "method": method, "params": params}).encode()
        head = (f"POST / HTTP/1.1\r\nHost: 127.0.0.1\r\nAuthorization: Basic {self.auth}\r\n"
                f"Content-Type: application/json\r\nContent-Length: {len(body)}\r\nConnection: close\r\n\r\n").encode()
        got = b""
        with socket.create_connection(("127.0.0.1", self.port), timeout=10) as s:
            s.sendall(head + body)
            try:
                while chunk := s.recv(65536):
                    got += chunk
            except OSError as e:
                got += f"<socket: {e}>".encode()
        text = got.decode("utf-8", "replace")
        status = int(text.split(" ", 2)[1]) if text.startswith("HTTP/1.1 ") else None
        self.log.append({"phase": self.phase, "method": method, "params": params, "http": status,
                         "reply": {"socket_bytes": text[:4000], "socket_length": len(got)}, "note": note})

    def call(self, method, params, note=""):
        status, reply = self.raw(method, params)
        self.log.append({"phase": self.phase, "method": method, "params": params, "http": status, "reply": reply, "note": note})
        return reply

    def ok(self, method, params, note=""):
        reply = self.call(method, params, note)
        if not isinstance(reply, dict) or reply.get("error") is not None or "result" not in reply:
            raise SystemExit(f"{self.phase}: {method} {params}: {reply}")
        return reply["result"]

    def stop(self):
        if self.proc.poll() is None:
            self.call("stop", [])
            try:
                self.proc.wait(timeout=120)
            except subprocess.TimeoutExpired:
                self.proc.terminate()
                self.proc.wait(timeout=30)
        self.log.append({"phase": self.phase, "stopped": self.proc.returncode})


def spend(n, coinbase, addr, wif, value, prev_script):
    raw = n.ok("createrawtransaction", [[{"txid": coinbase, "vout": 0}], {addr: value}])
    signed = n.ok("signrawtransaction", [raw, [{"txid": coinbase, "vout": 0, "scriptPubKey": prev_script, "amount": 50}], [wif], "ALL|FORKID"])
    if not signed.get("complete"):
        raise SystemExit(f"{n.phase}: signing incomplete: {signed}")
    return signed["hex"]


def wallet_phase(runs, log):
    n = Node("wallet", WALLET, runs, [], log)
    try:
        addr = n.ok("getnewaddress", [])
        wif = n.ok("dumpprivkey", [addr])
        n.ok("getwalletinfo", [])
        n.ok("validateaddress", [addr])
        n.call("validateaddress", ["not-an-address"], "an invalid address is a result, not an error")
        n.ok("setmocktime", [T0])
        hashes = n.ok("generatetoaddress", [101, addr])
        block = n.ok("getblock", [hashes[0], 1])
        n.ok("gettransaction", [block["tx"][0]])
        n.call("gettransaction", [ZERO], "an unknown txid")
        n.ok("getreceivedbyaddress", [addr, 0])
        n.call("getreceivedbyaddress", ["not-an-address"], "an invalid address")
    finally:
        n.stop()
    return addr, wif


def record_phase(runs, log, addr, wif):
    n = Node("record", RECORD, runs, [], log)
    try:
        n.ok("setmocktime", [T0])
        hashes = n.ok("generatetoaddress", [110, addr])
        n.ok("getblockcount", [])
        n.ok("getbestblockhash", [])
        h1 = n.ok("getblockhash", [1])
        n.call("getblockhash", [-1], "below range")
        n.call("getblockhash", [100000], "above range")
        n.call("getblockhash", ["1"], "a string height")
        for v in (0, 1, 2, 3):
            n.ok("getblock", [h1, v])
        n.call("getblock", [ZERO, 1], "an unknown hash")
        n.call("getblock", [h1, 4], "verbosity out of range")
        n.ok("getblockbyheight", [1, 1])
        for v in (0, 1, 2):
            n.ok("getblockheader", [h1, v])
        n.call("getblockheader", [ZERO], "an unknown hash")
        cb1 = n.ok("getblock", [h1, 1])["tx"][0]
        n.ok("getrawtransaction", [cb1, 0])
        n.ok("getrawtransaction", [cb1, 1])
        n.call("getrawtransaction", [cb1, "yes"], "a verbose that is neither number nor boolean")
        n.call("getrawtransaction", [ZERO, 1], "an unknown txid")
        coin = n.ok("gettxout", [cb1, 0])
        n.call("gettxout", [cb1, 1], "an absent output: null result")
        tx = spend(n, cb1, addr, wif, 49.999, coin["scriptPubKey"]["hex"])
        txid = n.ok("sendrawtransaction", [tx])
        n.call("sendrawtransaction", [tx], "the same transaction again")
        n.call("sendrawtransaction", ["00"], "undecodable")
        n.call("sendrawtransaction", [1], "a number where hex is due")
        cb2 = n.ok("getblock", [hashes[1], 1])["tx"][0]
        coin2 = n.ok("gettxout", [cb2, 0])
        tx2 = spend(n, cb2, addr, wif, 49.998, coin2["scriptPubKey"]["hex"])
        n.ok("sendrawtransactions", [[{"hex": tx2}, {"hex": tx}]])
        n.ok("getrawmempool", [False])
        n.ok("getrawmempool", [True])
        n.ok("getrawnonfinalmempool", [])
        n.ok("getmempoolinfo", [])
        n.ok("getorphaninfo", [])
        n.ok("waitforptvcompletion", [])
        n.ok("getblockchainactivity", [])
        n.ok("prioritisetransaction", [txid, 0, 1000])
        n.call("prioritisetransaction", [txid, 1, 1000], "a non-zero dummy")
        n.ok("gettxout", [txid, 0])
        n.ok("gettxout", [txid, 0, False])
        n.ok("verifyscript", [[{"tx": tx, "n": 0}]])
        n.call("verifyscript", [[{"tx": "00", "n": 0}]], "undecodable")
        mined = n.ok("generatetoaddress", [1, addr])[0]
        proof = n.ok("getmerkleproof", [txid])
        n.ok("getmerkleproof", [txid, mined])
        n.call("getmerkleproof", [ZERO], "an unknown txid")
        n.ok("getmerkleproof2", ["", txid])
        n.ok("getmerkleproof2", [mined, txid, True, "merkleroot"])
        n.call("getmerkleproof2", [mined, txid, False, "nonsense"], "an unknown target type")
        n.ok("verifymerkleproof", [proof])
        n.call("verifymerkleproof", [None], "a null proof")
        n.ok("getchaintxstats", [])
        n.call("getchaintxstats", [1000], "a window past the chain")
        n.ok("getnetworkinfo", [])
        n.ok("getpeerinfo", [])
        n.ok("getsafemodeinfo", [])
        tip = n.ok("getbestblockhash", [])
        n.call("ignoresafemodeforblock", [tip], "a block on the main chain")
        n.call("reconsidersafemodeforblock", [ZERO], "an unknown block")
        n.ok("invalidateblock", [tip])
        n.ok("getchaintips", [])
        n.call("ignoresafemodeforblock", [tip], "a block off the main chain")
        n.call("reconsidersafemodeforblock", [tip], "a block off the main chain")
        n.ok("reconsiderblock", [tip])
        n.call("invalidateblock", [ZERO], "an unknown hash")
        n.ok("preciousblock", [tip])
        n.ok("softrejectblock", [tip, 0])
        n.ok("getchaintips", [])
        n.ok("acceptblock", [tip])
        n.call("acceptblock", [tip], "a block not soft rejected")
        n.call("softrejectblock", [tip, -1], "a negative count")
        n.ok("getblockcount", [])
        n.ok("verifychain", [1, 5])
        n.ok("gettxoutsetinfo", [])
        n.call("pruneblockchain", [10], "not in prune mode")
        fund = {"txOut": {"txId": cb2, "vout": 0}}
        n.ok("addToPolicyBlacklist", [{"funds": [fund]}])
        n.ok("addToPolicyBlacklist", [{"funds": [fund]}])
        n.ok("addToConsensusBlacklist", [{"funds": [dict(fund, enforceAtHeight=[{"start": 0}], policyExpiresWithConsensus=False)]}])
        n.ok("queryBlacklist", [])
        n.call("addToPolicyBlacklist", [{"funds": [{"txOut": {"txId": cb2}}]}], "a fund without vout")
        n.ok("addToConfiscationTxidWhitelist", [{"confiscationTxs": [{"confiscationTx": {"enforceAtHeight": 1, "hex": tx}}]}])
        n.ok("queryConfiscationTxidWhitelist", [])
        n.ok("queryConfiscationTxidWhitelist", [True])
        raw_tip = n.ok("getblock", [tip, 0])
        n.call("submitblock", [raw_tip], "a block the node holds")
        n.call("submitblock", ["00"], "undecodable")
        n.call("getblockcount", [1], "too many arguments: the help text")
        n.call("nosuchmethod", [], "an unregistered method")
        n.call("getwalletinfo", [], "a wallet handler on the node of record")
    finally:
        n.stop()


def named_phase(runs, log, addr, wif):
    n = Node("named", RECORD, runs, [], log)
    try:
        n.ok("setmocktime", [T0])
        h1 = n.ok("generatetoaddress", [101, addr])[0]
        cb = n.ok("getblock", [h1, 1])["tx"][0]
        n.call("getmerkleproof", [cb, h1], "the only transaction of a one-transaction block")
        n.call("getmerkleproof2", [h1, cb], "the same, positional")
        coin = n.ok("gettxout", [cb, 0])
        txid = n.ok("sendrawtransaction", [spend(n, cb, addr, wif, 49.999, coin["scriptPubKey"]["hex"])])
        h = n.ok("generatetoaddress", [1, addr])[0]
        n.call("getmerkleproof2", [h, txid], "positional: blockhash then txid")
        n.call("getmerkleproof2", {"txid": txid, "blockhash": h}, "named, the registration's names")
        n.call("getmerkleproof2", {"txid": h, "blockhash": txid}, "named, the names swapped")
        n.call("getblockhash", {"height": 1}, "named, a one-argument handler")
    finally:
        n.stop()


def safemode_phase(runs, log, addr):
    n = Node("safemode", RECORD, runs, ["testsafemode=1"], log)
    try:
        n.call("setmocktime", [T0])
        n.call("generatetoaddress", [1, addr])
        n.call("getblockcount", [])
        n.call("getsafemodeinfo", [])
        n.call("getrawmempool", [])
        n.call("sendrawtransaction", ["00"], "okSafeMode false")
        n.call("sendrawtransactions", [[{"hex": "00"}]], "okSafeMode false")
        n.call("getnetworkinfo", [])
    finally:
        n.stop()


def prune_phase(runs, log, addr):
    n = Node("prune", RECORD, runs, ["prune=1", "preferredblockfilesize=4096"], log)
    try:
        n.ok("setmocktime", [T0])
        n.ok("generatetoaddress", [10, addr])
        n.call("pruneblockchain", [5], "below PruneAfterHeight")
        n.call("pruneblockchain", [-1], "a negative height")
        n.ok("generatetoaddress", [1290, addr])
        n.call("pruneblockchain", [5000], "above the tip")
        h5 = n.ok("getblockhash", [5])
        before = n.ok("getblockheader", [h5, 1])
        cb5 = n.ok("getblock", [h5, 1])["tx"][0]
        n.call("pruneblockchain", [1100], "inside the kept window: clamped to tip - 288")
        n.call("getblockheader", [h5, 1], "after pruning")
        n.call("getblockheader", [h5, 2], "the extended header after pruning")
        n.call("getblock", [h5, 1], "a pruned block, decoded")
        n.socket_read("getblock", [h5, 0], "a pruned block, raw: the bytes on the socket")
        n.call("getblockcount", [], "the instance answers after the pruned read")
        n.call("getrawtransaction", [cb5, 1], "a transaction in a pruned block")
        n.call("gettxout", [cb5, 0], "the pruned block's coin")
        n.call("getmerkleproof", [cb5, h5], "a proof in a pruned block")
        n.call("getchaintips", [])
        log.append({"phase": "prune", "status_before": before.get("status")})
    finally:
        n.stop()


def mocktime_phase(runs, log, addr):
    n = Node("mocktime", RECORD, runs, [], log)
    try:
        n.ok("setmocktime", [T0])
        h = n.ok("generatetoaddress", [1, addr])[0]
        n.ok("getblockheader", [h, 1])
        n.ok("getsafemodeinfo", [], "timeutc beside the mock clock")
        n.ok("setmocktime", [T0 + 86400])
        h = n.ok("generatetoaddress", [1, addr])[0]
        n.ok("getblockheader", [h, 1])
        n.ok("getnetworkinfo", [], "timeoffset")
        n.ok("setmocktime", [0])
        h = n.ok("generatetoaddress", [1, addr])[0]
        n.ok("getblockheader", [h, 1], "the wall clock again")
        n.call("setmocktime", ["x"], "a string timestamp")
    finally:
        n.stop()


def replies(log):
    """The replay projection: every success reply of a contract handler called with positional arguments, by method."""
    handlers = {h["method"] for h in json.loads((ROOT / "corpus/rpc/contract.json").read_text())["handlers"]}
    out = {}
    for c in log:
        r = c.get("reply")
        if c.get("method") in handlers and isinstance(c.get("params"), list) and isinstance(r, dict) and "result" in r and r.get("error") is None:
            out.setdefault(c["method"], []).append({"phase": c["phase"], "params": c["params"], "result": r["result"]})
    return dict(sorted(out.items()))


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--out", required=True)
    ap.add_argument("--replies", required=True)
    ap.add_argument("--runs", default=str(ROOT / ".lane-src/probe-runs"))
    a = ap.parse_args()
    runs = Path(a.runs) / time.strftime("%Y%m%d-%H%M%S", time.gmtime())
    runs.mkdir(parents=True)
    log = [{"date_utc": time.strftime("%Y-%m-%d %H:%M:%S", time.gmtime()), "label": "[X]", "load_1m": os.getloadavg()[0],
            "commit": subprocess.run(["git", "rev-parse", "HEAD"], cwd=ROOT, capture_output=True, text=True).stdout.strip()}]
    phase = "wallet"
    try:
        addr, wif = wallet_phase(runs, log)
        log.append({"phase": "wallet", "key": "a fresh regtest key of the wallet build, never funded outside this run"})
        for phase, fn in (("record", lambda: record_phase(runs, log, addr, wif)), ("named", lambda: named_phase(runs, log, addr, wif)),
                          ("safemode", lambda: safemode_phase(runs, log, addr)), ("prune", lambda: prune_phase(runs, log, addr)),
                          ("mocktime", lambda: mocktime_phase(runs, log, addr))):
            fn()
        status = 0
    except SystemExit as e:
        log.append({"phase": phase, "stopped_early": str(e)})
        print(f"rpc_probe: phase {phase} stopped: {e}", file=sys.stderr)
        status = 1
    for c in log:
        if c.get("method") == "dumpprivkey":
            c["reply"] = {"result": "<redacted: a regtest key>", "error": None, "id": "rpc-85"}
        if c.get("method") == "signrawtransaction":
            c["params"] = [c["params"][0], c["params"][1], ["<redacted>"], c["params"][3]]
    Path(a.out).write_text(json.dumps(log, indent=1) + "\n")
    Path(a.replies).parent.mkdir(parents=True, exist_ok=True)
    Path(a.replies).write_text(json.dumps(replies(log), indent=1, sort_keys=True) + "\n")
    print(f"rpc_probe: {sum(1 for c in log if 'method' in c)} calls over {sum(1 for c in log if 'launch' in c)} instances; exit {status}")
    return status


if __name__ == "__main__":
    sys.exit(main())
