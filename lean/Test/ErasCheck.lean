import BsvScript.Flags
import BsvScript.TxContext
import BsvScript.TxRules
import BsvScript.Properties.Eras
import BsvScript.Properties.P2SH
import Test.Common
import Lean.Data.Json
/-!
# The eras check (#20, #23; the `eras` leg of `make check`) and the writer of `corpus/eras`

A hand-written table of spends at the era boundaries and the activation heights,
each a corner of the rules that hang on the COIN's era (`411–427`: the 520-byte
push, the 1,000-element stack, the 500-op count, the 4-byte numbers, the
10,000-byte script, the 20-key multisig, `OP_RETURN`, CLTV/CSV, the second
`OP_ELSE`, the disabled opcodes, `OP_VER`/`OP_VERIF`, the expansion five, the
750,000-byte number width, P2SH) or on the SPEND's height and era (the block word
flag by flag, `verify_script_flags.cpp:32–81` under the tip's-height convention
`validation.cpp:2972–2981`: P2SH, DERSIG, CLTV, CSV, STRICTENC and FORKID, LOW_S
and NULLFAIL, GENESIS and SIGPUSHONLY, CHRONICLE with the hash-type bit), decided
under the two parameter sets a mainnet SV-node derives for the row's heights
(`Params.derive NodeConfig.svMainnetDefault`, `lean/BsvScript/Flags.lean`): the
block word (`consensus = true`) and the mempool word. Every cell's expected verdict
AND error code is written from the reference at the pin with its citation
(`lean/BsvScript/Properties/Eras.lean`, `P2SH.lean` carry the theorems). The
mempool cells of a historical spend height are what `Params.derive` says for a
v1.2.3 node whose tip is that height minus one (the standard word of the era; the
reference's mempool never saw those heights). The signatures are shapes only
(a valid DER form over a chosen `r`, `s` and hash type, the generator's own point
as the key): every signature row fails the equation and asks `OP_NOT`, so the
cell turns on the ENCODING rule of the height, never on the curve. The rows about
the transaction-level P2SH output rule are decided by `TxRules.checkRegularTransaction`.

`--write-corpus <dir>` writes the same rows as `corpus/eras/eras.jsonl` in the
`docs/DESIGN.md` §6 format (every outpoint synthetic: its txid is the SHA-256 of
the entry id; `params.consensus = true`, the block path) with `manifest.json`
beside it, for the harness (`run_bsvrs --record` for bsv-rs's verdicts under the
per-input words, `make diff` for the differential, the S3 node oracle).

Exit 1 on any cell that differs. The counts per family are printed.
-/

open BsvScript BsvScript.Params BsvScript.Machine BsvScript.Tx BsvScript.Numbers BsvScript.Test
open BsvScript.TxContext BsvScript.TxRules BsvScript.Hash BsvScript.Crypto
open Lean

/-! ## The opcodes -/

def OP_0 : Nat := 0x00
def OP_PUSHDATA1 : Nat := 0x4c
def OP_PUSHDATA2 : Nat := 0x4d
def OP_1NEGATE : Nat := 0x4f
def OP_1 : Nat := 0x51
def OP_2 : Nat := 0x52
def OP_3 : Nat := 0x53
def OP_4 : Nat := 0x54
def OP_16 : Nat := 0x60
def OP_NOP : Nat := 0x61
def OP_VER : Nat := 0x62
def OP_IF : Nat := 0x63
def OP_VERIF : Nat := 0x65
def OP_ELSE : Nat := 0x67
def OP_ENDIF : Nat := 0x68
def OP_RETURN : Nat := 0x6a
def OP_DROP : Nat := 0x75
def OP_DUP : Nat := 0x76
def OP_CAT : Nat := 0x7e
def OP_EQUAL : Nat := 0x87
def OP_1ADD : Nat := 0x8b
def OP_2MUL : Nat := 0x8d
def OP_NOT : Nat := 0x91
def OP_ADD : Nat := 0x93
def OP_NUMEQUAL : Nat := 0x9c
def OP_HASH160 : Nat := 0xa9
def OP_CHECKSIG : Nat := 0xac
def OP_CHECKMULTISIG : Nat := 0xae
def OP_CHECKLOCKTIMEVERIFY : Nat := 0xb1
def OP_CHECKSEQUENCEVERIFY : Nat := 0xb2
def OP_SUBSTR : Nat := 0xb3
def OP_LSHIFTNUM : Nat := 0xb6
def OP_RSHIFTNUM : Nat := 0xb7

/-! ## The heights (mainnet, `chainparams.cpp:1038–1076`, `:18`, `:23`, `:28`) -/

def G : Nat := 620538        -- GENESIS_ACTIVATION_MAIN (:18): the first post-Genesis height
def C : Nat := 943816        -- CHRONICLE_ACTIVATION_MAIN (:23)
def TIP : Nat := 967896      -- the spec's default spend height (docs/PARAMETERS.md §3)
def P2SHH : Nat := 173805    -- p2shHeight (:28, :1076): tested against the TIP's height (:39)
def BIP66 : Nat := 363725    -- (:1044): tested against tip + 1 (:43)
def BIP65 : Nat := 388381    -- (:1042): tip + 1 (:47)
def CSVH : Nat := 419328     -- (:1046): tip + 1 (:51)
def UAHF : Nat := 478558     -- (:1065): the tip's height (:55): the fork block is 478,559
def DAA : Nat := 504031      -- (:1068): the tip's height (:65): the fork block is 504,032

/-! ## The scripts -/

/-- The minimal push of `data` (`CheckMinimalPush`, `331–358`). -/
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

/-- `OP_HASH160 <hash160 redeem> OP_EQUAL` (`IsP2SH`, `script.cpp:168–172`). -/
def p2shLock (redeem : Bytes) : Bytes := [OP_HASH160, 0x14] ++ hash160 redeem ++ [OP_EQUAL]

/-- 32 big-endian bytes of a scalar. -/
def be32 (x : Nat) : Bytes := (List.range 32).reverse.map (fun i => x / 256 ^ i % 256)

/-- The strict DER integer of a scalar (`IsValidSignatureEncoding`, `232–252`). -/
def derInt (x : Nat) : Bytes :=
  let raw := (be32 x).dropWhile (· = 0)
  let body := if raw.isEmpty then [0] else raw
  let body := if 128 ≤ body.headD 0 then 0 :: body else body
  [0x02, body.length] ++ body

/-- A strict-DER signature shape over `(r, s)` with the given hash-type byte: the
encoding rules of a height (DERSIG `275–280`, LOW_S `282–287`, the hash type `291–307`)
read it; the equation then fails on it (a chosen `r`, `s` against the generator's point). -/
def derSig (r s hashType : Nat) : Bytes :=
  let body := derInt r ++ derInt s
  [0x30, body.length] ++ body ++ [hashType]

/-- The generator's point, compressed: a key on the curve that no signature here is made with. -/
def pkG : Bytes := [0x02] ++ be32 Secp256k1.Gx

/-- A byte string that is no DER signature at all (`205–206`: shorter than 9 bytes). -/
def sigBad : Bytes := [0x30, 0x02, 0x01, 0x01]

def bytes521 : Bytes := (List.range 521).map (fun i => (0x30 + i) % 256)
def bytes10000 : Bytes := (List.range 10000).map (fun i => (0x40 + i) % 256)
/-- The minimal 5-byte number `2^31` = `00 00 00 80 00` (`encode`; T6: a 5-byte width). -/
def num5 : Bytes := [0x00, 0x00, 0x00, 0x80, 0x00]

/-! ## The table -/

def V : Verdict := .valid
def E (e : ScriptError) : Verdict := .invalid e

/-- A row: the family and rule (`corpus/INDEX.md` §2), the scripts, the heights, the
transaction shape, and the expected verdict of the two cells (the block word and the
mempool word of `Params.derive NodeConfig.svMainnetDefault` at the row's heights). -/
structure Row where
  family : String
  rule : String
  name : String
  cite : String
  lock : Bytes
  unlock : Bytes := []
  version : Int := 2
  spendHeight : Nat := TIP
  utxoHeight : Nat := TIP
  sequence : Nat := 0xffffffff
  lockTime : Nat := 0
  outputs : List TxOut := [{ value := 1, scriptPubKey := [OP_1] }]
  block : Verdict
  mempool : Verdict
  /-- the verdict of `CheckRegularTransaction` under the spend height's era, for the rows about it -/
  txLevel : Option (Except TxReject Unit) := none
  note : String := ""

/-- The rows about the COIN's era: the same shape spent at the tip with the coin created
at each boundary height. -/
def coinRows : List Row :=
  [ -- OP_RETURN (856–871)
    { family := "eras/coin/op-return/pre-genesis", rule := "eras.utxo.pre-genesis", name := "OP_RETURN executed on a pre-Genesis coin", cite := "867–869: SCRIPT_ERR_OP_RETURN whatever the spend era (the coin's era, 411–427)",
      lock := [OP_1, OP_RETURN], utxoHeight := G - 1, block := E .opReturn, mempool := E .opReturn },
    { family := "eras/coin/op-return/post-genesis", rule := "eras.utxo.post-genesis", name := "a top-level OP_RETURN on a post-Genesis coin ends the script as success", cite := "858–861",
      lock := [OP_1, OP_RETURN], utxoHeight := G, block := V, mempool := V },
    -- the 520-byte element (455–456, script.h:29)
    { family := "eras/coin/push-521/pre-genesis", rule := "eras.utxo.pre-genesis", name := "a 521-byte push on a pre-Genesis coin", cite := "455–456: SCRIPT_ERR_PUSH_SIZE; script.h:29",
      lock := pm bytes521 ++ [OP_DROP, OP_1], utxoHeight := G - 1, block := E .pushSize, mempool := E .pushSize },
    { family := "eras/coin/push-521/post-genesis", rule := "eras.utxo.post-genesis", name := "a 521-byte push on a post-Genesis coin: the memory budget only", cite := "455 needs !utxo_after_genesis; limitedstack.cpp:194–207",
      lock := pm bytes521 ++ [OP_DROP, OP_1], utxoHeight := G, block := V, mempool := V },
    -- the 1,000-element stack (1800–1803, script.h:32)
    { family := "eras/coin/stack-1001/pre-genesis", rule := "eras.utxo.pre-genesis", name := "1,001 elements on a pre-Genesis coin", cite := "1800–1803: SCRIPT_ERR_STACK_SIZE after the 1,001st push; script.h:32",
      lock := List.replicate 1001 OP_1, utxoHeight := G - 1, block := E .stackSize, mempool := E .stackSize },
    { family := "eras/coin/stack-1001/post-genesis", rule := "eras.utxo.post-genesis", name := "1,001 elements on a post-Genesis coin (a version-2 spend post-Chronicle: no CLEANSTACK)", cite := "1800 needs !utxo_after_genesis; 2441–2445 under the gate",
      lock := List.replicate 1001 OP_1, utxoHeight := G, block := V, mempool := V },
    -- the 500-op count (466–467, consensus.h:40)
    { family := "eras/coin/ops-501/pre-genesis", rule := "eras.utxo.pre-genesis", name := "501 counted opcodes on a pre-Genesis coin", cite := "466–467: SCRIPT_ERR_OP_COUNT at the 501st; MaxOpsPerScript 500 (consensus.h:40, configscriptpolicy.cpp:67–70)",
      lock := [OP_1] ++ List.replicate 501 OP_NOP, utxoHeight := G - 1, block := E .opCount, mempool := E .opCount },
    { family := "eras/coin/ops-501/post-genesis", rule := "eras.utxo.post-genesis", name := "501 counted opcodes on a post-Genesis coin: UINT32_MAX at consensus and at SV-node's policy default", cite := "consensus.h:43; policy.h:147",
      lock := [OP_1] ++ List.replicate 501 OP_NOP, utxoHeight := G, block := V, mempool := V },
    -- the 4-byte number (script_num.cpp:62, consensus.h:62)
    { family := "eras/coin/num-5-bytes/pre-genesis", rule := "eras.utxo.pre-genesis", name := "a 5-byte number read by OP_1ADD on a pre-Genesis coin", cite := "1235; script_num.cpp:62: SCRIPT_ERR_SCRIPTNUM_OVERFLOW (1807–1810); MaxScriptNumLength 4 (consensus.h:62)",
      lock := pm num5 ++ [OP_1ADD, OP_DROP, OP_1], utxoHeight := G - 1, block := E .scriptnumOverflow, mempool := E .scriptnumOverflow },
    { family := "eras/coin/num-5-bytes/post-genesis", rule := "eras.utxo.post-genesis", name := "a 5-byte number on a post-Genesis coin: 750,000 at consensus, 10,000 at policy", cite := "consensus.h:64; policy.h:156",
      lock := pm num5 ++ [OP_1ADD, OP_DROP, OP_1], utxoHeight := G, block := V, mempool := V },
    -- the 10,000-byte script (429–430, consensus.h:58), before the push size (455)
    { family := "eras/coin/script-10005/pre-genesis", rule := "eras.utxo.pre-genesis", name := "a 10,005-byte locking script on a pre-Genesis coin: the size rule before the push rule", cite := "429–430: SCRIPT_ERR_SCRIPT_SIZE before the loop; MaxScriptSize 10,000 (consensus.h:58)",
      lock := pm bytes10000 ++ [OP_DROP, OP_1], utxoHeight := G - 1, block := E .scriptSize, mempool := E .scriptSize },
    { family := "eras/coin/script-10005/post-genesis", rule := "eras.utxo.post-genesis", name := "a 10,005-byte locking script on a post-Genesis coin", cite := "consensus.h:60; policy.h:93 (500,000)",
      lock := pm bytes10000 ++ [OP_DROP, OP_1], utxoHeight := G, block := V, mempool := V },
    -- the 20-key multisig (consensus.h:50)
    { family := "eras/coin/multisig-21/pre-genesis", rule := "eras.utxo.pre-genesis", name := "OP_CHECKMULTISIG with 21 keys on a pre-Genesis coin", cite := "1522–1530: SCRIPT_ERR_PUBKEY_COUNT; MaxPubKeysPerMultiSig 20 (consensus.h:50)",
      lock := [OP_0, OP_0] ++ (List.replicate 21 (pm pkG)).flatten ++ pm [21] ++ [OP_CHECKMULTISIG], utxoHeight := G - 1, block := E .pubkeyCount, mempool := E .pubkeyCount },
    { family := "eras/coin/multisig-21/post-genesis", rule := "eras.utxo.post-genesis", name := "OP_CHECKMULTISIG 0-of-21 on a post-Genesis coin", cite := "consensus.h:55; policy.h:150",
      lock := [OP_0, OP_0] ++ (List.replicate 21 (pm pkG)).flatten ++ pm [21] ++ [OP_CHECKMULTISIG], utxoHeight := G, block := V, mempool := V },
    -- CLTV / CSV (520, 563)
    { family := "eras/coin/cltv/pre-genesis", rule := "eras.utxo.pre-genesis", name := "OP_CHECKLOCKTIMEVERIFY live on a pre-Genesis coin: an unsatisfied lock time", cite := "520; 546–556: SCRIPT_ERR_UNSATISFIED_LOCKTIME; 2166–2202",
      lock := [OP_1, OP_CHECKLOCKTIMEVERIFY, OP_DROP, OP_1], utxoHeight := G - 1, sequence := 0xfffffffe, block := E .unsatisfiedLocktime, mempool := E .unsatisfiedLocktime },
    { family := "eras/coin/cltv/post-genesis", rule := "eras.utxo.post-genesis", name := "OP_CHECKLOCKTIMEVERIFY is a NOP on a post-Genesis coin, discouraged by the relay word", cite := "520 (|| utxo_after_genesis); 522–526 under DISCOURAGE_UPGRADABLE_NOPS (policy.h:185)",
      lock := [OP_1, OP_CHECKLOCKTIMEVERIFY, OP_DROP, OP_1], utxoHeight := G, sequence := 0xfffffffe, block := V, mempool := E .discourageUpgradableNops },
    { family := "eras/coin/csv/pre-genesis", rule := "eras.utxo.pre-genesis", name := "OP_CHECKSEQUENCEVERIFY live on a pre-Genesis coin: an unsatisfied relative lock", cite := "563; 577–595; 2204–2250",
      lock := [OP_1, OP_CHECKSEQUENCEVERIFY, OP_DROP, OP_1], utxoHeight := G - 1, sequence := 0, block := E .unsatisfiedLocktime, mempool := E .unsatisfiedLocktime },
    { family := "eras/coin/csv/post-genesis", rule := "eras.utxo.post-genesis", name := "OP_CHECKSEQUENCEVERIFY is a NOP on a post-Genesis coin, discouraged by the relay word", cite := "563; 565–569",
      lock := [OP_1, OP_CHECKSEQUENCEVERIFY, OP_DROP, OP_1], utxoHeight := G, sequence := 0, block := V, mempool := E .discourageUpgradableNops },
    -- the second OP_ELSE (829–831)
    { family := "eras/coin/else-twice/pre-genesis", rule := "eras.utxo.pre-genesis", name := "a second OP_ELSE toggles again on a pre-Genesis coin", cite := "829–831 need utxo_after_genesis; conditional_tracker.cpp:57–65",
      lock := [OP_1, OP_IF, OP_1, OP_ELSE, OP_0, OP_ELSE, OP_1, OP_ENDIF], utxoHeight := G - 1, block := V, mempool := V },
    { family := "eras/coin/else-twice/post-genesis", rule := "eras.utxo.post-genesis", name := "a second OP_ELSE is unbalanced on a post-Genesis coin", cite := "829–831; conditional_tracker.cpp:51–55",
      lock := [OP_1, OP_IF, OP_1, OP_ELSE, OP_0, OP_ELSE, OP_1, OP_ENDIF], utxoHeight := G, block := E .unbalancedConditional, mempool := E .unbalancedConditional },
    -- the disabled opcodes (470–471, 360–375)
    { family := "eras/coin/2mul-dead/pre-genesis", rule := "eras.utxo.pre-genesis", name := "OP_2MUL in a dead branch on a pre-Genesis coin fails unexecuted", cite := "470–471 (!utxo_after_genesis || fExec); 360–375",
      lock := [OP_0, OP_IF, OP_2MUL, OP_ENDIF, OP_1], utxoHeight := G - 1, block := E .disabledOpcode, mempool := E .disabledOpcode },
    { family := "eras/coin/2mul-dead/post-genesis", rule := "eras.utxo.post-genesis", name := "OP_2MUL in a dead branch on a post-Genesis, pre-Chronicle coin is skipped", cite := "470–471: fExec false and utxo_after_genesis",
      lock := [OP_0, OP_IF, OP_2MUL, OP_ENDIF, OP_1], utxoHeight := C - 1, block := V, mempool := V },
    { family := "eras/coin/2mul-dead/post-chronicle", rule := "eras.utxo.post-chronicle", name := "OP_2MUL in a dead branch on a post-Chronicle coin is not disabled", cite := "360–375: enabled when the coin's era is post-Chronicle",
      lock := [OP_0, OP_IF, OP_2MUL, OP_ENDIF, OP_1], utxoHeight := C, block := V, mempool := V },
    { family := "eras/coin/2mul/pre-genesis", rule := "eras.utxo.pre-genesis", name := "OP_2MUL executed on a pre-Genesis coin", cite := "470–471; 360–375",
      lock := [OP_2, OP_2MUL, OP_4, OP_NUMEQUAL], utxoHeight := G - 1, block := E .disabledOpcode, mempool := E .disabledOpcode },
    { family := "eras/coin/2mul/post-genesis", rule := "eras.utxo.post-genesis", name := "OP_2MUL executed on a post-Genesis, pre-Chronicle coin", cite := "470–471 (fExec); 360–375",
      lock := [OP_2, OP_2MUL, OP_4, OP_NUMEQUAL], utxoHeight := C - 1, block := E .disabledOpcode, mempool := E .disabledOpcode },
    { family := "eras/coin/2mul/post-chronicle", rule := "eras.utxo.post-chronicle", name := "OP_2MUL computes on a post-Chronicle coin: 2 · 2 = 4", cite := "1247–1250 (bn += bn)",
      lock := [OP_2, OP_2MUL, OP_4, OP_NUMEQUAL], utxoHeight := C, block := V, mempool := V },
    -- OP_VERIF unexecuted (773–781)
    { family := "eras/coin/verif-dead/pre-genesis", rule := "eras.utxo.pre-genesis", name := "OP_VERIF in a dead branch on a pre-Genesis coin fails unexecuted", cite := "775–780: BAD_OPCODE unless utxo_after_genesis && !fExec",
      lock := [OP_0, OP_IF, OP_VERIF, OP_ENDIF, OP_1], utxoHeight := G - 1, block := E .badOpcode, mempool := E .badOpcode },
    { family := "eras/coin/verif-dead/post-genesis", rule := "eras.utxo.post-genesis", name := "OP_VERIF in a dead branch on a post-Genesis, pre-Chronicle coin is skipped", cite := "777–778",
      lock := [OP_0, OP_IF, OP_VERIF, OP_ENDIF, OP_1], utxoHeight := C - 1, block := V, mempool := V },
    { family := "eras/coin/verif-dead/post-chronicle", rule := "eras.utxo.post-chronicle", name := "OP_VERIF in a dead branch on a post-Chronicle coin is a conditional: it nests, and the OP_ENDIF closes it, not the OP_IF", cite := "784–825 with 482 (an OP_IF-family opcode runs unexecuted: op_if(false), 823); 1828–1830",
      lock := [OP_0, OP_IF, OP_VERIF, OP_ENDIF, OP_1], utxoHeight := C, block := E .unbalancedConditional, mempool := E .unbalancedConditional },
    -- OP_VER (598–608)
    { family := "eras/coin/ver/pre-genesis", rule := "eras.utxo.pre-genesis", name := "OP_VER on a pre-Genesis coin", cite := "600–601: BAD_OPCODE",
      lock := [OP_VER] ++ pm [2, 0, 0, 0] ++ [OP_EQUAL], utxoHeight := G - 1, block := E .badOpcode, mempool := E .badOpcode },
    { family := "eras/coin/ver/post-genesis", rule := "eras.utxo.post-genesis", name := "OP_VER on a post-Genesis, pre-Chronicle coin", cite := "600–601",
      lock := [OP_VER] ++ pm [2, 0, 0, 0] ++ [OP_EQUAL], utxoHeight := C - 1, block := E .badOpcode, mempool := E .badOpcode },
    { family := "eras/coin/ver/post-chronicle", rule := "eras.utxo.post-chronicle", name := "OP_VER pushes the 4-byte version on a post-Chronicle coin", cite := "603–606; to_le 382–386",
      lock := [OP_VER] ++ pm [2, 0, 0, 0] ++ [OP_EQUAL], utxoHeight := C, block := V, mempool := V },
    -- the expansion five (609–764; NOPs before Chronicle, 611–618)
    { family := "eras/coin/substr/pre-genesis", rule := "eras.utxo.pre-genesis", name := "OP_SUBSTR is a NOP on a pre-Genesis coin, discouraged by the relay word", cite := "611–618: NOP, or DISCOURAGE_UPGRADABLE_NOPS (policy)",
      lock := [3, 0xaa, 0xbb, 0xcc, OP_1, OP_1, OP_SUBSTR, 1, 0xbb, OP_EQUAL], utxoHeight := G - 1, block := E .evalFalse, mempool := E .discourageUpgradableNops },
    { family := "eras/coin/substr/post-genesis", rule := "eras.utxo.post-genesis", name := "OP_SUBSTR is a NOP on a post-Genesis, pre-Chronicle coin", cite := "611–618",
      lock := [3, 0xaa, 0xbb, 0xcc, OP_1, OP_1, OP_SUBSTR, 1, 0xbb, OP_EQUAL], utxoHeight := C - 1, block := E .evalFalse, mempool := E .discourageUpgradableNops },
    { family := "eras/coin/substr/post-chronicle", rule := "eras.utxo.post-chronicle", name := "OP_SUBSTR executes on a post-Chronicle coin: aabbcc from 1 for 1 is bb", cite := "620–640",
      lock := [3, 0xaa, 0xbb, 0xcc, OP_1, OP_1, OP_SUBSTR, 1, 0xbb, OP_EQUAL], utxoHeight := C, block := V, mempool := V },
    { family := "eras/coin/lshiftnum/post-genesis", rule := "eras.utxo.post-genesis", name := "OP_LSHIFTNUM is a NOP on a pre-Chronicle coin", cite := "694–700",
      lock := [OP_1, OP_1, OP_LSHIFTNUM, OP_2, OP_NUMEQUAL], utxoHeight := C - 1, block := E .evalFalse, mempool := E .discourageUpgradableNops },
    { family := "eras/coin/lshiftnum/post-chronicle", rule := "eras.utxo.post-chronicle", name := "OP_LSHIFTNUM executes on a post-Chronicle coin: 1 << 1 = 2", cite := "702–726",
      lock := [OP_1, OP_1, OP_LSHIFTNUM, OP_2, OP_NUMEQUAL], utxoHeight := C, block := V, mempool := V },
    { family := "eras/coin/rshiftnum/post-genesis", rule := "eras.utxo.post-genesis", name := "OP_RSHIFTNUM is a NOP on a pre-Chronicle coin: 4 1 stay, 1 ≠ 2", cite := "730–736",
      lock := [OP_4, OP_1, OP_RSHIFTNUM, OP_2, OP_NUMEQUAL], utxoHeight := C - 1, block := E .evalFalse, mempool := E .discourageUpgradableNops },
    { family := "eras/coin/rshiftnum/post-chronicle", rule := "eras.utxo.post-chronicle", name := "OP_RSHIFTNUM executes on a post-Chronicle coin: 4 >> 1 = 2", cite := "738–763",
      lock := [OP_4, OP_1, OP_RSHIFTNUM, OP_2, OP_NUMEQUAL], utxoHeight := C, block := V, mempool := V },
    -- the number width by era (consensus.h:64, :66): a 1,048,577-byte element (a 1 followed by 2^20 zero bytes, a
    -- non-minimal encoding of 1 that the gate-off path never checks: the constructor's length test at script_num.cpp:62
    -- precedes the decode, and a zero-padded number decodes in linear time here and in the reference's BN_lebin2bn)
    { family := "eras/coin/num-1mb/pre-genesis", rule := "eras.utxo.pre-genesis", name := "a 1 MB element by doubling on a pre-Genesis coin: OP_CAT's 520-byte cap fires first", cite := "1699–1701: SCRIPT_ERR_PUSH_SIZE at the tenth OP_CAT",
      lock := [1, 0x01, 1, 0x00] ++ (List.replicate 20 [OP_DUP, OP_CAT]).flatten ++ [OP_CAT, OP_1ADD, OP_DROP, OP_1], utxoHeight := G - 1, block := E .pushSize, mempool := E .pushSize },
    { family := "eras/coin/num-1mb/post-genesis", rule := "eras.utxo.post-genesis", name := "a 1,048,577-byte number read by OP_1ADD on a post-Genesis, pre-Chronicle coin: above 750,000 (the length test precedes the decode)", cite := "1235; script_num.cpp:62; consensus.h:64 (750,000); policy.h:156 (10,000)",
      lock := [1, 0x01, 1, 0x00] ++ (List.replicate 20 [OP_DUP, OP_CAT]).flatten ++ [OP_CAT, OP_1ADD, OP_DROP, OP_1], utxoHeight := C - 1, block := E .scriptnumOverflow, mempool := E .scriptnumOverflow },
    { family := "eras/coin/num-1mb/post-chronicle", rule := "eras.utxo.post-chronicle", name := "a 1,048,577-byte number on a post-Chronicle coin: within 32,000,000 at consensus (it reads as 1, the pad unchecked with the gate off), above the 10,000 policy width", cite := "consensus.h:66 (32,000,000); policy.h:156",
      lock := [1, 0x01, 1, 0x00] ++ (List.replicate 20 [OP_DUP, OP_CAT]).flatten ++ [OP_CAT, OP_1ADD, OP_DROP, OP_1], utxoHeight := C, block := V, mempool := E .scriptnumOverflow } ]

/-- The rows about the SPEND's height and era: the block word flag by flag under the
tip's-height convention (`validation.cpp:2972–2981`, `3473`), and the era bits. The coin is pre-Genesis (height 100) unless
the row says otherwise; the mempool cells are the standard word of the spend era. -/
def spendRows : List Row :=
  [ -- GENESIS and SIGPUSHONLY by the spend era (verify_script_flags.cpp:71–75; 2321–2334)
    { family := "eras/spend/sigpushonly/pre-genesis", rule := "eras.spend.genesis", name := "a non-push unlocking script spent in the pre-Genesis era: no SIGPUSHONLY in any word", cite := "verify_script_flags.cpp:71–75 and policy.h:229 need Genesis; the standard set carries none (policy.h:182–189)",
      lock := [OP_2, OP_EQUAL], unlock := [OP_1, OP_1, OP_ADD], spendHeight := G - 1, utxoHeight := G - 1, block := V, mempool := V },
    { family := "eras/spend/sigpushonly/genesis", rule := "eras.spend.genesis", name := "the same spend in the Genesis block: SIGPUSHONLY, Genesis without Chronicle, whatever the version", cite := "2321–2334 (2325); verify_script_flags.cpp:71–75",
      lock := [OP_2, OP_EQUAL], unlock := [OP_1, OP_1, OP_ADD], spendHeight := G, utxoHeight := G - 1, block := E .sigPushonly, mempool := E .sigPushonly },
    { family := "eras/spend/sigpushonly/chronicle-v2", rule := "eras.spend.chronicle", name := "the same spend in the Chronicle block, version 2: the gate lifts push-only", cite := "2326–2327: Chronicle with a malleable version (34–38)",
      lock := [OP_2, OP_EQUAL], unlock := [OP_1, OP_1, OP_ADD], spendHeight := C, utxoHeight := G - 1, block := V, mempool := V },
    { family := "eras/spend/sigpushonly/chronicle-v1", rule := "eras.spend.chronicle", name := "the same spend in the Chronicle block, version 1: push-only", cite := "2327",
      lock := [OP_2, OP_EQUAL], unlock := [OP_1, OP_1, OP_ADD], version := 1, spendHeight := C, utxoHeight := G - 1, block := E .sigPushonly, mempool := E .sigPushonly },
    -- P2SH by height (verify_script_flags.cpp:38–40 against the TIP's height): the redeem script OP_0 fails only when P2SH is evaluated
    { family := "eras/spend/p2sh/before", rule := "eras.height.p2sh", name := "a P2SH-shaped pre-Genesis coin spent in block 173,805: the block word has no P2SH (the tip is 173,804), the hash puzzle passes; the mempool word always has P2SH", cite := "verify_script_flags.cpp:38–40 (height >= p2shHeight with height = the tip, validation.cpp:2972–2981, 3473); standard.h:56",
      lock := p2shLock [OP_0], unlock := pm [OP_0], spendHeight := P2SHH, utxoHeight := 100, block := V, mempool := E .evalFalse },
    { family := "eras/spend/p2sh/from", rule := "eras.height.p2sh", name := "the same spend in block 173,806: P2SH in the block word, the redeem script OP_0 fails", cite := "verify_script_flags.cpp:38–40; 2380–2424 (2418–2424: EVAL_FALSE)",
      lock := p2shLock [OP_0], unlock := pm [OP_0], spendHeight := P2SHH + 1, utxoHeight := 100, block := E .evalFalse, mempool := E .evalFalse },
    -- DERSIG at BIP66Height (verify_script_flags.cpp:42–44 against tip + 1)
    { family := "eras/spend/dersig/before", rule := "eras.height.dersig", name := "a non-DER signature with OP_NOT in block 363,724: no DERSIG in the block word", cite := "verify_script_flags.cpp:42–44 ((height + 1) >= BIP66Height); 275–280 not read; CheckSig false (2133–2164), OP_NOT",
      lock := pm sigBad ++ pm pkG ++ [OP_CHECKSIG, OP_NOT], spendHeight := BIP66 - 1, utxoHeight := 100, block := V, mempool := E .sigDer },
    { family := "eras/spend/dersig/from", rule := "eras.height.dersig", name := "the same spend in block 363,725: SCRIPT_ERR_SIG_DER", cite := "verify_script_flags.cpp:42–44; 275–280; 1459",
      lock := pm sigBad ++ pm pkG ++ [OP_CHECKSIG, OP_NOT], spendHeight := BIP66, utxoHeight := 100, block := E .sigDer, mempool := E .sigDer },
    -- CLTV at BIP65Height (46–48), CSV at CSVHeight (50–52): tip + 1
    { family := "eras/spend/cltv/before", rule := "eras.height.cltv", name := "OP_CHECKLOCKTIMEVERIFY in block 388,380: a NOP without the flag", cite := "verify_script_flags.cpp:46–48; 520 (!(flags & CLTV))",
      lock := [OP_1, OP_CHECKLOCKTIMEVERIFY, OP_DROP, OP_1], spendHeight := BIP65 - 1, utxoHeight := 100, sequence := 0xfffffffe, block := V, mempool := E .unsatisfiedLocktime },
    { family := "eras/spend/cltv/from", rule := "eras.height.cltv", name := "the same spend in block 388,381: the lock time checked", cite := "verify_script_flags.cpp:46–48; 546–556",
      lock := [OP_1, OP_CHECKLOCKTIMEVERIFY, OP_DROP, OP_1], spendHeight := BIP65, utxoHeight := 100, sequence := 0xfffffffe, block := E .unsatisfiedLocktime, mempool := E .unsatisfiedLocktime },
    { family := "eras/spend/csv/before", rule := "eras.height.csv", name := "OP_CHECKSEQUENCEVERIFY in block 419,327: a NOP without the flag", cite := "verify_script_flags.cpp:50–52; 563",
      lock := [OP_1, OP_CHECKSEQUENCEVERIFY, OP_DROP, OP_1], spendHeight := CSVH - 1, utxoHeight := 100, sequence := 0, block := V, mempool := E .unsatisfiedLocktime },
    { family := "eras/spend/csv/from", rule := "eras.height.csv", name := "the same spend in block 419,328: the sequence checked", cite := "verify_script_flags.cpp:50–52; 577–595",
      lock := [OP_1, OP_CHECKSEQUENCEVERIFY, OP_DROP, OP_1], spendHeight := CSVH, utxoHeight := 100, sequence := 0, block := E .unsatisfiedLocktime, mempool := E .unsatisfiedLocktime },
    -- STRICTENC and FORKID at uahfHeight (54–59 against the TIP's height: the fork block is 478,559)
    { family := "eras/spend/strictenc/before", rule := "eras.height.uahf", name := "an undefined hash-type byte (0x00) in block 478,558: no STRICTENC in the block word (the tip is 478,557)", cite := "verify_script_flags.cpp:54–59 (height >= uahfHeight); 291–294 not read",
      lock := pm (derSig 1 1 0x00) ++ pm pkG ++ [OP_CHECKSIG, OP_NOT], spendHeight := UAHF, utxoHeight := 100, block := V, mempool := E .sigHashtype },
    { family := "eras/spend/strictenc/from", rule := "eras.height.uahf", name := "the same spend in block 478,559: SCRIPT_ERR_SIG_HASHTYPE", cite := "verify_script_flags.cpp:54–59; 291–294; sighashtype.h:79–84",
      lock := pm (derSig 1 1 0x00) ++ pm pkG ++ [OP_CHECKSIG, OP_NOT], spendHeight := UAHF + 1, utxoHeight := 100, block := E .sigHashtype, mempool := E .sigHashtype },
    { family := "eras/spend/forkid/before", rule := "eras.height.uahf", name := "a hash type without the FORKID bit (0x01) in block 478,558: FORKID not enabled, the original digest", cite := "verify_script_flags.cpp:58; 2112–2124 (the original digest); 305–306 not read",
      lock := pm (derSig 1 1 0x01) ++ pm pkG ++ [OP_CHECKSIG, OP_NOT], spendHeight := UAHF, utxoHeight := 100, block := V, mempool := E .mustUseForkid },
    { family := "eras/spend/forkid/from", rule := "eras.height.uahf", name := "the same spend in block 478,559: SCRIPT_ERR_MUST_USE_FORKID", cite := "verify_script_flags.cpp:58; 2315–2319; 305–306",
      lock := pm (derSig 1 1 0x01) ++ pm pkG ++ [OP_CHECKSIG, OP_NOT], spendHeight := UAHF + 1, utxoHeight := 100, block := E .mustUseForkid, mempool := E .mustUseForkid },
    -- LOW_S and NULLFAIL at daaHeight (64–69 against the TIP's height: the fork block is 504,032)
    { family := "eras/spend/lows/before", rule := "eras.height.daa", name := "a high-S signature shape in block 504,031: no LOW_S in the block word (the tip is 504,030)", cite := "verify_script_flags.cpp:64–69 (height >= daaHeight); 282–287 not read",
      lock := pm (derSig 1 (Secp256k1.n - 1) 0x41) ++ pm pkG ++ [OP_CHECKSIG, OP_NOT], spendHeight := DAA, utxoHeight := 100, block := V, mempool := E .sigHighS },
    { family := "eras/spend/lows/from", rule := "eras.height.daa", name := "the same spend in block 504,032: SCRIPT_ERR_SIG_HIGH_S (the gate on: pre-Chronicle)", cite := "verify_script_flags.cpp:64–69; 282–287; pubkey.cpp:353–363",
      lock := pm (derSig 1 (Secp256k1.n - 1) 0x41) ++ pm pkG ++ [OP_CHECKSIG, OP_NOT], spendHeight := DAA + 1, utxoHeight := 100, block := E .sigHighS, mempool := E .sigHighS },
    { family := "eras/spend/nullfail/before", rule := "eras.height.daa", name := "a failing non-empty signature with OP_NOT in block 504,031: no NULLFAIL", cite := "verify_script_flags.cpp:64–69; 1491–1497 not read",
      lock := pm (derSig 1 1 0x41) ++ pm pkG ++ [OP_CHECKSIG, OP_NOT], spendHeight := DAA, utxoHeight := 100, block := V, mempool := E .sigNullfail },
    { family := "eras/spend/nullfail/from", rule := "eras.height.daa", name := "the same spend in block 504,032: SCRIPT_ERR_SIG_NULLFAIL", cite := "verify_script_flags.cpp:64–69; 1491–1497",
      lock := pm (derSig 1 1 0x41) ++ pm pkG ++ [OP_CHECKSIG, OP_NOT], spendHeight := DAA + 1, utxoHeight := 100, block := E .sigNullfail, mempool := E .sigNullfail },
    -- CHRONICLE by the spend era: the hash-type bit (302–303) and the version gate
    { family := "eras/spend/chronicle-bit/before", rule := "eras.spend.chronicle", name := "the CHRONICLE hash-type bit (0x61) in block 943,815: SCRIPT_ERR_ILLEGAL_CHRONICLE", cite := "verify_script_flags.cpp:77–78 (no SCRIPT_CHRONICLE); 296–303",
      lock := pm (derSig 1 1 0x61) ++ pm pkG ++ [OP_CHECKSIG, OP_NOT], spendHeight := C - 1, utxoHeight := G, block := E .illegalChronicle, mempool := E .illegalChronicle },
    { family := "eras/spend/chronicle-bit/from", rule := "eras.spend.chronicle", name := "the same spend in block 943,816, version 2: the bit is legal, the original digest is hashed (Q2), the failing signature passes OP_NOT without NULLFAIL (the gate off)", cite := "verify_script_flags.cpp:77–78; 2118 (the dispatch); 1491–1497 under the gate (40–44)",
      lock := pm (derSig 1 1 0x61) ++ pm pkG ++ [OP_CHECKSIG, OP_NOT], spendHeight := C, utxoHeight := G, block := V, mempool := V } ]

/-- The rows of #23: P2SH grandfathered for pre-Genesis coins, disabled for later ones, the
transaction-level output rule. -/
def p2shRows : List Row :=
  [ { family := "p2sh/grandfathered/valid", rule := "p2sh.grandfathered", name := "a pre-Genesis P2SH coin spent post-Chronicle: the redeem script OP_1 is evaluated and passes", cite := "2354–2356 (the copy), 2380–2424 (the block); the coin's era (411–427)",
      lock := p2shLock [OP_1], unlock := pm [OP_1], utxoHeight := G - 1, block := V, mempool := V },
    { family := "p2sh/grandfathered/redeem-fails", rule := "p2sh.grandfathered", name := "a pre-Genesis P2SH coin whose redeem script OP_0 fails: the hash matched, the spend is invalid", cite := "2418–2424: EVAL_FALSE after the redeem script",
      lock := p2shLock [OP_0], unlock := pm [OP_0], utxoHeight := G - 1, block := E .evalFalse, mempool := E .evalFalse },
    { family := "p2sh/disabled/hash-puzzle", rule := "p2sh.disabled", name := "the same P2SH-shaped lock on a coin created after Genesis: a hash puzzle, the redeem script never runs", cite := "2355, 2383 (SCRIPT_UTXO_AFTER_GENESIS); 2358–2378; phase2_p2sh_disabled_postGenesis",
      lock := p2shLock [OP_0], unlock := pm [OP_0], utxoHeight := G, block := V, mempool := V },
    { family := "p2sh/grandfathered/redeem-op-return", rule := "p2sh.grandfathered", name := "the redeem script of a pre-Genesis P2SH coin runs under the pre-Genesis rules: OP_RETURN fails", cite := "2402–2412 with the same flags; 867–869",
      lock := p2shLock [OP_1, OP_RETURN], unlock := pm [OP_1, OP_RETURN], utxoHeight := G - 1, block := E .opReturn, mempool := E .opReturn },
    { family := "p2sh/disabled/redeem-op-return", rule := "p2sh.disabled", name := "the same lock on a post-Genesis coin: the pushed bytes are data, the hash puzzle passes", cite := "2355; 2358–2378",
      lock := p2shLock [OP_1, OP_RETURN], unlock := pm [OP_1, OP_RETURN], utxoHeight := G, block := V, mempool := V },
    { family := "p2sh/grandfathered/non-push-unlock", rule := "p2sh.pushonly", name := "a non-push unlocking script on a pre-Genesis P2SH coin, version 2 post-Chronicle: the P2SH path's own push-only demand", cite := "2385–2387 (whatever the version gate at 2321–2334 said)",
      lock := p2shLock [OP_1], unlock := [1, OP_1, OP_DUP, OP_DROP], utxoHeight := G - 1, block := E .sigPushonly, mempool := E .sigPushonly },
    { family := "p2sh/disabled/non-push-unlock", rule := "p2sh.disabled", name := "the same non-push unlocking script on a post-Genesis P2SH-shaped coin, version 2 post-Chronicle: no P2SH path, the gate lifts push-only", cite := "2383; 2326–2327",
      lock := p2shLock [OP_1], unlock := [1, OP_1, OP_DUP, OP_DROP], utxoHeight := G, block := V, mempool := V },
    { family := "p2sh/grandfathered/redeem-args", rule := "p2sh.grandfathered", name := "the redeem script reads the arguments under it on the restored stack: 1 2 OP_ADD 3 OP_EQUAL", cite := "2393–2400 (the copy restored, the redeem script popped), 2402–2416",
      lock := p2shLock [OP_ADD, OP_3, OP_EQUAL], unlock := [OP_1, OP_2] ++ pm [OP_ADD, OP_3, OP_EQUAL], utxoHeight := G - 1, block := V, mempool := V },
    { family := "p2sh-txlevel/output/post-genesis", rule := "p2sh.output.post-genesis", name := "a regular transaction with a P2SH-shaped output in the Genesis era: invalid at the transaction level (bad-txns-vout-p2sh), the scripts valid", cite := "validation.cpp:609–622 (DoS 100, REJECT_INVALID); the era of the spend height (1032)",
      lock := [OP_1], outputs := [{ value := 1, scriptPubKey := p2shLock [OP_1] }], utxoHeight := G, block := V, mempool := V, txLevel := some (.error .p2shOutput) },
    { family := "p2sh-txlevel/output/pre-genesis", rule := "p2sh.output.post-genesis", name := "the same transaction in the pre-Genesis era: the output rule is not yet active", cite := "validation.cpp:610 (IsProtocolActive(era, Genesis))",
      lock := [OP_1], outputs := [{ value := 1, scriptPubKey := p2shLock [OP_1] }], spendHeight := G - 1, utxoHeight := 100, block := V, mempool := V, txLevel := some (.ok ()) } ]

def rows : List Row := coinRows ++ spendRows ++ p2shRows

/-! ## The transactions -/

def pad5 (n : Nat) : String :=
  let s := toString n
  String.ofList (List.replicate (5 - s.length) '0') ++ s

def rowId (i : Nat) : String := s!"eras-{pad5 (i + 1)}"

def utf8 (s : String) : Bytes := s.toUTF8.toList.map (·.toNat)

/-- The synthetic outpoint of a row: the SHA-256 of the entry id (internal byte order),
never a real transaction (`corpus/INDEX.md` §1). -/
def outpointOf (id : String) : Bytes := sha256 (utf8 ("bsv-script-lean/corpus/eras/" ++ id))

def mkTx (id : String) (r : Row) : Tx :=
  { version := r.version,
    inputs := [{ prevHash := outpointOf id, prevIndex := 0, scriptSig := r.unlock, sequence := r.sequence }],
    outputs := r.outputs, lockTime := r.lockTime }

/-- The era label of a spend height (`corpus.rs` `ParamsJson::era_of`). -/
def eraLabel (h : Nat) : String :=
  if h ≥ C then "post-chronicle" else if h ≥ G then "post-genesis" else "pre-genesis"

def codeOf : Verdict → String
  | .valid => "valid"
  | .invalid e => e.name
  | .unimplemented op => s!"unimplemented 0x{String.ofList (Nat.toDigits 16 op)}"
  | .undefinedInReference f => s!"undefined-in-reference ({f})"

def txRejectName : TxReject → String
  | .vinEmpty => "bad-txns-vin-empty" | .voutEmpty => "bad-txns-vout-empty" | .oversize => "bad-txns-oversize"
  | .voutNegative => "bad-txns-vout-negative" | .voutTooLarge => "bad-txns-vout-toolarge"
  | .txoutTotalTooLarge => "bad-txns-txouttotal-toolarge" | .sigops => "bad-txn-sigops"
  | .coinbaseWhereRegular => "bad-tx-coinbase" | .coinbaseMissing => "bad-cb-missing"
  | .coinbaseLength => "bad-cb-length" | .prevoutNull => "bad-txns-prevout-null"
  | .inputsDuplicate => "bad-txns-inputs-duplicate" | .p2shOutput => "bad-txns-vout-p2sh"

def txLevelShow : Except TxReject Unit → String
  | .ok () => "valid"
  | .error e => s!"invalid {txRejectName e}"

/-- `CheckRegularTransaction` under the spend height's era with the pre-Genesis consensus
limits the reference's vector runner uses (`TxRules`). -/
def txLevelOf (r : Row) (tx : Tx) : Except TxReject Unit :=
  checkRegularTransaction tx MAX_TX_SIGOPS_COUNT_BEFORE_GENESIS MAX_TX_SIZE_CONSENSUS_BEFORE_GENESIS (r.spendHeight < G)

/-! ## The leg -/

def decide (r : Row) (tx : Tx) (consensus : Bool) : Verdict :=
  let cfg := NodeConfig.svMainnetDefault
  let p := derive cfg r.spendHeight r.utxoHeight consensus
  let ctx := txContext tx 0 1000
  Eval.verifyScript p ctx r.unlock r.lock

def runLeg : IO UInt32 := do
  let mut ok := true
  let mut cells := 0
  let mut txLevelRows := 0
  let mut byFamily : Std.HashMap String Nat := {}
  let mut i := 0
  for r in rows do
    let id := rowId i
    i := i + 1
    let tx := mkTx id r
    let vB := decide r tx true
    let vM := decide r tx false
    let head := (r.family.splitOn "/").headD r.family
    byFamily := byFamily.insert head (byFamily.getD head 0 + 2)
    cells := cells + 2
    if vB != r.block then
      ok := false
      IO.println s!"MISMATCH {id} {r.family} block: expected {codeOf r.block}, got {codeOf vB} ({r.name}; {r.cite})"
    if vM != r.mempool then
      ok := false
      IO.println s!"MISMATCH {id} {r.family} mempool: expected {codeOf r.mempool}, got {codeOf vM} ({r.name}; {r.cite})"
    if let some expected := r.txLevel then
      txLevelRows := txLevelRows + 1
      let got := txLevelOf r tx
      if got != expected then
        ok := false
        IO.println s!"MISMATCH {id} {r.family} transaction level: expected {txLevelShow expected}, got {txLevelShow got} ({r.name}; {r.cite})"
  let fams := byFamily.toList.mergeSort (fun a b => a.1 ≤ b.1) |>.map (fun (k, c) => s!"{k} {c}") |> String.intercalate ", "
  IO.println s!"erascheck: {rows.length} rows × 2 cells = {cells} cells decided under Params.derive (SV-node's mainnet defaults, block and mempool) with the error code ({fams}); {txLevelRows} rows decided at the transaction level (CheckRegularTransaction): {if ok then "0 mismatches" else "MISMATCHES"}"
  return (if ok then 0 else 1)

/-! ## The corpus writer (`--write-corpus <dir>`) -/

def hexOf (bs : Bytes) : String := hexEncode bs

def entryJson (id : String) (r : Row) (tx : Tx) : Json :=
  let txid := outpointOf id
  let expectRef := s!"block path: {codeOf r.block}; mempool path: {codeOf r.mempool}" ++
    (match r.txLevel with | some t => s!"; transaction level: {txLevelShow t}" | none => "")
  Json.mkObj
    [ ("id", id), ("family", r.family), ("rule", r.rule),
      ("tx", hexOf (Sighash.serTx tx)),
      ("prevouts", Json.arr #[Json.mkObj
        [ ("txid", hexOf txid.reverse), ("vout", (0 : Nat)), ("script", hexOf r.lock), ("satoshis", (1000 : Nat)), ("height", r.utxoHeight) ]]),
      ("params", Json.mkObj [("spend_height", r.spendHeight), ("era", eraLabel r.spendHeight), ("consensus", true), ("tx_version", r.version)]),
      ("expect", Json.mkObj []),
      ("reference", Json.mkObj [("model", "bitcoin-sv v1.2.3 at the pin, read at the cited lines (lean/Test/ErasCheck.lean, the row's cite; the leg decides the spec agrees)"), ("expect", expectRef)]),
      ("note", s!"{r.name} [{r.cite}]") ]

def writeCorpus (dir : String) : IO UInt32 := do
  let mut lines : Array String := #[]
  let mut families : Std.HashMap String Nat := {}
  let mut rulesH : Std.HashMap String Nat := {}
  let mut i := 0
  for r in rows do
    let id := rowId i
    i := i + 1
    let tx := mkTx id r
    lines := lines.push (entryJson id r tx).compress
    families := families.insert r.family (families.getD r.family 0 + 1)
    rulesH := rulesH.insert r.rule (rulesH.getD r.rule 0 + 1)
  let text := String.intercalate "\n" lines.toList ++ "\n"
  IO.FS.writeFile (dir ++ "/eras.jsonl") text
  let sha := hexOf (sha256 (utf8 text))
  let hist (m : Std.HashMap String Nat) : Json :=
    Json.mkObj (m.toList.mergeSort (fun a b => a.1 ≤ b.1) |>.map (fun (k, c) => (k, (Json.num c))))
  let manifest := Json.mkObj
    [ ("corpus", "eras"), ("file", "eras.jsonl"),
      ("generator", "lean/Test/ErasCheck.lean --write-corpus (the hand-written table of #20 and #23: the era boundaries, the activation heights, P2SH; bsv-script-lean)"),
      ("seed", "none (hand-written)"), ("count", rows.length), ("sha256", sha),
      ("families", hist families), ("rules", hist rulesH), ("verdicts", Json.mkObj []),
      -- the bsv-rs runner reads the word PER INPUT from the heights (`harness/src/engine.rs` `word_for`;
      -- `run_bsvrs --record` fills the version, the verdicts and the rest of the configuration)
      ("implementations", Json.arr #[Json.mkObj [("name", "bsv-rs"), ("version", "recorded by run_bsvrs --record"),
                                                ("config", Json.mkObj [("words", "per-input")])]]),
      ("engine_executions", (0 : Nat)), ("generated", "2026-09-23"),
      ("provenance", "hand-written from bitcoin-sv v1.2.3 at the pin (docs/PROVENANCE.md); every outpoint synthetic (the SHA-256 of the entry id); no transaction of any private program") ]
  IO.FS.writeFile (dir ++ "/manifest.json") (manifest.pretty ++ "\n")
  IO.println s!"erascheck: wrote {rows.length} entries to {dir}/eras.jsonl (sha256 {sha}) and {dir}/manifest.json"
  return 0

def main (args : List String) : IO UInt32 := do
  match args with
  | ["--write-corpus", dir] => writeCorpus dir
  | _ => runLeg
