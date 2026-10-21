#!/usr/bin/env python3
"""tools/cpp_era_chain.py (S3, lane cpp-era-49, 2026-10-06; #49's `txvalidationcache` rows at their own era): the reference's
unit-test fixture's chain on the lane's own SV-node instances, and the check that a corpus's coins are that chain's.

THE FIXTURE. `txvalidationcache_tests.cpp` runs on `TestChain100Setup` (`test/test_bitcoin.cpp:191–206`): a hundred regtest
blocks, each `CreateAndProcessBlock(no txns, scriptPubKey)` (`:208–237`) with the coinbase paying the fixture's key by P2PK
(`CScript() << ToByteVector(coinbaseKey.GetPubKey()) << OP_CHECKSIG`, `:195–196`). The coinbase of block h is the assembler's
template coinbase re-cut by `IncrementExtraNonce` (`rpc/mining.cpp:41–55`): the unlocking script `CScript() << nHeight <<
CScriptNum(nExtraNonce)` plus `COINBASE_FLAGS` (empty, `validation.cpp:117`), the extra nonce 1 in EVERY block (a fresh
`extraNonce = 0` per block, incremented once, `test_bitcoin.cpp:223–224`, `mining.cpp:50`), version 2 (the `coin_tx` the
corpus records), one output of the subsidy (50 BTC below regtest's halving at 150, `chainparams.cpp:1460`) to the P2PK,
sequence final, lock time 0. So the chain's txids are the fixture's, whatever the headers' times and nonces: the coinbase at
height 1 built here hashes to the outpoint the test's opening spend carries (`mine` checks it before a block is submitted).
`checkinputs_test` then puts its opening spend into block 101 (`txvalidationcache_tests.cpp:394`, the coinbase to the same
P2PK, the subsidy alone: the template was built on an empty mempool and the fee stays unclaimed), and the later calls
spend that transaction's outputs at height 101 under a tip at 101.

THE BLOCKS are assembled here and `submitblock`'d (header: version 0x20000000, the previous hash, the merkle root, the
time one above the previous block's (above the median of the past eleven), bits 0x207fffff (regtest, `chainparams.cpp:1511`),
the nonce ground until the hash meets the target); no `generate` call, whose coinbase would be the node's own and pay another
script. Every instance given receives the same blocks and must end on one best hash. Loopback RPC only (CLAUDE.md rule 10).

  mine  --pubkey <hex> --to <height> [--tx <hex> ...] [--coinbase1-txid <display hex>] --node <rpc url> <cookie path> [--node …]
  check --corpus <cases.jsonl[.gz]> --node <rpc url> <cookie path> [--node …]
        every distinct prevout of the corpus against each instance's UTXO set (`gettxout`): the script, the value, the height
        (the tip's minus the confirmations plus one) and the coinbase flag; a JSON summary per instance on stdout;
        exit 1 on a missing coin or any mismatch
"""
import base64
import decimal
import gzip
import hashlib
import json
import sys
import urllib.request

SUBSIDY = 50 * 100_000_000
REGTEST_BITS = 0x207FFFFF


def dsha(b):
    return hashlib.sha256(hashlib.sha256(b).digest()).digest()


def varint(n):
    if n < 0xFD:
        return bytes([n])
    if n <= 0xFFFF:
        return b"\xfd" + n.to_bytes(2, "little")
    if n <= 0xFFFFFFFF:
        return b"\xfe" + n.to_bytes(4, "little")
    return b"\xff" + n.to_bytes(8, "little")


def scriptnum(n):
    """`CScriptNum::serialize` (script_num.h): little-endian magnitude, the sign in the top bit of the last byte."""
    if n == 0:
        return b""
    neg, v, out = n < 0, abs(n), bytearray()
    while v:
        out.append(v & 0xFF)
        v >>= 8
    if out[-1] & 0x80:
        out.append(0x80 if neg else 0)
    elif neg:
        out[-1] |= 0x80
    return bytes(out)


def push_int(n):
    """`CScript& operator<<(int64_t)` (script.h): OP_0 for 0, OP_1NEGATE for -1, OP_1..OP_16, else a push of the number."""
    if n == 0:
        return b"\x00"
    if n == -1:
        return b"\x4f"
    if 1 <= n <= 16:
        return bytes([0x50 + n])
    return push_data(scriptnum(n))


def push_data(b):
    n = len(b)
    if n < 0x4C:
        return bytes([n]) + b
    if n <= 0xFF:
        return b"\x4c" + bytes([n]) + b
    if n <= 0xFFFF:
        return b"\x4d" + n.to_bytes(2, "little") + b
    return b"\x4e" + n.to_bytes(4, "little") + b


def coinbase_tx(height, pubkey):
    """The fixture's coinbase at `height` (the module docstring): version 2, `<height> <1>`, the subsidy to P2PK(pubkey)."""
    lock = push_data(pubkey) + b"\xac"
    script_sig = push_int(height) + push_data(scriptnum(1))
    return (b"\x02\x00\x00\x00" + b"\x01" + b"\x00" * 32 + b"\xff\xff\xff\xff" + varint(len(script_sig)) + script_sig + b"\xff\xff\xff\xff"
            + b"\x01" + SUBSIDY.to_bytes(8, "little") + varint(len(lock)) + lock + b"\x00\x00\x00\x00")


def merkle_root(txids):
    layer = list(txids)
    while len(layer) > 1:
        if len(layer) % 2:
            layer.append(layer[-1])
        layer = [dsha(layer[i] + layer[i + 1]) for i in range(0, len(layer), 2)]
    return layer[0]


def target_of(bits):
    exp, mant = bits >> 24, bits & 0xFFFFFF
    return mant << (8 * (exp - 3))


def build_block(prev_hash_display, time, txs):
    """The serialized block: a header that meets regtest's target over the given transactions (the coinbase first)."""
    root = merkle_root([dsha(t) for t in txs])
    prev = bytes.fromhex(prev_hash_display)[::-1]
    target = target_of(REGTEST_BITS)
    nonce = 0
    while True:
        header = (0x20000000).to_bytes(4, "little") + prev + root + time.to_bytes(4, "little") + REGTEST_BITS.to_bytes(4, "little") + nonce.to_bytes(4, "little")
        if int.from_bytes(dsha(header), "little") <= target:
            break
        nonce += 1
    return header + varint(len(txs)) + b"".join(txs), dsha(header)[::-1].hex()


class Node:
    def __init__(self, url, cookie_path):
        self.url = url
        with open(cookie_path) as f:
            self.auth = base64.b64encode(f.read().strip().encode()).decode()
        self.calls = 0

    def call(self, method, *params):
        req = urllib.request.Request(self.url, data=json.dumps({"jsonrpc": "1.0", "id": "cpp-era", "method": method, "params": list(params)}).encode(),
                                     headers={"Authorization": "Basic " + self.auth, "Content-Type": "application/json"})
        self.calls += 1
        try:
            with urllib.request.urlopen(req, timeout=120) as r:
                body = r.read()
        except urllib.error.HTTPError as e:
            body = e.read()
        j = json.loads(body, parse_float=decimal.Decimal)
        if j.get("error"):
            raise RuntimeError(f"{self.url} {method}: {j['error']}")
        return j["result"]


def parse_nodes(args):
    nodes = []
    i = 0
    rest = []
    while i < len(args):
        if args[i] == "--node":
            nodes.append(Node(args[i + 1], args[i + 2]))
            i += 3
        else:
            rest.append(args[i])
            i += 1
    if not nodes:
        sys.exit("cpp_era_chain: at least one --node <rpc url> <cookie path>")
    return nodes, rest


def opt(rest, name, many=False):
    vals = [rest[i + 1] for i, a in enumerate(rest) if a == name]
    if many:
        return vals
    return vals[0] if vals else None


def cmd_mine(args):
    nodes, rest = parse_nodes(args)
    pubkey = bytes.fromhex(opt(rest, "--pubkey"))
    to = int(opt(rest, "--to"))
    txs = [bytes.fromhex(h) for h in opt(rest, "--tx", many=True)]
    expect1 = opt(rest, "--coinbase1-txid")
    cb1 = dsha(coinbase_tx(1, pubkey))[::-1].hex()
    if expect1 and cb1 != expect1:
        sys.exit(f"cpp_era_chain: the coinbase at height 1 built here is {cb1}, the corpus's opening spend expects {expect1}: not the fixture's chain, nothing mined")
    heights = [n.call("getblockcount") for n in nodes]
    bests = [n.call("getbestblockhash") for n in nodes]
    if len(set(heights)) != 1 or len(set(bests)) != 1:
        sys.exit(f"cpp_era_chain: the instances disagree before mining: heights {heights}, best {bests}")
    h, best = heights[0], bests[0]
    if to <= h:
        print(json.dumps({"mined": 0, "height": h, "best": best, "coinbase1_txid": cb1}))
        return
    prev_time = nodes[0].call("getblockheader", best)["time"]
    mined = []
    for height in range(h + 1, to + 1):
        block_txs = [coinbase_tx(height, pubkey)] + (txs if height == to else [])
        raw, bhash = build_block(best, prev_time + 1, block_txs)
        for n in nodes:
            res = n.call("submitblock", raw.hex())
            if res is not None:
                sys.exit(f"cpp_era_chain: {n.url} refused block {height}: {res}")
        bests = [n.call("getbestblockhash") for n in nodes]
        if len(set(bests)) != 1 or bests[0] != bhash:
            sys.exit(f"cpp_era_chain: after block {height} the instances' best hashes are {bests}, the block's {bhash}")
        best, prev_time = bhash, prev_time + 1
        mined.append({"height": height, "hash": bhash, "txs": [dsha(t)[::-1].hex() for t in block_txs]})
    print(json.dumps({"mined": len(mined), "from": h + 1, "to": to, "best": best, "coinbase1_txid": cb1,
                      "pubkey": pubkey.hex(), "txs_in_last_block": mined[-1]["txs"] if mined else [], "first": mined[0] if mined else None, "last": mined[-1] if mined else None}))


def read_lines(path):
    op = gzip.open if path.endswith(".gz") else open
    with op(path, "rt") as f:
        for line in f:
            if line.strip():
                yield json.loads(line)


def cmd_check(args):
    nodes, rest = parse_nodes(args)
    corpus = opt(rest, "--corpus")
    want = {}
    entries = 0
    for e in read_lines(corpus):
        entries += 1
        for p in e["prevouts"]:
            want[(p["txid"], p["vout"])] = (p["script"], p["satoshis"], p["height"])
    ok_all = True
    out = {"corpus": corpus, "entries": entries, "distinct_prevouts": len(want), "instances": []}
    for n in nodes:
        tip = n.call("getblockcount")
        summary = {"rpc": n.url, "tip": tip, "ok": 0, "missing": [], "mismatch": [], "coinbase": 0, "heights": {}}
        for (txid, vout), (script, sats, height) in sorted(want.items()):
            r = n.call("gettxout", txid, vout, True)
            if r is None:
                summary["missing"].append(f"{txid}:{vout}")
                continue
            got_script = r["scriptPubKey"]["hex"]
            got_sats = int((r["value"] * 100_000_000).to_integral_value())
            got_height = tip - int(r["confirmations"]) + 1
            if got_script != script or got_sats != sats or got_height != height:
                summary["mismatch"].append({"prevout": f"{txid}:{vout}", "script": [script, got_script], "satoshis": [sats, got_sats], "height": [height, got_height]})
                continue
            summary["ok"] += 1
            summary["coinbase"] += 1 if r.get("coinbase") else 0
            summary["heights"][str(height)] = summary["heights"].get(str(height), 0) + 1
        if summary["missing"] or summary["mismatch"]:
            ok_all = False
        out["instances"].append(summary)
    print(json.dumps(out))
    sys.exit(0 if ok_all else 1)


if __name__ == "__main__":
    a = sys.argv[1:]
    if a[:1] == ["mine"]:
        cmd_mine(a[1:])
    elif a[:1] == ["check"]:
        cmd_check(a[1:])
    else:
        print(__doc__)
        sys.exit(2)
