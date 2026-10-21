# `OP_SHA256` (`0xa8`)

**Family** crypto (hashes) · **module** `BsvScript.Ops.Crypto` · **landed at** #11 · **the switch** `1402–1443` · the reference bitcoin-sv v1.2.3 `6504a3af` (`docs/PROVENANCE.md`).

## History and eras

- counts against `MaxOpsPerScript` executed or not (`466–467`): 500 pre-Genesis, unbounded post-Genesis at consensus (`docs/PARAMETERS.md` §1)

## Semantics (the Lean docstrings that name it)

### `gadget` (def, `lean/BsvScript/Gadget/HashLock.lean:30`)

BIP 199's hash branch with `[HASHOP]` = `OP_SHA256` (`0xa8`): the digest `h` pushed by its length byte
(`0x20` for 32 bytes, the minimal push, `interpreter.cpp:473–481`), then `OP_EQUALVERIFY` (`0x88`).

`[SRC]` `interpreter.cpp:473–481`

### `run_sha256` (theorem, `lean/BsvScript/Gadget/HashLock.lean:34`)

**`OP_SHA256`** (`1402–1443`) on a stack whose top is `x`: the top replaced by `sha256 x`, one opcode
charged, `x`'s memory given back and the digest's charged (`limitedstack.h:163–173`).

`[SRC]` `interpreter.cpp:1402–1443`, `limitedstack.h:163–173`

### `sha256_triple` (theorem, `lean/BsvScript/Gadget/HashLock.lean:121`)

**`OP_SHA256` as a triple.** From a state whose top is `x` (the rest of the stack, the alt stack, the
conditional state and the counters named by ghost values), the top becomes `sha256 x`, one opcode charged, `x`'s
memory given back and the digest's 32 bytes charged.

### `hashLock_triple` (theorem, `lean/BsvScript/Gadget/HashLock.lean:173`)

**The hash-lock as a triple** (BIP 199's `OP_SHA256 <h> OP_EQUALVERIFY`; `docs/DESIGN.md` §12.4). *What it
says:* from every state whose top is a preimage `x` of `h`, the rest of the stack, the alt stack, the conditional
state and the counters named by ghost values, the gadget runs to its end, whatever follows it, in the state that
keeps all of them but the top, with two opcodes charged and `x`'s memory given back. *What it assumes:* the
gadget's preconditions (the module's header). *Why it matters:* the preimage check a contract compiler produces is
proved once, at the gadget level, as the composition of its three instructions' triples by `Triple.seq`, the
digest's equality carried across by `Triple.conseq`; a consumer's chain of gadgets composes it the same way.

### `sha256_valid` (theorem, `lean/BsvScript/Impl/Elem.lean:531`)

**`sha256_valid`.** *What it says:* a SHA-256 digest is bytes. *What it assumes:* nothing. *Why it matters:*
`OP_SHA256`, `OP_HASH160`, `OP_HASH256` (#143).

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

