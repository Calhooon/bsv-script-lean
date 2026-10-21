# `OP_SHA1` (`0xa7`)

**Family** crypto (hashes) · **module** `BsvScript.Ops.Crypto` · **landed at** #11 · **the switch** `1402–1443` · the reference bitcoin-sv v1.2.3 `6504a3af` (`docs/PROVENANCE.md`).

## History and eras

- counts against `MaxOpsPerScript` executed or not (`466–467`): 500 pre-Genesis, unbounded post-Genesis at consensus (`docs/PARAMETERS.md` §1)

## Semantics (the Lean docstrings that name it)

### `Sha1.compress_size` (theorem, `lean/BsvScript/Hash/Sha1.lean:68`)

**One compression keeps a 5-word state.** *What it says:* `Sha1.compress` returns an
array of size 5 for any state and block. *What it assumes:* nothing. *Why it matters:*
it is the step of T-SHA4's induction (`Sha1.blocks_size`), which `OP_SHA1`'s 20-byte
digest rests on.

### `sha1_valid` (theorem, `lean/BsvScript/Impl/Elem.lean:535`)

**`sha1_valid`.** *What it says:* a SHA-1 digest is bytes. *What it assumes:* nothing. *Why it matters:*
`OP_SHA1` (#143).

### `hashOp_ok` (theorem, `lean/BsvScript/Properties/Widths.lean:38`)

**W2 (the digest widths).** *What it says:* a hash opcode that succeeds replaces the top element by its
digest, 20 bytes for `OP_RIPEMD160`, `OP_SHA1` and `OP_HASH160`, 32 for `OP_SHA256` and `OP_HASH256`.
*What it assumes:* the opcode succeeded. *Why it matters:* the widths are the digests' own
(`CRIPEMD160::OUTPUT_SIZE`, `CSHA1::OUTPUT_SIZE`, `CHash160`, `CSHA256`, `CHash256`, `1412–1440`), so the
memory a hash adds is known before it runs.

`[SRC]` `interpreter.cpp:1412–1440`

## The corpus entries that exercise it (by rule)

| rule | corpus entries | `[SRC]` |
|---|---|---|
| `crypto.hash` | 117 | `interpreter.cpp:1402–1443`; `src/hash.h:24–78`; `src/crypto/sha1.cpp`, `ripemd160.cpp` |

