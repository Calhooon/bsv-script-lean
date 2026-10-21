#!/usr/bin/env python3
"""#61: deterministic source-derived UTXO boundaries, never node observations.

[SRC] bitcoin-sv v1.2.3, 6504a3aff65ba97c0f6c80962b033e35ecbfed4b:
src/validation.cpp:2480-2495,2552-2665,2667-2709,2864-2868,3326-3331,3421-3430;
src/coins.cpp:45-64,386-401,548-565; src/script/script.h:260-277;
src/frozentxo_db.cpp:614-717; src/consensus/consensus.h:71-79.
Expectations are chosen by the boundary table below, without calling Lean.
The P2PKH material is an existing public-read fixture; no network is used.
"""
from __future__ import annotations

from collections import Counter
from copy import deepcopy
import hashlib
import json
from pathlib import Path
import struct

ROOT = Path(__file__).resolve().parents[1]
PIN = "6504a3aff65ba97c0f6c80962b033e35ecbfed4b"
MAX = 21_000_000 * 100_000_000  # [SRC] src/amount.h:130-134 at the pin
MEMPOOL = 0x7FFFFFFF  # [SRC] src/protocol_era.h:14 at the pin
SOURCE = ("[SRC] src/validation.cpp:2480-2495,2552-2665,2667-2709,2864-2868,3326-3331,3421-3430; "
          "src/coins.cpp:45-64,386-401,548-565; src/script/script.h:260-277; "
          "src/frozentxo_db.cpp:614-717; src/consensus/consensus.h:71-79 at " + PIN)
FALSE = "blk-bad-inputs (Script evaluated without error but finished with a false/empty top stack element)"
RETURN = "blk-bad-inputs (OP_RETURN was encountered)"


def varint(n):
    if n < 253:
        return bytes([n])
    if n <= 0xFFFF:
        return b"\xfd" + struct.pack("<H", n)
    return b"\xfe" + struct.pack("<I", n)


def script(s):
    b = bytes.fromhex(s)
    return varint(len(b)) + b


def txhex(tx):
    b = struct.pack("<i", tx["version"]) + varint(len(tx["inputs"]))
    for i in tx["inputs"]:
        b += bytes.fromhex(i["hash"]) + struct.pack("<I", i["index"]) + script(i["script"])
        b += struct.pack("<I", i["sequence"])
    b += varint(len(tx["outputs"]))
    for o in tx["outputs"]:
        b += struct.pack("<Q", o["value"]) + script(o["script"])
    return (b + struct.pack("<I", tx["lockTime"])).hex()


def txid(tx):
    return hashlib.sha256(hashlib.sha256(bytes.fromhex(txhex(tx))).digest()).hexdigest()


def coin(n=1, value=10, locking="51", height=1, coinbase=False, confiscation=False):
    return dict(hash=f"{n:02x}" * 32, index=0, value=value, script=locking,
                height=height, isCoinbase=coinbase, isConfiscation=confiscation)


def txin(c, unlocking=""):
    return dict(hash=c["hash"], index=c["index"], script=unlocking, sequence=0xFFFFFFFF)


def base(name, family, coins=None, outputs=None):
    coins = deepcopy([coin()] if coins is None else coins)
    return dict(id=name, family=family, label="[D]", source=SOURCE, node="pending #66",
                scope="UTXO stage; caller supplies remaining transaction/block checks",
                kind="apply", utxo=coins,
                config=dict(coinbaseMaturity=100, confiscationMaturity=1000,
                            maxStackMemoryUsageConsensus=0, maxStackMemoryUsagePolicy=100_000_000,
                            maxScriptSizePolicy=100_000_000, maxTxFee=10_000_000),
                context=dict(network="regtest", genesisHeight=10, chronicleHeight=20,
                             height=1200, tipHeight=1199, onBlock=True, consensus=True,
                             blockWord=True, flags=None, now=0),
                frozen=dict(block=[], policy=[], whitelist=[]),
                transaction=dict(version=2, inputs=[txin(c) for c in coins],
                                 outputs=outputs or [dict(value=9, script="51")], lockTime=0))


def reject(row, reason, code=0x10):
    row["expected"] = dict(status="rejected", code=code, reason=reason)
    return row


def key(c):
    return c["hash"], c["index"]


def accept(row):
    """Derive the expected state from UpdateCoins/AddCoin, including undo loss."""
    tx = row["transaction"]
    cb = len(tx["inputs"]) == 1 and key(tx["inputs"][0]) == ("00" * 32, 0xFFFFFFFF)
    old = {key(c): c for c in row["utxo"]}
    spent = [] if cb else [deepcopy(old[key(i)]) for i in tx["inputs"]]
    state = deepcopy(old)
    for c in spent:
        state.pop(key(c))
    added = []
    ctx = row["context"]
    confiscation = tx["outputs"][0]["script"].startswith("006a0463667478")
    for index, o in enumerate(tx["outputs"]):
        sc = o["script"]
        prune = sc.startswith("006a") or (ctx["height"] < ctx["genesisHeight"] and
                                         (sc.startswith("6a") or len(sc) // 2 > 10000))
        if prune:
            continue
        c = dict(hash=txid(tx), index=index, value=o["value"], script=sc,
                 height=ctx["height"], isCoinbase=cb, isConfiscation=confiscation)
        state[key(c)] = c
        added.append(key(c))
    restored = deepcopy(state)
    for p in added:
        restored.pop(p)
    for c in reversed(spent):
        restored[key(c)] = c
    row["expected"] = dict(status="ok", fee=0 if cb else sum(c["value"] for c in spent) -
                           sum(o["value"] for o in tx["outputs"]),
                           state=list(state.values()), spent=spent, undoRestores=restored == old)
    return row


def rows():
    out = []
    def add(r):
        out.append(r)
    for name, stored in [("missing", []), ("spent", [coin(value=-1)])]:
        r = base("availability/" + name, "availability")
        r["utxo"] = stored
        add(reject(r, "bad-txns-inputs-missingorspent"))
        r = deepcopy(r); r["id"] += "-raw"; r["kind"] = "inputs"
        add(reject(r, "", 0))
    r = base("availability/precedes-frozen", "availability", [coin(), coin(2)])
    r["utxo"].pop(); r["frozen"]["block"] = [dict(hash="01"*32, index=0)]
    add(reject(r, "bad-txns-inputs-missingorspent"))
    for depth in [99, 100, 101]:
        r = base(f"coinbase/depth-{depth}", "coinbase-maturity", [coin(height=1200-depth, coinbase=True)])
        add(reject(r, "bad-txns-premature-spend-of-coinbase") if depth < 100 else accept(r))
    r = base("coinbase/future-height", "coinbase-maturity", [coin(height=1201, coinbase=True)])
    r["config"]["coinbaseMaturity"] = 0
    add(reject(r, "bad-txns-premature-spend-of-coinbase"))
    for depth in [1, 2]:
        r = base(f"coinbase/config-2-depth-{depth}", "coinbase-maturity", [coin(height=1200-depth, coinbase=True)])
        r["config"]["coinbaseMaturity"] = 2
        add(reject(r, "bad-txns-premature-spend-of-coinbase") if depth < 2 else accept(r))
    for depth in [999, 1000, 1001]:
        r = base(f"confiscation/depth-{depth}", "confiscation-maturity", [coin(height=1200-depth, confiscation=True)])
        add(reject(r, "bad-txns-premature-spend-of-confiscation") if depth < 1000 else accept(r))
    for depth in [1, 2]:
        r = base(f"confiscation/config-2-depth-{depth}", "confiscation-maturity", [coin(height=1200-depth, confiscation=True)])
        r["config"]["confiscationMaturity"] = 2
        add(reject(r, "bad-txns-premature-spend-of-confiscation") if depth < 2 else accept(r))
    for block in [True, False]:
        r = base(f"frozen/{'block' if block else 'admission'}", "frozen")
        r["context"]["onBlock"] = block
        r["frozen"]["block" if block else "policy"] = [dict(hash="01"*32, index=0)]
        add(reject(r, "bad-txns-inputs-frozen", 0x13 if block else 0x10))
    r = base("frozen/policy-only-block", "frozen")
    r["frozen"]["policy"] = [dict(hash="01"*32, index=0)]
    add(accept(r))
    r = base("order/frozen-before-maturity-value", "ordering", [coin(value=MAX+1, height=1200, coinbase=True)])
    r["frozen"]["block"] = [dict(hash="01"*32, index=0)]
    add(reject(r, "bad-txns-inputs-frozen", 0x13))
    r = base("order/coinbase-before-confiscation", "ordering", [coin(value=MAX+1, height=1200, coinbase=True, confiscation=True)])
    add(reject(r, "bad-txns-premature-spend-of-coinbase"))
    r = base("order/earlier-value-before-later-frozen", "ordering", [coin(value=MAX+1), coin(2)])
    r["frozen"]["block"] = [dict(hash="02"*32, index=0)]
    add(reject(r, "bad-txns-inputvalues-outofrange"))
    for value in [0, 1, MAX-1, MAX, MAX+1, -2]:
        r = base(f"value/input-{value}", "value", [coin(value=value)], [dict(value=0, script="51")])
        add(reject(r, "bad-txns-inputvalues-outofrange") if value < 0 or value > MAX else accept(r))
    for total in [MAX, MAX+1]:
        r = base(f"value/aggregate-{total}", "value", [coin(value=MAX-1), coin(2,value=total-MAX+1)],
                 [dict(value=0, script="51")])
        add(accept(r) if total == MAX else reject(r, "bad-txns-inputvalues-outofrange"))
    r = base("value/equal-max-values", "value", [coin(value=MAX)], [dict(value=MAX, script="51")])
    add(accept(r))
    r = base("value/below-output", "value", outputs=[dict(value=11, script="51")])
    add(reject(r, "bad-txns-in-belowout"))
    for value, reason in [(MAX+1,"bad-txns-vout-toolarge"), (2**64-1,"bad-txns-vout-negative")]:
        add(reject(base(f"structure/output-{value}", "structure", outputs=[dict(value=value,script="51")]), reason))
    r = base("structure/duplicate-input", "structure")
    r["transaction"]["inputs"] *= 2
    add(reject(r, "bad-txns-inputs-duplicate"))
    r = base("fee/policy-ceiling-ignored", "fee", [coin(value=MAX)], [dict(value=0,script="51")])
    r["config"]["maxTxFee"] = 1
    add(accept(r))
    for name, vi, vo, reason in [
        ("zero",0,0,None), ("one",1,0,None), ("max-minus-one",MAX-1,0,None),
        ("max",MAX,0,None), ("max-plus-one",MAX+1,0,"bad-txns-fee-outofrange"),
        ("below-out",1,2,"bad-txns-in-belowout"), ("negative-input",-1,0,"bad-txns-in-belowout"),
        ("equal-max",MAX,MAX,None), ("subtract",123,100,None)]:
        r = base("fee-stage/"+name, "fee-stage")
        r.update(kind="fee", valueIn=vi, valueOut=vo,
                 scope="isolated #60 fee stage; out-of-range inputs cannot reach it through checkTxInputs")
        r["expected"] = dict(status="ok", fee=vi-vo) if reason is None else dict(status="rejected",code=0x10,reason=reason)
        add(r)
    for height in [9, 10, 20]:
        for name, locking in [("return","6a"),("false-return","006a"),("true","51")]:
            r = base(f"outputs/{name}-height-{height}", "outputs", outputs=[dict(value=9,script=locking)])
            r["context"].update(height=height, tipHeight=height-1)
            add(accept(r))
    for height in [9,10]:
        r = base(f"outputs/oversized-height-{height}", "outputs", outputs=[dict(value=9,script="61"*10001)])
        r["context"].update(height=height,tipHeight=height-1)
        add(accept(r))
    r = base("outputs/mempool-stored-height", "outputs", outputs=[dict(value=9,script="6a")])
    r["context"].update(height=MEMPOOL, tipHeight=8)
    add(accept(r))
    for height in [9,10,20]:
        r = base(f"coinbase-add/height-{height}", "coinbase-add", outputs=[dict(value=50,script="51"),dict(value=0,script="006a"),dict(value=1,script="6a")])
        r["transaction"]["inputs"] = [dict(hash="00"*32,index=0xFFFFFFFF,script="0101",sequence=0xFFFFFFFF)]
        r["context"].update(height=height,tipHeight=height-1)
        add(accept(r))
    r = base("coinbase-add/overwrite-undo-loss", "overwrite", outputs=[dict(value=50,script="51")])
    r["transaction"]["inputs"] = [dict(hash="00"*32,index=0xFFFFFFFF,script="0101",sequence=0xFFFFFFFF)]
    old = coin(value=12); old.update(hash=txid(r["transaction"]),height=100)
    r["utxo"].append(old)
    add(accept(r))
    r = base("overwrite/regular-precondition", "overwrite")
    old = coin(2,value=12); old.update(hash=txid(r["transaction"]))
    r["utxo"].append(old)
    add(reject(r, "Adding new coin that replaces non-pruned entry", 0))
    for name, locking, unlock, reason in [("true","51","",None), ("false","00","",FALSE),
        ("number-equal","5287","52",None),("number-unequal","5287","53",FALSE)]:
        r = base("scripts/"+name, "scripts", [coin(locking=locking,height=10)])
        r["transaction"]["inputs"][0]["script"] = unlock
        add(accept(r) if reason is None else reject(r,reason))
    for height in [9,10,20,MEMPOOL]:
        r = base(f"scripts/return-coin-height-{height}", "coin-era", [coin(locking="6a",height=height)])
        r["transaction"]["inputs"][0]["script"] = "51"
        add(reject(r,RETURN) if height == 9 else accept(r))
    r = base("scripts/mempool-tip-before-genesis", "coin-era", [coin(locking="6a",height=MEMPOOL)])
    r["context"]["tipHeight"] = 8
    r["transaction"]["inputs"][0]["script"] = "51"
    add(reject(r,RETURN))
    for consensus in [True,False]:
        r = base(f"scripts/resource-selector-{consensus}", "script-params", [coin(locking="51",height=10)])
        r["config"]["maxScriptSizePolicy"] = 0 + 1
        r["transaction"]["inputs"][0]["script"] = "5151"
        r["context"]["consensus"] = consensus
        add(accept(r) if consensus else reject(r,"blk-bad-inputs (Script is too big)"))
    for flag in [0, 1 << 7]:
        r = base(f"scripts/explicit-word-{flag}", "script-params", [coin(locking="b051",height=10)])
        r["context"]["flags"] = flag
        add(accept(r) if flag == 0 else reject(r,"blk-bad-inputs (NOPx reserved for soft-fork upgrades)"))
    # Whitelisted confiscation skips a deliberately false input script.
    cftx = "006a04636674781501" + "00"*20
    for name, locking, whitelist, reason in [
        ("invalid-contents","006a0463667478",False,"bad-ctx-invalid"),
        ("not-whitelisted",cftx,False,"bad-ctx-not-whitelisted"),
        ("whitelisted-bypass",cftx,True,None)]:
        r = base("confiscation-tx/"+name,"confiscation-tx",[coin(locking="00")],
                 [dict(value=0,script=locking),dict(value=9,script="51")])
        r["frozen"]["block"] = [dict(hash="01"*32,index=0)]
        if whitelist:
            r["frozen"]["whitelist"] = [txid(r["transaction"])]
        add(accept(r) if reason is None else reject(r,reason))
    # Existing mainnet public read: one real P2PKH input, legacy SIGHASH_ALL.
    fixture = json.loads((ROOT/"corpus/sighash/mainnet.jsonl").read_text().splitlines()[0])
    raw = bytes.fromhex(fixture["tx"])
    c = coin(value=fixture["prevout"]["satoshis"],locking=fixture["prevout"]["script"],height=399999)
    c.update(hash=bytes.fromhex(fixture["prevout"]["txid"])[::-1].hex(),index=fixture["prevout"]["vout"])
    unlock_len = raw[41]; unlock = raw[42:42+unlock_len].hex()
    pos = 42 + unlock_len + 4 + 1
    value = int.from_bytes(raw[pos:pos+8],"little"); size = raw[pos+8]
    locking = raw[pos+9:pos+9+size].hex()
    r = base("scripts/real-p2pkh", "p2pkh", [c], [dict(value=value,script=locking)])
    r["transaction"].update(version=1)
    r["transaction"]["inputs"][0]["script"] = unlock
    r["context"].update(network="mainnet", genesisHeight=620538,chronicleHeight=943816,height=400000,tipHeight=399999)
    r["material"] = dict(path="corpus/sighash/mainnet.jsonl",txid=fixture["txid"],read=fixture["read"])
    assert txhex(r["transaction"]) == fixture["tx"]
    add(accept(r))
    r = deepcopy(r)
    # Legacy sighash does not commit the amount; use a changed signature byte as the negative control.
    r["id"] = "scripts/real-p2pkh-bad-signature"
    u = bytearray.fromhex(r["transaction"]["inputs"][0]["script"]); u[10] ^= 1
    r["transaction"]["inputs"][0]["script"] = u.hex()
    add(reject(r,FALSE))
    return out


def main():
    data = rows()
    assert len({r["id"] for r in data}) == len(data)
    for r in data:
        r["tx"] = txhex(r.pop("transaction"))
    path = ROOT / "corpus/chain/utxo/utxo.jsonl"
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("".join(json.dumps(r,sort_keys=True,separators=(",",":"))+"\n" for r in data))
    counts = Counter(r["family"] for r in data)
    print(f"utxo_cases: {len(data)} derived rows; " + "; ".join(f"{k}={v}" for k,v in sorted(counts.items())))
    print("utxo_cases: sha256 " + hashlib.sha256(path.read_bytes()).hexdigest())


if __name__ == "__main__":
    main()
