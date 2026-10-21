#!/usr/bin/env python3
"""Read public mainnet transactions as corpus material (CLAUDE.md rule 10: reads
only, nothing is ever broadcast; every run is recorded in docs/PROVENANCE.md §6).

Given transaction ids, fetch each raw transaction and the raw transaction of
every prevout from WhatsOnChain, decode the prevout's script and satoshis from
the raw bytes (never from a float), and emit one JSONL entry per input whose
scriptSig is a P2PKH unlock (<sig> <pubkey>): the fields the sighash check needs
(`lean/Test/SighashCheck.lean`) and the signature the verifier checks
(`harness/src/bin/sighash_verify.rs`).

Usage: tools/mainnet_read.py <height:txid> ... > corpus/sighash/mainnet.jsonl
"""
import json, sys, time, urllib.request

API = "https://api.whatsonchain.com/v1/bsv/main"

def get(path):
    req = urllib.request.Request(API + path, headers={"User-Agent": "bsv-script-lean corpus read"})
    with urllib.request.urlopen(req, timeout=30) as r:
        return r.read().decode()

def varint(b, i):
    n = b[i]
    if n < 0xfd: return n, i + 1
    if n == 0xfd: return int.from_bytes(b[i+1:i+3], "little"), i + 3
    if n == 0xfe: return int.from_bytes(b[i+1:i+5], "little"), i + 5
    return int.from_bytes(b[i+1:i+9], "little"), i + 9

def decode_tx(b):
    i = 4
    n, i = varint(b, i); vin = []
    for _ in range(n):
        prev = b[i:i+32][::-1].hex(); idx = int.from_bytes(b[i+32:i+36], "little"); i += 36
        l, i = varint(b, i); ss = b[i:i+l]; i += l
        seq = int.from_bytes(b[i:i+4], "little"); i += 4
        vin.append((prev, idx, ss, seq))
    n, i = varint(b, i); vout = []
    for _ in range(n):
        val = int.from_bytes(b[i:i+8], "little"); i += 8
        l, i = varint(b, i); spk = b[i:i+l]; i += l
        vout.append((val, spk))
    return vin, vout

def pushes(ss):
    """Parse a scriptSig as a sequence of direct pushes; None if anything else."""
    out = []; i = 0
    while i < len(ss):
        op = ss[i]
        if 1 <= op <= 0x4b: n, i = op, i + 1
        elif op == 0x4c: n, i = ss[i+1], i + 2
        else: return None
        out.append(ss[i:i+n]); i += n
    return out if i == len(ss) else None

cache = {}
def raw(txid):
    if txid not in cache:
        cache[txid] = bytes.fromhex(get(f"/tx/{txid}/hex").strip()); time.sleep(0.4)
    return cache[txid]

for arg in sys.argv[1:]:
    height, txid = arg.split(":")
    tx = raw(txid); vin, vout = decode_tx(tx)
    for n, (prev, idx, ss, seq) in enumerate(vin):
        p = pushes(ss)
        if p is None or len(p) != 2 or not (70 <= len(p[0]) <= 73) or len(p[1]) not in (33, 65): continue
        pvin, pvout = decode_tx(raw(prev)); val, spk = pvout[idx]
        if not (len(spk) == 25 and spk[0] == 0x76 and spk[1] == 0xa9 and spk[2] == 0x14 and spk[-2:] == b"\x88\xac"): continue
        print(json.dumps({"txid": txid, "height": int(height), "input": n, "tx": tx.hex(),
                          "prevout": {"txid": prev, "vout": idx, "script": spk.hex(), "satoshis": val},
                          "sig": p[0].hex(), "pubkey": p[1].hex(), "sighash_type": p[0][-1],
                          "read": "WhatsOnChain /tx/{txid}/hex, " + time.strftime("%Y-%m-%dT%H:%MZ", time.gmtime())}))
