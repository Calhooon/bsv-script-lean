# `OP_EQUALVERIFY` (`0x88`)

**Family** bitwise · **module** `BsvScript.Ops.Bitwise` · **landed at** #9 · **the switch** `1069–1217` · the reference bitcoin-sv v1.2.3 `6504a3af` (`docs/PROVENANCE.md`).

## History and eras

- counts against `MaxOpsPerScript` executed or not (`466–467`): 500 pre-Genesis, unbounded post-Genesis at consensus (`docs/PARAMETERS.md` §1)

## Semantics (the Lean docstrings that name it)

### `equal` (def, `lean/BsvScript/Ops/Bitwise.lean:149`)

`OP_EQUAL`/`OP_EQUALVERIFY` (`1189–1217`): byte-vector equality, the two
popped, the boolean pushed (`1207–1209`); `OP_EQUALVERIFY` pops a true result
or fails with `SCRIPT_ERR_EQUALVERIFY` (`1210–1215`).

`[SRC]` `interpreter.cpp:1189–1217`, `interpreter.cpp:1207–1209`, `interpreter.cpp:1210–1215`

### `gadget` (def, `lean/BsvScript/Gadget/HashLock.lean:30`)

BIP 199's hash branch with `[HASHOP]` = `OP_SHA256` (`0xa8`): the digest `h` pushed by its length byte
(`0x20` for 32 bytes, the minimal push, `interpreter.cpp:473–481`), then `OP_EQUALVERIFY` (`0x88`).

`[SRC]` `interpreter.cpp:473–481`

### `run_equalverify_same` (theorem, `lean/BsvScript/Gadget/HashLock.lean:79`)

**`OP_EQUALVERIFY`** (`1189–1217`) on two equal elements `v` on top: both popped, the result pushed and
verified away, one opcode charged.

`[SRC]` `interpreter.cpp:1189–1217`

### `equalverify_triple` (theorem, `lean/BsvScript/Gadget/HashLock.lean:154`)

**`OP_EQUALVERIFY` on two equal elements as a triple.** Both are popped, the result pushed and verified
away, one opcode charged.

### `hashLock_triple` (theorem, `lean/BsvScript/Gadget/HashLock.lean:173`)

**The hash-lock as a triple** (BIP 199's `OP_SHA256 <h> OP_EQUALVERIFY`; `docs/DESIGN.md` §12.4). *What it
says:* from every state whose top is a preimage `x` of `h`, the rest of the stack, the alt stack, the conditional
state and the counters named by ghost values, the gadget runs to its end, whatever follows it, in the state that
keeps all of them but the top, with two opcodes charged and `x`'s memory given back. *What it assumes:* the
gadget's preconditions (the module's header). *Why it matters:* the preimage check a contract compiler produces is
proved once, at the gadget level, as the composition of its three instructions' triples by `Triple.seq`, the
digest's equality carried across by `Triple.conseq`; a consumer's chain of gadgets composes it the same way.

### `equalI_abs` (theorem, `lean/BsvScript/Impl/Bitwise.lean:91`)

**`equalI_abs`.** *What it says:* the implementation's `OP_EQUAL`/`OP_EQUALVERIFY` computes what
`Ops.Bitwise.equal` computes on the state it stands for. *What it assumes:* nothing. *Why it matters:* the
family on the implementation (#50).

### `popTail_abs` (theorem, `lean/BsvScript/Impl/State.lean:497`)

**`popTail_abs`.** *What it says:* the implementation's "pop the top and continue with the rest" stands for
the spec's `match popElem st with | .ok (_, st') => pure st' | .error e => throw e`. *What it assumes:*
nothing. *Why it matters:* the `VERIFY` forms' final pop (`OP_EQUALVERIFY`, `OP_NUMEQUALVERIFY`), closed by
`exact` against each family's own `match` (#50).

### `bitwise_exec_isSome` (theorem, `lean/BsvScript/Properties/Coverage.lean:54`)

The bitwise family's hook answers exactly on `OP_AND`, `OP_OR`, `OP_XOR`,
`OP_INVERT`, `OP_LSHIFT`, `OP_RSHIFT`, `OP_EQUAL` and `OP_EQUALVERIFY`, and on no
other byte. One of the six lemmas `opExec_isSome_of_hookOwns` assembles.

### `equal_frame` (theorem, `lean/BsvScript/Properties/Hooks.lean:318`)

`OP_EQUAL`/`OP_EQUALVERIFY` are frames.

### `p2pkhScript` (def, `lean/BsvScript/TxPolicy.lean:742`)

A pay-to-public-key-hash locking script (`OP_DUP OP_HASH160 <20 bytes> OP_EQUALVERIFY OP_CHECKSIG`),
the template `standard.cpp:53–57`.

`[SRC]` `standard.cpp:53–57`

## The corpus entries that exercise it (by rule)

| rule | corpus entries | `[SRC]` |
|---|---|---|
| `bitwise.equal` | 34 | `interpreter.cpp:1189–1217` |

