import BsvChain.Wire.DoubleSpend
import BsvChain.Properties.P2P

/-!
# The double-spend notifications' laws (#80), 2026-10-15 [D]

Views of node behavior, never rules of validity; **a notification is never a
verdict**. The codecs read back their writers' bytes: the reference's VARINT
(both widths the callback message uses), the callback message, the
notification output that carries it, the merkle proof, the block details and
the `dsdetected` message. The blacklist holds an endpoint added now until its
hour is out and lets it go after. THE THEOREM (`notification_only_after_detection`):
every query and every proof the handler sends names a notice whose attempt is
a detection of #62's admission (a completed refusal at the pool's conflict
check or at the double-spend detector), whose notification-enabled transaction
and conflicting transaction are the two sides of that conflict on one
outpoint, and whose double-spend input passed a script check: the admission's
own (a refusal at the detector, after every script check) or the handler's
(a refusal at the conflict check, before any script ran). [SRC] bitcoin-sv
v1.2.3 at 6504a3aff65ba97c0f6c80962b033e35ecbfed4b, as cited in
`lean/BsvChain/Wire/DoubleSpend.lean`.
`Detected` is existential: some state of #62's machine (pool, UTXO view,
settings, script oracle, detector observation) refuses the double spend with
that detection, and `Reach` queues any such detection, so the theorem binds a
notice to a refusal #62's machine makes, not to this node's own admission; the
handler's own script check is an input (`Env.scriptCheck`), not #62's oracle;
the composed machine is owed.
-/

namespace BsvChain.Wire.DoubleSpend
open BsvScript.Numbers BsvScript.Tx BsvScript.Hash BsvScript.Sighash BsvChain BsvChain.Properties

/-! ## 1. The VARINT -/

/-- [D] 2026-10-15: one byte with the continuation bit read under the bound. -/
theorem readVarIntLoop_cont (ov fuel n b : Nat) (rest : Bytes) (hn : n ≤ ov) (hb : 128 ≤ b % 256) :
    readVarIntLoop ov (fuel + 1) n (b :: rest) =
      readVarIntLoop ov fuel (((n * 128 + b % 128) % 2 ^ 64 + 1) % 2 ^ 64) rest := by
  have h1 : ¬ n > ov := by omega
  have h2 : ¬ b % 256 < 128 := by omega
  simp only [readVarIntLoop, h1, h2, ite_false]

/-- [D] 2026-10-15: the last byte read under the bound. -/
theorem readVarIntLoop_stop (ov fuel n b : Nat) (rest : Bytes) (hn : n ≤ ov) (hb : b % 256 < 128) :
    readVarIntLoop ov (fuel + 1) n (b :: rest) = some ((n * 128 + b % 128) % 2 ^ 64, rest) := by
  have h1 : ¬ n > ov := by omega
  simp only [readVarIntLoop, h1, hb, ite_false, ite_true]

/-- [D] 2026-10-15: the digits before the last read back to their value plus
one, when that value is within the bound. [SRC] src/serialize.h:342-423 at 6504a3af. -/
theorem varIntHigh_read (ov : Nat) (hov : ov < 2 ^ 64) :
    ∀ m fuel (rest : Bytes), m + 1 ≤ ov →
      readVarIntLoop ov (fuel + (varIntHigh m).length) 0 (varIntHigh m ++ rest) =
        readVarIntLoop ov fuel (m + 1) rest := by
  intro m
  induction m using Nat.strong_induction_on with
  | _ m ih =>
    intro fuel rest hm
    by_cases h : m < 128
    · have e : varIntHigh m = [m % 128 + 128] := by
        rw [varIntHigh]; simp [h]
      rw [e]
      simp only [List.length_singleton, List.singleton_append]
      rw [readVarIntLoop_cont ov fuel 0 _ rest (by omega) (by omega)]
      congr 1
      omega
    · have e : varIntHigh m = varIntHigh (m / 128 - 1) ++ [m % 128 + 128] := by
        rw [varIntHigh]; simp [h]
      rw [e]
      have hl : (varIntHigh (m / 128 - 1) ++ [m % 128 + 128]).length =
          (varIntHigh (m / 128 - 1)).length + 1 := by simp
      rw [hl, List.append_assoc, List.singleton_append,
        show fuel + ((varIntHigh (m / 128 - 1)).length + 1) =
          (fuel + 1) + (varIntHigh (m / 128 - 1)).length by omega,
        ih (m / 128 - 1) (by omega) (fuel + 1) _ (by omega)]
      rw [readVarIntLoop_cont ov fuel _ _ rest (by omega) (by omega)]
      congr 1
      omega

/-- [D] 2026-10-15: every VARINT within the bound reads back with the stream's
rest untouched. [SRC] src/serialize.h:379-423 at 6504a3af. -/
theorem writeVarInt_read (ov n fuel : Nat) (rest : Bytes) (hov : ov * 128 + 127 < 2 ^ 64)
    (hn : n ≤ ov * 128 + 127) :
    readVarIntLoop ov (fuel + (writeVarInt n).length) 0 (writeVarInt n ++ rest) = some (n, rest) := by
  by_cases h : n < 128
  · have e : writeVarInt n = [n] := by simp [writeVarInt, h]
    rw [e]
    simp only [List.length_singleton, List.singleton_append]
    rw [readVarIntLoop_stop ov fuel 0 n rest (by omega) (by omega)]
    congr 2
    omega
  · have e : writeVarInt n = varIntHigh (n / 128 - 1) ++ [n % 128] := by simp [writeVarInt, h]
    rw [e]
    have hl : (varIntHigh (n / 128 - 1) ++ [n % 128]).length = (varIntHigh (n / 128 - 1)).length + 1 := by simp
    rw [hl, List.append_assoc, List.singleton_append,
      show fuel + ((varIntHigh (n / 128 - 1)).length + 1) = (fuel + 1) + (varIntHigh (n / 128 - 1)).length by omega,
      varIntHigh_read ov (by omega) (n / 128 - 1) (fuel + 1) _ (by omega)]
    rw [readVarIntLoop_stop ov fuel _ _ rest (by omega) (by omega)]
    congr 2
    omega

/-- [D] 2026-10-15: the thresholds of the VARINT's length: a value below
`varIntBound k` has at most `k + 1` digits before its last. -/
def varIntBound : Nat → Nat
  | 0 => 128
  | k + 1 => (varIntBound k + 1) * 128

/-- [D] 2026-10-15: a value below `varIntBound k` writes at most `k + 1` digits before its last. -/
theorem varIntHigh_length (k : Nat) : ∀ m, m < varIntBound k → (varIntHigh m).length ≤ k + 1 := by
  induction k with
  | zero =>
    intro m hm
    have h : m < 128 := by simpa [varIntBound] using hm
    rw [varIntHigh]; simp [h]
  | succ k ih =>
    intro m hm
    rw [varIntHigh]
    by_cases h : m < 128
    · simp [h]
    · simp only [h, dite_false, List.length_append, List.length_singleton]
      have hb : m < (varIntBound k + 1) * 128 := by simpa [varIntBound] using hm
      have := ih (m / 128 - 1) (by omega)
      omega

/-- [D] 2026-10-15: a 64-bit value's VARINT is at most ten bytes, the reader's
loop bound (src/serialize.h:407-408 at 6504a3af). -/
theorem writeVarInt_length (n : Nat) (h : n < 2 ^ 64) : (writeVarInt n).length ≤ 10 := by
  unfold writeVarInt
  by_cases h1 : n < 128
  · simp [h1]
  · simp only [h1, ite_false, List.length_append, List.length_singleton]
    have hb : varIntBound 8 = 9295997013522923648 := by decide
    have := varIntHigh_length 8 (n / 128 - 1) (by rw [hb]; omega)
    omega

/-- [D] 2026-10-15: THE VARINT ROUND TRIP, 64-bit (`ReadVarInt<uint64_t>`, the
callback message's counts). [SRC] src/serialize.h:379-423 at 6504a3af. -/
theorem readVarInt64_write (n : Nat) (rest : Bytes) (h : n < 2 ^ 64) :
    readVarInt64 (writeVarInt n ++ rest) = some (n, rest) := by
  have hl := writeVarInt_length n h
  have e := writeVarInt_read (2 ^ 57 - 1) n (10 - (writeVarInt n).length) rest (by norm_num) (by omega)
  rw [show 10 - (writeVarInt n).length + (writeVarInt n).length = 10 by omega] at e
  exact e

/-- [D] 2026-10-15: THE VARINT ROUND TRIP, 32-bit (`ReadVarInt<uint32_t>`, the
callback message's inputs). [SRC] src/serialize.h:379-423 at 6504a3af. -/
theorem readVarInt32_write (n : Nat) (rest : Bytes) (h : n < 2 ^ 32) :
    readVarInt32 (writeVarInt n ++ rest) = some (n, rest) := by
  have hl := writeVarInt_length n (by omega)
  have e := writeVarInt_read (2 ^ 25 - 1) n (10 - (writeVarInt n).length) rest (by norm_num) (by omega)
  rw [show 10 - (writeVarInt n).length + (writeVarInt n).length = 10 by omega] at e
  exact e

/-- [D] 2026-10-15: the source's table entry for 2^32, `8efefeff00`
(src/serialize.h:363 at 6504a3af), reads as 2^32 at 64 bits and is refused at
32 bits: before its last byte the accumulator passes 2^25 - 1, the 32-bit
type's bound (:405,409-411). A view, never a rule. -/
theorem varInt_2pow32_widths :
    readVarInt64 [0x8e, 0xfe, 0xfe, 0xff, 0x00] = some (2 ^ 32, []) ∧
      readVarInt32 [0x8e, 0xfe, 0xfe, 0xff, 0x00] = none := by decide

/-! ## 2. The callback message and the notification output -/

/-- [D] 2026-10-15: a callback message its writer serializes and its reader
reads: a version byte, at least one address and each at the family's width,
32-bit inputs, counts within 64 bits. [SRC] src/double_spend/dscallback_msg.h:52-149 at 6504a3af. -/
def CallbackMsg.WellFormed (m : CallbackMsg) : Prop :=
  m.version < 256 ∧ m.addrs ≠ [] ∧ m.addrs.length < 2 ^ 64 ∧
    (∀ a ∈ m.addrs, a.length = addrWidth m.version) ∧ m.inputs.length < 2 ^ 64 ∧
    ∀ i ∈ m.inputs, i < 2 ^ 32

/-- [D] 2026-10-15: THE CALLBACK ROUND TRIP. A well-formed message reads back
from its writer's bytes. [SRC] src/double_spend/dscallback_msg.h:52-149 at
6504a3af. A view, never a rule. -/
theorem CallbackMsg.decode_encode (m : CallbackMsg) (wf : m.WellFormed) :
    CallbackMsg.decode m.encode = some m := by
  obtain ⟨version, addrs, inputs⟩ := m
  obtain ⟨hv, hne, hal, haw, hil, hi⟩ := wf
  simp only at hv hne hal haw hil hi
  have hna : ¬ addrs.length = 0 := by
    intro h; exact hne (List.eq_nil_of_length_eq_zero h)
  have e1 := readLE_headerWordBytes 1 version
    (writeVarInt addrs.length ++ (addrs.flatten ++ (writeVarInt inputs.length ++
      (inputs.map writeVarInt).flatten))) (by norm_num; omega)
  have e2 := readVarInt64_write addrs.length
    (addrs.flatten ++ (writeVarInt inputs.length ++ (inputs.map writeVarInt).flatten)) hal
  have e3 := readMany_ser (readBytes (addrWidth version)) id (fun a => a.length = addrWidth version)
    (fun x r hx => readBytes_prefix _ x r hx) addrs haw
    (writeVarInt inputs.length ++ (inputs.map writeVarInt).flatten)
  rw [List.map_id] at e3
  have e4 := readVarInt64_write inputs.length ((inputs.map writeVarInt).flatten) hil
  have e5 := readMany_ser readVarInt32 writeVarInt (fun i => i < 2 ^ 32)
    (fun x r hx => readVarInt32_write x r hx) inputs hi []
  rw [List.append_nil] at e5
  unfold CallbackMsg.decode CallbackMsg.encode
  simp only [List.append_assoc, bind, Option.bind, e1, e2, hna, ite_false, e3, e4, e5, ite_true, pure]

/-- [D] 2026-10-15: a VARINT is at least one byte. -/
theorem writeVarInt_length_pos (n : Nat) : 1 ≤ (writeVarInt n).length := by
  unfold writeVarInt; split <;> simp

/-- [D] 2026-10-15: THE NOTIFICATION OUTPUT'S ROUND TRIP. A well-formed message
of up to 65535 bytes, written as the notification output's push, is read back
by the handler's reader of an output script. [SRC] src/script/script.h:104-133,165-200,
src/script/script.cpp:174-179, src/double_spend/dscallback_msg.cpp:94-114 at
6504a3af. A view, never a rule. -/
theorem callbackOfScript_dsntScript (m : CallbackMsg) (wf : m.WellFormed)
    (hl : m.encode.length ≤ 0xffff) : callbackOfScript (dsntScript m) = some m := by
  have hdec := CallbackMsg.decode_encode m wf
  have h3 : 3 ≤ m.encode.length := by
    have a := writeVarInt_length_pos m.addrs.length
    have b := writeVarInt_length_pos m.inputs.length
    simp only [CallbackMsg.encode, List.length_append, headerWordBytes_length]
    omega
  generalize he : m.encode = e at hdec hl h3
  have hpos : 1 ≤ (pushData e).length := by unfold pushData; split_ifs <;> simp
  have hop : ∃ op, BsvScript.Standard.getOp (pushData e) = some (op, e, []) := by
    unfold pushData
    split_ifs with h1 h2
    · refine ⟨e.length, ?_⟩
      have hle : e.length ≤ 78 := by omega
      simp [BsvScript.Standard.getOp, BsvScript.Machine.getOpTail, BsvScript.Op.OP_PUSHDATA4,
        BsvScript.Op.OP_PUSHDATA1, h1, hle]
    · refine ⟨0x4c, ?_⟩
      simp [BsvScript.Standard.getOp, BsvScript.Machine.getOpTail, BsvScript.Op.OP_PUSHDATA4,
        BsvScript.Op.OP_PUSHDATA1]
    · refine ⟨0x4d, ?_⟩
      have hw : headerWordBytes 2 e.length = [e.length % 256, e.length / 256 % 256] := by
        simp [headerWordBytes]
      have hv : e.length % 256 + 256 * (e.length / 256 % 256) = e.length := by omega
      simp [BsvScript.Standard.getOp, BsvScript.Machine.getOpTail, BsvScript.Op.OP_PUSHDATA4,
        BsvScript.Op.OP_PUSHDATA1, BsvScript.Op.OP_PUSHDATA2, hw, hv]
      try omega
  obtain ⟨op, hop⟩ := hop
  unfold callbackOfScript dsntScript isDSNotification
  rw [he]
  have hlen : 11 ≤ (dsntTag ++ pushData e).length := by
    simp only [List.length_append, dsntTag, List.length_cons, List.length_nil]
    have : e.length + 1 ≤ (pushData e).length := by unfold pushData; split_ifs <;> simp
    omega
  simp only [hlen, decide_true, Bool.true_and]
  simp [dsntTag, hop, hdec]

/-! ## 3. The `dsdetected` message -/

/-- [D] 2026-10-15: a node of a one-byte type and a 32-byte hash. -/
def ProofNode.WellFormed (n : ProofNode) : Prop := n.kind < 256 ∧ n.value.length = 32

/-- [D] 2026-10-15: a proof node of a one-byte type and a 32-byte hash reads back. [SRC] src/merkleproof.h:32-38 at 6504a3af. -/
theorem ProofNode.read_encode (n : ProofNode) (rest : Bytes) (wf : n.WellFormed) :
    ProofNode.read (n.encode ++ rest) = some (n, rest) := by
  obtain ⟨kind, value⟩ := n
  obtain ⟨hk, hv⟩ := wf
  simp only at hk hv
  simp only [ProofNode.read, ProofNode.encode, List.append_assoc, bind, Option.bind,
    readLE_headerWordBytes _ _ _ (by norm_num; omega : kind < 256 ^ 1),
    BsvChain.Wire.readBytes_prefix _ _ _ hv, pure]

/-- [D] 2026-10-15: a proof its writer serializes and its reader reads: the
flag bit 0x01 set exactly when it carries a transaction, which is then well
formed and names its own id, with a 64-bit length field; else a 32-byte id
and a zero length field (the reader keeps none); a 32-byte target; well-formed
nodes. [SRC] src/merkleproof.h:100-137 at 6504a3af. -/
def MerkleProof.WellFormed (p : MerkleProof) : Prop :=
  p.flags < 256 ∧ p.index < 2 ^ 64 ∧ p.target.length = 32 ∧ p.nodes.length < 2 ^ 64 ∧
    (∀ n ∈ p.nodes, n.WellFormed) ∧
    match p.tx with
    | some t => p.flags % 2 = 1 ∧ TxWellFormed t ∧ p.txLen < 2 ^ 64 ∧ p.txId = txid t
    | none => p.flags % 2 = 0 ∧ p.txLen = 0 ∧ p.txId.length = 32

/-- [D] 2026-10-15: THE PROOF'S ROUND TRIP. [SRC] src/merkleproof.h:100-137 at
6504a3af. A view, never a rule. -/
theorem MerkleProof.read_encode (p : MerkleProof) (rest : Bytes) (wf : p.WellFormed) :
    MerkleProof.read (p.encode ++ rest) = some (p, rest) := by
  obtain ⟨flags, index, txLen, tx, txId, target, nodes⟩ := p
  obtain ⟨hf, hi, ht, hn, hnodes, htx⟩ := wf
  simp only at hf hi ht hn hnodes htx
  have hm := readMany_ser ProofNode.read ProofNode.encode ProofNode.WellFormed
    (fun x r hx => ProofNode.read_encode x r hx) nodes hnodes rest
  have hc := readVarInt_compactSize nodes.length ((nodes.map ProofNode.encode).flatten ++ rest) hn
  have htg := BsvChain.Wire.readBytes_prefix 32 target
    (compactSize nodes.length ++ ((nodes.map ProofNode.encode).flatten ++ rest)) ht
  cases tx with
  | some t =>
    obtain ⟨hodd, htwf, hlen, hid⟩ := htx
    subst hid
    have hd := decodeTxPrefix_serTx t
      (target ++ (compactSize nodes.length ++ ((nodes.map ProofNode.encode).flatten ++ rest))) htwf
    simp only [MerkleProof.read, MerkleProof.encode, List.append_assoc, bind, Option.bind,
      readLE_headerWordBytes _ _ _ (by norm_num; omega : flags < 256 ^ 1),
      readVarInt_compactSize _ _ hi, hodd, ite_true, readVarInt_compactSize _ _ hlen, hd, pure,
      htg, hc, hm]
  | none =>
    obtain ⟨heven, hlen, hid⟩ := htx
    subst hlen
    have hidr := BsvChain.Wire.readBytes_prefix 32 txId
      (target ++ (compactSize nodes.length ++ ((nodes.map ProofNode.encode).flatten ++ rest))) hid
    have hne : ¬ flags % 2 = 1 := by omega
    simp only [MerkleProof.read, MerkleProof.encode, List.append_assoc, bind, Option.bind,
      readLE_headerWordBytes _ _ _ (by norm_num; omega : flags < 256 ^ 1),
      readVarInt_compactSize _ _ hi, hne, ite_false, hidr, pure, htg, hc, hm]

/-- [D] 2026-10-15: block details the reader accepts: at least one header, a
well-formed proof of the shape `Validate` passes. -/
def BlockDetails.WellFormed (b : BlockDetails) : Prop :=
  b.headers ≠ [] ∧ b.headers.length < 2 ^ 64 ∧ b.proof.WellFormed ∧ proofShapeOk b.proof = true

/-- [D] 2026-10-15: well-formed block details read back, the stream's rest untouched.
[SRC] src/double_spend/dsdetected_message.h:31-43 at 6504a3af. -/
theorem BlockDetails.read_encode (b : BlockDetails) (rest : Bytes) (wf : b.WellFormed) :
    BlockDetails.read (b.encode ++ rest) = some (b, rest) := by
  obtain ⟨headers, proof⟩ := b
  obtain ⟨hne, hl, hp, hs⟩ := wf
  simp only at hne hl hp hs
  have hh := readMany_ser BlockHeader.decodePrefix BlockHeader.encode (fun _ => True)
    (fun x r _ => header_decodePrefix_encode x r) headers (fun _ _ => trivial) (proof.encode ++ rest)
  have hc := readVarInt_compactSize headers.length
    ((headers.map BlockHeader.encode).flatten ++ (proof.encode ++ rest)) hl
  have hpr := MerkleProof.read_encode proof rest hp
  have hemp : headers.isEmpty = false := by
    cases headers with
    | nil => exact absurd rfl hne
    | cons _ _ => rfl
  simp only [BlockDetails.read, BlockDetails.encode, List.append_assoc, bind, Option.bind, hc, hh,
    hemp, hpr, hs, Bool.not_true, Bool.false_eq_true, ite_false, pure]

/-- [D] 2026-10-15: THE `dsdetected` ROUND TRIP. A message of version 1 with at
least two well-formed blocks reads back from its writer's bytes, the rest of
the payload untouched. [SRC] src/double_spend/dsdetected_message.h:29-98,
src/merkleproof.h:100-137 at 6504a3af. A view, never a rule. -/
theorem DSDetected.read_encode (m : DSDetected) (rest : Bytes) (hv : m.version = 1)
    (h2 : 2 ≤ m.blocks.length) (h64 : m.blocks.length < 2 ^ 64) (wf : ∀ b ∈ m.blocks, b.WellFormed) :
    DSDetected.read (m.encode ++ rest) = some (m, rest) := by
  obtain ⟨version, blocks⟩ := m
  simp only at hv h2 h64 wf
  subst hv
  have hb := readMany_ser BlockDetails.read BlockDetails.encode BlockDetails.WellFormed
    (fun x r hx => BlockDetails.read_encode x r hx) blocks wf rest
  have hc := readVarInt_compactSize blocks.length ((blocks.map BlockDetails.encode).flatten ++ rest) h64
  have hlt : ¬ blocks.length < 2 := by omega
  simp only [DSDetected.read, DSDetected.encode, List.append_assoc, bind, Option.bind,
    readLE_headerWordBytes _ _ _ (by norm_num : 1 < 256 ^ 2), hc, hb, hlt, ite_false, ne_eq,
    not_true_eq_false, pure]

/-! ## 4. The detector's events over #62's admission -/

/-- [D] 2026-10-15: `acceptDetect`'s admission component is #62's `acceptWithTrace`:
the detection is read beside the admission and changes nothing of it. A view,
never a rule. -/
theorem acceptDetect_fst (p : Mempool) (utxo : UtxoSet) (cfg : NodeConfig) (ctx : AdmissionContext)
    (lists : FrozenLists) (oracle : ScriptOracle) (observation : DetectorObservation)
    (others : List Tx) (request : TxRequest) :
    (acceptDetect p utxo cfg ctx lists oracle observation others request).1 =
      acceptWithTrace p utxo cfg ctx lists oracle observation request := by
  unfold acceptDetect acceptWithTrace
  split
  · rfl
  · dsimp only
    generalize beforeDetector (request.configOverride.getD cfg) ctx lists oracle
      { pool := p, view := mempoolView p utxo, request := request } = r
    obtain ⟨w, result, trace⟩ := r
    cases result with
    | some o => rfl
    | none => dsimp only

/-- [D] 2026-10-15: a run of stages that stops nowhere names every stage. -/
theorem runAdmissionStages_none (stages : List (AdmissionStage × (AdmissionWork → AdmissionStep)))
    (w w' : AdmissionWork) (tr : List AdmissionStage) (h : runAdmissionStages stages w = (w', none, tr)) :
    tr = stages.map (·.1) := by
  induction stages generalizing w tr with
  | nil => simp [runAdmissionStages] at h; simp [h.2]
  | cons sf rest ih =>
    obtain ⟨st, f⟩ := sf
    simp only [runAdmissionStages] at h
    generalize hf : f w = fw at h
    obtain ⟨w1, result⟩ := fw
    cases result with
    | some o => simp at h
    | none =>
      simp only at h
      generalize hr : runAdmissionStages rest w1 = rr at h
      obtain ⟨w2, r2, t2⟩ := rr
      simp only [Prod.mk.injEq] at h
      obtain ⟨rfl, rfl, rfl⟩ := h
      simp [ih w1 t2 hr]

/-- [D] 2026-10-15: a run that stops names the stopping stage last, and that
stage's check produced the outcome. -/
theorem runAdmissionStages_some (stages : List (AdmissionStage × (AdmissionWork → AdmissionStep)))
    (w w' : AdmissionWork) (o : TxOutcome) (tr : List AdmissionStage)
    (h : runAdmissionStages stages w = (w', some o, tr)) :
    ∃ st f w0, (st, f) ∈ stages ∧ tr.getLast? = some st ∧ f w0 = (w', some o) := by
  induction stages generalizing w tr with
  | nil => simp [runAdmissionStages] at h
  | cons sf rest ih =>
    obtain ⟨st, f⟩ := sf
    simp only [runAdmissionStages] at h
    generalize hf : f w = fw at h
    obtain ⟨w1, result⟩ := fw
    cases result with
    | some o' =>
      simp only [Prod.mk.injEq, Option.some.injEq] at h
      obtain ⟨rfl, rfl, rfl⟩ := h
      exact ⟨st, f, w, List.mem_cons_self .., rfl, hf⟩
    | none =>
      simp only at h
      generalize hr : runAdmissionStages rest w1 = rr at h
      obtain ⟨w2, r2, t2⟩ := rr
      simp only [Prod.mk.injEq] at h
      obtain ⟨rfl, rfl, rfl⟩ := h
      obtain ⟨st', f', w0, hm, hl, hf'⟩ := ih w1 t2 hr
      refine ⟨st', f', w0, List.mem_cons_of_mem _ hm, ?_, hf'⟩
      simp [List.getLast?_cons, hl]

/-- [D] 2026-10-15: the conflict stage refuses only as `txn-mempool-conflict`
(0x102). [SRC] src/validation.cpp:1147-1153 at 6504a3af. -/
theorem stageConflict_some (w w' : AdmissionWork) (o : TxOutcome) (h : stageConflict w = (w', some o)) :
    o = .completed (.rejected (.node 0x102) "txn-mempool-conflict") := by
  unfold stageConflict checkedStep rejectOutcome at h
  split at h <;> simp_all

/-- [D] 2026-10-15: the detector refuses only as `txn-mempool-conflict` (0x102)
or `txn-double-spend-detected` (0x12). [SRC] src/validation.cpp:1484-1494 at 6504a3af. -/
theorem stageDetector_some (obs : DetectorObservation) (w w' : AdmissionWork) (o : TxOutcome)
    (h : stageDetector obs w = (w', some o)) :
    o = .completed (.rejected (.node 0x102) "txn-mempool-conflict") ∨
      o = .completed (.rejected (.node 0x12) "txn-double-spend-detected") := by
  unfold stageDetector checkedStep rejectOutcome at h
  split at h
  · simp_all
  · split at h <;> simp_all

/-- [D] 2026-10-15: what a detection says of its admission's outcome and trace. -/
theorem detection_some (obs : DetectorObservation) (others : List Tx) (request : TxRequest)
    (w : AdmissionWork) (outcome : TxOutcome) (trace : List AdmissionStage) (d : Detection)
    (h : detection obs others request w outcome trace = some d) :
    outcome = .completed (.rejected (.node d.code) d.reason) ∧ d.spender = request.tx ∧
      ((trace.getLast? = some .conflict ∧ d.site = .conflictStage ∧ d.scriptsChecked = false) ∨
       (trace.getLast? = some .detector ∧ d.site ≠ .conflictStage ∧ d.scriptsChecked = true)) := by
  unfold detection at h
  split at h
  · simp only [Option.some.injEq] at h; subst h; simp_all
  · split at h <;> (simp only [Option.some.injEq] at h; subst h; simp_all)
  · simp at h

/-- [D] 2026-10-15: the stages before the detector, as `beforeDetector` runs them. -/
def beforeDetectorStages (cfg : NodeConfig) (ctx : AdmissionContext) (lists : FrozenLists)
    (oracle : ScriptOracle) : List (AdmissionStage × (AdmissionWork → AdmissionStep)) :=
  admissionPrefix cfg ctx ++
    [(.conflict, stageConflict), (.inputs, stageInputs cfg ctx), (.sequence, stageSequence cfg ctx),
     (.inputStandard, stageInputStandard cfg ctx), (.sigops, stageSigops cfg ctx),
     (.fee, stageFee cfg ctx), (.ancestors, stageAncestors cfg ctx),
     (.scripts, stageScripts cfg ctx lists oracle)]

/-- [D] 2026-10-15: `beforeDetector` runs exactly `beforeDetectorStages`. -/
theorem beforeDetector_eq (cfg : NodeConfig) (ctx : AdmissionContext) (lists : FrozenLists)
    (oracle : ScriptOracle) (w : AdmissionWork) :
    beforeDetector cfg ctx lists oracle w = runAdmissionStages (beforeDetectorStages cfg ctx lists oracle) w := rfl

/-- [D] 2026-10-15: the stages before the detector, by name. -/
theorem beforeDetector_names (cfg : NodeConfig) (ctx : AdmissionContext) (lists : FrozenLists)
    (oracle : ScriptOracle) :
    (beforeDetectorStages cfg ctx lists oracle).map (·.1) =
      [.regular, .standard, .finality, .alreadyKnown, .conflict, .inputs, .sequence, .inputStandard,
       .sigops, .fee, .ancestors, .scripts] := by
  simp [beforeDetectorStages, admissionPrefix]

/-- [D] 2026-10-15: THE DETECTOR'S EVENT, READ BACK. A detection of #62's
admission is a completed refusal of the request it names, by the pool's
conflict check (stage 5, 0x102, before any script ran; the scripts are not
marked checked) or by the double-spend detector (stage 13, 0x102 or 0x12,
after every earlier stage ran, the scripts' among them). [SRC]
src/validation.cpp:1147-1153,1478-1494 at 6504a3af. A view, never a rule. -/
theorem acceptDetect_snd (p : Mempool) (utxo : UtxoSet) (cfg : NodeConfig) (ctx : AdmissionContext)
    (lists : FrozenLists) (oracle : ScriptOracle) (observation : DetectorObservation)
    (others : List Tx) (request : TxRequest) (d : Detection)
    (h : (acceptDetect p utxo cfg ctx lists oracle observation others request).2 = some d) :
    (acceptWithTrace p utxo cfg ctx lists oracle observation request).2.1 =
        .completed (.rejected (.node d.code) d.reason) ∧ d.spender = request.tx ∧
      (((acceptWithTrace p utxo cfg ctx lists oracle observation request).2.2.getLast? = some .conflict ∧
          d.site = .conflictStage ∧ d.scriptsChecked = false ∧ d.code = 0x102) ∨
       ((acceptWithTrace p utxo cfg ctx lists oracle observation request).2.2.getLast? = some .detector ∧
          d.site ≠ .conflictStage ∧ d.scriptsChecked = true ∧
          .scripts ∈ (acceptWithTrace p utxo cfg ctx lists oracle observation request).2.2 ∧
          (d.code = 0x102 ∨ d.code = 0x12))) := by
  rw [← acceptDetect_fst p utxo cfg ctx lists oracle observation others request]
  unfold acceptDetect at h ⊢
  split
  · rename_i hp; simp [hp] at h
  · rename_i hp
    simp only [hp, Bool.false_eq_true, ite_false] at h
    dsimp only at h ⊢
    generalize hb : beforeDetector (request.configOverride.getD cfg) ctx lists oracle
      { pool := p, view := mempoolView p utxo, request := request } = r at h ⊢
    obtain ⟨w, result, trace⟩ := r
    cases result with
    | some o =>
      dsimp only at h ⊢
      obtain ⟨ho, hsp, hsite⟩ := detection_some _ _ _ _ _ _ _ h
      rw [beforeDetector_eq] at hb
      obtain ⟨st, f, w0, hm, hl, hf⟩ := runAdmissionStages_some _ _ _ _ _ hb
      have hnames := beforeDetector_names (request.configOverride.getD cfg) ctx lists oracle
      refine ⟨ho, hsp, ?_⟩
      rcases hsite with ⟨hc, hs1, hs2⟩ | ⟨hd, _, _⟩
      · rw [hl] at hc
        simp only [Option.some.injEq] at hc
        subst hc
        have hf' : f = stageConflict := by
          simp [beforeDetectorStages, admissionPrefix] at hm
          exact hm
        subst hf'
        have := stageConflict_some _ _ _ hf
        rw [ho] at this
        simp only [TxOutcome.completed.injEq, TxVerdict.rejected.injEq, RejectCode.node.injEq] at this
        exact .inl ⟨hl, hs1, hs2, this.1⟩
      · rw [hl] at hd
        simp only [Option.some.injEq] at hd
        subst hd
        have hmem : AdmissionStage.detector ∈
            (beforeDetectorStages (request.configOverride.getD cfg) ctx lists oracle).map (·.1) :=
          List.mem_map.mpr ⟨_, hm, rfl⟩
        rw [hnames] at hmem
        simp at hmem
    | none =>
      dsimp only at h ⊢
      rw [beforeDetector_eq] at hb
      have htr := runAdmissionStages_none _ _ _ _ hb
      generalize hs : runAdmissionStages [(.detector, stageDetector observation),
        (.commit, stageCommit (request.configOverride.getD cfg) ctx)] w = r2 at h ⊢
      obtain ⟨w2, res2, suffix⟩ := r2
      dsimp only at h ⊢
      obtain ⟨ho, hsp, hsite⟩ := detection_some _ _ _ _ _ _ _ h
      refine ⟨ho, hsp, ?_⟩
      cases res2 with
      | none => simp at ho
      | some o =>
        simp only [Option.getD_some] at ho
        subst ho
        obtain ⟨st, f, w0, hm, hl, hf⟩ := runAdmissionStages_some _ _ _ _ _ hs
        have hlast : (trace ++ suffix).getLast? = some st := by
          rw [List.getLast?_append, hl]; rfl
        have hsc : AdmissionStage.scripts ∈ trace ++ suffix := by
          apply List.mem_append_left
          rw [htr, beforeDetector_names]; simp
        simp only [List.mem_cons, Prod.mk.injEq, List.not_mem_nil, or_false] at hm
        rcases hsite with ⟨hc, _, _⟩ | ⟨hd, hs1, hs2⟩
        · rw [hlast] at hc
          rcases hm with ⟨rfl, _⟩ | ⟨rfl, _⟩ <;> simp at hc
        · rw [hlast] at hd
          rcases hm with ⟨rfl, rfl⟩ | ⟨rfl, _⟩
          · refine .inr ⟨hlast, hs1, hs2, hsc, ?_⟩
            rcases stageDetector_some _ _ _ _ hf with e | e <;>
              simp only [TxOutcome.completed.injEq, TxVerdict.rejected.injEq, RejectCode.node.injEq] at e
            · exact .inl e.1
            · exact .inr e.1
          · simp at hd

/-! ## 5. The handler: every request belongs to a checked notice of a detection -/

/-- [D] 2026-10-15: a detection of some admission of #62's machine. -/
def Detected (d : Detection) : Prop :=
  ∃ (p : Mempool) (utxo : UtxoSet) (cfg : NodeConfig) (ctx : AdmissionContext) (lists : FrozenLists)
    (oracle : ScriptOracle) (observation : DetectorObservation) (others : List Tx) (request : TxRequest),
    (acceptDetect p utxo cfg ctx lists oracle observation others request).2 = some d

/-- [D] 2026-10-15: a notice is its conflict's: the double spend and one
transaction it collided with are its two sides, the enabled side carries a
notification output, and the watched input and the conflicting input spend one
outpoint. -/
def NoticeShape (n : Notice) : Prop :=
  ((n.enabled ∈ n.detection.collided ∧ n.conflicting = n.detection.spender) ∨
    (n.enabled = n.detection.spender ∧ n.conflicting ∈ n.detection.collided)) ∧
  (dsOutput n.enabled).isSome ∧
  ∃ ei ci, n.enabled.inputs[n.enabledInput]? = some ei ∧ n.conflicting.inputs[n.conflictingInput]? = some ci ∧
    OutPoint.ofInput ci = OutPoint.ofInput ei

/-- [D] 2026-10-15: what the delivery may add to its working state: effects
whose notice satisfies `P`, slow tasks whose notice satisfies `P`. -/
def Grows (P : Notice → Prop) (k k' : Wk) : Prop :=
  (∀ e ∈ k'.effects, e ∈ k.effects ∨ ∀ m, e.notice? = some m → P m) ∧
  (∀ t ∈ k'.slow, t ∈ k.slow ∨ P t.notice)

/-- [D] 2026-10-15: a working state grows from itself. -/
theorem Grows.refl (P : Notice → Prop) (k : Wk) : Grows P k k :=
  ⟨fun _ he => .inl he, fun _ ht => .inl ht⟩

/-- [D] 2026-10-15: growth composes. -/
theorem Grows.trans {P : Notice → Prop} {k1 k2 k3 : Wk} (a : Grows P k1 k2) (b : Grows P k2 k3) :
    Grows P k1 k3 :=
  ⟨fun e he => (b.1 e he).elim (fun h => a.1 e h) .inr, fun t ht => (b.2 t ht).elim (fun h => a.2 t h) .inr⟩

/-- [D] 2026-10-15: one effect whose notice satisfies `P` is a growth. -/
theorem grows_emit (P : Notice → Prop) (k : Wk) (e : Effect) (h : ∀ m, e.notice? = some m → P m) :
    Grows P k (k.emit e) := by
  refine ⟨fun x hx => ?_, fun t ht => .inl ht⟩
  simp only [Wk.emit, List.mem_append, List.mem_singleton] at hx
  rcases hx with hx | rfl
  · exact .inl hx
  · exact .inr h

/-- [D] 2026-10-15: one effect with no notice is a growth under every `P`. -/
theorem grows_plain (P : Notice → Prop) (k : Wk) (e : Effect) (h : e.notice? = none) :
    Grows P k (k.emit e) :=
  grows_emit P k e (fun m hm => by rw [h] at hm; cases hm)

/-- [D] 2026-10-15: replacing the blacklist adds no effect and no task. -/
theorem grows_blacklist (P : Notice → Prop) (k : Wk) (bl : Blacklist) :
    Grows P k { k with blacklist := bl } := ⟨fun _ he => .inl he, fun _ ht => .inl ht⟩

/-- [D] 2026-10-15: reading a reply adds no effect and no task. -/
theorem grows_next (P : Notice → Prop) (k k' : Wk) (r : Reply) (h : k.next = (r, k')) : Grows P k k' := by
  unfold Wk.next at h
  split at h <;> (simp only [Prod.mk.injEq] at h; obtain ⟨_, rfl⟩ := h; exact ⟨fun _ he => .inl he, fun _ ht => .inl ht⟩)

/-- [D] 2026-10-15: blacklisting an endpoint adds one effect with no notice. -/
theorem grows_ban (P : Notice → Prop) (k : Wk) (now : Int) (ep : String) : Grows P k (k.ban now ep) :=
  (grows_blacklist P k _).trans (grows_plain P _ _ rfl)

/-- [D] 2026-10-15: recording a transaction adds at most one effect, with no notice. -/
theorem grows_record (P : Notice → Prop) (cfg : DSConfig) (k : Wk) (id : TxId) : Grows P k (k.record cfg id) := by
  unfold Wk.record
  split
  · exact Grows.refl P k
  · exact Grows.trans (⟨fun _ he => .inl he, fun _ ht => .inl ht⟩ : Grows P k _) (grows_plain P _ _ rfl)

/-- [D] 2026-10-15: queueing a slow task whose notice satisfies `P` is a growth. -/
theorem grows_slow (P : Notice → Prop) (k : Wk) (t : SlowTask) (ep : String) (c : Nat) (h : P t.notice) :
    Grows P k ({ k with slow := k.slow ++ [t] }.emit (.slowQueued ep c)) := by
  refine (?_ : Grows P k { k with slow := k.slow ++ [t] }).trans (grows_plain P _ _ rfl)
  refine ⟨fun _ he => .inl he, fun x hx => ?_⟩
  simp only [List.mem_append, List.mem_singleton] at hx
  rcases hx with hx | rfl
  · exact .inl hx
  · exact .inr h

/-- [D] 2026-10-15: one query-and-proof exchange adds requests and effects only under its own notice.
[SRC] src/double_spend/dsattempt_handler.cpp:698-767 at 6504a3af. -/
theorem attempt_grows (P : Notice → Prop) (cfg : DSConfig) (now : Int) (n : Notice) (ep : String)
    (t : Nat) (k : Wk) (hn : P n) : Grows P k (attempt cfg now n ep t k).2 := by
  have hq : ∀ m, (Effect.query n ep cfg.endpointPort (queryPath n) t).notice? = some m → P m := by
    intro m hm; simp only [Effect.notice?, Option.some.injEq] at hm; exact hm ▸ hn
  have hs : ∀ m, (Effect.submit n ep cfg.endpointPort (submitPath n) (serTx n.conflicting) t).notice? = some m →
      P m := by
    intro m hm; simp only [Effect.notice?, Option.some.injEq] at hm; exact hm ▸ hn
  unfold attempt
  dsimp only
  generalize h1 : (k.emit (.query n ep cfg.endpointPort (queryPath n) t)).next = rk1
  obtain ⟨r1, k1⟩ := rk1
  have g1 : Grows P k k1 := (grows_emit P k _ hq).trans (grows_next P _ k1 r1 h1)
  dsimp only
  split
  · exact g1
  · exact g1
  · exact g1.trans (grows_ban P _ _ _)
  · split
    · exact g1
    · split
      · exact g1
      · split
        · exact g1.trans (grows_ban P _ _ _)
        · split
          · exact g1
          · try dsimp only
            generalize h2 : (k1.emit (.submit n ep cfg.endpointPort (submitPath n) (serTx n.conflicting) t)).next = rk2
            obtain ⟨r2, k2⟩ := rk2
            have g2 : Grows P k k2 := g1.trans ((grows_emit P k1 _ hs).trans (grows_next P _ k2 r2 h2))
            try dsimp only
            split
            · exact g2
            · exact g2
            · exact g2.trans (grows_ban P _ _ _)
            · split
              · exact g2
              · split
                · split
                  · exact g2
                  · exact g2
                · exact g2

/-- [D] 2026-10-15: the fast path's loop adds requests and slow tasks only under its own notice.
[SRC] src/double_spend/dsattempt_handler.cpp:617-649 at 6504a3af. -/
theorem fastLoop_grows (P : Notice → Prop) (cfg : DSConfig) (now : Int) (n : Notice) (ep : String) (hn : P n) :
    ∀ count s w r k, Grows P k (fastLoop cfg now n ep count s w r k) := by
  intro count
  induction count with
  | zero =>
    intro s w r k
    simp only [fastLoop]
    split
    · exact grows_record P cfg k _
    · exact Grows.refl P k
  | succ c ih =>
    intro s w r k
    cases s <;> cases r
    · simp only [fastLoop]; split
      · exact grows_record P cfg k _
      · exact Grows.refl P k
    · rw [show fastLoop cfg now n ep (c + 1) false w true k =
          (match attempt cfg now n ep cfg.fastTimeout k with
           | (.ok s w r, k) => fastLoop cfg now n ep c s w r k
           | (.timeout, k) =>
             fastLoop cfg now n ep c false true false
               ({ k with slow := k.slow ++ [({ endpoint := ep, retries := c + 1, notice := n } : SlowTask)] }.emit
                 (.slowQueued ep (c + 1)))
           | (.error, k) => fastLoop cfg now n ep c false true false k) from rfl]
      generalize ha : attempt cfg now n ep cfg.fastTimeout k = ak
      have ga : Grows P k ak.2 := ha ▸ attempt_grows P cfg now n ep _ k hn
      obtain ⟨en, k'⟩ := ak
      cases en with
      | ok s' w' r' => exact ga.trans (ih s' w' r' k')
      | timeout => exact ga.trans ((grows_slow P k' _ ep _ hn).trans (ih _ _ _ _))
      | error => exact ga.trans (ih _ _ _ _)
    · simp only [fastLoop]; split
      · exact grows_record P cfg k _
      · exact Grows.refl P k
    · simp only [fastLoop]; split
      · exact grows_record P cfg k _
      · exact Grows.refl P k

/-- [D] 2026-10-15: a slow task's loop adds requests only under its own notice.
[SRC] src/double_spend/dsattempt_handler.cpp:660-696 at 6504a3af. -/
theorem slowLoop_grows (P : Notice → Prop) (cfg : DSConfig) (now : Int) (n : Notice) (ep : String) (hn : P n) :
    ∀ count s w r k, Grows P k (slowLoop cfg now n ep count s w r k) := by
  intro count
  induction count with
  | zero =>
    intro s w r k
    simp only [slowLoop]
    split
    · exact grows_record P cfg k _
    · exact Grows.refl P k
  | succ c ih =>
    intro s w r k
    cases s <;> cases r
    · simp only [slowLoop]; split
      · exact grows_record P cfg k _
      · exact Grows.refl P k
    · rw [show slowLoop cfg now n ep (c + 1) false w true k =
          (match attempt cfg now n ep cfg.slowTimeout k with
           | (.ok s w r, k) => slowLoop cfg now n ep c s w r k
           | (_, k) => k) from rfl]
      generalize ha : attempt cfg now n ep cfg.slowTimeout k = ak
      have ga : Grows P k ak.2 := ha ▸ attempt_grows P cfg now n ep _ k hn
      obtain ⟨en, k'⟩ := ak
      cases en with
      | ok s' w' r' => exact ga.trans (ih s' w' r' k')
      | timeout => exact ga
      | error => exact ga
    · simp only [slowLoop]; split
      · exact grows_record P cfg k _
      · exact Grows.refl P k
    · simp only [slowLoop]; split
      · exact grows_record P cfg k _
      · exact Grows.refl P k

/-- [D] 2026-10-15: the loop over a message's addresses adds requests and slow tasks only under its notice.
[SRC] src/double_spend/dsattempt_handler.cpp:556-657 at 6504a3af. -/
theorem sendLoop_grows (P : Notice → Prop) (cfg : DSConfig) (env : Env) (n : Notice) (hn : P n) :
    ∀ addrs count seen k, Grows P k (sendLoop cfg env n addrs count seen k) := by
  intro addrs
  induction addrs with
  | nil => intro count seen k; exact Grows.refl P k
  | cons a rest ih =>
    intro count seen k
    simp only [sendLoop]
    split
    · exact grows_plain P k _ rfl
    · split
      · exact (grows_plain P k _ rfl).trans (ih _ _ _)
      · generalize hc : k.blacklist.check (endpointKey a) env.now = bc
        obtain ⟨black, bl⟩ := bc
        try dsimp only
        refine (?_ : Grows P k _).trans (ih _ _ _)
        refine (grows_blacklist P k bl).trans ?_
        split
        · exact grows_plain P _ _ rfl
        · split
          · exact grows_plain P _ _ rfl
          · split
            · exact grows_slow P _ _ _ _ hn
            · exact fastLoop_grows P cfg env.now n _ hn _ _ _ _ _

/-- [D] 2026-10-15: the verdict loop adds requests and slow tasks only under a
notice it checked and passed. -/
theorem verdictLoop_grows (cfg : DSConfig) (env : Env) (banScore : Nat) (Q : Notice → Prop) :
    ∀ ns k, (∀ n ∈ ns, Q n) →
      Grows (fun m => ∃ n0, Q n0 ∧ m = { n0 with check := .passed } ∧ checkOf env n0 = .passed) k
        (verdictLoop cfg env banScore ns k) := by
  intro ns
  induction ns with
  | nil => intro k _; exact Grows.refl _ k
  | cons n rest ih =>
    intro k hq
    have hrest : ∀ m ∈ rest, Q m := fun m hm => hq m (List.mem_cons_of_mem _ hm)
    simp only [verdictLoop]
    split
    · rename_i hc
      try dsimp only
      refine (?_ : Grows _ k _).trans (ih _ hrest)
      split
      · exact Grows.refl _ k
      · exact sendLoop_grows _ cfg env _ ⟨n, hq n (List.mem_cons_self ..), rfl, hc⟩ _ _ _ _
    · exact grows_plain _ k _ rfl
    · exact (grows_plain _ k _ rfl).trans (ih _ hrest)

/-- [D] 2026-10-15: a pair the search yields names two inputs that spend one outpoint. -/
theorem mem_conflictPairs (e c : Tx) (w : List Nat) (i j : Nat) (h : (i, j) ∈ conflictPairs e c w) :
    ∃ ei ci, e.inputs[i]? = some ei ∧ c.inputs[j]? = some ci ∧ OutPoint.ofInput ci = OutPoint.ofInput ei := by
  unfold conflictPairs at h
  rw [List.mem_flatMap] at h
  obtain ⟨i', _, h⟩ := h
  split at h
  · rename_i ei hei
    rw [List.mem_filterMap] at h
    obtain ⟨j', _, h⟩ := h
    split at h
    · rename_i ci hci
      split at h
      · rename_i heq
        simp only [Option.some.injEq, Prod.mk.injEq] at h
        obtain ⟨rfl, rfl⟩ := h
        exact ⟨ei, ci, hei, hci, by simpa using heq⟩
      · simp at h
    · simp at h
  · simp at h

/-- [D] 2026-10-15: the two sides are the pooled transaction and the double spend, the enabled one carrying a notification output. -/
theorem sides_some (p sp e c : Tx) (o : Nat) (b : Bool) (h : sides p sp = some (e, o, c, b)) :
    ((e = p ∧ c = sp) ∨ (e = sp ∧ c = p)) ∧ dsOutput e = some o := by
  unfold sides at h
  cases h1 : dsOutput p with
  | some o1 =>
    rw [h1] at h
    simp only [Option.some.injEq, Prod.mk.injEq] at h
    obtain ⟨rfl, rfl, rfl, rfl⟩ := h
    exact ⟨.inl ⟨rfl, rfl⟩, h1⟩
  | none =>
    cases h2 : dsOutput sp with
    | some o2 =>
      rw [h1, h2] at h
      simp only [Option.some.injEq, Prod.mk.injEq] at h
      obtain ⟨rfl, rfl, rfl, rfl⟩ := h
      exact ⟨.inr ⟨rfl, rfl⟩, h2⟩
    | none => rw [h1, h2] at h; simp at h

/-- [D] 2026-10-15: a notice the handler builds names its detection, the two
sides of the conflict on one outpoint, and an enabled side with a notification
output; it is not yet checked. -/
theorem noticeFor_some (env : Env) (d : Detection) (t : Tx) (std : Bool) (n : Notice)
    (h : noticeFor env d t std = .ok (some n)) :
    n.detection = d ∧ n.check = .cancelled ∧
      ((n.enabled = t ∧ n.conflicting = d.spender) ∨ (n.enabled = d.spender ∧ n.conflicting = t)) ∧
      (dsOutput n.enabled).isSome ∧
      ∃ ei ci, n.enabled.inputs[n.enabledInput]? = some ei ∧ n.conflicting.inputs[n.conflictingInput]? = some ci ∧
        OutPoint.ofInput ci = OutPoint.ofInput ei := by
  unfold noticeFor at h
  split at h
  · simp at h
  · rename_i enabled out conflicting isSpender hs
    obtain ⟨hside, hout⟩ := sides_some _ _ _ _ _ _ hs
    split at h
    · simp at h
    · split at h
      · simp at h
      · split at h
        · simp at h
        · dsimp only at h
          split at h
          · simp at h
          · rename_i i c hf
            simp only [Except.ok.injEq, Option.some.injEq] at h
            subst h
            have hm := List.mem_of_find?_eq_some hf
            obtain ⟨ei, ci, h1, h2, h3⟩ := mem_conflictPairs _ _ _ _ _ hm
            exact ⟨rfl, rfl, hside, by simp [hout], ei, ci, h1, h2, h3⟩

/-- [D] 2026-10-15: every notice of the loop is `noticeFor`'s for one collided transaction. -/
theorem noticesLoop_mem (env : Env) (d : Detection) (std : Bool) :
    ∀ (ts : List Tx) (ns : List Notice), noticesLoop env d std ts = some ns →
      ∀ n ∈ ns, ∃ t ∈ ts, noticeFor env d t std = .ok (some n) := by
  intro ts
  induction ts with
  | nil => intro ns h n hn; simp [noticesLoop] at h; subst h; simp at hn
  | cons t ts ih =>
    intro ns h n hn
    simp only [noticesLoop] at h
    split at h
    · simp at h
    · rename_i o ho
      cases hl : noticesLoop env d std ts with
      | none => simp [hl] at h
      | some rest =>
        simp only [hl, Option.map_some, Option.some.injEq] at h
        subst h
        rcases List.mem_append.mp hn with hn | hn
        · cases o with
          | none => simp at hn
          | some o => simp at hn; subst hn; exact ⟨t, List.mem_cons_self .., ho⟩
        · obtain ⟨t', ht', h'⟩ := ih rest hl n hn
          exact ⟨t', List.mem_cons_of_mem _ ht', h'⟩

/-- [D] 2026-10-15: every notice of an attempt is its conflict's. -/
theorem mem_notices (cfg : DSConfig) (env : Env) (d : Detection) (n : Notice) (h : n ∈ notices cfg env d) :
    n.detection = d ∧ NoticeShape n := by
  unfold notices at h
  cases hl : noticesLoop env d (cfg.level = .standard || env.suspended) d.collided with
  | none => simp [hl] at h
  | some ns =>
    simp only [hl, Option.getD_some] at h
    obtain ⟨t, ht, hf⟩ := noticesLoop_mem env d _ d.collided ns hl n h
    obtain ⟨hd, _, hside, hout, hpt⟩ := noticeFor_some env d t _ n hf
    refine ⟨hd, ?_, hout, hpt⟩
    rw [hd]
    rcases hside with ⟨h1, h2⟩ | ⟨h1, h2⟩
    · exact .inl ⟨h1 ▸ ht, h2⟩
    · exact .inr ⟨h1, h2 ▸ ht⟩

/-- [D] 2026-10-15: what one processing step sends and queues: every request
and every new slow task carries a notice of the popped attempt that its script
check passed. -/
theorem process_grows (cfg : DSConfig) (banScore : Nat) (h : HandlerState) (env : Env)
    (q : Queued) (rest : List Queued) (hq : h.queue = q :: rest) :
    (∀ e ∈ (process cfg banScore h env).2, ∀ m, e.notice? = some m →
        ∃ n0 ∈ notices cfg env q.detection, m = { n0 with check := .passed } ∧ checkOf env n0 = .passed) ∧
    (∀ t ∈ (process cfg banScore h env).1.slow, t ∈ h.slow ∨
        ∃ n0 ∈ notices cfg env q.detection, t.notice = { n0 with check := .passed } ∧ checkOf env n0 = .passed) ∧
    (process cfg banScore h env).1.queue = rest := by
  unfold process
  rw [hq]
  dsimp only
  have g := verdictLoop_grows cfg env banScore (· ∈ notices cfg env q.detection)
    (notices cfg env q.detection)
    { blacklist := h.blacklist, notified := h.notified, slow := h.slow, replies := env.replies, effects := [] }
    (fun _ hn => hn)
  refine ⟨fun e he m hm => ?_, fun t ht => ?_, rfl⟩
  · rcases g.1 e he with h0 | h1
    · simp at h0
    · obtain ⟨n0, hn0, rfl, hc⟩ := h1 m hm
      exact ⟨n0, hn0, rfl, hc⟩
  · rcases g.2 t ht with h0 | ⟨n0, hn0, he, hc⟩
    · exact .inl h0
    · exact .inr ⟨n0, hn0, he, hc⟩

/-- [D] 2026-10-15: THE THEOREM, the handler's half. **A notification is
emitted only for a conflict the detector saw**: every query and every proof a
processing step sends names a notice whose attempt is a detection of #62's
admission (`Detected`), whose two sides are that conflict's on one outpoint
with a notification output on the enabled side (`NoticeShape`), and whose
double-spend input passed the script check that step ran or the admission
already ran (`checkOf`, recorded on the notice as `check`). Premise in plain
words: the queue holds only detections, which `Reach` below proves of every
reachable state. [SRC] src/double_spend/dsattempt_handler.cpp:323-465,555-767,
src/net/net.cpp:2653-2659, src/validation.cpp:1733-1757 at 6504a3af.
`Detected` is existential: some state of #62's machine (pool, UTXO view,
settings, script oracle, detector observation) refuses the double spend with
that detection, and `Reach` queues any such detection, so the theorem binds a
notice to a refusal #62's machine makes, not to this node's own admission; the
handler's own script check is an input (`Env.scriptCheck`), not #62's oracle;
the composed machine is owed. A view, never a rule. -/
theorem notification_only_after_detection (cfg : DSConfig) (banScore : Nat) (h : HandlerState) (env : Env)
    (hq : ∀ q ∈ h.queue, Detected q.detection) (e : Effect) (he : e ∈ (process cfg banScore h env).2)
    (n : Notice) (hn : e.notice? = some n) :
    Detected n.detection ∧ NoticeShape n ∧ n.check = .passed ∧ checkOf env n = .passed := by
  cases hqueue : h.queue with
  | nil =>
    unfold process at he
    rw [hqueue] at he
    simp at he
  | cons q rest =>
    obtain ⟨hr, _, _⟩ := process_grows cfg banScore h env q rest hqueue
    obtain ⟨n0, hn0, rfl, hc⟩ := hr e he n hn
    obtain ⟨hd, hshape⟩ := mem_notices cfg env q.detection n0 hn0
    have hdet : Detected q.detection := hq q (by rw [hqueue]; exact List.mem_cons_self ..)
    exact ⟨hd ▸ hdet, hshape, rfl, hc⟩

/-- [D] 2026-10-15: THE THEOREM, spelled against #62's machine. Every query and
every proof a processing step sends is for a completed refusal by
`acceptWithTrace` of a request whose transaction is one side of the notice;
either the refusal is the pool's conflict check (stage 5, `txn-mempool-conflict`
0x102), reached before any script ran, and the handler's own script check of
the double-spend input passed before it sent; or the refusal is the
double-spend detector's (stage 13, 0x102 or `txn-double-spend-detected` 0x12),
reached after every earlier stage, the script stage among them. **The issue's
sentence "after validation" holds literally of the detector's refusals only;
for a stage-5 conflict the detector saw the conflict before the double spend's
scripts ran, and the handler validates the input itself before it notifies**
(src/double_spend/dsattempt_handler.cpp:149-178,396-421 at 6504a3af).
`Detected` is existential: some state of #62's machine (pool, UTXO view,
settings, script oracle, detector observation) refuses the double spend with
that detection, and `Reach` queues any such detection, so the theorem binds a
notice to a refusal #62's machine makes, not to this node's own admission; the
handler's own script check is an input (`Env.scriptCheck`), not #62's oracle;
the composed machine is owed.
A notification is never a verdict. A view, never a rule. -/
theorem notification_conflict_after_validation (cfg : DSConfig) (banScore : Nat) (h : HandlerState)
    (env : Env) (hq : ∀ q ∈ h.queue, Detected q.detection) (e : Effect)
    (he : e ∈ (process cfg banScore h env).2) (n : Notice) (hn : e.notice? = some n) :
    ∃ (p : Mempool) (utxo : UtxoSet) (mcfg : NodeConfig) (ctx : AdmissionContext) (lists : FrozenLists)
      (oracle : ScriptOracle) (observation : DetectorObservation) (request : TxRequest),
      (acceptWithTrace p utxo mcfg ctx lists oracle observation request).2.1 =
          .completed (.rejected (.node n.detection.code) n.detection.reason) ∧
      request.tx = n.detection.spender ∧ (n.enabled = request.tx ∨ n.conflicting = request.tx) ∧
      (((acceptWithTrace p utxo mcfg ctx lists oracle observation request).2.2.getLast? = some .conflict ∧
          n.detection.code = 0x102 ∧ env.scriptCheck request.tx n.spendInput = .passed) ∨
       ((acceptWithTrace p utxo mcfg ctx lists oracle observation request).2.2.getLast? = some .detector ∧
          .scripts ∈ (acceptWithTrace p utxo mcfg ctx lists oracle observation request).2.2 ∧
          (n.detection.code = 0x102 ∨ n.detection.code = 0x12))) := by
  obtain ⟨⟨p, utxo, mcfg, ctx, lists, oracle, observation, others, request, hdet⟩, hshape, _, hc⟩ :=
    notification_only_after_detection cfg banScore h env hq e he n hn
  obtain ⟨ho, hsp, hsite⟩ := acceptDetect_snd p utxo mcfg ctx lists oracle observation others request _ hdet
  refine ⟨p, utxo, mcfg, ctx, lists, oracle, observation, request, ho, hsp.symm, ?_, ?_⟩
  · rcases hshape.1 with ⟨_, h2⟩ | ⟨h1, _⟩
    · exact .inr (h2.trans hsp)
    · exact .inl (h1.trans hsp)
  · rcases hsite with ⟨hl, _, hsc, hcode⟩ | ⟨hl, _, _, hs, hcode⟩
    · refine .inl ⟨hl, hcode, ?_⟩
      unfold checkOf at hc
      rw [hsc] at hc
      simpa [← hsp] using hc
    · exact .inr ⟨hl, hs, hcode⟩

/-- [D] 2026-10-15: a notice a request may carry: a detection's, its conflict's, checked and passed. -/
def Good (n : Notice) : Prop := Detected n.detection ∧ NoticeShape n ∧ n.check = .passed

/-- [D] 2026-10-15: the handler's reachable states: from its start, an attempt
queued only from a detection of #62's admission (the publisher's callback,
src/net/net.cpp:2653-2659), a processing step, a slow-queue task run. -/
inductive Reach (cfg : DSConfig) (banScore : Nat) : HandlerState → Prop
  | start : Reach cfg banScore (HandlerState.init cfg)
  | queued {h : HandlerState} (d : Detection) (usage : Nat) :
      Reach cfg banScore h → Detected d → Reach cfg banScore (handle cfg h d usage)
  | processed {h : HandlerState} (env : Env) :
      Reach cfg banScore h → Reach cfg banScore (process cfg banScore h env).1
  | slowRun {h : HandlerState} (env : Env) :
      Reach cfg banScore h → Reach cfg banScore (processSlow cfg h env).1

/-- [D] 2026-10-15: the invariant: the queue holds detections, the slow queue good notices. -/
theorem reach_invariant (cfg : DSConfig) (banScore : Nat) (h : HandlerState) (hr : Reach cfg banScore h) :
    (∀ q ∈ h.queue, Detected q.detection) ∧ (∀ t ∈ h.slow, Good t.notice) := by
  induction hr with
  | start => exact ⟨fun _ hq => by simp [HandlerState.init] at hq, fun _ ht => by simp [HandlerState.init] at ht⟩
  | queued d usage _ hd ih =>
    unfold handle
    split
    · exact ih
    · split
      · exact ih
      · split
        · exact ih
        · refine ⟨fun q hq => ?_, ih.2⟩
          simp only [List.mem_append, List.mem_singleton] at hq
          rcases hq with hq | rfl
          · exact ih.1 q hq
          · exact hd
  | @processed h env _ ih =>
    cases hqueue : h.queue with
    | nil =>
      unfold process; rw [hqueue]; exact ih
    | cons q rest =>
      obtain ⟨_, hs, hqr⟩ := process_grows cfg banScore h env q rest hqueue
      have hdq : Detected q.detection := ih.1 q (by rw [hqueue]; exact List.mem_cons_self ..)
      refine ⟨fun q' hq' => ?_, fun t ht => ?_⟩
      · rw [hqr] at hq'
        exact ih.1 q' (by rw [hqueue]; exact List.mem_cons_of_mem _ hq')
      · rcases hs t ht with h0 | ⟨n0, hn0, hn, _⟩
        · exact ih.2 t h0
        · obtain ⟨hd, hshape⟩ := mem_notices cfg env q.detection n0 hn0
          rw [hn]
          exact ⟨hd ▸ hdq, hshape, rfl⟩
  | @slowRun h env _ ih =>
    unfold processSlow
    split
    · exact ih
    · rename_i t rest hslow
      dsimp only
      have g := slowLoop_grows (· = t.notice) cfg env.now t.notice t.endpoint rfl t.retries false false true
        { blacklist := h.blacklist, notified := h.notified, slow := rest, replies := env.replies, effects := [] }
      have ht : Good t.notice := ih.2 t (by rw [hslow]; exact List.mem_cons_self ..)
      refine ⟨ih.1, fun t' ht' => ?_⟩
      rcases g.2 t' ht' with h0 | h1
      · exact ih.2 t' (by rw [hslow]; exact List.mem_cons_of_mem _ h0)
      · rw [h1]; exact ht

/-- [D] 2026-10-15: THE THEOREM over every reachable state: no request of the
handler, from the fast path or the slow queue, carries a notice that is not a
checked notice of a conflict the detector saw. A view, never a rule. -/
theorem every_request_good (cfg : DSConfig) (banScore : Nat) (h : HandlerState) (hr : Reach cfg banScore h)
    (env : Env) (e : Effect) (he : e ∈ (process cfg banScore h env).2 ∨ e ∈ (processSlow cfg h env).2)
    (n : Notice) (hn : e.notice? = some n) : Good n := by
  have inv := reach_invariant cfg banScore h hr
  rcases he with he | he
  · obtain ⟨hd, hs, hc, _⟩ := notification_only_after_detection cfg banScore h env inv.1 e he n hn
    exact ⟨hd, hs, hc⟩
  · unfold processSlow at he
    split at he
    · simp at he
    · rename_i t rest hslow
      have g := slowLoop_grows (· = t.notice) cfg env.now t.notice t.endpoint rfl t.retries false false true
        { blacklist := h.blacklist, notified := h.notified, slow := rest, replies := env.replies, effects := [] }
      rcases g.1 e he with h0 | h1
      · simp at h0
      · rw [h1 n hn]; exact inv.2 t (by rw [hslow]; exact List.mem_cons_self ..)

/-! ## 6. The blacklist and the delivery's skips -/

/-- [D] 2026-10-15: inserting a fresh endpoint keeps a subset of the old entries and appends the new one. -/
theorem Blacklist.insert_fresh (b : Blacklist) (item : String) (exp : Int)
    (h : ∀ x ∈ b.entries, x.1 ≠ item) :
    ∃ kept, (b.insert item exp).entries = kept ++ [(item, exp)] ∧ ∀ x ∈ kept, x ∈ b.entries := by
  unfold Blacklist.insert
  have hany : b.entries.any (·.1 == item) = false := by
    rw [List.any_eq_false]; intro x hx; simpa using h x hx
  simp only [hany, Bool.false_eq_true, ite_false]
  split
  · split
    · rename_i m _
      exact ⟨b.entries.erase m, rfl, fun x hx => List.mem_of_mem_erase hx⟩
    · exact ⟨b.entries, rfl, fun x hx => hx⟩
  · exact ⟨b.entries, rfl, fun x hx => hx⟩

/-- [D] 2026-10-15: an added endpoint is found with its new expiry: the
insertion never evicts itself and the update erased the old entry.
[SRC] src/double_spend/time_limited_blacklist.h:41-64, src/limitedmap.h:41-50 at 6504a3af. -/
theorem Blacklist.find_add (b : Blacklist) (item : String) (exp : Int) :
    (b.add item exp).entries.find? (·.1 == item) = some (item, exp) := by
  unfold Blacklist.add
  obtain ⟨kept, he, hk⟩ := Blacklist.insert_fresh { b with entries := b.entries.filter (·.1 != item) } item exp
    (fun x hx => by simp only [List.mem_filter, bne_iff_ne, ne_eq] at hx; exact hx.2)
  rw [he, List.find?_append]
  have hnone : kept.find? (·.1 == item) = none := by
    rw [List.find?_eq_none]
    intro x hx
    have := hk x hx
    simp only [List.mem_filter, bne_iff_ne, ne_eq] at this
    simpa using this.2
  simp [hnone]

/-- [D] 2026-10-15: THE BLACKLIST'S HOUR. An endpoint the handler blacklists
at time `t` (`AddToBlacklist`: until `t` plus 3600 s) is blacklisted at every
earlier instant before the hour is out and not at or after it, whatever the
list held. [SRC] src/double_spend/dsattempt_handler.cpp:28,316-321,
src/double_spend/time_limited_blacklist.h:41-107 at 6504a3af. A view, never a rule. -/
theorem Blacklist.add_hour (b : Blacklist) (ep : String) (t now : Int) :
    ((b.add ep (t + blacklistDuration)).check ep now).1 = decide (now < t + 3600) := by
  unfold Blacklist.check
  rw [Blacklist.find_add]
  simp only [blacklistDuration]
  by_cases h : now < t + 3600 <;> simp [h]

/-- [D] 2026-10-15: past its hour the entry is erased by the check that finds it expired. -/
theorem Blacklist.check_erases (b : Blacklist) (ep : String) (exp now : Int) (h : exp ≤ now)
    (hf : b.entries.find? (·.1 == ep) = some (ep, exp)) :
    (b.check ep now).1 = false ∧ ∀ x ∈ (b.check ep now).2.entries, x.1 ≠ ep := by
  unfold Blacklist.check
  rw [hf]
  have : ¬ now < exp := by omega
  simp only [this, ite_false, true_and]
  intro x hx
  simp only [List.mem_filter, bne_iff_ne, ne_eq] at hx
  exact hx.2

/-- [D] 2026-10-15: an endpoint blacklisted at the check is never queried: the
one-address loop records the skip and sends nothing. [SRC]
src/double_spend/dsattempt_handler.cpp:575-605 at 6504a3af. A view, never a rule. -/
theorem sendLoop_blacklisted (cfg : DSConfig) (env : Env) (n : Notice) (a : Bytes) (k : Wk)
    (hmax : 1 ≤ cfg.maxEndpoints) (hb : (k.blacklist.check (endpointKey a) env.now).1 = true) :
    (sendLoop cfg env n [a] 0 [] k).effects = k.effects ++ [.skipped (endpointKey a) "blacklist"] := by
  have hc : ¬ 0 + 1 > cfg.maxEndpoints := by omega
  generalize hk : k.blacklist.check (endpointKey a) env.now = bc at hb
  obtain ⟨black, bl⟩ := bc
  simp only at hb
  subst hb
  simp [sendLoop, hc, hk, Wk.emit]

/-! ## 7. The `dsdetected` handling -/

/-- [D] 2026-10-15: THE `dsdetected` RELAY. The node sends something only for a
message it read, had not seen, judged valid, found high enough, whose headers
it accepted and whose blocks it marked; it relays the message to every peer
but the sender and posts it to the webhook only when one is set. Nothing here
judges a block or a transaction. [SRC] src/net/net_processing.cpp:4573-4684 at
6504a3af. A view, never a rule. -/
theorem processDSDetected_sends (cfg : DSConfig) (mfd : Nat) (cv : ChainView) (c : DSDCache) (sender : Nat)
    (peers : List Nat) (payload : Bytes) (e : DSDEffect)
    (he : e ∈ (processDSDetected cfg mfd cv c sender peers payload).2.2) :
    ∃ m rest, DSDetected.read payload = some (m, rest) ∧ ¬ (cacheKey m ∈ c.keys) ∧ m.valid = true ∧
      forkHeightOk mfd cv m = true ∧ cv.headersAccepted = true ∧ cv.statusUpdated = true ∧
      (processDSDetected cfg mfd cv c sender peers payload).2.1 = .relayed ∧
      ((∃ p, p ∈ peers ∧ p ≠ sender ∧ e = .relay p m.encode) ∨
        ∃ host port path, cfg.webhook = some (host, port, path) ∧
          e = .webhook host port path (m.json cfg.webhookMaxTxnSize)) := by
  unfold processDSDetected at he ⊢
  cases hread : DSDetected.read payload with
  | none => simp [hread] at he
  | some mr =>
    obtain ⟨m, rest⟩ := mr
    simp only [hread] at he ⊢
    by_cases hk : cacheKey m ∈ c.keys
    · simp [hk] at he
    · by_cases hv : m.valid = true
      · by_cases hf : forkHeightOk mfd cv m = true
        · by_cases hh : cv.headersAccepted = true
          · by_cases hs : cv.statusUpdated = true
            · simp only [List.contains_iff_mem, hk, hv, hf, hh, hs, Bool.not_true,
                Bool.false_eq_true, ite_false] at he ⊢
              refine ⟨m, rest, rfl, hk, hv, hf, trivial, trivial, trivial, ?_⟩
              simp only [List.mem_append, List.mem_map, List.mem_filter, bne_iff_ne, ne_eq] at he
              rcases he with ⟨p, ⟨hp, hne⟩, rfl⟩ | he
              · exact .inl ⟨p, hp, by simpa using hne, rfl⟩
              · split at he
                · rename_i host port path hw
                  simp only [List.mem_singleton] at he
                  exact .inr ⟨host, port, path, hw, he⟩
                · simp at he
            · simp [hk, hv, hf, hh, hs] at he
          · simp [hk, hv, hf, hh] at he
        · simp [hk, hv, hf] at he
      · simp [hk, hv] at he

/-- [D] 2026-10-15: a message seen before is answered with nothing, whatever it
holds (the duplicate cache, src/net/net_processing.cpp:4601-4616 at 6504a3af). -/
theorem processDSDetected_duplicate (cfg : DSConfig) (mfd : Nat) (cv : ChainView) (c : DSDCache)
    (sender : Nat) (peers : List Nat) (payload : Bytes) (m : DSDetected) (rest : Bytes)
    (hr : DSDetected.read payload = some (m, rest)) (hk : cacheKey m ∈ c.keys) :
    processDSDetected cfg mfd cv c sender peers payload = (c, .duplicate, []) := by
  unfold processDSDetected
  simp [hr, hk]

end BsvChain.Wire.DoubleSpend
