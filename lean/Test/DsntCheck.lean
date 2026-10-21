import BsvChain
import Lean.Data.Json

/-!
# Double-spend notifications against two regtest instances (#80)

[D] 2026-10-15 (#80). Run by `chaincheck --dsnt <record.json>` (the chain
leg). It reads a receipt of `run_scenarios --dsnt`
(corpus/scenarios/2026-10-15-double-spend-notify.md) and judges it through
`lean/BsvChain/Wire/DoubleSpend.lean`, three ways:

* the codecs: each notification output read (`callbackOfScript`) and written
  again (`dsntScript`) byte for byte; the `dsdetected` payload the run sent and
  every relayed `dsdetected` frame read (`DSDetected.read`) and written again,
  and judged valid (`DSDetected.valid`);
* the detector: #62's admission (`acceptDetect`) replays the run: a pool that
  accepted E1, E2 and E3 refuses C1, C2 and C3 at the pool's conflict check,
  each with its E as the collided set and the scripts unchecked, against the
  node's lines (`rejected txn-mempool-conflict (code 258)`, `(checked 0)`);
* the handler and the `dsdetected` handling: `handle` then `process` per
  attempt, the endpoint's answers taken from the receiver's log, the predicted
  queries and proofs (method, path, body) against the receiver's requests in
  order, the blacklist and the skip against the node's lines; `processDSDetected`
  at B (sender PB) and at A (sender B): the relay against PA's frame and the
  nodes' lines, each webhook body against the model's JSON byte for byte, and
  the repeated message against the duplicate cache.

A disagreement is a witness (rule 4). Views of node behavior, never rules of
validity: a notification is never a verdict.
-/

open Lean BsvChain BsvScript.Tx BsvScript.Numbers BsvChain.Wire BsvChain.Wire.DoubleSpend

namespace DsntCheck

def need (x : Option α) (message : String) : Except String α :=
  match x with | some a => .ok a | none => .error message

def hex (s : String) : Except String Bytes := need (hexDecode s) s!"bad hex {s.take 16}"

def arr (j : Json) : Except String (List Json) := do return (← j.getArr?).toList

def str (j : Json) (k : String) : Except String String := j.getObjValAs? String k

/-- [D] 2026-10-15: the run's transaction by its name. -/
def txNamed (r : Json) (name : String) : Except String Tx := do
  let t ← (← r.getObjVal? "names").getObjVal? "transactions"
  let raw ← hex (← str (← t.getObjVal? name) "hex")
  need (decodeTx raw) s!"{name} does not decode"

/-- [D] 2026-10-15: a step of the receipt by its id. -/
def step (r : Json) (id : String) : Except String Json := do
  let steps ← arr (← r.getObjVal? "steps")
  need (steps.find? fun s => (s.getObjValAs? String "id").toOption == some id) s!"no step {id}"

def lines (s : Json) (k : String) : List String :=
  match s.getObjVal? k >>= Json.getArr? with
  | .ok a => a.toList.filterMap (fun j => j.getStr?.toOption)
  | .error _ => []

def anyLine (ls : List String) (needle : String) : Bool := ls.any (fun l => (l.splitOn needle).length > 1)

/-! ## The machine's context -/

/-- [D] 2026-10-15: the instance's settings the admission reads: the block size
the runner sets and the stack bound of the scenario profile
(harness/oracle/scenarios.conf); every other setting at its default. -/
def nodeConfig : NodeConfig :=
  { NodeConfig.defaults with excessiveBlockSize := 1000001, maxStackMemoryUsageConsensus := 100000000 }

/-- [D] 2026-10-15: a chain of 103 headers (heights 0 to 102, the run's tip
height) whose coins are G's four outputs at height 102, as the run mined them.
A fixture of the replay's prefix, not a claim the bodies were replayed. -/
def stateWith (g : Tx) : ChainState := Id.run do
  let mut s : ChainState := {}
  for h in List.range 103 do
    let header : BlockHeader := ⟨1, s.view.bestBlock, 0, BitVec.ofNat 32 (1699990000 + h), 0x207fffff, 0⟩
    let parent := s.active.getLast?
    let work := addChainWork ((parent.bind s.tree.get).map (·.work) |>.getD 0) header.bits
    let index : BlockIndex := { header, parent, height := h, work, tieRank := h, txCount := 1, chainTx := h + 1,
                                status := { validity := 5 }, sequence := h + 1, completion := .ignored }
    s := { s with tree := { s.tree with nodes := s.tree.nodes ++ [index] }, active := s.active ++ [index.id],
                  view := { s.view with bestBlock := index.id } }
  let gid := BsvScript.Sighash.txid g
  let coins := (List.range g.outputs.length).filterMap fun i =>
    (g.outputs[i]?).map fun o => (⟨gid, i⟩, ⟨o.value, o.scriptPubKey, 102, false, false⟩)
  return { s with tree := { s.tree with candidates := s.active.getLast?.toList, nextSequence := 104 },
                  view := { s.view with coins := coinMap coins } }

def chainContext : ChainContext :=
  { params := .regtest, cfg := nodeConfig, now := 1700000100, bucketTime := 1700000100 * 1000000000,
    accounting := .byteOnly, disconnectAccounting := ⟨0, fun tx => (BsvScript.Sighash.serTx tx).length⟩,
    innerUsage := fun tx => (BsvScript.Sighash.serTx tx).length, completionEvent := fun i => i.tieRank }

/-- [D] 2026-10-15: one admission of #62's machine with the detection beside it. -/
def admitDetect (s : ChainState) (pool : Mempool) (tx : Tx) (source : TxSource) :
    (Mempool × TxOutcome × List AdmissionStage) × Option Detection :=
  acceptDetect pool s.view.coins nodeConfig (admissionContext s chainContext) .empty evalOracle {} []
    { tx, acceptTime := chainContext.now, source }

/-- [D] 2026-10-15: the handler's script check of a double-spend input, read
from the machine: the same transaction admitted to a pool without the
conflict passes its scripts (`ValidateDoubleSpend` runs the input's check,
src/double_spend/dsattempt_handler.cpp:149-178 at 6504a3af). -/
def scriptCheckBy (s : ChainState) (spends : List Tx) : Tx → Nat → ScriptCheck := fun tx _ =>
  if spends.any (fun t => BsvScript.Sighash.txid t == BsvScript.Sighash.txid tx) then
    match (admitDetect s {} tx .p2p).1.2.1 with
    | .completed .accepted => .passed
    | .completed (.rejected _ _) => .invalid
    | _ => .cancelled
  else .cancelled

/-- [D] 2026-10-15: the handler's coin read: the output's script standard
(`IsStandardOutput`, BsvScript.Standard) when the coin is G's. -/
def coinStandardBy (s : ChainState) : Tx → Nat → Option Bool := fun tx i => do
  let input ← tx.inputs[i]?
  let coin ← getCoin s.view.coins (OutPoint.ofInput input)
  let cfg := admissionScriptConfig nodeConfig (admissionContext s chainContext)
  pure (BsvScript.Standard.isStandardOutput cfg false coin.script).2

/-! ## The comparisons -/

structure Tally where
  lines : List String := []
  agree : Nat := 0
  witnesses : List String := []

def Tally.check (t : Tally) (ok : Bool) (what : String) : Tally :=
  if ok then { t with agree := t.agree + 1 } else { t with witnesses := t.witnesses ++ [what] }

/-- [D] 2026-10-15: a section's word: agree when it added no witness. -/
def Tally.word (t : Tally) (before : Nat) : String := if t.witnesses.length == before then "agree" else "DIFFER"

/-- [D] 2026-10-15: a section's reading: as observed when it agreed, else the
model's, pointing at the witness (the fix of #80's review). -/
def Tally.reading (t : Tally) (before : Nat) (model observed : String) : String :=
  if t.word before == "agree" then s!"({model}{observed})" else s!"(the model: {model}; see the witness)"

/-- [D] 2026-10-15: a receiver entry's method, path and body. -/
def entry (e : Json) : Except String (String × String × Bytes) := do
  return (← str e "method", ← str e "path", ← hex (← str e "body_hex"))

/-- [D] 2026-10-15: the endpoint's answer the receiver gave, as the handler reads it. -/
def reply (e : Json) : Except String Reply := do
  let a ← e.getObjVal? "answer"
  let status ← a.getObjValAs? Nat "status"
  let dsnt := (a.getObjValAs? String "dsnt").toOption
  return .response status dsnt

/-- [D] 2026-10-15: the HTTP requests among the model's effects, in order. -/
def requests (es : List Effect) : List (String × String × Bytes) :=
  es.filterMap fun
    | .query _ _ _ path _ => some ("GET", path, [])
    | .submit _ _ _ path body _ => some ("POST", path, body)
    | _ => none

def effectWords (es : List Effect) : List String :=
  es.map fun
    | .query .. => "query" | .submit .. => "submit" | .skipped _ why => s!"skipped:{why}"
    | .slowQueued .. => "slow" | .blacklisted .. => "blacklisted" | .recorded _ => "recorded"
    | .misbehaving _ => "misbehaving" | .suspensionRaised => "suspension"

def dsConfig (port : Nat) : DSConfig := { level := .standard, endpointPort := port }

/-- [D] 2026-10-15: the frame's payload when its command is `dsdetected`. -/
def dsdetectedPayload (frameHex : String) : Except String (Option Bytes) := do
  let bs ← hex frameHex
  match unframe bs with
  | some ((cmd, payload), []) => return if cmd == Command.dsdetected.bytes then some payload else none
  | _ => throw "frame does not unframe"

def judge (r : Json) : Except String Tally := do
  let mut t : Tally := {}
  let mut w0 := 0
  -- 1. the codecs
  let script ← hex (← str r "dsnt_script")
  let g ← txNamed r "G"
  let es ← ["E1", "E2", "E3"].mapM (txNamed r)
  let cs ← ["C1", "C2", "C3"].mapM (txNamed r)
  for (e, n) in es.zip ["E1", "E2", "E3"] do
    let out ← need (e.outputs[1]?) s!"{n} has no output 1"
    t := t.check (out.scriptPubKey == script) s!"{n}: output 1 is not the run's notification output"
    t := t.check ((dsOutput e) == some 1) s!"{n}: dsOutput is not 1"
    match callbackOfScript out.scriptPubKey with
    | none => t := t.check false s!"{n}: callbackOfScript refused"
    | some m =>
      t := t.check (dsntScript m == out.scriptPubKey) s!"{n}: dsntScript does not write back"
      t := t.check (m.protocolVersion == 1 && m.addrs.map endpointKey == ["127.0.0.1"] && m.inputs == [])
        s!"{n}: message is not protocol 1, 127.0.0.1, every input"
  let s4 ← step r "s4-dsdetected-relayed"
  let payload ← hex (← str s4 "payload_hex")
  let (msg, rest) ← need (DSDetected.read payload) "the sent dsdetected payload does not read"
  t := t.check (rest.isEmpty && msg.encode == payload) "dsdetected payload does not write back"
  t := t.check msg.valid "dsdetected payload is not valid by DSDetected.valid"
  let mut relayed := 0
  for f in ← arr (← r.getObjVal? "frames") do
    if let some p ← dsdetectedPayload (← str f "hex") then
      relayed := relayed + 1
      match DSDetected.read p with
      | some (m, []) => t := t.check (m.encode == p && m.valid && p == payload) "relayed dsdetected frame differs"
      | _ => t := t.check false "relayed dsdetected frame does not read"
  t := { t with lines := t.lines ++ [s!"dsnt codecs: {t.word w0} [X] (3 notification outputs read and written back; the dsdetected payload of {payload.length} bytes and {relayed} relayed frame(s) read, written back and valid)"] }
  w0 := t.witnesses.length
  -- 2. the detector, over #62's admission
  let s := stateWith g
  let mut pool : Mempool := {}
  for (e, n) in es.zip ["E1", "E2", "E3"] do
    let ((p, outcome, _), _) := admitDetect s pool e .rpc
    t := t.check (outcome == .completed .accepted) s!"{n}: the machine does not accept it ({repr outcome})"
    pool := p
  let mut dets : List Detection := []
  for ((c, e), (n, sid)) in (cs.zip es).zip [("C1", "s1-proof-delivered"), ("C2", "s2-no-header-blacklisted"), ("C3", "s3-blacklisted-skip")] do
    let st ← step r sid
    let a := lines st "a_console"
    let cid := hexEncode (BsvScript.Sighash.txid c).reverse
    let ((_, outcome, trace), det) := admitDetect s pool c .p2p
    t := t.check (outcome == .completed (.rejected (.node 0x102) "txn-mempool-conflict"))
      s!"{n}: the machine's outcome {repr outcome}"
    t := t.check (anyLine a s!"{cid} rejected txn-mempool-conflict (code 258)") s!"{n}: no node line of the conflict refusal"
    match det with
    | none => t := t.check false s!"{n}: no detection"
    | some d =>
      t := t.check (d.site == .conflictStage && trace.getLast? == some .conflict) s!"{n}: not the stage-5 conflict"
      t := t.check (d.collided.map BsvScript.Sighash.txid == [BsvScript.Sighash.txid e]) s!"{n}: collided set is not its E"
      t := t.check (!d.scriptsChecked && anyLine a s!"Processing double-spend txn {cid} (checked 0)")
        s!"{n}: scripts-checked flag differs from the node's line"
      dets := dets ++ [d]
  t := { t with lines := t.lines ++ [s!"dsnt detector: {t.word w0} [X] {t.reading w0 "#62's admission accepts E1, E2, E3 and refuses C1, C2, C3 at the conflict check, 0x102, scripts unchecked, each against its E" "; the node's lines agree"}"] }
  w0 := t.witnesses.length
  -- 3. the handler, attempt by attempt, the state carried
  let port ← (← r.getObjVal? "ports").getObjValAs? Nat "receiver"
  let cfg := dsConfig port
  let mut h := HandlerState.init cfg
  for ((d, (sid, label)), e) in (dets.zip [("s1-proof-delivered", "s1"), ("s2-no-header-blacklisted", "s2"), ("s3-blacklisted-skip", "s3")]).zip es do
    let st ← step r sid
    let got ← arr (← st.getObjVal? "receiver")
    let replies ← got.mapM reply
    let now ← st.getObjValAs? Int "epoch_sent"
    let env : Env := { now, coinStandard := coinStandardBy s, scriptCheck := scriptCheckBy s cs, replies }
    h := handle cfg h d ((BsvScript.Sighash.serTx d.spender).length)
    let (h', effects) := process cfg 100 h env
    h := h'
    let want := requests effects
    let seen ← got.mapM entry
    t := t.check (want == seen) s!"{label}: requests {want.map (·.2.1)} against the receiver's {seen.map (·.2.1)}"
    let a := lines st "a_console"
    let words := effectWords effects
    let eid := hexEncode (BsvScript.Sighash.txid e).reverse
    if label == "s1" then
      t := t.check (words == ["query", "submit", "recorded"] && anyLine a s!"Submitted proof ok to 127.0.0.1 for double-spend enabled txn {eid}")
        s!"s1: effects {words}"
    else if label == "s2" then
      t := t.check (words == ["query", "blacklisted", "recorded"] && anyLine a "Missing x-bsv-dsnt header in response from endpoint 127.0.0.1")
        s!"s2: effects {words}"
    else
      t := t.check (words == ["skipped:blacklist"] && anyLine a "Skipping notification to blacklisted endpoint 127.0.0.1")
        s!"s3: effects {words}"
    t := { t with lines := t.lines ++ [s!"dsnt handler {label}: {t.word w0} [X] (the model's effects {words}; {want.length} request(s) against the receiver's {seen.length}, method, path and body)"] }
    w0 := t.witnesses.length
  -- 4. the dsdetected handling at B (sender PB) and at A (sender B)
  let tip ← s4.getObjVal? "tip"
  let tipHash ← hex (← str tip "hash")
  let tipHeight ← tip.getObjValAs? Nat "height"
  let tipWord := word256 tipHash.reverse
  let cv : ChainView := { ancestorHeight := fun hh => if hh == tipWord then some tipHeight else none,
                          bestHeaderHeight := tipHeight, headersAccepted := true, statusUpdated := true }
  let got ← (← arr (← s4.getObjVal? "receiver")).mapM entry
  let body (path : String) : Option String :=
    (got.find? (·.2.1 == path)).map fun (_, _, b) => String.ofList (b.map Char.ofNat)
  -- B's peers: A (0) and PB (2); A's peers: B (0) and PA (2), the node's own numbering in its lines.
  let cfgB : DSConfig := { cfg with webhook := some ("127.0.0.1", port, "/dsdetected/b") }
  let cfgA : DSConfig := { cfg with webhook := some ("127.0.0.1", port, "/dsdetected/a") }
  let (cacheB, outB, effB) := processDSDetected cfgB nodeConfig.safeModeMaxForkDistance cv {} 2 [0, 2] payload
  let (_, outA, effA) := processDSDetected cfgA nodeConfig.safeModeMaxForkDistance cv {} 0 [0, 2] payload
  let bl := lines s4 "b_console"
  let al := lines s4 "a_console"
  t := t.check (outB == .relayed && effB == [.relay 0 msg.encode, .webhook "127.0.0.1" port "/dsdetected/b" (msg.json cfgB.webhookMaxTxnSize)])
    "s4: B's model effects"
  t := t.check (outA == .relayed && effA == [.relay 2 msg.encode, .webhook "127.0.0.1" port "/dsdetected/a" (msg.json cfgA.webhookMaxTxnSize)])
    "s4: A's model effects"
  t := t.check (anyLine bl "Valid double-spend detected message from peer=2" && anyLine bl s!"sending dsdetected ({msg.encode.length} bytes) peer=0")
    "s4: B's lines (valid from PB, sent to A only)"
  t := t.check (anyLine al "Valid double-spend detected message from peer=0" && anyLine al s!"sending dsdetected ({msg.encode.length} bytes) peer=2")
    "s4: A's lines (valid from B, sent to PA only)"
  t := t.check (body "/dsdetected/b" == some (msg.json cfgB.webhookMaxTxnSize)) "s4: B's webhook body differs from the model's JSON"
  t := t.check (body "/dsdetected/a" == some (msg.json cfgA.webhookMaxTxnSize)) "s4: A's webhook body differs from the model's JSON"
  let pbGot := ((← arr (← s4.getObjVal? "pb_received")).filterMap fun e => (e.getObjValAs? String "command").toOption)
  t := t.check (!pbGot.contains "dsdetected") "s4: PB (the sender) received the message back"
  t := { t with lines := t.lines ++ [s!"dsnt dsdetected s4: {t.word w0} [X] {t.reading w0 s!"B: relayed to A only, posted /dsdetected/b; A: relayed to PA only, posted /dsdetected/a; both bodies equal to DSDetected.json byte for byte, {msg.json cfg.webhookMaxTxnSize |>.length} bytes" ""}"] }
  w0 := t.witnesses.length
  let s5 ← step r "s5-dsdetected-duplicate"
  let (_, outDup, effDup) := processDSDetected cfgB nodeConfig.safeModeMaxForkDistance cv cacheB 2 [0, 2] payload
  let got5 ← arr (← s5.getObjVal? "receiver")
  let pa5 ← arr (← s5.getObjVal? "pa_received")
  t := t.check (outDup == .duplicate && effDup.isEmpty && got5.isEmpty && pa5.isEmpty &&
      anyLine (lines s5 "b_console") "Ignoring duplicate double-spend detected message from peer=2")
    "s5: the duplicate"
  t := { t with lines := t.lines ++ [s!"dsnt dsdetected s5: {t.word w0} [X] (the repeat answered by the duplicate cache: no relay, no post)"] }
  w0 := t.witnesses.length
  return t

def run (path : String) : IO UInt32 := do
  match Json.parse (← IO.FS.readFile path) >>= judge with
  | .error e => IO.eprintln s!"dsnt projection: ERROR {e}"; return 1
  | .ok t =>
    for l in t.lines do IO.println l
    for w in t.witnesses do IO.println s!"  witness: {w}"
    let ok := t.witnesses.isEmpty
    IO.println s!"dsnt projection: {if ok then "GREEN" else "RED"} [X] ({t.agree} checks agree; {t.witnesses.length} witnesses; the receipt {path})"
    return if ok then 0 else 1

end DsntCheck
