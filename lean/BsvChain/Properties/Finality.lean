import BsvChain.Finality

/-! # Finality and fee properties (#60)

The statements concern the consensus predicates and fee stage, with arbitrary
height, time and values. [SRC] src/validation.cpp:227–247,2646–2663 at 6504a3af.
-/

namespace BsvChain.Properties
open BsvScript.Tx BsvScript.TxContext

/-- A zero lock time makes a transaction final at every height and time.
The only assumption is `lockTime = 0`; input sequences are unrestricted.
This proves the early return [SRC] src/validation.cpp:229–231 at 6504a3af. -/
theorem isFinalTx_lockTime_zero (tx : Tx) (height : Nat) (time : Int) (h : tx.lockTime = 0) :
    isFinalTx tx height time = true := by
  simp [isFinalTx, h]

/-- All final input sequences disable absolute locking for every lock time,
height and time. The premise covers each input, including the empty list.
This is the final loop's success [SRC] src/validation.cpp:240–247 at 6504a3af. -/
theorem isFinalTx_all_sequences_final (tx : Tx) (height : Nat) (time : Int)
    (h : ∀ input ∈ tx.inputs, input.sequence = SEQUENCE_FINAL) :
    isFinalTx tx height time = true := by
  have hall : tx.inputs.all (fun input => input.sequence == SEQUENCE_FINAL) = true := by
    simp only [List.all_eq_true, beq_iff_eq]
    exact h
  simp [isFinalTx, hall]

/-- A successful fee check returns a nonnegative fee. Acceptance here is
exactly `fee valueIn valueOut = .ok amount`, without assuming UTXO availability
or full admission. This isolates the value-preservation ingredient #61 needs.
[SRC] src/validation.cpp:2646–2663 at 6504a3af. -/
theorem fee_nonnegative (valueIn valueOut amount : Int)
    (h : fee valueIn valueOut = .ok amount) : 0 ≤ amount := by
  unfold fee at h
  split at h
  · contradiction
  · split at h
    · cases h
      omega
    · contradiction

/-- [M] 2026-10-13 (#68): on naturals, insertion sort and merge sort return
the same list, since both are sorted permutations of the input and the order
is antisymmetric. The median's sort changed presentation, not value.
[SRC] src/block_index.h:722–737 at 6504a3af. -/
theorem insertionSort_eq_mergeSort (l : List Nat) :
    l.insertionSort (· ≤ ·) = l.mergeSort (fun a b => decide (a ≤ b)) := by
  apply List.Perm.eq_of_pairwise (le := fun a b => a ≤ b)
  · intro a b _ _ hab hba
    exact Nat.le_antisymm hab hba
  · exact List.pairwise_insertionSort _ _
  · exact (List.pairwise_mergeSort (fun a b c hab hbc => by simp_all; omega)
      (fun a b => by simp; omega) l).imp (by simp)
  · exact (List.perm_insertionSort _ _).trans (List.mergeSort_perm _ _).symm

/-- A median taken from a nonempty chain with positive span is one of that
chain's times. Sorting permutes the selected ancestors, so the result is an
observed time, including on short chains; no averaging creates a timestamp.
[SRC] src/block_index.h:722–737 at 6504a3af. -/
theorem medianTimePast_mem (times : List Nat) (span : Nat)
    (ht : times ≠ []) (hs : 0 < span) : medianTimePast times span ∈ times := by
  unfold medianTimePast
  dsimp only
  split
  · rename_i heq
    have hlen := congrArg List.length heq
    simp only [List.length_insertionSort, List.length_take, List.length_nil] at hlen
    have hpos : 0 < times.length := List.length_pos_iff.mpr ht
    omega
  · rename_i t ts heq
    apply List.mem_of_mem_take
    apply (List.mem_insertionSort (· ≤ ·)).mp
    rw [heq]
    exact List.getElem_mem _

/-- Below the signed-int boundary, the tip and block judges agree on finality
for every transaction and ancestor list. Both use the successor height and
median: the tip has the median flag, and CSV is active for the block. Their
non-final outcomes retain the policy hold versus block rejection distinction.
The nonnegative median below 2^31 is unchanged by the tip's narrowing, so this
width correction has no effect in that range.
[SRC] src/validation.cpp:1101–1106,5998–6037,6042–6056,6067–6074 at 6504a3af. -/
theorem tip_block_finality_agree_of_mtp_lt (params : ChainParams) (cfg : NodeConfig)
    (tx : Tx) (tipHeight blockTime csvHeight : Nat) (times : List Nat) (now : Int)
    (hcsv : params.csvHeight = some csvHeight) (hactive : csvHeight ≤ tipHeight + 1)
    (hmtp : medianTimePast times cfg.medianTimeSpan < 2 ^ 31) :
    (contextualCheckTransactionForCurrentBlock params tx tipHeight
      (medianTimePast times cfg.medianTimeSpan) now LOCKTIME_MEDIAN_TIME_PAST = .ok true) ↔
    (contextualCheckTransactionForBlock params cfg tx (tipHeight + 1) blockTime times =
      some (.ok true)) := by
  have hlow : (medianTimePast times cfg.medianTimeSpan : Int) < 2 ^ 31 := by omega
  have hmod : (medianTimePast times cfg.medianTimeSpan : Int) % 2 ^ 32 =
      medianTimePast times cfg.medianTimeSpan := Int.emod_eq_of_lt (by omega) (by omega)
  have hnarrow : narrowToInt32 (medianTimePast times cfg.medianTimeSpan) =
      (medianTimePast times cfg.medianTimeSpan : Int) := by
    unfold narrowToInt32
    rw [hmod]
    simp only [Int.toNat_natCast, BsvScript.Tx.toInt32, ite_eq_left hmtp]
  by_cases hfinal : isFinalTx tx (tipHeight + 1) (medianTimePast times cfg.medianTimeSpan) = true
  all_goals simp [contextualCheckTransactionForCurrentBlock, LOCKTIME_MEDIAN_TIME_PAST,
    hnarrow, contextualCheckTransactionForBlock, blockFinalityCutoff, hcsv, hactive,
    contextualCheckTransaction, hfinal]
  split <;> simp

end BsvChain.Properties
