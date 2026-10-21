import BsvScript.Eval
import BsvScript.Ops.Crypto
/-!
# BsvScript.Properties.Basic

The opening properties (#16; `docs/DESIGN.md` §9). Each theorem carries an
explainer (what it says, what it assumes, why it matters) and is listed in
`lean/AxiomCheck.lean`, so the tripwire's axiom check covers it.

**P1** canonicality and **P2** `castToBool` with the width lemma are T1–T6 of
`BsvScript.Numbers` (#7). **P5** parameter separation is `Flags.derive_consensus_separation`
(#13: on the block path `Params.derive` reads only a node's consensus fields) with its verdict-level
corollary `Flags.verifyScript_consensus_separation`. Determinism and termination are by construction (a total function;
`termination_by` on the remaining bytes, `Machine.loop`); `Eval.verifyScript_deterministic`
states the former.
-/

namespace BsvScript.Properties
open BsvScript.Params BsvScript.Machine BsvScript.Numbers BsvScript.Tx

/-! ## P3: gate non-interference -/

/-- **P3, the main form.** *What it says:* `verifyScript` reads the flag word only
through six projections: `valid` of the word, and, of the FORKID-adjusted word,
the version-gated word (`Flags.gate`), `strictDer`, `utxoEra`, `p2shCopy` and
`cleanStackDemand`; two parameter records that agree on the limits and on those
six verify every spend identically. *What it assumes:* nothing beyond the six
equalities. *Why it matters:* it is the whole flag-word dependence of the
semantics in one place; the version gate's non-interference below is a
corollary, and #13's derivation of the word has exactly six things to get
right. -/
theorem verifyScript_congr (exec : OpExec) (p p' : EvalParams) (ctx : Context) (s l : Bytes)
    (hlim : p.limits = p'.limits) (hvalid : p.flags.valid = p'.flags.valid)
    (hgate : p.flags.forkAdjust.gate ctx.version = p'.flags.forkAdjust.gate ctx.version)
    (hder : p.flags.forkAdjust.strictDer = p'.flags.forkAdjust.strictDer)
    (hera : p.flags.forkAdjust.utxoEra = p'.flags.forkAdjust.utxoEra)
    (hcopy : p.flags.forkAdjust.p2shCopy = p'.flags.forkAdjust.p2shCopy)
    (hclean : p.flags.forkAdjust.cleanStackDemand = p'.flags.forkAdjust.cleanStackDemand) :
    verifyScript exec p ctx s l = verifyScript exec p' ctx s l := by
  unfold verifyScript phase2 mkEnv
  simp only [hlim, hvalid, hgate, hder, hera, hcopy, hclean]

/-- The seven version-gated bits of a word, set arbitrarily (MINIMALDATA,
MINIMALIF, NULLFAIL, NULLDUMMY, LOW_S, SIGPUSHONLY, CLEANSTACK). -/
def _root_.BsvScript.Params.Flags.setGated (f : Flags) (md mi nf nd ls sp cs : Bool) : Flags :=
  { f with minimalData := md, minimalIf := mi, nullFail := nf, nullDummy := nd,
           lowS := ls, sigPushOnly := sp, cleanStack := cs }

/-- **P3 (gate non-interference, the CLAUDE.md gotcha as a theorem).** *What it
says:* when the version gate is off (`SCRIPT_CHRONICLE` set and the version
above 1, `EnforceNonMalleability`, `interpreter.cpp:40–44`), the seven gated
bits may be set to anything and every spend verifies the same. *What it
assumes:* two side conditions found at the reference's ungated reads: DERSIG,
STRICTENC or FORKID is set (LOW_S also selects the strict DER shape, `275–280`;
under FORKID, STRICTENC is forced, `2315–2319`) and P2SH is set (CLEANSTACK
without P2SH is an invalid word, `2432–2435`); the mainnet word satisfies both
(STRICTENC and P2SH are mandatory, `standard.h:62–68`). *Why it matters:* under a
word with `SCRIPT_CHRONICLE` that meets the two side conditions, none of the seven
gated bits reaches the verdict of a version-2 spend, whatever their values: the
policy bits MINIMALDATA, NULLDUMMY and CLEANSTACK (the standard set only,
`policy.h:182–189`), the consensus-by-height bits LOW_S and NULLFAIL
(`verify_script_flags.cpp:65–69`) and SIGPUSHONLY (`:71–75`), and MINIMALIF, which
the node never sets at the pin. The statement compares one word with its gated
variants under one limits record, so it is not the comparison of a relaying node
with a mining node: the relay word also carries DISCOURAGE_UPGRADABLE_NOPS, and the
two paths' limits differ. That comparison is
`Params.verifyScript_relay_block_version2`, which carries the NOPs bit over and
leaves the limits a free parameter. -/
theorem gate_noninterference (exec : OpExec) (limits : Limits) (f : Flags) (ctx : Context) (s l : Bytes)
    (md mi nf nd ls sp cs : Bool)
    (hoff : enforceNonMalleability f ctx.version = false)
    (hA : (f.derSig || f.strictEnc || f.enableSighashForkid) = true) (hB : f.p2sh = true) :
    verifyScript exec { flags := f.setGated md mi nf nd ls sp cs, limits } ctx s l
      = verifyScript exec { flags := f, limits } ctx s l := by
  obtain ⟨hc, hv⟩ : f.chronicle = true ∧ isMalleableTxnVersion ctx.version = true := by
    simpa [enforceNonMalleability] using hoff
  cases f with
  | mk p2sh strictEnc derSig lowS nullDummy sigPushOnly minimalData discourageUpgradableNops cleanStack
      checkLockTimeVerify checkSequenceVerify minimalIf nullFail compressedPubKeyType enableSighashForkid
      genesis utxoAfterGenesis chronicle utxoAfterChronicle =>
    simp only at hc hB
    simp only [Bool.or_eq_true] at hA
    subst hc
    subst hB
    apply verifyScript_congr <;>
      (rcases hA with (hA | hA) | hA <;> subst hA <;> (try cases enableSighashForkid) <;>
       simp [Flags.setGated, Flags.forkAdjust, Flags.gate, Flags.valid, Flags.strictDer, Flags.utxoEra,
             Flags.p2shCopy, Flags.cleanStackDemand, enforceNonMalleability, hv])

/-! ## P4: phase crossing -/

/-- **P4 (phase crossing).** *What it says:* of the state the unlocking phase
leaves, the locking phase and everything after it (`Machine.phase2`) reads the
main stack and the memory counter alone: for the same parameters, context, word
and scripts, two states with the same stack and counter give the same verdict
(the alt stack, the conditional tracker, the op count, the separator position are
dropped at the phase boundary). It does not say the verdict depends on the
unlocking script only through that stack: `phase2` also reads the unlocking
script's bytes, since the P2SH branch re-reads `scriptSig.IsPushOnly()` after the
locking phase (`2382–2388`). *What it assumes:* nothing; the scripts `s` and `l`
are held fixed, so the statement is `phase2`'s congruence in its stack and counter
arguments, proven by a rewrite. *Why it matters:* `docs/DESIGN.md` §1.3's
statement of what crosses the phase boundary (`VerifyScript`, `2354–2372`: the
locking script runs on the stack the unlocking script left, the P2SH copy is of
that stack) is the type of `phase2`: beside the parameters, the context, the word
and the scripts, it takes that stack and that counter and nothing else of the
unlocking phase; this theorem is its congruence. -/
theorem phase2_stack_mem_only (exec : OpExec) (p : EvalParams) (ctx : Context) (f0 : Flags) (s l : Bytes)
    (st st' : State) (hs : st.stack = st'.stack) (hm : st.memUsed = st'.memUsed) :
    phase2 exec p ctx f0 s l st.stack st.memUsed = phase2 exec p ctx f0 s l st'.stack st'.memUsed := by
  rw [hs, hm]

/-! ## The cheap and real ones -/

/-- **`opreturn_suffix`.** *What it says:* the loop never reads the bytes after a
top-level `OP_RETURN`: for a post-Genesis UTXO, with no enclosing conditional,
the loop returns at the `OP_RETURN` whatever follows it (`interpreter.cpp:858–861`:
`return SCRIPT_ERR_OK;` from `EvalScript`), so nothing after it is parsed,
counted or executed. *What it assumes:* the UTXO is post-Genesis and the tracker
is empty (so the `OP_RETURN` is top-level and executing). *Why it matters:* it
says what the loop does with the suffix and no more; the suffix still bears on
the verdict. Its bytes count toward the script size, checked on the whole script
before the loop runs (`429–430`, `Machine.evalScript`), and a signature checked
earlier in the same script signs them, its scriptCode running from the last
separator to the script's end (`1473`, `1569`); post-Chronicle, a signature check
in the unlocking script also signs the whole locking script (`1475–1481`). So a
change to the suffix can change the verdict. -/
theorem opreturn_suffix (exec : OpExec) (env : Env) (st : State) (rest rest' : Bytes)
    (hg : env.utxoAfterGenesis = true) (htop : st.cond.conditions = []) (hact : st.cond.falseCount = 0) :
    loop exec env (Op.OP_RETURN :: rest) st = loop exec env (Op.OP_RETURN :: rest') st := by
  rw [loop.eq_2, loop.eq_2]
  simp [getOpTail, execStep, execFlow, Cond.isActive, Cond.empty, isOpcodeDisabled, hg, htop, hact,
        Op.OP_RETURN, Op.OP_PUSHDATA4, Op.OP_16, Op.OP_1NEGATE, Op.OP_1, Op.OP_NOP, Op.OP_CHECKLOCKTIMEVERIFY,
        Op.OP_CHECKSEQUENCEVERIFY, Op.OP_VER, Op.OP_NOP1, Op.OP_NOP9, Op.OP_NOP10, Op.OP_VERIF, Op.OP_VERNOTIF,
        Op.OP_IF, Op.OP_NOTIF, Op.OP_ELSE, Op.OP_ENDIF, Op.OP_VERIFY, Op.OP_CODESEPARATOR, Op.OP_2MUL, Op.OP_2DIV]

/-- **`checksig_empty_sig`.** *What it says:* the transaction checker with an
empty signature is false without touching the curve (`2145–2147`). *What it
assumes:* nothing. *Why it matters:* an empty signature is the canonical "this
check fails" element of multisig scripts; the equation, the digest and the key
decoding are never reached for it, so no property of the curve is involved in
that verdict (and NULLFAIL exempts it: the refusal `1493–1496` is reached only
through the `!vchSig.empty()` conjunct of `1491`, and in `OP_CHECKMULTISIG` the
refusal `1643–1646` only through that of `1641`). -/
theorem checksig_empty_sig (tx : Tx) (nIn amount : Nat) (pk sc : Bytes) (e : Bool) :
    Ops.Crypto.txCheckSig tx nIn amount [] pk sc e = false := by
  simp [Ops.Crypto.txCheckSig]

end BsvScript.Properties
