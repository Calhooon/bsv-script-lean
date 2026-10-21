import BsvChain.Status

/-!
# Status vocabularies, 2026-10-13 [D] (#67)

Every definition and theorem here is a view, never a rule. Partial semantic functions use the facts Status determines. Exact stored
producer words separately need history; no-function cells record independent
inputs on the remaining domains. Witness contexts
are derived local inputs, never measurements of these programs.

[SRC] Arcade models/transaction.go:87-113,126-247,329-333 at 1ae1208e,
https://github.com/bsv-blockchain/arcade/blob/1ae1208e/models/transaction.go.
[SRC] wallet-toolbox packages/wallet/wallet-toolbox/src/sdk/types.ts:19-84
at edf6e03d, https://github.com/bsv-blockchain/ts-stack/blob/edf6e03d/packages/wallet/wallet-toolbox/src/sdk/types.ts.
[SRC] Stored TransactionStatus failure/recovery steps, edf6e03d:
https://github.com/bsv-blockchain/ts-stack/blob/edf6e03d/packages/wallet/wallet-toolbox/src/monitor/tasks/TaskFailAbandoned.ts#L36-L46;
https://github.com/bsv-blockchain/ts-stack/blob/edf6e03d/packages/wallet/wallet-toolbox/src/storage/methods/ListActionsSpecOp.ts#L123-L139.
[SRC] Signed send intent, edf6e03d:
https://github.com/bsv-blockchain/ts-stack/blob/edf6e03d/packages/wallet/wallet-toolbox/src/storage/methods/processAction.ts#L359-L370.
Completed notifications require sdk/types.ts:50, independent of active inclusion.
[SRC] Teranode services/validator/validator_api/validator_api.proto:88-105,
services/validator/Server.go:899-909,941-1002 and
services/propagation/Server.go:755-790; errors/Error_types.go:31,37 at v0.16.0 (4edb60a4),
https://github.com/bsv-blockchain/teranode/tree/4edb60a40c6628ff0ef60231c2628efd7103fde5/services. [SRC] Node column (#74): stores/utxo/fields/fields.go:40,64-66,79, stores/utxo/aerospike/teranode.lua:584-606, services/rpc/handlers.go:127-142,924-931, services/asset/httpimpl/GetUTXOsByTXID.go:40-46, services/asset/httpimpl/http.go:340, services/rpc/handlers.go:854-856,880-904,1353, stores/utxo/aerospike/spend.go:1095, services/legacy/netsync/manager.go:487,1335-1352, daemon/daemon.go:577-600, services/validator/Validator.go:976-983 at 4edb60a4, read through docs/CONFORMANCE-TERANODE-MACHINE.md sections 1, 5 and 6; witnesses: docs/records/20261014-215508-s6-74-second-oracle-s4b.md.
[SRC] Exact structural-invalid receipt: src/validation.cpp:526-527,
https://github.com/bitcoin-sv/bitcoin-sv/blob/6504a3aff65ba97c0f6c80962b033e35ecbfed4b/src/validation.cpp#L526-L527.
[SRC] bitcoin-sv src/consensus/validation.h:14-24,
src/validation.h:1150-1163, src/rpc/rawtransaction.cpp:1636-1650,1716-1724
at 6504a3aff65ba97c0f6c80962b033e35ecbfed4b.
-/

namespace BsvChain.Views

/-- [SRC] 2026-10-13: Arcade's literal words at models/transaction.go:87-113,
1ae1208e. A vocabulary of views, never rules. -/
inductive Arcade where
  | UNKNOWN | RECEIVED | SENT_TO_NETWORK | ACCEPTED_BY_NETWORK
  | SEEN_ON_NETWORK | SEEN_MULTIPLE_NODES | DOUBLE_SPEND_ATTEMPTED
  | REJECTED | PENDING_RETRY | STUMP_PROCESSING | MINED | IMMUTABLE
  deriving DecidableEq, Repr

/-- [SRC] 2026-10-13: ProvenTxReqStatus at sdk/types.ts:54-67, edf6e03d,
wallet-toolbox in ts-stack. These process views are never rules. -/
inductive ProvenTxReq where
  | sending | unsent | nosend | unknown | nonfinal | unprocessed | unmined
  | callback | unconfirmed | completed | invalid | doubleSpend | unfail
  deriving DecidableEq, Repr

/-- [SRC] 2026-10-13: TransactionStatus at sdk/types.ts:83-84, edf6e03d,
wallet-toolbox in ts-stack. These stored views are never rules. -/
inductive WalletTransaction where
  | completed | failed | unprocessed | sending | unproven | unsigned
  | nosend | nonfinal | unfail
  deriving DecidableEq, Repr

/-- [SRC] 2026-10-13: validator valid boolean and HTTP /tx responses,
Teranode validator_api.proto:88-92 and services/validator/Server.go:899-909,
941-1002 at 4edb60a4. HTTP failures include service failure. Views, never rules. -/
inductive TeranodeValidator where
  | valid | invalid | OK | BadRequest | InternalServerError | ServiceUnavailable
  deriving DecidableEq, Repr

/-- [SRC] 2026-10-13: transaction /tx responses at Teranode
services/propagation/Server.go:755-790, v0.16.0 (4edb60a4).
Health statuses are about another object and are excluded. Views, never rules. -/
inductive TeranodePropagation where
  | OK | Forbidden | Conflict | UnprocessableEntity | ServiceUnavailable
  | BadRequest | InternalServerError
  deriving DecidableEq, Repr

/-- [SRC] 2026-10-13: named wire codes, internal codes and open namespaces.
REJECT_INTERNAL aliases REJECT_HIGHFEE at 256; preserve that ambiguity.
RPC codes are separate and never renamed to REJECT_INVALID. Views, never rules.
Bitcoin-sv src/consensus/validation.h:14-24, src/validation.h:1150-1163,
src/rpc/rawtransaction.cpp:1636-1650 at 6504a3af. -/
inductive NodeReject where
  | REJECT_MALFORMED | REJECT_INVALID | REJECT_OBSOLETE | REJECT_DUPLICATE
  | REJECT_SOFT_CONSENSUS_FREEZE | REJECT_NONSTANDARD | REJECT_DUST
  | REJECT_INSUFFICIENTFEE | REJECT_CHECKPOINT | REJECT_TOOBUSY | REJECT_RATE_EXCEEDED
  | REJECT_HIGHFEE_INTERNAL | REJECT_ALREADY_KNOWN | REJECT_CONFLICT | REJECT_MEMPOOL_FULL
  | otherNode (code : Nat) | rpc (code : Int)
  deriving DecidableEq, Repr

/-- [D] 2026-10-13: lossless code view. Open namespaces keep the function total;
reason strings belong to the receipt, not this enum. Never a rule. -/
def nodeWord : RejectCode → NodeReject
  | .node 1 => .REJECT_MALFORMED
  | .node 16 => .REJECT_INVALID
  | .node 17 => .REJECT_OBSOLETE
  | .node 18 => .REJECT_DUPLICATE
  | .node 19 => .REJECT_SOFT_CONSENSUS_FREEZE
  | .node 64 => .REJECT_NONSTANDARD
  | .node 65 => .REJECT_DUST
  | .node 66 => .REJECT_INSUFFICIENTFEE
  | .node 67 => .REJECT_CHECKPOINT
  | .node 68 => .REJECT_TOOBUSY
  | .node 69 => .REJECT_RATE_EXCEEDED
  | .node 256 => .REJECT_HIGHFEE_INTERNAL
  | .node 257 => .REJECT_ALREADY_KNOWN
  | .node 258 => .REJECT_CONFLICT
  | .node 259 => .REJECT_MEMPOOL_FULL
  | .node n => .otherNode n
  | .rpc n => .rpc n

/-- [D] 2026-10-13: None means the derived status is not rejected, not that an
RPC said the word None or that an older rejection never occurred. A view,
never a rule. [SRC] src/rpc/rawtransaction.cpp:1716-1724 at 6504a3af. -/
def nodeView : Status → Option (NodeReject × String)
  | .rejected code reason => some (nodeWord code, reason)
  | _ => none

/-- [D] 2026-10-13: exact reason bytes survive the rejection projection.
This theorem is about a view, never a validation rule. -/
theorem node_rejection_reason (code : RejectCode) (reason : String) :
    nodeView (.rejected code reason) = some (nodeWord code, reason) := rfl

/-- [D] 2026-10-13: signed RPC errors are not silently put in the wire-code
namespace. This theorem is about a view, never a validation rule. -/
theorem rpc_namespace_preserved (code : Int) (reason : String) :
    nodeView (.rejected (.rpc code) reason) = some (.rpc code, reason) := rfl

/-- [D] 2026-10-13: a record of missing producer inputs, never a rule. The
witness is a corpus id, not a purported measurement of the producer. -/
structure NoFunction where
  reason : String
  witness : String
  deriving DecidableEq, Repr

/-- [D] 2026-10-13: either an explicit projection or its recorded obstruction.
This is view packaging, never a rule. -/
inductive View (α : Type) where
  | function (project : Status → α)
  | noFunction (evidence : NoFunction)

/-- [D] 2026-10-13: table column ids; their order is consumed by specgen.
Every column describes a view, never a rule. -/
inductive Vocabulary where
  | arcade | provenTxReq | walletTransaction | teranodeValidator | teranodePropagation | node
  | teranodeNode
  deriving DecidableEq, Repr

/-- [D] 2026-10-13: machine row names and witness ids are executable data,
not a second prose table. Views, never rules. -/
def rows : List String :=
  ["unknown", "orphan", "inMempool", "heldNonFinal", "minedActive",
   "onStaleBranch", "conflictedByMinedSpend", "rejected"]

/-- [D] 2026-10-13: the ordered columns of the generated table. Views, never rules. -/
def columns : List (String × Vocabulary) :=
  [("Arcade", .arcade), ("ProvenTxReqStatus", .provenTxReq),
   ("TransactionStatus", .walletTransaction), ("Teranode validator", .teranodeValidator),
   ("Teranode propagation", .teranodePropagation), ("node rejection", .node),
   ("Teranode node", .teranodeNode)]

/-- [D] 2026-10-13: additional producer inputs read at the cited pins.
These explain no-function cells, never rules or inverse-map arguments. -/
def extraState : Vocabulary → String
  | .arcade => "initial receipt delivery and prior lifecycle state (models/transaction.go:90-93,167-176 at 1ae1208e)"
  | .provenTxReq => "signed noSend versus delayed queue; rejected receipt history (sdk/types.ts:22-26,30-34,48,50; storage/methods/processAction.ts:359-370 at edf6e03d)"
  | .walletTransaction => "prior failed storage record and recovery label (monitor/tasks/TaskFailAbandoned.ts:36-46; storage/methods/ListActionsSpecOp.ts:123-139 at edf6e03d)"
  | .teranodeValidator => "non-default HTTP options versus a returned processing error (services/validator/Server.go:899-909,733-740,970-1002 at 4edb60a4)"
  | .teranodePropagation => "ErrInvalidArgument versus dependency failure cause (services/propagation/Server.go:759-790 at 4edb60a4)"
  | .node => "none: completed rejection code and reason suffice"
  | .teranodeNode => "the delivery path and the legacy bridge for orphan (services/legacy/netsync/manager.go:487,1335-1352; daemon/daemon.go:577-600 at 4edb60a4); no non-final pool for heldNonFinal (services/validator/Validator.go:976-983 at 4edb60a4)"

/-- [D] 2026-10-13: each row's independent unchanged-input witness. A view,
never a rule; the node state does not move while producer contexts differ. -/
def obstruction (v : Vocabulary) (row : String) : NoFunction :=
  ⟨extraState v, "2026-10-13-status-view-" ++ row⟩

/-- [D] 2026-10-13: partial mining view defined on active inclusion, undefined
elsewhere. Stored Arcade lifecycle may lag independently. Views, never rules.
[SRC] models/transaction.go:110-113,128-245 at 1ae1208e. -/
def arcadeMining : Status → Option Arcade
  | .minedActive _ => some .MINED
  | _ => none

/-- [D] 2026-10-13: stale body inclusion supplies the mining predicate, even
when that branch is no longer active. Stored reorg delivery and anchor history
are separate: reorg_unmined carries SEEN_ON_NETWORK, reorg_reanchor carries MINED.
Views, never rules. [SRC] models/transaction.go:110-111,326-331 at 1ae1208e. -/
def arcadeStaleMining : Status → Option Arcade
  | .onStaleBranch => some .MINED
  | _ => none

/-- [D] 2026-10-13: narrow rejection predicate for the completed input-empty
node receipt. Undefined for other receipts. Stored Arcade delivery and transition
restrictions are separate. Views, never rules.
[SRC] models/transaction.go:104-105,227-237 at 1ae1208e;
src/validation.cpp:526-527, src/rpc/rawtransaction.cpp:1640-1644 at 6504a3af. -/
def arcadeRejected (s : Status) : Option Arcade :=
  if s == .rejected (.node 16) "bad-txns-vin-empty" then some .REJECTED else none

/-- [D] 2026-10-13: hypothesis h : arcadeStaleMining s = some MINED
entails the stale constructor, whose actual derived status retains off-active
body inclusion. No stored report is inferred. Views, never rules. -/
theorem partial_mined_implies_stale (s : Status)
    (h : arcadeStaleMining s = some .MINED) : s = .onStaleBranch := by
  cases s <;> simp_all [arcadeStaleMining]

/-- [D] 2026-10-13: hypothesis h : arcadeRejected s = some REJECTED
entails the exact completed node receipt in this narrow domain. No producer
receipt delivery is inferred. Views, never rules. -/
theorem partial_rejected_implies_receipt (s : Status)
    (h : arcadeRejected s = some .REJECTED) :
    s = .rejected (.node 16) "bad-txns-vin-empty" := by
  simpa [arcadeRejected] using h

/-- [D] 2026-10-13: hypothesis hInputs : tx.inputs = [] supplies the machine's
vinEmpty rejection at every size/sigop parameter choice, and its completed receipt
projects to Arcade REJECTED. Stored history is separate. Views, never rules.
[SRC] models/transaction.go:104-105 at 1ae1208e; src/validation.cpp:526-527 at 6504a3af. -/
theorem empty_inputs_rejected (tx : BsvScript.Tx.Tx) (maxSigOps maxSize : Nat)
    (preGenesis : Bool) (hInputs : tx.inputs = []) :
    arcadeRejected (.rejected (.node 16) "bad-txns-vin-empty") = some .REJECTED ∧
    BsvScript.TxRules.checkTransactionCommon tx maxSigOps maxSize preGenesis = .error .vinEmpty :=
  ⟨by simp [arcadeRejected], BsvScript.TxRules.checkTransactionCommon_vinEmpty tx maxSigOps maxSize preGenesis hInputs⟩

/-- [D] 2026-10-13: partial exact-conflict view; stored request history may lag.
Completed additionally requires proof storage and notifications at sdk/types.ts:50.
Views, never rules. [SRC] sdk/types.ts:46,50 at edf6e03d. -/
def requestConflict : Status → Option ProvenTxReq
  | .conflictedByMinedSpend => some .doubleSpend
  | _ => none

/-- [D] 2026-10-13: partial structural-invalid view for the exact input-empty
node receipt; other codes, reasons and RPC namespaces are undefined. Stored
request history may still lag. Views, never rules.
[SRC] sdk/types.ts:48 at edf6e03d; src/validation.cpp:526-527 at 6504a3af. -/
def requestInvalid (s : Status) : Option ProvenTxReq :=
  if s == .rejected (.node 16) "bad-txns-vin-empty" then some .invalid else none

/-- [D] 2026-10-13: hypothesis hInputs : tx.inputs = [] establishes the existing
machine's structural vinEmpty rejection at every size/sigop parameter choice.
The exact completed node receipt projects to invalid; an arbitrary cached report
is not used to prove hInputs. Views, never rules.
[SRC] src/validation.cpp:526-527 at 6504a3af; sdk/types.ts:48 at edf6e03d. -/
theorem empty_inputs_invalid (tx : BsvScript.Tx.Tx) (maxSigOps maxSize : Nat)
    (preGenesis : Bool) (hInputs : tx.inputs = []) :
    requestInvalid (.rejected (.node 16) "bad-txns-vin-empty") = some .invalid ∧
    BsvScript.TxRules.checkTransactionCommon tx maxSigOps maxSize preGenesis = .error .vinEmpty :=
  ⟨by simp [requestInvalid], BsvScript.TxRules.checkTransactionCommon_vinEmpty tx maxSigOps maxSize preGenesis hInputs⟩

/-- [D] 2026-10-13: executable partial-cell metadata consumed by specgen and
checked against the typed projections in replay. Views, never rules. -/
def partialCells : List (String × Vocabulary × String × String) :=
  [("minedActive", .arcade, "MINED", "models/transaction.go:110-111 at 1ae1208e"),
   ("onStaleBranch", .arcade, "MINED", "models/transaction.go:110-111 at 1ae1208e; off-active body inclusion, stored reorg events separate (:326-331)"),
   ("rejected", .arcade, "REJECTED", "models/transaction.go:104-105 at 1ae1208e; node 16 bad-txns-vin-empty only, other receipts undefined (src/validation.cpp:526-527 at 6504a3af)"),
   ("conflictedByMinedSpend", .provenTxReq, "doubleSpend", "sdk/types.ts:46 at edf6e03d"),
   ("rejected", .provenTxReq, "invalid", "sdk/types.ts:48 at edf6e03d; node 16 bad-txns-vin-empty only, other receipts undefined (src/validation.cpp:526-527 at 6504a3af)")]

/-- [D] 2026-10-13: active constructor suffices for the mining word.
Hypothesis h : arcadeMining s = some MINED concludes s = minedActive height
for some height. Stored reports are outside this view, never a rule. -/
theorem partial_mined_implies_active (s : Status) (h : arcadeMining s = some .MINED) :
    ∃ height, s = .minedActive height := by
  cases s <;> simp_all [arcadeMining]

/-- [D] 2026-10-13: hypothesis h : requestConflict (status s id) = some doubleSpend
entails the machine's exact different active spender predicate minedConflict s id.
That predicate tests a shared outpoint, not gettxout absence alone. Views, never rules.
[SRC] sdk/types.ts:46 at edf6e03d; src/txmempool.cpp:1093-1116 at 6504a3af. -/
theorem doubleSpend_implies_mined_conflict (s : StatusState) (id : BsvChain.TxId)
    (h : requestConflict (status s id) = some .doubleSpend) : minedConflict s id = true := by
  unfold status at h
  split at h
  · simp [requestConflict] at h
  · split at h
    · simp [requestConflict] at h
    · split at h
      · simp [requestConflict] at h
      · split at h
        · simp [requestConflict] at h
        · split at h
          · simp [requestConflict] at h
          · split at h
            · assumption
            · split at h <;> simp [requestConflict] at h

/-- [D] 2026-10-13: the node vocabulary is a function of rejection output.
The Option extension covers rows without a completed rejection. Never a rule. -/
def nodeRejectView : View (Option (NodeReject × String)) := .function nodeView

/-- [D] 2026-10-13: synchronized mining-only projection; this is not Arcade's
actual asynchronous lifecycle. Both active and stale bodies yield MINED.
No depth policy is built into Status. This view is never a rule.
[SRC] models/transaction.go:110-113 at 1ae1208e. -/
def synchronizedMining : Status → Arcade
  | .minedActive _ | .onStaleBranch => .MINED
  | _ => .UNKNOWN

/-- [D] 2026-10-13: hypothesis h : synchronizedMining s = MINED
concludes (exists height, s = minedActive height) or s = onStaleBranch.
Body inclusion is inherited from an actual machine-derived constructor.
Actual remote hints require synchronized evidence;
a cached MINED word has no such theorem. This view is never a rule. -/
theorem mined_implies_branch (s : Status) (h : synchronizedMining s = .MINED) :
    (∃ height, s = .minedActive height) ∨ s = .onStaleBranch := by
  cases s <;> simp_all [synchronizedMining]

/-- [D] 2026-10-13: client-selected depth threshold and observed tip height.
This is an illustrative depth policy, not an assertion of Arcade's threshold:
models/transaction.go:112-113 at 1ae1208e supplies no threshold. Never a rule. -/
def depthView (s : Status) (tipHeight requiredDepth : Nat) : Arcade :=
  match s with
  | .minedActive height =>
    if height ≤ tipHeight && requiredDepth ≤ tipHeight + 1 - height then .IMMUTABLE else .MINED
  | _ => synchronizedMining s

/-- [D] 2026-10-13: the same machine status and tip admit different client
depth decisions. No Status-only function equals every client's depth view.
This impossibility theorem concerns views, never a machine rule. -/
theorem immutable_needs_client_depth :
    ¬ ∃ f : Status → Arcade, ∀ s tip depth, f s = depthView s tip depth := by
  rintro ⟨f, h⟩
  have a := h (.minedActive 7) 7 1
  have b := h (.minedActive 7) 7 2
  simp [depthView] at a b
  exact Arcade.noConfusion (a.symm.trans b)

/-- [D] 2026-10-13: explicit remote report only, independent of machine
position. The source says seen on the network / by multiple independent
miners; it says no active-chain fact. Never a rule.
[SRC] models/transaction.go:98-101 at 1ae1208e. -/
def seenView (_s : Status) (multiple : Bool) : Arcade :=
  if multiple then .SEEN_MULTIPLE_NODES else .SEEN_ON_NETWORK

/-- [D] 2026-10-13: for any two machine statuses the same remote SEEN report
has the same word; it cannot distinguish unknown from active inclusion.
This theorem is about source-limited views, never a rule. -/
theorem seen_says_nothing_about_active (s t : Status) (multiple : Bool) :
    seenView s multiple = seenView t multiple := rfl

/-- [D] 2026-10-13: independent producer inputs for local obstruction models.
No terminal Arcade regression is permitted. Structurally invalid transactions
cannot use the signed noSend path. A failed wallet row is retained history,
possibly preceding this node observation; recovery changes storage only.
[SRC] Arcade models/transaction.go:90-93,167-176 at 1ae1208e;
sdk/types.ts:22-34,48,50; storage/methods/processAction.ts:359-370;
monitor/tasks/TaskFailAbandoned.ts:36-46 and
storage/methods/ListActionsSpecOp.ts:123-139 at edf6e03d. Views, never rules. -/
structure ProducerContext where
  receiptDelivered : Bool
  arcadePrior : Arcade := .UNKNOWN
  laterArcadeEvent : Bool := false
  signedComplete : Bool
  structurallyValid : Bool
  noSend : Bool
  delayed : Bool
  sendWith : Bool := false
  believedSent : Bool
  rejectionDelivered : Bool
  walletBeforeFailure : WalletTransaction := .unprocessed
  walletUpdatedAt : Nat := 1
  walletNow : Nat := 100
  walletAbandonedMsecs : Nat := 10
  walletFailureApplied : Bool := true
  failedFilterSelected : Bool := true
  recoveryLabel : Bool
  validatorSkipPolicyChecks : Bool
  validatorResponseValid : Bool := false
  validatorReason : String := "local producer validation failed"
  validatorErrorCause : String := ""
  validatorParentKnown : Bool := false
  propagationCause : String
  deriving Repr

/-- [D] 2026-10-13: derive words only when their source predicates hold.
HTTP inputs are protobuf requests with unlisted options at defaults. The options
rejection precedes processing; an explicit valid response is required for OK,
and is incompatible with structurally invalid bytes. Non-threshold processing
errors yield InternalServerError; an invalid response alone is not a realized
producer step. Propagation dispatch uses
an explicit unwrapped error cause, never selected-node admission.
[SRC] validator Server.go:970-974,992-1002; services/validator/http_options_guard.go:57-59; propagation Server.go:759-790
at 4edb60a4. Other unsupported or incompatible contexts are rejected. -/
def contextWords (s : Status) (c : ProducerContext) : Option (List (String × String)) := do
  if c.arcadePrior != .UNKNOWN || c.laterArcadeEvent then none else pure ()
  let arcade := if c.receiptDelivered then "RECEIVED" else "UNKNOWN"
  let request ← if s == .rejected (.node 16) "bad-txns-vin-empty" then
      if c.structurallyValid || c.signedComplete || c.noSend || c.delayed || c.sendWith || !c.believedSent then none
      else some (if c.rejectionDelivered then "invalid" else "unknown")
    else if !c.structurallyValid || !c.signedComplete || c.sendWith || c.believedSent || c.rejectionDelivered then none
    else if c.noSend && !c.delayed then some "nosend"
    else if !c.noSend && c.delayed then some "unsent"
    else none
  if (c.walletBeforeFailure != .unprocessed && c.walletBeforeFailure != .unsigned) ||
      !(c.walletUpdatedAt < c.walletNow - c.walletAbandonedMsecs) ||
      !c.walletFailureApplied || !c.failedFilterSelected then none else pure ()
  let wallet := if c.recoveryLabel then "unfail" else "failed"
  let validator ← if c.validatorSkipPolicyChecks then some "BadRequest"
    else if c.validatorErrorCause == "" && c.validatorResponseValid && c.structurallyValid then some "OK"
    else if !c.validatorResponseValid && !c.validatorReason.isEmpty &&
        ((c.validatorErrorCause == "ErrTxMissingParent" && !c.validatorParentKnown && c.structurallyValid) ||
         (c.validatorErrorCause == "ErrTxInvalid" && !c.structurallyValid)) then some "InternalServerError"
    else none
  let propagation ← if c.propagationCause == "ErrInvalidArgument" then some "BadRequest"
    else if c.propagationCause == "ErrServiceError" then some "InternalServerError"
    else none
  return [("Arcade",arcade),("ProvenTxReqStatus",request),("TransactionStatus",wallet),
    ("Teranode validator",validator),("Teranode propagation",propagation)]

/-- [D] 2026-10-13: witness contexts explicitly instantiate those predicates.
The rejected fixture uses notification history, never signed noSend or service OK.
The validator options input is a non-default protobuf option; the response input
is an error returned by independent producer validation: missing parent or
structural invalidity. Server.go:733-740 returns Valid=false WITH an error;
Server.go:992-995 takes that error through httpStatusForTxError:899-909.
[SRC] Validator.go:1657-1663,2723-2728 and ScriptVerifierGoBDK.go:401-433
at 4edb60a4 supply those processing causes. Propagation
ErrServiceError takes the source dispatch default arm. Views, never rules. -/
def witnessContext (s : Status) (alternate : Bool) : ProducerContext :=
  let invalid := s == .rejected (.node 16) "bad-txns-vin-empty"
  { receiptDelivered := alternate, signedComplete := !invalid, structurallyValid := !invalid,
    noSend := !invalid && alternate, delayed := !invalid && !alternate,
    believedSent := invalid, rejectionDelivered := invalid && alternate,
    recoveryLabel := alternate, validatorSkipPolicyChecks := !alternate,
    validatorErrorCause := if !alternate then "" else if invalid then "ErrTxInvalid" else "ErrTxMissingParent",
    propagationCause := if alternate then "ErrServiceError" else "ErrInvalidArgument" }

/-- [D] 2026-10-13: predicate-checked contexts have different words at the
same status. Unsupported contexts return none. These are local models of cited
producer steps, never measurements or machine rules. -/
theorem context_words_differ (s : Status) :
    contextWords s (witnessContext s false) ≠ contextWords s (witnessContext s true) := by
  cases h : (s == .rejected (.node 16) "bad-txns-vin-empty") <;>
    simp [witnessContext, contextWords, h]

/-- [SRC] 2026-10-15 (#74): Teranode's own transaction states at v0.16.0 (4edb60a4), the
UTXO store and block assembly, as docs/CONFORMANCE-TERANODE-MACHINE.md sections 1 and 6 map them.
noRecord: no store record and no assembly entry. unmined: unminedSince set
(stores/utxo/fields/fields.go:79), held by block assembly. minedOnCurrent h: blockIDs and
blockHeights (fields.go:64-66) name a block of height h on the current chain (getblock's
confirmations, services/rpc/handlers.go:127-142). minedOffCurrent: only blocks off the current
chain; an invalidation removes the block's entry (stores/utxo/aerospike/teranode.lua:584-606),
so that half is the runner's journal of blocks, read by source and unwitnessed.
spentByMinedOther: an input's output SPENT with spendingData naming another transaction mined
on the current chain (services/asset/httpimpl/GetUTXOsByTXID.go:40-46); a block-carried loser
is also marked conflicting (fields.go:40). refused: no stored state after a submission on
either path (the RPC's -25 and Teranode's own error words, services/rpc/handlers.go:924-931; the
legacy bridge drops it unless it is an orphan, services/legacy/netsync/manager.go:1335).
Views, never rules. -/
inductive TeranodeState where
  | noRecord | unmined | minedOnCurrent (height : Nat) | minedOffCurrent
  | spentByMinedOther | refused
  deriving DecidableEq, Repr

/-- [D] 2026-10-15 (#74): the generated table's word for each state; the height
of minedOnCurrent is the row's h. A view, never a rule. -/
def teranodeWord : TeranodeState → String
  | .noRecord => "noRecord"
  | .unmined => "unmined"
  | .minedOnCurrent _ => "minedOnCurrent h"
  | .minedOffCurrent => "minedOffCurrent"
  | .spentByMinedOther => "spentByMinedOther"
  | .refused => "refused"

/-- [D] 2026-10-15 (#74): the Teranode node column, a partial function of the
derived status alone, from the map's section 6 rows. Undefined on orphan, the
one recorded no-function cell of teranodeNoFunction; heldNonFinal is refused, the
state the column gives rejected (no non-final pool). A refusal
keeps the class only: Teranode's code and words are its own namespace, never the
reference's code and reason. The second oracle's defaults are never the rule.
Views, never rules. -/
def teranodeState : Status → Option TeranodeState
  | .unknown => some .noRecord
  | .inMempool => some .unmined
  | .minedActive height => some (.minedOnCurrent height)
  | .onStaleBranch => some .minedOffCurrent
  | .conflictedByMinedSpend => some .spentByMinedOther
  | .rejected _ _ => some .refused
  | .heldNonFinal => some .refused
  | .orphan => none

/-- [D] 2026-10-15 (#74): the map's reading back onto Status (section 5's derive,
harness/engines/teranode/client.rs and harness/src/scenarios/teranode.rs). A
refusal reads as rejected in Teranode's namespace, outside RejectCode's two, so
it has no Status here. A view, never a rule. -/
def teranodeRead : TeranodeState → Option Status
  | .noRecord => some .unknown
  | .unmined => some .inMempool
  | .minedOnCurrent height => some (.minedActive height)
  | .minedOffCurrent => some .onStaleBranch
  | .spentByMinedOther => some .conflictedByMinedSpend
  | .refused => none

/-- [D] 2026-10-15 (#74): the record of the measured status witnesses.
Its steps name each cell's witness. A view, never a rule. -/
def teranodeWitnessRecord : String := "docs/records/20261014-215508-s6-74-second-oracle-s4b.md"

/-- [D] 2026-10-15 (#74): executable function-cell metadata (row, word, source,
the record's witness step), consumed by specgen and checked against teranodeState
in replay. The onStaleBranch cell is by source: its step left the value unrealized.
Views, never rules. -/
def teranodeCells : List (String × String × String × String) :=
  [("unknown", "noRecord", "map section 1 row no record; the asset txmeta route (services/asset/httpimpl/http.go:340) and getrawmempool (services/rpc/handlers.go:1353) at 4edb60a4", "step unknown (4eb99653aae55cd8...): observed unknown [M], agree"),
   ("inMempool", "unmined", "unminedSince set (stores/utxo/fields/fields.go:79), listed by block assembly through getrawmempool (services/rpc/handlers.go:1353) at 4edb60a4", "step inMempool (1601152dd94823ac...): observed inMempool [M], agree"),
   ("minedActive", "minedOnCurrent h", "blockIDs and blockHeights (stores/utxo/fields/fields.go:64-66), the block current by getblock confirmations (services/rpc/handlers.go:127-142) at 4edb60a4", "step minedActive (1601152dd94823ac...): observed minedActive 103 [M], agree"),
   ("onStaleBranch", "minedOffCurrent", "blocks only off the current chain (getblock confirmations -1, services/rpc/handlers.go:127-142); after an invalidation the store drops the entry (stores/utxo/aerospike/teranode.lua:584-606) and the runner's journal keeps it, at 4edb60a4", "by source, unwitnessed: step onStaleBranch (after invalidation) (dfd683cd95242bbd...) observed inMempool [M], the transaction re-admitted, the value unrealized"),
   ("conflictedByMinedSpend", "spentByMinedOther", "an input's output SPENT with spendingData (services/asset/httpimpl/GetUTXOsByTXID.go:40-46) naming another transaction mined on the current chain; the spend refused with UTXO_SPENT (stores/utxo/aerospike/spend.go:1095) at 4edb60a4", "step conflictedByMinedSpend (188a438b06a3ccb0...): observed conflictedByMinedSpend [M], agree"),
   ("rejected", "refused", "no stored state; -25 with Teranode's words (services/rpc/handlers.go:924-931), malformed bytes -22 (:854-856) at 4edb60a4; the reference's code and reason are not carried", "step rejected (92f06005f51981ae...): observed rejected -25 TX_INVALID [M], agree"),
   ("heldNonFinal", "refused", "no non-final pool: a non-final transaction is refused with UTXO_NON_FINAL 71 wrapping TX_LOCK_TIME 35 (services/validator/Validator.go:976-983; util/lock_time.go) at 4edb60a4; the hold is policy (DESIGN-S6 2.1 row 3), never the rule", "step heldNonFinal (53c6bc6316407bd3...): observed rejected -25 TX_LOCK_TIME [M], non-judging")]

/-- [D] 2026-10-15 (#74): the one recorded no-function cell, with the record's
witness step. orphan needs the delivery path and the bridge beside the status.
Views, never rules. -/
def teranodeNoFunction : List (String × NoFunction) :=
  [("orphan", ⟨"the retained orphan lives only in the legacy bridge's expiring map (services/legacy/netsync/manager.go:487,1335-1352), which no RPC or asset route reads and the recipe runs off (-legacy=0, daemon/daemon.go:577-600); on RPC nothing is kept, the absurd-fee parent read refusing ahead of validation (services/rpc/handlers.go:880-904) at 4edb60a4", "step orphan (RPC path) (146984bf39c452d0...): observed rejected -25 None [M] (the RPC's PROCESSING (4) refusal before validation, record's status witnesses); the value orphan unrealized"⟩)]

/-- [D] 2026-10-15 (#74): the Teranode node column is undefined exactly on the
one recorded no-function row, orphan, and defined on the other seven. This
theorem is about a view, never a rule. -/
theorem teranode_undefined_iff (s : Status) :
    teranodeState s = none ↔ s = .orphan := by
  cases s <;> simp [teranodeState]

/-- [D] 2026-10-15 (#74): hypotheses h : teranodeState s = some x and
hx : x ≠ refused give back s through the map's reading: off a refusal the column
loses nothing of the derived status. This theorem is about a view, never a rule. -/
theorem teranode_read_inverse (s : Status) (x : TeranodeState)
    (h : teranodeState s = some x) (hx : x ≠ .refused) : teranodeRead x = some s := by
  cases s <;> simp [teranodeState] at h <;> subst h <;> simp_all [teranodeRead]

/-- [D] 2026-10-15 (#74): any two rejections have the same Teranode state, whatever
their codes and reasons: the refusal's words are Teranode's namespace, recorded
beside the reference's and never compared. This theorem is about a view, never a rule. -/
theorem teranode_refusal_forgets_reason (c c' : RejectCode) (r r' : String) :
    teranodeState (.rejected c r) = teranodeState (.rejected c' r') := rfl

/-- [D] 2026-10-15 (#74): hypothesis hs : teranodeState s = some (minedOnCurrent h)
concludes s = minedActive h: the current-chain state carries the derived height.
This theorem is about a view, never a rule. -/
theorem teranode_mined_implies_active (s : Status) (h : Nat)
    (hs : teranodeState s = some (.minedOnCurrent h)) : s = .minedActive h := by
  cases s <;> simp_all [teranodeState]

end BsvChain.Views
