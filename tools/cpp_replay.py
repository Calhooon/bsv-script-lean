#!/usr/bin/env python3
"""tools/cpp_replay.py (S3, #49 items 2 to 4; this repo's): the spend form of corpus/cpp's entries, and the judge of
the reference's unit tables against the node.

The C++ unit tables (`corpus/cpp/*.jsonl[.gz]`, `corpus/cpp/INVENTORY.md` §3) are calls of the interpreter, not
spends. The four differentials (the spec's `eval/bsvs corpus`, bsv-rs through `run_diff`, the two SV-node instances
through `run_svnode`) judge spends in the corpus's shape (`docs/DESIGN.md` §6). So this tool PROJECTS each entry
that has a faithful spend form into one spend entry, and names every other entry `undecided` with its reason:

* `evalscript` (`EvalScript(stack, script, flags, checker, params)`): the locking script is `input.script`; the
  unlocking script is the push-only script that rebuilds `input.stack` (each element by its minimal push, so the
  word's MINIMALDATA and SIGPUSHONLY accept it); the spending transaction's version is the checker's `Version()`
  (`input.tx_version`: OP_VER and the version gate read it, `interpreter.cpp:34-44`); its lock time 0 and the
  input's sequence final, so a lock-time or sequence check fails as `BaseSignatureChecker`'s does
  (`interpreter.h:52-75`: every check false). The unit's verdict becomes the spend's by `VerifyScript`'s steps
  after the locking script (`interpreter.cpp:2354-2448`, `docs/PARAMETERS.md` §2): an empty stack or a false top is
  `SCRIPT_ERR_EVAL_FALSE`; CLEANSTACK, where the word sets it and the version gate holds, wants exactly one
  element. Projected only when the spend runs the same computation: the checker is `base` or
  `versioned_sig_checker` (every signature check false, as a real checker's on a signature not made for this
  transaction), or the script executes no signature, lock-time or sequence opcode; the word is a valid word
  (`interpreter.cpp:2259-2262`) of bits `script_flags.h` names; CLEANSTACK only with P2SH (the reference asserts
  it); no P2SH evaluation is added (a P2SH-shaped locking script under P2SH on a pre-Genesis coin is undecided);
  the unlocking script fits the era's consensus script size and, pre-Genesis, every element fits 520 bytes
  (`docs/PARAMETERS.md` §1); the stack limit is no tighter than the consensus instance's.
* `verifyscript` (`VerifyScript(scriptSig, scriptPubKey, flags, checker)`): under `base` or
  `versioned_sig_checker` the spend is built as above with `input.script_sig`; under `tx` the entry's own
  transaction is the spend when it has one input (a second input's coin is not recorded).
* the predicates `CheckInputs` (a transaction, its coins in input order, a word: `returns` is the spend's
  validity) and `CScriptCheck` (one input of a one-input transaction against the output it spends).

Every other entry (the number layer, the decoder, the sighash and hash-type predicates, the standardness,
transaction and block predicates, a mempool-state predicate) is `undecided`: the drivers judge spends, and no
driver has a hook that runs a predicate. Entries the corpus marks `replayable: false` are counted apart. The ledger
names every undecided id under its reason and every not-replayable id (compressed, `compress_ids`/`expand_ids`).

THE CALLS WITH THEIR OWN CHAIN CONTEXT (lane cpp-era-49, 2026-10-06; the lens of the replay, (a), answered): a
`CheckInputs` call of `txvalidationcache_tests` runs on the fixture's chain (`TestChain100Setup`,
`test/test_bitcoin.cpp:191–206`: a hundred regtest blocks whose coinbases pay the fixture's key; the opening loop spends
the coinbase at height 1 under a tip at 100, block 101 then carries that spend, `txvalidationcache_tests.cpp:394`, and the
later loops spend its outputs at height 101 under a tip at 101), and the test sets the node's two activation heights per
call (`:117–125`: Genesis at 1 when the word carries UTXO_AFTER_GENESIS, else at the tip + 2; Chronicle likewise; `:329`).
`project_chain_context` projects such a call AT ITS OWN ERA: each coin at its recorded height (and coinbase flag), the
spend at the tip's successor (`GetSpendHeightAndMTP`, `validation.cpp:2858`), the activation heights the call's
`policy_at_tip_height` recorded, and as the explicit word the one `CheckInputScripts` passes to `CScriptCheck`: the call's
word with the per-input flags of those heights (`validation.cpp:2695–2708`; `InputScriptVerifyFlags`, `policy.h:226–244`:
SIGPUSHONLY when Genesis is active at the spend height, the two UTXO bits by the coin's era). The entries are grouped by
(tip, genesis height, chronicle height) into one corpus per group (`<out-dir>-t<tip>-g<genesis>-c<chronicle>/cases.jsonl`),
each run by `tools/cpp_era_run.sh` on the lane's own instances started with those heights on a chain of the fixture's
shape (`tools/cpp_era_chain.py`), the coins read from the chain; the file's ledger names the groups (`groups`, `corpora`).

The heights: the coin's height is chosen in the era the word's UTXO bits name (pre-Genesis 600,000; post-Genesis
700,000; post-Chronicle 950,000; mainnet's activation heights, `docs/PARAMETERS.md` §3), because the node re-derives
those two bits from the coin's height (`rpc/misc.cpp:816-825`) and the runner refuses a drift; the spend height is
the era the word's GENESIS and CHRONICLE bits name, never below the coin's. Every entry carries the word as its
explicit `flags` and `params.consensus` true: the `spec` column is the consensus instrument (the `local` instance's
zeroed policy). The `spec-mempool` column is the drivers' own: the relay word of those heights on the `policy`
instance, a differential of its own and not the unit's call.

The unit's expectations ride in `expect`: `sv-node-unit@v1.2.2` (what the C++ check asserts, as a spend verdict, only
where the assertion decides it) and `sv-node-unit-observed@v1.2.2` (what the instrumented build returned, `[X]`).
`judge` compares the node's recorded `spec` column (`sv-node@v1.2.2`, the consensus instance under the entry's own
word) with both: a disagreement is the reference against itself (rule 15), a Finding, never adjusted.

  python3 tools/cpp_replay.py project <corpus/cpp/<stem>.jsonl[.gz]> --out-dir corpus/cpp/replay/<name>
  python3 tools/cpp_replay.py judge corpus/cpp/replay/<name>
"""
import gzip
import hashlib
import json
import os
import sys

UNIT = "sv-node-unit@v1.2.2"
UNIT_OBS = "sv-node-unit-observed@v1.2.2"

# script_flags.h:13-115 at the pin (docs/PARAMETERS.md §2): the named bits; 11, 12, 17 unassigned, 22 the bound
P2SH, STRICTENC, SIGPUSHONLY, CLEANSTACK = 1 << 0, 1 << 1, 1 << 5, 1 << 8
GENESIS, UTXO_GENESIS, CHRONICLE, UTXO_CHRONICLE = 1 << 18, 1 << 19, 1 << 20, 1 << 21
NAMED = sum(1 << b for b in (0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 13, 14, 15, 16, 18, 19, 20, 21))

COIN_HEIGHT = {"pre-genesis": 600_000, "post-genesis": 700_000, "post-chronicle": 950_000}

# the opcodes whose result reads the checker (interpreter.cpp: OP_CHECKLOCKTIMEVERIFY 0xb1, OP_CHECKSEQUENCEVERIFY
# 0xb2, OP_CHECKSIG 0xac, OP_CHECKSIGVERIFY 0xad, OP_CHECKMULTISIG 0xae, OP_CHECKMULTISIGVERIFY 0xaf)
CHECKER_OPS = {0xAC, 0xAD, 0xAE, 0xAF, 0xB1, 0xB2}
BASE_LIKE = {"base", "versioned_sig_checker"}


def era_of(height):
    return "post-chronicle" if height >= 943_816 else ("post-genesis" if height >= 620_538 else "pre-genesis")


def utxo_era(word):
    if word & UTXO_CHRONICLE:
        return "post-chronicle"
    return "post-genesis" if word & UTXO_GENESIS else "pre-genesis"


def spend_era(word):
    if word & CHRONICLE:
        return "post-chronicle"
    return "post-genesis" if word & GENESIS else "pre-genesis"


def bytes_of(x):
    """An element or script as INVENTORY §3 writes it: hex, or exact runs; None for a digest-only one."""
    if isinstance(x, str):
        return bytes.fromhex(x)
    if isinstance(x, dict) and "runs" in x:
        out = b"".join(bytes.fromhex(b) * n for b, n in x["runs"])
        if len(out) != x["len"]:
            raise ValueError("runs do not add up to len")
        return out
    return None


def push(el):
    """The minimal push of an element (interpreter.cpp's CheckMinimalPush: OP_0, OP_1..OP_16, OP_1NEGATE, a direct push
    to 75 bytes, then PUSHDATA1, 2, 4)."""
    n = len(el)
    if n == 0:
        return b"\x00"
    if n == 1 and 1 <= el[0] <= 16:
        return bytes([0x50 + el[0]])
    if n == 1 and el[0] == 0x81:
        return b"\x4f"
    if n <= 75:
        return bytes([n]) + el
    if n <= 0xFF:
        return b"\x4c" + bytes([n]) + el
    if n <= 0xFFFF:
        return b"\x4d" + n.to_bytes(2, "little") + el
    return b"\x4e" + n.to_bytes(4, "little") + el


def opcodes(script):
    """The opcodes of a script in order, pushes skipped; a truncated push ends the walk (the decoder's failure)."""
    i, out = 0, []
    while i < len(script):
        op = script[i]
        i += 1
        if 1 <= op <= 75:
            i += op
        elif op in (0x4C, 0x4D, 0x4E):
            w = {0x4C: 1, 0x4D: 2, 0x4E: 4}[op]
            if i + w > len(script):
                break
            i += w + int.from_bytes(script[i:i + w], "little")
        else:
            out.append(op)
    return out


def is_p2sh(script):
    return len(script) == 23 and script[0] == 0xA9 and script[1] == 0x14 and script[22] == 0x87


def cast_to_bool(el):
    for i, b in enumerate(el):
        if b != 0:
            return not (i == len(el) - 1 and b == 0x80)
    return False


def varint(n):
    if n < 0xFD:
        return bytes([n])
    if n <= 0xFFFF:
        return b"\xfd" + n.to_bytes(2, "little")
    if n <= 0xFFFFFFFF:
        return b"\xfe" + n.to_bytes(4, "little")
    return b"\xff" + n.to_bytes(8, "little")


def build_tx(version, prev_hash_le, script_sig):
    """One input (the coin's outpoint, sequence final), one empty output of 0 satoshis, lock time 0."""
    return (
        (version & 0xFFFFFFFF).to_bytes(4, "little")
        + b"\x01" + prev_hash_le + b"\x00\x00\x00\x00" + varint(len(script_sig)) + script_sig + b"\xff\xff\xff\xff"
        + b"\x01" + (0).to_bytes(8, "little") + b"\x00"
        + b"\x00\x00\x00\x00"
    )


def tx_inputs(raw):
    """(version, [(prev hash LE, vout)]) of a raw transaction; scripts are skipped, never parsed."""
    def rd_varint(b, i):
        p = b[i]
        if p < 0xFD:
            return p, i + 1
        w = {0xFD: 2, 0xFE: 4, 0xFF: 8}[p]
        return int.from_bytes(b[i + 1:i + 1 + w], "little"), i + 1 + w
    version = int.from_bytes(raw[0:4], "little", signed=True)
    n, i = rd_varint(raw, 4)
    ins = []
    for _ in range(n):
        h, v = raw[i:i + 32], int.from_bytes(raw[i + 32:i + 36], "little")
        ln, i = rd_varint(raw, i + 36)
        i += ln + 4
        ins.append((h, v))
    nout, i = rd_varint(raw, i)
    return version, ins, nout


def with_script_sig(raw, n, script_sig):
    """The transaction with input n's unlocking script replaced (VerifyScript takes the unlocking script as an argument, and a
    test may leave the transaction's own empty, multisig_tests.cpp; no signature digest covers an input's script)."""
    def rd_varint(b, i):
        p = b[i]
        if p < 0xFD:
            return p, i + 1
        w = {0xFD: 2, 0xFE: 4, 0xFF: 8}[p]
        return int.from_bytes(b[i + 1:i + 1 + w], "little"), i + 1 + w
    nin, i = rd_varint(raw, 4)
    for k in range(nin):
        j = i + 36
        ln, after = rd_varint(raw, j)
        if k == n:
            return raw[:j] + varint(len(script_sig)) + script_sig + raw[after + ln:]
        i = after + ln + 4
    raise ValueError("no such input")


def word_refusal(word):
    if word >= 1 << 32 or word & ~NAMED:
        return "the word carries a bit script_flags.h does not name (11, 12, 17, or 22 and above), which run_diff refuses"
    if word & UTXO_CHRONICLE and not word & UTXO_GENESIS:
        return "an invalid word (UTXO_AFTER_CHRONICLE without UTXO_AFTER_GENESIS, interpreter.cpp:2259-2262)"
    if word & CLEANSTACK and not word & P2SH:
        return "CLEANSTACK without P2SH, which the reference asserts against"
    return None


def heights(word):
    coin = COIN_HEIGHT[utxo_era(word)]
    spend = max(coin, COIN_HEIGHT[spend_era(word)])
    return coin, spend


def spend_verdict_after(stack, word, version):
    """VerifyScript's steps after the locking script (interpreter.cpp:2354-2448): the top's truth, then CLEANSTACK
    under the version gate (EnforceNonMalleability, interpreter.cpp:34-44)."""
    if not stack or not cast_to_bool(stack[-1]):
        return {"verdict": "invalid", "code": "SCRIPT_ERR_EVAL_FALSE"}
    gate = not (word & CHRONICLE and version > 1)
    if word & CLEANSTACK and gate and len(stack) != 1:
        return {"verdict": "invalid", "code": "SCRIPT_ERR_CLEANSTACK"}
    return {"verdict": "valid"}


def stack_of(lst):
    out = []
    for x in lst:
        b = bytes_of(x)
        if b is None:
            return None
        out.append(b)
    return out


def partial_verdict(ex, word, version):
    """The spend verdict from an assertion that names the stack's size and its top (`stack_size` with `stack_top`, or with
    `elems_at`/`nums_at` at index -1 or size - 1: a number's truth is its being non-zero, CastToBool on its bytes; or a
    nonzero byte of the top by `bytes_at`); None when the assertion does not decide it."""
    size = ex.get("stack_size")
    if size == 0:
        return {"verdict": "invalid", "code": "SCRIPT_ERR_EVAL_FALSE"}
    top = bytes_of(ex["stack_top"]) if "stack_top" in ex else None
    for key in ("elems_at", "nums_at"):
        for idx, val in ex.get(key, []):
            if idx == -1 or (size is not None and idx == size - 1):
                top = bytes.fromhex(val)
    truth = None if top is None else cast_to_bool(top)
    if truth is None:
        # `bytes_at` (index, offset, byte) on the top: a nonzero byte decides CastToBool true unless it may be the last
        # byte and is 0x80 (negative zero, interpreter.cpp's CastToBool); a zero byte alone decides nothing (the lens of
        # #49's replay, (b): these assertions were ignored)
        top_len = ex.get("top_len")
        for idx, off, val in ex.get("bytes_at", []):
            if not (idx == -1 or (size is not None and idx == size - 1)):
                continue
            v = int(val, 16)
            maybe_last = top_len is None or off == top_len - 1
            if v != 0 and not (v == 0x80 and maybe_last):
                truth = True
    if truth is None:
        return None
    if not truth:
        return {"verdict": "invalid", "code": "SCRIPT_ERR_EVAL_FALSE"}
    gate = not (word & CHRONICLE and version > 1)
    if word & CLEANSTACK and gate:
        if size is None:
            return None
        if size != 1:
            return {"verdict": "invalid", "code": "SCRIPT_ERR_CLEANSTACK"}
    return {"verdict": "valid"}


def eval_expect(e, word, version):
    """The unit's asserted and observed verdicts of an evalscript call, as spend verdicts."""
    ex = e.get("expect", {}).get(UNIT, {})
    ob = e.get("observed", {}).get(UNIT, {})
    asserted = None
    if ex.get("verdict") == "error":
        asserted = {"verdict": "invalid"}
        if ex.get("error"):
            asserted["code"] = ex["error"]
    elif ex.get("verdict") == "ok":
        st = stack_of(ex["stack"]) if "stack" in ex else None
        if st is not None:
            asserted = spend_verdict_after(st, word, version)
        else:
            asserted = partial_verdict(ex, word, version)
    observed = None
    err = ob.get("error")
    if err and err != "SCRIPT_ERR_OK":
        observed = {"verdict": "invalid", "code": err}
    elif err == "SCRIPT_ERR_OK":
        st = stack_of(ob["stack"]) if "stack" in ob else (stack_of(ex["stack"]) if "stack" in ex else None)
        if st is not None:
            observed = spend_verdict_after(st, word, version)
    return asserted, observed


def verify_expect(e):
    ex = e.get("expect", {}).get(UNIT, {})
    ob = e.get("observed", {}).get(UNIT, {})
    asserted = None
    if ex.get("verdict") == "ok":
        asserted = {"verdict": "valid"}
    elif ex.get("verdict") == "error":
        asserted = {"verdict": "invalid"}
        if ex.get("error"):
            asserted["code"] = ex["error"]
    observed = None
    err = ob.get("error")
    if err == "SCRIPT_ERR_OK":
        observed = {"verdict": "valid"}
    elif err:
        observed = {"verdict": "invalid", "code": err}
    return asserted, observed


def mk_entry(e, tx, prevouts, word, spend, version, asserted, observed, note):
    expect = {}
    if asserted:
        expect[UNIT] = asserted
    if observed:
        expect[UNIT_OBS] = observed
    src = e["source"]
    cite = f"{src['file']}:{src.get('row_line', src['line'])}"
    out = {
        "id": e["id"], "family": e["family"], "rule": e["rule"], "tx": tx.hex(), "prevouts": prevouts,
        "params": {"spend_height": spend, "era": era_of(spend), "consensus": True, "tx_version": version},
        "flags": [word] * len(prevouts), "expect": expect,
        "note": f"[SRC] {cite} ({e['kind']}{', ' + e['predicate'] if e.get('predicate') else ''}){note}",
    }
    return out


def project_constructed(e, word, script_sig, lock, version, amount, asserted, observed, note):
    coin, spend = heights(word)
    prev = hashlib.sha256(("cpp-replay:" + e["id"]).encode()).digest()
    tx = build_tx(version, prev, script_sig)
    prevouts = [{"txid": prev[::-1].hex(), "vout": 0, "script": lock.hex(), "satoshis": amount, "height": coin}]
    return mk_entry(e, tx, prevouts, word, spend, version, asserted, observed, note)


def project_own_tx(e, word, raw, coins, asserted, observed, note):
    """The entry's own transaction with its coins in input order (each coin's script and amount)."""
    coin_h, spend = heights(word)
    version, ins, nout = tx_inputs(raw)
    if nout == 0:
        return None, "the transaction has no output (a corpus entry needs one, docs/DESIGN.md §6)"
    if len(ins) != len(coins):
        return None, "the transaction's inputs and the recorded coins differ in number"
    prevouts = [{"txid": h[::-1].hex(), "vout": v, "script": s.hex(), "satoshis": a, "height": coin_h}
                for (h, v), (s, a) in zip(ins, coins)]
    return mk_entry(e, raw, prevouts, word, spend, version, asserted, observed, note), None


def checker_reason(checker, lock, extra=b""):
    if checker in BASE_LIKE:
        return None
    if CHECKER_OPS & (set(opcodes(lock)) | set(opcodes(extra))):
        return f"the checker `{checker}` decides a signature, lock-time or sequence opcode the script executes, and no spend reproduces it"
    return None


def size_reason(word, script_sig, elements):
    pre = not word & UTXO_GENESIS
    if pre and len(script_sig) > 10_000:
        return "the rebuilt unlocking script exceeds the pre-Genesis script size (10,000, consensus.h:58)"
    if pre and any(len(x) > 520 for x in elements):
        return "a stack element above 520 bytes cannot be pushed on a pre-Genesis coin (script.h:29)"
    return None


def chain_era(genesis, chronicle, height):
    """`GetProtocolEra(genesis, chronicle, height)` (protocol_era.cpp:21–35): below the Genesis height PreGenesis, below the
    Chronicle height PostGenesis, else PostChronicle."""
    return "pre-genesis" if height < genesis else ("post-genesis" if height < chronicle else "post-chronicle")


def input_script_verify_flags(era, utxo_era):
    """`InputScriptVerifyFlags(era, utxoEra)` (policy.h:226–244): SIGPUSHONLY when Genesis is active at the spend height
    (:230–233), UTXO_AFTER_GENESIS and UTXO_AFTER_CHRONICLE by the coin's era (:235–242). `CheckInputScripts` ORs it into
    the call's word for `CScriptCheck` (validation.cpp:2695–2708)."""
    w = 0
    if era != "pre-genesis":
        w |= SIGPUSHONLY
    if utxo_era != "pre-genesis":
        w |= UTXO_GENESIS
    if utxo_era == "post-chronicle":
        w |= UTXO_CHRONICLE
    return w


def project_chain_context(e, word, raw, i, asserted):
    """A `CheckInputs` call with its own chain context (the module docstring): (spend entry carrying `_group`, None) or
    (None, reason). The entry's heights are the test's; the word is the call's with the per-input flags of those heights."""
    pol = i.get("policy_at_tip_height") or {}
    tip, genesis, chronicle = i.get("tip_height"), pol.get("genesis_height"), pol.get("chronicle_height")
    if tip is None or genesis is None or chronicle is None:
        return None, "the call's chain context is incomplete (no tip height or no activation heights recorded)"
    if any("height" not in p for p in i["prevouts"]):
        return None, "a coin of the call carries no height"
    spend = tip + 1
    note_c = ""
    if genesis <= 0:
        return None, "the test's config carried a non-positive Genesis height, which a node refuses (configscriptpolicy.cpp:310–321)"
    if chronicle <= 0:
        # the fixture's unset default: a node refuses a zero or negative activation height (configscriptpolicy.cpp:353–364);
        # below the Genesis height the era is PreGenesis whatever the Chronicle height (protocol_era.cpp:31–35), so the call is
        # run at Chronicle = Genesis when every height of the call is below Genesis, else it is undecided by name
        if any(h >= genesis for h in [spend] + [p["height"] for p in i["prevouts"]]):
            return None, "the test's config carried a non-positive Chronicle height, which a node refuses (configscriptpolicy.cpp:353–364), at a height where it decides the era"
        note_c = (f"; the test's config carried chronicle {chronicle} (the fixture's unset default), which a node refuses "
                  f"(configscriptpolicy.cpp:353–364): run at chronicle {genesis}, the same era at every height of this call "
                  f"(all below genesis {genesis}, protocol_era.cpp:31–35)")
        chronicle = genesis
    version, ins, nout = tx_inputs(raw)
    if nout == 0:
        return None, "the transaction has no output (a corpus entry needs one, docs/DESIGN.md §6)"
    if len(ins) != len(i["prevouts"]):
        return None, "the transaction's inputs and the recorded coins differ in number"
    era = chain_era(genesis, chronicle, spend)
    words = [word | input_script_verify_flags(era, chain_era(genesis, chronicle, p["height"])) for p in i["prevouts"]]
    prevouts = [{"txid": h[::-1].hex(), "vout": v, "script": p["script_pubkey"], "satoshis": p["amount"], "height": p["height"]}
                for (h, v), p in zip(ins, i["prevouts"])]
    coin_text = ", ".join(f"{p['height']}{' (coinbase)' if p.get('is_coinbase') else ''}" for p in i["prevouts"])
    words_text = ", ".join(f"0x{w:X}" for w in words)
    note = (f"; the test's chain: coins at height {coin_text}, the tip {tip}, the spend at {spend}; -genesisactivationheight {genesis}, "
            f"-chronicleactivationheight {chronicle} (policy_at_tip_height: the config at the call); the word CheckInputs passes to "
            f"CScriptCheck, the call's 0x{word:X} with the per-input flags of the heights (validation.cpp:2695–2708, policy.h:226–244): "
            f"{words_text}" + note_c)
    out = mk_entry(e, raw, prevouts, word, spend, version, asserted, None, note)
    out["flags"] = words
    out["_group"] = {"tip_height": tip, "spend_height": spend, "genesis_height": genesis, "chronicle_height": chronicle,
                     "coinbase_coins": sum(1 for p in i["prevouts"] if p.get("is_coinbase")),
                     "coin_heights": [p["height"] for p in i["prevouts"]]}
    return out, None


CAP = 1_000_000  # bytes of a spend's transaction and coins: the corpus writes elements as hex, corpus/cpp as runs


def project(e):
    """(spend entry, None) or (None, reason); a spend form above CAP bytes is undecided."""
    out, why = project_one(e)
    if out is not None and len(out["tx"]) // 2 + sum(len(p["script"]) // 2 for p in out["prevouts"]) > CAP:
        return None, "the spend form is above 1,000,000 bytes: the corpus format writes an element as hex, and no driver reads corpus/cpp's runs"
    return out, why


def project_one(e):
    """(spend entry, None) or (None, reason)."""
    amounts = [e.get("input", {}).get("amount", 0)] + [p.get("amount", 0) for p in e.get("input", {}).get("prevouts", []) or []]
    if any(isinstance(a, int) and a < 0 for a in amounts):
        return None, "the call's amount is negative, which no coin carries (a corpus prevout's satoshis are unsigned, docs/DESIGN.md section 6)"
    if e.get("replayable") is False:
        return None, "replayable: false"
    k = e["kind"]
    i = e.get("input", {})
    if k == "evalscript":
        word = i["flags"]
        r = word_refusal(word)
        if r:
            return None, r
        lock = bytes_of(i["script"])
        stack = stack_of(i["stack"])
        if lock is None or stack is None:
            return None, "an element recorded by its digest only"
        r = checker_reason(i["checker"], lock)
        if r:
            return None, r
        if word & (1 << 16) and not word & STRICTENC and CHECKER_OPS & set(opcodes(lock)):
            return None, "VerifyScript adds STRICTENC under SIGHASH_FORKID (interpreter.cpp:2315-2319), which the EvalScript call ran without, and the script executes a signature opcode"
        if word & P2SH and not word & UTXO_GENESIS and is_p2sh(lock):
            return None, "a P2SH-shaped locking script under P2SH on a pre-Genesis coin adds an evaluation EvalScript does not run"
        lim = i.get("stack_limit")
        if lim is not None and lim < 4_294_967_295:
            return None, f"the call's stack limit {lim} binds below any node configuration's (docs/PARAMETERS.md §1)"
        p = i.get("params", {})
        consensus_params = {
            "pre-genesis": {"max_ops": 500, "max_num_len": 4, "max_script_size": 10000, "max_pubkeys_multisig": 20},
        }
        cp = consensus_params.get(utxo_era(word))
        if cp is not None and any(p.get(key) != v for key, v in cp.items()):
            return None, "the call's limits are not the pre-Genesis consensus limits, which every node applies to a pre-Genesis coin"
        if cp is None and (p.get("max_script_size", 0) < 500_000 or p.get("max_ops", 0) < 4_294_967_295 or p.get("max_num_len", 0) < 10_000):
            return None, "the call's limits are below any node configuration's (a test's own parameters)"
        script_sig = b"".join(push(x) for x in stack)
        r = size_reason(word, script_sig, stack)
        if r:
            return None, r
        version = i.get("tx_version", 0)
        asserted, observed = eval_expect(e, word, version)
        lim_note = "" if cp is not None else (
            f"; the call's limits {json.dumps(p, sort_keys=True)}, the spec column's the era's consensus limits")
        return project_constructed(e, word, script_sig, lock, version, i.get("amount", 0), asserted, observed,
                                   lim_note), None
    if k == "verifyscript":
        word = i["flags"]
        r = word_refusal(word)
        if r:
            return None, r
        sig, pub = bytes_of(i["script_sig"]), bytes_of(i["script_pubkey"])
        if sig is None or pub is None:
            return None, "a script recorded by its digest only"
        asserted, observed = verify_expect(e)
        if i["checker"] == "tx" and "tx" in i:
            raw = bytes.fromhex(i["tx"])
            _, ins, _ = tx_inputs(raw)
            if len(ins) == 1 and i.get("n_in", 0) == 0:
                return project_own_tx(e, word, with_script_sig(raw, 0, sig), [(pub, i.get("amount", 0))], asserted, observed,
                                      "; its own transaction")
        r = checker_reason(i["checker"], pub, sig)
        if r:
            if i["checker"] == "tx":
                r = "the call's transaction has several inputs, the coins of the others are not recorded, and the script reads the checker"
            return None, r
        return project_constructed(e, word, sig, pub, i.get("tx_version", 0), i.get("amount", 0), asserted, observed,
                                   f"; checker {i['checker']}"), None
    if k == "predicate" and e.get("predicate") == "CheckInputs":
        word = i["flags"]
        r = word_refusal(word)
        if r:
            return None, r
        raw = bytes.fromhex(i["tx"]) if isinstance(i["tx"], str) else None
        if raw is None:
            return None, "a transaction recorded by its digest only"
        ret = e["expect"][UNIT].get("returns")
        asserted = {"verdict": "valid" if ret else "invalid"} if ret is not None else None
        if "tip_height" in i or any("height" in p or "is_coinbase" in p for p in i["prevouts"]):
            return project_chain_context(e, word, raw, i, asserted)
        coins = [(bytes.fromhex(p["script_pubkey"]), p["amount"]) for p in i["prevouts"]]
        return project_own_tx(e, word, raw, coins, asserted, None, "")
    if k == "predicate" and e.get("predicate") == "CScriptCheck":
        word = i["flags"]
        r = word_refusal(word)
        if r:
            return None, r
        raw = bytes.fromhex(i["tx"])
        version, ins, _ = tx_inputs(raw)
        if len(ins) != 1 or i.get("n_in", 0) != 0:
            return None, "the check's transaction has several inputs, and the coins of the others are not recorded"
        ret = e["expect"][UNIT].get("returns")
        asserted = {"verdict": "valid" if ret else "invalid"} if ret is not None else None
        return project_own_tx(e, word, raw, [(bytes.fromhex(i["script_pubkey"]), i["amount"])], asserted, None,
                              "")
    if k == "predicate":
        return None, f"a predicate ({e.get('predicate')}, layer {e.get('layer')}): the drivers judge spends, and none has a hook that runs it"
    return None, f"the kind `{k}` has no spend form"


def read_lines(path):
    if not os.path.exists(path) and os.path.exists(path + ".gz"):
        path += ".gz"  # a recorded corpus committed gzipped (corpus/cpp/replay/.gitignore)
    op = gzip.open if path.endswith(".gz") else open
    with op(path, "rt") as f:
        for line in f:
            if line.strip():
                yield json.loads(line)


def compress_ids(ids):
    """Every id, in the order met, consecutive numbers of one prefix folded into `prefix-NNNNN..MMMMM` (the lens of #49's
    replay, (c): a ledger names every undecided id); `expand_ids` reverses it, so every count is recomputable."""
    out, run = [], None
    for x in ids:
        pre, _, num = x.rpartition("-")
        if run and run[0] == pre and num.isdigit() and int(num) == run[2] + 1 and len(num) == run[3]:
            run[2] += 1
            continue
        if run:
            out.append(run_text(run))
        run = [pre, x, int(num), len(num)] if num.isdigit() else None
        if run is None:
            out.append(x)
    if run:
        out.append(run_text(run))
    return out


def run_text(run):
    pre, lo, last, width = run
    return lo if lo == f"{pre}-{last:0{width}d}" else f"{lo}..{last:0{width}d}"


def expand_ids(items):
    for it in items:
        if ".." in it:
            lo, last = it.split("..")
            pre, _, num = lo.rpartition("-")
            for k in range(int(num), int(last) + 1):
                yield f"{pre}-{k:0{len(num)}d}"
        else:
            yield it


class Tally:
    """The lines of one corpus and the histograms its manifest carries."""
    def __init__(self):
        self.lines, self.ids, self.fams, self.rules, self.verdicts = [], [], {}, {}, {}

    def add(self, out):
        self.fams[out["family"]] = self.fams.get(out["family"], 0) + 1
        self.rules[out["rule"]] = self.rules.get(out["rule"], 0) + 1
        v = out["expect"].get(UNIT, out["expect"].get(UNIT_OBS, {"verdict": "unasserted"}))["verdict"]
        self.verdicts[v] = self.verdicts.get(v, 0) + 1
        self.ids.append(out["id"])
        self.lines.append(json.dumps(out, separators=(",", ":"), sort_keys=False))


def write_corpus(out_dir, name, tally, src, generator):
    """`cases.jsonl` and `cases-manifest.json` of one corpus; the plain file's sha256."""
    os.makedirs(out_dir, exist_ok=True)
    text = "".join(l + "\n" for l in tally.lines).encode()
    with open(os.path.join(out_dir, "cases.jsonl"), "wb") as f:
        f.write(text)
    sha = hashlib.sha256(text).hexdigest()
    manifest = {
        "corpus": name, "file": "cases.jsonl", "generator": generator,
        "seed": "none (a projection of the committed C++ table, byte-deterministic)",
        "count": len(tally.lines), "sha256": sha,
        "families": dict(sorted(tally.fams.items())), "rules": dict(sorted(tally.rules.items())), "verdicts": dict(sorted(tally.verdicts.items())),
        "implementations": [], "engine_executions": 0, "generated": os.environ.get("SOURCE_DATE", ""),
        "provenance": f"bitcoin-sv v1.2.2 (879fc8b42168dd0e608dafd51b39c6dabad37d4d) unit tables, corpus/cpp/manifest.json; the source's sha256 {hashlib.sha256(open(src, 'rb').read()).hexdigest()}",
    }
    with open(os.path.join(out_dir, "cases-manifest.json"), "w") as f:
        f.write(json.dumps(manifest, indent=2) + "\n")
    return sha


def cmd_project(src, out_dir):
    stem = os.path.basename(src).split(".")[0]
    name = os.path.basename(out_dir.rstrip("/"))
    os.makedirs(out_dir, exist_ok=True)
    ledger = {"source": f"corpus/cpp/{os.path.basename(src)}", "entries": 0, "projected": 0,
              "not_replayable": 0, "undecided": {}, "undecided_ids": {}, "not_replayable_ids": []}
    own, groups = Tally(), {}  # the file's own corpus; the calls with their own chain context, by (tip, genesis, chronicle)
    for e in read_lines(src):
        ledger["entries"] += 1
        out, why = project(e)
        if out is None:
            if why == "replayable: false":
                ledger["not_replayable"] += 1
                ledger["not_replayable_ids"].append(e["id"])
            else:
                ledger["undecided"][why] = ledger["undecided"].get(why, 0) + 1
                ledger["undecided_ids"].setdefault(why, []).append(e["id"])
            continue
        ledger["projected"] += 1
        g = out.pop("_group", None)
        if g is None:
            own.add(out)
            continue
        key = (g["tip_height"], g["genesis_height"], g["chronicle_height"])
        grp = groups.setdefault(key, {"tally": Tally(), "spend_height": g["spend_height"], "coinbase_coins": 0, "coin_heights": {}})
        grp["tally"].add(out)
        grp["coinbase_coins"] += g["coinbase_coins"]
        for h in g["coin_heights"]:
            grp["coin_heights"][str(h)] = grp["coin_heights"].get(str(h), 0) + 1
    ledger["undecided_ids"] = {why: compress_ids(ids) for why, ids in ledger["undecided_ids"].items()}
    ledger["not_replayable_ids"] = compress_ids(ledger["not_replayable_ids"])
    ledger["ids_form"] = ("every undecided id under its reason and every not-replayable id, consecutive ids folded into "
                          "`first..last` (tools/cpp_replay.py expand_ids): the counts are the expanded lists' lengths")
    corpora = []
    if own.lines:
        write_corpus(out_dir, name, own, src, f"tools/cpp_replay.py project (#49 item 2): the spend form of corpus/cpp/{os.path.basename(src)}")
        corpora.append(name)
    if groups:
        ledger["groups"] = {}
        ledger["chain"] = ("the calls with their own chain context (the module docstring): one corpus per (tip, Genesis height, Chronicle "
                           "height), each run by tools/cpp_era_run.sh on the lane's own instances started with those heights "
                           "(-genesisactivationheight, -chronicleactivationheight) on a chain of the fixture's shape (tools/cpp_era_chain.py: "
                           "TestChain100Setup's hundred blocks, block 101 with the opening loop's spend), the coins read from that chain")
        for (tip, genesis, chronicle), grp in sorted(groups.items()):
            tag = f"t{tip}-g{genesis}-c{chronicle}"
            gname = f"{name}-{tag}"
            gdir = os.path.join(os.path.dirname(out_dir.rstrip("/")), gname)
            sha = write_corpus(gdir, gname, grp["tally"], src,
                               f"tools/cpp_replay.py project (#49 item 2; lane cpp-era-49): the CheckInputs calls of corpus/cpp/{os.path.basename(src)} "
                               f"with their own chain context, the tip at {tip}, -genesisactivationheight {genesis} -chronicleactivationheight {chronicle}")
            ledger["groups"][tag] = {"corpus": gname, "tip_height": tip, "spend_height": grp["spend_height"], "genesis_height": genesis,
                                     "chronicle_height": chronicle, "entries": len(grp["tally"].lines), "coinbase_coins": grp["coinbase_coins"],
                                     "coin_heights": grp["coin_heights"], "sha256": sha, "ids": compress_ids(grp["tally"].ids)}
            corpora.append(gname)
    ledger["corpora"] = corpora
    with open(os.path.join(out_dir, "ledger.json"), "w") as f:
        f.write(json.dumps(ledger, indent=2, sort_keys=True) + "\n")
    if not corpora:
        # nothing has a spend form: the ledger alone names every entry's reason (no corpus, no manifest, no run)
        print(f"cpp_replay: {stem}: {ledger['entries']} entries, 0 projected, {sum(ledger['undecided'].values())} undecided, "
              f"{ledger['not_replayable']} not replayable -> {out_dir}/ledger.json")
        return
    print(f"cpp_replay: {stem}: {ledger['entries']} entries, {ledger['projected']} projected, "
          f"{sum(ledger['undecided'].values())} undecided, {ledger['not_replayable']} not replayable -> {', '.join(corpora)}")
    for tag, g in ledger.get("groups", {}).items():
        print(f"    group {tag}: {g['entries']} spends, coins at heights {g['coin_heights']} ({g['coinbase_coins']} coinbase), the spend at {g['spend_height']}")
    for why, n in sorted(ledger["undecided"].items(), key=lambda x: -x[1]):
        print(f"    {n} undecided: {why}")


def judge_dir(cdir):
    """One corpus: the node's consensus column against the unit's two verdicts; (res, entries seen, words in bsv-rs's scope)."""
    res = {"asserted": {"agree": 0, "disagree": 0, "code_differs": 0, "none": 0},
           "observed": {"agree": 0, "disagree": 0, "code_differs": 0, "none": 0}, "findings": []}
    seen = 0
    for e in read_lines(os.path.join(cdir, "cases.jsonl")):
        seen += 1
        node = e["expect"].get("sv-node@v1.2.2")
        for key, tag in ((UNIT, "asserted"), (UNIT_OBS, "observed")):
            u = e["expect"].get(key)
            if not u or not node or node["verdict"] not in ("valid", "invalid"):
                res[tag]["none"] += 1
                continue
            if u["verdict"] != node["verdict"]:
                res[tag]["disagree"] += 1
                if len(res["findings"]) < 50:
                    res["findings"].append({"id": e["id"], "unit": tag, "unit_verdict": u, "node": node})
            else:
                res[tag]["agree"] += 1
                if u.get("code") and node.get("code") and u["code"] != node["code"]:
                    res[tag]["code_differs"] += 1
    # bsv-rs's scope (0.3.32 flags.rs:500–519): a word without SIGHASH_FORKID, GENESIS or UTXO_AFTER_GENESIS is refused, so its agreement
    # there is the verdict alone (both invalid); counted so the page never reads a refusal as a judgment
    in_scope = 0
    for e in read_lines(os.path.join(cdir, "cases.jsonl")):
        if all(w & (1 << 16) and w & GENESIS and w & UTXO_GENESIS for w in e["flags"]):
            in_scope += 1
    res["bsvrs_word_in_scope"] = in_scope
    return res, seen


def cmd_judge(out_dir):
    """The node's consensus column against the unit's own verdicts (rule 15) over the file's corpora (`corpora`: its own and
    the chain-context groups'), summed into the ledger's `judge`, each group's beside it."""
    led = json.load(open(os.path.join(out_dir, "ledger.json")))
    name = os.path.basename(out_dir.rstrip("/"))
    corpora = led.get("corpora") or [name]
    total = {"asserted": {"agree": 0, "disagree": 0, "code_differs": 0, "none": 0},
             "observed": {"agree": 0, "disagree": 0, "code_differs": 0, "none": 0}, "findings": [], "bsvrs_word_in_scope": 0}
    seen = 0
    for cname in corpora:
        cdir = out_dir if cname == name else os.path.join(os.path.dirname(out_dir.rstrip("/")), cname)
        res, n = judge_dir(cdir)
        seen += n
        for k in ("asserted", "observed"):
            for kk in total[k]:
                total[k][kk] += res[k][kk]
        total["findings"] = (total["findings"] + res["findings"])[:50]
        total["bsvrs_word_in_scope"] += res["bsvrs_word_in_scope"]
        for tag, g in led.get("groups", {}).items():
            if g["corpus"] == cname:
                g["judge"] = {k: v for k, v in res.items() if k != "findings"}
                g["judge"]["findings"] = len(res["findings"])
                g["judged_entries"] = n
    led["judge"] = total
    led["judged_entries"] = seen
    with open(os.path.join(out_dir, "ledger.json"), "w") as f:
        f.write(json.dumps(led, indent=2, sort_keys=True) + "\n")
    print(json.dumps({k: v for k, v in total.items() if k != "findings"}), f"findings listed: {len(total['findings'])}; {seen} entries over {len(corpora)} corpora")


if __name__ == "__main__":
    a = sys.argv[1:]
    if a[:1] == ["project"] and len(a) == 4 and a[2] == "--out-dir":
        cmd_project(a[1], a[3])
    elif a[:1] == ["judge"] and len(a) == 2:
        cmd_judge(a[1])
    else:
        print(__doc__)
        sys.exit(2)
