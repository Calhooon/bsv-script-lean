import BsvScript.Eval
import BsvScript.Flags
/-!
# BsvScript.Properties.KernelSample

The kernel-evaluated sample (the direction audit's item (b), of
2026-09-27 17:15 UTC; `docs/HYPOTHESES.md` §3). The kernel checks the
definitions, the theorems and each `@[csimp]` lemma's statement; the corpus judges the COMPILED
evaluator (`eval/bsvs`), whose code the Lean compiler emits with the `@[csimp]` substitutions applied.
This module is a bridge between the two at fixed points. Each vector below is a short arithmetic,
stack, flow, splice or version-gate script with its expected verdict and error code. Its theorem is
decided by `decide +kernel` on the definitions: the kernel reduces `Eval.verifyScript` as written, and
neither compiled code nor `Lean.ofReduceBool` enters the proof. The SAME list `vectors` is run by the
compiled evaluator in the flow leg (`Test/FlowCheck.lean`), which exits 1 on any disagreement. Since #50
the compiled `Eval.verifyScript` is `Eval.verifyScriptI`, the array machine (`@[csimp] Eval.verifyScript_eq_I`),
so the bridge has two links: the kernel-checked theorem `verifyScript_eq_I` ties that machine to the
definition, and these vectors check the compiler's translation of it. The list machine the compiled code
still runs elsewhere (the mempool gate's P2SH standardness run and `--trace`) is outside this sample.
Agreement on both sides is the sample's claim. It is evidence at these points, not a proof about the
compiler.

Two definitions the vectors reach are well-founded recursions, which the kernel does not reduce: the
loop (`Machine.loop`) and the push-only test (`Machine.isPushOnly`). Each has a copy here with a fuel
argument, structural on the fuel and otherwise the same body (`loopFuel`, `isPushOnlyFuel`), proven
equal to it at any fuel at least the script's length (`loop_eq_fuel`, `isPushOnly_eq_fuel`). A
vector's proof unfolds `Eval.verifyScript` down to the loop, rewrites the two recursions into their
copies, and hands the rest to the kernel. Every other definition is reduced as written, the families'
included.

The vectors take the parameters `Params.derive` gives SV-node's mainnet defaults at the default spend
height for an output of that height (`NodeConfig.svMainnetDefault`, `defaultSpendHeight`: a
post-Chronicle spend of a post-Chronicle output), on the block path unless the vector says the
mempool path, and a context whose three checkers answer `false` (no vector reaches a signature, a
lock time or a sequence). No vector has a hash, a signature or a large number, so the kernel finishes
each in seconds.

Bare line numbers are `src/script/interpreter.cpp` at the pin (`docs/PROVENANCE.md`).
-/

namespace BsvScript.Properties.KernelSample
open BsvScript.Params BsvScript.Machine BsvScript.Numbers

/-! ## The two recursions with fuel -/

/-- `Machine.isPushOnly` (`script.cpp:209–220`) with a fuel argument: the same body, structural on
the fuel. With no fuel left on a non-empty script it answers `false`, a case `isPushOnly_eq_fuel`
never reaches. -/
def isPushOnlyFuel : Nat → Bytes → Bool
  | _, [] => true
  | 0, _ :: _ => false
  | n + 1, op :: rest =>
    match getOpTail op rest with
    | none => false
    | some (_, k) => if op > Op.OP_16 then false else isPushOnlyFuel n (rest.drop k)

/-- **`isPushOnly_eq_fuel`.** *What it says:* at any fuel at least the script's length, the fuel copy
answers what `isPushOnly` answers. *What it assumes:* the bound only. *Why it matters:* the kernel
reduces the copy, a structural recursion, where it does not reduce `isPushOnly`'s well-founded one;
a vector whose unlocking script the SIGPUSHONLY gate reads (`2321–2334`) is decided through it. -/
theorem isPushOnly_eq_fuel : ∀ (n : Nat) (s : Bytes), s.length ≤ n → isPushOnly s = isPushOnlyFuel n s
  | _, [], _ => by rw [isPushOnly.eq_1, isPushOnlyFuel.eq_1]
  | 0, _ :: _, h => by simp at h
  | n + 1, op :: rest, h => by
    rw [isPushOnly.eq_2, isPushOnlyFuel.eq_3]
    cases getOpTail op rest with
    | none => rfl
    | some p =>
      obtain ⟨d, k⟩ := p
      dsimp only
      rw [isPushOnly_eq_fuel n (rest.drop k)
        (by simp only [List.length_drop, List.length_cons] at h ⊢; omega)]

/-- `isPushOnly_eq_fuel` at the script's own length: the form a vector's proof rewrites with. -/
theorem isPushOnly_eq_fuel_length (s : Bytes) : isPushOnly s = isPushOnlyFuel s.length s :=
  isPushOnly_eq_fuel s.length s (Nat.le_refl _)

/-- `Machine.loop` (`388–1833`) with a fuel argument: the same body, structural on the fuel. With no
fuel left on a non-empty script it answers `SCRIPT_ERR_BAD_OPCODE`, a case `loop_eq_fuel` never
reaches. -/
def loopFuel (exec : OpExec) (env : Env) : Nat → Bytes → State → Outcome × State
  | _, [], st => if st.cond.empty then (.ok, st) else (.err .unbalancedConditional, st)
  | 0, _ :: _, st => (.err .badOpcode, st)
  | n + 1, op :: rest, st =>
    match getOpTail op rest with
    | none => (.err .badOpcode, st)
    | some (data, k) =>
      if !env.utxoAfterGenesis && data.length > Consensus.maxScriptElementSizeBeforeGenesis then (.err .pushSize, st)
      else
        let fExec := st.cond.isActive && (!st.nonTopLevelReturn || op == Op.OP_RETURN)
        let st := if op > Op.OP_16 then { st with opCount := st.opCount + 1 } else st
        if op > Op.OP_16 && st.opCount > env.params.limits.maxOpsPerScript then (.err .opCount, st)
        else if isOpcodeDisabled op env.utxoEra && (!env.utxoAfterGenesis || fExec) then (.err .disabledOpcode, st)
        else
          match execStep exec env op data rest k fExec st with
          | .fail e => (.err e, st)
          | .unimpl o => (.unimplemented o, st)
          | .undefined f => (.undefinedInReference f, st)
          | .done => (.ok, st)
          | .cont st' =>
            if !env.utxoAfterGenesis && st'.stack.length + st'.alt.length > Consensus.maxStackElementsBeforeGenesis then
              (.err .stackSize, st')
            else loopFuel exec env n (rest.drop k) st'

/-- **`loop_eq_fuel`.** *What it says:* at any fuel at least the script's length, the fuel copy
returns what the loop returns, the outcome and the final state. *What it assumes:* the bound only,
for every family hook `exec` and environment. *Why it matters:* the kernel reduces the copy, a
structural recursion, where it does not reduce the loop's well-founded one; every vector is decided
through it. -/
theorem loop_eq_fuel (exec : OpExec) (env : Env) :
    ∀ (n : Nat) (s : Bytes) (st : State), s.length ≤ n → loop exec env s st = loopFuel exec env n s st
  | _, [], st, _ => by rw [loop.eq_1, loopFuel.eq_1]
  | 0, _ :: _, _, h => by simp at h
  | n + 1, op :: rest, st, h => by
    rw [loop.eq_2, loopFuel.eq_3]
    cases getOpTail op rest with
    | none => rfl
    | some p =>
      obtain ⟨data, k⟩ := p
      have ih : ∀ st', loop exec env (rest.drop k) st' = loopFuel exec env n (rest.drop k) st' := fun st' =>
        loop_eq_fuel exec env n (rest.drop k) st'
          (by simp only [List.length_drop, List.length_cons] at h ⊢; omega)
      dsimp only
      simp only [ih]
      rfl

/-- `loop_eq_fuel` at the script's own length: the form a vector's proof rewrites with. -/
theorem loop_eq_fuel_length (exec : OpExec) (env : Env) (s : Bytes) (st : State) :
    loop exec env s st = loopFuel exec env s.length s st :=
  loop_eq_fuel exec env s.length s st (Nat.le_refl _)

/-! ## The vectors -/

/-- A vector: the unlocking and the locking script, the spending transaction's version, the path (the
block path when `consensus`, else the mempool path), the expected verdict with its error code, and
the citation of the rule it exercises. -/
structure KernelVector where
  name : String
  cite : String
  unlock : Bytes := []
  lock : Bytes
  version : Int := 2
  consensus : Bool := true
  expect : Verdict

/-- The vector's parameters: `Params.derive` for SV-node's mainnet defaults, a spend at the default
height of an output of the same height, on the vector's path. -/
def KernelVector.params (v : KernelVector) : EvalParams :=
  derive NodeConfig.svMainnetDefault defaultSpendHeight defaultSpendHeight v.consensus

/-- The vector's context: its version, and three checkers that answer `false`. -/
def KernelVector.ctx (v : KernelVector) : Context :=
  { version := v.version, checkLockTime := fun _ => false, checkSequence := fun _ => false,
    checkSig := fun _ _ _ _ => false }

/-- The spec's verdict on the vector: `Eval.verifyScript` on its parameters, context and scripts. -/
def KernelVector.run (v : KernelVector) : Verdict :=
  Eval.verifyScript v.params v.ctx v.unlock v.lock

def vAdd : KernelVector :=
  { name := "2 3 OP_ADD 5 OP_NUMEQUAL", cite := "1304–1306; 1338–1341",
    lock := [0x52, 0x53, 0x93, 0x55, 0x9c], expect := .valid }

def vModSign : KernelVector :=
  { name := "-7 2 OP_MOD is -1: the remainder takes the dividend's sign", cite := "1324–1330; script_num.cpp:246; big_int.cpp:250–260",
    lock := [0x01, 0x87, 0x52, 0x97, 0x4f, 0x87], expect := .valid }

def vDivZero : KernelVector :=
  { name := "1 0 OP_DIV", cite := "1316–1319",
    lock := [0x51, 0x00, 0x96], expect := .invalid .divByZero }

def vNumEqVerify : KernelVector :=
  { name := "2 3 OP_NUMEQUALVERIFY", cite := "1338–1341; 1371–1377",
    lock := [0x52, 0x53, 0x9d], expect := .invalid .numequalverify }

def vWithin : KernelVector :=
  { name := "5 3 7 OP_WITHIN: 3 <= 5 < 7", cite := "1380–1397",
    lock := [0x55, 0x53, 0x57, 0xa5], expect := .valid }

def vNegZero : KernelVector :=
  { name := "<0x80> OP_1ADD 1 OP_NUMEQUAL: negative zero reads as 0", cite := "1222–1240; script_num.cpp:67",
    lock := [0x01, 0x80, 0x8b, 0x51, 0x9c], expect := .valid }

def vPick : KernelVector :=
  { name := "7 8 9 2 OP_PICK 7 OP_EQUAL", cite := "1006–1027; 1189–1215",
    lock := [0x57, 0x58, 0x59, 0x52, 0x79, 0x57, 0x87], expect := .valid }

def vRot : KernelVector :=
  { name := "1 2 3 OP_ROT 1 OP_EQUAL", cite := "1029–1038; 1189–1215",
    lock := [0x51, 0x52, 0x53, 0x7b, 0x51, 0x87], expect := .valid }

def vDropEmpty : KernelVector :=
  { name := "OP_DROP on an empty stack", cite := "972–978",
    lock := [0x75], expect := .invalid .invalidStackOperation }

def vAlt : KernelVector :=
  { name := "5 OP_TOALTSTACK OP_FROMALTSTACK 5 OP_EQUAL", cite := "876–887; 1189–1215",
    lock := [0x55, 0x6b, 0x6c, 0x55, 0x87], expect := .valid }

def vFromAltEmpty : KernelVector :=
  { name := "OP_FROMALTSTACK on an empty alt stack", cite := "883–887",
    lock := [0x6c], expect := .invalid .invalidAltstackOperation }

def vDepth : KernelVector :=
  { name := "1 1 OP_DEPTH 2 OP_EQUAL", cite := "966–970; 1189–1215",
    lock := [0x51, 0x51, 0x74, 0x52, 0x87], expect := .valid }

def vIfElse : KernelVector :=
  { name := "0 OP_IF 0 OP_ELSE 1 OP_ENDIF", cite := "784–840",
    lock := [0x00, 0x63, 0x00, 0x67, 0x51, 0x68], expect := .valid }

def vNotifNested : KernelVector :=
  { name := "0 OP_NOTIF 1 OP_IF 1 OP_ENDIF OP_ELSE 0 OP_ENDIF", cite := "784–840",
    lock := [0x00, 0x64, 0x51, 0x63, 0x51, 0x68, 0x67, 0x00, 0x68], expect := .valid }

def vUnclosedIf : KernelVector :=
  { name := "1 OP_IF 1, the IF never closed", cite := "1828–1830",
    lock := [0x51, 0x63, 0x51], expect := .invalid .unbalancedConditional }

def vEndifAlone : KernelVector :=
  { name := "1 OP_ENDIF, no IF open", cite := "835–840",
    lock := [0x51, 0x68], expect := .invalid .unbalancedConditional }

def vVerifyFalse : KernelVector :=
  { name := "0 OP_VERIFY", cite := "842–854",
    lock := [0x00, 0x69], expect := .invalid .verify }

def vReturnSuffix : KernelVector :=
  { name := "1 OP_RETURN, then a truncated push that is never parsed", cite := "856–861",
    lock := [0x51, 0x6a, 0x4c], expect := .valid }

def vFalseTop : KernelVector :=
  { name := "0: a false top when the locking script ends", cite := "2374–2378",
    lock := [0x00], expect := .invalid .evalFalse }

def vCat : KernelVector :=
  { name := "<11> <22> OP_CAT <1122> OP_EQUAL", cite := "1687–1706; 1189–1215",
    lock := [0x01, 0x11, 0x01, 0x22, 0x7e, 0x02, 0x11, 0x22, 0x87], expect := .valid }

def vPushOnlyV1 : KernelVector :=
  { name := "unlocking OP_1 OP_DUP, locking OP_EQUAL, version 1: not push-only under the gate",
    cite := "2321–2334", unlock := [0x51, 0x76], lock := [0x87], version := 1,
    expect := .invalid .sigPushonly }

def vPushOnlyV2 : KernelVector :=
  { name := "the same spend at version 2: the gate is off post-Chronicle", cite := "2321–2334; 34–38",
    unlock := [0x51, 0x76], lock := [0x87], version := 2, expect := .valid }

def vMinimalV1Mempool : KernelVector :=
  { name := "<01 00> OP_1ADD 2 OP_NUMEQUAL, version 1, the mempool path: a non-minimal number",
    cite := "433; script_num.cpp:67", lock := [0x02, 0x01, 0x00, 0x8b, 0x52, 0x9c], version := 1,
    consensus := false, expect := .invalid .scriptnumMinencode }

def vMinimalV2Mempool : KernelVector :=
  { name := "the same at version 2 on the mempool path: MINIMALDATA gated off", cite := "433; 40–44",
    lock := [0x02, 0x01, 0x00, 0x8b, 0x52, 0x9c], version := 2, consensus := false, expect := .valid }

def vMinimalV1Block : KernelVector :=
  { name := "the same at version 1 on the block path: MINIMALDATA is policy",
    cite := "policy.h:182–189; 433", lock := [0x02, 0x01, 0x00, 0x8b, 0x52, 0x9c], version := 1,
    expect := .valid }

/-- The sample, in the order the flow leg runs it. -/
def vectors : List KernelVector :=
  [vAdd, vModSign, vDivZero, vNumEqVerify, vWithin, vNegZero, vPick, vRot, vDropEmpty, vAlt,
   vFromAltEmpty, vDepth, vIfElse, vNotifNested, vUnclosedIf, vEndifAlone, vVerifyFalse, vReturnSuffix,
   vFalseTop, vCat, vPushOnlyV1, vPushOnlyV2, vMinimalV1Mempool, vMinimalV2Mempool, vMinimalV1Block]

/-! ## The kernel's verdicts

Each theorem below is one vector decided by the kernel: the unfolding to the loop and the rewrite
into the fuel copies, then `decide +kernel`. -/

/-- `2 3 OP_ADD 5 OP_NUMEQUAL` is valid (`1304–1306`, `1338–1341`). -/
theorem vAdd_kernel : vAdd.run = vAdd.expect := by
  simp only [KernelVector.run, Eval.verifyScript, Machine.verifyScript, Machine.phase2, Machine.evalScript,
    loop_eq_fuel_length, isPushOnly_eq_fuel_length]
  decide +kernel

/-- `-7 2 OP_MOD -1 OP_EQUAL` is valid: the remainder takes the dividend's sign (`1324–1330`; post-Genesis the number is a big integer, `script_num.cpp:246`, `big_int.cpp:250–260`). -/
theorem vModSign_kernel : vModSign.run = vModSign.expect := by
  simp only [KernelVector.run, Eval.verifyScript, Machine.verifyScript, Machine.phase2, Machine.evalScript,
    loop_eq_fuel_length, isPushOnly_eq_fuel_length]
  decide +kernel

/-- `1 0 OP_DIV` fails `SCRIPT_ERR_DIV_BY_ZERO` (`1316–1319`). -/
theorem vDivZero_kernel : vDivZero.run = vDivZero.expect := by
  simp only [KernelVector.run, Eval.verifyScript, Machine.verifyScript, Machine.phase2, Machine.evalScript,
    loop_eq_fuel_length, isPushOnly_eq_fuel_length]
  decide +kernel

/-- `2 3 OP_NUMEQUALVERIFY` fails `SCRIPT_ERR_NUMEQUALVERIFY` (`1371–1377`). -/
theorem vNumEqVerify_kernel : vNumEqVerify.run = vNumEqVerify.expect := by
  simp only [KernelVector.run, Eval.verifyScript, Machine.verifyScript, Machine.phase2, Machine.evalScript,
    loop_eq_fuel_length, isPushOnly_eq_fuel_length]
  decide +kernel

/-- `5 3 7 OP_WITHIN` is valid: 3 ≤ 5 < 7 (`1380–1397`). -/
theorem vWithin_kernel : vWithin.run = vWithin.expect := by
  simp only [KernelVector.run, Eval.verifyScript, Machine.verifyScript, Machine.phase2, Machine.evalScript,
    loop_eq_fuel_length, isPushOnly_eq_fuel_length]
  decide +kernel

/-- `<0x80> OP_1ADD 1 OP_NUMEQUAL` is valid: negative zero reads as zero on the block path, where MINIMALDATA is off (`1222–1240`, `script_num.cpp:67`). -/
theorem vNegZero_kernel : vNegZero.run = vNegZero.expect := by
  simp only [KernelVector.run, Eval.verifyScript, Machine.verifyScript, Machine.phase2, Machine.evalScript,
    loop_eq_fuel_length, isPushOnly_eq_fuel_length]
  decide +kernel

/-- `7 8 9 2 OP_PICK 7 OP_EQUAL` is valid: with the count popped, the element at depth 2 (the top at depth 0), the 7, is copied to the top (`1006–1027`). -/
theorem vPick_kernel : vPick.run = vPick.expect := by
  simp only [KernelVector.run, Eval.verifyScript, Machine.verifyScript, Machine.phase2, Machine.evalScript,
    loop_eq_fuel_length, isPushOnly_eq_fuel_length]
  decide +kernel

/-- `1 2 3 OP_ROT 1 OP_EQUAL` is valid: the third element moves to the top (`1029–1038`). -/
theorem vRot_kernel : vRot.run = vRot.expect := by
  simp only [KernelVector.run, Eval.verifyScript, Machine.verifyScript, Machine.phase2, Machine.evalScript,
    loop_eq_fuel_length, isPushOnly_eq_fuel_length]
  decide +kernel

/-- `OP_DROP` on an empty stack fails `SCRIPT_ERR_INVALID_STACK_OPERATION` (`972–978`). -/
theorem vDropEmpty_kernel : vDropEmpty.run = vDropEmpty.expect := by
  simp only [KernelVector.run, Eval.verifyScript, Machine.verifyScript, Machine.phase2, Machine.evalScript,
    loop_eq_fuel_length, isPushOnly_eq_fuel_length]
  decide +kernel

/-- `5 OP_TOALTSTACK OP_FROMALTSTACK 5 OP_EQUAL` is valid: the round trip through the alt stack (`876–887`). -/
theorem vAlt_kernel : vAlt.run = vAlt.expect := by
  simp only [KernelVector.run, Eval.verifyScript, Machine.verifyScript, Machine.phase2, Machine.evalScript,
    loop_eq_fuel_length, isPushOnly_eq_fuel_length]
  decide +kernel

/-- `OP_FROMALTSTACK` on an empty alt stack fails `SCRIPT_ERR_INVALID_ALTSTACK_OPERATION` (`883–887`). -/
theorem vFromAltEmpty_kernel : vFromAltEmpty.run = vFromAltEmpty.expect := by
  simp only [KernelVector.run, Eval.verifyScript, Machine.verifyScript, Machine.phase2, Machine.evalScript,
    loop_eq_fuel_length, isPushOnly_eq_fuel_length]
  decide +kernel

/-- `1 1 OP_DEPTH 2 OP_EQUAL` is valid: the depth is pushed as a number (`966–970`). -/
theorem vDepth_kernel : vDepth.run = vDepth.expect := by
  simp only [KernelVector.run, Eval.verifyScript, Machine.verifyScript, Machine.phase2, Machine.evalScript,
    loop_eq_fuel_length, isPushOnly_eq_fuel_length]
  decide +kernel

/-- `0 OP_IF 0 OP_ELSE 1 OP_ENDIF` is valid: the false branch is skipped, the else branch runs (`784–840`). -/
theorem vIfElse_kernel : vIfElse.run = vIfElse.expect := by
  simp only [KernelVector.run, Eval.verifyScript, Machine.verifyScript, Machine.phase2, Machine.evalScript,
    loop_eq_fuel_length, isPushOnly_eq_fuel_length]
  decide +kernel

/-- `0 OP_NOTIF 1 OP_IF 1 OP_ENDIF OP_ELSE 0 OP_ENDIF` is valid: a nested conditional inside a taken `NOTIF` branch (`784–840`). -/
theorem vNotifNested_kernel : vNotifNested.run = vNotifNested.expect := by
  simp only [KernelVector.run, Eval.verifyScript, Machine.verifyScript, Machine.phase2, Machine.evalScript,
    loop_eq_fuel_length, isPushOnly_eq_fuel_length]
  decide +kernel

/-- `1 OP_IF 1` fails `SCRIPT_ERR_UNBALANCED_CONDITIONAL`: the script ends with the `IF` open (`1828–1830`). -/
theorem vUnclosedIf_kernel : vUnclosedIf.run = vUnclosedIf.expect := by
  simp only [KernelVector.run, Eval.verifyScript, Machine.verifyScript, Machine.phase2, Machine.evalScript,
    loop_eq_fuel_length, isPushOnly_eq_fuel_length]
  decide +kernel

/-- `1 OP_ENDIF` fails `SCRIPT_ERR_UNBALANCED_CONDITIONAL`: no `IF` is open (`835–840`). -/
theorem vEndifAlone_kernel : vEndifAlone.run = vEndifAlone.expect := by
  simp only [KernelVector.run, Eval.verifyScript, Machine.verifyScript, Machine.phase2, Machine.evalScript,
    loop_eq_fuel_length, isPushOnly_eq_fuel_length]
  decide +kernel

/-- `0 OP_VERIFY` fails `SCRIPT_ERR_VERIFY` (`842–854`). -/
theorem vVerifyFalse_kernel : vVerifyFalse.run = vVerifyFalse.expect := by
  simp only [KernelVector.run, Eval.verifyScript, Machine.verifyScript, Machine.phase2, Machine.evalScript,
    loop_eq_fuel_length, isPushOnly_eq_fuel_length]
  decide +kernel

/-- `1 OP_RETURN` followed by a truncated push is valid: a top-level `OP_RETURN` post-Genesis ends the script before the rest is parsed (`856–861`). -/
theorem vReturnSuffix_kernel : vReturnSuffix.run = vReturnSuffix.expect := by
  simp only [KernelVector.run, Eval.verifyScript, Machine.verifyScript, Machine.phase2, Machine.evalScript,
    loop_eq_fuel_length, isPushOnly_eq_fuel_length]
  decide +kernel

/-- `0` fails `SCRIPT_ERR_EVAL_FALSE`: the top is false when the locking script ends (`2374–2378`). -/
theorem vFalseTop_kernel : vFalseTop.run = vFalseTop.expect := by
  simp only [KernelVector.run, Eval.verifyScript, Machine.verifyScript, Machine.phase2, Machine.evalScript,
    loop_eq_fuel_length, isPushOnly_eq_fuel_length]
  decide +kernel

/-- `<11> <22> OP_CAT <1122> OP_EQUAL` is valid (`1687–1706`). -/
theorem vCat_kernel : vCat.run = vCat.expect := by
  simp only [KernelVector.run, Eval.verifyScript, Machine.verifyScript, Machine.phase2, Machine.evalScript,
    loop_eq_fuel_length, isPushOnly_eq_fuel_length]
  decide +kernel

/-- An unlocking script `OP_1 OP_DUP` at version 1 fails `SCRIPT_ERR_SIG_PUSHONLY`: post-Chronicle the gate is on for version 1 (`2321–2334`); decided through `isPushOnly_eq_fuel`. -/
theorem vPushOnlyV1_kernel : vPushOnlyV1.run = vPushOnlyV1.expect := by
  simp only [KernelVector.run, Eval.verifyScript, Machine.verifyScript, Machine.phase2, Machine.evalScript,
    loop_eq_fuel_length, isPushOnly_eq_fuel_length]
  decide +kernel

/-- The same spend at version 2 is valid: the gate is off for a version above 1 post-Chronicle (`2321–2334`, `IsMalleableTxnVersion` at `34–38`). -/
theorem vPushOnlyV2_kernel : vPushOnlyV2.run = vPushOnlyV2.expect := by
  simp only [KernelVector.run, Eval.verifyScript, Machine.verifyScript, Machine.phase2, Machine.evalScript,
    loop_eq_fuel_length, isPushOnly_eq_fuel_length]
  decide +kernel

/-- `<01 00> OP_1ADD 2 OP_NUMEQUAL` at version 1 on the mempool path fails `SCRIPT_ERR_SCRIPTNUM_MINENCODE`: MINIMALDATA under the gate (`433`, `script_num.cpp:67`). -/
theorem vMinimalV1Mempool_kernel : vMinimalV1Mempool.run = vMinimalV1Mempool.expect := by
  simp only [KernelVector.run, Eval.verifyScript, Machine.verifyScript, Machine.phase2, Machine.evalScript,
    loop_eq_fuel_length, isPushOnly_eq_fuel_length]
  decide +kernel

/-- The same at version 2 on the mempool path is valid: the gate clears MINIMALDATA (`433`, `40–44`). -/
theorem vMinimalV2Mempool_kernel : vMinimalV2Mempool.run = vMinimalV2Mempool.expect := by
  simp only [KernelVector.run, Eval.verifyScript, Machine.verifyScript, Machine.phase2, Machine.evalScript,
    loop_eq_fuel_length, isPushOnly_eq_fuel_length]
  decide +kernel

/-- The same at version 1 on the block path is valid: MINIMALDATA is policy, absent from the block word (`policy.h:182–189`, `433`). -/
theorem vMinimalV1Block_kernel : vMinimalV1Block.run = vMinimalV1Block.expect := by
  simp only [KernelVector.run, Eval.verifyScript, Machine.verifyScript, Machine.phase2, Machine.evalScript,
    loop_eq_fuel_length, isPushOnly_eq_fuel_length]
  decide +kernel

/-- **`vectors_kernel`.** *What it says:* the Boolean the flow leg computes over the sample, every
vector's verdict equal to its expected one, is `true` on the definitions. *What it assumes:*
nothing. *Why it matters:* it ties the list the compiled evaluator runs (`Test/FlowCheck.lean`,
`kernelSamplePart`) to the kernel's verdicts vector by vector: the leg's agreement is a comparison
with these theorems, not with numbers written twice. -/
theorem vectors_kernel : vectors.all (fun v => v.run == v.expect) = true := by
  simp only [vectors, List.all_cons, List.all_nil, vAdd_kernel, vModSign_kernel, vDivZero_kernel,
    vNumEqVerify_kernel, vWithin_kernel, vNegZero_kernel, vPick_kernel, vRot_kernel, vDropEmpty_kernel,
    vAlt_kernel, vFromAltEmpty_kernel, vDepth_kernel, vIfElse_kernel, vNotifNested_kernel,
    vUnclosedIf_kernel, vEndifAlone_kernel, vVerifyFalse_kernel, vReturnSuffix_kernel, vFalseTop_kernel,
    vCat_kernel, vPushOnlyV1_kernel, vPushOnlyV2_kernel, vMinimalV1Mempool_kernel, vMinimalV2Mempool_kernel,
    vMinimalV1Block_kernel, beq_self_eq_true, Bool.and_true]

end BsvScript.Properties.KernelSample
