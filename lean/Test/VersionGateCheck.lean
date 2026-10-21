import BsvScript.Flags
import BsvScript.TxContext
import BsvScript.Properties.VersionGate
import Test.Common
/-!
# The version-1 branch check (#19; the `versiongate` leg of `make check`)

A hand-written table of spends, each a corner of MINIMALDATA, CLEANSTACK,
SIGPUSHONLY or LOW_S at one read site of the reference
(`lean/BsvScript/Properties/VersionGate.lean`, the audit table), decided under
the four parameter sets a mainnet SV-node derives for it
(`Params.derive NodeConfig.svMainnetDefault`, `lean/BsvScript/Flags.lean`):
version 1 and version 2, the block word and the mempool word, at the entry's
spend and UTXO heights. Every cell's expected verdict AND error code is written
from the reference at the pin with its citation; a row with an explicit flag
word runs under that word on both paths. The signatures are made here (a
deterministic nonce over the spec's own curve and digest), so the LOW_S rows
need no engine: the low-S signature, its high-S twin, the boundary values of
`s`, the overflowed `r` and `s` (the zero signature, low), the empty signature.

A second table runs one shape under other versions of the spending transaction
(`nVersion` is an `int32_t`: a negative version is not malleable, `34–38`).

Exit 1 on any cell that differs. The counts per flag are printed.
-/

open BsvScript BsvScript.Params BsvScript.Machine BsvScript.Tx BsvScript.Numbers BsvScript.Test
open BsvScript.TxContext BsvScript.Sighash BsvScript.Hash BsvScript.Crypto

/-! ## The scripts -/

def OP_0 : Nat := 0x00
def OP_PUSHDATA1 : Nat := 0x4c
def OP_PUSHDATA2 : Nat := 0x4d
def OP_PUSHDATA4 : Nat := 0x4e
def OP_1NEGATE : Nat := 0x4f
def OP_RESERVED : Nat := 0x50
def OP_1 : Nat := 0x51
def OP_2 : Nat := 0x52
def OP_5 : Nat := 0x55
def OP_6 : Nat := 0x56
def OP_16 : Nat := 0x60
def OP_NOP : Nat := 0x61
def OP_IF : Nat := 0x63
def OP_ELSE : Nat := 0x67
def OP_ENDIF : Nat := 0x68
def OP_VERIFY : Nat := 0x69
def OP_RETURN : Nat := 0x6a
def OP_TOALTSTACK : Nat := 0x6b
def OP_2DROP : Nat := 0x6d
def OP_DROP : Nat := 0x75
def OP_DUP : Nat := 0x76
def OP_PICK : Nat := 0x79
def OP_ROLL : Nat := 0x7a
def OP_SPLIT : Nat := 0x7f
def OP_NUM2BIN : Nat := 0x80
def OP_BIN2NUM : Nat := 0x81
def OP_EQUAL : Nat := 0x87
def OP_EQUALVERIFY : Nat := 0x88
def OP_1ADD : Nat := 0x8b
def OP_NOT : Nat := 0x91
def OP_ADD : Nat := 0x93
def OP_LSHIFT : Nat := 0x98
def OP_RSHIFT : Nat := 0x99
def OP_NUMEQUAL : Nat := 0x9c
def OP_WITHIN : Nat := 0xa5
def OP_HASH160 : Nat := 0xa9
def OP_CHECKSIG : Nat := 0xac
def OP_CHECKMULTISIG : Nat := 0xae
def OP_CHECKLOCKTIMEVERIFY : Nat := 0xb1
def OP_CHECKSEQUENCEVERIFY : Nat := 0xb2
def OP_SUBSTR : Nat := 0xb3
def OP_LEFT : Nat := 0xb4
def OP_RIGHT : Nat := 0xb5
def OP_LSHIFTNUM : Nat := 0xb6
def OP_RSHIFTNUM : Nat := 0xb7

/-- The minimal push of `data` (`CheckMinimalPush`, `331–358`, the form it demands). -/
def pm (data : Bytes) : Bytes :=
  match data with
  | [] => [OP_0]
  | [b] =>
    if 1 ≤ b ∧ b ≤ 16 then [OP_1 + (b - 1)]
    else if b = 0x81 then [OP_1NEGATE]
    else [1, b]
  | _ =>
    if data.length ≤ 75 then data.length :: data
    else if data.length ≤ 255 then OP_PUSHDATA1 :: data.length :: data
    else OP_PUSHDATA2 :: (data.length % 256) :: (data.length / 256) :: data

/-- The `PUSHDATA1` form of a push at most 255 bytes long. -/
def pd1 (data : Bytes) : Bytes := OP_PUSHDATA1 :: data.length :: data
/-- The `PUSHDATA2` form. -/
def pd2 (data : Bytes) : Bytes := OP_PUSHDATA2 :: (data.length % 256) :: (data.length / 256) :: data
/-- The `PUSHDATA4` form. -/
def pd4 (data : Bytes) : Bytes :=
  OP_PUSHDATA4 :: (data.length % 256) :: (data.length / 256 % 256) :: (data.length / 65536 % 256) :: (data.length / 16777216) :: data

/-- The non-minimal 2-byte encoding of 1 (`01 00`, a `0x00` pad), pushed by its minimal 2-byte push. -/
def one2 : Bytes := [2, 0x01, 0x00]
/-- The non-minimal 2-byte encoding of 2. -/
def two2 : Bytes := [2, 0x02, 0x00]
/-- The non-minimal 2-byte encoding of 0 (`00 00`). -/
def zero2 : Bytes := [2, 0x00, 0x00]

/-- `OP_HASH160 <hash160 redeem> OP_EQUAL` (`IsP2SH`, `script.cpp:168–172`). -/
def p2shLock (redeem : Bytes) : Bytes := [OP_HASH160, 0x14] ++ hash160 redeem ++ [OP_EQUAL]

/-! ## The signatures (test-only: a deterministic nonce over the spec's curve) -/

/-- 32 big-endian bytes of a scalar. -/
def be32 (x : Nat) : Bytes := (List.range 32).reverse.map (fun i => x / 256 ^ i % 256)

/-- The strict DER integer of a scalar: the minimal big-endian bytes, a leading `0x00`
when the top bit is set (`IsValidSignatureEncoding`, `232–252`). -/
def derInt (x : Nat) : Bytes :=
  let raw := (be32 x).dropWhile (· = 0)
  let body := if raw.isEmpty then [0] else raw
  let body := if 128 ≤ body.headD 0 then 0 :: body else body
  [0x02, body.length] ++ body

/-- The DER signature of `(r, s)` with the hash-type byte `ALL|FORKID`. -/
def derSig (r s : Nat) : Bytes :=
  let body := derInt r ++ derInt s
  [0x30, body.length] ++ body ++ [0x41]

/-- A private scalar and a nonce, fixed; the public key compressed. -/
def dKey : Nat := 12345678901234567890
def kNonce : Nat := 98765432109876543210

def pubKey : Bytes :=
  match Secp256k1.toAffine (Secp256k1.mul dKey Secp256k1.G) with
  | some (x, y) => (if y % 2 = 1 then 3 else 2) :: be32 x
  | none => []

/-- ECDSA over the spec's curve: `r = (k·G).x mod n`, `s = k⁻¹(z + r·d) mod n`. -/
def ecdsaSign (z : Nat) : Nat × Nat :=
  match Secp256k1.toAffine (Secp256k1.mul kNonce Secp256k1.G) with
  | some (rx, _) =>
    let r := rx % Secp256k1.n
    let s := Secp256k1.invN kNonce * ((z % Secp256k1.n + r * dKey % Secp256k1.n) % Secp256k1.n) % Secp256k1.n
    (r, s)
  | none => (0, 0)

/-- The BIP143 digest of input 0 over `scriptCode` (`ALL|FORKID`, the amount 1,000). -/
def digestOf (scriptCode : Bytes) (tx : Tx) : Nat :=
  Secp256k1.beNat (sighash scriptCode tx 0 { raw := 0x41 } 1000 true)

/-- A genuine signature over the digest of `tx` (the unlock empty: BIP143 never hashes it), low `s`, or its high-S twin. -/
def sigOver (scriptCode : Bytes) (tx : Tx) (high : Bool) : Bytes :=
  let (r, s) := ecdsaSign (digestOf scriptCode tx)
  let s := if Secp256k1.isHighS s then Secp256k1.n - s else s
  derSig r (if high then Secp256k1.n - s else s)

/-- A fixed `r` for the invalid signatures with a chosen `s`: the generator's `x`. -/
def rFixed : Nat := Secp256k1.Gx

/-! ## The table -/

def V : Verdict := .valid
def E (e : ScriptError) : Verdict := .invalid e

/-- A row: the scripts, the heights, the transaction shape, and the expected verdict of
each of the four cells: `(block, mempool)` under version 1 and under version 2. -/
structure Row where
  flag : String
  name : String
  cite : String
  lock : Bytes
  /-- the unlocking script, built from the version's transaction (a signature covers it) -/
  unlock : Tx → Bytes := fun _ => []
  spendHeight : Nat := defaultSpendHeight
  utxoHeight : Nat := defaultSpendHeight
  sequence : Nat := 0xffffffff
  lockTime : Nat := 0
  /-- an explicit flag word, run on both paths with the limits of its era -/
  flags : Option Nat := none
  v1 : Verdict × Verdict
  v2 : Verdict × Verdict

/-- A synthetic spend: one input spending a synthetic outpoint (never a real
transaction), one output of one satoshi locked by `OP_1`. -/
def mkTx (version : Int) (unlock : Bytes) (sequence lockTime : Nat) : Tx :=
  { version,
    inputs := [{ prevHash := List.replicate 32 0x19, prevIndex := 0, scriptSig := unlock, sequence }],
    outputs := [{ value := 1, scriptPubKey := [OP_1] }], lockTime }

def fixedUnlock (u : Bytes) : Tx → Bytes := fun _ => u

def bytes76 : Bytes := (List.range 76).map (fun i => 0x20 + i)
def bytes256 : Bytes := (List.range 256).map (fun i => (0x21 + i) % 256)

def rows : List Row :=
  -- ---- MINIMALDATA on the push form (433–434, 473–479, 331–358; policy.h:189) ----
  [ { flag := "MINIMALDATA", name := "PUSHDATA1 for one byte in the unlocking script", cite := "433–434; 473–479; 331–358 (data.size() ≤ 75: a direct push); policy.h:189 (policy)",
      lock := [OP_DROP, OP_1], unlock := fixedUnlock (pd1 [0x21]), v1 := (V, E .minimaldata), v2 := (V, V) },
    { flag := "MINIMALDATA", name := "PUSHDATA1 for one byte in the locking script", cite := "433 per EvalScript call: the locking script's own requireMinimal (2358–2372)",
      lock := pd1 [0x21] ++ [OP_DROP, OP_1], v1 := (V, E .minimaldata), v2 := (V, V) },
    { flag := "MINIMALDATA", name := "a non-minimal push in a dead branch is never checked", cite := "473 (fExec), 482, 789",
      lock := [OP_0, OP_IF] ++ pd1 [0x21] ++ [OP_ENDIF, OP_1], v1 := (V, V), v2 := (V, V) },
    { flag := "MINIMALDATA", name := "a direct push of [5] where OP_5 would do", cite := "336–339",
      lock := [1, 0x05, OP_DROP, OP_1], v1 := (V, E .minimaldata), v2 := (V, V) },
    { flag := "MINIMALDATA", name := "a direct push of [0x81] where OP_1NEGATE would do", cite := "340–343",
      lock := [1, 0x81, OP_DROP, OP_1], v1 := (V, E .minimaldata), v2 := (V, V) },
    { flag := "MINIMALDATA", name := "a direct push of [0x00] is minimal (not a small integer, not 0x81)", cite := "344–348",
      lock := [1, 0x00, OP_DROP, OP_1], v1 := (V, V), v2 := (V, V) },
    { flag := "MINIMALDATA", name := "PUSHDATA1 of zero bytes where OP_0 would do", cite := "332–335",
      lock := [OP_PUSHDATA1, 0, OP_DROP, OP_1], v1 := (V, E .minimaldata), v2 := (V, V) },
    { flag := "MINIMALDATA", name := "PUSHDATA2 for 76 bytes where PUSHDATA1 would do", cite := "349–352",
      lock := pd2 bytes76 ++ [OP_DROP, OP_1], v1 := (V, E .minimaldata), v2 := (V, V) },
    { flag := "MINIMALDATA", name := "PUSHDATA1 for 76 bytes is minimal", cite := "349–352",
      lock := pd1 bytes76 ++ [OP_DROP, OP_1], v1 := (V, V), v2 := (V, V) },
    { flag := "MINIMALDATA", name := "PUSHDATA4 for 256 bytes where PUSHDATA2 would do", cite := "353–356",
      lock := pd4 bytes256 ++ [OP_DROP, OP_1], v1 := (V, E .minimaldata), v2 := (V, V) },
    { flag := "MINIMALDATA", name := "PUSHDATA2 for 256 bytes is minimal", cite := "353–356",
      lock := pd2 bytes256 ++ [OP_DROP, OP_1], v1 := (V, V), v2 := (V, V) },
    { flag := "MINIMALDATA", name := "a non-minimal push after a top-level OP_RETURN is never parsed", cite := "858–861; opreturn_suffix",
      lock := [OP_1, OP_RETURN] ++ pd1 [0x21], v1 := (V, V), v2 := (V, V) },
    { flag := "MINIMALDATA", name := "the UTXO's era never selects the branch: a pre-Genesis UTXO spent today", cite := "40–44 read the spend era's SCRIPT_CHRONICLE (verify_script_flags.cpp:77–78), never the UTXO markers (411–427)",
      lock := [OP_DROP, OP_1], unlock := fixedUnlock (pd1 [0x21]), utxoHeight := 620537, v1 := (V, E .minimaldata), v2 := (V, V) },
    { flag := "the gate", name := "a pre-Chronicle spend era (height 943,815): the gate is ON for version 2 too", cite := "40–44: no SCRIPT_CHRONICLE in the word (verify_script_flags.cpp:77–78); MINIMALDATA in the mempool word only (policy.h:189, 209–223)",
      lock := [OP_DROP, OP_1], unlock := fixedUnlock (pd1 [0x21]), spendHeight := 943815, utxoHeight := 943815,
      v1 := (V, E .minimaldata), v2 := (V, E .minimaldata) },
    { flag := "the gate", name := "a pre-Genesis spend era (height 620,537): the gate is ON for version 2 too", cite := "40–44; the pre-Genesis limits (docs/PARAMETERS.md §1)",
      lock := [OP_DROP, OP_1], unlock := fixedUnlock (pd1 [0x21]), spendHeight := 620537, utxoHeight := 620537,
      v1 := (V, E .minimaldata), v2 := (V, E .minimaldata) },
    -- ---- MINIMALDATA on the number reads (script_num.cpp:53–91; int_serialization.h:120–152) ----
    { flag := "MINIMALDATA", name := "OP_1ADD reads a padded 1", cite := "1235; script_num.cpp:67–70; 1811–1814",
      lock := one2 ++ [OP_1ADD, OP_2, OP_NUMEQUAL], v1 := (V, E .scriptnumMinencode), v2 := (V, V) },
    { flag := "MINIMALDATA", name := "OP_ADD, the top operand padded", cite := "1300–1301",
      lock := [OP_1] ++ one2 ++ [OP_ADD, OP_2, OP_NUMEQUAL], v1 := (V, E .scriptnumMinencode), v2 := (V, V) },
    { flag := "MINIMALDATA", name := "OP_ADD, the second operand padded", cite := "1300–1301",
      lock := one2 ++ [OP_1, OP_ADD, OP_2, OP_NUMEQUAL], v1 := (V, E .scriptnumMinencode), v2 := (V, V) },
    { flag := "MINIMALDATA", name := "OP_WITHIN, the max padded", cite := "1386–1390",
      lock := [OP_1, OP_0] ++ two2 ++ [OP_WITHIN], v1 := (V, E .scriptnumMinencode), v2 := (V, V) },
    { flag := "MINIMALDATA", name := "OP_PICK by a padded index", cite := "1015",
      lock := [OP_5, OP_6] ++ one2 ++ [OP_PICK, OP_5, OP_EQUALVERIFY, OP_2DROP, OP_1], v1 := (V, E .scriptnumMinencode), v2 := (V, V) },
    { flag := "MINIMALDATA", name := "OP_ROLL by a padded index", cite := "1015",
      lock := [OP_5, OP_6] ++ one2 ++ [OP_ROLL, OP_5, OP_EQUALVERIFY, OP_DROP, OP_1], v1 := (V, E .scriptnumMinencode), v2 := (V, V) },
    { flag := "MINIMALDATA", name := "OP_LSHIFT by a padded count", cite := "1129",
      lock := [1, 0x21] ++ one2 ++ [OP_LSHIFT, 1, 0x42, OP_EQUAL], v1 := (V, E .scriptnumMinencode), v2 := (V, V) },
    { flag := "MINIMALDATA", name := "OP_RSHIFT by a padded count", cite := "1163",
      lock := [1, 0x42] ++ one2 ++ [OP_RSHIFT, 1, 0x21, OP_EQUAL], v1 := (V, E .scriptnumMinencode), v2 := (V, V) },
    { flag := "MINIMALDATA", name := "OP_SPLIT at a padded position", cite := "1717",
      lock := [2, 0xaa, 0xbb] ++ one2 ++ [OP_SPLIT, 1, 0xbb, OP_EQUALVERIFY, 1, 0xaa, OP_EQUAL], v1 := (V, E .scriptnumMinencode), v2 := (V, V) },
    { flag := "MINIMALDATA", name := "OP_NUM2BIN to a padded width", cite := "1747",
      lock := [OP_1] ++ two2 ++ [OP_NUM2BIN] ++ one2 ++ [OP_EQUAL], v1 := (V, E .scriptnumMinencode), v2 := (V, V) },
    { flag := "MINIMALDATA", name := "OP_CHECKMULTISIG, the key count padded (width 4)", cite := "1523–1526",
      lock := [OP_0, OP_0] ++ pm pubKey ++ one2 ++ [OP_CHECKMULTISIG], v1 := (V, E .scriptnumMinencode), v2 := (V, V) },
    { flag := "MINIMALDATA", name := "OP_CHECKMULTISIG, the signature count padded (00 00)", cite := "1550–1553",
      lock := [OP_0] ++ zero2 ++ pm pubKey ++ [OP_1, OP_CHECKMULTISIG], v1 := (V, E .scriptnumMinencode), v2 := (V, V) },
    { flag := "MINIMALDATA", name := "OP_LEFT, the length padded (post-Chronicle UTXO)", cite := "655",
      lock := [3, 0xaa, 0xbb, 0xcc] ++ one2 ++ [OP_LEFT, 1, 0xaa, OP_EQUAL], v1 := (V, E .scriptnumMinencode), v2 := (V, V) },
    { flag := "MINIMALDATA", name := "OP_RIGHT, the length padded", cite := "680",
      lock := [3, 0xaa, 0xbb, 0xcc] ++ one2 ++ [OP_RIGHT, 1, 0xcc, OP_EQUAL], v1 := (V, E .scriptnumMinencode), v2 := (V, V) },
    { flag := "MINIMALDATA", name := "OP_SUBSTR, the length padded", cite := "622",
      lock := [3, 0xaa, 0xbb, 0xcc, OP_1] ++ one2 ++ [OP_SUBSTR, 1, 0xbb, OP_EQUAL], v1 := (V, E .scriptnumMinencode), v2 := (V, V) },
    { flag := "MINIMALDATA", name := "OP_SUBSTR, the offset padded", cite := "624",
      lock := [3, 0xaa, 0xbb, 0xcc] ++ one2 ++ [OP_1, OP_SUBSTR, 1, 0xbb, OP_EQUAL], v1 := (V, E .scriptnumMinencode), v2 := (V, V) },
    { flag := "MINIMALDATA", name := "OP_LSHIFTNUM, the count padded", cite := "706–712",
      lock := [OP_1] ++ one2 ++ [OP_LSHIFTNUM, OP_2, OP_NUMEQUAL], v1 := (V, E .scriptnumMinencode), v2 := (V, V) },
    { flag := "MINIMALDATA", name := "OP_LSHIFTNUM, the value padded", cite := "714–719",
      lock := one2 ++ [OP_1, OP_LSHIFTNUM, OP_2, OP_NUMEQUAL], v1 := (V, E .scriptnumMinencode), v2 := (V, V) },
    { flag := "MINIMALDATA", name := "OP_RSHIFTNUM, the count padded", cite := "742–748",
      lock := [OP_2] ++ one2 ++ [OP_RSHIFTNUM, OP_1, OP_NUMEQUAL], v1 := (V, E .scriptnumMinencode), v2 := (V, V) },
    { flag := "MINIMALDATA", name := "OP_CHECKLOCKTIMEVERIFY reads a padded 0 (a pre-Genesis UTXO, the input not final)", cite := "546 (width 5); 2166–2202",
      lock := zero2 ++ [OP_CHECKLOCKTIMEVERIFY, OP_DROP, OP_1], utxoHeight := 620537, sequence := 0xfffffffe,
      v1 := (V, E .scriptnumMinencode), v2 := (V, V) },
    { flag := "MINIMALDATA", name := "OP_CHECKSEQUENCEVERIFY reads a padded 0 (a pre-Genesis UTXO; version 1 never satisfies CSV, 2212–2214)", cite := "577 (width 5); the read precedes the check (550–556 / 580–591)",
      lock := zero2 ++ [OP_CHECKSEQUENCEVERIFY, OP_DROP, OP_1], utxoHeight := 620537, sequence := 0,
      v1 := (E .unsatisfiedLocktime, E .scriptnumMinencode), v2 := (V, V) },
    { flag := "MINIMALDATA", name := "OP_BIN2NUM never demands a minimal input (the result is checked against the width only)", cite := "1786–1790",
      lock := one2 ++ [OP_BIN2NUM, OP_1, OP_EQUAL], v1 := (V, V), v2 := (V, V) },
    { flag := "MINIMALDATA", name := "OP_IF reads CastToBool, never a number (MINIMALIF is in no derived word at the pin)", cite := "815; 796–804; rpc/misc.cpp:697–702",
      lock := one2 ++ [OP_IF, OP_1, OP_ELSE, OP_0, OP_ENDIF], v1 := (V, V), v2 := (V, V) },
    { flag := "MINIMALDATA", name := "negative zero (0x80) at OP_1ADD", cite := "int_serialization.h:136–141; 1235",
      lock := [1, 0x80, OP_1ADD, OP_1, OP_NUMEQUAL], v1 := (V, E .scriptnumMinencode), v2 := (V, V) },
    -- ---- CLEANSTACK (2430–2448; policy.h:188) ----
    { flag := "CLEANSTACK", name := "two elements left by the locking script", cite := "2430–2448; policy.h:188 (policy)",
      lock := [OP_1, OP_1], v1 := (V, E .cleanstack), v2 := (V, V) },
    { flag := "CLEANSTACK", name := "an element left on the alt stack is not counted", cite := "2441–2445: stack.size() is the main stack; the alt stack dies with EvalScript (1993–2005)",
      lock := [OP_1, OP_TOALTSTACK, OP_1], v1 := (V, V), v2 := (V, V) },
    { flag := "CLEANSTACK", name := "two elements left by the unlocking script, an empty locking script", cite := "2430–2448",
      lock := [], unlock := fixedUnlock [OP_1, OP_1], v1 := (V, E .cleanstack), v2 := (V, V) },
    { flag := "CLEANSTACK", name := "an empty final stack is EVAL_FALSE first", cite := "2374–2375 precedes 2430",
      lock := [], v1 := (E .evalFalse, E .evalFalse), v2 := (E .evalFalse, E .evalFalse) },
    { flag := "CLEANSTACK", name := "a false top over another element is EVAL_FALSE first", cite := "2377–2378 precedes 2430",
      lock := [OP_1, OP_0], v1 := (E .evalFalse, E .evalFalse), v2 := (E .evalFalse, E .evalFalse) },
    { flag := "CLEANSTACK", name := "P2SH (a pre-Genesis UTXO): the redeem script OP_1 OP_1 leaves two elements", cite := "2426–2448: measured after the P2SH evaluation on the restored stack (2405–2416)",
      lock := p2shLock [OP_1, OP_1], unlock := fixedUnlock (pm [OP_1, OP_1]), utxoHeight := 620537,
      v1 := (V, E .cleanstack), v2 := (V, V) },
    { flag := "CLEANSTACK", name := "P2SH: the redeem script OP_1 leaves one element", cite := "2405–2448",
      lock := p2shLock [OP_1], unlock := fixedUnlock (pm [OP_1]), utxoHeight := 620537, v1 := (V, V), v2 := (V, V) },
    { flag := "CLEANSTACK", name := "P2SH: an extra element under the redeem script, consumed by it", cite := "2405–2416: the restored stack minus the redeem script is what the redeem script runs on",
      lock := p2shLock [OP_DROP, OP_1], unlock := fixedUnlock ([OP_2] ++ pm [OP_DROP, OP_1]), utxoHeight := 620537,
      v1 := (V, V), v2 := (V, V) },
    { flag := "CLEANSTACK", name := "CLEANSTACK without P2SH is an invalid word (an explicit word, both versions)", cite := "2432–2435 (ungated); verifyScript_cleanstack_without_p2sh",
      lock := [OP_1], flags := some 0x3D47FE, v1 := (E .invalidFlags, E .invalidFlags), v2 := (E .invalidFlags, E .invalidFlags) },
    { flag := "CLEANSTACK", name := "the same word, the script failing earlier: the final-stack rule comes first", cite := "2374–2378 before 2430",
      lock := [OP_0], flags := some 0x3D47FE, v1 := (E .evalFalse, E .evalFalse), v2 := (E .evalFalse, E .evalFalse) },
    -- ---- SIGPUSHONLY (2321–2334; verify_script_flags.cpp:71–75; policy.h:229–232) ----
    { flag := "SIGPUSHONLY", name := "OP_NOP in the unlocking script", cite := "2321–2334; script.cpp:209–220; the block word carries SIGPUSHONLY from Genesis (verify_script_flags.cpp:71–75): consensus",
      lock := [OP_VERIFY, OP_1], unlock := fixedUnlock [OP_1, OP_NOP], v1 := (E .sigPushonly, E .sigPushonly), v2 := (V, V) },
    { flag := "SIGPUSHONLY", name := "OP_DUP OP_DROP in the unlocking script", cite := "2321–2334",
      lock := [OP_VERIFY, OP_1], unlock := fixedUnlock [OP_1, OP_DUP, OP_DROP], v1 := (E .sigPushonly, E .sigPushonly), v2 := (V, V) },
    { flag := "SIGPUSHONLY", name := "OP_RESERVED counts as a push for IsPushOnly, then fails when executed", cite := "script.cpp:213–217; 1795 (the default:)",
      lock := [OP_1], unlock := fixedUnlock [OP_1, OP_RESERVED], v1 := (E .badOpcode, E .badOpcode), v2 := (E .badOpcode, E .badOpcode) },
    { flag := "SIGPUSHONLY", name := "a truncated push in the unlocking script: SIG_PUSHONLY under the gate, BAD_OPCODE without it", cite := "script.cpp:214 (GetOp false); 450–451",
      lock := [OP_1], unlock := fixedUnlock [2, 0x01], v1 := (E .sigPushonly, E .sigPushonly), v2 := (E .badOpcode, E .badOpcode) },
    { flag := "SIGPUSHONLY", name := "OP_16 is the last push-type opcode", cite := "script.cpp:219",
      lock := [OP_DROP, OP_1], unlock := fixedUnlock [OP_16], v1 := (V, V), v2 := (V, V) },
    { flag := "SIGPUSHONLY", name := "flow opcodes in the unlocking script", cite := "2321–2334",
      lock := [OP_1], unlock := fixedUnlock [OP_1, OP_IF, OP_ENDIF], v1 := (E .sigPushonly, E .sigPushonly), v2 := (V, V) },
    { flag := "SIGPUSHONLY", name := "a non-push opcode in a dead branch of the unlocking script: the rule is syntactic", cite := "script.cpp:209–220 walks every instruction",
      lock := [OP_1], unlock := fixedUnlock [OP_0, OP_IF, OP_NOP, OP_ENDIF], v1 := (E .sigPushonly, E .sigPushonly), v2 := (V, V) },
    { flag := "SIGPUSHONLY", name := "a pre-Chronicle spend era (Genesis without Chronicle): push-only whatever the version", cite := "2325; verify_script_flags.cpp:71–75",
      lock := [OP_VERIFY, OP_1], unlock := fixedUnlock [OP_1, OP_NOP], spendHeight := 943815, utxoHeight := 943815,
      v1 := (E .sigPushonly, E .sigPushonly), v2 := (E .sigPushonly, E .sigPushonly) },
    { flag := "SIGPUSHONLY", name := "a pre-Genesis spend era: no SIGPUSHONLY in any word", cite := "verify_script_flags.cpp:71–75 and policy.h:229 need Genesis; 2321",
      lock := [OP_VERIFY, OP_1], unlock := fixedUnlock [OP_1, OP_NOP], spendHeight := 620537, utxoHeight := 620537,
      v1 := (V, V), v2 := (V, V) },
    { flag := "SIGPUSHONLY", name := "a pre-Genesis spend of a P2SH output with a non-push unlocking script: the P2SH path demands push-only whatever the flag", cite := "2385–2387",
      lock := p2shLock [OP_1], unlock := fixedUnlock ([OP_1, OP_DROP] ++ pm [OP_1]), spendHeight := 620537, utxoHeight := 620537,
      v1 := (E .sigPushonly, E .sigPushonly), v2 := (E .sigPushonly, E .sigPushonly) },
    { flag := "SIGPUSHONLY", name := "the P2SH shape on a post-Genesis UTXO is plain script: only the gate's push-only rule applies", cite := "2383; 2321–2334",
      lock := p2shLock [OP_1], unlock := fixedUnlock ([OP_1, OP_DROP] ++ pm [OP_1]),
      v1 := (E .sigPushonly, E .sigPushonly), v2 := (V, V) },
    -- ---- LOW_S (275–287; pubkey.cpp:353–363; verify_script_flags.cpp:65–67) ----
    { flag := "LOW_S", name := "a genuine low-S signature (P2PK)", cite := "282–287; 1486–1487",
      lock := pm pubKey ++ [OP_CHECKSIG], unlock := fun tx => pm (sigOver (pm pubKey ++ [OP_CHECKSIG]) tx false),
      v1 := (V, V), v2 := (V, V) },
    { flag := "LOW_S", name := "the high-S twin: SIG_HIGH_S under the gate on both paths (LOW_S is consensus from daaHeight), verifies without it (Verify normalizes s)", cite := "282–287; verify_script_flags.cpp:65–67; pubkey.cpp:207–213",
      lock := pm pubKey ++ [OP_CHECKSIG], unlock := fun tx => pm (sigOver (pm pubKey ++ [OP_CHECKSIG]) tx true),
      v1 := (E .sigHighS, E .sigHighS), v2 := (V, V) },
    { flag := "LOW_S", name := "the high-S twin negated: the encoding check precedes the signature check", cite := "1459–1461 before 1486–1497",
      lock := pm pubKey ++ [OP_CHECKSIG, OP_NOT], unlock := fun tx => pm (sigOver (pm pubKey ++ [OP_CHECKSIG, OP_NOT]) tx true),
      v1 := (E .sigHighS, E .sigHighS), v2 := (E .evalFalse, E .evalFalse) },
    { flag := "LOW_S", name := "OP_CHECKMULTISIG 1-of-1 with the high-S twin", cite := "1600–1605",
      lock := [OP_1] ++ pm pubKey ++ [OP_1, OP_CHECKMULTISIG],
      unlock := fun tx => [OP_0] ++ pm (sigOver ([OP_1] ++ pm pubKey ++ [OP_1, OP_CHECKMULTISIG]) tx true),
      v1 := (E .sigHighS, E .sigHighS), v2 := (V, V) },
    { flag := "LOW_S", name := "an invalid signature with s = (n − 1)/2, the largest low s: NULLFAIL under the gate", cite := "secp256k1_scalar_is_high (s > (n−1)/2); 1491–1497",
      lock := pm pubKey ++ [OP_CHECKSIG], unlock := fixedUnlock (pm (derSig rFixed ((Secp256k1.n - 1) / 2))),
      v1 := (E .sigNullfail, E .sigNullfail), v2 := (E .evalFalse, E .evalFalse) },
    { flag := "LOW_S", name := "s = (n + 1)/2, the smallest high s", cite := "282–287",
      lock := pm pubKey ++ [OP_CHECKSIG], unlock := fixedUnlock (pm (derSig rFixed ((Secp256k1.n + 1) / 2))),
      v1 := (E .sigHighS, E .sigHighS), v2 := (E .evalFalse, E .evalFalse) },
    { flag := "LOW_S", name := "s = n − 1", cite := "282–287",
      lock := pm pubKey ++ [OP_CHECKSIG], unlock := fixedUnlock (pm (derSig rFixed (Secp256k1.n - 1))),
      v1 := (E .sigHighS, E .sigHighS), v2 := (E .evalFalse, E .evalFalse) },
    { flag := "LOW_S", name := "s = n overflows the lax parse into the zero signature, which is low: the check passes and the signature fails", cite := "pubkey.cpp:146–173, 353–363; docs/DESIGN.md §4.1; 1491–1497",
      lock := pm pubKey ++ [OP_CHECKSIG], unlock := fixedUnlock (pm (derSig rFixed Secp256k1.n)),
      v1 := (E .sigNullfail, E .sigNullfail), v2 := (E .evalFalse, E .evalFalse) },
    { flag := "LOW_S", name := "r = n overflows the same way", cite := "pubkey.cpp:146–173, 353–363",
      lock := pm pubKey ++ [OP_CHECKSIG], unlock := fixedUnlock (pm (derSig Secp256k1.n 7)),
      v1 := (E .sigNullfail, E .sigNullfail), v2 := (E .evalFalse, E .evalFalse) },
    { flag := "LOW_S", name := "s = 0 is low and never verifies", cite := "ecdsa_impl.h:204–205; 245–252 (a one-byte zero passes the strict shape)",
      lock := pm pubKey ++ [OP_CHECKSIG], unlock := fixedUnlock (pm (derSig rFixed 0)),
      v1 := (E .sigNullfail, E .sigNullfail), v2 := (E .evalFalse, E .evalFalse) },
    { flag := "LOW_S", name := "a non-DER signature is SIG_DER on every path (DERSIG in the block word since BIP66)", cite := "275–280; verify_script_flags.cpp:43",
      lock := pm pubKey ++ [OP_CHECKSIG], unlock := fun tx => pm (0x31 :: (sigOver (pm pubKey ++ [OP_CHECKSIG]) tx false).drop 1),
      v1 := (E .sigDer, E .sigDer), v2 := (E .sigDer, E .sigDer) },
    { flag := "LOW_S", name := "the empty signature passes every encoding check and fails the signature check (NULLFAIL exempts it)", cite := "272–273; 2145–2147; 1493–1496",
      lock := pm pubKey ++ [OP_CHECKSIG], unlock := fixedUnlock [OP_0],
      v1 := (E .evalFalse, E .evalFalse), v2 := (E .evalFalse, E .evalFalse) },
    { flag := "LOW_S", name := "the empty signature negated is valid on every path", cite := "272–273; checksig_empty_sig",
      lock := pm pubKey ++ [OP_CHECKSIG, OP_NOT], unlock := fixedUnlock [OP_0], v1 := (V, V), v2 := (V, V) },
    { flag := "LOW_S", name := "a pre-Chronicle spend era: the high-S twin fails under version 2 too", cite := "40–44; 282–287",
      lock := pm pubKey ++ [OP_CHECKSIG], unlock := fun tx => pm (sigOver (pm pubKey ++ [OP_CHECKSIG]) tx true),
      spendHeight := 943815, utxoHeight := 943815, v1 := (E .sigHighS, E .sigHighS), v2 := (E .sigHighS, E .sigHighS) } ]

/-- The version table: one shape (a padded number at `OP_1ADD`) under the mempool word
at the default height, for versions the `int32_t` can carry (`34–38`, `transaction.h:273`,
`2254–2257`; `Tx.toInt32`). -/
def versionRows : List (Int × Verdict) :=
  [ (-2147483648, E .scriptnumMinencode), (-1, E .scriptnumMinencode), (0, E .scriptnumMinencode),
    (1, E .scriptnumMinencode), (2, V), (3, V), (2147483647, V) ]

/-! ## The run -/

def cfg : NodeConfig := NodeConfig.svMainnetDefault

/-- The parameters of a cell: `Params.derive`, or the explicit word with the limits of
its era under the switch (as `eval/bsvs` and the `verifyscript` RPC take a given word). -/
def paramsOf (r : Row) (consensus : Bool) : EvalParams :=
  match r.flags with
  | some w =>
    let f := Flags.ofWord w
    { flags := f, limits := cfg.normalize.limitsFor f consensus }
  | none => derive cfg r.spendHeight r.utxoHeight consensus

def runCell (r : Row) (version : Int) (consensus : Bool) : Verdict :=
  let tx0 := mkTx version [] r.sequence r.lockTime
  let unlock := r.unlock tx0
  let tx := mkTx version unlock r.sequence r.lockTime
  let ctx := txContext tx 0 1000
  Eval.verifyScript (paramsOf r consensus) ctx unlock r.lock

def main (_ : List String) : IO UInt32 := do
  let mut bad := 0
  let mut cells := 0
  let mut perFlag : List (String × Nat) := []
  for r in rows do
    let got : List (String × Verdict × Verdict) :=
      [ ("version 1, the block word", runCell r 1 true, r.v1.1),
        ("version 1, the mempool word", runCell r 1 false, r.v1.2),
        ("version 2, the block word", runCell r 2 true, r.v2.1),
        ("version 2, the mempool word", runCell r 2 false, r.v2.2) ]
    for (cell, v, want) in got do
      cells := cells + 1
      if v != want then
        bad := bad + 1
        IO.println s!"  FAIL [{r.flag}] {r.name} ({cell}) [{r.cite}]: got {verdictShow v}, expected {verdictShow want}"
    perFlag := match perFlag.find? (·.1 == r.flag) with
      | some _ => perFlag.map (fun (f, n) => if f == r.flag then (f, n + 4) else (f, n))
      | none => perFlag ++ [(r.flag, 4)]
  -- the versions
  let shape : Row := { flag := "the gate", name := "versions", cite := "34–38", lock := one2 ++ [OP_1ADD, OP_2, OP_NUMEQUAL], v1 := (V, V), v2 := (V, V) }
  let mut vbad := 0
  for (version, want) in versionRows do
    let v := runCell shape version false
    if v != want then
      vbad := vbad + 1
      IO.println s!"  FAIL version {version} under the mempool word: got {verdictShow v}, expected {verdictShow want}"
  -- the signer is genuine: the low-S signature verifies under the spec's own equation
  let tx0 := mkTx 2 [] 0xffffffff 0
  let lockP2pk := pm pubKey ++ [OP_CHECKSIG]
  let sig := sigOver lockP2pk tx0 false
  let selfCheck := Secp256k1.verify pubKey sig.dropLast (sighash lockP2pk tx0 0 { raw := 0x41 } 1000 true)
  if !selfCheck then
    bad := bad + 1
    IO.println "  FAIL the test signer's signature does not verify under Crypto.Secp256k1.verify"
  let summary := perFlag.map (fun (f, n) => s!"{f} {n}") |> String.intercalate ", "
  IO.println s!"versiongatecheck: {rows.length} rows × 4 cells = {cells} cells ({summary}); {bad} differ; {versionRows.length} versions of the transaction, {vbad} differ; the test signer verifies: {selfCheck}"
  return (if bad == 0 && vbad == 0 && cells > 0 then 0 else 1)
