import Bsvs.Run
/-!
# The evaluator's self-test (#14; the tripwire's `eval` leg)

Three parts, exit 1 on any failure:

1. **Fixed vectors**, each a corner the spec must decide with its citation: the
   number corners the predecessors crystallized (`-7 2 OP_MOD`, negative zero,
   `00 OP_CAT OP_BIN2NUM`, `NUM2BIN`'s sign bit and width), both flag branches
   under the block and mempool words (the gate ON for version 1, OFF for
   version 2; CLEANSTACK and DISCOURAGE_UPGRADABLE_NOPS as policy), `OP_RETURN`
   in both UTXO eras, P2SH for a pre-Genesis and a post-Genesis UTXO, an explicit
   invalid word, the pre-Genesis op limit, a truncated push, and a two-input
   spend whose second input fails (the advisory index).
2. **The corpora** (`corpus/seed`, `corpus/flow`) through `runSpend`: the mempool
   verdict against bsv-rs's recorded one (the crate runs under the node's own standard word
   since 0.3.27, `Spend::set_flags` on `flags.rs`'s word; the version knobs of 0.3.24 at
   `spend.rs:190–192` at 0.3.24 are gone: `docs/lanes/lean.md:27`), a mismatch allowed only for bsv-rs's known divergences
   (`Test/SeedCheck.lean`, `Test/FlagsCheck.lean`) and the recorded flow families.
3. **Determinism** is `Eval.verifyScript_deterministic`; the run is repeated on
   the fixed vectors as the executable's own check of it.
-/

namespace Bsvs.SelfTest
open BsvScript BsvScript.Params BsvScript.Numbers BsvScript.Machine BsvScript.Tx BsvScript.Hash
open Bsvs.Corpus Bsvs.Run

structure Fixed where
  name : String
  cite : String
  lock : Bytes
  unlock : Bytes := []
  version : Int := 2
  spendHeight : Nat := defaultSpendHeight
  utxoHeight : Nat := defaultSpendHeight
  consensus : Bool := true
  flags : Option Nat := none
  expect : Verdict

/-- A synthetic spend: the given version, one input per unlock spending a synthetic
outpoint (never a real transaction), `SEQUENCE_FINAL`, one output of one satoshi
locked by `OP_1`, lock time 0. -/
def mkTx (version : Int) (unlocks : List Bytes) : Tx :=
  { version,
    inputs := ((List.range unlocks.length).zip unlocks).map (fun (i, u) =>
      { prevHash := List.replicate 31 0x11 ++ [i], prevIndex := i, scriptSig := u, sequence := 0xffffffff }),
    outputs := [{ value := 1, scriptPubKey := [0x51] }], lockTime := 0 }

def prevoutsFor (locks : List Bytes) (height : Nat) : List Prevout :=
  ((List.range locks.length).zip locks).map (fun (i, l) =>
    { txid := String.ofList (List.replicate 62 '1' ++ [Char.ofNat (0x30 + i)]), vout := i, script := l, satoshis := 1000, height })

/-- `OP_HASH160 <hash160 redeem> OP_EQUAL` (`IsP2SH`, `script.cpp:168–172`). -/
def p2shLock (redeem : Bytes) : Bytes := [0xa9, 0x14] ++ hash160 redeem ++ [0x87]

def OP_NOP : Nat := 0x61

def fixed : List Fixed :=
  [ { name := "-7 2 OP_MOD = -1: truncation toward zero, the dividend's sign", cite := "script_num.cpp:245–246; big_int.cpp:250–260",
      lock := [0x01, 0x87, 0x52, 0x97, 0x4f, 0x87], expect := .valid },
    { name := "-7 2 OP_MOD is not 1", cite := "script_num.cpp:245–246; big_int.cpp:250–260",
      lock := [0x01, 0x87, 0x52, 0x97, 0x51, 0x87], expect := .invalid .evalFalse },
    { name := "negative zero decodes to 0: <0x80> OP_1ADD = 1 (version 2)", cite := "script_num.cpp:80–83; big_int.cpp:577–594; 433",
      lock := [0x01, 0x80, 0x8b, 0x51, 0x9c], expect := .valid },
    { name := "negative zero is non-minimal under MINIMALDATA: version 1, the mempool word", cite := "script_num.cpp:67; 1811–1814; 433",
      lock := [0x01, 0x80, 0x8b, 0x51, 0x9c], version := 1, consensus := false, expect := .invalid .scriptnumMinencode },
    { name := "negative zero under the block word, version 1: MINIMALDATA is policy", cite := "policy.h:177–181; blockScriptFlags_policy_off",
      lock := [0x01, 0x80, 0x8b, 0x51, 0x9c], version := 1, consensus := true, expect := .valid },
    { name := "00 OP_CAT OP_BIN2NUM: raw bytes to a number (0xff → 255)", cite := "1687–1706; 1780–1792",
      lock := [0x01, 0xff, 0x01, 0x00, 0x7e, 0x81, 0x02, 0xff, 0x00, 0x87], expect := .valid },
    { name := "NUM2BIN moves the sign bit into the padding: -1 to 2 bytes = 01 80", cite := "1771–1777; limitedstack.cpp:60–71",
      lock := [0x4f, 0x52, 0x80, 0x02, 0x01, 0x80, 0x87], expect := .valid },
    { name := "NUM2BIN to a width too narrow: 128 into 1 byte", cite := "1760–1763",
      lock := [0x02, 0x80, 0x00, 0x51, 0x80], expect := .invalid .impossibleEncoding },
    { name := "a non-minimal number with the gate ON (version 1, the mempool word)", cite := "40–44; 433; script_num.cpp:67",
      lock := [0x02, 0x01, 0x00, 0x8b, 0x52, 0x9c], version := 1, consensus := false, expect := .invalid .scriptnumMinencode },
    { name := "the same with the gate OFF (version 2, the mempool word)", cite := "40–44; 433",
      lock := [0x02, 0x01, 0x00, 0x8b, 0x52, 0x9c], version := 2, consensus := false, expect := .valid },
    { name := "the same under the mainnet relay word given explicitly (0x3D47FF), version 2", cite := "Flags.ofWord; 40–44",
      lock := [0x02, 0x01, 0x00, 0x8b, 0x52, 0x9c], version := 2, consensus := false, flags := some 0x3D47FF, expect := .valid },
    { name := "the same under the mainnet relay word given explicitly, version 1", cite := "Flags.ofWord; 433",
      lock := [0x02, 0x01, 0x00, 0x8b, 0x52, 0x9c], version := 1, consensus := false, flags := some 0x3D47FF, expect := .invalid .scriptnumMinencode },
    { name := "CLEANSTACK under version 1 with the mempool word: two elements left", cite := "2430–2448",
      lock := [0x51, 0x51], version := 1, consensus := false, expect := .invalid .cleanstack },
    { name := "CLEANSTACK is policy: the block word accepts the same version-1 spend", cite := "policy.h:188; blockScriptFlags_policy_off",
      lock := [0x51, 0x51], version := 1, consensus := true, expect := .valid },
    { name := "OP_RETURN at the top level post-Genesis succeeds with the stack as it is", cite := "858–861",
      lock := [0x51, 0x6a, 0x00], expect := .valid },
    { name := "the bytes after a top-level OP_RETURN are never parsed, even a truncated push", cite := "858–861; opreturn_suffix",
      lock := [0x51, 0x6a, 0x4c], expect := .valid },
    { name := "OP_RETURN for a pre-Genesis UTXO fails", cite := "867–869",
      lock := [0x51, 0x6a], utxoHeight := 620537, expect := .invalid .opReturn },
    { name := "a truncated push executed is BAD_OPCODE", cite := "script.h:180–181; 450–451",
      lock := [0x4c], expect := .invalid .badOpcode },
    { name := "P2SH for a pre-Genesis UTXO: the redeem script OP_1 runs", cite := "2380–2424; script.cpp:168–172",
      lock := p2shLock [0x51], unlock := [0x01, 0x51], utxoHeight := 620537, expect := .valid },
    { name := "P2SH for a pre-Genesis UTXO: the redeem script OP_0 leaves a false top", cite := "2418–2422",
      lock := p2shLock [0x00], unlock := [0x01, 0x00], utxoHeight := 620537, expect := .invalid .evalFalse },
    { name := "the P2SH shape for a post-Genesis UTXO is plain script: the hash equality decides", cite := "2383",
      lock := p2shLock [0x00], unlock := [0x01, 0x00], expect := .valid },
    { name := "an explicit word with UTXO_AFTER_CHRONICLE alone is INVALID_FLAGS", cite := "2259–2262; 2312–2313",
      lock := [0x51], flags := some 0x200000, expect := .invalid .invalidFlags },
    { name := "the pre-Genesis op limit: 501 opcodes", cite := "466–467; consensus.h:40",
      lock := List.replicate 501 OP_NOP ++ [0x51], utxoHeight := 620537, expect := .invalid .opCount },
    { name := "501 opcodes post-Genesis under the consensus limit", cite := "consensus.h:43",
      lock := List.replicate 501 OP_NOP ++ [0x51], expect := .valid },
    { name := "OP_NOP1 under the mempool word: DISCOURAGE_UPGRADABLE_NOPS", cite := "765–771; policy.h:185",
      lock := [0xb0, 0x51], consensus := false, expect := .invalid .discourageUpgradableNops },
    { name := "OP_NOP1 under the block word", cite := "blockScriptFlags_policy_off; verifyScript_relay_block_version2",
      lock := [0xb0, 0x51], consensus := true, expect := .valid },
    { name := "OP_2MUL for a post-Chronicle UTXO executes", cite := "360–375; 1247–1250",
      lock := [0x52, 0x8d, 0x54, 0x9c], expect := .valid },
    { name := "OP_2MUL for a post-Genesis pre-Chronicle UTXO is disabled", cite := "360–375; 470–471",
      lock := [0x52, 0x8d, 0x54, 0x9c], utxoHeight := 943815, expect := .invalid .disabledOpcode } ]

def runFixed (cfg : NodeConfig) (f : Fixed) : Except String Verdict := do
  let tx := mkTx f.version [f.unlock]
  let prevouts := prevoutsFor [f.lock] f.utxoHeight
  let r ← runSpend cfg tx prevouts f.spendHeight f.consensus (f.flags.map (fun w => [w])) none false
  pure r.verdict

/-- The like-for-like comparison with bsv-rs (`Test/SeedCheck.lean`, `Test/FlagsCheck.lean`). -/
partial def hasDivergenceShape : Bytes → Bool
  | [] => false
  | op :: rest =>
    match getOpTail op rest with
    | none => true
    | some (_, k) => Op.FIRST_UNDEFINED_OP_VALUE ≤ op || hasDivergenceShape (rest.drop k)

/-- The fourth bsv-rs divergence class (#18): the expansion opcodes `0xb3`–`0xb7`
executed as NOPs (`spend.rs:407` at 0.3.24); the reference executes them for a post-Chronicle
UTXO (`609–764`). -/
partial def hasExpansionOp : Bytes → Bool
  | [] => false
  | op :: rest =>
    match getOpTail op rest with
    | none => false
    | some (_, k) => (Op.OP_SUBSTR ≤ op && op ≤ Op.OP_RSHIFTNUM) || hasExpansionOp (rest.drop k)

def explainedByBsvRs (v : Verdict) (version : Int) (lock unlock : Bytes) (expect : String) : Bool :=
  (v == .invalid .badOpcode && (hasDivergenceShape lock || hasDivergenceShape unlock))
  || (v == .valid && expect == "invalid" && version > 1 && !isPushOnly unlock)
  || (hasExpansionOp lock || hasExpansionOp unlock)

def recordedFamily (family : String) : Bool :=
  family.startsWith "flow-candidate/" || family.startsWith "flow-policy/"

def corpusPart (cfg : NodeConfig) (path : String) : IO (Bool × String) := do
  let entries ← readEntries path
  let mut n := 0
  let mut skipped := 0
  let mut agree := 0
  let mut explained := 0
  let mut recorded := 0
  let mut unimpl := 0
  let mut mismatch := 0
  let mut shown := 0
  for e in entries do
    if (e.expect.find? (·.1.startsWith "bsv-rs@")).isNone then
      skipped := skipped + 1
      continue
    let some (_, bsv) := e.expect.find? (·.1.startsWith "bsv-rs@") | continue
    n := n + 1
    let mempool ← match runSpend cfg e.tx e.prevouts e.spendHeight false none none false with
      | .ok r => pure r | .error err => throw (IO.userError s!"{e.id}: {err}")
    let v := mempool.verdict
    let kind := verdictKind v
    if kind == "unimplemented" || kind == "undefined-in-reference" then unimpl := unimpl + 1
    else if recordedFamily e.family then recorded := recorded + 1
    else if kind == bsv.verdict then agree := agree + 1
    else
      let lock := (e.prevouts.head?.map (·.script)).getD []
      let unlock := (e.tx.inputs.head?.map (·.scriptSig)).getD []
      if e.family.startsWith "mutation/" && explainedByBsvRs v e.tx.version lock unlock bsv.verdict then
        explained := explained + 1
      else
        mismatch := mismatch + 1
        if shown < 10 then
          shown := shown + 1
          IO.println s!"  MISMATCH {e.id} ({e.family}): spec {kind}{(verdictCode v).map (" " ++ ·) |>.getD ""} under the mempool word vs bsv-rs {bsv.verdict}"
  let name := (path.splitOn "/").getLast!
  let line := s!"  {name}: {n} entries: agree {agree}, mismatch {mismatch}, explained by bsv-rs's known divergences {explained}, recorded families {recorded}, unimplemented or undefined-in-reference (reported, not counted) {unimpl}, without a bsv-rs verdict (skipped, not in the entries) {skipped}"
  IO.println line
  pure (mismatch == 0 && agree > 0, line)

def run (root : String) (cfg : NodeConfig) (cli : List (String × Bool) := []) : IO UInt32 := do
  IO.println "bsvs --self-test"
  let mut ok := true
  -- 0. the CLI's rows (`Bsvs.Cli.cliRows`, passed in by the executable's root)
  for (what, good) in cli do
    if !good then
      ok := false
      IO.println s!"  FAIL the CLI: {what}"
  IO.println s!"  the CLI: {(cli.filter (·.2)).length} of {cli.length} rows pass"
  -- 1. the fixed vectors, run twice (determinism executed)
  let mut passed := 0
  for f in fixed do
    match runFixed cfg f, runFixed cfg f with
    | .ok v, .ok v' =>
      if v != v' then
        ok := false
        IO.println s!"  NONDETERMINISM {f.name}"
      else if v == f.expect then passed := passed + 1
      else
        ok := false
        IO.println s!"  FAIL {f.name} [{f.cite}]: got {verdictKind v}{(verdictCode v).map (" " ++ ·) |>.getD ""}, expected {verdictKind f.expect}{(verdictCode f.expect).map (" " ++ ·) |>.getD ""}"
    | .error e, _ | _, .error e =>
      ok := false
      IO.println s!"  ERROR {f.name}: {e}"
  IO.println s!"  fixed vectors: {passed} of {fixed.length} pass, each run twice"
  -- the two-input spend: input 0 valid, input 1 false; the transaction invalid at input 1
  let tx2 := mkTx 2 [[], []]
  let prev2 := prevoutsFor [[0x51], [0x00]] defaultSpendHeight
  match runSpend cfg tx2 prev2 defaultSpendHeight true none none false with
  | .ok r =>
    if r.verdict == .invalid .evalFalse && r.input == some 1 && r.inputs.length == 2 then
      IO.println "  two inputs: the transaction verdict is input 1's EVAL_FALSE, input 0 valid (Q5)"
    else
      ok := false
      IO.println s!"  FAIL two inputs: {verdictKind r.verdict} at {repr r.input}"
  | .error e =>
    ok := false
    IO.println s!"  ERROR two inputs: {e}"
  -- a coinbase: never evaluated
  let cb : Tx := { version := 1, inputs := [{ prevHash := List.replicate 32 0, prevIndex := 0xffffffff, scriptSig := [0x4c], sequence := 0xffffffff }],
                   outputs := [{ value := 1, scriptPubKey := [0x51] }], lockTime := 0 }
  match runSpend cfg cb [{ txid := "", vout := 0, script := [], satoshis := 0, height := 0 }] defaultSpendHeight true none none false with
  | .ok r =>
    if r.coinbase && r.verdict == .valid && r.inputs.isEmpty then IO.println "  a coinbase input's script is never evaluated (DESIGN §5.5)"
    else
      ok := false
      IO.println "  FAIL coinbase"
  | .error e =>
    ok := false
    IO.println s!"  ERROR coinbase: {e}"
  -- a coinbase on each path (the applied set's lens): the block path's gate is `CheckCoinbase` (a 2-byte script
  -- passes it, `validation.cpp:587–589`), the mempool path's `CheckRegularTransaction`, which refuses it first
  -- (`bad-tx-coinbase`, `validation.cpp:600–601`, reached at `1035–1036`; `Run.txGate`)
  let cb2 : Tx := { cb with inputs := cb.inputs.map (fun i => { i with scriptSig := [0x51, 0x51] }) }
  let cbPrev : List Prevout := [{ txid := "", vout := 0, script := [], satoshis := 0, height := 0 }]
  match runSpend cfg cb2 cbPrev defaultSpendHeight true none none false,
        runSpend cfg cb2 cbPrev defaultSpendHeight false none none false with
  | .ok b, .ok m =>
    if b.gate == none && m.gate == some "bad-tx-coinbase" then
      IO.println "  a coinbase: the block path's gate passes it, the mempool path's refuses it bad-tx-coinbase"
    else
      ok := false
      IO.println s!"  FAIL coinbase gates: block {b.gate}, mempool {m.gate}"
  | .error e, _ | _, .error e =>
    ok := false
    IO.println s!"  ERROR coinbase gates: {e}"
  -- an input index the transaction does not have is refused before the coinbase's early verdict (`Run.runSpend`)
  match runSpend cfg cb2 cbPrev defaultSpendHeight true none (some 1) false,
        runSpend cfg (mkTx 2 [[]]) (prevoutsFor [[0x51]] defaultSpendHeight) defaultSpendHeight true none (some 1) false with
  | .error _, .error _ => IO.println "  an input index past the inputs is refused, a coinbase's among them"
  | _, _ =>
    ok := false
    IO.println "  FAIL an input index past the inputs was run"
  -- 2. the corpora
  for rel in ["corpus/flow/flow.jsonl", "corpus/seed/seed.jsonl"] do
    let path := s!"{root}/{rel}"
    if ← System.FilePath.pathExists path then
      let (good, _) ← corpusPart cfg path
      ok := ok && good
    else
      ok := false
      IO.println s!"  MISSING {path}"
  IO.println (if ok then "bsvs --self-test: GREEN" else "bsvs --self-test: RED")
  return (if ok then 0 else 1)

end Bsvs.SelfTest
