"""cleanroom.py: a BSV script evaluator written from the published spec alone (#37).

Sources: harness/cleanroom/README.md (the one rule, the complete list). Every
function names the sentence it implements as `spec/<page>.md:<line>` or
`docs/<page>.md:<line>`; `[LIT]` marks a public standard the pages name by
reference. A behavior the pages do not determine is `need("<gap id>")`, which
raises `DocumentGap` in the strict mode and, in the labelled assumed mode, fills
the gap with the reading `ASSUMPTIONS` records (never silently).

Python 3, standard library only. Slow and plain on purpose.
"""

import hashlib

# ---------------------------------------------------------------------------
# Gaps and the two modes (harness/cleanroom/README.md, "The reading rule")
# ---------------------------------------------------------------------------


class DocumentGap(Exception):
    """The pages do not determine the behavior: `gid` names it in GAPS."""

    def __init__(self, gid):
        super().__init__(gid)
        self.gid = gid


class ScriptFail(Exception):
    """A verdict `invalid` with a reason from the error vocabulary (spec/errors.md:5)."""

    def __init__(self, code):
        super().__init__(code)
        self.code = code


class TxReject(Exception):
    """A transaction-level refusal with its reject string (spec/theorems.md:10236, TxRules)."""

    def __init__(self, code):
        super().__init__(code)
        self.code = code


# gid -> (where the pages name it, what is missing, the assumed reading or None).
# An assumed reading of None means the gap stays a gap in both columns.
GAPS = {
    "stack.dup": ("spec/opcodes/OP_DUP.md:1", "OP_DUP is named (DESIGN.md:255, `980`) with no stated effect", "push a copy of the top"),
    "stack.drop": ("spec/theorems.md:8364", "OP_DROP's effect is not stated; only its empty-stack refusal (vDropEmpty_kernel)", "remove the top"),
    "stack.nip": ("spec/opcodes/OP_NIP.md:1", "OP_NIP is named (`989`) with no stated effect", "remove the second element"),
    "stack.over": ("spec/opcodes/OP_OVER.md:1", "OP_OVER is named (`997`) with no stated effect", "push a copy of the second element"),
    "stack.swap": ("spec/opcodes/OP_SWAP.md:1", "OP_SWAP is named (`1040`); 'a swap costs nothing' (modules.md:2066) states the cost, not which elements", "exchange the top two"),
    "stack.2drop": ("spec/opcodes/OP_2DROP.md:1", "OP_2DROP is named (`890`) with no stated effect", "remove the top two"),
    "stack.2dup": ("spec/opcodes/OP_2DUP.md:1", "OP_2DUP is named (`899`) with no stated effect", "push copies of the top two, order kept"),
    "stack.3dup": ("spec/opcodes/OP_3DUP.md:1", "OP_3DUP is named (`910`) with no stated effect", "push copies of the top three, order kept"),
    "stack.2over": ("spec/opcodes/OP_2OVER.md:1", "OP_2OVER is named (`923`) with no stated effect", "push copies of the third and fourth, order kept"),
    "stack.2rot": ("spec/opcodes/OP_2ROT.md:1", "OP_2ROT is named (`934`) with no stated effect", "move the fifth and sixth to the top, order kept"),
    "stack.2swap": ("spec/opcodes/OP_2SWAP.md:1", "OP_2SWAP is named (`946`) with no stated effect", "exchange the top pair with the second pair"),
    "stack.ifdup": ("spec/opcodes/OP_IFDUP.md:1", "OP_IFDUP is named (`955`) with no stated effect", "push a copy of the top when it casts to true"),
    "stack.roll": ("spec/theorems.md:5939", "OP_ROLL 'erases the element k below the top' (reverse_eraseIdx); that it is then pushed on top is not stated", "move the element at depth k to the top"),
    "stack.tuck": ("spec/theorems.md:5945", "OP_TUCK 'inserts k below the top' (reverse_insertIdx): which element and which k is not stated", "insert a copy of the top below the second element"),
    "stack.size": ("spec/opcodes/OP_DEPTH.md:11", "OP_SIZE pushes CScriptNum(n) (pushCount); what n is and whether the top is popped is not stated", "push the top's length, the top kept"),
    "stack.verify-empty": ("spec/opcodes/OP_VERIFY.md:1", "OP_VERIFY on an empty stack: the refusal is not stated (only `0 OP_VERIFY`, vVerifyFalse_kernel)", "SCRIPT_ERR_INVALID_STACK_OPERATION"),
    "arith.1add": ("spec/opcodes/OP_2DIV.md:13", "unaryValue states OP_2MUL and OP_2DIV only; OP_1ADD's value is not stated (examples only)", "bn + 1"),
    "arith.1sub": ("spec/opcodes/OP_2DIV.md:13", "OP_1SUB's value is not stated", "bn - 1"),
    "arith.negate": ("spec/opcodes/OP_2DIV.md:13", "OP_NEGATE's value is not stated", "-bn"),
    "arith.abs": ("spec/opcodes/OP_2DIV.md:13", "OP_ABS's value is not stated", "the absolute value of bn"),
    "arith.not": ("spec/opcodes/OP_2DIV.md:13", "OP_NOT's value is not stated (a boolean, unaryBounded)", "bn == 0"),
    "arith.minmax": ("spec/opcodes/OP_DIV.md:12", "OP_MIN/OP_MAX 'copy an operand': which operand is not stated", "the lesser / the greater"),
    "arith.cmp": ("spec/rules.md:80", "the comparison opcodes are 'the numeric comparisons against the model'; the rule text is cut by the generator at 'OP_GREATERTHANOREQUA…'", "the comparison its name says"),
    "arith.bool2": ("spec/rules.md:80", "OP_BOOLAND/OP_BOOLOR are 'the boolean of two numbers': which boolean is not stated", "and / or of the two truth values"),
    "bitwise.op": ("spec/opcodes/OP_AND.md:11", "OP_AND/OP_OR/OP_XOR 'combined byte by byte': the byte operation is not stated", "the byte operation its name says"),
    "bitwise.shift-order": ("spec/opcodes/OP_LSHIFT.md:12", "OP_LSHIFT/OP_RSHIFT 'the shift by n' of a byte vector: the bit order across bytes is not stated", "the vector read as one big-endian bit string"),
    "multisig.order": ("spec/opcodes/OP_CHECKMULTISIG.md:21", "'the signatures tried against the keys from the top' (spec/rules.md:62), 'the loop (1587–1634)', 'the order rule': the consumption and failure rule is not spelled", "signatures and keys each from the top, a key consumed per attempt, fail when signatures outnumber the keys left"),
    "lock.threshold": ("spec/modules.md:2770", "LOCKTIME_THRESHOLD is named (`script.h:36`) without its value", "500,000,000 [LIT] BIP 65"),
    "lock.seq-fields": ("spec/modules.md:2771", "SEQUENCE_LOCKTIME_TYPE_FLAG and SEQUENCE_LOCKTIME_MASK are named without their values", "bit 22 and 0x0000ffff [LIT] BIP 68"),
    "tx.max-money": ("spec/theorems.md:10402", "MAX_MONEY (`amount.h:130`) is named without its value", "21,000,000 x 100,000,000 satoshis"),
    "tx.decode": ("spec/modules.md:2614-2617", "a transaction the stated serialization does not read: the reference's refusal of it is not stated", None),
    "tx.null-outpoint": ("spec/theorems.md:10318", "a null outpoint (`transaction.h:68`) is named without its value", "the zero hash with index 0xffffffff"),
    "tx.finality": ("spec/theorems.md:1149", "block finality (IsFinalTx): the early returns (:1151-1162) and the time cutoff (:1122-1146) are stated; which lock times are heights (below LOCKTIME_THRESHOLD) and that a lock time is final when strictly below the height or the cutoff are not", "a lock time below LOCKTIME_THRESHOLD is a height: final iff below the block's height"),
    "tx.finality-time": ("spec/theorems.md:1149", "a time-kind lock time compares with the cutoff of spec/theorems.md:1122-1146 (a block time), which no corpus entry carries", None),
    "tx.sequence-locks-time": ("spec/teranode-map.md:64", "a time-kind BIP 68 lock compares with the coins' median times, which no corpus entry carries", None),
    "crypto.lax-der": ("docs/DESIGN.md:293", "the lax DER parse of a signature that is not strict DER is named, not spelled", None),
    "crypto.hybrid-key": ("docs/DESIGN.md:291", "hybrid keys `06`/`07` are 'accepted here': the parity rule is not stated", "the X9.62 hybrid form: y's parity is the tag's low bit"),
    "expansion.shiftnum-order": ("spec/opcodes/OP_LSHIFTNUM.md:18", "which of the value and the count is read before the other is not stated: it decides the reason when the value read fails and the count read fails otherwise or reads negative", "the value (second) before the count (top), as the binary family reads"),
    "script_tests.limits": ("corpus/INDEX.md:419", "the limits DoTest runs the rows under are not stated", "the consensus limits of the word's UTXO era"),
}

# The labelled assumed mode (README.md, "two columns"): the gaps it fills.
ASSUMPTIONS = {gid for gid, v in GAPS.items() if v[2] is not None}

_MODE = {"assume": False, "used": set()}


def set_mode(assume):
    _MODE["assume"] = bool(assume)
    _MODE["used"] = set()


def used_assumptions():
    return sorted(_MODE["used"])


def need(gid):
    """A gap: raise in the strict mode; record and continue in the assumed mode."""
    if _MODE["assume"] and gid in ASSUMPTIONS:
        _MODE["used"].add(gid)
        return
    raise DocumentGap(gid)


# ---------------------------------------------------------------------------
# Hashes (spec/modules.md:1621-1660; [LIT] FIPS 180-4, the RIPEMD-160 paper)
# ---------------------------------------------------------------------------


def sha256(b):
    # spec/modules.md:1648: SHA-256 (FIPS 180-4 §6.2), the digest of OP_SHA256
    return hashlib.sha256(bytes(b)).digest()


def sha256d(b):
    # spec/opcodes/OP_HASH256.md:11: SHA-256 applied twice (CHash256)
    return sha256(sha256(b))


def sha1(b):
    # spec/modules.md:1639: SHA-1 (FIPS 180-4 §6.1), for OP_SHA1
    return hashlib.sha1(bytes(b)).digest()


_RMD_R = [
    0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15,
    7, 4, 13, 1, 10, 6, 15, 3, 12, 0, 9, 5, 2, 14, 11, 8,
    3, 10, 14, 4, 9, 15, 8, 1, 2, 7, 0, 6, 13, 11, 5, 12,
    1, 9, 11, 10, 0, 8, 12, 4, 13, 3, 7, 15, 14, 5, 6, 2,
    4, 0, 5, 9, 7, 12, 2, 10, 14, 1, 3, 8, 11, 6, 15, 13]
_RMD_RP = [
    5, 14, 7, 0, 9, 2, 11, 4, 13, 6, 15, 8, 1, 10, 3, 12,
    6, 11, 3, 7, 0, 13, 5, 10, 14, 15, 8, 12, 4, 9, 1, 2,
    15, 5, 1, 3, 7, 14, 6, 9, 11, 8, 12, 2, 10, 0, 4, 13,
    8, 6, 4, 1, 3, 11, 15, 0, 5, 12, 2, 13, 9, 7, 10, 14,
    12, 15, 10, 4, 1, 5, 8, 7, 6, 2, 13, 14, 0, 3, 9, 11]
_RMD_S = [
    11, 14, 15, 12, 5, 8, 7, 9, 11, 13, 14, 15, 6, 7, 9, 8,
    7, 6, 8, 13, 11, 9, 7, 15, 7, 12, 15, 9, 11, 7, 13, 12,
    11, 13, 6, 7, 14, 9, 13, 15, 14, 8, 13, 6, 5, 12, 7, 5,
    11, 12, 14, 15, 14, 15, 9, 8, 9, 14, 5, 6, 8, 6, 5, 12,
    9, 15, 5, 11, 6, 8, 13, 12, 5, 12, 13, 14, 11, 8, 5, 6]
_RMD_SP = [
    8, 9, 9, 11, 13, 15, 15, 5, 7, 7, 8, 11, 14, 14, 12, 6,
    9, 13, 15, 7, 12, 8, 9, 11, 7, 7, 12, 7, 6, 15, 13, 11,
    9, 7, 15, 11, 8, 6, 6, 14, 12, 13, 5, 14, 13, 13, 7, 5,
    15, 5, 8, 11, 14, 14, 6, 14, 6, 9, 12, 9, 12, 5, 15, 8,
    8, 5, 12, 9, 12, 5, 14, 6, 8, 13, 6, 5, 15, 13, 11, 11]
_RMD_K = [0x00000000, 0x5A827999, 0x6ED9EBA1, 0x8F1BBCDC, 0xA953FD4E]
_RMD_KP = [0x50A28BE6, 0x5C4DD124, 0x6D703EF3, 0x7A6D76E9, 0x00000000]
_M32 = 0xFFFFFFFF


def _rmd_f(j, x, y, z):
    if j < 16:
        return x ^ y ^ z
    if j < 32:
        return (x & y) | (~x & z & _M32)
    if j < 48:
        return (x | (~y & _M32)) ^ z
    if j < 64:
        return (x & z) | (y & ~z & _M32)
    return x ^ (y | (~z & _M32))


def _rol(x, n):
    return ((x << n) | (x >> (32 - n))) & _M32


def ripemd160(b):
    # spec/modules.md:1625: RIPEMD-160 for OP_RIPEMD160 and OP_HASH160;
    # [LIT] Dobbertin, Bosselaers, Preneel (1996): the five functions, the two
    # lines, the constants, the padding with a little-endian length.
    msg = bytes(b)
    ml = len(msg) * 8
    msg += b"\x80" + b"\x00" * ((55 - len(msg)) % 64) + ml.to_bytes(8, "little")
    h = [0x67452301, 0xEFCDAB89, 0x98BADCFE, 0x10325476, 0xC3D2E1F0]
    for off in range(0, len(msg), 64):
        x = [int.from_bytes(msg[off + 4 * i: off + 4 * i + 4], "little") for i in range(16)]
        a, b_, c, d, e = h
        ap, bp, cp, dp, ep = h
        for j in range(80):
            t = (_rol((a + _rmd_f(j, b_, c, d) + x[_RMD_R[j]] + _RMD_K[j // 16]) & _M32, _RMD_S[j]) + e) & _M32
            a, e, d, c, b_ = e, d, _rol(c, 10), b_, t
            t = (_rol((ap + _rmd_f(79 - j, bp, cp, dp) + x[_RMD_RP[j]] + _RMD_KP[j // 16]) & _M32, _RMD_SP[j]) + ep) & _M32
            ap, ep, dp, cp, bp = ep, dp, _rol(cp, 10), bp, t
        t = (h[1] + c + dp) & _M32
        h[1] = (h[2] + d + ep) & _M32
        h[2] = (h[3] + e + ap) & _M32
        h[3] = (h[4] + a + bp) & _M32
        h[4] = (h[0] + b_ + cp) & _M32
        h[0] = t
    return b"".join(v.to_bytes(4, "little") for v in h)


def hash160(b):
    # spec/modules.md:1626: CHash160 = RIPEMD-160 of SHA-256
    return ripemd160(sha256(b))


# ---------------------------------------------------------------------------
# secp256k1 and the ECDSA equation (spec/modules.md:1438-1456; docs/DESIGN.md:287-328;
# [LIT] SEC 2 for the constants, SEC 1 for the point encodings and the digest)
# ---------------------------------------------------------------------------

P = 2 ** 256 - 2 ** 32 - 977  # spec/modules.md:1452
N = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141  # [LIT] SEC 2 §2.4.1
GX = 0x79BE667EF9DCBBAC55A06295CE870B07029BFCDB2DCE28D959F2815B16F81798
GY = 0x483ADA7726A3C4655DA4FBFC0E1108A8FD17B448A68554199C47D08FFB10D4B8


def _ec_add(p1, p2):
    if p1 is None:
        return p2
    if p2 is None:
        return p1
    (x1, y1), (x2, y2) = p1, p2
    if x1 == x2:
        if (y1 + y2) % P == 0:
            return None
        lam = (3 * x1 * x1) * pow(2 * y1, -1, P) % P
    else:
        lam = (y2 - y1) * pow(x2 - x1, -1, P) % P
    x3 = (lam * lam - x1 - x2) % P
    return (x3, (lam * (x1 - x3) - y1) % P)


def _ec_mul(k, pt):
    # spec/modules.md:1453: double-and-add over the bits
    acc = None
    while k:
        if k & 1:
            acc = _ec_add(acc, pt)
        pt = _ec_add(pt, pt)
        k >>= 1
    return acc


def pubkey_size_from_tag(tag):
    # docs/DESIGN.md:289: IsValid, "the size from the tag byte"; [LIT] SEC 1 §2.3.3
    if tag in (2, 3):
        return 33
    if tag in (4, 6, 7):
        return 65
    return 0


def decode_point(pk):
    """docs/DESIGN.md:289-292: IsValid then point decoding; None is an invalid key."""
    if len(pk) == 0 or pubkey_size_from_tag(pk[0]) != len(pk):
        return None
    if pk[0] in (2, 3):
        x = int.from_bytes(pk[1:], "big")
        if x >= P:
            return None
        rhs = (pow(x, 3, P) + 7) % P
        y = pow(rhs, (P + 1) // 4, P)  # spec/modules.md:1466: the root by powMod to (p+1)/4
        if y * y % P != rhs:
            return None
        if (y & 1) != (pk[0] & 1):
            y = P - y
        return (x, y)
    x = int.from_bytes(pk[1:33], "big")
    y = int.from_bytes(pk[33:65], "big")
    if x >= P or y >= P or (y * y - x * x * x - 7) % P != 0:
        return None
    if pk[0] in (6, 7):
        need("crypto.hybrid-key")
        if (y & 1) != (pk[0] & 1):
            return None
    return (x, y)


def ecdsa_verify(q, z, r, s):
    # spec/modules.md:1444-1450: r != 0 and s != 0 (below n); s normalized when
    # high; u1 = z s^-1, u2 = r s^-1 mod n; R = u1 G + u2 Q != O; R.x mod n = r.
    if not (0 < r < N and 0 < s < N):
        return False
    if s > N // 2:
        s = N - s  # spec/modules.md:1444: a high s is replaced by n - s
    w = pow(s, -1, N)
    u1 = z * w % N
    u2 = r * w % N
    pt = _ec_add(_ec_mul(u1, (GX, GY)), _ec_mul(u2, q))
    if pt is None:
        return False
    return pt[0] % N == r


def is_strict_der(sig):
    """IsValidSignatureEncoding (spec/modules.md:1998; DESIGN.md:306): the strict DER
    shape of `sig` WITH its hash-type byte. The pages name it and bound it to 9..73
    bytes (spec/theorems.md:6966); the shape is [LIT] BIP 66, which the flag cites."""
    n = len(sig)
    if n < 9 or n > 73:
        return False
    if sig[0] != 0x30 or sig[1] != n - 3:
        return False
    len_r = sig[3]
    if 5 + len_r >= n:
        return False
    len_s = sig[5 + len_r]
    if len_r + len_s + 7 != n:
        return False
    if sig[2] != 0x02 or len_r == 0 or sig[4] & 0x80:
        return False
    if len_r > 1 and sig[4] == 0x00 and not (sig[5] & 0x80):
        return False
    if sig[len_r + 4] != 0x02 or len_s == 0 or sig[len_r + 6] & 0x80:
        return False
    if len_s > 1 and sig[len_r + 6] == 0x00 and not (sig[len_r + 7] & 0x80):
        return False
    return True


def parse_sig(der):
    """The lax DER parse (DESIGN.md:293-295) on a signature WITHOUT its type byte.
    On a strict-DER input the lax parse reads the two integers; an r or s above 32
    bytes or at or above n is the zero signature (DESIGN.md:294). A non-strict input
    is the lax parser's own territory, which the pages name and do not spell."""
    if not is_strict_der(bytes(der) + b"\x01"):
        need("crypto.lax-der")
        return None  # the assumed mode keeps this a gap (no assumption recorded)
    len_r = der[3]
    rb = bytes(der[4:4 + len_r]).lstrip(b"\x00")
    len_s = der[5 + len_r]
    sb = bytes(der[6 + len_r:6 + len_r + len_s]).lstrip(b"\x00")
    r = int.from_bytes(rb, "big")
    s = int.from_bytes(sb, "big")
    if len(rb) > 32 or len(sb) > 32 or r >= N or s >= N:
        return (0, 0)
    return (r, s)


def check_low_s(der):
    """CheckLowS (DESIGN.md:323-328): the lax parse then !normalize; an overflow is the
    zero signature, which is low; otherwise s <= (n-1)/2."""
    rs = parse_sig(der)
    if rs is None:
        return False
    return rs[1] <= (N - 1) // 2


# ---------------------------------------------------------------------------
# Script numbers (docs/DESIGN.md:22-81; spec/modules.md:1851-1923)
# ---------------------------------------------------------------------------


def num_decode(b):
    # docs/DESIGN.md:36-44: little-endian sign-magnitude; empty is zero; the top
    # byte's bit 7 is the sign; negative zero and padding decode to the value.
    if len(b) == 0:
        return 0
    mag = int.from_bytes(bytes(b[:-1]) + bytes([b[-1] & 0x7F]), "little")
    return -mag if b[-1] & 0x80 else mag


def num_encode(z):
    # docs/DESIGN.md:36-41 (serialize): zero is the empty vector; the magnitude's
    # bytes little-endian; a 0x00/0x80 byte when the top byte's bit 7 is set.
    if z == 0:
        return b""
    neg = z < 0
    m = -z if neg else z
    out = bytearray(m.to_bytes((m.bit_length() + 7) // 8, "little"))
    if out[-1] & 0x80:
        out.append(0x80 if neg else 0x00)
    elif neg:
        out[-1] |= 0x80
    return bytes(out)


def num_is_minimal(b, max_len):
    # docs/DESIGN.md:41-44 (IsMinimallyEncoded): size within the limit; the top byte
    # with bit 7 cleared is not zero unless the byte below it has bit 7 set.
    if len(b) > max_len:
        return False
    if len(b) == 0:
        return True
    if b[-1] & 0x7F == 0:
        if len(b) == 1 or not (b[-2] & 0x80):
            return False
    return True


def read_num(b, max_len, require_minimal):
    # spec/opcodes/OP_CHECKLOCKTIMEVERIFY.md:52 (readNum) and docs/DESIGN.md:46-50:
    # the length bound before all (SCRIPTNUM_OVERFLOW), then minimality under
    # requireMinimal (SCRIPTNUM_MINENCODE), then the decode.
    if len(b) > max_len:
        raise ScriptFail("SCRIPT_ERR_SCRIPTNUM_OVERFLOW")
    if require_minimal and not num_is_minimal(b, max_len):
        raise ScriptFail("SCRIPT_ERR_SCRIPTNUM_MINENCODE")
    return num_decode(b)


INT_MIN, INT_MAX = -(2 ** 31), 2 ** 31 - 1
INT32_MAX = 2 ** 31 - 1


def read_int64_operand(b, max_len, require_minimal):
    # spec/opcodes/OP_LEFT.md:18 (readInt64Operand) and spec/modules.md:1916-1923:
    # width and minimality, then the fixed-width reader: up to eight bytes
    # sign-magnitude; nine need a pure sign byte and a magnitude below 2^63, or
    # exactly 2^63 negative; longer is no value, SCRIPT_ERR_SCRIPTNUM_OVERFLOW.
    if len(b) > max_len:
        raise ScriptFail("SCRIPT_ERR_SCRIPTNUM_OVERFLOW")
    if require_minimal and not num_is_minimal(b, max_len):
        raise ScriptFail("SCRIPT_ERR_SCRIPTNUM_MINENCODE")
    if len(b) <= 8:
        v = num_decode(b)
    elif len(b) == 9:
        if b[8] not in (0x00, 0x80):
            raise ScriptFail("SCRIPT_ERR_SCRIPTNUM_OVERFLOW")
        mag = int.from_bytes(bytes(b[:8]), "little")
        neg = b[8] == 0x80
        if mag < 2 ** 63 or (mag == 2 ** 63 and neg):
            v = -mag if neg else mag
        else:
            raise ScriptFail("SCRIPT_ERR_SCRIPTNUM_OVERFLOW")
    else:
        raise ScriptFail("SCRIPT_ERR_SCRIPTNUM_OVERFLOW")
    # spec/opcodes/OP_SUBSTR.md:45 (getint): saturation to the int range
    return max(INT_MIN, min(INT_MAX, v))


def cast_to_bool(b):
    # docs/DESIGN.md:80-81 (CastToBool): every byte zero, or only the top byte 0x80
    # with the rest zero, is false.
    for i, x in enumerate(b):
        if x != 0:
            return not (i == len(b) - 1 and x == 0x80)
    return False


def minimally_encode(b):
    # spec/opcodes/OP_BIN2NUM.md:28: the canonical re-encoding encode(decode b) (T4)
    return num_encode(num_decode(b))


# ---------------------------------------------------------------------------
# Opcodes (spec/README.md:21-133, the table)
# ---------------------------------------------------------------------------

OP_0, OP_PUSHDATA1, OP_PUSHDATA2, OP_PUSHDATA4 = 0x00, 0x4C, 0x4D, 0x4E
OP_1NEGATE, OP_RESERVED, OP_1, OP_16 = 0x4F, 0x50, 0x51, 0x60
OP_NOP, OP_VER, OP_IF, OP_NOTIF, OP_VERIF, OP_VERNOTIF = 0x61, 0x62, 0x63, 0x64, 0x65, 0x66
OP_ELSE, OP_ENDIF, OP_VERIFY, OP_RETURN = 0x67, 0x68, 0x69, 0x6A
OP_TOALTSTACK, OP_FROMALTSTACK, OP_2DROP, OP_2DUP, OP_3DUP = 0x6B, 0x6C, 0x6D, 0x6E, 0x6F
OP_2OVER, OP_2ROT, OP_2SWAP, OP_IFDUP, OP_DEPTH, OP_DROP = 0x70, 0x71, 0x72, 0x73, 0x74, 0x75
OP_DUP, OP_NIP, OP_OVER, OP_PICK, OP_ROLL, OP_ROT, OP_SWAP, OP_TUCK = 0x76, 0x77, 0x78, 0x79, 0x7A, 0x7B, 0x7C, 0x7D
OP_CAT, OP_SPLIT, OP_NUM2BIN, OP_BIN2NUM, OP_SIZE = 0x7E, 0x7F, 0x80, 0x81, 0x82
OP_INVERT, OP_AND, OP_OR, OP_XOR, OP_EQUAL, OP_EQUALVERIFY = 0x83, 0x84, 0x85, 0x86, 0x87, 0x88
OP_RESERVED1, OP_RESERVED2 = 0x89, 0x8A
OP_1ADD, OP_1SUB, OP_2MUL, OP_2DIV, OP_NEGATE, OP_ABS, OP_NOT, OP_0NOTEQUAL = range(0x8B, 0x93)
(OP_ADD, OP_SUB, OP_MUL, OP_DIV, OP_MOD, OP_LSHIFT, OP_RSHIFT, OP_BOOLAND, OP_BOOLOR,
 OP_NUMEQUAL, OP_NUMEQUALVERIFY, OP_NUMNOTEQUAL, OP_LESSTHAN, OP_GREATERTHAN,
 OP_LESSTHANOREQUAL, OP_GREATERTHANOREQUAL, OP_MIN, OP_MAX, OP_WITHIN) = range(0x93, 0xA6)
OP_RIPEMD160, OP_SHA1, OP_SHA256, OP_HASH160, OP_HASH256 = range(0xA6, 0xAB)
OP_CODESEPARATOR, OP_CHECKSIG, OP_CHECKSIGVERIFY, OP_CHECKMULTISIG, OP_CHECKMULTISIGVERIFY = range(0xAB, 0xB0)
OP_NOP1, OP_CHECKLOCKTIMEVERIFY, OP_CHECKSEQUENCEVERIFY = 0xB0, 0xB1, 0xB2
OP_SUBSTR, OP_LEFT, OP_RIGHT, OP_LSHIFTNUM, OP_RSHIFTNUM, OP_NOP9, OP_NOP10 = range(0xB3, 0xBA)

# ---------------------------------------------------------------------------
# The parser (docs/DESIGN.md:14-20; spec/opcodes/OP_PUSHDATA1.md:12, getOpTail)
# ---------------------------------------------------------------------------


def get_op(script, pc):
    """GetOp2: (opcode, data, next pc, header_len) or None for a failed parse.
    Below OP_PUSHDATA1 the size is the opcode; then 1, 2 or 4 little-endian length
    bytes; a truncated length or push fails (spec/opcodes/OP_PUSHDATA1.md:12)."""
    if pc >= len(script):
        return None
    op = script[pc]
    pc += 1
    if op > OP_PUSHDATA4:
        return (op, b"", pc, 1)
    if op < OP_PUSHDATA1:
        size, hdr = op, 1
    else:
        width = {OP_PUSHDATA1: 1, OP_PUSHDATA2: 2, OP_PUSHDATA4: 4}[op]
        if pc + width > len(script):
            return None
        size = int.from_bytes(bytes(script[pc:pc + width]), "little")
        pc += width
        hdr = 1 + width
    if pc + size > len(script):
        return None
    return (op, bytes(script[pc:pc + size]), pc + size, hdr)


def truncated_head(script, pc):
    """The bytes GetOp2 consumes before failing (spec/theorems.md:9612, T-SH11): the
    opcode and, for OP_PUSHDATA1/2/4, the length prefix when wholly present."""
    op = script[pc]
    if op in (OP_PUSHDATA1, OP_PUSHDATA2, OP_PUSHDATA4):
        width = {OP_PUSHDATA1: 1, OP_PUSHDATA2: 2, OP_PUSHDATA4: 4}[op]
        if pc + 1 + width <= len(script):
            return 1 + width
    return 1


def is_push_only(script):
    # spec/opcodes/OP_16.md:7 (isPushOnly): every instruction parses and no opcode
    # is above OP_16 (OP_RESERVED counts as a push).
    pc = 0
    while pc < len(script):
        r = get_op(script, pc)
        if r is None or r[0] > OP_16:
            return False
        pc = r[2]
    return True


def is_p2sh(script):
    # spec/opcodes/OP_EQUAL.md:25 (isP2SH): 23 bytes, OP_HASH160 <20 bytes> OP_EQUAL
    return len(script) == 23 and script[0] == OP_HASH160 and script[1] == 0x14 and script[22] == OP_EQUAL


def push_data_script(data):
    """CScript(vchSig) (spec/theorems.md:9597-9608): a push opcode then the bytes; 1, 2,
    3 or 5 header bytes by size class (direct below OP_PUSHDATA1, then 1-, 2-, 4-byte
    prefixes)."""
    n = len(data)
    if n < OP_PUSHDATA1:
        return bytes([n]) + data
    if n <= 0xFF:
        return bytes([OP_PUSHDATA1, n]) + data
    if n <= 0xFFFF:
        return bytes([OP_PUSHDATA2]) + n.to_bytes(2, "little") + data
    return bytes([OP_PUSHDATA4]) + n.to_bytes(4, "little") + data


def is_minimal_push(op, data):
    # spec/theorems.md:8940-8943 (execStep_minimaldata): the smallest form for its data,
    # among the push forms of docs/DESIGN.md:14-20 and the OP_1NEGATE / OP_1..OP_16 pages
    n = len(data)
    if n == 0:
        return op == OP_0
    if n == 1 and 1 <= data[0] <= 16:
        return op == OP_1 + data[0] - 1
    if n == 1 and data[0] == 0x81:
        return op == OP_1NEGATE
    if n <= 75:
        return op == n
    if n <= 255:
        return op == OP_PUSHDATA1
    if n <= 65535:
        return op == OP_PUSHDATA2
    return True


def find_and_delete(script, pattern):
    """CScript::FindAndDelete, one pass (spec/modules.md:2685-2690; spec/theorems.md:
    9778-9836): at every instruction start strip every copy of the pattern that
    begins there, then copy the next instruction whole; a tail the parser cannot
    read is appended as it stands."""
    if not pattern:
        return bytes(script)  # T-SH5
    out = bytearray()
    pc = 0
    n = len(script)
    while True:
        while script[pc:pc + len(pattern)] == pattern:
            pc += len(pattern)
        if pc >= n:
            break
        r = get_op(script, pc)
        if r is None:
            out += script[pc:]
            break
        out += script[pc:r[2]]
        pc = r[2]
    return bytes(out)


# ---------------------------------------------------------------------------
# Flags and parameters (spec/flags.md; docs/PARAMETERS.md §1-§3)
# ---------------------------------------------------------------------------

F = {  # spec/flags.md:5-25, the bits
    "P2SH": 0, "STRICTENC": 1, "DERSIG": 2, "LOW_S": 3, "NULLDUMMY": 4, "SIGPUSHONLY": 5,
    "MINIMALDATA": 6, "DISCOURAGE_UPGRADABLE_NOPS": 7, "CLEANSTACK": 8,
    "CHECKLOCKTIMEVERIFY": 9, "CHECKSEQUENCEVERIFY": 10, "MINIMALIF": 13, "NULLFAIL": 14,
    "COMPRESSED_PUBKEYTYPE": 15, "SIGHASH_FORKID": 16, "GENESIS": 18,
    "UTXO_AFTER_GENESIS": 19, "CHRONICLE": 20, "UTXO_AFTER_CHRONICLE": 21,
}


def word(*names):
    w = 0
    for nm in names:
        w |= 1 << F[nm]
    return w


def has(w, nm):
    return bool(w >> F[nm] & 1)


# spec/opcodes/OP_CHECKSEQUENCEVERIFY.md:52 (ChainParams.mainnet)
MAINNET = {"p2sh": 173805, "bip66": 363725, "bip65": 388381, "csv": 419328,
           "uahf": 478558, "daa": 504031, "genesis": 620538, "chronicle": 943816}

PRE_GENESIS, POST_GENESIS, POST_CHRONICLE = 0, 1, 2


def era_of(height, chain=MAINNET):
    # spec/flags.md:37-41 (protocolEraOf): below Genesis pre-Genesis, below
    # Chronicle post-Genesis, else post-Chronicle.
    if height < chain["genesis"]:
        return PRE_GENESIS
    if height < chain["chronicle"]:
        return POST_GENESIS
    return POST_CHRONICLE


def block_word(tip, era, chain=MAINNET):
    # spec/flags.md:96-105 (blockScriptFlags): P2SH from p2shHeight; DERSIG, CLTV, CSV
    # from height + 1; STRICTENC and FORKID from uahfHeight; LOW_S and NULLFAIL
    # from daaHeight; GENESIS and SIGPUSHONLY with Genesis; CHRONICLE with Chronicle.
    w = 0
    if tip >= chain["p2sh"]:
        w |= word("P2SH")
    if tip + 1 >= chain["bip66"]:
        w |= word("DERSIG")
    if tip + 1 >= chain["bip65"]:
        w |= word("CHECKLOCKTIMEVERIFY")
    if tip + 1 >= chain["csv"]:
        w |= word("CHECKSEQUENCEVERIFY")
    if tip >= chain["uahf"]:
        w |= word("STRICTENC", "SIGHASH_FORKID")
    if tip >= chain["daa"]:
        w |= word("LOW_S", "NULLFAIL")
    if era >= POST_GENESIS:
        w |= word("GENESIS", "SIGPUSHONLY")
    if era >= POST_CHRONICLE:
        w |= word("CHRONICLE")
    return w


def mempool_word(era):
    # spec/flags.md:60-87: the era's mandatory set (P2SH, STRICTENC, FORKID, NULLFAIL,
    # LOW_S, plus CHRONICLE post-Chronicle) with the standard set (DERSIG, NULLDUMMY,
    # DISCOURAGE_UPGRADABLE_NOPS, CLTV, CSV, CLEANSTACK, MINIMALDATA), plus GENESIS
    # when Genesis is active; requireStandard on mainnet (docs/PARAMETERS.md §3).
    w = word("P2SH", "STRICTENC", "SIGHASH_FORKID", "NULLFAIL", "LOW_S",
             "DERSIG", "NULLDUMMY", "DISCOURAGE_UPGRADABLE_NOPS", "CHECKLOCKTIMEVERIFY",
             "CHECKSEQUENCEVERIFY", "CLEANSTACK", "MINIMALDATA")
    if era >= POST_CHRONICLE:
        w |= word("CHRONICLE")
    if era >= POST_GENESIS:
        w |= word("GENESIS")
    return w


def input_word(era, utxo_era):
    # spec/flags.md:89-94 (inputScriptVerifyFlags)
    w = 0
    if era >= POST_GENESIS:
        w |= word("SIGPUSHONLY")
    if utxo_era >= POST_GENESIS:
        w |= word("UTXO_AFTER_GENESIS")
    if utxo_era >= POST_CHRONICLE:
        w |= word("UTXO_AFTER_CHRONICLE")
    return w


UINT32_MAX = 2 ** 32 - 1
INT64_MAX = 2 ** 63 - 1

# The node configuration the corpus's node columns ran under (docs/PARAMETERS.md §1,
# the policy column's bitcoin-sv defaults; docs/DESIGN.md:550-560: the consensus
# instance zeroes every policy setting; maxstackmemoryusageconsensus set 0 -> INT64_MAX).
SV_POLICY = {"ops": UINT32_MAX, "numlen": 10000, "size": 500000, "keys": UINT32_MAX, "mem": 100000000}
STACK_MEM_CONSENSUS = INT64_MAX


def limits_for(w, consensus, policy=SV_POLICY):
    # spec/flags.md:136-151 (limitsFor), :174-189 (pre-Genesis, era consensus limits)
    if not has(w, "UTXO_AFTER_GENESIS"):
        return {"ops": 500, "numlen": 4, "size": 10000, "keys": 20, "mem": INT64_MAX}
    if consensus:
        return {"ops": UINT32_MAX,
                "numlen": 32000000 if has(w, "UTXO_AFTER_CHRONICLE") else 750000,
                "size": UINT32_MAX, "keys": UINT32_MAX, "mem": STACK_MEM_CONSENSUS}
    return dict(policy)


def derive(spend_height, utxo_height, consensus, chain=MAINNET):
    # spec/flags.md:153-172 (flagWord, derive): the block word at spendHeight - 1 with
    # the era of spendHeight under consensus, else the mempool word of that era,
    # united with the per-input word; the limits from that word.
    era = era_of(spend_height, chain)
    utxo_era = era_of(utxo_height, chain)
    w = block_word(spend_height - 1, era, chain) if consensus else mempool_word(era)
    w |= input_word(era, utxo_era)
    return w, limits_for(w, consensus)


# ---------------------------------------------------------------------------
# The transaction (spec/modules.md:2748-2759, Tx; serialization per spec/modules.md:2614-2617)
# ---------------------------------------------------------------------------


class Tx:
    def __init__(self, version, vin, vout, locktime):
        self.version = version  # int32 as read (docs/DESIGN.md:126-129)
        self.vin = vin  # [(txid32 as stored, index, script, sequence)]
        self.vout = vout  # [(value int64, script)]
        self.locktime = locktime


def _read_compact(b, i):
    # spec/modules.md:2617: CompactSize; docs/DESIGN.md:965: canonical encodings
    x = b[i]
    if x < 0xFD:
        return x, i + 1
    w = {0xFD: 2, 0xFE: 4, 0xFF: 8}[x]
    v = int.from_bytes(b[i + 1:i + 1 + w], "little")
    if i + 1 + w > len(b) or v < {2: 0xFD, 4: 0x10000, 8: 0x100000000}[w]:
        raise ValueError("non-canonical compact size")
    return v, i + 1 + w


def compact(n):
    # spec/modules.md:2617: CompactSize, little-endian
    if n < 0xFD:
        return bytes([n])
    if n <= 0xFFFF:
        return b"\xfd" + n.to_bytes(2, "little")
    if n <= 0xFFFFFFFF:
        return b"\xfe" + n.to_bytes(4, "little")
    return b"\xff" + n.to_bytes(8, "little")


def decode_tx(raw):
    # spec/modules.md:2614-2617: the version, the inputs (COutPoint: the txid as stored then
    # the index; the script; the sequence), the outputs (CTxOut: the value then the script),
    # the lock time; CompactSize counts, every integer little-endian. Bytes after the lock
    # time are not read: no page states their refusal.
    b = bytes(raw)
    i = 0
    version = int.from_bytes(b[0:4], "little", signed=True)
    i = 4
    n, i = _read_compact(b, i)
    vin = []
    for _ in range(n):
        txid = b[i:i + 32]
        idx = int.from_bytes(b[i + 32:i + 36], "little")
        i += 36
        ln, i = _read_compact(b, i)
        script = b[i:i + ln]
        i += ln
        seq = int.from_bytes(b[i:i + 4], "little")
        i += 4
        vin.append((txid, idx, script, seq))
    n, i = _read_compact(b, i)
    vout = []
    for _ in range(n):
        val = int.from_bytes(b[i:i + 8], "little", signed=True)
        i += 8
        ln, i = _read_compact(b, i)
        vout.append((val, b[i:i + ln]))
        i += ln
    locktime = int.from_bytes(b[i:i + 4], "little")
    return Tx(version, vin, vout, locktime)


def ser_tx(tx):
    # spec/modules.md:2614-2617: the serialization decode_tx reads, written back
    out = bytearray((tx.version & 0xFFFFFFFF).to_bytes(4, "little"))
    out += compact(len(tx.vin))
    for txid, idx, script, seq in tx.vin:
        out += txid + idx.to_bytes(4, "little") + compact(len(script)) + script + seq.to_bytes(4, "little")
    out += compact(len(tx.vout))
    for val, script in tx.vout:
        out += (val & 0xFFFFFFFFFFFFFFFF).to_bytes(8, "little") + compact(len(script)) + script
    out += tx.locktime.to_bytes(4, "little")
    return bytes(out)


# ---------------------------------------------------------------------------
# The signature hash (docs/DESIGN.md:354-369; spec/modules.md:2606-2642;
# spec/theorems.md:9371-9836; [LIT] BIP 143)
# ---------------------------------------------------------------------------

SIGHASH_ALL, SIGHASH_NONE, SIGHASH_SINGLE = 1, 2, 3
SIGHASH_CHRONICLE, SIGHASH_FORKID, SIGHASH_ANYONECANPAY = 0x20, 0x40, 0x80
ONE256 = b"\x01" + b"\x00" * 31  # spec/theorems.md:9425; the integer 1 in little-endian bytes (spec/modules.md:150-151)


def base_type(t):
    return t & 0x1F  # spec/theorems.md:9505: the base type is five bits


def is_defined(t):
    # spec/theorems.md:9511-9528 (isDefined): defined iff the base is ALL, NONE or SINGLE
    return base_type(t & 0xFF) in (SIGHASH_ALL, SIGHASH_NONE, SIGHASH_SINGLE)


def ser_script_code_original(code):
    """SerializeScriptCode (spec/modules.md:2630-2642; spec/theorems.md:9630-9670): a size
    prefix of the whole script minus the separators parsed, then every instruction but
    OP_CODESEPARATOR, and on a parse failure the bytes up to the failure point."""
    out = bytearray()
    seps = 0
    pc = 0
    while pc < len(code):
        r = get_op(code, pc)
        if r is None:
            out += code[pc:pc + truncated_head(code, pc)]
            break
        if r[0] == OP_CODESEPARATOR:
            seps += 1
        else:
            out += code[pc:r[2]]
        pc = r[2]
    return compact(len(code) - seps) + bytes(out)


def sighash_original(code, tx, n_in, t):
    # docs/DESIGN.md:362-369 and spec/theorems.md:9442-9456, 9723-9756
    if n_in >= len(tx.vin):
        return ONE256
    base = base_type(t)
    if base == SIGHASH_SINGLE and n_in >= len(tx.vout):
        return ONE256
    acp = bool(t & SIGHASH_ANYONECANPAY)
    out = bytearray((tx.version & 0xFFFFFFFF).to_bytes(4, "little"))
    inputs = [n_in] if acp else range(len(tx.vin))
    out += compact(len(inputs))
    for i in inputs:
        txid, idx, _script, seq = tx.vin[i]
        out += txid + idx.to_bytes(4, "little")
        if i == n_in:
            out += ser_script_code_original(code)
        else:
            out += b"\x00"
        if i != n_in and base in (SIGHASH_SINGLE, SIGHASH_NONE):
            seq = 0
        out += seq.to_bytes(4, "little")
    if base == SIGHASH_NONE:
        outs = []
    elif base == SIGHASH_SINGLE:
        outs = list(range(n_in + 1))
    else:
        outs = list(range(len(tx.vout)))
    out += compact(len(outs))
    for j in outs:
        if base == SIGHASH_SINGLE and j != n_in:
            out += (2 ** 64 - 1).to_bytes(8, "little") + b"\x00"  # the null CTxOut, nValue = -1
        else:
            val, script = tx.vout[j]
            out += (val & 0xFFFFFFFFFFFFFFFF).to_bytes(8, "little") + compact(len(script)) + script
    out += tx.locktime.to_bytes(4, "little")
    out += (t & 0xFFFFFFFF).to_bytes(4, "little")
    return sha256d(out)


def sighash_bip143(code, tx, n_in, t, amount):
    # docs/DESIGN.md:355-361; spec/theorems.md:9672-9721; [LIT] BIP 143
    base = base_type(t)
    acp = bool(t & SIGHASH_ANYONECANPAY)
    zero = b"\x00" * 32
    hp = zero if acp else sha256d(b"".join(v[0] + v[1].to_bytes(4, "little") for v in tx.vin))
    hs = zero if (acp or base in (SIGHASH_SINGLE, SIGHASH_NONE)) else sha256d(
        b"".join(v[3].to_bytes(4, "little") for v in tx.vin))
    if base not in (SIGHASH_SINGLE, SIGHASH_NONE):
        ho = sha256d(b"".join((v & 0xFFFFFFFFFFFFFFFF).to_bytes(8, "little") + compact(len(s)) + s for v, s in tx.vout))
    elif base == SIGHASH_SINGLE and n_in < len(tx.vout):
        v, s = tx.vout[n_in]
        ho = sha256d((v & 0xFFFFFFFFFFFFFFFF).to_bytes(8, "little") + compact(len(s)) + s)
    else:
        ho = zero
    txid, idx, _script, seq = tx.vin[n_in]
    pre = ((tx.version & 0xFFFFFFFF).to_bytes(4, "little") + hp + hs + txid + idx.to_bytes(4, "little")
           + compact(len(code)) + bytes(code) + (amount & 0xFFFFFFFFFFFFFFFF).to_bytes(8, "little")
           + seq.to_bytes(4, "little") + ho + tx.locktime.to_bytes(4, "little")
           + (t & 0xFFFFFFFF).to_bytes(4, "little"))
    return sha256d(pre)


def signature_hash(code, tx, n_in, t, amount, forkid_enabled):
    # spec/theorems.md:9462-9470 (T-SH6): BIP143 iff FORKID enabled, the FORKID bit and
    # not the CHRONICLE bit; the original digest otherwise.
    if forkid_enabled and t & SIGHASH_FORKID and not t & SIGHASH_CHRONICLE:
        return sighash_bip143(code, tx, n_in, t, amount)
    return sighash_original(code, tx, n_in, t)


# ---------------------------------------------------------------------------
# The checker context (docs/DESIGN.md:123-130, 447-454; spec/modules.md:2765-2780)
# ---------------------------------------------------------------------------


class Checker:
    def __init__(self, tx, n_in, amount):
        self.tx, self.n_in, self.amount = tx, n_in, amount

    def version(self):
        return self.tx.version  # docs/DESIGN.md:126-129: signed by the gate

    def check_sig(self, sig, pk, code, forkid_enabled):
        # docs/DESIGN.md:345-347 (CheckSig, 2133-2164): the key non-empty, the signature
        # non-empty, its last byte the hash type, the digest, then DESIGN §4.1.
        if len(pk) == 0 or len(sig) == 0:
            return False
        q = decode_point(pk)
        if q is None:
            return False
        t = sig[-1]
        rs = parse_sig(sig[:-1])
        if rs is None:
            return False
        digest = signature_hash(code, self.tx, self.n_in, t, self.amount, forkid_enabled)
        z = int.from_bytes(digest, "big")  # [LIT] SEC 1 §4.1.4: the digest read big-endian
        return ecdsa_verify(q, z, rs[0], rs[1])

    def check_lock_time(self, lock):
        # spec/theorems.md (checkLockTime_iff, OP_CHECKLOCKTIMEVERIFY.md:386-396): one kind
        # (both below LOCKTIME_THRESHOLD or both at least it), the operand at most the lock
        # time, the spent input not final.
        need("lock.threshold")
        thr = 500000000
        lt = self.tx.locktime
        if not ((lt < thr and lock < thr) or (lt >= thr and lock >= thr)):
            return False
        if lock > lt:
            return False
        if self.n_in >= len(self.tx.vin):
            return False  # checkSequence_missing_input: past the inputs reads as final
        return self.tx.vin[self.n_in][3] != 0xFFFFFFFF  # SEQUENCE_FINAL (spec/theorems.md:7852)

    def check_sequence(self, seq_op):
        # checkSequence_iff (spec/opcodes/OP_CHECKSEQUENCEVERIFY.md, thms 659-668): the
        # version at least 2 unsigned; no disable flag (bit 31) on the input's sequence;
        # both masked to the type flag and the low sixteen bits, of one kind, the operand's
        # at most the sequence's.
        if (self.tx.version & 0xFFFFFFFF) < 2:
            return False
        if self.n_in >= len(self.tx.vin):
            return False
        seq = self.tx.vin[self.n_in][3]
        if seq & (1 << 31):
            return False
        need("lock.seq-fields")
        type_flag, mask = 1 << 22, 0x0000FFFF
        a = seq_op & (type_flag | mask)
        b = seq & (type_flag | mask)
        if (a & type_flag) != (b & type_flag):
            return False
        return a <= b


# ---------------------------------------------------------------------------
# The machine (docs/DESIGN.md:94-117 the state; :193-241 the loop and flow)
# ---------------------------------------------------------------------------


class Env:
    """One EvalScript call's parameters: the word, the limits, the eras, the checker."""

    def __init__(self, w, limits, checker, enforce, phase1_lock=None):
        self.w = w
        self.lim = limits
        self.checker = checker
        self.enforce = enforce  # EnforceNonMalleability (docs/DESIGN.md:422-431)
        self.utxo_genesis = has(w, "UTXO_AFTER_GENESIS")
        self.utxo_chronicle = has(w, "UTXO_AFTER_CHRONICLE")
        self.phase1_lock = phase1_lock  # the locking script the unlocking phase sees (DESIGN.md:114-115)
        # docs/DESIGN.md:195-196: requireMinimal = MINIMALDATA and the version gate
        self.require_minimal = has(w, "MINIMALDATA") and enforce


class Stacks:
    """The main stack (crossing phases), the alt stack, and the memory counter
    (docs/DESIGN.md:94-105: each element costs its size plus 32; the counter lives
    in the root and is not given back for the alt stack's leftovers)."""

    def __init__(self, max_mem):
        self.main = []  # the bottom at index 0, the top at the end
        self.alt = []
        self.mem = 0
        self.max_mem = max_mem

    def charge(self, n):
        # docs/DESIGN.md:97-99: exceeding the budget is SCRIPT_ERR_STACK_SIZE;
        # spec/theorems.md (W5): refused when the counter exceeds MaxStackMemoryUsage
        self.mem += n
        if self.mem > self.max_mem:
            raise ScriptFail("SCRIPT_ERR_STACK_SIZE")

    def push(self, v):
        self.charge(len(v) + 32)
        self.main.append(bytes(v))

    def pop(self):
        v = self.main.pop()
        self.mem -= len(v) + 32
        return v

    def need(self, k):
        # spec/theorems.md:7029 (need) and vDropEmpty_kernel (theorems.md:8364): too few
        # elements is SCRIPT_ERR_INVALID_STACK_OPERATION
        if len(self.main) < k:
            raise ScriptFail("SCRIPT_ERR_INVALID_STACK_OPERATION")

    def top(self, k=0):
        return self.main[-1 - k]

    def replace_top(self, v):
        old = self.main[-1]
        self.charge(len(v) - len(old))
        self.main[-1] = bytes(v)


class Cond:
    """conditional_tracker (docs/DESIGN.md:105-109): the branch conditions, the else
    marks, the count of false conditions; active iff that count is zero."""

    def __init__(self):
        self.conds = []
        self.else_seen = []

    def active(self):
        return all(self.conds)

    def empty(self):
        return not self.conds


def bool_bytes(b):
    # spec/opcodes/OP_WITHIN.md:12 (pushBool): [0x01] or []
    return b"\x01" if b else b""


def read_operand(st, k, env):
    # spec/theorems.md:6913-6920 (readOperand): the element k below the top at the
    # number width in force, minimal under requireMinimal
    return read_num(st.top(k), env.lim["numlen"], env.require_minimal)


def push_num(st, z, env, bounded):
    # docs/DESIGN.md:60-63: post-Genesis +=, -=, *= and <<= throw when the result's size
    # exceeds the limit; pre-Genesis results are unbounded.
    v = num_encode(z)
    if bounded and env.utxo_genesis and len(v) > env.lim["numlen"]:
        raise ScriptFail("SCRIPT_ERR_SCRIPTNUM_OVERFLOW")
    st.push(v)


def version_le(env):
    # spec/opcodes/OP_VER.md:11 (versionLE): the int32 version, four little-endian bytes
    return (env.checker.version() & 0xFFFFFFFF).to_bytes(4, "little")


def tdiv(a, b):
    # docs/DESIGN.md:56-59: truncation toward zero
    q = abs(a) // abs(b)
    return q if (a >= 0) == (b >= 0) else -q


def tmod(a, b):
    # docs/DESIGN.md:56-59: the remainder takes the dividend's sign
    return a - b * tdiv(a, b)


def exec_op(op, script, nxt, codesep, st, env, cond, f_exec):
    w = env.w
    # --- the constants (DESIGN.md:253; OP_n's value, spec/opcodes/OP_0.md:12 DecodeOP_N,
    # pushed as a number: vDepth_kernel, spec/theorems.md:8382)
    if op == OP_1NEGATE:
        st.push(num_encode(-1))
        return None
    if OP_1 <= op <= OP_16:
        st.push(num_encode(op - OP_1 + 1))
        return None
    if op in (OP_RESERVED, OP_RESERVED1, OP_RESERVED2) or op > OP_NOP10:
        raise ScriptFail("SCRIPT_ERR_BAD_OPCODE")  # spec/opcodes/OP_1.md:7 (hasCase)
    if op == OP_NOP:
        return None  # DESIGN.md:235
    if op in (OP_NOP1, OP_NOP9, OP_NOP10):
        # DESIGN.md:235-236: no-ops unless DISCOURAGE_UPGRADABLE_NOPS
        if has(w, "DISCOURAGE_UPGRADABLE_NOPS"):
            raise ScriptFail("SCRIPT_ERR_DISCOURAGE_UPGRADABLE_NOPS")
        return None
    if op == OP_VER:
        # DESIGN.md:236-237
        if not env.utxo_chronicle:
            raise ScriptFail("SCRIPT_ERR_BAD_OPCODE")
        st.push(version_le(env))
        return None
    if op in (OP_IF, OP_NOTIF, OP_VERIF, OP_VERNOTIF):
        return exec_if(op, st, env, cond, f_exec)
    if op == OP_ELSE:
        # DESIGN.md:224-227: an empty tracker, or post-Genesis a second ELSE, is unbalanced
        if cond.empty():
            raise ScriptFail("SCRIPT_ERR_UNBALANCED_CONDITIONAL")
        if env.utxo_genesis and cond.else_seen[-1]:
            raise ScriptFail("SCRIPT_ERR_UNBALANCED_CONDITIONAL")
        cond.conds[-1] = not cond.conds[-1]
        cond.else_seen[-1] = True
        return None
    if op == OP_ENDIF:
        if cond.empty():
            raise ScriptFail("SCRIPT_ERR_UNBALANCED_CONDITIONAL")  # vEndifAlone_kernel
        cond.conds.pop()
        cond.else_seen.pop()
        return None
    if op == OP_VERIFY:
        # spec/theorems.md:8412 (vVerifyFalse_kernel): a false top fails SCRIPT_ERR_VERIFY
        if not st.main:
            need("stack.verify-empty")
            raise ScriptFail("SCRIPT_ERR_INVALID_STACK_OPERATION")
        if not cast_to_bool(st.top()):
            raise ScriptFail("SCRIPT_ERR_VERIFY")
        st.pop()
        return None
    if op == OP_RETURN:
        # DESIGN.md:228-235
        if not env.utxo_genesis:
            raise ScriptFail("SCRIPT_ERR_OP_RETURN")
        if cond.empty():
            return "return"
        return "mark-return"
    if op in (OP_CHECKLOCKTIMEVERIFY, OP_CHECKSEQUENCEVERIFY):
        return exec_locktime(op, st, env)
    if OP_TOALTSTACK <= op <= OP_TUCK:
        return exec_stack(op, st, env)
    if op in (OP_CAT, OP_SPLIT, OP_NUM2BIN, OP_BIN2NUM, OP_SIZE):
        return exec_splice(op, st, env)
    if op in (OP_INVERT, OP_AND, OP_OR, OP_XOR, OP_EQUAL, OP_EQUALVERIFY, OP_LSHIFT, OP_RSHIFT):
        return exec_bitwise(op, st, env)
    if OP_1ADD <= op <= OP_WITHIN:
        return exec_arith(op, st, env)
    if OP_RIPEMD160 <= op <= OP_HASH256:
        # spec/theorems.md (hashOp_ok, W2): the top replaced by its digest
        st.need(1)
        x = st.pop()
        fn = {OP_RIPEMD160: ripemd160, OP_SHA1: sha1, OP_SHA256: sha256,
              OP_HASH160: hash160, OP_HASH256: sha256d}[op]
        st.push(fn(x))
        return None
    if op in (OP_CHECKSIG, OP_CHECKSIGVERIFY):
        return exec_checksig(op, script, codesep, st, env)
    if op in (OP_CHECKMULTISIG, OP_CHECKMULTISIGVERIFY):
        return exec_multisig(op, script, codesep, st, env)
    if OP_SUBSTR <= op <= OP_RSHIFTNUM:
        return exec_expansion(op, st, env)
    raise AssertionError("unreachable opcode %02x" % op)


def exec_if(op, st, env, cond, f_exec):
    # spec/opcodes/OP_NOTIF.md:11 (execIf) and docs/DESIGN.md:213-224
    if op in (OP_VERIF, OP_VERNOTIF) and not env.utxo_chronicle:
        # DESIGN.md:219-221: pre-Chronicle BAD_OPCODE, even unexecuted pre-Genesis,
        # post-Genesis only when executed; unexecuted there they are skipped
        # (spec/theorems.md, execFlow_verif_postGenesis_preChronicle: 777-778)
        if f_exec or not env.utxo_genesis:
            raise ScriptFail("SCRIPT_ERR_BAD_OPCODE")
        return None
    value = False
    if f_exec:
        if not st.main:
            raise ScriptFail("SCRIPT_ERR_UNBALANCED_CONDITIONAL")  # DESIGN.md:214-215
        top = st.top()
        if op in (OP_IF, OP_NOTIF):
            if has(env.w, "MINIMALIF") and env.enforce and top not in (b"", b"\x01"):
                raise ScriptFail("SCRIPT_ERR_MINIMALIF")  # DESIGN.md:215-217
            value = cast_to_bool(top)
        else:
            value = top == version_le(env)  # DESIGN.md:221-224
        if op in (OP_NOTIF, OP_VERNOTIF):
            value = not value
        st.pop()
    cond.conds.append(value)
    cond.else_seen.append(False)
    return None


def exec_locktime(op, st, env):
    # spec/opcodes/OP_CHECKLOCKTIMEVERIFY.md:11-25 (execCltv, execCsv)
    flag = "CHECKLOCKTIMEVERIFY" if op == OP_CHECKLOCKTIMEVERIFY else "CHECKSEQUENCEVERIFY"
    if env.utxo_genesis or not has(env.w, flag):
        if has(env.w, "DISCOURAGE_UPGRADABLE_NOPS"):
            raise ScriptFail("SCRIPT_ERR_DISCOURAGE_UPGRADABLE_NOPS")
        return None
    st.need(1)  # spec/theorems.md:7818: the empty stack (528-529)
    n = read_num(st.top(), 5, env.require_minimal)
    if n < 0:
        raise ScriptFail("SCRIPT_ERR_NEGATIVE_LOCKTIME")
    if op == OP_CHECKLOCKTIMEVERIFY:
        if not env.checker.check_lock_time(n):
            raise ScriptFail("SCRIPT_ERR_UNSATISFIED_LOCKTIME")
        return None
    if n & (1 << 31):
        return None  # execCsv: the operand's disable flag makes it a NOP
    if not env.checker.check_sequence(n):
        raise ScriptFail("SCRIPT_ERR_UNSATISFIED_LOCKTIME")
    return None


def exec_stack(op, st, env):
    # spec/modules.md:2061-2070 (Ops.Stack): a copy costs its size plus the overhead, an
    # erase releases it, a swap costs nothing, a move to and from the alt stack costs
    # nothing.
    if op == OP_TOALTSTACK:
        st.need(1)  # spec/opcodes/OP_FROMALTSTACK.md:11 (toAlt)
        st.alt.append(st.main.pop())
        return None
    if op == OP_FROMALTSTACK:
        if not st.alt:
            raise ScriptFail("SCRIPT_ERR_INVALID_ALTSTACK_OPERATION")  # vFromAltEmpty_kernel
        st.main.append(st.alt.pop())
        return None
    if op == OP_DEPTH:
        # spec/opcodes/OP_DEPTH.md:11 (pushCount): refused when wider than the width
        v = num_encode(len(st.main))
        if len(v) > env.lim["numlen"]:
            raise ScriptFail("SCRIPT_ERR_SCRIPTNUM_OVERFLOW")
        st.push(v)
        return None
    if op in (OP_PICK, OP_ROLL):
        # spec/rules.md:67 and vPick_kernel (spec/theorems.md:8352): the index read as a
        # number, the count popped, outside 0 .. depth-1 refused, the element at that
        # depth (the top at 0) copied to the top.
        st.need(2)
        k = read_operand(st, 0, env)
        st.pop()
        if k < 0 or k >= len(st.main):
            raise ScriptFail("SCRIPT_ERR_INVALID_STACK_OPERATION")
        v = st.top(k)
        if op == OP_ROLL:
            need("stack.roll")
            del st.main[-1 - k]
            st.main.append(v)
            return None
        st.push(v)
        return None
    if op == OP_ROT:
        # vRot_kernel (spec/theorems.md:8358): the third element moves to the top
        st.need(3)
        v = st.main.pop(-3)
        st.main.append(v)
        return None
    simple = {
        OP_DUP: ("stack.dup", 1), OP_DROP: ("stack.drop", 1), OP_NIP: ("stack.nip", 2),
        OP_OVER: ("stack.over", 2), OP_SWAP: ("stack.swap", 2), OP_2DROP: ("stack.2drop", 2),
        OP_2DUP: ("stack.2dup", 2), OP_3DUP: ("stack.3dup", 3), OP_2OVER: ("stack.2over", 4),
        OP_2ROT: ("stack.2rot", 6), OP_2SWAP: ("stack.2swap", 4), OP_IFDUP: ("stack.ifdup", 1),
        OP_TUCK: ("stack.tuck", 2),
    }
    gid, depth = simple[op]
    st.need(depth)
    need(gid)
    m = st.main
    if op == OP_DUP:
        st.push(m[-1])
    elif op == OP_DROP:
        st.pop()
    elif op == OP_NIP:
        v = m.pop(-2)
        st.mem -= len(v) + 32
    elif op == OP_OVER:
        st.push(m[-2])
    elif op == OP_SWAP:
        m[-1], m[-2] = m[-2], m[-1]
    elif op == OP_2DROP:
        st.pop()
        st.pop()
    elif op == OP_2DUP:
        a, b = m[-2], m[-1]
        st.push(a)
        st.push(b)
    elif op == OP_3DUP:
        a, b, c = m[-3], m[-2], m[-1]
        st.push(a)
        st.push(b)
        st.push(c)
    elif op == OP_2OVER:
        a, b = m[-4], m[-3]
        st.push(a)
        st.push(b)
    elif op == OP_2ROT:
        a, b = m[-6], m[-5]
        del m[-6:-4]
        m.append(a)
        m.append(b)
    elif op == OP_2SWAP:
        m[-4], m[-3], m[-2], m[-1] = m[-2], m[-1], m[-4], m[-3]
    elif op == OP_IFDUP:
        if cast_to_bool(m[-1]):
            st.push(m[-1])
    elif op == OP_TUCK:
        v = m[-1]
        st.charge(len(v) + 32)
        m.insert(-2, v)
    return None


def exec_splice(op, st, env):
    if op == OP_SIZE:
        st.need(1)
        need("stack.size")
        v = num_encode(len(st.top()))
        if len(v) > env.lim["numlen"]:
            raise ScriptFail("SCRIPT_ERR_SCRIPTNUM_OVERFLOW")
        st.push(v)
        return None
    if op == OP_CAT:
        # spec/opcodes/OP_CAT.md:11 (cat): pre-Genesis at most 520 bytes; the top popped
        # and appended to the second (the error is the push-size one: spec/errors.md:11)
        st.need(2)
        if not env.utxo_genesis and len(st.top(1)) + len(st.top()) > 520:
            raise ScriptFail("SCRIPT_ERR_PUSH_SIZE")
        x1 = st.pop()
        st.replace_top(st.top() + x1)
        return None
    if op == OP_SPLIT:
        # spec/opcodes/OP_SPLIT.md:11-19 (split, invalidSplitPosition)
        st.need(2)
        n = read_operand(st, 0, env)
        data = st.top(1)
        if n < 0 or n > INT32_MAX or n > len(data):
            raise ScriptFail("SCRIPT_ERR_INVALID_SPLIT_RANGE")
        st.pop()
        st.pop()
        st.push(data[:n])
        st.push(data[n:])
        return None
    if op == OP_NUM2BIN:
        # spec/opcodes/OP_NUM2BIN.md:11 (num2binOp), :41 (num2binPad), :50 (num2bin)
        st.need(2)
        width = read_operand(st, 0, env)
        if width < 0 or width > INT32_MAX:
            raise ScriptFail("SCRIPT_ERR_PUSH_SIZE")
        if not env.utxo_genesis and width > 520:
            raise ScriptFail("SCRIPT_ERR_PUSH_SIZE")
        st.pop()
        m = minimally_encode(st.top())
        st.replace_top(m)
        if len(m) > width:
            raise ScriptFail("SCRIPT_ERR_IMPOSSIBLE_ENCODING")
        if len(m) == width:
            return None
        if m:
            sign = m[-1] & 0x80
            body = m[:-1] + bytes([m[-1] & 0x7F])
        else:
            sign, body = 0, b""
        st.charge(width - len(m))  # padRight charged against the budget (W5)
        st.main[-1] = body + b"\x00" * (width - len(body) - 1) + bytes([sign])
        return None
    if op == OP_BIN2NUM:
        # spec/opcodes/OP_BIN2NUM.md:11 (bin2num)
        st.need(1)
        m = minimally_encode(st.top())
        st.replace_top(m)
        if not num_is_minimal(m, env.lim["numlen"]):
            raise ScriptFail("SCRIPT_ERR_INVALID_NUMBER_RANGE")
        return None
    raise AssertionError


def exec_bitwise(op, st, env):
    if op == OP_INVERT:
        st.need(1)  # spec/opcodes/OP_INVERT.md:11: every byte complemented in place
        st.main[-1] = bytes(255 - x for x in st.top())
        return None
    if op in (OP_AND, OP_OR, OP_XOR):
        # spec/opcodes/OP_AND.md:11 (bitwise2): equal sizes else INVALID_OPERAND_SIZE;
        # combined byte by byte in place; the top popped
        st.need(2)
        a, b = st.top(1), st.top()
        if len(a) != len(b):
            raise ScriptFail("SCRIPT_ERR_INVALID_OPERAND_SIZE")
        need("bitwise.op")
        f = {OP_AND: lambda x, y: x & y, OP_OR: lambda x, y: x | y, OP_XOR: lambda x, y: x ^ y}[op]
        st.pop()
        st.main[-1] = bytes(f(x, y) for x, y in zip(a, b))
        return None
    if op in (OP_EQUAL, OP_EQUALVERIFY):
        # spec/opcodes/OP_EQUAL.md:11 (equal)
        st.need(2)
        eq = st.top(1) == st.top()
        st.pop()
        st.pop()
        st.push(bool_bytes(eq))
        if op == OP_EQUALVERIFY:
            if not eq:
                raise ScriptFail("SCRIPT_ERR_EQUALVERIFY")
            st.pop()
        return None
    # OP_LSHIFT / OP_RSHIFT: spec/opcodes/OP_LSHIFT.md:12 (shift)
    st.need(2)
    n = read_operand(st, 0, env)
    if n < 0:
        raise ScriptFail("SCRIPT_ERR_INVALID_NUMBER_RANGE")
    x = st.top(1)
    st.pop()
    if n >= 8 * len(x):
        st.main[-1] = b"\x00" * len(x)
        return None
    if n == 0:
        return None
    need("bitwise.shift-order")
    v = int.from_bytes(x, "big")
    bits = 8 * len(x)
    v = (v << n) & ((1 << bits) - 1) if op == OP_LSHIFT else v >> n
    st.main[-1] = v.to_bytes(len(x), "big")
    return None


def exec_arith(op, st, env):
    # spec/modules.md:1954-1970 (Ops.Arith); operands read as numbers (readOperand)
    if op == OP_WITHIN:
        # spec/opcodes/OP_WITHIN.md:20 (within): x third, min second, max top, read in
        # that order; min <= x < max; three pops, the boolean pushed
        st.need(3)
        x = read_operand(st, 2, env)
        lo = read_operand(st, 1, env)
        hi = read_operand(st, 0, env)
        st.pop()
        st.pop()
        st.pop()
        st.push(bool_bytes(lo <= x < hi))
        return None
    if op <= OP_0NOTEQUAL:
        st.need(1)
        bn = read_operand(st, 0, env)
        bounded = True
        if op == OP_2MUL:
            r = bn + bn  # spec/opcodes/OP_2DIV.md:13: bn += bn
        elif op == OP_2DIV:
            r = tdiv(bn, 2)  # bn /= 2 (truncation, DESIGN.md:56-59)
            bounded = False
        elif op == OP_0NOTEQUAL:
            r = int(bn != 0)  # spec/rules.md:80: bn != 0
            bounded = False
        elif op == OP_1ADD:
            need("arith.1add")
            r = bn + 1
        elif op == OP_1SUB:
            need("arith.1sub")
            r = bn - 1
        elif op == OP_NEGATE:
            need("arith.negate")
            r = -bn
        elif op == OP_ABS:
            need("arith.abs")
            r = abs(bn)
        else:  # OP_NOT
            need("arith.not")
            r = int(bn == 0)
            bounded = False
        st.pop()
        push_num(st, r, env, bounded)
        return None
    # the binary family: spec/opcodes/OP_NUMEQUALVERIFY.md:12 (binary): bn1 second, bn2
    # top, read in that order; both popped; the result pushed
    st.need(2)
    a = read_operand(st, 1, env)
    b = read_operand(st, 0, env)
    bounded = op in (OP_ADD, OP_SUB, OP_MUL)  # spec/opcodes/OP_ADD.md:12 (binaryBounded)
    if op == OP_ADD:
        r = a + b
    elif op == OP_SUB:
        r = a - b
    elif op == OP_MUL:
        r = a * b
    elif op == OP_DIV:
        if b == 0:
            raise ScriptFail("SCRIPT_ERR_DIV_BY_ZERO")  # spec/theorems.md:6899
        r = tdiv(a, b)
    elif op == OP_MOD:
        if b == 0:
            raise ScriptFail("SCRIPT_ERR_MOD_BY_ZERO")  # spec/theorems.md:6906
        r = tmod(a, b)
    elif op in (OP_BOOLAND, OP_BOOLOR):
        need("arith.bool2")
        r = int((a != 0 and b != 0) if op == OP_BOOLAND else (a != 0 or b != 0))
    elif op in (OP_MIN, OP_MAX):
        need("arith.minmax")
        r = min(a, b) if op == OP_MIN else max(a, b)
    else:
        need("arith.cmp")
        r = int({OP_NUMEQUAL: a == b, OP_NUMEQUALVERIFY: a == b, OP_NUMNOTEQUAL: a != b,
                 OP_LESSTHAN: a < b, OP_GREATERTHAN: a > b, OP_LESSTHANOREQUAL: a <= b,
                 OP_GREATERTHANOREQUAL: a >= b}[op])
    st.pop()
    st.pop()
    push_num(st, r, env, bounded)
    if op == OP_NUMEQUALVERIFY:
        # spec/rules.md:86: pops a true result or fails
        if not r:
            raise ScriptFail("SCRIPT_ERR_NUMEQUALVERIFY")
        st.pop()
    return None


def exec_expansion(op, st, env):
    # spec/modules.md:2025-2040 (Ops.Expansion): pre-Chronicle UTXO a NOP, or the
    # policy error under DISCOURAGE_UPGRADABLE_NOPS (nopOrDiscourage, OP_LEFT.md:11)
    if not env.utxo_chronicle:
        if has(env.w, "DISCOURAGE_UPGRADABLE_NOPS"):
            raise ScriptFail("SCRIPT_ERR_DISCOURAGE_UPGRADABLE_NOPS")
        return None
    numlen, rm = env.lim["numlen"], env.require_minimal
    if op == OP_SUBSTR:
        # spec/opcodes/OP_SUBSTR.md:29 (substr): the length (top) and the offset (second)
        # read, the data third
        st.need(3)
        ln = read_int64_operand(st.top(0), numlen, rm)
        off = read_int64_operand(st.top(1), numlen, rm)
        data = st.top(2)
        if off < 0 or off >= len(data) or ln < 0 or ln > len(data) - off:
            raise ScriptFail("SCRIPT_ERR_INVALID_NUMBER_RANGE")
        st.pop()
        st.pop()
        st.replace_top(data[off:off + ln])
        return None
    if op in (OP_LEFT, OP_RIGHT):
        # spec/opcodes/OP_LEFT.md:29 (left), :37 (right)
        st.need(2)
        ln = read_int64_operand(st.top(0), numlen, rm)
        data = st.top(1)
        if ln < 0 or ln > len(data):
            raise ScriptFail("SCRIPT_ERR_INVALID_NUMBER_RANGE")
        st.pop()
        st.replace_top(data[:ln] if op == OP_LEFT else data[len(data) - ln:])
        return None
    # OP_LSHIFTNUM (spec/opcodes/OP_LSHIFTNUM.md:18) and OP_RSHIFTNUM (OP_RSHIFTNUM.md:18):
    # the value the second element, the count the top, both ordinary number reads
    # (big_int = true). Which is read before the other is not stated: it decides the
    # reason when the value read refuses and the count read refuses with another
    # reason or reads negative (the count's refusal, SCRIPT_ERR_INVALID_NUMBER_RANGE).
    st.need(2)
    errs = []
    for k in (1, 0):
        try:
            errs.append(("ok", read_num(st.top(k), numlen, rm)))
        except ScriptFail as e:
            errs.append(("fail", e.code))
    (vk, vx), (nk, nx) = errs
    if vk == "fail" and ((nk == "fail" and nx != vx) or (nk == "ok" and nx < 0)):
        need("expansion.shiftnum-order")
    v = read_num(st.top(1), numlen, rm)
    n = read_num(st.top(0), numlen, rm)
    if n < 0:
        raise ScriptFail("SCRIPT_ERR_INVALID_NUMBER_RANGE")  # spec/theorems.md (rshiftnum_ok, W7)
    if op == OP_LSHIFTNUM:
        # the size of the value plus n / 8 bytes within the width, then the shift, then the
        # result's width again (scriptnum_overflow_error); a count above INT_MAX after the
        # size test is SCRIPT_ERR_BIG_INT (lshiftnum_ne_bigInt, W6)
        if len(num_encode(v)) + n // 8 > numlen:
            raise ScriptFail("SCRIPT_ERR_SCRIPTNUM_OVERFLOW")
        if n > INT_MAX:
            raise ScriptFail("SCRIPT_ERR_BIG_INT")
        r = v * (2 ** n)
        if len(num_encode(r)) > numlen:
            raise ScriptFail("SCRIPT_ERR_SCRIPTNUM_OVERFLOW")
    else:
        if n > INT_MAX:
            raise ScriptFail("SCRIPT_ERR_BIG_INT")  # W7: above INT_MAX
        r = tdiv(v, 2 ** n) if n < abs(v).bit_length() + 1 else 0
    st.pop()
    st.pop()
    st.push(num_encode(r))
    return None


def script_code_of(script, codesep, env):
    # spec/opcodes/OP_CODESEPARATOR.md:35 (scriptCodeOf): from the last OP_CODESEPARATOR
    # on, and inside the unlocking script under SCRIPT_CHRONICLE the locking script
    # appended
    code = bytes(script[codesep:])
    if env.phase1_lock is not None and has(env.w, "CHRONICLE"):
        code += bytes(env.phase1_lock)
    return code


def check_signature_encoding(sig, env):
    # docs/DESIGN.md:331-338 (CheckSignatureEncoding, 265-310) and the four refusals of
    # spec/theorems.md:7754-7810 in their order (293, 299, 302, 305)
    w = env.w
    if len(sig) == 0:
        return
    if (has(w, "DERSIG") or has(w, "LOW_S") or has(w, "STRICTENC")) and not is_strict_der(sig):
        raise ScriptFail("SCRIPT_ERR_SIG_DER")
    if has(w, "LOW_S") and env.enforce and not check_low_s(sig[:-1]):
        raise ScriptFail("SCRIPT_ERR_SIG_HIGH_S")
    if has(w, "STRICTENC"):
        t = sig[-1]
        if not is_defined(t):
            raise ScriptFail("SCRIPT_ERR_SIG_HASHTYPE")
        if t & SIGHASH_FORKID and not has(w, "SIGHASH_FORKID"):
            raise ScriptFail("SCRIPT_ERR_ILLEGAL_FORKID")
        if t & SIGHASH_CHRONICLE and not has(w, "CHRONICLE"):
            raise ScriptFail("SCRIPT_ERR_ILLEGAL_CHRONICLE")
        if has(w, "SIGHASH_FORKID") and not t & SIGHASH_FORKID:
            raise ScriptFail("SCRIPT_ERR_MUST_USE_FORKID")


def check_pubkey_encoding(pk, env):
    # docs/DESIGN.md:338-340 (CheckPubKeyEncoding, 312-329): under STRICTENC compressed
    # or uncompressed ([LIT] SEC 1: 33 bytes 02/03, 65 bytes 04), else PUBKEYTYPE; under
    # COMPRESSED_PUBKEYTYPE compressed only (spec/errors.md:47)
    if has(env.w, "STRICTENC"):
        ok = (len(pk) == 33 and pk[0] in (2, 3)) or (len(pk) == 65 and pk[0] == 4)
        if not ok:
            raise ScriptFail("SCRIPT_ERR_PUBKEYTYPE")
    if has(env.w, "COMPRESSED_PUBKEYTYPE") and not (len(pk) == 33 and pk[0] in (2, 3)):
        raise ScriptFail("SCRIPT_ERR_NONCOMPRESSED_PUBKEY")


def cleanup_script_code(code, sig, env):
    # spec/theorems.md:9572-9593 (CleanupScriptCode, T-SH8): the signature's push deleted
    # unless FORKID is enabled and the signature carries the FORKID bit
    if len(sig) and has(env.w, "SIGHASH_FORKID") and sig[-1] & SIGHASH_FORKID:
        return code
    return find_and_delete(code, push_data_script(bytes(sig)))


def exec_checksig(op, script, codesep, st, env):
    # spec/opcodes/OP_CHECKSIGVERIFY.md:13 (checkSigOp)
    st.need(2)
    sig, pk = st.top(1), st.top(0)
    check_signature_encoding(sig, env)
    check_pubkey_encoding(pk, env)
    code = cleanup_script_code(script_code_of(script, codesep, env), sig, env)
    ok = env.checker.check_sig(sig, pk, code, has(env.w, "SIGHASH_FORKID"))
    if not ok and len(sig) and has(env.w, "NULLFAIL") and env.enforce:
        raise ScriptFail("SCRIPT_ERR_SIG_NULLFAIL")
    st.pop()
    st.pop()
    st.push(bool_bytes(ok))
    if op == OP_CHECKSIGVERIFY:
        if not ok:
            raise ScriptFail("SCRIPT_ERR_CHECKSIGVERIFY")
        st.pop()
    return None


def exec_multisig(op, script, codesep, st, env):
    # spec/opcodes/OP_CHECKMULTISIG.md:21 (checkMultiSigOp) and :13 (readCount)
    rm = env.require_minimal
    st.need(1)
    n_keys = read_num(st.top(0), 4, rm)
    if n_keys < 0 or n_keys > env.lim["keys"]:
        raise ScriptFail("SCRIPT_ERR_PUBKEY_COUNT")
    # the key count is charged to the op count by the loop before this step (1534-1536)
    i_keys = 1
    st.need(i_keys + n_keys + 1)
    i_nsigs = i_keys + n_keys
    n_sigs = read_num(st.top(i_nsigs), 4, rm)
    if n_sigs < 0 or n_sigs > n_keys:
        raise ScriptFail("SCRIPT_ERR_SIG_COUNT")
    i_sig = i_nsigs + 1
    st.need(i_sig + n_sigs + 1)  # the dummy below the signatures (1661-1672)
    sigs = [st.top(i_sig + j) for j in range(n_sigs)]
    keys = [st.top(i_keys + j) for j in range(n_keys)]
    code = script_code_of(script, codesep, env)
    for s in sigs:
        if not (len(s) and has(env.w, "SIGHASH_FORKID") and s[-1] & SIGHASH_FORKID):
            code = find_and_delete(code, push_data_script(bytes(s)))
    success = True
    if n_sigs > 0:
        need("multisig.order")
        isig, ikey = 0, 0
        rem_sigs, rem_keys = n_sigs, n_keys
        while success and rem_sigs > 0:
            s, k = sigs[isig], keys[ikey]
            check_signature_encoding(s, env)
            check_pubkey_encoding(k, env)
            if env.checker.check_sig(s, k, code, has(env.w, "SIGHASH_FORKID")):
                isig += 1
                rem_sigs -= 1
            ikey += 1
            rem_keys -= 1
            if rem_sigs > rem_keys:
                success = False
    # the arguments popped (1636-1653), NULLFAIL on a non-empty signature after a failure
    for j in range(i_sig + n_sigs):
        v = st.top()
        if not success and has(env.w, "NULLFAIL") and env.enforce and i_sig <= j and len(v):
            raise ScriptFail("SCRIPT_ERR_SIG_NULLFAIL")
        st.pop()
    if has(env.w, "NULLDUMMY") and env.enforce and len(st.top()):
        raise ScriptFail("SCRIPT_ERR_SIG_NULLDUMMY")
    st.pop()
    st.push(bool_bytes(success))
    if op == OP_CHECKMULTISIGVERIFY:
        if not success:
            raise ScriptFail("SCRIPT_ERR_CHECKMULTISIGVERIFY")
        st.pop()
    return None


def eval_script(script, st, env):
    """EvalScript (docs/DESIGN.md:193-211): None on success (the end, or a post-Genesis
    top-level OP_RETURN); raises ScriptFail. The op count includes every executed
    multisig's key count (docs/DESIGN.md:110-113; OP_CHECKMULTISIG.md:21)."""
    if len(script) > env.lim["size"]:
        raise ScriptFail("SCRIPT_ERR_SCRIPT_SIZE")
    st.alt = []
    cond = Cond()
    ops = 0
    non_top_return = False
    codesep = 0
    pc = 0
    while pc < len(script):
        r = get_op(script, pc)
        if r is None:
            raise ScriptFail("SCRIPT_ERR_BAD_OPCODE")
        op, data, nxt, _hdr = r
        if not env.utxo_genesis and op <= OP_PUSHDATA4 and len(data) > 520:
            raise ScriptFail("SCRIPT_ERR_PUSH_SIZE")
        f_exec = cond.active() and (not non_top_return or op == OP_RETURN)
        if op > OP_16:
            ops += 1
            if ops > env.lim["ops"]:
                raise ScriptFail("SCRIPT_ERR_OP_COUNT")
        if op in (OP_2MUL, OP_2DIV) and not env.utxo_chronicle and (not env.utxo_genesis or f_exec):
            raise ScriptFail("SCRIPT_ERR_DISABLED_OPCODE")
        if op <= OP_PUSHDATA4:
            if f_exec:
                if env.require_minimal and not is_minimal_push(op, data):
                    raise ScriptFail("SCRIPT_ERR_MINIMALDATA")
                st.push(data)
        elif op == OP_CODESEPARATOR:
            if f_exec:
                codesep = nxt
        elif f_exec or OP_IF <= op <= OP_ENDIF:
            if op in (OP_CHECKMULTISIG, OP_CHECKMULTISIGVERIFY):
                # the key count is read and charged before anything else moves (R5)
                st.need(1)
                k = read_num(st.top(0), 4, env.require_minimal)
                if 0 <= k <= env.lim["keys"]:
                    if ops + k > env.lim["ops"]:
                        raise ScriptFail("SCRIPT_ERR_OP_COUNT")
                    ops += k
            res = exec_op(op, script, nxt, codesep, st, env, cond, f_exec)
            if res == "return":
                return None
            if res == "mark-return":
                non_top_return = True
        if not env.utxo_genesis and len(st.main) + len(st.alt) > 1000:
            raise ScriptFail("SCRIPT_ERR_STACK_SIZE")
        pc = nxt
    if not cond.empty():
        raise ScriptFail("SCRIPT_ERR_UNBALANCED_CONDITIONAL")
    return None


# ---------------------------------------------------------------------------
# VerifyScript (docs/DESIGN.md:169-191; spec/modules.md:2459-2499)
# ---------------------------------------------------------------------------


def verify_script(script_sig, script_pubkey, w, limits, checker):
    """The verdict of one input: None for valid, or a SCRIPT_ERR_* name."""
    try:
        _verify(bytes(script_sig), bytes(script_pubkey), w, limits, checker)
        return None
    except ScriptFail as e:
        return e.code


def _verify(sig, pub, w, limits, checker):
    # 1. valid_flags (DESIGN.md:170-171)
    if has(w, "UTXO_AFTER_CHRONICLE") and not has(w, "UTXO_AFTER_GENESIS"):
        raise ScriptFail("SCRIPT_ERR_INVALID_FLAGS")
    # 2. FORKID implies STRICTENC (DESIGN.md:172)
    if has(w, "SIGHASH_FORKID"):
        w |= word("STRICTENC")
    version = checker.version()
    # docs/DESIGN.md:422-423: EnforceNonMalleability = not (CHRONICLE and v > 1)
    enforce = not (has(w, "CHRONICLE") and version > 1)
    # 3. SIGPUSHONLY (DESIGN.md:173-176; spec/modules.md:2498)
    if has(w, "SIGPUSHONLY"):
        gen, chron = has(w, "GENESIS"), has(w, "CHRONICLE")
        if (gen and not chron) or (chron and version <= 1):
            if not is_push_only(sig):
                raise ScriptFail("SCRIPT_ERR_SIG_PUSHONLY")
    # 4-5. the two stacks with the budget; the unlocking script sees the locking one
    st = Stacks(limits["mem"])
    eval_script(sig, st, Env(w, limits, checker, enforce, phase1_lock=pub))
    # 6. the P2SH copy for a pre-Genesis UTXO (DESIGN.md:179)
    p2sh = has(w, "P2SH") and not has(w, "UTXO_AFTER_GENESIS")
    copy = (list(st.main), st.mem) if p2sh else None
    # 7. the locking script on the resulting stack
    eval_script(pub, st, Env(w, limits, checker, enforce))
    # 8. the final-stack rule (DESIGN.md:181-182)
    if not st.main or not cast_to_bool(st.top()):
        raise ScriptFail("SCRIPT_ERR_EVAL_FALSE")
    # 9. P2SH (DESIGN.md:183-188)
    if p2sh and is_p2sh(pub):
        if not is_push_only(sig):
            raise ScriptFail("SCRIPT_ERR_SIG_PUSHONLY")
        st.main, st.mem = copy
        if not st.main:
            raise ScriptFail("SCRIPT_ERR_EVAL_FALSE")
        redeem = st.pop()
        eval_script(redeem, st, Env(w, limits, checker, enforce))
        if not st.main or not cast_to_bool(st.top()):
            raise ScriptFail("SCRIPT_ERR_EVAL_FALSE")
    # 10. CLEANSTACK (DESIGN.md:189-191)
    if has(w, "CLEANSTACK"):
        if not has(w, "P2SH"):
            raise ScriptFail("SCRIPT_ERR_INVALID_FLAGS")
        if enforce and len(st.main) != 1:
            raise ScriptFail("SCRIPT_ERR_CLEANSTACK")


# ---------------------------------------------------------------------------
# The transaction-level gate (spec/modules.md:2887-2905; spec/theorems.md:10236-10507)
# ---------------------------------------------------------------------------


def is_null_outpoint(txid, idx):
    need("tx.null-outpoint")
    return txid == b"\x00" * 32 and idx == 0xFFFFFFFF


def is_coinbase(tx):
    # spec/theorems.md (checkCoinbase_not_coinbase): the one-input transaction whose
    # outpoint is null
    return len(tx.vin) == 1 and is_null_outpoint(tx.vin[0][0], tx.vin[0][1])


def sigop_count_pre_genesis(script):
    # spec/opcodes/OP_CHECKMULTISIG.md:193 (sigOpCountPreGenesis): CHECKSIG(VERIFY) one,
    # CHECKMULTISIG(VERIFY) twenty; the walk stops at a failed parse or a literal 0xff
    n, pc = 0, 0
    while pc < len(script):
        r = get_op(script, pc)
        if r is None or r[0] == 0xFF:
            break
        if r[0] in (OP_CHECKSIG, OP_CHECKSIGVERIFY):
            n += 1
        elif r[0] in (OP_CHECKMULTISIG, OP_CHECKMULTISIGVERIFY):
            n += 20
        pc = r[2]
    return n


def check_transaction_common(tx, era):
    # spec/theorems.md:10236-10440 (T-TX6, T-TX8, T-TX9, checkTransactionCommon_ok_iff)
    if not tx.vin:
        raise TxReject("bad-txns-vin-empty")
    if not tx.vout:
        raise TxReject("bad-txns-vout-empty")
    max_size = 1000000 if era == PRE_GENESIS else 1000000000  # spec/theorems.md:9990, 9263
    if len(ser_tx(tx)) > max_size:
        raise TxReject("bad-txns-oversize")
    total = 0
    for val, _s in tx.vout:
        if val < 0:
            raise TxReject("bad-txns-vout-negative")
        need("tx.max-money")
        max_money = 21000000 * 100000000
        if val > max_money:
            raise TxReject("bad-txns-vout-toolarge")
        total += val
        if total > max_money:
            raise TxReject("bad-txns-txouttotal-toolarge")
    if era == PRE_GENESIS:
        n = sum(sigop_count_pre_genesis(v[2]) for v in tx.vin) + sum(sigop_count_pre_genesis(s) for _v, s in tx.vout)
        if n > 20000:
            raise TxReject("bad-txn-sigops")


def check_regular_transaction(tx, era):
    # spec/theorems.md:10431-10465 (checkRegularTransaction_eq, _ok_iff)
    if is_coinbase(tx):
        raise TxReject("bad-tx-coinbase")
    check_transaction_common(tx, era)
    if era >= POST_GENESIS:
        for _v, s in tx.vout:
            if is_p2sh(s):
                raise TxReject("bad-txns-vout-p2sh")  # spec/modules.md:2359-2361
    seen = set()
    for txid, idx, _s, _q in tx.vin:
        if is_null_outpoint(txid, idx):
            raise TxReject("bad-txns-prevout-null")
        if (txid, idx) in seen:
            raise TxReject("bad-txns-inputs-duplicate")
        seen.add((txid, idx))


def check_coinbase(tx, era):
    # spec/theorems.md:10318-10330 (T-TX7): the common checks and the script 2 to 100 bytes
    check_transaction_common(tx, era)
    if not 2 <= len(tx.vin[0][2]) <= 100:
        raise TxReject("bad-cb-length")


def sequence_locks_ok(tx, coin_heights, height, era):
    """The block's BIP 68 relative locks (spec/teranode-map.md:64, `sequence-locks`:
    "BIP68 relative locks against the coins' heights and median times (a no-op after
    Genesis)"; [LIT] BIP 68): for a version-2 transaction every input without the
    disable flag (bit 31, spec/theorems.md:7846) asks its coin an age; a height lock
    is met when the block's height reaches the coin's height plus the lock."""
    if era >= POST_GENESIS:
        return True
    if (tx.version & 0xFFFFFFFF) < 2:  # spec/theorems.md:9944: relative locks need version 2
        return True
    for (_t, _i, _s, seq), ch in zip(tx.vin, coin_heights):
        if seq & (1 << 31):
            continue
        need("lock.seq-fields")
        if seq & (1 << 22):
            raise DocumentGap("tx.sequence-locks-time")
        if height < ch + (seq & 0xFFFF):
            return False
    return True
