"""run.py: the clean-room evaluator over the corpus (#37). See README.md.

python3 harness/cleanroom/run.py --all            every corpus below
python3 harness/cleanroom/run.py --corpus seed    one corpus

Each corpus is read in the format corpus/INDEX.md and docs/DESIGN.md:489-532 give it;
each entry is evaluated in the strict column (every gap raises) and, where the strict
column reached a gap, again in the labelled assumed column (cleanroom.ASSUMPTIONS);
an entry the strict column decides is decided identically in the assumed column. The
result is compared with the node's recorded verdict and written to
harness/cleanroom/out/<corpus>.json with per-entry agree|diverge|gap and the counts.
"""

import argparse
import collections
import gzip
import json
import os
import re
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
sys.path.insert(0, HERE)
import cleanroom as C  # noqa: E402

NODE_BLOCK = "sv-node@v1.2.3"
NODE_MEMPOOL = "sv-node-mempool@v1.2.3"

# docs/DESIGN.md:550-573: the script corpora ran through verifyscript (both columns); the
# transaction corpora tx and road through the block road (submitblock) for the block
# column and sendrawtransaction for the mempool column, whose standardness gate the
# clean room does not evaluate (spec/modules.md:2692-2724 is outside this lane's reach).
SCRIPT_CORPORA = {
    "seed": "corpus/seed/seed.jsonl", "gen": "corpus/gen/gen.jsonl",
    "eras": "corpus/eras/eras.jsonl", "flow": "corpus/flow/flow.jsonl",
    "arith": "corpus/arith/cases.jsonl", "bytes": "corpus/bytes/cases.jsonl",
    "stack": "corpus/stack/cases.jsonl", "crypto": "corpus/crypto/cases.jsonl",
}
BLOCK_CORPORA = {"tx": "corpus/tx/tx.jsonl", "road": "corpus/road/road.jsonl"}
REFERENCE = {
    "script_tests": "corpus/reference/bitcoin-sv-v1.2.3-script_tests.json",
    "tx_valid": "corpus/reference/bitcoin-sv-v1.2.3-tx_valid.json",
    "tx_invalid": "corpus/reference/bitcoin-sv-v1.2.3-tx_invalid.json",
    "sighash": "corpus/sighash/bitcoin-sv-v1.2.3-sighash.json",
    "sighash_mainnet": "corpus/sighash/mainnet.jsonl",
    "ecdsa": "corpus/crypto/ecdsa-bsv-rs-0.7.0.jsonl",
}
ALL = list(SCRIPT_CORPORA) + list(BLOCK_CORPORA) + list(REFERENCE)


# ---------------------------------------------------------------------------
# Running one evaluation in both columns
# ---------------------------------------------------------------------------


def both(fn):
    """(strict, assumed): each a dict {verdict, code, input} or {gap}; the assumed
    column re-runs only where the strict one reached a gap."""
    strict = _one(fn, False)
    if "gap" not in strict:
        return strict, dict(strict, used=[])
    assumed = _one(fn, True)
    assumed["used"] = C.used_assumptions()
    return strict, assumed


def _one(fn, assume):
    C.set_mode(assume)
    try:
        return fn()
    except C.DocumentGap as g:
        return {"gap": g.gid}


def eval_inputs(tx, prevouts, word_of):
    """Every input in order (docs/DESIGN.md:524-528: the transaction verdict; the
    earliest failing input's reason)."""
    for i, (vin, po) in enumerate(zip(tx.vin, prevouts)):
        w, lim = word_of(i, po)
        checker = C.Checker(tx, i, po["satoshis"])
        err = C.verify_script(vin[2], bytes.fromhex(po["script"]), w, lim, checker)
        if err:
            return {"verdict": "invalid", "code": err, "input": i}
    return {"verdict": "valid"}


# ---------------------------------------------------------------------------
# The entry formats
# ---------------------------------------------------------------------------


def script_entry(e, consensus):
    """docs/DESIGN.md:489-515: tx, prevouts (with heights), params (spend_height,
    consensus), the optional explicit flags per input."""
    def fn():
        tx = C.decode_tx(bytes.fromhex(e["tx"]))
        sh = e["params"]["spend_height"]
        explicit = e.get("flags")

        def word_of(i, po):
            if explicit is not None:
                w = explicit[i]
                return w, C.limits_for(w, consensus)
            return C.derive(sh, po["height"], consensus)
        return eval_inputs(tx, e["prevouts"], word_of)
    return both(fn)


def block_entry(e):
    """The block road (docs/DESIGN.md:568-582): the transaction gate, finality, then
    every input's script under the block word; a script failure is the block's
    `blk-bad-inputs`."""
    def fn():
        tx = C.decode_tx(bytes.fromhex(e["tx"]))
        sh = e["params"]["spend_height"]
        era = C.era_of(sh)
        try:
            if C.is_coinbase(tx):
                C.check_coinbase(tx, era)
                return {"verdict": "valid"}
            C.check_regular_transaction(tx, era)
        except C.TxReject as r:
            return {"verdict": "invalid", "code": r.code}
        if not is_final(tx, sh):
            return {"verdict": "invalid", "code": "bad-txns-nonfinal"}
        if not C.sequence_locks_ok(tx, [po["height"] for po in e["prevouts"]], sh, era):
            return {"verdict": "invalid", "code": "bad-txns-nonfinal"}
        r = eval_inputs(tx, e["prevouts"], lambda i, po: C.derive(sh, po["height"], True))
        if r["verdict"] == "invalid":
            return {"verdict": "invalid", "code": "blk-bad-inputs", "script_code": r["code"], "input": r["input"]}
        return r
    return both(fn)


def is_final(tx, height):
    # spec/theorems.md:1151-1162: a zero lock time is final; all final sequences are
    # final. spec/theorems.md:1122-1146: the time cutoff (from csvHeight the previous
    # blocks' median, below it the block's own time) and that the lock time is compared
    # with it; which lock times are heights and the comparison's direction are not stated.
    if tx.locktime == 0 or all(v[3] == 0xFFFFFFFF for v in tx.vin):
        return True
    C.need("tx.finality")
    if tx.locktime < 500000000:
        return tx.locktime < height
    raise C.DocumentGap("tx.finality-time")


def node_view(e, key):
    v = e.get("expect", {}).get(key)
    if v is None:
        return None
    return {"verdict": v.get("verdict"), "code": v.get("code"), "input": v.get("input")}


# ---------------------------------------------------------------------------
# The reference's vector files (corpus/INDEX.md:419-421 and :124)
# ---------------------------------------------------------------------------

OPNAMES = {}
for _name in dir(C):
    if _name.startswith("OP_") and isinstance(getattr(C, _name), int):
        OPNAMES[_name] = getattr(C, _name)
OPNAMES.update({"OP_FALSE": 0, "OP_TRUE": 0x51, "OP_NOP2": 0xB1, "OP_NOP3": 0xB2,
                "OP_CHECKLOCKTIMEVERIFY": 0xB1, "OP_CHECKSEQUENCEVERIFY": 0xB2})


def parse_script(text):
    """The ParseScript notation corpus/INDEX.md:419 names (`core_read.cpp:37-174`, not an
    allowed source): read under the published convention of the vector files (a
    disclosed format assumption, recorded): decimal numbers pushed as script numbers
    (-1 and 1..16 as OP_1NEGATE / OP_n, 0 as OP_0), 0x.. hex inserted raw, 'text'
    pushed, opcode names with or without OP_."""
    out = bytearray()
    for tok in text.split():
        if re.fullmatch(r"-?\d+", tok):
            n = int(tok)
            if n == -1 or 1 <= n <= 16:
                out.append(C.OP_1NEGATE if n == -1 else C.OP_1 + n - 1)
            elif n == 0:
                out.append(C.OP_0)
            else:
                out += C.push_data_script(C.num_encode(n))
        elif tok.startswith("0x"):
            out += bytes.fromhex(tok[2:])
        elif len(tok) >= 2 and tok[0] == "'" and tok[-1] == "'":
            out += C.push_data_script(tok[1:-1].encode())
        else:
            name = tok if tok.startswith("OP_") else "OP_" + tok
            if name not in OPNAMES:
                raise ValueError("unknown opcode " + tok)
            out.append(OPNAMES[name])
    return bytes(out)


TEST_FLAG = {"SIGHASH_FORKID": "SIGHASH_FORKID"}


def parse_flags(text):
    # spec/flags.md:241-244 (testName): the reference's parser names, the enum
    # identifiers of spec/flags.md:5-25 without their prefixes
    w = 0
    for nm in [x for x in text.split(",") if x and x != "NONE"]:
        w |= C.word(TEST_FLAG.get(nm, nm))
    return w


ERR_ALIASES = {"SPLIT_RANGE": "INVALID_SPLIT_RANGE", "OPERAND_SIZE": "INVALID_OPERAND_SIZE", "NULLFAIL": "SIG_NULLFAIL"}


def test_limits(w):
    C.need("script_tests.limits")
    return C.limits_for(w, True)


def credit_and_spend(script_sig, script_pubkey, amount, version):
    """The one-input spend of corpus/INDEX.md:419 (stated there; DoTest,
    `script_tests.cpp:271-348`, is not an allowed source); its crediting transaction's
    shape is not stated, read under the vector files' published convention (a disclosed
    format assumption, F13): a crediting transaction with a null input and one output of the
    amount paying scriptPubKey; the spend of its output 0 with scriptSig, one output of
    the amount with an empty script, sequences final, lock times zero."""
    credit = C.Tx(1, [(b"\x00" * 32, 0xFFFFFFFF, b"\x00\x00", 0xFFFFFFFF)], [(amount, script_pubkey)], 0)
    txid = C.sha256d(C.ser_tx(credit))
    return C.Tx(version, [(txid, 0, script_sig, 0xFFFFFFFF)], [(amount, b"")], 0)


def run_script_tests(path):
    rows = json.load(open(path))
    out = []
    for k, row in enumerate(rows):
        if len(row) == 1:
            continue
        amount = 0
        if isinstance(row[0], list):
            amount = int(round(row[0][0] * 100000000))
            row = row[1:]
        version, ssig, spub, flags, expected = row[0], row[1], row[2], row[3], row[4]
        rid = "row-%04d" % k

        def fn(ssig=ssig, spub=spub, flags=flags, amount=amount, version=version):
            sig, pub = parse_script(ssig), parse_script(spub)
            w = parse_flags(flags)
            if C.has(w, "CLEANSTACK"):
                w |= C.word("P2SH")  # spec/theorems.md:9047-9049 (the runner's P2SH)
            tx = credit_and_spend(sig, pub, amount, int(version))
            err = C.verify_script(sig, pub, w, test_limits(w), C.Checker(tx, 0, amount))
            return {"verdict": "invalid", "code": err, "input": 0} if err else {"verdict": "valid"}
        strict, assumed = both(fn)
        if expected == "OK":
            node = {"verdict": "valid"}
        else:
            node = {"verdict": "invalid", "code": "SCRIPT_ERR_" + ERR_ALIASES.get(expected, expected)}
        out.append((rid, "reference", strict, assumed, node))
    return out


def run_tx_tests(path, valid):
    rows = json.load(open(path))
    out = []
    for k, row in enumerate(rows):
        if len(row) == 1 or not isinstance(row[0], list):
            continue
        prev, txhex, flags = row[0], row[1], row[2]
        words = [parse_flags(f) for f in (flags if isinstance(flags, list) else [flags])]
        for wi, w in enumerate(words):
            rid = "row-%04d/w%d" % (k, wi)

            def fn(prev=prev, txhex=txhex, w=w):
                try:
                    tx = C.decode_tx(bytes.fromhex(txhex))
                except Exception:
                    raise C.DocumentGap("tx.decode")
                pmap = {}
                for p in prev:
                    amt = int(p[3]) if len(p) > 3 else 0
                    pmap[(bytes.fromhex(p[0])[::-1], p[1] & 0xFFFFFFFF)] = (parse_script(p[2]), amt)
                # corpus/INDEX.md:420: the transaction-level checks under the pre-Genesis
                # limits (a SegWit-serialized row reads as a zero-input transaction), then
                # every input's script for every flag word
                try:
                    if C.is_coinbase(tx):
                        C.check_coinbase(tx, C.PRE_GENESIS)
                        return {"verdict": "valid"}
                    C.check_regular_transaction(tx, C.PRE_GENESIS)
                except C.TxReject as r:
                    return {"verdict": "invalid", "code": r.code}
                for i, vin in enumerate(tx.vin):
                    if (vin[0], vin[1]) not in pmap:
                        return {"verdict": "invalid", "code": "missing-prevout", "input": i}
                    pub, amt = pmap[(vin[0], vin[1])]
                    err = C.verify_script(vin[2], pub, w, test_limits(w), C.Checker(tx, i, amt))
                    if err:
                        return {"verdict": "invalid", "code": err, "input": i}
                return {"verdict": "valid"}
            strict, assumed = both(fn)
            out.append((rid, "reference", strict, assumed, {"verdict": "valid" if valid else "invalid"}))
    return out


def run_sighash(path):
    """corpus/INDEX.md:124: column 4 = SignatureHash with FORKID enabled at amount 0,
    column 5 = the original digest, both uint256 hex (the bytes reversed); the type a
    32-bit word."""
    rows = json.load(open(path))
    out = []
    for k, row in enumerate(rows):
        if len(row) == 1:
            continue
        txhex, code, n_in, t, h_reg, h_orig = row
        t &= 0xFFFFFFFF
        for col, expect in (("regular", h_reg), ("original", h_orig)):
            def fn(col=col):
                tx = C.decode_tx(bytes.fromhex(txhex))
                sc = bytes.fromhex(code)
                d = (C.signature_hash(sc, tx, n_in, t, 0, True) if col == "regular"
                     else C.sighash_original(sc, tx, n_in, t))
                return {"verdict": "digest", "code": d[::-1].hex()}
            strict, assumed = both(fn)
            out.append(("row-%04d/%s" % (k, col), col, strict, assumed, {"verdict": "digest", "code": expect}))
    return out


def run_sighash_mainnet(path):
    """corpus/sighash/mainnet.jsonl: public mainnet spends at block 400,000 (rule 10:
    read as corpus material); the node accepted each, so the recorded verdict is valid.
    The coin's height is not recorded: any height below Genesis gives the same word."""
    out = []
    for line in open(path):
        e = json.loads(line)

        def fn(e=e):
            tx = C.decode_tx(bytes.fromhex(e["tx"]))
            i = e["input"]
            po = e["prevout"]
            w, lim = C.derive(e["height"], e["height"] - 1, True)
            err = C.verify_script(tx.vin[i][2], bytes.fromhex(po["script"]), w, lim,
                                  C.Checker(tx, i, po["satoshis"]))
            return {"verdict": "invalid", "code": err, "input": i} if err else {"verdict": "valid"}
        strict, assumed = both(fn)
        out.append((e["txid"][:16] + "/%d" % e["input"], "mainnet", strict, assumed, {"verdict": "valid"}))
    return out


def run_ecdsa(path):
    """corpus/crypto/ecdsa-bsv-rs-0.7.0.jsonl: the equation alone (docs/DESIGN.md:311-314:
    1,340 cases from 200 signatures, labelled BY CONSTRUCTION, not a node's verdict): the
    key decoded, the signature parsed, the digest read big-endian, the equation. Its
    column is a self-check of the curve, reported apart from the node comparisons."""
    out = []
    for k, line in enumerate(open(path)):
        e = json.loads(line)

        def fn(e=e):
            q = C.decode_point(bytes.fromhex(e["pubkey"]))
            rs = C.parse_sig(bytes.fromhex(e["sig"]))
            ok = q is not None and rs is not None and C.ecdsa_verify(q, int(e["hash"], 16), rs[0], rs[1])
            return {"verdict": "valid" if ok else "invalid"}
        strict, assumed = both(fn)
        out.append(("case-%04d" % k, "construction", strict, assumed,
                    {"verdict": "valid" if e["expect"] else "invalid"}))
    return out


# ---------------------------------------------------------------------------
# Comparison and output
# ---------------------------------------------------------------------------


def outcome(ours, node):
    if node is None or node.get("verdict") in (None, "undecided"):
        return "node-undecided"
    if "gap" in ours:
        return "gap"
    if ours.get("verdict") == "digest":
        return "agree" if ours.get("code") == node.get("code") else "diverge"
    return "agree" if ours["verdict"] == node["verdict"] else "diverge"


def code_match(ours, node):
    if "gap" in ours or ours.get("verdict") != "invalid" or node.get("verdict") != "invalid":
        return None
    if node.get("code") is None:
        return None
    return ours.get("code") == node.get("code")


def run_corpus(name):
    t0 = time.time()
    rows = []  # (id, column, strict, assumed, node)
    if name in SCRIPT_CORPORA:
        for line in open(os.path.join(ROOT, SCRIPT_CORPORA[name])):
            e = json.loads(line)
            for col, consensus, key in (("block", True, NODE_BLOCK), ("mempool", False, NODE_MEMPOOL)):
                strict, assumed = script_entry(e, consensus)
                rows.append((e["id"], col, strict, assumed, node_view(e, key)))
    elif name in BLOCK_CORPORA:
        for line in open(os.path.join(ROOT, BLOCK_CORPORA[name])):
            e = json.loads(line)
            strict, assumed = block_entry(e)
            rows.append((e["id"], "block", strict, assumed, node_view(e, NODE_BLOCK)))
    elif name == "script_tests":
        rows = run_script_tests(os.path.join(ROOT, REFERENCE[name]))
    elif name in ("tx_valid", "tx_invalid"):
        rows = run_tx_tests(os.path.join(ROOT, REFERENCE[name]), name == "tx_valid")
    elif name == "sighash":
        rows = run_sighash(os.path.join(ROOT, REFERENCE[name]))
    elif name == "sighash_mainnet":
        rows = run_sighash_mainnet(os.path.join(ROOT, REFERENCE[name]))
    elif name == "ecdsa":
        rows = run_ecdsa(os.path.join(ROOT, REFERENCE[name]))
    counts = collections.defaultdict(lambda: collections.Counter())
    gaps = collections.defaultdict(collections.Counter)
    for rid, col, strict, assumed, node in rows:
        o_s, o_a = outcome(strict, node), outcome(assumed, node)
        counts[col + "/strict"][o_s] += 1
        counts[col + "/assumed"][o_a] += 1
        for tag, ours in (("strict", strict), ("assumed", assumed)):
            cm = code_match(ours, node)
            if cm is not None:
                counts[col + "/" + tag]["code-" + ("match" if cm else "differ")] += 1
            if "gap" in ours:
                gaps[col + "/" + tag][ours["gap"]] += 1
    # The per-entry record, compact (docs/DESIGN.md:517-524: tier 1 the verdict, tier 2
    # the code): "outcomes" maps each column to {id: two letters}, the strict then the
    # assumed outcome (a agree, d diverge, g gap, u the node undecided); "strict_gap"
    # names the gap a strict entry reached; "assumed_used" the fills an assumed entry
    # took (an index into "used_sets"); "details" carries every divergence, every assumed gap and every code that
    # differs, in full.
    letter = {"agree": "a", "diverge": "d", "gap": "g", "node-undecided": "u"}
    outcomes = collections.defaultdict(dict)
    strict_gap = collections.defaultdict(dict)
    assumed_used = collections.defaultdict(dict)
    used_sets = []
    details = []
    for rid, col, strict, assumed, node in rows:
        o_s, o_a = outcome(strict, node), outcome(assumed, node)
        outcomes[col][rid] = letter[o_s] + letter[o_a]
        if "gap" in strict:
            strict_gap[col][rid] = strict["gap"]
        if assumed.get("used"):
            if assumed["used"] not in used_sets:
                used_sets.append(assumed["used"])
            assumed_used[col][rid] = used_sets.index(assumed["used"])
        cm_s, cm_a = code_match(strict, node), code_match(assumed, node)
        if o_s == "diverge" or o_a not in ("agree", "node-undecided") or cm_s is False or cm_a is False:
            details.append({"id": rid, "col": col, "strict": strict, "assumed": assumed, "node": node})
    result = {
        "corpus": name,
        "source": (SCRIPT_CORPORA.get(name) or BLOCK_CORPORA.get(name) or REFERENCE.get(name)),
        "node_keys": {"block": NODE_BLOCK, "mempool": NODE_MEMPOOL},
        "counts": {k: dict(v) for k, v in sorted(counts.items())},
        "gaps": {k: dict(v.most_common()) for k, v in sorted(gaps.items())},
        "seconds": round(time.time() - t0, 1),
        "outcomes": {k: v for k, v in sorted(outcomes.items())},
        "strict_gap": {k: v for k, v in sorted(strict_gap.items())},
        "assumed_used": {k: v for k, v in sorted(assumed_used.items())},
        "used_sets": used_sets,
        "details": details,
    }
    os.makedirs(os.path.join(HERE, "out"), exist_ok=True)
    with open(os.path.join(HERE, "out", name + ".json"), "w") as f:
        json.dump(result, f, separators=(",", ":"), sort_keys=True)
        f.write("\n")
    return result


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--all", action="store_true")
    ap.add_argument("--corpus", action="append", default=[])
    args = ap.parse_args()
    names = ALL if args.all else args.corpus
    if not names:
        ap.error("--all or --corpus NAME (%s)" % ", ".join(ALL))
    for n in names:
        r = run_corpus(n)
        print("%-16s %6.1fs  %s" % (n, r["seconds"], json.dumps(r["counts"], sort_keys=True)))
        for k, v in r["gaps"].items():
            print("%16s gaps %s %s" % ("", k, json.dumps(v)))


if __name__ == "__main__":
    main()
