import BsvScript.Flags
import BsvScript.TxRules
import BsvScript.Properties.Eras
/-!
# BsvScript.Properties.P2SH

The P2SH history (#23; `docs/DESIGN.md` §2.2 step 9, §3; `docs/PARAMETERS.md` §2):
disabled for new outputs after Genesis, grandfathered for the outputs that
existed, each rule at its site of the reference:

* **the shape**: `IsP2SH` (`script.cpp:168–172`): 23 bytes, `OP_HASH160 <20 bytes> OP_EQUAL`;
* **the flag**: `SCRIPT_VERIFY_P2SH`, consensus by height (`verify_script_flags.cpp:38–40`,
  `p2shHeight` 173,805 on mainnet, `chainparams.cpp:28`, `chainparams.cpp:1076`; in the block word from
  block 173,806 by the tip's-height convention, `flagWord_block_p2sh`), mandatory in every
  era (`standard.h:56`, `standard.h:63`), so in every mempool word a node derives with no
  `-promiscuousmempoolflags` word (`flagWord_mempool_p2sh`, its hypothesis `hp`); a promiscuous
  word REPLACES the mempool word (`verify_script_flags.cpp:19–25`) on a chain whose
  `RequireStandard()` is false (`validation.cpp:795–801`: stn, testnet and regtest,
  `chainparams.cpp:1271`, `:1416`, `:1527`; never mainnet, `:1121`), and one lacking P2SH or
  carrying `SCRIPT_UTXO_AFTER_GENESIS` takes the grandfathered evaluation below away on that
  node's mempool path (`derive_p2shCopy_grandfathered_mempool`); the block path never reads it;
* **the evaluation, pre-Genesis coins only** (`VerifyScript`, `2354–2356` the stack copy,
  `2380–2424` the block): the P2SH flag and the shape select the redeem script only when
  the UTXO was created before Genesis (`!(flags & SCRIPT_UTXO_AFTER_GENESIS)` at `2355`
  and `2383`); for a coin created after Genesis the same bytes are a plain script, a
  hash puzzle (`2358–2378`: `OP_HASH160 <h> OP_EQUAL` on whatever the unlocking script
  pushed), whatever the spend era: **disabled for new outputs**; a coin created before
  Genesis keeps the P2SH evaluation when spent after Genesis and after Chronicle:
  **grandfathered**;
* **the outputs, a consensus rule**: `CheckRegularTransaction` (`validation.cpp:609–622`)
  rejects a transaction with a P2SH-shaped output once Genesis is active in the era
  (`bad-txns-vout-p2sh`, `DoS(100)`, `REJECT_INVALID`), so no regular transaction can
  create one after Genesis; `CheckCoinbase` (`validation.cpp:571–592`) has no such test, so a coinbase
  can (recorded on #23), and its output is then the hash puzzle above;
* **standardness (policy, outside the semantics)**: `Solver` classes a P2SH-shaped output
  `TX_NONSTANDARD` once Genesis is active (`script/standard.cpp:72–76`), so it is never
  relayed as standard; the pre-Genesis input check evaluates the redeem script for its
  sigops (`IsInputStandard`, `standard.cpp:376–425`, `MAX_P2SH_SIGOPS`);
* **the block-level sigop count** (`GetP2SHSigOpCount`, `validation.cpp:462–493`): the
  redeem script's sigops are counted for a pre-Genesis coin with the P2SH shape and
  skipped for a coin created after Genesis (`validation.cpp:481–483`); a block rule (#36), named here.

Every `[SRC]` is bitcoin-sv v1.2.2 at `879fc8b` (`docs/PROVENANCE.md`); a bare
number is a line of `src/script/interpreter.cpp`.
-/

namespace BsvScript.Properties
open BsvScript.Params BsvScript.Machine BsvScript.Numbers BsvScript.Tx BsvScript.TxRules

/-! ## The shape and the copy -/

/-- **The P2SH shape** (`IsP2SH`, `script.cpp:168–172`): `OP_HASH160`, a 20-byte push, `OP_EQUAL`. -/
theorem isP2SH_of_shape (h : Bytes) (hl : h.length = 20) :
    isP2SH ([Op.OP_HASH160, 0x14] ++ h ++ [Op.OP_EQUAL]) = true := by
  simp [isP2SH, hl, List.getElem?_append_right]

/-- The copy for the P2SH evaluation is taken exactly when the flag is set and the coin is
pre-Genesis (`2354–2356`), the two bits read ungated. -/
theorem p2shCopy_iff (f : Flags) : f.p2shCopy = true ↔ f.p2sh = true ∧ f.utxoAfterGenesis = false := by
  simp [Flags.p2shCopy]

/-- **No copy for a coin created after Genesis**, whatever the flag (`2355`). -/
theorem p2shCopy_of_utxoAfterGenesis (f : Flags) (h : f.utxoAfterGenesis = true) : f.p2shCopy = false := by
  simp [Flags.p2shCopy, h]

/-- STRICTENC-from-FORKID (`2315–2319`) touches neither bit of the copy test. -/
theorem forkAdjust_p2shCopy (f : Flags) : f.forkAdjust.p2shCopy = f.p2shCopy := by
  simp [Flags.forkAdjust, Flags.p2shCopy]; split_ifs <;> rfl

/-! ## Disabled for new outputs: the locking phase without the P2SH block -/

/-- The locking phase with the P2SH block absent (`2358–2378`, then `2430–2448`): the
locking script on the unlocking phase's stack, the final-stack rule, CLEANSTACK. What a
P2SH-shaped locking script is for a coin created after Genesis: a hash puzzle. -/
def plainPhase2 (exec : OpExec) (params : EvalParams) (ctx : Context) (flags0 : Flags) (scriptPubKey : Bytes)
    (stack : List Bytes) (memUsed : Nat) : Verdict :=
  let flags := flags0.gate ctx.version
  match evalScript exec (mkEnv params ctx flags0 none) scriptPubKey stack memUsed with
  | (.err e, _) => .invalid e
  | (.unimplemented o, _) => .unimplemented o
  | (.undefinedInReference f, _) => .undefinedInReference f
  | (.ok, st2) =>
    match st2.stack with
    | [] => .invalid .evalFalse
    | top :: _ =>
      if !castToBool top then .invalid .evalFalse
      else if flags0.cleanStackDemand then .invalid .invalidFlags
      else if flags.cleanStack && st2.stack.length != 1 then .invalid .cleanstack
      else .valid

/-- **P2SH is disabled without the copy** (`2380–2383`): when no stack copy was taken, the
redeem script is never deserialized or evaluated, the P2SH shape of the locking script is
never consulted, and the phase is the plain one. -/
theorem phase2_of_not_p2shCopy (exec : OpExec) (p : EvalParams) (ctx : Context) (f0 : Flags) (s l : Bytes)
    (stack : List Bytes) (mem : Nat) (h : f0.p2shCopy = false) :
    phase2 exec p ctx f0 s l stack mem = plainPhase2 exec p ctx f0 l stack mem := by
  unfold phase2 plainPhase2
  rcases hev : evalScript exec (mkEnv p ctx f0 none) l stack mem with ⟨o, st2⟩
  cases o with
  | ok =>
    cases hs : st2.stack with
    | nil => simp [h, hs]
    | cons top rest =>
      by_cases hb : castToBool top = true <;> simp [h, hs, hb]
  | err e => simp
  | undefinedInReference f => simp
  | unimplemented o => simp

/-- **A P2SH-shaped output created after Genesis is a hash puzzle** (`2355`, `2383` with the
UTXO marker set): the spend is judged as a plain script, the redeem script never runs. -/
theorem phase2_p2sh_disabled_postGenesis (exec : OpExec) (p : EvalParams) (ctx : Context) (f0 : Flags) (s l : Bytes)
    (stack : List Bytes) (mem : Nat) (hg : f0.utxoAfterGenesis = true) :
    phase2 exec p ctx f0 s l stack mem = plainPhase2 exec p ctx f0 l stack mem :=
  phase2_of_not_p2shCopy exec p ctx f0 s l stack mem (p2shCopy_of_utxoAfterGenesis f0 hg)

/-- `VerifyScript` with the P2SH block absent: `valid_flags`, STRICTENC from FORKID, the push-only
gate, the unlocking script, then `plainPhase2`. -/
def verifyScriptPlain (exec : OpExec) (params : EvalParams) (ctx : Context) (scriptSig scriptPubKey : Bytes) : Verdict :=
  if !params.flags.valid then .invalid .invalidFlags
  else
    let flags0 := params.flags.forkAdjust
    let flags := flags0.gate ctx.version
    let pushOnlyRequired :=
      flags.sigPushOnly &&
        ((flags.genesis && !flags.chronicle) || (flags.chronicle && !isMalleableTxnVersion ctx.version))
    if pushOnlyRequired && !isPushOnly scriptSig then .invalid .sigPushonly
    else
      match evalScript exec (mkEnv params ctx flags0 (some scriptPubKey)) scriptSig [] 0 with
      | (.err e, _) => .invalid e
      | (.unimplemented o, _) => .unimplemented o
      | (.undefinedInReference f, _) => .undefinedInReference f
      | (.ok, st1) => plainPhase2 exec params ctx flags0 scriptPubKey st1.stack st1.memUsed

/-- **Disabled for new outputs, at the verdict** (`2354–2356`, `2380–2383`): for a coin
created after Genesis, `VerifyScript` never evaluates a redeem script, whatever the locking
script's shape and whatever the P2SH flag and the spend era. -/
theorem verifyScript_p2sh_disabled_postGenesis (exec : OpExec) (p : EvalParams) (ctx : Context) (s l : Bytes)
    (hg : p.flags.utxoAfterGenesis = true) :
    verifyScript exec p ctx s l = verifyScriptPlain exec p ctx s l := by
  have h : p.flags.forkAdjust.p2shCopy = false := by
    rw [forkAdjust_p2shCopy]; exact p2shCopy_of_utxoAfterGenesis _ hg
  unfold verifyScript verifyScriptPlain
  dsimp only
  split_ifs <;> try rfl
  split <;> simp_all [phase2_of_not_p2shCopy exec p ctx _ s l _ _ h]

/-! ## Grandfathered: the copy under the derived words -/

/-- **A pre-Genesis coin keeps the P2SH copy when spent in any later era, on the block path**,
from block `p2shHeight + 1` on (`flagWord_block_p2sh`; the UTXO marker off, `policy.h:234–237`). -/
theorem derive_p2shCopy_grandfathered_block (cfg : NodeConfig) (h u : Nat) (h1 : 1 ≤ h)
    (hu : u < cfg.genesisActivationHeight) (hh : cfg.chain.p2shHeight + 1 ≤ h) :
    (derive cfg h u true).flags.forkAdjust.p2shCopy = true := by
  rw [forkAdjust_p2shCopy, derive_flags]
  have hp : (cfg.normalize.flagWord h u true).p2sh = true := by
    rw [flagWord_block_p2sh _ _ _ h1]; simp [NodeConfig.normalize]; exact hh
  have hg : (cfg.normalize.flagWord h u true).utxoAfterGenesis = false := by
    rw [flagWord_block_utxoAfterGenesis, normalize_protocolEra, protocolEra_genesisActive]
    simp; omega
  simp [Flags.p2shCopy, hp, hg]

/-- P2SH is in every mempool word a node derives with no promiscuous word (`hp`): it is mandatory in both eras
(`standard.h:56`, `standard.h:63`, `policy.h:191–197`). A `-promiscuousmempoolflags` word replaces the mempool word
on a chain that does not require standardness (`verify_script_flags.cpp:19–25`) and need not carry P2SH. -/
theorem flagWord_mempool_p2sh (cfg : NodeConfig) (h u : Nat) (hp : cfg.promiscuousMempoolFlags = none) :
    (cfg.flagWord h u false).p2sh = true := by
  cases hE : cfg.protocolEra h <;> cases hU : cfg.protocolEra u <;> cases hs : cfg.requireStandard <;>
    simp [NodeConfig.flagWord, hE, hU, hs, hp, mempoolScriptFlags, standardScriptVerifyFlags, mandatoryFlags,
          mandatoryPreChronicle, mandatoryPostChronicle, standardOnly, inputScriptVerifyFlags, Flags.union, Flags.none,
          Era.genesisActive, Era.chronicleActive]

/-- **A pre-Genesis coin keeps the P2SH copy on the mempool path too**, at every spend height, on a node with no
promiscuous word (`hp`). On a chain whose `RequireStandard()` is false a promiscuous word replaces the mempool word
(`verify_script_flags.cpp:21–25`): one carrying `SCRIPT_UTXO_AFTER_GENESIS`, or lacking P2SH, takes the copy away
on that node's mempool path (`interpreter.cpp:2354–2356`). -/
theorem derive_p2shCopy_grandfathered_mempool (cfg : NodeConfig) (h u : Nat) (hp : cfg.promiscuousMempoolFlags = none)
    (hu : u < cfg.genesisActivationHeight) :
    (derive cfg h u false).flags.forkAdjust.p2shCopy = true := by
  have hp' : cfg.normalize.promiscuousMempoolFlags = none := by rw [normalize_promiscuous]; exact hp
  rw [forkAdjust_p2shCopy, derive_flags]
  have hpp : (cfg.normalize.flagWord h u false).p2sh = true := flagWord_mempool_p2sh _ _ _ hp'
  have hg : (cfg.normalize.flagWord h u false).utxoAfterGenesis = false := by
    rw [flagWord_utxoAfterGenesis _ _ _ _ hp', normalize_genesisActivationHeight]
    simp; omega
  simp [Flags.p2shCopy, hpp, hg]

/-- **A coin created after Genesis never gets the copy, on either path** (`2355`). -/
theorem derive_p2shCopy_postGenesis_coin (cfg : NodeConfig) (h u : Nat) (c : Bool) (hp : cfg.promiscuousMempoolFlags = none)
    (hu : cfg.genesisActivationHeight ≤ u) :
    (derive cfg h u c).flags.forkAdjust.p2shCopy = false := by
  rw [forkAdjust_p2shCopy]
  apply p2shCopy_of_utxoAfterGenesis
  rw [derive_flags, flagWord_utxoAfterGenesis _ _ _ _ (by rw [normalize_promiscuous]; exact hp), normalize_genesisActivationHeight]
  simp; exact hu

/-! ## The outputs: a consensus rule of the transaction level -/

/-- **No regular transaction creates a P2SH-shaped output once Genesis is active**
(`CheckRegularTransaction`, `validation.cpp:609–622`: `bad-txns-vout-p2sh`, `DoS(100)`,
`REJECT_INVALID`; the era is the block's or the next block's, `validation.cpp:1031`): given the checks before it pass. -/
theorem checkRegularTransaction_p2sh_output (tx : Tx) (maxSigOps maxSize : Nat)
    (hcb : isCoinBase tx = false) (hcommon : checkTransactionCommon tx maxSigOps maxSize false = .ok ())
    (hp2sh : tx.outputs.any (fun o => isP2SH o.scriptPubKey) = true) :
    checkRegularTransaction tx maxSigOps maxSize false = .error .p2shOutput := by
  simp [checkRegularTransaction, hcb, hcommon, hp2sh, bind, Except.bind]
  all_goals rfl

end BsvScript.Properties
