import BsvChain.Block

/-!
# Block properties (#63)

The header codec, padding-equivalent merkle suffix, finite subsidy schedule,
and accepted timestamp window. All statements name the executable definitions.
[SRC] src/primitives/block.h:38–45, src/consensus/merkle.cpp:18–50,247–282,
src/validation.cpp:2252–2262,5933–5975 at
`6504a3aff65ba97c0f6c80962b033e35ecbfed4b`.
-/

namespace BsvChain.Properties
open BsvScript.Numbers BsvScript.Tx

/-- A fixed-width word always emits its requested byte count, independent
of its value. This is the framing fact used by the round trip.
[SRC] src/serialize.h:71–91 at 6504a3af. -/
theorem headerWordBytes_length (n value : Nat) : (headerWordBytes n value).length = n := by
  induction n generalizing value with
  | zero => rfl
  | succ n ih => simp [headerWordBytes, ih]

/-- A word that fits in the requested width reads back unchanged. The width
premise excludes truncation and is discharged by each header field's type.
[SRC] src/serialize.h:71–91 at 6504a3af. -/
theorem leNat_headerWordBytes (n value : Nat) (h : value < 256 ^ n) :
    leNat (headerWordBytes n value) = value := by
  induction n generalizing value with
  | zero => simp at h; simp [headerWordBytes, leNat, h]
  | succ n ih =>
    have hd : value / 256 < 256 ^ n := by
      apply (Nat.div_lt_iff_lt_mul (by decide)).2
      simpa [Nat.pow_succ] using h
    simp only [headerWordBytes, leNat, ih _ hd]
    omega

/-- The existing prefix reader consumes exactly an encoded bounded word and
leaves an arbitrary following stream untouched. This ties the new encoder
to the reused transaction reader. [SRC] src/primitives/block.h:38–45 and
src/serialize.h:71–91 at 6504a3af. -/
theorem readLE_headerWordBytes (n value : Nat) (rest : Bytes) (h : value < 256 ^ n) :
    readLE n (headerWordBytes n value ++ rest) = some (value, rest) := by
  have hl := headerWordBytes_length n value
  simp [readLE, hl, leNat_headerWordBytes n value h]

/-- Every header encodes to the fixed frame size, [D] 80 bytes. Typed fields
give their exact widths without a well-formedness predicate on callers.
[SRC] src/primitives/block.h:26–45 at 6504a3af. -/
theorem header_encode_length (header : BlockHeader) : header.encode.length = 80 := by
  simp [BlockHeader.encode, headerWordBytes_length]

/-- The codec round trip also preserves an arbitrary body suffix. Each field
is a fixed-width bit vector, so no truncation premise is needed.
[SRC] src/primitives/block.h:26–45 at 6504a3af. -/
theorem header_decodePrefix_encode (header : BlockHeader) (rest : Bytes) :
    BlockHeader.decodePrefix (header.encode ++ rest) = some (header, rest) := by
  have h32 (v : BitVec 32) : v.toNat < 256 ^ 4 := by simpa using v.isLt
  have h256 (v : BitVec 256) : v.toNat < 256 ^ 32 := by simpa using v.isLt
  simp [BlockHeader.encode, BlockHeader.decodePrefix, List.append_assoc,
    readLE_headerWordBytes _ _ _ (h32 _), readLE_headerWordBytes _ _ _ (h256 _)]

/-- Exact-frame round trip for every typed header, following the stronger
prefix theorem. This checks the wire encoder/decoder composition, not hashes.
[SRC] src/primitives/block.h:38–45 at 6504a3af. -/
theorem header_codec_roundtrip (header : BlockHeader) :
    BlockHeader.decode header.encode = some header := by
  have hp := header_decodePrefix_encode header []
  simp only [List.append_nil] at hp
  simp [BlockHeader.decode, hp]

/-- Padding the odd terminal leaf in this shape preserves the root for every
three leaves, with no hash-injectivity assumption. It does not assert the
false generalization to an arbitrary duplicated suffix.
[SRC] src/consensus/merkle.cpp:18–50,263–281 at 6504a3af. -/
theorem merkle_padding_three (a b c : Bytes) :
    (computeMerkleRoot [a, b, c]).root = (computeMerkleRoot [a, b, c, c]).root := by
  simp [computeMerkleRoot, merkleReduce, merkleLevel]

/-- An actual duplicate terminal pair sets the flag, even though the preceding
theorem equates the roots. Other sibling equalities may already mark the
shorter list; no claim of an unmutated shorter tree is made.
[SRC] src/consensus/merkle.cpp:210–213,263–279 at 6504a3af. -/
theorem merkle_duplicate_suffix_mutated (a b c : Bytes) :
    (computeMerkleRoot [a, b, c, c]).mutated = true := by
  simp [computeMerkleRoot, merkleReduce, merkleLevel]

/-- Every position within a positive-length subsidy era pays the same amount.
Together with the eventual-zero law, this justifies summing the schedule by
eras instead of evaluating millions of identical heights.
[SRC] src/validation.cpp:2252–2262 at 6504a3af. -/
theorem subsidy_in_era (params : ChainParams) (era offset : Nat)
    (hi : 0 < params.subsidyHalvingInterval) (ho : offset < params.subsidyHalvingInterval) :
    getBlockSubsidy params (era * params.subsidyHalvingInterval + offset) =
      getBlockSubsidy params (era * params.subsidyHalvingInterval) := by
  have hd : (era * params.subsidyHalvingInterval + offset) / params.subsidyHalvingInterval = era := by
    rw [Nat.add_comm, Nat.add_mul_div_right _ _ hi]
    simp [Nat.div_eq_of_lt ho]
  simp [getBlockSubsidy, hd, Nat.ne_of_gt hi]

/-- No height after the finite schedule contributes subsidy. The interval
must be positive; division by zero is outside the pinned parameter domain.
[SRC] src/validation.cpp:2253–2256 at 6504a3af. -/
theorem subsidy_after_schedule (params : ChainParams) (height : Nat)
    (hi : 0 < params.subsidyHalvingInterval) (hh : 64 * params.subsidyHalvingInterval ≤ height) :
    getBlockSubsidy params height = 0 := by
  have h : 64 ≤ height / params.subsidyHalvingInterval := (Nat.le_div_iff_mul_le hi).2 hh
  simp [getBlockSubsidy, h]

/-- For a positive halving interval the schedule's total is the interval times
the sum of the 64 era subsidies, which no longer depends on the network.
[SRC] src/validation.cpp:2252–2262 at 6504a3af. -/
theorem subsidyScheduleTotal_eq (params : ChainParams) (hi : 0 < params.subsidyHalvingInterval) :
    subsidyScheduleTotal params =
      params.subsidyHalvingInterval * ((List.range 64).map (fun era => 5000000000 / 2 ^ era)).sum := by
  unfold subsidyScheduleTotal
  congr 2
  apply List.map_congr_left
  intro era hera
  have he : era < 64 := List.mem_range.mp hera
  have hd : era * params.subsidyHalvingInterval / params.subsidyHalvingInterval = era :=
    Nat.mul_div_cancel _ hi
  simp [getBlockSubsidy, hd, Nat.not_le.mpr he]

/-- The general form of the money bound, for ANY parameters: the schedule's
total lies strictly below `MAX_MONEY` exactly when the halving interval is at
most 210,000. A zero interval contributes no subsidy (the total is 0); above
210,000 the bound is false, so the pinned networks' intervals (210,000 on
mainnet, testnet and STN, 150 on regtest) are within it and a larger interval
is not. An arithmetic bound on permitted subsidies, not a claim about
circulating supply. [SRC] src/validation.cpp:2252–2262, src/amount.h:130 at 6504a3af. -/
theorem subsidy_total_bound_iff (params : ChainParams) :
    subsidyScheduleTotal params < BsvScript.TxRules.MAX_MONEY ↔
      params.subsidyHalvingInterval ≤ 210000 := by
  rcases Nat.eq_zero_or_pos params.subsidyHalvingInterval with h0 | hi
  · simp [subsidyScheduleTotal, h0, BsvScript.TxRules.MAX_MONEY]
  · rw [subsidyScheduleTotal_eq params hi]
    have hlo : 210000 * ((List.range 64).map (fun era => 5000000000 / 2 ^ era)).sum <
        BsvScript.TxRules.MAX_MONEY := by decide +kernel
    have hhi : BsvScript.TxRules.MAX_MONEY ≤
        210001 * ((List.range 64).map (fun era => 5000000000 / 2 ^ era)).sum := by decide +kernel
    have key : ∀ S : Nat, 210000 * S < BsvScript.TxRules.MAX_MONEY →
        BsvScript.TxRules.MAX_MONEY ≤ 210001 * S →
        (params.subsidyHalvingInterval * S < BsvScript.TxRules.MAX_MONEY ↔
          params.subsidyHalvingInterval ≤ 210000) := by
      intro S hl hh
      constructor
      · intro h
        apply Nat.le_of_not_lt
        intro hc
        have : 210001 * S ≤ params.subsidyHalvingInterval * S :=
          Nat.mul_le_mul (by omega : 210001 ≤ params.subsidyHalvingInterval) (Nat.le_refl S)
        omega
      · intro h
        have : params.subsidyHalvingInterval * S ≤ 210000 * S := Nat.mul_le_mul h (Nat.le_refl S)
        omega
    exact key _ hlo hhi

/-- The total schedule lies strictly below the existing money bound on each
pinned network, including STN's independent subsidy interval. This is an
arithmetic bound on permitted subsidies, not a claim about circulating supply
or the genesis output's spendability. The kernel evaluates only the finite
era sum. The general form is `subsidy_total_bound_iff`, for every network; this
theorem is its instance on the four pinned records. [SRC] src/validation.cpp:2252–2262, src/amount.h:130 and
src/chainparams.cpp:1037,1211,1333,1460 at 6504a3af. -/
theorem subsidy_total_pinned :
    subsidyScheduleTotal ChainParams.mainnet < BsvScript.TxRules.MAX_MONEY ∧
    subsidyScheduleTotal ChainParams.testnet < BsvScript.TxRules.MAX_MONEY ∧
    subsidyScheduleTotal ChainParams.stn < BsvScript.TxRules.MAX_MONEY ∧
    subsidyScheduleTotal ChainParams.regtest < BsvScript.TxRules.MAX_MONEY := by
  decide

/-- Passing the reward stage bounds coinbase outputs by the height's subsidy
plus supplied fees. #64 must establish that those fees came from accepted
transactions; this theorem does not assume that unproved integration.
[SRC] src/validation.cpp:3655–3666 at 6504a3af. -/
theorem coinbase_amount_bound (params : ChainParams) (height : Nat) (coinbase : Tx)
    (fees : Int) (h : checkCoinbaseAmount params height coinbase fees = .ok ()) :
    outputValue coinbase ≤ fees + getBlockSubsidy params height := by
  unfold checkCoinbaseAmount at h
  split at h
  · contradiction
  · omega

/-- An accepted contextual header is strictly newer than the parent median
and no later than explicit `now` plus the configured future-time constant.
No proof-of-work or block-body acceptance is inferred by this theorem.
[SRC] src/validation.cpp:5943–5959 at 6504a3af. -/
theorem contextual_header_timestamp_window (params : ChainParams) (cfg : NodeConfig)
    (header : BlockHeader) (previous : HeaderChain) (now : Int)
    (h : contextualCheckBlockHeader params cfg header previous now = some (.ok ())) :
    medianTimePast (previous.ancestors.map (·.time)) cfg.medianTimeSpan < header.time.toNat ∧
    (header.time.toNat : Int) ≤ now + cfg.maxFutureBlockTimeSeconds := by
  unfold contextualCheckBlockHeader at h
  cases hw : getNextWorkRequired params cfg (some previous) header with
  | none => simp [hw] at h
  | some expected =>
    simp only [hw, bind, Option.bind, pure] at h
    split at h
    · cases h
    · cases hm : previous.medianAt cfg previous.height with
      | none => simp [hm] at h
      | some median =>
        simp only [hm] at h
        split at h
        · cases h
        · split at h
          · cases h
          · have he : median = medianTimePast (previous.ancestors.map (·.time)) cfg.medianTimeSpan := by
              unfold HeaderChain.medianAt at hm
              simp only [Nat.sub_self, List.drop_zero] at hm
              split at hm
              · contradiction
              · exact (Option.some.inj hm).symm
            constructor <;> omega

/-- At the pinned future-time constant the preceding bound is exactly two
hours, [D] 2 * 60 * 60 = 7200 seconds, for arbitrary explicit `now`. The
general form is `contextual_header_timestamp_window`, for every configuration;
this theorem is its instance at the census defaults. [SRC] src/block_index.h:28–31 at 6504a3af. -/
theorem contextual_header_two_hours (params : ChainParams) (header : BlockHeader)
    (previous : HeaderChain) (now : Int)
    (h : contextualCheckBlockHeader params NodeConfig.defaults header previous now = some (.ok ())) :
    medianTimePast (previous.ancestors.map (·.time)) NodeConfig.defaults.medianTimeSpan < header.time.toNat ∧
    (header.time.toNat : Int) ≤ now + 7200 :=
  contextual_header_timestamp_window params NodeConfig.defaults header previous now h

end BsvChain.Properties
