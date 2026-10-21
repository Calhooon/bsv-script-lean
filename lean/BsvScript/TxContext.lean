import BsvScript.Machine
import BsvScript.Ops.Crypto
/-!
# BsvScript.TxContext

The transaction context of a spend (#22; `docs/DESIGN.md` §5.4 `Context`): what
the interpreter reads from the transaction. `TransactionSignatureChecker`
(`interpreter.cpp:2126–2256`) holds the transaction, the input index and the
amount; it answers `CheckSig` (`2133–2164`, `Ops.Crypto.txCheckSig`),
`CheckLockTime` (`2166–2202`), `CheckSequence` (`2204–2250`) and `Version`
(`2254–2257`). The lock-time constants: `LOCKTIME_THRESHOLD` (`script.h:36`),
`SEQUENCE_FINAL`, `SEQUENCE_LOCKTIME_DISABLE_FLAG`, `SEQUENCE_LOCKTIME_TYPE_FLAG`,
`SEQUENCE_LOCKTIME_MASK` (`transaction.h:99–119`).
[LIT] https://protocol.bsvblockchain.org/specification/transactions#bip68-relative-locktime-pre-genesis-only at v1.2.2 (the four sequence constants only).

**The scope boundary** (#22, #36): script reads the transaction's version, lock
time, the spent input's sequence and outpoint, every input's outpoint and
sequence and every output through the sighash (§4.3), and the amount of the
spent output through the sighash and `CheckSig`. The transaction's own validity
(`CheckRegularTransaction`, `validation.cpp:519–639`) and every block-level
rule are outside script (`BsvScript.TxRules` carries the transaction-level
checks the reference's vector runner applies; block-level consensus is #36).
-/

namespace BsvScript.TxContext
open BsvScript.Params BsvScript.Numbers BsvScript.Machine BsvScript.Tx

def LOCKTIME_THRESHOLD : Nat := 500000000            -- script.h:36
def SEQUENCE_FINAL : Nat := 0xffffffff               -- transaction.h:99
def SEQUENCE_LOCKTIME_DISABLE_FLAG : Nat := 2 ^ 31   -- transaction.h:106
def SEQUENCE_LOCKTIME_TYPE_FLAG : Nat := 2 ^ 22      -- transaction.h:113
def SEQUENCE_LOCKTIME_MASK : Nat := 0x0000ffff       -- transaction.h:119

/-- `CheckLockTime` (`2166–2202`): the operand and the transaction's lock time
must be of one kind (both heights or both times, `LOCKTIME_THRESHOLD`,
`2175–2180`); the operand may not exceed the lock time (`2184–2186`); the
spent input may not be final (`2196–2198`). The operand is non-negative at the
call (`547–548`). -/
def checkLockTime (tx : Tx) (nIn : Nat) (n : Int) : Bool :=
  let txLock : Int := tx.lockTime
  let sameKind := (txLock < LOCKTIME_THRESHOLD && n < LOCKTIME_THRESHOLD)
    || (LOCKTIME_THRESHOLD ≤ txLock && LOCKTIME_THRESHOLD ≤ n)
  if !sameKind then false
  else if txLock < n then false
  else if (tx.inputs[nIn]?.map (·.sequence)).getD SEQUENCE_FINAL = SEQUENCE_FINAL then false
  else true

/-- `CheckSequence` (`2204–2250`): the transaction's version must be at least 2
as an unsigned word (`2212–2214`; a negative version is large); the input's
sequence must not carry the disable flag (`2220–2222`); the operand and the
sequence are masked to the type flag and the low sixteen bits (`2226–2229`)
and must be of one kind (`2237–2242`); the operand may not exceed the
sequence (`2246–2248`). The operand is non-negative and without the disable
flag at the call (`577–587`). -/
def checkSequence (tx : Tx) (nIn : Nat) (n : Int) : Bool :=
  let txSeq : Nat := (tx.inputs[nIn]?.map (·.sequence)).getD SEQUENCE_FINAL
  let versionU32 : Nat := (tx.version % (2 ^ 32)).toNat
  if versionU32 < 2 then false
  else if Nat.testBit txSeq 31 then false
  else
    let mask := SEQUENCE_LOCKTIME_TYPE_FLAG ||| SEQUENCE_LOCKTIME_MASK
    let txMasked := txSeq &&& mask
    let nMasked := n.toNat &&& mask
    let sameKind := (txMasked < SEQUENCE_LOCKTIME_TYPE_FLAG && nMasked < SEQUENCE_LOCKTIME_TYPE_FLAG)
      || (SEQUENCE_LOCKTIME_TYPE_FLAG ≤ txMasked && SEQUENCE_LOCKTIME_TYPE_FLAG ≤ nMasked)
    if !sameKind then false
    else if txMasked < nMasked then false
    else true

/-- The `Context` of input `nIn` of `tx` spending `amount` satoshis: the
transaction signature checker (`2126–2256`). -/
def txContext (tx : Tx) (nIn : Nat) (amount : Nat) : Context :=
  { version := tx.version,
    checkLockTime := checkLockTime tx nIn,
    checkSequence := checkSequence tx nIn,
    checkSig := Ops.Crypto.txCheckSig tx nIn amount }

end BsvScript.TxContext

namespace BsvScript.TxContext
open BsvScript.Tx

/-- T-TX1: a spend whose input is final never satisfies `CHECKLOCKTIMEVERIFY`
(`2196–2198`): the lock-time feature is off for it. -/
theorem checkLockTime_final (tx : Tx) (nIn : Nat) (n : Int)
    (h : (tx.inputs[nIn]?.map (·.sequence)).getD SEQUENCE_FINAL = SEQUENCE_FINAL) :
    checkLockTime tx nIn n = false := by
  unfold checkLockTime
  simp only [h]
  split <;> simp

/-- T-TX2: a transaction of version below 2 never satisfies `CHECKSEQUENCEVERIFY`
(`2212–2214`, BIP 68): relative lock times need version 2. -/
theorem checkSequence_version_lt_two (tx : Tx) (nIn : Nat) (n : Int)
    (h : (tx.version % (2 ^ 32)).toNat < 2) : checkSequence tx nIn n = false := by
  simp only [checkSequence]
  split
  · rfl
  · rename_i hc; exact absurd h hc

end BsvScript.TxContext
