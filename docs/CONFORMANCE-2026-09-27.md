# The conformance report of 2026-09-27 (#30)

Issue numbers on this page are the archived tracker's ([docs/GLOSSARY.md](GLOSSARY.md), "archived #n").

**What this page stands for.** Every disagreement between the spec's evaluator and five implementations of BSV script, on the 26 generated corpora, at the commit `c62929e`, each with its class, the citation that decides it and its smallest witness, reproducible by one command (`tools/witness.sh <witness-id>`). Written by `tools/conformance.py` from the engine manifests under `corpus/witnesses/` and the classifier tables under `harness/rules/` (D83c); nothing on this page is decided here. The drivers are RED on a divergence no table explains and `rules_check` (the tripwire's harness leg) replays the go-sdk, ts-sdk, gobdk and sv-node manifests from their recorded verdicts and bsv-rs's live, including the combined gate/script tx road and its separate BIP34-context agreements. Every divergence below is classified `[X]`; the two recorded tx finality disagreements remain SPEC-SIDE under `tx.finality.out-of-scope`. The witnesses' replay record: NOT YET (a page without one does not ship).

**The classification** (#30's spec-wrong vs implementation-wrong). IMPLEMENTATION-WRONG: the reference and the spec agree, the implementation differs (a class ruled `impl-wrong`). SPEC-SIDE: the REFERENCE disagrees with the spec (CLAUDE.md rule 4: a spec bug until a human proves otherwise from source; the class's note says whether the rule sits outside the spec's scope or is a gap in it). OPEN: an implementation's class ruled open by the maintainers (a mode or a node's policy setting, never a consensus divergence) or one nobody has ruled yet (D8). MECHANISM: an engine abort or timeout filed as a witness (D15), never counted as agreement and never as an undecided run as well; its ruling column carries its disposition. An SDK's refusal to decode a transaction the reference decides is such an abort (`engine.decode-refusal`, the maintainers' ruling R3 on #32, 2026-10-05): implementation-wrong, the engine's script status undecided, the spec's script verdict kept. A script verdict is not a transaction's validity: that class does not establish an engine failure on a transaction the reference would accept. The ts-sdk's `default/…` columns are its default mode (@bsv/sdk without `verifyFlags`): their classes are scoped to that mode, the four consensus omissions of the mode ruled implementation-wrong and its policy-only omissions kept apart as OPEN (the maintainers' ruling R4 on #32, 2026-10-05).

## 1. The runs, per implementation, per corpus, per column

### bsv-rs

| corpus | entries | the implementation | the spec | column | agree | classified | undecided (the corpus) | aborts filed as witnesses (D15; the corpus) | the witness file's sha256 (the manifest's) |
|---|---|---|---|---|---|---|---|---|---|
| `corpus/seed` | 10000 | 0.5.0 | spec@cb7e46e | `spec` | 10000 | 0 | 0 | 0 | `e3b0c44298fc…` |
| `corpus/seed` |  |  |  | `spec-mempool` | 10000 | 0 |  |  |  |
| `corpus/flow` | 1094 | 0.5.0 | spec@cb7e46e | `spec` | 1094 | 0 | 0 | 0 | `e3b0c44298fc…` |
| `corpus/flow` |  |  |  | `spec-mempool` | 1094 | 0 |  |  |  |
| `corpus/arith` | 692 | 0.5.0 | spec@cb7e46e | `spec` | 692 | 0 | 0 | 0 | `e3b0c44298fc…` |
| `corpus/arith` |  |  |  | `spec-mempool` | 692 | 0 |  |  |  |
| `corpus/stack` | 262 | 0.5.0 | spec@cb7e46e | `spec` | 262 | 0 | 0 | 0 | `e3b0c44298fc…` |
| `corpus/stack` |  |  |  | `spec-mempool` | 262 | 0 |  |  |  |
| `corpus/crypto` | 84 | 0.5.0 | spec@cb7e46e | `spec` | 84 | 0 | 0 | 0 | `e3b0c44298fc…` |
| `corpus/crypto` |  |  |  | `spec-mempool` | 84 | 0 |  |  |  |
| `corpus/bytes` | 512 | 0.5.0 | spec@cb7e46e | `spec` | 512 | 0 | 0 | 0 | `e3b0c44298fc…` |
| `corpus/bytes` |  |  |  | `spec-mempool` | 512 | 0 |  |  |  |
| `corpus/eras` | 74 | 0.5.0 | spec@cb7e46e | `spec` | 32 | 0 | 42 | 0 | `e3b0c44298fc…` |
| `corpus/eras` |  |  |  | `spec-mempool` | 32 | 0 |  |  |  |
| `corpus/gen` | 1157 | 0.5.0 | spec@cb7e46e | `spec` | 1152 | 0 | 5 | 0 | `e3b0c44298fc…` |
| `corpus/gen` |  |  |  | `spec-mempool` | 1152 | 0 |  |  |  |
| `corpus/tx` | 40 | 0.5.0 | spec@cb7e46e | `spec` | 14 | 0 | 26 | 0 | `e3b0c44298fc…` |
| `corpus/tx` |  |  |  | `spec-mempool` | 14 | 0 |  |  |  |
| `corpus/million` | 4 | 0.5.0 | spec@cb7e46e | `spec` | 0 | 4 | 0 | 4 | `bfbc5a72996c…` |
| `corpus/million` |  |  |  | `spec-mempool` | 4 | 0 |  |  |  |
| `corpus/cpp-bn_op` | 170 | 0.5.0 | spec@cb7e46e | `spec` | 75 | 95 | 0 | 0 | `3b62b8109576…` |
| `corpus/cpp-bn_op` |  |  |  | `spec-mempool` | 170 | 0 |  |  |  |
| `corpus/cpp-lrshiftnum` | 36 | 0.5.0 | spec@cb7e46e | `spec` | 13 | 23 | 4 | 0 | `84947a489ad2…` |
| `corpus/cpp-lrshiftnum` |  |  |  | `spec-mempool` | 32 | 0 |  |  |  |
| `corpus/cpp-multisig` | 30 | 0.5.0 | spec@cb7e46e | `spec` | 24 | 6 | 30 | 0 | `52cda5fb56b3…` |
| `corpus/cpp-multisig` |  |  |  | `spec-mempool` | 0 | 0 |  |  |  |
| `corpus/cpp-opcode` | 144324 | 0.5.0 | spec@cb7e46e | `spec` | 67061 | 77263 | 144201 | 0 | `288e5d4350c8…` |
| `corpus/cpp-opcode` |  |  |  | `spec-mempool` | 123 | 0 |  |  |  |
| `corpus/cpp-script` | 67991 | 0.5.0 | spec@cb7e46e | `spec` | 357 | 67634 | 67857 | 0 | `2d94e8c9358f…` |
| `corpus/cpp-script` |  |  |  | `spec-mempool` | 134 | 0 |  |  |  |
| `corpus/cpp-script_P2SH` | 64 | 0.5.0 | spec@cb7e46e | `spec` | 56 | 8 | 64 | 0 | `4fa68411d6a1…` |
| `corpus/cpp-script_P2SH` |  |  |  | `spec-mempool` | 0 | 0 |  |  |  |
| `corpus/cpp-sigopcount` | 6 | 0.5.0 | spec@cb7e46e | `spec` | 6 | 0 | 4 | 0 | `e3b0c44298fc…` |
| `corpus/cpp-sigopcount` |  |  |  | `spec-mempool` | 2 | 0 |  |  |  |
| `corpus/cpp-transaction` | 167 | 0.5.0 | spec@cb7e46e | `spec` | 108 | 59 | 101 | 0 | `5dcae9ea5c6c…` |
| `corpus/cpp-transaction` |  |  |  | `spec-mempool` | 66 | 0 |  |  |  |
| `corpus/cpp-txvalidationcache-t100-g1-c1` | 1024 | 0.5.0 | spec@cb7e46e | `spec` | 1024 | 0 | 1024 | 0 | `e3b0c44298fc…` |
| `corpus/cpp-txvalidationcache-t100-g1-c1` |  |  |  | `spec-mempool` | 0 | 0 |  |  |  |
| `corpus/cpp-txvalidationcache-t100-g1-c102` | 2048 | 0.5.0 | spec@cb7e46e | `spec` | 2048 | 0 | 2048 | 0 | `e3b0c44298fc…` |
| `corpus/cpp-txvalidationcache-t100-g1-c102` |  |  |  | `spec-mempool` | 0 | 0 |  |  |  |
| `corpus/cpp-txvalidationcache-t100-g102-c102` | 4097 | 0.5.0 | spec@cb7e46e | `spec` | 2049 | 2048 | 4097 | 0 | `a0e74ce266c6…` |
| `corpus/cpp-txvalidationcache-t100-g102-c102` |  |  |  | `spec-mempool` | 0 | 0 |  |  |  |
| `corpus/cpp-txvalidationcache-t101-g1-c1` | 4096 | 0.5.0 | spec@cb7e46e | `spec` | 4096 | 0 | 4096 | 0 | `e3b0c44298fc…` |
| `corpus/cpp-txvalidationcache-t101-g1-c1` |  |  |  | `spec-mempool` | 0 | 0 |  |  |  |
| `corpus/cpp-txvalidationcache-t101-g1-c103` | 8192 | 0.5.0 | spec@cb7e46e | `spec` | 8192 | 0 | 8192 | 0 | `e3b0c44298fc…` |
| `corpus/cpp-txvalidationcache-t101-g1-c103` |  |  |  | `spec-mempool` | 0 | 0 |  |  |  |
| `corpus/cpp-txvalidationcache-t101-g102-c1` | 3 | 0.5.0 | spec@cb7e46e | `spec` | 1 | 2 | 3 | 0 | `0c588a6e02c8…` |
| `corpus/cpp-txvalidationcache-t101-g102-c1` |  |  |  | `spec-mempool` | 0 | 0 |  |  |  |
| `corpus/cpp-txvalidationcache-t101-g103-c103` | 16384 | 0.5.0 | spec@cb7e46e | `spec` | 10240 | 6144 | 16384 | 0 | `14a82ca863e1…` |
| `corpus/cpp-txvalidationcache-t101-g103-c103` |  |  |  | `spec-mempool` | 0 | 0 |  |  |  |
| `corpus/road` | 13512 | 0.5.0 | spec@cb7e46e | `spec` | 13512 | 0 | 0 | 0 | `e3b0c44298fc…` |
| `corpus/road` |  |  |  | `spec-mempool` | 13512 | 0 |  |  |  |

### go-sdk

The recorded implementation keys in the table are compared with `spec-mempool@cb7e46e` / `spec@cb7e46e`. The current node reference keys are `sv-node-mempool@v1.2.3` / `sv-node@v1.2.3`. Prior v1.2.2 comparisons remain in the manifests' histories; these full SDK columns were reclassified offline with original implementation verdicts retained.

| corpus | entries | the implementation | the spec | column | agree | classified | undecided (the corpus) | aborts filed as witnesses (D15; the corpus) | the witness file's sha256 (the manifest's) |
|---|---|---|---|---|---|---|---|---|---|
| `corpus/seed` | 10000 | go-sdk@v1.7.2 | spec@cb7e46e | `spec` | 10000 | 0 | 0 | 0 | `e3b0c44298fc…` |
| `corpus/seed` |  |  |  | `spec-mempool` | 10000 | 0 |  |  |  |
| `corpus/flow` | 1094 | go-sdk@v1.7.2 | spec@cb7e46e | `spec` | 1094 | 0 | 0 | 0 | `e3b0c44298fc…` |
| `corpus/flow` |  |  |  | `spec-mempool` | 1094 | 0 |  |  |  |
| `corpus/arith` | 692 | go-sdk@v1.7.2 | spec@cb7e46e | `spec` | 692 | 0 | 0 | 0 | `e3b0c44298fc…` |
| `corpus/arith` |  |  |  | `spec-mempool` | 692 | 0 |  |  |  |
| `corpus/stack` | 262 | go-sdk@v1.7.2 | spec@cb7e46e | `spec` | 262 | 0 | 0 | 0 | `e3b0c44298fc…` |
| `corpus/stack` |  |  |  | `spec-mempool` | 262 | 0 |  |  |  |
| `corpus/crypto` | 84 | go-sdk@v1.7.2 | spec@cb7e46e | `spec` | 84 | 0 | 0 | 0 | `e3b0c44298fc…` |
| `corpus/crypto` |  |  |  | `spec-mempool` | 84 | 0 |  |  |  |
| `corpus/bytes` | 512 | go-sdk@v1.7.2 | spec@cb7e46e | `spec` | 512 | 0 | 0 | 0 | `e3b0c44298fc…` |
| `corpus/bytes` |  |  |  | `spec-mempool` | 512 | 0 |  |  |  |
| `corpus/eras` | 74 | go-sdk@v1.7.2 | spec@cb7e46e | `spec` | 74 | 0 | 0 | 0 | `35e4a1204031…` |
| `corpus/eras` |  |  |  | `spec-mempool` | 73 | 1 |  |  |  |
| `corpus/gen` | 1157 | go-sdk@v1.7.2 | spec@cb7e46e | `spec` | 1099 | 57 | 0 | 0 | `6fed550eab28…` |
| `corpus/gen` |  |  |  | `spec-mempool` | 1090 | 66 |  |  |  |
| `corpus/tx` | 40 | go-sdk@v1.7.2 | spec@cb7e46e | `spec` | 40 | 0 | 0 | 0 | `e3b0c44298fc…` |
| `corpus/tx` |  |  |  | `spec-mempool` | 40 | 0 |  |  |  |
| `corpus/million` | 4 | go-sdk@v1.7.2 | spec@cb7e46e | `spec` | 3 | 1 | 0 | 0 | `705216b9dcb8…` |
| `corpus/million` |  |  |  | `spec-mempool` | 4 | 0 |  |  |  |
| `corpus/cpp-bn_op` | 170 | go-sdk@v1.7.2 | spec@cb7e46e | `spec` | 170 | 0 | 0 | 0 | `e3b0c44298fc…` |
| `corpus/cpp-bn_op` |  |  |  | `spec-mempool` | 170 | 0 |  |  |  |
| `corpus/cpp-lrshiftnum` | 36 | go-sdk@v1.7.2 | spec@cb7e46e | `spec` | 36 | 0 | 0 | 0 | `ee718638744f…` |
| `corpus/cpp-lrshiftnum` |  |  |  | `spec-mempool` | 35 | 1 |  |  |  |
| `corpus/cpp-multisig` | 30 | go-sdk@v1.7.2 | spec@cb7e46e | `spec` | 30 | 0 | 0 | 0 | `e3b0c44298fc…` |
| `corpus/cpp-multisig` |  |  |  | `spec-mempool` | 30 | 0 |  |  |  |
| `corpus/cpp-opcode` | 144324 | go-sdk@v1.7.2 | spec@cb7e46e | `spec` | 144324 | 0 | 0 | 0 | `e3b0c44298fc…` |
| `corpus/cpp-opcode` |  |  |  | `spec-mempool` | 144324 | 0 |  |  |  |
| `corpus/cpp-script` | 67991 | go-sdk@v1.7.2 | spec@cb7e46e | `spec` | 67991 | 0 | 0 | 0 | `e3b0c44298fc…` |
| `corpus/cpp-script` |  |  |  | `spec-mempool` | 67991 | 0 |  |  |  |
| `corpus/cpp-script_P2SH` | 64 | go-sdk@v1.7.2 | spec@cb7e46e | `spec` | 64 | 0 | 0 | 0 | `e3b0c44298fc…` |
| `corpus/cpp-script_P2SH` |  |  |  | `spec-mempool` | 64 | 0 |  |  |  |
| `corpus/cpp-sigopcount` | 6 | go-sdk@v1.7.2 | spec@cb7e46e | `spec` | 6 | 0 | 0 | 0 | `e3b0c44298fc…` |
| `corpus/cpp-sigopcount` |  |  |  | `spec-mempool` | 6 | 0 |  |  |  |
| `corpus/cpp-transaction` | 167 | go-sdk@v1.7.2 | spec@cb7e46e | `spec` | 167 | 0 | 0 | 0 | `e3b0c44298fc…` |
| `corpus/cpp-transaction` |  |  |  | `spec-mempool` | 167 | 0 |  |  |  |
| `corpus/cpp-txvalidationcache-t100-g1-c1` | 1024 | go-sdk@v1.7.2 | spec@cb7e46e | `spec` | 1024 | 0 | 0 | 0 | `e3b0c44298fc…` |
| `corpus/cpp-txvalidationcache-t100-g1-c1` |  |  |  | `spec-mempool` | 1024 | 0 |  |  |  |
| `corpus/cpp-txvalidationcache-t100-g1-c102` | 2048 | go-sdk@v1.7.2 | spec@cb7e46e | `spec` | 2048 | 0 | 0 | 0 | `e3b0c44298fc…` |
| `corpus/cpp-txvalidationcache-t100-g1-c102` |  |  |  | `spec-mempool` | 2048 | 0 |  |  |  |
| `corpus/cpp-txvalidationcache-t100-g102-c102` | 4097 | go-sdk@v1.7.2 | spec@cb7e46e | `spec` | 4097 | 0 | 0 | 0 | `e3b0c44298fc…` |
| `corpus/cpp-txvalidationcache-t100-g102-c102` |  |  |  | `spec-mempool` | 4097 | 0 |  |  |  |
| `corpus/cpp-txvalidationcache-t101-g1-c1` | 4096 | go-sdk@v1.7.2 | spec@cb7e46e | `spec` | 4096 | 0 | 0 | 0 | `e3b0c44298fc…` |
| `corpus/cpp-txvalidationcache-t101-g1-c1` |  |  |  | `spec-mempool` | 4096 | 0 |  |  |  |
| `corpus/cpp-txvalidationcache-t101-g1-c103` | 8192 | go-sdk@v1.7.2 | spec@cb7e46e | `spec` | 8192 | 0 | 0 | 0 | `e3b0c44298fc…` |
| `corpus/cpp-txvalidationcache-t101-g1-c103` |  |  |  | `spec-mempool` | 8192 | 0 |  |  |  |
| `corpus/cpp-txvalidationcache-t101-g102-c1` | 3 | go-sdk@v1.7.2 | spec@cb7e46e | `spec` | 3 | 0 | 0 | 0 | `e3b0c44298fc…` |
| `corpus/cpp-txvalidationcache-t101-g102-c1` |  |  |  | `spec-mempool` | 3 | 0 |  |  |  |
| `corpus/cpp-txvalidationcache-t101-g103-c103` | 16384 | go-sdk@v1.7.2 | spec@cb7e46e | `spec` | 16384 | 0 | 0 | 0 | `e3b0c44298fc…` |
| `corpus/cpp-txvalidationcache-t101-g103-c103` |  |  |  | `spec-mempool` | 16384 | 0 |  |  |  |
| `corpus/road` | 13512 | go-sdk@v1.7.2 | spec@cb7e46e | `spec` | 13510 | 1 | 0 | 0 | `2e08f001374b…` |
| `corpus/road` |  |  |  | `spec-mempool` | 13504 | 7 |  |  |  |

### ts-sdk

The recorded implementation keys in the table are compared with `spec-mempool@cb7e46e` / `spec@cb7e46e`. The current node reference keys are `sv-node-mempool@v1.2.3` / `sv-node@v1.2.3`. Prior v1.2.2 comparisons remain in the manifests' histories; these full SDK columns were reclassified offline with original implementation verdicts retained.

| corpus | entries | the implementation | the spec | column | agree | classified | undecided (the corpus) | aborts filed as witnesses (D15; the corpus) | the witness file's sha256 (the manifest's) |
|---|---|---|---|---|---|---|---|---|---|
| `corpus/seed` | 10000 | ts-sdk@3.0.0 | spec@cb7e46e | `default/spec` | 9840 | 160 | 0 | 0 | `5e281806a550…` |
| `corpus/seed` |  |  |  | `default/spec-mempool` | 10000 | 0 |  |  |  |
| `corpus/seed` |  |  |  | `spec` | 10000 | 0 |  |  |  |
| `corpus/seed` |  |  |  | `spec-mempool` | 10000 | 0 |  |  |  |
| `corpus/flow` | 1094 | ts-sdk@3.0.0 | spec@cb7e46e | `default/spec` | 796 | 298 | 0 | 0 | `15fa8496baab…` |
| `corpus/flow` |  |  |  | `default/spec-mempool` | 1087 | 7 |  |  |  |
| `corpus/flow` |  |  |  | `spec` | 1094 | 0 |  |  |  |
| `corpus/flow` |  |  |  | `spec-mempool` | 1094 | 0 |  |  |  |
| `corpus/arith` | 692 | ts-sdk@3.0.0 | spec@cb7e46e | `default/spec` | 684 | 8 | 0 | 0 | `3d0a8b346e93…` |
| `corpus/arith` |  |  |  | `default/spec-mempool` | 692 | 0 |  |  |  |
| `corpus/arith` |  |  |  | `spec` | 692 | 0 |  |  |  |
| `corpus/arith` |  |  |  | `spec-mempool` | 692 | 0 |  |  |  |
| `corpus/stack` | 262 | ts-sdk@3.0.0 | spec@cb7e46e | `default/spec` | 258 | 4 | 0 | 0 | `a93535e6326f…` |
| `corpus/stack` |  |  |  | `default/spec-mempool` | 262 | 0 |  |  |  |
| `corpus/stack` |  |  |  | `spec` | 262 | 0 |  |  |  |
| `corpus/stack` |  |  |  | `spec-mempool` | 262 | 0 |  |  |  |
| `corpus/crypto` | 84 | ts-sdk@3.0.0 | spec@cb7e46e | `default/spec` | 79 | 5 | 0 | 0 | `cc73f5875f5f…` |
| `corpus/crypto` |  |  |  | `default/spec-mempool` | 82 | 2 |  |  |  |
| `corpus/crypto` |  |  |  | `spec` | 84 | 0 |  |  |  |
| `corpus/crypto` |  |  |  | `spec-mempool` | 84 | 0 |  |  |  |
| `corpus/bytes` | 512 | ts-sdk@3.0.0 | spec@cb7e46e | `default/spec` | 358 | 154 | 0 | 0 | `e7eb6b7feb1a…` |
| `corpus/bytes` |  |  |  | `default/spec-mempool` | 507 | 5 |  |  |  |
| `corpus/bytes` |  |  |  | `spec` | 512 | 0 |  |  |  |
| `corpus/bytes` |  |  |  | `spec-mempool` | 512 | 0 |  |  |  |
| `corpus/eras` | 74 | ts-sdk@3.0.0 | spec@cb7e46e | `default/spec` | 39 | 35 | 0 | 0 | `9a0714ddc290…` |
| `corpus/eras` |  |  |  | `default/spec-mempool` | 32 | 42 |  |  |  |
| `corpus/eras` |  |  |  | `spec` | 74 | 0 |  |  |  |
| `corpus/eras` |  |  |  | `spec-mempool` | 73 | 1 |  |  |  |
| `corpus/gen` | 1157 | ts-sdk@3.0.0 | spec@cb7e46e | `default/spec` | 1078 | 79 | 0 | 2 | `2eb30a228787…` |
| `corpus/gen` |  |  |  | `default/spec-mempool` | 1079 | 78 |  |  |  |
| `corpus/gen` |  |  |  | `spec` | 1139 | 18 |  |  |  |
| `corpus/gen` |  |  |  | `spec-mempool` | 1130 | 27 |  |  |  |
| `corpus/tx` | 40 | ts-sdk@3.0.0 | spec@cb7e46e | `default/spec` | 29 | 11 | 0 | 3 (3 decode refusals, R3) | `fc58099b44c6…` |
| `corpus/tx` |  |  |  | `default/spec-mempool` | 27 | 13 |  |  |  |
| `corpus/tx` |  |  |  | `spec` | 39 | 1 |  |  |  |
| `corpus/tx` |  |  |  | `spec-mempool` | 39 | 1 |  |  |  |

### gobdk

The recorded implementation keys in the table are compared with `spec-mempool@cb7e46e` / `spec@cb7e46e`. The current node reference keys are `sv-node-mempool@v1.2.3` / `sv-node@v1.2.3`. Prior v1.2.2 comparisons remain in the manifests' histories; these full SDK columns were reclassified offline with original implementation verdicts retained.

| corpus | entries | the implementation | the spec | column | agree | classified | undecided (the corpus) | aborts filed as witnesses (D15; the corpus) | the witness file's sha256 (the manifest's) |
|---|---|---|---|---|---|---|---|---|---|
| `corpus/seed` | 10000 | gobdk@4eab3acd | spec@cb7e46e | `spec` | 10000 | 0 | 0 | 0 | `e3b0c44298fc…` |
| `corpus/seed` |  |  |  | `spec-mempool` | 10000 | 0 |  |  |  |
| `corpus/flow` | 1094 | gobdk@4eab3acd | spec@cb7e46e | `spec` | 1094 | 0 | 0 | 0 | `e3b0c44298fc…` |
| `corpus/flow` |  |  |  | `spec-mempool` | 1094 | 0 |  |  |  |
| `corpus/arith` | 692 | gobdk@4eab3acd | spec@cb7e46e | `spec` | 692 | 0 | 0 | 0 | `e3b0c44298fc…` |
| `corpus/arith` |  |  |  | `spec-mempool` | 692 | 0 |  |  |  |
| `corpus/stack` | 262 | gobdk@4eab3acd | spec@cb7e46e | `spec` | 262 | 0 | 0 | 0 | `e3b0c44298fc…` |
| `corpus/stack` |  |  |  | `spec-mempool` | 262 | 0 |  |  |  |
| `corpus/crypto` | 84 | gobdk@4eab3acd | spec@cb7e46e | `spec` | 84 | 0 | 0 | 0 | `e3b0c44298fc…` |
| `corpus/crypto` |  |  |  | `spec-mempool` | 84 | 0 |  |  |  |
| `corpus/bytes` | 512 | gobdk@4eab3acd | spec@cb7e46e | `spec` | 512 | 0 | 0 | 0 | `e3b0c44298fc…` |
| `corpus/bytes` |  |  |  | `spec-mempool` | 512 | 0 |  |  |  |
| `corpus/eras` | 74 | gobdk@4eab3acd | spec@cb7e46e | `spec` | 74 | 0 | 0 | 0 | `e3b0c44298fc…` |
| `corpus/eras` |  |  |  | `spec-mempool` | 74 | 0 |  |  |  |
| `corpus/gen` | 1157 | gobdk@4eab3acd | spec@cb7e46e | `spec` | 1099 | 58 | 0 | 0 | `09dd8985f352…` |
| `corpus/gen` |  |  |  | `spec-mempool` | 1099 | 58 |  |  |  |
| `corpus/tx` | 40 | gobdk@4eab3acd | spec@cb7e46e | `spec` | 40 | 0 | 0 | 0 | `e3b0c44298fc…` |
| `corpus/tx` |  |  |  | `spec-mempool` | 40 | 0 |  |  |  |

### teranode-instance (#41, #28)

The node itself, not its engine alone: Teranode `v0.16.0` at `4edb60a40c6628ff0ef60231c2628efd7103fde5`, run on the box under its test settings¹. Its columns compare the node's answers with the REFERENCE's verdicts recorded in each corpus (`sv-node@v1.2.2` for `block`, `sv-node-mempool@v1.2.2` for `mempool`), not with the spec; the classifier has not read them (no disagreement to classify). `unfundable`: the node refused to create the entry's previous outputs³; `undecided`: no verdict, by name in the manifest². Written by `tools/conformance.py` from the manifests under `harness/engines/instance41/runs/` and the checked replacements indexed by `corpus/instances/teranode/manifest.json`.

| corpus | entries | the implementation | compared with | column | agree | disagree | unfundable | undecided | the manifest's sha256 |
|---|---|---|---|---|---|---|---|---|---|
| `corpus/seed` | 10000 | teranode@v0.16.0 | sv-node@v1.2.2 (recorded) | `block` | 9988 | 0 | 0 | 12 | 5 chunk manifests |
| `corpus/seed` |  |  |  | `mempool` | 9986 | 0 | 0 | 14 |  |
| `corpus/flow` | 1094 | teranode@v0.16.0 | sv-node@v1.2.2 (recorded) | `block` | 1088 | 0 | 6 | 0 | `a46d931f56b3…` |
| `corpus/flow` |  |  |  | `mempool` | 1088 | 0 | 6 | 0 |  |
| `corpus/arith` | 692 | teranode@v0.16.0 | sv-node@v1.2.2 (recorded) | `block` | 692 | 0 | 0 | 0 | `c22dfbe4859f…` |
| `corpus/arith` |  |  |  | `mempool` | 692 | 0 | 0 | 0 |  |
| `corpus/stack` | 262 | teranode@v0.16.0 | sv-node@v1.2.2 (recorded) | `block` | 262 | 0 | 0 | 0 | `42e7e1f0c771…` |
| `corpus/stack` |  |  |  | `mempool` | 262 | 0 | 0 | 0 |  |
| `corpus/crypto` | 84 | teranode@v0.16.0 | sv-node@v1.2.2 (recorded) | `block` | 0 | 0 | 0 | 84 | `eb1872da9f13…` |
| `corpus/crypto` |  |  |  | `mempool` | 0 | 0 | 0 | 84 |  |
| `corpus/bytes` | 512 | teranode@v0.16.0 | sv-node@v1.2.2 (recorded) | `block` | 498 | 0 | 2 | 12 | `0816d40fdf25…` |
| `corpus/bytes` |  |  |  | `mempool` | 498 | 0 | 2 | 12 |  |
| `corpus/eras` | 74 | teranode@v0.16.0 | sv-node@v1.2.2 (recorded) | `block` | 8 | 0 | 0 | 66 | `44ffcc9e4d43…` |
| `corpus/eras` |  |  |  | `mempool` | 8 | 0 | 0 | 66 |  |
| `corpus/gen` | 1157 | teranode@v0.16.0 | sv-node@v1.2.2 (recorded) | `block` | 958 | 0 | 22 | 177 | `62210de9e6a9…` |
| `corpus/gen` |  |  |  | `mempool` | 958 | 0 | 22 | 177 |  |
| `corpus/tx` | 40 | teranode@v0.16.0 | sv-node@v1.2.2 (recorded) | `block` | 6 | 0 | 1 | 33 | `0a69b5a4153b…` |
| `corpus/tx` |  |  |  | `mempool` | 6 | 0 | 0 | 34 |  |
| `corpus/road` | 13512 | teranode@v0.16.0 | sv-node@v1.2.2 (recorded) | `block` | 13418 | 0 | 8 | 86 | 4 chunk manifests |
| `corpus/road` |  |  |  | `mempool` | 13417 | 0 | 8 | 87 |  |

¹ Binary sha256 `dedd0003386ac5ee7969ab1beaab9db91b0291baf70e066717a3c8e85b3f9ee8`; settings hash `133d2473bdbbfe199b39f7e586a80c37eed0936b952749759f616593bed8ce88` (the `tx` run's chain: `1e4de80c73a8e751…`, differing in `DATADIR`, `TMPDIR`); native validator client `528ec6de05c65498aea684d92a8572e92bdba814322bab87e049c6513a78dee4`; regtest at the heights the manifests name (Genesis 100, Chronicle 200, coinbase maturity 100; tracker comment 5853443740; go-chaincfg v1.6.2 params.go:276-277 (mainnet), 463,475-476 (regtest)): `seed`, `arith`, `bytes`, `crypto`, `eras`, `flow`, `gen`, `road`, `stack` on the chain of settings hash `133d2473…` (tips 206 to 255); `tx` on the chain of settings hash `1e4de80c…` (tips 0 to 103). The manifests: `corpus/instances/teranode/`, `harness/engines/instance41/runs/20261005-231500-seed/`, `harness/engines/instance41/runs/20261006-001608-corpora/arith/`, `harness/engines/instance41/runs/20261006-001608-corpora/bytes/`, `harness/engines/instance41/runs/20261006-001608-corpora/crypto/`, `harness/engines/instance41/runs/20261006-001608-corpora/eras/`, `harness/engines/instance41/runs/20261006-001608-corpora/flow/`, `harness/engines/instance41/runs/20261006-001608-corpora/road/`, `harness/engines/instance41/runs/20261006-001608-corpora/stack/`, `harness/engines/instance41/runs/20261006-001608-corpora/tx/`; the records `docs/records/20261006-140418-r1-lengths.md` and `docs/records/20261005-234745-instance41-seed.md` and `docs/records/20261006-013805-instance41-corpora.md`. THE LIMIT: the `block` column is the node's validator call, not a block's acceptance (the manifests' `paths.block`: "node ValidatorAPI.ValidateTransaction, SkipPolicyChecks=true, InBlock=true, parents read from its store; full block-wrapper acceptance is not inferred").

² `undecided`, by reason, from the manifests' `undecided` fields (a corpus's count stands for both paths unless split by path; an engine or node fault is a reason, never a verdict nor a class, D15):
- a signature row: the adapter rebinds outpoints and does not re-sign, because no entry carries its keys: 252 entries; `seed` 12, `crypto` 84, `bytes` 8, `eras` 14, `gen` 53, `road` 81
- an absolute locktime or sequence row (tracker comment 5853443740): 30 entries; `eras` 8, `gen` 1, `tx` 21
- a CLTV/CSV row (tracker comment 5853443740): 8 entries; `bytes` 4, `road` 4
- a mixed-era row: funding in two era ranges on one chain is not built: 163 entries; `eras` 40, `gen` 123
- a pre-Genesis row: no coinbase output matures below the regtest Genesis height: 11 entries; `eras` 4, `tx` 7
- a coinbase-shaped row: judged as a block's coinbase, and `submitblock` is unimplemented at the pin: 4 entries; `tx` 4
- an engine exception on the spend (`UNKNOWN (0): Exception thrown from C++ code`): 4 entries; `seed` block 0 · mempool 2, `road` block 0 · mempool 2; `road-seed-001961` (mempool), `road-seed-009637` (mempool), `seed-001961` (mempool), `seed-009637` (mempool)
- the node's validator gRPC limit of 4 MiB (`ResourceExhausted`): 1 entry; `tx` block 1 · mempool 0; `tx-00040` (block)
- not submitted after the block path's transport failure: 1 entry; `tx` block 0 · mempool 1; `tx-00040` (mempool)
- the node's store: `STORAGE_ERROR (69): [Spend] deadlock persisted after 3 retries`: 1 entry; `road` block 1 · mempool 0; `road-seed-006816` (block)
- the node could not decorate the previous outputs (a null outpoint): 1 entry; `tx` block 0 · mempool 1; `tx-00023` (mempool)

³ `unfundable`, by reason, from the manifests' `unfundable` fields (a corpus's count stands for both paths unless split by path; an engine or node fault is a reason, never a verdict nor a class, D15):
- an engine exception at funding (`UNKNOWN (0): Exception thrown from C++ code`; the record's **Finding.**): 16 entries; `flow` 6, `bytes` 2, `road` 8; `bytes-00105`, `bytes-00361`, `flow-00927`, `flow-00928`, `flow-00929`, `flow-00930`, `flow-01093`, `flow-01094`, `road-bytes-00105`, `road-bytes-00361`, `road-flow-00927`, `road-flow-00928`, `road-flow-00929`, `road-flow-00930`, `road-flow-01093`, `road-flow-01094`
- the funding transaction refused with `TX_INVALID (31): bad-txns-vout-p2sh`: 22 entries; `gen` 22; `gen-00846`, `gen-00847`, `gen-00856`, `gen-00857`, `gen-00866`, `gen-00867`, `gen-00876`, `gen-00877`, `gen-00886`, `gen-00887`, `gen-00896`, `gen-00897`, `gen-00906`, `gen-00907`, `gen-00916`, `gen-00917`, `gen-00926`, `gen-00927`, `gen-00936`, `gen-00937`, `gen-00946`, `gen-00947`
- the null outpoint's parent is missing (`TX_MISSING_PARENT (34)`): 1 entry; `tx` block 1 · mempool 0; `tx-00023` (block)

### sv-node

The current reference columns are `sv-node-mempool@v1.2.3` / `sv-node@v1.2.3`, compared with `spec-sv-node-mempool@cb7e46e` / `spec-sv-node@cb7e46e` from the rebuilt evaluator. The tx and road columns include its transaction gate. The historical v1.2.2 comparison has 58 gen and 2 road disagreements per column under `reference.v1.2.3.int64-overflow`; its separate manifest is `corpus/witnesses/sv-node-v1.2.2/manifest.json`. The recorded block tx finality scope boundary remains separately classified.

| corpus | entries | the implementation | the spec | column | agree | classified | undecided (the corpus) | aborts filed as witnesses (D15; the corpus) | the witness file's sha256 (the manifest's) |
|---|---|---|---|---|---|---|---|---|---|
| `corpus/seed` | 10000 | sv-node@v1.2.3 | spec@cb7e46e | `spec` | 10000 | 0 | 0 | – | `e3b0c44298fc…` |
| `corpus/seed` |  |  |  | `spec-mempool` | 10000 | 0 |  |  |  |
| `corpus/flow` | 1094 | sv-node@v1.2.3 | spec@cb7e46e | `spec` | 1094 | 0 | 0 | – | `e3b0c44298fc…` |
| `corpus/flow` |  |  |  | `spec-mempool` | 1094 | 0 |  |  |  |
| `corpus/arith` | 692 | sv-node@v1.2.3 | spec@cb7e46e | `spec` | 692 | 0 | 0 | – | `e3b0c44298fc…` |
| `corpus/arith` |  |  |  | `spec-mempool` | 692 | 0 |  |  |  |
| `corpus/stack` | 262 | sv-node@v1.2.3 | spec@cb7e46e | `spec` | 262 | 0 | 0 | – | `e3b0c44298fc…` |
| `corpus/stack` |  |  |  | `spec-mempool` | 262 | 0 |  |  |  |
| `corpus/crypto` | 84 | sv-node@v1.2.3 | spec@cb7e46e | `spec` | 84 | 0 | 0 | – | `e3b0c44298fc…` |
| `corpus/crypto` |  |  |  | `spec-mempool` | 84 | 0 |  |  |  |
| `corpus/bytes` | 512 | sv-node@v1.2.3 | spec@cb7e46e | `spec` | 512 | 0 | 0 | – | `e3b0c44298fc…` |
| `corpus/bytes` |  |  |  | `spec-mempool` | 512 | 0 |  |  |  |
| `corpus/eras` | 74 | sv-node@v1.2.3 | spec@cb7e46e | `spec` | 74 | 0 | 0 | – | `e3b0c44298fc…` |
| `corpus/eras` |  |  |  | `spec-mempool` | 74 | 0 |  |  |  |
| `corpus/gen` | 1157 | sv-node@v1.2.3 | spec@cb7e46e | `spec` | 1157 | 0 | 0 | – | `e3b0c44298fc…` |
| `corpus/gen` |  |  |  | `spec-mempool` | 1157 | 0 |  |  |  |
| `corpus/tx` | 40 | sv-node@v1.2.3 | spec@cb7e46e | `spec` | 36 | 2 | 4 | – | `81d3602209cc…` |
| `corpus/tx` |  |  |  | `spec-mempool` | 36 | 0 |  |  |  |
| `corpus/million` | 4 | sv-node@v1.2.3 | spec@cb7e46e | `spec` | 4 | 0 | 0 | – | `e3b0c44298fc…` |
| `corpus/million` |  |  |  | `spec-mempool` | 4 | 0 |  |  |  |
| `corpus/cpp-bn_op` | 170 | sv-node@v1.2.3 | spec@cb7e46e | `spec` | 170 | 0 | 0 | – | `e3b0c44298fc…` |
| `corpus/cpp-bn_op` |  |  |  | `spec-mempool` | 170 | 0 |  |  |  |
| `corpus/cpp-lrshiftnum` | 36 | sv-node@v1.2.3 | spec@cb7e46e | `spec` | 36 | 0 | 0 | – | `e3b0c44298fc…` |
| `corpus/cpp-lrshiftnum` |  |  |  | `spec-mempool` | 36 | 0 |  |  |  |
| `corpus/cpp-multisig` | 30 | sv-node@v1.2.3 | spec@cb7e46e | `spec` | 30 | 0 | 0 | – | `e3b0c44298fc…` |
| `corpus/cpp-multisig` |  |  |  | `spec-mempool` | 30 | 0 |  |  |  |
| `corpus/cpp-opcode` | 144324 | sv-node@v1.2.3 | spec@cb7e46e | `spec` | 144324 | 0 | 0 | – | `e3b0c44298fc…` |
| `corpus/cpp-opcode` |  |  |  | `spec-mempool` | 144324 | 0 |  |  |  |
| `corpus/cpp-script` | 67991 | sv-node@v1.2.3 | spec@cb7e46e | `spec` | 67991 | 0 | 0 | – | `e3b0c44298fc…` |
| `corpus/cpp-script` |  |  |  | `spec-mempool` | 67991 | 0 |  |  |  |
| `corpus/cpp-script_P2SH` | 64 | sv-node@v1.2.3 | spec@cb7e46e | `spec` | 64 | 0 | 0 | – | `e3b0c44298fc…` |
| `corpus/cpp-script_P2SH` |  |  |  | `spec-mempool` | 64 | 0 |  |  |  |
| `corpus/cpp-sigopcount` | 6 | sv-node@v1.2.3 | spec@cb7e46e | `spec` | 6 | 0 | 0 | – | `e3b0c44298fc…` |
| `corpus/cpp-sigopcount` |  |  |  | `spec-mempool` | 6 | 0 |  |  |  |
| `corpus/cpp-transaction` | 167 | sv-node@v1.2.3 | spec@cb7e46e | `spec` | 167 | 0 | 0 | – | `e3b0c44298fc…` |
| `corpus/cpp-transaction` |  |  |  | `spec-mempool` | 167 | 0 |  |  |  |
| `corpus/cpp-txvalidationcache-t100-g1-c1` | 1024 | sv-node@v1.2.3 | spec@cb7e46e | `spec` | 1024 | 0 | 0 | – | `e3b0c44298fc…` |
| `corpus/cpp-txvalidationcache-t100-g1-c1` |  |  |  | `spec-mempool` | 1024 | 0 |  |  |  |
| `corpus/cpp-txvalidationcache-t100-g1-c102` | 2048 | sv-node@v1.2.3 | spec@cb7e46e | `spec` | 2048 | 0 | 0 | – | `e3b0c44298fc…` |
| `corpus/cpp-txvalidationcache-t100-g1-c102` |  |  |  | `spec-mempool` | 2048 | 0 |  |  |  |
| `corpus/cpp-txvalidationcache-t100-g102-c102` | 4097 | sv-node@v1.2.3 | spec@cb7e46e | `spec` | 4097 | 0 | 0 | – | `e3b0c44298fc…` |
| `corpus/cpp-txvalidationcache-t100-g102-c102` |  |  |  | `spec-mempool` | 4097 | 0 |  |  |  |
| `corpus/cpp-txvalidationcache-t101-g1-c1` | 4096 | sv-node@v1.2.3 | spec@cb7e46e | `spec` | 4096 | 0 | 0 | – | `e3b0c44298fc…` |
| `corpus/cpp-txvalidationcache-t101-g1-c1` |  |  |  | `spec-mempool` | 4096 | 0 |  |  |  |
| `corpus/cpp-txvalidationcache-t101-g1-c103` | 8192 | sv-node@v1.2.3 | spec@cb7e46e | `spec` | 8192 | 0 | 0 | – | `e3b0c44298fc…` |
| `corpus/cpp-txvalidationcache-t101-g1-c103` |  |  |  | `spec-mempool` | 8192 | 0 |  |  |  |
| `corpus/cpp-txvalidationcache-t101-g102-c1` | 3 | sv-node@v1.2.3 | spec@cb7e46e | `spec` | 3 | 0 | 0 | – | `e3b0c44298fc…` |
| `corpus/cpp-txvalidationcache-t101-g102-c1` |  |  |  | `spec-mempool` | 3 | 0 |  |  |  |
| `corpus/cpp-txvalidationcache-t101-g103-c103` | 16384 | sv-node@v1.2.3 | spec@cb7e46e | `spec` | 16384 | 0 | 0 | – | `e3b0c44298fc…` |
| `corpus/cpp-txvalidationcache-t101-g103-c103` |  |  |  | `spec-mempool` | 16384 | 0 |  |  |  |
| `corpus/road` | 13512 | sv-node@v1.2.3 | spec@cb7e46e | `spec` | 13512 | 0 | 0 | – | `e3b0c44298fc…` |
| `corpus/road` |  |  |  | `spec-mempool` | 13512 | 0 |  |  |  |

**sv-node: the agreements at the instance's activation context only** (the maintainers' ruling R2 on #32, 2026-10-05). The `agree` column above counts the ordinary agreements; these are counted apart, never in it: each is a recorded verdict of the instance that would move at mainnet's activation height of the rule named.

| corpus | column | agree at the instance's context only | the entries (the recorded verdict) | the instance's BIP34 height | mainnet's |
|---|---|---|---|---|---|
| `corpus/tx` | `spec` | 2 | `tx-00029` (valid), `tx-00030` (valid) | 100,000,000 (regtest's compiled consensus.BIP34Height, chainparams.cpp:1463 at 6504a3a; the instance's configuration sets no BIP34 height [SRC]) | 227,931 (chainparams.cpp:1038 at 6504a3a [SRC]) |
| `corpus/road` | `spec` | 0 |  | 100,000,000 (regtest's compiled consensus.BIP34Height, chainparams.cpp:1463 at 6504a3a; the instance's configuration sets no BIP34 height [SRC]) | 227,931 (chainparams.cpp:1038 at 6504a3a [SRC]) |

### the reference's C++ unit tables (`corpus/cpp`, #49), per file

Each file of `corpus/cpp` (unit tables harvested at bitcoin-sv v1.2.2, `879fc8b42`, retained as a historical source snapshot) is projected by `tools/cpp_replay.py` into spends where a spend runs the same computation (an `EvalScript` call's stack rebuilt by minimal pushes in the unlocking script; a `VerifyScript` call; the `CheckInputs` and `CScriptCheck` predicates), each under the call's own flag word, and run through the four columns: the spec (`eval/bsvs corpus`), bsv-rs (`run_diff`), the node's consensus instance and its policy instance (`run_svnode`). The `spec` column is the call's word on the consensus instrument; `spec-mempool` is the relay word of the projected heights on the policy instance, a differential of its own and not the unit's call. Every other entry is undecided by name (the reason per entry in the file's ledger); `replayable: false` entries are counted apart. The last column is the node's `spec` verdict against what the C++ check asserts (rule 15: a disagreement is the reference against itself, recorded and never adjusted). That assertion comparison remains the ledger's historical `sv-node@v1.2.2` column; the active script comparisons in this table and above use the joined spec keys and `sv-node@v1.2.3`.

| file | entries | a spend form | undecided | not replayable | bsv-rs: agree `spec` · `spec-mempool` · classified · the call's word in the crate's scope | sv-node: agree `spec` · `spec-mempool` · classified | the node vs the unit's assertion: agree · disagree · no assertion |
|---|---|---|---|---|---|---|---|
| `corpus/cpp/big_int_tests.jsonl` | 46 | 0 | 46 | 0 | – · – · – · – | – · – · – | – · – · – |
| `corpus/cpp/blockcheck_tests.jsonl` | 3 | 0 | 3 | 0 | – · – · – · – | – · – · – | – · – · – |
| `corpus/cpp/bn_op_tests.jsonl` | 249 | 170 | 79 | 0 | 75 · 170 · 95 · 0 | 170 · 170 · 0 | 151 · 0 · 19 |
| `corpus/cpp/crypto_tests.jsonl` | 31 | 0 | 28 | 3 | – · – · – · – | – · – · – | – · – · – |
| `corpus/cpp/cscript_tests.jsonl` | 67 | 0 | 67 | 0 | – · – · – · – | – · – · – | – · – · – |
| `corpus/cpp/instruction_iterator_tests.jsonl` | 21 | 0 | 21 | 0 | – · – · – · – | – · – · – | – · – · – |
| `corpus/cpp/int_serialization_tests.jsonl` | 129 | 0 | 129 | 0 | – · – · – · – | – · – · – | – · – · – |
| `corpus/cpp/limitedstack_tests.jsonl` | 2 | 0 | 2 | 0 | – · – · – · – | – · – · – | – · – · – |
| `corpus/cpp/lrshiftnum_tests.jsonl` | 36 | 36 | 0 | 0 | 13 · 32 · 23 · 0 | 36 · 36 · 0 | 36 · 0 · 0 |
| `corpus/cpp/miner_tests.jsonl` | 9 | 0 | 9 | 0 | – · – · – · – | – · – · – | – · – · – |
| `corpus/cpp/multisig_tests.jsonl` | 56 | 30 | 26 | 0 | 24 · 0 · 6 · 0 | 30 · 30 · 0 | 30 · 0 · 0 |
| `corpus/cpp/opcode_tests.jsonl.gz` | 144,381 | 144,324 | 57 | 0 | 67,061 · 123 · 77,263 · 0 | 144,324 · 144,324 · 0 | 144,230 · 0 · 94 |
| `corpus/cpp/rpc_tests.jsonl` | 2 | 0 | 2 | 0 | – · – · – · – | – · – · – | – · – · – |
| `corpus/cpp/script_tests.jsonl.gz` | 135,669 | 67,991 | 67,618 | 60 | 357 · 134 · 67,634 · 124 | 67,991 · 67,991 · 0 | 67,911 · 0 · 80 |
| `corpus/cpp/script_P2SH_tests.jsonl` | 150 | 64 | 86 | 0 | 56 · 0 · 8 · 0 | 64 · 64 · 0 | 64 · 0 · 0 |
| `corpus/cpp/scriptnum_tests.jsonl` | 11,017 | 0 | 11,017 | 0 | – · – · – · – | – · – · – | – · – · – |
| `corpus/cpp/sighash_tests.jsonl` | 1,000 | 0 | 1,000 | 0 | – · – · – · – | – · – · – | – · – · – |
| `corpus/cpp/sighashtype_tests.jsonl` | 5,121 | 0 | 5,121 | 0 | – · – · – · – | – · – · – | – · – · – |
| `corpus/cpp/sigopcount_tests.jsonl` | 61 | 6 | 55 | 0 | 6 · 2 · 0 · 0 | 6 · 6 · 0 | 6 · 0 · 0 |
| `corpus/cpp/test_txnvalidator.jsonl` | 36 | 0 | 36 | 0 | – · – · – · – | – · – · – | – · – · – |
| `corpus/cpp/transaction_tests.jsonl` | 273 | 167 | 106 | 0 | 108 · 66 · 59 · 66 | 167 · 167 · 0 | 165 · 0 · 2 |
| `corpus/cpp/txvalidationcache_tests.jsonl.gz` | 286,727 | 35,844 | 250,883 | 0 | 27,650 · 0 · 8,194 · 15,360 | 35,844 · 35,844 · 0 | 35,844 · 0 · 0 |
| the family | 585,086 | 248,632 | 336,391 | 63 | 95,350 · 527 · 153,282 · 15,550 | 248,632 · 248,632 · 0 | 248,437 · 0 · 195 |

(– : no run; a file with no spend form has a ledger and no corpus. The classified runs are the `cpp-<stem>` rows of §2, each with its citation and its smallest witness. bsv-rs refuses a word without SIGHASH_FORKID, GENESIS or UTXO_AFTER_GENESIS (`engine.word-out-of-scope`), so on a word outside its scope an agreement is two refusals and not a judgment; the last bsv-rs figure counts the spends whose word the crate judges. `txvalidationcache_tests`' `CheckInputs` calls carry their own chain context, so they are projected at the test's own era, one corpus per node configuration (`cpp-txvalidationcache-t<tip>-g<genesis>-c<chronicle>`, the ledger's `groups`), each run on the run's own instances started with those activation heights on a chain of the fixture's shape, the coins read from that chain (`tools/cpp_era_run.sh`); its row sums them.)

## 2. Every class, with its citation and its smallest witness

A class under a still-private security advisory is WITHHELD on this page until the advisory publishes (D135): its row keeps its kind, its ruling, its corpus and column and its count; its name, its witness and its citation are withheld.

The published redacted rows below are retained verbatim from `docs/CONFORMANCE-2026-09-27.md` at `5e7cda8`. They are historical placeholders: their counts belong to that page's previous comparison keys. Current classified counts are in §1 and in the active engine manifests. No current private class name, witness or citation is printed here.

### bsv-rs (11 class rows)

| class | kind | ruling | corpus · column | entries | smallest witness (replay: `tools/witness.sh <id>`) | decided by |
|---|---|---|---|---|---|---|
| `engine.resource-abort` | MECHANISM | impl-wrong | `million` · `spec` | 4 | `witness-million-spec-engine.resource-abort-million-seed-969309` | the reference decides the input (its verdict recorded in the entry as sv-node@v1.2.2 on both instances, corpus/INDEX.md §4c; the spec's verdict in the witness); bsv-rs 0.3.33 spend.rs:467–473 (the LOCAL budget in force, memory_limit(): with memory_limit None, as engine.rs runs the crate, under a word WORD_MEMORY_LIMIT, 110–118, the node's POLICY default 100,000,000 on the block path as on the mempool path; in the default mode DEFAULT_MEMORY_LIMIT 32,000,000, 108), charged before any growth by check_node_budget 2415–2430 (the policy's verdict first, 2416–2422; then the local budget as a resource_error, 2423–2428, 2451–2463) and at OP_NUM2BIN's element check before the allocation (1190–1191); the reference bounds an element after Genesis by the stack memory budget alone (limitedstack; configscriptpolicy.cpp:139–154; the consensus budget is the operator's MANDATORY -maxstackmemoryusageconsensus, bitcoind.cpp:140–157, 0 meaning INT64_MAX, configscriptpolicy.cpp:280–283 and consensus.h:82, and the spec's oracle sets 0, harness/oracle/bitcoin.conf:40; OP_NUM2BIN's own bound INT32_MAX at interpreter.cpp:1749–1752) and a number by its length at the read (script_num.cpp:62 → interpreter.cpp:1807–1810) or at the shift's result (script_num.cpp:303–317 at v1.2.3); through 0.3.29 the default mode's budget applied in every mode (spend.rs:73 at 0.3.29, spend.rs:72 at 0.3.28): the Finding on #47 (5860579463) is the block path's budget at 0.3.30; the class stays for the seeded run's six (the engine side's call and the harness side's decision, 2026-09-28): under memory_limit Some(usize::MAX), the oracle's budget, each of the four witness lines gives the spec's verdict ([X-local] on the engine side, 2026-09-28T13:23:23Z) |
| `engine.word-out-of-scope` | MECHANISM | open | `cpp-bn_op` · `spec` | 95 | `witness-cpp-bn_op-spec-engine.word-out-of-scope-cpp-bn_op-00001` | bsv-rs 0.3.33 flags.rs:500–519 (ScriptFlags::check: a word without SIGHASH_FORKID, GENESIS or UTXO_AFTER_GENESIS, or with CHRONICLE without GENESIS, is ScriptFlagsError::NotApplicable, the crate's own scope: "pre-Genesis block rules are not implemented by this interpreter"), reported by Spend::validate as an evaluation error, spend.rs:523–529 ("Invalid verification flags: ...", bsvrs_codes.rs's SCRIPT_ERR_INVALID_FLAGS row; 0.3.30's flags.rs:493-512 and spend.rs:499-505 until the cpp column was re-recorded at 0.3.32); the reference evaluates such a word (valid_flags refuses only UTXO_AFTER_CHRONICLE without UTXO_AFTER_GENESIS, interpreter.cpp:2259–2262, 2312–2313, and CLEANSTACK without P2SH, 2435–2436; a word without FORKID drops the signature from the script code as the original digest does, CleanupScriptCode 255–263; docs/PARAMETERS.md section 2) |
| `engine.word-out-of-scope` | MECHANISM | open | `cpp-lrshiftnum` · `spec` | 23 | `witness-cpp-lrshiftnum-spec-engine.word-out-of-scope-cpp-lrshiftnum-00001` | bsv-rs 0.3.33 flags.rs:500–519 (ScriptFlags::check: a word without SIGHASH_FORKID, GENESIS or UTXO_AFTER_GENESIS, or with CHRONICLE without GENESIS, is ScriptFlagsError::NotApplicable, the crate's own scope: "pre-Genesis block rules are not implemented by this interpreter"), reported by Spend::validate as an evaluation error, spend.rs:523–529 ("Invalid verification flags: ...", bsvrs_codes.rs's SCRIPT_ERR_INVALID_FLAGS row; 0.3.30's flags.rs:493-512 and spend.rs:499-505 until the cpp column was re-recorded at 0.3.32); the reference evaluates such a word (valid_flags refuses only UTXO_AFTER_CHRONICLE without UTXO_AFTER_GENESIS, interpreter.cpp:2259–2262, 2312–2313, and CLEANSTACK without P2SH, 2435–2436; a word without FORKID drops the signature from the script code as the original digest does, CleanupScriptCode 255–263; docs/PARAMETERS.md section 2) |
| `engine.word-out-of-scope` | MECHANISM | open | `cpp-multisig` · `spec` | 6 | `witness-cpp-multisig-spec-engine.word-out-of-scope-cpp-multisig-00011` | bsv-rs 0.3.33 flags.rs:500–519 (ScriptFlags::check: a word without SIGHASH_FORKID, GENESIS or UTXO_AFTER_GENESIS, or with CHRONICLE without GENESIS, is ScriptFlagsError::NotApplicable, the crate's own scope: "pre-Genesis block rules are not implemented by this interpreter"), reported by Spend::validate as an evaluation error, spend.rs:523–529 ("Invalid verification flags: ...", bsvrs_codes.rs's SCRIPT_ERR_INVALID_FLAGS row; 0.3.30's flags.rs:493-512 and spend.rs:499-505 until the cpp column was re-recorded at 0.3.32); the reference evaluates such a word (valid_flags refuses only UTXO_AFTER_CHRONICLE without UTXO_AFTER_GENESIS, interpreter.cpp:2259–2262, 2312–2313, and CLEANSTACK without P2SH, 2435–2436; a word without FORKID drops the signature from the script code as the original digest does, CleanupScriptCode 255–263; docs/PARAMETERS.md section 2) |
| `engine.word-out-of-scope` | MECHANISM | open | `cpp-opcode` · `spec` | 77263 | `witness-cpp-opcode-spec-engine.word-out-of-scope-cpp-opcode-144216` | bsv-rs 0.3.33 flags.rs:500–519 (ScriptFlags::check: a word without SIGHASH_FORKID, GENESIS or UTXO_AFTER_GENESIS, or with CHRONICLE without GENESIS, is ScriptFlagsError::NotApplicable, the crate's own scope: "pre-Genesis block rules are not implemented by this interpreter"), reported by Spend::validate as an evaluation error, spend.rs:523–529 ("Invalid verification flags: ...", bsvrs_codes.rs's SCRIPT_ERR_INVALID_FLAGS row; 0.3.30's flags.rs:493-512 and spend.rs:499-505 until the cpp column was re-recorded at 0.3.32); the reference evaluates such a word (valid_flags refuses only UTXO_AFTER_CHRONICLE without UTXO_AFTER_GENESIS, interpreter.cpp:2259–2262, 2312–2313, and CLEANSTACK without P2SH, 2435–2436; a word without FORKID drops the signature from the script code as the original digest does, CleanupScriptCode 255–263; docs/PARAMETERS.md section 2) |
| `engine.word-out-of-scope` | MECHANISM | open | `cpp-script` · `spec` | 67634 | `witness-cpp-script-spec-engine.word-out-of-scope-cpp-script-00128` | bsv-rs 0.3.33 flags.rs:500–519 (ScriptFlags::check: a word without SIGHASH_FORKID, GENESIS or UTXO_AFTER_GENESIS, or with CHRONICLE without GENESIS, is ScriptFlagsError::NotApplicable, the crate's own scope: "pre-Genesis block rules are not implemented by this interpreter"), reported by Spend::validate as an evaluation error, spend.rs:523–529 ("Invalid verification flags: ...", bsvrs_codes.rs's SCRIPT_ERR_INVALID_FLAGS row; 0.3.30's flags.rs:493-512 and spend.rs:499-505 until the cpp column was re-recorded at 0.3.32); the reference evaluates such a word (valid_flags refuses only UTXO_AFTER_CHRONICLE without UTXO_AFTER_GENESIS, interpreter.cpp:2259–2262, 2312–2313, and CLEANSTACK without P2SH, 2435–2436; a word without FORKID drops the signature from the script code as the original digest does, CleanupScriptCode 255–263; docs/PARAMETERS.md section 2) |
| `engine.word-out-of-scope` | MECHANISM | open | `cpp-script_P2SH` · `spec` | 8 | `witness-cpp-script_P2SH-spec-engine.word-out-of-scope-cpp-script_P2SH-00063` | bsv-rs 0.3.33 flags.rs:500–519 (ScriptFlags::check: a word without SIGHASH_FORKID, GENESIS or UTXO_AFTER_GENESIS, or with CHRONICLE without GENESIS, is ScriptFlagsError::NotApplicable, the crate's own scope: "pre-Genesis block rules are not implemented by this interpreter"), reported by Spend::validate as an evaluation error, spend.rs:523–529 ("Invalid verification flags: ...", bsvrs_codes.rs's SCRIPT_ERR_INVALID_FLAGS row; 0.3.30's flags.rs:493-512 and spend.rs:499-505 until the cpp column was re-recorded at 0.3.32); the reference evaluates such a word (valid_flags refuses only UTXO_AFTER_CHRONICLE without UTXO_AFTER_GENESIS, interpreter.cpp:2259–2262, 2312–2313, and CLEANSTACK without P2SH, 2435–2436; a word without FORKID drops the signature from the script code as the original digest does, CleanupScriptCode 255–263; docs/PARAMETERS.md section 2) |
| `engine.word-out-of-scope` | MECHANISM | open | `cpp-transaction` · `spec` | 59 | `witness-cpp-transaction-spec-engine.word-out-of-scope-cpp-transaction-00044` | bsv-rs 0.3.33 flags.rs:500–519 (ScriptFlags::check: a word without SIGHASH_FORKID, GENESIS or UTXO_AFTER_GENESIS, or with CHRONICLE without GENESIS, is ScriptFlagsError::NotApplicable, the crate's own scope: "pre-Genesis block rules are not implemented by this interpreter"), reported by Spend::validate as an evaluation error, spend.rs:523–529 ("Invalid verification flags: ...", bsvrs_codes.rs's SCRIPT_ERR_INVALID_FLAGS row; 0.3.30's flags.rs:493-512 and spend.rs:499-505 until the cpp column was re-recorded at 0.3.32); the reference evaluates such a word (valid_flags refuses only UTXO_AFTER_CHRONICLE without UTXO_AFTER_GENESIS, interpreter.cpp:2259–2262, 2312–2313, and CLEANSTACK without P2SH, 2435–2436; a word without FORKID drops the signature from the script code as the original digest does, CleanupScriptCode 255–263; docs/PARAMETERS.md section 2) |
| `engine.word-out-of-scope` | MECHANISM | open | `cpp-txvalidationcache-t100-g102-c102` · `spec` | 2048 | `witness-cpp-txvalidationcache-t100-g102-c102-spec-engine.word-out-of-scope-cpp-txvalidationcache-00005` | bsv-rs 0.3.33 flags.rs:500–519 (ScriptFlags::check: a word without SIGHASH_FORKID, GENESIS or UTXO_AFTER_GENESIS, or with CHRONICLE without GENESIS, is ScriptFlagsError::NotApplicable, the crate's own scope: "pre-Genesis block rules are not implemented by this interpreter"), reported by Spend::validate as an evaluation error, spend.rs:523–529 ("Invalid verification flags: ...", bsvrs_codes.rs's SCRIPT_ERR_INVALID_FLAGS row; 0.3.30's flags.rs:493-512 and spend.rs:499-505 until the cpp column was re-recorded at 0.3.32); the reference evaluates such a word (valid_flags refuses only UTXO_AFTER_CHRONICLE without UTXO_AFTER_GENESIS, interpreter.cpp:2259–2262, 2312–2313, and CLEANSTACK without P2SH, 2435–2436; a word without FORKID drops the signature from the script code as the original digest does, CleanupScriptCode 255–263; docs/PARAMETERS.md section 2) |
| `engine.word-out-of-scope` | MECHANISM | open | `cpp-txvalidationcache-t101-g102-c1` · `spec` | 2 | `witness-cpp-txvalidationcache-t101-g102-c1-spec-engine.word-out-of-scope-cpp-txvalidationcache-172037` | bsv-rs 0.3.33 flags.rs:500–519 (ScriptFlags::check: a word without SIGHASH_FORKID, GENESIS or UTXO_AFTER_GENESIS, or with CHRONICLE without GENESIS, is ScriptFlagsError::NotApplicable, the crate's own scope: "pre-Genesis block rules are not implemented by this interpreter"), reported by Spend::validate as an evaluation error, spend.rs:523–529 ("Invalid verification flags: ...", bsvrs_codes.rs's SCRIPT_ERR_INVALID_FLAGS row; 0.3.30's flags.rs:493-512 and spend.rs:499-505 until the cpp column was re-recorded at 0.3.32); the reference evaluates such a word (valid_flags refuses only UTXO_AFTER_CHRONICLE without UTXO_AFTER_GENESIS, interpreter.cpp:2259–2262, 2312–2313, and CLEANSTACK without P2SH, 2435–2436; a word without FORKID drops the signature from the script code as the original digest does, CleanupScriptCode 255–263; docs/PARAMETERS.md section 2) |
| `engine.word-out-of-scope` | MECHANISM | open | `cpp-txvalidationcache-t101-g103-c103` · `spec` | 6144 | `witness-cpp-txvalidationcache-t101-g103-c103-spec-engine.word-out-of-scope-cpp-txvalidationcache-114693` | bsv-rs 0.3.33 flags.rs:500–519 (ScriptFlags::check: a word without SIGHASH_FORKID, GENESIS or UTXO_AFTER_GENESIS, or with CHRONICLE without GENESIS, is ScriptFlagsError::NotApplicable, the crate's own scope: "pre-Genesis block rules are not implemented by this interpreter"), reported by Spend::validate as an evaluation error, spend.rs:523–529 ("Invalid verification flags: ...", bsvrs_codes.rs's SCRIPT_ERR_INVALID_FLAGS row; 0.3.30's flags.rs:493-512 and spend.rs:499-505 until the cpp column was re-recorded at 0.3.32); the reference evaluates such a word (valid_flags refuses only UTXO_AFTER_CHRONICLE without UTXO_AFTER_GENESIS, interpreter.cpp:2259–2262, 2312–2313, and CLEANSTACK without P2SH, 2435–2436; a word without FORKID drops the signature from the script code as the original digest does, CleanupScriptCode 255–263; docs/PARAMETERS.md section 2) |

### go-sdk (9 class rows)

Exported `harness/rules/go-sdk.json`: [M] 27 class definitions, [M] 19 classifier rows; [M] 1 class definitions and [M] 1 classifier rows withheld by the rule policy.

| class | kind | ruling | corpus · column | entries | smallest witness (replay: `tools/witness.sh <id>`) | decided by |
|---|---|---|---|---|---|---|
| `limits.maxscriptnumlength.policy` | OPEN | open | `cpp-lrshiftnum` · `spec-mempool` | 1 | `witness-go-sdk-cpp-lrshiftnum-spec-mempool-limits.maxscriptnumlength.policy-cpp-lrshiftnum-00018` | [SRC] go-sdk@v1.7.2 (2ca481c5931b987a0c8f48bb341c70b7477b6b07) script/interpreter/config.go:22–31,96–102,132–134 (era widths 4, 750,000 and 32,000,000, without a separate policy width); CHANGELOG.md:86 (32,000,000-byte constant); harness/engines/go/main.go:164–167 (explicit WithFlags). The spec at bitcoin-sv v1.2.3 (6504a3af), spec/flags.md:121–151 and docs/PARAMETERS.md:37, cites configscriptpolicy.cpp:79–110 and policy.h:156: the configured policy width defaults to 10,000 bytes, while the block path uses the era width. This class requires a valid spec block verdict and an invalid policy verdict with the width error; it makes no consensus-divergence claim. |
| `limits.maxscriptnumlength.policy` | OPEN | open | `eras` · `spec-mempool` | 1 | `witness-go-sdk-eras-spec-mempool-limits.maxscriptnumlength.policy-eras-00042` | [SRC] go-sdk@v1.7.2 (2ca481c5931b987a0c8f48bb341c70b7477b6b07) script/interpreter/config.go:22–31,96–102,132–134 (era widths 4, 750,000 and 32,000,000, without a separate policy width); CHANGELOG.md:86 (32,000,000-byte constant); harness/engines/go/main.go:164–167 (explicit WithFlags). The spec at bitcoin-sv v1.2.3 (6504a3af), spec/flags.md:121–151 and docs/PARAMETERS.md:37, cites configscriptpolicy.cpp:79–110 and policy.h:156: the configured policy width defaults to 10,000 bytes, while the block path uses the era width. This class requires a valid spec block verdict and an invalid policy verdict with the width error; it makes no consensus-divergence claim. |
| `limits.maxscriptnumlength.policy` | OPEN | open | `gen` · `spec-mempool` | 9 | `witness-go-sdk-gen-spec-mempool-limits.maxscriptnumlength.policy-gen-00004` | [SRC] go-sdk@v1.7.2 (2ca481c5931b987a0c8f48bb341c70b7477b6b07) script/interpreter/config.go:22–31,96–102,132–134 (era widths 4, 750,000 and 32,000,000, without a separate policy width); CHANGELOG.md:86 (32,000,000-byte constant); harness/engines/go/main.go:164–167 (explicit WithFlags). The spec at bitcoin-sv v1.2.3 (6504a3af), spec/flags.md:121–151 and docs/PARAMETERS.md:37, cites configscriptpolicy.cpp:79–110 and policy.h:156: the configured policy width defaults to 10,000 bytes, while the block path uses the era width. This class requires a valid spec block verdict and an invalid policy verdict with the width error; it makes no consensus-divergence claim. |
| `limits.maxscriptnumlength.policy` | OPEN | open | `road` · `spec-mempool` | 6 | `witness-go-sdk-road-spec-mempool-limits.maxscriptnumlength.policy-road-eras-00042` | [SRC] go-sdk@v1.7.2 (2ca481c5931b987a0c8f48bb341c70b7477b6b07) script/interpreter/config.go:22–31,96–102,132–134 (era widths 4, 750,000 and 32,000,000, without a separate policy width); CHANGELOG.md:86 (32,000,000-byte constant); harness/engines/go/main.go:164–167 (explicit WithFlags). The spec at bitcoin-sv v1.2.3 (6504a3af), spec/flags.md:121–151 and docs/PARAMETERS.md:37, cites configscriptpolicy.cpp:79–110 and policy.h:156: the configured policy width defaults to 10,000 bytes, while the block path uses the era width. This class requires a valid spec block verdict and an invalid policy verdict with the width error; it makes no consensus-divergence claim. |
| `limits.stackmemory.policy-default` | OPEN | open | `million` · `spec` | 1 | `witness-go-sdk-million-spec-limits.stackmemory.policy-default-million-seed-352758` | [SRC] go-sdk@v1.7.2 (2ca481c5931b987a0c8f48bb341c70b7477b6b07) script/interpreter/config.go:34–40, script/interpreter/thread.go:482–490, script/interpreter/options.go:176–194, script/interpreter/operations.go:1071–1079, script/interpreter/stack.go:35–63; CHANGELOG.md:70,90 (new stack accounting and the 100,000,000-byte default, configurable with WithMaxStackMemory). The spec at bitcoin-sv v1.2.3 (6504a3af), spec/opcodes/OP_NUM2BIN.md:11–24 and spec/flags.md:136–151, cites interpreter.cpp:1741–1778 and configscriptpolicy.cpp:139–154,280–283: padding is charged against the configured budget, whose block zero setting means INT64_MAX. |

**go-sdk: the preserved historical redaction rows.** The following counts belong to the previous page; the current classified totals are in §1.

| class | kind | ruling | corpus · column | historical entries | smallest witness | decided by |
|---|---|---|---|---|---|---|
| (a class under a still-private advisory: withheld, D135) | IMPLEMENTATION-WRONG | impl-wrong | `arith` · `spec-mempool` | 8 | (withheld until the advisory publishes) | (withheld) |
| (a class under a still-private advisory: withheld, D135) | IMPLEMENTATION-WRONG | impl-wrong | `bytes` · `spec-mempool` | 149 | (withheld until the advisory publishes) | (withheld) |
| (a class under a still-private advisory: withheld, D135) | IMPLEMENTATION-WRONG | impl-wrong | `crypto` · `spec` | 6 | (withheld until the advisory publishes) | (withheld) |
| (a class under a still-private advisory: withheld, D135) | IMPLEMENTATION-WRONG | impl-wrong | `crypto` · `spec-mempool` | 9 | (withheld until the advisory publishes) | (withheld) |
| (a class under a still-private advisory: withheld, D135) | IMPLEMENTATION-WRONG | impl-wrong | `eras` · `spec` | 2 | (withheld until the advisory publishes) | (withheld) |
| (a class under a still-private advisory: withheld, D135) | IMPLEMENTATION-WRONG | impl-wrong | `eras` · `spec-mempool` | 4 | (withheld until the advisory publishes) | (withheld) |
| (a class under a still-private advisory: withheld, D135) | IMPLEMENTATION-WRONG | impl-wrong | `flow` · `spec` | 5 | (withheld until the advisory publishes) | (withheld) |
| (a class under a still-private advisory: withheld, D135) | IMPLEMENTATION-WRONG | impl-wrong | `flow` · `spec-mempool` | 302 | (withheld until the advisory publishes) | (withheld) |
| (a class under a still-private advisory: withheld, D135) | IMPLEMENTATION-WRONG | impl-wrong | `gen` · `spec-mempool` | 17 | (withheld until the advisory publishes) | (withheld) |
| (a class under a still-private advisory: withheld, D135) | IMPLEMENTATION-WRONG | impl-wrong | `seed` · `spec` | 12 | (withheld until the advisory publishes) | (withheld) |
| (a class under a still-private advisory: withheld, D135) | IMPLEMENTATION-WRONG | impl-wrong | `seed` · `spec-mempool` | 990 | (withheld until the advisory publishes) | (withheld) |
| (a class under a still-private advisory: withheld, D135) | IMPLEMENTATION-WRONG | impl-wrong | `stack` · `spec-mempool` | 4 | (withheld until the advisory publishes) | (withheld) |
| (a class under a still-private advisory: withheld, D135) | IMPLEMENTATION-WRONG | impl-wrong | `gen` · `spec` | 2 | (withheld until the advisory publishes) | (withheld) |
| (a class under a still-private advisory: withheld, D135) | IMPLEMENTATION-WRONG | impl-wrong | `gen` · `spec-mempool` | 1 | (withheld until the advisory publishes) | (withheld) |
| (a class under a still-private advisory: withheld, D135) | IMPLEMENTATION-WRONG | impl-wrong | `gen` · `spec` | 1 | (withheld until the advisory publishes) | (withheld) |
| (a class under a still-private advisory: withheld, D135) | IMPLEMENTATION-WRONG | impl-wrong | `eras` · `spec` | 1 | (withheld until the advisory publishes) | (withheld) |
| (a class under a still-private advisory: withheld, D135) | IMPLEMENTATION-WRONG | impl-wrong | `gen` · `spec` | 1 | (withheld until the advisory publishes) | (withheld) |
| (a class under a still-private advisory: withheld, D135) | IMPLEMENTATION-WRONG | impl-wrong | `gen` · `spec-mempool` | 3 | (withheld until the advisory publishes) | (withheld) |
| (a class under a still-private advisory: withheld, D135) | IMPLEMENTATION-WRONG | impl-wrong | `gen` · `spec` | 6 | (withheld until the advisory publishes) | (withheld) |
| (a class under a still-private advisory: withheld, D135) | IMPLEMENTATION-WRONG | impl-wrong | `gen` · `spec-mempool` | 6 | (withheld until the advisory publishes) | (withheld) |
| (a class under a still-private advisory: withheld, D135) | IMPLEMENTATION-WRONG | impl-wrong | `eras` · `spec` | 1 | (withheld until the advisory publishes) | (withheld) |
| (a class under a still-private advisory: withheld, D135) | IMPLEMENTATION-WRONG | impl-wrong | `eras` · `spec-mempool` | 1 | (withheld until the advisory publishes) | (withheld) |
| (a class under a still-private advisory: withheld, D135) | IMPLEMENTATION-WRONG | impl-wrong | `gen` · `spec` | 1 | (withheld until the advisory publishes) | (withheld) |
| (a class under a still-private advisory: withheld, D135) | IMPLEMENTATION-WRONG | impl-wrong | `gen` · `spec-mempool` | 1 | (withheld until the advisory publishes) | (withheld) |
| (a class under a still-private advisory: withheld, D135) | IMPLEMENTATION-WRONG | impl-wrong | `gen` · `spec` | 57 | (withheld until the advisory publishes) | (withheld) |
| (a class under a still-private advisory: withheld, D135) | IMPLEMENTATION-WRONG | impl-wrong | `gen` · `spec-mempool` | 47 | (withheld until the advisory publishes) | (withheld) |

### ts-sdk (44 class rows)

| class | kind | ruling | corpus · column | entries | smallest witness (replay: `tools/witness.sh <id>`) | decided by |
|---|---|---|---|---|---|---|
| `bitwise.shift.bigint-limit` | IMPLEMENTATION-WRONG | impl-wrong | `gen` · `default/spec` | 2 | `witness-ts-sdk-gen-default-spec-bitwise.shift.bigint-limit-gen-00813` | [SRC] bitcoin-sv v1.2.2 interpreter.cpp:692–764; script_num.cpp:303–317 at v1.2.3 (the numeric shift result width); [SRC] @bsv/sdk 3.0.0 Spend.ts:1048–1093 (numeric shifts, BigInt result at 1066), 1438–1469 (byte shifts preserve the input width). |
| `bitwise.shift.bigint-limit` | IMPLEMENTATION-WRONG | impl-wrong | `gen` · `default/spec-mempool` | 2 | `witness-ts-sdk-gen-default-spec-mempool-bitwise.shift.bigint-limit-gen-00813` | [SRC] bitcoin-sv v1.2.2 interpreter.cpp:692–764; script_num.cpp:303–317 at v1.2.3 (the numeric shift result width); [SRC] @bsv/sdk 3.0.0 Spend.ts:1048–1093 (numeric shifts, BigInt result at 1066), 1438–1469 (byte shifts preserve the input width). |
| `flags.version-gate.nullfail` | IMPLEMENTATION-WRONG | impl-wrong | `crypto` · `default/spec` | 2 | `witness-ts-sdk-crypto-default-spec-flags.version-gate.nullfail-crypto-00054` | [SRC] bitcoin-sv v1.2.2 interpreter.cpp:1491–1497,1641–1647; standard.h:62–68; @bsv/sdk 3.0.0 Spend.ts:1710–1715,1844–1849 (NULLFAIL requires an explicit flag name and the version gate); Spend.ts:327–329 (the default mode has no flag names). |
| `flags.version-gate.nullfail` | IMPLEMENTATION-WRONG | impl-wrong | `crypto` · `default/spec-mempool` | 2 | `witness-ts-sdk-crypto-default-spec-mempool-flags.version-gate.nullfail-crypto-00054` | [SRC] bitcoin-sv v1.2.2 interpreter.cpp:1491–1497,1641–1647; standard.h:62–68; @bsv/sdk 3.0.0 Spend.ts:1710–1715,1844–1849 (NULLFAIL requires an explicit flag name and the version gate); Spend.ts:327–329 (the default mode has no flag names). |
| `flags.version-gate.nullfail` | IMPLEMENTATION-WRONG | impl-wrong | `eras` · `default/spec` | 1 | `witness-ts-sdk-eras-default-spec-flags.version-gate.nullfail-eras-00062` | [SRC] bitcoin-sv v1.2.2 interpreter.cpp:1491–1497,1641–1647; standard.h:62–68; @bsv/sdk 3.0.0 Spend.ts:1710–1715,1844–1849 (NULLFAIL requires an explicit flag name and the version gate); Spend.ts:327–329 (the default mode has no flag names). |
| `flags.version-gate.nullfail` | IMPLEMENTATION-WRONG | impl-wrong | `eras` · `default/spec-mempool` | 1 | `witness-ts-sdk-eras-default-spec-mempool-flags.version-gate.nullfail-eras-00062` | [SRC] bitcoin-sv v1.2.2 interpreter.cpp:1491–1497,1641–1647; standard.h:62–68; @bsv/sdk 3.0.0 Spend.ts:1710–1715,1844–1849 (NULLFAIL requires an explicit flag name and the version gate); Spend.ts:327–329 (the default mode has no flag names). |
| `flow.else` | IMPLEMENTATION-WRONG | impl-wrong | `flow` · `default/spec` | 1 | `witness-ts-sdk-flow-default-spec-flow.else-flow-01077` | [SRC] bitcoin-sv v1.2.2 interpreter.cpp:829–831; conditional_tracker.cpp:51–55; @bsv/sdk 3.0.0 Spend.ts:1191–1202 (the single-ELSE test requires explicit flags and a post-Genesis coin; the default mode toggles again). |
| `flow.else` | IMPLEMENTATION-WRONG | impl-wrong | `flow` · `default/spec-mempool` | 1 | `witness-ts-sdk-flow-default-spec-mempool-flow.else-flow-01077` | [SRC] bitcoin-sv v1.2.2 interpreter.cpp:829–831; conditional_tracker.cpp:51–55; @bsv/sdk 3.0.0 Spend.ts:1191–1202 (the single-ELSE test requires explicit flags and a post-Genesis coin; the default mode toggles again). |
| `limits.maxscriptnumlength` | IMPLEMENTATION-WRONG | impl-wrong | `gen` · `default/spec` | 22 | `witness-ts-sdk-gen-default-spec-limits.maxscriptnumlength-gen-00002` | [SRC] bitcoin-sv v1.2.2 script_num.cpp:62; interpreter.cpp:1789–1790, 1807–1810; configscriptpolicy.cpp:79–110; consensus.h:62–66; [SRC] @bsv/sdk 3.0.0 Spend.ts:395–403 (explicit numeric reads: 4, 750000, 32000000 bytes; default unlimited), 1989–1997 (OP_BIN2NUM omits the size argument), 107–111 (helper default Number.MAX_SAFE_INTEGER). |
| `limits.maxscriptnumlength` | IMPLEMENTATION-WRONG | impl-wrong | `gen` · `default/spec-mempool` | 22 | `witness-ts-sdk-gen-default-spec-mempool-limits.maxscriptnumlength-gen-00002` | [SRC] bitcoin-sv v1.2.2 script_num.cpp:62; interpreter.cpp:1789–1790, 1807–1810; configscriptpolicy.cpp:79–110; consensus.h:62–66; [SRC] @bsv/sdk 3.0.0 Spend.ts:395–403 (explicit numeric reads: 4, 750000, 32000000 bytes; default unlimited), 1989–1997 (OP_BIN2NUM omits the size argument), 107–111 (helper default Number.MAX_SAFE_INTEGER). |
| `limits.maxscriptnumlength` | IMPLEMENTATION-WRONG | impl-wrong | `gen` · `spec` | 17 | `witness-ts-sdk-gen-spec-limits.maxscriptnumlength-gen-00011` | [SRC] bitcoin-sv v1.2.2 script_num.cpp:62; interpreter.cpp:1789–1790, 1807–1810; configscriptpolicy.cpp:79–110; consensus.h:62–66; [SRC] @bsv/sdk 3.0.0 Spend.ts:395–403 (explicit numeric reads: 4, 750000, 32000000 bytes; default unlimited), 1989–1997 (OP_BIN2NUM omits the size argument), 107–111 (helper default Number.MAX_SAFE_INTEGER). |
| `limits.maxscriptnumlength` | IMPLEMENTATION-WRONG | impl-wrong | `gen` · `spec-mempool` | 17 | `witness-ts-sdk-gen-spec-mempool-limits.maxscriptnumlength-gen-00011` | [SRC] bitcoin-sv v1.2.2 script_num.cpp:62; interpreter.cpp:1789–1790, 1807–1810; configscriptpolicy.cpp:79–110; consensus.h:62–66; [SRC] @bsv/sdk 3.0.0 Spend.ts:395–403 (explicit numeric reads: 4, 750000, 32000000 bytes; default unlimited), 1989–1997 (OP_BIN2NUM omits the size argument), 107–111 (helper default Number.MAX_SAFE_INTEGER). |
| `sighash.default-mode.forkid-not-required` | IMPLEMENTATION-WRONG | impl-wrong | `gen` · `default/spec` | 1 | `witness-ts-sdk-gen-default-spec-sighash.default-mode.forkid-not-required-gen-00972` | [SRC] bitcoin-sv v1.2.2 interpreter.cpp:304–306; verify_script_flags.cpp:56–58; [SRC] @bsv/sdk 3.0.0 Spend.ts:595–603 (the default mode returns before enforcing FORKID). |
| `sighash.default-mode.forkid-not-required` | IMPLEMENTATION-WRONG | impl-wrong | `gen` · `default/spec-mempool` | 1 | `witness-ts-sdk-gen-default-spec-mempool-sighash.default-mode.forkid-not-required-gen-00972` | [SRC] bitcoin-sv v1.2.2 interpreter.cpp:304–306; verify_script_flags.cpp:56–58; [SRC] @bsv/sdk 3.0.0 Spend.ts:595–603 (the default mode returns before enforcing FORKID). |
| `splice.substr.int64-reader.first-8-bytes` | IMPLEMENTATION-WRONG | impl-wrong | `gen` · `default/spec` | 1 | `witness-ts-sdk-gen-default-spec-splice.substr.int64-reader.first-8-bytes-WITHHELD: d9-gosdk-172-splice (see corpus/INDEX.md)` | The reading of record at v1.2.3 is a defined refusal ([SRC] `int_serialization.h:61–118`, `script_num.cpp:80–91` at `6504a3af`); the previous pin's reading and its measurements are recorded in material withheld from the public edition at the maintainers' request (group `d8-node-team-discretion`). [SRC] @bsv/sdk 3.0.0 `Spend.ts:539–562` reads the lower eight bytes above that width, uses BigInt.asIntN(64), and clamps. |
| `splice.substr.int64-reader.first-8-bytes` | IMPLEMENTATION-WRONG | impl-wrong | `gen` · `default/spec-mempool` | 1 | `witness-ts-sdk-gen-default-spec-mempool-splice.substr.int64-reader.first-8-bytes-WITHHELD: d9-gosdk-172-splice (see corpus/INDEX.md)` | The reading of record at v1.2.3 is a defined refusal ([SRC] `int_serialization.h:61–118`, `script_num.cpp:80–91` at `6504a3af`); the previous pin's reading and its measurements are recorded in material withheld from the public edition at the maintainers' request (group `d8-node-team-discretion`). [SRC] @bsv/sdk 3.0.0 `Spend.ts:539–562` reads the lower eight bytes above that width, uses BigInt.asIntN(64), and clamps. |
| `splice.substr.int64-reader.first-8-bytes` | IMPLEMENTATION-WRONG | impl-wrong | `gen` · `spec` | 1 | `witness-ts-sdk-gen-spec-splice.substr.int64-reader.first-8-bytes-WITHHELD: d9-gosdk-172-splice (see corpus/INDEX.md)` | The reading of record at v1.2.3 is a defined refusal ([SRC] `int_serialization.h:61–118`, `script_num.cpp:80–91` at `6504a3af`); the previous pin's reading and its measurements are recorded in material withheld from the public edition at the maintainers' request (group `d8-node-team-discretion`). [SRC] @bsv/sdk 3.0.0 `Spend.ts:539–562` reads the lower eight bytes above that width, uses BigInt.asIntN(64), and clamps. |
| `splice.substr.int64-reader.first-8-bytes` | IMPLEMENTATION-WRONG | impl-wrong | `gen` · `spec-mempool` | 1 | `witness-ts-sdk-gen-spec-mempool-splice.substr.int64-reader.first-8-bytes-WITHHELD: d9-gosdk-172-splice (see corpus/INDEX.md)` | The reading of record at v1.2.3 is a defined refusal ([SRC] `int_serialization.h:61–118`, `script_num.cpp:80–91` at `6504a3af`); the previous pin's reading and its measurements are recorded in material withheld from the public edition at the maintainers' request (group `d8-node-team-discretion`). [SRC] @bsv/sdk 3.0.0 `Spend.ts:539–562` reads the lower eight bytes above that width, uses BigInt.asIntN(64), and clamps. |
| `engine.decode-refusal` | MECHANISM | impl-wrong | `tx` · `default/spec` | 1 | `witness-ts-sdk-tx-default-spec-engine.decode-refusal-tx-00026` | [SRC] @bsv/sdk 3.0.0 Transaction.ts:548–553 (fromHex), 497 (every output amount through readUInt64LEBn().toNumber()), BigNumber.ts:625–629 (toNumber throws above 2^53: 'Number can only safely store up to 53 bits'); [SRC] bitcoin-sv v1.2.2 validation.cpp:543–546 (the reference decodes the amount as an int64 and decides the transaction at its own checks); D15 (docs/DESIGN.md §2.1). |
| `engine.decode-refusal` | MECHANISM | impl-wrong | `tx` · `default/spec-mempool` | 1 | `witness-ts-sdk-tx-default-spec-mempool-engine.decode-refusal-tx-00026` | [SRC] @bsv/sdk 3.0.0 Transaction.ts:548–553 (fromHex), 497 (every output amount through readUInt64LEBn().toNumber()), BigNumber.ts:625–629 (toNumber throws above 2^53: 'Number can only safely store up to 53 bits'); [SRC] bitcoin-sv v1.2.2 validation.cpp:543–546 (the reference decodes the amount as an int64 and decides the transaction at its own checks); D15 (docs/DESIGN.md §2.1). |
| `engine.decode-refusal` | MECHANISM | impl-wrong | `tx` · `spec` | 1 | `witness-ts-sdk-tx-spec-engine.decode-refusal-tx-00026` | [SRC] @bsv/sdk 3.0.0 Transaction.ts:548–553 (fromHex), 497 (every output amount through readUInt64LEBn().toNumber()), BigNumber.ts:625–629 (toNumber throws above 2^53: 'Number can only safely store up to 53 bits'); [SRC] bitcoin-sv v1.2.2 validation.cpp:543–546 (the reference decodes the amount as an int64 and decides the transaction at its own checks); D15 (docs/DESIGN.md §2.1). |
| `engine.decode-refusal` | MECHANISM | impl-wrong | `tx` · `spec-mempool` | 1 | `witness-ts-sdk-tx-spec-mempool-engine.decode-refusal-tx-00026` | [SRC] @bsv/sdk 3.0.0 Transaction.ts:548–553 (fromHex), 497 (every output amount through readUInt64LEBn().toNumber()), BigNumber.ts:625–629 (toNumber throws above 2^53: 'Number can only safely store up to 53 bits'); [SRC] bitcoin-sv v1.2.2 validation.cpp:543–546 (the reference decodes the amount as an int64 and decides the transaction at its own checks); D15 (docs/DESIGN.md §2.1). |
| `eras.default-mode.no-era` | OPEN | open | `eras` · `default/spec` | 34 | `witness-ts-sdk-eras-default-spec-eras.default-mode.no-era-eras-00001` | [SRC] @bsv/sdk 3.0.0 Spend.ts:319–321, 331–341 (without explicit flags, the eras follow the transaction version); [SRC] bitcoin-sv v1.2.2 policy.h:226–245, verify_script_flags.cpp:32–81 (coin and spend heights). |
| `eras.default-mode.no-era` | OPEN | open | `eras` · `default/spec-mempool` | 34 | `witness-ts-sdk-eras-default-spec-mempool-eras.default-mode.no-era-eras-00001` | [SRC] @bsv/sdk 3.0.0 Spend.ts:319–321, 331–341 (without explicit flags, the eras follow the transaction version); [SRC] bitcoin-sv v1.2.2 policy.h:226–245, verify_script_flags.cpp:32–81 (coin and spend heights). |
| `eras.default-mode.no-era` | OPEN | open | `gen` · `default/spec` | 53 | `witness-ts-sdk-gen-default-spec-eras.default-mode.no-era-gen-00756` | [SRC] @bsv/sdk 3.0.0 Spend.ts:319–321, 331–341 (without explicit flags, the eras follow the transaction version); [SRC] bitcoin-sv v1.2.2 policy.h:226–245, verify_script_flags.cpp:32–81 (coin and spend heights). |
| `eras.default-mode.no-era` | OPEN | open | `gen` · `default/spec-mempool` | 1 | `witness-ts-sdk-gen-default-spec-mempool-eras.default-mode.no-era-gen-00973` | [SRC] @bsv/sdk 3.0.0 Spend.ts:319–321, 331–341 (without explicit flags, the eras follow the transaction version); [SRC] bitcoin-sv v1.2.2 policy.h:226–245, verify_script_flags.cpp:32–81 (coin and spend heights). |
| `flags.default-mode.policy-only` | OPEN | open | `eras` · `default/spec-mempool` | 1 | `witness-ts-sdk-eras-default-spec-mempool-flags.default-mode.policy-only-eras-00061` | [SRC] bitcoin-sv v1.2.2 verify_script_flags.cpp:32–81 (the block word by the spend height: SIGHASH_FORKID from the UAHF, 56–58), policy.h:178–190 and standard.h:62–68 (the relay word's standard flags at every height); interpreter.cpp:304–306, 1491–1497, 1641–1647 (MUST_USE_FORKID, NULLFAIL); [SRC] @bsv/sdk 3.0.0 Spend.ts:595–603, 1710–1715, 1844–1849 (FORKID and NULLFAIL only under explicit flag names), 327–329 (no flag names in the default mode). |
| `flags.default-mode.policy-only` | OPEN | open | `gen` · `default/spec-mempool` | 2 | `witness-ts-sdk-gen-default-spec-mempool-flags.default-mode.policy-only-gen-00996` | [SRC] bitcoin-sv v1.2.2 verify_script_flags.cpp:32–81 (the block word by the spend height: SIGHASH_FORKID from the UAHF, 56–58), policy.h:178–190 and standard.h:62–68 (the relay word's standard flags at every height); interpreter.cpp:304–306, 1491–1497, 1641–1647 (MUST_USE_FORKID, NULLFAIL); [SRC] @bsv/sdk 3.0.0 Spend.ts:595–603, 1710–1715, 1844–1849 (FORKID and NULLFAIL only under explicit flag names), 327–329 (no flag names in the default mode). |
| `flags.discourage-upgradable-nops` | OPEN | open | `bytes` · `default/spec-mempool` | 5 | `witness-ts-sdk-bytes-default-spec-mempool-flags.discourage-upgradable-nops-bytes-00177` | [SRC] bitcoin-sv v1.2.2 policy.h:186 (policy flag); interpreter.cpp:765–771; [SRC] @bsv/sdk 3.0.0 Spend.ts:839, 887 (DISCOURAGE_UPGRADABLE_NOPS). |
| `flags.discourage-upgradable-nops` | OPEN | open | `eras` · `default/spec-mempool` | 6 | `witness-ts-sdk-eras-default-spec-mempool-flags.discourage-upgradable-nops-eras-00016` | [SRC] bitcoin-sv v1.2.2 policy.h:186 (policy flag); interpreter.cpp:765–771; [SRC] @bsv/sdk 3.0.0 Spend.ts:839, 887 (DISCOURAGE_UPGRADABLE_NOPS). |
| `flags.discourage-upgradable-nops` | OPEN | open | `flow` · `default/spec-mempool` | 6 | `witness-ts-sdk-flow-default-spec-mempool-flags.discourage-upgradable-nops-flow-00971` | [SRC] bitcoin-sv v1.2.2 policy.h:186 (policy flag); interpreter.cpp:765–771; [SRC] @bsv/sdk 3.0.0 Spend.ts:839, 887 (DISCOURAGE_UPGRADABLE_NOPS). |
| `flags.discourage-upgradable-nops` | OPEN | open | `gen` · `default/spec-mempool` | 40 | `witness-ts-sdk-gen-default-spec-mempool-flags.discourage-upgradable-nops-gen-00754` | [SRC] bitcoin-sv v1.2.2 policy.h:186 (policy flag); interpreter.cpp:765–771; [SRC] @bsv/sdk 3.0.0 Spend.ts:839, 887 (DISCOURAGE_UPGRADABLE_NOPS). |
| `flags.discourage-upgradable-nops` | OPEN | open | `tx` · `default/spec-mempool` | 2 | `witness-ts-sdk-tx-default-spec-mempool-flags.discourage-upgradable-nops-tx-00011` | [SRC] bitcoin-sv v1.2.2 policy.h:186 (policy flag); interpreter.cpp:765–771; [SRC] @bsv/sdk 3.0.0 Spend.ts:839, 887 (DISCOURAGE_UPGRADABLE_NOPS). |
| `flags.policy-as-consensus` | OPEN | open | `arith` · `default/spec` | 8 | `witness-ts-sdk-arith-default-spec-flags.policy-as-consensus-arith-00352` | [SRC] bitcoin-sv v1.2.2 policy.h:178–190; verify_script_flags.cpp:32–81 (standard restrictions absent from the block word); [SRC] @bsv/sdk 3.0.0 Spend.ts:319–321, 347–374 (default restrictions by transaction version). |
| `flags.policy-as-consensus` | OPEN | open | `bytes` · `default/spec` | 154 | `witness-ts-sdk-bytes-default-spec-flags.policy-as-consensus-bytes-00258` | [SRC] bitcoin-sv v1.2.2 policy.h:178–190; verify_script_flags.cpp:32–81 (standard restrictions absent from the block word); [SRC] @bsv/sdk 3.0.0 Spend.ts:319–321, 347–374 (default restrictions by transaction version). |
| `flags.policy-as-consensus` | OPEN | open | `crypto` · `default/spec` | 3 | `witness-ts-sdk-crypto-default-spec-flags.policy-as-consensus-crypto-00081` | [SRC] bitcoin-sv v1.2.2 policy.h:178–190; verify_script_flags.cpp:32–81 (standard restrictions absent from the block word); [SRC] @bsv/sdk 3.0.0 Spend.ts:319–321, 347–374 (default restrictions by transaction version). |
| `flags.policy-as-consensus` | OPEN | open | `flow` · `default/spec` | 297 | `witness-ts-sdk-flow-default-spec-flags.policy-as-consensus-flow-01006` | [SRC] bitcoin-sv v1.2.2 policy.h:178–190; verify_script_flags.cpp:32–81 (standard restrictions absent from the block word); [SRC] @bsv/sdk 3.0.0 Spend.ts:319–321, 347–374 (default restrictions by transaction version). |
| `flags.policy-as-consensus` | OPEN | open | `seed` · `default/spec` | 160 | `witness-ts-sdk-seed-default-spec-flags.policy-as-consensus-seed-000296` | [SRC] bitcoin-sv v1.2.2 policy.h:178–190; verify_script_flags.cpp:32–81 (standard restrictions absent from the block word); [SRC] @bsv/sdk 3.0.0 Spend.ts:319–321, 347–374 (default restrictions by transaction version). |
| `flags.policy-as-consensus` | OPEN | open | `stack` · `default/spec` | 4 | `witness-ts-sdk-stack-default-spec-flags.policy-as-consensus-stack-00224` | [SRC] bitcoin-sv v1.2.2 policy.h:178–190; verify_script_flags.cpp:32–81 (standard restrictions absent from the block word); [SRC] @bsv/sdk 3.0.0 Spend.ts:319–321, 347–374 (default restrictions by transaction version). |
| `limits.maxscriptnumlength.policy` | OPEN | open | `eras` · `spec-mempool` | 1 | `witness-ts-sdk-eras-spec-mempool-limits.maxscriptnumlength.policy-eras-00042` | [SRC] bitcoin-sv v1.2.2 configscriptpolicy.cpp:79–110; policy.h:156 (default policy width 10000 bytes); consensus.h:64, 66 (consensus widths); interpreter.cpp:1789–1790, 1807–1810; [SRC] @bsv/sdk 3.0.0 Spend.ts:395–403 (consensus widths on numeric reads, no policy input), 1989–1997 (OP_BIN2NUM result test has no width). |
| `limits.maxscriptnumlength.policy` | OPEN | open | `gen` · `default/spec-mempool` | 9 | `witness-ts-sdk-gen-default-spec-mempool-limits.maxscriptnumlength.policy-gen-00004` | [SRC] bitcoin-sv v1.2.2 configscriptpolicy.cpp:79–110; policy.h:156 (default policy width 10000 bytes); consensus.h:64, 66 (consensus widths); interpreter.cpp:1789–1790, 1807–1810; [SRC] @bsv/sdk 3.0.0 Spend.ts:395–403 (consensus widths on numeric reads, no policy input), 1989–1997 (OP_BIN2NUM result test has no width). |
| `limits.maxscriptnumlength.policy` | OPEN | open | `gen` · `spec-mempool` | 9 | `witness-ts-sdk-gen-spec-mempool-limits.maxscriptnumlength.policy-gen-00004` | [SRC] bitcoin-sv v1.2.2 configscriptpolicy.cpp:79–110; policy.h:156 (default policy width 10000 bytes); consensus.h:64, 66 (consensus widths); interpreter.cpp:1789–1790, 1807–1810; [SRC] @bsv/sdk 3.0.0 Spend.ts:395–403 (consensus widths on numeric reads, no policy input), 1989–1997 (OP_BIN2NUM result test has no width). |

**ts-sdk: the preserved historical redaction rows.** The following counts belong to the previous page; the current classified totals are in §1.

| class | kind | ruling | corpus · column | historical entries | smallest witness | decided by |
|---|---|---|---|---|---|---|
| (a class under a still-private advisory: withheld, D135) | IMPLEMENTATION-WRONG | impl-wrong | `tx` · `default/spec` | 10 | (withheld until the advisory publishes) | (withheld) |
| (a class under a still-private advisory: withheld, D135) | IMPLEMENTATION-WRONG | impl-wrong | `tx` · `default/spec-mempool` | 10 | (withheld until the advisory publishes) | (withheld) |

### gobdk (2 class rows)

| class | kind | ruling | corpus · column | entries | smallest witness (replay: `tools/witness.sh <id>`) | decided by |
|---|---|---|---|---|---|---|
| `splice.substr.int64-reader.v1.2.2-fold` | IMPLEMENTATION-WRONG | impl-wrong | `gen` · `spec` | 58 | `witness-gobdk-gen-spec-splice.substr.int64-reader.v1.2.2-fold-WITHHELD: d9-gosdk-172-splice (see corpus/INDEX.md)` | The reading of record at v1.2.3 is a defined refusal ([SRC] `int_serialization.h:61–118`, `script_num.cpp:80–91` at `6504a3af`); the previous pin's reading and its measurements are recorded in material withheld from the public edition at the maintainers' request (group `d8-node-team-discretion`). [SRC] GoBDK `4eab3acd`, `module/gobdk/bdkcgo/version_cgo.h:22–23`, identifies its linked reference; its own recorded columns remain in the corpus. |
| `splice.substr.int64-reader.v1.2.2-fold` | IMPLEMENTATION-WRONG | impl-wrong | `gen` · `spec-mempool` | 58 | `witness-gobdk-gen-spec-mempool-splice.substr.int64-reader.v1.2.2-fold-WITHHELD: d9-gosdk-172-splice (see corpus/INDEX.md)` | The reading of record at v1.2.3 is a defined refusal ([SRC] `int_serialization.h:61–118`, `script_num.cpp:80–91` at `6504a3af`); the previous pin's reading and its measurements are recorded in material withheld from the public edition at the maintainers' request (group `d8-node-team-discretion`). [SRC] GoBDK `4eab3acd`, `module/gobdk/bdkcgo/version_cgo.h:22–23`, identifies its linked reference; its own recorded columns remain in the corpus. |

### sv-node (1 class rows)

| class | kind | ruling | corpus · column | entries | smallest witness (replay: `tools/witness.sh <id>`) | decided by |
|---|---|---|---|---|---|---|
| `tx.finality.out-of-scope` | SPEC-SIDE | open | `tx` · `spec` | 2 | `witness-sv-node-tx-spec-tx.finality.out-of-scope-tx-00037` | [SRC] bitcoin-sv v1.2.3 at 6504a3aff65ba97c0f6c80962b033e35ecbfed4b: validation.cpp:227–247 (IsFinalTx), :5977–5993 (ContextualCheckTransaction: block bad-txns-nonfinal; after Genesis an off-block non-final transaction routes to the non-final pool, :912–926), :257–336 (CalculateSequenceLocks/EvaluateSequenceLocks), :3345–3348 (block BIP68 refusal), :1201–1203 (mempool non-BIP68-final); policy.h:247–255 (StandardNonFinalVerifyFlags: sequence locks before Genesis only). docs/DESIGN.md §5.5: block-level rules, the UTXO set, ordering and maturity are outside the transaction gate, #36. |

## 3. The counts

| implementation | IMPLEMENTATION-WRONG | SPEC-SIDE | OPEN | MECHANISM |
|---|---|---|---|---|
| bsv-rs | 0 | 0 | 0 | 2 |
| go-sdk | 1 | 0 | 2 | 0 |
| ts-sdk | 7 | 0 | 5 | 1 |
| gobdk | 1 | 0 | 0 | 0 |
| sv-node | 0 | 1 | 0 | 0 |

(distinct classes per implementation; a class seen in several corpora or columns is counted once here and listed per row in §2)

## 4. Not in this report

The mutators and the random scripts (#26's remaining families); the entries of the reference's C++ unit tables that have no spend form (§1's `corpus/cpp` table: the undecided column, each entry's reason in its file's ledger).

**Excluded from the transaction gate, from source, not measured `[SRC]`:** the coinbase height requirement (BIP34), validation.cpp:6085–6093 bad-cb-height: block context, outside the transaction gate by the maintainers' ruling R2 on #32; recorded from source, never executed by the road. The recorded reference context is the block instance (harness/oracle/bitcoin-block.conf, regtest, bitcoin-sv v1.2.3 6504a3a). Mainnet's BIP34 height is 227,931 (chainparams.cpp:1038 at 6504a3a [SRC]); the instance's is 100,000,000 (regtest's compiled consensus.BIP34Height, chainparams.cpp:1463 at 6504a3a; the instance's configuration sets no BIP34 height [SRC]). No run of this report executes it; the agreements that turn on it are listed apart in §1.
