import Bsvs.Run
import Bsvs.SelfTest
import Lean.Data.Json
/-!
# `bsvs`: the evaluator CLI (#14; `docs/DESIGN.md` §6)

```
bsvs eval --tx <hex | @file> --prevouts <json array | @file> [--spend-height <n>] [--consensus true|false]
          [--flags <u32 | json array of u32>] [--config sv|sv-regtest|teranode] [--input <i>] [--trace] [--pretty]
          [--genesis-height <n> --chronicle-height <n>]
bsvs corpus <file.jsonl> [--out <file.jsonl>] [--config sv|sv-regtest|teranode] [--genesis-height <n> --chronicle-height <n>]
bsvs sighash --tx <hex|@file> --scriptcode <hex> --type <u32> [--input <i>] [--amount <satoshis>] [--forkid true|false]
bsvs --self-test [--root <repo>]
bsvs --version
```

`sighash` prints the digest the spec's `OP_CHECKSIG` signs (`BsvScript.Sighash.sighash`:
the BIP143 digest iff FORKID is enabled by the flags and the type has the FORKID bit
and not the CHRONICLE bit, else the original digest) for one input of a transaction
over a scriptCode (the locking script from the last `OP_CODESEPARATOR`, as
`CleanupScriptCode` left it), as 32 bytes of hex: the oracle a generator signs
against (#26's sighash family, 2026-09-24; the words come from `eval` the same way).

`eval` prints one JSON object: the transaction's verdict (`valid` · `invalid` ·
`undefined-in-reference` (an undecided region of the reference; none since D72, 2026-09-24) · `unimplemented`), its `code` (the reference's `SCRIPT_ERR_*` name at the pin)
and `message` (`ScriptErrorString`), the advisory `input` index, the transaction-level
`gate` beside the script verdict (`Run.txGate`), every input's verdict with the parameters it
ran under **echoed** (the flag word as the `uint32_t` and by name, the five limits, the heights,
the path), and with `--trace` the per-phase, per-instruction trace (`Bsvs.Trace`: each phase's
result proven to be the loop's; the steps the same computation by construction; since #50 the
verdict runs `verifyScriptI`, the trace the list machine; lean #32's second lens, B-10, A-10). The evaluator never reads a chain: the spend height
defaults to `DEFAULT_SPEND_HEIGHT` (`docs/PARAMETERS.md` §3), the path to the
block path (`consensus = true`), the configuration to SV-node's mainnet
defaults; every prevout carries its own `height`.

`corpus` runs every entry of a corpus file (the DESIGN §6 format) and writes,
per entry, the spec's verdict under the entry's own `params` and under the
mempool word of the same configuration (`spec` and `spec-mempool`), one JSON
object per line: the input of #15's differential.

`--config sv-regtest` is SV-node's default policy on the REGTEST chain's heights (`regtestChain`), and
`--genesis-height`/`--chronicle-height` (both together) move the configuration's two activation heights as
a node's `-genesisactivationheight`/`-chronicleactivationheight` do (`init.cpp:2474–2481`): the chain the
reference's own unit tables run on (`corpus/cpp`, #49: `txvalidationcache_tests` sets the two heights per
call, `test/txvalidationcache_tests.cpp:117–125`), so the spec derives that chain's era from the test's own
heights. The configuration's name carries the heights (`sv-regtest(genesis=1,chronicle=103)`), and the
harness's node runner checks it against what it was asked (`run_svnode --spec-config`).

`--self-test` is the tripwire's leg (`make check`): the fixed vectors, the
seed and flow corpora against bsv-rs's recorded verdicts, determinism.
-/

open BsvScript BsvScript.Params BsvScript.Numbers BsvScript.Machine BsvScript.Tx
open Bsvs.Corpus Bsvs.Run Bsvs.Trace
open Lean

namespace Bsvs.Cli

structure Args where
  positional : List String := []
  opts : List (String × String) := []
  switches : List String := []

def isSwitch (a : String) : Bool :=
  a ∈ ["--trace", "--pretty", "--self-test", "--version", "--help", "-h"]

/-- `--key value` pairs, switches, positionals; the fuel is the argument count. -/
def parseArgs (args : List String) : Args := go args.length args {}
where
  go : Nat → List String → Args → Args
  | 0, _, acc => acc
  | _, [], acc => acc
  | n + 1, a :: rest, acc =>
    if a.startsWith "--" || a == "-h" then
      if isSwitch a then go n rest { acc with switches := a :: acc.switches }
      else match rest with
        | v :: rest' =>
          if v.startsWith "--" then go n rest { acc with switches := a :: acc.switches }
          else go n rest' { acc with opts := (a, v) :: acc.opts }
        | [] => { acc with switches := a :: acc.switches }
    else go n rest { acc with positional := acc.positional ++ [a] }

def Args.get (a : Args) (k : String) : Option String := (a.opts.find? (·.1 == k)).map (·.2)
def Args.has (a : Args) (k : String) : Bool := a.switches.contains k

def hexOf (bs : Bytes) : String := hexEncode bs

def natJson (n : Nat) : Json := Json.num n

def flagsJson (f : Flags) : Json :=
  Json.mkObj [("word", natJson f.toWord), ("hex", s!"0x{String.ofList (Nat.toDigits 16 f.toWord)}"),
              ("names", Json.arr ((FlagBit.ofFlags f).map (fun b => Json.str b.testName)).toArray)]

def limitsJson (l : Limits) : Json :=
  Json.mkObj [("maxOpsPerScript", natJson l.maxOpsPerScript), ("maxScriptNumLength", natJson l.maxScriptNumLength),
              ("maxScriptSize", natJson l.maxScriptSize), ("maxPubKeysPerMultiSig", natJson l.maxPubKeysPerMultiSig),
              ("maxStackMemoryUsage", natJson l.maxStackMemoryUsage)]

def eraName : Era → String
  | .preGenesis => "pre-genesis"
  | .postGenesis => "post-genesis"
  | .postChronicle => "post-chronicle"

def inputParamsJson (cfg : NodeConfig) (ip : InputParams) : Json :=
  Json.mkObj [("flags", flagsJson ip.params.flags), ("limits", limitsJson ip.params.limits),
              ("spend_height", natJson ip.spendHeight), ("utxo_height", natJson ip.utxoHeight),
              ("consensus", Json.bool ip.consensus),
              ("era", eraName (cfg.protocolEra ip.spendHeight)), ("utxo_era", eraName ip.params.flags.utxoEra),
              ("explicit_flags", match ip.explicit with | some w => natJson w | none => Json.null)]

def optStr : Option String → Json
  | some s => Json.str s
  | none => Json.null

def stepJson (s : Step) : Json :=
  Json.mkObj [("pc", natJson s.pc), ("op", natJson s.op), ("name", opName s.op), ("push", natJson s.dataLen),
              ("exec", Json.bool s.exec), ("result", s.result), ("depth", natJson s.depth), ("alt", natJson s.altDepth),
              ("top", match s.top with | some t => Json.str (hexOf t) | none => Json.null),
              ("mem", natJson s.mem), ("ops", natJson s.ops)]

def phaseJson (p : PhaseTrace) : Json :=
  Json.mkObj [("phase", p.phase), ("outcome", p.outcome), ("steps", Json.arr (p.steps.map stepJson).toArray),
              ("stack", Json.arr (p.stack.map (fun b => Json.str (hexOf b))).toArray),
              ("alt", Json.arr (p.alt.map (fun b => Json.str (hexOf b))).toArray), ("mem", natJson p.memUsed)]

/-- The transaction-level gate as JSON (`Run.txGate`): `{"verdict": "valid"}` or `{"verdict": "invalid", "code": <the reject string>}`. -/
def gateJson (g : Option String) : Json :=
  match g with
  | some c => Json.mkObj [("verdict", "invalid"), ("code", c)]
  | none => Json.mkObj [("verdict", "valid")]

def inputJson (cfg : NodeConfig) (r : InputResult) : Json :=
  Json.mkObj ([("input", natJson r.index), ("verdict", verdictKind r.verdict), ("code", optStr (verdictCode r.verdict)),
               ("message", optStr (verdictMessage r.verdict)), ("params", inputParamsJson cfg r.input)] ++
              (match r.trace with | some t => [("trace", Json.arr (t.map phaseJson).toArray)] | none => []))

def spendJson (cfg : NodeConfig) (cfgName : String) (commit : String) (r : SpendResult) : Json :=
  Json.mkObj [("verdict", verdictKind r.verdict), ("code", optStr (verdictCode r.verdict)),
              ("message", optStr (verdictMessage r.verdict)),
              ("input", match r.input with | some i => natJson i | none => Json.null),
              ("coinbase", Json.bool r.coinbase), ("gate", gateJson r.gate),
              ("inputs", Json.arr (r.inputs.map (inputJson cfg)).toArray),
              ("config", cfgName), ("spec", s!"spec@{commit}"),
              ("reference", "bitcoin-sv v1.2.3 6504a3af (docs/PROVENANCE.md)")]

/-- The regtest chain's heights (`CRegTestParams`, `chainparams.cpp:1456–1498` `[SRC]`): P2SH from height 1
(`P2SH_ACTIVATION_REGTEST`, `chainparams.cpp:31`, `:1498`), BIP66 at 1,251 (`:1468`), BIP65 at 1,351 (`:1466`), CSV at 576
(`:1470`), UAHF and DAA from height 0 (`:1487`, `:1490`), Genesis at 10,000 (`GENESIS_ACTIVATION_REGTEST`, `:21`, `:1493`),
Chronicle at 15,000 (`CHRONICLE_ACTIVATION_REGTEST`, `:26`, `:1496`). The chain the reference's unit tables run on
(`TestChain100Setup`, `test/test_bitcoin.cpp:191–206`: a hundred blocks on regtest). -/
def regtestChain : ChainParams :=
  { p2shHeight := 1, bip66Height := 1251, bip65Height := 1351, csvHeight := 576,
    uahfHeight := 0, daaHeight := 0, genesisHeight := 10000, chronicleHeight := 15000 }

/-- `--config`: SV-node's mainnet defaults (`sv`), Teranode's (`teranode`), or SV-node's default policy on the regtest
chain's heights (`sv-regtest`: `regtestChain`, its activation heights the chain's 10,000 and 15,000 until
`--genesis-height`/`--chronicle-height` move them; the policy fields and `requireStandard` stay the mainnet default's,
which is what the harness's policy instance runs, `harness/oracle/bitcoin-policy.conf`). -/
def configOf (name : String) : Except String (NodeConfig × String) :=
  match name with
  | "sv" => pure (NodeConfig.svMainnetDefault, "sv-mainnet-default")
  | "sv-mainnet-default" => pure (NodeConfig.svMainnetDefault, "sv-mainnet-default")
  | "sv-regtest" =>
    pure ({ NodeConfig.svMainnetDefault with
              chain := regtestChain, genesisActivationHeight := 10000, chronicleActivationHeight := 15000 }, "sv-regtest")
  | "teranode" => pure (NodeConfig.teranodeDefault, "teranode-default")
  | "teranode-default" => pure (NodeConfig.teranodeDefault, "teranode-default")
  | s => throw s!"unknown --config {s} (sv | sv-regtest | teranode)"

def parseNat (s : String) (what : String) : Except String Nat :=
  let s' := if s.startsWith "0x" || s.startsWith "0X" then String.ofList (s.toList.drop 2) else s
  if s.startsWith "0x" || s.startsWith "0X" then
    if s'.isEmpty then throw s!"{what}: bad hex {s}" else
    match hexDecodeChars (if s'.length % 2 = 1 then '0' :: s'.toList else s'.toList) with
    | some bs => pure (beNat bs)
    | none => throw s!"{what}: bad hex {s}"
  else if s.isEmpty || !s.all Char.isDigit then throw s!"{what}: not a number: {s}"
  else match s.toNat? with
    | some n => pure n
    | none => throw s!"{what}: not a number: {s}"

/-- `--genesis-height`/`--chronicle-height` (both, or neither): the configuration's two activation heights, as a node's
`-genesisactivationheight`/`-chronicleactivationheight` set them (`init.cpp:2474–2481`); a zero is refused as the setters
refuse it (`configscriptpolicy.cpp:310–321`, `:353–364`). The configuration's name carries the heights. -/
def withHeights (a : Args) (cfg : NodeConfig) (name : String) : Except String (NodeConfig × String) := do
  match a.get "--genesis-height", a.get "--chronicle-height" with
  | none, none => pure (cfg, name)
  | some g, some c =>
    let g ← parseNat g "--genesis-height"
    let c ← parseNat c "--chronicle-height"
    if g = 0 then throw "--genesis-height 0: the node refuses a zero or negative height (configscriptpolicy.cpp:310–321)"
    if c = 0 then throw "--chronicle-height 0: the node refuses a zero or negative height (configscriptpolicy.cpp:353–364)"
    pure ({ cfg with genesisActivationHeight := g, chronicleActivationHeight := c }, s!"{name}(genesis={g},chronicle={c})")
  | _, _ => throw "--genesis-height and --chronicle-height go together (a node sets both activation heights)"

def parseFlagsArg (s : String) (nIn : Nat) : Except String (List Nat) := do
  if s.startsWith "[" then
    match Json.parse s with
    | .ok j => match j.getArr? with
      | .ok arr => do
        match Bsvs.Corpus.plainIntegers s with | .ok () => pure () | .error e => throw s!"--flags: {e}"
        arr.toList.mapM (fun w => match w.getNat? with
          | .ok n => if 2 ^ 32 ≤ n then throw s!"--flags: {n} does not fit 32 bits (rpc/misc.cpp:702)" else pure n
          | .error e => throw s!"--flags: {e}")
      | .error e => throw s!"--flags: {e}"
    | .error e => throw s!"--flags: {e}"
  else
    let w ← parseNat s "--flags"
    if 2 ^ 32 ≤ w then throw s!"--flags: {w} does not fit 32 bits (rpc/misc.cpp:702)"
    pure (List.replicate nIn w)

def readArgFile (v : String) : IO String := do
  if v.startsWith "@" then IO.FS.readFile (String.ofList (v.toList.drop 1)) else pure v

def evalCmd (a : Args) (commit : String) : IO UInt32 := do
  let some txHex := a.get "--tx" | throw (IO.userError "eval: --tx <hex> is required")
  let some prevArg := a.get "--prevouts" | throw (IO.userError "eval: --prevouts <json array | @file> is required")
  let txHex ← readArgFile txHex
  let prevText ← readArgFile prevArg
  let txBytes ← match hexDecode txHex.trimAscii.toString with | some b => pure b | none => throw (IO.userError "eval: --tx is not hex")
  let tx ← match decodeTx txBytes with | some t => pure t | none => throw (IO.userError "eval: the transaction frame does not parse")
  match Bsvs.Corpus.plainIntegers prevText with
  | .ok () => pure () | .error e => throw (IO.userError s!"eval: --prevouts: {e}")
  let prevJ ← match Json.parse prevText with | .ok j => pure j | .error e => throw (IO.userError s!"eval: --prevouts: {e}")
  let prevouts ← match parsePrevouts prevJ with | .ok p => pure p | .error e => throw (IO.userError s!"eval: --prevouts: {e}")
  let (cfg, cfgName) ← match configOf ((a.get "--config").getD "sv") with | .ok c => pure c | .error e => throw (IO.userError e)
  let (cfg, cfgName) ← match withHeights a cfg cfgName with | .ok c => pure c | .error e => throw (IO.userError s!"eval: {e}")
  let spendHeight ← match a.get "--spend-height" with
    | some s => match parseNat s "--spend-height" with | .ok n => pure n | .error e => throw (IO.userError e)
    | none => pure defaultSpendHeight
  match checkHeights spendHeight prevouts with
  | .ok () => pure ()
  | .error e => throw (IO.userError s!"eval: {e}")
  let consensus ← match a.get "--consensus" with
    | some "true" => pure true | some "false" => pure false | none => pure true
    | some s => throw (IO.userError s!"--consensus {s}: true | false")
  let flags ← match a.get "--flags" with
    | some s => match parseFlagsArg s tx.inputs.length with | .ok f => pure (some f) | .error e => throw (IO.userError e)
    | none => pure none
  let only ← match a.get "--input" with
    | some s => match parseNat s "--input" with | .ok n => pure (some n) | .error e => throw (IO.userError e)
    | none => pure none
  let r ← match runSpend cfg tx prevouts spendHeight consensus flags only (a.has "--trace") with
    | .ok r => pure r | .error e => throw (IO.userError s!"eval: {e}")
  let j := spendJson cfg cfgName commit r
  IO.println (if a.has "--pretty" then j.pretty else j.compress)
  return 0

/-- The spec's verdicts on one entry: under the entry's `params` (the block path
when `consensus`, else the mempool path; an explicit `flags` word when given),
and under the mempool word of the same configuration. -/
def entryVerdicts (cfg : NodeConfig) (e : Entry) : Except String (SpendResult × SpendResult) := do
  let own ← runSpend cfg e.tx e.prevouts e.spendHeight e.consensus e.flags none false
  let mempool ← runSpend cfg e.tx e.prevouts e.spendHeight false none none false
  pure (own, mempool)

def resultJson (r : SpendResult) : Json :=
  Json.mkObj [("verdict", verdictKind r.verdict), ("code", optStr (verdictCode r.verdict)),
              ("input", match r.input with | some i => natJson i | none => Json.null),
              ("gate", gateJson r.gate)]

def corpusCmd (a : Args) (commit : String) : IO UInt32 := do
  let some path := a.positional.head? | throw (IO.userError "corpus: a .jsonl file is required")
  let (cfg, cfgName) ← match configOf ((a.get "--config").getD "sv") with | .ok c => pure c | .error e => throw (IO.userError e)
  let (cfg, cfgName) ← match withHeights a cfg cfgName with | .ok c => pure c | .error e => throw (IO.userError s!"corpus: {e}")
  let entries ← readEntries path
  let mut lines : Array String := #[]
  let mut n := 0
  for e in entries do
    let (own, mempool) ← match entryVerdicts cfg e with | .ok r => pure r | .error err => throw (IO.userError s!"{e.id}: {err}")
    n := n + 1
    let j := Json.mkObj [("id", e.id), ("spec", resultJson own), ("spec-mempool", resultJson mempool),
                         ("config", cfgName), ("commit", commit)]
    lines := lines.push j.compress
  match a.get "--out" with
  | some out => IO.FS.writeFile out (String.intercalate "\n" lines.toList ++ "\n")
  | none => for l in lines do IO.println l
  IO.eprintln s!"bsvs corpus: {n} entries of {path} under {cfgName}, keyed spec@{commit}"
  return 0

/-- `bsvs sighash`: the spec's digest for one input over a scriptCode (#26's sighash family signs against it). -/
def sighashCmd (a : Args) : IO UInt32 := do
  let some txHex := a.get "--tx" | throw (IO.userError "sighash: --tx <hex|@file> is required")
  let txHex ← readArgFile txHex
  let txBytes ← match hexDecode txHex.trimAscii.toString with | some b => pure b | none => throw (IO.userError "sighash: --tx is not hex")
  let tx ← match decodeTx txBytes with | some t => pure t | none => throw (IO.userError "sighash: the transaction frame does not parse")
  let some scHex := a.get "--scriptcode" | throw (IO.userError "sighash: --scriptcode <hex> is required")
  let scriptCode ← match hexDecode scHex.trimAscii.toString with | some b => pure b | none => throw (IO.userError "sighash: --scriptcode is not hex")
  let raw ← match a.get "--type" with
    | some s => match parseNat s "--type" with | .ok n => pure n | .error e => throw (IO.userError e)
    | none => throw (IO.userError "sighash: --type <u32> is required (the raw hash type)")
  let nIn ← match a.get "--input" with
    | some s => match parseNat s "--input" with | .ok n => pure n | .error e => throw (IO.userError e)
    | none => pure 0
  let amount ← match a.get "--amount" with
    | some s => match parseNat s "--amount" with | .ok n => pure n | .error e => throw (IO.userError e)
    | none => pure 0
  if tx.inputs.length ≤ nIn then throw (IO.userError s!"sighash: --input {nIn}: the transaction has {tx.inputs.length} inputs")
  let forkid ← match (a.get "--forkid").getD "true" with
    | "true" => pure true | "false" => pure false
    | s => throw (IO.userError s!"sighash: --forkid {s}: true | false")
  IO.println (hexOf (BsvScript.Sighash.sighash scriptCode tx nIn { raw := raw } amount forkid))
  return 0

def usage : String :=
"bsvs: the executable BSV script semantics (bsv-script-lean, #14)
  bsvs eval --tx <hex|@file> --prevouts <json array|@file> [--spend-height <n>] [--consensus true|false]
            [--flags <u32|json array>] [--config sv|sv-regtest|teranode] [--input <i>] [--trace] [--pretty]
            [--genesis-height <n> --chronicle-height <n>]
  bsvs corpus <file.jsonl> [--out <file.jsonl>] [--config sv|sv-regtest|teranode] [--genesis-height <n> --chronicle-height <n>]
  bsvs sighash --tx <hex|@file> --scriptcode <hex> --type <u32> [--input <i>] [--amount <satoshis>] [--forkid true|false]
  bsvs --self-test [--root <repo>]
  bsvs --version"

/-- The options and switches each command takes (lean #32's second lens, B-8): anything else is refused with
exit 2, as the reference's RPC refuses an unexpected key (`rpc/misc.cpp:736–742`), and so is a `--key=value`
spelling and an unexpected positional. -/
def allowed (cmd : String) : List String × List String × Nat :=
  match cmd with
  | "eval" => (["--tx", "--prevouts", "--spend-height", "--consensus", "--flags", "--config", "--input", "--root", "--commit",
                "--genesis-height", "--chronicle-height"],
               ["--trace", "--pretty"], 1)
  | "corpus" => (["--out", "--config", "--root", "--commit", "--genesis-height", "--chronicle-height"], [], 2)
  | "sighash" => (["--tx", "--scriptcode", "--type", "--input", "--amount", "--forkid", "--root", "--commit"], [], 1)
  | _ => (["--root", "--commit"], [], 0)

def checkArgs (cmd : String) (isMode : Bool) (a : Args) : Except String Unit := do
  let (opts, sws, npos) := allowed cmd
  let modes := ["--self-test", "--version", "--help", "-h"]
  for (k, _) in a.opts do
    if k.contains '=' then throw s!"{k}: give the option and its value as two arguments"
    if !opts.contains k then throw s!"unknown option {k} for {if cmd.isEmpty then "bsvs" else cmd}"
  for s in a.switches do
    if s.contains '=' then throw s!"{s}: give the option and its value as two arguments"
    if !sws.contains s && !modes.contains s then throw s!"unknown switch, or an option without its value: {s}"
  -- a mode (`--version`, `--self-test`, `--help`) answers whatever command word stands beside it, as before
  -- the check (lean #32's re-lens, BN-8); its options are still the command's
  if !isMode && a.positional.length != npos then throw s!"unexpected arguments: {a.positional}"

/-- A commit as `git rev-parse --short` prints it: 7 to 40 lowercase hex digits. -/
def isAbbrev (c : String) : Bool :=
  7 ≤ c.length && c.length ≤ 40 && c.all (fun ch => ch.isDigit || ('a' ≤ ch && ch ≤ 'f'))

/-- The commit stamp's forms (the applied set's lens, Sol and Astra): what the wrapper `eval/bsvs` passes, a commit
(`isAbbrev`), that with `+dirty`, or `unknown`; anything else is refused with exit 2 and the value named, so no
verdict is stamped `spec@` with no commit. `harness/src/stamp.rs` reads the same forms back. -/
def checkCommit (c : String) : Except String Unit :=
  if isAbbrev c || c == "unknown" || (c.endsWith "+dirty" && isAbbrev (String.ofList (c.toList.take (c.length - 6))))
  then pure ()
  else throw s!"--commit {repr c}: none of the forms eval/bsvs emits (7 to 40 lowercase hex digits, that with +dirty, or unknown)"

/-- The CLI's own rows for `--self-test` (the applied set's lens): each rejection path `checkArgs`, `checkCommit`,
`parseNat` and `parseFlagsArg` add is taken once, and the forms they accept beside them. -/
def cliRows : List (String × Bool) :=
  let refused (x : Except String Unit) : Bool := match x with | .error _ => true | .ok () => false
  let args (l : List String) := checkArgs ((parseArgs l).positional.headD "") false (parseArgs l)
  let modeArgs (l : List String) := checkArgs ((parseArgs l).positional.headD "") true (parseArgs l)
  let nat (s : String) : Bool := match parseNat s "--x" with | .error _ => true | .ok _ => false
  let flags (s : String) : Bool := match parseFlagsArg s 1 with | .error _ => true | .ok _ => false
  [ ("checkArgs refuses an unknown option", refused (args ["eval", "--tx", "00", "--prevouts", "[]", "--bogus", "1"])),
    ("checkArgs refuses a --key=value spelling", refused (args ["eval", "--tx=00", "--prevouts", "[]"])),
    ("checkArgs refuses an unexpected positional", refused (args ["eval", "extra", "--tx", "00", "--prevouts", "[]"])),
    ("checkArgs refuses a switch the command does not take", refused (args ["corpus", "f.jsonl", "--trace"])),
    ("checkArgs reads an eval line with its switches", !refused (args ["eval", "--tx", "00", "--prevouts", "[]", "--trace", "--pretty"])),
    ("checkArgs lets a mode answer beside a command word", !refused (modeArgs ["sighash", "extra", "--version"])),
    ("checkCommit reads a commit, +dirty and unknown",
      ["8e449b5", "8e449b5c0ffee", "8e449b5+dirty", "unknown"].all (fun c => !refused (checkCommit c))),
    ("checkCommit refuses an empty, spaced or arbitrary stamp",
      ["", " ", "8e44 9b5", "8E449B5", "8e449b", "+dirty", "HEAD", "unknown+dirty", "spec@8e449b5"].all (fun c => refused (checkCommit c))),
    ("parseNat refuses an empty, signed or bare-0x number", nat "" && nat "-1" && nat "0x" && !nat "0x1f" && !nat "31"),
    ("parseFlagsArg refuses a word of 33 bits, bare and in an array",
      flags "4294967296" && flags "[4294967296]" && !flags "4294967295" && !flags "[1]"),
    ("checkArgs reads the two activation heights on eval and on corpus",
      !refused (args ["corpus", "f.jsonl", "--genesis-height", "1", "--chronicle-height", "103"]) &&
      !refused (args ["eval", "--tx", "00", "--prevouts", "[]", "--genesis-height", "102", "--chronicle-height", "102"])),
    ("withHeights takes both heights, names them, and refuses one alone or a zero",
      let hs (l : List String) : Except String (NodeConfig × String) := withHeights (parseArgs l) NodeConfig.svMainnetDefault "sv-regtest"
      (match hs ["--genesis-height", "1", "--chronicle-height", "103"] with
        | .ok (c, n) => c.genesisActivationHeight == 1 && c.chronicleActivationHeight == 103 && n == "sv-regtest(genesis=1,chronicle=103)"
        | .error _ => false) &&
      (match hs [] with | .ok (c, n) => c.genesisActivationHeight == 620538 && n == "sv-regtest" | .error _ => false) &&
      (match hs ["--genesis-height", "1"] with | .error _ => true | .ok _ => false) &&
      (match hs ["--genesis-height", "0", "--chronicle-height", "1"] with | .error _ => true | .ok _ => false)),
    ("configOf sv-regtest is the regtest chain's heights under the mainnet default's policy",
      match configOf "sv-regtest" with
        | .ok (c, n) => n == "sv-regtest" && c.chain.p2shHeight == 1 && c.chain.uahfHeight == 0 && c.genesisActivationHeight == 10000
                        && c.chronicleActivationHeight == 15000 && c.maxScriptNumLengthPolicy == NodeConfig.svMainnetDefault.maxScriptNumLengthPolicy
        | .error _ => false) ]

def main (args : List String) : IO UInt32 := do
  let a := parseArgs args
  let isMode := a.has "--version" || a.has "--self-test" || a.has "--help" || a.has "-h"
  let cmd := a.positional.headD ""
  if let .error e := checkArgs cmd isMode a then
    IO.eprintln s!"bsvs: {e}"
    IO.eprintln usage
    return 2
  if let some c := a.get "--commit" then
    if let .error e := checkCommit c then
      IO.eprintln s!"bsvs: {e}"
      return 2
  let commit := (a.get "--commit").getD "unknown"
  let root := (a.get "--root").getD "."
  if a.has "--version" then
    IO.println s!"bsvs spec@{commit} (bitcoin-sv v1.2.3 6504a3af; lean/Bsvs, #14)"
    return 0
  if a.has "--self-test" then
    return (← Bsvs.SelfTest.run root cfgSv cliRows)
  if a.has "--help" || a.has "-h" then
    IO.println usage
    return 0
  match a.positional with
  | "eval" :: _ => evalCmd a commit
  | "corpus" :: rest => corpusCmd { a with positional := rest } commit
  | "sighash" :: _ => sighashCmd a
  | _ =>
    IO.eprintln usage
    return 2
where
  cfgSv := NodeConfig.svMainnetDefault

end Bsvs.Cli

def main (args : List String) : IO UInt32 := Bsvs.Cli.main args
