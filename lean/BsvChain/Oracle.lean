import BsvChain.Coin
import BsvScript.Eval
import Mathlib.Data.Finmap

/-!
# Script calls and recorded verdicts (#76)

The oracle receives the complete spend and the exact parameters of a call.
Caller flags and resource selection are independent; ordinary derivation is
only one case. No oracle runs where a caller bypasses scripts.
[SRC] src/validation.cpp:1328–1347,1411–1423,705–717,2693–2707,2738–2749,
2864–2868,2885–2897 at 6504a3aff65ba97c0f6c80962b033e35ecbfed4b.
-/

namespace BsvChain
open BsvScript.Tx BsvScript.Params BsvScript.Machine

/-- An outpoint and the existing coin, in transaction input order. This keeps
signed amounts, locking scripts and stored heights without another coin type.
[SRC] src/validation.cpp:2900–2915 at 6504a3af. -/
abbrev Prevout := OutPoint × Coin

/-- DESIGN-S6 §4.3's complete per-input interface. Coin height is the raw stored
height; the wrapper resolves a mempool coin against the active tip before
forming EvalParams. The spend height and all prevouts remain available even
to an oracle that does not implement the current signature algorithm.
[SRC] src/validation.cpp:2676–2709,2900–2915 at 6504a3af. -/
abbrev ScriptOracle := Tx → List Prevout → Nat → Nat → Nat → EvalParams → Verdict

/-- The existing executable evaluator with explicit parameters and transaction
context. Input/prevout alignment, stored height and nonnegative amount are
checked before conversion. Malformed adapter inputs decline by name through
the existing non-judging constructor; they are not reference script errors.
[SRC] src/validation.cpp:2523–2542,2639–2642,2900–2915 at 6504a3af. -/
def evalOracle : ScriptOracle := fun tx prevouts input coinHeight _ params =>
  match tx.inputs[input]?, prevouts[input]? with
  | some txin, some (point, coin) =>
    if point ≠ OutPoint.ofInput txin || coin.height ≠ coinHeight || coin.value < 0 then
      .undefinedInReference "oracle-prevout-context"
    else BsvScript.Eval.verifyScript params
      (BsvScript.TxContext.txContext tx input coin.value.toNat) txin.scriptSig coin.script
  | _, _ => .undefinedInReference "oracle-input-index"

/-- Limits for an already composed word. This is also the modified-mandatory
re-check's entry point: it must not restore flags cleared after composition.
[SRC] src/validation.cpp:2738–2749 and src/script/interpreter.cpp:2282–2302
at 6504a3af. -/
def exactEvalParams (cfg : NodeConfig) (flags : Flags) (consensus : Bool) : EvalParams :=
  { flags, limits := cfg.toNodeConfig.normalize.limitsFor flags consensus }

/-- Per-input composition using the existing era flags and limit getters.
The resource selector is independent of the caller word, including a block
word checked with policy limits in the mempool. Params.derive cannot encode
all these calls. [SRC] src/validation.cpp:1328–1347,1411–1423,705–717,
2693–2707,2738–2749 at 6504a3af. -/
def inputEvalParams (cfg : NodeConfig) (params : BsvChain.ChainParams)
    (height tipHeight : Nat) (callerFlags : Flags) (consensus : Bool) (coin : Coin) : EvalParams :=
  let era := protocolEraOf params.genesisHeight params.chronicleHeight height
  let flags := callerFlags.union (inputScriptVerifyFlags era (coin.era params tipHeight))
  exactEvalParams cfg flags consensus

/-- Ordinary block or relay caller word from the explicit network data.
Absent activation assignments stay unresolved, with no network fallback.
[SRC] src/verify_script_flags.cpp:11–81 and src/validation.cpp:2972–2981
at 6504a3af. -/
def ordinaryScriptFlags (cfg : NodeConfig) (params : BsvChain.ChainParams)
    (height : Nat) (blockWord : Bool) : Option Flags := do
  let era := protocolEraOf params.genesisHeight params.chronicleHeight height
  if blockWord then
    return blockScriptFlags (← params.toScript?) (height - 1) era
  else
    return mempoolScriptFlags era cfg.chainRequireStandard cfg.promiscuousMempoolFlags

/-- Clear selected bits through the existing word codec, retaining the other
modeled bits. Used before per-input composition for request exclusions, and
after it for the modified-mandatory re-check.
[SRC] src/validation.cpp:1330,2738 at 6504a3af. -/
def excludeScriptFlags (flags excluded : Flags) : Flags :=
  Flags.ofWord (flags.toWord &&& (uint32Max ^^^ excluded.toWord))

/-- Caller's word selection. Explicit words include inverse-era admission
re-checks; mandatory is the outer fallback word, distinct from removing
nonmandatory bits from a composed input word. Resource selection is separate.
[SRC] src/validation.cpp:1328–1347,1364–1380,1411–1423,1444–1457
at 6504a3af. -/
inductive ScriptWord where
  | block
  | relay (excluded : Flags)
  | mandatory
  | explicit (flags : Flags)
  deriving Repr

/-- Resolve a caller's word before the per-input contribution. Exclusions do
not remove a bit subsequently contributed by the input's era.
[SRC] src/validation.cpp:1330,2693–2707 and src/verify_script_flags.cpp:11–81
at 6504a3af. -/
def callerScriptFlags (cfg : NodeConfig) (params : BsvChain.ChainParams)
    (height : Nat) : ScriptWord → Option Flags
  | .block => ordinaryScriptFlags cfg params height true
  | .relay excluded => (ordinaryScriptFlags cfg params height false).map
      (fun flags => excludeScriptFlags flags excluded)
  | .mandatory => some (mandatoryFlags
      (protocolEraOf params.genesisHeight params.chronicleHeight height))
  | .explicit flags => some flags

/-- Wrapper for each requested call, retaining the independent resource
selector. Block-word mempool re-checks pass false here; modified-mandatory
re-checks use exactEvalParams after clearing the composed word instead.
[SRC] src/validation.cpp:1328–1347,1411–1423,705–717,2693–2707,2738–2749
at 6504a3af. -/
def scriptEvalParams (cfg : NodeConfig) (params : BsvChain.ChainParams)
    (height tipHeight : Nat) (word : ScriptWord) (consensus : Bool)
    (coin : Coin) : Option EvalParams :=
  (callerScriptFlags cfg params height word).map
    (fun flags => inputEvalParams cfg params height tipHeight flags consensus coin)

-- Structural equality on the existing frame; no serialized-hash injectivity
-- assumption enters recorded lookup. [SRC] src/validation.cpp:2503–2519 at 6504a3af.
deriving instance DecidableEq for TxIn, TxOut, Tx

/-- Complete call identity, including exact limits, independent of a corpus
row's display id. Equal transaction hashes alone would not justify equality.
[SRC] src/validation.cpp:2503–2519,2676–2709 at 6504a3af. -/
structure ScriptCall where
  tx : Tx
  prevouts : List Prevout
  input : Nat
  coinHeight : Nat
  spendHeight : Nat
  params : EvalParams
  deriving DecidableEq, Repr

/-- Invoke a call through the parameter, without inspecting its implementation.
[SRC] src/validation.cpp:2523–2542 at 6504a3af. -/
def ScriptCall.run (call : ScriptCall) (oracle : ScriptOracle) : Verdict :=
  oracle call.tx call.prevouts call.input call.coinHeight call.spendHeight call.params

/-- The corpus's spec and spec-mempool columns, kept distinct even when their
parameters happen to coincide. This is recording metadata, not a node rule.
[SRC] src/validation.cpp:1335–1347,3376–3392 at 6504a3af. -/
inductive OracleColumn where
  | spec
  | specMempool
  deriving DecidableEq, Repr

/-- Recording key: column plus structural spend, prevouts, input, both heights
and every effective parameter. A changed limit must miss an old recording.
[SRC] src/validation.cpp:2503–2519,2693–2707 at 6504a3af. -/
structure RecordedKey where
  column : OracleColumn
  call : ScriptCall
  deriving DecidableEq, Repr

/-- Executable finite map of recorded values, using #61's finite-map mechanism.
Loading the map is the check executable's IO boundary. This is corpus data.
[SRC] src/validation.cpp:2523–2542 at 6504a3af. -/
abbrev RecordedVerdicts := Finmap (fun _ : RecordedKey => Verdict)

/-- A missing recording is a named decline, never acceptance or an invented
script failure. The inherited non-judging constructor is used as a model
signal, not a claim of undefined source behavior.
[SRC] src/validation.cpp:2538–2542 at 6504a3af. -/
def recordedOracleMissing : Verdict := .undefinedInReference "recorded-oracle-missing-key"

/-- Lookup-only oracle for a selected corpus column. It never falls back to
execution and never borrows the verdict of another parameter set or column.
[SRC] src/validation.cpp:2503–2542 at 6504a3af. -/
def recordedOracle (recorded : RecordedVerdicts) (column : OracleColumn) : ScriptOracle :=
  fun tx prevouts input coinHeight spendHeight params =>
    (recorded.lookup ⟨column, ⟨tx, prevouts, input, coinHeight, spendHeight, params⟩⟩).getD
      recordedOracleMissing

/-- Materialize verdicts into a finite map. Values are computed at construction;
recordedOracle subsequently reads only the map. Agreement on covered calls
is proved independently of which oracle produced the values.
[SRC] src/validation.cpp:2523–2542 at 6504a3af. -/
def recordOracle (oracle : ScriptOracle) (column : OracleColumn) : List ScriptCall → RecordedVerdicts
  | [] => ∅
  | call :: rest => (recordOracle oracle column rest).insert ⟨column, call⟩ (call.run oracle)

/-- Serial queued block result mapping, after the caller requires execution.
Non-judging results remain model errors with code zero, never node rejection.
[SRC] src/validation.cpp:3421–3430 at 6504a3af. -/
def queuedScriptResult : Verdict → Except Reject Unit
  | .valid => .ok ()
  | .invalid e => .error ⟨.node 0x10, "blk-bad-inputs (" ++ e.message ++ ")"⟩
  | _ => .error ⟨.node 0, "model: non-judging script oracle result"⟩

/-- Standard-but-not-mandatory mask, composed from the script layer's existing
sets. The GENESIS marker added by standardScriptVerifyFlags is not in this
mask, so removing all standard flags would be wrong.
[SRC] src/policy/policy.h:182–204,257–268 at 6504a3af. -/
def nonMandatoryScriptFlags (era : Era) : Flags :=
  excludeScriptFlags (standardOnly.union (mandatoryFlags era)) (mandatoryFlags era)

/-- The exact mandatory re-check word is the composed word minus the era's
nonmandatory mask; its resource selector is true. Per-input bits are not
reintroduced afterward. [SRC] src/validation.cpp:2738–2749 at 6504a3af. -/
def mandatoryRecheckParams (cfg : NodeConfig) (era : Era) (flags : Flags) : EvalParams :=
  exactEvalParams cfg (excludeScriptFlags flags (nonMandatoryScriptFlags era)) true

/-- Inverse input era for a supplied grace-period branch. Unsupported pairs
are explicit model declines, matching the source's exception boundary.
[SRC] src/protocol_era.cpp:49–85 at 6504a3af. -/
def inverseInputEra (genesis : Bool) (era : Era) : Option Era :=
  match genesis, era with
  | true, .preGenesis => some .postGenesis
  | true, .postGenesis => some .preGenesis
  | false, .postGenesis => some .postChronicle
  | false, .postChronicle => some .postGenesis
  | _, _ => none

/-- Grace re-check composition: invert only the input era, combine with the
original caller word, then remove the same nonmandatory mask. Resource limits
are selected anew with true. [SRC] src/validation.cpp:2767–2813 at 6504a3af. -/
def graceRecheckParams (cfg : NodeConfig) (params : BsvChain.ChainParams)
    (height tipHeight : Nat) (callerFlags : Flags) (genesis : Bool)
    (coin : Coin) : Option EvalParams := do
  let era := protocolEraOf params.genesisHeight params.chronicleHeight height
  let inverse ← inverseInputEra genesis (coin.era params tipHeight)
  return mandatoryRecheckParams cfg era (callerFlags.union (inputScriptVerifyFlags era inverse))

/-- Inline CheckInputScripts result mapping. Every needed re-check invokes the
oracle with its own exact parameters; an uncovered recorded call declines.
Grace membership is supplied by the admission caller; Genesis has priority.
Ban scores, cancellation, outer admission re-check scheduling and cache/depth
bypasses belong to #62/#71/#73, not to this per-input verdict wrapper.
[SRC] src/validation.cpp:2716–2837 at 6504a3af. -/
def inlineScriptCheck (cfg : NodeConfig) (params : BsvChain.ChainParams)
    (tipHeight : Nat) (callerFlags : Flags) (genesisGrace chronicleGrace : Bool)
    (oracle : ScriptOracle) (call : ScriptCall) : Except Reject Unit := do
  let initial := call.run oracle
  let .invalid error := initial | return ← queuedScriptResult initial
  let era := protocolEraOf params.genesisHeight params.chronicleHeight call.spendHeight
  let mask := nonMandatoryScriptFlags era
  if call.params.flags.toWord &&& mask.toWord != 0 then
    let retry := { call with params := mandatoryRecheckParams cfg era call.params.flags }
    match retry.run oracle with
    | .valid =>
      let policyNumber := !genesisGrace && !chronicleGrace && error == .scriptnumOverflow
      throw ⟨.node (if policyNumber then 0x10 else 0x40),
        (if policyNumber then "max-script-num-length-policy-limit-violated ("
         else "non-mandatory-script-verify-flag (") ++ error.message ++ ")"⟩
    | .invalid _ =>
      if genesisGrace || chronicleGrace then
        let some (_, coin) := call.prevouts[call.input]? |
          throw ⟨.node 0, "model: oracle-input-index"⟩
        let some graceParams := graceRecheckParams cfg params call.spendHeight tipHeight
            callerFlags genesisGrace coin |
          throw ⟨.node 0, "model: unsupported inverse input era"⟩
        let graceCall := { call with params := graceParams }
        match graceCall.run oracle with
        | .valid => throw ⟨.node 0x40,
            (if genesisGrace then "genesis-script-verify-flag-failed ("
             else "chronicle-script-verify-flag-failed (") ++ error.message ++ ")"⟩
        | .invalid _ => pure ()
        | _ => throw ⟨.node 0, "model: non-judging script oracle result"⟩
    | _ => throw ⟨.node 0, "model: non-judging script oracle result"⟩
  throw ⟨.node 0x10,
    (if error == .bigInt then "max-script-num-overflow ("
     else "mandatory-script-verify-flag-failed (") ++ error.message ++ ")"⟩

end BsvChain
