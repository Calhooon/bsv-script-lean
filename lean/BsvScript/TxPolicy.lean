import BsvScript.TxRules
import BsvScript.SigOps
import BsvScript.Flags
import BsvScript.Standard
/-!
# BsvScript.TxPolicy

The two transaction-level POLICY caps the node's mempool applies beside the
consensus checks of `BsvScript.TxRules` (the spec gap `tx.gate.policy-caps.unmodelled`
the block road found, `docs/records/20260926-231004-txroad-s3.md`: `tx-00035`,
20,000 sigops, consensus-valid, refused `bad-txns-too-many-sigops` by that road's policy
instance, which then did not require standardness (`acceptnonstdtxn=1`); at the node's
default, which the mempool column stands for since D123, it is refused `dust` first, for
its zero-value outputs (T-STD7); CLAUDE.md rule 1: a policy limit enters the
semantics only as a named parameter with its default and its source). Both are
`NodeConfig` fields (`lean/BsvScript/Params.lean`), read here by era exactly as
the node's getters read them:

* the sigop count against `-maxtxsigopscountspolicy`: `validation.cpp:1235–1247`
  (`GetTransactionSigOpCount(config, tx, view, true, era, err)` over
  `GetMaxTxSigOpsCountPolicy(era)`; `REJECT_NONSTANDARD`, `"bad-txns-too-many-sigops"`,
  a DoS score of 0); the getter `config.cpp:2422–2430`: the constant
  `MAX_TX_SIGOPS_COUNT_POLICY_BEFORE_GENESIS` = 20,000 / 5 = 4,000 before Genesis
  (`policy.h:81`), the setting after it (default `UINT32_MAX`, `policy.h:83–85`,
  `config.cpp:61`; the setter `config.cpp:2391–2415`: 0 → `UINT32_MAX`, above it refused);
* the serialized size against `-maxtxsizepolicy`: `IsStandardTx`,
  `script/standard.cpp:445–449` (`tx.GetTotalSize() > GetMaxTxSize(era, false)`,
  the reason `"tx-size"`; the standardness gate `validation.cpp:1073`); the getter
  `configscriptpolicy.cpp:397–413`: the constant `MAX_TX_SIZE_POLICY_BEFORE_GENESIS`
  = 99,999 before Genesis (`policy.h:68`), the setting after it (default
  `DEFAULT_MAX_TX_SIZE_POLICY_AFTER_GENESIS` = 10,000,000, `policy.h:70`,
  `configscriptpolicy.cpp:57`; the setter `:415–446`: 0 → the consensus size
  `MAX_TX_SIZE_CONSENSUS_AFTER_GENESIS`, above it or below 99,999 refused). A failed
  standardness test is enforced only when the node does not accept non-standard outputs
  for the era, or after Genesis under `requireStandard` for a reason other than
  `scriptpubkey` (`validation.cpp:1080–1088`; `GetAcceptNonStandardOutput(era)` is
  `!requireStandard` before Genesis and the setting `acceptnonstdoutputs` after it,
  `configscriptpolicy.cpp:468–471`, default true at `:60`): at that default the size
  refusal applies exactly under `requireStandard`, in both eras; `NodeConfig.acceptNonStandardOutput`
  carries the setting and `standardnessEnforced` reads the node's condition whatever it is (a node
  set to `-acceptnonstdoutputs=0` refuses after Genesis without `requireStandard`). The mempool
  column stands for the node default (D123, the maintainers' ruling of
  2026-09-27: `requireStandard` true on mainnet, the size cap live; T-TP9). The size test is one of
  `IsStandardTx`'s (`standard.cpp:427–500`), and since 2026-09-28 the mempool gate takes the whole test
  and `AreInputsStandard` (`BsvScript.Standard`; the last section, `standardnessRefusal`): the
  first reason refused where `validation.cpp:1081–1088` refuses it, a non-standard input where the node does
  not accept non-standard outputs (`1207–1224`), both before the sigop cap.

The count the node compares (`GetTransactionSigOpCount`, `validation.cpp:495–517`)
is `GetSigOpCountWithoutP2SH` (`438–460`) plus, for a non-coinbase, the P2SH count of
every pre-Genesis P2SH coin it spends (`463–494`: the redeem script's accurate count),
each over `CScript::GetSigOpCount` on its path (`BsvScript.SigOps`). The gate
`txPolicyGateFor` takes a count as an argument; `txPolicyGateCounted` takes the count
the node computes, `txSigOpCount` (the last section: both parts, on every path, with
`sigOpCountError` as `none`, refused at any cap, `validation.cpp:1242`), and
`mempoolTxPolicy` computes it from the spend's and the coins' heights. After Genesis a
multisig counts the preceding push's number, up to 2,147,483,647 from a four-byte push,
so the default cap `UINT32_MAX` is reachable: `multisigWitnessTx` (three outputs of
`04 ffffff7f OP_CHECKMULTISIG`, 18 bytes of locking script) counts 6,442,450,941 and
the mempool refuses it at SV-node's default (T-TP7); an unbalanced `OP_ENDIF`, or a
count push longer than four bytes, not minimal or negative, is `sigOpCountError`
(`script.cpp:59–67`, `script.cpp:89–95`, `script.cpp:102–115`; T-SO3, T-SO7, T-TP8). The corpus entries that
exercise them are the harness's (#26).

Pre-Genesis the two caps are constants below the consensus limits (4,000 < 20,000
sigops; 99,999 < 1,000,000 bytes), so the caps refuse transactions the consensus gate
accepts: `tx-00035` is the witness where the standardness gate lets it through (above).
Post-Genesis the consensus gate has no sigop cap and a size cap of 1,000,000,000
(`consensus.h:29`); the theorems below say exactly what the caps add at the values the
setters' zero rules select (the "consensus configuration": `-maxtxsizepolicy=0`,
`-maxtxsigopscountspolicy=0`), which is all the mempool's transaction gate adds to the block's
(`Bsvs.Run.txGate`, `consensus` false against true) on a transaction the standardness gate passes
(T-STD5). The mempool column differs from the block column in the scripts too: they run under the relay
word and the policy limits (`Params.derive` with `consensus` false; `Params.verifyScript_relay_block_version2`).

Bare line numbers are `src/validation.cpp` at the pin (`docs/PROVENANCE.md`).
-/

namespace BsvScript.TxPolicy
open BsvScript.Params BsvScript.Tx

/-- `MAX_TX_SIGOPS_COUNT_POLICY_BEFORE_GENESIS` (`policy.h:81`): `MAX_TX_SIGOPS_COUNT_BEFORE_GENESIS / 5` = 4,000. -/
def MAX_TX_SIGOPS_COUNT_POLICY_BEFORE_GENESIS : Nat := TxRules.MAX_TX_SIGOPS_COUNT_BEFORE_GENESIS / 5
/-- `MAX_TX_SIGOPS_COUNT_POLICY_AFTER_GENESIS` (`policy.h:83`): `UINT32_MAX`, the largest settable value
and the default `DEFAULT_TX_SIGOPS_COUNT_POLICY_AFTER_GENESIS` (`:85`, `config.cpp:61`). -/
def MAX_TX_SIGOPS_COUNT_POLICY_AFTER_GENESIS : Nat := 4294967295
/-- `MAX_TX_SIZE_POLICY_BEFORE_GENESIS` (`policy.h:68`): `100000 - 1`, "because pre genesis policy validation was >=". -/
def MAX_TX_SIZE_POLICY_BEFORE_GENESIS : Nat := 99999
/-- `DEFAULT_MAX_TX_SIZE_POLICY_AFTER_GENESIS` (`policy.h:70`): 10 × `ONE_MEGABYTE` = 10,000,000 (`consensus.h:15`). -/
def DEFAULT_MAX_TX_SIZE_POLICY_AFTER_GENESIS : Nat := 10000000
/-- `MAX_TX_SIZE_CONSENSUS_AFTER_GENESIS` (`consensus.h:29`): `ONE_GIGABYTE`; what `-maxtxsizepolicy=0`
selects (`configscriptpolicy.cpp:421–425`). The pre-Genesis consensus size is `TxRules.MAX_TX_SIZE_CONSENSUS_BEFORE_GENESIS`. -/
def MAX_TX_SIZE_CONSENSUS_AFTER_GENESIS : Nat := 1000000000

example : MAX_TX_SIGOPS_COUNT_POLICY_BEFORE_GENESIS = 4000 := by decide

/-- `GetMaxTxSigOpsCountPolicy(era)` (`config.cpp:2422–2430`): the pre-Genesis constant, else the node's setting. -/
def sigOpsCap (cfg : NodeConfig) (preGenesis : Bool) : Nat :=
  if preGenesis then MAX_TX_SIGOPS_COUNT_POLICY_BEFORE_GENESIS else cfg.maxTxSigOpsCountPolicy

/-- `GetMaxTxSize(era, false)` (`configscriptpolicy.cpp:397–413`, the policy column): the pre-Genesis
constant, else the node's setting. -/
def sizeCap (cfg : NodeConfig) (preGenesis : Bool) : Nat :=
  if preGenesis then MAX_TX_SIZE_POLICY_BEFORE_GENESIS else cfg.maxTxSizePolicy

/-- The mempool's policy rejections, in the node's words: the two caps, `"tx-size"` (`standard.cpp:447`) and
`"bad-txns-too-many-sigops"` (`1245`); and the standardness gate's (the last section), `IsStandardTx`'s reason
(`1087`, `Standard.NonStandard`) and `"bad-txns-nonstandard-inputs"` (`1221–1222`). -/
inductive PolicyReject where
  | txSize | tooManySigOps
  | nonStandard (r : Standard.NonStandard)
  | nonStandardInputs
  deriving DecidableEq, Repr

/-- The reject string of each (`standard.cpp:447`, `1245`, `1087` with `Standard.NonStandard.code`,
`1222`), as `Bsvs.Run.rejectCode` gives the consensus gate's. -/
def PolicyReject.code : PolicyReject → String
  | .txSize => "tx-size"
  | .tooManySigOps => "bad-txns-too-many-sigops"
  | .nonStandard r => r.code
  | .nonStandardInputs => "bad-txns-nonstandard-inputs"

/-- The policy gate over a transaction and its sigop count at explicit caps: the size first
(`IsStandardTx` runs at `1074`, before the inputs are fetched), the sigop count after (`1243`);
`.ok ()` when both caps hold. The consensus gate (`TxRules.checkRegularTransaction`, `1033–1050`)
runs before either. -/
def txPolicyGate (tx : Tx) (sigOps sigOpsCapV sizeCapV : Nat) : Except PolicyReject Unit := do
  if sizeCapV < (Sighash.serTx tx).length then throw .txSize
  if sigOpsCapV < sigOps then throw .tooManySigOps
  pure ()

/-- Whether a failed standardness test other than on an output script refuses the transaction
(`validation.cpp:1080–1088`): when the node does not accept non-standard outputs for the era
(`GetAcceptNonStandardOutput(era)`, `configscriptpolicy.cpp:468–471`: `!requireStandard` before Genesis,
the setting `acceptNonStandardOutput` after it), or after Genesis under `requireStandard`. -/
def standardnessEnforced (cfg : NodeConfig) (preGenesis : Bool) : Bool :=
  !(if preGenesis then !cfg.requireStandard else cfg.acceptNonStandardOutput) || (!preGenesis && cfg.requireStandard)

/-- The gate at a node's caps for the spend's era (`sigOpsCap`, `sizeCap`): what the evaluator's
mempool column applies after the consensus gate (`Bsvs.Run.txGate`, the parent's wiring). The size
refusal is a standardness failure (`tx-size`, not `scriptpubkey`), enforced exactly when
`standardnessEnforced` holds (`validation.cpp:1080–1088`); the sigop cap is enforced whatever the
standardness settings (`1243–1247`). -/
def txPolicyGateFor (cfg : NodeConfig) (preGenesis : Bool) (tx : Tx) (sigOps : Nat) : Except PolicyReject Unit :=
  if standardnessEnforced cfg preGenesis then txPolicyGate tx sigOps (sigOpsCap cfg preGenesis) (sizeCap cfg preGenesis)
  else if sigOpsCap cfg preGenesis < sigOps then .error .tooManySigOps else .ok ()

/-- The node's "consensus configuration" for the two caps: what `-maxtxsizepolicy=0` and
`-maxtxsigopscountspolicy=0` select through the setters' zero rules (`configscriptpolicy.cpp:421–425`:
the consensus size; `config.cpp:2406–2409`: `UINT32_MAX`, the node's largest value). -/
def _root_.BsvScript.Params.NodeConfig.txPolicyAtConsensus (cfg : NodeConfig) : NodeConfig :=
  { cfg with maxTxSigOpsCountPolicy := MAX_TX_SIGOPS_COUNT_POLICY_AFTER_GENESIS,
             maxTxSizePolicy := MAX_TX_SIZE_CONSENSUS_AFTER_GENESIS }

-- The defaults by era, as decided facts (`docs/PARAMETERS.md` §4): bitcoin-sv 4,000 / 99,999 before
-- Genesis and UINT32_MAX / 10,000,000 after it; Teranode's after-Genesis size cap is 10,485,760.
example : sigOpsCap NodeConfig.svMainnetDefault true = 4000 := by decide
example : sizeCap NodeConfig.svMainnetDefault true = 99999 := by decide
example : sigOpsCap NodeConfig.svMainnetDefault false = 4294967295 := by decide
example : sizeCap NodeConfig.svMainnetDefault false = 10000000 := by decide
example : sizeCap NodeConfig.teranodeDefault false = 10485760 := by decide

end BsvScript.TxPolicy

namespace BsvScript.TxPolicy
open BsvScript.Params BsvScript.Tx BsvScript.TxRules

/-- **T-TP1.** *What it says:* the policy gate accepts exactly when the serialized size is within
the size cap and the sigop count within the sigop cap. *What it assumes:* nothing. *Why it matters:*
the gate is the two comparisons the node makes (`standard.cpp:446`, `1243`) and nothing else. -/
theorem txPolicyGate_ok_iff (tx : Tx) (sigOps c s : Nat) :
    txPolicyGate tx sigOps c s = .ok () ↔ (Sighash.serTx tx).length ≤ s ∧ sigOps ≤ c := by
  simp only [txPolicyGate, bind, Except.bind]
  constructor
  · intro h
    split_ifs at h with h1 h2; simp_all
  · rintro ⟨h1, h2⟩
    simp [Nat.not_lt.mpr h1, Nat.not_lt.mpr h2]
    rfl

/-- **T-TP1a.** The size refusal comes first (`1074` before `1243`): a transaction over the size cap
is `tx-size` whatever its sigop count. -/
theorem txPolicyGate_txSize (tx : Tx) (sigOps c s : Nat) (h : s < (Sighash.serTx tx).length) :
    txPolicyGate tx sigOps c s = .error .txSize := by
  simp [txPolicyGate, h, bind, Except.bind]
  rfl

/-- **T-TP1b.** Within the size cap, a sigop count over its cap is `bad-txns-too-many-sigops` (`1243–1246`). -/
theorem txPolicyGate_tooManySigOps (tx : Tx) (sigOps c s : Nat) (hs : (Sighash.serTx tx).length ≤ s)
    (hc : c < sigOps) : txPolicyGate tx sigOps c s = .error .tooManySigOps := by
  simp [txPolicyGate, Nat.not_lt.mpr hs, hc, bind, Except.bind]
  rfl

/-- The consensus gate's acceptance bounds the size: `CheckTransactionCommon` refuses `bad-txns-oversize`
above `maxSize` (`536–537`, the comment at `535`; T-TX6's `checkTransactionCommon_oversize` with the two
checks before it). -/
theorem checkTransactionCommon_ok_size (tx : Tx) (maxSigOps maxSize : Nat) (preGenesis : Bool)
    (h : checkTransactionCommon tx maxSigOps maxSize preGenesis = .ok ()) :
    (Sighash.serTx tx).length ≤ maxSize := by
  by_contra hc
  rw [Nat.not_le] at hc
  by_cases h1 : tx.inputs = []
  · rw [checkTransactionCommon_vinEmpty tx maxSigOps maxSize preGenesis h1] at h; cases h
  by_cases h2 : tx.outputs = []
  · rw [checkTransactionCommon_voutEmpty tx maxSigOps maxSize preGenesis h1 h2] at h; cases h
  rw [checkTransactionCommon_oversize tx maxSigOps maxSize preGenesis h1 h2 hc] at h; cases h

/-- The consensus gate's acceptance bounds the pre-Genesis sigop count: `CheckTransactionCommon` refuses
`bad-txn-sigops` above `maxSigOps` before Genesis (`560–567`), after the value loop. -/
theorem checkTransactionCommon_ok_sigops (tx : Tx) (maxSigOps maxSize : Nat)
    (h : checkTransactionCommon tx maxSigOps maxSize true = .ok ()) :
    sigOpCountWithoutP2SH tx ≤ maxSigOps := by
  by_contra hc
  rw [Nat.not_le] at hc
  simp only [checkTransactionCommon, bind, Except.bind, hc, Bool.true_and, decide_true, ite_true] at h
  split_ifs at h
  simp_all
  split at h <;> simp_all

/-- **T-TP2 (the identity on the consensus configuration, before Genesis).** *What it says:* with the
policy caps at the consensus values the consensus gate applies before Genesis (`MAX_TX_SIGOPS_COUNT_BEFORE_GENESIS`
= 20,000 and `MAX_TX_SIZE_CONSENSUS_BEFORE_GENESIS` = 1,000,000, `consensus.h:47`, `:27`), the policy gate
on the same count refuses nothing the consensus gate accepts. *What it assumes:* the consensus gate's
`.ok ()`. *Why it matters:* the policy gate adds nothing to consensus except where its caps are lower;
at the node's actual pre-Genesis caps (4,000 and 99,999, the constants of `sigOpsCap`/`sizeCap`) they
are lower, and `tx-00035` (20,000 sigops) is the witness of the difference where the standardness gate lets
it through: at a node that does not require standardness (`acceptnonstdtxn=1`) the sigop constant refuses it
`bad-txns-too-many-sigops`, while at SV-node's default it is refused `dust` first, for its zero-value outputs
(T-STD7). -/
theorem txPolicyGate_consensus_preGenesis (tx : Tx) (maxSigOps maxSize : Nat)
    (h : checkTransactionCommon tx maxSigOps maxSize true = .ok ()) :
    txPolicyGate tx (sigOpCountWithoutP2SH tx) maxSigOps maxSize = .ok () :=
  (txPolicyGate_ok_iff _ _ _ _).mpr
    ⟨checkTransactionCommon_ok_size tx maxSigOps maxSize true h, checkTransactionCommon_ok_sigops tx maxSigOps maxSize h⟩

/-- **T-TP3 (the identity on the consensus configuration, after Genesis).** *What it says:* after Genesis
the consensus gate has no sigop cap (`560`: "sigops are unlimited") and the size cap
`MAX_TX_SIZE_CONSENSUS_AFTER_GENESIS`; at that size cap the policy gate refuses only a sigop count over
its own cap, which is not a consensus rule: on the node's consensus configuration (`txPolicyAtConsensus`,
the zero rules) it accepts every transaction the consensus gate accepts whose count is at most
`UINT32_MAX`, the largest value the setter admits. *What it assumes:* the consensus gate's `.ok ()` at the
after-Genesis size cap and the count bound. *Why it matters:* at the zero-rule configuration what the caps
add to the block column is a count above `UINT32_MAX` (reachable after Genesis by the multisig count,
`multisigWitnessTx`, T-TP7; `txPolicyGateCounted` adds the count's error, T-TP6) and nothing of the size,
whatever the standardness settings. That is all the mempool's transaction gate adds to the block's
(`Bsvs.Run.txGate`) on a transaction the standardness gate passes (T-STD5), the scripts aside (they run under
the relay word and the policy limits, `Params.derive` with `consensus` false; for a version-2 spend after Chronicle
on mainnet, `Params.verifyScript_relay_block_version2`): the gate runs first (`1081–1089` before `1243`) and, the zero rules
changing only the caps, still refuses every reason but `scriptpubkey` after Genesis at SV-node's default
(T-TP9a, T-STD2; `dust` in T-STD8). -/
theorem txPolicyGate_consensus_postGenesis (cfg : NodeConfig) (tx : Tx) (maxSigOps sigOps : Nat)
    (h : checkTransactionCommon tx maxSigOps MAX_TX_SIZE_CONSENSUS_AFTER_GENESIS false = .ok ())
    (hc : sigOps ≤ MAX_TX_SIGOPS_COUNT_POLICY_AFTER_GENESIS) :
    txPolicyGateFor cfg.txPolicyAtConsensus false tx sigOps = .ok () := by
  unfold txPolicyGateFor sigOpsCap sizeCap NodeConfig.txPolicyAtConsensus
  simp only [Bool.false_eq_true, ite_false]
  split
  · exact (txPolicyGate_ok_iff _ _ _ _).mpr
      ⟨checkTransactionCommon_ok_size tx maxSigOps _ false h, hc⟩
  · simp [Nat.not_lt.mpr hc]

/-- **T-TP4.** *What it says:* before Genesis the node's caps are the two constants whatever the
configuration (`config.cpp:2424–2427`, `configscriptpolicy.cpp:399–406`): the gate accepts exactly a
transaction with at most 4,000 sigops and, under `requireStandard`, at most 99,999 bytes. *Why it
matters:* the cap settings do not reach the pre-Genesis mempool; the sigop constant refuses the witness
`tx-00035` (20,000 sigops) at every configuration, and decides the node's verdict where the standardness
gate lets it through (`acceptnonstdtxn=1`); at SV-node's default that gate refuses it first, `dust` (T-STD7). -/
theorem txPolicyGateFor_preGenesis_iff (cfg : NodeConfig) (tx : Tx) (sigOps : Nat) :
    txPolicyGateFor cfg true tx sigOps = .ok ()
      ↔ (cfg.requireStandard = true → (Sighash.serTx tx).length ≤ MAX_TX_SIZE_POLICY_BEFORE_GENESIS)
        ∧ sigOps ≤ MAX_TX_SIGOPS_COUNT_POLICY_BEFORE_GENESIS := by
  unfold txPolicyGateFor sigOpsCap sizeCap standardnessEnforced
  cases hr : cfg.requireStandard
  · by_cases hs : MAX_TX_SIGOPS_COUNT_POLICY_BEFORE_GENESIS < sigOps <;> simp [hs] <;> omega
  · simpa using txPolicyGate_ok_iff tx sigOps MAX_TX_SIGOPS_COUNT_POLICY_BEFORE_GENESIS
      MAX_TX_SIZE_POLICY_BEFORE_GENESIS

/-- **T-TP9a (the enforcement condition by era).** *What it says:* before Genesis a failed standardness
test refuses exactly under `requireStandard`; after Genesis exactly when the node does not accept
non-standard outputs or under `requireStandard`. *What it assumes:* nothing. *Why it matters:* this is
`validation.cpp:1080–1088` over `configscriptpolicy.cpp:468–471`, read once, so the size cap's reach is a
function of the two settings with their defaults and sources (`NodeConfig.requireStandard`,
`NodeConfig.acceptNonStandardOutput`). -/
theorem standardnessEnforced_eras (cfg : NodeConfig) :
    standardnessEnforced cfg true = cfg.requireStandard ∧
      standardnessEnforced cfg false = (!cfg.acceptNonStandardOutput || cfg.requireStandard) := by
  unfold standardnessEnforced
  cases cfg.requireStandard <;> cases cfg.acceptNonStandardOutput <;> simp

/-- **T-TP9 (the size cap is live at the node default; D123).** *What it says:* at SV-node's mainnet
default the standardness failures refuse in both eras, so after Genesis a transaction longer than
10,000,000 bytes is refused `tx-size` whatever its sigop count; at Teranode's default they refuse in
neither era. *What it assumes:* nothing. *Why it matters:* the maintainers' ruling D123
(2026-09-27) makes the evaluator's mempool column stand for the node default, `requireStandard`
true on mainnet (`chainparams.h:86`, `init.cpp:3158–3160`) with `acceptnonstdoutputs` true
(`configscriptpolicy.cpp:60`): the size cap `DEFAULT_MAX_TX_SIZE_POLICY_AFTER_GENESIS` (`policy.h:70`) is
live there, and the oracle's `acceptnonstdtxn=1` instance is the consensus instrument, not this column. -/
theorem txPolicyGateFor_svMainnetDefault_size (tx : Tx) (sigOps : Nat)
    (h : DEFAULT_MAX_TX_SIZE_POLICY_AFTER_GENESIS < (Sighash.serTx tx).length) :
    standardnessEnforced NodeConfig.svMainnetDefault true = true ∧
      standardnessEnforced NodeConfig.svMainnetDefault false = true ∧
      standardnessEnforced NodeConfig.teranodeDefault true = false ∧
      standardnessEnforced NodeConfig.teranodeDefault false = false ∧
      txPolicyGateFor NodeConfig.svMainnetDefault false tx sigOps = .error .txSize := by
  refine ⟨rfl, rfl, rfl, rfl, ?_⟩
  have hse : standardnessEnforced NodeConfig.svMainnetDefault false = true := rfl
  unfold txPolicyGateFor
  rw [hse]
  simp only [↓reduceIte]
  exact txPolicyGate_txSize tx sigOps _ _ h

end BsvScript.TxPolicy

namespace BsvScript.TxPolicy
open BsvScript.Params BsvScript.Tx BsvScript.Machine BsvScript.Numbers

/-! ## The mempool's sigop count on every path (2026-09-27: the spec gap's remainder)

`GetTransactionSigOpCount(config, tx, view, true, era, …)` (`validation.cpp:495–517`) is what the
mempool compares (`1236–1248`) under the spend's era (`1032`): `GetSigOpCountWithoutP2SH` (`438–460`:
every unlocking and every locking script at `fAccurate = false`, `SigOps.sigOpCount false genesis`) and,
for a non-coinbase, `GetP2SHSigOpCount` (`463–494`): for every input whose coin is pre-Genesis by its own
height (`478–484`; a coin still in the mempool counts as post-Genesis, `478–479`, as its height
`MEMPOOL_HEIGHT` = `0x7FFFFFFF`, `protocol_era.h:14`, lies above both activation heights) and P2SH
(`486`), the accurate count of its redeem script (`SigOps.p2shRedeemSigOps`). `sigOpCountError` refuses
at any cap (`1243`): `txPolicyGateCounted` on `none`. `mempoolTxPolicy` is the gate over the spend's and
the coins' heights for the evaluator's mempool column; the count `TxRules.sigOpCountWithoutP2SH` that
`txPolicyGateFor` was handed until now is its pre-Genesis part on every script without a literal `0xff`
(`sigOpCountWithoutP2SHAt_legacy_eq`).
-/

/-- `GetSigOpCountWithoutP2SH(tx, era, …)` (`validation.cpp:437–459`) under an era: every unlocking
script, then every locking script, at `fAccurate = false` (`445`, `454`); `genesis` is
`IsProtocolActive(era, ProtocolName::Genesis)`; `none` is `sigOpCountError` (`446–449`, `455–458`). -/
def sigOpCountWithoutP2SHAt (genesis : Bool) (tx : Tx) : Option Nat :=
  SigOps.sumOpt (tx.inputs.map (fun i => SigOps.sigOpCount false genesis i.scriptSig)
    ++ tx.outputs.map (fun o => SigOps.sigOpCount false genesis o.scriptPubKey))

/-- `GetP2SHSigOpCount` (`validation.cpp:462–493`): nothing for a coinbase (`469–471`); for every input,
with its coin's locking script and whether Genesis is active at the coin's height (`coins`, aligned
with the inputs, `475–481`), the redeem script's count when the coin is pre-Genesis (`482–484`) and P2SH
(`486–487`); `none` is `sigOpCountError` (`488–490`). -/
def p2shSigOpCount (tx : Tx) (coins : List (Bytes × Bool)) : Option Nat :=
  if TxRules.isCoinBase tx then some 0
  else SigOps.sumOpt ((tx.inputs.zip coins).map fun ic =>
    if ic.2.2 then some 0 else if isP2SH ic.2.1 then SigOps.p2shRedeemSigOps ic.1.scriptSig else some 0)

/-- `GetTransactionSigOpCount(config, tx, view, true, era, …)` (`validation.cpp:495–517`): the count without
P2SH (`504–507`), then, for a non-coinbase, the P2SH part (`509–515`); `none` is `sigOpCountError`. -/
def txSigOpCount (genesis : Bool) (tx : Tx) (coins : List (Bytes × Bool)) : Option Nat :=
  match sigOpCountWithoutP2SHAt genesis tx with
  | none => none
  | some base => if TxRules.isCoinBase tx then some base else (p2shSigOpCount tx coins).map (base + ·)

/-- The mempool's sigop test on the counted path (`validation.cpp:1242–1246`): `sigOpCountError ||
nSigOpsCount > GetMaxTxSigOpsCountPolicy(era)` refuses `bad-txns-too-many-sigops`; the size test runs
first (`1074`) under the standardness settings, exactly as `txPolicyGateFor` orders them. -/
def txPolicyGateCounted (cfg : NodeConfig) (preGenesis : Bool) (tx : Tx) :
    Option Nat → Except PolicyReject Unit
  | some n => txPolicyGateFor cfg preGenesis tx n
  | none =>
    if standardnessEnforced cfg preGenesis && decide (sizeCap cfg preGenesis < (Sighash.serTx tx).length) then .error .txSize
    else .error .tooManySigOps

/-- `GetAcceptNonStandardOutput(era)` (`configscriptpolicy.cpp:468–471`): after Genesis the setting
`acceptNonStandardOutput`, before it `!requireStandard`. -/
def acceptsNonStandardOutput (cfg : NodeConfig) (preGenesis : Bool) : Bool :=
  if preGenesis then !cfg.requireStandard else cfg.acceptNonStandardOutput

/-- Whether `IsStandardTx`'s reason `r` refuses the transaction (`validation.cpp:1080–1088`): when the node does
not accept non-standard outputs for the era, or after Genesis under `requireStandard` for a reason other than
`scriptpubkey` (`1085`). -/
def refusesNonStandard (cfg : NodeConfig) (preGenesis : Bool) (r : Standard.NonStandard) : Bool :=
  !acceptsNonStandardOutput cfg preGenesis || (!preGenesis && cfg.requireStandard && r != .scriptPubKey)

/-- `AreInputsStandard`'s refusal (`validation.cpp:1206–1223`): only where the node does not accept
non-standard outputs for the era, `bad-txns-nonstandard-inputs` when an input's coin is not standard. Where it
accepts them, the test at `1226–1235` refuses only as a validation timeout, and a high-priority transaction
is re-queued at low priority (`txn_validator.cpp:633–641`), where the test is not run (`1226`): not a
refusal of the inputs. -/
def inputsRefusal (cfg : NodeConfig) (spendHeight : Nat) (tx : Tx) (coins : List (Bytes × Nat))
    (preGenesis : Bool) : Option PolicyReject :=
  if !acceptsNonStandardOutput cfg preGenesis && !Standard.areInputsStandard cfg spendHeight tx coins then
    some .nonStandardInputs
  else none

/-- The standardness gate (`validation.cpp:1072–1088`, then `1207–1224`): `IsStandardTx` at the spend's height
(`1074`: the tip plus one, the mempool's spend height) with its first reason, refused as `refusesNonStandard`
says (`1087`); then `AreInputsStandard` (`inputsRefusal`). The lock-time and BIP68 finality tests between
them (`1092–1205`) are not this gate's. -/
def standardnessRefusal (cfg : NodeConfig) (spendHeight : Nat) (tx : Tx) (coins : List (Bytes × Nat)) :
    Option PolicyReject :=
  let era := cfg.protocolEra spendHeight
  match Standard.isStandardTx cfg era.genesisActive era.chronicleActive (sizeCap cfg (!era.genesisActive)) tx with
  | some r =>
    if refusesNonStandard cfg (!era.genesisActive) r then some (.nonStandard r)
    else inputsRefusal cfg spendHeight tx coins (!era.genesisActive)
  | none => inputsRefusal cfg spendHeight tx coins (!era.genesisActive)

/-- The mempool's policy gate for a spend at `spendHeight` of the coins `coins` (each spent output's locking
script and height, aligned with the inputs): the standardness gate first (`validation.cpp:1072–1088`,
`1207–1224`), then the sigop cap on the count under the spend's era (`1032`, `1236–1248`), each coin's era
from its own height (`480`), both through `NodeConfig.protocolEra` (`protocol_era.cpp:42–47`). The caps' size
test inside `txPolicyGateCounted` is the standardness gate's own and never refuses after it passes
(`mempoolTxPolicy_of_standard`). -/
def mempoolTxPolicy (cfg : NodeConfig) (spendHeight : Nat) (tx : Tx) (coins : List (Bytes × Nat)) :
    Except PolicyReject Unit :=
  match standardnessRefusal cfg spendHeight tx coins with
  | some e => .error e
  | none =>
    let genesis := (cfg.protocolEra spendHeight).genesisActive
    txPolicyGateCounted cfg (!genesis) tx
      (txSigOpCount genesis tx (coins.map fun c => (c.1, (cfg.protocolEra c.2).genesisActive)))

/-- The witness of a post-Genesis count past `UINT32_MAX` (`SigOps.sigOpCount_multisig_max`): one input
(a synthetic outpoint, an empty unlocking script) and three outputs of 1 satoshi each (not dust,
`Standard.isDust`) paying `04 ffffff7f OP_CHECKMULTISIG`, 18 bytes of locking script in all. -/
def multisigWitnessTx : Tx :=
  { version := 2
    inputs := [{ prevHash := List.replicate 32 1, prevIndex := 0, scriptSig := [], sequence := 0xffffffff }]
    outputs := List.replicate 3 { value := 1, scriptPubKey := [0x04, 0xff, 0xff, 0xff, 0x7f, Op.OP_CHECKMULTISIG] }
    lockTime := 0 }

/-- The witness of an unbalanced `OP_ENDIF` (`SigOps.sigOpCount_endif`): one input and one output of
0 satoshis paying `OP_ENDIF`. -/
def endifWitnessTx : Tx :=
  { version := 2
    inputs := [{ prevHash := List.replicate 32 1, prevIndex := 0, scriptSig := [], sequence := 0xffffffff }]
    outputs := [{ value := 0, scriptPubKey := [Op.OP_ENDIF] }]
    lockTime := 0 }

/-- The legacy walk is `TxRules.sigOpCountPreGenesis` on a script without a literal `0xff`, generalized over
the state (the induction behind T-SO10). -/
theorem sigOpWalk_legacy_eq : ∀ (fuel : Nat) (s : Bytes) (lo : Nat) (ld : Bytes) (n : Nat),
    s.length ≤ fuel → SigOps.noInvalidOp s = true →
      SigOps.sigOpWalk false false fuel s lo ld 0 n = some (n + TxRules.sigOpCountPreGenesis s) := by
  intro fuel
  induction fuel with
  | zero =>
    intro s lo ld n hl _
    have : s = [] := List.eq_nil_of_length_eq_zero (by omega)
    subst this
    simp [SigOps.sigOpWalk, TxRules.sigOpCountPreGenesis_nil]
  | succ f ih =>
    intro s lo ld n hl hno
    cases s with
    | nil => simp [SigOps.sigOpWalk, TxRules.sigOpCountPreGenesis_nil]
    | cons op rest =>
      rw [SigOps.noInvalidOp] at hno
      rw [TxRules.sigOpCountPreGenesis]
      simp only [SigOps.sigOpWalk]
      cases hgt : getOpTail op rest with
      | none => simp
      | some dk =>
        obtain ⟨data, k⟩ := dk
        simp only [hgt, Bool.and_eq_true, bne_iff_ne, ne_eq] at hno
        obtain ⟨hff, hno'⟩ := hno
        have hsc : SigOps.scopeAfter false op 0 = 0 := by simp [SigOps.scopeAfter]
        have hlen : (rest.drop k).length ≤ f := by
          simp only [List.length_drop, List.length_cons] at hl ⊢; omega
        have hadd : SigOps.opSigOps false false op lo ld =
            some (if op = Op.OP_CHECKSIG || op = Op.OP_CHECKSIGVERIFY then 1
              else if op = Op.OP_CHECKMULTISIG || op = Op.OP_CHECKMULTISIGVERIFY then
                TxRules.MAX_PUBKEYS_PER_MULTISIG_BEFORE_GENESIS else 0) := by
          unfold SigOps.opSigOps
          rw [SigOps.multisigSigOps_legacy]
          by_cases h1 : op = Op.OP_CHECKSIG ∨ op = Op.OP_CHECKSIGVERIFY
          · rcases h1 with h1 | h1 <;> subst h1 <;> decide
          · by_cases h2 : op = Op.OP_CHECKMULTISIG ∨ op = Op.OP_CHECKMULTISIGVERIFY
            · rcases h2 with h2 | h2 <;> subst h2 <;> decide
            · simp only [not_or] at h1 h2
              simp [h1, h2]
        simp only [hff, Bool.or_self, Bool.false_and, Bool.false_eq_true, ite_false, hadd, hsc]
        have h00 : ¬ ((0 : Int) < 0) := by decide
        simp only [h00, ite_false]
        rw [ih _ _ _ _ hlen hno']
        simp only [Option.some.injEq]
        omega

/-- **T-SO10 (the pre-Genesis count is `TxRules`'s).** *What it says:* before Genesis without `fAccurate`,
the count of a script without a literal `0xff` is `TxRules.sigOpCountPreGenesis`, the consensus gate's
count. *What it assumes:* no instruction of the script is `0xff`. *Why it matters:* the mempool's count and
the consensus gate's agree on the pre-Genesis path wherever the spec's `TxRules` walk agrees with the
reference. Since the Lean families' `616008e` both stop at a literal `0xff` (`script.cpp:44–45`; `SigOps.sigOpCount_ff`,
`TxRules.sigOpCountPreGenesis_invalidop`), and `TxRules.sigOpCountPreGenesis_eq_sigOpCount` (T-TX11) states the
equality on every script: this theorem's hypothesis is stronger than it needs to be. -/
theorem sigOpCount_legacy_eq (s : Bytes) (h : SigOps.noInvalidOp s = true) :
    SigOps.sigOpCount false false s = some (TxRules.sigOpCountPreGenesis s) := by
  have := sigOpWalk_legacy_eq s.length s Op.OP_INVALIDOPCODE [] 0 (Nat.le_refl _) h
  simpa [SigOps.sigOpCount] using this

/-- A sum of counts none of which fails is the sum of the numbers. -/
theorem sumOpt_map_some {α : Type} (l : List α) (f : α → Nat) :
    SigOps.sumOpt (l.map (fun x => some (f x))) = some (l.map f).sum := by
  induction l with
  | nil => rfl
  | cons x rest ih => simp [SigOps.sumOpt, ih]

/-- **T-SO11 (the transaction's pre-Genesis count).** *What it says:* before Genesis the count without P2SH
of a transaction none of whose scripts has a literal `0xff` is `TxRules.sigOpCountWithoutP2SH`. *What it
assumes:* no `0xff` instruction in any unlocking or locking script. *Why it matters:* `mempoolTxPolicy`
extends the count the policy gate was handed (`Bsvs.Run.txGate`'s `TxRules.sigOpCountWithoutP2SH`) by the
P2SH part and the post-Genesis path, and leaves the pre-Genesis part as it was. -/
theorem sigOpCountWithoutP2SHAt_legacy_eq (tx : Tx)
    (hi : ∀ i ∈ tx.inputs, SigOps.noInvalidOp i.scriptSig = true)
    (ho : ∀ o ∈ tx.outputs, SigOps.noInvalidOp o.scriptPubKey = true) :
    sigOpCountWithoutP2SHAt false tx = some (TxRules.sigOpCountWithoutP2SH tx) := by
  have e1 : tx.inputs.map (fun i => SigOps.sigOpCount false false i.scriptSig)
      = tx.inputs.map (fun i => some (TxRules.sigOpCountPreGenesis i.scriptSig)) :=
    List.map_congr_left (fun i hi' => sigOpCount_legacy_eq _ (hi i hi'))
  have e2 : tx.outputs.map (fun o => SigOps.sigOpCount false false o.scriptPubKey)
      = tx.outputs.map (fun o => some (TxRules.sigOpCountPreGenesis o.scriptPubKey)) :=
    List.map_congr_left (fun o ho' => sigOpCount_legacy_eq _ (ho o ho'))
  unfold sigOpCountWithoutP2SHAt TxRules.sigOpCountWithoutP2SH
  rw [e1, e2, SigOps.sumOpt_append, sumOpt_map_some, sumOpt_map_some]
  rfl

/-- **T-SO12 (the P2SH part vanishes on post-Genesis coins).** *What it says:* when every coin is
post-Genesis the P2SH part is 0. *What it assumes:* every coin's era Genesis-active. *Why it matters:* after
Genesis a P2SH output is refused (`validation.cpp:610–621`) and its redeem script never runs, so its sigops
never count (`482–484`); only a pre-Genesis coin spent after Genesis still brings its redeem script's count. -/
theorem p2shSigOpCount_genesis_coins (tx : Tx) (coins : List (Bytes × Bool))
    (h : ∀ c ∈ coins, c.2 = true) : p2shSigOpCount tx coins = some 0 := by
  unfold p2shSigOpCount
  split
  · rfl
  · apply SigOps.sumOpt_zeros
    intro x hx
    obtain ⟨ic, hic, rfl⟩ := List.mem_map.mp hx
    have hc := h ic.2 (List.of_mem_zip hic).2
    simp [hc]

/-- **T-SO13 (the count on post-Genesis coins).** *What it says:* when every coin is post-Genesis the
mempool's count is the count without P2SH. *What it assumes:* every coin's era Genesis-active. *Why it
matters:* the whole count of a post-Genesis spend of post-Genesis coins is the scripts' own, on the
post-Genesis path of `SigOps.sigOpCount` (its multisig count reaching 2,147,483,647 per instruction). -/
theorem txSigOpCount_genesis_coins (genesis : Bool) (tx : Tx) (coins : List (Bytes × Bool))
    (h : ∀ c ∈ coins, c.2 = true) : txSigOpCount genesis tx coins = sigOpCountWithoutP2SHAt genesis tx := by
  unfold txSigOpCount
  split
  · rename_i hn; rw [hn]
  · rename_i base hb
    rw [hb]
    split
    · rfl
    · rw [p2shSigOpCount_genesis_coins tx coins h]; rfl

/-- **T-SO14 (an output's error is the transaction's).** *What it says:* when an output script's count is
`sigOpCountError`, the transaction's count is too. *What it assumes:* the output is the transaction's.
*Why it matters:* one output opening with an unbalanced `OP_ENDIF` (after Genesis), or a multisig after
a bad count push, makes the whole transaction's count an error (`validation.cpp:453–457`), refused by the
mempool at any cap (`txPolicyGateCounted_error`). -/
theorem txSigOpCount_output_error (genesis : Bool) (tx : Tx) (coins : List (Bytes × Bool)) (o : TxOut)
    (ho : o ∈ tx.outputs) (h : SigOps.sigOpCount false genesis o.scriptPubKey = none) :
    txSigOpCount genesis tx coins = none := by
  have : sigOpCountWithoutP2SHAt genesis tx = none := by
    unfold sigOpCountWithoutP2SHAt
    rw [SigOps.sumOpt_eq_none_iff]
    exact List.mem_append_right _ (List.mem_map.mpr ⟨o, ho, h⟩)
  unfold txSigOpCount
  rw [this]

/-- **T-TP5 (`sigOpCountError` refuses at any cap).** *What it says:* on a count that is `sigOpCountError`
the gate refuses, whatever the node's configuration and era. *What it assumes:* nothing. *Why it matters:*
`sigOpCountError || nSigOpsCount > cap` (`validation.cpp:1242`): no cap setting admits the error. -/
theorem txPolicyGateCounted_error (cfg : NodeConfig) (preGenesis : Bool) (tx : Tx) :
    txPolicyGateCounted cfg preGenesis tx none ≠ .ok () := by
  simp only [txPolicyGateCounted]
  split <;> simp

/-- **T-TP6 (what the counted gate adds after Genesis, at the consensus configuration).** *What it says:*
after Genesis, on the node's zero-rule caps (`txPolicyAtConsensus`), a transaction the consensus gate
accepts passes the counted gate exactly when its count is a number of at most `UINT32_MAX`. *What it
assumes:* the consensus gate's `.ok ()` at the after-Genesis size cap. *Why it matters:* on a transaction the
standardness gate passes (T-STD5), this is the whole difference between the block's transaction gate and the
mempool's (`Bsvs.Run.txGate`) after Genesis at those caps, the scripts aside (they run under the relay word and
the policy limits, `Params.derive` with `consensus` false; for a version-2 spend after Chronicle on mainnet,
`Params.verifyScript_relay_block_version2`): a `sigOpCountError` (an unbalanced `OP_ENDIF`, a bad multisig count
push) or a count past `UINT32_MAX` (`multisigWitnessTx`), never the size (T-TP3); the standardness gate,
which runs first, adds its own reasons (`dust` in T-STD8). -/
theorem txPolicyGateCounted_postGenesis_iff (cfg : NodeConfig) (tx : Tx) (maxSigOps : Nat)
    (c : Option Nat)
    (h : TxRules.checkTransactionCommon tx maxSigOps MAX_TX_SIZE_CONSENSUS_AFTER_GENESIS false = .ok ()) :
    txPolicyGateCounted cfg.txPolicyAtConsensus false tx c = .ok ()
      ↔ ∃ n, c = some n ∧ n ≤ MAX_TX_SIGOPS_COUNT_POLICY_AFTER_GENESIS := by
  cases c with
  | none =>
    constructor
    · intro hc; exact absurd hc (txPolicyGateCounted_error _ _ _)
    · rintro ⟨n, hn, -⟩; cases hn
  | some n =>
    constructor
    · intro hc
      refine ⟨n, rfl, ?_⟩
      simp only [txPolicyGateCounted] at hc
      by_contra hlt
      rw [Nat.not_le] at hlt
      unfold txPolicyGateFor sigOpsCap sizeCap NodeConfig.txPolicyAtConsensus at hc
      simp only [Bool.false_eq_true, ite_false] at hc
      split at hc
      · rw [txPolicyGate_ok_iff] at hc; omega
      · simp at hc
    · rintro ⟨m, hm, hle⟩
      simp only [Option.some.injEq] at hm
      subst hm
      simp only [txPolicyGateCounted]
      exact txPolicyGate_consensus_postGenesis cfg tx maxSigOps _ h hle

/-- **T-TP7 (the witness of the count past `UINT32_MAX`).** *What it says:* after Genesis the transaction
`multisigWitnessTx` counts 6,442,450,941 on post-Genesis coins, the consensus gate accepts it, and the
mempool refuses it `bad-txns-too-many-sigops` at SV-node's mainnet default (the cap `UINT32_MAX`, also the
largest the setter admits, `config.cpp:2391–2415`), past the standardness gate (its outputs have no type, the
reason `scriptpubkey`, which that default relays after Genesis, T-STD3). *What it assumes:* nothing. *Why it matters:* the
post-Genesis count path decides a real verdict: a consensus-valid transaction of 18 bytes of locking
script no SV-node mempool relays whatever its setting; the corpus entry that exercises it is the
harness's (#26). -/
theorem mempoolTxPolicy_multisig_witness :
    txSigOpCount true multisigWitnessTx [([Op.OP_1], true)] = some 6442450941 ∧
    TxRules.checkRegularTransaction multisigWitnessTx TxRules.MAX_TX_SIGOPS_COUNT_BEFORE_GENESIS
      MAX_TX_SIZE_CONSENSUS_AFTER_GENESIS false = .ok () ∧
    mempoolTxPolicy NodeConfig.svMainnetDefault 967896 multisigWitnessTx [([Op.OP_1], 967896)]
      = .error .tooManySigOps := by
  refine ⟨by decide, rfl, rfl⟩

/-- **T-TP8 (the witness of the unbalanced `OP_ENDIF`).** *What it says:* after Genesis the transaction
`endifWitnessTx` has no count, and the mempool refuses it at every node configuration. *What it assumes:*
a spend after Genesis. *Why it matters:* `sigOpCountError` (`script.cpp:59–67`) on an output script that
no script ever executes still keeps the transaction out of every SV-node mempool (`validation.cpp:1242`),
whether or not the standardness gate refuses it first (its zero-value output is dust, refused where the
gate's condition holds); the corpus entry that exercises it is the harness's (#26). -/
theorem mempoolTxPolicy_endif_witness (cfg : NodeConfig) (spendHeight : Nat) (coins : List (Bytes × Nat))
    (h : cfg.genesisActivationHeight ≤ spendHeight) :
    mempoolTxPolicy cfg spendHeight endifWitnessTx coins ≠ .ok () := by
  have hg : (cfg.protocolEra spendHeight).genesisActive = true := by
    simp only [NodeConfig.protocolEra, protocolEraOf]
    split
    · omega
    · split <;> rfl
  have hn : txSigOpCount true endifWitnessTx
      (coins.map fun c => (c.1, (cfg.protocolEra c.2).genesisActive)) = none :=
    txSigOpCount_output_error true _ _ { value := 0, scriptPubKey := [Op.OP_ENDIF] } (by simp [endifWitnessTx])
      (SigOps.sigOpCount_endif false true (by rfl) [])
  unfold mempoolTxPolicy
  split
  · intro h; cases h
  · simp only [hg, hn]
    exact txPolicyGateCounted_error _ _ _

/-! ## The standardness gate's properties (2026-09-28: `tx.gate.standardness.unmodelled`)

The gate (`standardnessRefusal`, above `mempoolTxPolicy`) is `IsStandardTx` and `AreInputsStandard`
(`BsvScript.Standard`) where `validation.cpp:1080–1088` and `1207–1224` refuse them. Its condition is the node's
two settings by era (`acceptsNonStandardOutput`), so at SV-node's mainnet default (`requireStandard` true) every
reason refuses before Genesis, every reason but `scriptpubkey` after it, and a non-standard input only before it;
at Teranode's default (`requireStandard` false, `acceptnonstdoutputs` true) the gate refuses nothing and the
mempool gate is the caps' counted gate, as it was: there the sigop cap and the count's error, the size cap
applying only under `standardnessEnforced`, false at that default (T-TP9). The witnesses are the shapes of the
road's five pre-Genesis rows the standardness decides (`corpus/tx`: the class's four, `tx-00032`, `tx-00037`,
`tx-00038` `scriptpubkey` and `tx-00036` `bad-txns-nonstandard-inputs`, and `tx-00035`'s code note, `dust`; the
parent's `**Finding.**` on #27, 5860811662).
-/

/-- **T-STD1 (the gate's condition at the two defaults).** *What it says:* SV-node's mainnet default does not
accept non-standard outputs before Genesis and does after it; Teranode's default accepts them in both eras.
*What it assumes:* nothing. *Why it matters:* it fixes where each refusal applies at each default
(`configscriptpolicy.cpp:468–471` over `requireStandard` and `acceptnonstdoutputs`). -/
theorem acceptsNonStandardOutput_defaults :
    acceptsNonStandardOutput NodeConfig.svMainnetDefault true = false ∧
    acceptsNonStandardOutput NodeConfig.svMainnetDefault false = true ∧
    acceptsNonStandardOutput NodeConfig.teranodeDefault true = true ∧
    acceptsNonStandardOutput NodeConfig.teranodeDefault false = true := by
  decide

/-- **T-STD2 (every reason but one refuses as the size cap does).** *What it says:* a reason other than
`scriptpubkey` refuses exactly when `standardnessEnforced` holds. *What it assumes:* the reason is not
`scriptpubkey`. *Why it matters:* the size reason (`tx-size`) is one of them, so the gate's size refusal and the
caps' (`txPolicyGateFor` under `standardnessEnforced`, T-TP9) are one rule and the caps' theorems still hold. -/
theorem refusesNonStandard_of_ne (cfg : NodeConfig) (pg : Bool) (r : Standard.NonStandard)
    (h : r ≠ .scriptPubKey) : refusesNonStandard cfg pg r = standardnessEnforced cfg pg := by
  have hb : (r != .scriptPubKey) = true := bne_iff_ne.mpr h
  unfold refusesNonStandard standardnessEnforced acceptsNonStandardOutput
  cases pg <;> simp [hb]

/-- **T-STD3 (the `scriptpubkey` reason).** *What it says:* a transaction whose only reason is an output with no
standard type is refused exactly when the node does not accept non-standard outputs for the era. *What it
assumes:* nothing. *Why it matters:* after Genesis SV-node's default passes such a transaction
(`1085`: `reason != "scriptpubkey"`), and before Genesis it refuses it (`1084`). A P2SH output never reaches
the test after Genesis: consensus refuses it first (`610–623`, `bad-txns-vout-p2sh`, checked at `1036`, before
`IsStandardTx` at `1074`). -/
theorem refusesNonStandard_scriptPubKey (cfg : NodeConfig) (pg : Bool) :
    refusesNonStandard cfg pg .scriptPubKey = !acceptsNonStandardOutput cfg pg := by
  unfold refusesNonStandard
  cases pg <;> simp

/-- **T-STD4 (the gate is off where non-standard transactions are accepted).** *What it says:* a node that
neither requires standardness nor refuses non-standard outputs after Genesis refuses nothing at the
standardness gate, in any era. *What it assumes:* `requireStandard` false and `acceptNonStandardOutput` true.
*Why it matters:* Teranode's default is such a node (T-STD1), and there the mempool gate is the caps'
counted gate (T-STD5, T-STD6), which refuses only a sigop count over the cap or the count's error: its size
cap applies only under `standardnessEnforced`, false there (T-TP9). -/
theorem standardnessRefusal_off (cfg : NodeConfig) (h1 : cfg.requireStandard = false)
    (h2 : cfg.acceptNonStandardOutput = true) (spendHeight : Nat) (tx : Tx) (coins : List (Bytes × Nat)) :
    standardnessRefusal cfg spendHeight tx coins = none := by
  unfold standardnessRefusal inputsRefusal refusesNonStandard acceptsNonStandardOutput
  dsimp only
  split <;> simp [h1, h2]

/-- **T-STD5 (the gate passed, the caps decide).** *What it says:* when the standardness gate refuses nothing,
the mempool gate is the two caps on the node's count. *What it assumes:* no standardness refusal. *Why it
matters:* the caps' theorems (T-TP1 to T-TP9) describe the mempool gate on every standard transaction and at
every node that accepts non-standard ones; the caps' size test is never the one that refuses after the gate,
which runs the same test first (T-STD2). -/
theorem mempoolTxPolicy_of_standard (cfg : NodeConfig) (spendHeight : Nat) (tx : Tx) (coins : List (Bytes × Nat))
    (h : standardnessRefusal cfg spendHeight tx coins = none) :
    mempoolTxPolicy cfg spendHeight tx coins =
      txPolicyGateCounted cfg (!(cfg.protocolEra spendHeight).genesisActive) tx
        (txSigOpCount (cfg.protocolEra spendHeight).genesisActive tx
          (coins.map fun c => (c.1, (cfg.protocolEra c.2).genesisActive))) := by
  unfold mempoolTxPolicy
  simp only [h]

/-- **T-STD6 (Teranode's default).** *What it says:* at Teranode's default (v0.15.9's and v0.16.0's: they differ only in `maxScriptSizePolicy`, which this gate does not read) the mempool gate is the caps'
counted gate (`txPolicyGateCounted`), in every era and for every transaction. *What it assumes:* nothing. *Why
it matters:* modeling the standardness moves no verdict of the Teranode columns; it moves SV-node's. At Teranode's default the
counted gate refuses only a sigop count over the cap or the count's error: its size cap applies only under
`standardnessEnforced`, false at that default in both eras (T-TP9). -/
theorem mempoolTxPolicy_teranodeDefault (spendHeight : Nat) (tx : Tx) (coins : List (Bytes × Nat)) :
    mempoolTxPolicy NodeConfig.teranodeDefault spendHeight tx coins =
      txPolicyGateCounted NodeConfig.teranodeDefault (!(NodeConfig.teranodeDefault.protocolEra spendHeight).genesisActive) tx
        (txSigOpCount (NodeConfig.teranodeDefault.protocolEra spendHeight).genesisActive tx
          (coins.map fun c => (c.1, (NodeConfig.teranodeDefault.protocolEra c.2).genesisActive))) :=
  mempoolTxPolicy_of_standard _ _ _ _ (standardnessRefusal_off _ rfl rfl _ _ _)

/-- A spend for the standardness witnesses: version 1, one input (a synthetic outpoint, an empty unlocking
script) and one output. -/
def stdWitnessTx (out : TxOut) : Tx :=
  { version := 1
    inputs := [{ prevHash := List.replicate 32 1, prevIndex := 0, scriptSig := [], sequence := 0xffffffff }]
    outputs := [out]
    lockTime := 0 }

/-- A pay-to-public-key-hash locking script (`OP_DUP OP_HASH160 <20 bytes> OP_EQUALVERIFY OP_CHECKSIG`),
the template `standard.cpp:53–57`. -/
def p2pkhScript : Bytes :=
  [Op.OP_DUP, Op.OP_HASH160, 0x14] ++ List.replicate 20 0x11 ++ [Op.OP_EQUALVERIFY, Op.OP_CHECKSIG]

/-- Every unlocking script of a standardness witness is empty. -/
theorem stdWitnessTx_inputs (out : TxOut) : ∀ i ∈ (stdWitnessTx out).inputs, i.scriptSig = [] := by
  simp [stdWitnessTx]

/-- **T-STD7 (the road's pre-Genesis rows, by shape).** *What it says:* at SV-node's mainnet default, for a
spend at 610,000 (before Genesis) of a coin of 600,000: a transaction creating a one-satoshi `OP_TRUE` output
is refused `scriptpubkey`; one creating a zero-value `OP_TRUE` output is refused `dust`, before its type is
reported (`standard.cpp:476–485`, then `:493–497`); one creating a standard output (pay to a key hash) from an
`OP_TRUE` coin is refused `bad-txns-nonstandard-inputs`. *What it assumes:* the witnesses' shapes. *Why it
matters:* these are the node's mempool verdicts on `tx-00032`, `tx-00037` and `tx-00038`, `tx-00035` and
`tx-00036` (`docs/records/20260927-231608-d123-road-s3.md` for `tx-00032`, `tx-00035`, `tx-00036` and `tx-00037`,
`docs/records/20260928-113333-road-a3-s3.md` for all five), which the spec's gate did not give before it modeled the standardness. -/
theorem standardnessRefusal_preGenesis_witnesses :
    standardnessRefusal NodeConfig.svMainnetDefault 610000 (stdWitnessTx ⟨1, [Op.OP_1]⟩) [([Op.OP_1], 600000)]
      = some (.nonStandard .scriptPubKey) ∧
    standardnessRefusal NodeConfig.svMainnetDefault 610000 (stdWitnessTx ⟨0, [Op.OP_1]⟩) [([Op.OP_1], 600000)]
      = some (.nonStandard .dust) ∧
    standardnessRefusal NodeConfig.svMainnetDefault 610000 (stdWitnessTx ⟨1, p2pkhScript⟩) [([Op.OP_1], 600000)]
      = some .nonStandardInputs := by
  refine ⟨?_, ?_, ?_⟩ <;>
  · unfold standardnessRefusal Standard.isStandardTx
    dsimp only
    rw [Standard.inputsReason_empty _ _ _ (stdWitnessTx_inputs _)]
    decide +kernel

/-- **T-STD8 (the same shapes after Genesis).** *What it says:* at SV-node's mainnet default, for a spend at
967,896 (after Chronicle) of a coin of the same height, the one-satoshi `OP_TRUE` output and the `OP_TRUE` coin
are not refused, and the zero-value output is refused `dust`. *What it assumes:* the witnesses' shapes. *Why it
matters:* after Genesis that default's gate refuses no output for having no standard type, and no coin (`1085`,
`1208`), and still refuses dust, a reason other than `scriptpubkey`; a P2SH output never reaches the gate after
Genesis, refused first by consensus (`610–623`, `bad-txns-vout-p2sh`, at `1036`). -/
theorem standardnessRefusal_postGenesis_witnesses :
    standardnessRefusal NodeConfig.svMainnetDefault 967896 (stdWitnessTx ⟨1, [Op.OP_1]⟩) [([Op.OP_1], 967896)]
      = none ∧
    standardnessRefusal NodeConfig.svMainnetDefault 967896 (stdWitnessTx ⟨1, p2pkhScript⟩) [([Op.OP_1], 967896)]
      = none ∧
    standardnessRefusal NodeConfig.svMainnetDefault 967896 (stdWitnessTx ⟨0, [Op.OP_1]⟩) [([Op.OP_1], 967896)]
      = some (.nonStandard .dust) := by
  refine ⟨?_, ?_, ?_⟩ <;> decide +kernel

end BsvScript.TxPolicy
