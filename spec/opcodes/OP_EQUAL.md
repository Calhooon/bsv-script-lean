# `OP_EQUAL` (`0x87`)

**Family** bitwise · **module** `BsvScript.Ops.Bitwise` · **landed at** #9 · **the switch** `1069–1217` · the reference bitcoin-sv v1.2.3 `6504a3af` (`docs/PROVENANCE.md`).

## History and eras

- counts against `MaxOpsPerScript` executed or not (`466–467`): 500 pre-Genesis, unbounded post-Genesis at consensus (`docs/PARAMETERS.md` §1)

## Semantics (the Lean docstrings that name it)

### `equal` (def, `lean/BsvScript/Ops/Bitwise.lean:149`)

`OP_EQUAL`/`OP_EQUALVERIFY` (`1189–1217`): byte-vector equality, the two
popped, the boolean pushed (`1207–1209`); `OP_EQUALVERIFY` pops a true result
or fails with `SCRIPT_ERR_EQUALVERIFY` (`1210–1215`).

`[SRC]` `interpreter.cpp:1189–1217`, `interpreter.cpp:1207–1209`, `interpreter.cpp:1210–1215`

### `equalI_abs` (theorem, `lean/BsvScript/Impl/Bitwise.lean:91`)

**`equalI_abs`.** *What it says:* the implementation's `OP_EQUAL`/`OP_EQUALVERIFY` computes what
`Ops.Bitwise.equal` computes on the state it stands for. *What it assumes:* nothing. *Why it matters:* the
family on the implementation (#50).

### `toBytes_inj` (theorem, `lean/BsvScript/Impl/Elem.lean:136`)

**`toBytes_inj`.** *What it says:* two elements with the same bytes are the same. *What it assumes:*
nothing. *Why it matters:* `OP_EQUAL` compares the packed arrays (#143).

### `decide_toBytes_eq` (theorem, `lean/BsvScript/Impl/Elem.lean:164`)

**`decide_toBytes_eq`.** *What it says:* comparing two elements' lists is comparing the elements (the
runtime's `lean_sarray_dec_eq`, a `memcmp`). *What it assumes:* nothing. *Why it matters:* `OP_EQUAL` (#143).

### `toBytes_vchTrue` (theorem, `lean/BsvScript/Impl/Elem.lean:223`)

**`toBytes_vchTrue`.** *What it says:* the element is `[1]`. *What it assumes:* nothing. *Why it matters:*
`OP_EQUAL` and the signature checks' results (#143).

### `toBytes_vchFalse` (theorem, `lean/BsvScript/Impl/Elem.lean:227`)

**`toBytes_vchFalse`.** *What it says:* `vchFalse` is the empty element. *What it assumes:* nothing. *Why
it matters:* `OP_EQUAL` and the signature checks' results (#143).

### `isP2SH` (def, `lean/BsvScript/Machine.lean:63`)

`IsP2SH` (`script.cpp:168–172`): 23 bytes, `OP_HASH160 <20 bytes> OP_EQUAL`.

`[SRC]` `script.cpp:168–172`

### `bitwise_exec_isSome` (theorem, `lean/BsvScript/Properties/Coverage.lean:54`)

The bitwise family's hook answers exactly on `OP_AND`, `OP_OR`, `OP_XOR`,
`OP_INVERT`, `OP_LSHIFT`, `OP_RSHIFT`, `OP_EQUAL` and `OP_EQUALVERIFY`, and on no
other byte. One of the six lemmas `opExec_isSome_of_hookOwns` assembles.

### `equal_frame` (theorem, `lean/BsvScript/Properties/Hooks.lean:318`)

`OP_EQUAL`/`OP_EQUALVERIFY` are frames.

### `vModSign_kernel` (theorem, `lean/BsvScript/Properties/KernelSample.lean:279`)

`-7 2 OP_MOD -1 OP_EQUAL` is valid: the remainder takes the dividend's sign (`1324–1330`; post-Genesis the number is a big integer, `script_num.cpp:246`, `big_int.cpp:250–260`).

`[SRC]` `interpreter.cpp:1324–1330`, `script_num.cpp:246`, `big_int.cpp:250–260`

### `vPick_kernel` (theorem, `lean/BsvScript/Properties/KernelSample.lean:309`)

`7 8 9 2 OP_PICK 7 OP_EQUAL` is valid: with the count popped, the element at depth 2 (the top at depth 0), the 7, is copied to the top (`1006–1027`).

`[SRC]` `interpreter.cpp:1006–1027`

### `vRot_kernel` (theorem, `lean/BsvScript/Properties/KernelSample.lean:315`)

`1 2 3 OP_ROT 1 OP_EQUAL` is valid: the third element moves to the top (`1029–1038`).

`[SRC]` `interpreter.cpp:1029–1038`

### `vAlt_kernel` (theorem, `lean/BsvScript/Properties/KernelSample.lean:327`)

`5 OP_TOALTSTACK OP_FROMALTSTACK 5 OP_EQUAL` is valid: the round trip through the alt stack (`876–887`).

`[SRC]` `interpreter.cpp:876–887`

### `vDepth_kernel` (theorem, `lean/BsvScript/Properties/KernelSample.lean:339`)

`1 1 OP_DEPTH 2 OP_EQUAL` is valid: the depth is pushed as a number (`966–970`).

`[SRC]` `interpreter.cpp:966–970`

### `vCat_kernel` (theorem, `lean/BsvScript/Properties/KernelSample.lean:387`)

`<11> <22> OP_CAT <1122> OP_EQUAL` is valid (`1687–1706`).

`[SRC]` `interpreter.cpp:1687–1706`

### `isP2SH_of_shape` (theorem, `lean/BsvScript/Properties/P2SH.lean:52`)

**The P2SH shape** (`IsP2SH`, `script.cpp:168–172`): `OP_HASH160`, a 20-byte push, `OP_EQUAL`.

`[SRC]` `script.cpp:168–172`

## The corpus entries that exercise it (by rule)

| rule | corpus entries | `[SRC]` |
|---|---|---|
| `bitwise.equal` | 34 | `interpreter.cpp:1189–1217` |
| `eras.height.p2sh`, `eras.height.dersig`, `eras.height.cltv`, `eras.height.csv`, `eras.height.uahf`, `eras.height.daa` | 16 | `verify_script_flags.cpp:32–81`; `validation.cpp:2973–2982`, `3473`; `chainparams.cpp:1038–1076`, `:28` |
| `p2sh.grandfathered`, `p2sh.disabled`, `p2sh.pushonly`, `p2sh.output.post-genesis` | 10 | `interpreter.cpp:2354–2356`, `2380–2424`, `2430–2448`; `script.cpp:164–168`; `validation.cpp:610–623`; `standard.cpp:72–76` (policy) |

