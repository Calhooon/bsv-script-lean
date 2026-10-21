import BsvScript.Flags
import BsvScript.TxContext
import BsvScript.TxRules
import BsvScript.TxPolicy
import Bsvs.Corpus
import Bsvs.Trace
/-!
# Bsvs.Run: one spend through the evaluator, every input (#14; `docs/DESIGN.md` §6)

For input `i` of the spending transaction: the `EvalParams` are `Params.derive`
of the node's configuration at the spend height and the prevout's height on
the chosen path, or, with an explicit word, `Flags.ofWord` with the limits
`make_verify_script_params` builds for that word (`interpreter.cpp:2282–2302`): the
`verifyscript` RPC's word without `txo.height` (the RPC re-derives the two UTXO bits from a
given height, `rpc/misc.cpp:803–823`), with the RPC's limits only under `consensus` false
(`858–867`; lean #32's second lens, B-9);
the context is `TxContext.txContext tx i amount` (`TransactionSignatureChecker`,
`2126–2256`); the verdict is `Eval.verifyScript` (`VerifyScript`, `2304–2451`).

The transaction's verdict (Q5, DESIGN §6): valid when every input is valid;
otherwise the first non-valid input's verdict, its index advisory (the
reference's mempool path is sequential and stops at the first failure,
`validation.cpp:2900–2924`; its block path is a set). A build-time
`unimplemented` input (an opcode no family has written; none since #18, by
`Properties.evalScript_ne_unimplemented`) or an `undefined-in-reference` input
(a reserved verdict kind; the v1.2.3 reader has a defined overflow refusal.
The previous pin's reading is retained in a history module withheld from the public
edition at the maintainers' request, group `d8-node-team-discretion`)
makes the transaction that verdict unless another input is invalid.

A coinbase transaction's input script is never evaluated (`docs/DESIGN.md` §5.5;
`ConnectBlock` runs the scripts of the non-coinbase transactions only, `if (!tx.IsCoinBase())`,
`validation.cpp:3369`, and `assert(!tx.IsCoinBase())` at `2856`): its verdict is valid with no
inputs run.

THE TRANSACTION-LEVEL GATE (2026-09-26, S3, for the `tx.*` families of #26 under D97): beside the
script verdict, `SpendResult.gate` reports `TxRules.checkRegularTransaction` (or `checkCoinbase`
for a coinbase on the block path) under the SPEND's era (`GetProtocolEra` at the block's height with
`IsProtocolActive(era, ProtocolName::Genesis)`, `validation.cpp:560`, `611`, `1032`, `5773`: pre-Genesis the
size limit `MAX_TX_SIZE_CONSENSUS_BEFORE_GENESIS` and the sigop count apply, after Genesis the
size limit is `MAX_TX_SIZE_CONSENSUS_AFTER_GENESIS`; `consensus.h:27, 29, 47`), as the reject
string `validation.cpp` uses (`rejectCode`), or nothing when the transaction passes. Inside the Genesis
grace window (`validation.cpp:1040`; the window `protocol_era.cpp:125–126` with `policy.h:128`) the
mempool checks a refused transaction again under the inverse era: if that check accepts it, the string is
`"flexible-" + reason` (`1047–1050`), else the reason stands (`1052–1055`), a coinbase's
`bad-tx-coinbase` among them; the harness strips the prefix (`harness/src/svnode_codes.rs`).
On the MEMPOOL path a coinbase meets `CheckRegularTransaction`, which refuses it first (`"bad-tx-coinbase"`,
`validation.cpp:600–601`, reached at `1035–1036`: "Coinbase is only valid in a block"); `CheckCoinbase`
applies on the block path alone (lean #32's second lens, B-3). On the MEMPOOL
path (not `consensus`) a non-coinbase that passes the consensus gate then meets the node's STANDARDNESS
(`TxPolicy.standardnessRefusal`, 2026-09-28, S1's `eb4cddf`) and its two transaction-level POLICY caps,
`TxPolicy.txPolicyGateFor` (2026-09-27:
the size cap of `IsStandardTx`, `standard.cpp:445–449`, reached at `validation.cpp:1073`, then the
sigop cap at `1236–1248`; both `NodeConfig` fields with their defaults, CLAUDE.md rule 1), as
`TxPolicy.PolicyReject.code`'s string (the caps' `"tx-size"` and `"bad-txns-too-many-sigops"`, `IsStandardTx`'s eight
reasons, `"bad-txns-nonstandard-inputs"`); the count it
compares is the node's whole count, `TxPolicy.mempoolTxPolicy` over the prevouts' scripts and heights
(`TxPolicy.txSigOpCount`: the count without P2SH, then the P2SH part, `validation.cpp:495–517`;
2026-09-27, in place of `TxRules.sigOpCountWithoutP2SH`); the block path never meets a
policy cap. The sigop cap refuses unconditionally (`DoS(0, … REJECT_NONSTANDARD`,
`1243–1247`); the size cap's refusal is conditional on the standardness settings (`1081–1090`: before
Genesis when `requireStandard`, after it unless `acceptNonStandardOutput` holds and `requireStandard`
does not, `configscriptpolicy.cpp:468–471`), which `TxPolicy.standardnessEnforced` models. The node's
STANDARDNESS itself (`IsStandardTx`, `AreInputsStandard`) is modelled since 2026-09-28 in `BsvScript.Standard`
(S1's `eb4cddf`) and refused by `TxPolicy.standardnessRefusal` before the two caps, under `requireStandard` and
`-acceptnonstdoutputs`; the block road's class `tx.gate.standardness.unmodelled`, open from D123's move (the
policy instance at mainnet's default, `acceptnonstdtxn=0`, `harness/oracle/bitcoin-policy.conf`; the consensus
instance keeps `acceptnonstdtxn=1`, the harness's consensus instrument),
CLOSED by the parent's re-run of 2026-09-28 at `spec@013f578` (the four entries agree with the node; the class removed from `harness/rules/sv-node.json` the same day). No entry of `corpus/tx` reaches the size cap:
`tx-00033`'s 1,020,053 bytes fail the consensus size first. It is a
SEPARATE field: the script engines the harness compares (bsv-rs, go-sdk, ts-sdk, `verifyscript`)
never see the gate, so the script verdict stays what it was; the block road (`run_svnode --mode tx`:
the transaction in a block on the spec's own instance, and through its mempool) is compared with the
gate AND the script verdict together. Entries with no input or no output are not corpus entries
(`Entry.check`); those two rules are exercised by the reference's `tx_invalid.json` (the `txtests` leg).
-/

namespace Bsvs.Run
open BsvScript BsvScript.Params BsvScript.Numbers BsvScript.Machine BsvScript.Tx BsvScript.TxContext
open Bsvs.Corpus Bsvs.Trace

/-- The parameters one input is verified under and where they came from. -/
structure InputParams where
  params : EvalParams
  spendHeight : Nat
  utxoHeight : Nat
  consensus : Bool
  /-- the explicit word, when one was given -/
  explicit : Option Nat
  deriving Repr

/-- `Params.derive`, or the explicit word with the limits of its UTXO era under the
switch (`make_verify_script_params` on the given word, `2295–2302`; the
configuration as the setters leave it, `NodeConfig.normalize`). -/
def paramsFor (cfg : NodeConfig) (spendHeight utxoHeight : Nat) (consensus : Bool) (explicit : Option Nat) : InputParams :=
  match explicit with
  | some w =>
    let f := Flags.ofWord w
    { params := { flags := f, limits := cfg.normalize.limitsFor f consensus }, spendHeight, utxoHeight, consensus, explicit := some w }
  | none => { params := derive cfg spendHeight utxoHeight consensus, spendHeight, utxoHeight, consensus, explicit := none }

structure InputResult where
  index : Nat
  verdict : Verdict
  input : InputParams
  trace : Option (List PhaseTrace)

structure SpendResult where
  verdict : Verdict
  /-- the first non-valid input, advisory -/
  input : Option Nat
  inputs : List InputResult
  coinbase : Bool
  /-- the transaction-level gate's reject string (`validation.cpp:519–639`), or `none` when the
  transaction passes `CheckRegularTransaction`/`CheckCoinbase` under the spend's era -/
  gate : Option String

def verdictKind : Verdict → String
  | .valid => "valid"
  | .invalid _ => "invalid"
  | .unimplemented _ => "unimplemented"
  | .undefinedInReference _ => "undefined-in-reference"

def verdictCode : Verdict → Option String
  | .valid => none
  | .invalid e => some e.name
  | .unimplemented op => some s!"unimplemented 0x{String.ofList (Nat.toDigits 16 op)}"
  | .undefinedInReference f => some s!"undefined-in-reference ({f})"

def verdictMessage : Verdict → Option String
  | .valid => none
  | .invalid e => some e.message
  | .unimplemented op => some s!"opcode 0x{String.ofList (Nat.toDigits 16 op)} has no family module yet (#18)"
  | .undefinedInReference f => some s!"an undecided region of the reference (family {f}; docs/DESIGN.md §9): a reserved kind for an undecided region; never valid or invalid"

/-- The reject strings of `validation.cpp` for `TxRules.TxReject`, the node's own words on the block and
the mempool roads, so the transaction-level code compares like a script error's name: `CheckTransactionCommon`
`:528` (vin), `:532` (vout), `:537` (oversize), `:544–545` (a negative value), `:549–550` (a value over
`MAX_MONEY`), `:555–556` (the total), `:565` (the pre-Genesis sigop count); `CheckCoinbase` `:579`, `:589`;
`CheckRegularTransaction` `:602`, `:621` (a P2SH output after Genesis), `:629` (a null outpoint), `:634` (a
duplicate outpoint). -/
def rejectCode : TxRules.TxReject → String
  | .vinEmpty => "bad-txns-vin-empty"
  | .voutEmpty => "bad-txns-vout-empty"
  | .oversize => "bad-txns-oversize"
  | .voutNegative => "bad-txns-vout-negative"
  | .voutTooLarge => "bad-txns-vout-toolarge"
  | .txoutTotalTooLarge => "bad-txns-txouttotal-toolarge"
  | .sigops => "bad-txn-sigops"
  | .coinbaseWhereRegular => "bad-tx-coinbase"
  | .coinbaseMissing => "bad-cb-missing"
  | .coinbaseLength => "bad-cb-length"
  | .prevoutNull => "bad-txns-prevout-null"
  | .inputsDuplicate => "bad-txns-inputs-duplicate"
  | .p2shOutput => "bad-txns-vout-p2sh"

/-- `MAX_TX_SIZE_CONSENSUS_AFTER_GENESIS` (`consensus.h:29`, `ONE_GIGABYTE`; the pre-Genesis limit is
`TxRules.MAX_TX_SIZE_CONSENSUS_BEFORE_GENESIS`, `:27`). -/
def MAX_TX_SIZE_CONSENSUS_AFTER_GENESIS : Nat := 1000000000

/-- The transaction-level gate under the spend's era (the module docstring): the reject string, or `none`;
on the mempool path (`consensus = false`) a non-coinbase that passes the consensus gate then meets the
two policy caps with the node's whole sigop count (`TxPolicy.mempoolTxPolicy` over the prevouts' scripts and heights). -/
def txGate (cfg : NodeConfig) (tx : Tx) (prevouts : List Prevout) (spendHeight : Nat) (consensus : Bool := true) :
    Option String :=
  let preGenesis := spendHeight < cfg.genesisActivationHeight
  let maxSize := if preGenesis then TxRules.MAX_TX_SIZE_CONSENSUS_BEFORE_GENESIS else MAX_TX_SIZE_CONSENSUS_AFTER_GENESIS
  let r := if TxRules.isCoinBase tx && consensus
    then TxRules.checkCoinbase tx TxRules.MAX_TX_SIGOPS_COUNT_BEFORE_GENESIS maxSize preGenesis
    else TxRules.checkRegularTransaction tx TxRules.MAX_TX_SIGOPS_COUNT_BEFORE_GENESIS maxSize preGenesis
  match r with
  | .ok () =>
    if consensus || TxRules.isCoinBase tx then none
    else match TxPolicy.mempoolTxPolicy cfg spendHeight tx (prevouts.map fun p => (p.script, p.height)) with
      | .ok () => none
      | .error e => some e.code
  | .error e => some (rejectCode e)

/-- One input. -/
def runInput (cfg : NodeConfig) (tx : Tx) (prevouts : List Prevout) (spendHeight : Nat) (consensus : Bool)
    (explicit : Option Nat) (i : Nat) (withTrace : Bool) : Option InputResult := do
  let inp ← tx.inputs[i]?
  let prev ← prevouts[i]?
  let ip := paramsFor cfg spendHeight prev.height consensus explicit
  let ctx := txContext tx i prev.satoshis
  let v := Eval.verifyScript ip.params ctx inp.scriptSig prev.script
  let tr := if withTrace then some (traceVerifyScript Eval.opExec ip.params ctx inp.scriptSig prev.script) else none
  pure { index := i, verdict := v, input := ip, trace := tr }

/-- The transaction's verdict from its inputs' (Q5). -/
def combine (rs : List InputResult) : Verdict × Option Nat :=
  match rs.find? (fun r => match r.verdict with | .invalid _ => true | _ => false) with
  | some r => (r.verdict, some r.index)
  | none =>
    match rs.find? (fun r => match r.verdict with | .unimplemented _ => true | .undefinedInReference _ => true | _ => false) with
    | some r => (r.verdict, some r.index)
    | none => (.valid, none)

/-- Every input (or the one asked for), then the transaction's verdict. -/
def runSpend (cfg : NodeConfig) (tx : Tx) (prevouts : List Prevout) (spendHeight : Nat) (consensus : Bool)
    (flags : Option (List Nat)) (only : Option Nat) (withTrace : Bool) : Except String SpendResult := do
  if tx.inputs.length != prevouts.length then
    throw s!"{tx.inputs.length} inputs but {prevouts.length} prevouts"
  if let some ws := flags then
    if ws.length != tx.inputs.length then throw s!"{tx.inputs.length} inputs but {ws.length} flag words"
  let gate := txGate cfg tx prevouts spendHeight consensus
  if let some i := only then
    if tx.inputs.length ≤ i then throw "no such input"
  if TxRules.isCoinBase tx then
    pure { verdict := .valid, input := none, inputs := [], coinbase := true, gate }
  else
    let indices := match only with
      | some i => if i < tx.inputs.length then [i] else []
      | none => List.range tx.inputs.length
    if indices.isEmpty then throw "no such input"
    let results := indices.filterMap (fun i =>
      runInput cfg tx prevouts spendHeight consensus (flags.bind (·[i]?)) i withTrace)
    let (v, idx) := combine results
    pure { verdict := v, input := idx, inputs := results, coinbase := false, gate }

end Bsvs.Run
