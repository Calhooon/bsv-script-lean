import BsvChain.Depth
import BsvChain.Properties.Theorems

/-!
# Validation depth: what a connection checked (#73)

[M] 2026-10-14 (#73). These theorems describe the model decision,
its wiring premise, and successful model connections under named premises.
`blockScriptCalls` defines the ordinary input calls used by the statements.
Reference-run interpretations and observation scope are in
`docs/records/20261014-013925-s6-73-regtest-s3.md`.
[SRC] bitcoin-sv v1.2.3 at 6504a3aff65ba97c0f6c80962b033e35ecbfed4b:
src/validation.cpp:2864-2889,3379-3430,3482-3518,3678-3714,
src/block_index.cpp:75-150, src/init.cpp:324-333, src/warnings.cpp:36-96.
-/

namespace BsvChain.Properties
open BsvScript.Tx BsvScript.TxRules

/-! ## The decision -/

/-- [M] 2026-10-14, #73 (the decision with no assumed-valid hash). With the
assumed-valid setting zero, the decision is to run the scripts, for every
tree, every best header and every block. Premise in plain words: the node was
launched with `-assumevalid=0`, or on a network whose compiled value is zero
(regtest, STN) with no override.
[SRC] src/validation.cpp:3482-3483 at 6504a3af. -/
theorem scriptChecks_no_assumed_valid (params : ChainParams) (cfg : NodeConfig)
    (tree : HeaderTree) (best : Option BlockIndex) (i : BlockIndex)
    (h : cfg.assumeValid = 0) : scriptChecksRequired params cfg tree best i = true := by
  simp [scriptChecksRequired, h]

/-- [M] 2026-10-14, #73 (the assumed hash names no block of the index). When
the configured hash is not a block of the header tree, the decision is to run
the scripts. Premise in plain words: the lookup of the hash in the index finds
nothing, as on a node that has not yet received that header.
[SRC] src/validation.cpp:3491 at 6504a3af. -/
theorem scriptChecks_unknown_assumed_valid (params : ChainParams) (cfg : NodeConfig)
    (tree : HeaderTree) (best : Option BlockIndex) (i : BlockIndex)
    (h : tree.get cfg.assumeValid = none) : scriptChecksRequired params cfg tree best i = true := by
  unfold scriptChecksRequired
  split
  · rfl
  · simp [h]

/-- [M] 2026-10-14, #73 (what a skip needed). If the decision is to skip the
scripts of a block, then every conjunct of the reference held: a hash is
configured; it is a block of the index; the connecting block is on that
block's chain and on the best header's chain; the best header's work reaches
the floor; and the proof-equivalent time from the block to the best header
exceeds the two-week setting. Premise in plain words: the decision returned
`false`.
[SRC] src/validation.cpp:3482-3518 at 6504a3af. -/
theorem scriptChecks_skip_conjuncts (params : ChainParams) (cfg : NodeConfig)
    (tree : HeaderTree) (best : Option BlockIndex) (i : BlockIndex)
    (h : scriptChecksRequired params cfg tree best i = false) :
    cfg.assumeValid ≠ 0 ∧ ∃ assumed top, tree.get cfg.assumeValid = some assumed ∧ best = some top ∧
      onChainOf tree assumed i = true ∧ onChainOf tree top i = true ∧
      cfg.minimumChainWork ≤ top.work.toNat ∧
      ∃ seconds, blockProofEquivalentTime params top.work i.work top.header.bits = some seconds ∧
        (cfg.assumeValidMinWorkTimeSeconds : Int) < seconds := by
  unfold scriptChecksRequired at h
  split at h
  · cases h
  · rename_i hz
    refine ⟨by simpa using hz, ?_⟩
    cases ha : tree.get cfg.assumeValid with
    | none => simp [ha] at h
    | some assumed =>
      cases best with
      | none => simp [ha] at h
      | some top =>
        simp only [ha] at h
        split at h
        · rename_i hc
          simp only [Bool.and_eq_true, decide_eq_true_eq] at hc
          cases hs : blockProofEquivalentTime params top.work i.work top.header.bits with
          | none => simp [hs] at h
          | some seconds =>
            simp only [hs, decide_eq_false_iff_not, Int.not_le] at h
            exact ⟨assumed, top, rfl, rfl, hc.1.1, hc.1.2, hc.2, seconds, hs, h⟩
        · cases h

/-- [M] 2026-10-14, #73 (the second theorem: a block off the assumed chain is
never skipped). If the connecting block is not on the chain of the configured
block (it is no ancestor of the assumed-valid block, nor that block itself),
the decision is to run its scripts, whatever the best header, the work floor
and the burial. Premise in plain words: for the index entry the configured
hash names, the ancestor of that entry at the connecting block's height is not
the connecting block.
[SRC] src/validation.cpp:3494 at 6504a3af. -/
theorem scriptChecks_off_assumed_chain (params : ChainParams) (cfg : NodeConfig)
    (tree : HeaderTree) (best : Option BlockIndex) (i : BlockIndex)
    (h : ∀ assumed, tree.get cfg.assumeValid = some assumed → onChainOf tree assumed i = false) :
    scriptChecksRequired params cfg tree best i = true := by
  cases hr : scriptChecksRequired params cfg tree best i with
  | true => rfl
  | false =>
    obtain ⟨_, assumed, _, ha, _, hon, _⟩ := scriptChecks_skip_conjuncts params cfg tree best i hr
    rw [h assumed ha] at hon
    cases hon

/-- [D] 2026-10-14: the saturated quotient is never negative.
[SRC] src/block_index.cpp:146-149 at 6504a3af. -/
theorem saturateInt63_nonneg (r : Nat) : 0 ≤ saturateInt63 r := by
  unfold saturateInt63
  split <;> omega

/-- [D] 2026-10-14: proof-equivalent time toward a block of no more work is
never positive. [SRC] src/block_index.cpp:130-150 at 6504a3af. -/
theorem blockProofEquivalentTime_nonpos (params : ChainParams) (toWork fromWork : BitVec 256)
    (bits : BitVec 32) (seconds : Int) (h : toWork.toNat ≤ fromWork.toNat)
    (hs : blockProofEquivalentTime params toWork fromWork bits = some seconds) : seconds ≤ 0 := by
  unfold blockProofEquivalentTime at hs
  split at hs
  · cases hs
  · split at hs
    · omega
    · cases hs
      have := saturateInt63_nonneg ((fromWork.toNat - toWork.toNat) *
        (params.powTargetSpacing % 2 ^ 64) % 2 ^ 256 / blockProof bits)
      omega

/-- [M] 2026-10-14, #73 (burial needs strictly more work). A skip is never
decided for the best header itself or for a block with at least the best
header's work: the proof-equivalent time is then not positive, and the setting
is not negative. Premise in plain words: the connecting block's accumulated
work is at least the best header's.
[SRC] src/block_index.cpp:130-150 and src/validation.cpp:3511-3514
at 6504a3af. -/
theorem scriptChecks_unburied (params : ChainParams) (cfg : NodeConfig)
    (tree : HeaderTree) (top i : BlockIndex) (h : top.work.toNat ≤ i.work.toNat) :
    scriptChecksRequired params cfg tree (some top) i = true := by
  cases hr : scriptChecksRequired params cfg tree (some top) i with
  | true => rfl
  | false =>
    obtain ⟨_, _, top', _, hb, _, _, _, seconds, hs, hlt⟩ :=
      scriptChecks_skip_conjuncts params cfg tree (some top) i hr
    cases hb
    have hle := blockProofEquivalentTime_nonpos params top.work i.work top.header.bits seconds h hs
    have hn : (0 : Int) ≤ (cfg.assumeValidMinWorkTimeSeconds : Int) := Int.natCast_nonneg _
    omega

/-! ## The wiring -/

/-! [D] 2026-10-14, #73 scope: `DepthWired` is a premise discharged by an
explicit `withValidationDepth` call. These explicit wired calls satisfy the
depth-argument deliverable; automatic internal coupling is deferred.
`connectTip` is unchanged and does not compute the depth decision internally.
There is no context-indexed `Reachable` lift or history of past check decisions.
`bestHeader` is recomputed from insertion order; a stored best-header pointer
is deferred. Safe-mode forks are recomputed, without the cached fork-table
update history. Client switches use auxiliary `SafeModeClient` fields; the
webhook field is omitted, and integration into `NodeConfig` is deferred.
The proposed `onChainOf_ancestry` lemma was dropped; the reported kernel-recursion
cause is unverified. These are limitations of the model theorem scope.
-/

/-- [M] 2026-10-14, #73 (the hook is filled). The context built by
`withValidationDepth` uses the depth decision on every connection.
[SRC] src/validation.cpp:3482-3518 at 6504a3af. -/
theorem withValidationDepth_wired (ctx : ChainContext) : DepthWired ctx.withValidationDepth := by
  intro s i target
  rfl

/-- [M] 2026-10-14, #73 (the other decisions are untouched). Filling the depth
decision changes neither the BIP30 gate nor the execution schedule.
[SRC] src/validation.cpp:3070-3117,3421-3430 at 6504a3af. -/
theorem withValidationDepth_others (ctx : ChainContext) (s : ChainState) (i target : BlockIndex) :
    (ctx.withValidationDepth.connectionChecks s i target).bip30Required =
        (ctx.connectionChecks s i target).bip30Required ∧
      (ctx.withValidationDepth.connectionChecks s i target).queued =
        (ctx.connectionChecks s i target).queued := ⟨rfl, rfl⟩

/-- [M] 2026-10-14, #73. In the model, `DepthWired ctx` (`hw`) and
`assumeValid = 0` or absence of that hash from the current tree (`h`) imply
`checkScripts = true` for the supplied state, connecting index and target.
`withValidationDepth_wired` proves `hw` for the explicitly transformed context.
This is a conditional connection statement; `connectBlock_scripts_judged`
describes successful model connections under its additional premises.
[SRC] src/validation.cpp:3482-3491 at 6504a3af. -/
theorem s6_no_assumed_valid_checks_scripts (ctx : ChainContext) (hw : DepthWired ctx)
    (s : ChainState) (i target : BlockIndex)
    (h : ctx.cfg.assumeValid = 0 ∨ s.tree.get ctx.cfg.assumeValid = none) :
    (ctx.connectionChecks s i target).checkScripts = true := by
  rw [hw s i target]
  rcases h with h | h
  · exact scriptChecks_no_assumed_valid _ _ _ _ _ h
  · exact scriptChecks_unknown_assumed_valid _ _ _ _ _ h

/-- [M] 2026-10-14, #73 (the second theorem at the connection). On a wired
node, a connection that skips the scripts is the connection of a block on the
chain of the configured assumed-valid block: never of a block off that chain.
Premises in plain words: the context is wired (`hw`) and this connection was
made with `checkScripts = false` (`h`).
[SRC] src/validation.cpp:3491-3494 at 6504a3af. -/
theorem s6_skip_only_under_assumed_valid (ctx : ChainContext) (hw : DepthWired ctx)
    (s : ChainState) (i target : BlockIndex)
    (h : (ctx.connectionChecks s i target).checkScripts = false) :
    ∃ assumed, s.tree.get ctx.cfg.assumeValid = some assumed ∧ onChainOf s.tree assumed i = true := by
  rw [hw s i target] at h
  obtain ⟨_, assumed, _, ha, _, hon, _⟩ := scriptChecks_skip_conjuncts _ _ _ _ _ h
  exact ⟨assumed, ha, hon⟩

/-- [M] 2026-10-14, #73 (the whole machine under `-assumevalid=0`). A wired
context with the setting zero IS the context that forces `checkScripts` on:
the two are equal, so every transition taken under it (activation,
invalidation, reconsideration, the soft settings) is the transition that
judges scripts on each of its connections. Premises in plain words: the
context is wired (`hw`) and the setting is zero (`h`).
[SRC] src/validation.cpp:3482-3483 at 6504a3af. -/
theorem s6_no_assumed_valid_context (ctx : ChainContext) (hw : DepthWired ctx)
    (h : ctx.cfg.assumeValid = 0) :
    ctx = { ctx with connectionChecks := fun s i target =>
      { ctx.connectionChecks s i target with checkScripts := true } } := by
  have hf : ctx.connectionChecks = fun s i target =>
      { ctx.connectionChecks s i target with checkScripts := true } := by
    funext s i target
    have ht := s6_no_assumed_valid_checks_scripts ctx hw s i target (Or.inl h)
    cases hc : ctx.connectionChecks s i target with
    | mk b c q =>
      rw [hc] at ht
      simp only at ht
      subst ht
      rfl
  rw [← hf]

/-! ## What a connection with the scripts on judged -/

/-- [D] 2026-10-14: the queued calls of a run are, in body order, the oracle
keys of each transaction in the view immediately before it, when the scripts
are on and queued; no call is collected otherwise.
[SRC] src/validation.cpp:3379-3393,3413-3430 at 6504a3af. -/
theorem runBlockTransactions_calls (cfg : NodeConfig) (ctx : UtxoContext)
    (lists : FrozenLists) (oracle : ScriptOracle) (previous : Option HeaderChain)
    (checks : ConnectionChecks) (cap : Nat) (txs : List Tx) (s : UtxoSet)
    (total : Nat) (run : BlockRun)
    (h : runBlockTransactions cfg ctx lists oracle previous checks cap txs s total = .ok run) :
    run.calls = run.applications.flatMap (fun a =>
      if checks.checkScripts && checks.queued then blockScriptCalls a.before cfg ctx a.tx else []) := by
  induction txs generalizing s total run with
  | nil => simp [runBlockTransactions] at h; subst run; simp
  | cons tx rest ih =>
    simp only [runBlockTransactions, bind, Except.bind] at h
    cases hc : checkBlockInputs s cfg ctx previous tx total cap with
    | error e => simp [hc] at h
    | ok count =>
      simp only [hc] at h
      cases ha : applyTx s cfg ctx lists
          (if checks.checkScripts && !checks.queued then oracle else deferredBlockOracle) tx with
      | error e => rw [ha] at h; cases h
      | ok pair =>
        rcases pair with ⟨next, undo⟩
        simp only [ha] at h
        cases hr : runBlockTransactions cfg ctx lists oracle previous checks cap rest next count with
        | error e => simp [hr] at h
        | ok tail =>
          simp only [hr, pure, Except.pure, Except.ok.injEq] at h
          subst run
          have ht := ih next count tail hr
          simp only [List.flatMap_cons]
          rw [ht]

/-- [D] 2026-10-14: an accepted queue judged every one of its calls valid.
[SRC] src/validation.cpp:3678-3714 at 6504a3af. -/
theorem finishBlockScripts_valid (oracle : ScriptOracle) (calls : List ScriptCall)
    (h : finishBlockScripts oracle calls = .ok ()) : ∀ call ∈ calls, call.run oracle = .valid := by
  unfold finishBlockScripts at h
  induction calls with
  | nil => intro call hc; simp at hc
  | cons c cs ih =>
    simp only [List.forIn_cons, bind, Except.bind] at h
    cases hv : c.run oracle with
    | valid =>
      simp only [hv, pure, Except.pure] at h
      intro call hc
      rcases List.mem_cons.mp hc with rfl | hc
      · exact hv
      · exact ih h call hc
    | invalid e => simp [hv, throw, throwThe, MonadExceptOf.throw] at h
    | _ => simp [hv, queuedScriptResult] at h

/-- [M] 2026-10-14, #73 (what the scripts-on connection judged). For every
successful connection of a non-genesis block made with `checkScripts = true`,
under any parameters, configuration, operator lists, oracle and time: on the
serial schedule, every transaction of the body was applied in order under the
real script oracle, each in the view immediately before it; on the queued
schedule, the queue holds exactly the oracle keys of every transaction in body
order (none for the coinbase and for a confiscation transaction), and the
oracle judged every one of them valid before the block was published.
Premises in plain words: the connection succeeded (`hc`), the block is not the
network's genesis block (`nonGenesis`), and the decision was to run the
scripts (`hs`). This statement describes the serial applications and queued
oracle calls of `connectBlock` under those premises.
[SRC] src/validation.cpp:2864-2889,3379-3430,3678-3714 at 6504a3af. -/
theorem connectBlock_scripts_judged (view : CoinsView) (params : ChainParams) (cfg : NodeConfig)
    (block : Block) (previous : Option HeaderChain) (now : Int) (lists : FrozenLists)
    (oracle : ScriptOracle) (checks : ConnectionChecks) (out : ConnectedBlock)
    (hc : connectBlock view params cfg block previous now lists oracle checks = .ok out)
    (nonGenesis : block.header.hash.toNat ≠ params.hashGenesisBlock)
    (hs : checks.checkScripts = true) :
    ∃ ctx, prepareBlockConnection view params cfg block previous now checks = .ok (some ctx) ∧
      out.run.applications.map (·.tx) = block.transactions ∧
      (checks.queued = false →
        ApplicationsValid cfg ctx lists oracle view.coins out.run.applications out.view.coins) ∧
      (checks.queued = true →
        out.run.calls = out.run.applications.flatMap (fun a => blockScriptCalls a.before cfg ctx a.tx) ∧
        ∀ call ∈ out.run.calls, call.run oracle = .valid) := by
  obtain ⟨ctx, cb, rest, hp, _, _, _, _, _, _, hv, horder, _, _⟩ :=
    connected_shape view params cfg block previous now lists oracle checks out hc nonGenesis
  obtain ⟨hr, _, _⟩ := connectBlock_run view params cfg block previous now lists oracle checks ctx out hp hc
  refine ⟨ctx, hp, horder, ?_, ?_⟩
  · intro hq
    simpa [hs, hq] using hv
  · intro hq
    have hcalls := runBlockTransactions_calls cfg ctx lists oracle previous checks _ _ _ _ _ hr
    simp only [hs, hq, Bool.and_self, ↓reduceIte] at hcalls
    refine ⟨hcalls, ?_⟩
    have hfin : finishBlockScripts oracle out.run.calls = .ok () := by
      unfold connectBlock at hc
      simp only [hp, bind, Except.bind] at hc
      rw [hr] at hc
      simp only [Except.mapError] at hc
      cases hb : block.transactions.head? with
      | none => simp [hb] at hc
      | some cb' =>
        simp only [hb] at hc
        cases hf : checkCoinbaseAmount params ctx.height cb' out.run.fees with
        | error e => simp [hf] at hc
        | ok u =>
          cases u
          simp only [hf] at hc
          cases hfs : finishBlockScripts oracle out.run.calls with
          | error e => simp [hfs] at hc
          | ok u => cases u; rfl
    exact finishBlockScripts_valid oracle _ hfin

/-- [M] 2026-10-14, #73 (the tip connection under no assumed-valid hash). On a
wired node with no assumed-valid hash, a successful `connectTip` is a
successful block connection made with the scripts on. Premises in plain
words: the context is wired (`hw`), the hash is zero or unknown to the state's
tree (`h`), and the tip connection succeeded (`hc`).
[SRC] src/validation.cpp:3482-3518,4345-4404 at 6504a3af. -/
theorem s6_connectTip_checks_scripts (ctx : ChainContext) (hw : DepthWired ctx)
    (s t : ChainState) (lists : FrozenLists) (oracle : ScriptOracle) (i target : BlockIndex)
    (h : ctx.cfg.assumeValid = 0 ∨ s.tree.get ctx.cfg.assumeValid = none)
    (hc : connectTip s ctx lists oracle i target = .ok t) :
    ∃ block out, i.body = some block ∧
      connectBlock s.view ctx.params ctx.cfg block (headerContext s.tree i.parent) ctx.now
        (ctx.connectionLists s i target lists) oracle (ctx.connectionChecks s i target) = .ok out ∧
      (ctx.connectionChecks s i target).checkScripts = true := by
  cases hb : i.body with
  | none => simp [connectTip, hb] at hc
  | some block =>
    simp only [connectTip, hb, bind, Except.bind] at hc
    split at hc
    · cases hc
    · cases hr : connectBlock s.view ctx.params ctx.cfg block (headerContext s.tree i.parent)
        ctx.now (ctx.connectionLists s i target lists) oracle (ctx.connectionChecks s i target) with
      | error r => simp [hr] at hc
      | ok connected =>
        exact ⟨block, connected, rfl, hr, s6_no_assumed_valid_checks_scripts ctx hw s i target h⟩

/-! ## Safe mode changes no validity -/

/-- [M] 2026-10-14, #73 (safe mode refuses nothing without a warning). With
no triggering fork and `-testsafemode` off, no RPC command is refused.
Premises in plain words: the level is `none` and the test switch is off.
[SRC] src/init.cpp:324-333 and src/warnings.cpp:46-83 at 6504a3af. -/
theorem safeMode_none_refuses_nothing (client : SafeModeClient) (ibd ok : Bool)
    (h : client.testSafeMode = false) : safeModeRpcRefusal client .none ibd ok = none := by
  simp [safeModeRpcRefusal, safeModeRpcWarning, h]

/-- [M] 2026-10-14, #73 (a safe command is always answered). A command
registered with `okSafeMode` true is never refused, at any level; neither is
any command under `-disablesafemode`. Premise in plain words: the command is
registered safe, or the operator disabled the refusal.
[SRC] src/init.cpp:324-333 at 6504a3af. -/
theorem safeMode_safe_command_answered (client : SafeModeClient) (level : SafeModeLevel)
    (ibd ok : Bool) (h : ok = true ∨ client.disableSafeMode = true) :
    safeModeRpcRefusal client level ibd ok = none := by
  rcases h with h | h <;> simp [safeModeRpcRefusal, h]

/-- [M] 2026-10-14, #73 (a fork on the active chain triggers nothing). A tip
that is a block of the active chain has level `none`.
[SRC] src/safe_mode.cpp:67-70 at 6504a3af. -/
theorem forkSafeModeLevel_active (cfg : NodeConfig) (active : List (BitVec 256))
    (activeTip forkTip forkBase : BlockIndex) (h : active.contains forkTip.id = true) :
    forkSafeModeLevel cfg active activeTip forkTip forkBase = .none := by
  unfold forkSafeModeLevel
  simp only [h, ↓reduceIte]

end BsvChain.Properties
