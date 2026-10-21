import BsvScript.Params
import BsvScript.Numbers
import BsvScript.Machine
import BsvScript.Opcodes
import BsvScript.Sighash
import BsvScript.Flags
import BsvScript.Tx
import BsvScript.Eval
import BsvScript.TxContext
import BsvScript.TxRules
import BsvScript.SigOps
import BsvScript.Standard
import BsvScript.TxPolicy
import BsvScript.Properties.Basic
import BsvScript.Properties.TxValue
import BsvScript.Properties.Coverage
import BsvScript.Properties.VersionGate
import BsvScript.Properties.Eras
import BsvScript.Properties.P2SH
import BsvScript.Properties.Resources
import BsvScript.Properties.Widths
import BsvScript.Properties.Hooks
import BsvScript.Properties.KernelSample
import BsvScript.Properties.Sighash
import BsvScript.Gadget
import BsvScript.Gadget.HashLock
import BsvScript.Impl.State
import BsvScript.Impl.Stack
import BsvScript.Impl.Arith
import BsvScript.Impl.Bitwise
import BsvScript.Impl.Splice
import BsvScript.Impl.Expansion
import BsvScript.Impl.Crypto
import BsvScript.Impl.Machine
/-!
# BsvScript: an executable, machine-checked specification of BSV script consensus

The library root. Module map (`docs/DESIGN.md`; each module names the issue
that fills it and cites the reference at the pin in `docs/PROVENANCE.md`):

* `BsvScript.Params`     the parameters record: every limit and flag the
                          interpreter reads, by kind (consensus / miner-configurable
                          / policy), with its default and its `[SRC]` (#6)
* `BsvScript.Numbers`    script numbers: the LE sign-magnitude encoding, minimal
                          encoding, `BIN2NUM`/`NUM2BIN`, negative zero, the size
                          rules, the canonicality theorems (#7)
* `BsvScript.Machine`    the machine state, `step`, `run`, the condition stack,
                          the two-phase spend, the final-stack rule (#8)
* `BsvScript.Opcodes`    the opcode table: one definition per opcode with its
                          byte, history, stack effect, semantics and `[SRC]`
                          (#9, #10, #11, #18)
* `BsvScript.Sighash`    the FORKID preimage, the SIGHASH types, `scriptCode`
                          after `OP_CODESEPARATOR`, the legacy path (#12)
* `BsvScript.Flags`      the flags model: the version gate on one expression,
                          every flag's status and kind (#13)
* `BsvScript.SigOps`     the node's count of signature operations on every path
                          (`CScript::GetSigOpCount`: before and after Genesis, with and
                          without `fAccurate`, the P2SH redeem count, `sigOpCountError`;
                          the spec gap of #27's remainder, 2026-09-27)
* `BsvScript.Standard`   the node's standardness tests (`IsStandardTx` with its reasons,
                          `Solver`'s output types, dust, the data carrier, `AreInputsStandard`;
                          `script/standard.cpp`, `policy/policy.cpp`; the standardness gap
                          of #27, 2026-09-28)
* `BsvScript.TxPolicy`   the mempool's two transaction-level policy caps as named
                          parameters (the sigop count, the serialized size), the policy
                          gate beside `TxRules`'s consensus gate, the mempool's count over
                          `SigOps` with its error, and what the gate adds at the
                          consensus configuration (the spec gap of #27, 2026-09-27); the
                          standardness gate before the caps under `requireStandard` and
                          `acceptnonstdoutputs` (2026-09-28)
* `BsvScript.Properties` determinism, termination under the parameters,
                          canonicality, the parameter separation (#16, #25); every
                          byte defined (#18); the version-1 branch at every site (#19);
                          the activation rules as parameters and the era rules per
                          opcode (#20); P2SH disabled for new outputs, grandfathered (#23);
                          the resource bounds at their sites (#25: the script size, the op
                          count, the stack memory, the pre-Genesis depth, the multisig bounds,
                          the result width); the opcode widths (#25: the reader's overflow,
                          the digests, `OP_CAT`/`OP_SPLIT`, `OP_NUM2BIN`'s memory, the shifts);
                          the two hook hypotheses discharged for every family (#25: the op
                          count and the memory invariant hold for `Eval.opExec`);
                          the kernel-evaluated sample (the direction audit's item (b):
                          25 vectors decided by the kernel on the definitions and run
                          by the compiled evaluator in the flow leg; `docs/HYPOTHESES.md` §3)
* `BsvScript.Gadget`     the gadget-level API for a layer-4 consumer (#35, 35a; `docs/DESIGN.md`
                          §12.4): a fragment's run over the spec's own loop (`loop_eq_run`),
                          composition by concatenation (`run_append`), and the triple a
                          consumer proves per gadget with its rules (`Triple.seq`,
                          `Triple.conseq`); written by S2, applied by S1 (2026-09-29)
* `BsvScript.Gadget.HashLock` the API's worked example (#35, 35a): BIP 199's hash puzzle
                          `OP_SHA256 <h> OP_EQUALVERIFY` as a gadget triple (`hashLock_triple`),
                          composed from the three instructions' triples; written by S2, applied
                          by S1 (2026-09-29)
* `BsvScript.Impl`       the compiled evaluator's machine (#50): the machine over an
                          array-backed stack held bottom-first (`Impl.State`), every family
                          restated over it (`Impl.Stack`, `Impl.Arith`, `Impl.Bitwise`,
                          `Impl.Splice`, `Impl.Expansion`, `Impl.Crypto`), the loop and the two
                          phases (`Impl.Machine`), each proven a refinement of the spec's
                          (`Impl.verifyScriptA_eq`), substituted for `Eval.verifyScript` by
                          `@[csimp]` (`Eval.verifyScript_eq_I`); not the semantics: nothing of
                          the spec moves (S1, 2026-09-29)

Discipline (CLAUDE.md rule 7): statements first; sorry-free and axiom-clean on
`main`; `#print axioms` on every main theorem shows only
`[propext, Classical.choice, Quot.sound]`: there is no signature-verification
hypothesis, the ECDSA equation is an executable definition (Q9 ruled (A) on #38,
2026-09-22; `docs/HYPOTHESES.md`); an explainer per theorem.
-/
