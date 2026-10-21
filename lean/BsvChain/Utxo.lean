import BsvChain.Oracle
import Mathlib.Data.Finmap

/-!
# The UTXO transition (#61)

Executable finite maps implement DESIGN-S6 §1's `Map OutPoint Coin`.
Finmap uses association lists modulo permutation, with unique keys and
lookup extensionality; its executable operations are the definitions proved
about here, so no unproved map implementation stands between model and run.
The source is bitcoin-sv v1.2.3 at
6504a3aff65ba97c0f6c80962b033e35ecbfed4b.

`checkTxInputs` is the non-coinbase input stage in source order.
`applyTx` supplies the block caller's unavailable-input reason, performs the
required script judgments, and updates coins. It is not a complete block or
admission validator: finality, sequence locks, size, sigops, coinbase structure
and subsidy belong to their callers (#60, #62, #63, #64). The existing output
and distinct-input loops guard the mutation's structural preconditions.
-/

namespace BsvChain
open BsvScript.Tx BsvScript.Numbers

/-- The note's finite `Map OutPoint Coin`, with executable lookup/erase/insert.
Cache spent sentinels are representable but are absent from `getCoin`'s live
view. [SRC] src/coins.h:204–239,399 and src/coins.cpp:116–128 at 6504a3af. -/
abbrev UtxoSet := Finmap (fun _ : OutPoint => Coin)

/-- Live-coin view; a missing key and the spent sentinel are both unavailable.
[SRC] src/coins.h:235 and src/coins.cpp:116–128 at 6504a3af. -/
def getCoin (s : UtxoSet) (p : OutPoint) : Option Coin :=
  (s.lookup p).filter (fun coin => !coin.isSpent)

/-- Small operator-list interface for #70: effective frozen membership and
effective confiscation whitelist membership at a height and on a path.
`onBlock` selects block versus admission checks. #70 resolves modes, ranges,
explicit soft freezes and the depth waiver into these projections; this type
does not turn their contents into consensus constants or policy limits.
[SRC] src/frozentxo.cpp:37–82,133–170 at 6504a3af. -/
structure FrozenLists where
  frozen : Bool → Nat → OutPoint → Bool
  whitelisted : Bool → Nat → Bytes → Bool

/-- Empty operator lists, an explicit scenario input.
[SRC] src/frozentxo.cpp:44–49,135–143 at 6504a3af. -/
def FrozenLists.empty : FrozenLists := ⟨fun _ _ _ => false, fun _ _ _ => false⟩

/-- Explicit transition inputs. The caller word is independent of the
resource selector, and the active tip height independently resolves mempool
coins. `now` is retained for #77; this transition reads no clock and ignores
it. `onBlock` selects only the operator-list path; `applyTx` maps queued script
failures as the block caller does. Inline script mappings are in Oracle; admission scheduling is #62.
[SRC] src/validation.cpp:2552–2554,2667–2709,3421–3430 at 6504a3af. -/
structure UtxoContext where
  params : ChainParams
  height : Nat
  tipHeight : Nat
  flags : BsvScript.Params.Flags
  consensus : Bool
  onBlock : Bool
  now : Int

/-- The availability pass precedes every frozen, maturity and value check.
Coinbase's structural input is not spent.
[SRC] src/coins.cpp:116–128 and src/validation.cpp:2556–2560 at 6504a3af. -/
def haveInputs (s : UtxoSet) (tx : Tx) : Bool :=
  BsvScript.TxRules.isCoinBase tx || tx.inputs.all (fun i => (getCoin s (.ofInput i)).isSome)

/-- Input outpoints removed by UpdateCoins, with the coinbase case empty.
[SRC] src/validation.cpp:2483–2491 at 6504a3af. -/
def spentOutpoints (tx : Tx) : List OutPoint :=
  if BsvScript.TxRules.isCoinBase tx then [] else tx.inputs.map OutPoint.ofInput

/-- Input value sum in the live view, zero on an absent coin as a total
extension used only after availability succeeds in validation.
[SRC] src/validation.cpp:2589–2643 at 6504a3af. -/
def inputValue (s : UtxoSet) (tx : Tx) : Int :=
  (tx.inputs.map (fun i => ((getCoin s (.ofInput i)).map (·.value)).getD 0)).sum

/-- Output sum, including pruned outputs: value conservation counts every
output, not just the new UTXOs. Output range checks are reused separately.
[SRC] src/primitives/transaction.cpp:101–112 and src/validation.cpp:2646–2660
at 6504a3af. -/
def outputValue (tx : Tx) : Int := (tx.outputs.map (fun o => (o.value : Int))).sum

/-- In-order per-input checks: frozen, coinbase maturity, confiscation maturity,
then individual and accumulated MoneyRange. Both maturities reuse #59's
consensus-constant census fields (`COINBASE_MATURITY` = 100 and
`CONFISCATION_MATURITY` = 1000 at the pin), never relay policy settings.
Signed depth preserves a future-height coin's negative depth.
[SRC] src/validation.cpp:2591–2643 and src/consensus/consensus.h:71–79
at 6504a3af. -/
def checkInputCoins (s : UtxoSet) (cfg : NodeConfig) (ctx : UtxoContext)
    (lists : FrozenLists) (confiscation : Bool) : List TxIn → Int → Except Reject Unit
  | [], _ => .ok ()
  | input :: rest, total =>
    let p := OutPoint.ofInput input
    if !confiscation && lists.frozen ctx.onBlock ctx.height p then
      .error ⟨.node (if ctx.onBlock then 0x13 else 0x10), "bad-txns-inputs-frozen"⟩
    else match getCoin s p with
    | none => .error ⟨.node 0, ""⟩
    | some coin =>
      let depth := (ctx.height : Int) - (coin.height : Int)
      if coin.isCoinbase && decide (depth < cfg.coinbaseMaturity) then
        .error ⟨.node 0x10, "bad-txns-premature-spend-of-coinbase"⟩
      else if coin.isConfiscation && decide (depth < cfg.confiscationMaturity) then
        .error ⟨.node 0x10, "bad-txns-premature-spend-of-confiscation"⟩
      else if !moneyRangeInt coin.value || !moneyRangeInt (total + coin.value) then
        .error ⟨.node 0x10, "bad-txns-inputvalues-outofrange"⟩
      else checkInputCoins s cfg ctx lists confiscation rest (total + coin.value)

/-- Consensus input stage, with the operator-list checks in their separate
kind. Availability, confiscation contents/whitelist, input loop, then #60's
fee. The pin returns code 0 and an empty reject reason for unavailable inputs;
`bad-txns-inputs-missingorspent` belongs to the block caller, not this function.
The debug string `Inputs unavailable` is not the reject reason.
Called on non-coinbase transactions after structural output checks.
[SRC] src/validation.cpp:2552–2665,3326–3331 at 6504a3af. -/
def checkTxInputs (s : UtxoSet) (cfg : NodeConfig) (ctx : UtxoContext)
    (lists : FrozenLists) (tx : Tx) : Except Reject Int := do
  if !haveInputs s tx then throw ⟨.node 0, ""⟩
  let confiscation := isConfiscationTx tx
  if confiscation then
    if !validConfiscationContents tx then throw ⟨.node 0x10, "bad-ctx-invalid"⟩
    if !lists.whitelisted ctx.onBlock ctx.height (BsvScript.Sighash.txid tx) then
      throw ⟨.node 0x10, "bad-ctx-not-whitelisted"⟩
  checkInputCoins s cfg ctx lists confiscation tx.inputs 0
  fee (inputValue s tx) (outputValue tx)

/-- Structural preconditions reused from the interpreter: output ranges, then
nonnull distinct outpoints. Other structural checks remain with the caller.
Only these five TxReject constructors can arise from the two reused loops;
the wildcard is an explicit internal model error, not a node validity code.
[SRC] src/validation.cpp:542–558,625–637 at 6504a3af. -/
def checkUtxoStructure (tx : Tx) : Except Reject Unit :=
  let result := do
    let _ ← BsvScript.TxRules.checkOutputs tx.outputs 0
    BsvScript.TxRules.checkInputs tx.inputs []
  result.mapError fun e =>
    match e with
    | .voutNegative => ⟨.node 0x10, "bad-txns-vout-negative"⟩
    | .voutTooLarge => ⟨.node 0x10, "bad-txns-vout-toolarge"⟩
    | .txoutTotalTooLarge => ⟨.node 0x10, "bad-txns-txouttotal-toolarge"⟩
    | .prevoutNull => ⟨.node 0x10, "bad-txns-prevout-null"⟩
    | .inputsDuplicate => ⟨.node 0x10, "bad-txns-inputs-duplicate"⟩
    | _ => ⟨.node 0, "model: unexpected structural result"⟩

/-- Each ordinary input is judged through the parameter, after all value
checks. Confiscation bypasses scripts exactly where the reference does.
Invalid scripts use the serial block queue's error and the existing error
message. Non-verdict oracle outcomes return an explicit model error (code 0),
never a claimed node invalidity. Scheduling/assumevalid are callers' work.
[SRC] src/validation.cpp:2864–2868,2900–2924,3421–3430 and
src/script/script_error.cpp:9–115 at 6504a3af. -/
def checkInputScripts (s : UtxoSet) (cfg : NodeConfig) (ctx : UtxoContext)
    (oracle : ScriptOracle) (tx : Tx) : Except Reject Unit := do
  if isConfiscationTx tx then return ()
  let prevouts ← tx.inputs.mapM fun input => do
    let point := OutPoint.ofInput input
    let some coin := getCoin s point | throw ⟨.node 0, ""⟩
    pure (point, coin)
  for ((_, coin), index) in prevouts.zipIdx do
    let params := inputEvalParams cfg ctx.params ctx.height ctx.tipHeight ctx.flags ctx.consensus coin
    queuedScriptResult (oracle tx prevouts index coin.height ctx.height params)

/-- Remove precisely the named keys. Erasures commute, so the recursive order
has the same live view as UpdateCoins' input loop.
[SRC] src/validation.cpp:2483–2491 at 6504a3af. -/
def eraseKeys (s : UtxoSet) : List OutPoint → UtxoSet
  | [] => s
  | p :: ps => (eraseKeys s ps).erase p

/-- Executable finite map of the pairs, earlier pairs taking precedence.
Used for the created outputs and the retained spent coins.
[SRC] src/coins.cpp:548–565 and src/undo.h:80–83 at 6504a3af. -/
def coinMap : List (OutPoint × Coin) → UtxoSet
  | [] => ∅
  | (p, coin) :: rest => (coinMap rest).insert p coin

/-- Retain the spent coins with their input-derived outpoint, in input order.
The pairing is a lossless presentation of the pin's aligned coin vector, not
a snapshot of the original set or of overwritten outputs.
[SRC] src/validation.cpp:2483–2489 and src/undo.h:80–83 at 6504a3af. -/
def coinsAt (s : UtxoSet) : List OutPoint → List (OutPoint × Coin)
  | [] => []
  | p :: ps => match s.lookup p with
    | none => coinsAt s ps
    | some coin => (p, coin) :: coinsAt s ps

/-- One transaction's spent-coin undo vector with input-derived keys.
Coinbase's vector is empty. No overwritten output is retained.
[SRC] src/undo.h:80–83 and src/validation.cpp:2483–2491 at 6504a3af. -/
structure Undo where
  spent : List (OutPoint × Coin)
  deriving DecidableEq, Repr

/-- Eligible output pairs with the transaction's actual hash. Pruning uses
the stored creation height against Genesis directly, including the mempool
sentinel, as AddCoin does; it does not use the spend's era or tip substitution.
Chronicle does not affect this predicate. Coinbase and confiscation metadata
are carried to every added coin.
[SRC] src/coins.cpp:45–64,548–565 and src/validation.cpp:2493–2494 at 6504a3af. -/
def createdOutputs (params : ChainParams) (height : Nat) (tx : Tx) : List (OutPoint × Coin) :=
  let id := BsvScript.Sighash.txid tx
  tx.outputs.zipIdx.filterMap fun (output, index) =>
    if isUnspendable (decide (params.genesisHeight ≤ height)) output.scriptPubKey then none
    else some (⟨id, index⟩,
      ⟨output.value, output.scriptPubKey, height, BsvScript.TxRules.isCoinBase tx, isConfiscationTx tx⟩)

/-- Spend inputs and add eligible outputs, as UpdateCoins. Validation and the
non-coinbase overwrite guard are in applyTx; this is the pure mutation.
[SRC] src/validation.cpp:2480–2495 and src/coins.cpp:548–565 at 6504a3af. -/
def updateCoins (s : UtxoSet) (params : ChainParams) (height : Nat) (tx : Tx) : UtxoSet × Undo :=
  (coinMap (createdOutputs params height tx) ∪ eraseKeys s (spentOutpoints tx),
   ⟨coinsAt s (spentOutpoints tx)⟩)

/-- Validated one-transaction application. Coinbase adds eligible outputs and
spends nothing; its own structure/subsidy checks are #63's. Non-coinbase
overwrites are the pin's logic-error precondition, represented by code 0 and
its exact exception text, not by an invented consensus rejection. Coinbase
overwrites remain permitted, hence the conditional undo theorem.
[SRC] src/validation.cpp:2480–2495,3326–3331,3376–3392 and
src/coins.cpp:386–401,548–565 at 6504a3af. -/
def validateUtxoTx (s : UtxoSet) (cfg : NodeConfig) (ctx : UtxoContext)
    (lists : FrozenLists) (oracle : ScriptOracle) (tx : Tx) : Except Reject Unit := do
  if BsvScript.TxRules.isCoinBase tx then return ()
  checkUtxoStructure tx
  if !haveInputs s tx then throw ⟨.node 0x10, "bad-txns-inputs-missingorspent"⟩
  let _ ← checkTxInputs s cfg ctx lists tx
  checkInputScripts s cfg ctx oracle tx
  let remaining := eraseKeys s (spentOutpoints tx)
  if (createdOutputs ctx.params ctx.height tx).any (fun (p, _) => (getCoin remaining p).isSome) then
    throw ⟨.node 0, "Adding new coin that replaces non-pruned entry"⟩
  return ()

/-- Check and atomically apply one transaction. Failure returns no mutated
view; success returns the updated view and spent-coin undo. Coinbase's own
structural checks remain #63's, as for UpdateCoins.
[SRC] src/validation.cpp:2480–2495,3326–3434 at 6504a3af. -/
def applyTx (s : UtxoSet) (cfg : NodeConfig) (ctx : UtxoContext)
    (lists : FrozenLists) (oracle : ScriptOracle) (tx : Tx) : Except Reject (UtxoSet × Undo) := do
  validateUtxoTx s cfg ctx lists oracle tx
  return updateCoins s ctx.params ctx.height tx

/-- Remove this transaction's eligible outputs, then restore the spent vector
in reverse application order (earlier input entries win). Clean/mismatch
status for a whole block belongs to #64. This state operation takes the
retained undo, not the former set.
[SRC] src/processing_block_index.cpp:30–69 and src/validation.cpp:2937–2953
at 6504a3af. -/
def undoTx (s : UtxoSet) (params : ChainParams) (height : Nat) (tx : Tx) (undo : Undo) : UtxoSet :=
  coinMap undo.spent ∪ eraseKeys s ((createdOutputs params height tx).map Prod.fst)

end BsvChain
