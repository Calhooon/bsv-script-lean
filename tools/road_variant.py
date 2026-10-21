#!/usr/bin/env python3
"""tools/road_variant.py: THE SCRIPT FAMILIES AS FUNDED TRANSACTIONS (S3, set 4 sitting 3, 2026-09-27; the spec's direction
audit, the plan's docs/c4/wave-read-spec-2026-09-27.md (C) item 1, LANE F's item (c)).

`run_svnode` passes `verifyscript` the flag word the spec's own `Params.derive` produced, so on the script corpora the node
never derives the spend's word itself; the block road (`run_svnode --mode tx`, `harness/src/txroad.rs`) makes it derive the
word, by block-connect on the block instance and by `sendrawtransaction` on the policy instance. This tool writes the ROAD
VARIANT of the script corpora, `corpus/road/road.jsonl`, for that road:

  * every entry of the eight script corpora whose spend is after Chronicle and whose every coin is after Chronicle (the
    road's chain starts from a base snapshot at 600,000; an earlier coin cannot be funded on it; Chronicle at 943,816,
    mainnet's, the height the road probes);
  * the same transaction, scripts, amounts and `params`; every coin's `height` set to `spend_height - 1` (the road funds a
    coin strictly below the block that spends it; `txroad.rs`'s funding contract), the id prefixed `road-`, no `expect` keys
    (the spec, the engines and the node record their own);
  * not an entry with a P2SH-shaped coin (`OP_HASH160 <20 bytes> OP_EQUAL`, 23 bytes): after Genesis a transaction may
    not create such an output (`validation.cpp:613–621` at the pin, `bad-txns-vout-p2sh`, REJECT_INVALID), so no
    post-Genesis chain holds the coin and the road cannot fund it (UNFUNDABLE; the first run of 2026-09-27 found it);
  * not an entry with a coin whose lock begins `OP_FALSE OP_RETURN`: after Genesis the node's one provably unspendable
    output (`script.h:258–275`), never added to its UTXO set (`coins.cpp:61–65`), so the road cannot fund it either
    (UNSPENDABLE; package B's third start of 2026-09-28 found it: `bad-txns-inputs-missingorspent`, `Missing inputs`);
  * ONLY the entries whose spec verdict (both columns) is unchanged when every input's outpoint is rewritten (the road
    rewrites the outpoints to its funding outputs at run time: an entry carrying a real signature over its synthetic
    outpoint is DIGEST-BOUND and is left out, named in the scratch list, for a road that re-signs).

The spec decides both variants through the worktree's own evaluator (`eval/bsvs corpus`), so the tool runs where the
evaluator is built (the Studio, under the Lean lock if it must build). Deterministic: the same corpora give the same file.

  python3 tools/road_variant.py [--out corpus/road] [--scratch DIR]
"""
import hashlib, json, os, subprocess, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CHRONICLE = 943_816          # mainnet's Chronicle activation height (the road probes it through `verifyscript`)
SOURCES = ["seed/seed", "flow/flow", "arith/cases", "stack/cases", "crypto/cases", "bytes/cases", "eras/eras", "gen/gen"]


def arg(name, default):
    a = sys.argv[1:]
    return a[a.index(name) + 1] if name in a else default


def varint(buf, i):
    x = buf[i]
    if x < 0xfd: return x, i + 1
    if x == 0xfd: return int.from_bytes(buf[i + 1:i + 3], "little"), i + 3
    if x == 0xfe: return int.from_bytes(buf[i + 1:i + 5], "little"), i + 5
    return int.from_bytes(buf[i + 1:i + 9], "little"), i + 9


def p2sh_shaped(script_hex):
    s = bytes.fromhex(script_hex)
    return len(s) == 23 and s[0] == 0xa9 and s[1] == 0x14 and s[22] == 0x87


def unspendable(script_hex):
    """OP_FALSE OP_RETURN: after Genesis the node's one provably unspendable output (script.h:258-275), never added to its
    UTXO set (coins.cpp:61-65), so the road cannot fund it (package B's third start, 2026-09-28: bad-txns-inputs-missingorspent)."""
    s = bytes.fromhex(script_hex)
    return len(s) > 1 and s[0] == 0x00 and s[1] == 0x6a


def rewritten(entry):
    """The same entry with every non-null input outpoint replaced by a different synthetic one (tx and prevouts alike)."""
    e = json.loads(json.dumps(entry))
    tx = bytearray(bytes.fromhex(e["tx"]))
    i = 4
    nin, i = varint(tx, i)
    for k in range(nin):
        old = bytes(tx[i:i + 32]); vout = int.from_bytes(tx[i + 32:i + 36], "little")
        if old != b"\x00" * 32:
            new = hashlib.sha256(b"road-rewrite-" + e["id"].encode() + bytes([k])).digest()
            tx[i:i + 32] = new
            for p in e["prevouts"]:
                if bytes.fromhex(p["txid"])[::-1] == old and p.get("vout") == vout:
                    p["txid"] = new[::-1].hex()
        i += 36
        sl, i = varint(tx, i)
        i += sl + 4
    e["tx"] = bytes(tx).hex()
    return e


def spec_of(path, out):
    r = subprocess.run([os.path.join(ROOT, "eval", "bsvs"), "corpus", path, "--out", out], capture_output=True, text=True)
    if r.returncode != 0:
        sys.exit(f"road_variant: eval/bsvs corpus {path} failed: {r.stderr.strip()[-600:]}")
    return {j["id"]: j for j in map(json.loads, open(out))}


def main():
    out_dir = os.path.join(ROOT, arg("--out", "corpus/road"))
    scratch = arg("--scratch", os.path.join(ROOT, "lean", ".lake", "road-variant"))
    os.makedirs(out_dir, exist_ok=True); os.makedirs(scratch, exist_ok=True)
    cand, skipped, sources = [], {"pre-chronicle spend or coin": 0, "unfundable after Genesis": 0, "unspendable coin": 0}, {}
    for c in SOURCES:
        p = os.path.join(ROOT, "corpus", c + ".jsonl")
        sources[c] = hashlib.sha256(open(p, "rb").read()).hexdigest()
        for l in open(p):
            if not l.strip(): continue
            e = json.loads(l)
            sh = e["params"]["spend_height"]
            if sh <= CHRONICLE or any((q.get("height") or 0) < CHRONICLE for q in e.get("prevouts", [])):
                skipped["pre-chronicle spend or coin"] += 1
                continue
            if any(p2sh_shaped(q.get("script", "")) for q in e.get("prevouts", [])):
                skipped["unfundable after Genesis"] += 1
                continue
            if any(unspendable(q.get("script", "")) for q in e.get("prevouts", [])):
                skipped["unspendable coin"] += 1
                continue
            v = {k: e[k] for k in e if k != "expect"}
            v["id"] = "road-" + e["id"]
            v["prevouts"] = [dict(q, height=sh - 1) for q in e.get("prevouts", [])]
            v["expect"] = {}
            cand.append((c, v))
    pa, pb = os.path.join(scratch, "a.jsonl"), os.path.join(scratch, "b.jsonl")
    with open(pa, "w") as fa, open(pb, "w") as fb:
        for _, v in cand:
            fa.write(json.dumps(v, separators=(",", ":")) + "\n")
            fb.write(json.dumps(rewritten(v), separators=(",", ":")) + "\n")
    A = spec_of(pa, os.path.join(scratch, "spec-a.jsonl"))
    B = spec_of(pb, os.path.join(scratch, "spec-b.jsonl"))
    vc = lambda x: (x.get("verdict"), x.get("code"))
    kept, bound, per_source = [], [], {}
    for c, v in cand:
        a, b = A[v["id"]], B[v["id"]]
        if vc(a["spec"]) == vc(b["spec"]) and vc(a["spec-mempool"]) == vc(b["spec-mempool"]):
            kept.append(v); per_source[c] = per_source.get(c, 0) + 1
        else:
            bound.append(v["id"])
    body = "".join(json.dumps(v, separators=(",", ":")) + "\n" for v in kept)
    open(os.path.join(out_dir, "road.jsonl"), "w").write(body)
    fams, rules = {}, {}
    for v in kept:
        fams[v.get("family", "?")] = fams.get(v.get("family", "?"), 0) + 1
        rules[v.get("rule", "?")] = rules.get(v.get("rule", "?"), 0) + 1
    srcs = ", ".join(f"{c.split('/')[0]} {h[:16]}" for c, h in sources.items())
    manifest = {
        # the fields of harness/src/corpus.rs's Manifest, exactly (a runner that records rewrites the file from them)
        "corpus": "road",
        "file": "road.jsonl",
        "generator": "tools/road_variant.py (#27; the direction audit's (C) item 1; S3, 2026-09-27): the script corpora's post-Chronicle entries as funded transactions for the block road",
        "seed": "derived",
        "count": len(kept),
        "sha256": hashlib.sha256(body.encode()).hexdigest(),
        "families": dict(sorted(fams.items())),
        "rules": dict(sorted(rules.items())),
        "verdicts": {},
        "implementations": [],
        "engine_executions": 0,
        "generated": os.environ.get("SOURCE_DATE", "2026-09-27"),
        "provenance": ("derived from the eight script corpora (sha256 at derivation: " + srcs + "): each entry whose spend and every coin "
                       "are after Chronicle, the same transaction, scripts and params, every coin at spend_height - 1 (the road funds a "
                       "coin strictly below its spend), the id prefixed road-, no expect keys; ONLY the entries whose spec verdict, both "
                       "columns, is unchanged when every input's outpoint is rewritten (the road rewrites them to its funding outputs at "
                       f"run time); left out: {skipped['pre-chronicle spend or coin']} with a pre-Chronicle spend or coin, {skipped['unfundable after Genesis']} "
                       f"with a P2SH-shaped coin no post-Genesis chain can hold (validation.cpp:613-621, bad-txns-vout-p2sh), {skipped['unspendable coin']} "
                       "whose coin is provably unspendable after Genesis, OP_FALSE OP_RETURN (script.h:258-275; the node never adds it to "
                       f"its UTXO set, coins.cpp:61-65), {len(bound)} "
                       "digest-bound (a real signature over the synthetic outpoint; their ids in the road's record); every outpoint "
                       "synthetic; no transaction of any private program"),
    }
    open(os.path.join(out_dir, "manifest.json"), "w").write(json.dumps(manifest, indent=2) + "\n")
    open(os.path.join(scratch, "digest-bound.txt"), "w").write("\n".join(bound) + "\n")
    print(f"road_variant: {len(kept)} entries to {os.path.relpath(out_dir, ROOT)}/road.jsonl (sha256 {manifest['sha256'][:16]}…); "
          f"left out: {skipped['pre-chronicle spend or coin']} pre-Chronicle, {skipped['unfundable after Genesis']} unfundable after Genesis, {skipped['unspendable coin']} unspendable, {len(bound)} digest-bound (their ids in "
          f"{os.path.relpath(os.path.join(scratch, 'digest-bound.txt'), ROOT)})")


if __name__ == "__main__":
    main()
