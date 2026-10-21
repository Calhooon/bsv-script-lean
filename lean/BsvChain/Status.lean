import BsvChain.Chain

/-!
# Derived transaction status, 2026-10-13 [D] (#58, #67)

These are views, never rules. DESIGN-S6 sections 1.4 and 3 specify the
observation journals and ordered clauses. The machine's ChainState and
TxJournal are retained intact in the observation envelope.
[SRC] bitcoin-sv v1.2.3 at 6504a3aff65ba97c0f6c80962b033e35ecbfed4b:
src/rpc/blockchain.cpp:79-90,440-550,2675-2693;
src/rpc/rawtransaction.cpp:1636-1650,1716-1724.
-/

namespace BsvChain
open BsvScript.Tx

/-- [D] 2026-10-13: the eight ordered outcomes of DESIGN-S6 section 3.
This is an observation view, never an admission rule. -/
inductive Status where
  | unknown | orphan | inMempool | heldNonFinal
  | minedActive (height : Nat) | onStaleBranch | conflictedByMinedSpend
  | rejected (code : RejectCode) (reason : String)
  deriving DecidableEq, Repr

/-- [D] 2026-10-13: machine plus the explicitly retained observation journal.
A node does not persist these rejection receipts. This envelope is a view,
never a rule. [SRC] src/validation.cpp:1934-1950 at 6504a3af. -/
structure StatusState where
  chain : ChainState
  journal : TxJournal := {}

/-- [D] 2026-10-13: test the actual body id, ignoring absent bodies.
A header alone does not supply inclusion. This view is never a rule.
[SRC] src/rpc/blockchain.cpp:79-90 at 6504a3af. -/
def bodyContains (index : BlockIndex) (id : TxId) : Bool :=
  index.body.any (fun block => block.transactions.any (fun tx => BsvScript.Sighash.txid tx == id))

/-- [D] 2026-10-13: greatest active array index containing the transaction,
as DESIGN-S6 section 3 specifies even on inconsistent records. A view,
never a rule. [SRC] src/rpc/blockchain.cpp:79-90 at 6504a3af. -/
def activeHeight (s : ChainState) (id : TxId) : Option Nat :=
  (s.active.zipIdx).foldl (fun found (hash, height) =>
    if (s.tree.get hash).any (fun index => bodyContains index id) then some height else found) none

/-- [D] 2026-10-13: an exact different active spender of an unavailable
journaled input, never inferred from gettxout null alone. A view, never a rule.
[SRC] src/txmempool.cpp:1091-1117 at 6504a3af. -/
def minedConflict (s : StatusState) (id : TxId) : Bool :=
  (s.journal.seen.lookup id).any fun tx => tx.inputs.any fun input =>
    let point := OutPoint.ofInput input
    (getCoin s.chain.view.coins point).isNone && s.chain.active.any fun hash =>
      (s.chain.tree.get hash).any fun index => index.body.any fun block =>
        block.transactions.any fun spender => BsvScript.Sighash.txid spender != id &&
          spender.inputs.any (fun other => OutPoint.ofInput other == point)

/-- [D] 2026-10-13: DESIGN-S6 section 3's clauses, in their stated order.
Active inclusion wins; pool precedes stale body; stale body precedes conflict;
conflict precedes the completed rejection journal. Seen alone is unknown.
This derived view is never a rule. [SRC] src/rpc/blockchain.cpp:79-90,440-550
and src/rpc/rawtransaction.cpp:1636-1650 at 6504a3af. -/
def status (s : StatusState) (id : TxId) : Status :=
  match activeHeight s.chain id with
  | some height => .minedActive height
  | none =>
    if s.chain.mempool.accepted.any (fun entry => entry.id == id) then .inMempool
    else if s.chain.mempool.nonFinal.any (fun entry => entry.entry.id == id) then .heldNonFinal
    else if s.chain.mempool.orphans.any (fun entry => BsvScript.Sighash.txid entry.request.tx == id) then .orphan
    else if s.chain.tree.nodes.any (fun index => !s.chain.active.contains index.id && bodyContains index id) then .onStaleBranch
    else if minedConflict s id then .conflictedByMinedSpend
    else match s.journal.rejected.lookup id with
      | some rejection => .rejected rejection.code rejection.reason
      | none => .unknown

/-- [D] 2026-10-13: repeat evaluation of the same explicit state is identical.
This is determinism of a view, never a rule or a persistence guarantee. -/
theorem status_deterministic (s : StatusState) (id : TxId) : status s id = status s id := rfl

/-- [D] 2026-10-13: hypothesis h : activeHeight s.chain id = some height
selects minedActive height over every pool or rejection journal fact. This ordered-clause theorem concerns views, never rules. -/
theorem active_inclusion_wins (s : StatusState) (id : TxId) (height : Nat)
    (h : activeHeight s.chain id = some height) : status s id = .minedActive height := by
  simp [status, h]

end BsvChain
