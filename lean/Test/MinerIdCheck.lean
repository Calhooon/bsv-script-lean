import BsvChain.Views.MinerId
import Lean.Data.Json

/-!
# The Miner ID check (#83)

[M] 2026-10-15 (#83). Two parts, run by `chaincheck --minerid <file>`.

The mainnet part reads `corpus/minerid/coinbase-docs.jsonl` (mainnet coinbase documents,
public reads by URL, read only, rule 10) and checks per row: the coinbase transaction's
id is the row's; the 0.1/0.2 output frame reads and re-encodes to the same bytes; the
static document reads as JSON and its compact write is the pushed bytes (the text every
signature is over); `extractMinerId` under the node's verifier
(`BsvScript.Crypto.Secp256k1.verify`) accepts it at the block's height with the row's
version and keys; `findMinerId` over the whole coinbase finds it; the same output at the
next height and with its signature's last byte changed are refused. Nothing of Miner ID
is consensus (cited in `lean/BsvChain/Views/MinerId.lean`'s header); these are checks of
the node's index views.

The synthetic part [D] runs the 0.3 path, the `revokemid` codec and the database with
fixed inputs: the frames' round trips, every coded error the 0.3 document parser
returns in the reference's order (under a verifier that accepts every signature, so
the order of the structural checks is what is tested), and a rotation and a partial
revocation through the database.
-/

open Lean BsvScript.Numbers BsvScript.Tx BsvChain.Views.MinerId

namespace MinerIdCheck

def need (x : Option α) (message : String) : Except String α :=
  match x with | some a => .ok a | none => .error message

def str (j : Json) (k : String) : Except String String := j.getObjValAs? String k

def isOk [BEq α] (x : Except Fault α) (a : α) : Bool := match x with | .ok b => b == a | .error _ => false

def isErr (x : Except Fault α) (e : MinerInfoError) : Bool := match x with | .error (.code c) => c == e | _ => false

/-- One mainnet row: the checks above; the result names the height and the miner id. -/
def mainnetRow (j : Json) : Except String (Nat × String) := do
  unless (← str j "label").startsWith "[M] mainnet" do throw "label"
  let height ← j.getObjValAs? Nat "height"
  let script ← need (hexDecode (← str j "script")) "script hex"
  let raw ← need (hexDecode (← str j "coinbase_hex")) "coinbase hex"
  let cb ← need (decodeTx raw) "coinbase decode"
  let txidHex ← str j "coinbase_txid"
  unless hexEncode (BsvScript.Sighash.txid cb).reverse == txidHex do throw "coinbase txid"
  let vout ← j.getObjValAs? Nat "vout"
  unless (cb.outputs[vout]?.map (·.scriptPubKey)) == some script do throw "output script"
  let expect ← j.getObjVal? "expect"
  -- the frame
  let o ← need (MinerIdOutput.decode script) "frame decode"
  unless o.encode == script do throw "frame round trip"
  -- the JSON text
  let doc ← need (readJson o.staticDoc) "static document JSON"
  unless write doc == o.staticDoc do throw "JSON round trip (compact write)"
  -- the node's checks
  let d ← match extractMinerId nodeVerifier script height with
    | .ok d => pure d
    | .error f => throw s!"node check refused: {repr f}"
  unless d.version == ascii (← str expect "version") && d.minerId == ascii (← str expect "minerId") &&
      d.prevMinerId == ascii (← str expect "prevMinerId") && d.height == height do throw "document fields"
  let found ← need (findMinerId nodeVerifier ⟨[cb], []⟩ height) "findMinerId"
  unless found.doc.minerId == d.minerId && found.minerInfoTx.isNone do throw "findMinerId answer"
  -- the refusals
  match extractMinerId nodeVerifier script (height + 1) with
  | .ok _ => throw "accepted at the next height"
  | .error _ => pure ()
  let flipped := o.staticSig.dropLast ++ [(o.staticSig.getLast?.getD 0) ^^^ 1]
  match extractMinerId nodeVerifier { o with staticSig := flipped }.encode height with
  | .ok _ => throw "accepted with a changed signature"
  | .error _ => pure ()
  return (height, (← str expect "minerId"))

/-! ## The synthetic part [D] -/

def acceptAll : Verifier := fun _ _ _ => true

def key1 : String := "03e92d3e5c3f7bd945dfbf48e7a99393b1bfb3f11f380ae30d286e7ff2aec5a270"
def key2 : String := "02" ++ String.ofList (List.replicate 64 '1')
def sigHex : String := "3045022100" ++ String.ofList (List.replicate 64 'a') ++ "0220" ++ String.ofList (List.replicate 64 'b')

/-- [D] a 0.3 miner-info document with the eight required fields. -/
def infoDoc (extra : List (String × Json) := []) (drop : List String := []) : String :=
  let base : List (String × Json) :=
    [("version", "0.3"), ("height", (700000 : Nat)), ("minerId", key1), ("prevMinerId", key1),
     ("prevMinerIdSig", sigHex), ("revocationKey", key2), ("prevRevocationKey", key2),
     ("prevRevocationKeySig", sigHex)]
  (Json.mkObj ((base.filter fun (k, _) => !drop.contains k) ++ extra)).compress

def codeOf (raw : String) : Option MinerInfoError :=
  match parseMinerInfoDoc acceptAll (ascii raw) with
  | .error (.code e) => some e
  | _ => none

/-- [D] each coded error at its place in the reference's order
(src/miner_id/miner_info_doc.cpp:313-442 at 6504a3af). -/
def docCases : List (String × String × Option MinerInfoError) :=
  [ ("accepts the base document", infoDoc, none),
    ("ill-formed JSON", "{\"version\":", some .docIllFormedJson),
    ("a missing field", infoDoc [] ["revocationKey"], some .docMissingFields),
    ("a number where a string is due", infoDoc [("minerId", (5 : Nat))] ["minerId"], some .docInvalidStringType),
    ("a string height", infoDoc [("height", "700000")] ["height"], some .docInvalidNumberType),
    ("version 0.2", infoDoc [("version", "0.2")] ["version"], some .docUnsupportedVersion),
    ("height 0", infoDoc [("height", (0 : Nat))] ["height"], some .docInvalidHeight),
    ("height 1.5", infoDoc [("height", Json.num ⟨15, 1⟩)] ["height"], some .docInvalidHeight),
    ("an uncompressed minerId", infoDoc [("minerId", "04" ++ (key1.drop 2).toString)] ["minerId"], some .docInvalidMinerId),
    ("a short prevMinerIdSig", infoDoc [("prevMinerIdSig", "3045")] ["prevMinerIdSig"], some .docInvalidPrevMinerIdSig),
    ("a bad revocationKey", infoDoc [("revocationKey", "zz")] ["revocationKey"], some .docInvalidRevocationKey),
    ("a message without its signatures", infoDoc [("revocationMessage", Json.mkObj [("compromised_minerId", key1)])], some .docRevMsgFields),
    ("a message whose key is not a string",
      infoDoc [("revocationMessage", Json.mkObj [("compromised_minerId", (1 : Nat))]),
               ("revocationMessageSig", Json.mkObj [("sig1", sigHex), ("sig2", sigHex)])], some .docRevMsgField),
    ("a message without sig2",
      infoDoc [("revocationMessage", Json.mkObj [("compromised_minerId", key1)]),
               ("revocationMessageSig", Json.mkObj [("sig1", sigHex)])], some .docRevMsgSig2),
    ("a full message", infoDoc [("revocationMessage", Json.mkObj [("compromised_minerId", key1)]),
               ("revocationMessageSig", Json.mkObj [("sig1", sigHex), ("sig2", sigHex)])], none),
    ("dataRefs not an object", infoDoc [("extensions", Json.mkObj [("dataRefs", (1 : Nat))])], some .datarefsInvalidDatarefsType),
    ("a dataref txid that is not 64 hex", infoDoc [("extensions", Json.mkObj [("dataRefs", Json.mkObj [("refs",
        Json.arr #[Json.mkObj [("brfcIds", Json.arr #["62b21572ca46"]), ("txid", "abc"), ("vout", (0 : Nat))]])])])],
      some .datarefsRefsTxidType),
    ("a dataref without vout", infoDoc [("extensions", Json.mkObj [("dataRefs", Json.mkObj [("refs",
        Json.arr #[Json.mkObj [("brfcIds", Json.arr #[]), ("txid", (key1.drop 2).toString)]])])])],
      some .datarefsDatarefMissingFields) ]

/-- [D] the reference frame's refusals (src/miner_id/miner_info_ref.cpp:60-114 at 6504a3af). -/
def refCases : List (String × Bytes × Option MinerInfoError) :=
  let t := List.replicate 32 7
  let s := List.replicate 70 9
  [ ("a well-formed reference", MinerInfoRef.encode ⟨t, t, s⟩, none),
    ("version 1", frameHead minerInfoProtocolId ++ [1, 1] ++ BsvScript.Sighash.pushData t, some .scriptVersionUnsupported),
    ("a 31-byte txid", MinerInfoRef.encode ⟨t.drop 1, t, s⟩, some .invalidTxidLen),
    ("a 63-byte signature", MinerInfoRef.encode ⟨t, t, s.drop 7⟩, some .invalidSigLen),
    ("a 73-byte signature", MinerInfoRef.encode ⟨t, t, s ++ [1, 2, 3]⟩, some .invalidSigLen),
    ("no signature", frameHead minerInfoProtocolId ++ [1, 0] ++ BsvScript.Sighash.pushData t ++ BsvScript.Sighash.pushData t,
      some .invalidInstruction) ]

/-- [D] a rotation then a partial revocation through the database, keys as bytes. -/
def dbScenario : Except String Unit := do
  let ctx : ChainView := ⟨fun b => some (b.headD 0), fun _ _ => true⟩
  let cfg : MinerIdConfig := {}
  let mk (cur prev : String) (rev : Option String) : CoinbaseDoc :=
    { rawJson := [], version := ascii "0.3", height := 1, prevMinerId := ascii prev, prevMinerIdSig := [],
      minerId := ascii cur, vctx := none, dataRefs := none, prevRevocationKey := ascii "aa",
      revocationKey := ascii "aa", revocationMessage := rev.map ascii, minerContact := none }
  let kA := parseHex (ascii "0a")
  let kB := parseHex (ascii "0b")
  let kC := parseHex (ascii "0c")
  let db0 : Db := {}
  let db1 := db0.blockAdded cfg ctx [1] 1 (some (mk "0a" "0a" none))
  let db2 := db1.blockAdded cfg ctx [2] 2 (some (mk "0b" "0a" none))
  unless (db2.lookupId kA).map (·.state) == some .rotated && (db2.lookupId kB).map (·.state) == some .current do
    throw "rotation states"
  let db3 := db2.blockAdded cfg ctx [3] 3 (some (mk "0c" "0b" (some "0b")))
  unless (db3.lookupId kB).map (·.state) == some .revoked && (db3.lookupId kC).map (·.state) == some .current &&
      (db3.lookupId kA).map (·.state) == some .rotated do throw "partial revocation states"
  -- reuse of the revoked id is refused
  let db4 := db3.blockAdded cfg ctx [4] 4 (some (mk "0b" "0b" none))
  unless (db4.lookupId kB).map (·.state) == some .revoked do throw "revoked id reused"
  -- a full revocation from the current id
  let db5 := db4.blockAdded cfg ctx [5] 5 (some (mk "0c" "0c" (some "0a")))
  unless [kA, kB, kC].all (fun k => (db5.lookupId k).map (·.state) == some .revoked) do throw "full revocation"
  unless db5.recent.length == 5 do throw "recent rows"

def synthetic : Except String Nat := do
  let mut n := 0
  for (name, raw, want) in docCases do
    unless codeOf raw == want do throw s!"document case '{name}': {repr (codeOf raw)}"
    n := n + 1
  for (name, s, want) in refCases do
    let got := match parseMinerInfoRef s with | .error (.code e) => some e | _ => none
    unless got == want do throw s!"reference case '{name}': {repr got}"
    n := n + 1
  -- the frames' round trips
  let f : MinerInfoFrame := ⟨ascii (infoDoc), List.replicate 71 5⟩
  unless isOk (MinerInfoFrame.decode f.encode) f do throw "miner-info frame"
  unless (match parseMinerInfoScript acceptAll f.encode with | .ok (r, _, s) => r == f.doc && s == f.sig | _ => false) do
    throw "miner-info script"
  unless isOk (dataRefJson (dataRefScript (ascii "{\"62b21572ca46\":{}}"))) (ascii "{\"62b21572ca46\":{}}") do throw "dataref"
  unless isOk (verifyDataObject (ascii "{\"62b21572ca46\":{}}")) () &&
      isErr (verifyDataObject (ascii "{\"62b21572ca4\":{}}")) .brfcidInvalidLength &&
      isErr (verifyDataObject (ascii "{\"62b21572ca4z\":{}}")) .brfcidInvalidContent &&
      isErr (verifyDataObject (ascii "{\"62b21572ca46\":1}")) .brfcidInvalidValueType do throw "data object"
  n := n + 7
  -- revokemid
  let k1 ← need (hexDecode key1) "key1"
  let m : RevokeMid := ⟨k1, k1, k1, List.replicate 71 1, List.replicate 72 2⟩
  unless keyValid k1 && RevokeMid.decode m.encode == some m do throw "revokemid round trip"
  unless RevokeMid.decode (m.encode.set 0 1) == none do throw "revokemid version 1 accepted"
  n := n + 2
  dbScenario
  return n + 1

def run (path : String) : IO UInt32 := do
  let rows := (← IO.FS.readFile path).splitOn "\n" |>.filter (fun s => !s.trimAscii.toString.isEmpty)
  let mut count := 0
  let mut failures := 0
  let mut keys : List String := []
  for row in rows do
    match Json.parse row >>= mainnetRow with
    | .error e => failures := failures + 1; IO.eprintln s!"minerid mainnet: ERROR {e}"
    | .ok (h, k) =>
      count := count + 1
      unless keys.contains k do keys := keys ++ [k]
      IO.println s!"minerid mainnet: height [M] {h}; frame and JSON round trips; node checks accept; the document is refused at the next height and with a changed signature (the node indexes no Miner ID for it; the block's validity is not read) [X]"
  let syn := synthetic
  match syn with
  | .error e => failures := failures + 1; IO.eprintln s!"minerid synthetic: ERROR {e}"
  | .ok n => IO.println s!"minerid synthetic: GREEN [X] ([D] {n} fixtures: 0.3 document codes, reference codes, frames, revokemid, database scenario)"
  let ok := failures == 0 && count > 0
  IO.println s!"chaincheck minerid: {if ok then "GREEN" else "RED"} [X] ([M] {count} of {rows.length} mainnet coinbase documents, {keys.length} miner ids; frame round trips {count}; JSON round trips {count}; node checks accept {count}; refusals {2 * count}; failures {failures}; nothing of Miner ID is consensus)"
  return if ok then 0 else 1

end MinerIdCheck
