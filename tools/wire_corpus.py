#!/usr/bin/env python3
"""The wire-view corpus of #86 (lane wire-86, 2026-10-15): mainnet-derived EF, BEEF, BUMP,
Atomic BEEF and TSC files, READ ONLY (CLAUDE.md rule 10: public reads, nothing is ever broadcast).

Two phases:
  tools/wire_corpus.py fetch [--cache DIR]   public GETs from WhatsOnChain, each response kept in
                                             the cache with its URL, UTC time, HTTP status and sha256
  tools/wire_corpus.py build [--cache DIR]   offline: writes corpus/wire/<format>.jsonl and
                                             corpus/wire/reads.jsonl from the cache, deterministically
  tools/wire_corpus.py check                 the five files and the read log agree with a fresh build

A row is [M] when its bytes are a response body as read (a WhatsOnChain BUMP or BEEF), and [D] when it
is derived from read bodies by a named construction (an EF from a transaction and its parents' outputs,
an Atomic BEEF from a BEEF and its subject, a binary TSC proof from the JSON proof and the block header,
a degenerate shape from a mainnet row by a named mutation). Every row names the reads it rests on.
"""
import argparse, hashlib, json, os, sys, time, urllib.error, urllib.request

API = "https://api.whatsonchain.com/v1/bsv/main"
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "corpus", "wire")
DEFAULT_CACHE = os.path.join(ROOT, "scratch", "wire86-cache")

# The subjects: display-order txids, chosen across eras and tree shapes (a lone coinbase, a coinbase,
# the last position of an odd level, small early blocks, a 1,037-transaction block, recent blocks).
SUBJECTS = [
    "0e3e2357e806b6cdb1f70b54c3a3a17b6714ee1f0e68bebb44a74b1efd512098",  # block 1, the lone transaction
    "f4184fc596403b9d638783cf57adfe4c75c605f6356fbc91338530e9831e9e16",  # block 170, index 1
    "8c14f0db3df150123e6f3dbbf30f8b955a8249b62ac1d1ff16284aefa3d06d87",  # block 100000, the coinbase
    "fff2525b8931402dd09222c50775608f75787bd2b87e56995a7bdd30f79702c4",  # block 100000, index 1
    "6359f0868171b1d194cbee1af2f16ea598ae8fad666d9b012c8ed2b79a236ec4",  # block 100000, index 2
    "e9a66845e05d5abc0ad04ec80f774a7e585c6e8db975962d069a522137b80c1d",  # block 100000, index 3
    "74d681e0e03bafa802c8aa084379aa98d9fcd632ddc2ed9782b586ec87451f20",  # block 100002, index 8 of 9
    "aa4e1965c95cdd060205544aa047ffb7c41906eb46818a7f4fb6f6340e35efdf",  # block 900000, the coinbase
    "52854619b1c2e78d6c1e9a91fdb14c4bef1b8d1897de3253a538e152bd055be6",  # block 900000, index 1
    "05705ea0c2276d6708263f2b3cf8b8cecf01c7ff07adc392bbcdc899b85d409a",  # block 900000, index 2
    "ebc7b84c8eeb38e94c026d1ecbdb6fe3a25d3e77a3eca92f7db038c70a118239",  # block 900000, index 3
    "bff56bfa34d481a4fb2d95abc3c2c4832c58817fcbd01388c4842266e84b8b8d",  # block 900000, index 4
    "81e2ca36feb2a77a9514cdff8cb946b5ae48d1c1016648fe65b9c2b417901a6e",  # block 900000, index 5
]
# Blocks whose opening page of txids adds subjects (a pre-Genesis block of 2017 and a recent one).
SUBJECT_BLOCKS = [(500000, 4), (971000, 5)]
MAX_EF_INPUTS = 24


class Cache:
    """The response cache: one JSON record per URL path with the body as text."""

    def __init__(self, path):
        self.path = path
        os.makedirs(path, exist_ok=True)

    def file(self, rel):
        return os.path.join(self.path, hashlib.sha256(rel.encode()).hexdigest()[:24] + ".json")

    def get(self, rel):
        f = self.file(rel)
        if not os.path.exists(f):
            return None
        with open(f) as fh:
            return json.load(fh)

    def fetch(self, rel):
        hit = self.get(rel)
        if hit is not None:
            return hit
        url = API + rel
        for attempt in range(5):
            stamp = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
            req = urllib.request.Request(url, headers={"User-Agent": "bsv-script-lean corpus read (#86)"})
            try:
                with urllib.request.urlopen(req, timeout=60) as r:
                    status, body = r.status, r.read()
            except urllib.error.HTTPError as e:
                status, body = e.code, e.read()
            if status == 429:
                time.sleep(2 + 2 * attempt)
                continue
            break
        rec = {"url": url, "utc": stamp, "status": status, "bytes": len(body),
               "sha256": hashlib.sha256(body).hexdigest(), "body": body.decode("utf-8", "replace")}
        with open(self.file(rel), "w") as fh:
            json.dump(rec, fh)
        time.sleep(0.45)
        return rec


class Reader:
    """A cursor over raw bytes: the transaction grammar of BRC-12."""

    def __init__(self, b):
        self.b, self.i = b, 0

    def take(self, n):
        out = self.b[self.i:self.i + n]
        self.i += n
        return out

    def varint(self):
        head = self.take(1)[0]
        width = {0xfd: 2, 0xfe: 4, 0xff: 8}.get(head)
        return head if width is None else int.from_bytes(self.take(width), "little")

    def tx(self):
        version = self.take(4)
        ins = [(self.take(32), int.from_bytes(self.take(4), "little"), self.take(self.varint()), self.take(4))
               for _ in range(self.varint())]
        outs = [(int.from_bytes(self.take(8), "little"), self.take(self.varint())) for _ in range(self.varint())]
        return version, ins, outs, self.take(4)


def cs(n):
    """CompactSize, the canonical writer."""
    if n < 0xfd:
        return bytes([n])
    if n <= 0xffff:
        return b"\xfd" + n.to_bytes(2, "little")
    if n <= 0xffffffff:
        return b"\xfe" + n.to_bytes(4, "little")
    return b"\xff" + n.to_bytes(8, "little")


def dsha(b):
    return hashlib.sha256(hashlib.sha256(b).digest()).digest()


def subjects(cache):
    out = list(SUBJECTS)
    for height, count in SUBJECT_BLOCKS:
        rec = cache.fetch(f"/block/height/{height}")
        if rec["status"] == 200:
            txids = json.loads(rec["body"]).get("tx", [])
            out += [t for t in txids[1:count + 1] if t not in out]
    return out


def fetch(cache):
    for s in subjects(cache):
        for rel in (f"/tx/{s}/hex", f"/tx/hash/{s}", f"/tx/{s}/proof/bump", f"/tx/{s}/beef", f"/tx/{s}/proof/tsc"):
            cache.fetch(rel)
        info = json.loads(cache.fetch(f"/tx/hash/{s}")["body"])
        cache.fetch(f"/block/{info['blockhash']}/header")
        raw = bytes.fromhex(cache.fetch(f"/tx/{s}/hex")["body"].strip())
        _, ins, _, _ = Reader(raw).tx()
        if any(p == bytes(32) for p, *_ in ins) or len(ins) > MAX_EF_INPUTS:
            continue
        for prev, *_ in ins:
            parent = prev[::-1].hex()
            cache.fetch(f"/tx/{parent}/hex")
            cache.fetch(f"/tx/{parent}/proof/bump")
            cache.fetch(f"/tx/hash/{parent}")
    print(f"wire_corpus: fetch done, cache {cache.path}")


# ---------------------------------------------------------------- build (offline)

class Rows:
    """The rows of one format and the reads they cite."""

    def __init__(self, fmt, cache, reads):
        self.fmt, self.cache, self.reads, self.rows = fmt, cache, reads, []

    def cite(self, rel):
        rec = self.cache.get(rel)
        if rec is None:
            raise SystemExit(f"wire_corpus: {rel} is not in the cache; run fetch")
        key = {k: rec[k] for k in ("url", "utc", "status", "bytes", "sha256")}
        self.reads[rec["url"]] = key
        return rec

    def add(self, shape, data, label, reads, derivation, **extra):
        rid = f"{self.fmt}-{len(self.rows) + 1:03d}"
        row = {"id": rid, "format": self.fmt, "shape": shape, "label": label, "hex": data.hex(),
               "reads": sorted({self.cache.get(r)["url"] for r in reads}), "derivation": derivation}
        row.update(extra)
        self.rows.append(row)
        return rid


def body_hex(rec):
    return bytes.fromhex(rec["body"].strip().strip('"'))


def header_bytes(rec):
    h = json.loads(rec["body"])
    h = h[0] if isinstance(h, list) else h
    return (h["version"].to_bytes(4, "little") + bytes.fromhex(h["previousblockhash"])[::-1]
            + bytes.fromhex(h["merkleroot"])[::-1] + h["time"].to_bytes(4, "little")
            + bytes.fromhex(h["bits"])[::-1] + h["nonce"].to_bytes(4, "little"))


def ef_of(raw, parents):
    """BRC-30 EF from a raw transaction and its parents' raw bytes: the 8-byte value width the engines use."""
    version, ins, outs, lock = Reader(raw).tx()
    body = version + bytes.fromhex("0000000000ef") + cs(len(ins))
    for prev, idx, script, seq in ins:
        value, spk = Reader(parents[prev[::-1].hex()]).tx()[2][idx]
        body += prev + idx.to_bytes(4, "little") + cs(len(script)) + script + seq
        body += value.to_bytes(8, "little") + cs(len(spk)) + spk
    body += cs(len(outs)) + b"".join(v.to_bytes(8, "little") + cs(len(s)) + s for v, s in outs)
    return body + lock


def tsc_binary(proof, raw, header, full_tx, target_kind):
    """The TSC binary form (#75's codec) from WhatsOnChain's JSON proof: flags, index, txOrId, target, nodes."""
    flags = (1 if full_tx else 0) | (target_kind << 1)
    out = bytes([flags]) + cs(proof["index"])
    out += cs(len(raw)) + raw if full_tx else bytes.fromhex(proof["txOrId"])[::-1]
    out += {0: bytes.fromhex(proof["target"])[::-1], 1: header, 2: header[36:68]}[target_kind]
    nodes = proof["nodes"] or []  # WhatsOnChain answers `null` for a lone transaction (block 1)
    out += cs(len(nodes))
    for n in nodes:
        out += b"\x01" if n == "*" else b"\x00" + bytes.fromhex(n)[::-1]
    return out


def build(cache):
    reads = {}
    fmts = {f: Rows(f, cache, reads) for f in ("ef", "bump", "beef", "atomic-beef", "tsc")}
    subs = subjects(cache)
    mined = []
    for s in subs:
        raw = body_hex(fmts["bump"].cite(f"/tx/{s}/hex"))
        info = json.loads(fmts["bump"].cite(f"/tx/hash/{s}")["body"])
        bump_rec = fmts["bump"].cite(f"/tx/{s}/proof/bump")
        beef_rec = fmts["beef"].cite(f"/tx/{s}/beef")
        mined.append((s, raw, info, bump_rec, beef_rec))
    ef_rows(fmts["ef"], mined)
    bump_rows(fmts["bump"], mined)
    beef_rows(fmts["beef"], mined)
    atomic_rows(fmts["atomic-beef"], mined)
    tsc_rows(fmts["tsc"], mined)
    return fmts, reads


def ef_rows(rows, mined):
    base = None
    for s, raw, info, _, _ in mined:
        _, ins, _, _ = Reader(raw).tx()
        if any(p == bytes(32) for p, *_ in ins) or len(ins) > MAX_EF_INPUTS:
            continue
        rels = [f"/tx/{s}/hex"] + [f"/tx/{p[::-1].hex()}/hex" for p, *_ in ins]
        parents = {p[::-1].hex(): body_hex(rows.cite(f"/tx/{p[::-1].hex()}/hex")) for p, *_ in ins}
        ef = ef_of(raw, parents)
        rows.add("mainnet", ef, "[D]", rels, "BRC-30 EF of the transaction with its parents' outputs, value width 8",
                 subject=s, tx_hex=raw.hex())
        base = base or (ef, rels, s, raw)
    ef, rels, s, raw = base
    four = ef_value_width_4(ef)
    mut = [("marker-mutated", ef[:9] + b"\xee" + ef[10:], "the marker's last byte 0xef replaced by 0xee"),
           ("trailing-byte", ef + b"\x00", "one byte appended"),
           ("truncated", ef[:-1], "the last byte removed"),
           ("value-width-4", four, "the spent value written in 4 bytes, BRC-30's table at 0030.md:67"),
           ("plain-tx", raw, "the plain transaction, no marker")]
    for shape, data, how in mut:
        rows.add(shape, data, "[D]", rels, "derived from " + s + ": " + how, subject=s)


def ef_value_width_4(ef):
    """Re-write an EF with 4-byte spent values (BRC-30's table): a degenerate shape every engine refuses."""
    r = Reader(ef)
    out = r.take(10)
    n = r.varint()
    out += cs(n)
    for _ in range(n):
        out += r.take(36)
        sl = r.varint()
        out += cs(sl) + r.take(sl) + r.take(4)
        out += (int.from_bytes(r.take(8), "little") & 0xffffffff).to_bytes(4, "little")
        pl = r.varint()
        out += cs(pl) + r.take(pl)
    return out + r.b[r.i:]


def parse_bump(b):
    """BRC-74 levels as (offset, flags, hash) lists, in wire order."""
    r = Reader(b)
    height = r.varint()
    levels = []
    for _ in range(r.take(1)[0]):
        lv = []
        for _ in range(r.varint()):
            off, fl = r.varint(), r.take(1)[0]
            lv.append((off, fl, b"" if fl & 1 else r.take(32)))
        levels.append(lv)
    return height, levels, r.b[r.i:]


def write_bump(height, levels, height_bytes=None):
    out = height_bytes if height_bytes is not None else cs(height)
    out += bytes([len(levels)])
    for lv in levels:
        out += cs(len(lv)) + b"".join(cs(o) + bytes([f]) + h for o, f, h in lv)
    return out


def bump_rows(rows, mined):
    by_block, compounds = {}, []
    for s, raw, info, rec, _ in mined:
        b = body_hex(rec)
        rows.add("mainnet", b, "[M]", [f"/tx/{s}/proof/bump"], "the BUMP as read", subject=s)
        by_block.setdefault(info["blockheight"], []).append((s, b))
    # A compound BUMP: two paths of one block merged by leaf union per level (0074.md:356-387).
    for height, items in sorted(by_block.items()):
        if len(items) >= 2:
            (s1, b1), (s2, b2) = items[0], items[1]
            h, l1, _ = parse_bump(b1)
            _, l2, _ = parse_bump(b2)
            merged = [sorted({o: (o, f, x) for o, f, x in a + c}.values()) for a, c in zip(l1, l2)]
            compounds.append((height, h, merged, s1, s2))
            rows.add("compound", write_bump(h, merged), "[D]", [f"/tx/{s1}/proof/bump", f"/tx/{s2}/proof/bump"],
                     f"the two BUMPs of block {height} merged by leaf union per level, sorted by offset", subject=s1,
                     subjects=[s1, s2])
    s, b = next((s, b) for s, _, info, rec, _ in mined
                if info["blockheight"] >= 900000 for b in [body_hex(rec)])
    h, levels, _ = parse_bump(b)
    # the degenerate shapes start from the BUMP with each level in ascending offset order (the order every engine
    # writes), so a shape differs from its base by its own mutation alone; the order itself is `reversed-level-0`,
    # taken from a compound BUMP whose level 0 has at least three leaves (a two-leaf level reversed is
    # WhatsOnChain's own descending file, a mainnet row's bytes)
    levels = [sorted(lv) for lv in levels]
    b = write_bump(h, levels)
    rel = [f"/tx/{s}/proof/bump"]
    lv0 = levels[0]
    t = next(i for i, (o, f, x) in enumerate(lv0) if f == 2)
    def with_flag(fl, keep_hash=True):
        return write_bump(h, [[(o, fl if i == t else f, x if i != t or keep_hash else b"")
                               for i, (o, f, x) in enumerate(lv0)]] + levels[1:])
    ch, chh, clevels, c1, c2 = next(c for c in compounds if len(c[2][0]) >= 3)
    muts = [("flags-03", with_flag(3, keep_hash=False),
             "the client txid leaf's flags 02 set to 03 (txid and duplicate bits) and its 32-byte hash dropped "
             "(a duplicate leaf carries none, 0074.md:73-77)"),
            ("flags-04", with_flag(4), "the client txid leaf's flags 02 set to 04 (an undefined bit)"),
            ("tree-height-65", write_bump(h, levels + [[]] * (65 - len(levels))), "empty levels appended to 65"),
            ("noncanonical-offset", write_bump(h, levels)[: len(cs(h)) + 1] + bytes([len(lv0)])
             + b"".join((b"\xfd" + o.to_bytes(2, "little") if i == 0 else cs(o)) + bytes([f]) + x
                        for i, (o, f, x) in enumerate(lv0))
             + write_bump(h, levels)[len(write_bump(h, [lv0])):], "level 0's leading offset in 3-byte form"),
            ("height-above-32-bits", write_bump(h, levels, b"\xff" + (h + (1 << 32)).to_bytes(8, "little")),
             "block height plus 2^32 in 9-byte form"),
            ("trailing-byte", b + b"\x00", "one byte appended"),
            ("truncated", b[:-1], "the last byte removed"),
            ("reversed-level-0", write_bump(chh, [clevels[0][::-1]] + clevels[1:]),
             f"the compound BUMP of block {ch} ({c1} and {c2}, levels in ascending offset order): level 0's "
             f"{len(clevels[0])} leaves in reverse order"),
            ("zero-word", write_bump(h, levels[:-1] + [[(o, f, bytes(32)) for o, f, x in levels[-1]]]),
             "the top level's hash replaced by 32 zero bytes")]
    for shape, data, how in muts:
        if shape == "reversed-level-0":
            rows.add(shape, data, "[D]", [f"/tx/{c1}/proof/bump", f"/tx/{c2}/proof/bump"], how, subject=c1,
                     subjects=[c1, c2])
            continue
        rows.add(shape, data, "[D]", rel, f"derived from {s} (levels in ascending offset order): {how}", subject=s)


def raw_entries(beef):
    """The (raw, bump index) entries of a version-1 BEEF and its BUMP bytes."""
    r = Reader(beef)
    r.take(4)
    bumps = []
    for _ in range(r.varint()):
        start = r.i
        r.varint()
        for _ in range(r.take(1)[0]):
            for _ in range(r.varint()):
                r.varint()
                if not r.take(1)[0] & 1:
                    r.take(32)
        bumps.append(beef[start:r.i])
    txs = []
    for _ in range(r.varint()):
        start = r.i
        r.tx()
        raw = beef[start:r.i]
        txs.append((raw, r.varint() if r.take(1)[0] else None))
    return bumps, txs


def v1(bumps, txs):
    out = (4022206465).to_bytes(4, "little") + cs(len(bumps)) + b"".join(bumps) + cs(len(txs))
    return out + b"".join(raw + (b"\x01" + cs(i) if i is not None else b"\x00") for raw, i in txs)


def v2(bumps, txs):
    out = (4022206466).to_bytes(4, "little") + cs(len(bumps)) + b"".join(bumps) + cs(len(txs))
    for raw, i in txs:
        if isinstance(raw, str):
            out += b"\x02" + bytes.fromhex(raw)[::-1]
        else:
            out += (b"\x01" + cs(i) if i is not None else b"\x00") + raw
    return out


def chain_beef(rows, mined):
    """A parent with its BUMP and a child without one: BRC-62's simplest form (0062.md:14)."""
    for s, raw, info, _, _ in mined:
        _, ins, _, _ = Reader(raw).tx()
        if len(ins) != 1 or ins[0][0] == bytes(32):
            continue
        parent = ins[0][0][::-1].hex()
        prec = rows.cache.get(f"/tx/{parent}/proof/bump")
        if prec is None or prec["status"] != 200:
            continue
        rows.cite(f"/tx/{parent}/proof/bump")
        praw = body_hex(rows.cite(f"/tx/{parent}/hex"))
        rels = [f"/tx/{parent}/proof/bump", f"/tx/{parent}/hex", f"/tx/{s}/hex"]
        ph, plevels, _ = parse_bump(body_hex(prec))
        # the parent's BUMP with each level in ascending offset order, as in bump_rows
        return s, parent, [write_bump(ph, [sorted(lv) for lv in plevels])], [(praw, 0), (raw, None)], rels
    return None


def beef_rows(rows, mined):
    for s, _, _, _, rec in mined:
        rows.add("mainnet", body_hex(rec), "[M]", [f"/tx/{s}/beef"], "the BEEF as read", subject=s)
    s, parent, bumps, txs, rels = chain_beef(rows, mined)
    d = f"derived from {s} and its parent {parent} (the parent's BUMP levels in ascending offset order)"
    rows.add("parent-and-child-v1", v1(bumps, txs), "[D]", rels, d + ": version 1, the parent with its BUMP", subject=s)
    rows.add("parent-and-child-v2", v2(bumps, txs), "[D]", rels, d + ": version 2 of the same", subject=s)
    rows.add("txid-only-parent-v2", v2([], [(parent, None), (txs[1][0], None)]), "[D]", rels,
             d + ": version 2, the parent as a txid only", subject=s)
    rows.add("child-before-parent", v1(bumps, txs[::-1]), "[D]", rels, d + ": the two entries swapped", subject=s)
    rows.add("has-bump-02", v1(bumps, txs)[:-1 - len(txs[1][0]) - 2] + b"\x02\x00" + txs[1][0] + b"\x00",
             "[D]", rels, d + ": the parent's Has BUMP byte 01 set to 02", subject=s)
    rows.add("format-03-v2", v2(bumps, txs)[:-len(txs[1][0]) - 1] + b"\x03" + txs[1][0], "[D]", rels,
             d + ": version 2, the child's format byte 00 set to 03", subject=s)
    rows.add("bump-index-out-of-range", v1(bumps, [(txs[0][0], 1), txs[1]]), "[D]", rels,
             d + ": the parent's BUMP index 0 set to 1, one BUMP present", subject=s)
    rows.add("trailing-byte", v1(bumps, txs) + b"\x00", "[D]", rels, d + ": one byte appended", subject=s)
    rows.add("truncated", v1(bumps, txs)[:-1], "[D]", rels, d + ": the last byte removed", subject=s)
    rows.add("empty", v1([], []), "[D]", [], "no BUMP and no transaction (constructed, no read)")
    rows.add("version-3", (4022206467).to_bytes(4, "little") + v1(bumps, txs)[4:], "[D]", rels,
             d + ": the version word 0300BEEF")


def atomic_rows(rows, mined):
    for s, _, _, _, rec in mined:
        rows.cite(f"/tx/{s}/beef")
        beef = body_hex(rec)
        rows.add("mainnet-v1", b"\x01\x01\x01\x01" + bytes.fromhex(s)[::-1] + beef, "[D]", [f"/tx/{s}/beef"],
                 "BRC-95: the prefix, the subject's txid, the BEEF as read", subject=s)
    s, parent, bumps, txs, rels = chain_beef(rows, mined)
    sub, par = bytes.fromhex(s)[::-1], bytes.fromhex(parent)[::-1]
    d = f"derived from {s} and its parent {parent} (the parent's BUMP levels in ascending offset order)"
    pre = b"\x01\x01\x01\x01"
    other = mined[0]
    rows.add("parent-and-child-v2", pre + sub + v2(bumps, txs), "[D]", rels, d + ": version 2 inside", subject=s)
    rows.add("subject-is-parent", pre + par + v1(bumps, txs), "[D]", rels,
             d + ": the parent named as the subject, the child unrelated to it", subject=parent)
    rows.add("subject-missing", pre + bytes.fromhex(other[0])[::-1] + v1(bumps, txs), "[D]", rels,
             d + f": the subject word of {other[0]}, absent from the BEEF", subject=other[0])
    rows.add("unrelated-extra", pre + sub + v1(bumps + [body_hex(rows.cite(f'/tx/{other[0]}/proof/bump'))],
             [(other[1], 1)] + txs), "[D]", rels + [f"/tx/{other[0]}/proof/bump", f"/tx/{other[0]}/hex"],
             d + f": {other[0]} with its BUMP added, unrelated to the subject", subject=s)
    rows.add("nested-prefix", pre + sub + pre + sub + v1(bumps, txs), "[D]", rels, d + ": the prefix twice", subject=s)
    rows.add("prefix-mutated", b"\x01\x01\x01\x02" + sub + v1(bumps, txs), "[D]", rels,
             d + ": the prefix 01010102", subject=s)
    rows.add("trailing-byte", pre + sub + v1(bumps, txs) + b"\x00", "[D]", rels, d + ": one byte appended", subject=s)
    rows.add("short-subject", pre + sub[:16], "[D]", rels, d + ": the prefix and half a subject", subject=s)


def tsc_rows(rows, mined):
    shapes = [(False, 0, "txid, block-hash target"), (False, 1, "txid, header target"),
              (False, 2, "txid, merkle-root target"), (True, 2, "full transaction, merkle-root target")]
    k = 0
    for s, raw, info, bump_rec, _ in mined:
        prec = rows.cite(f"/tx/{s}/proof/tsc")
        hrec = rows.cite(f"/block/{info['blockhash']}/header")
        proof = json.loads(prec["body"])[0]
        full, kind, how = shapes[k % len(shapes)]
        k += 1
        rels = [f"/tx/{s}/proof/tsc", f"/tx/hash/{s}", f"/block/{info['blockhash']}/header", f"/tx/{s}/hex",
                f"/tx/{s}/proof/bump"]
        rows.add("mainnet", tsc_binary(proof, raw, header_bytes(hrec), full, kind), "[D]", rels,
                 f"the binary TSC proof ({how}) from the JSON proof as read and the block header",
                 subject=s, block_height=info["blockheight"], header_hex=header_bytes(hrec).hex(),
                 bump_hex=body_hex(bump_rec).hex())
    s, raw, info, bump_rec, _ = mined[3]
    base = rows.rows[3]
    b = bytes.fromhex(base["hex"])
    extra = {"subject": s, "block_height": info["blockheight"], "header_hex": base["header_hex"],
             "bump_hex": base["bump_hex"]}
    rels = [f"/tx/{s}/proof/tsc", f"/tx/hash/{s}", f"/block/{info['blockhash']}/header"]
    muts = [("flags-proof-type", bytes([b[0] | 8]) + b[1:], "flag bit 3 (the tree proof type, an extension) set"),
            ("flags-composite", bytes([b[0] | 16]) + b[1:], "flag bit 4 (composite, an extension) set"),
            ("target-kind-3", bytes([b[0] | 6]) + b[1:], "flag bits 1-2 set to the reserved value 3"),
            ("node-type-2", b[:-33] + b"\x02" + b[-32:], "the last node's type byte set to 2 (the extension's index)"),
            ("trailing-byte", b + b"\x00", "one byte appended"),
            ("truncated", b[:-1], "the last byte removed")]
    for shape, data, how in muts:
        rows.add(shape, data, "[D]", rels, f"derived from {s}: {how}", **extra)


def write(fmts, reads):
    os.makedirs(OUT, exist_ok=True)
    files = {}
    for f, rows in fmts.items():
        files[f"{f}.jsonl"] = "".join(json.dumps(r, sort_keys=True) + "\n" for r in rows.rows)
    files["reads.jsonl"] = "".join(json.dumps(reads[u], sort_keys=True) + "\n" for u in sorted(reads))
    return files


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("phase", choices=["fetch", "build", "check"])
    ap.add_argument("--cache", default=DEFAULT_CACHE)
    a = ap.parse_args()
    cache = Cache(a.cache)
    if a.phase == "fetch":
        fetch(cache)
        return 0
    files = write(*build(cache))
    if a.phase == "check":
        bad = [n for n, text in files.items() if open(os.path.join(OUT, n)).read() != text]
        print(f"wire_corpus check: {'GREEN' if not bad else 'RED'} ({len(files)} files; differ: {bad or 'none'})")
        return 1 if bad else 0
    for n, text in files.items():
        with open(os.path.join(OUT, n), "w") as fh:
            fh.write(text)
        print(f"wire_corpus: {n} {text.count(chr(10))} rows sha256 {hashlib.sha256(text.encode()).hexdigest()}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
