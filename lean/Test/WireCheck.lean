import BsvChain.Views.Wire.EF
import BsvChain.Views.Wire.AtomicBEEF
import BsvChain.Views.Wire.TSC
import Lean.Data.Json

/-!
# The wire views' column (#86)

[M] 2026-10-15 (#86). Runs every row of `corpus/wire/<format>.jsonl`
through the spec's codec and projection of its format
(`BsvChain.Views.Wire`) and writes one JSON line per row: whether the codec
reads the bytes, whether the view's checks hold, the re-encoding, and the
objects the projection yields (txids in display order, roots, spent outputs,
entries). The harness compares the engines' lines with these
(`harness/src/bin/run_wire.rs`); this column is the oracle (CLAUDE.md rule 3).
Views, never rules.
-/

open Lean BsvChain BsvChain.Views BsvChain.Views.Wire BsvScript.Numbers BsvScript.Tx

namespace WireCheck

/-- Display order: the reversed word as hex. -/
def disp (w : Bytes) : String := hexEncode w.reverse

def str (j : Json) (key : String) : Option String := (j.getObjValAs? String key).toOption

def nat? (j : Json) (key : String) : Option Nat := (j.getObjValAs? Nat key).toOption

def efLine (bs : Bytes) : List (String × Json) :=
  match EfTx.decode bs with
  | none => [("codec", toJson false), ("accept", toJson false)]
  | some t =>
    [("codec", toJson true), ("accept", toJson true), ("reencode", toJson (hexEncode t.encode)),
      ("txid", toJson (disp (BsvScript.Sighash.txid t.tx))), ("tx", toJson (hexEncode (BsvScript.Sighash.serTx t.tx))),
      ("spent", toJson (t.spent.map fun o => Json.arr #[toJson o.value, toJson (hexEncode o.scriptPubKey)]))]

def bumpObjects (b : Bump) : List (String × Json) :=
  [("height", toJson b.blockHeight), ("root", toJson (b.root.map disp)),
    ("txids", toJson (b.clientTxids.map fun (o, w) =>
      Json.mkObj [("offset", toJson o), ("txid", toJson (disp w)), ("root", toJson ((b.rootFor w o).map disp))]))]

def bumpLine (bs : Bytes) : List (String × Json) :=
  match Bump.decode bs with
  | none => [("codec", toJson false), ("accept", toJson false)]
  | some b =>
    [("codec", toJson true), ("accept", toJson b.root.isSome), ("reencode", toJson (hexEncode b.encode))] ++
      bumpObjects b

def entryJson (b : Beef) (e : BeefEntry) : Json :=
  let kind := match e with
    | .raw _ none => "raw"
    | .raw _ (some _) => "raw+bump"
    | .txidOnly _ => "txid"
  let bump := match e with
    | .raw _ (some i) => toJson i
    | _ => Json.null
  let mined := match b.object e with
    | some (.mined _ h index nodes) =>
      Json.mkObj [("height", toJson h), ("index", toJson index),
        ("root", toJson (disp (bumpFold e.txid nodes index)))]
    | some _ => Json.null
    | none => toJson "unresolved"
  Json.mkObj [("txid", toJson (disp e.txid)), ("kind", toJson kind), ("bump", bump), ("mined", mined)]

/-- The BEEF view's checks: every BUMP has a root and every entry resolves. -/
def beefViewOk (b : Beef) : Bool := b.bumps.all (·.root.isSome) && b.objects.isSome

def beefObjects (b : Beef) : List (String × Json) :=
  [("version", toJson (match b.version with | .v1 => 1 | .v2 => 2)),
    ("bumps", toJson (b.bumps.map fun x => Json.mkObj [("height", toJson x.blockHeight), ("root", toJson (x.root.map disp))])),
    ("txs", toJson (b.txs.map (entryJson b))), ("ordered", toJson b.ordered)]

def beefLine (bs : Bytes) : List (String × Json) :=
  match Beef.decode bs with
  | none => [("codec", toJson false), ("accept", toJson false)]
  | some b =>
    [("codec", toJson true), ("accept", toJson (beefViewOk b)), ("reencode", toJson (hexEncode b.encode))] ++
      beefObjects b

def atomicLine (bs : Bytes) : List (String × Json) :=
  match AtomicBeef.decode bs with
  | none => [("codec", toJson false), ("accept", toJson false)]
  | some a =>
    [("codec", toJson true), ("accept", toJson (beefViewOk a.beef && a.scoped)),
      ("reencode", toJson (hexEncode a.encode)), ("subject", toJson (disp a.subject)),
      ("scoped", toJson a.scoped), ("ancestry", toJson ((a.ancestry.map fun (_, objs) => objs.map (disp ·.1)).getD []))] ++
      beefObjects a.beef

def tscLine (row : Json) (bs : Bytes) : List (String × Json) :=
  match Views.decode bs with
  | none => [("codec", toJson false), ("accept", toJson false)]
  | some p =>
    let leaf := tscLeaf p.txOrId
    let header := (str row "header_hex").bind hexDecode |>.bind BlockHeader.decode
    let root := computeRootFromBranch leaf (markerPath p.nodes) p.index
    let target := (resolveTarget p.target header).map disp
    let height := (nat? row "block_height").getD 0
    let read := ((str row "bump_hex").bind hexDecode).bind Bump.decode
    [("codec", toJson true), ("accept", toJson true), ("reencode", toJson (hexEncode p.encode)),
      ("flags", toJson p.flags), ("index", toJson p.index), ("txid", toJson (disp leaf)),
      ("root", toJson (disp root)), ("target_root", toJson target), ("verify", toJson (verifyTsc p header)),
      ("bump", toJson (hexEncode (p.toBump height).encode)),
      ("read_bump_root", toJson ((read.bind fun b => b.rootFor leaf p.index).map disp))]

def lineFor (row : Json) : Except String Json := do
  let id ← row.getObjValAs? String "id"
  let fmt ← row.getObjValAs? String "format"
  let hex ← row.getObjValAs? String "hex"
  let bs ← match hexDecode hex with
    | some b => pure b
    | none => throw s!"{id}: invalid hex"
  let fields := match fmt with
    | "ef" => efLine bs
    | "bump" => bumpLine bs
    | "beef" => beefLine bs
    | "atomic-beef" => atomicLine bs
    | "tsc" => tscLine row bs
    | _ => [("error", toJson s!"unknown format {fmt}")]
  pure (Json.mkObj ([("id", toJson id), ("format", toJson fmt), ("impl", toJson "spec")] ++ fields))

end WireCheck

def main (args : List String) : IO UInt32 := do
  if args.isEmpty then
    IO.eprintln "usage: wirecheck corpus/wire/<format>.jsonl ..."
    return 2
  let mut rows := 0
  let mut bad := 0
  for path in args do
    for line in (← IO.FS.lines path) do
      if line.trim.isEmpty then continue
      match Json.parse line >>= WireCheck.lineFor with
      | .ok j =>
        rows := rows + 1
        IO.println j.compress
      | .error e =>
        bad := bad + 1
        IO.eprintln s!"wirecheck: {e}"
  IO.eprintln s!"wirecheck: {rows} rows, {bad} unreadable"
  return if bad = 0 then 0 else 1
