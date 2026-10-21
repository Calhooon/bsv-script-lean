import BsvChain.Params
import BsvScript.Tx
import BsvScript.TxContext
import BsvScript.TxRules
import BsvScript.Flags

/-!
# Transaction finality and the fee (#60)

The predicates below transcribe bitcoin-sv v1.2.3 at
`6504a3aff65ba97c0f6c80962b033e35ecbfed4b`. The tip judge, holding and expiry
are policy; the block finality path is consensus.
Ancestor times are a list in newest-to-oldest order, including the named tip;
#63 can project its header chain to this input. Effective `ChainParams` include
any scenario's activation overrides. Time is supplied, never read here.
The fee is the arithmetic stage of [SRC] src/validation.cpp:2646–2663 at
6504a3af; #61 owns the preceding per-coin and aggregate input bounds.
-/

namespace BsvChain
open BsvScript.Tx BsvScript.TxContext

/-- DESIGN-S6 §3's code namespaces. Node validation codes include both wire and
internal values [SRC] src/consensus/validation.h:14–24 and
src/validation.h:1150–1163 at 6504a3af. RPC codes remain signed. -/
inductive RejectCode where
  | node (code : Nat)
  | rpc (code : Int)
  deriving DecidableEq, Repr

namespace RejectCode

/-- Node code encoding, not a policy limit. [SRC] src/consensus/validation.h:14–24 at 6504a3af. -/
def REJECT_MALFORMED : RejectCode := .node 0x01

/-- Node code encoding, not a policy limit. [SRC] src/consensus/validation.h:14–24 at 6504a3af. -/
def REJECT_INVALID : RejectCode := .node 0x10

/-- Node code encoding, not a policy limit. [SRC] src/consensus/validation.h:14–24 at 6504a3af. -/
def REJECT_OBSOLETE : RejectCode := .node 0x11

/-- Node code encoding, not a policy limit. [SRC] src/consensus/validation.h:14–24 at 6504a3af. -/
def REJECT_DUPLICATE : RejectCode := .node 0x12

/-- Node code encoding, not a policy limit. [SRC] src/consensus/validation.h:14–24 at 6504a3af. -/
def REJECT_SOFT_CONSENSUS_FREEZE : RejectCode := .node 0x13

/-- Node code encoding, not a policy limit. [SRC] src/consensus/validation.h:14–24 at 6504a3af. -/
def REJECT_NONSTANDARD : RejectCode := .node 0x40

/-- Node code encoding, not a policy limit. [SRC] src/consensus/validation.h:14–24 at 6504a3af. -/
def REJECT_DUST : RejectCode := .node 0x41

/-- Node code encoding, not a policy limit. [SRC] src/consensus/validation.h:14–24 at 6504a3af. -/
def REJECT_INSUFFICIENTFEE : RejectCode := .node 0x42

/-- Node code encoding, not a policy limit. [SRC] src/consensus/validation.h:14–24 at 6504a3af. -/
def REJECT_CHECKPOINT : RejectCode := .node 0x43

/-- Node code encoding, not a policy limit. [SRC] src/consensus/validation.h:14–24 at 6504a3af. -/
def REJECT_TOOBUSY : RejectCode := .node 0x44

/-- Node code encoding, not a policy limit. [SRC] src/consensus/validation.h:14–24 at 6504a3af. -/
def REJECT_RATE_EXCEEDED : RejectCode := .node 0x45

/-- Node code encoding, not a policy limit. [SRC] src/validation.h:1150–1163 at 6504a3af. -/
def REJECT_INTERNAL : RejectCode := .node 0x100

/-- Node code encoding, not a policy limit. [SRC] src/validation.h:1150–1163 at 6504a3af. -/
def REJECT_HIGHFEE : RejectCode := .node 0x100

/-- Node code encoding, not a policy limit. [SRC] src/validation.h:1150–1163 at 6504a3af. -/
def REJECT_ALREADY_KNOWN : RejectCode := .node 0x101

/-- Node code encoding, not a policy limit. [SRC] src/validation.h:1150–1163 at 6504a3af. -/
def REJECT_CONFLICT : RejectCode := .node 0x102

/-- Node code encoding, not a policy limit. [SRC] src/validation.h:1150–1163 at 6504a3af. -/
def REJECT_MEMPOOL_FULL : RejectCode := .node 0x103

/-- Only positive, non-internal node codes have a P2P reject representation.
RPC errors retain their signed, separate namespace.
[SRC] src/validation.cpp:1934–1950 at 6504a3af. -/
def wireValue : RejectCode → Option Nat
  | .node n => if 0 < n && n < 0x100 then some n else none
  | .rpc _ => none

end RejectCode

/-- The rejection record shared by #60, #61, #62 and #76, as DESIGN-S6 §1.4 specifies.
Code and reason remain separate [SRC] src/consensus/validation.h:26–42 at
6504a3af. A held transaction never constructs this record. -/
structure Reject where
  code : RejectCode
  reason : String
  deriving DecidableEq, Repr

/-- Consensus median of the most recent `span` ancestors, using the sorted
element at length / 2, including the upper middle of an even short chain.
[SRC] src/block_index.h:720–737 at 6504a3af. The default reads the existing
census field (11 at the pin). Empty input or zero span returns 0 as a total
extension; the source's live index is nonempty, and the no-parent block case
uses 0 [SRC] src/validation.cpp:6055–6056 at 6504a3af. [M] 2026-10-13 (#68):
the sort is insertion sort, which the kernel reduces (merge sort's
well-founded recursion does not), so concrete chain runs can be kernel-checked;
`insertionSort_eq_mergeSort` proves it the same sorted list as before. -/
def medianTimePast (times : List Nat) (span : Nat := NodeConfig.defaults.medianTimeSpan) : Nat :=
  let sorted := (times.take span).insertionSort (· ≤ ·)
  match sorted with
  | [] => 0
  | t :: ts => (t :: ts)[(t :: ts).length / 2]'(by simp; omega)

/-- Consensus absolute finality, reused by block validation and admission.
The threshold and final sequence are the interpreter's existing definitions.
[SRC] src/validation.cpp:227–247 at 6504a3af. Equality with the height or time
limit is non-final unless every input disables the lock. -/
def isFinalTx (tx : Tx) (height : Nat) (time : Int) : Bool :=
  if tx.lockTime = 0 then true
  else if (tx.lockTime : Int) < (if tx.lockTime < LOCKTIME_THRESHOLD then (height : Int) else time) then true
  else tx.inputs.all (fun input => input.sequence == SEQUENCE_FINAL)

/-- Consensus sequence-lock flag encoding [SRC] src/consensus/consensus.h:84–91
at 6504a3af. This is an encoding, not an additional configuration parameter. -/
def LOCKTIME_VERIFY_SEQUENCE : Nat := 1

/-- Consensus median-time flag encoding [SRC] src/consensus/consensus.h:84–91
at 6504a3af. This is an encoding, not an additional configuration parameter. -/
def LOCKTIME_MEDIAN_TIME_PAST : Nat := 2

/-- Admission's lock-time word by era: median time always, sequence locks only
before Genesis. Policy selects this word; the block path also reuses it.
[SRC] src/policy/policy.h:246–255 and src/validation.cpp:1096–1105,3465–3469
at 6504a3af. -/
def standardNonFinalVerifyFlags (era : BsvScript.Params.Era) : Nat :=
  if era.genesisActive then LOCKTIME_MEDIAN_TIME_PAST
  else LOCKTIME_MEDIAN_TIME_PAST ||| LOCKTIME_VERIFY_SEQUENCE

/-- Consensus finality on the block path; policy permits holding after Genesis
off that path. `ok false` means non-final with no rejection, `ok true` means
this check passed. Neither means full transaction admission.
[SRC] src/validation.cpp:5977–5996 at 6504a3af. -/
def contextualCheckTransaction (params : ChainParams) (tx : Tx)
    (height : Nat) (cutoff : Int) (fromBlock : Bool) : Except Reject Bool :=
  if isFinalTx tx height cutoff then .ok true
  else if !fromBlock && (BsvScript.Params.protocolEraOf
      params.genesisHeight params.chronicleHeight height).genesisActive then .ok false
  else .error ⟨.node 0x10, "bad-txns-nonfinal"⟩

/-- The tip caller's signed integral narrowing conversion: keep the low 32 bits
and reuse the interpreter's `Tx.toInt32` for their signed reading. C++17 [conv.integral]
makes an out-of-range conversion to a signed type implementation-defined;
this models the two's-complement result on the pin's build targets.
The node's `int64_t` median [SRC] src/block_index.h:722–737 enters the `int`
parameter [SRC] src/validation.cpp:5998–6004 through the explicitly suppressed
call [SRC] src/validation.cpp:1101–1106, all at 6504a3af. -/
def narrowToInt32 (value : Int) : Int :=
  BsvScript.Tx.toInt32 ((value % (2 ^ 32)).toNat)

/-- The policy admission judge at the tip: successor height, narrowed median
under its flag, otherwise explicit signed adjusted `now`. The median input
represents the caller's `int64_t`; `narrowToInt32` models its conversion to the
callee's `int`, then the cutoff widens back to `int64_t`. Negative flags clamp
to zero [SRC] src/validation.cpp:1101–1106,5998–6037 at 6504a3af. -/
def contextualCheckTransactionForCurrentBlock (params : ChainParams) (tx : Tx)
    (tipHeight : Nat) (tipMedianTimePast now : Int) (flags : Int) : Except Reject Bool :=
  let cutoff := if flags.toNat &&& LOCKTIME_MEDIAN_TIME_PAST != 0 then narrowToInt32 tipMedianTimePast else now
  contextualCheckTransaction params tx (tipHeight + 1) cutoff false

/-- Consensus block cutoff: previous-block median from CSVHeight, otherwise
the block's own time. This path retains the full `int64_t` median and cutoff;
it does not narrow to `int` [SRC] src/validation.cpp:6042–6056,6067–6074 at 6504a3af.
An absent CSV assignment yields `none`, preserving PARAMETERS §8.3's unresolved
network data; it never silently disables BIP113. -/
def blockFinalityCutoff (params : ChainParams) (cfg : NodeConfig)
    (height blockTime : Nat) (previousTimes : List Nat) : Option Nat := do
  let csvHeight ← params.csvHeight
  return if height ≥ csvHeight then medianTimePast previousTimes cfg.medianTimeSpan else blockTime

/-- Consensus transaction finality within a block, including the rejection even
after Genesis [SRC] src/validation.cpp:5977–5996,6067–6074 at 6504a3af.
`none` records an unresolved network cutoff, not a node rejection. -/
def contextualCheckTransactionForBlock (params : ChainParams) (cfg : NodeConfig)
    (tx : Tx) (height blockTime : Nat) (previousTimes : List Nat) : Option (Except Reject Bool) := do
  let cutoff ← blockFinalityCutoff params cfg height blockTime previousTimes
  return contextualCheckTransaction params tx height cutoff true

/-- The finality stage's status, before the remaining admission checks: `final`
continues validation, `heldNonFinal` routes to the non-final pool if they pass.
Policy status [SRC] src/validation.cpp:1107–1124,912–926 at 6504a3af.
#62 defines the complete `TxVerdict` and pool transition. -/
inductive FinalityStatus where
  | final
  | heldNonFinal
  deriving DecidableEq, Repr

/-- Policy hold predicate using the existing census capacity. Only zero
configured memory produces this early `non-final-pool-full` refusal; occupancy,
replacement and dependency checks belong to #62.
[SRC] src/validation.cpp:1117–1137 at 6504a3af; internal code
[SRC] src/validation.h:1162–1163 at 6504a3af. -/
def routeNonFinal (cfg : NodeConfig) (isFinal : Bool) : Except Reject FinalityStatus :=
  if isFinal then .ok .final
  else if cfg.maxMempoolNonFinal = 0 then .error ⟨.node 0x103, "non-final-pool-full"⟩
  else .ok .heldNonFinal

/-- Admission policy's finality stage, including the pre-Genesis nonstandard
code mapping. The era selecting the flags is the tip's; the contextual judge's
era is the successor's [SRC] src/validation.cpp:1094–1124,5998–6037 at 6504a3af.
All later admission checks still belong to #62. -/
def mempoolFinality (params : ChainParams) (cfg : NodeConfig) (tx : Tx)
    (tipHeight : Nat) (tipTimes : List Nat) (now : Int) : Except Reject FinalityStatus :=
  let era := BsvScript.Params.protocolEraOf params.genesisHeight params.chronicleHeight tipHeight
  match contextualCheckTransactionForCurrentBlock params tx tipHeight
      (medianTimePast tipTimes cfg.medianTimeSpan) now (standardNonFinalVerifyFlags era) with
  | .error reject => .error { reject with code := .node 0x40 }
  | .ok final => routeNonFinal cfg final

/-- Policy expiry predicate at an explicit maintenance event. Signed subtraction
preserves clock rollback; expiry includes equality. #62 must check newly final
transactions for revalidation before applying expiry.
[SRC] src/time_locked_mempool.cpp:627–660 at 6504a3af. The census field is already
in seconds [SRC] src/time_locked_mempool.cpp:403–404 at 6504a3af. -/
def nonFinalExpired (cfg : NodeConfig) (insertionTime now : Int) : Bool :=
  now - insertionTime ≥ (cfg.mempoolNonFinalExpiry : Int)

/-- Consensus BIP68's last invalid height and time, initially -1 for both.
[SRC] src/validation.cpp:261–267 at 6504a3af. -/
structure SequenceLock where
  minHeight : Int := -1
  minTime : Int := -1
  deriving DecidableEq, Repr

/-- Consensus BIP68 calculation, with an explicit ancestor-MTP lookup. Disabled
inputs are ignored; the unsigned version comparison matches the interpreter.
Time units are 2^9 seconds, and subtraction is signed, including zero locks.
[SRC] src/validation.cpp:256–324 and src/primitives/transaction.h:121–129 at
6504a3af. `none` means a malformed height vector or absent required ancestor;
the source asserts a matching vector and an existing ancestor. Lock-point cache
mutation is outside this pure calculation. -/
def calculateSequenceLocks (tx : Tx) (flags : Nat) (prevHeights : List Nat)
    (ancestorMtp : Nat → Option Nat) : Option SequenceLock := do
  if prevHeights.length != tx.inputs.length then none
  else if (tx.version % (2 ^ 32)).toNat < 2 || flags &&& LOCKTIME_VERIFY_SEQUENCE == 0 then
    some {}
  else
    (tx.inputs.zip prevHeights).foldlM (fun locks (input, coinHeight) => do
      let sequence := input.sequence
      if sequence &&& SEQUENCE_LOCKTIME_DISABLE_FLAG != 0 then return locks
      let relative := sequence &&& SEQUENCE_LOCKTIME_MASK
      if sequence &&& SEQUENCE_LOCKTIME_TYPE_FLAG != 0 then
        let coinTime ← ancestorMtp (coinHeight - 1)
        return { locks with minTime := max locks.minTime ((coinTime : Int) + (relative * 2 ^ 9 : Nat) - 1) }
      else
        return { locks with minHeight := max locks.minHeight ((coinHeight : Int) + relative - 1) }) {}

/-- Consensus BIP68 evaluation uses strict bounds on candidate height and its
parent's median time [SRC] src/validation.cpp:326–341 at 6504a3af. -/
def evaluateSequenceLocks (height previousMedianTimePast : Nat) (locks : SequenceLock) : Bool :=
  locks.minHeight < (height : Int) && locks.minTime < (previousMedianTimePast : Int)

/-- Project an ancestor's median from newest-to-oldest times, preserving missing
ancestry explicitly. This is the header lookup consumed by BIP68, not another
consensus rule [SRC] src/validation.cpp:295–297 and src/block_index.h:722–737
at 6504a3af. #63 can refine this projection from its header chain. -/
def ancestorMedianTimePast (cfg : NodeConfig) (tipHeight : Nat) (times : List Nat)
    (height : Nat) : Option Nat :=
  if height > tipHeight || times.length ≤ tipHeight - height then none
  else some (medianTimePast (times.drop (tipHeight - height)) cfg.medianTimeSpan)

/-- The mempool BIP68 judge, a consensus relative-lock predicate before Genesis.
After Genesis at the tip it returns true before any input/ancestor computation.
Before it, absent/spent coins are `none`, the existing `mempoolHeight` sentinel
is resolved to tip + 1, and fresh locks are evaluated at that successor.
[SRC] src/validation.cpp:362–406,434–435 at 6504a3af. Cache reuse and its ancestry
invariant are #62's responsibility; this definition computes fresh lock points. -/
def checkSequenceLocks (params : ChainParams) (cfg : NodeConfig) (tx : Tx)
    (tipHeight : Nat) (tipTimes : List Nat) (coinHeights : List (Option Nat))
    (flags : Nat) : Bool :=
  if (BsvScript.Params.protocolEraOf params.genesisHeight params.chronicleHeight tipHeight).genesisActive then true
  else
    let result : Option Bool := do
      let heights ← coinHeights.mapM (fun (height : Option Nat) => height.map (BsvScript.Params.inputScriptBlockHeight · tipHeight))
      let locks ← calculateSequenceLocks tx flags heights (ancestorMedianTimePast cfg tipHeight tipTimes)
      return evaluateSequenceLocks (tipHeight + 1) (medianTimePast tipTimes cfg.medianTimeSpan) locks
    result.getD false

/-- Consensus MoneyRange for signed arithmetic, reusing the script layer's
nonnegative money bound [SRC] src/amount.h:130–134 at 6504a3af. -/
def moneyRangeInt (value : Int) : Bool :=
  0 ≤ value && BsvScript.TxRules.moneyRange value.toNat

/-- Consensus fee stage: inputs minus outputs, with the source's ordered reject
reasons [SRC] src/validation.cpp:2646–2663 at 6504a3af. The preceding input and
output value checks belong to #61 and `BsvScript.TxRules`. With exact integers,
the intervening negative-fee branch cannot follow `valueIn ≥ valueOut`.
Success of this stage is the accepted predicate in `fee_nonnegative`. -/
def fee (valueIn valueOut : Int) : Except Reject Int :=
  if valueIn < valueOut then .error ⟨.node 0x10, "bad-txns-in-belowout"⟩
  else if moneyRangeInt (valueIn - valueOut) then .ok (valueIn - valueOut)
  else .error ⟨.node 0x10, "bad-txns-fee-outofrange"⟩

end BsvChain
