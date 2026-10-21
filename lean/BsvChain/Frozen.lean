import BsvChain.Utxo

/-!
# Frozen outputs and the confiscation whitelist as operator data (#70)

The operator's records, as the reference's frozen-output database stores them,
and the effective projection `FrozenLists` derived from them exactly as
`CFrozenTXOCheck::Check` and `CheckConfiscationTxWhitelisted` decide. Every
record here is operator data: a node setting supplied through the freeze RPCs,
an explicit input of each scenario, never a constant of the chain. The
reference names one list "consensus" (`Blacklist::Consensus`); that is the
reference's label for an operator list whose entries the node also applies at
block connection, not a consensus rule of the chain. The spec's kind for every
record and every derived check is the operator-list mechanism, a policy
parameter (DESIGN-S6 §1.5, PARAMETERS §8.2).

Heights in the records are the reference's signed 32-bit values, held as `Int`.
The source is bitcoin-sv v1.2.3 at 6504a3aff65ba97c0f6c80962b033e35ecbfed4b.
-/

namespace BsvChain
open BsvScript.Tx BsvScript.Numbers

/-- The list a record is stored on: `Consensus` = 1, `PolicyOnly` = 2,
`Confiscation` = 3. Operator data; the name Consensus is the reference's label.
[SRC] src/frozentxo_db.h:192–219 at 6504a3af. -/
inductive Blacklist where
  | consensus | policyOnly | confiscation
  deriving DecidableEq, Repr

/-- The stored byte of each list. [SRC] src/frozentxo_db.h:202,211,218 at 6504a3af. -/
def Blacklist.code : Blacklist → Nat
  | .consensus => 1
  | .policyOnly => 2
  | .confiscation => 3

/-- A half-open interval [start, stop) of block heights; an absent stop is
INT32_MAX. An interval with start ≥ stop holds no height and is ignored.
[SRC] src/frozentxo_db.h:226–241 and src/rpc/frozentxo_rpc.cpp:29–55 at 6504a3af. -/
structure HeightInterval where
  start : Int
  stop : Int := 2147483647
  deriving DecidableEq, Repr

/-- [SRC] src/frozentxo_db.h:238–241 at 6504a3af. -/
def HeightInterval.valid (i : HeightInterval) : Bool := decide (i.start < i.stop)

/-- One frozen output's record: its list, the height intervals of the list the
reference calls "consensus", and whether the policy freeze expires with them.
For a `PolicyOnly` record the other two fields are not read.
[SRC] src/frozentxo_db.h:179–308 at 6504a3af. -/
structure FrozenTxoData where
  blacklist : Blacklist
  enforceAtHeight : List HeightInterval := []
  policyExpiresWithConsensus : Bool := false
  deriving DecidableEq, Repr

/-- `IsFrozenOnPolicy`: frozen on the policy list at height `h`. Both other
lists imply it except a ranged record whose policy freeze expires with its
intervals, which is frozen below the stop of a valid interval.
[SRC] src/frozentxo_db.h:323–348 at 6504a3af. -/
def FrozenTxoData.frozenOnPolicy (d : FrozenTxoData) (h : Int) : Bool :=
  d.blacklist == Blacklist.policyOnly || d.blacklist == Blacklist.confiscation || !d.policyExpiresWithConsensus ||
    d.enforceAtHeight.any (fun i => i.valid && decide (h < i.stop))

/-- `IsFrozenOnConsensus`: a confiscated record at every height; a ranged record
inside one of its intervals; a policy-only record never.
[SRC] src/frozentxo_db.h:353–377 at 6504a3af. -/
def FrozenTxoData.frozenOnConsensus (d : FrozenTxoData) (h : Int) : Bool :=
  match d.blacklist with
  | .confiscation => true
  | .policyOnly => false
  | .consensus => d.enforceAtHeight.any (fun i => decide (i.start ≤ h) && decide (h < i.stop))

/-- A whitelisted confiscation transaction: the lowest height at which it can
be spent, and the outputs it confiscates.
[SRC] src/frozentxo_db.h:589–616 at 6504a3af. -/
structure WhitelistedTx where
  enforceAtHeight : Int
  confiscatedTxos : List OutPoint := []
  deriving DecidableEq, Repr

/-- The operator's records: one entry per frozen output and per whitelisted
transaction id (internal byte order), keyed as the reference's database keys
them. Both lists empty is the reference's fresh database.
[SRC] src/frozentxo_db.h:25–75,535–559,665–689 at 6504a3af. -/
structure OperatorLists where
  frozen : List (OutPoint × FrozenTxoData) := []
  whitelist : List (Bytes × WhitelistedTx) := []
  deriving Repr

/-- `GetFrozenTXOData`: the output's record, if any.
[SRC] src/frozentxo_db.cpp:520–533 at 6504a3af. -/
def OperatorLists.frozenData (d : OperatorLists) (p : OutPoint) : Option FrozenTxoData :=
  (d.frozen.find? (fun e => e.1 == p)).map (·.2)

/-- `IsTxWhitelisted`: the transaction's whitelist record, if any.
[SRC] src/frozentxo_db.cpp:802–815 at 6504a3af. -/
def OperatorLists.whitelisted? (d : OperatorLists) (txid : Bytes) : Option WhitelistedTx :=
  (d.whitelist.find? (fun e => e.1 == txid)).map (·.2)

/-- `CFrozenTXOCheck::Check(outpoint, effectiveBlacklist)`. `none` is a pass;
`some b` is a frozen output with its effective list `b`. On the block path
(`onBlock`) a block in an explicit soft consensus freeze checks nothing, and
otherwise only the ranged and confiscated records apply at the block's height;
on the admission path the policy predicate applies at the tip's successor, the
effective list `Consensus` when the ranged predicate also holds there.
[SRC] src/frozentxo.cpp:37–83 at 6504a3af. -/
def OperatorLists.check (d : OperatorLists) (onBlock explicitFreeze : Bool) (h : Int)
    (p : OutPoint) : Option Blacklist :=
  if onBlock && explicitFreeze then none else
  match d.frozenData p with
  | none => none
  | some ftd =>
    if onBlock then (if ftd.frozenOnConsensus h then some .consensus else none)
    else if !ftd.frozenOnPolicy h then none
    else some (if ftd.frozenOnConsensus h then .consensus else .policyOnly)

/-- `CheckConfiscationTxWhitelisted`: listed with its enforce height at most
`h`; on the block path also when the depth waiver disabled the enforcement
(`DisableEnforcingConfiscationTransactionChecks`).
[SRC] src/frozentxo.cpp:133–171 and src/frozentxo.h:102–122 at 6504a3af. -/
def OperatorLists.checkWhitelisted (d : OperatorLists) (onBlock waive : Bool) (h : Int)
    (txid : Bytes) : Bool :=
  (d.whitelisted? txid).any (fun w => decide (w.enforceAtHeight ≤ h)) || (onBlock && waive)

/-- The effective projection read by `checkTxInputs`, before the connecting
block's own adjustments (`FrozenLists.atBlock`): the two checks with no
explicit freeze and no waiver. [SRC] src/frozentxo.cpp:37–83,133–171 at 6504a3af. -/
def OperatorLists.project (d : OperatorLists) : FrozenLists :=
  ⟨fun onBlock h p => (d.check onBlock false (h : Int) p).isSome,
   fun onBlock h txid => d.checkWhitelisted onBlock false (h : Int) txid⟩

/-- The connecting block's adjustments to an effective projection: its explicit
soft consensus freeze makes the block-path frozen check a no-op, and the depth
waiver admits every confiscation transaction on the block path. The admission
path is unchanged. [SRC] src/frozentxo.cpp:39–42,158–165 and
src/validation.cpp:3529–3555 at 6504a3af. -/
def FrozenLists.atBlock (explicitFreeze waive : Bool) (lists : FrozenLists) : FrozenLists :=
  ⟨fun onBlock h p => !(onBlock && explicitFreeze) && lists.frozen onBlock h p,
   fun onBlock h txid => lists.whitelisted onBlock h txid || (onBlock && waive)⟩

/-! ## The operator calls (the freeze RPCs' database effects) -/

/-- Replace the output's record, or add it. [SRC] src/frozentxo_db.cpp:313,345,353,368 at 6504a3af. -/
def OperatorLists.setFrozen (d : OperatorLists) (p : OutPoint) (data : FrozenTxoData) : OperatorLists :=
  if d.frozen.any (fun e => e.1 == p) then
    { d with frozen := d.frozen.map (fun e => if e.1 == p then (p, data) else e) }
  else { d with frozen := d.frozen ++ [(p, data)] }

/-- `FreezeTXOResult`. [SRC] src/frozentxo_db.h:392–399 at 6504a3af. -/
inductive FreezeResult where
  | ok | okAlreadyFrozen | okUpdatedToConsensus | okUpdated | errorAlreadyInConsensus
  deriving DecidableEq, Repr

/-- `FreezeTXOPolicyOnly` (`addToPolicyBlacklist`). A record on another list is
left unchanged. [SRC] src/frozentxo_db.cpp:299–326 and src/rpc/frozentxo_rpc.cpp:320–344 at 6504a3af. -/
def OperatorLists.freezePolicyOnly (d : OperatorLists) (p : OutPoint) : FreezeResult × OperatorLists :=
  match d.frozenData p with
  | none => (.ok, d.setFrozen p ⟨.policyOnly, [], false⟩)
  | some data => if data.blacklist == Blacklist.policyOnly then (.okAlreadyFrozen, d) else (.errorAlreadyInConsensus, d)

/-- `FreezeTXOConsensus` (`addToConsensusBlacklist`). A policy-only record moves
to the ranged list; a ranged or confiscated record keeps its list and takes the
new intervals and expiry. [SRC] src/frozentxo_db.cpp:328–371 and
src/rpc/frozentxo_rpc.cpp:346–378 at 6504a3af. -/
def OperatorLists.freezeConsensus (d : OperatorLists) (p : OutPoint) (ranges : List HeightInterval)
    (expires : Bool) : FreezeResult × OperatorLists :=
  match d.frozenData p with
  | none => (.ok, d.setFrozen p ⟨.consensus, ranges, expires⟩)
  | some data =>
    if data.blacklist == Blacklist.policyOnly then (.okUpdatedToConsensus, d.setFrozen p ⟨.consensus, ranges, expires⟩)
    else if data.enforceAtHeight == ranges && data.policyExpiresWithConsensus == expires then (.okAlreadyFrozen, d)
    else (.okUpdated, d.setFrozen p { data with enforceAtHeight := ranges, policyExpiresWithConsensus := expires })

/-- `UnfreezeTXOResult`. [SRC] src/frozentxo_db.h:448–453 at 6504a3af. -/
inductive UnfreezeResult where
  | ok | errorInConsensus | errorNotFrozen
  deriving DecidableEq, Repr

/-- `UnfreezeTXOPolicyOnly` (`removeFromPolicyBlacklist`): only a policy-only
record is removed. [SRC] src/frozentxo_db.cpp:373–396 and src/rpc/frozentxo_rpc.cpp:380–402 at 6504a3af. -/
def OperatorLists.unfreezePolicyOnly (d : OperatorLists) (p : OutPoint) : UnfreezeResult × OperatorLists :=
  match d.frozenData p with
  | none => (.errorNotFrozen, d)
  | some data =>
    if data.blacklist == Blacklist.policyOnly then (.ok, { d with frozen := d.frozen.filter (fun e => e.1 != p) })
    else (.errorInConsensus, d)

/-- `WhitelistTxResult`. [SRC] src/frozentxo_db.h:618–625 at 6504a3af. -/
inductive WhitelistResult where
  | ok | okAlreadyWhitelistedAtLowerHeight | okUpdated | errorTxoNotConsensusFrozen | errorNotValid
  deriving DecidableEq, Repr

/-- `WhitelistTx` (`addToConfiscationTxidWhitelist`): a valid confiscation
transaction whose inputs are all frozen on the ranged or confiscated list at the
enforce height is listed, and its inputs move to the confiscation list; a listed
one only lowers its enforce height.
[SRC] src/frozentxo_db.cpp:720–800 and src/rpc/frozentxo_rpc.cpp:632–764 at 6504a3af. -/
def OperatorLists.whitelistTx (d : OperatorLists) (enforce : Int) (tx : Tx) : WhitelistResult × OperatorLists :=
  if !isConfiscationTx tx || !validConfiscationContents tx then (.errorNotValid, d) else
  let txid := BsvScript.Sighash.txid tx
  match d.whitelisted? txid with
  | none =>
    let inputs := tx.inputs.map OutPoint.ofInput
    if !inputs.all (fun p => (d.frozenData p).any (·.frozenOnConsensus enforce)) then
      (.errorTxoNotConsensusFrozen, d)
    else
      let moved := inputs.foldl (fun d p => match d.frozenData p with
        | some data => d.setFrozen p { data with blacklist := .confiscation }
        | none => d) d
      (.ok, { moved with whitelist := moved.whitelist ++ [(txid, ⟨enforce, inputs⟩)] })
  | some w =>
    if w.enforceAtHeight == enforce then (.ok, d)
    else if w.enforceAtHeight < enforce then (.okAlreadyWhitelistedAtLowerHeight, d)
    else (.okUpdated, { d with whitelist := d.whitelist.map (fun e =>
      if e.1 == txid then (txid, { e.2 with enforceAtHeight := enforce }) else e) })

/-- `ClearWhitelist` (`clearConfiscationWhitelist`): every confiscated output
returns to the ranged list with its intervals, and the whitelist empties.
[SRC] src/frozentxo_db.cpp:838–888 and src/rpc/frozentxo_rpc.cpp:766–797 at 6504a3af. -/
def OperatorLists.clearWhitelist (d : OperatorLists) : OperatorLists :=
  let back := d.whitelist.foldl (fun d (_, w) => w.confiscatedTxos.foldl (fun d p =>
    match d.frozenData p with
    | some data => if data.blacklist == Blacklist.confiscation then d.setFrozen p { data with blacklist := .consensus } else d
    | none => d) d) d
  { back with whitelist := [] }

end BsvChain
