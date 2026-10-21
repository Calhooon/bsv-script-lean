#!/usr/bin/env python3
"""Select #63 header windows from publicly read WhatsOnChain byte archives.

The cache contains the named archives, woc-info.json and reads.jsonl request
receipts. No network operation is performed here. Source expectations [M]
are the observed chain's own nBits; Lean computes its answer independently.
Archive documentation: https://docs.taal.com/core-products/whatsonchain/block
"""
import argparse
import hashlib
import json
from pathlib import Path
import struct


def hash256(raw):
    return hashlib.sha256(hashlib.sha256(raw).digest()).digest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--cache", type=Path, required=True)
    parser.add_argument("--out", type=Path, default=Path("corpus/chain/headers/mainnet.jsonl"))
    args = parser.parse_args()
    receipts = [json.loads(line) for line in (args.cache / "reads.jsonl").read_text().splitlines()]
    info = json.loads((args.cache / "woc-info.json").read_text())
    archives = [(0, 10000), (500001, 510000), (610001, 620000), (620001, 630000)]
    data = {}
    for start, end in archives:
        name = f"{start}_{end}_headers.bin"
        raw = (args.cache / name).read_bytes()
        assert len(raw) == (end - start + 1) * 80
        receipt = next(r for r in receipts if r["url"].endswith("/" + name) and r.get("status") == "200")
        for height in range(start, end + 1):
            data[height] = (raw[(height-start)*80:(height-start+1)*80], receipt)
    raw = (args.cache / "latest").read_bytes()
    assert len(raw) % 80 == 0
    # Bind this archive to the independently read chain-info tip hash.
    assert hash256(raw[-80:])[::-1].hex() == info["bestblockhash"]
    end = info["blocks"]
    start = end - len(raw) // 80 + 1
    receipt = next(r for r in receipts if r["url"].endswith("/headers/latest") and r.get("status") == "200")
    for height in range(start, end + 1):
        data[height] = (raw[(height-start)*80:(height-start+1)*80], receipt)
    # [D] 2016 = the pinned 1209600 / 600 interval, centered at each activation.
    windows = [("genesis", 0, 0), ("daa", 504031-1008, 504031+1007),
               ("genesis-activation", 620538-1008, 620538+1007), ("recent", end-199, end)]
    rows = []
    for group, lo, hi in windows:
        previous = None
        for height in range(lo, hi + 1):
            header, receipt = data[height]
            if previous is not None:
                assert header[4:36] == hash256(previous)
            previous = header
            rows.append(dict(id=f"mainnet/{height}", group=group, height=height,
                header=header.hex(), hash=hash256(header)[::-1].hex(), label="[M]",
                source=receipt["url"], requestedAt=receipt["time"],
                expected=dict(proofOfWork=True, nextBits=struct.unpack_from("<I", header, 72)[0]),
                difficultyScope="compare own nBits when the window supplies required ancestry"))
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text("".join(json.dumps(r, separators=(",", ":")) + "\n" for r in rows))
    print(f"block_headers: {len(rows)} measured headers; " + "; ".join(f"{g}={lo}..{hi}" for g,lo,hi in windows))


if __name__ == "__main__":
    main()
