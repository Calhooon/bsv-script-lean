import BsvScript.Impl.State
import BsvScript.Ops.Crypto
/-!
# BsvScript.Impl.Crypto: the crypto family over the implementation state (lean #50, slice (d))

`Ops.Crypto`'s hash opcodes (`interpreter.cpp:1402–1443`), `OP_CHECKSIG`/`OP_CHECKSIGVERIFY` (`1450–1508`) and
`OP_CHECKMULTISIG`/`OP_CHECKMULTISIGVERIFY` (`1510–1682`) restated over `Impl.IState`: the digests, the encoding
checks, the scriptCode's cleanup and the transaction checker are the spec's own functions, on the elements' bytes
(`Impl.Elem`, #143), and only the stack is reached through `State.lean`'s helpers, so the signature loop reads each
signature and key in one index and the arguments' pops are at the array's end. Each `…I_abs` theorem proves the
restated function computes what the spec's computes on every state it stands for (#50's design, its comment
5884618665).
-/

set_option autoImplicit false

namespace BsvScript.Impl
open BsvScript.Params BsvScript.Numbers BsvScript.Machine BsvScript.Hash BsvScript.Sighash BsvScript.Ops.Crypto
open IState

namespace Crypto

/-- `Ops.Crypto.scriptCodeOf` over the implementation state (`1472–1481`, `1568–1577`). -/
def scriptCodeOfI (env : Env) (s : IState) : Bytes :=
  match env.checksigData with
  | some lock => if env.params.flags.chronicle then s.codeSep ++ lock else s.codeSep
  | none => s.codeSep

/-- **`scriptCodeOf_abs`.** *What it says:* the implementation's scriptCode is the spec's. *What it
assumes:* nothing. *Why it matters:* the signature checks (#50). -/
theorem scriptCodeOf_abs (env : Env) (s : IState) : scriptCodeOf env s.abs = scriptCodeOfI env s := rfl

/-- `Ops.Crypto.hashOp` over the implementation state (`1402–1443`). -/
def hashOpI (env : Env) (op : Nat) (s : IState) : Except ScriptError IState := do
  needI s 1
  let p ← popElemI s
  pushElemI env p.2 (Elem.hashOp op p.1)

/-- **`hashOpI_abs`.** *What it says:* the implementation's hash opcodes compute what `Ops.Crypto.hashOp`
computes on the state it stands for. *What it assumes:* nothing. *Why it matters:* the family on the
implementation (#50). -/
theorem hashOpI_abs (env : Env) (op : Nat) (s : IState) :
    IState.abs <$> hashOpI env op s = hashOp env op s.abs := by
  unfold hashOpI hashOp
  simp only [need_abs, popElem_abs, ← Elem.toBytes_hashOp, pushElem_abs, map_bind, bind_map_left]

/-- **`pushBit_abs`.** *What it says:* the signature checks' result push, `[1]` or `[]`, is the push of the packed
`vchTrue` or the empty element. *What it assumes:* nothing. *Why it matters:* `OP_CHECKSIG`'s and
`OP_CHECKMULTISIG`'s results (#143). -/
theorem pushBit_abs (env : Env) (t : IState) (ok : Bool) :
    pushElem env t.abs (if ok then [1] else []) =
      IState.abs <$> pushElemI env t (if ok then Elem.vchTrue else Elem.empty) := by
  cases ok
  · exact pushElem_abs env t Elem.empty
  · exact pushElem_abs env t Elem.vchTrue

/-- `Ops.Crypto.checkSigOp` over the implementation state (`1450–1508`). -/
def checkSigOpI (env : Env) (op : Nat) (s : IState) : Except ScriptError IState := do
  needI s 2
  let sig := Elem.toBytes (topAtI s 1)
  let pubkey := Elem.toBytes (topAtI s 0)
  checkSignatureEncoding env sig
  checkPubKeyEncoding env pubkey
  let forkid := env.params.flags.enableSighashForkid
  let scriptCode := cleanupScriptCode (scriptCodeOfI env s) sig forkid
  let ok := env.ctx.checkSig sig pubkey scriptCode forkid
  if !ok && env.params.flags.nullFail && !sig.isEmpty && enforceNonMalleability env.params.flags env.ctx.version then
    throw .sigNullfail
  let p ← popElemI s
  let q ← popElemI p.2
  let s ← pushElemI env q.2 (if ok then Elem.vchTrue else Elem.empty)
  if op = Op.OP_CHECKSIGVERIFY then
    if ok then
      let t ← popElemI s
      pure t.2
    else throw .checksigverify
  else pure s

/-- **`checkSigOpI_abs`.** *What it says:* the implementation's `OP_CHECKSIG`/`OP_CHECKSIGVERIFY` computes
what `Ops.Crypto.checkSigOp` computes on the state it stands for. *What it assumes:* nothing. *Why it
matters:* the family on the implementation (#50). -/
theorem checkSigOpI_abs (env : Env) (op : Nat) (s : IState) :
    IState.abs <$> checkSigOpI env op s = checkSigOp env op s.abs := by
  unfold checkSigOpI checkSigOp
  simp only [need_abs, topAt_abs, scriptCodeOf_abs, popElem_abs, pushBit_abs, map_bind,
    bind_map_left, map_pure, throw_bind_except, map_throw_except, apply_ite (Functor.map IState.abs)]

/-- `Ops.Crypto.multisigLoop` over the implementation state (`1587–1634`): each signature and key read in one
index. -/
def multisigLoopI (env : Env) (s : IState) (scriptCode : Bytes) (forkid : Bool) :
    Nat → Nat → Nat → Nat → Except ScriptError Bool
  | isig, ikey, nSigs, nKeys =>
    if nSigs = 0 then .ok true
    else if nKeys < nSigs then .ok false
    else do
      let sig := Elem.toBytes (topAtI s isig)
      let pubkey := Elem.toBytes (topAtI s ikey)
      checkSignatureEncoding env sig                                            -- 1605–1609
      checkPubKeyEncoding env pubkey                                            -- 1611–1615
      let ok := env.ctx.checkSig sig pubkey scriptCode forkid                   -- 1618–1619
      if ok then multisigLoopI env s scriptCode forkid (isig + 1) (ikey + 1) (nSigs - 1) (nKeys - 1)
      else multisigLoopI env s scriptCode forkid isig (ikey + 1) nSigs (nKeys - 1)
  termination_by _ _ _ nKeys => nKeys

/-- **`multisigLoop_abs`.** *What it says:* the implementation's signature loop answers what
`Ops.Crypto.multisigLoop` answers on the state it stands for. *What it assumes:* nothing. *Why it matters:*
`OP_CHECKMULTISIG` on the implementation (#50). -/
theorem multisigLoop_abs (env : Env) (s : IState) (scriptCode : Bytes) (forkid : Bool) :
    ∀ nKeys isig ikey nSigs, multisigLoop env s.abs scriptCode forkid isig ikey nSigs nKeys =
      multisigLoopI env s scriptCode forkid isig ikey nSigs nKeys := by
  intro nKeys
  induction nKeys using Nat.strong_induction_on with
  | _ nKeys ih =>
    intro isig ikey nSigs
    rw [multisigLoop, multisigLoopI]
    by_cases h0 : nSigs = 0
    · simp only [h0, ↓reduceIte]
    · by_cases h1 : nKeys < nSigs
      · simp only [h0, h1, ↓reduceIte]
      · have hlt : nKeys - 1 < nKeys := by omega
        simp only [h0, h1, ↓reduceIte, topAt_abs, ih (nKeys - 1) hlt]

/-- The loop step of `ForInStep` read as the spec's. -/
def stepAbs : ForInStep IState → ForInStep State
  | .done s => .done s.abs
  | .yield s => .yield s.abs

/-- **`forIn_bind_abs`.** *What it says:* a `for` loop over a list whose body over the implementation state
stands for the spec's body, followed by continuations that agree, computes what the spec's loop and
continuation compute. *What it assumes:* the two bodies and the two continuations agree on every state.
*Why it matters:* `OP_CHECKMULTISIG`'s pops of its arguments (`1636–1653`) (#50). -/
theorem forIn_bind_abs {α : Type} (l : List Nat) (s : IState)
    (fI : Nat → IState → Except ScriptError (ForInStep IState))
    (fS : Nat → State → Except ScriptError (ForInStep State))
    (kI : IState → Except ScriptError α) (kS : State → Except ScriptError α)
    (hf : ∀ j s, stepAbs <$> fI j s = fS j s.abs) (hk : ∀ s, kI s = kS s.abs) :
    (forIn l s fI >>= kI) = (forIn l s.abs fS >>= kS) := by
  induction l generalizing s with
  | nil => simp only [List.forIn_nil, pure_bind, hk]
  | cons j l ih =>
    simp only [List.forIn_cons, ← hf, bind_assoc, bind_map_left]
    congr 1
    funext r
    cases r with
    | done x => simp only [stepAbs, pure_bind, hk]
    | yield x => simp only [stepAbs, ih]

/-- `Ops.Crypto.checkMultiSigOp` over the implementation state (`1510–1682`). -/
def checkMultiSigOpI (env : Env) (op : Nat) (s : IState) : Except ScriptError IState := do
  needI s 1
  let nKeysI ← Elem.readCount env (topAtI s 0)
  if nKeysI < 0 then throw .pubkeyCount
  let nKeys := nKeysI.toNat
  if env.params.limits.maxPubKeysPerMultiSig < nKeys then throw .pubkeyCount
  let s := { s with opCount := s.opCount + nKeys }
  if env.params.limits.maxOpsPerScript < s.opCount then throw .opCount
  needI s (nKeys + 2)
  let nSigsI ← Elem.readCount env (topAtI s (nKeys + 1))
  if nSigsI < 0 then throw .sigCount
  let nSigs := nSigsI.toNat
  if nKeys < nSigs then throw .sigCount
  needI s (nKeys + 2 + nSigs + 1)
  let forkid := env.params.flags.enableSighashForkid
  let scriptCode0 := scriptCodeOfI env s
  let scriptCode :=
    (List.range nSigs).foldl (fun sc k => cleanupScriptCode sc (Elem.toBytes (topAtI s (nKeys + 2 + k))) forkid)
      scriptCode0
  let ok ← multisigLoopI env s scriptCode forkid (nKeys + 2) 1 nSigs nKeys
  let total := nKeys + 2 + nSigs
  let nullfailBites := !ok && env.params.flags.nullFail && enforceNonMalleability env.params.flags env.ctx.version
  let mut sm := s
  for j in List.range total do
    let sigRegion := nKeys + 2 ≤ j
    if nullfailBites && sigRegion && !((topAtI sm 0).size == 0) then throw .sigNullfail
    let t ← popElemI sm
    sm := t.2
  let s1 := sm
  if s1.stack.isEmpty then throw .invalidStackOperation                         -- 1661–1662
  if env.params.flags.nullDummy && !((topAtI s1 0).size == 0) &&
      enforceNonMalleability env.params.flags env.ctx.version then
    throw .sigNulldummy
  let t2 ← popElemI s1
  let s3 ← pushElemI env t2.2 (if ok then Elem.vchTrue else Elem.empty)
  if op = Op.OP_CHECKMULTISIGVERIFY then
    if ok then
      let t4 ← popElemI s3
      pure t4.2
    else throw .checkmultisigverify
  else pure s3

/-- **`checkMultiSigOpI_abs`.** *What it says:* the implementation's `OP_CHECKMULTISIG`/
`OP_CHECKMULTISIGVERIFY` computes what `Ops.Crypto.checkMultiSigOp` computes on the state it stands for.
*What it assumes:* nothing. *Why it matters:* the family on the implementation (#50). -/
theorem checkMultiSigOpI_abs (env : Env) (op : Nat) (s : IState) :
    IState.abs <$> checkMultiSigOpI env op s = checkMultiSigOp env op s.abs := by
  unfold checkMultiSigOpI checkMultiSigOp
  simp only [need_abs, topAt_abs, scriptCodeOf_abs, multisigLoop_abs, abs_opCount, abs_withOpCount, map_bind,
    map_pure, throw_bind_except, map_throw_except, apply_ite (Functor.map IState.abs), ← Elem.readCount_eq]
  impl_descend
  all_goals first
    | rfl
    | (refine forIn_bind_abs _ _ _ _ _ _ (fun j s1 => ?_) (fun s1 => ?_)
       · simp only [topAt_abs, Elem.isEmpty_toBytes, popElem_abs, map_bind, bind_map_left, map_pure,
           map_throw_except, apply_ite (Functor.map stepAbs), stepAbs]
       · simp only [isEmpty_abs, topAt_abs, Elem.isEmpty_toBytes, popElem_abs, pushBit_abs,
           bind_map_left])

/-- `Ops.Crypto.exec` over the implementation state (`OP_CODESEPARATOR` is the loop's). -/
def execI : OpExecI := fun op _ env s =>
  if Op.OP_RIPEMD160 ≤ op && op ≤ Op.OP_HASH256 then some (hashOpI env op s)
  else if op = Op.OP_CHECKSIG || op = Op.OP_CHECKSIGVERIFY then some (checkSigOpI env op s)
  else if op = Op.OP_CHECKMULTISIG || op = Op.OP_CHECKMULTISIGVERIFY then some (checkMultiSigOpI env op s)
  else none

/-- **`Crypto.execI_refines`.** *What it says:* the implementation's crypto hook refines `Ops.Crypto.exec`.
*What it assumes:* nothing. *Why it matters:* the family's part of the machine's refinement (#50). -/
theorem execI_refines : Refines Ops.Crypto.exec execI := by
  intro op data env s
  unfold execI Ops.Crypto.exec
  split
  · simp only [Option.map_some, HookRI.abs_ofExcept, hashOpI_abs]
  · split
    · simp only [Option.map_some, HookRI.abs_ofExcept, checkSigOpI_abs]
    · split
      · simp only [Option.map_some, HookRI.abs_ofExcept, checkMultiSigOpI_abs]
      · rfl

/-- The opcodes the family's hook answers for: `execI`'s tests, which read the opcode alone. The machine's
dispatcher asks this first, so the state goes to one family only and its array stays unshared (#50). -/
def owns (op : Nat) : Bool :=
  (Op.OP_RIPEMD160 ≤ op && op ≤ Op.OP_HASH256) || (op = Op.OP_CHECKSIG || op = Op.OP_CHECKSIGVERIFY) ||
    (op = Op.OP_CHECKMULTISIG || op = Op.OP_CHECKMULTISIGVERIFY)

/-- **`Crypto.execI_of_not_owns`.** *What it says:* the hook answers `none` for an opcode it does not own. *What
it assumes:* `owns op = false`. *Why it matters:* the machine's dispatcher (#50). -/
theorem execI_of_not_owns (op : Nat) (data : Bytes) (env : Env) (s : IState) (h : owns op = false) :
    execI op data env s = none := by
  unfold execI
  unfold owns at h
  simp_all

/-- **`Crypto.isSome_execI`.** *What it says:* the hook answers for every opcode it owns. *What it assumes:*
`owns op = true`. *Why it matters:* the machine's dispatcher (#50). -/
theorem isSome_execI (op : Nat) (data : Bytes) (env : Env) (s : IState) (h : owns op = true) :
    (execI op data env s).isSome = true := by
  unfold execI
  unfold owns at h
  split_ifs <;> simp_all

end Crypto

end BsvScript.Impl
