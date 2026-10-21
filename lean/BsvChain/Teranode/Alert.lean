import BsvChain.Frozen
import BsvChain.Chain

/-!
# BsvChain.Teranode.Alert: the alert service against the reference's frozen-TXO path (#94)

[M] 2026-10-15 (#94). Teranode takes the operator's frozen-output, confiscation, block and
peer actions from an in-process alert service whose authority is a signed alert message; the reference takes
the same actions from its RPC server, whose authority is the RPC credential. This module writes the alert
service's actions as transitions on Teranode's UTXO store, ban lists and chain, beside the transitions #70
wrote for the reference (`BsvChain.OperatorLists`, `lean/BsvChain/Frozen.lean`), and proves where the two
agree and where they do not.

The Teranode side is v0.16.0 at `4edb60a40c6628ff0ef60231c2628efd7103fde5` (`docs/PROVENANCE.md` §1a): the
node interface `services/alert/node.go` (`InvalidateBlock` :160, `BanPeer` :189, `UnbanPeer` :229,
`AddToConsensusBlacklist` :274, `AddToConfiscationTransactionWhitelist` :397, the key read at :459 by
`extractPublicKey` :538), the store calls `stores/utxo/aerospike/alert_system.go` (`FreezeUTXOs` :88,
`UnFreezeUTXOs` :165, `ReAssignUTXO` :233) and the Lua functions they call
(`stores/utxo/aerospike/teranode.lua`: `freeze` :713, `unfreeze` :795, `reassign` :870, the output read
`getUTXOAndSpendingData` :194, the spend's gates :346-411) [SRC]. The store modelled is the Aerospike backend; the instance of
record runs the SQL backend (`settings.conf:1592`), whose alert calls reach the same marks without reading the
UTXO hash (`stores/utxo/sql/alert_system.go:54-193`) and whose reassignment delay is the node setting
`utxostore_reassignedUtxoSpendableAfterBlocks` (default 1000, `settings/settings.go:528`) [SRC] 4edb60a4. The alert messages that reach the node
interface are read in `github.com/bsv-blockchain/go-alert-system` v0.1.17, the version Teranode's `go.mod:197`
requires (module sum `h1:qWh/nnN3DiP2OahWbb0hdLBNKkKHXDToSDDnxEzjJ08=`, Teranode's `go.sum`) [SRC]. The
reference side is bitcoin-sv v1.2.3 at `6504a3aff65ba97c0f6c80962b033e35ecbfed4b`: the RPC table
`src/rpc/frozentxo_rpc.cpp:897-915`, `addToConsensusBlacklist` :346-378 through `ImportFundsToDB` :188-206,
and #70's transitions [SRC].

**Kinds (rule 1).** Every list here is operator data, the operator-list mechanism of #70, never a consensus
constant; the authority that may change it (§6) is a node setting, policy. Neither node's alert or RPC path
is a rule of validity: two nodes with the same lists decide the same spends whoever wrote the lists.

What closes:
* `freeze_agrees`, `unfreeze_agrees`: an alert fund whose single interval contains the height (or whose stop
  is behind the store's height and whose policy freeze expires with it) leaves the output frozen (not frozen)
  in Teranode's store exactly as #70's `freezeConsensus` leaves it frozen (not frozen) on both of the
  reference's paths at that height, stated in `FrozenLists`, the input every reference transition reads.
* The witnesses where they differ, each a theorem over every store and every record:
  `unfreeze_keeps_policy_freeze` (a policy freeze that does not expire), `future_start_frozen_early` (an
  interval that has not begun), `stop_passed_still_frozen` (an interval that has ended under a standing
  freeze), `freeze_spent_refused` (an output an unmined transaction already spends),
  `whitelist_ignores_enforce`, `reassign_gate` and `reassign_strands` (confiscation by reassignment, not by
  a transaction whitelist), and `whitelist_not_confiscation` (no confiscation-shape check on the alert path).
* `ban_agrees`, `unban_agrees`, `ban_until_differs`: the ban lists.
* `alert_invalidate_is_operator_invalidate` and `alert_invalidate_refines`: the alert's invalidation is the
  blockchain service's own call; equality with `BsvChain.invalidateBlock` is #88's `invalidation` row,
  stated and NOT asserted.
* `trust_root_changes_who_not_what`: under any two authorities that both admit a request, the action applied
  is the same.
-/

namespace BsvChain.Teranode.Alert
open BsvChain BsvScript.Tx BsvScript.Numbers

/-! ## 1. The store's output, as the alert touches it -/

/-- An output's spending data in the store: absent (unspent), a spender's data, or all `0xFF` bytes, which
the store reads as frozen (`FROZEN_BYTE = 255` and `isFrozen`, `teranode.lua:5,234-245`; written by `freeze`
:768-774) [SRC] 4edb60a4. -/
inductive Slot where
  | unspent
  | spent (spender : Bytes)
  | frozen
  deriving DecidableEq, Repr

/-- One output's entry: the UTXO hash the record stores (the commitment `util.UTXOHashFromOutput` computes
over the transaction id, the index and the output, `node.go:325`), its spending data, and the height from
which a reassigned output is spendable (the record's `utxoSpendableIn` map, `teranode.lua:25,934-948`)
[SRC] 4edb60a4. -/
structure Utxo where
  hash : Bytes
  slot : Slot := .unspent
  spendableIn : Option Nat := none
  deriving DecidableEq, Repr

/-- The store as the alert's calls read it: each output's entry and the store's block height
(`GetBlockHeight`, read by `node.go:339` and passed to `reassign` by `alert_system.go:249`) [SRC] 4edb60a4. -/
structure Store where
  utxo : OutPoint → Option Utxo
  height : Nat

/-- Replace one output's entry (the Lua functions' `utxos[offset + 1] = newUtxo`). -/
def Store.set (s : Store) (p : OutPoint) (u : Utxo) : Store :=
  { s with utxo := fun q => if q = p then some u else s.utxo q }

/-- The Lua functions' error codes, as the alert's calls can meet them (`teranode.lua:38-75`) [SRC] 4edb60a4. -/
inductive StoreResult where
  | ok | utxoNotFound | hashMismatch | invalidSize | alreadyFrozen | spent | notFrozen | frozen | frozenUntil (h : Nat)
  deriving DecidableEq, Repr

/-- `getUTXOAndSpendingData`: the output's entry when its stored hash is the caller's
(`teranode.lua:194-232`) [SRC] 4edb60a4. -/
def Store.lookup (s : Store) (p : OutPoint) (hash : Bytes) : Except StoreResult Utxo :=
  match s.utxo p with
  | none => .error .utxoNotFound
  | some u => if u.hash = hash then .ok u else .error .hashMismatch

/-- Frozen in the store: the spending data is the frozen mark. -/
def Store.frozenAt (s : Store) (p : OutPoint) : Bool :=
  (s.utxo p).any (fun u => decide (u.slot = .frozen))

/-- The store's lists as the reference machine's input: one mark for both paths and every height (the
spend's gate reads it whether the spend comes from a transaction or a block's, `teranode.lua:406-411`), and no
transaction whitelist (no store call records a transaction id; confiscation is the reassignment of §3)
[SRC] 4edb60a4. -/
def Store.project (s : Store) : FrozenLists :=
  ⟨fun _ _ p => s.frozenAt p, fun _ _ _ => false⟩

/-! ## 2. The store calls -/

/-- `freeze` (`teranode.lua:713-787`, called per output by `FreezeUTXOs`, `alert_system.go:88-147`): an
unspent output takes the frozen mark; a frozen one is `ALREADY_FROZEN` and a spent one `SPENT`, the store
unchanged [SRC] 4edb60a4. -/
def freeze (s : Store) (p : OutPoint) (hash : Bytes) : StoreResult × Store :=
  match s.lookup p hash with
  | .error e => (e, s)
  | .ok u =>
    match u.slot with
    | .frozen => (.alreadyFrozen, s)
    | .spent _ => (.spent, s)
    | .unspent => (.ok, s.set p { u with slot := .frozen })

/-- `unfreeze` (`teranode.lua:795-860`, called by `UnFreezeUTXOs`, `alert_system.go:165-213`): a frozen
output's spending data is cleared; an unspent output is `UTXO_INVALID_SIZE` (:828-834) and a spent one
`UTXO_NOT_FROZEN` (:837-843), the store unchanged [SRC] 4edb60a4. -/
def unfreeze (s : Store) (p : OutPoint) (hash : Bytes) : StoreResult × Store :=
  match s.lookup p hash with
  | .error e => (e, s)
  | .ok u =>
    if u.slot = .frozen then (.ok, s.set p { u with slot := .unspent })
    else match u.slot with | .unspent => (.invalidSize, s) | _ => (.notFrozen, s)

/-- `ReAssignedUtxoSpendableAfterBlocks = 1_000` (`stores/utxo/Interface.go:46-48`); the Aerospike path passes
this constant (`alert_system.go:250`); the SQL path reads the setting (`stores/utxo/sql/alert_system.go:172-177`)
[SRC] 4edb60a4. -/
def reassignedSpendableAfter : Nat := 1000

/-- `reassign` (`teranode.lua:870-958`, called by `ReAssignUTXO`, `alert_system.go:233-270`): a frozen
output takes the new hash, its spending data cleared, spendable from the store's height plus
`reassignedSpendableAfter`; an unspent output is `UTXO_INVALID_SIZE` (:903-909) and a spent one
`UTXO_NOT_FROZEN` (:912-918), the store unchanged [SRC] 4edb60a4. -/
def reassign (s : Store) (p : OutPoint) (old new : Bytes) : StoreResult × Store :=
  match s.lookup p old with
  | .error e => (e, s)
  | .ok u =>
    if u.slot = .frozen then
      (.ok, s.set p { hash := new, slot := .unspent, spendableIn := some (s.height + reassignedSpendableAfter) })
    else match u.slot with | .unspent => (.invalidSize, s) | _ => (.notFrozen, s)

/-- One output's spend in `spendMulti`, the gates the alert's marks meet: the hash (`teranode.lua:357`), the
reassignment's height gate `FROZEN_UNTIL` (:371-382), the same spender's idempotent success (:386-405), the
frozen mark `FROZEN` (:406-411), another spender `SPENT` (:415-425), else the spending data written. The
record-level gates before them (the conflicting and locked marks, coinbase maturity) are #90's
(`BsvChain.Teranode.spendOne`) [SRC] 4edb60a4. -/
def spend (s : Store) (p : OutPoint) (hash spender : Bytes) : StoreResult × Store :=
  match s.lookup p hash with
  | .error e => (e, s)
  | .ok u =>
    match u.spendableIn with
    | some n => if s.height < n then (.frozenUntil n, s) else spendSlot u
    | none => spendSlot u
where
  spendSlot (u : Utxo) : StoreResult × Store :=
    match u.slot with
    | .spent j => if j = spender then (.ok, s) else (.spent, s)
    | .frozen => (.frozen, s)
    | .unspent => (.ok, s.set p { u with slot := .spent spender })

/-! ## 3. The node interface's actions (`services/alert/node.go`) -/

/-- The parent's output as the store's `Get` returns it (`node.go:296,310-315`): its satoshis and script. -/
abbrev Parents := OutPoint → Option (Nat × Bytes)

/-- `util.UTXOHashFromOutput`: the commitment over the outpoint and the output's satoshis and script
(`node.go:325,443,481`) [SRC] 4edb60a4. -/
abbrev UtxoHash := OutPoint → Nat → Bytes → Bytes

/-- One fund of a freeze or unfreeze alert. The alert's wire form carries exactly one interval per fund
(`AlertMessageFreezeUtxo.Read` and `AlertMessageUnfreezeUtxo.Read`, go-alert-system v0.1.17
`app/models/alert_message_freeze_utxo.go:46-88`, `alert_message_unfreeze_utxo.go:36-55`, both handed to
`AddToConsensusBlacklist`, :91-97 and :68-69) [SRC]; `node.go:339` reads only `EnforceAtHeight[0]` and freezes
on an empty list [SRC] 4edb60a4. -/
structure Fund where
  out : OutPoint
  start : Int
  stop : Int
  expires : Bool
  deriving DecidableEq, Repr

/-- One fund of `AddToConsensusBlacklist` (`node.go:288-350`): the parent read (absent: not processed),
the hash from the stored output, then the interval's stop against the store's height: behind it, unfreeze;
otherwise freeze. The start and the expiry flag are not read [SRC] 4edb60a4. -/
def blacklistOne (H : UtxoHash) (parents : Parents) (s : Store) (f : Fund) : Store :=
  match parents f.out with
  | none => s
  | some (sats, script) =>
    if f.stop < (s.height : Int) then (unfreeze s f.out (H f.out sats script)).2
    else (freeze s f.out (H f.out sats script)).2

/-- `AddToConsensusBlacklist` (`node.go:274-353`): the funds one by one [SRC] 4edb60a4. -/
def addToConsensusBlacklist (H : UtxoHash) (parents : Parents) (s : Store) (funds : List Fund) : Store :=
  funds.foldl (blacklistOne H parents) s

/-- The reference's `addToConsensusBlacklist` (`src/rpc/frozentxo_rpc.cpp:346-378`) on the same fund: the
fund's intervals and expiry handed to #70's `freezeConsensus` (`ImportFundsToDB`, :188-206) [SRC] 6504a3af. -/
def refBlacklistOne (d : OperatorLists) (f : Fund) : OperatorLists :=
  (d.freezeConsensus f.out [⟨f.start, f.stop⟩] f.expires).2

/-- The reference's call over the funds. The same handler then removes the pool's entries that spend a
newly frozen output (`RemoveFundsFromQueues`, :250-267, through `CTxMemPool::RemoveFrozen`), the pool
transition this module does not restate [SRC] 6504a3af. -/
def refAddToConsensusBlacklist (d : OperatorLists) (funds : List Fund) : OperatorLists :=
  funds.foldl refBlacklistOne d

/-- One input of a confiscation alert's transaction: the outpoint, the satoshis the extended input claims
(`PreviousTxSatoshis`, `node.go:437`) and the unlocking script. -/
structure CInput where
  out : OutPoint
  claimedSats : Nat
  unlocking : Bytes
  deriving DecidableEq, Repr

/-- A confiscation alert's entry: the enforce height the alert carries (`AlertMessageConfiscateTransaction`,
go-alert-system v0.1.17 `app/models/alert_message_confiscate_utxo.go:24,57-61`) [SRC] and the
transaction's inputs. -/
structure Confiscation where
  enforceAtHeight : Int
  inputs : List CInput
  deriving DecidableEq, Repr

/-- One input of `AddToConfiscationTransactionWhitelist` (`node.go:419-497`): the parent read, the claimed
satoshis at most the parent's (:437-440), the key `key` reads from the unlocking script (`extractPublicKey`
:459,538-555: the last element of at least two), the new commitment over the same satoshis and the
P2PKH script `p2pkh` builds for the key (:466-481), and `ReAssignUTXO` (:494) [SRC] 4edb60a4. A failure of the
script's construction (`node.go:466-470`: not processed) is folded into `key` returning `none`. -/
def whitelistInput (H : UtxoHash) (parents : Parents) (key : Bytes → Option Bytes) (p2pkh : Bytes → Bytes)
    (s : Store) (i : CInput) : Store :=
  match parents i.out with
  | none => s
  | some (sats, script) =>
    if sats < i.claimedSats then s else
    match key i.unlocking with
    | none => s
    | some pk => (reassign s i.out (H i.out sats script) (H i.out sats (p2pkh pk))).2

/-- `AddToConfiscationTransactionWhitelist` (`node.go:397-501`): every input of every transaction. The
alert's enforce height is not read [SRC] 4edb60a4. -/
def addToConfiscationTransactionWhitelist (H : UtxoHash) (parents : Parents) (key : Bytes → Option Bytes)
    (p2pkh : Bytes → Bytes) (s : Store) (txs : List Confiscation) : Store :=
  txs.foldl (fun s c => c.inputs.foldl (whitelistInput H parents key p2pkh) s) s

/-! ## 4. The equivalence where it holds -/

/-- Writing an output's entry makes it the entry the store reads back for that output. -/
theorem set_utxo_self (s : Store) (p : OutPoint) (u : Utxo) : (s.set p u).utxo p = some u := by
  simp [Store.set]

/-- Rewriting every entry of the output to its new record leaves the new record the one a lookup finds,
when the output had an entry. -/
theorem find_map_set (l : List (OutPoint × FrozenTxoData)) (p : OutPoint) (data : FrozenTxoData)
    (h : ∃ x, (p, x) ∈ l) :
    (l.map (fun e => if e.1 == p then (p, data) else e)).find? (fun e => e.1 == p) = some (p, data) := by
  induction l with
  | nil => obtain ⟨x, hx⟩ := h; simp at hx
  | cons e l ih =>
    by_cases he : e.1 = p
    · simp [he]
    · have h' : ∃ x, (p, x) ∈ l := by
        obtain ⟨x, hx⟩ := h
        rcases List.mem_cons.mp hx with hx | hx
        · exact absurd (by rw [← hx]) he
        · exact ⟨x, hx⟩
      have hb : (e.1 == p) = false := by simpa using he
      rw [List.map_cons, ite_eq_right (by simp [hb]), List.find?_cons_of_neg (by simp [hb]), ih h']

/-- #70's `setFrozen` makes the record the output's. -/
theorem setFrozen_frozenData (d : OperatorLists) (p : OutPoint) (data : FrozenTxoData) :
    (d.setFrozen p data).frozenData p = some data := by
  unfold OperatorLists.setFrozen OperatorLists.frozenData
  split
  · rename_i hany
    have h' : ∃ x, (p, x) ∈ d.frozen := by simpa using hany
    simp only [find_map_set _ _ _ h', Option.map_some]
  · rename_i hany
    have hnot : ∀ y, (p, y) ∉ d.frozen := by simpa using hany
    have hnone : d.frozen.find? (fun e => e.1 == p) = none := by
      rw [List.find?_eq_none]
      intro x hx heq
      obtain ⟨a, b⟩ := x
      simp at heq
      subst heq
      exact hnot b hx
    simp [List.find?_append, hnone]

/-- After #70's `freezeConsensus` the output's record carries the call's intervals and expiry on the ranged
or the confiscated list: a policy-only or absent record moves to the ranged list, a ranged or confiscated
record keeps its list (`src/frozentxo_db.cpp:328-371`) [SRC] 6504a3af. -/
theorem freezeConsensus_record (d : OperatorLists) (p : OutPoint) (ranges : List HeightInterval) (e : Bool) :
    ∃ bl, bl ≠ Blacklist.policyOnly ∧ (d.freezeConsensus p ranges e).2.frozenData p = some ⟨bl, ranges, e⟩ := by
  unfold OperatorLists.freezeConsensus
  cases hd : d.frozenData p with
  | none => exact ⟨.consensus, by decide, by simp [setFrozen_frozenData]⟩
  | some data =>
    rcases data with ⟨bl, rs, ex⟩
    by_cases hp : bl = .policyOnly
    · subst hp; exact ⟨.consensus, by decide, by simp [setFrozen_frozenData]⟩
    · have hb : (bl == Blacklist.policyOnly) = false := by simpa using hp
      by_cases hs : rs = ranges ∧ ex = e
      · obtain ⟨rfl, rfl⟩ := hs
        exact ⟨bl, hp, by simp [hb, hd]⟩
      · refine ⟨bl, hp, ?_⟩
        have hne : (rs == ranges && ex == e) = false := by
          by_cases h1 : rs = ranges <;> by_cases h2 : ex = e <;> simp_all
        simp [hb, hne, setFrozen_frozenData]

/-- **The freeze agrees.** Premises: the fund's parent is stored with the output's committed hash and the
output is unspent or already frozen in Teranode's store; the store's height is not past the fund's stop (so
`node.go:339` freezes); the height `h` lies in the fund's interval. Then, at `h` and on both paths, the
output is frozen in Teranode's projection and in the reference's after #70's `freezeConsensus`.
[SRC] `node.go:339-349`, `teranode.lua:713-787` at 4edb60a4; `src/frozentxo.cpp:37-83`,
`src/frozentxo_db.h:323-377` at 6504a3af. -/
theorem freeze_agrees (H : UtxoHash) (parents : Parents) (s : Store) (d : OperatorLists) (f : Fund)
    (sats : Nat) (script : Bytes) (u : Utxo) (h : Nat)
    (hparent : parents f.out = some (sats, script)) (hu : s.utxo f.out = some u)
    (hhash : u.hash = H f.out sats script) (hslot : u.slot = .unspent ∨ u.slot = .frozen)
    (hfreeze : ¬ f.stop < (s.height : Int)) (hstart : f.start ≤ (h : Int)) (hstop : (h : Int) < f.stop)
    (onBlock : Bool) :
    (blacklistOne H parents s f).project.frozen onBlock h f.out = true ∧
    (refBlacklistOne d f).project.frozen onBlock h f.out = true := by
  constructor
  · simp only [Store.project, Store.frozenAt, blacklistOne, hparent, hfreeze, ite_false]
    rcases hslot with hs | hs
    · simp [freeze, Store.lookup, hu, hhash, hs, Store.set]
    · simp [freeze, Store.lookup, hu, hhash, hs]
  · obtain ⟨bl, hbl, hrec⟩ := freezeConsensus_record d f.out [⟨f.start, f.stop⟩] f.expires
    simp only [refBlacklistOne, OperatorLists.project, OperatorLists.check, hrec]
    have hv : decide (f.start < f.stop) = true := by simp; omega
    cases bl <;> cases onBlock <;>
      simp_all [FrozenTxoData.frozenOnConsensus, FrozenTxoData.frozenOnPolicy, HeightInterval.valid]

/-- **The unfreeze agrees.** Premises: the fund's parent is stored with the output's committed hash and the
output is frozen or unspent in Teranode's store; the fund's stop is behind the store's height (so
`node.go:339` unfreezes); the fund's policy freeze expires with its interval; the reference's record is not
on the confiscation list; the height `h` is at or past the stop. Then, at `h` and on both paths, the output
is not frozen in either projection. [SRC] `node.go:339-343`, `teranode.lua:795-860` at 4edb60a4;
`src/frozentxo_db.h:323-377` at 6504a3af. -/
theorem unfreeze_agrees (H : UtxoHash) (parents : Parents) (s : Store) (d : OperatorLists) (f : Fund)
    (sats : Nat) (script : Bytes) (u : Utxo) (h : Nat)
    (hparent : parents f.out = some (sats, script)) (hu : s.utxo f.out = some u)
    (hhash : u.hash = H f.out sats script) (hslot : u.slot = .unspent ∨ u.slot = .frozen)
    (hunfreeze : f.stop < (s.height : Int)) (hexp : f.expires = true)
    (hconf : ∀ x, d.frozenData f.out = some x → x.blacklist ≠ .confiscation)
    (hpast : f.stop ≤ (h : Int)) (onBlock : Bool) :
    (blacklistOne H parents s f).project.frozen onBlock h f.out = false ∧
    (refBlacklistOne d f).project.frozen onBlock h f.out = false := by
  constructor
  · simp only [Store.project, Store.frozenAt, blacklistOne, hparent, hunfreeze, ite_true]
    rcases hslot with hs | hs
    · simp [unfreeze, Store.lookup, hu, hhash, hs]
    · simp [unfreeze, Store.lookup, hu, hhash, hs, Store.set]
  · obtain ⟨bl, hbl, hrec⟩ := freezeConsensus_record d f.out [⟨f.start, f.stop⟩] f.expires
    have hnc : bl ≠ .confiscation := by
      intro hb; subst hb
      unfold OperatorLists.freezeConsensus at hrec
      cases hd : d.frozenData f.out with
      | none => simp [hd, setFrozen_frozenData] at hrec
      | some x =>
        have := hconf x hd
        by_cases hp : x.blacklist = .policyOnly
        · simp [hd, hp, setFrozen_frozenData] at hrec
        · by_cases hs : x.enforceAtHeight = [⟨f.start, f.stop⟩] ∧ x.policyExpiresWithConsensus = f.expires
          · simp [hd, hp, hs.1, hs.2] at hrec; exact this (by rw [hrec])
          · have hne : (x.enforceAtHeight == [⟨f.start, f.stop⟩] && x.policyExpiresWithConsensus == f.expires) = false := by
              by_cases h1 : x.enforceAtHeight = [⟨f.start, f.stop⟩] <;>
                by_cases h2 : x.policyExpiresWithConsensus = f.expires <;> simp_all
            simp [hd, hp, hne, setFrozen_frozenData] at hrec
            exact this hrec
    have hcons : bl = .consensus := by cases bl <;> simp_all
    subst hcons
    simp only [refBlacklistOne, OperatorLists.project, OperatorLists.check, hrec]
    cases onBlock <;>
      simp [FrozenTxoData.frozenOnConsensus, FrozenTxoData.frozenOnPolicy, HeightInterval.valid, hexp] <;> omega

/-! ## 5. The witnesses where they differ -/

/-- **Witness: an unfreeze that does not expire the policy freeze.** Under `unfreeze_agrees`'s premises but
the fund's `policyExpiresWithConsensus` false, Teranode's store reads the output not frozen while the
reference still refuses it on the admission path at every height at or past the stop: #70's record keeps
the policy freeze after its intervals (`src/frozentxo_db.h:323-348`) [SRC] 6504a3af, and `node.go:339` reads
neither the expiry flag nor anything but the stop [SRC] 4edb60a4. -/
theorem unfreeze_keeps_policy_freeze (H : UtxoHash) (parents : Parents) (s : Store) (d : OperatorLists)
    (f : Fund) (sats : Nat) (script : Bytes) (u : Utxo) (h : Nat)
    (hparent : parents f.out = some (sats, script)) (hu : s.utxo f.out = some u)
    (hhash : u.hash = H f.out sats script) (hslot : u.slot = .unspent ∨ u.slot = .frozen)
    (hunfreeze : f.stop < (s.height : Int)) (hexp : f.expires = false) :
    (blacklistOne H parents s f).project.frozen false h f.out = false ∧
    (refBlacklistOne d f).project.frozen false h f.out = true := by
  constructor
  · simp only [Store.project, Store.frozenAt, blacklistOne, hparent, hunfreeze, ite_true]
    rcases hslot with hs | hs
    · simp [unfreeze, Store.lookup, hu, hhash, hs]
    · simp [unfreeze, Store.lookup, hu, hhash, hs, Store.set]
  · obtain ⟨bl, hbl, hrec⟩ := freezeConsensus_record d f.out [⟨f.start, f.stop⟩] f.expires
    simp only [refBlacklistOne, OperatorLists.project, OperatorLists.check, hrec]
    cases bl <;> simp_all [FrozenTxoData.frozenOnPolicy]

/-- **Witness: an interval that has not begun.** A fund whose start is above `h` (and whose stop is not
behind the store's height): Teranode freezes the output at once, on both paths; the reference's block path
does not consult the record below the start for a ranged record (`src/frozentxo_db.h:353-377`) [SRC]
6504a3af, so a block at `h` spending it connects on the reference and is refused on Teranode. The premise on
the reference's prior record (none or policy-only) makes the resulting list the ranged one. -/
theorem future_start_frozen_early (H : UtxoHash) (parents : Parents) (s : Store) (d : OperatorLists)
    (f : Fund) (sats : Nat) (script : Bytes) (u : Utxo) (h : Nat)
    (hparent : parents f.out = some (sats, script)) (hu : s.utxo f.out = some u)
    (hhash : u.hash = H f.out sats script) (hslot : u.slot = .unspent)
    (hfreeze : ¬ f.stop < (s.height : Int)) (hbefore : (h : Int) < f.start)
    (hprior : ∀ x, d.frozenData f.out = some x → x.blacklist = .policyOnly) :
    (blacklistOne H parents s f).project.frozen true h f.out = true ∧
    (refBlacklistOne d f).project.frozen true h f.out = false := by
  constructor
  · simp [Store.project, Store.frozenAt, blacklistOne, hparent, hfreeze, freeze, Store.lookup, hu, hhash,
      hslot, Store.set]
  · have hrec : (refBlacklistOne d f).frozenData f.out = some ⟨.consensus, [⟨f.start, f.stop⟩], f.expires⟩ := by
      unfold refBlacklistOne OperatorLists.freezeConsensus
      cases hd : d.frozenData f.out with
      | none => simp [setFrozen_frozenData]
      | some x => simp [hprior x hd, setFrozen_frozenData]
    simp [OperatorLists.project, OperatorLists.check, hrec, FrozenTxoData.frozenOnConsensus]
    omega

/-- **Witness: an interval that has ended under a standing freeze.** After a fund that froze the output
(the store's height not past the stop), with the policy freeze expiring with the interval, at every height
at or past the stop the reference reads the output free on both paths of a ranged record, while
Teranode's mark stands until another alert clears it: the store's mark carries no height
(`teranode.lua:768-774`) [SRC] 4edb60a4. -/
theorem stop_passed_still_frozen (H : UtxoHash) (parents : Parents) (s : Store) (d : OperatorLists)
    (f : Fund) (sats : Nat) (script : Bytes) (u : Utxo) (h : Nat)
    (hparent : parents f.out = some (sats, script)) (hu : s.utxo f.out = some u)
    (hhash : u.hash = H f.out sats script) (hslot : u.slot = .unspent)
    (hfreeze : ¬ f.stop < (s.height : Int)) (hexp : f.expires = true) (hpast : f.stop ≤ (h : Int))
    (hprior : ∀ x, d.frozenData f.out = some x → x.blacklist = .policyOnly) (onBlock : Bool) :
    (blacklistOne H parents s f).project.frozen onBlock h f.out = true ∧
    (refBlacklistOne d f).project.frozen onBlock h f.out = false := by
  constructor
  · simp [Store.project, Store.frozenAt, blacklistOne, hparent, hfreeze, freeze, Store.lookup, hu, hhash,
      hslot, Store.set]
  · have hrec : (refBlacklistOne d f).frozenData f.out = some ⟨.consensus, [⟨f.start, f.stop⟩], f.expires⟩ := by
      unfold refBlacklistOne OperatorLists.freezeConsensus
      cases hd : d.frozenData f.out with
      | none => simp [setFrozen_frozenData]
      | some x => simp [hprior x hd, setFrozen_frozenData]
    cases onBlock <;>
      simp [OperatorLists.project, OperatorLists.check, hrec, FrozenTxoData.frozenOnConsensus,
        FrozenTxoData.frozenOnPolicy, HeightInterval.valid, hexp] <;> omega

/-- **Witness: an output an unmined transaction already spends.** Teranode's `freeze` refuses it with
`SPENT` and the store is unchanged, so the spender stays (`teranode.lua:743-765`) [SRC] 4edb60a4; the
reference records the freeze whatever the output's state (#70's `freezeConsensus` reads only the record) and
its handler then evicts the pool's spenders of frozen outputs (`RemoveFundsFromQueues`,
`src/rpc/frozentxo_rpc.cpp:250-267,375`) [SRC] 6504a3af. -/
theorem freeze_spent_refused (H : UtxoHash) (parents : Parents) (s : Store) (d : OperatorLists) (f : Fund)
    (sats : Nat) (script : Bytes) (u : Utxo) (j : Bytes) (h : Nat)
    (hparent : parents f.out = some (sats, script)) (hu : s.utxo f.out = some u)
    (hhash : u.hash = H f.out sats script) (hslot : u.slot = .spent j)
    (hfreeze : ¬ f.stop < (s.height : Int)) (hstart : f.start ≤ (h : Int)) (hstop : (h : Int) < f.stop) :
    blacklistOne H parents s f = s ∧ (refBlacklistOne d f).project.frozen false h f.out = true := by
  constructor
  · simp [blacklistOne, hparent, hfreeze, freeze, Store.lookup, hu, hhash, hslot]
  · have hu' : u.slot = .unspent ∨ u.slot = .frozen → False := by rw [hslot]; simp
    obtain ⟨bl, hbl, hrec⟩ := freezeConsensus_record d f.out [⟨f.start, f.stop⟩] f.expires
    simp only [refBlacklistOne, OperatorLists.project, OperatorLists.check, hrec]
    cases bl <;>
      (simp_all [FrozenTxoData.frozenOnConsensus, FrozenTxoData.frozenOnPolicy, HeightInterval.valid]
       all_goals omega)

/-- **Witness: the confiscation's enforce height is not read.** Two confiscation alerts that differ only in
their enforce height leave the same store (`node.go:397-501` reads only the transaction) [SRC] 4edb60a4;
the reference's whitelist entry carries it and admits the transaction from that height
(`src/frozentxo.cpp:133-171`) [SRC] 6504a3af. [D] one-sided: the reference's half is that cited prose, not a
theorem here. -/
theorem whitelist_ignores_enforce (H : UtxoHash) (parents : Parents) (key : Bytes → Option Bytes)
    (p2pkh : Bytes → Bytes) (s : Store) (ins : List CInput) (e₁ e₂ : Int) :
    addToConfiscationTransactionWhitelist H parents key p2pkh s [⟨e₁, ins⟩] =
    addToConfiscationTransactionWhitelist H parents key p2pkh s [⟨e₂, ins⟩] := rfl

/-- **Witness: the reassignment's height gate.** After a reassignment of a frozen output, a spend presenting
the new hash is `FROZEN_UNTIL` the store's height plus 1000 while the store's height is below it
(`teranode.lua:371-382,948`; `Interface.go:46-48`) [SRC] 4edb60a4. The reference admits the whitelisted
transaction from the enforce height the operator chose, and a confiscation output's own maturity is
`confiscationMaturity` (PARAMETERS §8.2) [SRC] 6504a3af. [D] one-sided: the reference's half is that cited
prose, not a theorem here. -/
theorem reassign_gate (s : Store) (p : OutPoint) (old new spender : Bytes) (u : Utxo)
    (hu : s.utxo p = some u) (hhash : u.hash = old) (hslot : u.slot = .frozen) :
    (spend (reassign s p old new).2 p new spender).1 = .frozenUntil (s.height + reassignedSpendableAfter) := by
  simp [reassign, spend, Store.lookup, hu, hhash, hslot, Store.set, reassignedSpendableAfter]

/-- **Witness: the reassigned output is stranded for its original script.** After the reassignment, a
spend presenting the hash of the output's stored script (the parent transaction the store still holds) meets
`UTXO_HASH_MISMATCH` whenever the new commitment differs from it, whatever the height: the store keeps the
new hash and not the script it commits to (`teranode.lua:922-925`); Teranode's own comment says the
replacement script is not persisted (`node.go:478-480`) [SRC] 4edb60a4. -/
theorem reassign_strands (s : Store) (p : OutPoint) (old new spender : Bytes) (u : Utxo)
    (hu : s.utxo p = some u) (hhash : u.hash = old) (hslot : u.slot = .frozen) (hne : new ≠ old) :
    (spend (reassign s p old new).2 p old spender).1 = .hashMismatch := by
  simp [reassign, spend, Store.lookup, hu, hhash, hslot, Store.set, hne]

/-- **Witness: no confiscation-shape check on the alert path.** The reference refuses to whitelist a
transaction that is not a confiscation transaction (its output zero not the `cftx` protocol prefix) and
leaves its lists unchanged (`src/frozentxo_db.cpp:614-636,720-800`) [SRC] 6504a3af; Teranode's
`whitelistInput` reads no output of the transaction, so a frozen input of any transaction is reassigned
(`node.go:411-497`) [SRC] 4edb60a4. [D] one-sided: the theorem states the reference's half; Teranode's half
is the sibling theorem `whitelist_input_reassigns`. -/
theorem whitelist_not_confiscation (d : OperatorLists) (enforce : Int) (tx : Tx)
    (hshape : isConfiscationTx tx = false) :
    d.whitelistTx enforce tx = (.errorNotValid, d) := by
  simp [OperatorLists.whitelistTx, hshape]

/-- The other half of the same witness: a frozen input with a stored parent, claimed satoshis at most the
parent's and an unlocking script `key` reads is reassigned, whatever the transaction's outputs. [D] one-sided:
the theorem states Teranode's half; the reference's half is the sibling theorem `whitelist_not_confiscation`. -/
theorem whitelist_input_reassigns (H : UtxoHash) (parents : Parents) (key : Bytes → Option Bytes)
    (p2pkh : Bytes → Bytes) (s : Store) (i : CInput) (sats : Nat) (script pk : Bytes) (u : Utxo)
    (hparent : parents i.out = some (sats, script)) (hsats : ¬ sats < i.claimedSats)
    (hkey : key i.unlocking = some pk) (hu : s.utxo i.out = some u) (hhash : u.hash = H i.out sats script)
    (hslot : u.slot = .frozen) :
    (whitelistInput H parents key p2pkh s i).utxo i.out =
      some { hash := H i.out sats (p2pkh pk), slot := .unspent,
             spendableIn := some (s.height + reassignedSpendableAfter) } := by
  simp [whitelistInput, hparent, hsats, hkey, reassign, Store.lookup, hu, hhash, hslot, Store.set]

/-! ## 6. The peers and the chain -/

/-- A ban list: each banned address and the time its ban ends (seconds since the epoch). Addresses are
taken as the lists' keys; Teranode's removal also matches every spelling of the same host
(`internal/banlist/ban_list.go:221-226`) [SRC] 4edb60a4. -/
abbrev BanList := List (String × Int)

/-- The ban's end for an address, if banned. -/
def banUntil? (l : BanList) (a : String) : Option Int := (l.find? (fun e => e.1 == a)).map (·.2)

/-- Write an address's ban. -/
def banSet (l : BanList) (a : String) (u : Int) : BanList := l.filter (fun e => e.1 != a) ++ [(a, u)]

/-- The reference's `CConnman::Ban` with an absolute time: a ban only lengthens (`src/net/net.cpp:541-559`)
[SRC] 6504a3af. -/
def refBan (l : BanList) (a : String) (u : Int) : BanList :=
  if (banUntil? l a).getD 0 < u then banSet l a u else l

/-- The reference's `CConnman::Unban` (`src/net/net.cpp:587-594`) [SRC] 6504a3af. -/
def refUnban (l : BanList) (a : String) : BanList := l.filter (fun e => e.1 != a)

/-- Teranode's `BanList.Add` overwrites (`internal/banlist/ban_list.go:192-219`) [SRC] 4edb60a4. -/
def teraBan (l : BanList) (a : String) (u : Int) : BanList := banSet l a u

/-- Teranode's `BanList.Remove` (`internal/banlist/ban_list.go:227-290`) [SRC] 4edb60a4. -/
def teraUnban (l : BanList) (a : String) : BanList := l.filter (fun e => e.1 != a)

/-- The alert's ban length, 100 years in seconds (`node.go:192-193,202`) [SRC] 4edb60a4. -/
def alertBanSeconds : Int := 24 * 365 * 100 * 3600

/-- `BanPeer` (`node.go:189-216`): the P2P service's list takes the ban until `now` plus 100 years
(`services/p2p/Server.go:2973-2985`); the legacy service bans only a connected peer and otherwise errors
(`services/legacy/Server.go:663-685`), so the call reports failure for a peer not connected on the legacy
side after the P2P ban is written. The result: the list and whether the call reported success [SRC] 4edb60a4. -/
def alertBan (now : Int) (legacyConnected : Bool) (l : BanList) (a : String) : BanList × Bool :=
  (teraBan l a (now + alertBanSeconds), legacyConnected)

/-- **The ban agrees** when no ban of the address stands at `now`: Teranode's list after the alert is the
reference's after `setban <a> add <now + 100 years> true` (`src/rpc/net.cpp:726-747`); the RPC refuses
otherwise (`src/rpc/net.cpp:727-731`; `IsBanned` is `GetTime() < nBanUntil`, `src/net/net.cpp:512,527`)
[SRC] 6504a3af. -/
theorem ban_agrees (now : Int) (c : Bool) (l : BanList) (a : String)
    (hfree : (banUntil? l a).getD 0 ≤ now) :
    (alertBan now c l a).1 = refBan l a (now + alertBanSeconds) := by
  have hlonger : (banUntil? l a).getD 0 < now + alertBanSeconds := by simp [alertBanSeconds]; omega
  simp [alertBan, teraBan, refBan, hlonger]

/-- **The unban agrees**: the same list after `UnbanPeer` (`node.go:229-255`) and `setban <a> remove`; the
reference's call errors for an address not banned (`src/rpc/net.cpp:748-754`), leaving the list as it was,
which is the same list. [D] Under the key abstraction of `BanList`: a host held under several spellings is the
case this statement does not reach; Teranode clears them all (`internal/banlist/ban_list.go:221-226`), the
reference the one subnet (`src/net/net.cpp:587-594`). -/
theorem unban_agrees (l : BanList) (a : String) : teraUnban l a = refUnban l a := rfl

/-- The ban's length from an `setban add` with no time: `-bantime`'s default, `DEFAULT_MISBEHAVING_BANTIME`
(`src/net/net.cpp:545-549`, `src/net/net.h:152`) [SRC] 6504a3af. -/
def rpcDefaultBanSeconds : Int := 60 * 60 * 24

/-- **Witness: the ban's length.** The alert's ban lasts 100 years on Teranode; the standalone alert system
that drives the reference passes `setban add` with no time (go-alert-system v0.1.17
`app/config/node.go:65-68`) [SRC], which the reference reads as `-bantime`, a day by default. Stated on the
two transitions when no ban of the address stands at `now`: the ban's end each list records differs. -/
theorem ban_until_differs (now : Int) (c : Bool) (l : BanList) (a : String)
    (hfree : (banUntil? l a).getD 0 ≤ now) :
    banUntil? (alertBan now c l a).1 a ≠ banUntil? (refBan l a (now + rpcDefaultBanSeconds)) a := by
  have hset : ∀ (l : BanList) (u : Int), banUntil? (banSet l a u) a = some u := by
    intro l u
    have hnone : (l.filter (fun e => e.1 != a)).find? (fun e => e.1 == a) = none := by
      rw [List.find?_eq_none]
      intro x hx
      simp only [List.mem_filter, bne_iff_ne, ne_eq] at hx
      simpa using hx.2
    unfold banUntil? banSet
    rw [List.find?_append, hnone]
    simp
  have hlonger : (banUntil? l a).getD 0 < now + rpcDefaultBanSeconds := by simp [rpcDefaultBanSeconds]; omega
  simp only [alertBan, teraBan, refBan, hlonger, ↓reduceIte, hset]
  simp [alertBanSeconds, rpcDefaultBanSeconds]

/-- `InvalidateBlock` (`node.go:160-176`): parse the hash and call the blockchain service's
`InvalidateBlock`, the call the node's own operator path reaches (`services/blockchain/Server.go:2380`)
[SRC] 4edb60a4. The service's transition is the parameter `inv`. -/
def alertInvalidate {σ : Type} (inv : σ → BitVec 256 → σ) (s : σ) (hash : BitVec 256) : σ := inv s hash

/-- The alert adds no step of its own to Teranode's invalidation. -/
theorem alert_invalidate_is_operator_invalidate {σ : Type} (inv : σ → BitVec 256 → σ) (s : σ)
    (hash : BitVec 256) : alertInvalidate inv s hash = inv s hash := rfl

/-- #88's `invalidation` row (spec/teranode-map.md): Teranode's invalidation, under a projection of its state
onto the reference machine's, is `BsvChain.invalidateBlock` (`src/validation.cpp:5230-5330`) [SRC]
6504a3af. Stated and NOT asserted: the obligation #88 owns. -/
def InvalidationRefines {σ : Type} (proj : σ → ChainState) (inv : σ → BitVec 256 → σ) (ctx : ChainContext)
    (lists : FrozenLists) (oracle : ScriptOracle) (fuel : Nat) : Prop :=
  ∀ s hash, proj (inv s hash) = (BsvChain.invalidateBlock (proj s) ctx lists oracle hash fuel).1

/-- Under #88's `invalidation` row the alert's invalidation is the reference's: the alert path discharges
nothing of the row and adds nothing to it. -/
theorem alert_invalidate_refines {σ : Type} (proj : σ → ChainState) (inv : σ → BitVec 256 → σ)
    (ctx : ChainContext) (lists : FrozenLists) (oracle : ScriptOracle) (fuel : Nat)
    (hrow : InvalidationRefines proj inv ctx lists oracle fuel) (s : σ) (hash : BitVec 256) :
    proj (alertInvalidate inv s hash) = (BsvChain.invalidateBlock (proj s) ctx lists oracle hash fuel).1 :=
  hrow s hash

/-! ## 7. The authority path: a node setting, policy -/

/-- Who may change the lists, a node setting (policy, rule 1; `docs/PARAMETERS.md` §8.10). The reference: the
holder of the RPC server's credential (`-rpcuser`/`-rpcpassword`, `-rpcauth` or the cookie,
`src/httprpc.cpp:130-150,344-366`) [SRC] 6504a3af. Teranode: an alert on the topic `alert_topic_name`
signed under the active keys, which start as `alert_genesis_keys` (`settings/settings.go:198,202`)
[SRC] 4edb60a4; the signature check is go-alert-system's (`AreSignaturesValid`, v0.1.17
`app/models/alert_message.go:159-204`) [SRC], abstracted here as the request's `verified`. -/
inductive Authority where
  | rpcCredential (userColonPass : String)
  | alertKeys (genesisKeys : List Bytes) (topic : String)
  deriving DecidableEq, Repr

/-- A request for an action: the credential it presents, or the topic it arrived on and whether its
signatures verified under the active keys. -/
structure Request (α : Type) where
  action : α
  credential : String := ""
  topic : String := ""
  verified : Bool := false

/-- The authority's admission test. -/
def Authority.admits {α : Type} : Authority → Request α → Bool
  | .rpcCredential up, r => r.credential == up
  | .alertKeys _ topic, r => r.topic == topic && r.verified

/-- An action under an authority: applied when admitted, else nothing. -/
def gated {α σ : Type} (auth : Authority) (apply : α → σ → σ) (r : Request α) (s : σ) : σ :=
  if auth.admits r then apply r.action s else s

/-- **The trust root changes who, never what.** Under any two authorities that both admit a request, the
same action is applied to the same state: the parameter set is the same and only the trust root differs.
No premise beyond the two admissions. [D] by construction: whichever authority admits a request, the gate
applies the same action; whether the two nodes' actions agree is the module's §4 and §5. -/
theorem trust_root_changes_who_not_what {α σ : Type} (a₁ a₂ : Authority) (apply : α → σ → σ)
    (r : Request α) (s : σ) (h₁ : a₁.admits r = true) (h₂ : a₂.admits r = true) :
    gated a₁ apply r s = gated a₂ apply r s := by
  simp [gated, h₁, h₂]

end BsvChain.Teranode.Alert
