# `OP_VERIFY` (`0x69`)

**Family** flow · **module** `BsvScript.Machine` · **landed at** #8 · **the switch** §2.4 of DESIGN · the reference bitcoin-sv v1.2.3 `6504a3af` (`docs/PROVENANCE.md`).

## Semantics (the Lean docstrings that name it)

### `castToBool_eq` (theorem, `lean/BsvScript/Impl/Elem.lean:304`)

**`castToBool_eq`.** *What it says:* the element's truth is its list's. *What it assumes:* nothing. *Why it
matters:* `OP_IF`, `OP_VERIFY`, `OP_IFDUP`, `OP_NUMEQUALVERIFY` (#143).

### `verifyStep_eq` (theorem, `lean/BsvScript/Impl/Machine.lean:87`)

**`verifyStep_eq`.** *What it says:* `OP_VERIFY` on the implementation says what the spec's says. *What it
assumes:* nothing. *Why it matters:* `execFlow`'s `842–854` (#50).

`[SRC]` `interpreter.cpp:842–854`

### `vVerifyFalse_kernel` (theorem, `lean/BsvScript/Properties/KernelSample.lean:369`)

`0 OP_VERIFY` fails `SCRIPT_ERR_VERIFY` (`842–854`).

`[SRC]` `interpreter.cpp:842–854`

### `execFlow_preserves` (theorem, `lean/BsvScript/Properties/Resources.lean:113`)

**The machine's own switch, branch by branch** (`483–871`): a property of states that holds of the
state handed in, of every push's result, of the three checkers' results (`execCltv`, `execCsv`,
`execIf`), of the tracker and `OP_RETURN` updates, of `OP_VERIFY`'s pop and of the hook's answer holds
of every state `execFlow` continues with. Walked `if` by `if` (`split_ifs` on the thirteen-way chain
times out), so each of R2 and R3 discharges the branches once.

`[SRC]` `interpreter.cpp:483–871`

## The corpus entries that exercise it (by rule)

| rule | corpus entries | `[SRC]` |
|---|---|---|
| `flow.verify`, `flow.return` | 64 | `842–854`, `856–871`, `459`, `482` |

