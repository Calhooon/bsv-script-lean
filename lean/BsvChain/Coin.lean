import BsvChain.Finality
import BsvScript.Standard

/-!
# Coins and outpoints (#61)

The representation of the pinned coins view, bitcoin-sv v1.2.3 at
6504a3aff65ba97c0f6c80962b033e35ecbfed4b. Script rules and era derivation
are the existing interpreter's definitions. Amounts are signed so the
source's spent sentinel and negative-value refusals remain representable.
-/

namespace BsvChain
open BsvScript.Numbers BsvScript.Tx

/-- The serialized internal-order hash and output index of an input.
[SRC] src/primitives/transaction.h:51–73,85–94 at 6504a3af. -/
structure OutPoint where
  hash : Bytes
  index : Nat
  deriving DecidableEq, Repr

/-- Project the existing transaction input; no second transaction frame.
[SRC] src/primitives/transaction.h:85–94 at 6504a3af. -/
def OutPoint.ofInput (input : TxIn) : OutPoint := ⟨input.prevHash, input.prevIndex⟩

/-- Coin plus its locking script. The reference packs height and the coinbase
bit into `nHeightAndIsCoinBase`, keeps confiscation separately, and uses amount
-1 for spentness. We retain those fields without packing, and use `Int` for
the signed amount, refining DESIGN-S6 §1's `Nat`.
[SRC] src/coins.h:204–239,263–325 at 6504a3af. -/
structure Coin where
  value : Int
  script : Bytes
  height : Nat
  isCoinbase : Bool
  isConfiscation : Bool
  deriving DecidableEq, Repr

/-- The cache's spent sentinel, distinct from a negative live amount that
MoneyRange rejects. [SRC] src/coins.h:235 at 6504a3af. -/
def Coin.isSpent (coin : Coin) : Bool := coin.value == -1

/-- Reuse the interpreter's pruning predicate: after Genesis only the
OP_FALSE OP_RETURN prefix; before it also a leading OP_RETURN or oversized
script. This is the UTXO creation rule, not a relay policy.
[SRC] src/script/script.h:260–277 and src/coins.cpp:45–64 at 6504a3af. -/
abbrev isUnspendable := BsvScript.Standard.isUnspendable

/-- Script era of the coin, with a mempool coin resolved against the active
tip's successor, independently of the supplied spend height. Reuses the
existing sentinel and height derivation.
[SRC] src/validation.cpp:2667–2674,2692–2696 at 6504a3af. -/
def Coin.era (coin : Coin) (params : ChainParams) (tipHeight : Nat) : BsvScript.Params.Era :=
  BsvScript.Params.protocolEraOf params.genesisHeight params.chronicleHeight
    (BsvScript.Params.inputScriptBlockHeight coin.height tipHeight)

/-- Transaction classification, by output zero's literal protocol prefix.
Operator-list mechanism, not a policy limit.
[SRC] src/frozentxo_db.cpp:614–636 at 6504a3af. -/
def isConfiscationTx (tx : Tx) : Bool :=
  match tx.outputs with
  | [] => false
  | output :: _ => output.scriptPubKey.take 7 == [0, 0x6a, 4, 0x63, 0x66, 0x74, 0x78]

/-- Confiscation contents before the whitelist lookup. The encoded sizes and
version are protocol constants, not configurable policy limits. Other outputs
may contain a lone OP_RETURN: the code excludes only OP_FALSE OP_RETURN.
[SRC] src/frozentxo_db.cpp:638–717 at 6504a3af. -/
def validConfiscationContents (tx : Tx) : Bool :=
  match tx.outputs with
  | [] => false
  | output :: rest =>
    let script := output.scriptPubKey
    !tx.inputs.isEmpty && decide (29 ≤ script.length ∧ script.length ≤ 83) &&
      decide (script[7]?.getD 0 < 0x4c) && script[7]? == some (script.length - 8) &&
      script[8]? == some 1 &&
      rest.all (fun o => !(isUnspendable true o.scriptPubKey))

end BsvChain
