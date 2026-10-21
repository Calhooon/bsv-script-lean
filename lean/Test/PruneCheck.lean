import BsvChain.Views.Prune
import Lean.Data.Json

/-!
# The pruning check (#82)

[M] 2026-10-15 (#82). Run by `chaincheck --prune <file>`. The file is a regtest
run's events in arrival order, written by the scenario runner from the node's own output
(harness/src/scenarios/prune.rs): every block's height, serialized size and whether it was
connected with an undo record; every `pruneblockchain` call with the tip at the call; the
probe blocks and whether their merkle tree was asked for before pruning. The check
replays them through `BsvChain.Views.Prune` and prints, as one JSON object, what the Lean
function says the node answers: every RPC reply, the data and undo bits of every block
after every call, the removed files, `pruneheight`, and the answer to every request for
the probe blocks. The runner compares it with the node. Views, never rules: pruning is a
node's storage setting (cited in `lean/BsvChain/Views/Prune.lean`).
-/

open Lean BsvChain.Views.Prune

namespace PruneCheck

def modeOf (j : Json) : Except String Mode := do
  match j.getStr? with
  | .ok "off" => pure .off
  | .ok "manual" => pure .manual
  | .ok m => throw s!"unknown mode {m}"
  | .error _ => pure (.auto (← j.getObjValAs? Nat "auto"))

def configOf (j : Json) : Except String Config := do
  pure { mode := ← modeOf (← j.getObjVal? "mode"),
         minBlocksToKeep := ← j.getObjValAs? Nat "minBlocksToKeep",
         hysteresis := ← j.getObjValAs? Nat "hysteresis",
         preferredBlockFileSize := ← j.getObjValAs? Nat "preferredBlockFileSize" }

def requests : List (String × Request) :=
  [("getblock0", .getblock 0), ("getblock1", .getblock 1), ("getblockheader", .getblockheader),
   ("getblockheader2", .getblockheaderExtended), ("getrawtransaction", .getrawtransaction),
   ("getmerkleproof", .getmerkleproof), ("getmerkleproof2", .getmerkleproof2),
   ("gettxout", .gettxout), ("getblockhash", .getblockhash), ("getchaintxstats", .getchaintxstats)]

def answerJson : Answer → Json
  | .served => Json.mkObj [("kind", "served")]
  | .servedWithout fs => Json.mkObj [("kind", "served"), ("absent", toJson fs)]
  | .error c m => Json.mkObj [("kind", "error"), ("code", toJson c), ("message", toJson m)]
  | .headThenError c m =>
    Json.mkObj [("kind", "head-then-error"), ("code", toJson c), ("message", toJson m)]

def bits (s : Store) (f : Store → Nat → Bool) : List Bool := (List.range s.placed.length).map (f s)

/-- The data bit by height on a single chain: the block stored at that height. -/
def dataAt (s : Store) (h : Nat) : Bool :=
  match (List.range s.placed.length).find? (fun k => (s.placed[k]?.map (·.1)) == some h) with
  | some k => s.hasData k
  | none => false

def compute (j : Json) : Except String Json := do
    let c ← configOf (← j.getObjVal? "config")
    let pa ← j.getObjValAs? Nat "pruneAfterHeight"
    let events ← j.getObjValAs? (Array Json) "events"
    let mut s : Store := {}
    let mut replies : Array Json := #[]
    for e in events do
      match e.getObjVal? "block" with
      | .ok b =>
        let h ← b.getArrVal? 0 >>= Json.getNat?
        let size ← b.getArrVal? 1 >>= Json.getNat?
        let undo ← b.getArrVal? 2 >>= Json.getBool?
        s := s.addBlock c h size 0 undo
      | .error _ =>
      match e.getObjVal? "auto" with
      | .ok a =>
        let tip ← a.getObjValAs? Nat "tip"
        let flushed ← a.getObjValAs? Nat "flushed"
        let set := autoSet c s pa tip flushed
        s := s.unlink set
        replies := replies.push (Json.mkObj [("auto", toJson tip), ("removed", toJson set), ("count", toJson s.count),
          ("data", toJson (bits s Store.hasData)), ("undo", toJson (bits s Store.hasUndo)),
          ("pruneheight", toJson (pruneHeightFrom (dataAt s) tip))])
      | .error _ =>
        let p ← e.getObjVal? "prune"
        let tip ← p.getObjValAs? Nat "tip"
        let param ← p.getObjValAs? Int "param"
        let before := s.removed.length
        let (r, s') := s.pruneRpc c pa tip param
        s := s'
        let reply := match r with
          | .ok h => Json.mkObj [("result", toJson (asUInt64 h)), ("height", toJson h)]
          | .error (code, msg) => Json.mkObj [("error", Json.mkObj [("code", toJson code), ("message", toJson msg)])]
        replies := replies.push (Json.mkObj [("tip", toJson tip), ("param", toJson param),
          ("reply", reply), ("removed", toJson (s.removed.drop before)), ("count", toJson s.count),
          ("data", toJson (bits s Store.hasData)), ("undo", toJson (bits s Store.hasUndo)),
          ("pruneheight", toJson (pruneHeightFrom (dataAt s) tip))])
    let probes ← j.getObjValAs? (Array Json) "probes"
    let mut probed : Array Json := #[]
    for p in probes do
      let k ← p.getObjValAs? Nat "index"
      let hash ← p.getObjValAs? String "hash"
      let tree ← p.getObjValAs? Bool "treeHeld"
      let held : Held := { data := s.hasData k, treeHeld := tree }
      probed := probed.push (Json.mkObj [("index", toJson k), ("hash", toJson hash),
        ("data", toJson held.data), ("treeHeld", toJson tree),
        ("answers", Json.mkObj (requests.map fun (n, r) => (n, answerJson (answer hash held r))))])
    let launchArgs : List Int := (j.getObjValAs? (List Int) "launchArgs").toOption.getD []
    let launch := launchArgs.map fun arg =>
      match modeOfArg arg with
      | .ok m => Json.mkObj [("arg", toJson arg), ("mode", toJson (reprStr m))]
      | .error msg => Json.mkObj [("arg", toJson arg), ("error", toJson msg)]
    pure (Json.mkObj [("files", toJson s.count), ("last", toJson s.last), ("launch", toJson launch),
      ("removed", toJson s.removed), ("fileOf", toJson (s.placed.map (·.2.1))),
      ("replies", toJson replies), ("probes", toJson probed)])

def run (path : String) : IO UInt32 := do
  match Json.parse (← IO.FS.readFile path) >>= compute with
  | .ok out => IO.println out.compress; return 0
  | .error e => IO.eprintln s!"chaincheck prune: ERROR {e}"; return 1

end PruneCheck
