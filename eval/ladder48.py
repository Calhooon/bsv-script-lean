#!/usr/bin/env python3
"""eval/ladder48.py: lean #48's ladder, synthetic spends of growing size for `eval/bsvs` (S1, Lean A, 2026-09-29).

One input and one output, version 2, the coin post-Chronicle at the spec's default height (967,896), so the block path
runs every step under the consensus limits: no script-size, op-count or stack-memory cap applies after Genesis at
consensus (`consensus.h:43, 60, 82`). The shape is the depth wall's (#48, a record withheld from the public edition):
the unlocking script pushes K one-byte numbers (`OP_1` to `OP_16` in turn), so the lock runs on a stack K deep, and the
locking script repeats M times one STEP of 55 opcodes, then ends with `OP_1`. The STEP reaches every opcode depth test
that measures the stack (each of its 29 non-push opcodes tests the stack's depth before it reads the stack, after the
coin's era for the five expansion opcodes, e.g. `interpreter.cpp:1231–1232`, `1294–1295`, `611` then `619`; its 26 pushes,
`OP_0`, `OP_1`, `OP_2`, test no depth, `473–481`, `488–511`) on fresh constants over the deep
stack, and leaves the depth where it found it. Outside the STEP: the flow opcodes' tests (`OP_IF`, `OP_VERIFY`, CLTV, CSV)
match the head of the stack, at the same cost on both machines; the pre-Genesis element limit (`1800–1804`) and CLEANSTACK
(`2441–2447`) measure it, bounded by the limit or once per spend, and neither applies to this post-Genesis version-2
spend; `OP_DEPTH` reads it (`966–970`), on the list machine by walking it. `eval/bsvs` judges with
the array machine since #50 (`needI` and the `Impl` families' size tests); the functions below are the list machine's
fourteen whose depth tests #48 compiled (the flow leg's list-machine row, `lean/Test/FlowCheck.lean`, times them):
  OP_DUP OP_DROP                     execStack (need)        OP_1 OP_1ADD OP_DROP              Arith.unary
  OP_1 OP_1 OP_ADD OP_DROP           Arith.binary            OP_1 OP_0 OP_2 OP_WITHIN OP_DROP  Arith.within
  OP_1 OP_1 OP_EQUAL OP_DROP         Bitwise.equal           OP_1 OP_1 OP_AND OP_DROP          Bitwise.bitwise2
  OP_1 OP_INVERT OP_DROP             Bitwise.invert          OP_1 OP_1 OP_LSHIFT OP_DROP       Bitwise.shift
  OP_1 OP_0 OP_1 OP_SUBSTR OP_DROP   Expansion.substr        OP_1 OP_1 OP_LEFT OP_DROP         Expansion.left
  OP_1 OP_1 OP_RIGHT OP_DROP         Expansion.right         OP_1 OP_1 OP_LSHIFTNUM OP_DROP    Expansion.lshiftnum
  OP_1 OP_1 OP_RSHIFTNUM OP_DROP     Expansion.rshiftnum     OP_0 OP_PICK OP_DROP              execStack (PICK)
  OP_1 OP_ROLL                       execStack (ROLL)
The verdict on the block path is valid (the top is true; CLEANSTACK is policy, absent from the block word). Before #48's
fix every depth test measured the whole stack, so a step cost K per depth test; after it, a constant. The tripwire's two
large-lock rows (`lean/Test/FlowCheck.lean`, `largeLockSpend`) build the same bytes in Lean.

  eval/ladder48.py <lock-bytes> <out-dir> [<depth>]   writes <out-dir>/ladder-<lock-bytes>[-d<depth>].tx.hex and
                                                      .prevouts.json (M = lock-bytes / 55 steps; the depth K defaults to M)

Nothing of any other program is used: every byte is generated here.
"""
import hashlib
import json
import os
import sys


def varint(k: int) -> bytes:
    if k < 0xFD:
        return bytes([k])
    if k <= 0xFFFF:
        return b"\xfd" + k.to_bytes(2, "little")
    if k <= 0xFFFFFFFF:
        return b"\xfe" + k.to_bytes(4, "little")
    return b"\xff" + k.to_bytes(8, "little")


STEP = bytes([
    0x76, 0x75,                    # OP_DUP OP_DROP
    0x51, 0x8B, 0x75,              # OP_1 OP_1ADD OP_DROP
    0x51, 0x51, 0x93, 0x75,        # OP_1 OP_1 OP_ADD OP_DROP
    0x51, 0x00, 0x52, 0xA5, 0x75,  # OP_1 OP_0 OP_2 OP_WITHIN OP_DROP
    0x51, 0x51, 0x87, 0x75,        # OP_1 OP_1 OP_EQUAL OP_DROP
    0x51, 0x51, 0x84, 0x75,        # OP_1 OP_1 OP_AND OP_DROP
    0x51, 0x83, 0x75,              # OP_1 OP_INVERT OP_DROP
    0x51, 0x51, 0x98, 0x75,        # OP_1 OP_1 OP_LSHIFT OP_DROP
    0x51, 0x00, 0x51, 0xB3, 0x75,  # OP_1 OP_0 OP_1 OP_SUBSTR OP_DROP
    0x51, 0x51, 0xB4, 0x75,        # OP_1 OP_1 OP_LEFT OP_DROP
    0x51, 0x51, 0xB5, 0x75,        # OP_1 OP_1 OP_RIGHT OP_DROP
    0x51, 0x51, 0xB6, 0x75,        # OP_1 OP_1 OP_LSHIFTNUM OP_DROP
    0x51, 0x51, 0xB7, 0x75,        # OP_1 OP_1 OP_RSHIFTNUM OP_DROP
    0x00, 0x79, 0x75,              # OP_0 OP_PICK OP_DROP
    0x51, 0x7A,                    # OP_1 OP_ROLL
])
assert len(STEP) == 55


def build(lock_bytes: int, out: str, depth: int = 0) -> None:
    m = max(1, lock_bytes // len(STEP))
    k = depth or m
    lock = STEP * m + b"\x51"  # ... OP_1
    unlock = bytes(0x51 + (i % 16) for i in range(k))  # OP_1 ... OP_16, one byte each
    tag = f"ladder-{lock_bytes}" + (f"-d{k}" if depth else "")
    prev = hashlib.sha256(f"bsv-script-lean #48: {tag}, a synthetic outpoint".encode()).hexdigest()
    tx = (
        (2).to_bytes(4, "little") + varint(1) + bytes.fromhex(prev)[::-1] + (0).to_bytes(4, "little")
        + varint(len(unlock)) + unlock + b"\xff\xff\xff\xff"
        + varint(1) + (1).to_bytes(8, "little") + varint(1) + b"\x51" + (0).to_bytes(4, "little")
    )
    os.makedirs(out, exist_ok=True)
    with open(os.path.join(out, tag + ".tx.hex"), "w") as f:
        f.write(tx.hex())
    with open(os.path.join(out, tag + ".prevouts.json"), "w") as f:
        json.dump([{"txid": prev, "vout": 0, "script": lock.hex(), "satoshis": 1000, "height": 967896}], f)
    print(f"{tag}: lock {len(lock)} B ({m} steps of {len(STEP)} opcodes), unlocking {len(unlock)} B ({k} pushes), "
          f"tx {len(tx)} B, lock sha256 {hashlib.sha256(lock).hexdigest()}")


if __name__ == "__main__":
    if len(sys.argv) not in (3, 4):
        sys.exit(__doc__)
    build(int(sys.argv[1]), sys.argv[2], int(sys.argv[3]) if len(sys.argv) == 4 else 0)
