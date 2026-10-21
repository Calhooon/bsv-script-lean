import BsvScript.TxRules
/-!
# BsvScript.Properties.TxValue

The output-side value bounds of `checkTransactionCommon` at the bitcoin-sv pin
in `docs/PROVENANCE.md`. The proofs use `checkTransactionCommon_ok_iff` and
`checkOutputs_ok_iff`, whose bridge to the executable loop is
`checkTransactionCommon_eq` and `forIn_eq_checkOutputs`.

These statements concern the transaction's outputs. The input-side UTXO set
and fees belong to the transaction state machine (S6, #58; `docs/DESIGN-S6.md`:
`applyTx`, #61) and are outside these statements.
-/

namespace BsvScript.Properties
open BsvScript.Tx BsvScript.TxRules

/-- **The total output value is bounded.** *What it says:* the sum of an accepted
transaction's output values is at most `MAX_MONEY`. *What it assumes:*
`checkTransactionCommon` accepts, with arbitrary size and sigop limits and era.
*Why it matters:* the running total is tested by `moneyRange` after every
addition, including the final one ([SRC] `validation.cpp:553–557`,
`amount.h:130`). This is an output-side bound; the input-side UTXO set and fees
are the transaction state machine's (S6, #58; `docs/DESIGN-S6.md`) and are outside
this statement. -/
theorem checkTransactionCommon_total_le_maxMoney (tx : Tx) (maxSigOps maxSize : Nat)
    (preGenesis : Bool)
    (h : checkTransactionCommon tx maxSigOps maxSize preGenesis = .ok ()) :
    (tx.outputs.map (·.value)).sum ≤ MAX_MONEY := by
  exact ((checkTransactionCommon_ok_iff tx maxSigOps maxSize preGenesis).1 h).2.2.2.1

/-- **Every output value is in range.** *What it says:* every output of an
accepted transaction has value below `2^63` and at most `MAX_MONEY`.
*What it assumes:* `checkTransactionCommon` accepts, with arbitrary size and
sigop limits and era. *Why it matters:* the output checks exclude negative
serialized `int64` values and values above the money bound ([SRC]
`validation.cpp:543–546`, `validation.cpp:548–551`, `amount.h:130`); each
natural-valued output is bounded by the accepted total, and `MAX_MONEY < 2^63`.
This is an output-side bound; the input-side UTXO set and fees are the transaction
state machine's (S6, #58; `docs/DESIGN-S6.md`) and are outside this statement. -/
theorem checkTransactionCommon_outputs_in_range (tx : Tx) (maxSigOps maxSize : Nat)
    (preGenesis : Bool)
    (h : checkTransactionCommon tx maxSigOps maxSize preGenesis = .ok ()) :
    ∀ o ∈ tx.outputs, o.value < 2 ^ 63 ∧ o.value ≤ MAX_MONEY := by
  intro o ho
  have hvalue : ∀ os : List TxOut, o ∈ os → o.value ≤ (os.map (·.value)).sum := by
    intro os
    induction os with
    | nil => simp
    | cons p os ih =>
      intro hm
      simp only [List.mem_cons] at hm
      simp only [List.map_cons, List.sum_cons]
      rcases hm with rfl | hm
      · omega
      · have := ih hm
        omega
  have hle := Nat.le_trans (hvalue tx.outputs ho)
    (checkTransactionCommon_total_le_maxMoney tx maxSigOps maxSize preGenesis h)
  refine ⟨?_, hle⟩
  simp only [MAX_MONEY, Nat.reducePow] at hle ⊢
  omega

/-- **The output loop returns the sum.** *What it says:* for an accepted
transaction, `checkOutputs tx.outputs 0` returns exactly the sum of the output
values. *What it assumes:* `checkTransactionCommon` accepts, with arbitrary size
and sigop limits and era. *Why it matters:* `checkOutputs` is the executable
loop's denotation (`checkTransactionCommon_eq`, `forIn_eq_checkOutputs`); its
initial total is zero and each step adds the output value ([SRC]
`validation.cpp:542–558`, `validation.cpp:553`). This is an output-side
accounting identity; the input-side UTXO set and fees are the transaction state
machine's (S6, #58; `docs/DESIGN-S6.md`) and are outside this statement. -/
theorem checkTransactionCommon_output_total_eq_sum (tx : Tx) (maxSigOps maxSize : Nat)
    (preGenesis : Bool)
    (h : checkTransactionCommon tx maxSigOps maxSize preGenesis = .ok ()) :
    checkOutputs tx.outputs 0 = .ok (tx.outputs.map (·.value)).sum := by
  apply (checkOutputs_ok_iff tx.outputs 0 _ (Nat.zero_le _)).2
  exact ⟨by simpa using checkTransactionCommon_total_le_maxMoney tx maxSigOps maxSize preGenesis h,
    by simp⟩

end BsvScript.Properties
