import BsvChain
import Lean.Data.Json
import Test.P2PCheck

/-!
# Compact blocks against two regtest instances (#79)

[D] 2026-10-15 (#79). Run by `chaincheck --compact <record.json>` (the
chain leg runs it over `corpus/p2p/2026-10-15-compact-two-node.receipt.json`).

It reads a receipt of `run_scenarios --compact` and the scenario it names
(corpus/scenarios/2026-10-15-compact-blocks-two-node.md) and checks, per
block: the block read from A's bytes; the test peer's `cmpctblock` frame read
back and written again byte for byte, and equal to the message the Lean
sender builds from the block with the frame's nonce (the short ids are the
Lean SipHash's); the Lean reconstruction (`initData`, `missing`, `fillBlock`)
over B's pool as B held it before the block, against the scenario's declared
missing set and B's own account (its log's counts and required ids, its
per-command byte counters for `cmpctblock`, `getblocktxn` and `blocktxn`);
the filled block equal to the block, also over a pool that has every
transaction and one that has none; the peer's `blocktxn` frame read back and
equal to the Lean sender's answer. Every frame the peer received goes
through the frame round trip, `sendcmpct` through its codec. And the
SipHash-2-4 vectors of the reference's own test (src/test/hash_tests.cpp:62-84,
:139-140 at 6504a3af). A disagreement is a witness line and the check is RED
(rule 4). Views of the relay layer, never rules of validity.
-/

open Lean BsvScript.Numbers BsvScript.Tx BsvScript.Sighash BsvScript.Hash BsvChain BsvChain.Wire
open P2PCheck (need hex internal arr frameRoundTrip)

namespace CompactCheck

/-- [SRC] 2026-10-15: the 64 SipHash-2-4 outputs of src/test/hash_tests.cpp:62-84
at 6504a3af, for the key 00..0f and the inputs 00, 00 01, ... (the SipHash
paper's vectors). -/
def sipVectors : List Nat :=
  [0x726fdb47dd0e0e31, 0x74f839c593dc67fd, 0x0d6c8009d9a94f5a, 0x85676696d7fb7e2d,
   0xcf2794e0277187b7, 0x18765564cd99a68d, 0xcbc9466e58fee3ce, 0xab0200f58b01d137,
   0x93f5f5799a932462, 0x9e0082df0ba9e4b0, 0x7a5dbbc594ddb9f3, 0xf4b32f46226bada7,
   0x751e8fbc860ee5fb, 0x14ea5627c0843d90, 0xf723ca908e7af2ee, 0xa129ca6149be45e5,
   0x3f2acc7f57c29bdb, 0x699ae9f52cbe4794, 0x4bc1b3f0968dd39c, 0xbb6dc91da77961bd,
   0xbed65cf21aa2ee98, 0xd0f2cbb02e3b67c7, 0x93536795e3a33e88, 0xa80c038ccd5ccec8,
   0xb8ad50c6f649af94, 0xbce192de8a85b8ea, 0x17d835b85bbb15f3, 0x2f2e6163076bcfad,
   0xde4daaaca71dc9a5, 0xa6a2506687956571, 0xad87a3535c49ef28, 0x32d892fad841c342,
   0x7127512f72f27cce, 0xa7f32346f95978e3, 0x12e0b01abb051238, 0x15e034d40fa197ae,
   0x314dffbe0815a3b4, 0x027990f029623981, 0xcadcd4e59ef40c4d, 0x9abfd8766a33735c,
   0x0e3ea96b5304a7d0, 0xad0c42d6fc585992, 0x187306c89bc215a9, 0xd4a60abcf3792b95,
   0xf935451de4f21df2, 0xa9538f0419755787, 0xdb9acddff56ca510, 0xd06c98cd5c0975eb,
   0xe612a3cb9ecba951, 0xc766e62cfcadaf96, 0xee64435a9752fe72, 0xa192d576b245165a,
   0x0a8787bf8ecb74b2, 0x81b3e73d20b49b6f, 0x7fa8220ba3b2ecea, 0x245731c13ca42499,
   0xb78dbfaf3a8d83bd, 0xea1ad565322a1a0b, 0x60e61c23a3795013, 0x6606d7e446282b93,
   0x6ca4ecb15c5f91e1, 0x9f626da15c9625f3, 0xe51b38608ef25f57, 0x958a324ceb064572]

/-- [D] 2026-10-15: the 64 vectors, and `SipHashUint256(1, 2, hash)` of the
empty version-1 transaction (src/test/hash_tests.cpp:133-140 at 6504a3af).
The witnesses, if any. -/
def sipCheck : List String :=
  let k0 : UInt64 := 0x0706050403020100
  let k1 : UInt64 := 0x0F0E0D0C0B0A0908
  let vec := (sipVectors.zipIdx).filterMap fun (v, i) =>
    if (sipHash24 k0 k1 (List.range i)).toNat == v then none else some s!"siphash vector {i}"
  let tx := (sipHash24 1 2 (txid ⟨1, [], [], 0⟩)).toNat
  vec ++ (if tx == 0x79751e980c2a0a35 then [] else ["siphash of the empty transaction's hash"])

/-- [D] 2026-10-15: the digits that follow a marker in a log line. -/
def numAfter (line marker : String) : Option Nat :=
  match line.splitOn marker with
  | _ :: rest :: _ => (String.ofList (rest.toList.takeWhile Char.isDigit)).toNat?
  | _ => none

/-- [D] 2026-10-15: the display form of an internal hash. -/
def display (h : Bytes) : String := hexEncode h.reverse

/-- [D] 2026-10-15: a per-command byte counter's growth over a step. -/
def grew (step : Json) (dir cmd : String) : Nat :=
  let at_ (k : String) := ((step.getObjValD k).getObjValD "b" |>.getObjValD dir |>.getObjValD cmd).getNat?.toOption.getD 0
  at_ "counters_after" - at_ "counters_before"

/-- [D] 2026-10-15: the payload of the peer's frame of a command for a block. -/
def framePayload (frames : List Json) (cmd hash : String) : Except String Bytes := do
  let f ← need (frames.find? fun f =>
    f.getObjValD "command" == Json.str cmd && f.getObjValD "hash" == Json.str hash) s!"no {cmd} frame for {hash.take 12}"
  let bs ← hex (← f.getObjValAs? String "hex")
  let ((_, payload), _) ← need (unframe bs) s!"{cmd} frame"
  return payload

/-- [D] 2026-10-15: the regtest node of the run: the census defaults with the
block size the instance started on (`-excessiveblocksize`, the receipt's
settings). -/
def runConfig (size : Nat) : NodeConfig := { NodeConfig.defaults with excessiveBlockSize := size }

structure Tally where
  checks : Nat := 0
  witnesses : List String := []

def Tally.eq [BEq α] [ToString α] (t : Tally) (what : String) (got want : α) : Tally :=
  if got == want then { t with checks := t.checks + 1 }
  else { checks := t.checks + 1, witnesses := t.witnesses ++ [s!"{what}: Lean {got}, observed {want}"] }

def Tally.ok (t : Tally) (what : String) (b : Bool) : Tally :=
  if b then { t with checks := t.checks + 1 }
  else { checks := t.checks + 1, witnesses := t.witnesses ++ [what] }

/-- [D] 2026-10-15: the reconstruction's account: the missing positions, the
positions filled from the pool, and the filled block, or the status. -/
def reconstruct (size height : Nat) (c : CompactBlock) (b : Block) (pool : List Tx) :
    Except String (List Nat × Nat × Except ReadStatus Block) := do
  match initData size c pool [] with
  | .error s => throw s!"initData {repr s}"
  | .ok p =>
    let held := p.avail.length - p.missing.length - c.prefilled.length
    let vtx := p.missing.filterMap (fun i => b.transactions[i]?)
    return (p.missing, held, fillBlock ChainParams.regtest (runConfig size) height p vtx)

/-- [D] 2026-10-15: one block of the run. -/
def blockCheck (t : Tally) (size : Nat) (frames : List Json) (declared : Json) (step : Json) :
    Except String Tally := do
  let mut t := t
  let id ← step.getObjValAs? String "id"
  let blk := step.getObjValD "block"
  let hashHex ← blk.getObjValAs? String "hash"
  let bytes ← hex (← blk.getObjValAs? String "hex")
  let height ← step.getObjValAs? Nat "height"
  let b ← need (Block.decode bytes) s!"{id}: block bytes"
  t := t.ok s!"{id}: block writes back" (b.encode == bytes)
  let bhash := sha256d b.header.encode
  t := t.eq s!"{id}: block hash" (display bhash) hashHex
  -- The peer's compact block: read back, written again, and the Lean sender's.
  let payload ← framePayload frames "cmpctblock" hashHex
  let c ← need (CompactBlock.decode payload) s!"{id}: cmpctblock payload"
  t := t.ok s!"{id}: cmpctblock writes back" (c.encode == payload)
  t := t.ok s!"{id}: cmpctblock header is the block's" (c.header == b.header)
  t := t.ok s!"{id}: cmpctblock equals the Lean sender's message at its nonce (short ids by SipHash)"
    ((CompactBlock.ofBlock b c.nonce).encode == payload)
  -- B's pool before the block; the Lean reconstruction over it.
  let pool ← (← arr (step.getObjValD "b_pool")).mapM fun j => do
    need (decodeTx (← hex (← j.getObjValAs? String "hex"))) s!"{id}: pool transaction"
  let (missing, held, filled) ← reconstruct size height c b pool
  let want ← (declared.getObjValD "missing").getArr?
  let wantMissing := (← want.toList.mapM (·.getNat?))
  t := t.eq s!"{id}: declared missing set" missing wantMissing
  t := t.eq s!"{id}: declared from_pool" held ((declared.getObjValD "from_pool").getNat?.toOption.getD 0)
  t := t.ok s!"{id}: filled block is the block" (match filled with | .ok fb => fb.encode == bytes | _ => false)
  -- B's own account: its log line, its required ids, its byte counters.
  let lines := (← arr (step.getObjValD "b_console")).filterMap (·.getStr?.toOption)
  let line ← need (lines.find? (·.contains "Successfully reconstructed block")) s!"{id}: no reconstruction line"
  t := t.ok s!"{id}: reconstructed block is this block" (line.contains hashHex)
  t := t.eq s!"{id}: prefilled" (some c.prefilled.length) (numAfter line "with ")
  t := t.eq s!"{id}: from the pool" (some held) (numAfter line "prefilled, ")
  t := t.eq s!"{id}: requested" (some missing.length) (numAfter line "and ")
  let required := lines.filterMap fun l =>
    if l.contains "required tx " then (l.splitOn "required tx ").getLast?.map (·.trimAscii.toString) else none
  let leanRequired := missing.filterMap fun i => (b.transactions[i]?).map (display ∘ txid)
  t := t.eq s!"{id}: required ids" leanRequired required
  t := t.eq s!"{id}: cmpctblock bytes at B" (24 + c.encode.length) (grew step "recv" "cmpctblock")
  let req : BlockTxnRequest := { blockHash := bhash, indices := missing }
  let resp : BlockTxns := { blockHash := bhash, txs := missing.filterMap fun i => b.transactions[i]? }
  t := t.eq s!"{id}: getblocktxn bytes from B" (if missing.isEmpty then 0 else 24 + req.encode.length)
    (grew step "sent" "getblocktxn")
  t := t.eq s!"{id}: blocktxn bytes at B" (if missing.isEmpty then 0 else 24 + resp.encode.length)
    (grew step "recv" "blocktxn")
  -- The theorem's other two views: a pool with every transaction, a pool with none.
  let rest := b.transactions.drop 1
  let (mAll, _, fAll) ← reconstruct size height c b rest
  let (mNone, _, fNone) ← reconstruct size height c b []
  t := t.eq s!"{id}: missing over a full pool" mAll []
  t := t.eq s!"{id}: missing over an empty pool" mNone ((List.range rest.length).map (· + 1))
  t := t.ok s!"{id}: filled from both views" (match fAll, fNone with
    | .ok x, .ok y => x.encode == bytes && y.encode == bytes | _, _ => false)
  -- The peer's blocktxn: read back and the Lean sender's answer.
  let ask := (← (step.getObjValD "pa_ask").getArr?).toList.filterMap (·.getNat?.toOption)
  unless ask.isEmpty do
    let tp ← framePayload frames "blocktxn" hashHex
    let bt ← need (BlockTxns.decode tp) s!"{id}: blocktxn payload"
    t := t.ok s!"{id}: blocktxn writes back" (bt.encode == tp)
    t := t.ok s!"{id}: blocktxn is the Lean sender's answer" (match answerGetBlockTxn {} b
        { blockHash := bhash, indices := ask } with
      | .inl (some x) => x.encode == tp | _ => false)
  return t

/-- [D] 2026-10-15: the scenario's declared blocks, from its JSON block. -/
def declaredSteps (path : String) : IO (Except String (List Json)) := do
  let raw ← IO.FS.readFile path
  let body := match raw.splitOn "```json" with
    | _ :: rest :: _ => (rest.splitOn "```").head?.getD ""
    | _ => ""
  return do
    let j ← Json.parse body
    arr (j.getObjValD "steps")

def run (path : String) : IO UInt32 := do
  let raw ← IO.FS.readFile path
  let declared ← match Json.parse raw with
    | .ok j => pure j
    | .error e => IO.eprintln s!"compact blocks: RED {e}"; return 1
  let scen := (declared.getObjValD "scenario").getStr?.toOption.getD ""
  let steps ← declaredSteps scen
  let result : Except String (Tally × Nat) := do
    let frames ← arr (declared.getObjValD "frames")
    let size := ((declared.getObjValD "settings").getObjValD "excessiveblocksize").getNat?.toOption.getD 1000001
    let decl ← steps
    let mut t : Tally := {}
    for w in sipCheck do t := { t with witnesses := t.witnesses ++ [w] }
    t := { t with checks := t.checks + 65 }
    let mut nframes := 0
    for f in frames do
      let bs ← hex (← f.getObjValAs? String "hex")
      let name ← frameRoundTrip bs
      nframes := nframes + 1
      if name == "sendcmpct" then
        let ((_, p), _) ← need (unframe bs) "sendcmpct frame"
        let s ← need (SendCmpct.decode p) "sendcmpct payload"
        t := t.ok "sendcmpct writes back" (s.encode == p)
        t := t.ok "A's sendcmpct is (false, 1)" (s == { announce := false, version := 1 })
    let ss ← arr (declared.getObjValD "steps")
    for s in ss do
      let id ← s.getObjValAs? String "id"
      let d ← need (decl.find? (·.getObjValD "id" == Json.str id)) s!"{id}: not declared"
      t ← blockCheck t size frames (d.getObjValD "expected") s
    return (t, nframes)
  match result with
  | .error e => IO.eprintln s!"compact blocks: RED {e}"; return 1
  | .ok (t, n) =>
    for w in t.witnesses do IO.println s!"  witness: {w}"
    let verdict := if t.witnesses.isEmpty then "GREEN" else "RED"
    IO.println s!"compact blocks: {verdict} [X] ({t.checks} checks, {t.witnesses.length} witnesses; {n} frames read back byte for byte; the SipHash vectors of the reference's test)"
    return if t.witnesses.isEmpty then 0 else 1

end CompactCheck
