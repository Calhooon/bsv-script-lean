import BsvScript.Sighash
import BsvScript.Params
import Test.OpNames
import Test.Common
/-!
# The reference's test notation

`ParseScript` (`src/core_read.cpp:37–174`) and `ParseScriptFlags`
(`src/test/scriptflags.cpp:14–56`), shared by the script and transaction vector
runners.
-/

namespace BsvScript.Test
open BsvScript BsvScript.Params BsvScript.Numbers BsvScript.Tx

/-- `push_int64` (`src/script/script.cpp:228–245`): `-1` and `1`…`16` are the
constant opcodes, `0` is `OP_0`, anything else the minimal push of the
serialized `int64`. -/
def pushInt64 (n : Int) : Bytes :=
  if n = -1 ∨ (1 ≤ n ∧ n ≤ 16) then [(n + (Op.OP_1 - 1 : Nat)).toNat]
  else if n = 0 then [Op.OP_0]
  else Sighash.pushData (encode n)

def isDecimal (w : String) : Bool :=
  let s := if w.startsWith "-" then w.drop 1 else w
  !s.isEmpty && s.all Char.isDigit

/-- `ParseScript` (`core_read.cpp:37–174`): a decimal word is `push_int64`;
`0x…` is raw bytes inserted, not pushed (`86–90`); a single-quoted word is
pushed as data (`94–101`); a name is its opcode (`104–108`). -/
def parseScript (s : String) : Except String Bytes := do
  let mut out : Bytes := []
  for w in ((s.replace "\t" " ").replace "\n" " ").splitOn " " do
    if w.isEmpty then continue
    if isDecimal w then
      match w.toInt? with
      | some n => out := out ++ pushInt64 n
      | none => throw s!"bad decimal {w}"
    else if w.startsWith "0x" && w.length > 2 then
      match hexDecode (String.ofList (w.toList.drop 2)) with
      | some b => out := out ++ b
      | none => throw s!"bad hex {w}"
    else if w.length ≥ 2 && w.startsWith "'" && w.endsWith "'" then
      out := out ++ Sighash.pushData ((String.ofList (w.toList.drop 1).dropLast).toUTF8.toList.map (·.toNat))
    else
      match opNames.lookup w with
      | some b => out := out ++ [b]
      | none => throw s!"unknown word {w}"
  pure out

/-- `mapFlagNames` (`src/test/scriptflags.cpp:14–36`). -/
def setFlag (f : Flags) : String → Except String Flags
  | "NONE" => pure f
  | "P2SH" => pure { f with p2sh := true }
  | "STRICTENC" => pure { f with strictEnc := true }
  | "DERSIG" => pure { f with derSig := true }
  | "LOW_S" => pure { f with lowS := true }
  | "SIGPUSHONLY" => pure { f with sigPushOnly := true }
  | "MINIMALDATA" => pure { f with minimalData := true }
  | "NULLDUMMY" => pure { f with nullDummy := true }
  | "DISCOURAGE_UPGRADABLE_NOPS" => pure { f with discourageUpgradableNops := true }
  | "CLEANSTACK" => pure { f with cleanStack := true }
  | "MINIMALIF" => pure { f with minimalIf := true }
  | "NULLFAIL" => pure { f with nullFail := true }
  | "CHECKLOCKTIMEVERIFY" => pure { f with checkLockTimeVerify := true }
  | "CHECKSEQUENCEVERIFY" => pure { f with checkSequenceVerify := true }
  | "COMPRESSED_PUBKEYTYPE" => pure { f with compressedPubKeyType := true }
  | "SIGHASH_FORKID" => pure { f with enableSighashForkid := true }
  | "GENESIS" => pure { f with genesis := true }
  | "UTXO_AFTER_GENESIS" => pure { f with utxoAfterGenesis := true }
  | "CHRONICLE" => pure { f with chronicle := true }
  | "UTXO_AFTER_CHRONICLE" => pure { f with utxoAfterChronicle := true }
  | w => throw s!"unknown flag {w}"

/-- `ParseScriptFlags` (`scriptflags.cpp:40–56`): comma-separated names; empty is none. -/
def parseFlagWord (s : String) : Except String Flags := do
  let mut f := noFlags
  if !s.isEmpty then
    for w in s.splitOn "," do
      f ← setFlag f w
  pure f

end BsvScript.Test
