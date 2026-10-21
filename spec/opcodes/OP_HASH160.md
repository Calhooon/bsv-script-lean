# `OP_HASH160` (`0xa9`)

**Family** crypto (hashes) · **module** `BsvScript.Ops.Crypto` · **landed at** #11 · **the switch** `1402–1443` · the reference bitcoin-sv v1.2.3 `6504a3af` (`docs/PROVENANCE.md`).

## History and eras

- counts against `MaxOpsPerScript` executed or not (`466–467`): 500 pre-Genesis, unbounded post-Genesis at consensus (`docs/PARAMETERS.md` §1)

## Semantics (the Lean docstrings that name it)

### `hash160_length` (theorem, `lean/BsvScript/Hash/Ripemd160.lean:147`)

**`hash160` is 20 bytes.** *What it says:* `hash160` (`CHash160`, RIPEMD-160 of
SHA-256) of any message has length 20. *What it assumes:* nothing. *Why it matters:*
`OP_HASH160`'s result (`Ops/Crypto.lean`) is 20 bytes, the width of the hash in
`isP2SH`'s 23-byte shape (T-RMD2 applied to the SHA-256 digest).

### `sha256_valid` (theorem, `lean/BsvScript/Impl/Elem.lean:531`)

**`sha256_valid`.** *What it says:* a SHA-256 digest is bytes. *What it assumes:* nothing. *Why it matters:*
`OP_SHA256`, `OP_HASH160`, `OP_HASH256` (#143).

### `ripemd160_valid` (theorem, `lean/BsvScript/Impl/Elem.lean:539`)

**`ripemd160_valid`.** *What it says:* a RIPEMD-160 digest is bytes. *What it assumes:* nothing. *Why it
matters:* `OP_RIPEMD160`, `OP_HASH160` (#143).

### `isP2SH` (def, `lean/BsvScript/Machine.lean:63`)

`IsP2SH` (`script.cpp:168–172`): 23 bytes, `OP_HASH160 <20 bytes> OP_EQUAL`.

`[SRC]` `script.cpp:168–172`

### `isP2SH_of_shape` (theorem, `lean/BsvScript/Properties/P2SH.lean:52`)

**The P2SH shape** (`IsP2SH`, `script.cpp:168–172`): `OP_HASH160`, a 20-byte push, `OP_EQUAL`.

`[SRC]` `script.cpp:168–172`

### `hashOp_ok` (theorem, `lean/BsvScript/Properties/Widths.lean:38`)

**W2 (the digest widths).** *What it says:* a hash opcode that succeeds replaces the top element by its
digest, 20 bytes for `OP_RIPEMD160`, `OP_SHA1` and `OP_HASH160`, 32 for `OP_SHA256` and `OP_HASH256`.
*What it assumes:* the opcode succeeded. *Why it matters:* the widths are the digests' own
(`CRIPEMD160::OUTPUT_SIZE`, `CSHA1::OUTPUT_SIZE`, `CHash160`, `CSHA256`, `CHash256`, `1412–1440`), so the
memory a hash adds is known before it runs.

`[SRC]` `interpreter.cpp:1412–1440`

### `p2pkhScript` (def, `lean/BsvScript/TxPolicy.lean:742`)

A pay-to-public-key-hash locking script (`OP_DUP OP_HASH160 <20 bytes> OP_EQUALVERIFY OP_CHECKSIG`),
the template `standard.cpp:53–57`.

`[SRC]` `standard.cpp:53–57`

## The corpus entries that exercise it (by rule)

| rule | corpus entries | `[SRC]` |
|---|---|---|
| `crypto.hash` | 117 | `interpreter.cpp:1402–1443`; `src/hash.h:24–78`; `src/crypto/sha1.cpp`, `ripemd160.cpp` |
| `eras.height.p2sh`, `eras.height.dersig`, `eras.height.cltv`, `eras.height.csv`, `eras.height.uahf`, `eras.height.daa` | 16 | `verify_script_flags.cpp:32–81`; `validation.cpp:2973–2982`, `3473`; `chainparams.cpp:1038–1076`, `:28` |
| `p2sh.grandfathered`, `p2sh.disabled`, `p2sh.pushonly`, `p2sh.output.post-genesis` | 10 | `interpreter.cpp:2354–2356`, `2380–2424`, `2430–2448`; `script.cpp:164–168`; `validation.cpp:610–623`; `standard.cpp:72–76` (policy) |

