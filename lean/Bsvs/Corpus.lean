import BsvScript.Tx
import BsvScript.Params
import Lean.Data.Json
/-!
# Bsvs.Corpus: the corpus entry as the CLI reads it (#14; `docs/DESIGN.md` §6)

One JSON object per line: `id`, `family`, `rule`, `tx` (hex), `prevouts`
(aligned with the inputs: `txid`, `vout`, `script`, `satoshis`, `height`),
`params` (`spend_height`, `era`, `consensus`, `tx_version`), an optional
explicit `flags` word per input, `expect` keyed by `name@version`, an optional
`note`, and the harness's own `reference` and `divergence`. The harness's `corpus.rs` writes it; the CLI's
`eval` mode takes the same `prevouts` array on the command line.

The reader is strict where the reference's is (lean #32's second lens, findings B-2 and B-8, and its re-lens,
BN-5 and BN-6): an unknown key in an entry, its `params`, a prevout or an expectation is refused, never ignored,
as the `verifyscript` RPC's `RPCTypeCheckObj(…, true, true)` refuses one (`rpc/misc.cpp:736–742`); a prevout's
satoshis above `int64`'s maximum, a height at `MEMPOOL_HEIGHT` or above, a spend height of 0, a prevout created
after the spend's block and a flag word of 32 bits or more are refused; and a number that is not a plain decimal
integer (`1e3`, `1.5e1`, which Lean's JSON reader folds into an integer) is refused, as the reference's
`get_int`/`get_int64` refuse it (`univalue_get.cpp:104–121`: `strtol`/`strtoll` must consume the whole text,
`30–58`). Every refusal names the file's line; after the JSON parse it names the entry's `id` too, and the field or
the object it concerns (a missing or mistyped field by its key, an unknown key by its object; its re-lens 2, B2N-3).
Two spellings differ from the RPC's, the words not (B2N-4): the flag word is a `uint32_t` in both, spelled here
unsigned, 0 to 2^32 − 1, where the RPC reads it with `get_int`, a signed 32-bit read, and casts it
(`rpc/misc.cpp:702`, `univalue_get.cpp:104–112`), so it takes the high words spelled negative and refuses them spelled
unsigned; and a duplicate key is
read here as its last value (Lean's parser keeps the last), in the RPC as its first (`univalue_read.cpp:438`,
`univalue.cpp:168–178`, `198–208`). No committed entry carries a flag word or a duplicate key. The prevouts pair with the inputs by position, as the RPC's
`txo` carries no outpoint (`rpc/misc.cpp:730–788`): a prevout's `txid` and `vout` are the entry's record of the
outpoint, not checked against the input's.
-/

namespace Bsvs.Corpus
open BsvScript BsvScript.Numbers BsvScript.Tx
open Lean

structure Prevout where
  /-- display-order hex, as explorers show it -/
  txid : String
  vout : Nat
  script : Bytes
  satoshis : Nat
  /-- the height of the block that created the output (selects the UTXO's era) -/
  height : Nat
  deriving Repr

structure Expect where
  verdict : String
  code : Option String
  reason : Option String
  input : Option Nat
  deriving Repr

structure Entry where
  id : String
  family : String
  rule : String
  txHex : String
  tx : Tx
  prevouts : List Prevout
  spendHeight : Nat
  consensus : Bool
  txVersion : Int
  flags : Option (List Nat)
  expect : List (String × Expect)
  note : Option String
  raw : Json

/-- The largest satoshi value a coin can carry: `Amount` is an `int64_t`, and the `verifyscript` RPC reads
`txo.value` with `get_int64` and refuses a negative one (`rpc/misc.cpp:762–766`). -/
def satoshisMax : Nat := 9223372036854775807

/-- `MEMPOOL_HEIGHT` (`protocol_era.h:14`), the height a coin in the memory pool carries. It is not a
height: every caller substitutes the next block's height before the era is read (`rpc/misc.cpp:784–787` then
`806–812`; `validation.cpp:2667–2674`). The reader cannot know the tip, so it refuses this value and every
height above it. -/
def mempoolHeight : Nat := 0x7FFFFFFF

/-- The keys an object may carry: an unexpected key is refused (`rpc/misc.cpp:736–742`). The caller names
the object. -/
def onlyKeys (j : Json) (allowed : List String) : Except String Unit :=
  match j with
  | .obj kvs =>
    match kvs.toList.find? (fun (k, _) => !allowed.contains k) with
    | some (k, _) => throw s!"unexpected key {k}"
    | none => pure ()
  | _ => throw "not an object"

/-- Every number of a line's JSON text, outside its strings, is a plain decimal integer (an optional `-` and
digits): the reference reads its integers with `get_int`/`get_int64` (`univalue_get.cpp:104–121`), whose
`ParseInt32`/`ParseInt64` require `strtol`/`strtoll` to consume the whole text (`30–58`), so a fraction or an
exponent is refused there; Lean's JSON reader would fold `1e3` into 1000 and `1.5e1` into 15. -/
def plainIntegers (text : String) : Except String Unit := Id.run do
  let bs := text.toUTF8
  let mut inStr := false
  let mut esc := false
  let mut inNum := false
  for i in [0:bs.size] do
    let b := bs.get! i
    if inStr then
      if esc then esc := false
      else if b == 92 then esc := true
      else if b == 34 then inStr := false
    else if b == 34 then
      inStr := true
      inNum := false
    else if (48 ≤ b && b ≤ 57) || b == 45 then
      inNum := true
    else if inNum && (b == 46 || b == 101 || b == 69 || b == 43) then
      return .error s!"the number at byte {i} is not a plain decimal integer (a fraction or an exponent), which the reference's get_int and get_int64 refuse (univalue_get.cpp:30–58, 104–121)"
    else
      inNum := false
  return .ok ()

/-- A required field, its refusal naming the key (lean #32's re-lens 2, B2N-3). -/
def field (α : Type) [FromJson α] (j : Json) (k : String) : Except String α :=
  (j.getObjValAs? α k).mapError (s!"{k}: " ++ ·)

/-- An optional field: absent or `null` is none; present, it must read, its refusal naming the key. -/
def optField (α : Type) [FromJson α] (j : Json) (k : String) : Except String (Option α) :=
  match j.getObjVal? k with
  | .error _ => pure none
  | .ok .null => pure none
  | .ok v => (fromJson? v).map some |>.mapError (s!"{k}: " ++ ·)

def getNat (j : Json) (what : String) : Except String Nat :=
  match j.getNat? with
  | .ok n => pure n
  | .error e => throw s!"{what}: {e}"

def getStr (j : Json) (what : String) : Except String String :=
  match j.getStr? with
  | .ok s => pure s
  | .error e => throw s!"{what}: {e}"

def hexBytes (s : String) (what : String) : Except String Bytes :=
  match hexDecode s with
  | some b => pure b
  | none => throw s!"{what}: bad hex"

def parsePrevout (j : Json) : Except String Prevout := do
  onlyKeys j ["txid", "vout", "script", "satoshis", "height"]
  let txid ← field String j "txid"
  let vout ← field Nat j "vout"
  let script ← hexBytes (← field String j "script") "script"
  let satoshis ← field Nat j "satoshis"
  let height ← field Nat j "height"
  if satoshisMax < satoshis then
    throw s!"satoshis {satoshis}: above int64's maximum {satoshisMax}, no coin carries it (rpc/misc.cpp:762–766)"
  if mempoolHeight ≤ height then
    throw s!"height {height}: MEMPOOL_HEIGHT (0x7FFFFFFF) or above is not a height; give the height it stands for (protocol_era.h:14, rpc/misc.cpp:803–809)"
  pure { txid, vout, script, satoshis, height }

/-- Every prevout's height against the spend's (a coin is created in the spend's block or before it), and the
spend height itself (at least 1: no transaction spends in the genesis block; below `MEMPOOL_HEIGHT`). -/
def checkHeights (spendHeight : Nat) (prevouts : List Prevout) : Except String Unit := do
  if spendHeight = 0 then throw "spend height 0: no transaction spends in the genesis block"
  if mempoolHeight ≤ spendHeight then
    throw s!"spend height {spendHeight}: MEMPOOL_HEIGHT (0x7FFFFFFF) or above is not a height"
  for pr in prevouts do
    if spendHeight < pr.height then
      throw s!"prevout height {pr.height} above the spend height {spendHeight}: a coin is created in the spend's block or before it"

/-- The `prevouts` array (the corpus field and the CLI's `--prevouts`); a refusal names the prevout's index. -/
def parsePrevouts (j : Json) : Except String (List Prevout) := do
  let arr ← j.getArr?
  let mut out : Array Prevout := #[]
  for i in [0:arr.size] do
    out := out.push (← (parsePrevout arr[i]!).mapError (s!"prevout {i}: " ++ ·))
  pure out.toList

def parseExpect (j : Json) : Except String Expect := do
  onlyKeys j ["verdict", "code", "reason", "input"]
  let verdict ← field String j "verdict"
  let code ← optField String j "code"
  let reason ← optField String j "reason"
  let input ← optField Nat j "input"
  pure { verdict, code, reason, input }

/-- An entry's fields once its `id` is read; `parseEntry` names the entry in every refusal. -/
def parseEntryBody (id : String) (j : Json) : Except String Entry := do
  onlyKeys j ["id", "family", "rule", "tx", "prevouts", "params", "flags", "expect", "note", "reference", "divergence"]
  let family ← field String j "family"
  let rule ← field String j "rule"
  let txHex ← field String j "tx"
  let txBytes ← hexBytes txHex "tx"
  let tx ← match decodeTx txBytes with | some t => pure t | none => throw "tx frame"
  let prevouts ← (parsePrevouts (← j.getObjVal? "prevouts")).mapError ("prevouts: " ++ ·)
  let params ← j.getObjVal? "params"
  (onlyKeys params ["spend_height", "era", "consensus", "tx_version"]).mapError ("params: " ++ ·)
  let spendHeight ← (field Nat params "spend_height").mapError ("params: " ++ ·)
  let consensus ← (field Bool params "consensus").mapError ("params: " ++ ·)
  let txVersion ← (field Int params "tx_version").mapError ("params: " ++ ·)
  let flags ← match j.getObjVal? "flags" with
    | .ok f => match f.getArr? with
      | .ok arr => do
        let ws ← arr.toList.mapM (fun w => getNat w "flags")
        if let some w := ws.find? (fun w => 2 ^ 32 ≤ w) then
          throw s!"flag word {w} does not fit 32 bits (rpc/misc.cpp:702)"
        pure (some ws)
      | .error e => throw s!"flags: {e}"
    | .error _ => pure none
  let expectJ ← j.getObjVal? "expect"
  let expect ← match expectJ with
    | .obj kvs => kvs.toList.mapM (fun (k, v) => do
        let e ← (parseExpect v).mapError (s!"expect {k}: " ++ ·)
        pure (k, e))
    | _ => throw "expect is not an object"
  let note ← optField String j "note"
  if tx.inputs.length != prevouts.length then throw s!"{tx.inputs.length} inputs but {prevouts.length} prevouts"
  checkHeights spendHeight prevouts
  if let some ws := flags then
    if ws.length != tx.inputs.length then throw s!"{tx.inputs.length} inputs but {ws.length} flag words"
  pure { id, family, rule, txHex, tx, prevouts, spendHeight, consensus, txVersion, flags, expect, note, raw := j }

/-- One entry: its `id` first, then its fields, every refusal prefixed with the `id` (lean #32's re-lens, BN-5). -/
def parseEntry (j : Json) : Except String Entry := do
  let id ← (j.getObjValAs? String "id").mapError (s!"an entry without a string id: " ++ ·)
  (parseEntryBody id j).mapError (s!"{id}: " ++ ·)

/-- Every entry of a `.jsonl` file (blank lines skipped); a refusal names the line, and after the JSON parse also the
entry's `id` and the field or object. -/
def readEntries (path : String) : IO (List Entry) := do
  let lines ← IO.FS.lines path
  let mut out : Array Entry := #[]
  let mut n := 0
  for line in lines do
    n := n + 1
    if line.trimAscii.isEmpty then continue
    match plainIntegers line with
    | .ok () => pure ()
    | .error e => throw (IO.userError s!"{path}:{n}: {e}")
    let j ← match Json.parse line with | .ok j => pure j | .error e => throw (IO.userError s!"{path}:{n}: json: {e}")
    let e ← match parseEntry j with | .ok e => pure e | .error e => throw (IO.userError s!"{path}:{n}: {e}")
    out := out.push e
  pure out.toList

end Bsvs.Corpus
