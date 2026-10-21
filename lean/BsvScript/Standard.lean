import BsvScript.Eval
import BsvScript.Flags
import BsvScript.SigOps
import BsvScript.TxRules
/-!
# BsvScript.Standard

The node's standardness tests: the policy half of the mempool gate that D123's road found missing
(`tx.gate.standardness.unmodelled`, the parent's `**Finding.**` on #27, 5860811662, and its class in
`harness/rules/sv-node.json`, 2026-09-28). Each definition is one function of
bitcoin-sv at the pin (`docs/PROVENANCE.md`), read line by line:

* `solver`: `Solver` (`script/standard.cpp:40–199`), the output types. P2SH is a type before Genesis only
  (`72–83`). A data carrier is `OP_RETURN` before Genesis or `OP_FALSE OP_RETURN` in both eras, followed by
  pushes only (`85–105`). Otherwise the three templates are tried in the order the map holds them (`47–65`;
  `txnouttype`'s order, `script/standard.h:73–82`), each walked by `matchTemplate` (`108–194`), and a
  multisig must carry minimal counts that agree with its keys (`124–139`).
* `isStandardOutput`: `IsStandardOutput` (`353–374`): multisig up to x-of-3 (`360–366`); a data carrier
  only when `-datacarrier` is on (`367–371`).
* `isDust`: `CTxOut::IsDust` (`primitives/transaction.h:203–213`): a threshold of 1 satoshi per output, none
  for a provably unspendable script (`CScript::IsUnspendable`, `script/script.h:260–277`).
* `isStandardTx`: `IsStandardTx` (`standard.cpp:427–500`) with its first reason. Before Chronicle the
  version (`431–439`); the size (`445–449`); before Genesis the size of each unlocking script (`458–461`);
  before Chronicle its push-only form (`462–465`); then the outputs (`468–485`: bare multisig and dust
  refuse at once, a non-standard type is noted and reported last), the data carrier's total (`487–491`),
  and the noted type (`493–497`).
* `isInputStandard`, `areInputsStandard`: `IsInputStandard` (`standard.cpp:376–425`) over every input
  (`AreInputsStandard`, `policy/policy.cpp:166–198`). The coin's locking script must solve in the coin's era
  (`coins.h:318–325`). For a P2SH coin the redeem script, read by running the unlocking script with no flags
  (`policy.cpp:178–180`) and the base checker (`interpreter.h:52–72`), must count at most `MAX_P2SH_SIGOPS`
  = 15 accurately (`standard.h:27`).

Where these refuse is the mempool gate's (`BsvScript.TxPolicy.standardnessRefusal`, `validation.cpp:1072–1088`
and `validation.cpp:1206–1223`), under `NodeConfig`'s `requireStandard` and `acceptNonStandardOutput`. The three settings the
tests read are `NodeConfig` fields with their defaults and sources (`dataCarrier`, `dataCarrierSize`,
`permitBareMultisig`; CLAUDE.md rule 1).

Bare line numbers are `src/script/standard.cpp` at the pin.
-/

namespace BsvScript.Standard
open BsvScript.Params BsvScript.Machine BsvScript.Numbers BsvScript.Tx

/-! ## The output types (`Solver`, `40–199`) -/

/-- `txnouttype` (`script/standard.h:73–82`), in its declared order. -/
inductive OutType where
  | nonstandard | pubkey | pubkeyhash | scripthash | multisig | nullData
  deriving DecidableEq, Repr

/-- The template matcher's pseudo-opcodes (`script/opcodes.h:155–158`). -/
def OP_SMALLINTEGER : Nat := 0xfa
def OP_PUBKEYS : Nat := 0xfb
def OP_PUBKEYHASH : Nat := 0xfd
def OP_PUBKEY : Nat := 0xfe

/-- The three templates (`49–64`), each a script of single opcodes. -/
def tmplPubKey : List Nat := [OP_PUBKEY, Op.OP_CHECKSIG]
/-- The P2PKH template (`standard.cpp:55`).
[LIT] https://protocol.bsvblockchain.org/concepts/transaction-templates#transaction-template-example-payment-to-public-key-hash at v1.2.2.
[LIT] https://protocol.bsvblockchain.org/implementation-notes/light-clients-and-spv#proof-of-integrity at v1.2.2. -/
def tmplPubKeyHash : List Nat := [Op.OP_DUP, Op.OP_HASH160, OP_PUBKEYHASH, Op.OP_EQUALVERIFY, Op.OP_CHECKSIG]
def tmplMultisig : List Nat := [OP_SMALLINTEGER, OP_PUBKEYS, OP_SMALLINTEGER, Op.OP_CHECKMULTISIG]

/-- `CScript::GetOp` as the matcher reads it (`script/script.h:165–200`): the opcode, its push data and the
rest of the script, or `none` when the script is exhausted or the push is truncated. -/
def getOp : Bytes → Option (Nat × Bytes × Bytes)
  | [] => none
  | op :: rest =>
    match getOpTail op rest with
    | none => none
    | some (data, k) => some (op, data, rest.drop k)

/-- The `OP_PUBKEYS` loop (`150–156`): while the current push is 33 to 65 bytes it is a key and the next
instruction is read. A failed read ends the loop with `OP_INVALIDOPCODE` and no data (`script/script.h:167–169`).
Returns the current instruction, the rest of the script and the solutions with the keys appended; the fuel
is the script's length. -/
def pubkeysLoop : Nat → Nat → Bytes → Bytes → List Bytes → Nat × Bytes × Bytes × List Bytes
  | 0, op1, v1, s1, sols => (op1, v1, s1, sols)
  | fuel + 1, op1, v1, s1, sols =>
    if 33 ≤ v1.length ∧ v1.length ≤ 65 then
      match getOp s1 with
      | none => (Op.OP_INVALIDOPCODE, [], s1, sols ++ [v1])
      | some (o, v, r) => pubkeysLoop fuel o v r (sols ++ [v1])
    else (op1, v1, s1, sols)

/-- One template opcode against the current instruction (`164–192`): a key of 33 to 65 bytes, a key hash of
20, a small integer (`OP_0`, or after Genesis any push of at most 4 bytes, `176–182`; or `OP_1` to `OP_16`, its
value, `183–185`), else the same opcode with no data (`189–192`). The solutions extended, or `none` for a
mismatch (`break`). -/
def matchOne (genesis : Bool) (op1 : Nat) (v1 : Bytes) (op2 : Nat) (sols : List Bytes) : Option (List Bytes) :=
  if op2 = OP_PUBKEY then
    if 33 ≤ v1.length ∧ v1.length ≤ 65 then some (sols ++ [v1]) else none
  else if op2 = OP_PUBKEYHASH then
    if v1.length = 20 then some (sols ++ [v1]) else none
  else if op2 = OP_SMALLINTEGER then
    if op1 = Op.OP_0 ∨ (genesis = true ∧ v1 ≠ []) then
      if 4 < v1.length then none else some (sols ++ [v1])
    else if Op.OP_1 ≤ op1 ∧ op1 ≤ Op.OP_16 then some (sols ++ [[op1 - (Op.OP_1 - 1)]])
    else none
  else if op1 ≠ op2 ∨ v1 ≠ [] then none
  else some sols

/-- The walk of one template (`117–193`): both scripts at their end is a match (`121–141`); a failed read of
either is a mismatch (`142–147`); after `OP_PUBKEYS` the key loop runs, the template's next opcode is read and
the chain continues with it (`150–162`). The solutions of a match, or `none`; the fuel is the script's length
plus one (every step consumes an instruction). -/
def matchTemplate (genesis : Bool) : Nat → Bytes → List Nat → List Bytes → Option (List Bytes)
  | 0, _, _, _ => none
  | fuel + 1, s1, t, sols =>
    if s1.isEmpty && t.isEmpty then some sols
    else
      match getOp s1 with
      | none => none
      | some (op1, v1, s1') =>
        match t with
        | [] => none
        | op2 :: t' =>
          if op2 = OP_PUBKEYS then
            match pubkeysLoop (s1'.length + 1) op1 v1 s1' sols with
            | (o, v, r, ss) =>
              match t' with
              | [] => none
              | op2' :: t'' =>
                match matchOne genesis o v op2' ss with
                | none => none
                | some ss' => matchTemplate genesis fuel r t'' ss'
          else
            match matchOne genesis op1 v1 op2 sols with
            | none => none
            | some ss' => matchTemplate genesis fuel s1' t' ss'

/-- The multisig's checks on a match (`124–139`): both counts minimally encoded in at most 4 bytes, else no
type at all (`127–131`); `m` and `n` at least 1, `m ≤ n`, and exactly `n` keys between them (`133–138`),
else the type with no solution. -/
def multisigCheck (sols : List Bytes) : OutType × Bool × List Bytes :=
  let front := sols.headD []
  let back := sols.getLastD []
  if !(isMinimallyEncoded front 4) || !(isMinimallyEncoded back 4) then (.nonstandard, false, [])
  else
    let m := decode front
    let n := decode back
    if m < 1 ∨ n < 1 ∨ n < m ∨ sols.length < 2 ∨ sols.length - 2 ≠ n.toNat then (.multisig, false, sols)
    else (.multisig, true, sols)

/-- The templates in the map's order (`110–194`), then no type (`196–198`). -/
def solveTemplates (genesis : Bool) (s : Bytes) : OutType × Bool × List Bytes :=
  match matchTemplate genesis (s.length + 1) s tmplPubKey [] with
  | some sols => (.pubkey, true, sols)
  | none =>
    match matchTemplate genesis (s.length + 1) s tmplPubKeyHash [] with
    | some sols => (.pubkeyhash, true, sols)
    | none =>
      match matchTemplate genesis (s.length + 1) s tmplMultisig [] with
      | some sols => multisigCheck sols
      | none => (.nonstandard, false, [])

/-- `Solver(scriptPubKey, era, typeRet, vSolutionsRet)` (`40–199`): the type, whether the script solves, and
the solutions (read by `isStandardOutput` for the multisig's counts). P2SH first (`72–83`: no type after
Genesis), then the data carrier (`85–105`: `OP_RETURN` before Genesis, `OP_FALSE OP_RETURN` in both eras,
pushes only after it, `CScript::IsPushOnly(pc)`, `script.cpp:209–220`), then the templates. `genesis` is the
era's Genesis. -/
def solver (genesis : Bool) (s : Bytes) : OutType × Bool × List Bytes :=
  if isP2SH s then
    if genesis then (.nonstandard, false, []) else (.scripthash, true, [(s.drop 2).take 20])
  else
    let off : Option Nat :=
      if !genesis && s.head? = some Op.OP_RETURN then some 1
      else if s.head? = some Op.OP_FALSE && s[1]? = some Op.OP_RETURN then some 2
      else none
    match off with
    | some k => if isPushOnly (s.drop k) then (.nullData, true, []) else solveTemplates genesis s
    | none => solveTemplates genesis s

/-! ## Outputs (`IsStandardOutput`, `353–374`; `CTxOut::IsDust`) -/

/-- `IsStandardOutput(scriptPolicy, scriptPubKey, nHeight, whichType)` (`353–374`): the type `Solver` gives
and whether the output is standard. A multisig is standard up to x-of-3 (`360–366`); a data carrier only
under `-datacarrier` (`367–371`); no type is not standard (`373`). -/
def isStandardOutput (cfg : NodeConfig) (genesis : Bool) (s : Bytes) : OutType × Bool :=
  match solver genesis s with
  | (t, false, _) => (t, false)
  | (t, true, sols) =>
    if t = .multisig then
      let m := decode (sols.headD [])
      let n := decode (sols.getLastD [])
      if n < 1 ∨ 3 < n then (t, false) else if m < 1 ∨ n < m then (t, false) else (t, true)
    else if t = .nullData then (t, cfg.dataCarrier)
    else (t, t ≠ .nonstandard)

/-- `CScript::IsUnspendable(era)` (`script/script.h:260–277`): after Genesis only `OP_FALSE OP_RETURN`
(`script/script.h:262–270`); before it also a leading `OP_RETURN` and a script above `MAX_SCRIPT_SIZE_BEFORE_GENESIS`
(`script/script.h:271–276`). -/
def isUnspendable (genesis : Bool) (s : Bytes) : Bool :=
  let falseReturn := s.head? = some Op.OP_FALSE && s[1]? = some Op.OP_RETURN
  if genesis then falseReturn
  else s.head? = some Op.OP_RETURN || falseReturn || decide (Consensus.maxScriptSizeBeforeGenesis < s.length)

/-- `CTxOut::IsDust(era)` (`primitives/transaction.h:211–213`): the value below the threshold, which is
1 satoshi, or none for a provably unspendable script (`:203–209`, "hardcoded to 1 satoshi per output"). -/
def isDust (genesis : Bool) (o : TxOut) : Bool :=
  decide (o.value < if isUnspendable genesis o.scriptPubKey then 0 else 1)

/-! ## The transaction (`IsStandardTx`, `427–500`) -/

/-- `IsStandardTx`'s reasons, in the node's words (`436`, `447`, `459`, `463`, `479`, `482`, `489`, `495`). -/
inductive NonStandard where
  | version | txSize | scriptSigSize | scriptSigNotPushOnly | bareMultisig | dust | dataCarrierSize | scriptPubKey
  deriving DecidableEq, Repr

/-- The reason string (the reject reason `validation.cpp:1086` reports). -/
def NonStandard.code : NonStandard → String
  | .version => "version"
  | .txSize => "tx-size"
  | .scriptSigSize => "scriptsig-size"
  | .scriptSigNotPushOnly => "scriptsig-not-pushonly"
  | .bareMultisig => "bare-multisig"
  | .dust => "dust"
  | .dataCarrierSize => "datacarrier-size-exceeded"
  | .scriptPubKey => "scriptpubkey"

/-- `CTransaction::PRE_CHRONICLE_MIN_STANDARD_VERSION` (`primitives/transaction.h:264`). -/
def PRE_CHRONICLE_MIN_STANDARD_VERSION : Int := 1
/-- `CTransaction::PRE_CHRONICLE_MAX_STANDARD_VERSION` (`primitives/transaction.h:265`). -/
def PRE_CHRONICLE_MAX_STANDARD_VERSION : Int := 2
/-- The largest standard unlocking script before Genesis (`458`, the literal 1650: "a 15-of-15 P2SH multisig
with compressed keys ... which we round off to 1650 bytes", `452–457`). -/
def MAX_SCRIPTSIG_SIZE_BEFORE_GENESIS : Nat := 1650
/-- `MAX_P2SH_SIGOPS` (`script/standard.h:27`). -/
def MAX_P2SH_SIGOPS : Nat := 15

/-- The unlocking scripts in order (`451–466`): before Genesis a size above 1650 bytes (`458–461`), before
Chronicle a script that is not push-only (`462–465`). -/
def inputsReason (genesis chronicle : Bool) : List TxIn → Option NonStandard
  | [] => none
  | i :: is =>
    if !genesis && decide (MAX_SCRIPTSIG_SIZE_BEFORE_GENESIS < i.scriptSig.length) then some .scriptSigSize
    else if !chronicle && !isPushOnly i.scriptSig then some .scriptSigNotPushOnly
    else inputsReason genesis chronicle is

/-- The outputs in order (`468–485`), carrying the data carrier's total and whether some type was not
standard: a data carrier adds its script's size (`476–477`); otherwise a multisig refuses `bare-multisig`
unless `-permitbaremultisig` (`478–480`), and dust refuses `dust` (`481–483`). -/
def outputsScan (cfg : NodeConfig) (genesis : Bool) : List TxOut → Nat → Bool → Except NonStandard (Nat × Bool)
  | [], d, spk => .ok (d, spk)
  | o :: os, d, spk =>
    match isStandardOutput cfg genesis o.scriptPubKey with
    | (t, std) =>
      if t = .nullData then outputsScan cfg genesis os (d + o.scriptPubKey.length) (spk || !std)
      else if t = .multisig && !cfg.permitBareMultisig then .error .bareMultisig
      else if isDust genesis o then .error .dust
      else outputsScan cfg genesis os d (spk || !std)

/-- `IsStandardTx(scriptPolicy, tx, nHeight, reason)` (`427–500`) for the era `genesis`, `chronicle` of the
spend's height (`429`; the mempool's height, `validation.cpp:1073`), with the node's size cap `sizeCap`
(`GetMaxTxSize(era, false)`, `446`; `TxPolicy.sizeCap`). `none` is standard; else the first reason. -/
def isStandardTx (cfg : NodeConfig) (genesis chronicle : Bool) (sizeCap : Nat) (tx : Tx) : Option NonStandard :=
  if !chronicle && (decide (PRE_CHRONICLE_MAX_STANDARD_VERSION < tx.version) || decide (tx.version < PRE_CHRONICLE_MIN_STANDARD_VERSION)) then
    some .version
  else if sizeCap < (Sighash.serTx tx).length then some .txSize
  else
    match inputsReason genesis chronicle tx.inputs with
    | some r => some r
    | none =>
      match outputsScan cfg genesis tx.outputs 0 false with
      | .error r => some r
      | .ok (d, spk) =>
        if cfg.dataCarrierSize < d then some .dataCarrierSize
        else if spk then some .scriptPubKey
        else none

/-! ## The inputs (`IsInputStandard`, `376–425`; `AreInputsStandard`, `policy.cpp:166–198`) -/

/-- The parameters `AreInputsStandard` runs an unlocking script under (`policy.cpp:178–180`:
`make_eval_script_params(scriptPolicy, SCRIPT_VERIFY_NONE, false)`, so the pre-Genesis limits of a word with no
UTXO bit), with the stack's own budget `UINT32_MAX` (`394`: "LimitedStack stack(UINT32_MAX)"). -/
def inputEvalParams : EvalParams :=
  { flags := Flags.none, limits := { preGenesisLimits with maxStackMemoryUsage := 4294967295 } }

/-- `BaseSignatureChecker` (`interpreter.h:52–72`): every check false, the version 0. -/
def baseChecker : Context :=
  { version := 0, checkLockTime := fun _ => false, checkSequence := fun _ => false,
    checkSig := fun _ _ _ _ => false }

/-- `IsInputStandard(token, params, scriptSig, prevScript, utxoEra, flags)` (`376–425`): the coin's locking
script solves in the coin's era (`388–390`); for a P2SH coin, the unlocking script run with no flags leaves a
redeem script on top (`392–416`: an error or an empty stack is not standard) whose accurate count
(`GetSigOpCount(true, PreGenesis, …)`, `417–418`) is at most 15 without error (`419–421`). An outcome of the
spec's evaluator that is not the reference's (`undefinedInReference`) is read as not standard. -/
def isInputStandard (scriptSig prevScript : Bytes) (utxoGenesis : Bool) : Bool :=
  match solver utxoGenesis prevScript with
  | (_, false, _) => false
  | (t, true, _) =>
    if t = .scripthash then
      match evalScript Eval.opExec (mkEnv inputEvalParams baseChecker Flags.none none) scriptSig [] 0 with
      | (.ok, st) =>
        match st.stack with
        | [] => false
        | redeem :: _ =>
          match SigOps.sigOpCount true false redeem with
          | none => false
          | some n => decide (n ≤ MAX_P2SH_SIGOPS)
      | _ => false
    else true

/-- `Coin::GetProtocolEra(config, miningHeight)` (`coins.h:318–325`): a coin still in the mempool
(`MEMPOOL_HEIGHT`) takes the mining height's era. -/
def coinEraHeight (coinHeight miningHeight : Nat) : Nat :=
  if coinHeight = mempoolHeight then miningHeight else coinHeight

/-- `AreInputsStandard(token, scriptPolicy, tx, mapInputs, mempoolHeight)` (`policy.cpp:166–198`): a coinbase
is standard (`policy.cpp:173–176`); else every input with its coin (`coins`, each spent output's locking script and
height, aligned with the inputs, `policy.cpp:182–195`) passes `IsInputStandard` in the coin's era (`policy.cpp:189`). -/
def areInputsStandard (cfg : NodeConfig) (spendHeight : Nat) (tx : Tx) (coins : List (Bytes × Nat)) : Bool :=
  if TxRules.isCoinBase tx then true
  else (tx.inputs.zip coins).all fun ic =>
    isInputStandard ic.1.scriptSig ic.2.1 (cfg.protocolEra (coinEraHeight ic.2.2 spendHeight)).genesisActive

end BsvScript.Standard

namespace BsvScript.Standard
open BsvScript.Params BsvScript.Machine BsvScript.Numbers BsvScript.Tx

/-! ## Properties -/

/-- **T-ST1.** *What it says:* the P2SH shape is its own type before Genesis and no type after it, whatever
its hash. *What it assumes:* the shape (`isP2SH`). *Why it matters:* a coin is solved in its own era
(`388–390`), so a P2SH coin created before Genesis keeps its type when it is spent after it. An output of the
shape never meets the post-Genesis half (`72–75`) as a `scriptpubkey` reason: after Genesis consensus refuses
it at every node configuration (`validation.cpp:609–622`, `bad-txns-vout-p2sh`; the spec's `.p2shOutput` in
`TxRules.checkRegularTransaction`), and the mempool checks that (`validation.cpp:1035`) before `IsStandardTx` (`validation.cpp:1073`). -/
theorem solver_p2sh (s : Bytes) (h : isP2SH s = true) :
    (solver false s).1 = .scripthash ∧ (solver true s).1 = .nonstandard ∧ (solver true s).2.1 = false := by
  simp [solver, h]

/-- **T-ST2.** *What it says:* the locking script `OP_TRUE` (`OP_1`) has no type in either era. *What it
assumes:* nothing. *Why it matters:* it is the corpus's usual output and coin (`corpus/tx`: `tx-00032`,
`tx-00037`), and with no type it makes every transaction that creates it non-standard and every input spending
it non-standard (`388–390`). `IsStandardTx` reports its first reason, so `scriptpubkey` (`493–497`) only
when no earlier one is met (the version, the size, the unlocking scripts, an output's `bare-multisig` or
`dust`, the data carrier's total, `431–491`): a zero-value `OP_TRUE` output is reported `dust`
(`TxPolicy.standardnessRefusal_preGenesis_witnesses`, T-STD7). -/
theorem solver_opTrue (g : Bool) : solver g [Op.OP_1] = (.nonstandard, false, []) := by
  cases g <;> decide

/-- **T-ST3.** *What it says:* an output is dust exactly when its value is 0 and its script is not provably
unspendable in the era. *What it assumes:* nothing. *Why it matters:* the threshold is hard-coded to one
satoshi (`primitives/transaction.h:204`), so no setting moves it; a zero-value `OP_FALSE OP_RETURN` carrier is
never dust, and before Genesis neither is a leading `OP_RETURN`. -/
theorem isDust_iff (g : Bool) (o : TxOut) :
    isDust g o = true ↔ o.value = 0 ∧ isUnspendable g o.scriptPubKey = false := by
  unfold isDust
  cases h : isUnspendable g o.scriptPubKey <;> simp

/-- **T-ST4.** *What it says:* after Chronicle the unlocking scripts give no reason: neither their size nor
their form is tested. *What it assumes:* both markers on (a post-Chronicle era is post-Genesis). *Why it
matters:* after Chronicle `IsStandardTx` reads only the version-free size, the outputs and the data carrier
(`431`, `458`, `462`), so the script corpora's post-Chronicle entries meet little of it. -/
theorem inputsReason_postChronicle (ins : List TxIn) : inputsReason true true ins = none := by
  induction ins with
  | nil => rfl
  | cons i is ih => simp [inputsReason, ih]

/-- **T-ST5.** *What it says:* inputs whose unlocking scripts are all empty give no reason in any era.
*What it assumes:* every unlocking script empty. *Why it matters:* an empty script is push-only
(`script.cpp:209–220`, `isPushOnly []`) and short, so a witness with empty unlocking scripts is decided by its
version, size and outputs alone. -/
theorem inputsReason_empty (g c : Bool) (ins : List TxIn) (h : ∀ i ∈ ins, i.scriptSig = []) :
    inputsReason g c ins = none := by
  induction ins with
  | nil => rfl
  | cons i is ih =>
    have hi : i.scriptSig = [] := h i (List.mem_cons_self ..)
    have hr : ∀ j ∈ is, j.scriptSig = [] := fun j hj => h j (List.mem_cons_of_mem _ hj)
    simp only [inputsReason, hi, List.length_nil, isPushOnly.eq_1]
    simp [MAX_SCRIPTSIG_SIZE_BEFORE_GENESIS, ih hr]

end BsvScript.Standard
