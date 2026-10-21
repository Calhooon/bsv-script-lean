import BsvScript.Sighash
import BsvScript.Properties.Eras
import BsvScript.Properties.Hooks
/-!
# BsvScript.Properties.Sighash

The three signer properties as theorems (#149; `docs/DESIGN.md` §4.3): what a signer must hash for the node to
accept its signature, each a sentence about the executable semantics at its site of the reference:

* **the scriptCode of a signature check** (`1471–1481`, `2338–2342`): inside the unlocking script under
  `SCRIPT_CHRONICLE` the bytes from the last executed `OP_CODESEPARATOR` with the locking script appended; the
  tail alone without the flag; in the locking script the bytes from its last executed separator
  (`scriptCode_unlock_site`, with the separator's two sites in `codeSep_sites` and the cleaned form a FORKID
  signature digests in `scriptCode_unlock_site_forkid`); over a whole run, `codeSep` is the script from the byte
  after the last executed separator, the script's start when none executed (`codeSep_last`, from the frames
  `opExec_codeSep` and `execStep_codeSep`; at the check, `scriptCode_last`), so in the unlocking script it is a
  suffix containing the check (`codeSep_run_suffix`) and under `SCRIPT_CHRONICLE` the scriptCode is never the
  locking script alone (`scriptCode_run`);
* **the dispatch** (`2112–2124`): the CHRONICLE bit selects the original digest whatever the FORKID bit; FORKID
  without CHRONICLE, under FORKID enabled, selects the BIP143 digest (`digest_dispatch_chronicle`);
* **SIGHASH_SINGLE past the outputs** (`2086–2100`; `2034–2083`): the original digest is the constant `one`,
  unhashed; the BIP143 digest hashes a preimage whose `hashOutputs` is thirty-two zero bytes
  (`single_past_outputs`).

The definitions are `BsvScript.Sighash` and `BsvScript.Machine` as they stand; this module adds the run
statements' vocabulary and no definition of the semantics: two inductive propositions, `LoopReach` (the loop's
iterations; `LoopReach.loop_eq` ties it to `loop`) and `LoopTrace` (the same iterations with the instructions
they ran, `LoopTrace.reach` and `LoopReach.trace`), the record `TraceEntry` and the function `afterLastSep` (the
offset after a trace's last executed separator).
Every `[SRC]` that names no other source is bitcoin-sv v1.2.3 at `6504a3af` (`docs/PROVENANCE.md`); a bare
number is a line of `src/script/interpreter.cpp`. The measured lines of the signers are each record's own
reading at its release.
-/

namespace BsvScript.Properties
open BsvScript.Params BsvScript.Machine BsvScript.Numbers BsvScript.Tx BsvScript.Hash BsvScript.Sighash
open BsvScript.Ops.Crypto

/-! ## The scriptCode of a signature check (`1471–1481`, `2338–2342`) -/

/-- **`scriptCode_unlock_site`.** *The rule:* the scriptCode a signature check builds is `codeSep` (the reference's
`{pbegincodehash, pend}`; what writes `codeSep` is `codeSep_sites`, and the whole run is `scriptCode_last`),
with the locking script appended when the check executes inside the unlocking script under `SCRIPT_CHRONICLE`.
*What it says:* in the environments `verifyScript` builds from the word `params.flags` (after STRICTENC from
FORKID, `Flags.forkAdjust`), the unlocking phase's, whose `checksigData` is the locking script, and the locking
and P2SH-redeem phases', whose `checksigData` is none (`Machine.lean`'s `phase2` builds that one twice),
`scriptCodeOf` is `codeSep ++ scriptPubKey` in the unlocking phase with the CHRONICLE bit set, `codeSep` in the
unlocking phase without it, and `codeSep` in the locking phase. *What it assumes:* nothing beyond the word: every
parameter record, context, locking script and state. [SRC] `1471–1481` (`CScript scriptCode {pbegincodehash,
pend}`; `if(checksigData && IsChronicle(flags)) scriptCode += *checksigData`) and of `OP_CHECKMULTISIG`
(`1567–1577`); `2338–2342` (the unlocking script evaluated with `&scriptPubKey` as `checksigData`); `2358–2362`
and `2402–2406` (the locking script and the P2SH redeem script evaluated with `nullptr` as `checksigData`);
`1445–1448` (`pbegincodehash`). *Measured contradiction:* go-sdk v1.7.2 hashes the source output's locking
script as the scriptCode on its default path (`transaction/signaturehash.go:277-299`), class
`sighash.scriptcode.in-unlock.lock-only`; at @bsv/sdk 3.0.0 the caller supplies the subscript
(`primitives/TransactionSignature.ts:262,394-396`), the class ruled `caller-scriptcode-required`
(`docs/records/20261016-203024-s3-145d-signer-column-s3.md`); bsv-rs 0.5.0 selects the source locking script
(`src/script/template.rs:85-99`), the same lock-only class (`docs/records/20261016-234915-s3-147-signer-column-s3.md`). -/
theorem scriptCode_unlock_site (params : EvalParams) (ctx : Context) (scriptPubKey : Bytes) (st : State) :
    (params.flags.chronicle = true →
      scriptCodeOf (mkEnv params ctx params.flags.forkAdjust (some scriptPubKey)) st = st.codeSep ++ scriptPubKey)
    ∧ (params.flags.chronicle = false →
      scriptCodeOf (mkEnv params ctx params.flags.forkAdjust (some scriptPubKey)) st = st.codeSep)
    ∧ scriptCodeOf (mkEnv params ctx params.flags.forkAdjust none) st = st.codeSep := by
  have hch : (mkEnv params ctx params.flags.forkAdjust (some scriptPubKey)).params.flags.chronicle
      = params.flags.chronicle := by
    simp only [mkEnv, Flags.gate, Flags.forkAdjust]
    split_ifs <;> rfl
  refine ⟨fun h => ?_, fun h => ?_, ?_⟩
  · exact scriptCodeOf_chronicle _ _ _ rfl (hch.trans h)
  · exact scriptCodeOf_eq_codeSep _ _ (Or.inr (hch.trans h))
  · exact scriptCodeOf_eq_codeSep _ _ (Or.inl rfl)

/-- **`codeSep_sites`.** *The rule:* `codeSep` is the script from the last executed `OP_CODESEPARATOR`, the whole
script before any. *What it says:* the two sites that write it: `evalScript` starts the loop with `codeSep` the
whole script (within the size limit), an executed separator sets it to the bytes after itself, and an unexecuted
one (an inactive branch) leaves the state as it was. *What it assumes:* the script within `maxScriptSize` for the
opening clause; nothing for the other two. [SRC] `407` (`pbegincodehash = script.begin()`), `1445–1448`
(`pbegincodehash = pc`), `482` (the switch runs only under `fExec` or for `OP_IF`…`OP_ENDIF`). The opcodes other
than the separator do not write `codeSep` (`execStep_codeSep`); the whole run is `codeSep_last`. -/
theorem codeSep_sites (exec : OpExec) (env : Env) (script : Bytes) (stack : List Bytes) (memUsed : Nat)
    (data rest : Bytes) (k : Nat) (st : State) :
    (script.length ≤ env.params.limits.maxScriptSize →
      evalScript exec env script stack memUsed
        = loop exec env script { stack := stack, memUsed := memUsed, codeSep := script })
    ∧ execStep exec env Op.OP_CODESEPARATOR data rest k true st = .cont { st with codeSep := rest.drop k }
    ∧ execStep exec env Op.OP_CODESEPARATOR data rest k false st = .cont st := by
  refine ⟨fun h => ?_, execStep_codeseparator _ _ _ _ _ _, execStep_codeseparator_unexecuted _ _ _ _ _ _⟩
  simp [evalScript, Nat.not_lt.mpr h]

/-- **`scriptCode_unlock_site_forkid`.** *The rule:* under FORKID a signature carrying the FORKID bit digests the
scriptCode uncleaned. *What it says:* with `SCRIPT_ENABLE_SIGHASH_FORKID` and `SCRIPT_CHRONICLE` in the word and a
signature whose hash type has the FORKID bit, the bytes `checkSigOp` hands its checker in the unlocking phase,
`cleanupScriptCode (scriptCodeOf env st) sig forkid`, are `codeSep ++ scriptPubKey`. *What it assumes:* the two
bits and the signature's FORKID bit. [SRC] `1471–1481`, `1484`, `255–263` (`CleanupScriptCode` deletes the
signature only when FORKID is off or the type lacks it), `2338–2342`. -/
theorem scriptCode_unlock_site_forkid (params : EvalParams) (ctx : Context) (scriptPubKey sig : Bytes) (st : State)
    (hc : params.flags.chronicle = true) (hf : params.flags.enableSighashForkid = true)
    (hs : (SigHashType.ofSig sig).hasForkId = true) :
    let env := mkEnv params ctx params.flags.forkAdjust (some scriptPubKey)
    cleanupScriptCode (scriptCodeOf env st) sig env.params.flags.enableSighashForkid = st.codeSep ++ scriptPubKey := by
  intro env
  have he : env.params.flags.enableSighashForkid = true := by
    simp only [env, mkEnv, Flags.gate, Flags.forkAdjust, hf]
    split_ifs <;> rfl
  rw [he, cleanupScriptCode_forkid _ _ hs]
  exact (scriptCode_unlock_site params ctx scriptPubKey st).1 hc

/-! ## The scriptCode over a whole run (`407`, `1445–1448`, `482`, `1471–1481`) -/

/-- **`opExec_codeSep`.** *The rule:* no opcode family writes the scriptCode's start; only the loop's own
separator does (`1445–1448`). *What it says:* every state the evaluator's hook `Eval.opExec` continues with has
the `codeSep` it was handed. *What it assumes:* nothing. [SRC] `1445–1448` (the one `pbegincodehash = pc` of
the switch); the families' frames (`Properties.Hooks`, `Frame`, `checkMultiSigOp_ok`). -/
theorem opExec_codeSep (op : Nat) (data : Bytes) (env : Env) (st st' : State)
    (h : Eval.opExec op data env st = some (.ok st')) : st'.codeSep = st.codeSep :=
  (opExec_good h).2.2

/-- `OP_IF` and its three siblings leave `codeSep` as they found it (`784–854`: the tracker and one pop). -/
theorem execIf_codeSep (env : Env) (op : Nat) (fExec : Bool) (st st' : State)
    (h : execIf env op fExec st = .cont st') : st'.codeSep = st.codeSep := by
  revert h
  unfold execIf
  try dsimp only
  repeat' split
  all_goals (intro h; cases h <;> rfl)

/-- `OP_CHECKLOCKTIMEVERIFY` leaves `codeSep` as it found it (`519–560`). -/
theorem execCltv_codeSep (env : Env) (st st' : State) (h : execCltv env st = .cont st') :
    st'.codeSep = st.codeSep := by
  revert h
  unfold execCltv
  try dsimp only
  repeat' split
  all_goals (intro h; cases h <;> rfl)

/-- `OP_CHECKSEQUENCEVERIFY` leaves `codeSep` as it found it (`562–597`). -/
theorem execCsv_codeSep (env : Env) (st st' : State) (h : execCsv env st = .cont st') :
    st'.codeSep = st.codeSep := by
  revert h
  unfold execCsv
  try dsimp only
  repeat' split
  all_goals (intro h; cases h <;> rfl)

/-- The machine's own switch leaves `codeSep` as it found it, the hook under its frame hypothesis
(`483–871`). -/
theorem execFlow_codeSep (exec : OpExec) (env : Env)
    (hh : ∀ op data st st', exec op data env st = some (.ok st') → st'.codeSep = st.codeSep)
    (op : Nat) (data : Bytes) (fExec : Bool) (st st' : State)
    (h : execFlow exec env op data fExec st = .cont st') : st'.codeSep = st.codeSep :=
  execFlow_preserves (fun s => s.codeSep = st.codeSep) exec env op data fExec st st' rfl
    (fun v s hs => by rw [pushElem_ok env st s v hs])
    (fun s hs => execCltv_codeSep env st s hs)
    (fun s hs => execCsv_codeSep env st s hs)
    (fun s hs => execIf_codeSep env op fExec st s hs)
    (fun _ => rfl) rfl (fun _ _ _ => rfl) (fun s hs => hh op data st s hs) h

/-- **`execStep_codeSep`.** *The rule:* an instruction other than an executed `OP_CODESEPARATOR` leaves the
scriptCode's start where it was. *What it says:* when `execStep` continues, the state's `codeSep` is the one it
was handed unless the opcode is `OP_CODESEPARATOR` and `fExec` holds (that site is `codeSep_sites`): the push
branch, the switch and the hook, the latter under the frame hypothesis `opExec_codeSep` discharges for the
evaluator. *What it assumes:* the hook's frame. [SRC] `473–481` (the push), `1445–1448` (the separator, the one
writer), `482` (the switch under `fExec` or for `OP_IF`…`OP_ENDIF`). -/
theorem execStep_codeSep (exec : OpExec) (env : Env)
    (hh : ∀ op data st st', exec op data env st = some (.ok st') → st'.codeSep = st.codeSep)
    (op : Nat) (data rest : Bytes) (k : Nat) (fExec : Bool) (st st' : State)
    (hsep : ¬(fExec = true ∧ op = Op.OP_CODESEPARATOR))
    (h : execStep exec env op data rest k fExec st = .cont st') : st'.codeSep = st.codeSep := by
  revert h
  unfold execStep
  try dsimp only
  repeat' split
  all_goals intro h
  all_goals first
    | (cases h; done)
    | (cases h; rfl)
    | (cases h; rename_i hp; rw [pushElem_ok _ _ _ _ hp])
    | exact execFlow_codeSep exec env hh op data fExec st st' h
    | (exfalso; simp_all)

/-- The loop's iterations (#149's run statement's vocabulary; no semantics): `LoopReach exec env s₀ st₀ s st` when
`loop exec env s₀ st₀` reaches the bytes `s` with the state `st`, each step one pass of `loop`'s second clause
whose guards all pass and whose `execStep` continues (`Machine.loop`, `450–1803`). `LoopReach.loop_eq`: the loop
from the start returns what it returns from every configuration it reaches. -/
inductive LoopReach (exec : OpExec) (env : Env) (s₀ : Bytes) (st₀ : State) : Bytes → State → Prop where
  | refl : LoopReach exec env s₀ st₀ s₀ st₀
  | step {op : Nat} {rest data : Bytes} {k : Nat} {st st' : State} :
      LoopReach exec env s₀ st₀ (op :: rest) st →
      getOpTail op rest = some (data, k) →
      (!env.utxoAfterGenesis && data.length > Consensus.maxScriptElementSizeBeforeGenesis) = false →
      (op > Op.OP_16 &&
          (if op > Op.OP_16 then { st with opCount := st.opCount + 1 } else st).opCount
            > env.params.limits.maxOpsPerScript) = false →
      (isOpcodeDisabled op env.utxoEra &&
          (!env.utxoAfterGenesis || (st.cond.isActive && (!st.nonTopLevelReturn || op == Op.OP_RETURN)))) = false →
      execStep exec env op data rest k (st.cond.isActive && (!st.nonTopLevelReturn || op == Op.OP_RETURN))
          (if op > Op.OP_16 then { st with opCount := st.opCount + 1 } else st) = .cont st' →
      (!env.utxoAfterGenesis &&
          st'.stack.length + st'.alt.length > Consensus.maxStackElementsBeforeGenesis) = false →
      LoopReach exec env s₀ st₀ (rest.drop k) st'

/-- **`LoopReach.loop_eq`.** *What it says:* every configuration `LoopReach` names is one the loop passes
through: the loop from the start returns what it returns from there. *What it assumes:* nothing. -/
theorem LoopReach.loop_eq {exec : OpExec} {env : Env} {s₀ : Bytes} {st₀ : State} {s : Bytes} {st : State}
    (hr : LoopReach exec env s₀ st₀ s st) : loop exec env s₀ st₀ = loop exec env s st := by
  induction hr with
  | refl => rfl
  | step _ hp h1 h2 h3 hs h4 ih =>
    rw [ih, loop.eq_2]
    simp only [hp, h1, h2, h3, hs, h4]
    rfl

/-! ## The last executed separator over a whole run (`405–407`, `450`, `459`, `482`, `1445–1448`, `1471–1481`) -/

/-- One instruction of a run as the trace records it (#149's `codeSep_last` vocabulary; no semantics): `pc`, the
byte offset of its opcode in the script (the reference's `pc` before `GetOp`, `450`), the opcode, and `fExec`, whether
it ran under the executing flag (`459`). -/
structure TraceEntry where
  pc : Nat
  op : Nat
  fExec : Bool
  deriving Repr, DecidableEq

/-- The offset after the last executed `OP_CODESEPARATOR` of a trace, `0` (the script's start) when none executed:
the reference's `pbegincodehash` as an offset, set to `script.begin()` (`407`) and to `pc` after the separator's
`GetOp` (`1445–1448`, `450`), which consumed the one opcode byte. An unexecuted separator (`fExec` false) does not
move it (`482`). -/
def afterLastSep (tr : List TraceEntry) : Nat :=
  tr.foldl (fun p e => if e.fExec && e.op == Op.OP_CODESEPARATOR then e.pc + 1 else p) 0

/-- **`afterLastSep_snoc`.** *What it says:* `afterLastSep` of a trace with one more instruction is that
instruction's offset plus one if it is an executed separator, else the trace's. *What it assumes:* nothing. -/
theorem afterLastSep_snoc (tr : List TraceEntry) (e : TraceEntry) :
    afterLastSep (tr ++ [e])
      = if e.fExec && e.op == Op.OP_CODESEPARATOR then e.pc + 1 else afterLastSep tr := by
  simp only [afterLastSep, List.foldl_append, List.foldl_cons, List.foldl_nil]

/-- The loop's iterations with their trace (#149's `codeSep_last` vocabulary; no semantics): `LoopTrace exec env s₀
st₀ s st tr` when `loop exec env s₀ st₀` reaches the bytes `s` with the state `st` through the instructions `tr`, in
order. The guards are `LoopReach`'s, one for one (`LoopTrace.reach`, `LoopReach.trace`: the two name the same
configurations); each step appends the instruction's offset `s₀.length - (op :: rest).length`, its opcode and the
`fExec` the loop computed for it (`459`). -/
inductive LoopTrace (exec : OpExec) (env : Env) (s₀ : Bytes) (st₀ : State) :
    Bytes → State → List TraceEntry → Prop where
  | refl : LoopTrace exec env s₀ st₀ s₀ st₀ []
  | step {op : Nat} {rest data : Bytes} {k : Nat} {st st' : State} {tr : List TraceEntry} :
      LoopTrace exec env s₀ st₀ (op :: rest) st tr →
      getOpTail op rest = some (data, k) →
      (!env.utxoAfterGenesis && data.length > Consensus.maxScriptElementSizeBeforeGenesis) = false →
      (op > Op.OP_16 &&
          (if op > Op.OP_16 then { st with opCount := st.opCount + 1 } else st).opCount
            > env.params.limits.maxOpsPerScript) = false →
      (isOpcodeDisabled op env.utxoEra &&
          (!env.utxoAfterGenesis || (st.cond.isActive && (!st.nonTopLevelReturn || op == Op.OP_RETURN)))) = false →
      execStep exec env op data rest k (st.cond.isActive && (!st.nonTopLevelReturn || op == Op.OP_RETURN))
          (if op > Op.OP_16 then { st with opCount := st.opCount + 1 } else st) = .cont st' →
      (!env.utxoAfterGenesis &&
          st'.stack.length + st'.alt.length > Consensus.maxStackElementsBeforeGenesis) = false →
      LoopTrace exec env s₀ st₀ (rest.drop k) st'
        (tr ++ [⟨s₀.length - (op :: rest).length, op,
          st.cond.isActive && (!st.nonTopLevelReturn || op == Op.OP_RETURN)⟩])

/-- **`LoopTrace.reach`.** *What it says:* a traced configuration is a reached one (`LoopReach`), so
`LoopReach.loop_eq` applies to it. *What it assumes:* nothing. -/
theorem LoopTrace.reach {exec : OpExec} {env : Env} {s₀ : Bytes} {st₀ : State} {s : Bytes} {st : State}
    {tr : List TraceEntry} (h : LoopTrace exec env s₀ st₀ s st tr) : LoopReach exec env s₀ st₀ s st := by
  induction h with
  | refl => exact .refl
  | step _ hp h1 h2 h3 hs h4 ih => exact .step ih hp h1 h2 h3 hs h4

/-- **`LoopReach.trace`.** *What it says:* every reached configuration has its trace. *What it assumes:* nothing. -/
theorem LoopReach.trace {exec : OpExec} {env : Env} {s₀ : Bytes} {st₀ : State} {s : Bytes} {st : State}
    (h : LoopReach exec env s₀ st₀ s st) : ∃ tr, LoopTrace exec env s₀ st₀ s st tr := by
  induction h with
  | refl => exact ⟨[], .refl⟩
  | step _ hp h1 h2 h3 hs h4 ih =>
    obtain ⟨tr, ht⟩ := ih
    exact ⟨_, .step ht hp h1 h2 h3 hs h4⟩

/-- **`drop_of_suffix`.** *What it says:* a suffix `s` of `s₀` is `s₀` from the offset `s₀.length - s.length`, the
offset of the current instruction. *What it assumes:* nothing. -/
theorem drop_of_suffix {s s₀ : Bytes} (h : s <:+ s₀) : s₀.drop (s₀.length - s.length) = s := by
  obtain ⟨pre, rfl⟩ := h
  have : (pre ++ s).length - s.length = pre.length := by simp
  rw [this, List.drop_left]

/-- **`codeSep_last`.** *The rule:* the scriptCode a signature check digests begins after the last executed
`OP_CODESEPARATOR` before the check, or at the script's start when none executed: `pbegincodehash` is set to
`script.begin()` and moved only by an executed `OP_CODESEPARATOR`, to the byte after it. *What it says:* for every
hook `exec` whose continuations leave `codeSep` as they found it (the frame `opExec_codeSep` proves for the
evaluator's own table, `Eval.opExec`), every run of `loop exec env` from a state whose `codeSep` is the script `s₀`
(as `evalScript` starts it, `codeSep_sites`) and every configuration `(s, st)` it reaches through the trace `tr`:
`st.codeSep` is `s₀` from the offset `afterLastSep tr`, the offset after the trace's last executed separator or `0`;
that offset is at or before the current instruction's, `s₀.length - s.length`; and `s` is `s₀` from that
instruction's offset. *What it assumes:* the hook's frame and the start. [SRC] `405–407` (`pc` and
`pbegincodehash` both `script.begin()`), `450` (`GetOp(pc, …)` advances `pc` past the instruction), `459`
(`fExec`), `482` (the switch runs only under `fExec` or for `OP_IF`…`OP_ENDIF`), `1445–1448` (`case
OP_CODESEPARATOR: pbegincodehash = pc;`), `1471–1473` and `1567–1569` ("Subset of script starting at the most
recent codeseparator to the end of the current script", `CScript scriptCode {pbegincodehash, pend}`). *Measured
contradiction:* none of the three signers measured under #145 and #147 is classed on the separator; their class,
`sighash.scriptcode.in-unlock.lock-only` (at @bsv/sdk 3.0.0 ruled `caller-scriptcode-required`, the class id
unchanged), is which script the scriptCode is drawn from (`scriptCode_run`, `scriptCode_last`)
(`docs/records/20261016-203024-s3-145d-signer-column-s3.md`, `docs/records/20261016-234915-s3-147-signer-column-s3.md`),
and @bsv/sdk's appended-lock behaviour (2.1.5 to 3.2.1)
(`docs/records/20261016-234806-s4b-147-tssdk-releases-s4b.md`) is that same scriptCode question, not a separator
one. -/
theorem codeSep_last (exec : OpExec) (env : Env)
    (hh : ∀ op data st st', exec op data env st = some (.ok st') → st'.codeSep = st.codeSep)
    (s₀ : Bytes) (st₀ : State) (h0 : st₀.codeSep = s₀) (s : Bytes) (st : State) (tr : List TraceEntry)
    (hr : LoopTrace exec env s₀ st₀ s st tr) :
    st.codeSep = s₀.drop (afterLastSep tr) ∧ afterLastSep tr ≤ s₀.length - s.length
      ∧ s₀.drop (s₀.length - s.length) = s := by
  suffices H : st.codeSep = s₀.drop (afterLastSep tr) ∧ afterLastSep tr ≤ s₀.length - s.length ∧ s <:+ s₀ from
    ⟨H.1, H.2.1, drop_of_suffix H.2.2⟩
  induction hr with
  | refl => exact ⟨by simp [h0, afterLastSep], Nat.zero_le _, List.suffix_refl _⟩
  | @step op rest data k st st' tr _ hp _ _ _ hs _ ih =>
    obtain ⟨ih1, ih2, ih3⟩ := ih
    have hb : (if op > Op.OP_16 then { st with opCount := st.opCount + 1 } else st).codeSep = st.codeSep := by
      split <;> rfl
    have hdrop : rest.drop k <:+ op :: rest :=
      (List.drop_suffix k rest).trans (List.suffix_cons op rest)
    have hlk : (rest.drop k).length < (op :: rest).length := by
      simp only [List.length_drop, List.length_cons]; omega
    have hl0 : (op :: rest).length ≤ s₀.length := ih3.length_le
    rw [afterLastSep_snoc]
    by_cases hsep : (st.cond.isActive && (!st.nonTopLevelReturn || op == Op.OP_RETURN)) = true ∧
        op = Op.OP_CODESEPARATOR
    · obtain ⟨hf, hop⟩ := hsep
      subst hop
      have hk : k = 0 := by
        simp only [getOpTail, Op.OP_CODESEPARATOR, Op.OP_PUSHDATA4] at hp
        cases hp; rfl
      subst hk
      rw [hf, execStep_codeseparator] at hs
      cases hs
      obtain ⟨pre, hpre⟩ := ih3
      subst hpre
      simp only [hf, beq_self_eq_true, Bool.and_self, ite_true, List.drop_zero]
      refine ⟨?_, ?_, (List.suffix_cons _ _).trans (List.suffix_append _ _)⟩
      · have : (pre ++ Op.OP_CODESEPARATOR :: rest).length - (Op.OP_CODESEPARATOR :: rest).length + 1
            = pre.length + 1 := by simp
        rw [this, List.drop_append]
        simp
      · simp only [List.length_append, List.length_cons]
        omega
    · have hc := execStep_codeSep exec env hh _ _ _ _ _ _ _ hsep hs
      have hne : ((st.cond.isActive && (!st.nonTopLevelReturn || op == Op.OP_RETURN))
          && op == Op.OP_CODESEPARATOR) = false := by
        cases hfx : (st.cond.isActive && (!st.nonTopLevelReturn || op == Op.OP_RETURN))
        · rfl
        · simp only [Bool.true_and, beq_eq_false_iff_ne]
          exact fun hop => hsep ⟨hfx, hop⟩
      simp only [hne, Bool.false_eq_true, ite_false]
      refine ⟨by rw [hc, hb, ih1], by omega, hdrop.trans ih3⟩

/-- **`codeSep_run_suffix`.** *The rule:* along a run, the scriptCode's start is a suffix of the script and the
instruction being run lies inside it (`407`, `1445–1448`). *What it says:* for every configuration the
evaluator's loop reaches from a state whose `codeSep` is the script `s₀` (as `evalScript` starts it,
`codeSep_sites`), `codeSep` is a suffix of `s₀` and the remaining bytes are a suffix of `codeSep`; a corollary of
`codeSep_last`, which names the suffix: `s₀` from the offset after the last executed separator. *What it
assumes:* the start. [SRC] `407` (`pbegincodehash = script.begin()`), `1445–1448` (`pbegincodehash = pc`, the
byte after the separator), `482`. -/
theorem codeSep_run_suffix (env : Env) (s₀ : Bytes) (st₀ : State) (h0 : st₀.codeSep = s₀) (s : Bytes) (st : State)
    (hr : LoopReach Eval.opExec env s₀ st₀ s st) : s <:+ st.codeSep ∧ st.codeSep <:+ s₀ := by
  obtain ⟨tr, ht⟩ := hr.trace
  obtain ⟨h1, h2, h3⟩ := codeSep_last Eval.opExec env
    (fun op data st st' h => opExec_codeSep op data env st st' h) s₀ st₀ h0 s st tr ht
  refine ⟨?_, h1 ▸ List.drop_suffix _ _⟩
  have hq : (s₀.drop (afterLastSep tr)).drop (s₀.length - s.length - afterLastSep tr)
      = s₀.drop (s₀.length - s.length) := by
    rw [List.drop_drop]; congr 1; omega
  rw [h1, ← h3, ← hq]
  exact List.drop_suffix _ _

/-- **`scriptCode_last`.** *The rule:* the scriptCode a signature check digests is the script being run from the
byte after its last executed `OP_CODESEPARATOR` before the check (from its start when none executed), with the
locking script appended when the check runs inside the unlocking script under `SCRIPT_CHRONICLE`. *What it says:*
`codeSep_last` composed with `scriptCode_unlock_site` at the state the check reads: in the environments
`verifyScript` builds from the word, for a run of the evaluator's loop over `script` from `evalScript`'s start state
(any stack and memory counter) that reaches the instruction `op` (an `OP_CHECKSIG`, `OP_CHECKSIGVERIFY`,
`OP_CHECKMULTISIG`, `OP_CHECKMULTISIGVERIFY` or any other) through the trace `tr`, the scriptCode of the state
handed to `op`'s step (the reached state with the op count's charge, `466–467`) is `script.drop (afterLastSep tr)
++ scriptPubKey` in the unlocking phase under CHRONICLE, `script.drop (afterLastSep tr)` in it without the bit, and
`script.drop (afterLastSep tr)` in the locking and P2SH-redeem phases (`checksigData` none). The bytes are those
before `CleanupScriptCode` (`1484`; the FORKID form is `scriptCode_unlock_site_forkid`). *What it assumes:* the
run from the start state. [SRC] `405–407`, `450`, `1445–1448`, `1471–1481` and `1567–1577` (the scriptCode and the
CHRONICLE append), `2338–2342` (the unlocking script with `&scriptPubKey`), `2358–2362` and `2402–2406` (`nullptr`).
*Measured contradiction:* `sighash.scriptcode.in-unlock.lock-only` (go-sdk v1.7.2, bsv-rs 0.5.0; at @bsv/sdk 3.0.0
`caller-scriptcode-required`), which is the which-script half of this statement, not the separator half
(`docs/records/20261016-203024-s3-145d-signer-column-s3.md`, `docs/records/20261016-234915-s3-147-signer-column-s3.md`). -/
theorem scriptCode_last (params : EvalParams) (ctx : Context) (script scriptPubKey : Bytes) (stack : List Bytes)
    (memUsed : Nat) (op : Nat) (rest : Bytes) (st : State) (tr : List TraceEntry) :
    (LoopTrace Eval.opExec (mkEnv params ctx params.flags.forkAdjust (some scriptPubKey)) script
        { stack := stack, memUsed := memUsed, codeSep := script } (op :: rest) st tr →
      (params.flags.chronicle = true →
        scriptCodeOf (mkEnv params ctx params.flags.forkAdjust (some scriptPubKey))
          (if op > Op.OP_16 then { st with opCount := st.opCount + 1 } else st)
          = script.drop (afterLastSep tr) ++ scriptPubKey)
      ∧ (params.flags.chronicle = false →
        scriptCodeOf (mkEnv params ctx params.flags.forkAdjust (some scriptPubKey))
          (if op > Op.OP_16 then { st with opCount := st.opCount + 1 } else st)
          = script.drop (afterLastSep tr)))
    ∧ (LoopTrace Eval.opExec (mkEnv params ctx params.flags.forkAdjust none) script
        { stack := stack, memUsed := memUsed, codeSep := script } (op :: rest) st tr →
      scriptCodeOf (mkEnv params ctx params.flags.forkAdjust none)
        (if op > Op.OP_16 then { st with opCount := st.opCount + 1 } else st)
        = script.drop (afterLastSep tr)) := by
  have hb : (if op > Op.OP_16 then { st with opCount := st.opCount + 1 } else st).codeSep = st.codeSep := by
    split <;> rfl
  have hh : ∀ env : Env, ∀ op data st st', Eval.opExec op data env st = some (.ok st') → st'.codeSep = st.codeSep :=
    fun env op data st st' h => opExec_codeSep op data env st st' h
  refine ⟨fun ht => ?_, fun ht => ?_⟩
  · have hc := hb.trans (codeSep_last _ _ (hh _) script _ rfl _ _ _ ht).1
    have hs := scriptCode_unlock_site params ctx scriptPubKey
      (if op > Op.OP_16 then { st with opCount := st.opCount + 1 } else st)
    rw [hc] at hs
    exact ⟨hs.1, hs.2.1⟩
  · have hc := hb.trans (codeSep_last _ _ (hh _) script _ rfl _ _ _ ht).1
    have hs := (scriptCode_unlock_site params ctx scriptPubKey
      (if op > Op.OP_16 then { st with opCount := st.opCount + 1 } else st)).2.2
    rw [hc] at hs
    exact hs

/-- **`scriptCode_run`.** *The rule:* a signature check that executes while the unlocking script runs under
`SCRIPT_CHRONICLE` digests the unlocking script from its scriptCode's start, which lies at or before the check
itself, followed by the locking script; so its scriptCode is never the locking script alone. *What it says:* in
the unlocking phase `verifyScript` builds (`mkEnv … (some scriptPubKey)`, its loop started by `evalScript` with
`codeSep` the unlocking script, `codeSep_sites`), at every configuration the evaluator's loop reaches, with the
instruction `op` next (an `OP_CHECKSIG`, `OP_CHECKSIGVERIFY`, `OP_CHECKMULTISIG` or any other), `codeSep` is a
suffix of the unlocking script that contains `op :: rest`; under the CHRONICLE bit `scriptCodeOf` is
`codeSep ++ scriptPubKey`, strictly longer than `scriptPubKey`, at the scriptCode before its cleanup (`1484`), so it differs from it. The state the check reads
differs from the reached one by the op count's charge only (`loop`, `466–467`), which leaves `codeSep` as it
was. *What it assumes:* the configuration reached from the unlocking phase's start state (`LoopReach`); the CHRONICLE bit for the third conjunct. [SRC] `407`, `1445–1448`, `1471–1481` and `1567–1577`
(the scriptCode and the CHRONICLE append), `2338–2342` (the unlocking script with `&scriptPubKey` as
`checksigData`). *Measured contradiction:* `sighash.scriptcode.in-unlock.lock-only`, a signer hashing
`scriptPubKey` alone where this scriptCode is longer (go-sdk v1.7.2 and bsv-rs 0.5.0; at @bsv/sdk 3.0.0 the
caller's obligation, `caller-scriptcode-required`; `docs/records/20261016-203024-s3-145d-signer-column-s3.md`,
`docs/records/20261016-234915-s3-147-signer-column-s3.md`). The bytes run from the scriptCode's start, which
the run fixes at the script's start or after an executed separator before `op` (`codeSep_sites`,
`execStep_codeSep`); which separator is the last, and the bytes from it, is `codeSep_last` and, at the check,
`scriptCode_last`. -/
theorem scriptCode_run (params : EvalParams) (ctx : Context) (scriptSig scriptPubKey : Bytes) (op : Nat)
    (rest : Bytes) (st : State)
    (hr : LoopReach Eval.opExec (mkEnv params ctx params.flags.forkAdjust (some scriptPubKey)) scriptSig
      { stack := [], memUsed := 0, codeSep := scriptSig } (op :: rest) st) :
    op :: rest <:+ st.codeSep ∧ st.codeSep <:+ scriptSig ∧
    (params.flags.chronicle = true →
      scriptCodeOf (mkEnv params ctx params.flags.forkAdjust (some scriptPubKey)) st = st.codeSep ++ scriptPubKey ∧
      scriptPubKey.length < (scriptCodeOf (mkEnv params ctx params.flags.forkAdjust (some scriptPubKey)) st).length ∧
      scriptCodeOf (mkEnv params ctx params.flags.forkAdjust (some scriptPubKey)) st ≠ scriptPubKey) := by
  obtain ⟨h1, h2⟩ := codeSep_run_suffix _ scriptSig _ rfl _ _ hr
  refine ⟨h1, h2, fun hc => ?_⟩
  have he := (scriptCode_unlock_site params ctx scriptPubKey st).1 hc
  have hlen : 0 < st.codeSep.length := by
    have := h1.length_le
    simp only [List.length_cons] at this
    omega
  have hlt : scriptPubKey.length < (st.codeSep ++ scriptPubKey).length := by
    rw [List.length_append]; omega
  refine ⟨he, he ▸ hlt, fun hq => ?_⟩
  rw [he] at hq
  rw [hq] at hlt
  exact Nat.lt_irrefl _ hlt

/-! ## The dispatch (`2112–2124`) -/

/-- **`digest_dispatch_chronicle`.** *The rule:* a hash type carrying the CHRONICLE bit is signed over the
original digest whatever its FORKID bit; FORKID without CHRONICLE, under FORKID enabled, over the BIP143 digest.
*What it says:* `sighash` is `sighashOriginal` for every type with `hasChronicle` and every value of the FORKID
switch, and `sighashBIP143` for a type with `hasForkId` and not `hasChronicle` when FORKID is enabled. *What it
assumes:* the bits named. [SRC] `2112–2124` (`if(enabledSighashForkid && sigHashType.hasForkId() &&
!sigHashType.hasChronicle())`); `sighashtype.h:86–87` (the two bits). *Measured contradiction:* bsv-rs 0.5.0's
default path computes the BIP143 digest for a type with the CHRONICLE bit (`src/primitives/bsv/sighash.rs:941-944`),
class `sighash.chronicle.bip143` (`docs/records/20261016-234915-s3-147-signer-column-s3.md`). -/
theorem digest_dispatch_chronicle (scriptCode : Bytes) (tx : Tx) (nIn : Nat) (t : SigHashType) (amount : Nat) :
    (t.hasChronicle = true → ∀ e : Bool, sighash scriptCode tx nIn t amount e = sighashOriginal scriptCode tx nIn t)
    ∧ (t.hasForkId = true → t.hasChronicle = false →
        sighash scriptCode tx nIn t amount true = sighashBIP143 scriptCode tx nIn t amount) :=
  ⟨fun hc e => sighash_original_of_chronicle _ _ _ _ _ e hc,
   fun hf hc => sighash_eq_bip143 _ _ _ _ _ hf hc⟩

/-! ## SIGHASH_SINGLE past the outputs (`2086–2100`; `2034–2083`) -/

/-- **`single_past_outputs`.** *The rule:* under SIGHASH_SINGLE with no output at the signed input's index, the
original digest is the constant `one`, never a hash, and the BIP143 digest hashes a preimage whose `hashOutputs`
is thirty-two zero bytes. *What it says:* for a type of base SINGLE and `nIn ≥ tx.outputs.length`,
`sighashOriginal` is `one256`; so is `sighash` for a type carrying the CHRONICLE bit, whatever the FORKID switch;
`bip143Outputs` is `zero32`; and `sighashBIP143` is SHA-256d of the preimage with `zero32` in the `hashOutputs`
field. *What it assumes:* the base type and the index. [SRC] `2086–2100` (`return one` when `nIn >=
txTo.vout.size()` under SINGLE); `2053–2061` (`hashOutputs` left zero when the SINGLE guard fails); `2063–2083`
(the preimage); `2112–2124` (the dispatch). *Measured contradiction:* bsv-rs 0.5.0's default path builds the BIP143
preimage with `hashOutputs` zero for this scope whatever the CHRONICLE bit (`src/primitives/bsv/sighash.rs:534-536`),
class `sighash.single.out-of-range.one` (`docs/records/20261016-234915-s3-147-signer-column-s3.md`); @bsv/sdk 3.0.0
hashes the full original serialization for the same scope (`primitives/TransactionSignature.ts:254-365`,
`:425-440`), the same class (`docs/records/20261016-203024-s3-145d-signer-column-s3.md`). -/
theorem single_past_outputs (scriptCode : Bytes) (tx : Tx) (nIn : Nat) (t : SigHashType) (amount : Nat)
    (hs : t.baseType = SIGHASH_SINGLE) (ho : tx.outputs.length ≤ nIn) :
    sighashOriginal scriptCode tx nIn t = one256
    ∧ (t.hasChronicle = true → ∀ e : Bool, sighash scriptCode tx nIn t amount e = one256)
    ∧ bip143Outputs tx nIn t = zero32
    ∧ sighashBIP143 scriptCode tx nIn t amount
        = sha256d (serVersion tx.version ++ bip143Prevouts tx t ++ bip143Sequence tx t
            ++ serOutPoint (inputAt tx nIn) ++ serScript scriptCode ++ le64 amount
            ++ le32 (inputAt tx nIn).sequence ++ zero32 ++ le32 tx.lockTime ++ t.serialize) := by
  have h1 := sighashOriginal_single_no_output scriptCode tx nIn t hs ho
  have h3 := bip143Outputs_single_past tx nIn t hs ho
  refine ⟨h1, fun hc e => (sighash_original_of_chronicle _ _ _ _ _ e hc).trans h1, h3, ?_⟩
  simp only [sighashBIP143, preimageBIP143, h3]

end BsvScript.Properties
