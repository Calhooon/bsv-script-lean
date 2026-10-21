import BsvScript.Eval
import BsvScript.Ops.Crypto
import BsvScript.Properties.Basic
/-!
# BsvScript.Properties.VersionGate

The version-1 branch (#19; `docs/DESIGN.md` §5.3): the four restrictions the
issue names, MINIMALDATA, CLEANSTACK, SIGPUSHONLY and LOW_S, at every site the
reference reads them, the branch-selection parameter they hang on, and the
theorems of both branches (the gate ON: the restriction binds as the word says;
the gate OFF: the bit is never consulted). Every `[SRC]` is bitcoin-sv v1.2.3 at
`6504a3af` (`docs/PROVENANCE.md`); a bare number is a line of
`src/script/interpreter.cpp`.

## The branch-selection parameter, verified at the pin

`checker.Version()` is `txTo_->nVersion` (`2254–2257`), the spending
transaction's `nVersion`, an `int32_t` (`src/primitives/transaction.h:273`;
read as `Tx.version` through `Tx.toInt32`, so a negative version is a negative
`Int`). `IsMalleableTxnVersion(v) = v > 1` (`34–38`);
`EnforceNonMalleability(flags, v) = !(IsChronicle(flags) && v > 1)` (`40–44`;
the four `static_assert`s of `46–49` are decided in `Params.lean`). So the
branch is: **the gate is ON** (the seven restrictions bind exactly as the flag
word says) when the word lacks `SCRIPT_CHRONICLE` (a pre-Chronicle spend era:
`verify_script_flags.cpp:77–78` on the block path, `policy.h:195–197, 212–215`
on the mempool path) or the version is at most 1, a negative version included;
**OFF** for a version above 1 in a word with `SCRIPT_CHRONICLE`. The UTXO's era
never selects the branch (`411–427` read the UTXO markers for the era rules
only). The sites that read the gate at the pin: seven `EnforceNonMalleability`
reads, `285` (LOW_S), `433` (MINIMALDATA), `801` (MINIMALIF), `1493` and `1643`
(NULLFAIL), `1666` (NULLDUMMY), `2441` (CLEANSTACK), plus one inlined read of
`IsMalleableTxnVersion` under `IsChronicle` at `2327` (SIGPUSHONLY): an
exhaustive grep of the file for `EnforceNonMalleability` returns exactly the seven,
and a grep for `IsMalleableTxnVersion` and `checker.Version()` adds `2327` and the
two version pushes of `OP_VER`/`OP_VERIF` (`603`, `810–811`), which are not gates. In the Lean the gate is
`Params.enforceNonMalleability`, applied once to the word (`Flags.gate`, in
`Machine.mkEnv` and `Machine.verifyScript`) and re-read at the crypto sites as
the reference does (`enforceNonMalleability_gate`: the second read is the
first).

## The audit: every read of the four flags at the pin, and its Lean

| flag (bit) | where the word gets it (its kind) | read at | the Lean |
|---|---|---|---|
| `SCRIPT_VERIFY_LOW_S` (3) | the block word from `daaHeight` (`verify_script_flags.cpp:65–67`); mandatory (`standard.h:60, 67`): **consensus by height** | `275–280`: with DERSIG and STRICTENC, the strict DER shape (`IsValidSignatureEncoding`, `177–245`), ungated | `Env.strictDer` (`Flags.strictDer` of the FORKID-adjusted word), `Ops.Crypto.checkSignatureEncoding` |
| | | `282–287`: `CPubKey::CheckLowS` on the signature without its hash-type byte; the error `SCRIPT_ERR_SIG_HIGH_S` only when the gate is on | `checkSignatureEncoding`: `f.lowS && !checkLowS (sig.dropLast) && enforceNonMalleability f version` on the gated word |
| | | `pubkey.cpp:353–363` `CheckLowS`: the lax parse (`32–175`), then `!secp256k1_ecdsa_signature_normalize`; a signature that does not lax-parse fails the check; an `r` or `s` above 32 bytes or at or above `n` is the zero signature (`146–173`), which is low, so the check passes and the signature then fails verification (`docs/DESIGN.md` §4.1) | `Crypto.Secp256k1.checkLowS`, `parseDerLax`, `isHighS` |
| | | the callers: `1459` (`OP_CHECKSIG`/`OP_CHECKSIGVERIFY`, every signature), `1605` (`OP_CHECKMULTISIG`/`VERIFY`, every signature tried) | `Ops.Crypto.checkSigOp`, `multisigLoop` |
| `SCRIPT_VERIFY_MINIMALDATA` (6) | the standard set only (`policy.h:189`): **policy**, in no block word (`blockScriptFlags_policy_off`) | `433–434`: `requireMinimal` = the flag under the gate, computed once per `EvalScript` call (so once per script: the unlocking script, the locking script, the P2SH redeem script) | `Machine.mkEnv` (`Env.requireMinimal`), `mkEnv_requireMinimal` |
| | | `475`: `CheckMinimalPush` (`331–358`) on every EXECUTED push (`473`: under `fExec`; a push in a dead branch, or after a non-top-level `OP_RETURN`, is never checked; the bytes after a top-level `OP_RETURN` are never parsed, `858–861`) | `Machine.execStep`, `checkMinimalPush`, `execStep_minimaldata` |
| | | every `CScriptNum` constructed with `requireMinimal` (`script_num.cpp:53–91`: the width first, `:62–65`, then `IsMinimallyEncoded`, `:67–70`, `int_serialization.h:120–152`): `546` CLTV and `577` CSV (width 5, pre-Genesis UTXOs); `622`, `624`, `655`, `680` `OP_SUBSTR`/`OP_LEFT`/`OP_RIGHT`; `709`, `717`, `745`, `753` `OP_LSHIFTNUM`/`OP_RSHIFTNUM`; `1015` `OP_PICK`/`OP_ROLL`; `1129`, `1163` `OP_LSHIFT`/`OP_RSHIFT`; `1235` the unary family; `1300–1301` the binary family; `1386–1390` `OP_WITHIN`; `1524`, `1551` the `OP_CHECKMULTISIG` counts (width 4); `1717` `OP_SPLIT`; `1747` `OP_NUM2BIN` | `Numbers.isMinimallyEncoded`, `readNum`; `Machine.execCltv`/`execCsv`, `Ops.Expansion.readInt64Operand`, `lshiftnum`, `rshiftnum`, `Ops.Stack.execStack`, `Ops.Bitwise.shift`, `Ops.Arith.readOperand` (`unary`, `binary`, `within`), `Ops.Crypto.readCount`, `Ops.Splice.split`, `num2binOp`; `readOperand_minencode`, `readNum_minencode` |
| | | NOT read by: `OP_BIN2NUM` (`1786–1790`: the result's `IsMinimallyEncoded` against the width, always, `SCRIPT_ERR_INVALID_NUMBER_RANGE`), `OP_IF`/`OP_NOTIF` (`CastToBool`, `815`; MINIMALIF is its own flag, never set at the pin), `OP_EQUAL`, the hashes, `OP_SIZE`, `OP_DEPTH`, `OP_CAT`, the stack moves | `Ops.Splice.bin2num`, `Machine.execIf` |
| `SCRIPT_VERIFY_CLEANSTACK` (8) | the standard set only (`policy.h:188`): **policy** | `2430–2448`, after the final-stack rule (`2374–2378`) and the P2SH evaluation (`2380–2424`): without P2SH the word is invalid (`2432–2435`, ungated); under the gate the MAIN stack must hold exactly one element (`2441–2445`; the alt stack died with `EvalScript`, `1993–2005`; after P2SH it is the restored stack the redeem script ran on, `2405–2416`) | `Machine.phase2` (`Flags.cleanStackDemand`, then `flags.cleanStack && stF.stack.length != 1`); `verifyScript_cleanstack_without_p2sh`, `phase2_cleanstack` |
| `SCRIPT_VERIFY_SIGPUSHONLY` (5) | the block word when Genesis is active (`verify_script_flags.cpp:71–75`); the per-input word (`policy.h:229–232`): **consensus by height** (Genesis) | `2321–2334`: under the flag, with Genesis-without-Chronicle, or Chronicle with a non-malleable version (`IsMalleableTxnVersion` at `2327`), `CScript::IsPushOnly` (`script.cpp:209–220`: every instruction parses and no opcode is above `OP_16`; `OP_RESERVED` counts as a push, `209–213`; a truncated push fails the parse) | `Machine.verifyScript` (`pushOnlyRequired`), `isPushOnly`; `verifyScript_sigpushonly` |
| | | `2385–2387`: the P2SH path demands a push-only unlocking script whatever the flag and the version (a pre-Genesis UTXO with the P2SH shape) | `Machine.phase2` |

The other three gated restrictions are #11's (NULLFAIL `1491–1497`, `1641–1647`;
NULLDUMMY `1664–1670`) and #8's (MINIMALIF `796–804`);
`Properties.Basic.gate_noninterference` covers all seven when the gate is off.

## What the theorems below say

* the gate: `enforceNonMalleability_iff` (ON iff no CHRONICLE or version ≤ 1),
  `Flags.gate_of_on` (the word is read as given), `enforceNonMalleability_gate`
  and `Flags.gate_gate` (gating twice is gating once);
* MINIMALDATA: `mkEnv_requireMinimal` (`433` as an equation),
  `execStep_minimaldata` and `execStep_push_of_not_requireMinimal` (`475`),
  `readNum_minencode`/`readOperand_minencode` and their relaxed twins (every
  number read);
* LOW_S: `checkSignatureEncoding_highS` (`282–287` with the gate on),
  `checkSignatureEncoding_ne_highS` (the error is unreachable when the gated
  bit is clear);
* SIGPUSHONLY: `verifyScript_sigpushonly` (`2321–2334` with the gate on);
* CLEANSTACK: `verifyScript_cleanstack_without_p2sh` (`2432–2435`, every
  version), `phase2_cleanstack` (`2441–2445` with the gate on);
* the version-2 halves: `verifyScript_minimaldata_off`, `verifyScript_lowS_off`,
  `verifyScript_sigpushonly_off`, `verifyScript_cleanstack_off`: with
  `SCRIPT_CHRONICLE` and a version above 1, each bit may be set or cleared
  without changing any verdict (P3 restricted to one bit, with that bit's own
  side condition).

The executable evidence is `lean/Test/VersionGateCheck.lean` (`make versiongatecheck`):
every corner above under the four parameter sets a mainnet node derives, verdict
and error code; the reference's own `script_tests.json` rows carrying the four
flags (`make scripttests`); the corpora with their version-1 twins against bsv-rs.
-/

namespace BsvScript.Properties
open BsvScript.Params BsvScript.Machine BsvScript.Numbers

/-! ## The gate (`34–44`) -/

/-- **The branch, as an equivalence.** *What it says:* the gate is on exactly when the
word lacks `SCRIPT_CHRONICLE` or the version is at most 1 (`40–44` with `34–38`).
*What it assumes:* nothing. *Why it matters:* it is the whole content of the
branch-selection parameter: a pre-Chronicle spend era, or any version-1 spend (the
negative versions included), runs the restrictions; only a version above 1 under
Chronicle lifts them. -/
theorem enforceNonMalleability_iff (f : Flags) (v : Int) :
    enforceNonMalleability f v = true ↔ (f.chronicle = false ∨ v ≤ 1) := by
  cases hc : f.chronicle
  · simp [enforceNonMalleability, isMalleableTxnVersion, hc]
  · simp [enforceNonMalleability, isMalleableTxnVersion, hc]

/-- **The gate on: the word is read as given.** *What it says:* when the gate is on,
`Flags.gate` is the identity, so every gated site reads the bit the word carries
(`433`, `285`, `2327`, `2441`, and the three of #11/#8). *Why it matters:* the
version-1 branch is the word itself; the theorems below then speak about the bits. -/
theorem Flags.gate_of_on (f : Flags) (v : Int) (h : enforceNonMalleability f v = true) : f.gate v = f := by
  simp [Flags.gate, h]

/-- The gate does not touch `SCRIPT_CHRONICLE`, so re-reading it on the gated word
gives the same answer: the crypto sites (`285`, `1493`, `1643`, `1666`) read
`bit && gate` on the gated word and get exactly the reference's `bit && gate`. -/
theorem enforceNonMalleability_gate (f : Flags) (v : Int) :
    enforceNonMalleability (f.gate v) v = enforceNonMalleability f v := by
  unfold Flags.gate
  split <;> simp [enforceNonMalleability]

/-- Gating twice is gating once. -/
theorem Flags.gate_gate (f : Flags) (v : Int) : (f.gate v).gate v = f.gate v := by
  by_cases h : enforceNonMalleability f v = true
  · rw [Flags.gate_of_on f v h, Flags.gate_of_on f v h]
  · have h' : enforceNonMalleability f v = false := by simpa using h
    have h2 : enforceNonMalleability (f.gate v) v = false := by rw [enforceNonMalleability_gate, h']
    simp [Flags.gate, h']

/-! ## MINIMALDATA (`433–434`, `475`, every number read) -/

/-- **`requireMinimal` as an equation** (`433–434`). *What it says:* the environment's
`requireMinimal` is the word's MINIMALDATA bit and the gate, on the word before
gating. *Why it matters:* it is the one place the flag enters the loop; every push
and every number read consults this value and nothing else about MINIMALDATA. -/
theorem mkEnv_requireMinimal (p : EvalParams) (ctx : Context) (f0 : Flags) (cd : Option Bytes) :
    (mkEnv p ctx f0 cd).requireMinimal = (f0.minimalData && enforceNonMalleability f0 ctx.version) := by
  simp only [mkEnv, enforceNonMalleability_gate]
  by_cases h : enforceNonMalleability f0 ctx.version = true
  · rw [Flags.gate_of_on f0 ctx.version h]
  · have h' : enforceNonMalleability f0 ctx.version = false := by simpa using h
    simp [h']

/-- **An executed non-minimal push fails** (`473–479`, `331–358`). *What it says:*
under `requireMinimal`, an executed push whose opcode is not the smallest form for
its data is `SCRIPT_ERR_MINIMALDATA`, before the element reaches the stack. *What it
assumes:* the push is executed (`fExec`). *Why it matters:* it is the MINIMALDATA
rule on pushes, in both scripts and the redeem script, and only there: a push in a
dead branch is not executed and `execStep` never reaches this test for it. -/
theorem execStep_minimaldata (exec : OpExec) (env : Env) (op : Nat) (data rest : Bytes) (k : Nat) (st : State)
    (hmin : env.requireMinimal = true) (hpush : op ≤ Op.OP_PUSHDATA4) (hform : checkMinimalPush data op = false) :
    execStep exec env op data rest k true st = .fail .minimaldata := by
  simp [execStep, hmin, hpush, hform]

/-- **Without `requireMinimal` the push form is never consulted** (`475`): the push
succeeds when the budget allows (`pushElem`). -/
theorem execStep_push_of_not_requireMinimal (exec : OpExec) (env : Env) (op : Nat) (data rest : Bytes) (k : Nat)
    (st st' : State) (hmin : env.requireMinimal = false) (hpush : op ≤ Op.OP_PUSHDATA4)
    (hok : pushElem env st data = .ok st') :
    execStep exec env op data rest k true st = .cont st' := by
  simp [execStep, hmin, hpush, hok]

/-- The same, the budget refused (`stack_overflow_error` → `SCRIPT_ERR_STACK_SIZE`). -/
theorem execStep_push_err_of_not_requireMinimal (exec : OpExec) (env : Env) (op : Nat) (data rest : Bytes) (k : Nat)
    (st : State) (e : ScriptError) (hmin : env.requireMinimal = false) (hpush : op ≤ Op.OP_PUSHDATA4)
    (herr : pushElem env st data = .error e) :
    execStep exec env op data rest k true st = .fail e := by
  simp [execStep, hmin, hpush, herr]

/-- **A non-minimal number read under `requireMinimal` fails** (`script_num.cpp:67–70`,
`SCRIPT_ERR_SCRIPTNUM_MINENCODE` at `1811–1814`): the width passed
(`script_num.cpp:62–65`), the encoding is not minimal (`int_serialization.h:120–152`).
This is the constructor every site of the table above calls. -/
theorem readNum_minencode (bs : Bytes) (maxLen : Nat) (hlen : bs.length ≤ maxLen)
    (hnm : isMinimallyEncoded bs maxLen = false) :
    readNum bs true maxLen = .error .minencode := by
  have hnlt : ¬ maxLen < bs.length := Nat.not_lt.mpr hlen
  simp [readNum, hnlt, hnm]

/-- **Without `requireMinimal` every encoding within the width decodes** (`script_num.cpp:53–91`
with `min_encoding_check::no`): the padded and negative-zero forms read as their value
(`Numbers.decode`). -/
theorem readNum_of_not_requireMinimal (bs : Bytes) (maxLen : Nat) (hlen : bs.length ≤ maxLen) :
    readNum bs false maxLen = .ok (decode bs) := by
  have hnlt : ¬ maxLen < bs.length := Nat.not_lt.mpr hlen
  simp [readNum, hnlt]

/-- The operand read of the arithmetic, bitwise, stack and splice families
(`Ops.Arith.readOperand`, the sites `1015`, `1129`, `1163`, `1235`, `1300–1301`,
`1386–1390`, `1717`, `1747` and the shifts `709–753`): under `requireMinimal` a
non-minimal encoding within the width is `SCRIPT_ERR_SCRIPTNUM_MINENCODE`. -/
theorem readOperand_minencode (env : Env) (bs : Bytes) (hmin : env.requireMinimal = true)
    (hlen : bs.length ≤ env.params.limits.maxScriptNumLength)
    (hnm : isMinimallyEncoded bs env.params.limits.maxScriptNumLength = false) :
    Ops.Arith.readOperand env bs = .error .scriptnumMinencode := by
  have hnlt : ¬ env.params.limits.maxScriptNumLength < bs.length := Nat.not_lt.mpr hlen
  simp [Ops.Arith.readOperand, hnlt, hmin, hnm]

/-- The same read without `requireMinimal`: the value, whatever the encoding. -/
theorem readOperand_of_not_requireMinimal (env : Env) (bs : Bytes) (hmin : env.requireMinimal = false)
    (hlen : bs.length ≤ env.params.limits.maxScriptNumLength) :
    Ops.Arith.readOperand env bs = .ok (decode bs) := by
  have hnlt : ¬ env.params.limits.maxScriptNumLength < bs.length := Nat.not_lt.mpr hlen
  simp [Ops.Arith.readOperand, hnlt, hmin]

/-! ## LOW_S (`282–287`, `pubkey.cpp:353–363`) -/

/-- **A high-S signature fails under LOW_S and the gate** (`282–287`). *What it says:*
a non-empty signature of the strict DER shape whose `s` is not low
(`CPubKey::CheckLowS` false: `s > (n − 1)/2`, or the lax parse fails) is
`SCRIPT_ERR_SIG_HIGH_S` when LOW_S is set and the gate is on, before the hash-type
rules and before any curve computation. *What it assumes:* the strict shape, so
that `275–280` does not fire first. *Why it matters:* LOW_S is a consensus flag
(`verify_script_flags.cpp:65–67`), so on the version-1 branch a high-S signature
is refused by every node. On the version-2 branch the gate is off and LOW_S
refuses nothing: the signature goes on to the hash-type rules and the curve check,
where the high-S twin of a valid signature verifies, because `CPubKey::Verify`
normalizes `s` (`pubkey.cpp:207–213`), and a high-S signature that is not a valid
signature fails as any invalid signature does (`lean/Test/VersionGateCheck.lean`'s
LOW_S rows: `s = (n + 1)/2` and `s = n − 1` answer `SCRIPT_ERR_EVAL_FALSE` on the
version-2 branch). The gate's being off decides the encoding check only, never the
signature's validity. -/
theorem checkSignatureEncoding_highS (env : Env) (sig : Bytes) (hne : sig ≠ [])
    (hder : Ops.Crypto.isValidSignatureEncoding sig = true) (hlow : env.params.flags.lowS = true)
    (hhigh : Crypto.Secp256k1.checkLowS sig.dropLast = false)
    (hgate : enforceNonMalleability env.params.flags env.ctx.version = true) :
    Ops.Crypto.checkSignatureEncoding env sig = .error .sigHighS := by
  have hne' : sig.isEmpty = false := by cases sig with | nil => exact absurd rfl hne | cons _ _ => rfl
  simp [Ops.Crypto.checkSignatureEncoding, hne', hder, hlow, hhigh, hgate]

/-- **With the gated LOW_S bit clear, `SCRIPT_ERR_SIG_HIGH_S` is unreachable**
(`282–287`): the encoding check can still refuse the shape (`SIG_DER`) or the hash
type (`291–307`), never the height of `s`. -/
theorem checkSignatureEncoding_ne_highS (env : Env) (sig : Bytes) (hlow : env.params.flags.lowS = false) :
    Ops.Crypto.checkSignatureEncoding env sig ≠ .error .sigHighS := by
  unfold Ops.Crypto.checkSignatureEncoding
  simp only [hlow, Bool.false_and, Bool.false_eq_true, ite_false]
  repeat' split
  all_goals simp

/-! ## SIGPUSHONLY (`2321–2334`) -/

/-- **A non-push unlocking script fails under SIGPUSHONLY and the era gate** (`2321–2334`).
*What it says:* with a valid word carrying SIGPUSHONLY, in a spend era that is
Genesis-without-Chronicle, or Chronicle with a version at most 1 (`2325–2327`), an
unlocking script that is not push-only (`IsPushOnly`, `script.cpp:209–220`) is
`SCRIPT_ERR_SIG_PUSHONLY`, before any script runs. *What it assumes:* the two
disjuncts of `2325–2327`. *Why it matters:* SIGPUSHONLY is a consensus flag from
Genesis (`verify_script_flags.cpp:71–75`, `policy.h:229–232`): a version-1 spend
post-Chronicle, and every spend between Genesis and Chronicle, may carry only pushes
in its unlocking script, on the block path as on the mempool path. -/
theorem verifyScript_sigpushonly (exec : OpExec) (p : EvalParams) (ctx : Context) (s l : Bytes)
    (hvalid : p.flags.valid = true) (hflag : p.flags.sigPushOnly = true)
    (hera : ((p.flags.genesis && !p.flags.chronicle) || (p.flags.chronicle && !isMalleableTxnVersion ctx.version)) = true)
    (hnp : isPushOnly s = false) :
    verifyScript exec p ctx s l = .invalid .sigPushonly := by
  have hfa_c : p.flags.forkAdjust.chronicle = p.flags.chronicle := by unfold Flags.forkAdjust; split <;> rfl
  have hfa_g : p.flags.forkAdjust.genesis = p.flags.genesis := by unfold Flags.forkAdjust; split <;> rfl
  have hfa_s : p.flags.forkAdjust.sigPushOnly = p.flags.sigPushOnly := by unfold Flags.forkAdjust; split <;> rfl
  have hgate : enforceNonMalleability p.flags.forkAdjust ctx.version = true := by
    simp only [enforceNonMalleability, hfa_c]
    simp only [Bool.or_eq_true, Bool.and_eq_true, Bool.not_eq_true'] at hera
    rcases hera with ⟨_, hc⟩ | ⟨_, hm⟩
    · simp [hc]
    · simp [hm]
  have hg : p.flags.forkAdjust.gate ctx.version = p.flags.forkAdjust := Flags.gate_of_on _ _ hgate
  have hreq : (p.flags.forkAdjust.sigPushOnly &&
      ((p.flags.forkAdjust.genesis && !p.flags.forkAdjust.chronicle) ||
       (p.flags.forkAdjust.chronicle && !isMalleableTxnVersion ctx.version))) = true := by
    rw [hfa_s, hfa_g, hfa_c, hflag, hera]; rfl
  unfold verifyScript
  simp only [hvalid, Bool.not_true, Bool.false_eq_true, ite_false, hg, hreq, hnp, Bool.true_and, Bool.not_false, ite_true]

/-! ## CLEANSTACK (`2430–2448`) -/

set_option linter.unusedTactic false in
/-- **CLEANSTACK without P2SH never validates** (`2432–2435`): whatever the version and
the scripts, a word with CLEANSTACK and without P2SH cannot reach `SCRIPT_ERR_OK`
through `phase2`: the demand is tested, ungated, on the way to every `valid`. -/
theorem phase2_ne_valid_of_cleanStackDemand (exec : OpExec) (p : EvalParams) (ctx : Context) (f0 : Flags)
    (s l : Bytes) (stack : List Bytes) (mem : Nat) (h : f0.cleanStackDemand = true) :
    phase2 exec p ctx f0 s l stack mem ≠ .valid := by
  intro hv
  unfold phase2 at hv
  simp only [h, ite_true] at hv
  repeat' (split at hv)
  all_goals first | (simp at hv; done) | (subst hv; simp_all)

/-- **CLEANSTACK without P2SH is an invalid word** (`2432–2435`), for every version.
*What it says:* a parameter record whose word carries CLEANSTACK and not P2SH never
returns `valid`, and says no more: the verdict it returns instead may be
`SCRIPT_ERR_INVALID_FLAGS` (the test's own error), an earlier error, or one of the
two outcomes that are not errors, `unimplemented` and `undefinedInReference`
(`Machine.Verdict`). *Why it matters:* the reference's own vector runner adds P2SH
whenever it sets CLEANSTACK (`script_tests.cpp:281–282`), so its vectors never
reach this line; the spec states it. -/
theorem verifyScript_cleanstack_without_p2sh (exec : OpExec) (p : EvalParams) (ctx : Context) (s l : Bytes)
    (hcs : p.flags.cleanStack = true) (hp : p.flags.p2sh = false) :
    verifyScript exec p ctx s l ≠ .valid := by
  have hd : p.flags.forkAdjust.cleanStackDemand = true := by
    unfold Flags.forkAdjust Flags.cleanStackDemand; split <;> simp [hcs, hp]
  intro hv
  unfold verifyScript at hv
  dsimp only at hv
  split at hv
  · simp at hv
  · split at hv
    · simp at hv
    · split at hv
      · simp at hv
      · simp at hv
      · simp at hv
      · exact phase2_ne_valid_of_cleanStackDemand exec p ctx _ s l _ _ hd hv

/-- **The clean-stack rule with the gate on** (`2441–2445`). *What it says:* for a
post-Genesis UTXO (no P2SH copy), when the locking script leaves a true top element
over at least one more element, CLEANSTACK with P2SH set and the gate on makes the
spend `SCRIPT_ERR_CLEANSTACK`. *What it assumes:* the locking phase's outcome and its
stack (the hypotheses name them). *Why it matters:* it is the version-1 branch's
clean-stack rule at its site; with the gate off the same stack is valid
(`verifyScript_cleanstack_off`), and on the block path the word never carries the bit
(`blockScriptFlags_policy_off`). -/
theorem phase2_cleanstack (exec : OpExec) (p : EvalParams) (ctx : Context) (f0 : Flags) (s l : Bytes)
    (stack : List Bytes) (mem : Nat) (st2 : State) (top : Bytes) (rest : List Bytes)
    (heval : evalScript exec (mkEnv p ctx f0 none) l stack mem = (.ok, st2))
    (hstack : st2.stack = top :: rest) (htop : castToBool top = true) (hrest : rest ≠ [])
    (hcopy : f0.p2shCopy = false) (hcs : f0.cleanStack = true) (hp : f0.p2sh = true)
    (hgate : enforceNonMalleability f0 ctx.version = true) :
    phase2 exec p ctx f0 s l stack mem = .invalid .cleanstack := by
  have hg : f0.gate ctx.version = f0 := Flags.gate_of_on f0 _ hgate
  have hd : f0.cleanStackDemand = false := by simp [Flags.cleanStackDemand, hcs, hp]
  have hlen : (top :: rest).length != 1 := by
    cases rest with
    | nil => exact absurd rfl hrest
    | cons _ _ => simp
  unfold phase2
  simp only [heval, hstack, htop, hcopy, hg, hd, hcs, Bool.not_true, Bool.false_eq_true, ite_false, ite_true, Bool.true_and, hlen]

/-! ## The version-2 halves: each bit alone, with the gate off -/

/-- **MINIMALDATA is never consulted with the gate off.** *What it says:* with
`SCRIPT_CHRONICLE` and a version above 1, the MINIMALDATA bit may be set or cleared
without changing any verdict. *What it assumes:* nothing else (MINIMALDATA has no
ungated read). *Why it matters:* it is the version-2 half of the MINIMALDATA rule,
and it needs `SCRIPT_CHRONICLE` (`hc`): under a word carrying it the relay-only bit
never reaches a version-2 verdict, and `blockScriptFlags_policy_off` keeps the bit
out of every block word. A word without CHRONICLE that carries MINIMALDATA binds a
version-2 spend to it, the gate being on for every version (`40–44`, read at `433`):
the standard relay word of every spend era before Chronicle (`policy.h:191–193`) is
such a word, and so is any explicit word of that shape. -/
theorem verifyScript_minimaldata_off (exec : OpExec) (f : Flags) (limits : Limits) (ctx : Context) (s l : Bytes) (b : Bool)
    (hc : f.chronicle = true) (hv : 1 < ctx.version) :
    verifyScript exec { flags := { f with minimalData := b }, limits } ctx s l
      = verifyScript exec { flags := f, limits } ctx s l := by
  cases f with
  | mk p2sh strictEnc derSig lowS nullDummy sigPushOnly minimalData discourageUpgradableNops cleanStack
      checkLockTimeVerify checkSequenceVerify minimalIf nullFail compressedPubKeyType enableSighashForkid
      genesis utxoAfterGenesis chronicle utxoAfterChronicle =>
    simp only at hc
    subst hc
    apply verifyScript_congr <;> cases enableSighashForkid <;>
      simp [Flags.forkAdjust, Flags.gate, Flags.valid, Flags.strictDer, Flags.utxoEra, Flags.p2shCopy,
            Flags.cleanStackDemand, enforceNonMalleability, isMalleableTxnVersion, hv]

/-- **SIGPUSHONLY is never consulted with the gate off** (`2325–2327`: neither disjunct
holds for a version above 1 under Chronicle). -/
theorem verifyScript_sigpushonly_off (exec : OpExec) (f : Flags) (limits : Limits) (ctx : Context) (s l : Bytes) (b : Bool)
    (hc : f.chronicle = true) (hv : 1 < ctx.version) :
    verifyScript exec { flags := { f with sigPushOnly := b }, limits } ctx s l
      = verifyScript exec { flags := f, limits } ctx s l := by
  cases f with
  | mk p2sh strictEnc derSig lowS nullDummy sigPushOnly minimalData discourageUpgradableNops cleanStack
      checkLockTimeVerify checkSequenceVerify minimalIf nullFail compressedPubKeyType enableSighashForkid
      genesis utxoAfterGenesis chronicle utxoAfterChronicle =>
    simp only at hc
    subst hc
    apply verifyScript_congr <;> cases enableSighashForkid <;>
      simp [Flags.forkAdjust, Flags.gate, Flags.valid, Flags.strictDer, Flags.utxoEra, Flags.p2shCopy,
            Flags.cleanStackDemand, enforceNonMalleability, isMalleableTxnVersion, hv]

/-- **CLEANSTACK is never consulted with the gate off**, given P2SH (the ungated demand
`2432–2435` is then satisfied either way): the size test `2441–2445` is skipped. -/
theorem verifyScript_cleanstack_off (exec : OpExec) (f : Flags) (limits : Limits) (ctx : Context) (s l : Bytes) (b : Bool)
    (hc : f.chronicle = true) (hv : 1 < ctx.version) (hp : f.p2sh = true) :
    verifyScript exec { flags := { f with cleanStack := b }, limits } ctx s l
      = verifyScript exec { flags := f, limits } ctx s l := by
  cases f with
  | mk p2sh strictEnc derSig lowS nullDummy sigPushOnly minimalData discourageUpgradableNops cleanStack
      checkLockTimeVerify checkSequenceVerify minimalIf nullFail compressedPubKeyType enableSighashForkid
      genesis utxoAfterGenesis chronicle utxoAfterChronicle =>
    simp only at hc hp
    subst hc
    subst hp
    apply verifyScript_congr <;> cases enableSighashForkid <;>
      simp [Flags.forkAdjust, Flags.gate, Flags.valid, Flags.strictDer, Flags.utxoEra, Flags.p2shCopy,
            Flags.cleanStackDemand, enforceNonMalleability, isMalleableTxnVersion, hv]

/-- **LOW_S is never consulted with the gate off**, given DERSIG, STRICTENC or FORKID
(the ungated read `275–280` then selects the strict DER shape either way): the high-S
test `282–287` is skipped and `CPubKey::Verify` normalizes `s` (`pubkey.cpp:207–213`). -/
theorem verifyScript_lowS_off (exec : OpExec) (f : Flags) (limits : Limits) (ctx : Context) (s l : Bytes) (b : Bool)
    (hc : f.chronicle = true) (hv : 1 < ctx.version)
    (hA : (f.derSig || f.strictEnc || f.enableSighashForkid) = true) :
    verifyScript exec { flags := { f with lowS := b }, limits } ctx s l
      = verifyScript exec { flags := f, limits } ctx s l := by
  cases f with
  | mk p2sh strictEnc derSig lowS nullDummy sigPushOnly minimalData discourageUpgradableNops cleanStack
      checkLockTimeVerify checkSequenceVerify minimalIf nullFail compressedPubKeyType enableSighashForkid
      genesis utxoAfterGenesis chronicle utxoAfterChronicle =>
    simp only at hc
    simp only [Bool.or_eq_true] at hA
    subst hc
    apply verifyScript_congr <;>
      (rcases hA with (hA | hA) | hA <;> subst hA <;> (try cases enableSighashForkid) <;>
       simp [Flags.forkAdjust, Flags.gate, Flags.valid, Flags.strictDer, Flags.utxoEra, Flags.p2shCopy,
             Flags.cleanStackDemand, enforceNonMalleability, isMalleableTxnVersion, hv])

end BsvScript.Properties
