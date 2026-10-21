import BsvChain
import Lean.Data.Json

/-!
# The relay machine against two regtest instances (#78)

[D] 2026-10-15 (#78). Run by `chaincheck --p2p <record.json>` and
`chaincheck --p2p-frames <frames.jsonl>` (the run's frames,
corpus/p2p/2026-10-15-relay-frames.jsonl); both in the chain leg.

`--p2p` reads a receipt of `run_scenarios --relay` and the scenario it names
(corpus/scenarios/2026-10-15-p2p-relay-two-node.md). It runs the relay machine
(`lean/BsvChain/Wire/Relay.lean`) on two nodes joined by one link, applies each
step's stimuli, lets the nodes exchange messages until quiet (the propagator's
pass, every peer's request pass, flush and ban step, in rounds), and compares
three ways per step: the scenario's declared observations against the
machine's, and the machine's against the receipt: the messages each logging
peer received (its frames decoded by the Lean codec), the bytes each node
counted per command on the link (`getpeerinfo`'s per-command counters: equal to
the machine's frames, or to the same items cut into more messages), the pools,
the recorded increments (the node's `Misbehaving` lines), the disconnections
and the ban list. The verdicts of the mempool are inputs: the scenario's,
with a transaction whose parent is neither mined nor pooled read as missing
its inputs. A header over its cap (step s8) is derived from the bytes the
runner sent, through `Header.read` and `Header.oversized`, never only
declared; a logging peer's frames outside the machine's messages must be the
handshake, keep-alive and settings commands (`unmodelled`), any other is a
witness.

`--p2p-frames` (and `--p2p` over the receipt's frames) reads every frame back
through `unframe` and writes it again byte for byte through `frame`, and runs
the payload codecs of `inv`, `getdata`, `notfound`, `reject`, `ping`, `pong`,
`protoconf` and `version` both ways. Views of the relay layer, never rules of
validity.
-/

open Lean BsvScript.Numbers BsvScript.Tx BsvChain.Wire

namespace P2PCheck

def need (x : Option α) (message : String) : Except String α :=
  match x with | some a => .ok a | none => .error message

def hex (s : String) : Except String Bytes := need (hexDecode s) s!"bad hex {s.take 16}"

/-- [D] 2026-10-15: a display id (big-endian hex) as the wire's internal bytes. -/
def internal (s : String) : Except String Bytes := do return (← hex s).reverse

def arr (j : Json) : Except String (List Json) := do return (← j.getArr?).toList

/-! ## The frames -/

/-- [D] 2026-10-15: one frame read back and written again; the payload codecs
where the vocabulary has one. The result names the command. -/
def frameRoundTrip (bs : Bytes) : Except String String := do
  let ((cmd, payload), rest) ← need (unframe bs) "unframe refused"
  unless rest.isEmpty do throw "trailing bytes after the frame"
  unless frame regtestMagic cmd payload == bs do throw "frame does not write back"
  let name := String.ofList (cmd.map Char.ofNat)
  if name == "inv" || name == "getdata" || name == "notfound" then
    let items ← need (decodeInv payload) s!"{name} payload"
    unless encodeInv items == payload do throw s!"{name} payload does not write back"
  else if name == "reject" then
    let r ← need (Reject.decode payload) "reject payload"
    unless r.encode == payload do throw "reject payload does not write back"
  else if name == "ping" || name == "pong" then
    let n ← need (decodeNonce payload) s!"{name} nonce"
    unless encodeNonce n == payload do throw s!"{name} does not write back"
  else if name == "protoconf" then
    let p ← need (Protoconf.decode payload) "protoconf payload"
    unless p.encode == payload do throw "protoconf does not write back"
  else if name == "version" then
    let v ← need (Version.decode payload) "version payload"
    unless v.encode == payload do throw "version does not write back"
  return name

def codecs : List String := ["inv", "getdata", "notfound", "reject", "ping", "pong", "protoconf", "version"]

/-- [D] 2026-10-15: every frame of a list; per command the count, and how many
went through a payload codec as well. -/
def framesCheck (frames : List Json) : Except String (Nat × List (String × Nat)) := do
  let mut counts : List (String × Nat) := []
  for f in frames do
    let bs ← hex (← f.getObjValAs? String "hex")
    let name ← frameRoundTrip bs
    counts := match counts.find? (·.1 == name) with
      | some _ => counts.map (fun (k, n) => if k == name then (k, n + 1) else (k, n))
      | none => counts ++ [(name, 1)]
  return (frames.length, counts)

def framesLine (n : Nat) (counts : List (String × Nat)) : String :=
  let viaCodec := (counts.filter (fun (k, _) => codecs.contains k)).foldl (· + ·.2) 0
  let parts := counts.map (fun (k, c) => s!"{k} {c}")
  s!"p2p frames: GREEN [X] ({n} frames read back and written again byte for byte; {viaCodec} through a payload codec both ways; {String.intercalate ", " parts})"

/-! ## The two nodes -/

structure Names where
  ids : List (String × Bytes)
  raw : List (String × Bytes)
  mined : List Bytes

def Names.id (ns : Names) (n : String) : Except String Bytes := need (ns.ids.lookup n) s!"unbound name {n}"
def Names.name (ns : Names) (h : Bytes) : String :=
  match ns.ids.find? (·.2 == h) with | some (n, _) => n | none => s!"?{hexEncode h |>.take 12}"

/-- [D] 2026-10-15: a side's peers by name and id; the link's name on each side. -/
structure Side where
  name : String
  peers : List (String × PeerId)
  link : String

def Side.pid (s : Side) (n : String) : Except String PeerId := need (s.peers.lookup n) s!"no peer {n} at {s.name}"
def Side.peerName (s : Side) (pid : PeerId) : String :=
  match s.peers.find? (·.2 == pid) with | some (n, _) => n | none => s!"#{pid}"

structure Net where
  a : Node
  b : Node
  sa : Side
  sb : Side

def Net.node (net : Net) (side : String) : Node := if side == "A" then net.a else net.b
def Net.side (net : Net) (side : String) : Side := if side == "A" then net.sa else net.sb
def Net.set (net : Net) (side : String) (n : Node) : Net :=
  if side == "A" then { net with a := n } else { net with b := n }
def other (side : String) : String := if side == "A" then "B" else "A"

/-- [D] 2026-10-15: an observed message: the sending side, the receiving peer's
name (the link's name for the other node), the message. -/
structure Obs where
  sender : String
  peer : String
  msg : Msg

/-- [D] 2026-10-15: the scenario's verdicts, with the parents read from the
transaction's bytes: a parent neither mined nor pooled is missing. -/
def verdict (ns : Names) (base : List (String × Verdict)) (node : Node) (name : String) :
    Except String Verdict := do
  let raw ← need (ns.raw.lookup name) s!"no bytes for {name}"
  let tx ← need (decodeTx raw) s!"{name} does not decode"
  let parents := tx.inputs.map (·.prevHash) |>.filter (fun h => ns.ids.any (·.2 == h))
  let missing := parents.filter (fun h => !ns.mined.contains h && !node.pool.contains h)
  if !missing.isEmpty then return .missingInputs missing
  need (base.lookup name) s!"no verdict for {name}"

def queued (ns : Names) (name : String) : Except String Queued := do
  let raw ← need (ns.raw.lookup name) s!"no bytes for {name}"
  return { id := ← ns.id name, fee := 1000, size := raw.length }

/-- [D] 2026-10-15: a transaction received, then every orphan whose parents
are now pooled retried (src/txn_validator.cpp:695-724). -/
def receiveTx (ns : Names) (base : List (String × Verdict)) (node : Node) (pid : PeerId) (name : String) :
    Except String (Node × List (PeerId × Msg)) := do
  let v ← verdict ns base node name
  let (n1, o1) := node.recvTx pid (← queued ns name) v
  let mut n := n1
  let mut out := o1
  for _ in [0:4] do
    for (oid, _, _) in n.orphans do
      let oname := ns.name oid
      let v ← verdict ns base n oname
      match v with
      | .missingInputs _ => pure ()
      | _ =>
        let (n2, o2) := n.retryOrphan (← queued ns oname) v
        n := n2; out := out ++ o2
  return (n, out)

/-- [D] 2026-10-15: deliver a node's outputs: to the other node over the link,
or recorded for a logging peer. The fuel bounds the exchange. -/
partial def route (ns : Names) (base : List (String × Verdict)) (net : Net) (sender : String)
    (outs : List (PeerId × Msg)) (fuel : Nat) : Except String (Net × List Obs) := do
  if fuel == 0 then throw "route: no fuel"
  let mut net := net
  let mut obs : List Obs := []
  for (pid, msg) in outs do
    let ss := net.side sender
    let pname := ss.peerName pid
    obs := obs ++ [{ sender, peer := pname, msg }]
    if pname == ss.link then
      let recv := other sender
      let rs := net.side recv
      let from_ ← rs.pid rs.link
      let node := net.node recv
      match msg with
      | .inv items => net := net.set recv (node.recvInv from_ items)
      | .getdata items =>
        let (net', o) ← route ns base net recv (node.recvGetData from_ items) (fuel - 1)
        net := net'; obs := obs ++ o
      | .tx h =>
        let (n2, o2) ← receiveTx ns base node from_ (ns.name h)
        let (net', o) ← route ns base (net.set recv n2) recv o2 (fuel - 1)
        net := net'; obs := obs ++ o
      | _ => pure ()
  return (net, obs)

/-- [D] 2026-10-15: one round: on each side the propagator's pass, then for
every peer the request pass, the flush and the ban step. -/
def round (ns : Names) (base : List (String × Verdict)) (net : Net) : Except String (Net × List Obs) := do
  let mut net := net
  let mut obs : List Obs := []
  for side in ["A", "B"] do
    net := net.set side (net.node side).propagate
    for (_, pid) in (net.side side).peers do
      let (n1, o1) := (net.node side).request pid
      let (net1, ob1) ← route ns base (net.set side n1) side o1 16
      let (n2, o2) := (net1.node side).flush pid
      let (net2, ob2) ← route ns base (net1.set side n2) side o2 16
      net := net2.set side ((net2.node side).consumeBan pid)
      obs := obs ++ ob1 ++ ob2
  return (net, obs)

def settle (ns : Names) (base : List (String × Verdict)) (net : Net) : Except String (Net × List Obs) := do
  let mut net := net
  let mut obs : List Obs := []
  for _ in [0:12] do
    let (net', o) ← round ns base net
    net := net'
    if o.isEmpty then return (net, obs)
    obs := obs ++ o
  throw "settle: the nodes did not go quiet in 12 rounds"

/-- [D] 2026-10-15: a step's stimuli at their nodes. -/
def stimulus (ns : Names) (base : List (String × Verdict)) (net : Net) (j : Json) :
    Except String (Net × List Obs) := do
  let at_ ← j.getObjValAs? String "at"
  let ev ← j.getObjValAs? String "event"
  let node := net.node at_
  let side := net.side at_
  match ev with
  | "recvInv" =>
    let pid ← side.pid (← j.getObjValAs? String "from")
    let items ← (← arr (← j.getObjVal? "items")).mapM (fun i => do return txItem (← ns.id (← i.getStr?)))
    return (net.set at_ (node.recvInv pid items), [])
  | "recvTx" =>
    let pid ← side.pid (← j.getObjValAs? String "from")
    let (n, o) ← receiveTx ns base node pid (← j.getObjValAs? String "tx")
    route ns base (net.set at_ n) at_ o 16
  | "rpcAccepted" =>
    return (net.set at_ (node.rpcAccepted (← queued ns (← j.getObjValAs? String "tx"))), [])
  | "setIbd" => return (net.set at_ { node with ibd := ← j.getObjValAs? Bool "value" }, [])
  | "connect" =>
    let pid ← side.pid (← j.getObjValAs? String "peer")
    return (net.set at_ { node with peers := node.peers ++ [{ id := pid, addr := 1, isLocal := true }] }, [])
  | "close" =>
    let pid ← side.pid (← j.getObjValAs? String "peer")
    return (net.set at_ { node with peers := node.peers.filter (·.id != pid) }, [])
  | "oversizedHeader" =>
    let pid ← side.pid (← j.getObjValAs? String "from")
    return (net.set at_ (node.step (.oversizedHeader pid)).1, [])
  | e => throw s!"unknown stimulus {e}"

/-! ## Observations, the machine's and the node's -/

def itemNames (ns : Names) (items : List InvItem) : List String := items.map (fun i => ns.name i.hash)

def sortS (l : List String) : List String := (l.toArray.qsort (· < ·)).toList

/-- [D] 2026-10-15: per peer and command, the item names (sorted) and for
`reject` the code, the reason and the name. -/
def summarize (ns : Names) (obs : List Obs) (peer : String) : List (String × List String) :=
  let ms := obs.filter (·.peer == peer) |>.map (·.msg)
  let inv := ms.foldl (fun acc m => match m with | .inv i => acc ++ itemNames ns i | _ => acc) []
  let gd := ms.foldl (fun acc m => match m with | .getdata i => acc ++ itemNames ns i | _ => acc) []
  let txs := ms.foldl (fun acc m => match m with | .tx h => acc ++ [ns.name h] | _ => acc) []
  let nf := ms.foldl (fun acc m => match m with | .notfound i => acc ++ itemNames ns i | _ => acc) []
  let rj := ms.foldl (fun acc m => match m with
    | .reject r => acc ++ [s!"{r.code}/{String.ofList (r.reason.map Char.ofNat)}/{(r.hash.map ns.name).getD "-"}"]
    | _ => acc) []
  [("inv", sortS inv), ("getdata", sortS gd), ("tx", sortS txs), ("notfound", sortS nf),
    ("reject", rj)].filter (!·.2.isEmpty)

/-- [D] 2026-10-15: the commands a logging peer may receive that the machine
does not model: the handshake, the keep-alive and the settings a node sends
every peer (src/net/net_processing.cpp at 6504a3af); any other unmodelled
command is a witness. -/
def unmodelled : List String :=
  ["ping", "pong", "feefilter", "sendheaders", "sendcmpct", "protoconf", "authch", "getheaders",
   "version", "verack"]

/-- [D] 2026-10-15: a logging peer's received frames, decoded by the Lean codec:
the summary in `summarize`'s form (a `tx` named by its payload's double
SHA-256) and the commands outside the machine and outside `unmodelled`. -/
def observedPeer (ns : Names) (events : List Json) :
    Except String (List (String × List String) × List String) := do
  let mut inv : List String := []
  let mut gd : List String := []
  let mut txs : List String := []
  let mut nf : List String := []
  let mut rj : List String := []
  let mut stray : List String := []
  for e in events do
    let bs ← hex (← e.getObjValAs? String "frame")
    let ((cmd, payload), _) ← need (unframe bs) "unframe refused"
    let name := String.ofList (cmd.map Char.ofNat)
    if name == "inv" then inv := inv ++ itemNames ns (← need (decodeInv payload) "inv")
    else if name == "getdata" then gd := gd ++ itemNames ns (← need (decodeInv payload) "getdata")
    else if name == "tx" then txs := txs ++ [ns.name (BsvScript.Hash.sha256d payload)]
    else if name == "notfound" then nf := nf ++ itemNames ns (← need (decodeInv payload) "notfound")
    else if name == "reject" then
      let r ← need (Reject.decode payload) "reject"
      rj := rj ++ [s!"{r.code}/{String.ofList (r.reason.map Char.ofNat)}/{(r.hash.map ns.name).getD "-"}"]
    else if !unmodelled.contains name then stray := stray ++ [name]
  return ([("inv", sortS inv), ("getdata", sortS gd), ("tx", sortS txs), ("notfound", sortS nf),
    ("reject", rj)].filter (!·.2.isEmpty), stray)

/-- [D] 2026-10-15: the stimulus of a header over its cap, derived from the
bytes the runner sent (the step's `raw.sent`) through the Lean reader: one
header and nothing after it, the regtest magic, over its command's cap and so
invalid (`Header.read`, `Header.oversized`, `Header.valid`) at the run's caps
(`runCaps`). The answer is whether the bytes are such a header, and what they
read as; bytes that do not read as a header are an error. -/
def derivedOversized (ob : Json) : Except String (Bool × String) := do
  let sent ← hex (← (← ob.getObjVal? "raw").getObjValAs? String "sent")
  let (h, rest) ← need (Header.read sent) "raw.sent does not read as a header"
  let name := String.ofList (h.getCommand.map Char.ofNat)
  let ok := rest.isEmpty && h.magic == regtestMagic && h.oversized runCaps &&
    !h.valid runCaps regtestMagic
  return (ok, s!"{name} of {h.payloadLength} bytes against its cap {maxMessageLength runCaps h.getCommand}, {rest.length} bytes after the header")

/-- [D] 2026-10-15: the declared observations of a peer (`to`), in the summary's form. -/
def declaredPeer (j : Json) : Except String (List (String × List String)) := do
  let mut out : List (String × List String) := []
  for k in ["inv", "getdata"] do
    match j.getObjVal? k with
    | .ok v => out := out ++ [(k, sortS (← (← arr v).mapM (·.getStr?)))]
    | .error _ => pure ()
  match j.getObjVal? "reject" with
  | .ok v =>
    let rows ← (← arr v).mapM (fun r => do
      let xs ← arr r
      let code ← (xs.getD 0 Json.null).getNat?
      let reason ← (xs.getD 1 Json.null).getStr?
      let n ← (xs.getD 2 Json.null).getStr?
      return s!"{code}/{reason}/{n}")
    out := out ++ [("reject", rows)]
  | .error _ => pure ()
  return out

/-- [D] 2026-10-15: the bytes of a command on the link, from the machine's
messages: each message's frame through the Lean encoder. -/
def frameBytes (ns : Names) (m : Msg) : Except String (String × Nat × Nat) := do
  match m with
  | .inv i => return ("inv", (frame regtestMagic (asciiBytes "inv") (encodeInv i)).length, i.length)
  | .getdata i => return ("getdata", (frame regtestMagic (asciiBytes "getdata") (encodeInv i)).length, i.length)
  | .tx h => return ("tx", (frame regtestMagic (asciiBytes "tx") (← need (ns.raw.lookup (ns.name h)) "tx bytes")).length, 1)
  | .notfound i => return ("notfound", (frame regtestMagic (asciiBytes "notfound") (encodeInv i)).length, i.length)
  | .reject r => return ("reject", (frame regtestMagic (asciiBytes "reject") r.encode).length, 1)

def counterDelta (before after : Json) (k : String) : Nat :=
  let a := (after.getObjValAs? Nat k).toOption.getD 0
  let b := (before.getObjValAs? Nat k).toOption.getD 0
  a - b

structure Verdicts where
  lines : List String := []
  witnesses : List String := []
  matched : Nat := 0

def Verdicts.check (v : Verdicts) (ok : Bool) (what : String) : Verdicts :=
  if ok then { v with matched := v.matched + 1 } else { v with witnesses := v.witnesses ++ [what] }

/-- [D] 2026-10-15: the link's bytes per command against the counters: equal to
the machine's frames, or the same items cut into k messages (k from 1 to the
item count; an `inv` or `getdata` frame of n items is 25 + 36n bytes below 253
items). -/
def linkAgree (predicted : List (String × Nat × Nat)) (cmd : String) (observed : Nat) : Bool × String :=
  let ps := predicted.filter (·.1 == cmd)
  let bytes := ps.foldl (· + ·.2.1) 0
  let items := ps.foldl (· + ·.2.2) 0
  if observed == bytes then (true, "exact")
  else if (cmd == "inv" || cmd == "getdata") && items > 0 &&
      (List.range items).any (fun k => observed == 25 * (k + 1) + 36 * items) then (true, "re-cut")
  else (false, s!"predicted {bytes} bytes, observed {observed}")

def score (n : Node) (pid : PeerId) : Nat := n.score pid

/-- [D] 2026-10-15: the receipt's steps against the machine, step by step. -/
def judge (rec' : Json) (raw : String) : Except String (List String × Nat × Nat × Nat × String) := do
      let fence ← need ((raw.splitOn "```json\n")[1]? >>= fun r => (r.splitOn "\n```")[0]?) "scenario fence"
      let scen ← Json.parse fence
      let nm ← rec'.getObjVal? "names"
      let txs ← nm.getObjVal? "transactions"
      let mut ids : List (String × Bytes) := []
      let mut raws : List (String × Bytes) := []
      for n in ["F", "T", "P", "C", "K", "D"] do
        let t ← txs.getObjVal? n
        let rawb ← hex (← t.getObjValAs? String "hex")
        let idb ← internal (← t.getObjValAs? String "txid")
        unless BsvScript.Hash.sha256d rawb == idb do throw s!"{n}: txid is not the bytes' double hash"
        ids := ids ++ [(n, idb)]; raws := raws ++ [(n, rawb)]
      ids := ids ++ [("X", ← internal (← nm.getObjValAs? String "x")), ("Y", ← internal (← nm.getObjValAs? String "y"))]
      let mined ← (← arr (← (← scen.getObjVal? "initial_chain").getObjVal? "mined")).mapM (fun j => do
        need (ids.lookup (← j.getStr?)) "mined name")
      let ns : Names := { ids, raw := raws, mined }
      let vj ← scen.getObjVal? "verdicts"
      let mut base : List (String × Verdict) := []
      for n in ["T", "P", "C", "K", "D"] do
        let v ← vj.getObjVal? n
        match v.getStr? with
        | .ok "accepted" => base := base ++ [(n, .accepted)]
        | _ =>
          let xs ← arr (← v.getObjVal? "invalid")
          base := base ++ [(n, .invalid (← (xs.getD 0 Json.null).getNat?)
            (asciiBytes (← (xs.getD 1 Json.null).getStr?)) (← (xs.getD 2 Json.null).getNat?) false)]
      -- [D] the topology: every peer local at one address; the link on each side.
      let sa : Side := { name := "A", peers := [("B", 1), ("PA", 2), ("R", 3)], link := "B" }
      let sb : Side := { name := "B", peers := [("probe", 0), ("A", 1), ("PB", 2)], link := "A" }
      let topo ← scen.getObjVal? "topology"
      let start (side : Side) : Except String Node := do
        let t ← topo.getObjVal? side.name
        let names ← (← arr (← t.getObjVal? "connected")).mapM (·.getStr?)
        let peers ← names.mapM (fun n => do return ({ id := ← side.pid n, addr := 1, isLocal := true } : Peer))
        return { ibd := ← t.getObjValAs? Bool "ibd", peers }
      let mut net : Net := { a := ← start sa, b := ← start sb, sa, sb }
      let steps ← arr (← scen.getObjVal? "steps")
      let observed ← arr (← rec'.getObjVal? "steps")
      let mut lines : List String := []
      let mut matchedAll := 0
      let mut witnessesAll := 0
      let mut messages := 0
      for (st, ob) in steps.zip observed do
        let sid ← st.getObjValAs? String "id"
        unless (← ob.getObjValAs? String "id") == sid do throw s!"step order differs at {sid}"
        let logA0 := net.a.log.length
        let logB0 := net.b.log.length
        let mut obs : List Obs := []
        -- each stimulus, then the nodes until quiet: the runner waits for each
        -- stimulus's effect before the next (harness/src/scenarios/relay.rs)
        let mut derived : List (Bool × String) := []
        for j in ← arr (← st.getObjVal? "stimulus") do
          -- a header over its cap is derived from the bytes sent, never only declared
          if (j.getObjValAs? String "event").toOption == some "oversizedHeader" then
            derived := derived ++ [← derivedOversized ob]
          let (net', o) ← stimulus ns base net j
          let (net'', o') ← settle ns base net'
          net := net''; obs := obs ++ o ++ o'
        messages := messages + obs.length
        let exp ← st.getObjVal? "expected_observations"
        let mut v : Verdicts := {}
        for (ok, d) in derived do
          v := v.check ok s!"{sid} the bytes sent are not an oversized header: {d}"
        -- the logging peers
        for (peer, key) in [("probe", "probe_received"), ("PB", "pb_received"), ("PA", "pa_received")] do
          match ob.getObjVal? key with
          | .error _ => pure ()
          | .ok evs =>
            let (seen, stray) ← observedPeer ns (← arr evs)
            let mach := summarize ns obs peer
            v := v.check (seen == mach) s!"{sid} {peer}: machine {mach} node {seen}"
            v := v.check stray.isEmpty s!"{sid} {peer}: unmodelled commands received {stray}"
            match (exp.getObjVal? "to") >>= (·.getObjVal? peer) with
            | .ok d => let dd ← declaredPeer d; v := v.check (dd == mach) s!"{sid} {peer}: declared {dd} machine {mach}"
            | .error _ => pure ()
        -- the link's counters
        match ob.getObjVal? "counters_before", ob.getObjVal? "counters_after" with
        | .ok cb, .ok ca =>
          for (dir, sender, ctr) in [("A>B", "A", "a"), ("B>A", "B", "b")] do
            let link := (net.side sender).link
            let pred ← (obs.filter (fun o => o.sender == sender && o.peer == link)).mapM (fun o => frameBytes ns o.msg)
            let sent ← (← ca.getObjVal? ctr).getObjVal? "sent"
            let sent0 ← (← cb.getObjVal? ctr).getObjVal? "sent"
            let recvSide := if ctr == "a" then "b" else "a"
            let recv ← (← ca.getObjVal? recvSide).getObjVal? "recv"
            let recv0 ← (← cb.getObjVal? recvSide).getObjVal? "recv"
            for cmd in ["inv", "getdata", "tx", "notfound", "reject"] do
              let o := counterDelta sent0 sent cmd
              let o' := counterDelta recv0 recv cmd
              let (ok, why) := linkAgree pred cmd o
              v := v.check (ok && o == o') s!"{sid} {dir} {cmd}: {why}; the receiver counted {o'}"
            match (exp.getObjVal? "edges") >>= (·.getObjVal? dir) with
            | .ok d =>
              for cmd in ["inv", "getdata", "tx"] do
                let dd := match d.getObjVal? cmd with
                  | .ok xs => sortS ((arr xs).toOption.getD [] |>.filterMap (fun x => x.getStr?.toOption))
                  | .error _ => []
                let mm := (summarize ns (obs.filter (·.sender == sender)) link).lookup cmd |>.getD []
                v := v.check (dd == mm) s!"{sid} {dir} {cmd}: declared {dd} machine {mm}"
            | .error _ => pure ()
        | _, _ => pure ()
        -- the pools
        match ob.getObjVal? "pool" with
        | .ok pj =>
          for (side, key) in [("A", "a"), ("B", "b")] do
            let seen ← (← arr (← pj.getObjVal? key)).mapM (fun j => do return ns.name (← internal (← j.getStr?)))
            let mach := (net.node side).pool.map ns.name
            v := v.check (sortS seen == sortS mach) s!"{sid} pool {side}: machine {mach} node {seen}"
            match (exp.getObjVal? "pool") >>= (·.getObjVal? side) with
            | .ok d =>
              let dd ← (← arr d).mapM (·.getStr?)
              v := v.check (sortS dd == sortS mach) s!"{sid} pool {side}: declared {dd} machine {mach}"
            | .error _ => pure ()
        | .error _ => pure ()
        -- the increments: the machine's new log entries and the node's Misbehaving lines
        for (side, key, l0) in [("A", "a_console", logA0), ("B", "b_console", logB0)] do
          match ob.getObjVal? key with
          | .error _ => pure ()
          | .ok cj =>
            let lines' ← (← arr cj).mapM (·.getStr?)
            let seen := lines'.filter (fun l => (l.splitOn "Misbehaving:").length > 1) |>.filterMap (fun l =>
              match (l.splitOn "(").getLast?.map (·.splitOn ")") with
              | some (arrow :: rest :: _) =>
                let nums := arrow.splitOn " -> "
                match nums with
                | [x, y] => match x.toNat?, y.toNat? with
                  | some a, some b =>
                    let reason := ((rest.splitOn "reason: ")[1]?.getD "").splitOn " BAN THRESHOLD" |>.head!
                    some s!"{b - a}/{reason.trimAscii.toString}"
                  | _, _ => none
                | _ => none
              | _ => none)
            let entries := (net.node side).log.drop l0
            let mach := entries.map (fun (_, n, r) => s!"{n}/{String.ofList (r.map Char.ofNat)}")
            v := v.check (seen == mach) s!"{sid} increments {side}: machine {mach} node {seen}"
            match (exp.getObjVal? "increments") >>= (·.getObjVal? side) with
            | .ok d =>
              let dd ← (← arr d).mapM (fun r => do
                let xs ← arr r
                return s!"{← (xs.getD 1 Json.null).getNat?}/{← (xs.getD 2 Json.null).getStr?}")
              v := v.check (dd == mach) s!"{sid} increments {side}: declared {dd} machine {mach}"
            | .error _ => pure ()
        -- disconnections and bans
        for (side, peersKey, bannedKey) in [("A", "a_peers_after", "a_banned"), ("B", "b_peers", "b_banned")] do
          match ob.getObjVal? bannedKey with
          | .error _ => pure ()
          | .ok bj =>
            let seen ← (← arr bj).mapM (fun e => do
              return s!"{← e.getObjValAs? String "address"}/{← e.getObjValAs? String "ban_reason"}")
            let mach := (net.node side).banned.map (fun b =>
              s!"127.0.0.1/32/{if b.cause == .operator then "manually added" else "node misbehaving"}")
            v := v.check (seen == mach) s!"{sid} banned {side}: machine {mach} node {seen}"
            match (exp.getObjVal? "banned") >>= (·.getObjVal? side) with
            | .ok d =>
              let dd ← (← arr d).mapM (fun r => do return s!"{← ((← arr r).getD 1 Json.null).getStr?}")
              let mc := (net.node side).banned.map (fun b => reprStr b.cause |>.replace "BsvChain.Wire.BanCause." "")
              v := v.check (dd == mc) s!"{sid} banned {side}: declared {dd} machine {mc}"
            | .error _ => pure ()
            match ob.getObjVal? peersKey with
            | .error _ => pure ()
            | .ok pj =>
              let present ← (← arr pj).mapM (fun p => do return (← p.getObjValAs? String "subver"))
              let sideRec := net.side side
              let gone := (net.node side).peers.filter (·.disconnect) |>.map (fun p => sideRec.peerName p.id)
              -- the node lists only connected peers: a peer the machine disconnected is absent
              let nodeLink := present.any (fun s => (s.splitOn "Bitcoin SV").length > 1)
              let nodeTest := present.any (fun s => (s.splitOn "mininode").length > 1)
              let machLink := !gone.contains sideRec.link
              let testName := if side == "A" then "PA" else "PB"
              let machTest := !gone.contains testName
              v := v.check (nodeLink == machLink && nodeTest == machTest)
                s!"{sid} peers {side}: machine disconnected {gone}; node lists {present}"
              match (exp.getObjVal? "disconnected") >>= (·.getObjVal? side) with
              | .ok d =>
                let dd ← (← arr d).mapM (·.getStr?)
                v := v.check (sortS dd == sortS gone) s!"{sid} disconnected {side}: declared {dd} machine {gone}"
              | .error _ => pure ()
        -- the score of PB, where the step declares it
        match (exp.getObjVal? "score") >>= (·.getObjValAs? Nat "PB") with
        | .ok d => v := v.check (score net.b 2 == d) s!"{sid} score PB: declared {d} machine {score net.b 2}"
        | .error _ => pure ()
        match ob.getObjVal? "b_pb_banscore" with
        | .ok j => match j.getNat? with
          | .ok n => v := v.check (n == score net.b 2) s!"{sid} score PB: node {n} machine {score net.b 2}"
          | .error _ => pure ()
        | .error _ => pure ()
        -- the probes the runner asserted
        for key in ["probe_expect_none", "pb_expect_getdata", "pa_expect_inv", "pb_expect_inv",
            "pb_expect_getdata_parent", "a_pool_has_p_c", "b_pool_has_t", "pb_expect_none"] do
          match ob.getObjValAs? Bool key with
          | .ok b => v := v.check b s!"{sid} {key} false"
          | .error _ => pure ()
        if sid == "s2-connect-sync" then
          v := v.check ((← ob.getObjValAs? Nat "b_height") == 101) s!"{sid}: B did not reach height 101"
        -- [D] a disconnected peer leaves the node's list (the connection
        -- manager's cleanup, `CConnman::ThreadSocketHandler`'s disconnect block,
        -- src/net/net.cpp:1588-1614 at 6504a3af, outside the machine)
        net := { net with a := { net.a with peers := net.a.peers.filter (!·.disconnect) },
                          b := { net.b with peers := net.b.peers.filter (!·.disconnect) } }
        let verdictWord := if v.witnesses.isEmpty then "agree" else "diverge"
        lines := lines ++ [s!"p2p projection {sid}: {verdictWord} [X] ({v.matched} checks, {obs.length} machine messages{if v.witnesses.isEmpty then "" else "; witnesses: " ++ String.intercalate "; " v.witnesses})"]
        matchedAll := matchedAll + v.matched
        witnessesAll := witnessesAll + v.witnesses.length
      let (nf, counts) ← framesCheck (← arr (← rec'.getObjVal? "frames"))
      return (lines, matchedAll, witnessesAll, messages, framesLine nf counts)

def run (path : String) : IO UInt32 := do
  let res ← do
    match Json.parse (← IO.FS.readFile path) with
    | .error e => pure (.error e)
    | .ok rec' =>
      match rec'.getObjValAs? String "scenario" with
      | .error e => pure (.error e)
      | .ok scenPath => pure (judge rec' (← IO.FS.readFile scenPath))
  match res with
  | .error e => IO.eprintln s!"p2p projection: ERROR {e}"; return 1
  | .ok (lines, matched, witnesses, messages, fl) =>
    for l in lines do IO.println l
    IO.println fl
    let ok := witnesses == 0
    IO.println s!"p2p projection: {if ok then "GREEN" else "RED"} [X] ({lines.length} steps; {matched} checks agree; {witnesses} witnesses; {messages} machine messages; the receipt {path})"
    return if ok then 0 else 1

/-- [D] 2026-10-15: the frames corpus alone (one JSON object a line, its `hex`). -/
def runFrames (path : String) : IO UInt32 := do
  let rows := (← IO.FS.readFile path).splitOn "\n" |>.filter (fun s => !s.trimAscii.toString.isEmpty)
  match rows.mapM Json.parse >>= framesCheck with
  | .error e => IO.eprintln s!"p2p frames: RED {e}"; return 1
  | .ok (n, counts) => IO.println (framesLine n counts); return if n > 0 then 0 else 1

end P2PCheck
