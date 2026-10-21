import BsvChain.Views.MinerId
import BsvChain.Properties.TxCodec

/-!
# Miner ID: the frames round-trip, and what the database's transitions keep (#83)

[M] 2026-10-15 (#83). Views, never rules: nothing of Miner ID is consensus (cited in
`lean/BsvChain/Views/MinerId.lean`'s header).
The output frames of `BsvChain.Views.MinerId` read back what a miner writes (the 0.1/0.2
coinbase output, the 0.3 reference, the miner-info output, the dataref output and the
`revokemid` message); on the database: the reputation test is false for a voided miner
and after an invalid block from a CURRENT id, and it does not read the id's state; a
`revokemid` that the node accepts leaves the compromised id REVOKED; a full revocation
leaves every id of the miner REVOKED; a block that reuses a REVOKED id leaves every id
entry as it was; the recent-blocks table never holds more than N rows.
[SRC] bitcoin-sv v1.2.3 at 6504a3aff65ba97c0f6c80962b033e35ecbfed4b:
src/script/instruction_iterator.h:19-128, src/script/script.h:104-133,309-320,
src/script/script.cpp:198-207, src/miner_id/miner_id.cpp:454-555,
src/miner_id/miner_info_ref.cpp:60-114, src/miner_id/miner_info_doc.cpp:445-491,
src/miner_id/miner_info.cpp:231-262, src/miner_id/revokemid.h:49-97,
src/miner_id/miner_id_db.cpp:205-329,1010-1128,1153-1166,1361-1374.
-/

namespace BsvChain.Properties
open BsvScript.Numbers BsvScript.Tx BsvScript.Hash BsvScript.Sighash BsvChain.Views.MinerId

/-- [D] 2026-10-15: a direct push opcode (1 to 75) reads that many bytes.
[SRC] src/script/instruction_iterator.h:34-42 at 6504a3af. -/
theorem readInstr_direct (op : Nat) (s : Bytes) (h0 : 0 < op) (h1 : op < 0x4c) (hs : s ≠ []) :
    readInstr (op :: s) = (readBytes op s).map fun (d, r) => (op, d, r) := by
  simp only [readInstr]
  rw [if_neg (by omega), if_neg hs, if_pos h1]

/-- [D] 2026-10-15: `OP_PUSHDATA1` reads a one-byte length. [SRC] src/script/instruction_iterator.h:44-50 at 6504a3af. -/
theorem readInstr_pd1 (s : Bytes) (hs : s ≠ []) :
    readInstr (0x4c :: s) = (readLE 1 s).bind fun (n, r) => (readBytes n r).map fun (d, r') => (0x4c, d, r') := by
  simp only [readInstr]
  rw [if_neg (by decide), if_neg hs, if_neg (by decide), ite_true]

/-- [D] 2026-10-15: `OP_PUSHDATA2` reads a two-byte length. [SRC] src/script/instruction_iterator.h:52-63 at 6504a3af. -/
theorem readInstr_pd2 (s : Bytes) (hs : s ≠ []) :
    readInstr (0x4d :: s) = (readLE 2 s).bind fun (n, r) => (readBytes n r).map fun (d, r') => (0x4d, d, r') := by
  simp only [readInstr]
  rw [if_neg (by decide), if_neg hs, if_neg (by decide), if_neg (by decide), ite_true]

/-- [D] 2026-10-15: `OP_PUSHDATA4` reads a four-byte length. [SRC] src/script/instruction_iterator.h:65-75 at 6504a3af. -/
theorem readInstr_pd4 (s : Bytes) (hs : s ≠ []) :
    readInstr (0x4e :: s) = (readLE 4 s).bind fun (n, r) => (readBytes n r).map fun (d, r') => (0x4e, d, r') := by
  simp only [readInstr]
  rw [if_neg (by decide), if_neg hs, if_neg (by decide), if_neg (by decide), if_neg (by decide)]

/-- [D] 2026-10-15: a minimal push reads back as its operand, with any following stream
untouched; the empty push is `OP_0`, read as the empty operand.
[SRC] src/script/script.h:104-133, src/script/instruction_iterator.h:19-77 at 6504a3af. -/
theorem readOperand_pushData (b rest : Bytes) (h : b.length < 2 ^ 32) :
    readOperand (pushData b ++ rest) = some (b, rest) := by
  unfold pushData
  by_cases h1 : b.length < BsvScript.Op.OP_PUSHDATA1
  · rw [if_pos h1]
    have h1' : b.length < 76 := h1
    rcases b with _ | ⟨x, xs⟩
    · rfl
    · have e : ((x :: xs).length :: (x :: xs)) ++ rest = (x :: xs).length :: ((x :: xs) ++ rest) := rfl
      rw [e]
      unfold readOperand
      rw [readInstr_direct _ _ (by simp) h1' (by simp), readBytes_append]
      rfl
  · rw [if_neg h1]
    by_cases h2 : b.length ≤ 0xff
    · rw [if_pos h2]
      have e : (BsvScript.Op.OP_PUSHDATA1 :: b.length :: b) ++ rest = 0x4c :: (b.length :: (b ++ rest)) := rfl
      have r1 : readLE 1 (b.length :: (b ++ rest)) = some (b.length, b ++ rest) := by
        simp [readLE, leNat]
      rw [e]
      unfold readOperand
      rw [readInstr_pd1 _ (by simp), r1]
      simp only [Option.bind_some, readBytes_append, Option.map_some]
    · rw [if_neg h2]
      by_cases h3 : b.length ≤ 0xffff
      · rw [if_pos h3]
        have e : (BsvScript.Op.OP_PUSHDATA2 :: [b.length % 256, b.length / 256 % 256] ++ b) ++ rest =
            0x4d :: (headerWordBytes 2 b.length ++ (b ++ rest)) := rfl
        have r2 := readLE_headerWordBytes 2 b.length (b ++ rest) (by omega)
        rw [e]
        unfold readOperand
        rw [readInstr_pd2 _ (by simp [headerWordBytes]), r2]
        simp only [Option.bind_some, readBytes_append, Option.map_some]
      · rw [if_neg h3]
        have e : (BsvScript.Op.OP_PUSHDATA4 :: le32 b.length ++ b) ++ rest =
            0x4e :: (headerWordBytes 4 b.length ++ (b ++ rest)) := by rw [le32_eq]; rfl
        have r4 := readLE_headerWordBytes 4 b.length (b ++ rest) (by omega)
        rw [e]
        unfold readOperand
        rw [readInstr_pd4 _ (by simp [headerWordBytes]), r4]
        simp only [Option.bind_some, readBytes_append, Option.map_some]

/-- [D] 2026-10-15: the same with nothing after the push. -/
theorem readOperand_pushData_nil (b : Bytes) (h : b.length < 2 ^ 32) :
    readOperand (pushData b) = some (b, []) := by
  simpa using readOperand_pushData b [] h

/-- [D] 2026-10-15: a minimal push begins with a push opcode (at most `OP_PUSHDATA4`), so
`IsMinerId`'s byte-7 test holds for every encoded output. [SRC] src/script/script.cpp:206 at 6504a3af. -/
theorem pushData_head (b : Bytes) : ∃ op t, pushData b = op :: t ∧ op ≤ 0x4e := by
  unfold pushData
  by_cases h1 : b.length < BsvScript.Op.OP_PUSHDATA1
  · rw [if_pos h1]; have h1' : b.length < 76 := h1; exact ⟨_, _, rfl, by omega⟩
  · rw [if_neg h1]
    by_cases h2 : b.length ≤ 0xff
    · rw [if_pos h2]; exact ⟨_, _, rfl, by decide⟩
    · rw [if_neg h2]
      by_cases h3 : b.length ≤ 0xffff
      · rw [if_pos h3]; exact ⟨_, _, rfl, by decide⟩
      · rw [if_neg h3]; exact ⟨_, _, rfl, by decide⟩

/-- [D] 2026-10-15: the empty stream has no instruction (the iterator at the end).
[SRC] src/script/instruction_iterator.h:22-23 at 6504a3af. -/
theorem readOperand_nil : readOperand [] = none := rfl

/-- [D] 2026-10-15: a byte string of the stated length reads back.
[SRC] src/serialize.h:786-792 at 6504a3af. -/
theorem readBytes_of_length (s rest : Bytes) (n : Nat) (h : s.length = n) :
    readBytes n (s ++ rest) = some (s, rest) := h ▸ readBytes_append s rest

/-- [D] 2026-10-15: the 0.1/0.2 output a miner writes reads back: the static document and
signature (non-empty, as the node requires) and the dynamic pair when present.
[SRC] src/miner_id/miner_id.cpp:454-555, src/script/script.cpp:198-207 at 6504a3af. -/
theorem minerIdOutput_decode_encode (o : MinerIdOutput) (hd : o.staticDoc ≠ []) (hs : o.staticSig ≠ [])
    (ld : o.staticDoc.length < 2 ^ 32) (ls : o.staticSig.length < 2 ^ 32)
    (ldyn : ∀ d s, o.dynamic = some (d, s) → d.length < 2 ^ 32 ∧ s.length < 2 ^ 32) :
    MinerIdOutput.decode o.encode = some o := by
  obtain ⟨op, t, hp, hop⟩ := pushData_head o.staticDoc
  have hm : isMinerId o.encode = true := by
    simp [isMinerId, MinerIdOutput.encode, frameHead, minerIdProtocolId, hp, hop]
  rcases o with ⟨doc, sig, _ | ⟨d, s⟩⟩
  · simp only at hd hs ld ls hm
    have hdrop : (MinerIdOutput.encode ⟨doc, sig, none⟩).drop 7 = pushData doc ++ (pushData sig ++ []) := by
      simp [MinerIdOutput.encode, frameHead, minerIdProtocolId]
    unfold MinerIdOutput.decode
    rw [hm, hdrop]
    simp only [Bool.not_true, Bool.false_eq_true, ite_false, readOperand_pushData _ _ ld, hd,
      readOperand_pushData _ _ ls, hs, readOperand_nil]
  · obtain ⟨l1, l2⟩ := ldyn d s rfl
    simp only at hd hs ld ls hm
    have hdrop : (MinerIdOutput.encode ⟨doc, sig, some (d, s)⟩).drop 7 =
        pushData doc ++ (pushData sig ++ (pushData d ++ (pushData s ++ []))) := by
      simp [MinerIdOutput.encode, frameHead, minerIdProtocolId]
    unfold MinerIdOutput.decode
    rw [hm, hdrop]
    simp only [Bool.not_true, Bool.false_eq_true, ite_false, readOperand_pushData _ _ ld, hd,
      readOperand_pushData _ _ ls, hs, readOperand_pushData _ _ l1, readOperand_pushData _ _ l2]

/-- [D] 2026-10-15: the version push reads back. [SRC] src/miner_id/miner_info_ref.cpp:77-87 at 6504a3af. -/
theorem readVersion_push (rest : Bytes) : readVersion (pushData [0] ++ rest) = .ok rest := by
  simp [readVersion, readOperand_pushData [0] rest (by decide)]

/-- [D] 2026-10-15: the coinbase's 0.3 reference reads back when its fields have the sizes
the node checks (a 32-byte txid and hash, a signature of 64 to 72 bytes).
[SRC] src/miner_id/miner_info_ref.cpp:60-114 at 6504a3af. -/
theorem minerInfoRef_parse_encode (r : MinerInfoRef) (ht : r.txid.length = 32) (hb : r.blockBind.length = 32)
    (hs1 : 64 ≤ r.sig.length) (hs2 : r.sig.length ≤ 72) :
    parseMinerInfoRef r.encode = .ok r := by
  have hm : isMinerInfo r.encode = true := by
    simp [isMinerInfo, MinerInfoRef.encode, frameHead, minerInfoProtocolId, pushData, BsvScript.Op.OP_PUSHDATA1]
  rcases r with ⟨t, b, s⟩
  simp only at ht hb hs1 hs2 hm ⊢
  have e : MinerInfoRef.encode ⟨t, b, s⟩ = frameHead minerInfoProtocolId ++
      (pushData [0] ++ (pushData t ++ (pushData b ++ (pushData s ++ [])))) := by
    simp [MinerInfoRef.encode, List.append_assoc]
  have hf : (frameHead minerInfoProtocolId).length = 7 := rfl
  rw [e] at hm
  simp only [parseMinerInfoRef, e, hm, List.drop_left' hf]
  simp [readVersion_push, readOperand_pushData _ _ (by omega : t.length < 2 ^ 32),
    readOperand_pushData _ _ (by omega : b.length < 2 ^ 32), readOperand_pushData_nil _ (by omega : s.length < 2 ^ 32),
    ht, hb, derSigLength, hs1, hs2, bind, Except.bind, pure, Except.pure]

/-- [D] 2026-10-15: the miner-info output's frame reads back.
[SRC] src/miner_id/miner_info_doc.cpp:445-491 at 6504a3af. -/
theorem minerInfoFrame_decode_encode (f : MinerInfoFrame) (hd : f.doc.length < 2 ^ 32)
    (hs1 : 64 ≤ f.sig.length) (hs2 : f.sig.length ≤ 72) :
    MinerInfoFrame.decode f.encode = .ok f := by
  have hm : isMinerInfo f.encode = true := by
    simp [isMinerInfo, MinerInfoFrame.encode, frameHead, minerInfoProtocolId, pushData, BsvScript.Op.OP_PUSHDATA1]
  rcases f with ⟨d, s⟩
  simp only at hd hs1 hs2 hm ⊢
  have e : MinerInfoFrame.encode ⟨d, s⟩ = frameHead minerInfoProtocolId ++
      (pushData [0] ++ (pushData d ++ (pushData s ++ []))) := by
    simp [MinerInfoFrame.encode, List.append_assoc]
  have hf : (frameHead minerInfoProtocolId).length = 7 := rfl
  rw [e] at hm
  simp only [MinerInfoFrame.decode, e, hm, List.drop_left' hf]
  simp [readVersion_push, readOperand_pushData _ _ hd, readOperand_pushData_nil _ (by omega : s.length < 2 ^ 32),
    derSigLength, hs1, hs2, bind, Except.bind, pure, Except.pure]

/-- [D] 2026-10-15: the dataref output's JSON reads back.
[SRC] src/miner_id/miner_info.cpp:231-262 at 6504a3af. -/
theorem dataRefJson_script (json : Bytes) (h : json.length < 2 ^ 32) : dataRefJson (dataRefScript json) = .ok json := by
  have hm : isMinerInfo (dataRefScript json) = true := by
    simp [isMinerInfo, dataRefScript, frameHead, minerInfoProtocolId, pushData, BsvScript.Op.OP_PUSHDATA1]
  have e : dataRefScript json = frameHead minerInfoProtocolId ++ (pushData [0] ++ (pushData json ++ [])) := by
    simp [dataRefScript, List.append_assoc]
  have hf : (frameHead minerInfoProtocolId).length = 7 := rfl
  rw [e] at hm
  simp only [dataRefJson, e, hm, List.drop_left' hf]
  simp [readVersion_push, readOperand_pushData_nil _ h, bind, Except.bind, pure, Except.pure]

/-- [D] 2026-10-15: the `revokemid` message reads back when its keys are valid and each
signature is shorter than 256 bytes (its length is one byte).
[SRC] src/miner_id/revokemid.h:49-97, src/miner_id/revokemid.cpp:37-60 at 6504a3af. -/
theorem revokeMid_decode_encode (m : RevokeMid) (hk1 : keyValid m.revocationKey = true)
    (hk2 : keyValid m.minerId = true) (hk3 : keyValid m.revocationMessage = true)
    (hs1 : m.sig1.length < 256) (hs2 : m.sig2.length < 256) :
    RevokeMid.decode m.encode = some m := by
  rcases m with ⟨rk, mid, msg, s1, s2⟩
  simp only at hk1 hk2 hk3 hs1 hs2 ⊢
  have l1 : rk.length = 33 := by simp [keyValid] at hk1; exact hk1.1
  have l2 : mid.length = 33 := by simp [keyValid] at hk2; exact hk2.1
  have l3 : msg.length = 33 := by simp [keyValid] at hk3; exact hk3.1
  generalize hb : [s1.length] ++ s1 ++ [s2.length] ++ s2 = body
  have hbody : body.length < 2 ^ 64 := by subst hb; simp; omega
  have henc : RevokeMid.encode ⟨rk, mid, msg, s1, s2⟩ =
      headerWordBytes 4 0 ++ (rk ++ (mid ++ (msg ++ (compactSize body.length ++ (body ++ []))))) := by
    subst hb; simp [RevokeMid.encode, le32_eq, List.append_assoc]
  rw [henc]
  simp only [RevokeMid.decode, bind, Option.bind, readLE_headerWordBytes 4 0 _ (by decide),
    readBytes_of_length _ _ _ l1, readBytes_of_length _ _ _ l2, readBytes_of_length _ _ _ l3,
    readVarInt_compactSize _ _ hbody, readBytes_append, hk1, hk2, hk3]
  subst hb
  simp [List.drop_append, List.take_append]
  omega

/-! ## The database -/

/-- [D] 2026-10-15: a lookup after an insertion under the same key finds the inserted entry,
and under another key finds what was there. [SRC] src/miner_id/miner_id_db.cpp:571-600 at 6504a3af. -/
theorem lookupId_putId (db : Db) (e : IdEntry) (k : Bytes) :
    (db.putId e).lookupId k = if e.key == k then some e else db.lookupId k := by
  simp only [Db.putId, Db.lookupId]
  by_cases h : e.key == k
  · simp [List.find?, h]
  · simp only [List.find?_cons, h, if_false]
    induction db.ids with
    | nil => simp
    | cons x xs ih =>
      by_cases hx : x.key == k
      · have hne : (x.key != e.key) = true := by
          simp at hx h ⊢; intro hh; exact h (hh ▸ hx)
        simp [List.filter, hne, hx]
      · by_cases hk : (x.key != e.key) = true
        · simp [List.filter, hk, hx, ih]
        · simp [List.filter, hk, hx, ih]

/-- [D] 2026-10-15: unlinking recent blocks touches no id. -/
theorem lookupId_unlinkRecent (db : Db) (k k' : Bytes) : (db.unlinkRecent k).lookupId k' = db.lookupId k' := rfl

/-- [D] 2026-10-15: the miner table's update touches no id. -/
theorem lookupId_putMiner (db : Db) (m : MinerEntry) (k : Bytes) : (db.putMiner m).lookupId k = db.lookupId k := rfl

/-- [D] 2026-10-15: a lookup of the miner just written finds it. -/
theorem lookupMiner_putMiner (db : Db) (m : MinerEntry) : (db.putMiner m).lookupMiner m.uuid = some m := by
  simp [Db.putMiner, Db.lookupMiner, List.find?]

/-- [D] 2026-10-15: a miner whose reputation is void fails the reputation test, whatever its
recent blocks. [SRC] src/miner_id/miner_id_db.cpp:299-329 at 6504a3af. -/
theorem goodReputation_void (db : Db) (k : Bytes) (e : IdEntry) (m : MinerEntry)
    (he : db.lookupId k = some e) (hm : db.lookupMiner e.uuid = some m) (hv : m.rep.void = true) :
    db.goodReputation k = false := by
  simp [Db.goodReputation, he, hm, hv]

/-- [D] 2026-10-15: the reputation test does not read the id's state: re-writing the entry
with any other state, the same miner, leaves the answer as it was. So a ROTATED or REVOKED
id answers as its miner does. [SRC] src/miner_id/miner_id_db.cpp:299-329 (no read of
`mState`) at 6504a3af. -/
theorem goodReputation_state_blind (db : Db) (k : Bytes) (e : IdEntry) (s : IdState)
    (he : db.lookupId k = some e) (hk : e.key = k) :
    (db.putId { e with state := s }).goodReputation k = db.goodReputation k := by
  have h1 : (db.putId { e with state := s }).lookupId k = some { e with state := s } := by
    rw [lookupId_putId]; simp [hk]
  simp only [Db.goodReputation, h1, he]
  rfl

/-- [D] 2026-10-15: after an invalid block signed by a CURRENT id whose miner is known, that
id fails the reputation test. [SRC] src/miner_id/miner_id_db.cpp:205-239,299-329 at 6504a3af. -/
theorem invalidBlock_voids (db : Db) (doc : CoinbaseDoc) (e : IdEntry) (m : MinerEntry)
    (he : db.lookupId (parseHex doc.minerId) = some e) (hc : e.state = .current)
    (hm : db.lookupMiner e.uuid = some m) :
    (db.invalidBlock (some doc)).goodReputation (parseHex doc.minerId) = false := by
  cases hv : m.rep.void
  · have hmu : m.uuid = e.uuid := by
      have := List.find?_some hm
      simpa using this
    have h1 : db.invalidBlock (some doc) =
        db.putMiner { m with rep := { m.rep with void := true, voidingId := some e.key } } := by
      simp [Db.invalidBlock, he, hc, hm, hv]
    rw [h1]
    apply goodReputation_void _ _ e { m with rep := { m.rep with void := true, voidingId := some e.key } }
    · rw [lookupId_putMiner]; exact he
    · have := lookupMiner_putMiner db { m with rep := { m.rep with void := true, voidingId := some e.key } }
      simpa [hmu] using this
    · rfl
  · have h1 : db.invalidBlock (some doc) = db := by simp [Db.invalidBlock, he, hc, hm, hv]
    rw [h1]
    exact goodReputation_void db _ e m he hm hv

/-- [D] 2026-10-15: revoking up to a key that the list holds leaves that key REVOKED.
[SRC] src/miner_id/miner_id_db.cpp:275-285,1042-1076 at 6504a3af. -/
theorem revokeUpTo_revokes (stop : Bytes) (ids : List IdEntry) (h : ids.any (·.key == stop) = true) :
    ∀ db : Db, ∃ e, (db.revokeUpTo stop ids).lookupId stop = some e ∧ e.state = .revoked := by
  induction ids with
  | nil => simp at h
  | cons x xs ih =>
    intro db
    by_cases hx : (x.key == stop) = true
    · refine ⟨{ x with state := .revoked }, ?_, rfl⟩
      simp [Db.revokeUpTo, hx, lookupId_unlinkRecent, lookupId_putId]
    · have h' : xs.any (·.key == stop) = true := by
        simp only [List.any_cons, Bool.or_eq_true] at h
        rcases h with h | h
        · exact absurd h hx
        · exact h
      simp only [Db.revokeUpTo, hx, Bool.false_eq_true, if_false]
      exact ih h' _

/-- [D] 2026-10-15: a `revokemid` the database accepts leaves the compromised id REVOKED.
[SRC] src/miner_id/miner_id_db.cpp:242-296 at 6504a3af. -/
theorem processRevokemid_revokes (v : Verifier) (ctx : ChainView) (db db' : Db) (m : RevokeMid)
    (h : db.processRevokemid v ctx m = .ok db') :
    ∃ e, db'.lookupId m.revocationMessage = some e ∧ e.state = .revoked := by
  unfold Db.processRevokemid at h
  simp only [need, bind, Except.bind, pure, Except.pure] at h
  split at h <;> try (simp at h; done)
  split at h <;> try (simp at h; done)
  rename_i e _
  split at h <;> try (simp at h; done)
  split at h <;> try (simp at h; done)
  rename_i hany
  injection h with h
  subst h
  exact revokeUpTo_revokes _ _ (by simpa using hany) db

/-- [D] 2026-10-15: revoking entries under other keys leaves a key's entry as it was. -/
theorem foldl_revoke_keep (k : Bytes) (v : IdEntry) : ∀ (xs : List IdEntry) (d : Db), k ∉ xs.map (·.key) →
    d.lookupId k = some v →
      (xs.foldl (fun d e => (d.putId { e with state := .revoked }).unlinkRecent e.key) d).lookupId k = some v := by
  intro xs
  induction xs with
  | nil => intro d _ hd; exact hd
  | cons y ys ih =>
    intro d hn hd
    simp only [List.map_cons, List.mem_cons, not_or] at hn
    simp only [List.foldl_cons]
    apply ih _ hn.2
    rw [lookupId_unlinkRecent, lookupId_putId]
    have : (y.key == k) = false := beq_false_of_ne (fun h => hn.1 h.symm)
    simp [this, hd]

/-- [D] 2026-10-15: revoking every entry of a list leaves each of its keys REVOKED.
[SRC] src/miner_id/miner_id_db.cpp:1103-1112 at 6504a3af. -/
theorem foldl_revoke (ids : List IdEntry) :
    ∀ (db : Db) (k : Bytes), k ∈ ids.map (·.key) →
      ∃ e, (ids.foldl (fun d e => (d.putId { e with state := .revoked }).unlinkRecent e.key) db).lookupId k = some e ∧
        e.state = .revoked := by
  induction ids with
  | nil => simp
  | cons x xs ih =>
    intro db k hk
    simp only [List.foldl_cons]
    by_cases hin : k ∈ xs.map (·.key)
    · exact ih _ k hin
    · have hx : x.key = k := by
        simp only [List.map_cons, List.mem_cons] at hk
        rcases hk with h | h
        · exact h.symm
        · exact absurd h hin
      refine ⟨{ x with state := .revoked }, foldl_revoke_keep k _ xs _ hin ?_, rfl⟩
      rw [lookupId_unlinkRecent, lookupId_putId]; simp [hx]

/-- [D] 2026-10-15: a full revocation the database accepts (the key does not roll) leaves
every id it listed for the miner REVOKED.
[SRC] src/miner_id/miner_id_db.cpp:1101-1127,1241-1250 at 6504a3af. -/
theorem fullRevocation_revokes_all (cfg : MinerIdConfig) (ctx : ChainView) (db db' : Db) (k : Bytes)
    (doc : CoinbaseDoc) (block : Bytes) (u : Option Nat) (kk : Bytes)
    (h : db.processRevocation cfg ctx k k doc block = .ok (db', u, kk)) :
    ∃ ce, db.lookupId k = some ce ∧
      ∀ k' ∈ (db.idsOfMiner ctx ce.uuid).map (·.key), ∃ e, db'.lookupId k' = some e ∧ e.state = .revoked := by
  unfold Db.processRevocation at h
  simp only [need, bind, Except.bind, pure, Except.pure, bne_self_eq_false, Bool.false_eq_true, if_false] at h
  split at h <;> try (simp at h; done)
  split at h <;> try (simp at h; done)
  split at h <;> try (simp at h; done)
  rename_i ce hce
  refine ⟨ce, hce, ?_⟩
  intro k' hk'
  obtain ⟨e, he, hs⟩ := foldl_revoke _ db k' hk'
  split at h <;> (injection h with h; injection h with h; subst h)
  · exact ⟨e, by rw [lookupId_putMiner]; exact he, hs⟩
  · exact ⟨e, he, hs⟩

/-- [D] 2026-10-15: a block whose (non-revoking) document reuses a key that the database
holds as not CURRENT changes no id entry: the reuse is refused (the reference throws at
src/miner_id/miner_id_db.cpp:949-953) and only the recent-blocks row and the best block move.
So a REVOKED or ROTATED id stays as it is. -/
theorem blockAdded_reuse_refused (cfg : MinerIdConfig) (ctx : ChainView) (db : Db) (block : Bytes) (height : Nat)
    (doc : CoinbaseDoc) (e : IdEntry) (hr : doc.revocationMessage = none)
    (hsame : parseHex doc.minerId = parseHex doc.prevMinerId)
    (he : db.lookupId (parseHex doc.minerId) = some e) (hs : e.state ≠ .current) (k : Bytes) :
    (db.blockAdded cfg ctx block height (some doc)).lookupId k = db.lookupId k := by
  have hp : ∃ k', db.processDoc cfg ctx doc block = .error k' := by
    unfold Db.processDoc
    simp only [hr, Option.isSome_none, Bool.false_eq_true, if_false, ← hsame, beq_self_eq_true, if_true, he,
      Db.processExisting, need, hs, decide_false]
    split
    · exact ⟨_, rfl⟩
    · exact ⟨_, rfl⟩
  obtain ⟨k', hk'⟩ := hp
  unfold Db.blockAdded
  simp only [hk']
  rfl

/-- [D] 2026-10-15: the recent-blocks table never holds more than N rows after an addition.
[SRC] src/miner_id/miner_id_db.cpp:1361-1374 at 6504a3af. -/
theorem addRecent_bounded (cfg : MinerIdConfig) (db : Db) (b : RecentBlock) :
    (db.addRecent cfg b).recent.length ≤ cfg.reputationN := by
  simp [Db.addRecent, List.length_take]

end BsvChain.Properties
