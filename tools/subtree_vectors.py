#!/usr/bin/env python3
"""tools/subtree_vectors.py: the subtree merkle vectors of #89 (lane merkle-89, 2026-10-14) [D].

Writes corpus/merkle/subtree-vectors.jsonl: per case the transaction ids (synthetic, internal byte order, hex),
the subtree partition, Teranode's root (or its refusal) and the reference's root and mutation flag, computed
by two transcriptions written from the source here, independent of the Lean definitions that
`chaincheck --subtree` checks against them in structure (the array layout and the binary counter, not the
levels), written by the same lane and sharing its reading of `RootHash` (every root recomputed from the nodes,
the in-memory reading; a stored subtree's `RootHash` is its header's claim, subtree.go:481-483,837-839):

  Teranode v0.16.0 (4edb60a40c6628ff0ef60231c2628efd7103fde5): model/Block.go:2709-2771 CheckMerkleRoot,
    :2793-2879 blockMerkleRoot, model/subtree_body_shape.go:37-60 CheckSubtreeShape, :75-103
    ComposeSubtreeRootsToMerkleRoot; go-subtree v1.5.1 (go.mod:17, go.sum:142): merkle_tree.go:45-161
    BuildMerkleTreeStoreFromBytes with its array layout and zero sentinel, power_of_two.go:24-45,
    subtree.go:290-306 ReplaceRootNode, :416-449 AddNode (the placeholder refused), :476-498 RootHash,
    :516-541 RootHashPadded, coinbase_placeholder.go:13-18 [SRC].
  bitcoin-sv v1.2.3 (6504a3aff65ba97c0f6c80962b033e35ecbfed4b): src/consensus/merkle.cpp:183-245 MerkleSiblings,
    combine, lift_combine; :247-282 ComputeMerkleRoot through src/binary_counter.h:12-35 add_to_counter,
    :80-136 binary_counter, :168-185 reduce_counter; :312-319 BlockMerkleRoot [SRC].

Ten rows (lane fix-merkle-89) take mainnet blocks 100000 and 100002 from
corpus/chain/merkle/2026-10-13-mainnet-paths.jsonl (public reads of 2026-10-13, read-only, rule 10): their
`block_txids` reversed to internal order, and the header's `merkle_root`, reversed, as `header_root` [M].
Lane vec-89 (2026-10-15) adds eight blocks from corpus/chain/merkle/2026-10-15-mainnet-blocks.jsonl (public
reads of api.whatsonchain.com, read-only, rule 10; the URLs and times in each line's `reads`): heights 160000,
150000, 128500, 170000, 142500, 180000 and 200000 at sizes 1, 2, 4, 8, 16, and 714000 (8,100 transactions, the
largest block read under the file's megabyte) once at size 1024. Each header's 80 bytes hash to its block hash
and its merkle root field is `header_root` [M]; the root checked against src/consensus/merkle.cpp:312-319
BlockMerkleRoot at 6504a3af [SRC].
The generator itself reads no network; nothing broadcast. Usage: python3 tools/subtree_vectors.py [--check]  (--check: the file
on disk equals a fresh generation).
"""
import hashlib
import json
import math
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "corpus", "merkle", "subtree-vectors.jsonl")
MAINNET = os.path.join(ROOT, "corpus", "chain", "merkle", "2026-10-13-mainnet-paths.jsonl")
BLOCKS = os.path.join(ROOT, "corpus", "chain", "merkle", "2026-10-15-mainnet-blocks.jsonl")
LARGEST_SIZE = 1024  # the largest block of BLOCKS: one row, subtrees of 1024 (the file stays under a megabyte)
ZERO = bytes(32)
PLACEHOLDER = b"\xff" * 32


def h2(a, b):
    return hashlib.sha256(hashlib.sha256(a + b).digest()).digest()


# ---- Teranode and go-subtree v1.5.1 -------------------------------------------------------------

def next_power_of_two(n):  # power_of_two.go:35-45
    if n & (n - 1) == 0:
        return n
    return 1 << (int(math.log2(n)) + 1)


def calc_merkle(l, r):  # merkle_tree.go:136-161
    if l == ZERO:
        return ZERO
    if r == ZERO:
        return h2(l, l)
    return h2(l, r)


def build_store(nodes):  # merkle_tree.go:45-133
    if not nodes:
        return []
    length = len(nodes)
    npot = next_power_of_two(length)
    merkles = [ZERO] * (npot - 1)
    if npot * 2 - 1 == 1:
        return [nodes[0]]
    height = int(math.ceil(math.log2(length)))
    lo = 0
    for h in range(height + 1):
        hi = lo + int(math.pow(2, height - h)) - 1
        for i in range(lo, hi, 2):
            if i < npot:
                a = nodes[i] if i < length else ZERO
                b = nodes[i + 1] if i + 1 < length else ZERO
            else:
                a, b = merkles[i - npot], merkles[i - npot + 1]
            merkles[i // 2] = calc_merkle(a, b)
        lo = hi + 1
    return merkles


def root_hash(nodes):  # subtree.go:476-498
    if not nodes:
        return None
    return build_store(nodes)[-1]


def root_hash_padded(nodes, target_height):  # subtree.go:516-541
    if not nodes:
        return None
    actual = (len(nodes) - 1).bit_length()
    if target_height < actual:
        raise ValueError("target height too small")
    root = root_hash(nodes)
    for _ in range(target_height - actual):
        root = h2(root, root)
    return root


def is_power_of_two(n):  # power_of_two.go:24-30
    return n > 0 and n & (n - 1) == 0


def teranode_root(coinbase, subtrees):
    """CheckMerkleRoot and blockMerkleRoot: (root, None) or (None, the refusal)."""
    if not subtrees:  # Block.go:2760-2761
        return coinbase, None
    hashes = []
    for i, st in enumerate(subtrees):
        if i == 0:  # Block.go:2736-2742, ReplaceRootNode subtree.go:290-306
            replaced = [coinbase] + st[1:] if st else [coinbase]
            hashes.append(build_store(replaced)[-1])
        else:  # Block.go:2744-2748
            r = root_hash(st)
            if r is None:
                return None, "nil subtree root"
            hashes.append(r)
    if len(hashes) == 1:  # Block.go:2794-2796
        return hashes[0], None
    target_length = len(subtrees[0])
    target_height = int(math.ceil(math.log2(target_length))) if target_length > 0 else 0  # subtree.go:925,976
    for i, st in enumerate(subtrees):  # subtree_body_shape.go:37-60
        last = i == len(subtrees) - 1
        if i == 0 and not is_power_of_two(target_length):
            return None, "leading subtree leaf count is not a power of two (paraphrased)"
        if not last and len(st) != target_length:
            return None, "only the final subtree may be incomplete"
        if last and len(st) > target_length:
            return None, "final subtree exceeds the leading subtree size (paraphrased)"
    if len(subtrees[-1]) < target_length:  # Block.go:2867-2876
        hashes[-1] = root_hash_padded(subtrees[-1], target_height)
    seen = set()  # subtree_body_shape.go:81-93
    for r in hashes:
        if r in seen:
            return None, "duplicate subtree root"
        seen.add(r)
        if r == PLACEHOLDER:  # subtree.go:421-423
            return None, "coinbase placeholder as a root"
    return build_store(hashes)[-1], None


def partition(size, xs):  # block assembly: full subtrees, the last partial
    out = []
    while len(xs) > size:
        out.append(xs[:size])
        xs = xs[size:]
    out.append(xs)
    return out


# ---- bitcoin-sv v1.2.3 ---------------------------------------------------------------------------

class Siblings:  # merkle.cpp:185-225
    def __init__(self, lhs, rhs, level=0, odd=False, mutated=False):
        self.lhs, self.rhs, self.level, self.odd, self.mut = lhs, rhs, level, odd, mutated

    def mutated(self):
        return self.mut or (self.lhs == self.rhs and not self.odd)

    def lift(self):
        p = h2(self.lhs, self.rhs)
        return Siblings(p, p, self.level + 1, True, self.mutated())


def combine(a, b):  # merkle.cpp:227-237
    return Siblings(h2(a.lhs, a.rhs), h2(b.lhs, b.rhs), a.level + 1, False, a.mutated() or b.mutated())


def lift_combine(a, b):  # merkle.cpp:239-244
    while b.level < a.level:
        b = b.lift()
    return combine(a, b)


def compute_merkle_root(leaves):  # merkle.cpp:247-282
    if len(leaves) <= 1:
        return (leaves[0] if leaves else ZERO), False
    slots = []  # binary_counter.h:80-136; None is the empty optional

    def push(carry):  # binary_counter.h:12-35 and operator()
        for i in range(len(slots)):
            if slots[i] is None:
                slots[i] = carry
                return
            carry = combine(slots[i], carry)
            slots[i] = None
        slots.append(carry)

    for i in range(len(leaves) // 2):
        push(Siblings(leaves[2 * i], leaves[2 * i + 1]))
    if len(leaves) & 1:
        push(Siblings(leaves[-1], leaves[-1], 0, True))
    result = None  # binary_counter.h:168-185
    for y in slots:
        if y is None:
            continue
        result = y if result is None else lift_combine(y, result)
    return h2(result.lhs, result.rhs), result.mutated()


# ---- the cases -----------------------------------------------------------------------------------

def txid(i):
    return h2(b"bsv-script-lean #89 synthetic txid ", i.to_bytes(4, "little"))


def row(case_id, note, txids, size, subtrees, explicit, header=None, date="2026-10-14"):
    coinbase = txids[0]
    t_root, t_err = teranode_root(coinbase, subtrees)
    r_root, r_mut = compute_merkle_root(txids)
    out = {"id": case_id, "label": "[D]", "date": date, "note": note,
           "count": len(txids), "size": size, "txids": [x.hex() for x in txids],
           "subtree_lengths": [len(s) for s in subtrees]}
    if explicit:
        out["subtrees"] = [[x.hex() for x in s] for s in subtrees]
    out.update({"teranode_root": t_root.hex() if t_root else None, "teranode_refusal": t_err,
                "reference_root": r_root.hex(), "reference_mutated": r_mut,
                "agree": t_root == r_root})
    if header is not None:
        root, source = header
        if t_root != root or r_root != root:
            raise SystemExit(f"{case_id}: a root differs from the mainnet header's")
        out.update({"header_root": root.hex(), "header_root_label": "[M]", "header_root_source": source})
    return out


def mainnet_blocks():
    """The distinct blocks of the mainnet paths file: (height, txids internal order, header root internal order)."""
    blocks = {}
    for line in open(MAINNET):
        j = json.loads(line)
        if j["height"] not in blocks:
            blocks[j["height"]] = ([bytes.fromhex(t)[::-1] for t in j["block_txids"]],
                                   bytes.fromhex(j["merkle_root"])[::-1])
    return [(h, *blocks[h]) for h in sorted(blocks)]


def mainnet_blocks_read():
    """The blocks of lane vec-89's read (2026-10-15): (height, txids internal order, header root internal order),
    each header's 80 bytes hashing to its block hash and its merkle root field equal to the row's root."""
    out = []
    for line in open(BLOCKS):
        j = json.loads(line)
        header = bytes.fromhex(j["header_hex"])
        if len(header) != 80 or h2(header, b"")[::-1].hex() != j["block_hash"]:
            raise SystemExit(f"height {j['height']}: the header does not hash to the block hash")
        if header[36:68][::-1].hex() != j["merkle_root"] or len(j["block_txids"]) != j["tx_count"]:
            raise SystemExit(f"height {j['height']}: the header's root or the count differs")
        out.append((j["height"], [bytes.fromhex(t)[::-1] for t in j["block_txids"]], header[36:68]))
    return sorted(out, key=lambda b: len(b[1]))


def cases():
    rows = []
    for size in (1, 2, 4, 8, 16):
        for count in range(1, 21):
            txs = [txid(i) for i in range(count)]
            sts = partition(size, [PLACEHOLDER] + txs[1:])
            rows.append(row(f"grid-count{count:02d}-size{size:02d}",
                            "block assembly's partition of the placeholder and the transactions; the coinbase txid at index 0",
                            txs, size, sts, False))
    t = [txid(100 + i) for i in range(8)]
    six = t[:6]
    eight = t[:6] + t[4:6]
    rows.append(row("cve-2012-2459-six", "merkle.cpp:21-24's six-leaf list, one subtree of eight",
                    six, 8, partition(8, [PLACEHOLDER] + six[1:]), False))
    rows.append(row("cve-2012-2459-eight", "the same root with 5 and 6 repeated: the reference flags mutated; Teranode's root is the same (its repeated-txid check is elsewhere)",
                    eight, 8, partition(8, [PLACEHOLDER] + eight[1:]), False))
    a, b, c = txid(200), txid(201), txid(202)
    cb = txid(203)
    rows.append(row("duplicate-root-nonsibling", "subtrees [cb] [B] [C] [B]: Teranode refuses the repeated root; the reference's flag is false",
                    [cb, b, c, b], 1, [[PLACEHOLDER], [b], [c], [b]], True))
    rows.append(row("duplicate-root-sibling", "subtrees [cb] [A] [B] [B]: both refuse (the reference through mutated)",
                    [cb, a, b, b], 1, [[PLACEHOLDER], [a], [b], [b]], True))
    rows.append(row("leading-subtree-three", "subtrees of 3 and 2: Teranode's power-of-two rule refuses the body",
                    [cb, a, b, c, txid(204)], 3, [[PLACEHOLDER, a, b], [c, txid(204)]], True))
    rows.append(row("single-subtree-three", "one subtree of 3: no shape rule, the roots agree",
                    [cb, a, b], 3, [[PLACEHOLDER, a, b]], True))
    rows.append(row("zero-txid", "a zero transaction id (infeasible: a zero txid needs a SHA256d preimage of the zero word): the builder's sentinel makes the roots differ",
                    [cb, ZERO], 2, [[PLACEHOLDER, ZERO]], True))
    for height, txs, root in mainnet_blocks():
        for size in (1, 2, 4, 8, 16):
            source = (f"corpus/chain/merkle/2026-10-13-mainnet-paths.jsonl, height {height}, "
                      "merkle_root reversed to internal order")
            rows.append(row(f"mainnet-{height}-size{size:02d}",
                            f"mainnet block {height} (read-only), block assembly's partition at size {size}",
                            txs, size, partition(size, [PLACEHOLDER] + txs[1:]), False, (root, source)))
    read = mainnet_blocks_read()
    for k, (height, txs, root) in enumerate(read):
        source = (f"corpus/chain/merkle/2026-10-15-mainnet-blocks.jsonl, height {height}, "
                  "the header's merkle root field (internal order)")
        for size in ((LARGEST_SIZE,) if k == len(read) - 1 else (1, 2, 4, 8, 16)):
            rows.append(row(f"mainnet-{height}-size{size:02d}",
                            f"mainnet block {height} ({len(txs)} transactions, read-only), block assembly's partition at size {size}",
                            txs, size, partition(size, [PLACEHOLDER] + txs[1:]), False, (root, source), "2026-10-15"))
    return rows


def main():
    text = "".join(json.dumps(r, separators=(",", ":")) + "\n" for r in cases())
    if "--check" in sys.argv:
        same = os.path.exists(OUT) and open(OUT).read() == text
        print(f"subtree vectors: {'GREEN' if same else 'RED'} [X] (the file {'equals' if same else 'differs from'} a fresh generation)")
        return 0 if same else 1
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, "w") as f:
        f.write(text)
    rows = cases()
    print(f"wrote {OUT}: {len(rows)} rows; agree {sum(r['agree'] for r in rows)}; "
          f"Teranode refusals {sum(r['teranode_root'] is None for r in rows)}; "
          f"roots differ {sum((not r['agree']) and r['teranode_root'] is not None for r in rows)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
