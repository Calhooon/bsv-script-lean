import BsvChain.Mempool

/-!
# Mempool persistence across a restart (#81)

The dump at shutdown and the load at start as transitions of the pool state of
#62, at bitcoin-sv v1.2.3, 6504a3aff65ba97c0f6c80962b033e35ecbfed4b.

Policy throughout: nothing here is consensus. `-persistmempool` is a node
setting (default on), read at four sites: the transaction database's
cross-check at launch (src/init.cpp:3548, src/txmempool.cpp:3030-3038), the
sanity check's resume (src/init.cpp:3549-3551), the load after the best chain is
activated (src/init.cpp:1901-1905) and the dump at shutdown
(src/init.cpp:237-240). The dump writes two files in the data
directory: `mempool.dat` for the accepted pool (src/txmempool.cpp:3279-3344) and
`non-final-mempool.dat` for the held pool (src/time_locked_mempool.cpp:247-284).
The load re-validates every unexpired record through the same admission machine
(`accept`, #62) with the file source, the record's own entry time as its
acceptance time and the pool's size limit on; nothing is restored without
re-validation (src/txmempool.cpp:3154-3273, src/time_locked_mempool.cpp:287-378).

What a load drops, by `DropReason`: a record whose entry time plus the expiry is
not after the load's clock (`expired`; src/txmempool.cpp:3209,3235-3240 and
src/time_locked_mempool.cpp:325,356-359); a record whose inputs are gone, as
when a block mined while the node was down spent one (`missingInputs`, the
orphan verdict, src/validation.cpp:1178-1188, with no orphan handler on the file
source, src/txn_validator.cpp:163-167); a record admission refuses
(`rejected`); a record whose admission did not complete (`notCompleted`). After
Genesis a record that is non-final at the load's tip is not dropped: admission
holds it, so it moves from the accepted pool to the held pool
(src/validation.cpp:1107-1119,5981-5987); before Genesis admission refuses it
`bad-txns-nonfinal` (src/validation.cpp:5989-5992), a `rejected` drop.

The ordering: the load runs after the block index is loaded and the best chain
activated (src/init.cpp:1884,1901), on a pool the fresh process starts empty;
the reference's own comment states the assumption that the block index's
unload, which clears the pool, never runs after the restore
(src/validation.cpp:7150-7156). Records are read in the dump's order, the
accepted pool's insertion order (src/txmempool.cpp:1851-1858, the sequenced
index src/txmempool.h:475-477); [D] the reference keeps that order topological
across a reorg (src/txmempool.cpp:2386), an assumption of this model, not a
theorem: `PoolTopological` names it and `dump_topological` carries it to the
file (`DumpTopological`); the held file is read in txid order
(src/time_locked_mempool.h:146-152,181-185), after the accepted file
(src/txmempool.cpp:3271-3272).

The clock is an explicit input: `ctx.now` is the one GetTime sample of the load
(src/txmempool.cpp:3172, src/time_locked_mempool.cpp:301), which a launch's
`-mocktime` sets (src/init.cpp:3198-3199). A shutdown during the load
(src/txmempool.cpp:3241-3243, src/init.cpp:1904) and a failure to open the dump
file for writing (src/txmempool.cpp:3289-3292) are not modelled; their absence
is declared in the record of #81.
-/

namespace BsvChain.Persist
open BsvChain BsvScript.Tx

/-- P: the persistence setting, outside `NodeConfig` (docs/PARAMETERS.md §8.7).
Default on. [SRC] src/validation.h:197-198, src/init.cpp:495-498 at 6504a3af. -/
structure PersistConfig where
  persistMempool : Bool := true
  deriving DecidableEq, Repr

/-- One record of `mempool.dat` at format version 2: the transaction, or its id
when the pool had moved the body to the transaction database, the entry time
and the entry's fee delta. Version 1 has no in-memory flag and every body.
[SRC] src/txmempool.cpp:2996-3021,3307-3323 at 6504a3af. -/
structure DumpRecord where
  id : TxId
  body : Option Tx
  time : Int
  feeDelta : Int
  deriving Repr

/-- The accepted pool's file: version, records in order and the residual fee
deltas of ids outside the pool. [SRC] src/txmempool.cpp:3296-3328 at 6504a3af. -/
structure MempoolDump where
  version : Nat := 2
  records : List DumpRecord
  deltas : List (TxId × Int)
  deriving Repr

/-- One record of `non-final-mempool.dat`: the transaction and its entry time.
[SRC] src/time_locked_mempool.cpp:262-272 at 6504a3af. -/
structure NonFinalRecord where
  tx : Tx
  time : Int
  deriving Repr

/-- The held pool's file; its version constant is 1.
[SRC] src/time_locked_mempool.h:98 and src/time_locked_mempool.cpp:262-272 at 6504a3af. -/
structure NonFinalDump where
  version : Nat := 1
  records : List NonFinalRecord
  deriving Repr

/-- The two files in the data directory; `none` is an absent file.
[SRC] src/txmempool.cpp:3289,3331-3332 and src/time_locked_mempool.cpp:255,276 at 6504a3af. -/
structure DataDir where
  mempool : Option MempoolDump := none
  nonFinal : Option NonFinalDump := none
  deriving Repr

/-- The order of the held pool's dump index: uint256's defaulted comparison,
lexicographic over the internal-order bytes.
[SRC] src/time_locked_mempool.h:146-152 and src/uint256.h:31,58 at 6504a3af. -/
def bytesLe : List Nat → List Nat → Bool
  | [], _ => true
  | _ :: _, [] => false
  | a :: as, b :: bs => a < b || (a == b && bytesLe as bs)

/-- P: the accepted pool's dump. `onDisk` names the entries whose bodies the
pool had moved to the transaction database (an observation; SaveTxsToDisk,
src/txmempool.cpp:1807-1833). Each entry's delta is written with it and erased
from the residual map. [SRC] src/txmempool.cpp:1982-1988,3279-3328 at 6504a3af. -/
def dumpMempool (p : Mempool) (onDisk : List TxId := []) : MempoolDump :=
  { records := p.accepted.map fun e =>
      { id := e.id, body := if onDisk.contains e.id then none else some e.tx,
        time := e.time, feeDelta := feeDelta p e.id },
    deltas := p.feeDeltas.filter fun d => !(p.accepted.map (·.id)).contains d.1 }

/-- The accepted pool is topological: no entry spends an output of an entry
inserted after it. [D] An assumption of this model on `Mempool.accepted`, not a
theorem of #62; the reference keeps its insertion order topological across a
reorg by construction ("Add original mempool contents on top to preserve
toposort"). [SRC] src/txmempool.cpp:1851-1858,2386 and src/txmempool.h:475-477
at 6504a3af. -/
def PoolTopological (p : Mempool) : Prop :=
  ∀ pre e post, p.accepted = pre ++ e :: post →
    ∀ i ∈ e.tx.inputs, i.prevHash ∉ post.map (·.id)

/-- The accepted pool's file is topological: no record's body spends an output
of a record written after it, so every in-file parent comes earlier.
[SRC] src/txmempool.cpp:1982-1988,3307-3323 (the records in the pool's order)
at 6504a3af. -/
def DumpTopological (d : MempoolDump) : Prop :=
  ∀ pre r post, d.records = pre ++ r :: post → ∀ tx, r.body = some tx →
    ∀ i ∈ tx.inputs, i.prevHash ∉ post.map (·.id)

/-- P: the held pool's dump, in txid order.
[SRC] src/time_locked_mempool.cpp:247-284 at 6504a3af. -/
def dumpNonFinal (p : Mempool) : NonFinalDump :=
  { records := (p.nonFinal.mergeSort (fun a b => bytesLe a.entry.id b.entry.id)).map
      fun e => { tx := e.entry.tx, time := e.entry.time } }

/-- P: shutdown. With the setting on (and the start's load completed, the flag
`fDumpMempoolLater`) both files are replaced; with it off nothing is written and
an earlier run's files stay in the data directory.
[SRC] src/init.cpp:158,237-240,1901-1905, src/txmempool.cpp:3331-3332,3342-3343
at 6504a3af. -/
def shutdown (pc : PersistConfig) (p : Mempool) (dir : DataDir) (onDisk : List TxId := []) : DataDir :=
  if pc.persistMempool then { mempool := some (dumpMempool p onDisk), nonFinal := some (dumpNonFinal p) }
  else dir

/-- The file a load step read. -/
inductive PersistFile where
  | mempool | nonFinal
  deriving DecidableEq, Repr

/-- Why a load dropped a record.
[SRC] src/txmempool.cpp:3209,3227-3240 and src/time_locked_mempool.cpp:325,347-359 at 6504a3af. -/
inductive DropReason where
  | expired
  | missingInputs
  | rejected (code : RejectCode) (reason : String)
  | notCompleted (outcome : TxOutcome)
  deriving DecidableEq, Repr

/-- A load step's fate: kept with admission's verdict, or dropped with a reason.
The reference counts a kept record as a success (`state.IsValid()`, held
included) and the others as failed or expired.
[SRC] src/txmempool.cpp:3227-3240,3259-3261 and src/validation.cpp:1117-1119 at 6504a3af. -/
inductive LoadFate where
  | kept (verdict : TxVerdict)
  | dropped (reason : DropReason)
  deriving DecidableEq, Repr

/-- P: admission's outcome as a load fate: accepted and held are kept; the
orphan verdict is missing inputs (state.Invalid with the missing-inputs mark).
[SRC] src/validation.cpp:1117-1119,1178-1188 and src/txmempool.cpp:3227-3234 at 6504a3af. -/
def fateOf : TxOutcome → LoadFate
  | .completed .accepted => .kept .accepted
  | .completed .heldNonFinal => .kept .heldNonFinal
  | .completed .orphan => .dropped .missingInputs
  | .completed (.rejected code reason) => .dropped (.rejected code reason)
  | outcome => .dropped (.notCompleted outcome)

/-- One record's ledger line: `outcome` is admission's, `none` when the record
was expired and never validated. -/
structure LoadStep where
  file : PersistFile
  id : TxId
  time : Int
  outcome : Option TxOutcome
  fate : LoadFate
  deriving Repr

/-- The environment of a start: the coins and tip after activation, the
admission context with the load's clock, and the transaction database after
the launch's cross-check (emptied when its key does not match the file,
src/txmempool.cpp:3057-3075). `txdbInSync` is the end-of-load comparison
(src/txmempool.cpp:3253-3257), an observation. -/
structure LoadContext where
  utxo : UtxoSet
  cfg : NodeConfig
  ctx : AdmissionContext
  lists : FrozenLists
  oracle : ScriptOracle
  observation : DetectorObservation := {}
  txdb : List (TxId × Tx) := []
  txdbInSync : Bool := true

/-- P: the request a load submits: the file source, the record's entry time,
the size limit on and no timed cancellation. The accepted file uses the normal
priority, which the budget treats as high (src/validation.cpp:999-1000); the
held file uses high for a standard transaction and low otherwise.
[SRC] src/txmempool.cpp:3213-3225, src/time_locked_mempool.cpp:330-344 and
src/txn_validator.cpp:171-177 at 6504a3af. -/
def fileRequest (tx : Tx) (time : Int) (priority : TxPriority) : TxRequest :=
  { tx, source := .file, priority, acceptTime := time, limitMempoolSize := true }

/-- P: a pool the fresh process starts with, filters at the configured policy.
[SRC] src/txn_recent_rejects.cpp:9-11 and src/time_locked_mempool.h:213-214 at 6504a3af. -/
def emptyPool (cfg : NodeConfig) : Mempool :=
  { recentRejects := rejectFilter cfg, nonFinalRecentlyRemoved := removedNonFinalFilter cfg }

/-- P: a fee delta added to the retained map, capped at MAX_MONEY. A load reaches
it only for an id outside the accepted pool; the reference's group repair for
a present entry (src/txmempool.cpp:1948-1973) is not reached by a file this
dump writes (`dump_residual_absent`).
[SRC] src/txmempool.cpp:1942-1947,3205-3208,3249-3251 at 6504a3af. -/
def prioritise (p : Mempool) (id : TxId) (delta : Int) : Mempool :=
  { p with feeDeltas := (id, min (BsvScript.TxRules.MAX_MONEY : Int) (feeDelta p id + delta)) ::
      p.feeDeltas.filter (fun d => d.1 != id) }

/-- P: the pool's Clear on a failed load: entries, spend index and the rolling
fee reset; the fee deltas and the held pool stay.
[SRC] src/txmempool.cpp:1345-1363,3264-3269 at 6504a3af. -/
def clearPool (p : Mempool) (now : Int) : Mempool :=
  { p with accepted := [], mapNextTx := [], rollingFee := { lastUpdate := now } }

/-- P: each file's expiry: the accepted pool's and the held pool's purge age,
both read at launch. [SRC] src/txmempool.cpp:3163 (config.GetMemPoolExpiry,
src/config.cpp:87) and src/time_locked_mempool.cpp:400-405 at 6504a3af. -/
def expiryOf (cfg : NodeConfig) : PersistFile → Nat
  | .mempool => cfg.mempoolExpiry
  | .nonFinal => cfg.mempoolNonFinalExpiry

/-- P: one record through the expiry test and, unexpired, through admission.
The test is strict: kept only when entry time plus expiry is after now.
[SRC] src/txmempool.cpp:3209-3240 and src/time_locked_mempool.cpp:325-359 at 6504a3af. -/
def loadOne (lc : LoadContext) (file : PersistFile) (expiry : Nat) (priority : TxPriority)
    (p : Mempool) (tx : Tx) (time : Int) : Mempool × LoadStep :=
  if time + (expiry : Int) > lc.ctx.now then
    let r := accept p lc.utxo lc.cfg lc.ctx lc.lists lc.oracle lc.observation (fileRequest tx time priority)
    (r.1, ⟨file, BsvScript.Sighash.txid tx, time, some r.2, fateOf r.2⟩)
  else (p, ⟨file, BsvScript.Sighash.txid tx, time, none, .dropped .expired⟩)

/-- P: a record's body, from the file or the transaction database.
[SRC] src/txmempool.cpp:3180-3198 at 6504a3af. -/
def resolve (lc : LoadContext) (r : DumpRecord) : Option Tx :=
  match r.body with
  | some tx => some tx
  | none => lc.txdb.lookup r.id

/-- P: the accepted file's records in order; the delta is applied before the
expiry test. A body missing from the transaction database ends the loop with
the reason, as the source's exception does.
[SRC] src/txmempool.cpp:3179-3244 at 6504a3af. -/
def loadRecords (lc : LoadContext) : Mempool → List DumpRecord → Mempool × List LoadStep × Option String
  | p, [] => (p, [], none)
  | p, r :: rs =>
    match resolve lc r with
    | none => (p, [], some "Transaction was not in mempool database")
    | some tx =>
      let p := if r.feeDelta != 0 then prioritise p (BsvScript.Sighash.txid tx) r.feeDelta else p
      let one := loadOne lc .mempool (expiryOf lc.cfg .mempool) .high p tx r.time
      let rest := loadRecords lc one.1 rs
      (rest.1, one.2 :: rest.2.1, rest.2.2)

/-- P: the accepted file: open and version check, the records, the residual
deltas, the database comparison; any failure clears the pool and the load
continues with the held file.
[SRC] src/txmempool.cpp:3111-3138,3161-3269 at 6504a3af. -/
def loadMempoolFile (lc : LoadContext) (p : Mempool) : Option MempoolDump → Mempool × List LoadStep × Option String
  | none => (clearPool p lc.ctx.now, [], some "Failed to open mempool file from disk")
  | some d =>
    if d.version < 1 || d.version > 2 then (clearPool p lc.ctx.now, [], some "Bad mempool dump version")
    else
      let run := loadRecords lc p d.records
      match run.2.2 with
      | some e => (clearPool run.1 lc.ctx.now, run.2.1, some e)
      | none =>
        let q := d.deltas.foldl (fun q (x : TxId × Int) => prioritise q x.1 x.2) run.1
        if lc.txdbInSync then (q, run.2.1, none)
        else (clearPool q lc.ctx.now, run.2.1, some "Mempool and transaction database contents do not match")

/-- P: the held file's records in order, against the purge age, each with its
standardness priority. [SRC] src/time_locked_mempool.cpp:318-366 at 6504a3af. -/
def loadNonFinalRecords (lc : LoadContext) : Mempool → List NonFinalRecord → Mempool × List LoadStep
  | p, [] => (p, [])
  | p, r :: rs =>
    let era := admissionEra lc.ctx
    let standard := BsvScript.Standard.isStandardTx (admissionScriptConfig lc.cfg lc.ctx)
      era.genesisActive era.chronicleActive
      (BsvScript.TxPolicy.sizeCap lc.cfg.toNodeConfig (!era.genesisActive)) r.tx
    let one := loadOne lc .nonFinal (expiryOf lc.cfg .nonFinal)
      (if standard.isNone then .high else .low) p r.tx r.time
    let rest := loadNonFinalRecords lc one.1 rs
    (rest.1, one.2 :: rest.2)

/-- P: the held file: an absent file or another version loads nothing.
[SRC] src/time_locked_mempool.cpp:287-312,371-375 at 6504a3af. -/
def loadNonFinalFile (lc : LoadContext) (p : Mempool) : Option NonFinalDump → Mempool × List LoadStep
  | none => (p, [])
  | some d => if d.version != 1 then (p, []) else loadNonFinalRecords lc p d.records

/-- A start's result: the pool, every record's ledger line in reading order,
and the accepted file's failure if it had one. -/
structure LoadResult where
  pool : Mempool
  steps : List LoadStep
  failure : Option String
  deriving Repr

/-- P: the load: the accepted file, then the held file.
[SRC] src/init.cpp:1901-1905 and src/txmempool.cpp:3154-3273 at 6504a3af. -/
def load (lc : LoadContext) (dir : DataDir) : LoadResult :=
  let main := loadMempoolFile lc (emptyPool lc.cfg) dir.mempool
  let held := loadNonFinalFile lc main.1 dir.nonFinal
  ⟨held.1, main.2.1 ++ held.2, main.2.2⟩

/-- P: a start: the fresh process's empty pool, then the load when the setting
is on. With it off the files are not read. The empty start is structural here:
`start` begins from `emptyPool`, as the reference's restore runs on the pool the
block index's unload leaves empty (src/validation.cpp:7150-7156).
[SRC] src/init.cpp:1901-1905,3548 and src/validation.cpp:7150-7156 at 6504a3af. -/
def start (pc : PersistConfig) (lc : LoadContext) (dir : DataDir) : LoadResult :=
  if pc.persistMempool then load lc dir else ⟨emptyPool lc.cfg, [], none⟩

/-- P: the success, failed and expired counts the reference logs per file.
[SRC] src/txmempool.cpp:3259-3261 and src/time_locked_mempool.cpp:368-369 at 6504a3af. -/
def counts (steps : List LoadStep) (file : PersistFile) : Nat × Nat × Nat :=
  let s := steps.filter (·.file == file)
  ((s.filter fun x => match x.fate with | .kept _ => true | _ => false).length,
   (s.filter fun x => match x.fate with | .dropped .expired => false | .dropped _ => true | _ => false).length,
   (s.filter fun x => x.fate == .dropped .expired).length)

end BsvChain.Persist
