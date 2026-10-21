import BsvChain.Properties.Utxo

/-!
# Oracle substitution and recorded agreement (#76)

Statements quantify over every script oracle. Recording is a finite map
construction, not a cryptographic hypothesis or a claim about a node run.
The inherited UTXO laws already quantify over the oracle without restriction.
[SRC] src/validation.cpp:2503–2542,2693–2709,3326–3434 at 6504a3af.
-/

namespace BsvChain.Properties
open BsvScript.Tx BsvScript.Params BsvScript.Machine

/-- A covered key returns precisely its recorded verdict. The sole assumption
is lookup success, including the column and complete effective parameters.
This is the loader-to-oracle boundary, independent of the recorded producer.
[SRC] src/validation.cpp:2503–2542 at 6504a3af. -/
theorem recordedOracle_of_lookup (recorded : RecordedVerdicts) (column : OracleColumn)
    (call : ScriptCall) (v : Verdict) (h : recorded.lookup ⟨column, call⟩ = some v) :
    call.run (recordedOracle recorded column) = v := by
  cases call
  simpa [ScriptCall.run, recordedOracle] using congrArg (fun o => o.getD recordedOracleMissing) h

/-- An uncovered call declines by name. No evaluation or other column can
supply a guessed verdict, even if most of the spend context agrees.
[SRC] src/validation.cpp:2538–2542 at 6504a3af. -/
theorem recordedOracle_missing (recorded : RecordedVerdicts) (column : OracleColumn)
    (call : ScriptCall) (h : recorded.lookup ⟨column, call⟩ = none) :
    call.run (recordedOracle recorded column) = recordedOracleMissing := by
  cases call
  simpa [ScriptCall.run, recordedOracle] using congrArg (fun o => o.getD recordedOracleMissing) h

/-- Materialization preserves every covered call's answer for every producer.
Repeated identical calls have identical values because the producer is a
function. No uniqueness or signature-validity hypothesis is needed.
[SRC] src/validation.cpp:2523–2542 at 6504a3af. -/
theorem recordOracle_lookup (oracle : ScriptOracle) (column : OracleColumn)
    (calls : List ScriptCall) (call : ScriptCall) (h : call ∈ calls) :
    (recordOracle oracle column calls).lookup ⟨column, call⟩ = some (call.run oracle) := by
  induction calls with
  | nil => simp at h
  | cons head rest ih =>
    by_cases he : call = head
    · subst call; simp [recordOracle]
    · have hn : (⟨column, call⟩ : RecordedKey) ≠ ⟨column, head⟩ := by
        intro hk
        exact he (congrArg RecordedKey.call hk)
      rw [recordOracle, Finmap.lookup_insert_of_ne _ hn]
      exact ih ((List.mem_cons.mp h).resolve_left he)

/-- For ANY oracle, the oracle and a map recorded from it agree on every
covered call: replaying a recording returns the recorded producer's verdict.
[SRC] src/validation.cpp:2523–2542 at 6504a3af. -/
theorem recorded_oracle_agree (oracle : ScriptOracle) (column : OracleColumn)
    (calls : List ScriptCall) (call : ScriptCall) (h : call ∈ calls) :
    call.run (recordedOracle (recordOracle oracle column calls) column) =
      call.run oracle :=
  recordedOracle_of_lookup _ _ _ _ (recordOracle_lookup _ _ _ _ h)

/-- The evaluator and a map recorded from it agree on every covered call.
This proves the construction, including actual ECDSA as a definition; the
executable separately checks columns already committed as corpus evidence.
The general form is `recorded_oracle_agree`, for every oracle; this theorem is
its instance at the evaluator. [SRC] src/validation.cpp:2523–2542 at 6504a3af. -/
theorem recorded_eval_agree (column : OracleColumn) (calls : List ScriptCall)
    (call : ScriptCall) (h : call ∈ calls) :
    call.run (recordedOracle (recordOracle evalOracle column calls) column) =
      call.run evalOracle :=
  recorded_oracle_agree evalOracle column calls call h

/-- The resource selector leaves the word unchanged. Thus block-word policy
re-checks cannot be collapsed into ordinary block derivation. Resource limits
can differ, as checked by the corpus's selector boundary. This is a
definition-level law: the proof is `rfl`, because the selector is passed only
to the limits constructor; it adds no transition or cryptographic fact.
[SRC] src/validation.cpp:705–717,2693–2707 at 6504a3af. -/
theorem inputEvalParams_flags_independent (cfg : NodeConfig) (params : BsvChain.ChainParams)
    (height tipHeight : Nat) (flags : Flags) (coin : Coin) (a b : Bool) :
    (inputEvalParams cfg params height tipHeight flags a coin).flags =
      (inputEvalParams cfg params height tipHeight flags b coin).flags := rfl

/-- Pointwise equal oracles yield the same applyTx result, including undo and
rejections, for all configurations, times, network parameters and operator
lists. This permits substitution without weakening any inherited UTXO law.
The conservation, membership, retained/added lookup, determinism and undo
statements in Properties.Utxo already have unrestricted oracle parameters.
[SRC] src/validation.cpp:2480–2495,3326–3434 at 6504a3af. -/
theorem applyTx_oracle_ext (s : UtxoSet) (cfg : NodeConfig) (ctx : UtxoContext)
    (lists : FrozenLists) (a b : ScriptOracle) (tx : Tx)
    (h : ∀ tx prevouts input coinHeight spendHeight params,
      a tx prevouts input coinHeight spendHeight params =
      b tx prevouts input coinHeight spendHeight params) :
    applyTx s cfg ctx lists a tx = applyTx s cfg ctx lists b tx := by
  have he : a = b := funext fun tx => funext fun prevouts => funext fun input =>
    funext fun coinHeight => funext fun spendHeight => funext fun params =>
      h tx prevouts input coinHeight spendHeight params
  rw [he]

end BsvChain.Properties
