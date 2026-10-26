import BsvChain
import Lean.Data.Json
import Test.NodeMetadata
-- #91 (2026-10-14): the sentinel grid's #guard lines run when chaincheck builds.
import Test.SentinelCheck
-- #83 (2026-10-15): the Miner ID check, run by `chaincheck --minerid`.
import Test.MinerIdCheck
-- #78 (2026-10-15): the relay machine against two instances, run by `chaincheck --p2p`.
import Test.P2PCheck
-- #79 (2026-10-15): compact blocks against two instances, run by `chaincheck --compact`.
import Test.CompactCheck
-- #80 (2026-10-15): the double-spend notifications against two instances, run by `chaincheck --dsnt`.
import Test.DsntCheck
-- #82 (2026-10-15): the pruning check, run by `chaincheck --prune <file>`.
import Test.PruneCheck

/-!
# Derived chain witnesses (#64)

Every selected height, amount, time, nonce-search budget and byte-only
allocation below is [D] synthetic input. The node column records per-row metadata independently of this spec projection.
The stored expectations are read independently from JSONL; observed output is
never used to approve an expectation. The script oracle is the landed evaluator.
[SRC] src/validation.cpp:3021–3719,4065–4133,4413–5330 and
src/txmempool.cpp:2330–2560 at 6504a3aff65ba97c0f6c80962b033e35ecbfed4b.
-/

open Lean BsvChain BsvScript.Tx BsvScript.Numbers

namespace ChainCheck

def need (x : Option α) (message : String) : Except String α :=
  match x with | some a => .ok a | none => .error message

def checked (x : Except Reject α) : Except String α := x.mapError (·.reason)

def checkedBlock (x : Except BlockReject α) : Except String α := x.mapError (·.reason)

def field [FromJson α] (j : Json) (key : String) (fallback : α) : Except String α :=
  match j.getObjVal? key with | .error _ => .ok fallback | .ok v => fromJson? v

/-- [D] Standard P2SH of OP_TRUE, before Genesis, with an actual evaluator
run. It needs no signature and is not a client-generated transaction fixture.
[SRC] src/validation.cpp:462–517,2690–2924 at 6504a3af. -/
def fixtureScript : Bytes := [0xa9, 20] ++ BsvScript.Hash.hash160 [0x51] ++ [0x87]

def fundingPoint : OutPoint := ⟨List.replicate 32 7, 0⟩

def transaction (point : OutPoint) (amount : Nat) (tag : Int := 1)
    (lock : Nat := 0) (sequence : Nat := 0xffffffff) : Tx :=
  ⟨tag, [⟨point.hash, point.index, [1, 0x51], sequence⟩], [⟨amount, fixtureScript⟩], lock⟩

def txPoint (tx : Tx) : OutPoint := ⟨BsvScript.Sighash.txid tx, 0⟩

def coinbase (height tag : Nat) (value : Nat := 5000000000) : Tx :=
  ⟨1, [⟨List.replicate 32 0, 0xffffffff, [2, height % 256, tag % 256], 0xffffffff⟩],
    [⟨value, fixtureScript⟩], 0⟩

def fixtureConfig : NodeConfig :=
  { NodeConfig.defaults with excessiveBlockSize := 1000000, maxStackMemoryUsageConsensus := 100000000, blockMinTxFee := 500 }

def fixtureContext (now : Int := 1700000000) : ChainContext :=
  { params := .regtest, cfg := fixtureConfig, now, bucketTime := now * 1000000000,
    accounting := .byteOnly, disconnectAccounting := ⟨0, fun tx => (BsvScript.Sighash.serTx tx).length⟩,
    innerUsage := fun tx => (BsvScript.Sighash.serTx tx).length,
    completionEvent := fun i => i.tieRank }

/-- [D] A complete header projection for the assumed intake prefix. This is an
initial-state fixture, not a claim that these historical bodies were replayed.
[SRC] src/block_index.h:330–349 at 6504a3af. -/
def initialState (coinHeight : Nat := 101) (isCoinbase : Bool := false) : ChainState := Id.run do
  let mut s : ChainState := {}
  for h in List.range 102 do
    let header : BlockHeader := ⟨1, s.view.bestBlock, 0, BitVec.ofNat 32 (1699900000 + h * 60), 0x207fffff, 0⟩
    let parent := s.active.getLast?
    let work := addChainWork ((parent.bind s.tree.get).map (·.work) |>.getD 0) header.bits
    let index : BlockIndex := { header, parent, height := h, work, tieRank := h, txCount := 1, chainTx := h + 1, status := { validity := 5 }, sequence := h + 1, completion := .ignored }
    s := { s with tree := { s.tree with nodes := s.tree.nodes ++ [index] }, active := s.active ++ [index.id], view := { s.view with bestBlock := index.id } }
  return { s with tree := { s.tree with candidates := s.active.getLast?.toList, nextSequence := 103 }, view := { s.view with coins := coinMap [(fundingPoint, ⟨100000, fixtureScript, coinHeight, isCoinbase, false⟩)] } }

def mineHeader (params : ChainParams) (header : BlockHeader) : Nat → Option BlockHeader
  | 0 => none
  | n + 1 =>
    if checkProofOfWork params header.hash header.bits then some header
    else mineHeader params { header with nonce := header.nonce + 1 } n

def makeBlock (parent : BlockIndex) (txs : List Tx) (tag : Nat) (reward : Nat := 5000000000) : Except String Block := do
  let txs := coinbase (parent.height + 1) tag reward :: txs
  let root := (blockMerkleRoot txs).root
  let header : BlockHeader := ⟨1, parent.id, BitVec.ofNat 256 (BsvScript.Numbers.leNat root),
    BitVec.ofNat 32 (1700000000 + tag), parent.header.bits, 0⟩
  let header ← need (mineHeader .regtest header 10000) "fixture nonce-search budget exhausted"
  return ⟨header, txs⟩

def tip (s : ChainState) : Except String BlockIndex := need (s.active.getLast?.bind s.tree.get) "no tip"

def store (s : ChainState) (ctx : ChainContext) (block : Block) (rank : Nat) : Except String ChainState := do
  let (s, result) := acceptBlock s ctx block rank true
  let _ ← checkedBlock result
  return s

def activate (s : ChainState) (ctx : ChainContext) : Except String ChainState := do
  let (s, status) := activateBestChain s ctx .empty evalOracle 1000
  unless status == .complete do throw s!"activation {repr status}"
  return s

def mine (s : ChainState) (ctx : ChainContext) (txs : List Tx) (tag : Nat) : Except String (ChainState × Block) := do
  let block ← makeBlock (← tip s) txs tag
  let s ← store s ctx block (1000 + tag)
  return (← activate s ctx, block)

def admit (s : ChainState) (ctx : ChainContext) (tx : Tx) : ChainState × TxOutcome :=
  let (pool, result) := accept s.mempool s.view.coins ctx.cfg (admissionContext s ctx) .empty evalOracle {}
    { tx, acceptTime := ctx.now }
  ({ s with mempool := pool }, result)

def snapshot (s : ChainState) (watched : List (String × OutPoint)) (names : List (String × Tx)) : Json :=
  Json.mkObj [
    ("height", toJson ((s.active.getLast?.bind s.tree.get).map (·.height))),
    ("coins", toJson ((watched.filter (fun (_, p) => (getCoin s.view.coins p).isSome)).map Prod.fst)),
    ("pool", toJson ((names.filter (fun (_, tx) => s.mempool.accepted.any (fun e => e.id == BsvScript.Sighash.txid tx))).map Prod.fst)),
    ("held", toJson ((names.filter (fun (_, tx) => s.mempool.nonFinal.any (fun e => e.entry.id == BsvScript.Sighash.txid tx))).map Prod.fst))]

def standardTx : Tx := transaction fundingPoint 99000
def conflictTx : Tx := transaction fundingPoint 98000 2
def watched : List (String × OutPoint) := [("F", fundingPoint), ("T", txPoint standardTx), ("K", txPoint conflictTx)]
def names : List (String × Tx) := [("T", standardTx), ("K", conflictTx)]

def completeSnapshot (s : ChainState) (points : List (String × OutPoint))
    (watched : List (String × OutPoint)) (names : List (String × Tx)) : Json :=
  let coins := points.filterMap fun (name,p) => (getCoin s.view.coins p).map (fun c => (name,p,c))
  let whole := coinMap (coins.map (fun (_,p,c) => (p,c)))
  let rows := coins.map fun (name,_,c) => Json.mkObj [
    ("outpoint",toJson name),("value",toJson c.value),("script",toJson (hexEncode c.script)),
    ("height",toJson c.height),("coinbase",toJson c.isCoinbase),("confiscation",toJson c.isConfiscation)]
  Json.mkObj [("view",snapshot s watched names),("utxo",toJson rows),("complete",toJson (decide (whole = s.view.coins)))]

def undoCase (overwrite : Bool) : Except String Json := do
  let s := initialState
  let ctx := fixtureContext
  let block ← makeBlock (← tip s) [standardTx] 1
  let cp := txPoint (← need block.transactions.head? "missing coinbase")
  let oldCoin : Coin := ⟨777, fixtureScript, 1, true, false⟩
  let view := if overwrite then { s.view with coins := s.view.coins.insert cp oldCoin } else s.view
  let connected ← checkedBlock (connectBlock view ctx.params ctx.cfg block
    (headerContext s.tree s.active.getLast?) ctx.now .empty evalOracle { bip30Required := !overwrite })
  let (status, back) := disconnectBlock connected.view ctx.params 102 block connected.undo
  return Json.mkObj [("status", toJson (reprStr status)),
    ("restored", toJson (decide (back.coins = view.coins))),
    ("overwrittenCoinPresent", toJson ((getCoin back.coins cp).isSome)),
    ("undoVectors", toJson connected.undo.transactions.length),
    ("undoCoins", toJson ((connected.undo.transactions.map (·.spent.length)).sum))]

def reorgCase (depth : Nat) : Except String Json := do
  let base := initialState
  let ctx := fixtureContext
  let mut a := base
  let mut txs : List Tx := []
  let mut aBlocks : List Block := []
  let mut point := fundingPoint
  for i in List.range depth do
    let tx := transaction point (99000 - i * 1000)
    let (next, b) ← mine a ctx [tx] (i + 1)
    a := next
    aBlocks := aBlocks ++ [b]
    txs := txs ++ [tx]
    point := txPoint tx
  let watch := [("F", fundingPoint)] ++ (txs.zipIdx.map (fun (tx,i) => (s!"T{i+1}", txPoint tx))) ++ [("K", txPoint conflictTx)]
  let nm := txs.zipIdx.map (fun (tx,i) => (s!"T{i+1}",tx)) ++ [("K",conflictTx)]
  let mut parent ← tip base
  let mut blocks : List Block := []
  for i in List.range (depth + 1) do
    let b ← makeBlock parent (if i == 0 then [conflictTx] else []) (20 + i)
    a ← store a ctx b (1020 + i)
    parent ← need (a.tree.get b.header.hash) "missing rival"
    blocks := blocks ++ [b]
  let automatic ← activate a ctx
  let aCoinbases ← aBlocks.zipIdx.mapM fun (b,i) => do
    let cb ← need b.transactions.head? "missing active coinbase"
    pure (s!"A{i+1}:coinbase", txPoint cb)
  let bCoinbases ← blocks.zipIdx.mapM fun (b,i) => do
    let cb ← need b.transactions.head? "missing rival coinbase"
    pure (s!"B{i+1}:coinbase", txPoint cb)
  let coinbasePoints := aCoinbases ++ bCoinbases
  let points := watch ++ coinbasePoints
  let mut manual := a
  let mut views := [completeSnapshot manual points watch nm]
  for _ in List.range depth do
    let (next, status) := disconnectTip manual ctx .reorg
    unless status == .ok do throw "reorg disconnect failed"
    manual := next
    views := views ++ [completeSnapshot manual points watch nm]
  for b in blocks do
    let index ← need (manual.tree.get b.header.hash) "missing forward index"
    manual ← checkedBlock (connectTip manual ctx .empty evalOracle index (← need (manual.tree.get (← need blocks.getLast? "no target").header.hash) "missing target"))
    views := views ++ [completeSnapshot manual points watch nm]
  manual := settleReorg manual ctx .empty evalOracle
  return Json.mkObj [("views", toJson views),
    ("automaticAgrees", toJson (decide (manual.view.coins = automatic.view.coins) && manual.active == automatic.active)),
    ("disconnects", toJson ((automatic.events.filter (fun e => match e with | .disconnected _ _ => true | _ => false)).length)),
    ("final", snapshot automatic watch nm)]

def readmitCase (kind : String) : Except String Json := do
  let immature := kind == "immature"
  let nonfinal := kind == "nonfinal"
  let base := initialState (if immature then 3 else 101) immature
  let ctx := fixtureContext
  let tx := if nonfinal then transaction fundingPoint 99000 1 102 0xfffffffe else standardTx
  let (one, a) ← mine base ctx (if immature || nonfinal then [] else [tx]) 1
  let s ← if immature || nonfinal then (mine one ctx [tx] 2).map Prod.fst else pure one
  let (s, status) := invalidateBlock s ctx .empty evalOracle a.header.hash 1000
  unless status == .complete do throw s!"invalidation {repr status}"
  return snapshot s [("F",fundingPoint),("T",txPoint tx)] [("T",tx)]

/-- [D] Return the connected, invalidated and reconsidered snapshots. The caller supplies the unchanged fixture context so row work starts only after selection. -/
def invalidateReconsiderCase (ctx : ChainContext) : Except String Json := do
  let base := initialState
  let (s, a) ← mine base ctx [standardTx] 1
  let (invalid, status) := invalidateBlock s ctx .empty evalOracle a.header.hash 1000
  unless status == .complete do throw "invalidate did not complete"
  let (reconsidered, status) := reconsiderBlock invalid ctx .empty evalOracle a.header.hash 1000
  unless status == .complete do throw "reconsider did not complete"
  return toJson [snapshot s watched names, snapshot invalid watched names, snapshot reconsidered watched names]

def tieCase (which : String) : Except String Json := do
  let base := initialState
  let ctx := fixtureContext
  let a ← makeBlock (← tip base) [standardTx] 1
  let b ← makeBlock (← tip base) [conflictTx] 2
  let s ← store (← store base ctx a 2000) ctx b 1000
  let tree := s.tree.modify a.header.hash (fun i => { i with sequence := 1, completion := .completed 10 })
  let tree := tree.modify b.header.hash (fun i =>
    { i with sequence := if which == "sequence" then 0 else 1, completion := .completed (if which == "completion" then 9 else 10) })
  let s := { s with tree }
  let (_, selected) := findMostWorkChain s
  return Json.mkObj [("selected", toJson (if selected.any (fun i => i.id == b.header.hash) then "B" else "A")),
    ("equalWork", toJson ((tree.get a.header.hash).map (·.work) == (tree.get b.header.hash).map (·.work)))]

def missingBodyCase (redeliver : Bool := false) : Except String Json := do
  let ctx := fixtureContext
  let base := initialState
  let a ← makeBlock (← tip base) [] 1
  let s ← store base ctx a 200
  let ai ← need (s.tree.get a.header.hash) "missing A"
  let b ← makeBlock ai [] 2
  let s ← store s ctx b 201
  let s := { s with tree := s.tree.modify a.header.hash (fun i => { i with body := none }) }
  let (s, selected) := findMostWorkChain s
  if redeliver then
    let restored ← store s ctx a 200
    let (_, selected) := findMostWorkChain restored
    return Json.mkObj [("restoredA", toJson (restored.tree.candidates.contains a.header.hash)),
      ("restoredB", toJson (restored.tree.candidates.contains b.header.hash)),
      ("selectedB", toJson (selected.any (fun i => i.id == b.header.hash))),
      ("unlinkedEmpty", toJson restored.tree.unlinked.isEmpty)]
  return Json.mkObj [("selectedBase", toJson (selected.map (·.id) == base.active.getLast?)),
    ("removedA", toJson (!s.tree.candidates.contains a.header.hash)),
    ("removedB", toJson (!s.tree.candidates.contains b.header.hash)),
    ("unlinkedB", toJson (s.tree.unlinked.contains (a.header.hash,b.header.hash)))]

/-- [D] Headers A then B, bodies B then A while P has no body. Linkage must
sequence B before A even though its header and pointer rank come later.
[SRC] src/validation.cpp:5692–5717 at 6504a3af. -/
def receiptOrderCase (ctx : ChainContext) : Except String Json := do
  let base := initialState
  let p ← makeBlock (← tip base) [] 1
  let s ← checked (acceptHeader base ctx p.header 200)
  let pi ← need (s.tree.get p.header.hash) "missing P"
  let a ← makeBlock pi [] 2
  let b ← makeBlock pi [] 3
  let s ← checked (acceptHeader (← checked (acceptHeader s ctx a.header 201)) ctx b.header 202)
  let s ← store (← store (← store s ctx b 202) ctx a 201) ctx p 200
  let ai ← need (s.tree.get a.header.hash) "missing A"
  let bi ← need (s.tree.get b.header.hash) "missing B"
  let (_, selected) := findMostWorkChain s
  return Json.mkObj [("bodyOrderWins", toJson (decide (bi.sequence < ai.sequence))),
    ("selectedB", toJson (selected.any (fun i => i.id == bi.id))),
    ("equalWork", toJson (ai.work == bi.work))]

/-- [D] 500 sat/kB requires 1050 for 2100 bytes; fee 100 is insufficient.
Mining the 2000-byte zero-fee parent leaves a 100-byte child requiring 50.
[SRC] src/txmempool.cpp:1082–1084,1161–1168 and src/amount.cpp:28–42 at 6504a3af. -/
def minedSecondaryCase (ctx : ChainContext) : Except String Json := do
  let child := transaction (txPoint standardTx) 98900
  let parentEntry : MempoolEntry := {
    tx := standardTx, fee := 0, size := 2000
    time := ctx.now, height := 101, innerUsage := 2000 }
  let childEntry : MempoolEntry := {
    tx := child, fee := 100, size := 100
    time := ctx.now, height := 101, innerUsage := 100, ancestorCount := 1 }
  let p := addUnchecked (addUnchecked {} ctx.cfg parentEntry) ctx.cfg childEntry
  let secondary := p.accepted.all (fun e => !e.primary)
  let block ← makeBlock (← tip initialState) [standardTx] 1
  let p := removeForBlock p ctx.cfg block ctx.now
  let e ← need p.accepted.head? "child removed"
  return Json.mkObj [("bothSecondaryBefore", toJson secondary),
    ("onlyChild", toJson (p.accepted.length == 1 && e.id == BsvScript.Sighash.txid child)),
    ("childPrimary", toJson e.primary), ("ancestorCount", toJson e.ancestorCount),
    ("secondaryAncestorCount", toJson e.secondaryAncestorCount)]

/-- [D] Common coinbase at 50, fork 101, old spend 150 and tip 151, rival 152.
At the partial tip 133 successor depth is 84; at original work it is 102.
The derived coinbase reward follows the network subsidy at every height.
[SRC] src/validation.cpp:2252–2262,4674–4705,4755–4767 at 6504a3af. -/
def batchingCase (ctx : ChainContext) : Except String Json := do
  let base := initialState 50 true
  let mut s := base
  for offset in List.range 50 do
    let parent ← tip s
    let block ← makeBlock parent (if offset == 48 then [standardTx] else []) (offset + 1)
      (getBlockSubsidy ctx.params (parent.height + 1))
    s ← store s ctx block (1001 + offset)
    let index ← need (s.tree.get block.header.hash) "missing old branch"
    s ← checkedBlock (connectTip s ctx .empty evalOracle index index)
  let mut parent ← tip base
  for offset in List.range 51 do
    let block ← makeBlock parent [] (70 + offset) (getBlockSubsidy ctx.params (parent.height + 1))
    s ← store s ctx block (2070 + offset)
    parent ← need (s.tree.get block.header.hash) "missing rival"
  let final ← activate s ctx
  return Json.mkObj [("height", toJson (← tip final).height),
    ("readmitted", toJson (final.mempool.accepted.any (fun e => e.id == BsvScript.Sighash.txid standardTx))),
    ("fundingLive", toJson ((getCoin final.view.coins fundingPoint).isSome)),
    ("queueEmpty", toJson final.disconnectPool.queued.isEmpty)]

/-- [D] B disconnects cleanly, then A lacks undo. Automatic activation re-admits
B's spend; explicit invalidation and freeze failure remove only.
[SRC] src/validation.cpp:4608–4616,4644–4668,5250–5255,4536–4539 at 6504a3af. -/
def partialDisconnectFailureCase (caller : String) : Except String Json := do
  let ctx := fixtureContext
  let base := initialState
  let (aState, a) ← mine base ctx [] 1
  let (s, _) ← mine aState ctx [standardTx] 2
  let s := { s with tree := s.tree.modify a.header.hash (fun i => { i with undo := none }) }
  let mut s := s
  let mut parent ← tip base
  for offset in List.range 3 do
    let block ← makeBlock parent [] (10 + offset)
    s ← store s ctx block (2010 + offset)
    parent ← need (s.tree.get block.header.hash) "missing rival"
  let (out, status) := if caller == "invalidate" then
      invalidateBlock s ctx .empty evalOracle a.header.hash 1000
    else if caller == "freeze" then setSoftFreeze s ctx .empty evalOracle a.header.hash 1 1000
    else activateBestChain s ctx .empty evalOracle 1000
  return Json.mkObj [("failed", toJson (status == .disconnectFailed)),
    ("height", toJson (← tip out).height),
    ("readmitted", toJson (out.mempool.accepted.any (fun e => e.id == BsvScript.Sighash.txid standardTx))),
    ("queueEmpty", toJson out.disconnectPool.queued.isEmpty)]

/-- [D] Equal-work precious selection invokes activation; a header without
linked transactions is excluded from insertion.
[SRC] src/validation.cpp:5156–5190 at 6504a3af. -/
def preciousCase (ctx : ChainContext) : Except String Json := do
  let base := initialState
  let (s, _) ← mine base ctx [standardTx] 1
  let b ← makeBlock (← tip base) [conflictTx] 2
  let headers ← checked (acceptHeader s ctx b.header 2000)
  let (headers, _) := preciousBlock headers ctx .empty evalOracle b.header.hash 1000
  let excluded := !headers.tree.candidates.contains b.header.hash
  let s ← store headers ctx b 2000
  let (s, status) := preciousBlock s ctx .empty evalOracle b.header.hash 1000
  return Json.mkObj [("headerExcluded", toJson excluded),
    ("complete", toJson (status == .complete)), ("selectedB", toJson (s.active.getLast? == some b.header.hash))]

def disconnectStatusCase (kind : String) : Except String Json := do
  let base := initialState
  let ctx := fixtureContext
  let block ← makeBlock (← tip base) [standardTx] 1
  let connected ← checkedBlock (connectBlock base.view ctx.params ctx.cfg block
    (headerContext base.tree base.active.getLast?) ctx.now .empty evalOracle)
  let undo := if kind == "undo-count" then BlockUndo.mk [] else connected.undo
  let view := if kind == "missing-output" then
      { connected.view with coins := connected.view.coins.erase (txPoint standardTx) }
    else if kind == "undo-collision" then
      { connected.view with coins := connected.view.coins.insert fundingPoint ⟨1,fixtureScript,1,false,false⟩ }
    else if kind == "output-metadata" then
      { connected.view with coins := connected.view.coins.insert (txPoint standardTx) ⟨99000,fixtureScript,999,true,true⟩ }
    else connected.view
  let (status,restored) := disconnectBlock view ctx.params 102 block undo
  return Json.mkObj [("status",toJson (reprStr status)),
    ("published",toJson (restored.bestBlock != view.bestBlock)),
    ("restoresInitial",toJson (decide (restored.coins = base.view.coins)))]

def connectFailureCase (kind : String) : Except String Json := do
  let base := initialState
  let ctx := fixtureContext
  let tx := if kind == "missing-input" then transaction ⟨List.replicate 32 9,0⟩ 99000 else standardTx
  let block ← makeBlock (← tip base) [tx] 1 (if kind == "reward" || kind == "reward-before-script" then 5000001001 else 5000000000)
  let view := if kind == "parent-tip" then { base.view with bestBlock := 0 } else base.view
  let oracle : ScriptOracle := if kind == "queued-script" || kind == "reward-before-script" then
    (fun _ _ _ _ _ _ => .invalid .evalFalse) else evalOracle
  let result := connectBlock view ctx.params ctx.cfg block
    (headerContext base.tree base.active.getLast?) ctx.now .empty oracle
  return toJson (match result with | .error r => r.reason | .ok _ => "accepted")

def settingCase (freeze : Bool) : Except String Json := do
  let ctx := fixtureContext
  let (s,a) ← mine initialState ctx [standardTx] 1
  let (s,status) := if freeze then setSoftFreeze s ctx .empty evalOracle a.header.hash 0 1000
    else setSoftRejection s ctx .empty evalOracle a.header.hash 0 1000
  unless status == .complete do throw s!"setting removal {repr status}"
  let removed := snapshot s watched names
  let cause := s.events.getLast?
  let (restored,status) := if freeze then setSoftFreeze s ctx .empty evalOracle a.header.hash (-1) 1000
    else setSoftRejection s ctx .empty evalOracle a.header.hash (-1) 1000
  unless status == .complete do throw s!"setting restoration {repr status}"
  return Json.mkObj [("removed",removed),("restored",snapshot restored watched names),
    ("causeRecorded",toJson (cause == some (.disconnected (if freeze then .freezeChange else .softRejection) a.header.hash)))]

/-- [D] Check queued coinbase, filtering, capacity and the emptied accepted pool. The caller supplies the unchanged fixture context so row work starts only after selection. -/
def poolCapCase (ctx : ChainContext) : Except String Json := do
  let base := initialState
  let (s,verdict) := admit base ctx standardTx
  unless verdict == .completed .accepted do throw "cap setup admission failed"
  let child := transaction (txPoint standardTx) 98000
  let (s,verdict) := admit s ctx child
  unless verdict == .completed .accepted do throw "cap child admission failed"
  let block ← makeBlock (← tip base) [standardTx] 1
  let cb ← need block.transactions.head? "missing cap coinbase"
  let cfg := { ctx.cfg with maxMempool := (BsvScript.Sighash.serTx cb).length }
  let (q,p) := addToDisconnectPool cfg ctx.disconnectAccounting {} s.mempool block
  return Json.mkObj [("onlyCoinbase",toJson (q.queued == [cb])),("coinbaseFiltered",toJson (q.filtered.contains (BsvScript.Sighash.txid cb))),
    ("withinCap",toJson (decide (q.usage ctx.disconnectAccounting ≤ cfg.maxMempool))),("poolEmpty",toJson p.accepted.isEmpty)]

def retainedNonfinalCase (genesis : Bool) : Except String Json := do
  let tx := { standardTx with
    lockTime := 102
    inputs := standardTx.inputs.map (fun i => { i with sequence := 0xfffffffe, scriptSig := [] })
    outputs := [⟨99000,[0x51]⟩] }
  let base := initialState
  let base := { base with view := { base.view with coins := coinMap [(fundingPoint,⟨100000,[0x51],101,false,false⟩)] } }
  let ctx := fixtureContext
  let ctx := { ctx with cfg := { ctx.cfg with requireStandard := false, chainRequireStandard := false, acceptNonStandardOutput := true } }
  let ctx := if genesis then { ctx with params := { ctx.params with genesisHeight := 0 } } else ctx
  let old := { admissionContext base ctx with tipHeight := 103 }
  let (p,result) := accept {} base.view.coins ctx.cfg old .empty evalOracle {} { tx, acceptTime := ctx.now }
  unless result == .completed .accepted do throw s!"retained finality setup: {repr result}"
  let p := removeForReorg p base.view.coins ctx.cfg (admissionContext base ctx)
  return toJson (p.accepted.length == 1)

/-- [D] Check valid-candidate retry and failed/failed-parent flags. The caller supplies the unchanged fixture context so row work starts only after selection. -/
def invalidRetryCase (ctx : ChainContext) : Except String Json := do
  let base := initialState
  let badTx := transaction ⟨List.replicate 32 9,0⟩ 99000
  let a ← makeBlock (← tip base) [badTx] 1
  let s ← store base ctx a 2000
  let ai ← need (s.tree.get a.header.hash) "missing invalid fixture index"
  let child ← makeBlock ai [] 2
  let s ← store s ctx child 2001
  let good ← makeBlock (← tip base) [standardTx] 3
  let s ← store s ctx good 2002
  let s ← activate s ctx
  let bad ← need (s.tree.get a.header.hash) "missing invalid fixture index"
  let child ← need (s.tree.get child.header.hash) "missing child fixture index"
  return Json.mkObj [("selectedGood",toJson (s.active.getLast? == some good.header.hash)),
    ("badFailed",toJson bad.status.failed),("childFailedParent",toJson child.status.failedParent),
    ("childNotFailedSelf",toJson (!child.status.failed)),("view",snapshot s watched names)]

def sequentialCase (reverse : Bool) : Except String Json := do
  let ctx := fixtureContext
  let base := initialState
  let child := transaction (txPoint standardTx) 98000
  let block ← makeBlock (← tip base) (if reverse then [child,standardTx] else [standardTx,child]) 1
  match connectBlock base.view ctx.params ctx.cfg block (headerContext base.tree base.active.getLast?)
      ctx.now .empty evalOracle with
  | .error r => return toJson r.reason
  | .ok out => return Json.mkObj [("parentSpent",toJson ((getCoin out.view.coins (txPoint standardTx)).isNone)),
      ("childLive",toJson ((getCoin out.view.coins (txPoint child)).isSome)),("fees",toJson out.run.fees)]

def eraClearCase (height : Nat) : Json :=
  let ctx := fixtureContext
  let e : MempoolEntry := { tx := standardTx, fee := 1000, time := ctx.now, height, size := (BsvScript.Sighash.serTx standardTx).length, innerUsage := 0 }
  let request : TxRequest := { tx := standardTx, acceptTime := ctx.now }
  let p : Mempool := reindex { accepted := [e], nonFinal := [⟨e,{}⟩], orphans := [⟨request,ctx.now+100,1⟩], feeDeltas := [(e.id,1)], rollingFee := ⟨(10 : Float).toBits,ctx.now,true⟩ }
  let p := finalizeEraCrossing ctx.params height ctx.now p
  Json.mkObj [("accepted",toJson p.accepted.length),("held",toJson p.nonFinal.length),
    ("orphans",toJson p.orphans.length),("deltas",toJson p.feeDeltas.length),
    ("feeReset",toJson (p.rollingFee.rateBits == 0))]

/-- [D] Check the configured genesis fixture's unchanged coins, empty undo and updated tip. The caller supplies the unchanged fixture context so row work starts only after selection. -/
def genesisCase (ctx : ChainContext) : Except String Json := do
  let base := initialState
  let block ← makeBlock (← tip base) [] 1 5000000001
  let header ← need (mineHeader .regtest { block.header with prevBlock := 0 } 10000) "genesis nonce budget"
  let block := { block with header }
  let params := { ctx.params with hashGenesisBlock := header.hash.toNat }
  let view := { base.view with bestBlock := 0 }
  let out ← checkedBlock (connectBlock view params ctx.cfg block none ctx.now .empty evalOracle)
  return Json.mkObj [("unchangedCoins",toJson (decide (out.view.coins = view.coins))),
    ("undoEmpty",toJson out.undo.transactions.isEmpty),("tipUpdated",toJson (out.view.bestBlock == header.hash))]

/-- [D] Check equal-work unrequested body omission without failure. The caller supplies the unchanged fixture context so row work starts only after selection. -/
def unrequestedCase (ctx : ChainContext) : Except String Json := do
  let base := initialState
  let ctx := { ctx with cfg := { ctx.cfg with minimumChainWork := 0 } }
  let (active,_) ← mine base ctx [standardTx] 1
  let block ← makeBlock (← tip base) [conflictTx] 2
  let (s,result) := acceptBlock active ctx block 2000 false
  let disposition ← checkedBlock result
  let index ← need (s.tree.get block.header.hash) "ignored header missing"
  return Json.mkObj [("ignored",toJson (disposition == .ignored)),("bodyAbsent",toJson index.body.isNone),
    ("equalWork",toJson (index.work == (← tip active).work)),("notFailed",toJson (!index.status.failed))]

/-- [D] Dispatch the declared case, passing fixtureContext at each deferred case call and returning its unchanged projection. -/
def runRow (j : Json) : Except String Json := do
  let kind ← j.getObjValAs? String "case"
  match kind with
  | "undo" => undoCase false
  | "overwrite" => undoCase true
  | "reorg" => reorgCase (← j.getObjValAs? Nat "depth")
  | "readmit" | "nonfinal" | "immature" => readmitCase kind
  | "invalidate-reconsider" => invalidateReconsiderCase fixtureContext
  | "rank" | "completion" | "sequence" => tieCase kind
  | "missing-body" => missingBodyCase
  | "body-return" => missingBodyCase true
  | "receipt-order" => receiptOrderCase fixtureContext
  | "mined-secondary" => minedSecondaryCase fixtureContext
  | "batching" => batchingCase fixtureContext
  | "partial-disconnect-auto" => partialDisconnectFailureCase "auto"
  | "partial-disconnect-invalidate" => partialDisconnectFailureCase "invalidate"
  | "partial-disconnect-freeze" => partialDisconnectFailureCase "freeze"
  | "precious" => preciousCase fixtureContext
  | "undo-count" | "missing-output" | "undo-collision" | "output-metadata" => disconnectStatusCase kind
  | "missing-input" | "reward" | "parent-tip" | "queued-script" | "reward-before-script" => connectFailureCase kind
  | "soft-rejection" => settingCase false
  | "soft-freeze" => settingCase true
  | "disconnect-pool-cap" => poolCapCase fixtureContext
  | "retained-nonfinal-before-genesis" => retainedNonfinalCase false
  | "retained-nonfinal-after-genesis" => retainedNonfinalCase true
  | "invalid-retry" => invalidRetryCase fixtureContext
  | "sequential-inputs" => sequentialCase false
  | "reversed-inputs" => sequentialCase true
  | "era-clear" => pure (eraClearCase (← j.getObjValAs? Nat "height"))
  | "genesis" => genesisCase fixtureContext
  | "unrequested-equal-work" => unrequestedCase fixtureContext
  | _ => throw s!"unknown case {kind}"

/-- [D] 2026-10-13: execute #64 mining and invalidation, retaining a path
for a block with coinbase and T. The assumed intake prefix predates T; all
retained active bodies are checked for its identifier after clean undo.
The context is a parameter (the caller passes `fixtureContext`) so the case
runs at its call in `--scenarios` and not during module initialization of every
mode ([M] 2026-10-14: about 3.6 s per invocation on the box).
[SRC] src/validation.cpp:5230-5330; src/consensus/merkle.cpp:284-310 at 6504a3af. -/
def orphanedProofCase (ctx : ChainContext) : Except String Unit := do
  let tx := standardTx
  let (mined, block) ← mine initialState ctx [tx] 65
  let path := computeBranch block.transactions 1
  let root := headerWordBytes 32 block.header.merkleRoot.toNat
  unless block.transactions.length ≥ 2 && verifyPath (BsvScript.Sighash.txid tx) path 1 root do
    throw "orphaned proof: mined path invalid"
  let (stale, status) := invalidateBlock mined ctx .empty evalOracle block.header.hash 1000
  unless status == .complete && !stale.active.contains block.header.hash do
    throw "orphaned proof: branch still active or undo incomplete"
  let stored ← need (stale.tree.get block.header.hash) "orphaned proof: missing stale header"
  let body ← need stored.body "orphaned proof: missing stale body"
  unless body.transactions.any (fun t => BsvScript.Sighash.txid t == BsvScript.Sighash.txid tx) &&
      verifyPath (BsvScript.Sighash.txid tx) path 1 root do throw "orphaned proof: stale evidence lost"
  for hash in stale.active do
    if let some body := (stale.tree.get hash).bind (·.body) then
      if body.transactions.any (fun t => BsvScript.Sighash.txid t == BsvScript.Sighash.txid tx) then
        throw "orphaned proof: active inclusion retained"

/-- [D] 2026-10-13: multi-level, odd-padding, singleton, positional-alias
and null-marker vectors for the executable branch operations.
[SRC] src/consensus/merkle.cpp:57-178,291-310 at 6504a3af. -/
def merklePathCases : Except String Unit := do
  for count in [1, 2, 3, 5, 6, 9, 17] do
    let leaves := (List.range count).map (fun i => BsvScript.Hash.sha256d [i])
    for index in List.range count do
      let leaf ← need leaves[index]? "missing vector leaf"
      let path := branchReduce count leaves index
      unless verifyPath leaf path index (computeMerkleRoot leaves).root do
        throw "merkle path: completeness vector failed"
  let leaf := BsvScript.Hash.sha256d [65]
  unless verifyPath leaf [] 99 leaf &&
      computeRootFromBranch leaf [BsvScript.Sighash.zero32] 1 == BsvScript.Hash.sha256d (leaf ++ leaf) do
    throw "merkle path: empty/null vector failed"

/-- [D] 2026-10-13: #75 executed TSC vectors. The standard's example proof
[LIT] decodes to its JSON fields (index 12, five hash nodes, a block-hash
target) and re-encodes byte-identical; its hash target verifies only with a
header, so `verifyTsc` is false without one. Every position of bodies of 1 to
9 leaves verifies through the node's marker branch and round-trips; the
marker shapes match the generator's cases (the last of an odd level, two
consecutive markers, the virtual parent as a hash); the one-leaf body yields
the empty vector. [SRC] src/merkletree.cpp:294-346 at 6504a3af. -/
def tscCases : Except String Unit := do
  let exampleHex := "000cef65a4611570303539143dabd6aa64dbd0f41ed89074406dc0e7cd251cf1efff69f17b44cfe9c2a23285168fe05084e1254daa5305311ed8cd95b19ea6b0ed7505008e66d81026ddb2dae0bd88082632790fc6921b299ca798088bef5325a607efb9004d104f378654a25e35dbd6a539505a1e3ddbba7f92420414387bb5b12fc1c10f00472581a20a043cee55edee1c65dd6677e09903f22992062d8fd4b8d55de7b060006fcc978b3f999a3dbb85a6ae55edc06dd9a30855a030b450206c3646dadbd8c000423ab0273c2572880cdc0030034c72ec300ec9dd7bbc7d3f948a9d41b3621e39"
  let bytes ← need (hexDecode exampleHex) "tsc example hex"
  let p ← need (BsvChain.Views.decode bytes) "tsc example decode"
  let word (s : String) : Except String Bytes := do
    let w ← need (hexDecode s) "tsc example word"
    pure w.reverse
  let txid ← word "ffeff11c25cde7c06d407490d81ef4d0db64aad6ab3d14393530701561a465ef"
  let target ← word "75edb0a69eb195cdd81e310553aa4d25e18450e08f168532a2c2e9cf447bf169"
  let nodes ← ["b9ef07a62553ef8b0898a79c291b92c60f7932260888bde0dab2dd2610d8668e",
    "0fc1c12fb1b57b38140442927fbadb3d1e5a5039a5d6db355ea25486374f104d",
    "60b0e75dd5b8d48f2d069229f20399e07766dd651ceeed55ee3c040aa2812547",
    "c0d8dbda46366c2050b430a05508a3d96dc0ed55aea685bb3d9a993f8b97cc6f",
    "391e62b3419d8a943f7dbc7bddc90e30ec724c033000dc0c8872253c27b03a42"].mapM fun s => do
      pure (BsvChain.Views.TscNode.hash (← word s))
  let expected : BsvChain.Views.TscProof := ⟨12, .txid txid, .hash target, nodes⟩
  unless p == expected && p.encode == bytes && p.flags == 0 && BsvChain.Views.verifyTsc p == false &&
      bytes.length == 232 do
    throw "tsc exampleHex: fields, bytes, flags or hash-target verdict differ"
  for count in [1, 2, 3, 5, 6, 8, 9] do
    let leaves := (List.range count).map (fun i => BsvScript.Hash.sha256d [i])
    for index in List.range count do
      let q := BsvChain.Views.bodyProof leaves index
      unless BsvChain.Views.verifyTsc q && BsvChain.Views.decode q.encode == some q do
        throw "tsc body proof: verification or round trip failed"
  let isHash (n : BsvChain.Views.TscNode) : Bool := match n with | .hash _ => true | .duplicate => false
  let shape (count index : Nat) : List Bool :=
    (BsvChain.Views.tscBranchReduce count ((List.range count).map (fun i => BsvScript.Hash.sha256d [i])) index).map isHash
  unless shape 1 0 == [] && shape 2 1 == [true] && shape 3 1 == [true, true] && shape 3 2 == [false, true] &&
      shape 5 4 == [false, false, true] && shape 6 5 == [true, false, true] && shape 7 6 == [false, true, true] &&
      shape 8 7 == [true, true, true] do
    throw "tsc marker shape vectors failed"

/-- [D] 2026-10-13: #75 the node's proof JSON into the TSC structure: verified
through `verifyTsc` against the supplied header (its hash bound to the block
hash), re-encoded in the binary form and decoded back (the round trip, measured
on the node's output), re-rendered as the node's JSON words, and compared with
the model of the node's branch generator over the body's identifiers.
[SRC] src/rpc/rawtransaction.cpp:2242-2339,2342-2525 at 6504a3af. -/
def verifyTscRow (j : Json) : Except String Json := do
  let word (s : String) : Except String Bytes := do
    let w ← need (hexDecode s) s!"invalid hex {s}"
    unless w.length == 32 do throw "invalid hash width"
    pure w.reverse
  let index ← j.getObjValAs? Nat "index"
  let txOrIdHex ← j.getObjValAs? String "txOrId"
  let txOrId : BsvChain.Views.TscTxOrId ←
    if txOrIdHex.length == 64 then pure (.txid (← word txOrIdHex))
    else pure (.tx (← need (hexDecode txOrIdHex) "invalid transaction hex"))
  let targetType ← field j "targetType" "hash"
  let targetHex ← j.getObjValAs? String "target"
  let target : BsvChain.Views.TscTarget ←
    if targetType == "hash" then pure (.hash (← word targetHex))
    else if targetType == "merkleroot" then pure (.merkleRoot (← word targetHex))
    else if targetType == "header" then
      pure (.header (← need ((hexDecode targetHex).bind BlockHeader.decode) "invalid header frame"))
    else throw s!"unknown targetType {targetType}"
  let nodes : List BsvChain.Views.TscNode ← (← j.getObjValAs? (List String) "nodes").mapM fun s =>
    if s == "*" then pure .duplicate else do pure (.hash (← word s))
  let p : BsvChain.Views.TscProof := ⟨index, txOrId, target, nodes⟩
  let supplied : Option BlockHeader ← match (← field j "header_hex" (none : Option String)) with
    | some h => pure (some (← need ((hexDecode h).bind BlockHeader.decode) "invalid supplied header"))
    | none => pure none
  let blockHashBound ← match (← field j "block_hash" (none : Option String)), supplied with
    | some bh, some h => pure (headerWordBytes 32 h.hash.toNat == (← word bh))
    | some _, none => pure false
    | none, _ => pure true
  let encoded := p.encode
  let decoded := BsvChain.Views.decode encoded
  let view (q : BsvChain.Views.TscProof) : Json := Json.mkObj [
    ("index", toJson q.index), ("txOrId", toJson (BsvChain.Views.txOrIdWord q.txOrId)),
    ("target", toJson (BsvChain.Views.targetWord q.target)),
    ("targetType", toJson (BsvChain.Views.targetTypeField q.target)),
    ("nodes", toJson (q.nodes.map BsvChain.Views.tscNodeWord))]
  let modelBranch : Option Bool ← match (← field j "block_txids" (none : Option (List String))) with
    | some ids => do
      let leaves ← ids.mapM word
      pure (some (decide (BsvChain.Views.tscBranchReduce leaves.length leaves index = nodes) &&
        leaves[index]? == some (BsvChain.Views.tscLeaf txOrId)))
    | none => pure none
  return Json.mkObj [
    ("verifyTsc", toJson (BsvChain.Views.verifyTsc p supplied)),
    ("blockHashBound", toJson blockHashBound),
    ("flags", toJson p.flags),
    ("binary_hex", toJson (hexEncode encoded)), ("binary_len", toJson encoded.length),
    ("roundTrip", toJson (decoded == some p)),
    ("view", (decoded.map view).getD Json.null),
    ("modelBranchEqual", toJson modelBranch),
    ("theorems", toJson ["BsvChain.Properties.tsc_decode_encode",
      "BsvChain.Properties.verifyTsc_eq_verifyPath", "BsvChain.Properties.tscBranchReduce_complete"])]

/-- [D] Concrete materialization of the intake's symbolic state projection.
Client histories and transaction-status synthesis are owed to
#66/#68/#75; [M] 2026-10-13 adds body-derived path checks; they are never counted as chain-run agreement.
[SRC] src/validation.cpp:4065–4133,4913–5330 at 6504a3af. -/
-- [D] 2026-10-13: stored body-derived path, independent of node RPC output.
structure ScenarioProof where
  leaf : Bytes
  path : List Bytes
  index : Nat
  root : Bytes
  header : BitVec 256

structure ScenarioState where
  state : ChainState
  context : ChainContext
  blocks : List (String × BitVec 256)
  transactions : List (String × Tx)
  proofs : List (String × ScenarioProof) := []

def scenarioStep (s : ScenarioState) (step : Json) : Except String ScenarioState := do
  let action ← step.getObjVal? "action"
  let kind ← action.getObjValAs? String "type"
  let now ← field action "now" s.context.now
  let s := { s with context := { s.context with now } }
  if kind == "submit" then
    let name ← action.getObjValAs? String "transaction"
    let tx ← need (s.transactions.lookup name) "unknown submitted symbol"
    let (next, verdict) := admit s.state s.context tx
    unless verdict == .completed .accepted do throw s!"scenario submit: {repr verdict}"
    return { s with state := next }
  if kind == "mine" then
    let name ← action.getObjValAs? String "block"
    let parentName ← action.getObjValAs? String "parent"
    let parentHash ← need (s.blocks.lookup parentName) "unknown parent symbol"
    let parent ← need (s.state.tree.get parentHash) "missing scenario parent"
    let txs ← (← action.getObjValAs? (List String) "transactions").mapM
      (fun name => need (s.transactions.lookup name) "unknown mined symbol")
    let block ← makeBlock parent txs (s.blocks.length + 1)
    let next ← activate (← store s.state s.context block (2000 + s.blocks.length)) s.context
    return { s with state := next, blocks := s.blocks ++ [(name,block.header.hash)] }
  if kind == "invalidateBlock" || kind == "reconsiderBlock" then
    let name ← action.getObjValAs? String "block"
    let hash ← need (s.blocks.lookup name) "unknown operator target"
    let (next,status) := if kind == "invalidateBlock" then
      invalidateBlock s.state s.context .empty evalOracle hash 1000
      else reconsiderBlock s.state s.context .empty evalOracle hash 1000
    unless status == .complete do throw s!"scenario operator: {repr status}"
    return { s with state := next }
  if kind == "advanceTime" then
    let trigger ← action.getObjVal? "trigger"
    -- The isolated RPC batch rejects both probes, then sweeps: pinned
    -- src/rawtxvalidator.cpp:54-92; src/txn_validator.cpp:303-314.
    unless (← trigger.getObjValAs? String "type") == "rpc" &&
        (← trigger.getObjValAs? String "rpc") == "sendrawtransactions" &&
        (← trigger.getObjValAs? (List String) "transactions") == ["sweep0", "sweep1"] do
      throw "unmapped maintenance event"
    let pool := advanceTime s.state.mempool s.context.cfg (admissionContext s.state s.context) .limit
    return { s with state := { s.state with mempool := pool } }
  if kind == "checkPath" then
    let name ← action.getObjValAs? String "transaction"
    let tx ← need (s.transactions.lookup name) "unknown path transaction"
    let blockName ← action.getObjValAs? String "block"
    let hash ← need (s.blocks.lookup blockName) "unknown path header"
    let i ← need (s.state.tree.get hash) "missing path header"
    let body ← need i.body "missing path body"
    let reuse ← field action "reuse" false
    let proof ← if reuse then need (s.proofs.lookup name) "missing stored path" else do
      let (_, index) ← need (body.transactions.zipIdx.find? (fun (t,_) =>
        BsvScript.Sighash.txid t == BsvScript.Sighash.txid tx)) "leaf not in body"
      pure {
        leaf := BsvScript.Sighash.txid tx
        path := computeBranch body.transactions index
        index := index
        root := headerWordBytes 32 i.header.merkleRoot.toNat
        header := hash }
    let active ← field action "active" true
    unless verifyPath proof.leaf proof.path proof.index proof.root && proof.header == hash &&
        s.state.active.contains hash == active do throw "path/header check failed"
    if !active then
      for activeHash in s.state.active do
        if let some body := (s.state.tree.get activeHash).bind (·.body) then
          if body.transactions.any (fun t => BsvScript.Sighash.txid t == proof.leaf) then
            throw "stale path still has active inclusion"
    return { s with proofs := (name, proof) :: s.proofs }
  unless ["observeClient", "serveBeef", "walletRoundTrip", "checkPath"].contains kind do
    throw s!"unmapped scenario action {kind}"
  return s

def scenarioProjection (s : ScenarioState) : Except String Json := do
  let tip ← tip s.state
  let tipName ← need ((s.blocks.find? (fun (_,h) => h == tip.id)).map Prod.fst) "unnamed tip"
  let pool := s.transactions.filter (fun (_,tx) => s.state.mempool.accepted.any (fun e => e.id == BsvScript.Sighash.txid tx)) |>.map Prod.fst
  let held := s.transactions.filter (fun (_,tx) => s.state.mempool.nonFinal.any (fun e => e.entry.id == BsvScript.Sighash.txid tx)) |>.map Prod.fst
  let points := [("F:fund",fundingPoint)] ++ s.transactions.map (fun (name,tx) => (name ++ ":credit",txPoint tx))
  let utxos := points.map fun (name,p) => (name,toJson (if (getCoin s.state.view.coins p).isSome then "unspent" else if name == "F:fund" then "spent" else "absent"))
  let tips := s.blocks.filterMap fun (name,hash) => do
    let i ← s.state.tree.get hash
    if i.id == tip.id then some (Json.mkObj [("block",toJson name),("status",toJson "active")])
    else if s.state.tree.nodes.any (fun child => child.parent == some i.id) then none else
      some (Json.mkObj [("block",toJson name),("status",toJson (if i.status.failed || i.status.failedParent then "invalid" else "valid-fork"))])
  let tips := tips.mergeSort (fun a b =>
    ((a.getObjValAs? String "block").toOption.getD "") ≤ ((b.getObjValAs? String "block").toOption.getD ""))
  return Json.mkObj [("mempool",toJson pool),("non_final_pool",toJson held),
    ("tip",Json.mkObj [("block",toJson tipName),("height",toJson tip.height)]),
    ("utxos",Json.mkObj utxos),("chain_tips",toJson tips)]

def expectedScenarioProjection (step : Json) : Except String Json := do
  let expected ← step.getObjVal? "expected_observations"
  let tips ← expected.getObjValAs? (List Json) "chain_tips"
  let tips := tips.mergeSort (fun a b =>
    ((a.getObjValAs? String "block").toOption.getD "") ≤ ((b.getObjValAs? String "block").toOption.getD ""))
  return Json.mkObj [("mempool",← expected.getObjVal? "mempool"),
    ("non_final_pool",← expected.getObjVal? "non_final_pool"),("tip",← expected.getObjVal? "tip"),
    ("utxos",← expected.getObjVal? "utxos"),("chain_tips",toJson tips)]

def runScenarioSteps (s : ScenarioState) : List Json → Except String (List (String × ScenarioState × Json))
  | [] => .ok []
  | step :: rest => do
    let id ← step.getObjValAs? String "id"
    let next ← scenarioStep s step
    let actual ← scenarioProjection next
    let expected ← expectedScenarioProjection step
    unless actual == expected do throw s!"scenario {id}: expected {expected.compress}; observed {actual.compress}"
    return (id,next,actual) :: (← runScenarioSteps next rest)

/-- [D] 2026-10-14 (#72): the done-bar's `L`, a spend of a mature height-2
coinbase coin whose 10-satoshi fee is below `blockMinTxFee` (500 per kB) for its
size, so admission keeps it secondary. The replay mines the body the node was
observed to assemble (the step's `transactions`), never a predicted one.
[SRC] src/txmempool.cpp:411–414 and src/mining/journaling_block_assembler.cpp:80–97
at 6504a3af. -/
def lowFeePoint : OutPoint := ⟨List.replicate 32 9, 0⟩
def lowFeeTx : Tx := transaction lowFeePoint 99990

def runScenario (j : Json) : Except String (List Json) := do
  let id ← j.getObjValAs? String "id"
  let lowFee := id.endsWith "assembly-excludes-low-fee"
  let base := initialState
  let coins := coinMap [(fundingPoint, ⟨100000, fixtureScript, 101, false, false⟩),
    (lowFeePoint, ⟨100000, fixtureScript, 2, true, false⟩)]
  let state := if lowFee then { base with view := { base.view with coins := coins } } else base
  let proofScenario := id.endsWith "bumpless-beef-stored-proof" || id.endsWith "orphaned-block-proof"
  let txs := if proofScenario then [("T",standardTx),("U",transaction (txPoint standardTx) 98000)]
    else if lowFee then [("L",lowFeeTx),("T",standardTx)] else names
  let initial : ScenarioState := {
    state := state
    context := fixtureContext
    blocks := [("base",(← tip state).id)]
    transactions := txs }
  let main ← runScenarioSteps initial (← j.getObjValAs? (List Json) "steps")
  let mut results := main
  for variant in (← field j "variants" ([] : List Json)) do
    let checkpoint ← variant.getObjValAs? String "fork_after"
    let (_,start,_) ← need (main.find? (fun (id,_,_) => id == checkpoint)) "missing scenario checkpoint"
    results := results ++ (← runScenarioSteps start (← variant.getObjValAs? (List Json) "steps"))
  return results.map fun (step,_,actual) => Json.mkObj [
    ("scenario",toJson id),("step",toJson step),("label",toJson "[M]"),
    ("scope",toJson "symbolic chain/pool projection; standard P2SH fixture; assumed prefix; client/status projections owed; body-derived paths checked"),
    ("agree",toJson true),("observed",actual)]

/-- [M] 2026-10-13: replay read-only public mainnet identifiers, raw selected
transactions, TSC-projected paths and generated literal branches. Header hex
is serialized from fetched block fields [D]; its hash binds the TSC block-hash
target. This projection is fixture intake; #75 still owns the TSC codec.
[SRC] src/consensus/merkle.cpp:57-178,291-310; src/primitives/block.h:38-45
at 6504a3af. Exact API URLs and read stamps are in each vector and PROVENANCE. -/
def mainnetPathRow (j : Json) : Except String (String × Nat) := do
  unless (← j.getObjValAs? String "label") == "[M]" &&
      (← j.getObjValAs? String "network") == "main" do throw "invalid public provenance"
  let hashWord (key : String) := do
    let word ← need (hexDecode (← j.getObjValAs? String key)) "invalid hash hex"
    unless word.length == 32 do throw "invalid hash width"
    pure word.reverse
  let txid ← j.getObjValAs? String "txid"
  let leaf ← hashWord "txid"
  let raw ← need (hexDecode (← j.getObjValAs? String "tx_hex")) "invalid transaction hex"
  unless BsvScript.Hash.sha256d raw == leaf do throw "transaction identifier mismatch"
  let headerRaw ← need (hexDecode (← j.getObjValAs? String "header_hex")) "invalid header hex"
  let header ← need (BlockHeader.decode headerRaw) "invalid header frame"
  let blockHash ← hashWord "block_hash"
  unless headerWordBytes 32 header.hash.toNat == blockHash &&
      (← hashWord "tsc_target") == blockHash do throw "header/target mismatch"
  let root := headerWordBytes 32 header.merkleRoot.toNat
  unless root == (← hashWord "merkle_root") do throw "header merkle root mismatch"
  let leaves ← (← j.getObjValAs? (List String) "block_txids").mapM fun id => do
    let word ← need (hexDecode id) "invalid body identifier"
    unless word.length == 32 do throw "invalid body identifier width"
    pure word.reverse
  let index ← j.getObjValAs? Nat "index"
  unless leaves.length == (← j.getObjValAs? Nat "tx_count") && leaves.length > 1 &&
      leaves[index]? == some leaf && (← j.getObjValAs? Nat "confirmations_at_read") > 100000 do
    throw "body position, count or settlement mismatch"
  let path ← (← j.getObjValAs? (List String) "branch_hashes").mapM fun node => do
    if node == "*" then pure BsvScript.Sighash.zero32 else do
      let word ← need (hexDecode node) "invalid branch hash"
      unless word.length == 32 do throw "invalid branch hash width"
      pure word.reverse
  let generated := branchReduce leaves.length leaves index
  unless !(computeMerkleRoot leaves).mutated && (computeMerkleRoot leaves).root == root &&
      verifyPath leaf generated index root do throw "generated body branch failed"
  unless verifyPath leaf path index root do throw "public verifyPath failed"
  return (txid, index)

def runMainnetPaths (path : String := "corpus/chain/merkle/2026-10-13-mainnet-paths.jsonl") : IO UInt32 := do
  let rows := (← IO.FS.readFile path).splitOn "\n" |>.filter (fun s => !s.trimAscii.toString.isEmpty)
  let mut count := 0
  let mut failures := 0
  for row in rows do
    match Json.parse row >>= mainnetPathRow with
    | .error e => failures := failures + 1; IO.eprintln s!"mainnet path: ERROR {e}"
    | .ok (txid, index) =>
      count := count + 1
      IO.println s!"mainnet path: {txid} index [M] {index}; verifyPath true; generated verifyPath true [X]"
  IO.println s!"mainnet paths: {if failures == 0 && count > 0 then "GREEN" else "RED"} [X] ([M] {count} vectors; failures {failures}; header roots; public reads only)"
  return if failures == 0 && count > 0 then 0 else 1

/-- [D] 2026-10-14 (#89): one row of corpus/merkle/subtree-vectors.jsonl. The row's
expectations come from tools/subtree_vectors.py's transcriptions of go-subtree v1.5.1 and of
src/consensus/merkle.cpp:247-282 at 6504a3af; here the Lean definitions of
`BsvChain.Teranode` (the partition, `checkMerkleRoot` with every root `recomputed`, the in-memory
reading) and #63's `computeMerkleRoot` must reproduce them. A row with a `header_root` (mainnet,
read-only) must equal it on both sides. -/
def subtreeRow (j : Json) : Except String (String × Bool × Bool) := do
  let id ← j.getObjValAs? String "id"
  let word (h : String) : Except String Bytes := do
    let w ← need (hexDecode h) s!"{id}: invalid hex"
    unless w.length == 32 do throw s!"{id}: a word is not 32 bytes"
    pure w
  let txids ← (← j.getObjValAs? (List String) "txids").mapM word
  let size ← j.getObjValAs? Nat "size"
  let coinbase ← need txids.head? s!"{id}: no transaction"
  let subtrees : List (List Bytes) ← match j.getObjVal? "subtrees" with
    | .ok v => do
      let rows ← fromJson? (α := List (List String)) v
      rows.mapM (·.mapM word)
    | .error _ =>
      pure (BsvChain.Teranode.partition size (BsvChain.Teranode.coinbasePlaceholder :: txids.tail))
  unless subtrees.map List.length == (← j.getObjValAs? (List Nat) "subtree_lengths") do
    throw s!"{id}: the partition's lengths differ"
  unless BsvChain.Teranode.flatLeaves coinbase subtrees == txids do
    throw s!"{id}: the flat list is not the subtrees' leaves"
  let teranode := BsvChain.Teranode.checkMerkleRoot BsvChain.Teranode.recomputed coinbase subtrees
  let reference := computeMerkleRoot txids
  let expected : Option Bytes ← match j.getObjVal? "teranode_root" with
    | .ok Json.null => pure none
    | .ok v => some <$> (word (← fromJson? (α := String) v))
    | .error _ => throw s!"{id}: no teranode_root"
  unless teranode == expected do throw s!"{id}: Teranode's root differs from the transcription"
  unless reference.root == (← word (← j.getObjValAs? String "reference_root")) &&
      reference.mutated == (← j.getObjValAs? Bool "reference_mutated") do
    throw s!"{id}: the reference's root or flag differs from the transcription"
  match j.getObjVal? "header_root" with
  | .ok v =>
    let hr ← word (← fromJson? (α := String) v)
    unless teranode == some hr && reference.root == hr do
      throw s!"{id}: a root differs from the mainnet header's"
  | .error _ => pure ()
  let agree := teranode == some reference.root
  unless agree == (← j.getObjValAs? Bool "agree") do throw s!"{id}: the agreement differs"
  return (id, agree, teranode.isNone)

/-- [D] 2026-10-14 (#89): every row of the subtree vectors through the Lean definitions. -/
def runSubtreeVectors (path : String := "corpus/merkle/subtree-vectors.jsonl") : IO UInt32 := do
  let rows := (← IO.FS.readFile path).splitOn "\n" |>.filter (fun s => !s.trimAscii.toString.isEmpty)
  let mut count := 0
  let mut agree := 0
  let mut refused := 0
  let mut failures := 0
  for row in rows do
    match Json.parse row >>= subtreeRow with
    | .error e => failures := failures + 1; IO.eprintln s!"chaincheck subtree: ERROR {e}"
    | .ok (_, a, r) =>
      count := count + 1
      if a then agree := agree + 1
      if r then refused := refused + 1
  let ok := failures == 0 && count > 0
  IO.println s!"chaincheck subtree vectors: {if ok then "GREEN" else "RED"} [X] ([M] {count} rows; Teranode root = flat root on {agree}; refused {refused}; roots differ {count - agree - refused}; failures {failures})"
  return if ok then 0 else 1

/-- IO references keep the pure workload between the clock reads. Reading the
input after the start prevents closed-term lifting from precomputing the workload;
writing its result before the stop forces evaluation before the clock is read.
The result is returned unchanged, and the timing goes only to the IO shell. -/
@[noinline] def measure (input : α) (work : α → β) : IO (β × Nat) := do
  let source ← IO.mkRef input
  let target ← IO.mkRef (none : Option β)
  let start ← IO.monoNanosNow
  let input ← source.get
  target.set (some (work input))
  let stop ← IO.monoNanosNow
  match ← target.get with
  | some result => return (result, stop-start)
  | none => throw (IO.userError "missing measured result")

/-- Isolate connection and undo for the clean-undo corpus fixture. Setup includes
its assumed header prefix; connection includes the unchanged ancestry projection.
This diagnostic reports actual calls to the same connection/undo APIs as `undoCase`. -/
def profileUndo : IO UInt32 := do
  let (setup, nanos) ← measure (101 : Nat) fun height => do
    let s := initialState height
    let block ← makeBlock (← tip s) [standardTx] 1
    return (s, block)
  IO.eprintln s!"chaincheck profile: clean-undo setup [M] {nanos} ns"
  let (s, block) ← IO.ofExcept setup
  let (result, nanos) ← measure (s, block) fun (s, block) =>
    checkedBlock (connectBlock s.view .regtest fixtureConfig block
      (headerContext s.tree s.active.getLast?) (fixtureContext.now) .empty evalOracle)
  IO.eprintln s!"chaincheck profile: clean-undo block connection [M] {nanos} ns"
  let connected ← IO.ofExcept result
  let ((status, back), nanos) ← measure (connected, block) fun (connected, block) =>
    disconnectBlock connected.view .regtest 102 block connected.undo
  IO.eprintln s!"chaincheck profile: clean-undo block undo [M] {nanos} ns"
  return if status == .ok && decide (back.coins = s.view.coins) then 0 else 1

/-- Optional isolated hash workloads. Each nonce/tag varies and each digest contributes
 to the printed checksum. These walls are microbenchmarks, separate from the
 row/scenario phase walls, and include serialization and digest decoding. -/
def profileHashes : IO UInt32 := do
  let header : BlockHeader := ⟨1, 0, 0, 1700000000, 0x207fffff, 0⟩
  let (checksum, nanos) ← measure header fun header => Id.run do
    let mut checksum := 0
    for nonce in List.range 10000 do
      checksum := checksum + ({ header with nonce := BitVec.ofNat 32 nonce }.hash.toNat % 256)
    return checksum
  IO.eprintln s!"chaincheck profile: header hashing [M] 10000 frames; {nanos} ns; checksum {checksum}"
  let (merkleChecksum, nanos) ← measure standardTx fun tx => Id.run do
    let mut checksum := 0
    for tag in List.range 10000 do
      checksum := checksum + BsvScript.Numbers.leNat (blockMerkleRoot [coinbase 102 tag, tx]).root % 256
    return checksum
  IO.eprintln s!"chaincheck profile: merkle hashing [M] 10000 two-transaction roots; {nanos} ns; checksum {merkleChecksum}"
  return ← profileUndo

/-- [D] 2026-10-13: serialize the derived view, never a node RPC word or rule. -/
def statusJson : BsvChain.Status → Json
  | .minedActive height => Json.mkObj [("value",toJson "minedActive"),("height",toJson height)]
  | .rejected code reason =>
    let (space, number) := match code with | .node n => ("node",(n : Int)) | .rpc n => ("rpc",n)
    Json.mkObj [("value",toJson "rejected"),("namespace",toJson space),("code",toJson number),("reason",toJson reason)]
  | s => Json.mkObj [("value",toJson (match s with
      | .unknown => "unknown" | .orphan => "orphan" | .inMempool => "inMempool"
      | .heldNonFinal => "heldNonFinal" | .onStaleBranch => "onStaleBranch"
      | .conflictedByMinedSpend => "conflictedByMinedSpend" | _ => "unreachable"))]

/-- [D] 2026-10-13: post-Genesis view fixture with eligible OP_TRUE outputs.
The funding script in the assumed prefix was created before Genesis. All
new bodies pass the actual block/connection path. Views, never rules. -/
def statusViewMine (s : ChainState) (ctx : ChainContext) (txs : List Tx) (tag : Nat) :
    Except String (ChainState × Block) := do
  let parent ← tip s
  let cb := { coinbase (parent.height + 1) tag with outputs := [⟨5000000000,[0x51]⟩] }
  let txs := cb :: txs
  let root := (blockMerkleRoot txs).root
  let header : BlockHeader := ⟨1,parent.id,BitVec.ofNat 256 (leNat root),BitVec.ofNat 32 (1700000000+tag),parent.header.bits,0⟩
  let header ← need (mineHeader ctx.params header 10000) "view fixture nonce-search budget"
  let block : Block := ⟨header,txs⟩
  let next ← store s ctx block (1000+tag)
  return (← activate next ctx,block)

/-- [D] 2026-10-13: retain every independent predicate input in replay receipts.
Words are derived separately and checked; these inputs are local models. -/
def producerContextJson (c : BsvChain.Views.ProducerContext) : Json :=
  Json.mkObj [("receipt_delivered",toJson c.receiptDelivered),("arcade_prior",toJson (reprStr c.arcadePrior)),
    ("later_arcade_event",toJson c.laterArcadeEvent),("signed_complete",toJson c.signedComplete),
    ("structurally_valid",toJson c.structurallyValid),("no_send",toJson c.noSend),
    ("delayed",toJson c.delayed),("send_with",toJson c.sendWith),("believed_sent",toJson c.believedSent),
    ("rejection_delivered",toJson c.rejectionDelivered),("wallet_before_failure",toJson (reprStr c.walletBeforeFailure)),
    ("wallet_updated_at",toJson c.walletUpdatedAt),("wallet_now",toJson c.walletNow),
    ("wallet_abandoned_msecs",toJson c.walletAbandonedMsecs),("wallet_failure_applied",toJson c.walletFailureApplied),
    ("failed_filter_selected",toJson c.failedFilterSelected),("recovery_label",toJson c.recoveryLabel),
    ("validator_skip_policy_checks",toJson c.validatorSkipPolicyChecks),
    ("validator_response_valid",toJson c.validatorResponseValid),("validator_reason",toJson c.validatorReason),
    ("validator_error_cause",toJson c.validatorErrorCause),("validator_parent_known",toJson c.validatorParentKnown),
    ("propagation_cause",toJson c.propagationCause)]

/-- [D] 2026-10-13: execute actual admission and chain transitions for all
status-view witnesses. The common prefix is assumed just as in #64's intake
projection. Each independent witness uses the evaluator and a fresh state.
Client contexts are local derivations, never measurements or rules. -/
def statusViewCase (row : String) : Except String Json := do
  let ctx := { fixtureContext with params := { ChainParams.regtest with genesisHeight := 100 } }
  let base := initialState 99
  let primary := { standardTx with outputs := [⟨99000,[0x51]⟩] }
  let tx := if row == "heldNonFinal" then
      { primary with version := 2, lockTime := 102, inputs := primary.inputs.map (fun i => { i with sequence := 0 }) }
    else if row == "orphan" then { transaction (txPoint primary) 98000 with outputs := [⟨98000,[0x51]⟩] }
    else if row == "rejected" then { primary with inputs := [] }
    else primary
  let mut chain := base
  let mut journal : TxJournal := {}
  if ["inMempool", "heldNonFinal", "orphan", "rejected", "minedActive", "onStaleBranch", "conflictedByMinedSpend"].contains row then
    let (pool, outcome) := accept chain.mempool chain.view.coins ctx.cfg (admissionContext chain ctx)
      .empty evalOracle {} { tx, acceptTime := ctx.now, source := if row == "orphan" then .p2p else .rpc, orphanHandler := row == "orphan" }
    chain := { chain with mempool := pool }
    journal := recordTxOutcome journal tx outcome
  if row == "minedActive" || row == "onStaleBranch" then
    let (next, block) ← statusViewMine chain ctx [tx] 1
    chain := next
    if row == "onStaleBranch" then
      let (next, progress) := invalidateBlock chain ctx .empty evalOracle block.header.hash 1000
      unless progress == .complete do throw "view invalidation incomplete"
      let later := { ctx with now := ctx.now + ctx.cfg.mempoolExpiry + 1 }
      chain := { next with mempool := advanceTime next.mempool later.cfg (admissionContext next later) .limit }
  if row == "conflictedByMinedSpend" then
    chain := (← statusViewMine chain ctx [{ conflictTx with outputs := [⟨98000,[0x51]⟩] }] 1).1
  let derived := BsvChain.status ⟨chain,journal⟩ (BsvScript.Sighash.txid tx)
  -- [X] 2026-10-13: narrow domains reject unsupported reasons/namespaces.
  unless (BsvChain.Views.arcadeRejected (.rejected (.rpc (-26)) "bad-txns-vin-empty")).isNone &&
      (BsvChain.Views.arcadeRejected (.rejected (.node 16) "other reason")).isNone &&
      (BsvChain.Views.arcadeRejected .onStaleBranch).isNone &&
      (BsvChain.Views.arcadeStaleMining (.minedActive 1)).isNone do
    throw "partial Arcade domain checks failed"
  let mut contexts : List (String × Json) := []
  let mut wordVectors : List (List (String × String)) := []
  for (name, alternate) in [("initial",false),("alternate",true)] do
    let input := BsvChain.Views.witnessContext derived alternate
    let words ← need (BsvChain.Views.contextWords derived input) "incompatible producer context"
    -- [X] 2026-10-13: incompatible or unsupported source-step inputs must fail.
    unless (BsvChain.Views.contextWords derived { input with arcadePrior := .MINED }).isNone &&
        (BsvChain.Views.contextWords derived { input with failedFilterSelected := false }).isNone &&
        (BsvChain.Views.contextWords derived { input with validatorSkipPolicyChecks := false, validatorResponseValid := false, validatorReason := "" }).isNone &&
        (BsvChain.Views.contextWords derived { input with validatorSkipPolicyChecks := false, validatorErrorCause := "" }).isNone &&
        (BsvChain.Views.contextWords derived { input with propagationCause := "unsupported" }).isNone do
      throw "producer predicate negative checks failed"
    if row == "rejected" then
      unless (BsvChain.Views.contextWords derived { input with signedComplete := true, noSend := true }).isNone &&
          (BsvChain.Views.contextWords derived { input with validatorSkipPolicyChecks := false, validatorResponseValid := true, validatorErrorCause := "" }).isNone do
        throw "structurally invalid noSend context accepted"
    wordVectors := wordVectors ++ [words]
    contexts := contexts ++ [(name,Json.mkObj [("inputs",producerContextJson input),
      ("words",Json.mkObj (words.map (fun (k,v) => (k,toJson v)))),("predicates_checked",toJson true)])]
  let mut cells : List (String × Json) := []
  let mut teranodeCell := Json.null
  for (name, vocabulary) in BsvChain.Views.columns do
    -- [X] 2026-10-15 (#74): the Teranode node column's witnesses are the instance's record, not this
    -- SV replay's producer contexts, so its cell is checked against teranodeState and emitted beside cells.
    if vocabulary == .teranodeNode then
      let state := BsvChain.Views.teranodeState derived
      if let some (_,word,source,witness) := BsvChain.Views.teranodeCells.find? (fun (r,_,_,_) => r == row) then
        let some x := state | throw "Teranode function cell undefined at its row"
        unless BsvChain.Views.teranodeWord x == word do throw "Teranode cell disagrees with teranodeState"
        unless x == .refused || BsvChain.Views.teranodeRead x == some derived do
          throw "Teranode reading does not return the derived status"
        teranodeCell := Json.mkObj [("column",toJson name),("kind",toJson "function"),("output",toJson (reprStr x)),
          ("word",toJson word),("source",toJson source),("witness",toJson witness),
          ("record",toJson BsvChain.Views.teranodeWitnessRecord),("label",toJson "[D]")]
      else if let some (_,missing) := BsvChain.Views.teranodeNoFunction.find? (fun (r,_) => r == row) then
        unless state.isNone do throw "Teranode no-function cell has a state"
        teranodeCell := Json.mkObj [("column",toJson name),("kind",toJson "no function"),("reason",toJson missing.reason),
          ("witness",toJson missing.witness),("record",toJson BsvChain.Views.teranodeWitnessRecord),("label",toJson "[D]")]
      else throw "Teranode node cell missing"
    else if vocabulary == .node then
      let output := match BsvChain.Views.nodeView derived with
        | none => Json.null
        | some (word,reason) => Json.mkObj [("word",toJson (reprStr word)),("reason",toJson reason)]
      cells := cells ++ [(name,Json.mkObj [("kind",toJson "function"),("output",output),("label",toJson "[D]")])]
    else if let some (_,_,word,source) := BsvChain.Views.partialCells.find? (fun (r,v,_,_) => r == row && v == vocabulary) then
      let actual := if vocabulary == .arcade then
          if BsvChain.Views.arcadeMining derived == some .MINED ||
              BsvChain.Views.arcadeStaleMining derived == some .MINED then some "MINED"
          else if BsvChain.Views.arcadeRejected derived == some .REJECTED then some "REJECTED" else none
        else if vocabulary == .provenTxReq then
          if BsvChain.Views.requestConflict derived == some .doubleSpend then some "doubleSpend"
          else if BsvChain.Views.requestInvalid derived == some .invalid then some "invalid" else none
        else none
      unless actual == some word do throw "partial cell disagrees with the pinned typed projection"
      if vocabulary == .provenTxReq && row == "conflictedByMinedSpend" then
        unless BsvChain.minedConflict ⟨chain,journal⟩ (BsvScript.Sighash.txid tx) do
          throw "partial doubleSpend lacks exact active spender"
      if vocabulary == .arcade && row == "onStaleBranch" then
        unless chain.tree.nodes.any (fun index => !chain.active.contains index.id &&
            BsvChain.bodyContains index (BsvScript.Sighash.txid tx)) do
          throw "partial stale MINED lacks off-active body"
      if (vocabulary == .provenTxReq || vocabulary == .arcade) && row == "rejected" then
        unless tx.inputs.isEmpty do throw "partial invalid lacks empty inputs"
      cells := cells ++ [(name,Json.mkObj [("kind",toJson "function"),("partial",toJson true),
        ("output",toJson word),("source",toJson source),
        ("stored_lifecycle_obstruction",toJson (BsvChain.Views.extraState vocabulary)),("label",toJson "[D]")])]
    else
      let missing := BsvChain.Views.obstruction vocabulary row
      unless (wordVectors[0]!).lookup name != (wordVectors[1]!).lookup name do
        throw "obstruction words do not differ"
      cells := cells ++ [(name,Json.mkObj [("kind",toJson "no function"),("reason",toJson missing.reason),
        ("witness",toJson missing.witness),("label",toJson "[D]")])]
  return Json.mkObj [("row",toJson row),("status",statusJson derived),("cells",Json.mkObj cells),
    ("teranode_node",teranodeCell),
    ("producer_contexts",Json.mkObj contexts),("incompatible_contexts_rejected",toJson true),
    ("synchronized_mining",toJson (reprStr (BsvChain.Views.synchronizedMining derived))),
    ("client_depth_1",toJson (reprStr (BsvChain.Views.depthView derived 102 1))),
    ("client_depth_2",toJson (reprStr (BsvChain.Views.depthView derived 102 2))),
    ("seen",toJson (reprStr (BsvChain.Views.seenView derived false)))]

/-- [D] 2026-10-13: emitted table cells come from the Lean view definitions.
Each observed derived status is checked against its independent row name.
This checks views, never validation rules. -/
def statusViewsReport : IO UInt32 := do
  let mut failures := 0
  -- [M] 2026-10-14: the rows are pure, spawned as tasks and read in order.
  let tasks := BsvChain.Views.rows.map fun row => (row, Task.spawn fun _ => statusViewCase row)
  for (row, task) in tasks do
    match task.get with
    | .error message => IO.eprintln s!"status views: ERROR {row}: {message}"; failures := failures + 1
    | .ok result =>
      IO.println result.compress
      unless (result.getObjVal? "status" >>= (fun j => j.getObjValAs? String "value")) == .ok row do
        failures := failures + 1
  let functionCells := BsvChain.Views.rows.length + BsvChain.Views.partialCells.length + BsvChain.Views.teranodeCells.length
  let noFunctionCells := BsvChain.Views.rows.length * BsvChain.Views.columns.length - functionCells
  IO.eprintln s!"status views: {if failures == 0 then "GREEN" else "RED"} [X] ([M] {BsvChain.Views.rows.length} rows, {BsvChain.Views.columns.length} columns, {functionCells} function cells including {BsvChain.Views.partialCells.length} partial, {noFunctionCells} no-function cells; predicates checked; failures {failures}; producer outputs [D])"
  return if failures == 0 then 0 else 1

/-! ## Era boundaries (#69)

[D] 2026-10-13: each row names a network and a boundary; the judge evaluates
the executable era definitions at the row's height. Mainnet rows are the spec
projection only; regtest rows also carry the node column of a fresh instance.
[SRC] src/validation.cpp:3070–3117,5962–5972,6039–6104, src/pow.cpp:95–117,
src/verify_script_flags.cpp:32–81 at 6504a3aff65ba97c0f6c80962b033e35ecbfed4b. -/

def eraNetwork (j : Json) : Except String ChainParams := do
  match ← j.getObjValAs? String "network" with
  | "mainnet" => pure .mainnet
  | "testnet" => pure .testnet
  | "regtest" => pure .regtest
  | "stn" => pure .stn
  | other => throw s!"unknown network {other}"

/-- A displayed-order hash string as the header-hash integer. -/
def displayHash (s : String) : Except String (BitVec 256) := do
  let bytes ← need (BsvScript.Tx.hexDecode s) s!"bad hash {s}"
  unless bytes.length == 32 do throw s!"hash length {s}"
  return BitVec.ofNat 256 (BsvScript.Numbers.leNat bytes.reverse)

def judgment (r : Except Reject Unit) : Json :=
  match r with
  | .ok () => Json.mkObj [("status", "ok")]
  | .error e => Json.mkObj [("status", "rejected"), ("reason", toJson e.reason)]

/-- [D] Eleven equal ancestor times ending at the row's parent height. -/
def eraPrevious (height : Nat) (times : List Nat) (bits : BitVec 32) : HeaderChain :=
  ⟨height - 1, times.map (fun t => ⟨t, bits, 0⟩)⟩

/-- [D] A coinbase-only block at `height` with the BIP34 height push, for the
size rows; proof of work is not this row's subject and is switched off. -/
def eraSizeBlock (height : Nat) : Block :=
  let cb : Tx := ⟨1, [⟨List.replicate 32 0, 0xffffffff, coinbaseHeightPush height ++ [0x51], 0xffffffff⟩],
    [⟨0, fixtureScript⟩], 0⟩
  let root := (blockMerkleRoot [cb]).root
  ⟨⟨4, 0, BitVec.ofNat 256 (BsvScript.Numbers.leNat root), 1700000000, 0x207fffff, 0⟩, [cb]⟩

/-- [D] The BIP30 connection rows: block A at 102 holds coinbase C; block B at
103 repeats C byte for byte. The default context computes the gate. -/
def bip30ConnectCase (disable : Bool) : Except String Json := do
  -- A structure update copies the derived field; re-derive it for the new setting.
  let ctx := if disable then
      let cfg := { fixtureConfig with disableBip30Checks := true }
      { fixtureContext with cfg, connectionChecks := fun s i _ => eraConnectionChecks .regtest cfg s i }
    else fixtureContext
  let (s, a) ← mine initialState ctx [] 69
  let c ← need a.transactions.head? "missing coinbase"
  let parent ← need (s.tree.get a.header.hash) "missing A"
  let header : BlockHeader := ⟨1, parent.id, BitVec.ofNat 256 (BsvScript.Numbers.leNat (blockMerkleRoot [c]).root),
    BitVec.ofNat 32 1700000070, parent.header.bits, 0⟩
  let header ← need (mineHeader .regtest header 10000) "fixture nonce-search budget exhausted"
  let b : Block := ⟨header, [c]⟩
  let s ← store s ctx b 2069
  let index ← need (s.tree.get b.header.hash) "missing B"
  return match connectTip s ctx .empty evalOracle index index with
    | .ok _ => Json.mkObj [("status", "ok")]
    | .error r => Json.mkObj [("status", "rejected"), ("reason", toJson r.reason)]

def eraRow (j : Json) : Except String Json := do
  let params ← eraNetwork j
  let cfg := fixtureConfig
  match ← j.getObjValAs? String "case" with
  | "version" =>
    let height ← j.getObjValAs? Nat "height"
    let version ← j.getObjValAs? Nat "version"
    let header : BlockHeader := ⟨BitVec.ofNat 32 version, 0, 0, 0, 0x207fffff, 0⟩
    return judgment (← need (checkBlockVersion params header height) "unresolved activation height")
  | "lock-cutoff" =>
    let height ← j.getObjValAs? Nat "height"
    let blockTime ← j.getObjValAs? Nat "blockTime"
    let times ← j.getObjValAs? (List Nat) "previousTimes"
    let tx : Tx := ⟨1, [⟨List.replicate 32 7, 0, [1, 0x51], ← j.getObjValAs? Nat "sequence"⟩],
      [⟨1000, fixtureScript⟩], ← j.getObjValAs? Nat "lockTime"⟩
    let cutoff ← need (blockFinalityCutoff params cfg height blockTime times) "unresolved CSV height"
    let verdict ← need (contextualCheckTransactionForBlock params cfg tx height blockTime times) "unresolved CSV height"
    let base := judgment (verdict.map (fun _ => ()))
    return base.mergeObj (Json.mkObj [("cutoff", toJson cutoff)])
  | "bip30" =>
    let height ← j.getObjValAs? Nat "height"
    let hash ← displayHash (← j.getObjValAs? String "hash")
    let ancestor ← match j.getObjVal? "bip34Ancestor" with
      | .ok .null | .error _ => pure none
      | .ok v => some <$> (displayHash (← fromJson? v))
    let cfg := { cfg with disableBip30Checks := ← field j "disable" false }
    return Json.mkObj [("enforced", toJson (bip30Enforced params cfg height hash ancestor))]
  | "bip30-connect" => bip30ConnectCase (← field j "disable" false)
  | "work-path" =>
    let parent : Option Nat ← match j.getObjVal? "parentHeight" with
      | .ok .null | .error _ => pure none
      | .ok v => some <$> fromJson? v
    let path := match nextWorkPath params parent with
      | .genesis => "genesis" | .noRetargeting => "noRetargeting" | .cash => "cash" | .eda => "eda"
    return Json.mkObj [("path", toJson path)]
  | "regtest-bits" =>
    let blocks ← j.getObjValAs? Nat "blocks"
    let genesis : HeaderWork := ⟨1296688602, 0x207fffff, 2⟩
    let mut chain : HeaderChain := ⟨0, [genesis]⟩
    let mut bits : List String := []
    for k in List.range blocks do
      let candidate : BlockHeader := ⟨4, 0, 0, BitVec.ofNat 32 (1296688602 + 600 * (k + 1)), 0, 0⟩
      let next ← need (getNextWorkRequired params cfg (some chain) candidate) "unresolved next work"
      bits := bits ++ [hexEncode (headerWordBytes 4 next.toNat).reverse]
      chain := ⟨chain.height + 1, ⟨candidate.time.toNat, next, 0⟩ :: chain.ancestors⟩
    return Json.mkObj [("bits", toJson bits)]
  | "era" =>
    let height ← j.getObjValAs? Nat "height"
    let era := BsvScript.Params.protocolEraOf params.genesisHeight params.chronicleHeight height
    let name := if era.chronicleActive then "chronicle" else if era.genesisActive then "genesis" else "preGenesis"
    return Json.mkObj [("era", toJson name), ("blockSigOpsCounted", toJson !era.genesisActive)]
  | "uahf-size" =>
    let height ← j.getObjValAs? Nat "height"
    let cfg := { cfg with excessiveBlockSize := ← j.getObjValAs? Nat "excessiveBlockSize" }
    let block := eraSizeBlock height
    let times := List.replicate 11 1699999000
    let structural := (checkBlock params cfg block height { proofOfWork := false }).mapError (·.toReject)
    let previous := eraPrevious height times 0x207fffff
    let contextual ← need (contextualCheckBlock params cfg block (some previous)) "unresolved body context"
    let verdict := match structural with
      | .error r => Except.error r
      | .ok () => contextual
    let forkid ← need ((ordinaryScriptFlags cfg params height true).map (·.enableSighashForkid)) "unresolved script word"
    return (judgment verdict).mergeObj (Json.mkObj [("size", toJson block.encode.length),
      ("legacyBound", toJson LEGACY_MAX_BLOCK_SIZE), ("forkid", toJson forkid)])
  | other => throw s!"unknown era case {other}"

/-- [D] The node-free era leg: every row's provenance, then its expectation. -/
def erasReport (path : String) : IO UInt32 := do
  let rows := (← IO.FS.readFile path).splitOn "\n" |>.filter (fun s => !s.trimAscii.toString.isEmpty)
  let mut count := 0
  let mut failures := 0
  for line in rows do
    let result : Except String (String × Json × Json) := do
      let j ← Json.parse line
      let id ← j.getObjValAs? String "id"
      unless (← j.getObjValAs? String "label") == "[D]" &&
          NodeMetadata.valid (← j.getObjValAs? String "node") do throw s!"{id}: invalid corpus provenance"
      return (id, ← j.getObjVal? "expected", ← eraRow j)
    match result with
    | .error e => failures := failures + 1; IO.eprintln s!"chaincheck eras: ERROR {e}"
    | .ok (id, expected, actual) =>
      count := count + 1
      if actual != expected then
        failures := failures + 1
        IO.eprintln s!"chaincheck eras: MISMATCH {id}\nexpected {expected.compress}\nobserved {actual.compress}"
  IO.println s!"chaincheck eras: {if failures == 0 && count > 0 then "GREEN" else "RED"} [X] ([M] {count} era rows; agree {count - failures}; failures {failures}; node column independently recorded)"
  return if failures == 0 && count > 0 then 0 else 1

/-! ## Validation depth and safe mode (#73) -/

/-- [D] 2026-10-14: the node rows bury their block under 2,017 or 2,016
blocks. The model replays the same shape with this many blocks removed from
both chains and the same count of spacings removed from the two-week setting,
which leaves the burial less the setting unchanged; the full-size burial is
checked as arithmetic beside it.
[SRC] src/validation.cpp:3511-3514 at 6504a3af. -/
def depthScale : Nat := 2015

/-- [D] A spend of the fixture coin whose redeem script does not hash to the
coin's script: the script fails wherever it is run.
[SRC] src/validation.cpp:2885-2924 at 6504a3af, through the landed evaluator. -/
def failingTx : Tx :=
  ⟨1, [⟨fundingPoint.hash, fundingPoint.index, [1, 0x52], 0xffffffff⟩], [⟨99000, fixtureScript⟩], 0⟩

/-- [D] The chain-tip status word of the reference's RPC, on the model's index.
[SRC] src/rpc/blockchain.cpp:2497-2632 at 6504a3af. -/
def tipStatusWord (s : ChainState) (i : BlockIndex) : String :=
  if s.active.contains i.id then "active"
  else if i.status.failed || i.status.failedParent then "invalid"
  else if i.chainTx == 0 then "headers-only"
  else if i.status.validity ≥ 5 then "valid-fork"
  else "valid-headers"

/-- [D] 2026-10-14: `count` blocks chained on `parent`, built with no state:
`makeBlock` reads only the parent's identifier, height and target.
[SRC] src/primitives/block.h:26-45 at 6504a3af. -/
def depthChain (parent : BlockIndex) (count tag : Nat) (leading : List Tx) : Except String (List Block) := do
  let mut parent := parent
  let mut blocks : List Block := []
  for i in List.range count do
    let b ← makeBlock parent (if i == 0 then leading else []) (tag + i)
    parent := { header := b.header, parent := some parent.id, height := parent.height + 1, work := parent.work, tieRank := 0 }
    blocks := blocks ++ [b]
  return blocks

/-- [D] 2026-10-14: an assumevalid row through the machine: the active chain's
bodies stored and activated, then the side chain's bodies stored, with the
activation run where a body can change the best chain (after each of the side
chain's last two: equal work, then more work), under the row's settings with
the depth decision wired.
[SRC] src/validation.cpp:3482-3518,4913-5130 at 6504a3af. -/
def depthAssumeValidCase (setup : Json) : Except String Json := do
  let aFull ← setup.getObjValAs? Nat "a_blocks"
  let fFull ← setup.getObjValAs? Nat "f_blocks"
  unless aFull > depthScale && fFull == aFull + 1 do throw "depth row outside the scaled shape"
  let (aLen, fLen) := (aFull - depthScale, fFull - depthScale)
  let base := initialState
  let aBlocks ← depthChain (← tip base) aLen 1 []
  let fBlocks ← depthChain (← tip base) fLen 40 [failingTx]
  let aTip ← need aBlocks.getLast? "no active chain"
  let fTip ← need fBlocks.getLast? "no side chain"
  let bad ← need fBlocks.head? "no bad block"
  let assumed : BitVec 256 ← match ← setup.getObjValAs? String "assumevalid" with
    | "zero" => pure 0
    | "fork-tip" => pure fTip.header.hash
    | "active-tip" => pure aTip.header.hash
    | "unknown" => pure 0x73
    | other => throw s!"assumevalid choice {other}"
  let floor ← match setup.getObjValAs? String "minimumchainwork" with
    | .ok word => need ((hexDecode word).map (fun bytes => bytes.foldl (fun acc b => acc * 256 + b) 0)) "invalid work floor"
    | .error _ => pure DepthNetwork.regtest.minimumChainWork
  let cfg : NodeConfig := { fixtureConfig with
    assumeValid := assumed, minimumChainWork := floor
    assumeValidMinWorkTimeSeconds := NodeConfig.defaults.assumeValidMinWorkTimeSeconds - depthScale * 600 }
  let ctx := ({ fixtureContext with cfg }).withValidationDepth
  let mut s := base
  for (b, i) in aBlocks.zipIdx do
    s ← store s ctx b (1001 + i)
  s ← activate s ctx
  unless s.active.getLast? == some aTip.header.hash do throw "active chain not connected"
  for (b, i) in fBlocks.zipIdx do
    s ← store s ctx b (2000 + i)
    if i + 2 ≥ fLen then
      s ← activate s ctx
  let badIndex ← need (s.tree.get bad.header.hash) "missing bad index"
  let sideTip ← need (s.tree.get fTip.header.hash) "missing side tip"
  let tipName := if s.active.getLast? == some aTip.header.hash then "A"
    else if s.active.getLast? == some fTip.header.hash then "F" else "other"
  let full := blockProofEquivalentTime .regtest
    (BitVec.ofNat 256 (2 * (101 + fFull + 1))) (BitVec.ofNat 256 (2 * 103)) 0x207fffff
  return Json.mkObj [
    ("scriptChecks", toJson (scriptChecksRequired ctx.params ctx.cfg s.tree (bestHeader s.tree) badIndex)),
    ("burialSeconds", toJson full),
    ("node", Json.mkObj [
      ("tip", toJson tipName),
      ("badBlockActive", toJson (s.active.contains bad.header.hash)),
      ("badOutputUnspent", toJson (getCoin s.view.coins (txPoint failingTx)).isSome),
      ("sideTipStatus", toJson (tipStatusWord s sideTip))])]

/-- [D] 2026-10-14: a safe-mode row on a synthetic index: the common blocks,
the active chain to the row's height and a side chain of stored bodies.
[SRC] src/safe_mode.cpp:58-115,227-302 at 6504a3af. -/
def depthSafeModeCase (setup : Json) (rpc : Bool) : Except String Json := do
  let settings ← setup.getObjVal? "settings"
  let common ← setup.getObjValAs? Nat "common_height"
  let activeHeight ← setup.getObjValAs? Nat "active_height"
  let forkBlocks ← setup.getObjValAs? Nat "fork_blocks"
  let cfg : NodeConfig := { fixtureConfig with
    safeModeMaxForkDistance := ← settings.getObjValAs? Nat "maxForkDistance"
    safeModeMinForkLength := ← settings.getObjValAs? Nat "minForkLength"
    safeModeMinPowDifference := ← settings.getObjValAs? Int "minPowDifference" }
  let index (parent : Option BlockIndex) (tag : Nat) (status : BlockStatus) : BlockIndex :=
    let header : BlockHeader := ⟨1, (parent.map (·.id)).getD 0, BitVec.ofNat 256 tag, BitVec.ofNat 32 (1700000000 + tag), 0x207fffff, 0⟩
    { header, parent := parent.map (·.id), height := (parent.map (·.height + 1)).getD 0
      work := addChainWork ((parent.map (·.work)).getD 0) header.bits, tieRank := tag, txCount := 1
      chainTx := (parent.map (·.height + 2)).getD 1, status }
  let mut nodes : List (String × BlockIndex) := []
  let mut parent : Option BlockIndex := none
  let mut fork : Option BlockIndex := none
  for h in List.range (activeHeight + 1) do
    let i := index parent (1000 + h) { validity := 5 }
    nodes := nodes ++ [(if h == 0 then "genesis" else if h ≤ common then s!"C{h}" else s!"A{h}", i)]
    parent := some i
    if h == common then fork := some i
  let active := nodes.map (·.2.id)
  for k in List.range forkBlocks do
    let i := index fork (2000 + k) { validity := 3 }
    nodes := nodes ++ [(s!"F{common + 1 + k}", i)]
    fork := some i
  let tree : HeaderTree := { nodes := nodes.map (·.2) }
  let named (name : String) : Except String (BitVec 256) :=
    need ((nodes.find? (·.1 == name)).map (·.2.id)) s!"unknown block name {name}"
  let nameOf (hash : BitVec 256) : String := ((nodes.find? (·.2.id == hash)).map (·.1)).getD "other"
  let mut ignored ← (← field setup "ignored_before" ([] : List String)).mapM named
  if let .ok target := setup.getObjValAs? String "ignore" then
    ignored ← ignoreSafeModeForBlock tree active ignored (← named target)
  if let .ok target := setup.getObjValAs? String "reconsider" then
    ignored ← reconsiderSafeModeForBlock tree active ignored (← named target)
  let forks := safeModeForks tree cfg active ignored
  let level := safeModeLevel tree cfg active ignored
  if rpc then
    let refusal := safeModeRpcRefusal {} level false false
    return Json.mkObj [
      ("refused", toJson refusal.isSome),
      ("code", match refusal with | some (code, _) => toJson code | none => Json.null),
      ("message", match refusal with | some (_, message) => toJson message | none => Json.null),
      ("safeCommandAnswered", toJson (safeModeRpcRefusal {} level false true).isNone)]
  let bases := (forks.map (·.base)).eraseDups
  return Json.mkObj [
    ("level", toJson (match level with | .none => "none" | .unknown => "unknown" | .invalid => "invalid" | .valid => "valid")),
    ("node", Json.mkObj [
      ("safemodeenabled", toJson (level != .none)),
      ("forks", toJson (bases.map fun base => Json.mkObj [
        ("base", toJson (nameOf base)),
        ("tips", toJson ((forks.filter (·.base == base)).map (fun f => nameOf f.tip))),
        ("lastCommon", toJson (nameOf (((tree.get base).bind (·.parent)).getD 0)))]))])]

/-- [D] 2026-10-14: regtest's checkpoint table refuses a second header at its
only checkpoint height, and the setting switched off refuses nothing.
[SRC] src/validation.cpp:5903-5930 and src/chainparams.cpp:1530-1533 at 6504a3af. -/
def depthCheckpointCase : Json :=
  let word (cfg : NodeConfig) : String :=
    let ctx := { fixtureContext with cfg, checkpoints := DepthNetwork.regtest.checkpoints }
    match checkCheckpoint {} ctx ⟨1, 0, 0, 0, 0x207fffff, 7⟩ 0 with
    | .ok _ => "ok"
    | .error r => r.reason
  Json.mkObj [("enabled", toJson (word fixtureConfig)),
    ("disabled", toJson (word { fixtureConfig with checkpointsEnabled := false }))]

def runDepthRow (j : Json) : Except String Json := do
  let setup := (j.getObjVal? "setup").toOption.getD Json.null
  match ← j.getObjValAs? String "case" with
  | "assumevalid" => depthAssumeValidCase setup
  | "safemode" => depthSafeModeCase setup false
  | "safemode-rpc" => do
    return Json.mkObj [("node", ← depthSafeModeCase setup true)]
  | "checkpoint" => return depthCheckpointCase
  | other => throw s!"unknown depth case {other}"

/-- The #73 rows against the model, with no node. -/
def depthReport (path : String) : IO UInt32 := do
  let rows := (← IO.FS.readFile path).splitOn "\n" |>.filter (fun s => !s.trimAscii.toString.isEmpty)
  let mut count := 0
  let mut failures := 0
  -- [M] 2026-10-14: each row is a pure computation, so every row is
  -- spawned as a task and the results are read in file order (the same values and output).
  let tasks := rows.map fun line => Task.spawn fun _ => (do
      let j ← Json.parse line
      let id ← j.getObjValAs? String "id"
      unless (← j.getObjValAs? String "label") == "[D]" do throw s!"{id}: invalid corpus provenance"
      if let .ok node := j.getObjValAs? String "node" then
        unless NodeMetadata.valid node do throw s!"{id}: invalid node column"
      return (id, ← j.getObjVal? "expected", ← runDepthRow j) : Except String (String × Json × Json))
  for task in tasks do
    match task.get with
    | .error e => failures := failures + 1; IO.eprintln s!"chaincheck depth: ERROR {e}"
    | .ok (id, expected, actual) =>
      count := count + 1
      IO.println (Json.mkObj [("id", toJson id), ("observed", actual)]).compress
      if actual != expected then
        failures := failures + 1
        IO.eprintln s!"chaincheck depth: MISMATCH {id}\nexpected {expected.compress}\nobserved {actual.compress}"
  IO.eprintln s!"depth: {if failures == 0 && count > 0 then "GREEN" else "RED"} [X] ([M] {count} derived rows; agree {count-failures}; failures {failures}; node column independently recorded)"
  return if failures == 0 && count > 0 then 0 else 1

/-! ## #70: the operator lists (`--frozen`)

[D] 2026-10-14 (#70). Each row replays its freeze RPCs into
`OperatorLists` and judges the UTXO stage (`checkTxInputs`) of the named spend
with the derived projection, or projects the records as the two query RPCs
report them. Every row is operator data (policy). [SRC] src/frozentxo.cpp:27–171,
src/frozentxo_db.cpp:299–396,720–800 and src/rpc/frozentxo_rpc.cpp:404–499,
799–894 at 6504a3aff65ba97c0f6c80962b033e35ecbfed4b. -/

/-- [D] The rows' two funded outputs, by name. -/
def frozenNamed : List (String × OutPoint) :=
  [("F", ⟨List.replicate 32 0xf1, 0⟩), ("F2", ⟨List.replicate 32 0xf2, 0⟩)]

def frozenPointOf (name : String) : Except String OutPoint := do
  let base := (name.splitOn ":").head!
  need ((frozenNamed.find? (·.1 == base)).map (·.2)) s!"unknown output {name}"

def frozenNameOf (p : OutPoint) : String :=
  ((frozenNamed.find? (·.2 == p)).map (·.1)).getD "unnamed" ++ s!":{p.index}"

/-- [D] The confiscation transaction of the rows: the protocol marker, version 1,
a 20-byte order hash, then 99000 to OP_TRUE. [SRC] src/frozentxo_db.cpp:614–717 at 6504a3af. -/
def frozenCtx : Tx :=
  ⟨1, [⟨List.replicate 32 0xf1, 0, [], 0xffffffff⟩],
    [⟨0, [0, 0x6a, 4, 0x63, 0x66, 0x74, 0x78, 21, 1] ++ List.replicate 20 0xab⟩, ⟨99000, [0x51]⟩], 0⟩

def frozenSpend (p : OutPoint) : Tx := ⟨1, [⟨p.hash, p.index, [], 0xffffffff⟩], [⟨99000, [0x51]⟩], 0⟩

/-- [D] Replay a row's operator calls into the records. The rows carry the
three add calls only (five of the eight registered handlers are measured, the
two queries among them), so `unfreezePolicyOnly` and `clearWhitelist` are not
exercised here. [SRC] src/rpc/frozentxo_rpc.cpp:903–910 at 6504a3af. -/
def frozenReplay (ops : List Json) : Except String OperatorLists := do
  let mut d : OperatorLists := {}
  for op in ops do
    match ← op.getObjValAs? String "call" with
    | "addToPolicyBlacklist" => d := (d.freezePolicyOnly (← frozenPointOf (← op.getObjValAs? String "txOut"))).2
    | "addToConsensusBlacklist" =>
      let ranges ← (← op.getObjValAs? (List Json) "enforceAtHeight").mapM fun r => do
        let start ← r.getObjValAs? Int "start"
        match r.getObjVal? "stop" with
        | .ok v => pure ({ start, stop := ← fromJson? v } : HeightInterval)
        | .error _ => pure ({ start } : HeightInterval)
      d := (d.freezeConsensus (← frozenPointOf (← op.getObjValAs? String "txOut")) ranges
        (← op.getObjValAs? Bool "policyExpiresWithConsensus")).2
    | "addToConfiscationTxidWhitelist" =>
      let (result, next) := d.whitelistTx (← op.getObjValAs? Int "enforceAtHeight") frozenCtx
      unless result == .ok do throw "whitelist call not processed"
      d := next
    | other => throw s!"unknown operator call {other}"
  return d

def frozenBlacklistView (d : OperatorLists) : Json :=
  let funds := d.frozen.map fun (p, data) =>
    let lists : List String := match data.blacklist with
      | .policyOnly => ["policy"] | .consensus => ["policy", "consensus"] | .confiscation => []
    let base := Json.mkObj [("txOut", toJson (frozenNameOf p)), ("blacklist", toJson lists)]
    if data.blacklist == Blacklist.consensus then
      base.mergeObj (Json.mkObj [("enforceAtHeight", toJson (data.enforceAtHeight.map fun i =>
          Json.mkObj [("start", toJson i.start), ("stop", toJson i.stop)])),
        -- [D] queryBlacklist reports the flag as 0 or 1: a `bool` argument selects
        -- `pushKV`'s `int` overload [SRC] src/rpc/frozentxo_rpc.cpp:477 and
        -- src/univalue/include/univalue.h:121–141 at 6504a3af.
        ("policyExpiresWithConsensus", toJson (if data.policyExpiresWithConsensus then 1 else 0))])
    else base
  let key := fun (j : Json) => (j.getObjValAs? String "txOut").toOption.getD ""
  toJson (funds.toArray.qsort (fun a b => key a < key b)).toList

def frozenRow (j : Json) : Except String Json := do
  let d ← frozenReplay (← j.getObjValAs? (List Json) "operator")
  match ← j.getObjValAs? String "case" with
  | "query-blacklist" => return Json.mkObj [("funds", frozenBlacklistView d)]
  | "query-whitelist" =>
    let ctxId := BsvScript.Sighash.txid frozenCtx
    let txs := d.whitelist.map fun (id, w) => Json.mkObj [
      ("txId", toJson (if id == ctxId then "CTX" else "unnamed")),
      ("enforceAtHeight", toJson w.enforceAtHeight),
      ("inputs", toJson (w.confiscatedTxos.map frozenNameOf))]
    return Json.mkObj [("confiscationTxs", toJson txs), ("blacklist", frozenBlacklistView d)]
  | "spend" =>
    let onBlock := (← j.getObjValAs? String "path") == "block"
    let height ← j.getObjValAs? Nat "height"
    let tx ← match ← j.getObjValAs? String "spend" with
      | "CTX" => pure frozenCtx
      | name => pure (frozenSpend (← frozenPointOf name))
    let coins : List (OutPoint × Coin) := frozenNamed.map fun (_, p) => (p, ⟨100000, [0x51], 102, false, false⟩)
    let lists := d.project.atBlock (← field j "explicitFreeze" false) false
    let ctx : UtxoContext := ⟨ChainParams.regtest, height, height - 1, BsvScript.Params.Flags.ofWord 0, onBlock, onBlock, 0⟩
    return match checkTxInputs (coinMap coins) fixtureConfig ctx lists tx with
      | .ok _ => Json.mkObj [("status", "ok")]
      | .error r =>
        let base := Json.mkObj [("status", "rejected"), ("reason", toJson r.reason)]
        if onBlock then base.mergeObj (Json.mkObj [("softFreeze", toJson (r.code == .node 0x13))])
        else base.mergeObj (Json.mkObj [("code", toJson (match r.code with | .node n => (n : Int) | .rpc n => n))])
  | other => throw s!"unknown frozen case {other}"

/-- [D] The node-free operator-list leg: provenance, the policy label, then the
row's expectation. -/
def frozenReport (path : String) : IO UInt32 := do
  let rows := (← IO.FS.readFile path).splitOn "\n" |>.filter (fun s => !s.trimAscii.toString.isEmpty)
  let mut count := 0
  let mut failures := 0
  for line in rows do
    let result : Except String (String × Json × Json) := do
      let j ← Json.parse line
      let id ← j.getObjValAs? String "id"
      unless (← j.getObjValAs? String "label") == "[D]" && (← j.getObjValAs? String "kind") == "policy" &&
          NodeMetadata.valid (← j.getObjValAs? String "node") do throw s!"{id}: invalid corpus provenance"
      return (id, ← j.getObjVal? "expected", ← frozenRow j)
    match result with
    | .error e => failures := failures + 1; IO.eprintln s!"chaincheck frozen: ERROR {e}"
    | .ok (id, expected, actual) =>
      count := count + 1
      if actual != expected then
        failures := failures + 1
        IO.eprintln s!"chaincheck frozen: MISMATCH {id}\nexpected {expected.compress}\nobserved {actual.compress}"
  IO.println s!"chaincheck frozen: {if failures == 0 && count > 0 then "GREEN" else "RED"} [X] ([M] {count} operator-list rows, every row policy; agree {count - failures}; failures {failures}; node column independently recorded)"
  return if failures == 0 && count > 0 then 0 else 1

/-! ## #81: persistence across restarts (`--persist`)

[D] 2026-10-15 (#81). The scenario file's steps through the machine:
submissions through `accept`, the restarts through `Persist.shutdown` and
`Persist.start` on the same data directory, the chain steps through #64's
invalidation and mining. Genesis is active from height 100, as the node's launch
sets it: before Genesis a non-final transaction is refused, after it the held
pool takes it (src/validation.cpp:5977-5993). Synthetic coins at height 50 stand
for the node's coinbase coins (maturity is not under test); new outputs are
OP_TRUE (post-Genesis, as `statusViewMine`); lock times are relative to the tip
at the prefix's end, so the projection's heights are its own.
[SRC] src/init.cpp:237-240,1901-1905 and src/txmempool.cpp:3154-3344 at
6504a3aff65ba97c0f6c80962b033e35ecbfed4b. -/

/-- [D] The six fixture coins, `coin1` to `coin6`. -/
def persistCoin (n : Nat) : OutPoint := ⟨List.replicate 32 (40 + n), 0⟩

structure PersistRun where
  state : ChainState
  context : ChainContext
  pc : Persist.PersistConfig := {}
  dir : Persist.DataDir := {}
  txs : List (String × Tx)
  blocks : List (String × BitVec 256)
  clock : List (String × Int)

def persistName (r : PersistRun) (id : TxId) : String :=
  ((r.txs.find? (fun (_, tx) => BsvScript.Sighash.txid tx == id)).map (·.1)).getD "unnamed"

def sortedNames (names : List String) : Json := toJson (names.mergeSort (fun a b => decide (a ≤ b)))

def fateWord : Persist.LoadFate → String
  | .kept .accepted => "accepted"
  | .kept .heldNonFinal => "heldNonFinal"
  | .kept _ => "kept"
  | .dropped .expired => "expired"
  | .dropped .missingInputs => "missingInputs"
  | .dropped (.rejected _ reason) => "rejected:" ++ reason
  | .dropped (.notCompleted _) => "notCompleted"

/-- [D] The files a start finds, by name: the accepted file in its order, the
residual deltas, the held file as a set. -/
def filesJson (r : PersistRun) (dir : Persist.DataDir) : Json :=
  let main := (dir.mempool.map (·.records)).getD []
  let deltas := (dir.mempool.map (·.deltas)).getD []
  let held := (dir.nonFinal.map (·.records)).getD []
  Json.mkObj [("mempool", toJson (main.map (fun x => persistName r x.id))),
    ("deltas", toJson (deltas.map (fun d => persistName r d.1))),
    ("non_final", sortedNames (held.map (fun x => persistName r (BsvScript.Sighash.txid x.tx))))]

def persistContext (r : PersistRun) (clock : String) (cfg : NodeConfig := r.context.cfg) : Except String ChainContext := do
  let now ← need (r.clock.lookup clock) s!"unknown clock {clock}"
  return { r.context with cfg, now, bucketTime := now * 1000000000 }

/-- [D] One step: the action, then the observation the expectation names. -/
def persistStep (r : PersistRun) (step : Json) : Except String (PersistRun × List (String × Json)) := do
  let action ← step.getObjVal? "action"
  let kind ← action.getObjValAs? String "type"
  let tx (name : String) : Except String Tx := need (r.txs.lookup name) s!"unknown fixture {name}"
  let mut r := r
  let mut extra : List (String × Json) := []
  match kind with
  | "prefix" => pure ()
  | "submit" =>
    let ctx ← persistContext r (← action.getObjValAs? String "clock")
    let (s, _) := admit r.state ctx (← tx (← action.getObjValAs? String "tx"))
    r := { r with state := s, context := ctx }
  | "prioritise" =>
    let t ← tx (← action.getObjValAs? String "tx")
    let delta ← action.getObjValAs? Int "delta"
    r := { r with state := { r.state with mempool := Persist.prioritise r.state.mempool (BsvScript.Sighash.txid t) delta } }
  | "restart" =>
    let dir := Persist.shutdown r.pc r.state.mempool r.dir
    let pc : Persist.PersistConfig := match action.getObjValAs? Bool "persistmempool" with
      | .ok b => { persistMempool := b }
      | .error _ => {}
    let hours ← field action "mempoolexpirynonfinal" (fixtureConfig.mempoolNonFinalExpiry / 3600)
    let ctx ← persistContext r (← action.getObjValAs? String "clock")
      { fixtureConfig with mempoolNonFinalExpiry := hours * 3600 }
    let lc : Persist.LoadContext :=
      { utxo := r.state.view.coins, cfg := ctx.cfg, ctx := admissionContext r.state ctx, lists := .empty, oracle := evalOracle }
    let result := Persist.start pc lc dir
    let fates := fun (file : Persist.PersistFile) => Json.mkObj ((result.steps.filter (·.file == file)).map
      fun st => (persistName r st.id, toJson (fateWord st.fate)))
    let count := fun (file : Persist.PersistFile) =>
      let (k, f, e) := Persist.counts result.steps file
      toJson [k, f, e]
    extra := [("files_read", filesJson r dir),
      ("load", if pc.persistMempool then Json.mkObj [("mempool", fates .mempool), ("non_final", fates .nonFinal)] else Json.null),
      ("counts", if pc.persistMempool then Json.mkObj [("mempool", count .mempool), ("non_final", count .nonFinal)] else Json.null)]
    r := { r with state := { r.state with mempool := result.pool, disconnectPool := {} }, context := ctx, pc, dir }
  | "invalidateblock" =>
    let hash ← need (r.blocks.lookup (← action.getObjValAs? String "block")) "unknown block"
    let (s, status) := invalidateBlock r.state r.context .empty evalOracle hash 1000
    unless status == .complete do throw s!"persist invalidate: {repr status}"
    r := { r with state := s }
  | "generate" =>
    let ctx ← persistContext r (← action.getObjValAs? String "clock")
    let body ← (← action.getObjValAs? (List String) "transactions").mapM tx
    let (s, block) ← statusViewMine r.state ctx body (r.blocks.length + 10)
    let name ← action.getObjValAs? String "block"
    r := { r with state := s, context := ctx, blocks := r.blocks ++ [(name, block.header.hash)] }
  | "stop" =>
    let dir := Persist.shutdown r.pc r.state.mempool r.dir
    extra := [("files_written", filesJson r dir)]
    r := { r with dir }
  | other => throw s!"unknown persist action {other}"
  let tipBlock ← tip r.state
  let pool := r.state.mempool
  let names := fun (ids : List TxId) => ids.map (persistName r)
  let observed : List (String × Json) := [
    ("mempool", sortedNames (names (pool.accepted.map (·.id)))),
    ("non_final_pool", sortedNames (names (pool.nonFinal.map (·.entry.id)))),
    ("tip", toJson (((r.blocks.find? (·.2 == tipBlock.id)).map (·.1)).getD "unnamed")),
    ("entry_times", Json.mkObj (pool.accepted.map fun e => (persistName r e.id, toJson e.time))),
    ("fee_deltas", Json.mkObj (r.txs.filterMap fun (name, t) =>
      let d := feeDelta pool (BsvScript.Sighash.txid t)
      if d != 0 then some (name, toJson d) else none)),
    ("spent_on_chain", sortedNames ((List.range 6).filterMap fun n =>
      if (getCoin r.state.view.coins (persistCoin (n + 1))).isNone then some s!"coin{n + 1}" else none))] ++ extra
  return (r, observed)

/-- [D] An expectation names its clock symbols; the projection compares numbers. -/
def persistExpected (r : PersistRun) (key : String) (v : Json) : Json :=
  if key != "entry_times" then v else
  match v with
  | .obj kvs => Json.mkObj (kvs.toList.map fun (k, x) => (k, match x with
      | .str sym => ((r.clock.lookup sym).map toJson).getD x
      | other => other))
  | other => other

def persistReport (path : String) : IO UInt32 := do
  let raw ← IO.FS.readFile path
  let result : Except String (Nat × List String) := do
    let block ← need ((raw.splitOn "```json\n")[1]?) "missing scenario JSON"
    let j ← Json.parse ((block.splitOn "\n```").head!)
    let clock ← (← j.getObjVal? "clock").getObj?
    let clock ← clock.toList.mapM fun (k, v) => return (k, ← v.getInt?)
    let coins := (List.range 6).map fun n => (persistCoin (n + 1), (⟨100000, fixtureScript, 50, false, false⟩ : Coin))
    let base := initialState
    let state := { base with view := { base.view with coins := coinMap coins } }
    let a0 := (← tip state).id
    let context := { fixtureContext with params := { ChainParams.regtest with genesisHeight := 100 } }
    let (state, a1) ← statusViewMine state context [] 1
    let (state, a2) ← statusViewMine state context [] 2
    let tipHeight := (← tip state).height
    let fixtures ← j.getObjValAs? (List Json) "fixtures"
    let mut txs : List (String × Tx) := []
    for f in fixtures do
      let name ← f.getObjValAs? String "name"
      let spends ← f.getObjValAs? String "spends"
      let variant ← f.getObjValAs? Nat "variant"
      let (point, value, unlock) ← match txs.lookup spends with
        | some parent => pure (txPoint parent, 99000, ([] : Bytes))
        | none => pure (persistCoin ((spends.drop 4).toNat?.getD 0), 100000, [1, 0x51])
      let lock := match (← f.getObjValAs? String "lock") with
        | "tip" => tipHeight | "far" => tipHeight + 880 | _ => 0
      let sequence := match f.getObjValAs? Nat "sequence" with
        | .ok n => n | .error _ => 0xffffffff
      let t : Tx := ⟨1, [⟨point.hash, point.index, unlock, sequence⟩], [⟨value - 1000 * variant, [0x51]⟩], lock⟩
      txs := txs ++ [(name, t)]
    let blocks := [("A0", a0), ("A1", a1.header.hash), ("A2", a2.header.hash)]
    let mut run : PersistRun := { state, context, txs, blocks, clock }
    let mut lines : List String := []
    let mut count := 0
    for step in ← j.getObjValAs? (List Json) "steps" do
      let id ← step.getObjValAs? String "id"
      unless (← step.getObjValAs? String "label") == "[D]" && NodeMetadata.valid (← step.getObjValAs? String "node") do
        throw s!"{id}: invalid scenario provenance"
      let (next, observed) ← persistStep run step
      run := next
      let expected ← (← step.getObjVal? "expected_observations").getObj?
      for (key, value) in expected.toList do
        let seen ← need (observed.lookup key) s!"{id}: no projection of {key}"
        let want := persistExpected run key value
        let seen := if key == "entry_times" then
            Json.mkObj ((match want with | .obj kvs => kvs.toList.map (fun (kv : String × Json) => kv.1) | _ => []).filterMap fun k =>
              match seen.getObjVal? k with | .ok v => some (k, v) | .error _ => none)
          else seen
        unless seen.compress == want.compress do
          lines := lines ++ [s!"{id} {key}: expected {want.compress}; observed {seen.compress}"]
      count := count + 1
    return (count, lines)
  match result with
  | .error e =>
    IO.eprintln s!"chaincheck persist: ERROR {e}"
    IO.println "chaincheck persist: RED [X] (the scenario did not run)"
    return 1
  | .ok (count, lines) =>
    for l in lines do IO.eprintln s!"chaincheck persist: MISMATCH {l}"
    IO.println s!"chaincheck persist: {if lines.isEmpty && count > 0 then "GREEN" else "RED"} [X] ([M] {count} declared steps of {path}; {lines.length} disagreements; Persist.shutdown and Persist.start over accept; node column independently recorded)"
    return if lines.isEmpty && count > 0 then 0 else 1

/-! ## #88: the obligation list against the map, the ledger and its JSON (`--refinement`, `--obligations-json`)

[M] 2026-10-15 (#88); re-cut [M] 2026-10-17 (six kinds, the
divergences, the legs). `BsvChain.Teranode.Refinement.obligations` against `corpus/teranode/map.json` (#87),
`corpus/teranode/absences.json` (#96) and `corpus/teranode/obligations.json` (the list as data, the input of
`tools/node_contract.py`'s section 5 and of #95's gate): the map's row ids in its order are `mapRows` (and
`obligations_rows` proves the list's rows are `mapRows`), each row's issue is the map's obligation column,
each row's kind follows the map's mechanism (`same` a report or a witness, `absent` a design or chain-split row
naming at least one ledger row, `different` anything but a report), no row twice, every ledger row an obligation
names exists with that row as its map id, every ledger row of the file is named by the obligation of its map id,
whatever the kind, the row's effective word (`ruling.owner.word` where ruled, else `ruling.proposed`) equals the
word the list carries, every landed leg's record exists by its path (never opened), every label is consensus or
policy, each divergence's rule label is its row's (`Divergence.ruleLabel`: a design hold, policy, may sit on a
consensus rule, #92's premature-block row, [M] 2026-10-18), and the JSON file equals the list's emission (`--obligations-json` writes it). Node-free; the counts by
kind are read from the list. -/

open BsvChain.Teranode.Refinement in
def familyName : Family → String
  | .recordMark => "recordMark" | .blockMined => "blockMined" | .prune => "prune" | .fsmKeep => "fsmKeep"
  | .fsmExit => "fsmExit" | .alertStore => "alertStore" | .alertReassign => "alertReassign" | .ban => "ban"
  | .kafka => "kafka" | .reorg => "reorg"
  | .conflictDrop => "conflictDrop" | .invalidate => "invalidate" | .reconsider => "reconsider"
  | .frozenSpendBlock => "frozenSpendBlock" | .unminedExpire => "unminedExpire" | .evict => "evict"

open BsvChain.Teranode.Refinement in
/-- The list as data: `corpus/teranode/obligations.json` is this value, written by `--obligations-json`. -/
def obligationsJson : Json :=
  let names (ns : List Lean.Name) : Json := toJson (ns.map (·.toString))
  let leg (lr : Leg × String) : Json := Json.mkObj [("issue", toJson lr.1.issue), ("lane", toJson lr.1.lane),
    ("record", toJson lr.1.record), ("counts", toJson lr.1.counts), ("landed", toJson lr.1.landed),
    ("rows", toJson lr.2)]
  let owed (o : Owed) : Json := Json.mkObj [("names", names o.names), ("statement", toJson o.statement),
    ("owner", toJson o.owner)]
  let div (d : Divergence) : Json := Json.mkObj [("id", toJson d.id), ("issue", toJson d.issue),
    ("class", toJson (match d.cls with | .chainSplit => "chain-split" | .design => "design")),
    ("label", toJson d.label), ("rule_label", toJson d.ruleLabel), ("reason", toJson d.reason), ("model", names d.model),
    ("witnesses", toJson (d.witnesses.map leg))]
  let rel (r : Rel) : List (String × Json) := match r with
    | .stutter ts => [("rel", toJson "stutter"), ("names", names ts)]
    | .suspends t => [("rel", toJson "suspends"), ("names", names [t])]
    | .agreesOutside ts => [("rel", toJson "agrees outside the relation"), ("names", names ts)]
    | .owed n o => [("rel", toJson "owed"), ("names", names [n]), ("owner", toJson o)]
    | .departs => [("rel", toJson "departs"), ("names", names [])]
  let fam (a : Account) : Json := Json.mkObj ([("family", toJson (familyName a.family)),
    ("divergence", toJson (a.divergence.map (·.id)))] ++ rel a.rel)
  let primary (d : Discharge) : List Lean.Name := match d with
    | .proved ns _ _ _ _ => ns | .witness _ s => s | .design _ _ s _ => s | .chainSplit _ s => s
    | .report => [] | .owed o _ => o.names
  let row (o : Obligation) : Json := Json.mkObj [("row", toJson o.row), ("issue", toJson o.issue),
    ("label", toJson o.label), ("kind", toJson o.discharge.kind), ("names", names (primary o.discharge)),
    ("premises", toJson (match o.discharge with | .proved _ p _ _ _ => p | _ => "")),
    ("model_witnesses", names (match o.discharge with | .proved _ _ _ w _ => w | _ => [])),
    ("legs", toJson (o.discharge.legs.map leg)),
    ("divergences", toJson (o.discharge.divergences.map (·.id))),
    ("page", toJson (match o.discharge with | .design _ p _ _ => p | _ => none)),
    ("statement", toJson (match o.discharge with | .owed w _ => w.statement | _ => "")),
    ("owner", toJson o.discharge.owner?),
    ("owed_halves", toJson (o.discharge.rest.map owed)),
    ("ledger", toJson (o.ledger.map fun (i, w) => Json.mkObj [("id", toJson i), ("word", toJson w)])),
    ("rerun", toJson o.discharge.rerun)]
  Json.mkObj [
    ("_header", toJson [
      "corpus/teranode/obligations.json: #88's obligation list as data, one row per row of #87's map (corpus/teranode/map.json), each pointing at exactly one obligation of one kind.",
      "GENERATED by `lean/.lake/build/bin/chaincheck --obligations-json` from BsvChain.Teranode.Refinement (lean/BsvChain/Teranode/Refinement.lean: obligations, Divergence, accounts); `chaincheck --refinement` reads it RED when it differs from the emission. Never edited by hand.",
      "Read by tools/node_contract.py (section 5 of spec/node-client-contract.md) and by #95's per-release gate (the rows marked rerun). The legs' records are named, never quoted: their contents are withheld from the public edition by name; the counts are the public ones.",
      "[M] 2026-10-17, lane close-88 (S1 and S3). Teranode v0.16.0 = 4edb60a40c6628ff0ef60231c2628efd7103fde5, bitcoin-sv v1.2.3 = 6504a3aff65ba97c0f6c80962b033e35ecbfed4b (docs/PROVENANCE.md section 1a)."]),
    ("kinds", Json.mkObj [
      ("theorem", toJson "agreement theorems, every name resolved by the Lean elaborator, with the legs that measured the row agreeing"),
      ("witness", toJson "a measured leg on both nodes agreeing on the row: the harness is the judge (rule 4)"),
      ("design", toJson "an architecture decision of Teranode's in the protocol's service, its reason cited before the difference, its divergence labeled policy; the row keeps its rule's label (coinbase-maturity: the hold policy, the maturity rule consensus)"),
      ("chain-split", toJson "the two nodes decide the same blocks differently: a chain decision, consensus"),
      ("report", toJson "a row the two implement the same way, judged by the per-release divergence gate (#95)"),
      ("open", toJson "stated, not discharged: the Lean objects it names, its owner, and the legs that measured part of it")]),
    ("counts", Json.mkObj ([("rows", toJson obligations.length)] ++
      ["theorem", "witness", "design", "chain-split", "report", "open"].map (fun k => (k, toJson (countKind k))))),
    ("divergences", toJson (Divergence.all.map div)),
    ("families", toJson (accounts.map fam)),
    ("rows", toJson (obligations.map row))]

/-- The public edition lacks the paths `tools/export_withheld.txt` names (the owner's word, `tools/export_public.py`):
a landed leg's record on that list is absent there by design, said BY NAME, never a failure (the hosted gate of
2026-10-26, run 40408981548). An exact line of the list only: its globs name directories, never a record. -/
def withheldAtExport (path : String) : IO Bool := do
  let list : System.FilePath := "tools/export_withheld.txt"
  unless ← list.pathExists do return false
  let text ← IO.FS.readFile list
  return (text.splitOn "\n").any (fun line => line.replace "\r" "" == path)

open BsvChain.Teranode.Refinement in
def refinementReport (mapPath ledgerPath listPath : String) : IO UInt32 := do
  let parse (path : String) : IO Json := do
    match Json.parse (← IO.FS.readFile path) with
    | .ok j => pure j
    | .error e => throw (IO.userError s!"{path}: {e}")
  let rowsOf (j : Json) : Except String (Array Json) := do (← j.getObjVal? "rows").getArr?
  let mapJ ← parse mapPath
  let ledgerJ ← parse ledgerPath
  let mut failures : Array String := #[]
  let mut skipped : Array String := #[]
  let mapRowsJ ← match rowsOf mapJ with | .ok a => pure a | .error e => throw (IO.userError e)
  let ledgerRowsJ ← match rowsOf ledgerJ with | .ok a => pure a | .error e => throw (IO.userError e)
  let read (j : Json) (key : String) : String := (j.getObjValAs? String key).toOption.getD ""
  -- `ruling.owner` is null until the maintainers rule, then `{word, date, by}` (the ledger's header, RULINGS).
  let ownerOf (j : Json) : Option Json :=
    match (j.getObjVal? "ruling").toOption.bind (fun r => (r.getObjVal? "owner").toOption) with
    | some Json.null => none
    | w => w
  let mapIds := mapRowsJ.toList.map (read · "id")
  if mapIds != mapRows then failures := failures.push "the map's row ids are not mapRows"
  let rows := obligations.map (·.row)
  if rows.eraseDups.length != rows.length then failures := failures.push "a row has two obligations"
  for o in obligations do
    if o.label != "consensus" && o.label != "policy" then
      failures := failures.push s!"{o.row}: label {o.label} (consensus or policy, rule 1)"
    match mapRowsJ.find? (fun j => read j "id" == o.row) with
    | none => failures := failures.push s!"{o.row}: not a row of the map"
    | some j =>
      if read j "obligation" != o.issue then
        failures := failures.push s!"{o.row}: issue {o.issue}, the map says {read j "obligation"}"
      let mech := read j "mechanism"
      let kind := o.discharge.kind
      if mech == "same" && kind != "report" && kind != "witness" then
        failures := failures.push s!"{o.row}: mechanism same, the list's kind {kind} (a same row is a report or a witness)"
      else if mech == "absent" && kind != "design" && kind != "chain-split" then
        failures := failures.push s!"{o.row}: mechanism absent, the list's kind {kind} (an absent row is a design or chain-split row)"
      else if mech == "absent" && o.ledger.isEmpty then
        failures := failures.push s!"{o.row}: an absent row naming no ledger row"
      else if mech == "different" && kind == "report" then
        failures := failures.push s!"{o.row}: mechanism different, the list's kind report"
      else if mech != "same" && mech != "absent" && mech != "different" then
        failures := failures.push s!"{o.row}: mechanism {mech} unknown"
    for (id, proposed) in o.ledger do
      match ledgerRowsJ.find? (fun j => read j "id" == id) with
      | none => failures := failures.push s!"{o.row}: ledger row {id} absent"
      | some j =>
        if read j "map_id" != o.row then failures := failures.push s!"{o.row}: ledger row {id} keys {read j "map_id"}"
        let p := ((j.getObjVal? "ruling").toOption.map (read · "proposed")).getD ""
        -- the effective word: the maintainers' where ruled, else the proposal (#96's `ruling_rule`)
        let (eff, whose) := match ownerOf j with
          | some w => ((w.getObjValAs? String "word").toOption.getD "", "ruled by the owner")
          | none => (p, "proposed")
        if eff != proposed then
          failures := failures.push s!"{o.row}: ledger row {id} {whose} {eff}, the list carries {proposed}"
    for (l, _) in o.discharge.legs do
      if l.landed then
        unless ← System.FilePath.pathExists l.record do
          if ← withheldAtExport l.record then
            skipped := skipped.push s!"{o.row}: leg {l.lane}'s record {l.record} withheld at export (the private history holds it)"
          else
            failures := failures.push s!"{o.row}: leg {l.lane}'s record {l.record} absent"
    if o.discharge.kind == "chain-split" && o.label != "consensus" then
      failures := failures.push s!"{o.row}: a chain-split row labeled {o.label}"
    for d in o.discharge.divergences do
      if d.ruleLabel != o.label then failures := failures.push s!"{o.row}: divergence {d.id}'s rule labeled {d.ruleLabel}, the row {o.label}"
  for s in [scenarioConflicts, scenarioLifetimes, scenarioBranches] do
    unless ← System.FilePath.pathExists s do failures := failures.push s!"scenario {s} absent"
  for j in ledgerRowsJ do
    match obligations.find? (·.row == read j "map_id") with
    | none => failures := failures.push s!"ledger row {read j "id"}: map id {read j "map_id"} has no obligation"
    | some o =>
      unless o.ledger.any (·.1 == read j "id") do
        failures := failures.push s!"{o.row}: ledger row {read j "id"} not named"
  -- the list as data: the file is the emission (compared compressed; Lean's objects keep their keys sorted)
  match Json.parse (← IO.FS.readFile listPath) with
  | .ok j => if j.compress != obligationsJson.compress then
      failures := failures.push s!"{listPath} differs from the list's emission (write it with --obligations-json)"
  | .error e => failures := failures.push s!"{listPath}: {e}"
  let ruled := ledgerRowsJ.toList.filter (fun j => (ownerOf j).isSome)
  let ledgerOf (k : String) : Nat :=
    ((obligations.filter (fun o => o.discharge.kind == k)).map (·.ledger.length)).foldl (· + ·) 0
  let halves := owedHalves
  let halvesBy (s : String) : Nat := (halves.filter (·.owner == s)).length
  let reruns := (obligations.filter (·.discharge.rerun)).length
  for f in skipped do IO.println s!"refinement: SKIPPED BY NAME {f}"
  for f in failures do IO.eprintln s!"refinement: RED {f}"
  let ok := failures.isEmpty && obligations.length == 54
  IO.println s!"refinement: {if ok then "GREEN" else "RED"} [X] ([M] {obligations.length} rows of {mapPath}, one obligation each, kinds tied to the map's mechanism: {countKind "theorem"} theorem ({countWithWitnesses} also carrying model witnesses), {countKind "witness"} witness, {countKind "design"} design, {countKind "chain-split"} chain-split, {countKind "report"} report, {countKind "open"} open (S1 {countOwedBy "S1"}, S3 {countOwedBy "S3"}, S4b {countOwedBy "S4b"}, the owner {countOwedBy "the owner"}); {Divergence.all.length} divergences; {halves.length} owed halves (S1 {halvesBy "S1"}, S3 {halvesBy "S3"}, S4b {halvesBy "S4b"}); {ledgerRowsJ.size} ledger rows read, {ledgerOf "design"} on design rows, {ledgerOf "chain-split"} on chain-split rows, {ledgerRowsJ.size - ledgerOf "design" - ledgerOf "chain-split"} on others, {ruled.length} ruled by the owner; {reruns} rows for #95's re-run; {listPath} {if failures.any (·.startsWith listPath) then "STALE" else "equal to the emission"}; failures {failures.size})"
  return if ok then 0 else 1

/-- Case computations take their unchanged context at the selected branch. A nullary
case definition is evaluated during module initialization, even for `--scenarios`;
context parameters keep that row's work at its call. Corpus equality is checked
against the untouched executable for every row and declared scenario step.
The default replays both projections. The short tripwire selects the seed
scenarios; the standalone full replay retains every derived row. Selection changes
only which independent checks run, never their inputs, evaluator or expectations.
`--profile` writes phase walls to stderr without changing verdict/report bytes. -/
def main (args : List String) : IO UInt32 := do
  -- [D] 2026-10-13: raw internal-order path projection for #65's RPC replay.
  if args.head? == some "--verify-path" then
    let result : Except String Bool := do
      let j ← Json.parse (← need args[1]? "missing path vector")
      let leaf ← j.getObjValAs? Bytes "leaf"
      let path ← j.getObjValAs? (List Bytes) "path"
      let index ← j.getObjValAs? Nat "index"
      let root ← j.getObjValAs? Bytes "root"
      unless leaf.length == 32 && root.length == 32 &&
          path.all (fun node => node.length == 32 && node.all (· < 256)) &&
          leaf.all (· < 256) && root.all (· < 256) do throw "invalid hash word"
      return verifyPath leaf path index root
    match result with
    | .ok valid => IO.println (if valid then "true" else "false"); return 0
    | .error e => IO.eprintln e; return 1
  -- [D] 2026-10-13: #75 the TSC proof view of a node reply, for the proof-surface runner.
  if args.head? == some "--verify-tsc" then
    match Json.parse (args[1]?.getD "") >>= verifyTscRow with
    | .ok out => IO.println out.compress; return 0
    | .error e => IO.eprintln e; return 1
  if args.head? == some "--mainnet-paths" then
    return ← runMainnetPaths (args[1]?.getD "corpus/chain/merkle/2026-10-13-mainnet-paths.jsonl")
  if args.head? == some "--p2p" then
    return ← P2PCheck.run (args[1]?.getD "")
  if args.head? == some "--compact" then
    return ← CompactCheck.run (args[1]?.getD "corpus/p2p/2026-10-15-compact-two-node.receipt.json")
  if args.head? == some "--dsnt" then
    return ← DsntCheck.run (args[1]?.getD "")
  if args.head? == some "--p2p-frames" then
    return ← P2PCheck.runFrames (args[1]?.getD "corpus/p2p/2026-10-15-relay-frames.jsonl")
  if args.head? == some "--minerid" then
    return ← MinerIdCheck.run (args[1]?.getD "corpus/minerid/coinbase-docs.jsonl")
  if args.head? == some "--prune" then
    return ← PruneCheck.run (args[1]?.getD "")
  if args.head? == some "--subtree" then
    return ← runSubtreeVectors (args[1]?.getD "corpus/merkle/subtree-vectors.jsonl")
  if args.contains "--status-views" then return ← statusViewsReport
  if args.head? == some "--eras" then
    return ← erasReport (args[1]?.getD "corpus/chain/eras/eras.jsonl")
  if args.head? == some "--depth" then
    return ← depthReport (args[1]?.getD "corpus/chain/depth/depth.jsonl")
  -- [D] 2026-10-15: #81 persistence across restarts, node-free.
  if args.head? == some "--persist" then
    return ← persistReport (args[1]?.getD "corpus/scenarios/2026-10-15-persist-restart.md")
  if args.head? == some "--refinement" then
    return ← refinementReport (args[1]?.getD "corpus/teranode/map.json") (args[2]?.getD "corpus/teranode/absences.json")
      (args[3]?.getD "corpus/teranode/obligations.json")
  -- [M] 2026-10-17: the obligation list as data, the file `--refinement` compares.
  if args.head? == some "--obligations-json" then
    IO.println obligationsJson.pretty
    return 0
  if args.head? == some "--frozen" then
    return ← frozenReport (args[1]?.getD "corpus/chain/frozen/frozen.jsonl")
  if args.contains "--profile-hashes" then return ← profileHashes
  if args.contains "--rows" && args.contains "--scenarios" then
    IO.eprintln "chaincheck: ERROR choose --rows or --scenarios, or omit both for the full replay"
    return 1
  let doRows := !args.contains "--scenarios"
  let doScenarios := !args.contains "--rows"
  let profile := args.contains "--profile"
  let path := (args.find? (fun a => !a.startsWith "--")).getD "corpus/chain/chain/chain.jsonl"
  let mut count := 0
  let mut failures := 0
  let mut parseNanos := 0
  let mut rowNanos := 0
  if doRows then
    let rows := (← IO.FS.readFile path).splitOn "\n" |>.filter (fun s => !s.trimAscii.toString.isEmpty)
    for line in rows do
      let (parsed, nanos) ← measure line fun line => do
        let j ← Json.parse line
        let id ← j.getObjValAs? String "id"
        unless (← j.getObjValAs? String "label") == "[D]" &&
            NodeMetadata.valid (← j.getObjValAs? String "node") do throw s!"{id}: invalid corpus provenance"
        let expected ← j.getObjVal? "expected"
        return (j, id, expected)
      parseNanos := parseNanos + nanos
      match parsed with
      | .error e => failures := failures + 1; IO.eprintln s!"chaincheck: ERROR {e}"
      | .ok (j, id, expected) =>
        let (result, nanos) ← measure j runRow
        rowNanos := rowNanos + nanos
        if profile then IO.eprintln s!"chaincheck profile: row {id} [M] {nanos} ns"
        match result with
        | .error e => failures := failures + 1; IO.eprintln s!"chaincheck: ERROR {e}"
        | .ok actual =>
          count := count + 1
          if args.contains "--observed" then IO.println (Json.mkObj [("id",toJson id),("observed",actual)]).compress
          if actual != expected then
            failures := failures + 1
            IO.eprintln s!"chaincheck: MISMATCH {id}\nexpected {expected.compress}\nobserved {actual.compress}"
    IO.println s!"chaincheck: {if failures == 0 && count > 0 then "GREEN" else "RED"} [X] ([M] {count} derived rows; agree {count-failures}; failures {failures}; node column independently recorded)"
  let mut scenarioRows : List Json := []
  let mut scenarioNanos := 0
  if doScenarios then
    -- [M] 2026-10-14: the orphaned case and the scenarios are pure, so they run as
    -- tasks beside the IO checks and are read in the order below (the same values and output);
    -- under --profile each scenario is executed inside `measure` as before.
    let orphaned := Task.spawn fun _ => orphanedProofCase fixtureContext
    let mut scenarioJobs : List (String × Except String Json × Option (Task (Except String (List Json)))) := []
    for path in ["corpus/scenarios/2026-10-12-mempool-presence-terminal.md", "corpus/scenarios/2026-10-12-bumpless-beef-stored-proof.md", "corpus/scenarios/2026-10-13-orphaned-block-proof.md", "corpus/scenarios/2026-10-13-assembly-excludes-low-fee.md"] do
      let raw ← IO.FS.readFile path
      let (parsed, nanos) ← measure raw fun raw => do
        let block ← need ((raw.splitOn "```json\n")[1]?) "missing scenario JSON"
        Json.parse ((block.splitOn "\n```").head!)
      parseNanos := parseNanos + nanos
      let task := match parsed with
        | .ok json => if profile then none else some (Task.spawn fun _ => runScenario json)
        | .error _ => none
      scenarioJobs := scenarioJobs ++ [(path, parsed, task)]
    if (← runMainnetPaths) != 0 then failures := failures + 1
    match merklePathCases with
    | .error e => failures := failures + 1; IO.eprintln e
    | .ok _ => IO.println "merkle paths: GREEN [X] ([D] odd-padding, empty-branch and null-marker vectors)"
    match tscCases with
    | .error e => failures := failures + 1; IO.eprintln e
    | .ok _ => IO.println "tsc proofs: GREEN [X] ([LIT] the standard's example round trip; [D] body proofs of 1 to 9 leaves verified and round-tripped; marker shapes)"
    match orphaned.get with
    | .error e => failures := failures + 1; IO.eprintln e
    | .ok _ => IO.println "orphaned proof: GREEN [X] ([D] #64 mined/invalidate execution; retained path valid; active inclusion absent)"
    for (path, parsed, task) in scenarioJobs do
      match parsed with
      | .error e => failures := failures + 1; IO.eprintln s!"chaincheck: ERROR {e}"
      | .ok json =>
        let (result, nanos) ← match task with
          | some t => measure t Task.get
          | none => measure json runScenario
        scenarioNanos := scenarioNanos + nanos
        if profile then IO.eprintln s!"chaincheck profile: scenario {path} [M] {nanos} ns"
        match result with
        | .error e => failures := failures + 1; IO.eprintln s!"chaincheck: ERROR {e}"
        | .ok rows => scenarioRows := scenarioRows ++ rows
    if args.contains "--scenario-report" then
      IO.FS.writeFile "/tmp/s6-64-scenarios.jsonl" (String.intercalate "\n" (scenarioRows.map Json.compress) ++ "\n")
    IO.println s!"chaincheck scenarios: [M] {scenarioRows.length} declared steps agree [X] in the spec projection; node column independently recorded; client/status projections owed; body-derived paths checked"
  if profile then
    IO.eprintln s!"chaincheck profile: JSON parsing/provenance [M] {parseNanos} ns; row execution [M] {rowNanos} ns; scenario execution [M] {scenarioNanos} ns"
  return if failures == 0 && (!doRows || count > 0) && (!doScenarios || scenarioRows.length == 29) then 0 else 1

end ChainCheck

def main := ChainCheck.main
