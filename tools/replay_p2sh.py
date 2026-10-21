#!/usr/bin/env python3
"""The replay reading of #26 (carried from the C2 audit's S.G10 and #20's question): read one public mainnet block from
WhatsOnChain and list every input that spends a P2SH-shaped output (`OP_HASH160 <20 bytes> OP_EQUAL`, BIP16's template).

Why block 173,805: `GetBlockScriptFlags` sets SCRIPT_VERIFY_P2SH when `height >= consensus_params.p2shHeight`
(verify_script_flags.cpp:38-40 at the pin), `p2shHeight` is 173,805 on mainnet (chainparams.cpp:28, 1076), and the comment
above the test says "P2SH became active on Apr 1 2012, block height 173,805"; read with the height its callers pass, the code
enforces P2SH from 173,806 (#20). The two readings judge a block differently only if block 173,805 itself spends a P2SH-shaped
output: then that input is checked against the redeem script under one reading and against the hash alone under the other.
This tool answers whether such an input exists in real history. Reads only (CLAUDE.md rule 10: nothing is ever broadcast;
every run is recorded in docs/PROVENANCE.md §6); the output names public transactions of 2012, none of any private program.

Usage: tools/replay_p2sh.py [--height 173805] [--out <file.json>]
"""
import json, sys, time, urllib.request

API = "https://api.whatsonchain.com/v1/bsv/main"
cache, calls = {}, [0]


def get(path):
    for attempt in range(4):
        try:
            req = urllib.request.Request(API + path, headers={"User-Agent": "bsv-script-lean corpus read"})
            with urllib.request.urlopen(req, timeout=30) as r:
                calls[0] += 1
                return r.read().decode()
        except Exception:
            if attempt == 3:
                raise
            time.sleep(2 + 3 * attempt)
        finally:
            time.sleep(0.4)   # at most ~2.5 requests a second, under the service's free rate


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
        i += 4
        vin.append((prev, idx, ss))
    n, i = varint(b, i); vout = []
    for _ in range(n):
        val = int.from_bytes(b[i:i+8], "little"); i += 8
        l, i = varint(b, i); spk = b[i:i+l]; i += l
        vout.append((val, spk))
    return vin, vout


def raw(txid):
    if txid not in cache:
        cache[txid] = bytes.fromhex(get(f"/tx/{txid}/hex").strip())
    return cache[txid]


def p2sh_shaped(spk):
    return len(spk) == 23 and spk[0] == 0xa9 and spk[1] == 0x14 and spk[22] == 0x87


def main():
    args = sys.argv[1:]
    height = int(args[args.index("--height") + 1]) if "--height" in args else 173_805
    out = args[args.index("--out") + 1] if "--out" in args else None
    t0 = time.time()
    block = json.loads(get(f"/block/height/{height}"))
    txids = list(block.get("tx") or [])
    pages = block.get("pages") or {}
    for page in range(2, int((pages.get("size") or 1)) + 1 if isinstance(pages, dict) else 1):
        txids += json.loads(get(f"/block/hash/{block['hash']}/page/{page}"))
    assert len(txids) == block.get("txcount", len(txids)), (len(txids), block.get("txcount"))
    report = {"height": height, "hash": block["hash"], "time": block.get("time"), "txcount": len(txids), "inputs": 0,
              "p2sh_spends": [], "p2sh_outputs_created": 0}
    for n, txid in enumerate(txids):
        vin, vout = decode_tx(raw(txid))
        report["p2sh_outputs_created"] += sum(1 for _, spk in vout if p2sh_shaped(spk))
        if n == 0:
            continue   # the coinbase spends nothing
        for k, (prev, idx, ss) in enumerate(vin):
            report["inputs"] += 1
            _, pout = decode_tx(raw(prev))
            val, spk = pout[idx]
            if p2sh_shaped(spk):
                report["p2sh_spends"].append({"txid": txid, "vin": k, "prevout": f"{prev}:{idx}", "satoshis": val,
                                              "prevout_script": spk.hex(), "scriptSig": ss.hex()})
    report["requests"] = calls[0]
    report["wall_s"] = round(time.time() - t0, 1)
    report["verdict"] = ("the two readings DIFFER on real history: block %d spends P2SH-shaped outputs" % height
                         if report["p2sh_spends"] else
                         "no P2SH-shaped output is spent in block %d: the two readings judge real history alike" % height)
    text = json.dumps(report, indent=1)
    if out:
        open(out, "w").write(text + "\n")
    print(text)


if __name__ == "__main__":
    main()
