#!/usr/bin/env python3
"""[M] 2026-10-16, lane xsig-144 (#144): the checksig-in-unlock witness on a fresh regtest instance of the reference.

The owner's question (#144): does an SDK build the wrong digest for a CHECKSIG that executes inside the UNLOCKING script
after Chronicle? The reference (bitcoin-sv v1.2.3 `6504a3af`, docs/PROVENANCE.md §1a) signs, for such a CHECKSIG, the
unlocking script from its last OP_CODESEPARATOR to its end PLUS the locking script (interpreter.cpp:1474-1481, gated on
SCRIPT_CHRONICLE; checksigData is the scriptPubKey VerifyScript passes, :2338-2342), then CleanupScriptCode (:255-263).

Two shapes, both from go-sdk v1.7.2's own test (script/interpreter/chronicle_scriptsig_checksig_test.go):
  A  the plain one (:26-50, :62-66): lock `<utxoPub> OP_CHECKSIG`; unlock
     `<utxoSig> <sig0> OP_CODESEPARATOR <pub0> OP_CHECKSIGVERIFY`; sig0 must sign `<pub0> OP_CHECKSIGVERIFY` ++ lock.
  B  the OP_PUSH_TX-style one (:91-105, the unlock ends OP_CODESEPARATOR OP_CHECKSIGVERIFY OP_ENDIF): lock P2PKH(utxo);
     unlock `<utxoSig> <utxoPub> <P> OP_1 OP_IF <signer> <G> OP_CODESEPARATOR OP_CHECKSIGVERIFY OP_ENDIF`, where
     <signer> computes in script the k=1, d=1 signature over hash256(P) (r = Gx, s = z + Gx mod n, DER, 0x41): the
     spend is valid exactly when P is the preimage the node computes, i.e. over `OP_CHECKSIGVERIFY OP_ENDIF` ++ lock.
Four spends of each, each on its own coin: (a) the signature (A) or preimage (B) over the locking script ALONE as go-sdk's
CalcInputSignatureHash / p2pkh template produce it (tools/xsig/gosign); (b) the same as @bsv/sdk's P2PKH template
passes `subscript` (tools/xsig/tssign.mjs); (c) over the CORRECT scriptCode, computed here byte by byte (BIP143,
interpreter.cpp:2034-2083); (d) the correct scriptCode through @bsv/sdk's TransactionSignature.format by hand. Then the
era rows of shape A (a coin spent before Genesis and one spent after Genesis but before Chronicle, each signed over the
unlock-only scriptCode and over unlock ++ lock).

The instance: bitcoind at docs/PROVENANCE.md's `reference.binary`, harness/oracle/bitcoin.conf's lines with regtest's
own activation heights replaced by low ones (GENESIS_HEIGHT, CHRONICLE_HEIGHT below; chainparams.cpp:21, 26 give 10,000
and 15,000, past regtest's 150-block subsidy halving), on the lowest free RPC/P2P pair in 18571..18590, its own datadir
under $TMPDIR (scratch/ when unset), started and stopped by this script and the datadir removed. Nothing reaches a peer (listen=0, no
connect; CLAUDE.md rule 10). Only the verdict fields of the node's replies are kept.

The corpus (`--corpus`): each spend of the witness as an entry of corpus/xsig-144/xsig-144.jsonl (docs/DESIGN.md §6, the
shape of corpus/crypto/cases.jsonl), its coin at a MAINNET height of the same era (the oracle's and the harness's
convention, harness/oracle/bitcoin.conf: post-Chronicle 967,896 as crypto-00041, post-Genesis 900,000, pre-Genesis
600,000), the regtest chain's verdict in the note; the manifest beside it (corpus/xsig-144/manifest.json).
The runners record their keys into both (`--record`); the corpus has its own directory because the drivers key a corpus by
its directory's name (differential.rs:79-82) and rules_check's bsv-rs replay finds only a manifest.json or cases-manifest.json
beside it (rules_check.rs:695-703), so the four witness manifests carry it as `xsig-144`.

Shape C (#147 item 2, lane min-147, `--shape C`): the minimal example of #144's outside reader, run alone on its own
instance: lock `51` (OP_1); unlock `<sig> <pub> OP_CODESEPARATOR OP_CHECKSIGVERIFY`; ALL|FORKID. The reference's scriptCode
is `ad51` after Chronicle (the unlock from its last OP_CODESEPARATOR, `ad`, plus the lock) and `ad` before it. Four spends,
one coin each: (c1) signed over `ad51` and (c2) over `ad`, both spent after Chronicle; (c3) over `ad51` and (c4) over `ad`,
both spent before Genesis, as the era rows of shape A. Its spends join the corpus after the kept rows (`--corpus W --append`).

Usage: tools/xsig_witness.py --out scratch/xsig-witness.json
       tools/xsig_witness.py --shape C --out scratch/xsig-witness-c.json
       tools/xsig_witness.py --corpus scratch/xsig-witness.json
       tools/xsig_witness.py --corpus scratch/xsig-witness-c.json --append
       tools/xsig_witness.py --manifest   (after the runners' --record: the manifest's sha256, verdicts and implementations;
                                           the runners re-stamp only a manifest.json or cases-manifest.json, differential.rs:83)
"""
import argparse
import base64
import hashlib
import hmac
import http.client
import json
import os
import re
from pathlib import Path
import shutil
import socket
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parent.parent
BITCOIND = Path.home() / "bsv/targets/sv-v1.2.3/bin/bitcoind"
GOSIGN = ROOT / "harness/target/engines/xsig-gosign"
TSSIGN = ROOT / "tools/xsig/tssign.mjs"
GENESIS_HEIGHT = 115
CHRONICLE_HEIGHT = 130
FEE = 1000
COIN_SATS = 100000

# secp256k1 (SEC 2 §2.4.1)
P_FIELD = 2**256 - 2**32 - 977
N = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141
GX = 0x79BE667EF9DCBBAC55A06295CE870B07029BFCDB2DCE28D959F2815B16F81798
GY = 0x483ADA7726A3C4655DA4FBFC0E1108A8FD17B448A68554199C47D08FFB10D4B8


def ec_add(a, b):
    if a is None:
        return b
    if b is None:
        return a
    if a[0] == b[0] and (a[1] + b[1]) % P_FIELD == 0:
        return None
    if a == b:
        lam = 3 * a[0] * a[0] * pow(2 * a[1], -1, P_FIELD) % P_FIELD
    else:
        lam = (b[1] - a[1]) * pow(b[0] - a[0], -1, P_FIELD) % P_FIELD
    x = (lam * lam - a[0] - b[0]) % P_FIELD
    return (x, (lam * (a[0] - x) - a[1]) % P_FIELD)


def ec_mul(k, pt=(GX, GY)):
    acc = None
    while k:
        if k & 1:
            acc = ec_add(acc, pt)
        pt = ec_add(pt, pt)
        k >>= 1
    return acc


def pub_of(d):
    x, y = ec_mul(d)
    return bytes([2 + (y & 1)]) + x.to_bytes(32, "big")


def rfc6979_k(d, z):
    """RFC 6979 §3.2 with HMAC-SHA256 (qlen = hlen = 256)."""
    x = d.to_bytes(32, "big")
    h = (z % N).to_bytes(32, "big")
    v, k = b"\x01" * 32, b"\x00" * 32
    k = hmac.new(k, v + b"\x00" + x + h, hashlib.sha256).digest()
    v = hmac.new(k, v, hashlib.sha256).digest()
    k = hmac.new(k, v + b"\x01" + x + h, hashlib.sha256).digest()
    v = hmac.new(k, v, hashlib.sha256).digest()
    while True:
        v = hmac.new(k, v, hashlib.sha256).digest()
        t = int.from_bytes(v, "big")
        if 1 <= t < N:
            return t
        k = hmac.new(k, v + b"\x00", hashlib.sha256).digest()
        v = hmac.new(k, v, hashlib.sha256).digest()


def der_int(i):
    b = i.to_bytes((i.bit_length() + 7) // 8 or 1, "big")
    if b[0] & 0x80:
        b = b"\x00" + b
    return b"\x02" + bytes([len(b)]) + b


def sign(d, digest, hashtype=0x41):
    """ECDSA over the 32-byte digest (its bytes read big-endian, as secp256k1_ecdsa_sign reads them), low S."""
    z = int.from_bytes(digest, "big")
    k = rfc6979_k(d, z)
    r = ec_mul(k)[0] % N
    s = pow(k, -1, N) * (z + r * d) % N
    if s > N // 2:
        s = N - s
    body = der_int(r) + der_int(s)
    return b"\x30" + bytes([len(body)]) + body + bytes([hashtype])


def sha256(b):
    return hashlib.sha256(b).digest()


def hash256(b):
    return sha256(sha256(b))


def hash160(b):
    return hashlib.new("ripemd160", sha256(b)).digest()


def key(label):
    return int.from_bytes(sha256(("xsig-144/" + label).encode()), "big") % N


# script
OP_0, OP_PUSHDATA1, OP_PUSHDATA2, OP_1 = 0x00, 0x4C, 0x4D, 0x51
OP_IF, OP_ENDIF, OP_DUP, OP_NIP, OP_OVER, OP_SWAP = 0x63, 0x68, 0x76, 0x77, 0x78, 0x7C
OP_CAT, OP_SPLIT, OP_NUM2BIN, OP_BIN2NUM, OP_SIZE = 0x7E, 0x7F, 0x80, 0x81, 0x82
OP_EQUALVERIFY, OP_ADD, OP_SUB, OP_MOD = 0x88, 0x93, 0x94, 0x97
OP_HASH160, OP_HASH256, OP_CODESEPARATOR, OP_CHECKSIG, OP_CHECKSIGVERIFY = 0xA9, 0xAA, 0xAB, 0xAC, 0xAD


def push(b):
    n = len(b)
    if n < OP_PUSHDATA1:
        return bytes([n]) + b
    if n <= 0xFF:
        return bytes([OP_PUSHDATA1, n]) + b
    return bytes([OP_PUSHDATA2]) + n.to_bytes(2, "little") + b


def scriptnum(i):
    """The minimal script number of a non-negative integer."""
    if i == 0:
        return b""
    b = i.to_bytes((i.bit_length() + 7) // 8, "little")
    return b + b"\x00" if b[-1] & 0x80 else b


def reverse(n):
    """Reverse the top element of exactly n bytes: n-1 one-byte splits, then n-1 swap-cats."""
    return bytes([OP_1, OP_SPLIT] * (n - 1) + [OP_SWAP, OP_CAT] * (n - 1))


def preimage_signer():
    """P -> DER(r = Gx, s = (z + Gx) mod n) ++ 0x41, z = hash256(P) read big-endian: the k = 1, d = 1 signature."""
    r = GX.to_bytes(32, "big")
    return (bytes([OP_HASH256]) + reverse(32) + push(b"\x00") + bytes([OP_CAT, OP_BIN2NUM])
            + push(scriptnum(GX)) + bytes([OP_ADD]) + push(scriptnum(N)) + bytes([OP_MOD])
            + bytes([OP_SIZE, OP_SWAP]) + push(scriptnum(33)) + bytes([OP_NUM2BIN]) + reverse(33)
            + bytes([OP_OVER]) + push(scriptnum(33)) + bytes([OP_SWAP, OP_SUB, OP_SPLIT, OP_NIP])
            + bytes([OP_OVER, OP_SWAP, OP_CAT]) + push(b"\x02") + bytes([OP_SWAP, OP_CAT])
            + push(b"\x02\x20" + r) + bytes([OP_SWAP, OP_CAT])
            + bytes([OP_SWAP]) + push(scriptnum(36)) + bytes([OP_ADD, OP_SWAP, OP_CAT])
            + push(b"\x30") + bytes([OP_SWAP, OP_CAT]) + push(b"\x41") + bytes([OP_CAT]))


def p2pkh(pub):
    return bytes([OP_DUP, OP_HASH160]) + push(hash160(pub)) + bytes([OP_EQUALVERIFY, OP_CHECKSIG])


# transactions
def varint(n):
    if n < 0xFD:
        return bytes([n])
    if n <= 0xFFFF:
        return b"\xfd" + n.to_bytes(2, "little")
    return b"\xfe" + n.to_bytes(4, "little")


def ser_tx(version, ins, outs, locktime=0):
    """ins: [(txid_hex, vout, script_sig, sequence)]; outs: [(sats, script)]."""
    b = version.to_bytes(4, "little") + varint(len(ins))
    for txid, vout, ss, seq in ins:
        b += bytes.fromhex(txid)[::-1] + vout.to_bytes(4, "little") + varint(len(ss)) + ss + seq.to_bytes(4, "little")
    b += varint(len(outs))
    for sats, spk in outs:
        b += sats.to_bytes(8, "little") + varint(len(spk)) + spk
    return b + locktime.to_bytes(4, "little")


def txid_of(raw):
    return hash256(raw)[::-1].hex()


def bip143(version, ins, outs, i, script_code, sats, hashtype=0x41, locktime=0):
    """SignatureHashBIP143's preimage (interpreter.cpp:2034-2083) for ALL|FORKID."""
    prevouts = b"".join(bytes.fromhex(t)[::-1] + v.to_bytes(4, "little") for t, v, _, _ in ins)
    seqs = b"".join(s.to_bytes(4, "little") for _, _, _, s in ins)
    outb = b"".join(s.to_bytes(8, "little") + varint(len(p)) + p for s, p in outs)
    t, v, _, s = ins[i]
    return (version.to_bytes(4, "little") + hash256(prevouts) + hash256(seqs) + bytes.fromhex(t)[::-1]
            + v.to_bytes(4, "little") + varint(len(script_code)) + script_code + sats.to_bytes(8, "little")
            + s.to_bytes(4, "little") + hash256(outb) + locktime.to_bytes(4, "little") + hashtype.to_bytes(4, "little"))


# the node
def free_pair():
    for port in range(18571, 18590, 2):
        ok = True
        for p in (port, port + 1):
            with socket.socket() as s:
                try:
                    s.bind(("127.0.0.1", p))
                except OSError:
                    ok = False
        if ok:
            return port
    sys.exit("no free RPC/P2P pair in 18571..18590")


class Node:
    def __init__(self, datadir, port):
        self.datadir, self.port = datadir, port
        conf = (ROOT / "harness/oracle/bitcoin.conf").read_text()
        conf = conf.replace("genesisactivationheight=620538", f"genesisactivationheight={GENESIS_HEIGHT}")
        conf = conf.replace("chronicleactivationheight=943816", f"chronicleactivationheight={CHRONICLE_HEIGHT}")
        if f"chronicleactivationheight={CHRONICLE_HEIGHT}" not in conf:
            sys.exit("harness/oracle/bitcoin.conf no longer carries the two activation lines this script replaces")
        # the grace periods (init.cpp:3244-3263, protocol_era.cpp:106-127) at 0: with both activations a few blocks
        # apart, the mempool's diagnosis of a failed script inside a grace period asks GetInverseProtocolEra of an era
        # that has none (validation.cpp:2768-2770, protocol_era.cpp:49-86) and the reply is that exception, not the
        # script's error; the verdict is the same refusal, the reason becomes the script's
        conf += "maxgenesisgracefulperiod=0\nmaxchroniclegracefulperiod=0\n"
        datadir.mkdir(parents=True)
        (datadir / "bitcoin.conf").write_text(conf)
        self.proc = subprocess.Popen(
            [str(BITCOIND), "-regtest", f"-conf={datadir / 'bitcoin.conf'}", f"-datadir={datadir}",
             f"-rpcport={port}", f"-port={port + 1}"],
            stdout=subprocess.DEVNULL, stderr=open(datadir / "bitcoind.err", "w"), start_new_session=True)
        for _ in range(120):
            try:
                self.call("getblockcount")
                return
            except (OSError, RuntimeError, ValueError):
                time.sleep(1)
        sys.exit(f"the node did not answer within 120 s; its stderr is {datadir / 'bitcoind.err'}")

    def call(self, method, *params):
        cookie = (self.datadir / "regtest" / ".cookie").read_text().strip()
        c = http.client.HTTPConnection("127.0.0.1", self.port, timeout=600)
        body = json.dumps({"jsonrpc": "1.0", "id": method, "method": method, "params": list(params)})
        c.request("POST", "/", body, {"Authorization": "Basic " + base64.b64encode(cookie.encode()).decode(),
                                      "Content-Type": "application/json"})
        r = json.loads(c.getresponse().read())
        if r.get("error"):
            raise RuntimeError(json.dumps(r["error"]))
        return r["result"]

    def submit(self, raw):
        """sendrawtransaction; the verdict fields only: accepted, or the error code and message."""
        try:
            self.call("sendrawtransaction", raw.hex())
            return {"verdict": "accepted"}
        except RuntimeError as e:
            err = json.loads(str(e))
            return {"verdict": "rejected", "code": err.get("code"), "message": err.get("message")}

    def stop(self):
        try:
            self.call("stop")
        except (OSError, RuntimeError, ValueError):
            pass
        try:
            self.proc.wait(timeout=120)
        except subprocess.TimeoutExpired:
            self.proc.kill()
            self.proc.wait()


def helper(cmd, req):
    out = subprocess.run(cmd, input=json.dumps(req), capture_output=True, text=True, check=False)
    if out.returncode != 0:
        sys.exit(f"{cmd[0]} failed: {out.stderr.strip()}")
    return json.loads(out.stdout)


def node_bin():
    return os.environ.get("NODE_BIN") or subprocess.run([str(ROOT / "tools/node_bin.sh")], capture_output=True,
                                                         text=True, check=True).stdout.strip()


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out")
    ap.add_argument("--corpus")
    ap.add_argument("--manifest", action="store_true")
    ap.add_argument("--shape", choices=["AB", "C"], default="AB",
                    help="AB: shapes A and B and the era rows (#144); C: the reader's minimal example alone (#147)")
    ap.add_argument("--append", action="store_true",
                    help="with --corpus: keep the corpus's rows and append the witness's spends after them")
    args = ap.parse_args()
    if args.manifest:
        restamp_manifest()
        return
    if args.corpus:
        write_corpus(json.loads(Path(args.corpus).read_text()), args.append)
        return
    if not args.out:
        sys.exit("--out <witness.json> or --corpus <witness.json>")
    for p in (BITCOIND, GOSIGN, TSSIGN) if args.shape == "AB" else (BITCOIND,):
        if not p.exists():
            sys.exit(f"missing {p} (the go helper: cd tools/xsig/gosign && go build -o {GOSIGN} .)")
    nodejs = node_bin() if args.shape == "AB" else None

    d_fund, d_utxo, d_k0 = key("funder"), key("utxo"), key("secret0")
    pub_fund, pub_utxo, pub0 = pub_of(d_fund), pub_of(d_utxo), pub_of(d_k0)
    g_pub = pub_of(1)
    lock_fund = p2pkh(pub_fund)
    lock_a = push(pub_utxo) + bytes([OP_CHECKSIG])
    lock_b = p2pkh(pub_utxo)
    check_a = push(pub0) + bytes([OP_CHECKSIGVERIFY])
    tail_b = bytes([OP_CHECKSIGVERIFY, OP_ENDIF])
    d_c = key("shape-c")
    pub_c, lock_c = pub_of(d_c), bytes([OP_1])
    addr_payload = b"\x6f" + hash160(pub_fund)
    addr = b58check(addr_payload)

    port = free_pair()
    datadir = Path(os.environ.get("TMPDIR") or ROOT / "scratch") / f"xsig-node-{port}"
    if datadir.exists():
        shutil.rmtree(datadir)
    node = Node(datadir, port)
    rec = {"instance": {"binary": str(BITCOIND).replace(str(Path.home()), "~"), "rpc_port": port,
                        "genesisactivationheight": GENESIS_HEIGHT, "chronicleactivationheight": CHRONICLE_HEIGHT,
                        "maxgenesisgracefulperiod": 0, "maxchroniclegracefulperiod": 0,
                        "version": node.call("getnetworkinfo")["subversion"]},
           "keys": "sha256('xsig-144/' + label) mod n: funder, utxo, secret0, shape-c; shape B's in-script key is d = 1",
           "checks": [], "spends": []}
    try:
        cb = node.call("generatetoaddress", 101, addr)
        coinbases = []
        for h in cb[:3]:
            blk = node.call("getblock", h, 2)
            t = blk["tx"][0]
            coinbases.append((t["txid"], int(round(t["vout"][0]["value"] * 1e8)), blk["height"]))

        def fund(cbi, locks):
            txid, sats, _ = coinbases[cbi]
            outs = [(COIN_SATS, lk) for lk in locks]
            outs.append((sats - COIN_SATS * len(locks) - 10 * FEE, lock_fund))
            ins = [(txid, 0, b"", 0xFFFFFFFF)]
            sig = sign(d_fund, hash256(bip143(2, ins, outs, 0, lock_fund, sats)))
            raw = ser_tx(2, [(txid, 0, push(sig) + push(pub_fund), 0xFFFFFFFF)], outs)
            v = node.submit(raw)
            if v["verdict"] != "accepted":
                sys.exit(f"funding refused: {v}")
            node.call("generatetoaddress", 1, addr)
            return txid_of(raw), raw, node.call("getblockcount")

        def spend_tx(coin, script_sig):
            ins = [(coin["txid"], coin["vout"], script_sig, 0xFFFFFFFF)]
            return ser_tx(2, ins, [(COIN_SATS - FEE, lock_fund)])

        def preimage(coin, script_code):
            ins = [(coin["txid"], coin["vout"], b"", 0xFFFFFFFF)]
            return bip143(2, ins, [(COIN_SATS - FEE, lock_fund)], 0, script_code, COIN_SATS)

        def coin_of(fund_txid, fund_raw, height, vout, lock):
            return {"txid": fund_txid, "vout": vout, "script": lock.hex(), "satoshis": COIN_SATS, "height": height,
                    "funding_tx": fund_raw.hex()}

        def unlock_a(coin, sig0):
            utxo_sig = sign(d_utxo, hash256(preimage(coin, lock_a)))
            return push(utxo_sig) + push(sig0) + bytes([OP_CODESEPARATOR]) + check_a

        def unlock_b(coin, pre):
            utxo_sig = sign(d_utxo, hash256(preimage(coin, lock_b)))
            return (push(utxo_sig) + push(pub_utxo) + push(pre) + bytes([OP_1, OP_IF]) + preimage_signer()
                    + push(g_pub) + bytes([OP_CODESEPARATOR]) + tail_b)

        def sdk_sides(coin, script_code):
            unsigned = spend_tx(coin, b"")
            req = {"tx": unsigned.hex(), "input": 0, "lock": coin["script"], "satoshis": COIN_SATS,
                   "key": d_k0.to_bytes(32, "big").hex(), "script_code": script_code.hex(),
                   "source_tx": coin["funding_tx"]}
            return helper([str(GOSIGN)], req), helper([nodejs, str(TSSIGN)], req)

        def submit_all(rows):
            for row in rows:
                row["reference_submit"] = node.submit(bytes.fromhex(row["tx"]))
                row["reference_submit"]["tip_before"] = node.call("getblockcount")
            node.call("generatetoaddress", 1, addr)
            for row in rows:
                if row["reference_submit"]["verdict"] == "accepted":
                    info = node.call("getrawtransaction", row["txid"], 1)
                    row["reference_submit"]["blockhash"] = info.get("blockhash")
                    row["reference_submit"]["confirmations"] = info.get("confirmations")
                    row["reference_submit"]["height"] = node.call("getblockheader", info["blockhash"])["height"]
            rec["spends"].extend(rows)

        if args.shape == "C":
            # shape C, the reader's minimal example (#147 item 2): lock OP_1; unlock <sig> <pub> OP_CODESEPARATOR
            # OP_CHECKSIGVERIFY; ALL|FORKID. The reference's scriptCode for that CHECKSIGVERIFY is the unlock from its last
            # OP_CODESEPARATOR, `ad`, with the lock `51` appended under SCRIPT_CHRONICLE only: `ad51` after Chronicle, `ad`
            # before (interpreter.cpp:1474-1481). Each spend signed over each of the two, one coin per spend.
            sc_both, sc_unlock = bytes([OP_CHECKSIGVERIFY]) + lock_c, bytes([OP_CHECKSIGVERIFY])

            def rows_c(fund_txid, fund_raw, fund_h, era, signings):
                rows = []
                for vout, (label, method, signed_over) in enumerate(signings):
                    coin = coin_of(fund_txid, fund_raw, fund_h, vout, lock_c)
                    sig = sign(d_c, hash256(preimage(coin, signed_over)))
                    raw = spend_tx(coin, push(sig) + push(pub_c) + bytes([OP_CODESEPARATOR, OP_CHECKSIGVERIFY]))
                    rows.append({"shape": "C", "label": label, "method": method, "era": era, "coin": coin,
                                 "script_code": (sc_both if era == "post-chronicle" else sc_unlock).hex(),
                                 "signed_over": signed_over.hex(), "tx": raw.hex(), "txid": txid_of(raw)})
                return rows

            # before Genesis (tip 102, the next block 103 < GENESIS_HEIGHT)
            submit_all(rows_c(*fund(0, [lock_c, lock_c]), "pre-genesis",
                              [("c3", "c3:pre-genesis/signed-over-ad51", sc_both),
                               ("c4", "c4:pre-genesis/signed-over-ad", sc_unlock)]))
            # past Chronicle: the coins mined after the activation height, then the two spends
            node.call("generatetoaddress", CHRONICLE_HEIGHT + 1 - node.call("getblockcount"), addr)
            submit_all(rows_c(*fund(1, [lock_c, lock_c]), "post-chronicle",
                              [("c1", "c1:post-chronicle/signed-over-ad51", sc_both),
                               ("c2", "c2:post-chronicle/signed-over-ad", sc_unlock)]))
            rec["spends"].sort(key=lambda r: r["label"])
        else:
            # the era rows of shape A: before Genesis (tip 102, the next block 103 < GENESIS_HEIGHT)
            f1_txid, f1_raw, f1_h = fund(0, [lock_a, lock_a])
            rows = []
            for vout, (name, sc) in enumerate([("pre-genesis/unlock-only", check_a),
                                               ("pre-genesis/unlock+lock", check_a + lock_a)]):
                coin = coin_of(f1_txid, f1_raw, f1_h, vout, lock_a)
                raw = spend_tx(coin, unlock_a(coin, sign(d_k0, hash256(preimage(coin, sc)))))
                rows.append({"shape": "A", "method": name, "era": "pre-genesis", "coin": coin, "script_code": sc.hex(),
                             "tx": raw.hex(), "txid": txid_of(raw)})
            submit_all(rows)
            # after Genesis, before Chronicle
            node.call("generatetoaddress", GENESIS_HEIGHT + 5 - node.call("getblockcount"), addr)
            f2_txid, f2_raw, f2_h = fund(1, [lock_a, lock_a])
            rows = []
            for vout, (name, sc) in enumerate([("pre-chronicle/unlock-only", check_a),
                                               ("pre-chronicle/unlock+lock", check_a + lock_a)]):
                coin = coin_of(f2_txid, f2_raw, f2_h, vout, lock_a)
                raw = spend_tx(coin, unlock_a(coin, sign(d_k0, hash256(preimage(coin, sc)))))
                rows.append({"shape": "A", "method": name, "era": "post-genesis-pre-chronicle", "coin": coin,
                             "script_code": sc.hex(), "tx": raw.hex(), "txid": txid_of(raw)})
            submit_all(rows)
            # past Chronicle: the coins mined after the activation height, then the eight spends
            node.call("generatetoaddress", CHRONICLE_HEIGHT + 1 - node.call("getblockcount"), addr)
            f3_txid, f3_raw, f3_h = fund(2, [lock_a] * 4 + [lock_b] * 4)
            rows = []
            for shape, base, lock, correct in (("A", 0, lock_a, check_a + lock_a), ("B", 4, lock_b, tail_b + lock_b)):
                for j, method in enumerate(["a:go-sdk-lock-only", "b:ts-sdk-template-lock-only",
                                            "c:correct-scriptcode", "d:ts-sdk-format-correct-subscript"]):
                    coin = coin_of(f3_txid, f3_raw, f3_h, base + j, lock)
                    go, ts = sdk_sides(coin, correct)
                    mine_lock, mine_ok = preimage(coin, lock), preimage(coin, correct)
                    rec["checks"].append({
                        "coin": f"{f3_txid}:{base + j}",
                        "go_preimage_lock_equals_bip143_lock": go["preimage_lock"] == mine_lock.hex(),
                        "ts_preimage_lock_equals_bip143_lock": ts["preimage_lock"] == mine_lock.hex(),
                        "go_preimage_substituted_equals_bip143_correct": go["preimage_sub"] == mine_ok.hex(),
                        "go_sighash_substituted_equals_hash256_correct": go["sighash_sub"] == hash256(mine_ok)[::-1].hex()
                        or go["sighash_sub"] == hash256(mine_ok).hex(),
                        "ts_preimage_sub_equals_bip143_correct": ts["preimage_sub"] == mine_ok.hex(),
                        "ts_template_with_lockingScript_param_equals_sig_sub": ts["template_sig_sub"] == ts["sig_sub"]})
                    if shape == "A":
                        sig0 = {0: bytes.fromhex(go["template_sig"]), 1: bytes.fromhex(ts["template_sig"]),
                                2: sign(d_k0, hash256(mine_ok)), 3: bytes.fromhex(ts["sig_sub"])}[j]
                        ss = unlock_a(coin, sig0)
                    else:
                        pre = {0: bytes.fromhex(go["preimage_lock"]), 1: bytes.fromhex(ts["preimage_lock"]),
                               2: mine_ok, 3: bytes.fromhex(ts["preimage_sub"])}[j]
                        ss = unlock_b(coin, pre)
                    raw = spend_tx(coin, ss)
                    rows.append({"shape": shape, "method": method, "era": "post-chronicle", "coin": coin,
                                 "script_code": correct.hex(), "tx": raw.hex(), "txid": txid_of(raw)})
            submit_all(rows)
        rec["tip"] = node.call("getblockcount")
    finally:
        node.stop()
        shutil.rmtree(datadir, ignore_errors=True)
    rec["instance"]["stopped_and_removed"] = not datadir.exists()
    rec["generated"] = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
    Path(args.out).write_text(json.dumps(rec, indent=1) + "\n")
    for row in rec["spends"]:
        v = row["reference_submit"]
        print(f"{row['shape']} {row['method']:<36} {row['txid']} {v['verdict']} {v.get('height', '')}"
              f" {v.get('code', '')} {v.get('message', '')}")
    for c in rec["checks"]:
        bad = [k for k, ok in c.items() if ok is False]
        print(f"check {c['coin']}: {'all equal' if not bad else 'DIFFER ' + ', '.join(bad)}")


MAINNET_HEIGHT = {"post-chronicle": 967896, "post-genesis-pre-chronicle": 900000, "pre-genesis": 600000}
ERA_LABEL = {"post-chronicle": "post-chronicle", "post-genesis-pre-chronicle": "post-genesis", "pre-genesis": "pre-genesis"}


SHAPE_NOTE = {"A": "P2PK lock, sig0 in the unlock", "B": "P2PKH lock, in-script k=1 OP_PUSH_TX signer",
              "C": "the reader's minimal example of #147: lock OP_1, unlock <sig> <pub> OP_CODESEPARATOR OP_CHECKSIGVERIFY"}


def write_corpus(rec, append=False):
    out = ROOT / "corpus/xsig-144/xsig-144.jsonl"
    man_path = ROOT / "corpus/xsig-144/manifest.json"
    kept = [json.loads(line) for line in out.read_text().splitlines() if line.strip()] if append else []
    rows = []
    for i, sp in enumerate(rec["spends"], len(kept) + 1):
        h = MAINNET_HEIGHT[sp["era"]]
        v = sp["reference_submit"]
        chain = (f"accepted, mined at regtest height {v['height']} in block {v['blockhash']}" if v["verdict"] == "accepted"
                 else f"rejected: {v.get('message', '')}")
        rows.append({
            "id": f"xsig-{i:05d}", "family": f"crypto/checksig-in-unlock/xsig/{sp['shape']}/{sp['method']}",
            "rule": "crypto.checksig.unlock", "tx": sp["tx"],
            "prevouts": [{"txid": sp["coin"]["txid"], "vout": sp["coin"]["vout"], "script": sp["coin"]["script"],
                          "satoshis": sp["coin"]["satoshis"], "height": h}],
            "params": {"spend_height": h, "era": ERA_LABEL[sp["era"]], "consensus": True, "tx_version": 2},
            "expect": {},
            "note": (f"#144 shape {sp['shape']} ({SHAPE_NOTE[sp['shape']]}),"
                     f" signed {sp['method']}{' over ' + sp['signed_over'] if 'signed_over' in sp else ''};"
                     f" the correct scriptCode {sp['script_code']}; on the lane's regtest instance"
                     f" of v1.2.3 (txid {sp['txid']}, the coin at regtest height {sp['coin']['height']}): {chain}")})
    if {r["id"] for r in kept} & {r["id"] for r in rows}:
        sys.exit("an appended id is already in the corpus")
    body = "".join(json.dumps(r, separators=(",", ":")) + "\n" for r in rows)
    if append:
        body = out.read_text() + body
        rows = kept + rows
    out.write_text(body)
    fam, rules = {}, {}
    for r in rows:
        fam[r["family"]] = fam.get(r["family"], 0) + 1
        rules[r["rule"]] = rules.get(r["rule"], 0) + 1
    man = {"corpus": "xsig-144", "file": "xsig-144.jsonl",
           "generator": "tools/xsig_witness.py (#144, lane xsig-144): the witness on a fresh regtest instance of v1.2.3, signed by go-sdk v1.7.2, @bsv/sdk 3.0.0 and by hand",
           "seed": "the keys are sha256('xsig-144/' + label); shape B's in-script key is d = 1",
           "count": len(rows), "sha256": hashlib.sha256(body.encode()).hexdigest(), "families": fam, "rules": rules,
           "verdicts": {}, "implementations": [], "engine_executions": 0,
           "generated": rec.get("generated", ""), "provenance": "docs/records/*-s4b-144-checksig-in-unlock-signers-s4b.md"}
    if append:
        # the kept rows' recorded keys stay in the entries; the runners' --record and --manifest re-stamp the rest
        old = json.loads(man_path.read_text())
        old.update({k: man[k] for k in ("count", "sha256", "families", "rules")})
        if rec.get("generated"):
            old["generated_appended"] = rec["generated"]
        man = old
    man_path.write_text(json.dumps(man, indent=2, ensure_ascii=False) + "\n")
    print(f"{out.relative_to(ROOT)}: {len(rows)} entries, sha256 {man['sha256']}")


GOSDK_ADAPTER = "gosdk-runner (bsv-script-lean #29) go-sdk v1.7.2 (docs/PROVENANCE.md §1a)"
TSSDK_ADAPTER = "tssdk-runner (bsv-script-lean #29) @bsv/sdk 3.0.0 on node v22 (docs/PROVENANCE.md §1a)"
WORD_MODE = ("under the reference's flag word of the entry's own params (the block word unless the entry gives one), "
             "the word asked of eval/bsvs (Params.derive), one run per input")
MEMPOOL_MODE = "under the mempool word of the same configuration (Params.derive with consensus = false)"


def restamp_manifest():
    """The implementations whose keys the runners recorded into the entries, the sha256 and the reference's verdicts."""
    path = ROOT / "corpus/xsig-144/manifest.json"
    man = json.loads(path.read_text())
    body = (ROOT / "corpus/xsig-144" / man["file"]).read_bytes()
    entries = [json.loads(line) for line in body.decode().splitlines() if line.strip()]
    keys = sorted({k for e in entries for k in e["expect"]})
    conf = {
        "bsv-rs": {"memory_limit": 32000000, "require_push_only": True, "words": "per-input",
                   "mode": "the reference's word per input from the entry's spend height and the coin's height (engine::word_for: the block word of the spend's era when params.consensus, the standard word otherwise, the coin's Chronicle marker by the coin's era; a pre-Genesis spend or coin is not applicable = undecided), the transaction's own version"},
        "go-sdk": {"adapter": GOSDK_ADAPTER, "mode": WORD_MODE},
        "go-sdk-mempool": {"adapter": GOSDK_ADAPTER, "mode": MEMPOOL_MODE},
        "ts-sdk": {"adapter": TSSDK_ADAPTER, "mode": WORD_MODE},
        "ts-sdk-mempool": {"adapter": TSSDK_ADAPTER, "mode": MEMPOOL_MODE},
        "ts-sdk-default": {"adapter": TSSDK_ADAPTER, "mode": "the SDK's default mode: no explicit word, its own derivation from the transaction version (Spend.ts #isRelaxed = version > 1)"},
        "sv-node": {"configuration": "harness/oracle/bitcoin.conf: mainnet activation heights, every policy setting zeroed (the consensus limits on the policy path, Q6), a fresh instance of the lane's on a port of 18571..18590, stopped and removed after the run",
                    "mode": "the verifyscript RPC under the reference's flag word of the entry's own params, the word asked of eval/bsvs (Params.derive); txo.height = the prevout's",
                    "node": "subversion /Bitcoin SV:1.2.3/; version 101020300"},
        "sv-node-mempool": {"configuration": "the SAME zeroed instance (run_svnode without --rpc-mempool): the mempool word under the consensus limits, not the node's default policy caps",
                            "mode": "the verifyscript RPC under the mempool word (Params.derive with consensus = false)",
                            "node": "subversion /Bitcoin SV:1.2.3/; version 101020300"},
    }
    impls = []
    for k in keys:
        name, version = k.rsplit("@", 1)
        if name.startswith("spec"):
            path_txt = "the mempool word of the same configuration" if name.endswith("-mempool") else "the entry's params (consensus = the block path)"
            impls.append({"name": name, "version": version, "config": {"config": "sv-mainnet-default", "path": path_txt}})
        elif name in conf:
            impls.append({"name": name, "version": version, "config": conf[name]})
        else:
            sys.exit(f"a recorded key without a configuration here: {k}")
    if not any(i["name"] == "bsv-rs" for i in impls):
        pin = re.search(r'BSV_RS_VERSION: &str = "([^"]+)"', (ROOT / "harness/src/lib.rs").read_text()).group(1)
        impls.insert(0, {"name": "bsv-rs", "version": pin, "config": conf["bsv-rs"]})
    verdicts = {}
    for e in entries:
        v = e["expect"].get("sv-node@v1.2.3", {}).get("verdict", "unrecorded")
        verdicts[v] = verdicts.get(v, 0) + 1
    man.update({"sha256": hashlib.sha256(body).hexdigest(), "count": len(entries), "verdicts": verdicts,
                "implementations": impls, "engine_executions": len(entries) * len(impls)})
    path.write_text(json.dumps(man, indent=2, ensure_ascii=False) + "\n")
    print(f"{path.relative_to(ROOT)}: sha256 {man['sha256']}, {len(impls)} implementations, verdicts {verdicts}")


def b58check(payload):
    alphabet = "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz"
    b = payload + hash256(payload)[:4]
    n = int.from_bytes(b, "big")
    s = ""
    while n:
        n, r = divmod(n, 58)
        s = alphabet[r] + s
    return "1" * (len(b) - len(b.lstrip(b"\x00"))) + s


if __name__ == "__main__":
    main()
