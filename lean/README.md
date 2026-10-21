# lean: the semantics, its theorems and the evaluator's Lean side

This directory is one Lake project. It holds the executable semantics of BSV script and of the
transaction and chain rules around it, the theorems about that semantics, and the Lean half of the
evaluator `eval/bsvs`. Every rule cites the bitcoin-sv source at the release pinned in
`docs/PROVENANCE.md`. Words such as "era", "flag word" and "policy" are defined in `docs/GLOSSARY.md`.

The tree on `main` has no `sorry`, and its theorems depend on Lean's three standard axioms only.

## The layout

The libraries come from `lean/lakefile.toml`.

| library | roots | what it holds |
|---|---|---|
| `BsvScript` | `lean/BsvScript.lean` | the script semantics: numbers, the stack machine, the opcode families, sighash, flags, parameters, the transaction checks and the policy gates |
| `BsvChain` | `lean/BsvChain.lean` | the transaction state machine: the UTXO set, blocks, the chain and reorgs, the mempool, finality, and the views a client reads |
| `StaleRunCheck` | `lean/BsvChain/Properties/StaleRun.lean` | one chain scenario evaluated by Lean's kernel itself, as the kernel sample does for script (`docs/GLOSSARY.md`), kept in its own library so that `lake build BsvChain` does not reduce it |
| `Bsvs` | `lean/Bsvs/Corpus.lean`, `Trace.lean`, `Run.lean`, `SelfTest.lean` | the evaluator's Lean side: the corpus entry, the multi-input runner, the trace, the self-test |
| `TestSupport` | eleven modules under `lean/Test/` | shared helpers for the check executables |

The directories:

- `lean/BsvScript/`: the definitions of the script semantics, one module per family (the table below).
- `lean/BsvScript/Ops/`: the opcode families as the semantics states them.
- `lean/BsvScript/Impl/`: a faster copy of each family over an array-backed stack. It is not the semantics.
  `BsvScript.Eval.verifyScript_eq_I` proves it gives the same verdict on every spend, and the compiler
  runs it in place of the definition.
- `lean/BsvScript/Properties/`: the theorems about the script semantics (the families below).
- `lean/BsvChain/` and `lean/BsvChain/Properties/`: the chain definitions and their theorems.
- `lean/Test/`: the check executables (`numcheck`, `flowcheck`, `sighashcheck` and the rest in the lakefile).
  Each one runs the semantics against a corpus under `corpus/`.
- `lean/Bsvs/`: the library above and `lean/Bsvs/Main.lean`, the root of the executable `bsvs`.
- `eval/`: the shell side of the evaluator. `eval/bsvs` builds and runs the `bsvs` executable;
  `eval/README.md` documents its commands.
- `lean/AxiomCheck.lean` and `lean/AXIOMS-ALLOWED`: the axiom check (below).

## Where each opcode family lives

Every family is a function of type `OpExec` (`lean/BsvScript/Machine.lean:232`).
`BsvScript.Eval.opExec` (`lean/BsvScript/Eval.lean:34`) tries the six families in order, and
`BsvScript.Eval.verifyScript` (`lean/BsvScript/Eval.lean:40`) is the evaluator.

| family | module | defining declaration |
|---|---|---|
| the opcode table and the error codes | `lean/BsvScript/Opcodes.lean` | `OP_0` and the other byte constants; `inductive ScriptError` (line 157) |
| pushes, flow control (`OP_IF`, `OP_VERIFY`, `OP_RETURN`), locktime checks | `lean/BsvScript/Machine.lean` | `execFlow` (line 309), `execCltv` (274), `execCsv` (291) |
| the state machine | `lean/BsvScript/Machine.lean` | `structure State` (141), `structure Env` (167), `loop` (379), `evalScript` (407), `verifyScript` (495) |
| arithmetic | `lean/BsvScript/Ops/Arith.lean` | `unary` (87), `binary` (144), `within` (192), `exec` (233) |
| stack | `lean/BsvScript/Ops/Stack.lean` | `execStack` (86), `exec` (248) |
| splice and conversion | `lean/BsvScript/Ops/Splice.lean` | `cat` (25), `split` (53), `num2binOp` (85), `bin2num` (106), `exec` (114) |
| bitwise | `lean/BsvScript/Ops/Bitwise.lean` | `bitwise2` (52), `invert` (84), `shift` (114), `equal` (152), `exec` (194) |
| hashes and signatures | `lean/BsvScript/Ops/Crypto.lean` | `checkSignatureEncoding` (62), `checkSigOp` (140), `checkMultiSigOp` (199), `exec` (241) |
| `OP_SUBSTR`, `OP_LEFT`, `OP_RIGHT`, `OP_LSHIFTNUM`, `OP_RSHIFTNUM` | `lean/BsvScript/Ops/Expansion.lean` | `substr` (60), `left` (118), `exec` (333) |
| the number encoding | `lean/BsvScript/Numbers.lean` | `encode` (146), `decode` (164), `readNum` (251), `num2bin` (280) |
| the hash functions | `lean/BsvScript/Hash/Sha256.lean`, `Sha1.lean`, `Ripemd160.lean` | one executable function each |
| the curve and the ECDSA equation | `lean/BsvScript/Crypto/Secp256k1.lean` | `decodePubKey` (156), `verify` (265) |
| the sighash digest | `lean/BsvScript/Sighash.lean` | `structure SigHashType` (61), `sighashBIP143` (182), `sighashOriginal` (258), `sighash` (268) |
| parameters and the flag record | `lean/BsvScript/Params.lean` | `structure Flags` (35), `structure EvalParams` (152), `structure ChainParams` (164), `structure NodeConfig` (200) |
| the flag word by era and path | `lean/BsvScript/Flags.lean` | `protocolEraOf` (79), `mandatoryFlags` (140), `blockScriptFlags` (175), `mempoolScriptFlags` (193) |
| the transaction frame | `lean/BsvScript/Tx.lean` | `structure Tx` (34), `decodeTx` (101) |
| the transaction context of a spend | `lean/BsvScript/TxContext.lean` | what the interpreter reads from the transaction: the signature, locktime and sequence checks |
| the consensus transaction checks | `lean/BsvScript/TxRules.lean` | `checkTransactionCommon` (87), `checkRegularTransaction` (104), `checkCoinbase` (117) |
| the signature-operation count | `lean/BsvScript/SigOps.lean` | `sigOpCount` (96) |
| standardness (policy) | `lean/BsvScript/Standard.lean` | `solver` (163), `isStandardTx` (257) |
| the mempool's policy caps | `lean/BsvScript/TxPolicy.lean` | `txPolicyGate` (127), `mempoolTxPolicy` (406) |
| the UTXO set | `lean/BsvChain/Utxo.lean` | `checkTxInputs` (120), `applyTx` (241), `undoTx` (252) |
| blocks | `lean/BsvChain/Block.lean` | `checkBlock` (78), `connectBlock` (381), `disconnectBlock` (470) |
| the chain | `lean/BsvChain/Chain.lean` | `structure ChainState` (341), `acceptBlock` (528), `activateBestChain` (829) |
| the mempool | `lean/BsvChain/Mempool.lean` | `accept` (1244) |

A policy limit appears only as a named field of `NodeConfig`, with its default and its source.
A consensus rule never reads one.

### Six lookups

| what | file and line |
|---|---|
| `OP_CHECKSIG`, `OP_CHECKSIGVERIFY` | `checkSigOp`, `lean/BsvScript/Ops/Crypto.lean:140` |
| `OP_CHECKMULTISIG`, `OP_CHECKMULTISIGVERIFY` | `checkMultiSigOp`, `lean/BsvScript/Ops/Crypto.lean:199` |
| `OP_NUM2BIN` | `num2binOp`, `lean/BsvScript/Ops/Splice.lean:85`; the conversion `num2bin`, `lean/BsvScript/Numbers.lean:280` |
| `OP_BIN2NUM` | `bin2num`, `lean/BsvScript/Ops/Splice.lean:106` |
| the number codec | `encode`, `lean/BsvScript/Numbers.lean:146`; `decode`, `lean/BsvScript/Numbers.lean:164` |
| the sighash digest | `sighash`, `lean/BsvScript/Sighash.lean:268` (it picks `sighashBIP143` at line 182 or `sighashOriginal` at line 258) |

## The theorems and their explainers

Each theorem carries a docstring that says what it states, what it assumes and why it matters.
Three generated pages collect them; edit the Lean docstring, never the page.

- `spec/theorems.md`: every theorem with its explainer, grouped by module.
- `spec/modules.md`: every module's docstring, in module order.
- `spec/rules.md`: the rule vocabulary of the corpus, with each rule's source lines and its corpus entries.

The families of theorems under `lean/BsvScript/Properties/`:

| module | what it proves |
|---|---|
| `Basic.lean` | that the evaluator reads the flag word through six projections only, and that the version gate does not interfere |
| `Coverage.lean` | that every opcode the reference's switch names is handled by some family, so no byte is left undefined |
| `Resources.lean`, `Hooks.lean` | the resource bounds the machine enforces, for every family |
| `Widths.lean` | the width limits: the number reader's overflow refusal, the hash digest widths, `OP_CAT` and `OP_SPLIT` as inverses, `OP_NUM2BIN`'s memory refusal, the shift bounds |
| `Sighash.lean` | what a signer must hash for the node to accept its signature |
| `VersionGate.lean` | the restrictions a transaction's version turns on or off |
| `Eras.lean`, `P2SH.lean` | the era boundaries, the activation heights and P2SH |
| `TxValue.lean` | the output-side value bounds of the transaction checks |
| `KernelSample.lean` | a sample of the semantics evaluated by the kernel itself, beside the compiled evaluator the corpus runs |

The chain's theorems sit beside their definitions under `lean/BsvChain/Properties/`.

The newest full check on the project's build machine walked 115 modules and 8634 theorems, and found 0
axioms beyond Lean's three (`docs/records/20261019-224915-make-check-box.txt`).

## The axioms

`lean/AXIOMS-ALLOWED` lists the only axioms a theorem may depend on: `propext`, `Classical.choice`
and `Quot.sound`, the three that Lean's own library uses. No domain axiom stands in for signature
verification: the ECDSA equation is an executable definition in `lean/BsvScript/Crypto/Secp256k1.lean`.

`lean/AxiomCheck.lean` prints the axioms of every listed theorem with `#print axioms`, and then walks
every module the libraries hold and collects the axioms of every theorem there. `tools/axiom_check.py`
runs that file with `lake env lean AxiomCheck.lean` and fails on any axiom outside the list, on a
theorem missing from the list, and on any compiler override. Run it from the repository root:

```sh
python3 tools/axiom_check.py
```

Build before the check: `lake env lean` builds nothing, so on a stale build it checks old files. `tools/check.sh axioms`
builds the `StaleRunCheck` library (which `AxiomCheck.lean` imports), runs the checker's self-test, then runs the
checker; `make verify` runs that same leg.

## Build

The toolchain is `leanprover/lean4:v4.34.0` (`lean/lean-toolchain`). Mathlib is pinned at
`5ed2965256430c3649e86755f9576b54eca72435` (`lean/lake-manifest.json`). `docs/PROVENANCE.md` §1a
records both pins. With `elan` installed:

```sh
cd lean
lake exe cache get    # Mathlib's prebuilt files, once
lake build            # every default target, StaleRunCheck included
```

A bare `lake build` includes `StaleRunCheck`, the heaviest target in memory and time.
`lake build BsvScript BsvChain Bsvs` builds the semantics and the evaluator's Lean side without it, and `lake build bsvs` builds the executable `eval/bsvs` runs. From the repository root, `make verify` runs the build, the
axiom check, the evaluator self-test and the harness smoke run in that order.

## Reading one theorem end to end

Take `BsvScript.Numbers.decode_encode`, at `lean/BsvScript/Numbers.lean:468`:

```lean
theorem decode_encode (v : Int) : decode (encode v) = v
```

It says that decoding the script-number encoding of any integer gives that integer back.
`encode` (`lean/BsvScript/Numbers.lean:146`) is the node's `serialize`: zero is the empty byte string,
and any other value is its magnitude in little-endian bytes with the sign on the top bit of the last
byte; when the magnitude's top bit is already set, an extra byte, 0x00 (positive) or 0x80 (negative), carries the sign. `decode`
(`lean/BsvScript/Numbers.lean:164`) is the node's `deserialize`. The docstring above each definition names
the source lines it transcribes. The theorem's explainer is under `BsvScript.Numbers` in `spec/theorems.md`,
and `lean/AxiomCheck.lean` lists it, so the axiom check covers it.
