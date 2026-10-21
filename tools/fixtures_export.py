#!/usr/bin/env python3
"""fixtures_export (#146): the corpus as the SDKs' own fixture files.

Renders, from the corpora the engines already run, the files each SDK's own test
loader reads. [SRC] Go shapes follow go-sdk v1.7.2; TypeScript shapes follow
conformance/runner/ts/dispatchers/sdkHelpers.ts:613-782 and runner.test.ts:29-43,70-148
at ts-stack 4d0ea63c (git show, never the working tree). The record
`docs/records/20261016-192742-s3-146-fixtures-export-s3.md` section 1 cites every
field by file and line:

  corpus/fixtures/go-sdk/node_vectors.json  go-sdk v1.7.2 `TestNodeVectors`
      (script/interpreter/node_vectors_test.go:25-43, read at :101-114): one vector
      per spend with the node's verdict for the block word (`consensus` true) and
      the relay word (false); the record in `source` (decoded at :35, never asserted).
  corpus/fixtures/go-sdk/script_tests.json  go-sdk v1.7.2 `TestScripts`
      (script/interpreter/reference_test.go:150-201, run at :435-528): the
      single-input spends whose scripts run no signature or lock-time opcode, so the
      loader's synthetic spending transaction (:397-429) decides them as the real one
      did; the record in the comment string (the test's name only, :195-196).
  corpus/fixtures/go-sdk/evaluation.json  go-sdk v1.7.2 `TestEvaluation`'s
      conformance file (internal/conformance/vectors.go:26-48) with `node-sighash`
      rows (evaluation_conformance_test.go:521-591).
  corpus/fixtures/ts-sdk/evaluation.json  ts-stack's conformance file for @bsv/sdk
      3.0.0 (`sdkHelpers.ts`'s dispatchers; the keys are the ones ts-stack's own
      vectors carry): `node-transaction` rows (block and relay word each) and the
      same `node-sighash` rows.
  corpus/fixtures/go-sdk/signer/node_vectors.json and ts-sdk/signer/evaluation.json
      the hand-signed signer corpus and the SDK transactions refused in #145's
      column, in the same transaction shapes (tools/fixtures_signer.py).
  corpus/fixtures/bsv-rs/sighash.json       bsv-rs v0.7.0's `test_sighash_vectors` file shape
      (tests/sighash_tests.rs:9-22, run at :24-135): the node's own sighash table at the pin
      (corpus/sighash/bitcoin-sv-v1.2.3-sighash.json), the rows whose regular digest is BIP143, each
      reconstructed and compared with the node's digest before it is written.
  corpus/fixtures/bsv-rs/findings.json      the same shape for the signer sites of #145 and #147's bsv-rs column at
      the pin 0.7.0 an SDK signed over another scriptCode: the node's scriptCode and the generator's BIP143 digest
      over it at amount 0, the class and the record as fields the loader skips. The record `docs/records/20261018-000137-s3-146-fixtures-bsvrs-s3.md` cites the shape.
  corpus/fixtures/manifest.json             the files, their row counts and sha256,
      the sources and the exclusions by reason.

[X] Transaction and script fixtures carry the recorded bitcoin-sv v1.2.3 block
or relay verdict and its manifest entry. The five node-sighash rows in each
evaluation file carry digests reconstructed by fixtures_export, verified against
the mined signatures, and replayed through the pinned SDKs; they do not claim a
v1.2.3 verifyscript measurement.

Sources: corpus/seed/seed.jsonl, corpus/crypto/cases.jsonl, corpus/xsig-144/xsig-144.jsonl
(#144's spends, when the tree has them), corpus/witnesses/<engine>/*.jsonl, and
corpus/sighash/mainnet.jsonl, and corpus/signer/*.jsonl. The signer source records,
regeneration inputs and nonzero-amount shape limits are in corpus/fixtures/README.md.
The node's verdict of record is the corpus key
`sv-node@v1.2.3` (block word) and `sv-node-mempool@v1.2.3` (relay word); the word is
the one the node was asked under, read from the manifests' `words`. Withheld by
construction: every entry named in tools/export_withheld_entries.txt, every spend
whose transaction equals one of those, and every witness of a class named in
tools/export_withheld_rules.txt (rule 14).

Run from anywhere: tools/fixtures_export.py [--root DIR] [--check]
  --check   regenerate into a scratch directory and compare byte for byte.
"""
import collections, glob, hashlib, json, os, re, shutil, sys, tempfile

TOOLS = os.path.dirname(os.path.abspath(__file__))
sys.dont_write_bytecode = True
sys.path.insert(0, TOOLS)
from export_public import load_withheld, load_withheld_entries, load_withheld_rules, group_of  # noqa: E402

NODE = 'sv-node@v1.2.3'
NODE_MEMPOOL = 'sv-node-mempool@v1.2.3'
NODE_NAME = 'bitcoin-sv v1.2.3 (6504a3af)'
# the record of the run that measured each corpus's node keys: the node's manifest entry for the corpus
# (its node, settings and date); #144's spends add the lane's own record
NODE_MANIFEST = 'corpus/witnesses/sv-node/manifest.json'
RECORDS = {'xsig-144': 'docs/records/20261016-185844-s4b-144-checksig-in-unlock-signers-s4b.md'}
MAINNET_RECORD = 'docs/records/20261016-192742-s3-146-fixtures-export-s3.md section 3 (go-sdk v1.7.2 and @bsv/sdk 3.0.0: five node-sighash rows agree)'
ENGINES = ('go-sdk', 'ts-sdk')
# go-sdk v1.7.2 node_vectors.json's own comment: rows over 100,000 hex characters are left out
MAX_TX_HEX = 100_000
JS_MAX_SAFE = 2**53 - 1

# [SRC] bitcoin-sv 6504a3af src/script/script_flags.h:17-111; go-sdk v1.7.2 node_vectors_test.go:47-66
# maps exactly these bits; reference_test.go:217-272 and helpers_conformance_test.go:84-112 read these names.
FLAG_BITS = [(0, 'P2SH'), (1, 'STRICTENC'), (2, 'DERSIG'), (3, 'LOW_S'), (4, 'NULLDUMMY'),
             (5, 'SIGPUSHONLY'), (6, 'MINIMALDATA'), (7, 'DISCOURAGE_UPGRADABLE_NOPS'), (8, 'CLEANSTACK'),
             (9, 'CHECKLOCKTIMEVERIFY'), (10, 'CHECKSEQUENCEVERIFY'), (13, 'MINIMALIF'), (14, 'NULLFAIL'),
             (16, 'SIGHASH_FORKID'), (18, 'GENESIS'), (19, 'UTXO_AFTER_GENESIS'), (20, 'CHRONICLE'),
             (21, 'UTXO_AFTER_CHRONICLE')]
KNOWN_BITS = sum(1 << b for b, _ in FLAG_BITS)

# [SRC] bitcoin-sv 6504a3af src/test/script_tests.cpp:59-103 (the names script_tests.json uses)
REF_ERROR_NAMES = {'SCRIPT_ERR_INVALID_OPERAND_SIZE': 'OPERAND_SIZE', 'SCRIPT_ERR_INVALID_SPLIT_RANGE': 'SPLIT_RANGE',
                   'SCRIPT_ERR_SIG_NULLFAIL': 'NULLFAIL', 'SCRIPT_ERR_MUST_USE_FORKID': 'MISSING_FORKID'}
# [SRC] go-sdk v1.7.2 script/interpreter/reference_test.go:275-390: every name parseExpectedResult accepts
GO_RESULTS = set('''OK INVALID_NUMBER_RANGE SPLIT_RANGE OPERAND_SIZE PUBKEYTYPE SIG_DER EVAL_FALSE EQUALVERIFY NULLFAIL
SIG_HIGH_S SIG_HASHTYPE ILLEGAL_CHRONICLE MISSING_FORKID MUST_USE_FORKID BIG_INT INVALID_FLAGS IMPOSSIBLE_ENCODING
CHECKMULTISIGVERIFY NUMEQUALVERIFY NONCOMPRESSED_PUBKEY UNKNOWN_ERROR SIG_NULLDUMMY SIG_PUSHONLY CLEANSTACK BAD_OPCODE
UNBALANCED_CONDITIONAL OP_RETURN VERIFY INVALID_STACK_OPERATION INVALID_ALTSTACK_OPERATION DISABLED_OPCODE
DISCOURAGE_UPGRADABLE_NOPS SCRIPTNUM_OVERFLOW NUMBER_SIZE PUSH_SIZE OP_COUNT STACK_SIZE SCRIPT_SIZE ELEMENT_SIZE
PUBKEY_COUNT SIG_COUNT MINIMALDATA MINIMALIF NEGATIVE_LOCKTIME UNSATISFIED_LOCKTIME SCRIPTNUM_MINENCODE DIV_BY_ZERO
MOD_BY_ZERO CHECKSIGVERIFY ILLEGAL_FORKID'''.split())
# the opcodes whose verdict reads the spending transaction: the signature checks and the lock-time checks
TX_OPS = {0xac, 0xad, 0xae, 0xaf, 0xb1, 0xb2}


def names_of(word):
    return [n for b, n in FLAG_BITS if word >> b & 1]


def ops_of(script):
    """The opcodes of a script outside its pushes; the scan stops at a truncated push."""
    out, i = [], 0
    while i < len(script):
        op = script[i]; i += 1
        n = 0
        if 1 <= op <= 75:
            n = op
        elif op in (76, 77, 78):
            w = {76: 1, 77: 2, 78: 4}[op]
            if i + w > len(script):
                break
            n = int.from_bytes(script[i:i + w], 'little'); i += w
        else:
            out.append(op)
        if i + n > len(script):
            break
        i += n
    return out


# ---- the transaction and the digests (for the mainnet sighash rows) ------------------------------------------

def varint(b, i):
    v = b[i]
    if v < 0xfd:
        return v, i + 1
    w = {0xfd: 2, 0xfe: 4, 0xff: 8}[v]
    return int.from_bytes(b[i + 1:i + 1 + w], 'little'), i + 1 + w


def ser_varint(n):
    if n < 0xfd:
        return bytes([n])
    if n <= 0xffff:
        return b'\xfd' + n.to_bytes(2, 'little')
    if n <= 0xffffffff:
        return b'\xfe' + n.to_bytes(4, 'little')
    return b'\xff' + n.to_bytes(8, 'little')


def parse_tx(raw):
    i = 4
    version = int.from_bytes(raw[:4], 'little')
    n, i = varint(raw, i)
    ins = []
    for _ in range(n):
        prev = raw[i:i + 36]; i += 36
        ln, i = varint(raw, i)
        ins.append([prev, raw[i:i + ln], raw[i + ln:i + ln + 4]]); i += ln + 4
    n, i = varint(raw, i)
    outs = []
    for _ in range(n):
        val = raw[i:i + 8]; i += 8
        ln, i = varint(raw, i)
        outs.append((val, raw[i:i + ln])); i += ln
    lock = raw[i:i + 4]
    assert i + 4 == len(raw), 'trailing bytes'
    return version, ins, outs, lock


def sha256d(b):
    return hashlib.sha256(hashlib.sha256(b).digest()).digest()


def original_digest(raw, index, script_code, hash_type):
    """[SRC] bitcoin-sv 6504a3af interpreter.cpp SignatureHashOriginal for SIGHASH_ALL without ANYONECANPAY (the
    only type the rows carry; asserted): every other input's script emptied, the signed input's set to the
    scriptCode with its OP_CODESEPARATORs removed (none here: asserted), the type appended as four bytes."""
    assert hash_type & 0x1f == 1 and not hash_type & 0x80 and 0xab not in ops_of(script_code)
    version, ins, outs, lock = parse_tx(raw)
    b = version.to_bytes(4, 'little') + ser_varint(len(ins))
    for k, (prev, _, seq) in enumerate(ins):
        s = script_code if k == index else b''
        b += prev + ser_varint(len(s)) + s + seq
    b += ser_varint(len(outs)) + b''.join(v + ser_varint(len(s)) + s for v, s in outs)
    return sha256d(b + lock + (hash_type & 0xffffffff).to_bytes(4, 'little'))


def is_bip143(hash_type):
    """[SRC] bitcoin-sv 6504a3af interpreter.cpp:2112-2124 (`SignatureHash`): BIP143 iff FORKID is enabled (every row
    here) and the type has the FORKID bit (0x40) and not the CHRONICLE bit (0x20); the original digest otherwise."""
    return bool(hash_type & 0x40) and not hash_type & 0x20


def bip143_digest(raw, index, script_code, amount, hash_type):
    """[SRC] bitcoin-sv 6504a3af interpreter.cpp:1960-1982, 2034-2084: the BIP143 preimage (the scriptCode whole,
    hashPrevouts/hashSequence/hashOutputs and their zero cases) under sha256d, in the natural byte order."""
    version, ins, outs, lock = parse_tx(raw)
    acp, base = hash_type & 0x80, hash_type & 0x1f
    zero = bytes(32)
    prevouts = zero if acp else sha256d(b''.join(prev for prev, _, _ in ins))
    sequence = zero if acp or base in (2, 3) else sha256d(b''.join(seq for _, _, seq in ins))
    if base not in (2, 3):
        outputs = sha256d(b''.join(v + ser_varint(len(s)) + s for v, s in outs))
    elif base == 3 and index < len(outs):
        outputs = sha256d(outs[index][0] + ser_varint(len(outs[index][1])) + outs[index][1])
    else:
        outputs = zero
    return sha256d(version.to_bytes(4, 'little') + prevouts + sequence + ins[index][0] + ser_varint(len(script_code)) +
                   script_code + amount.to_bytes(8, 'little') + ins[index][2] + outputs + lock +
                   (hash_type & 0xffffffff).to_bytes(4, 'little'))


# secp256k1, for the check that the digest is the one the mined signature signs
P = 2**256 - 2**32 - 977
N = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141
G = (0x79BE667EF9DCBBAC55A06295CE870B07029BFCDB2DCE28D959F2815B16F81798,
     0x483ADA7726A3C4655DA4FBFC0E1108A8FD17B448A68554199C47D08FFB10D4B8)


def ec_add(a, b):
    if a is None:
        return b
    if b is None:
        return a
    if a[0] == b[0] and (a[1] + b[1]) % P == 0:
        return None
    if a == b:
        m = 3 * a[0] * a[0] * pow(2 * a[1], -1, P)
    else:
        m = (b[1] - a[1]) * pow(b[0] - a[0], -1, P)
    x = (m * m - a[0] - b[0]) % P
    return x, (m * (a[0] - x) - a[1]) % P


def ec_mul(k, pt):
    r = None
    while k:
        if k & 1:
            r = ec_add(r, pt)
        pt = ec_add(pt, pt); k >>= 1
    return r


def pubkey_point(pub):
    if pub[0] == 4:
        return int.from_bytes(pub[1:33], 'big'), int.from_bytes(pub[33:65], 'big')
    x = int.from_bytes(pub[1:33], 'big')
    y = pow((x ** 3 + 7) % P, (P + 1) // 4, P)
    if y & 1 != pub[0] & 1:
        y = P - y
    return x, y


def der_rs(sig):
    assert sig[0] == 0x30 and sig[2] == 2
    lr = sig[3]; r = int.from_bytes(sig[4:4 + lr], 'big')
    assert sig[4 + lr] == 2
    ls = sig[5 + lr]; s = int.from_bytes(sig[6 + lr:6 + lr + ls], 'big')
    return r, s


def ecdsa_verifies(pub, sig_der, digest):
    r, s = der_rs(sig_der)
    z = int.from_bytes(digest, 'big')
    w = pow(s, -1, N)
    pt = ec_add(ec_mul(z * w % N, G), ec_mul(r * w % N, pubkey_point(pub)))
    return pt is not None and pt[0] % N == r


# ---- the sources ---------------------------------------------------------------------------------------------

def read_jsonl(path):
    with open(path, encoding='utf-8') as f:
        return [json.loads(line) for line in f if line.strip()]


class Ctx:
    def __init__(self, root):
        self.root = root
        self.globs = load_withheld(os.path.join(root, 'tools', 'export_withheld.txt'))
        self.entries = load_withheld_entries(os.path.join(root, 'tools', 'export_withheld_entries.txt'))
        self.rules = load_withheld_rules(os.path.join(root, 'tools', 'export_withheld_rules.txt'))
        # the withheld spends' transactions: a row carrying one is withheld wherever it sits
        self.withheld_tx = set()
        for rel, ids in self.entries.items():
            path = os.path.join(root, rel)
            if os.path.isfile(path):
                for e in read_jsonl(path):
                    if e.get('id') in ids and isinstance(e.get('tx'), str):
                        self.withheld_tx.add(e['tx'].lower())
        self.words = {}
        for m in sorted(glob.glob(os.path.join(root, 'corpus', 'witnesses', '*', 'manifest.json'))):
            for corpus, body in json.load(open(m, encoding='utf-8')).items():
                for w in (body.get('words') if isinstance(body, dict) else None) or []:
                    key = (corpus, w['consensus'], w['spend_height'], w['utxo_height'])
                    if self.words.setdefault(key, w['word']) != w['word']:
                        sys.exit(f'fixtures_export: two words for {key} in the manifests')
        self.node_runs = {k: v.get('generated') for k, v in
                          json.load(open(os.path.join(root, NODE_MANIFEST), encoding='utf-8')).items()
                          if isinstance(v, dict) and v.get('node') == NODE}
        for rel in set(RECORDS.values()) | {NODE_MANIFEST}:
            if group_of(self.globs, rel) is not None:
                sys.exit(f'fixtures_export: the record {rel} is withheld from the public edition')

    def withheld(self, rel, entry, engine=None):
        if entry.get('id') in self.entries.get(rel, {}):
            return 'withheld entry'
        if str(entry.get('tx', '')).lower() in self.withheld_tx:
            return 'withheld entry'
        div = entry.get('divergence') or {}
        for path, classes in self.rules.items():
            if div.get('rule') in classes and (engine is None or path == f'harness/rules/{engine}.json'):
                return 'withheld class'
        if group_of(self.globs, rel) is not None:
            return 'withheld path'
        return None


def spend_sources(ctx, engine):
    """[(corpus key, path rel to root, line number, entry)] for one engine's files."""
    out = []
    fixed = [('seed', 'corpus/seed/seed.jsonl'), ('crypto', 'corpus/crypto/cases.jsonl'),
             ('xsig-144', 'corpus/xsig-144/xsig-144.jsonl')]
    for key, rel in fixed:
        if os.path.isfile(os.path.join(ctx.root, rel)):
            out += [(key, rel, n, e) for n, e in enumerate(read_jsonl(os.path.join(ctx.root, rel)), 1)]
    for path in sorted(glob.glob(os.path.join(ctx.root, 'corpus', 'witnesses', engine, '*.jsonl'))):
        rel = os.path.relpath(path, ctx.root)
        key = os.path.basename(path)[:-len('.jsonl')]
        rows = [(key, rel, n, e) for n, e in enumerate(read_jsonl(path), 1)]
        # a flags-mode witness before a default-mode one of the same spend (the loaders pass flags)
        out += sorted(rows, key=lambda r: '-default@' in str((r[3].get('divergence') or {}).get('b', '')))
    return out


class Tally:
    def __init__(self):
        self.out = {}

    def note(self, file, reason):
        self.out.setdefault(file, {}).setdefault(reason, 0)
        self.out[file][reason] += 1


def node_result(entry, key):
    v = (entry.get('expect') or {}).get(key)
    if not isinstance(v, dict) or v.get('verdict') not in ('valid', 'invalid'):
        return None, 'no node verdict'
    code = v.get('code', '')
    if v['verdict'] == 'invalid' and not code.startswith('SCRIPT_ERR_'):
        return None, 'node verdict not a script error'
    return v, None


def word_of(ctx, corpus, entry, consensus):
    heights = {p.get('height') for p in entry['prevouts']}
    if len(heights) != 1:
        return None, 'inputs of several coin heights (one word per vector)'
    w = ctx.words.get((corpus, consensus, entry['params']['spend_height'], heights.pop()))
    if w is None:
        return None, 'no recorded word'
    if w & ~KNOWN_BITS:
        return None, 'a word bit the loaders do not map'
    return w, None


def source_text(ctx, corpus, rel, entry):
    rec = f'the run of {NODE_MANIFEST} entry "{corpus}" ({ctx.node_runs[corpus]})'
    if corpus in RECORDS:
        rec += f' and {RECORDS[corpus]}'
    return (f'bsv-script-lean {rel} {entry["id"]} ({entry.get("rule", "")}): node verdicts {NODE} and '
            f'{NODE_MEMPOOL} ({NODE_NAME}, verifyscript), measured by {rec}')


def common_skip(ctx, engine, rel, entry):
    why = ctx.withheld(rel, entry, engine)
    if why:
        return why
    tx = entry.get('tx')
    if not isinstance(tx, str) or not re.fullmatch(r'(?:[0-9a-f]{2})+', tx):
        return 'no transaction hex'
    if len(tx) > MAX_TX_HEX:
        return 'over 100,000 hex characters'
    return None


def build_spends(ctx, engine, tally):
    """The vectors of node_vectors.json, the rows of script_tests.json and the node-transaction vectors."""
    nv, st, nt, seen = [], [], [], set()
    for corpus, rel, line, e in spend_sources(ctx, engine):
        why = common_skip(ctx, engine, rel, e) or (None if corpus in ctx.node_runs else 'no v1.2.3 node run of the corpus')
        if why:
            for f in ('node_vectors', 'script_tests', 'evaluation'):
                tally.note(f, why)
            continue
        dedup = (e['tx'], tuple((p['script'], p['satoshis']) for p in e['prevouts']))
        if dedup in seen:
            for f in ('node_vectors', 'script_tests', 'evaluation'):
                tally.note(f, 'the same spend from another source')
            continue
        seen.add(dedup)
        vid = f'bsl:{corpus}:{e["id"]}'
        src = source_text(ctx, corpus, rel, e)
        results = []
        for key, consensus in ((NODE, True), (NODE_MEMPOOL, False)):
            v, why = node_result(e, key)
            w, why2 = (None, None) if v is None else word_of(ctx, corpus, e, consensus)
            if v is None or w is None:
                tally.note('node_vectors', why or why2)
                continue
            results.append((key, consensus, w, v))
        if not results:
            continue
        tx = e['tx']
        nv.append({'id': vid, 'name': f'{e.get("family", "")} {e.get("rule", "")}'.strip(), 'source': src,
                   'tx': tx, 'locks': [p['script'] for p in e['prevouts']],
                   'sats': [p['satoshis'] for p in e['prevouts']],
                   'coinHeights': [p['height'] for p in e['prevouts']], 'spend': e['params']['spend_height'],
                   'results': [{'word': f'0x{w:x}', 'consensus': c, 'valid': v['verdict'] == 'valid',
                                'nodeError': v.get('code', '')} for _, c, w, v in results]})
        # node-transaction (ts-stack's shape), one vector per word
        version, ins, outs, _ = parse_tx(bytes.fromhex(tx))
        big = any(int.from_bytes(v, 'little') > JS_MAX_SAFE for v, _ in outs) or \
            any(p['satoshis'] > JS_MAX_SAFE for p in e['prevouts'])
        if len(e['prevouts']) != len(ins):
            tally.note('evaluation', 'prevouts do not cover the inputs')
        elif big:
            tally.note('evaluation', 'an amount above 2^53-1 (JavaScript)')
        else:
            for key, consensus, w, v in results:
                col = 'block' if consensus else 'relay'
                nt.append({'id': f'{vid}:{col}',
                           'description': f'bsv-script-lean {corpus} {e["id"]}, {col} word 0x{w:x}: {NODE if consensus else NODE_MEMPOOL} says {v["verdict"]}' + (f' ({v["code"]})' if v.get('code') else ''),
                           'input': {'fixture_type': 'node-transaction', 'sources': ['bitcoin-sv'],
                                     'source_file': f'bsv-script-lean:{rel}', 'source_index': line,
                                     'tx_hex': tx,
                                     'prevouts': [{'txid': p['txid'], 'vout': p['vout'], 'script_pubkey_hex': p['script'],
                                                   'amount_satoshis': p['satoshis']} for p in e['prevouts']],
                                     'flag_strings': [','.join(names_of(w))]},
                           'expected': {'valid': v['verdict'] == 'valid'},
                           'tags': ['script', 'evaluation', 'node-fixture', 'bitcoin-sv', 'bsv-script-lean', col,
                                    'valid' if v['verdict'] == 'valid' else 'invalid'],
                           'notes': src})
        # script_tests.json: one input, no opcode that reads the spending transaction
        if len(ins) != 1:
            tally.note('script_tests', 'more than one input')
            continue
        sig, lock = ins[0][1], bytes.fromhex(e['prevouts'][0]['script'])
        if TX_OPS & set(ops_of(sig) + ops_of(lock)):
            tally.note('script_tests', 'a signature or lock-time opcode (the synthetic spend differs)')
            continue
        for key, consensus, w, v in results:
            if not consensus:
                continue  # the loader runs the SDK's default (policy) stack memory limit, so the block word only
            code = v.get('code', '')
            res = 'OK' if v['verdict'] == 'valid' else REF_ERROR_NAMES.get(code, code[len('SCRIPT_ERR_'):])
            if res not in GO_RESULTS:
                tally.note('script_tests', 'a node error name the loader does not read')
                continue
            st.append([[e['prevouts'][0]['satoshis'] / 1e8], str(version), '0x' + sig.hex() if sig else '',
                       '0x' + lock.hex() if lock else '', ','.join(names_of(w)) or 'NONE', res,
                       f'{vid} block word 0x{w:x}: {src}'])
    return nv, st, nt


def build_sighash(ctx, tally):
    """node-sighash vectors from the mainnet reads whose digest needs no amount (the loader sets the spent
    output's amount to 0, evaluation_conformance_test.go:535), each digest checked against the mined signature."""
    rows = []
    rel = 'corpus/sighash/mainnet.jsonl'
    for line, e in enumerate(read_jsonl(os.path.join(ctx.root, rel)), 1):
        if e['sighash_type'] & 0x40:
            tally.note('sighash', 'a FORKID type: its digest commits to the amount the loader sets to 0')
            continue
        raw = bytes.fromhex(e['tx'])
        script = bytes.fromhex(e['prevout']['script'])
        digest = original_digest(raw, e['input'], script, e['sighash_type'])
        if not ecdsa_verifies(bytes.fromhex(e['pubkey']), bytes.fromhex(e['sig'])[:-1], digest):
            sys.exit(f'fixtures_export: {rel}:{line}: the digest does not verify the mined signature')
        h = digest[::-1].hex()
        rows.append({'id': f'bsl:mainnet:{e["txid"]}:{e["input"]}',
                     'description': f'mainnet {e["txid"]} input {e["input"]}, mined at height {e["height"]}: the digest its signature verifies under',
                     'input': {'fixture_type': 'node-sighash', 'sources': ['bitcoin-sv'],
                               'source_file': f'bsv-script-lean:{rel}', 'source_index': line,
                               'tx_hex': e['tx'], 'script_hex': e['prevout']['script'],
                               'input_index': e['input'], 'hash_type': e['sighash_type']},
                     'expected': {'regular_hash': h, 'original_hash': h},
                     'tags': ['script', 'sighash', 'node-fixture', 'bitcoin-sv', 'bsv-script-lean', 'mainnet'],
                     'notes': (f'bsv-script-lean {rel} line {line}: a mainnet spend mined at height {e["height"]} '
                               f'(read: {e["read"]}); the digest checked by fixtures_export against the '
                               f'transaction\'s own signature and key; {MAINNET_RECORD}')})
    return rows


# ---- bsv-rs's own vector format (#146's follow-up) ------------------------------------------------------------
# [SRC] bsv-rs v0.7.0 (5841f98c) tests/sighash_tests.rs:9-22 reads tests/vectors/sighash.json as a list of
# {raw_tx, script, input_index, hash_type (i32, the word cast to u32 at :87), expected_hash}; :91-100 calls
# compute_sighash with satoshis 0 for every vector, and src/primitives/bsv/sighash.rs:929-935 is the BIP143 preimage
# (build_sighash_preimage) under sha256d, reversed (the display order). No deny_unknown_fields (:10-17): serde skips
# a field the struct does not name, which findings.json uses for its provenance.

BSVRS_PIN = 'v0.7.0 (5841f98c)'
NODE_SIGHASH = 'corpus/sighash/bitcoin-sv-v1.2.3-sighash.json'
# #147's bsv-rs column at the pin 0.7.0 (lane repin-148; the same 54 sites as #148's pre-release measurement), and
# #147's column at the pin 0.5.0, read only to count its sites, superseded at 0.7.0 (#148); pinned by hash like
# fixtures_signer's
BSVRS_SIGNER = ('docs/records/20261017-020326-s3-147-signer-column-bsv-rs-s3.json',
                '2416427d7b1b62824aa5cb9b56ce3bb166d3c0f11b4c332fc353ee8f3f645c41')
BSVRS_SIGNER_050 = ('docs/records/20261017-000557-s3-147-signer-column-bsv-rs-s3.json',
                    '5b30a2edbe159a893b688061d79190439d92f371158cfaefead44e6de1400f02')
NOT_FINDING_CONTROL = ('not a finding, under a hand-signed control the node also refuses (not signer disagreements, '
                       'docs/records/20261017-013756-s3-148-measure-bsvrs-main-s3.md:100)')
SUPERSEDED_050 = ('#147\'s bsv-rs 0.5.0 column (docs/records/20261017-000557-s3-147-signer-column-bsv-rs-s3.json), '
                  'superseded at 0.7.0 (#148)')
NOT_BSVRS_ORIGINAL = ('the original digest (no FORKID bit, or the CHRONICLE bit; interpreter.cpp:2112-2124): '
                      'the loader computes BIP143 for every scope (sighash_tests.rs:91-100)')
NOT_BSVRS_AMOUNT = 'a BIP143 digest over a nonzero amount: the loader sets the amount to 0 (sighash_tests.rs:98)'
NOT_BSVRS_ONE = ('SINGLE past the outputs under the original digest: the node signs the constant one '
                 '(interpreter.cpp:2086-2100); the loader computes BIP143 for every scope (sighash_tests.rs:91-100)')
LOCK_ONLY = 'sighash.scriptcode.in-unlock.lock-only'
LOCK_ONLY_DESIGN = ('[SRC] bsv-rs v0.7.0 src/script/template.rs:142 signs over script_code.unwrap_or(locking_script), the '
                    'default None (:103), and the public override SigningContext::with_script_code (:114-117) takes '
                    'the execution-site scriptCode: the class is the caller supplying the scriptCode by design '
                    '(harness/rules/bsv-rs-signer.json ruling caller-scriptcode-required), not a bug of bsv-rs; the node '
                    'selects the scriptCode at bitcoin-sv v1.2.3 interpreter.cpp:1471-1481')


def bsvrs_vector(raw_tx, script, index, hash_type, digest):
    assert -2**31 <= hash_type < 2**31
    return {'raw_tx': raw_tx, 'script': script, 'input_index': index, 'hash_type': hash_type,
            'expected_hash': digest}


def build_bsvrs_sighash(ctx, tally):
    """The node's own sighash table at the pin, the rows whose regular digest is BIP143, each reconstructed and
    compared with the node's column before it is written; the mainnet reads counted by why they cannot ride."""
    table = json.load(open(os.path.join(ctx.root, NODE_SIGHASH), encoding='utf-8'))
    out, rows = [], []
    for k, (tx, script, index, hash_type, regular, _original) in enumerate(table[1:], 1):
        if not is_bip143(hash_type & 0xffffffff):
            tally.note('sighash', 'the node table: ' + NOT_BSVRS_ORIGINAL)
            continue
        mine = bip143_digest(bytes.fromhex(tx), index, bytes.fromhex(script), 0, hash_type & 0xffffffff)[::-1].hex()
        if mine != regular:
            sys.exit(f'fixtures_export: {NODE_SIGHASH} row {k}: the BIP143 reconstruction differs from the node\'s digest')
        out.append(bsvrs_vector(tx, script, index, hash_type, regular))
        rows.append(k)
    for e in read_jsonl(os.path.join(ctx.root, 'corpus/sighash/mainnet.jsonl')):
        tally.note('sighash', 'the mainnet reads: ' + (NOT_BSVRS_AMOUNT if is_bip143(e['sighash_type']) and
                                                         e['prevout']['satoshis'] else NOT_BSVRS_ORIGINAL))
    return out, rows


def build_bsvrs_findings(ctx, tally):
    """One vector per signer site an SDK signed over a scriptCode other than the node's (#145's go-sdk and @bsv/sdk
    columns, #147's bsv-rs column at the pin 0.7.0): the node's scriptCode and the generator's BIP143 digest over it at
    the amount the loader fixes (0), the generator's digest at the row's own amount checked against the control digest
    the node accepted before it. Extra fields carry the class and the record. The sites under a refused control and
    #147's 0.5.0 column are counted, not written."""
    from pathlib import Path
    from fixtures_signer import record
    records = [record(Path(ctx.root), e) for e in ('go-sdk', 'ts-sdk')]

    def pinned(path, digest):
        data = open(os.path.join(ctx.root, path), 'rb').read()
        if hashlib.sha256(data).hexdigest() != digest:
            sys.exit(f'fixtures_export: {path}: record changed')
        return json.loads(data)
    records.append((BSVRS_SIGNER[0], pinned(*BSVRS_SIGNER)))
    rows = {}
    for path in sorted(glob.glob(os.path.join(ctx.root, 'corpus', 'signer', '*.jsonl'))):
        rows.update({e['id']: (os.path.relpath(path, ctx.root), e) for e in read_jsonl(path)})
    def unequal(rec):
        for r in rec['results']:
            for col in r.get('columns', []):
                for inp in col['inputs']:
                    for d in inp['digests']:
                        if not d['equal']:
                            yield r, inp, d
    sites, controls = {}, {}
    for name, rec in records:
        for r, inp, d in unequal(rec):
            if not inp.get('divergent'):
                controls.setdefault((r['id'], inp['index'], d['control']['site']), inp['class'])
    for _, cls in sorted(controls.items()):
        tally.note('findings', f'{NOT_FINDING_CONTROL}: {cls}')
    for name, rec in records:
        for r in rec['results']:
            for col in r.get('columns', []):
                for inp in col['inputs']:
                    if not inp.get('divergent') or not inp.get('class'):
                        continue
                    for d in inp['digests']:
                        if d['equal']:
                            continue
                        s = sites.setdefault((r['id'], inp['index'], d['control']['site']),
                                             {'class': inp['class'], 'control': d['control'], 'sdk': {},
                                              'sdk_digest': {}, 'records': set()})
                        if s['class'] != inp['class'] or s['control'] != d['control']:
                            sys.exit(f'fixtures_export: two classes or controls for the signer site {r["id"]}')
                        key = rec['engine'], d['sdk']['scriptcode_used_hex']
                        s['sdk'].setdefault(key, set()).add(r['method'])
                        s['sdk_digest'][key] = d['sdk']['digest_hex']
                        s['records'].add(name)
    old = {}
    for r, inp, d in unequal(pinned(*BSVRS_SIGNER_050)):
        key = r['id'], inp['index'], d['control']['site']
        if key not in sites and key not in controls:
            old.setdefault(key, (bool(inp.get('divergent')), inp['class']))
    for (rid, index, _), (divergent, cls) in sorted(old.items()):
        e = rows[rid][1]
        if divergent and is_bip143(next(i for i in e['signing']['inputs'] if i['index'] == index)['sighash_type']):
            sys.exit(f'fixtures_export: {rid}: a BIP143 site of the 0.5.0 column absent at 0.7.0')
        tally.note('findings', f'{SUPERSEDED_050}: ' + (f'{cls}, the original digest' if divergent
                                                         else f'under the refused control {cls}, not a finding'))
    out = []
    for (rid, index, site), s in sorted(sites.items()):
        rel, e = rows[rid]
        hash_type = next(i for i in e['signing']['inputs'] if i['index'] == index)['sighash_type']
        if not is_bip143(hash_type):
            tally.note('findings', NOT_BSVRS_ONE if s['class'] == 'sighash.single.out-of-range.one'
                       else NOT_BSVRS_ORIGINAL)
            continue
        raw, amount = bytes.fromhex(e['tx']), e['prevouts'][index]['satoshis']
        code = bytes.fromhex(s['control']['scriptcode_hex'])
        if bip143_digest(raw, index, code, amount, hash_type).hex() != s['control']['digest_hex']:
            sys.exit(f'fixtures_export: {rid} input {index} site {site}: the node\'s digest does not reconstruct')
        for (engine, used), digest in s['sdk_digest'].items():
            if bip143_digest(raw, index, bytes.fromhex(used), amount, hash_type).hex() != digest:
                sys.exit(f'fixtures_export: {rid} input {index} site {site}: the {engine} digest does not reconstruct')
        used = sorted({u for _, u in s['sdk']})
        if len(used) != 1:
            sys.exit(f'fixtures_export: {rid}: the SDKs used several scriptCodes')
        v = bsvrs_vector(e['tx'], s['control']['scriptcode_hex'], index, hash_type,
                         bip143_digest(raw, index, code, 0, hash_type)[::-1].hex())
        v.update({'id': f'bsl:signer:{rid}:{index}:{site}', 'class': s['class'],
                  'design': LOCK_ONLY_DESIGN if s['class'] == LOCK_ONLY else '',
                  'sdk_script': used[0],
                  'sdk_hash': bip143_digest(raw, index, bytes.fromhex(used[0]), 0, hash_type)[::-1].hex(),
                  'engines': sorted(f'{eng} {"/".join(sorted(m))}' for (eng, _), m in s['sdk'].items()),
                  'amount_satoshis': amount, 'hash_at_amount': bytes.fromhex(s['control']['digest_hex'])[::-1].hex(),
                  'source': (f'bsv-script-lean {rel} {rid} input {index} CHECKSIG site {site}: the node\'s scriptCode '
                             f'(corpus/signer/README.md), its signature judged by {NODE_NAME} verifyscript in '
                             + ', '.join(sorted(s['records'])))})
        out.append(v)
    return out


def write_bsvrs(path, vectors):
    write(path, json.dumps(vectors, indent=2, ensure_ascii=True) + '\n')


# ---- the writers ---------------------------------------------------------------------------------------------

def dump(v):
    return json.dumps(v, separators=(',', ':'), ensure_ascii=True)


def write_vectors(path, head, vectors):
    lines = ['{'] + [f' {json.dumps(k)}: {dump(v)},' for k, v in head.items()] + [' "vectors": [']
    lines += [('  ' + dump(v) + (',' if i + 1 < len(vectors) else '')) for i, v in enumerate(vectors)]
    lines += [' ]', '}']
    write(path, '\n'.join(lines) + '\n')


def write(path, text):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, 'w', encoding='utf-8', newline='\n') as f:
        f.write(text)


COMMON = ('Generated by bsv-script-lean tools/fixtures_export.py (#146); regenerate, never edit. '
          f'Every verdict is the node\'s of record ({NODE_NAME}), the record named per row.')


def conformance_head(engine, what):
    return {'id': f'bsv-script-lean.{engine}.node-fixtures', 'name': f'bsv-script-lean: {what}',
            'version': '1', 'parity_class': 'required'}


def generate(root, out):
    ctx = Ctx(root)
    from fixtures_signer import build as build_signer
    signer, signer_stats, signer_sources = build_signer(ctx)
    sighash_tally = Tally()
    sighash = build_sighash(ctx, sighash_tally)
    manifest = {'generator': 'tools/fixtures_export.py', 'issue': 146, 'node': NODE_NAME,
                'node_keys': [NODE, NODE_MEMPOOL], 'pins': {'go-sdk': 'v1.7.2 (2ca481c5)', 'ts-sdk': '3.0.0 (ts-stack 4d0ea63c)'},
                'files': {}}
    for engine in ENGINES:
        tally = Tally()
        nv, st, nt = build_spends(ctx, engine, tally)
        base = os.path.join(out, engine)
        files = {}
        if engine == 'go-sdk':
            write_vectors(os.path.join(base, 'node_vectors.json'),
                          {'comment': [COMMON, 'Shape: go-sdk v1.7.2 script/interpreter/testdata/node_vectors.json (TestNodeVectors).',
                                       'word is the flag word the node was asked under; consensus true for the block word (sv-node@v1.2.3), false for the relay word (sv-node-mempool@v1.2.3).']},
                          nv)
            files['node_vectors.json'] = {'loader': 'go-sdk v1.7.2 TestNodeVectors (script/interpreter/node_vectors_test.go)',
                                          'vectors': len(nv), 'results': sum(len(v['results']) for v in nv)}
            rows = [[COMMON], ['Shape: go-sdk v1.7.2 script/interpreter/data/script_tests.json (TestScripts): [[amount], version, scriptSig, scriptPubKey, flags, expected, comment].'],
                    ['Only single-input spends whose scripts run no signature or lock-time opcode, under the block word.']] + st
            write(os.path.join(base, 'script_tests.json'), '[\n' + ',\n'.join(dump(r) for r in rows) + '\n]\n')
            files['script_tests.json'] = {'loader': 'go-sdk v1.7.2 TestScripts (script/interpreter/reference_test.go)', 'rows': len(st)}
            write_vectors(os.path.join(base, 'evaluation.json'),
                          conformance_head(engine, 'node-sighash vectors witnessed by mined signatures'), sighash)
            files['evaluation.json'] = {'loader': 'go-sdk v1.7.2 TestEvaluation (internal/conformance/scripts/evaluation_conformance_test.go)',
                                        'vectors': len(sighash), 'node-sighash': len(sighash)}
        else:
            vecs = sighash + nt
            write_vectors(os.path.join(base, 'evaluation.json'),
                          conformance_head(engine, 'recorded node transaction verdicts and reconstructed sighashes checked against mined signatures'), vecs)
            files['evaluation.json'] = {'loader': "@bsv/sdk 3.0.0 under ts-stack's conformance runner (sdkHelpers.ts dispatchNodeTransactionFixture, dispatchNodeSighashFixture)",
                                        'vectors': len(vecs), 'node-sighash': len(sighash), 'node-transaction': len(nt)}
        signer_nv, signer_nt = signer[engine]
        if engine == 'go-sdk':
            write_vectors(os.path.join(base, 'signer/node_vectors.json'),
                          {'comment': ['Signer reference and SDK-refused transactions (#145/#146); regenerate with tools/fixtures_export.py.',
                                       'Judgment provenance and signer classes are in source; input verdicts are retained per word.']}, signer_nv)
            files['signer/node_vectors.json'] = {
                'loader': files['node_vectors.json']['loader'], 'vectors': len(signer_nv),
                'results': sum(len(v['results']) for v in signer_nv)}
        else:
            write_vectors(os.path.join(base, 'signer/evaluation.json'),
                          conformance_head(engine, 'signer reference and SDK-refused transactions (#145/#146)'), signer_nt)
            files['signer/evaluation.json'] = {
                'loader': files['evaluation.json']['loader'], 'vectors': len(signer_nt), 'node-transaction': len(signer_nt)}
        for name, info in files.items():
            info['sha256'] = hashlib.sha256(open(os.path.join(base, name), 'rb').read()).hexdigest()
            spends = {} if (engine, name) == ('go-sdk', 'evaluation.json') else tally.out.get(name.split('.')[0], {})
            info['excluded'] = dict(sorted({**spends, **(sighash_tally.out.get('sighash', {})
                                                         if name == 'evaluation.json' else {})}.items()))
            manifest['files'][f'{engine}/{name}'] = info
    bsvrs_tally = Tally()
    bsvrs, bsvrs_rows = build_bsvrs_sighash(ctx, bsvrs_tally)
    findings = build_bsvrs_findings(ctx, bsvrs_tally)
    base = os.path.join(out, 'bsv-rs')
    write_bsvrs(os.path.join(base, 'sighash.json'), bsvrs)
    write_bsvrs(os.path.join(base, 'findings.json'), findings)
    loader = f'bsv-rs {BSVRS_PIN} test_sighash_vectors (tests/sighash_tests.rs:9-135; corpus/fixtures/bsv-rs/loader_proof.rs)'
    for name, vecs, key, extra in (('sighash.json', bsvrs, 'sighash', {'source_rows': bsvrs_rows}),
                                   ('findings.json', findings, 'findings',
                                    {'classes': dict(sorted(collections.Counter(v['class'] for v in findings).items()))})):
        manifest['files'][f'bsv-rs/{name}'] = {
            'loader': loader, 'vectors': len(vecs), **extra,
            'sha256': hashlib.sha256(open(os.path.join(base, name), 'rb').read()).hexdigest(),
            'excluded': dict(sorted(bsvrs_tally.out.get(key, {}).items()))}
    manifest['pins']['bsv-rs'] = BSVRS_PIN
    manifest['signer'] = signer_stats
    manifest['sources'] = sorted({rel for e in ENGINES for _, rel, _, _ in spend_sources(ctx, e)} |
                                 {'corpus/sighash/mainnet.jsonl', NODE_SIGHASH, BSVRS_SIGNER[0], BSVRS_SIGNER_050[0],
                                  *signer_sources})
    write(os.path.join(out, 'manifest.json'), json.dumps(manifest, indent=1, sort_keys=True, ensure_ascii=True) + '\n')
    return manifest


def main():
    args = sys.argv[1:]
    root = os.path.dirname(TOOLS)
    if '--root' in args:
        i = args.index('--root'); root = os.path.abspath(args[i + 1]); del args[i:i + 2]
    check = '--check' in args
    target = os.path.join(root, 'corpus', 'fixtures')
    if not check:
        m = generate(root, target)
        for name, info in sorted(m['files'].items()):
            print(f'fixtures_export: {name}: ' + ', '.join(f'{k} {v}' for k, v in info.items() if isinstance(v, int)))
        return
    tmp = tempfile.mkdtemp(prefix='fixtures-check-')
    try:
        generate(root, tmp)
        bad = []
        for dirpath, _, names in os.walk(tmp):
            for n in names:
                rel = os.path.relpath(os.path.join(dirpath, n), tmp)
                mine = os.path.join(target, rel)
                if not os.path.isfile(mine) or open(mine, 'rb').read() != open(os.path.join(dirpath, n), 'rb').read():
                    bad.append(rel)
        if bad:
            print('fixtures_export --check: STALE: ' + ', '.join(sorted(bad)) + ' (make fixtures)'); sys.exit(1)
        print(f'fixtures_export --check: OK (every generated file byte-identical under {os.path.relpath(target, root)})')
    finally:
        shutil.rmtree(tmp)


if __name__ == '__main__':
    main()
