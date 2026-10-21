import BsvScript.SigOps
import BsvScript.Sighash
/-!
# BsvScript.TxRules

The transaction-level checks the reference applies before any script runs
(#22, the scope boundary of `BsvScript.TxContext`): `CheckTransactionCommon`
(`validation.cpp:519–569`), `CheckRegularTransaction` (`595–640`),
`CheckCoinbase` (`572–593`), with the sigop count `GetSigOpCountWithoutP2SH`
(`438–460`) over `CScript::GetSigOpCount` (`script.cpp:30–128`). They are
written for the reference's vector runner (`src/test/transaction_tests.cpp`
`RunTests`, which calls them with the pre-Genesis limits `MAX_TX_SIGOPS_COUNT_BEFORE_GENESIS`
= 20,000 and `MAX_TX_SIZE_CONSENSUS_BEFORE_GENESIS` = 1 MB, `consensus.h:27, 47`,
and `ProtocolEra::PreGenesis`) and for the spec's transaction verdict; the
block-level rules (fees, the UTXO set, ordering, maturity) are the transaction state
machine's, S6 (#58; `docs/DESIGN-S6.md`), which calls this module's gate from `lean/BsvChain`.

Bare line numbers are `src/validation.cpp` at the pin (`docs/PROVENANCE.md`); the
sigop walk's lines are cited with their file, `script.cpp`, and a `:NNN` continues
the file last named.
-/

namespace BsvScript.TxRules
open BsvScript.Params BsvScript.Numbers BsvScript.Machine BsvScript.Tx

-- [LIT] https://protocol.bsvblockchain.org/specification/transactions#output-ctxout at v1.2.2.
def MAX_MONEY : Nat := 2100000000000000                 -- amount.h:130, 21,000,000 × 10⁸
def MAX_TX_SIZE_CONSENSUS_BEFORE_GENESIS : Nat := 1000000  -- consensus.h:27
def MAX_TX_SIGOPS_COUNT_BEFORE_GENESIS : Nat := 20000      -- consensus.h:47
def MAX_COINBASE_SCRIPTSIG_SIZE : Nat := 100              -- consensus.h:69
def MAX_PUBKEYS_PER_MULTISIG_BEFORE_GENESIS : Nat := 20    -- consensus.h:50

/-- `COutPoint::IsNull` (`transaction.h:68`): the zero txid and index `0xffffffff`.
[LIT] https://protocol.bsvblockchain.org/specification/transactions#coinbase-transaction at v1.2.2. -/
def outPointIsNull (i : TxIn) : Bool := i.prevHash.all (· = 0) && i.prevIndex = 0xffffffff

/-- `CTransaction::IsCoinBase` (`transaction.h:323–325`). -/
def isCoinBase (tx : Tx) : Bool :=
  match tx.inputs with
  | [i] => outPointIsNull i
  | _ => false

/-- `MoneyRange` (`amount.h`): `0 ≤ v ≤ MAX_MONEY`; a serialized value at or
above `2⁶³` is a negative `int64`. -/
def moneyRange (v : Nat) : Bool := v ≤ MAX_MONEY

/-- `CScript::GetSigOpCount(fAccurate, era)` (`script.cpp:30–128`) on the
pre-Genesis path (`fAccurate = false`, the era pre-Genesis, as the vector runner
calls it): the instructions are walked until one whose opcode is `OP_INVALIDOPCODE`
(`script.cpp:44–45`), a push that fails to decode (`instruction_iterator.h:31–72`) or a
literal `0xff`, which decodes as a valid instruction (`:26–27`);
`OP_CHECKSIG`/`OP_CHECKSIGVERIFY` count one (`script.cpp:71–74`); `OP_CHECKMULTISIG`/
`OP_CHECKMULTISIGVERIFY` count `MAX_PUBKEYS_PER_MULTISIG_BEFORE_GENESIS`
(`script.cpp:119–122`; the accurate count and the post-Genesis rules are the other
branches, `script.cpp:78–118`, `SigOps.sigOpCount`, equal to this walk on the pre-Genesis
path by T-TX11). -/
def sigOpCountPreGenesis : Bytes → Nat
  | [] => 0
  | op :: rest =>
    match getOpTail op rest with
    | none => 0
    | some (_, k) =>
      if op = Op.OP_INVALIDOPCODE then 0
      else (if op = Op.OP_CHECKSIG || op = Op.OP_CHECKSIGVERIFY then 1
       else if op = Op.OP_CHECKMULTISIG || op = Op.OP_CHECKMULTISIGVERIFY then MAX_PUBKEYS_PER_MULTISIG_BEFORE_GENESIS
       else 0) + sigOpCountPreGenesis (rest.drop k)
termination_by s => s.length
decreasing_by all_goals simp [List.length_drop]

/-- `GetSigOpCountWithoutP2SH` (`validation.cpp:437–459`): every input's
unlocking script and every output's locking script. -/
def sigOpCountWithoutP2SH (tx : Tx) : Nat :=
  (tx.inputs.map (fun i => sigOpCountPreGenesis i.scriptSig)).sum
    + (tx.outputs.map (fun o => sigOpCountPreGenesis o.scriptPubKey)).sum

/-- The rejection reasons of the transaction-level checks (`validation.cpp`). -/
inductive TxReject where
  | vinEmpty | voutEmpty | oversize | voutNegative | voutTooLarge | txoutTotalTooLarge | sigops
  | coinbaseWhereRegular | coinbaseMissing | coinbaseLength | prevoutNull | inputsDuplicate | p2shOutput
  deriving DecidableEq, Repr

/-- `CheckTransactionCommon` (`validation.cpp:519–569`) under the pre-Genesis
era: inputs and outputs non-empty (`527–532`), the serialized size (`534–536`),
every output's value non-negative and at most `MAX_MONEY` with the running
total in range (`540–558`), and, pre-Genesis only, the sigop count
(`560–567`). -/
def checkTransactionCommon (tx : Tx) (maxSigOps maxSize : Nat) (preGenesis : Bool) : Except TxReject Unit := do
  if tx.inputs.isEmpty then throw .vinEmpty
  if tx.outputs.isEmpty then throw .voutEmpty
  if maxSize < (Sighash.serTx tx).length then throw .oversize
  let mut total := 0
  for o in tx.outputs do
    if 2 ^ 63 ≤ o.value then throw .voutNegative
    if MAX_MONEY < o.value then throw .voutTooLarge
    total := total + o.value
    if !moneyRange total then throw .txoutTotalTooLarge
  if preGenesis && maxSigOps < sigOpCountWithoutP2SH tx then throw .sigops
  pure ()

/-- `CheckRegularTransaction` (`validation.cpp:594–639`): not a coinbase
(`601–603`), the common checks (`605–608`), post-Genesis no P2SH output (`611–622`),
every input's outpoint non-null (`627–631`) and no duplicate outpoint
(`633–636`). -/
def checkRegularTransaction (tx : Tx) (maxSigOps maxSize : Nat) (preGenesis : Bool) : Except TxReject Unit := do
  if isCoinBase tx then throw .coinbaseWhereRegular
  checkTransactionCommon tx maxSigOps maxSize preGenesis
  if !preGenesis && tx.outputs.any (fun o => isP2SH o.scriptPubKey) then throw .p2shOutput
  let mut seen : List (Bytes × Nat) := []
  for i in tx.inputs do
    if outPointIsNull i then throw .prevoutNull
    if seen.contains (i.prevHash, i.prevIndex) then throw .inputsDuplicate
    seen := (i.prevHash, i.prevIndex) :: seen
  pure ()

/-- `CheckCoinbase` (`validation.cpp:571–592`): a coinbase, the common checks,
the coinbase script of 2 to 100 bytes (`588–590`). -/
def checkCoinbase (tx : Tx) (maxSigOps maxSize : Nat) (preGenesis : Bool) : Except TxReject Unit := do
  if !isCoinBase tx then throw .coinbaseMissing
  checkTransactionCommon tx maxSigOps maxSize preGenesis
  let len := (tx.inputs.head?.map (·.scriptSig.length)).getD 0
  if len < 2 || MAX_COINBASE_SCRIPTSIG_SIZE < len then throw .coinbaseLength
  pure ()

end BsvScript.TxRules

namespace BsvScript.TxRules
open BsvScript.Tx

/-- T-TX3: a coinbase has exactly one input (`transaction.h:323–325`). -/
theorem isCoinBase_length (tx : Tx) (h : isCoinBase tx = true) : tx.inputs.length = 1 := by
  unfold isCoinBase at h
  split at h <;> simp_all

open BsvScript.Params BsvScript.Numbers BsvScript.Machine

/-- A non-push opcode parses as itself with no operand (`script.h:176`: no immediate operand above
`OP_PUSHDATA4`; `script.h:198–199`: the opcode returned): the walk's step for every opcode above `OP_PUSHDATA4`. -/
theorem getOpTail_nonpush (op : Nat) (rest : Bytes) (h : Op.OP_PUSHDATA4 < op) : getOpTail op rest = some ([], 0) := by
  simp [getOpTail, Nat.not_le.2 h]

/-- T-TX4: the pre-Genesis sigop count by cases (`script.cpp:30–128`, the `fAccurate = false`, pre-Genesis
branch the vector runner takes): nothing for an empty script … -/
theorem sigOpCountPreGenesis_nil : sigOpCountPreGenesis [] = 0 := by
  simp [sigOpCountPreGenesis]

/-- … `OP_CHECKSIG` counts one (`script.cpp:71–74`) … -/
theorem sigOpCountPreGenesis_checksig (rest : Bytes) :
    sigOpCountPreGenesis (Op.OP_CHECKSIG :: rest) = 1 + sigOpCountPreGenesis rest := by
  rw [sigOpCountPreGenesis]
  simp [getOpTail_nonpush _ _ (by decide : Op.OP_PUSHDATA4 < Op.OP_CHECKSIG),
    (by decide : Op.OP_CHECKSIG ≠ Op.OP_INVALIDOPCODE)]

/-- … as does `OP_CHECKSIGVERIFY` (`script.cpp:71–74`) … -/
theorem sigOpCountPreGenesis_checksigverify (rest : Bytes) :
    sigOpCountPreGenesis (Op.OP_CHECKSIGVERIFY :: rest) = 1 + sigOpCountPreGenesis rest := by
  rw [sigOpCountPreGenesis]
  simp [getOpTail_nonpush _ _ (by decide : Op.OP_PUSHDATA4 < Op.OP_CHECKSIGVERIFY),
    (by decide : Op.OP_CHECKSIGVERIFY ≠ Op.OP_INVALIDOPCODE)]

/-- … `OP_CHECKMULTISIG` counts `MAX_PUBKEYS_PER_MULTISIG_BEFORE_GENESIS` = 20 (`script.cpp:119–122`, `consensus.h:50`;
the inaccurate count, whatever the key count pushed) … -/
theorem sigOpCountPreGenesis_checkmultisig (rest : Bytes) :
    sigOpCountPreGenesis (Op.OP_CHECKMULTISIG :: rest) = MAX_PUBKEYS_PER_MULTISIG_BEFORE_GENESIS + sigOpCountPreGenesis rest := by
  rw [sigOpCountPreGenesis]
  simp [getOpTail_nonpush _ _ (by decide : Op.OP_PUSHDATA4 < Op.OP_CHECKMULTISIG),
    (by decide : Op.OP_CHECKMULTISIG ≠ Op.OP_INVALIDOPCODE),
    (by decide : Op.OP_CHECKMULTISIG ≠ Op.OP_CHECKSIG), (by decide : Op.OP_CHECKMULTISIG ≠ Op.OP_CHECKSIGVERIFY)]

/-- … as does `OP_CHECKMULTISIGVERIFY` (`script.cpp:119–122`) … -/
theorem sigOpCountPreGenesis_checkmultisigverify (rest : Bytes) :
    sigOpCountPreGenesis (Op.OP_CHECKMULTISIGVERIFY :: rest) = MAX_PUBKEYS_PER_MULTISIG_BEFORE_GENESIS + sigOpCountPreGenesis rest := by
  rw [sigOpCountPreGenesis]
  simp [getOpTail_nonpush _ _ (by decide : Op.OP_PUSHDATA4 < Op.OP_CHECKMULTISIGVERIFY),
    (by decide : Op.OP_CHECKMULTISIGVERIFY ≠ Op.OP_INVALIDOPCODE),
    (by decide : Op.OP_CHECKMULTISIGVERIFY ≠ Op.OP_CHECKSIG), (by decide : Op.OP_CHECKMULTISIGVERIFY ≠ Op.OP_CHECKSIGVERIFY),
    (by decide : Op.OP_CHECKMULTISIGVERIFY ≠ Op.OP_CHECKMULTISIG)]

/-- … the walk stops at a push that fails to decode with the count so far (`script.cpp:44–45`: it decodes as
`OP_INVALIDOPCODE`, `instruction_iterator.h:31–72`) … -/
theorem sigOpCountPreGenesis_truncated (op : Nat) (rest : Bytes) (h : getOpTail op rest = none) :
    sigOpCountPreGenesis (op :: rest) = 0 := by
  rw [sigOpCountPreGenesis]; simp [h]

/-- … and at a literal `0xff`, whatever follows (`script.cpp:44–45`: `decode_instruction` returns the byte as a valid
instruction whose opcode is `OP_INVALIDOPCODE`, `instruction_iterator.h:26–27`) … -/
theorem sigOpCountPreGenesis_invalidop (rest : Bytes) :
    sigOpCountPreGenesis (Op.OP_INVALIDOPCODE :: rest) = 0 := by
  rw [sigOpCountPreGenesis]; simp [getOpTail_nonpush _ _ (by decide : Op.OP_PUSHDATA4 < Op.OP_INVALIDOPCODE)]

/-- … and every other instruction counts nothing (`script.cpp:30–128`: no other case in the pre-Genesis branch).
The per-transaction limit against the total is `MAX_TX_SIGOPS_COUNT_BEFORE_GENESIS` = 20,000 ("Allowed number of
signature check operations per transaction before Genesis", `consensus.h:46–47`) at `checkTransactionCommon`'s
`validation.cpp:559–566`; the block's own limit is `MAX_BLOCK_SIGOPS_PER_MB_BEFORE_GENESIS` (`consensus.h:33–37`,
applied at `validation.cpp:3362–3366` and `validation.cpp:5841–5864`, block-level rules outside this module). -/
theorem sigOpCountPreGenesis_other (op : Nat) (rest data : Bytes) (k : Nat) (h : getOpTail op rest = some (data, k))
    (h1 : op ≠ Op.OP_CHECKSIG) (h2 : op ≠ Op.OP_CHECKSIGVERIFY) (h3 : op ≠ Op.OP_CHECKMULTISIG)
    (h4 : op ≠ Op.OP_CHECKMULTISIGVERIFY) (h5 : op ≠ Op.OP_INVALIDOPCODE) :
    sigOpCountPreGenesis (op :: rest) = sigOpCountPreGenesis (rest.drop k) := by
  rw [sigOpCountPreGenesis]; simp [h, h1, h2, h3, h4, h5]

/-- T-TX5: the coinbase rule is exclusive (`validation.cpp:600–602`): a coinbase fails `CheckRegularTransaction`
before any other check … -/
theorem checkRegularTransaction_coinbase (tx : Tx) (maxSigOps maxSize : Nat) (preGenesis : Bool)
    (h : isCoinBase tx = true) :
    checkRegularTransaction tx maxSigOps maxSize preGenesis = .error .coinbaseWhereRegular := by
  simp [checkRegularTransaction, h, bind, Except.bind]
  all_goals rfl

/-- … and a non-coinbase fails `CheckCoinbase` (`validation.cpp:571–592`, its first test) before any other;
with `isCoinBase_length` (T-TX3) a coinbase is the one-input transaction whose outpoint is null
(`transaction.h:68`, `:323–325`). -/
theorem checkCoinbase_not_coinbase (tx : Tx) (maxSigOps maxSize : Nat) (preGenesis : Bool)
    (h : isCoinBase tx = false) :
    checkCoinbase tx maxSigOps maxSize preGenesis = .error .coinbaseMissing := by
  simp [checkCoinbase, h, bind, Except.bind]
  all_goals rfl

/-- T-TX6: the first three checks of `CheckTransactionCommon` in their order (`validation.cpp:526–535`):
`bad-txns-vin-empty` … -/
theorem checkTransactionCommon_vinEmpty (tx : Tx) (maxSigOps maxSize : Nat) (preGenesis : Bool)
    (h : tx.inputs = []) :
    checkTransactionCommon tx maxSigOps maxSize preGenesis = .error .vinEmpty := by
  simp [checkTransactionCommon, h, bind, Except.bind]
  all_goals rfl

/-- … `bad-txns-vout-empty` (`529–532`) … -/
theorem checkTransactionCommon_voutEmpty (tx : Tx) (maxSigOps maxSize : Nat) (preGenesis : Bool)
    (h1 : tx.inputs ≠ []) (h2 : tx.outputs = []) :
    checkTransactionCommon tx maxSigOps maxSize preGenesis = .error .voutEmpty := by
  simp [checkTransactionCommon, h1, h2, bind, Except.bind]
  all_goals rfl

/-- … and `bad-txns-oversize` against the serialized size (`534–536`; `Sighash.serTx`, the size the reference
measures). -/
theorem checkTransactionCommon_oversize (tx : Tx) (maxSigOps maxSize : Nat) (preGenesis : Bool)
    (h1 : tx.inputs ≠ []) (h2 : tx.outputs ≠ []) (h3 : maxSize < (Sighash.serTx tx).length) :
    checkTransactionCommon tx maxSigOps maxSize preGenesis = .error .oversize := by
  simp [checkTransactionCommon, h1, h2, h3, bind, Except.bind]
  all_goals rfl

/-- T-TX7: the coinbase script's length (`validation.cpp:587–589`): 2 to 100 bytes (`MAX_COINBASE_SCRIPTSIG_SIZE`,
`consensus.h:69`), given the common checks pass. -/
theorem checkCoinbase_length (tx : Tx) (maxSigOps maxSize : Nat) (preGenesis : Bool)
    (h : isCoinBase tx = true) (hc : checkTransactionCommon tx maxSigOps maxSize preGenesis = .ok ())
    (hl : (tx.inputs.head?.map (·.scriptSig.length)).getD 0 < 2
          ∨ MAX_COINBASE_SCRIPTSIG_SIZE < (tx.inputs.head?.map (·.scriptSig.length)).getD 0) :
    checkCoinbase tx maxSigOps maxSize preGenesis = .error .coinbaseLength := by
  simp [checkCoinbase, h, hc, bind, Except.bind]
  split_ifs with hif
  · rfl
  · exfalso; omega

/-! ## The loops of `CheckTransactionCommon` and `CheckRegularTransaction` (archived #25, the Lean families, 2026-09-27)

The definitions above write the reference's two `for` loops as do-blocks. A theorem about a do-block's `forIn` is
stated over a recursion that decides as the loop's body does (`forIn_eq_checkOutputs`, `forIn_eq_checkInputs`, each
quantified over the body with its tests as the hypothesis), and each definition is proven equal to the nested
conditional it denotes (`checkTransactionCommon_eq`, `checkRegularTransaction_eq`); the value checks (T-TX8), the
sigop count (T-TX9) and the outpoint checks (T-TX10) read off those. -/

/-- The output loop of `CheckTransactionCommon` (`542–558`) as a recursion on the outputs with the running total: a
value at or above `2⁶³` is a negative `int64` (`543–546`, `bad-txns-vout-negative`), one above `MAX_MONEY`
(`548–551`, `bad-txns-vout-toolarge`), then the total is added and tested by `MoneyRange` (`553–557`,
`bad-txns-txouttotal-toolarge`). -/
def checkOutputs : List TxOut → Nat → Except TxReject Nat
  | [], total => .ok total
  | o :: os, total =>
    if 2 ^ 63 ≤ o.value then .error .voutNegative
    else if MAX_MONEY < o.value then .error .voutTooLarge
    else if !moneyRange (total + o.value) then .error .txoutTotalTooLarge
    else checkOutputs os (total + o.value)

/-- The do-block's loop is the recursion, for any body that decides as the three tests do: the bridge from
`checkTransactionCommon`'s syntax to its theorems. -/
theorem forIn_eq_checkOutputs (os : List TxOut) (total : Nat) (body : TxOut → Nat → Except TxReject (ForInStep Nat))
    (hb : ∀ o s, body o s =
      if 2 ^ 63 ≤ o.value then .error .voutNegative
      else if MAX_MONEY < o.value then .error .voutTooLarge
      else if !moneyRange (s + o.value) then .error .txoutTotalTooLarge
      else .ok (ForInStep.yield (s + o.value))) :
    forIn os total body = checkOutputs os total := by
  induction os generalizing total with
  | nil => rfl
  | cons o os ih =>
    rw [List.forIn_cons, hb]
    unfold checkOutputs
    split_ifs <;> simp [bind, Except.bind, ih]

/-- **`CheckTransactionCommon` as a case analysis** (`527–569`): the do-block equals the nested conditional with the
loop as `checkOutputs`; the theorems below read off it. -/
theorem checkTransactionCommon_eq (tx : Tx) (maxSigOps maxSize : Nat) (preGenesis : Bool) :
    checkTransactionCommon tx maxSigOps maxSize preGenesis =
      (if tx.inputs.isEmpty then .error .vinEmpty
       else if tx.outputs.isEmpty then .error .voutEmpty
       else if maxSize < (Sighash.serTx tx).length then .error .oversize
       else match checkOutputs tx.outputs 0 with
         | .error e => .error e
         | .ok _ => if preGenesis && maxSigOps < sigOpCountWithoutP2SH tx then .error .sigops else .ok ()) := by
  unfold checkTransactionCommon
  try dsimp only
  by_cases h1 : tx.inputs.isEmpty = true
  · rw [ite_eq_left h1, ite_eq_left h1]; rfl
  rw [ite_eq_right h1, ite_eq_right h1]
  by_cases h2 : tx.outputs.isEmpty = true
  · rw [ite_eq_left h2, ite_eq_left h2]; rfl
  rw [ite_eq_right h2, ite_eq_right h2]
  by_cases h3 : maxSize < (Sighash.serTx tx).length
  · rw [ite_eq_left h3, ite_eq_left h3]; rfl
  rw [ite_eq_right h3, ite_eq_right h3]
  rw [forIn_eq_checkOutputs tx.outputs 0]
  · cases checkOutputs tx.outputs 0 with
    | error e => rfl
    | ok t => rfl
  · intro o s
    try dsimp only
    split_ifs <;> rfl

/-- The loop accepts iff the sum of the values stays within `MAX_MONEY` (the total is monotone, so `554` at the last
output is the binding test, and every single value is then in range too), and it returns that sum. -/
theorem checkOutputs_ok_iff (os : List TxOut) (total t : Nat) (htot : total ≤ MAX_MONEY) :
    checkOutputs os total = .ok t ↔ total + (os.map (·.value)).sum ≤ MAX_MONEY ∧ t = total + (os.map (·.value)).sum := by
  induction os generalizing total with
  | nil =>
    simp only [checkOutputs, List.map_nil, List.sum_nil, Nat.add_zero, Except.ok.injEq]
    constructor
    · intro h; exact ⟨htot, h.symm⟩
    · intro h; exact h.2.symm
  | cons o os ih =>
    simp only [checkOutputs, List.map_cons, List.sum_cons]
    by_cases h1 : 2 ^ 63 ≤ o.value
    · rw [ite_eq_left h1]
      exact iff_of_false (by simp) (by simp only [MAX_MONEY, Nat.reducePow] at *; omega)
    rw [ite_eq_right h1]
    by_cases h2 : MAX_MONEY < o.value
    · rw [ite_eq_left h2]
      exact iff_of_false (by simp) (by simp only [MAX_MONEY, Nat.reducePow] at *; omega)
    rw [ite_eq_right h2]
    by_cases h3 : (!moneyRange (total + o.value)) = true
    · rw [ite_eq_left h3]
      simp only [moneyRange, Bool.not_eq_true', decide_eq_false_iff_not, Nat.not_le] at h3
      exact iff_of_false (by simp) (by simp only [MAX_MONEY] at *; omega)
    rw [ite_eq_right h3]
    simp only [moneyRange, Bool.not_eq_true', decide_eq_false_iff_not, Nat.not_le, Nat.not_lt] at h3
    rw [ih (total + o.value) h3]
    constructor
    · rintro ⟨a, b⟩; exact ⟨by omega, by omega⟩
    · rintro ⟨a, b⟩; exact ⟨by omega, by omega⟩

/-- A prefix that passes carries its sum into the rest (`542`: the outputs in order; `553`: the total accumulates). -/
theorem checkOutputs_append (pre os : List TxOut) (total : Nat) (h : total + (pre.map (·.value)).sum ≤ MAX_MONEY) :
    checkOutputs (pre ++ os) total = checkOutputs os (total + (pre.map (·.value)).sum) := by
  induction pre generalizing total with
  | nil => simp
  | cons p pre ih =>
    simp only [List.cons_append, checkOutputs, List.map_cons, List.sum_cons] at h ⊢
    have hp : p.value ≤ MAX_MONEY := by omega
    have h1 : ¬ 2 ^ 63 ≤ p.value := by simp only [MAX_MONEY, Nat.reducePow] at *; omega
    have h2 : ¬ MAX_MONEY < p.value := by omega
    have h3 : ¬ ((!moneyRange (total + p.value)) = true) := by
      simp only [moneyRange, Bool.not_eq_true', decide_eq_false_iff_not, Nat.not_le, Nat.not_lt]; omega
    rw [ite_eq_right h1, ite_eq_right h2, ite_eq_right h3]
    rw [ih (total + p.value) (by omega), Nat.add_assoc]

/-- The first output failing a test names the rejection, in the tests' order: a negative value (`543–546`) … -/
theorem checkOutputs_voutNegative (pre post : List TxOut) (o : TxOut)
    (hpre : (pre.map (·.value)).sum ≤ MAX_MONEY) (ho : 2 ^ 63 ≤ o.value) :
    checkOutputs (pre ++ o :: post) 0 = .error .voutNegative := by
  rw [checkOutputs_append pre _ 0 (by simpa using hpre)]
  unfold checkOutputs
  rw [ite_eq_left ho]

/-- … a value above `MAX_MONEY` (`548–551`) … -/
theorem checkOutputs_voutTooLarge (pre post : List TxOut) (o : TxOut)
    (hpre : (pre.map (·.value)).sum ≤ MAX_MONEY) (ho1 : o.value < 2 ^ 63) (ho2 : MAX_MONEY < o.value) :
    checkOutputs (pre ++ o :: post) 0 = .error .voutTooLarge := by
  rw [checkOutputs_append pre _ 0 (by simpa using hpre)]
  unfold checkOutputs
  rw [ite_eq_right (Nat.not_le.2 ho1), ite_eq_left ho2]

/-- … a total above `MAX_MONEY` (`553–557`). -/
theorem checkOutputs_txoutTotalTooLarge (pre post : List TxOut) (o : TxOut)
    (hpre : (pre.map (·.value)).sum ≤ MAX_MONEY) (ho : o.value ≤ MAX_MONEY)
    (hsum : MAX_MONEY < (pre.map (·.value)).sum + o.value) :
    checkOutputs (pre ++ o :: post) 0 = .error .txoutTotalTooLarge := by
  rw [checkOutputs_append pre _ 0 (by simpa using hpre)]
  unfold checkOutputs
  have h1 : ¬ 2 ^ 63 ≤ o.value := by simp only [MAX_MONEY, Nat.reducePow] at *; omega
  have h2 : ¬ MAX_MONEY < o.value := by omega
  have h3 : (!moneyRange (0 + (pre.map (·.value)).sum + o.value)) = true := by
    simp only [moneyRange, Bool.not_eq_true', decide_eq_false_iff_not, Nat.not_le]; omega
  rw [ite_eq_right h1, ite_eq_right h2, ite_eq_left h3]

/-- T-TX8: **the value checks through the loop** (`540–558`): with T-TX6's three checks passing, the first output
that fails a test names the rejection: `bad-txns-vout-negative` for a serialized value at or above `2⁶³`
(`543–546`) … -/
theorem checkTransactionCommon_voutNegative (tx : Tx) (maxSigOps maxSize : Nat) (preGenesis : Bool)
    (pre post : List TxOut) (o : TxOut)
    (h1 : tx.inputs ≠ []) (h3 : (Sighash.serTx tx).length ≤ maxSize)
    (hout : tx.outputs = pre ++ o :: post) (hpre : (pre.map (·.value)).sum ≤ MAX_MONEY) (ho : 2 ^ 63 ≤ o.value) :
    checkTransactionCommon tx maxSigOps maxSize preGenesis = .error .voutNegative := by
  rw [checkTransactionCommon_eq]
  simp [h1, Nat.not_lt.2 h3, hout, checkOutputs_voutNegative pre post o hpre ho]

/-- … `bad-txns-vout-toolarge` above `MAX_MONEY` (`548–551`; `amount.h:130`) … -/
theorem checkTransactionCommon_voutTooLarge (tx : Tx) (maxSigOps maxSize : Nat) (preGenesis : Bool)
    (pre post : List TxOut) (o : TxOut)
    (h1 : tx.inputs ≠ []) (h3 : (Sighash.serTx tx).length ≤ maxSize)
    (hout : tx.outputs = pre ++ o :: post) (hpre : (pre.map (·.value)).sum ≤ MAX_MONEY)
    (ho1 : o.value < 2 ^ 63) (ho2 : MAX_MONEY < o.value) :
    checkTransactionCommon tx maxSigOps maxSize preGenesis = .error .voutTooLarge := by
  rw [checkTransactionCommon_eq]
  simp [h1, Nat.not_lt.2 h3, hout, checkOutputs_voutTooLarge pre post o hpre ho1 ho2]

/-- … `bad-txns-txouttotal-toolarge` when the running total leaves `MoneyRange` (`553–557`). -/
theorem checkTransactionCommon_txoutTotalTooLarge (tx : Tx) (maxSigOps maxSize : Nat) (preGenesis : Bool)
    (pre post : List TxOut) (o : TxOut)
    (h1 : tx.inputs ≠ []) (h3 : (Sighash.serTx tx).length ≤ maxSize)
    (hout : tx.outputs = pre ++ o :: post) (hpre : (pre.map (·.value)).sum ≤ MAX_MONEY)
    (ho : o.value ≤ MAX_MONEY) (hsum : MAX_MONEY < (pre.map (·.value)).sum + o.value) :
    checkTransactionCommon tx maxSigOps maxSize preGenesis = .error .txoutTotalTooLarge := by
  rw [checkTransactionCommon_eq]
  simp [h1, Nat.not_lt.2 h3, hout, checkOutputs_txoutTotalTooLarge pre post o hpre ho hsum]

/-- T-TX9: **the pre-Genesis sigop count at the transaction level** (`560–567`; `consensus.h:47`): with every check
before passing, a pre-Genesis transaction whose count (`sigOpCountWithoutP2SH`, T-TX4) exceeds the limit is
`bad-txn-sigops`; after Genesis the count is not taken (`560–561`: "sigops are unlimited"). -/
theorem checkTransactionCommon_sigops (tx : Tx) (maxSigOps maxSize : Nat) (preGenesis : Bool)
    (h1 : tx.inputs ≠ []) (h2 : tx.outputs ≠ []) (h3 : (Sighash.serTx tx).length ≤ maxSize)
    (hval : (tx.outputs.map (·.value)).sum ≤ MAX_MONEY) (hpg : preGenesis = true)
    (hsig : maxSigOps < sigOpCountWithoutP2SH tx) :
    checkTransactionCommon tx maxSigOps maxSize preGenesis = .error .sigops := by
  rw [checkTransactionCommon_eq]
  have hok : checkOutputs tx.outputs 0 = .ok (tx.outputs.map (·.value)).sum :=
    (checkOutputs_ok_iff tx.outputs 0 _ (by simp [MAX_MONEY])).2 ⟨by simpa using hval, by simp⟩
  simp [h1, h2, Nat.not_lt.2 h3, hok, hpg, hsig]

/-- **The common checks pass iff** the inputs and the outputs are non-empty, the serialized size is within the limit,
the values sum within `MAX_MONEY` and, pre-Genesis, the sigop count is within its limit (`527–569`). -/
theorem checkTransactionCommon_ok_iff (tx : Tx) (maxSigOps maxSize : Nat) (preGenesis : Bool) :
    checkTransactionCommon tx maxSigOps maxSize preGenesis = .ok () ↔
      tx.inputs ≠ [] ∧ tx.outputs ≠ [] ∧ (Sighash.serTx tx).length ≤ maxSize
      ∧ (tx.outputs.map (·.value)).sum ≤ MAX_MONEY
      ∧ ¬ (preGenesis = true ∧ maxSigOps < sigOpCountWithoutP2SH tx) := by
  rw [checkTransactionCommon_eq]
  by_cases h1 : tx.inputs = []
  · simp [h1]
  by_cases h2 : tx.outputs = []
  · simp [h1, h2]
  by_cases h3 : maxSize < (Sighash.serTx tx).length
  · simp [h1, h2, h3]
  simp only [List.isEmpty_iff, h1, h2, h3, ite_false]
  cases hco : checkOutputs tx.outputs 0 with
  | error e =>
    have : ¬ (tx.outputs.map (·.value)).sum ≤ MAX_MONEY := by
      intro hle
      have := (checkOutputs_ok_iff tx.outputs 0 ((tx.outputs.map (·.value)).sum) (by simp [MAX_MONEY])).2
        ⟨by simpa using hle, by simp⟩
      rw [hco] at this; cases this
    simp [this]
  | ok t =>
    have hle : (tx.outputs.map (·.value)).sum ≤ MAX_MONEY := by
      have := (checkOutputs_ok_iff tx.outputs 0 t (by simp [MAX_MONEY])).1 hco
      simpa using this.1
    have h3' : (Sighash.serTx tx).length ≤ maxSize := Nat.not_lt.1 h3
    cases preGenesis <;> simp [h1, h2, h3', hle]

/-- The input loop of `CheckRegularTransaction` (`625–637`) as a recursion with the outpoints seen so far
(`inOutPoints`): a null outpoint (`628–631`, `bad-txns-prevout-null`), then a repeated one (`633–636`,
`bad-txns-inputs-duplicate`). -/
def checkInputs : List TxIn → List (Bytes × Nat) → Except TxReject Unit
  | [], _ => .ok ()
  | i :: is, seen =>
    if outPointIsNull i then .error .prevoutNull
    else if seen.contains (i.prevHash, i.prevIndex) then .error .inputsDuplicate
    else checkInputs is ((i.prevHash, i.prevIndex) :: seen)

/-- The do-block's loop, then `pure ()`, is the recursion, for any body that decides as the two tests do. -/
theorem forIn_eq_checkInputs (is : List TxIn) (seen : List (Bytes × Nat))
    (body : TxIn → List (Bytes × Nat) → Except TxReject (ForInStep (List (Bytes × Nat))))
    (hb : ∀ i s, body i s =
      if outPointIsNull i then .error .prevoutNull
      else if s.contains (i.prevHash, i.prevIndex) then .error .inputsDuplicate
      else .ok (ForInStep.yield ((i.prevHash, i.prevIndex) :: s))) :
    (do let _ ← forIn is seen body; pure () : Except TxReject Unit) = checkInputs is seen := by
  induction is generalizing seen with
  | nil => rfl
  | cons i is ih =>
    rw [List.forIn_cons, hb]
    unfold checkInputs
    split_ifs <;> first | rfl | (simp only [bind, Except.bind]; exact ih _)

/-- **`CheckRegularTransaction` as a case analysis** (`595–640`): not a coinbase (`601–603`), the common checks
(`605–608`), post-Genesis no P2SH output (`611–622`), then the loop as `checkInputs`. -/
theorem checkRegularTransaction_eq (tx : Tx) (maxSigOps maxSize : Nat) (preGenesis : Bool) :
    checkRegularTransaction tx maxSigOps maxSize preGenesis =
      (if isCoinBase tx then .error .coinbaseWhereRegular
       else match checkTransactionCommon tx maxSigOps maxSize preGenesis with
         | .error e => .error e
         | .ok () =>
           if !preGenesis && tx.outputs.any (fun o => isP2SH o.scriptPubKey) then .error .p2shOutput
           else checkInputs tx.inputs []) := by
  unfold checkRegularTransaction
  try dsimp only
  by_cases h1 : isCoinBase tx = true
  · rw [ite_eq_left h1, ite_eq_left h1]; rfl
  rw [ite_eq_right h1, ite_eq_right h1]
  cases checkTransactionCommon tx maxSigOps maxSize preGenesis with
  | error e => rfl
  | ok u =>
    cases u
    show (if _ then _ else _) = _
    by_cases h2 : (!preGenesis && tx.outputs.any (fun o => isP2SH o.scriptPubKey)) = true
    · rw [ite_eq_left h2, ite_eq_left h2]; rfl
    rw [ite_eq_right h2, ite_eq_right h2]
    rw [← forIn_eq_checkInputs tx.inputs []]
    intro i s
    try dsimp only
    split_ifs <;> rfl

/-- The loop accepts iff no outpoint is null, no outpoint repeats, and none was seen before. -/
theorem checkInputs_ok_iff (is : List TxIn) (seen : List (Bytes × Nat)) :
    checkInputs is seen = .ok () ↔
      (∀ i ∈ is, outPointIsNull i = false)
      ∧ (is.map (fun i => (i.prevHash, i.prevIndex))).Nodup
      ∧ ∀ i ∈ is, (i.prevHash, i.prevIndex) ∉ seen := by
  induction is generalizing seen with
  | nil => simp [checkInputs]
  | cons i is ih =>
    simp only [checkInputs]
    split_ifs with h1 h2
    · simp [h1]
    · simp at h2
      simp [h2]
    · rw [ih]
      simp at h1 h2
      simp only [List.mem_cons, forall_eq_or_imp, h1, true_and, List.map_cons, List.nodup_cons, List.mem_map,
        not_exists, not_and, h2, not_false_eq_true]
      constructor
      · rintro ⟨a, b, c⟩
        refine ⟨a, ⟨?_, b⟩, ?_⟩
        · intro j hj hje
          exact (c j hj) (by simp [hje])
        · intro j hj
          exact fun hm => (c j hj) (by simp [hm])
      · rintro ⟨a, ⟨b, c⟩, d⟩
        refine ⟨a, c, ?_⟩
        intro j hj
        simp only [not_or]
        exact ⟨fun h => b j hj h, d j hj⟩

/-- A prefix that passes carries its outpoints into the seen set, in the loop's order (`627`, `633`: the set
`inOutPoints` grows by one outpoint per input). -/
theorem checkInputs_append (pre is : List TxIn) (seen : List (Bytes × Nat))
    (hpre : ∀ j ∈ pre, outPointIsNull j = false)
    (hnd : (pre.map (fun i => (i.prevHash, i.prevIndex))).Nodup)
    (hdisj : ∀ j ∈ pre, (j.prevHash, j.prevIndex) ∉ seen) :
    checkInputs (pre ++ is) seen
      = checkInputs is ((pre.map (fun i => (i.prevHash, i.prevIndex))).reverse ++ seen) := by
  induction pre generalizing seen with
  | nil => simp
  | cons p pre ih =>
    simp only [List.cons_append, checkInputs]
    have h1 : outPointIsNull p = false := hpre p (by simp)
    have h2 : seen.contains (p.prevHash, p.prevIndex) = false := by
      have := hdisj p (by simp)
      simpa using this
    simp only [h1, h2, Bool.false_eq_true, ite_false]
    simp only [List.map_cons, List.nodup_cons, List.mem_map] at hnd
    rw [ih ((p.prevHash, p.prevIndex) :: seen) (fun j hj => hpre j (by simp [hj])) hnd.2]
    · simp
    · intro j hj
      simp only [List.mem_cons, not_or]
      exact ⟨fun h => hnd.1 ⟨j, hj, h⟩, hdisj j (by simp [hj])⟩

/-- T-TX10: **the outpoint checks through the loop** (`627–637`): with the checks before passing, the first input
whose outpoint is null is `bad-txns-prevout-null` (`628–631`) … -/
theorem checkRegularTransaction_prevoutNull (tx : Tx) (maxSigOps maxSize : Nat) (preGenesis : Bool)
    (pre post : List TxIn) (i : TxIn)
    (hcb : isCoinBase tx = false) (hc : checkTransactionCommon tx maxSigOps maxSize preGenesis = .ok ())
    (hp2sh : (!preGenesis && tx.outputs.any (fun o => isP2SH o.scriptPubKey)) = false)
    (hin : tx.inputs = pre ++ i :: post) (hpre : ∀ j ∈ pre, outPointIsNull j = false)
    (hnd : (pre.map (fun i => (i.prevHash, i.prevIndex))).Nodup) (hi : outPointIsNull i = true) :
    checkRegularTransaction tx maxSigOps maxSize preGenesis = .error .prevoutNull := by
  rw [checkRegularTransaction_eq]
  simp only [hcb, hc, hp2sh, Bool.false_eq_true, ite_false, hin]
  rw [checkInputs_append pre _ [] hpre hnd (by simp)]
  simp [checkInputs, hi]

/-- … and the first input repeating an earlier outpoint is `bad-txns-inputs-duplicate` (`633–636`). -/
theorem checkRegularTransaction_inputsDuplicate (tx : Tx) (maxSigOps maxSize : Nat) (preGenesis : Bool)
    (pre post : List TxIn) (i : TxIn)
    (hcb : isCoinBase tx = false) (hc : checkTransactionCommon tx maxSigOps maxSize preGenesis = .ok ())
    (hp2sh : (!preGenesis && tx.outputs.any (fun o => isP2SH o.scriptPubKey)) = false)
    (hin : tx.inputs = pre ++ i :: post) (hpre : ∀ j ∈ pre, outPointIsNull j = false)
    (hnd : (pre.map (fun i => (i.prevHash, i.prevIndex))).Nodup) (hi : outPointIsNull i = false)
    (hdup : ∃ j ∈ pre, (j.prevHash, j.prevIndex) = (i.prevHash, i.prevIndex)) :
    checkRegularTransaction tx maxSigOps maxSize preGenesis = .error .inputsDuplicate := by
  rw [checkRegularTransaction_eq]
  simp only [hcb, hc, hp2sh, Bool.false_eq_true, ite_false, hin]
  rw [checkInputs_append pre _ [] hpre hnd (by simp)]
  have hmem : (i.prevHash, i.prevIndex) ∈ (pre.map (fun j : TxIn => (j.prevHash, j.prevIndex))).reverse ++ [] := by
    obtain ⟨j, hj, hje⟩ := hdup
    simp only [List.append_nil, List.mem_reverse, List.mem_map]
    exact ⟨j, hj, hje⟩
  have hcont : ((pre.map (fun j : TxIn => (j.prevHash, j.prevIndex))).reverse ++ []).contains (i.prevHash, i.prevIndex) = true := by
    simpa using hmem
  unfold checkInputs
  rw [ite_eq_right (by simp [hi]), ite_eq_left hcont]

/-- **`CheckRegularTransaction` passes iff** not a coinbase, the common checks pass, no P2SH output after Genesis,
no null outpoint and no repeated outpoint (`595–640`). -/
theorem checkRegularTransaction_ok_iff (tx : Tx) (maxSigOps maxSize : Nat) (preGenesis : Bool) :
    checkRegularTransaction tx maxSigOps maxSize preGenesis = .ok () ↔
      isCoinBase tx = false ∧ checkTransactionCommon tx maxSigOps maxSize preGenesis = .ok ()
      ∧ (!preGenesis && tx.outputs.any (fun o => isP2SH o.scriptPubKey)) = false
      ∧ (∀ i ∈ tx.inputs, outPointIsNull i = false)
      ∧ (tx.inputs.map (fun i => (i.prevHash, i.prevIndex))).Nodup := by
  rw [checkRegularTransaction_eq]
  by_cases hcb : isCoinBase tx = true
  · simp [hcb]
  have hcb' : isCoinBase tx = false := Bool.eq_false_iff.mpr hcb
  simp only [hcb', Bool.false_eq_true, ite_false, true_and]
  cases hc : checkTransactionCommon tx maxSigOps maxSize preGenesis with
  | error e => simp
  | ok u =>
    cases u
    simp only [true_and]
    by_cases hp : (!preGenesis && tx.outputs.any (fun o => isP2SH o.scriptPubKey)) = true
    · simp [hp]
    have hp' := Bool.eq_false_iff.mpr hp
    simp only [hp', Bool.false_eq_true, ite_false, true_and]
    rw [checkInputs_ok_iff]
    simp


/-! ## The pre-Genesis count is the node's on every script (2026-09-27; the Lean semantics' ask 5)

`SigOps.sigOpCount` (the Lean semantics') models `CScript::GetSigOpCount` on every path; `TxPolicy.sigOpCount_legacy_eq`
tied it to `sigOpCountPreGenesis` on the scripts without a literal `0xff`, where the two parted until the walk
above stopped at that byte. T-TX11 drops the hypothesis. -/

/-- The legacy walk of `SigOps` is `sigOpCountPreGenesis` on every script, generalized over the walk's state
(the induction behind T-TX11): before Genesis without `fAccurate` no scope is tracked and a multisig counts 20
(`script.cpp:47`, `script.cpp:119–122`); a push that fails to decode and a literal `0xff` end both walks (`script.cpp:44–45`). -/
theorem sigOpWalk_legacy_eq_all : ∀ (fuel : Nat) (s : Bytes) (lo : Nat) (ld : Bytes) (n : Nat),
    s.length ≤ fuel → SigOps.sigOpWalk false false fuel s lo ld 0 n = some (n + sigOpCountPreGenesis s) := by
  intro fuel
  induction fuel with
  | zero =>
    intro s lo ld n hl
    have : s = [] := List.eq_nil_of_length_eq_zero (by omega)
    subst this
    simp [SigOps.sigOpWalk, sigOpCountPreGenesis_nil]
  | succ f ih =>
    intro s lo ld n hl
    cases s with
    | nil => simp [SigOps.sigOpWalk, sigOpCountPreGenesis_nil]
    | cons op rest =>
      rw [sigOpCountPreGenesis]
      simp only [SigOps.sigOpWalk]
      cases hgt : getOpTail op rest with
      | none => simp
      | some dk =>
        obtain ⟨data, k⟩ := dk
        by_cases hff : op = Op.OP_INVALIDOPCODE
        · simp [hff]
        · have hsc : SigOps.scopeAfter false op 0 = 0 := by simp [SigOps.scopeAfter]
          have hlen : (rest.drop k).length ≤ f := by
            simp only [List.length_drop, List.length_cons] at hl ⊢; omega
          have hadd : SigOps.opSigOps false false op lo ld =
              some (if op = Op.OP_CHECKSIG || op = Op.OP_CHECKSIGVERIFY then 1
                else if op = Op.OP_CHECKMULTISIG || op = Op.OP_CHECKMULTISIGVERIFY then
                  MAX_PUBKEYS_PER_MULTISIG_BEFORE_GENESIS else 0) := by
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
          rw [ih _ _ _ _ hlen]
          simp only [Option.some.injEq]
          omega

/-- **T-TX11 (the pre-Genesis count is the node's, on every script).** *What it says:* before Genesis without
`fAccurate`, `CScript::GetSigOpCount` as `SigOps.sigOpCount` models it (`script.cpp:30–128`) is
`sigOpCountPreGenesis` on every script, a literal `0xff` included. *What it assumes:* nothing. *Why it
matters:* the consensus gate's count (`validation.cpp:437–459` at `validation.cpp:559–566`) is the node's, so the gate
refuses exactly the transactions `CheckTransactionCommon` refuses for their sigops. The node's other pre-Genesis
sigop refusals are not this gate's: `ConnectBlock`'s count with the P2SH part (`validation.cpp:3351–3360`,
`bad-txn-sigops`), the block totals (`validation.cpp:3362–3366`, `validation.cpp:5849–5864`, `bad-blk-sigops`) and the mempool's policy cap
(`validation.cpp:1235–1247`). `TxPolicy.sigOpCount_legacy_eq` needed the script free of `0xff`. -/
theorem sigOpCountPreGenesis_eq_sigOpCount (s : Bytes) :
    SigOps.sigOpCount false false s = some (sigOpCountPreGenesis s) := by
  have := sigOpWalk_legacy_eq_all s.length s Op.OP_INVALIDOPCODE [] 0 (Nat.le_refl _)
  simpa [SigOps.sigOpCount] using this

/-- `n` `OP_CHECKSIG`s in a row count `n` before Genesis (`script.cpp:71–74`), whatever follows them. -/
theorem sigOpCountPreGenesis_replicate_checksig (n : Nat) (rest : Bytes) :
    sigOpCountPreGenesis (List.replicate n Op.OP_CHECKSIG ++ rest) = n + sigOpCountPreGenesis rest := by
  induction n with
  | zero => simp
  | succ n ih => rw [List.replicate_succ, List.cons_append, sigOpCountPreGenesis_checksig, ih]; omega

/-- The witness of a literal `0xff` before the checks: one input (a synthetic outpoint, an empty unlocking
script) and one output of 0 satoshis paying `0xff` then 20,001 `OP_CHECKSIG`, 20,002 bytes of locking
script. -/
def ffWitnessTx : Tx :=
  { version := 2
    inputs := [{ prevHash := List.replicate 32 1, prevIndex := 0, scriptSig := [], sequence := 0xffffffff }]
    outputs := [{ value := 0, scriptPubKey := Op.OP_INVALIDOPCODE :: List.replicate 20001 Op.OP_CHECKSIG }]
    lockTime := 0 }

/-- **T-TX12 (the `0xff` witness).** *What it says:* the witness transaction counts 0 sigops before Genesis,
so it passes the consensus gate's test against `MAX_TX_SIGOPS_COUNT_BEFORE_GENESIS` = 20,000
(`validation.cpp:559–566`, `consensus.h:47`), while the same 20,001 `OP_CHECKSIG` without the `0xff` count
20,001, over it. *What it assumes:* nothing. *Why it matters:* the node stops at the `0xff`
(`script.cpp:44–45`), so a count that reads on past it refuses a transaction the node accepts: a pre-Genesis
consensus divergence, which the spec's count had until 2026-09-27. -/
theorem sigOpCountPreGenesis_ff_witness :
    sigOpCountWithoutP2SH ffWitnessTx = 0 ∧ ¬ (MAX_TX_SIGOPS_COUNT_BEFORE_GENESIS < sigOpCountWithoutP2SH ffWitnessTx)
      ∧ sigOpCountPreGenesis (List.replicate 20001 Op.OP_CHECKSIG) = 20001 := by
  have h0 : sigOpCountWithoutP2SH ffWitnessTx = 0 := by
    rw [sigOpCountWithoutP2SH]
    show [sigOpCountPreGenesis []].sum
        + [sigOpCountPreGenesis (Op.OP_INVALIDOPCODE :: List.replicate 20001 Op.OP_CHECKSIG)].sum = 0
    rw [sigOpCountPreGenesis_nil, sigOpCountPreGenesis_invalidop]; rfl
  have h1 := sigOpCountPreGenesis_replicate_checksig 20001 []
  rw [List.append_nil, sigOpCountPreGenesis_nil] at h1
  exact ⟨h0, by rw [h0]; decide, h1⟩

end BsvScript.TxRules
