#!/usr/bin/env python3
"""Replay the #144 witness as shared signer rows; no network or node process.

Read the witness JSON and crypto corpus from lane/xsig-144. Write converted rows,
adapter output and a comparison receipt only to the explicitly supplied --out.
The independent ALL|FORKID serializer below is scoped to that witness's spends.
"""

import argparse
from collections import Counter
import hashlib
import json
from pathlib import Path
import subprocess


def sha256d(data):
    return hashlib.sha256(hashlib.sha256(data).digest()).digest()


def varint(n):
    if n < 253:
        return bytes([n])
    size, prefix = (2, 253) if n <= 65535 else (4, 254)
    return bytes([prefix]) + n.to_bytes(size, "little")


class Reader:
    def __init__(self, data):
        self.data = data
        self.pos = 0

    def take(self, n):
        value = self.data[self.pos:self.pos + n]
        assert len(value) == n
        self.pos += n
        return value

    def count(self):
        n = self.take(1)[0]
        return int.from_bytes(self.take({253: 2, 254: 4, 255: 8}[n]), "little") if n >= 253 else n

    def push(self):
        n = self.take(1)[0]
        if n >= 76:
            n = int.from_bytes(self.take({76: 1, 77: 2, 78: 4}[n]), "little")
        return self.take(n)


def transaction_parts(raw):
    r = Reader(raw)
    version = r.take(4)
    assert r.count() == 1, "the development witness has one input per spend"
    outpoint = r.take(36)
    unlock = r.take(r.count())
    sequence = r.take(4)
    tail = r.pos
    for _ in range(r.count()):
        r.take(8)
        r.take(r.count())
    outputs = raw[tail:r.pos]
    locktime = r.take(4)
    assert r.pos == len(raw)
    unsigned = version + b"\x01" + outpoint + b"\x00" + sequence + outputs + locktime
    return version, outpoint, unlock, sequence, outputs, locktime, unsigned


def preimage(parts, scriptcode, satoshis):
    version, outpoint, _, sequence, outputs, locktime, _ = parts
    r = Reader(outputs)
    r.count()
    return (version + sha256d(outpoint) + sha256d(sequence) + outpoint
            + varint(len(scriptcode)) + scriptcode + satoshis.to_bytes(8, "little")
            + sequence + sha256d(outputs[r.pos:]) + locktime + b"\x41\x00\x00\x00")


def testkey(label):
    # The key recipe recorded in #144, with the secp256k1 group order.
    order = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141
    d = int.from_bytes(hashlib.sha256(("xsig-144/" + label).encode()).digest(), "big") % order
    return d.to_bytes(32, "big").hex()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--signer", required=True, type=Path)
    parser.add_argument("--witness", required=True, type=Path)
    parser.add_argument("--corpus", required=True, type=Path)
    parser.add_argument("--out", required=True, type=Path)
    args = parser.parse_args()
    witness = json.loads(args.witness.read_text())
    originals = {row["tx"]: row for row in map(json.loads, args.corpus.read_text().splitlines())}
    rows, expected = [], {}
    pub_utxo = next(s["coin"]["script"][2:-2] for s in witness["spends"] if s["shape"] == "A")
    for spend in witness["spends"]:
        if spend["era"] != "post-chronicle":
            continue
        original = originals[spend["tx"]]
        parts = transaction_parts(bytes.fromhex(spend["tx"]))
        version, _, unlock, sequence, _, locktime, unsigned = parts
        code, lock = spend["script_code"], spend["coin"]["script"]
        r = Reader(unlock)
        r.push()  # the funding-key signature, replaced by <sig1>
        if spend["shape"] == "A":
            r.push()
            assert r.take(1) == b"\xab"
            pub = r.push().hex()
            assert r.take(1) == b"\xad" and r.pos == len(unlock)
            key = testkey("secret0")
            pattern = "<sig1><sig0>ab<pub0>ad"
        else:
            assert r.push().hex() == pub_utxo
            pushed_preimage = r.push()
            # Preserve the witness's entire in-script signing program verbatim.
            pattern = "<sig1><pub1><preimage0>" + unlock[r.pos:].hex()
            pub = "0279be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798"
            key = (1).to_bytes(32, "big").hex()
            selected = lock if spend["method"].startswith(("a:", "b:")) else code
            assert pushed_preimage == preimage(parts, bytes.fromhex(selected), spend["coin"]["satoshis"])
        row = {k: original[k] for k in ("id", "family", "rule", "prevouts", "params")}
        row.update(tx=unsigned.hex(), expect={}, signing={
            "version": int.from_bytes(version, "little"), "locktime": int.from_bytes(locktime, "little"),
            "inputs": [{"index": 0, "template": "checksig-in-unlock-" + spend["shape"].lower(),
                        "privkeys": [key, testkey("utxo")], "pubkeys": [pub, pub_utxo],
                        "sighash_type": 65, "sequence": int.from_bytes(sequence, "little"),
                        "scriptcode_hex": [code, lock], "sig_sites": [0, 1], "unlock_template": pattern}]})
        rows.append(row)
        expected[row["id"]] = (spend, parts)
    assert len(rows) == 8
    args.out.mkdir(parents=True, exist_ok=True)
    corpus_file = args.out / "xsig-144-signer.jsonl"
    output_file = args.out / "gosdk-signer.jsonl"
    corpus_file.write_text("".join(json.dumps(row, separators=(",", ":")) + "\n" for row in rows))
    command = [str(args.signer.resolve()), "--corpus", str(corpus_file), "--out", str(output_file)]
    subprocess.run(command, check=True)
    measured = output_file.read_bytes()
    repeat = subprocess.check_output([str(args.signer.resolve()), "--corpus", str(corpus_file)])
    assert measured == repeat, "adapter output changed on repeat"
    results = [json.loads(line) for line in measured.splitlines()]
    assert len(results) == 24
    receipt, counts = [], Counter()
    for result in results:
        spend, parts = expected[result["id"]]
        method = result["method"]
        counts[(method, "signed" if result["tx_hex"] else "null")] += 1
        if method == "template":
            assert result["tx_hex"] is None and "no public" in result["note"]
            continue
        assert result["tx_hex"] is not None, result["note"]
        codes = [spend["script_code"], spend["coin"]["script"]]
        if method == "api-default":
            codes[0] = codes[1]
        assert len(result["inputs"]) == len(codes)
        for site, code in zip(result["inputs"], codes):
            raw = preimage(parts, bytes.fromhex(code), spend["coin"]["satoshis"])
            assert site["preimage_hex"] == raw.hex()
            assert site["digest_hex"] == sha256d(raw).hex()
            assert site["scriptcode_used_hex"] == code
        reference_method = "api-default" if spend["method"].startswith(("a:", "b:")) else "api-scriptcode"
        if method == reference_method:
            assert result["tx_hex"] == spend["tx"], "signed witness transaction differs byte for byte"
        receipt.append({"id": result["id"], "shape": spend["shape"], "method": method,
                        "digest_hex": result["inputs"][0]["digest_hex"], "preimages_equal": True,
                        "reference_tx_equal": method == reference_method,
                        "reference_verdict": spend["reference_submit"]["verdict"] if method == reference_method else None})
    summary = {"checks": receipt, "repeat_equal": True,
               "counts": {m: {k: counts[(m, k)] for k in ("signed", "null")} for m in ("template", "api-default", "api-scriptcode")}}
    (args.out / "selfcheck.json").write_text(json.dumps(summary, indent=2) + "\n")
    for row in receipt:
        if row["reference_tx_equal"]:
            print(f"[M] {row['id']} shape {row['shape']} {row['method']} {row['reference_verdict']}: {row['digest_hex']}")
    print("[M] gosdk-signer self-check: GREEN; 8 exact witness transactions, 32 preimages, repeat identical")
    print("[M] counts: " + json.dumps(summary["counts"], sort_keys=True))


if __name__ == "__main__":
    main()
