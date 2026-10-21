# SECOND FORMALIZATION: the candidates, ranked by the trust each would remove (#37; 2026-10-05)

**What this page is.** `NORTH-STAR.md` §6: the reference is a program, and what the spec trusts is the
transcription, one reading of the C++ into Lean. This note lists what that trust consists of today, what the
harness's engine columns already remove, and ranks the candidates for a second formalization or a
cross-framework check by the trust each would remove, with a rough cost in work periods, labeled `[EST]`. It
recommends nothing: the maintainers charter. A candidate chartered gets its own issue with its done-bar; nothing
below is a gate (the tracker's bar for #37).

Labels as in `README.md`: `[SRC]` read at the pin (`docs/PROVENANCE.md` §1), `[X]` executed, with the record
that names the measured commit (`CLAUDE.md` rule 17), `[LIT]` a public source, `[EST]` an estimate. The reference is bitcoin-sv v1.2.2 at
`879fc8b42168dd0e608dafd51b39c6dabad37d4d`.

## 1. What is trusted today, by name

| # | what is trusted | the evidence that stands for it today |
|---|---|---|
| T1 | **the transcription of the interpreter**: one reader's rendering of `interpreter.cpp` and the files of `docs/PROVENANCE.md` §2 into the definitions of `lean/BsvScript/` | the reference's own verdicts: the sv-node column agrees with the spec on every entry of the eleven corpora but the two finality entries of `corpus/tx` (`docs/CONFORMANCE-2026-09-27.md` §1, the sv-node rows; `corpus/INDEX.md` §4c: 13,512 of 13,512 on `corpus/road`, 10,000 of 10,000 on `corpus/seed`); the differential's 26,514 cells (`corpus/INDEX.md` §4) |
| T2 | **the transcription of the signature path**: point decoding, the lax DER parse, the normalization and the equation, with the field and group arithmetic computing the same values by other means (`lean/BsvScript/Crypto/Secp256k1.lean`'s header; `docs/DESIGN.md` §4.1) | 1,340 constructed cases (`docs/HYPOTHESES.md` §1), the node's agreement on `corpus/crypto` and `corpus/gen` (`docs/HYPOTHESES.md` §1, second row); no axiom: `lean/AXIOMS-ALLOWED` is Lean's three |
| T3 | **the compiled evaluator**: the Lean compiler, the C toolchain, the runtime, the `@[csimp]` substitutions, and the CLI's own readers no theorem covers | `docs/HYPOTHESES.md` §3; the bridge is the kernel-evaluated sample: 25 vectors decided by `decide +kernel` and run by the compiled code in the flow leg (`lean/BsvScript/Properties/KernelSample.lean`, `vectors_kernel`) |
| T4 | **the Lean kernel** and the three axioms `propext`, `Classical.choice`, `Quot.sound` | `lean/AXIOMS-ALLOWED`; `tools/axiom_check.py` on every declared theorem (the `axioms` leg, `tools/check.sh`) |
| T5 | **the statements**: that each theorem says what its explainer and the pages say it says | the three-lens review of #32 (`docs/STATE-OF-THE-WORLD.md` §3, the trust-boundary row) |
| T6 | **the harness glue**: the entry readers, `Run.paramsFor`, `Run.combine`, `Run.txGate`, the adapters | `docs/HYPOTHESES.md` §3 names them as trusted; a one-sided glue error would appear as a divergence in a column |
| T7 | **coverage**: the inputs no corpus reaches | a statement about the evidence, not the definitions; `corpus/INDEX.md` §1 lists the generators and their seeds |
| T8 | **the reference itself**: a program that can be wrong or disagree with its own documentation | `CLAUDE.md` rule 15; `NORTH-STAR.md` §6. No formalization removes it; the maintainers rule a disagreement |

## 2. What the engine columns already give

The harness runs each implementation in two columns, `spec` (the block word, what a mining node decides) and
`spec-mempool` (the relay word, the node's default policy), and @bsv/sdk in a third, `default`, its own
derivation from the transaction's version (`harness/README.md`, "The columns"). Each column compares the
implementation's verdict with the spec's on the same entry; a divergence is a classified witness
(`docs/CONFORMANCE-2026-09-27.md`, the page's opening paragraph).

| implementation (the pin, `docs/PROVENANCE.md` §1) | what it is | independent of the C++? | independent of the spec's reading? | what its agreement removes |
|---|---|---|---|---|
| sv-node v1.2.2, two instances (`corpus/INDEX.md` §4c) | the reference itself, through `verifyscript` and the block road | no: it is the C++ | yes | T1 on every corpus input; the judge of the spec (`CLAUDE.md` rule 4) |
| GoBDK `cdfa7814` | bitcoin-sv's own `src/script/*` compiled into Teranode's library, identified byte-level (`docs/PROVENANCE.md` §1) | no: the same interpreter, another build | yes | an independent build and an independent flag derivation (`CalculateFlags`, Go): the word, not the semantics |
| bsv-rs 0.3.30 | a Rust engine written outside the C++ (`docs/PROVENANCE.md` §1) | yes | partly: its fixes since 0.3.26 closed the spec's own witness classes (`docs/PROVENANCE.md` §1, the bsv-rs row; its section of `docs/CONFORMANCE-2026-09-27.md` §2 is empty since 0.3.30) | T1 on the rules it decided before the fixes; on the fixed rules its agreement is the spec's reading fed back |
| go-sdk v1.5.2 | a Go engine by other authors | yes | yes | T1 where it agrees; it diverges in 8 classes ruled implementation-wrong and 1 open (`docs/CONFORMANCE-2026-09-27.md` §3) |
| @bsv/sdk 2.8.0 | a TypeScript engine by other authors | yes | yes | T1 where it agrees; 17 implementation-wrong and 6 open (`docs/CONFORMANCE-2026-09-27.md` §3) |

**What the columns remove.** T1 on every input a corpus holds, by the reference's own verdict; T6 where an
error would be one-sided. **What they leave.** T1 off the corpora (T7), T2 beyond the signatures the corpora
carry, T3 beyond the 25 vectors, T4, T5 and T8. Two independently written engines agreeing with the spec and
the node on an entry is a reading independent of both the C++ and the transcription; where they disagree,
the reference's lines decide (`docs/CONFORMANCE-2026-09-27.md` §2, the "decided by" column), so the columns are
evidence about T1 and never a second definition.

## 3. The candidates, ranked by the trust each would remove

The size of what would be formalized again. Of record: 760 theorems pass the axiom leg at commit `61e2d1a`
(`docs/records/20261005-210841-make-check-box.txt`, its `axiom check` line; `tools/axiom_check.py` over every
declared theorem), and the same record's `flowcheck` line carries the 25 kernel-sample vectors `[X]`. That
record carries no line count (its text names no `wc` run and no count of lines; other records were not read),
so the sizes are estimates, to be re-measured by the command named: roughly 17,000 lines of Lean under
`lean/BsvScript/` (`find lean/BsvScript -name '*.lean' | xargs wc -l`), of which the hashes and the curve are
under 1,000 and the properties under 5,000; roughly 3,000 lines of test legs under `lean/Test/` `[EST]`.
Calibration for the estimates: the model and its properties were built by two Lean seats between the
birth on 2026-09-21 and the trust lens of 2026-09-29 (`docs/STATE-OF-THE-WORLD.md` §3, the dated rows) `[EST]`.

| rank | candidate | what it would remove | what it would leave | cost `[EST]` |
|---|---|---|---|---|
| 1 | **C1. Extend the kernel-evaluated bridge**: corpus entries, a hash and a signature among them, decided by `decide +kernel` on the definitions and compared with the compiled verdicts, as the 25 vectors are | T3 at every added point | T3 elsewhere; T1 | 1 to 3 work periods; the kernel's reduction of a signature is unmeasured and may run for hours |
| 2 | **C2. Replay the built environment through `lean4checker`**, which re-checks every declaration of the `.olean` files with Lean's own kernel from a fresh environment; its README: "This is not an external verifier, as it uses the Lean kernel itself", a tool "to detect 'environment hacking', i.e. using metaprogramming facilities to build an inconsistent Lean Environment" (`[LIT]` github.com/leanprover/lean4checker, README, read 2026-10-05); a verified kernel would be a later and separate step (`[LIT]` M. Carneiro, "Lean4Lean: Towards a Verified Typechecker for Lean, in Lean", 2024) | the risk that the build's environment holds a declaration the kernel never checked (an inconsistent environment built by metaprogramming); nothing of the kernel's implementation | T4 whole: the kernel's implementation and its theory, the three axioms | under 1 work period |
| 3 | **C3. The signature path against vectors other authors chose**: Project Wycheproof's ECDSA secp256k1 SHA-256 set, 476 tests (`[LIT]` github.com/C2SP/wycheproof, `testvectors_v1/ecdsa_secp256k1_sha256_test.json`, read 2026-10-05). Its cases include BER and otherwise malformed encodings, among them signatures whose r and s are valid values in a non-DER encoding (the flags `BerEncodedSignature` and `MissingZero`) labelled `invalid`, so an equation-level comparison must filter or reclassify every case by its encoding flags against the reference's own lax parse (`docs/DESIGN.md` §4.1) before it compares. The secp256k1 field and scalar arithmetic against arithmetic generated and proven per prime by Fiat-Crypto (`[LIT]` Erbsen, Philipoom, Gross, Sloan, Chlipala, "Simple High-Level Code for Cryptographic Arithmetic: With Proofs, Without Compromises", IEEE S&P 2019) | T2 on inputs the reference's signatures never produced, at the equation and at the arithmetic | T2's parse, where the reference's lax parse and the vectors' encoding verdicts differ by design; the classification is work, not evidence | 1 to 2 work periods |
| 4 | **C4. A statement audit**: a reader who has not seen the proofs compares every theorem's statement with its explainer and with the `[SRC]` lines it cites, and reports the mismatches | T5 | the proofs (the kernel already checks them); T1 | 2 to 4 work periods; the trust lens of #32 was one such pass |
| 5 | **C6. A second model in Lean by an independent reader**, no shared code but Mathlib and the hash and curve modules, then the equivalence theorem `verifyScript₁ = verifyScript₂` (or, failing it, a kernel-checked differential on the corpora) | T1 as a one-reader risk, on every input if the equivalence is proven | T2 (shared by construction), T3, T4 | 12 to 18 work periods for the model, 4 to 8 for the equivalence |
| 6 | **C7. A second model in another framework** (Isabelle/HOL, Rocq, the K framework, HOL4, ACL2) | T1 as a one-reader risk, on the inputs where the two models' extracted evaluators agree | agreement by execution is bounded by the inputs run (T7) and discharges nothing of T4 and nothing about any proof; this note identifies no theorem relating a Lean model to a model in another framework and does not claim one is impossible: the precedents named are each checked by execution against a test suite, and Lem's road is one source definition exported to several provers, not two independent models related by a theorem; the hashes and the curve re-done or hooked (a hook moves T2 to the hook) | 20 to 30 work periods; precedents `[LIT]`: KEVM (Hildenbrandt et al., IEEE CSF 2018), the EVM in Lem for Isabelle/HOL (Hirai, 2017), the Python execution specs of Ethereum (ethereum/execution-specs); Simplicity in Coq (`README.md`, the wording rules) |
| 7 | **C5. A clean-room evaluator from the generated document alone** (`spec/`, never the C++), run as a sixth column | nothing of T1 the node column does not already decide; a test of the document as a specification (the tuple's property 5) | T1 to T8 | 8 to 12 work periods |
| 8 | **C8. Relate the C++ itself to the model** through a formal semantics of the reference's C++ at the pin | T1 in full | this note identifies no formal semantics of that C++ dialect fit for the task; T2 to T8 | not estimable |

The ranking is trust removed per work period. C1, C3 and C4 are small and sharp and remove trust the columns
cannot reach (T3, T2, T5); C2 is cheaper still and removes only the risk of an environment assembled past the
kernel, nothing of T4. C6 is the one candidate that removes the headline trust, T1, by a theorem rather than
by inputs; C7 removes T1 on the inputs run and nothing of T4; C5 tests the document, not the semantics; C8
has no identified road. Nothing on the list removes T4 short of a verified kernel, and nothing removes T8.

## 4. What this note does not do

It charters nothing and orders nothing. It names no gate: v1.0 (`NORTH-STAR.md` §5) does not depend on any
row of §3. A chartered candidate carries, in its issue, its done-bar, its record and the trust row of §1 it
retires; this page then moves that row from §1 to a closing section with the record's name, in the same
commit (`CLAUDE.md` rules 9 and 12).

*Update rule: a new engine column is a row in §2; a new trusted item is a row in §1; a candidate run is a
record, never a sentence here without one.*
