import BsvChain.Properties.Reachable

/-!
# The orphaned branch reached by the machine's own transitions (#68, G2)

[M] 2026-10-13 (#68). A concrete run of the executable transitions on
the regtest network from its actual genesis block: accept and activate
genesis; mine and activate block 1a, whose body holds the transaction T; mine
the competitor 1b on genesis; extend it with 2b; activate. The kernel checks
the run (`decide +kernel` on the definitions, no compiled code, no
`native_decide`): the active chain is genesis, 1b, 2b, and T's path verifies
against 1a's retained header while T is in no active block. Near genesis no
output is mature (coinbase maturity 100), so T is 1a's coinbase and its path
is the one-leaf empty branch. A second run invalidates 1a after its
activation: T leaves the active chain and the selected work decreases, so the
charter's "only when a chain of more work is connected" is false in the
machine. The script oracle is never called (no block spends an input).
Every height, time and nonce below is [D] synthetic input; the nonces were
found by compiled search and are checked by the kernel's proof-of-work test.
[M] 2026-10-14, #120: the kernel reduces the run only in the
two `decide +kernel` checks (and the genesis block's hash in
`staleRunGenesis_hash`). The three run states are plain definitions and the
reachability proof goes through one step stated on `staleRunActivate`; [D]
read from the measurements, not the kernel's source: the kernel then matches
each state by unfolding its name; [M] the landed form (abbreviations, the constructors' own indices) took 95 to
203 s of kernel time on the box and this one under 0.1 s. The charter
refutation closes its equation by the pair's eta (34 s by `rfl`, under 0.2 s
now). The module is its own Lake library, `StaleRunCheck`, outside
`lake build BsvChain`; the axioms leg of `tools/check.sh` builds it.
[SRC] bitcoin-sv v1.2.3 at 6504a3aff65ba97c0f6c80962b033e35ecbfed4b:
src/chainparams.cpp:33-90,1511-1514, src/validation.cpp:4913-5330,6134-6395,
src/consensus/merkle.cpp:291-310.
-/

namespace BsvChain.Properties
open BsvScript.Numbers BsvScript.Tx BsvScript.TxRules BsvScript.Hash

/-- [SRC] 2026-10-13: the genesis coinbase: version 1, the null input with the
scriptSig pushing 486604799, 4 and the Times headline, one 50 BTC output to the
pinned key with OP_CHECKSIG, lock time 0.
src/chainparams.cpp:33-53,78-90 at 6504a3af. -/
def staleRunGenesisCoinbase : Tx :=
  ⟨1, [⟨List.replicate 32 0, 0xffffffff, [0x04, 0xff, 0xff, 0x00, 0x1d, 0x01, 0x04, 0x45, 0x54, 0x68, 0x65, 0x20, 0x54, 0x69, 0x6d, 0x65, 0x73, 0x20, 0x30, 0x33, 0x2f, 0x4a, 0x61, 0x6e, 0x2f, 0x32, 0x30, 0x30, 0x39, 0x20, 0x43, 0x68, 0x61, 0x6e, 0x63, 0x65, 0x6c, 0x6c, 0x6f, 0x72, 0x20, 0x6f, 0x6e, 0x20, 0x62, 0x72, 0x69, 0x6e, 0x6b, 0x20, 0x6f, 0x66, 0x20, 0x73, 0x65, 0x63, 0x6f, 0x6e, 0x64, 0x20, 0x62, 0x61, 0x69, 0x6c, 0x6f, 0x75, 0x74, 0x20, 0x66, 0x6f, 0x72, 0x20, 0x62, 0x61, 0x6e, 0x6b, 0x73], 0xffffffff⟩], [⟨5000000000, [0x41, 0x04, 0x67, 0x8a, 0xfd, 0xb0, 0xfe, 0x55, 0x48, 0x27, 0x19, 0x67, 0xf1, 0xa6, 0x71, 0x30, 0xb7, 0x10, 0x5c, 0xd6, 0xa8, 0x28, 0xe0, 0x39, 0x09, 0xa6, 0x79, 0x62, 0xe0, 0xea, 0x1f, 0x61, 0xde, 0xb6, 0x49, 0xf6, 0xbc, 0x3f, 0x4c, 0xef, 0x38, 0xc4, 0xf3, 0x55, 0x04, 0xe5, 0x1e, 0xc1, 0x12, 0xde, 0x5c, 0x38, 0x4d, 0xf7, 0xba, 0x0b, 0x8d, 0x57, 0x8a, 0x4c, 0x70, 0x2b, 0x6b, 0xf1, 0x1d, 0x5f, 0xac]⟩], 0⟩

/-- [SRC] 2026-10-13: the regtest genesis block, CreateGenesisBlock(1296688602,
2, 0x207fffff, 1, 50 * COIN). src/chainparams.cpp:54-62,1511 at 6504a3af. -/
def staleRunGenesis : Block :=
  ⟨⟨1, 0, BitVec.ofNat 256 (leNat (BsvScript.Sighash.txid staleRunGenesisCoinbase)), 1296688602, 0x207fffff, 2⟩,
    [staleRunGenesisCoinbase]⟩

/-- [SRC] 2026-10-13: the block reproduces the network's pinned genesis hash,
checked by the kernel. src/chainparams.cpp:1511-1514 at 6504a3af. -/
theorem staleRunGenesis_hash :
    staleRunGenesis.header.hash.toNat = ChainParams.regtest.hashGenesisBlock := by
  decide +kernel

/-- [D] 2026-10-13: the run's context: regtest, the census defaults, an
explicit time later than every block's timestamp, byte-only accounting.
[SRC] src/chainparams.cpp:1460-1514 and src/validation.cpp:5956-5959 at 6504a3af. -/
def staleRunContext : ChainContext :=
  { params := .regtest, cfg := NodeConfig.defaults, now := 1296700000, bucketTime := 0,
    accounting := .byteOnly, disconnectAccounting := ⟨0, fun _ => 0⟩,
    innerUsage := fun _ => 0, completionEvent := fun i => i.tieRank }

/-- [D] 2026-10-13: a coinbase with a two-byte scriptSig tagged by its block
and one 50 BTC OP_TRUE output; BIP34 is not active on regtest at these heights.
[SRC] src/validation.cpp:5823-5827,6085-6099 and src/chainparams.cpp:1461-1463 at 6504a3af. -/
def staleRunCoinbase (tag : Nat) : Tx :=
  ⟨1, [⟨List.replicate 32 0, 0xffffffff, [1, tag], 0xffffffff⟩], [⟨5000000000, [0x51]⟩], 0⟩

/-- [D] 2026-10-13: a one-transaction block on a parent with the regtest bits.
[SRC] src/primitives/block.h:26-107 at 6504a3af. -/
def staleRunBlock (parent : BitVec 256) (tag time nonce : Nat) : Block :=
  ⟨⟨1, parent, BitVec.ofNat 256 (leNat (BsvScript.Sighash.txid (staleRunCoinbase tag))),
    BitVec.ofNat 32 time, 0x207fffff, BitVec.ofNat 32 nonce⟩, [staleRunCoinbase tag]⟩

/-- [D] 2026-10-13: block 1a on genesis; its coinbase is T.
[SRC] src/validation.cpp:6238-6395 at 6504a3af. -/
def staleRun1a : Block := staleRunBlock staleRunGenesis.header.hash 1 1296689202 1

/-- [D] 2026-10-13: the competitor 1b on genesis.
[SRC] src/validation.cpp:6238-6395 at 6504a3af. -/
def staleRun1b : Block := staleRunBlock staleRunGenesis.header.hash 2 1296689203 1

/-- [D] 2026-10-13: the extension 2b on 1b.
[SRC] src/validation.cpp:6238-6395 at 6504a3af. -/
def staleRun2b : Block := staleRunBlock staleRun1b.header.hash 3 1296689802 0

/-- [D] 2026-10-13: activation with the empty operator lists, the landed
evaluator as oracle and a budget of eight steps.
[SRC] src/validation.cpp:4913-5130 at 6504a3af. -/
def staleRunActivate (s : ChainState) : ChainState :=
  (activateBestChain s staleRunContext .empty evalOracle 8).1

/-- [D] 2026-10-13: genesis accepted and activated, 1a accepted and activated.
[SRC] src/validation.cpp:6509-6525 at 6504a3af. -/
def staleRunWith1a : ChainState :=
  staleRunActivate (acceptBlock (staleRunActivate (acceptBlock {} staleRunContext staleRunGenesis 0 true).1)
    staleRunContext staleRun1a 1 true).1

/-- [D] 2026-10-13: then 1b and 2b accepted and the chain activated.
[SRC] src/validation.cpp:6509-6525 at 6504a3af. -/
def staleRunFinal : ChainState :=
  staleRunActivate (acceptBlock (acceptBlock staleRunWith1a staleRunContext staleRun1b 2 true).1
    staleRunContext staleRun2b 3 true).1

/-- [D] 2026-10-13: the run is a sequence of the machine's own transitions.
[SRC] src/validation.cpp:4913-5130,6238-6395 at 6504a3af. -/
theorem staleRunFinal_reachable : Reachable staleRunWith1a ∧ Reachable staleRunFinal :=
  have step : ∀ {s : ChainState} (b : Block) (rank : Nat), Reachable s →
      Reachable (staleRunActivate (acceptBlock s staleRunContext b rank true).1) :=
    fun b rank h => .activate _ _ _ _ (.block _ b rank true h)
  have h1 : Reachable staleRunWith1a := step staleRun1a 1 (step staleRunGenesis 0 .empty)
  ⟨h1, step staleRun2b 3 (.block _ staleRun1b 2 true h1)⟩

/-- [D] 2026-10-13: the executable facts of a stale witness for the
transaction at 1a's hash: 1a is retained and inactive with a one-transaction
body whose header encodes as the index's, whose transaction has T's identifier,
whose empty path verifies against the index's merkle root, and whose identifier
is in no active body.
[SRC] src/consensus/merkle.cpp:291-310 and src/validation.cpp:4117 at 6504a3af. -/
def staleFacts (s : ChainState) (hash : BitVec 256) (id : Bytes) : Bool :=
  match s.tree.get hash with
  | none => false
  | some i =>
    match i.body with
    | none => false
    | some b =>
      match b.transactions with
      | [t] =>
        !s.active.contains i.id && i.header.encode == b.header.encode &&
        BsvScript.Sighash.txid t == id &&
        verifyPath (BsvScript.Sighash.txid t) [] 0 (headerWordBytes 32 i.header.merkleRoot.toNat) &&
        s.active.all (fun h => match (s.tree.get h).bind (·.body) with
          | none => true
          | some b' => !(b'.transactions.map BsvScript.Sighash.txid).contains (BsvScript.Sighash.txid t))
      | _ => false

/-- [D] 2026-10-13: the executable stale facts mean the propositions: a stale
path for the retained transaction, which is in no active block.
[SRC] src/consensus/merkle.cpp:291-310 and src/validation.cpp:4117 at 6504a3af. -/
theorem staleFacts_sound (s : ChainState) (hash : BitVec 256) (id : Bytes)
    (h : staleFacts s hash id = true) :
    ∃ i tx, StalePath s i tx [] 0 ∧ ¬ ActiveTransaction s.tree s.active tx ∧
      BsvScript.Sighash.txid tx = id := by
  unfold staleFacts at h
  split at h
  · cases h
  · rename_i i hi
    obtain ⟨_, hid⟩ := get_mem _ _ _ hi
    split at h
    · cases h
    · rename_i b hb
      split at h
      · rename_i t ht
        simp only [Bool.and_eq_true, Bool.not_eq_true', beq_iff_eq, List.all_eq_true] at h
        obtain ⟨⟨⟨⟨hinactive, henc⟩, htid⟩, hpath⟩, hall⟩ := h
        refine ⟨i, t, ⟨?_, b, hid ▸ hi, hb, ?_, by simp [ht], hpath⟩, ?_, htid⟩
        · simpa using hinactive
        · have hr := header_codec_roundtrip i.header
          rw [henc, header_codec_roundtrip] at hr
          exact (Option.some.inj hr).symm
        · rintro ⟨h', hm, block, hblk, htx⟩
          have := hall h' hm
          rw [hblk] at this
          simp at this
          exact this t htx rfl
      · cases h

/-- [D] 2026-10-13: the run's expected active chain and stale witness, one
executable fact for the kernel.
[SRC] src/validation.cpp:4913-5130 at 6504a3af. -/
def staleRunChecks : Bool :=
  staleRunFinal.active == [staleRunGenesis.header.hash, staleRun1b.header.hash, staleRun2b.header.hash] &&
    staleFacts staleRunFinal staleRun1a.header.hash (BsvScript.Sighash.txid (staleRunCoinbase 1))

/-- [D] 2026-10-13: the kernel evaluates the run. [M] the kernel check takes
minutes on the box (#120's record states the wall and the memory).
[SRC] src/validation.cpp:4913-5130,6238-6395 at 6504a3af. -/
theorem staleRunChecks_true : staleRunChecks = true := by decide +kernel

/-- [M] 2026-10-13, #68 G2 (the orphaned-branch class reached by the machine's
own transitions). There is a reachable state, the run from the regtest genesis
that mines T in block 1a, mines the competitor 1b, extends it with 2b and
activates, whose active chain is genesis, 1b, 2b, and in which a transaction
with T's identifier has a path that verifies against 1a's retained stale
header (StalePath) while it is in no active block. No premise: the run is
concrete and kernel-checked. T is block 1a's coinbase; its body holds one
transaction, the body-derived path is `[]`, and verification is root equals
txid. Near genesis no spendable output has reached the pinned maturity.
The path carries no positional information by itself and is not a node-emitted
proof: #75 measured RPC -5 for this body form. The non-degenerate class with
a multi-transaction body and a non-empty path is distinct and owed.
[SRC] src/validation.cpp:2620-2626, src/consensus/merkle.cpp:291-310 and
src/rpc/rawtransaction.cpp:2302-2306 at 6504a3af.
With #65's universal refutation
(`stale_path_does_not_entail_active`, over raw states) this places the
orphaned-proof class among reachable states: path validity against a header
says nothing about the active chain unless the header is on it.
[SRC] src/consensus/merkle.cpp:291-310, src/validation.cpp:4117,4913-5130,6238-6395
and src/chainparams.cpp:1511-1514 at 6504a3af. -/
theorem s6_stale_path_reachable :
    Reachable staleRunFinal ∧
      staleRunFinal.active = [staleRunGenesis.header.hash, staleRun1b.header.hash, staleRun2b.header.hash] ∧
      ∃ i tx, StalePath staleRunFinal i tx [] 0 ∧
        ¬ ActiveTransaction staleRunFinal.tree staleRunFinal.active tx ∧
        BsvScript.Sighash.txid tx = BsvScript.Sighash.txid (staleRunCoinbase 1) := by
  have h := staleRunChecks_true
  simp only [staleRunChecks, Bool.and_eq_true, beq_iff_eq] at h
  exact ⟨staleRunFinal_reachable.2, h.1, staleFacts_sound _ _ _ h.2⟩

/-- [D] 2026-10-13: the executable facts of a removal without more work: the
transition completed, the selected work decreased, and the one transaction
of the block at the hash was in an active block before and is in none after.
[SRC] src/validation.cpp:5230-5330 at 6504a3af. -/
def charterFacts (s t : ChainState) (status : ActivationStatus) (hash : BitVec 256) : Bool :=
  status == .complete && decide (activeWork t < activeWork s) &&
  match s.tree.get hash with
  | none => false
  | some i =>
    match i.body with
    | none => false
    | some b =>
      match b.transactions with
      | [x] =>
        s.active.contains i.id &&
        t.active.all (fun h => match (t.tree.get h).bind (·.body) with
          | none => true
          | some b' => !(b'.transactions.map BsvScript.Sighash.txid).contains (BsvScript.Sighash.txid x))
      | _ => false

/-- [D] 2026-10-13: the executable removal facts mean the propositions.
[SRC] src/validation.cpp:5230-5330 at 6504a3af. -/
theorem charterFacts_sound (s t : ChainState) (status : ActivationStatus) (hash : BitVec 256)
    (h : charterFacts s t status hash = true) :
    status = .complete ∧ activeWork t < activeWork s ∧
      ∃ x, ActiveTransaction s.tree s.active x ∧ ¬ ActiveTransaction t.tree t.active x := by
  unfold charterFacts at h
  simp only [Bool.and_eq_true, beq_iff_eq, decide_eq_true_eq] at h
  obtain ⟨⟨hstatus, hwork⟩, h⟩ := h
  refine ⟨hstatus, hwork, ?_⟩
  split at h
  · cases h
  · rename_i i hi
    obtain ⟨_, hid⟩ := get_mem _ _ _ hi
    split at h
    · cases h
    · rename_i b hb
      split at h
      · rename_i x hx
        simp only [Bool.and_eq_true, List.all_eq_true, List.contains_iff_mem] at h
        obtain ⟨hactive, hall⟩ := h
        refine ⟨x, ⟨i.id, hactive, b, by simp [hid ▸ hi, hb], by simp [hx]⟩, ?_⟩
        rintro ⟨h', hm, block, hblk, htx⟩
        have := hall h' hm
        rw [hblk] at this
        simp at this
        exact this x htx rfl
      · cases h

/-- [D] 2026-10-13: the operator invalidates 1a after its activation.
[SRC] src/validation.cpp:5230-5330 at 6504a3af. -/
def staleRunInvalidated : ChainState × ActivationStatus :=
  invalidateBlock staleRunWith1a staleRunContext .empty evalOracle staleRun1a.header.hash 8

/-- [D] 2026-10-13: the kernel evaluates the invalidation run.
[SRC] src/validation.cpp:5230-5330 at 6504a3af. -/
theorem staleRunInvalidated_facts :
    charterFacts staleRunWith1a staleRunInvalidated.1 staleRunInvalidated.2 staleRun1a.header.hash = true := by
  decide +kernel

/-- [M] 2026-10-13, #68 theorem 4's charter note, kernel-checked. The charter's
unconditional sentence, "a transaction leaves the active chain only when a
chain of more accumulated work is connected", is false in the machine: from a
reachable state, a completed operator invalidation of the tip (one transition)
reaches a reachable state where a transaction that was in an active block is
in none, and the selected accumulated work strictly decreased. No premise: the
run is concrete. The reference does the same: InvalidateBlock marks the block
failed and disconnects it at once, with no higher-work replacement.
[SRC] src/validation.cpp:5234-5256 at 6504a3af. -/
theorem s6_charter_removal_false :
    ∃ s t tx, Reachable s ∧ Reachable t ∧
      invalidateBlock s staleRunContext .empty evalOracle staleRun1a.header.hash 8 = (t, .complete) ∧
      ActiveTransaction s.tree s.active tx ∧ ¬ ActiveTransaction t.tree t.active tx ∧
      activeWork t < activeWork s := by
  obtain ⟨hstatus, hwork, x, hbefore, hafter⟩ := charterFacts_sound _ _ _ _ staleRunInvalidated_facts
  refine ⟨staleRunWith1a, staleRunInvalidated.1, x, staleRunFinal_reachable.1,
    .invalidate _ _ _ _ _ staleRunFinal_reachable.1, ?_, hbefore, hafter, hwork⟩
  rw [← hstatus]
  exact (Prod.mk.eta (p := staleRunInvalidated)).symm

end BsvChain.Properties
