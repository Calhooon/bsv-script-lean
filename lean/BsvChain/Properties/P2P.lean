import BsvChain.Wire.P2P
import BsvChain.Properties.TxCodec

/-!
# The P2P wire formats' laws (#78), 2026-10-15 [D]

Views of the relay layer, never block-validity rules. The framing round trip:
every command the vocabulary frames, under any payload up to 2^64 - 1 bytes,
reads back from its frame with the following stream untouched, through the
basic header (with its checksum) below 2^32 bytes and the extended header
above. The payload codecs of `inv`/`getdata`/`notfound`, `reject`,
`ping`/`pong`, `protoconf` and `version` read back their writers' bytes.
[SRC] bitcoin-sv v1.2.3 at 6504a3aff65ba97c0f6c80962b033e35ecbfed4b, as cited
in `lean/BsvChain/Wire/P2P.lean`.
-/

namespace BsvChain.Wire
open BsvScript.Numbers BsvScript.Tx BsvScript.Hash BsvScript.Sighash BsvChain.Properties

/-! ## 1. The vocabulary -/

/-- [D] 2026-10-15: thirty-eight names, thirty-seven registered, and the one
the registered list omits is `revokemid` (src/protocol.cpp:16-53,107-121 at
6504a3af; rule 15: the comment at :103-106 says the list keeps in step). The
per-command byte counters are keyed by the registered list. A view, never a rule. -/
theorem registered_omits_revokemid :
    Command.all.length = 38 ∧ Command.registered.length = 37 ∧
      Command.revokemid ∉ Command.registered ∧
      ∀ c ∈ Command.all, c ≠ .revokemid → c ∈ Command.registered := by
  decide

/-- [D] 2026-10-15: every command of the vocabulary except `extmsg` itself is
a command the frame carries: at most twelve printable bytes whose padded field
does not begin with `extmsg`. A view, never a rule. -/
theorem vocabulary_frames (c : Command) (h : c ≠ .extmsg) : CommandOk c.bytes := by
  revert h; cases c <;> decide

/-- [D] 2026-10-15: `extmsg` as a basic command does not read back: its
field begins with `extmsg`, so the reader takes the next twenty bytes as
the extended fields (src/protocol.cpp:259-266 at 6504a3af). The name is the
marker of the extended header, never a message of its own. A view, never a rule. -/
theorem extmsg_not_framed : ¬ CommandOk Command.extmsg.bytes := by decide

/-! ## 2. The framing round trip -/

/-- [D] 2026-10-15: a byte string of its own length reads back. -/
theorem readBytes_prefix (n : Nat) (s rest : Bytes) (h : s.length = n) :
    readBytes n (s ++ rest) = some (s, rest) := by
  subst h; exact readBytes_append s rest

/-- [D] 2026-10-15: the padded command field is twelve bytes. -/
theorem padCommand_length (c : Bytes) (h : c.length ≤ commandSize) :
    (padCommand c).length = commandSize := by
  simp [padCommand]; omega

/-- [D] 2026-10-15: NUL padding after a NUL-free command stops the scan. -/
theorem takeWhile_nonzero_append (c : Bytes) (k : Nat) (h : ∀ b ∈ c, b ≠ 0) :
    (c ++ List.replicate k 0).takeWhile (· != 0) = c := by
  induction c with
  | nil => cases k <;> simp [List.replicate_succ]
  | cons b c ih =>
    have hb := h b (List.mem_cons_self ..)
    simp [hb, ih (fun x hx => h x (List.mem_cons_of_mem _ hx))]

/-- [D] 2026-10-15: `GetCommand` recovers a command with no NUL from its field. -/
theorem stripCommand_padCommand (c : Bytes) (h : ∀ b ∈ c, b ≠ 0) :
    stripCommand (padCommand c) = c :=
  takeWhile_nonzero_append c _ h

/-- [D] 2026-10-15: the checksum is four bytes. -/
theorem checksumOf_length (p : Bytes) : (checksumOf p).length = 4 := by
  simp [checksumOf, sha256d_length]

/-- [D] 2026-10-15: THE FRAMING ROUND TRIP. For network magic of four bytes,
a command the frame carries (`CommandOk`) and any payload below 2^64 bytes,
the frame reads back the command and the payload and leaves the rest of the
stream untouched: through the basic header and its checksum up to 2^32 - 1
payload bytes, through the extended header above. [SRC] the writer
src/protocol.cpp:208-241, the reader :244-276, the payload and checksum
src/net/net_message.cpp:12-53 and src/net/net_processing.cpp:5054-5090 at
6504a3af. A view, never a rule: the frame decides what a node reads, never
what is valid. -/
theorem unframe_frame (magic cmd payload rest : Bytes) (hm : magic.length = magicSize)
    (hc : CommandOk cmd) (hp : payload.length < 2 ^ 64) :
    unframe (frame magic cmd payload ++ rest) = some ((cmd, payload), rest) := by
  obtain ⟨hlen, hprint, hpre⟩ := hc
  have hnz : ∀ b ∈ cmd, b ≠ 0 := fun b hb => by have := hprint b hb; omega
  have hpad := padCommand_length cmd hlen
  unfold frame Header.make
  split
  · rename_i hbig
    have hx : (padCommand extmsgPrefix).take 6 = extmsgPrefix := by decide
    have hxl : (padCommand extmsgPrefix).length = commandSize := by decide
    simp only [Header.encode, List.append_assoc, unframe, Header.read, bind,
      Option.bind, readBytes_prefix _ _ _ hm, readBytes_prefix _ _ _ hxl,
      readLE_headerWordBytes _ _ _ (by norm_num : 0xffffffff < 256 ^ 4),
      readBytes_prefix 4 [0, 0, 0, 0] _ rfl, hx, ite_true,
      readBytes_prefix _ _ _ hpad,
      readLE_headerWordBytes _ _ _ (by norm_num at hp ⊢; omega : payload.length < 256 ^ 8),
      Header.payloadLength, readBytes_append, Option.isNone_some, Bool.false_and,
      Bool.false_eq_true, ite_false, Header.getCommand, stripCommand_padCommand cmd hnz, pure]
  · rename_i hsmall
    simp only [Header.encode, List.append_assoc, List.append_nil, unframe,
      Header.read, bind, Option.bind, readBytes_prefix _ _ _ hm, readBytes_prefix _ _ _ hpad,
      readLE_headerWordBytes _ _ _ (by omega : payload.length < 256 ^ 4),
      readBytes_prefix _ _ _ (checksumOf_length payload), hpre, ite_false,
      Header.payloadLength, readBytes_append, Option.isNone_none, bne_self_eq_false,
      Bool.and_false, Bool.false_eq_true, Header.getCommand, stripCommand_padCommand cmd hnz, pure]

/-- [D] 2026-10-15: the frame's size is the header's plus the payload's:
24 bytes of header up to 2^32 - 1 payload bytes, 44 above
(`GetHeaderSizeForPayload`, src/protocol.cpp:304-312 at 6504a3af). A view,
never a rule. -/
theorem frame_length (magic cmd payload : Bytes) (hm : magic.length = magicSize)
    (hc : cmd.length ≤ commandSize) :
    (frame magic cmd payload).length =
      (if payload.length > 0xffffffff then extendedHeaderSize else basicHeaderSize) +
        payload.length := by
  have hpad := padCommand_length cmd hc
  have hx : (padCommand extmsgPrefix).length = commandSize := by decide
  unfold frame Header.make
  split <;>
    simp only [Header.encode, List.length_append, headerWordBytes_length,
      checksumOf_length, List.length_cons, List.length_nil, *] <;>
    simp [extendedHeaderSize, basicHeaderSize, magicSize, commandSize]

/-! ## 3. The payload codecs -/

/-- [D] 2026-10-15: an inventory item whose type fits 32 bits and whose hash
is 32 bytes reads back. [SRC] src/protocol.h:555-561 at 6504a3af. -/
theorem InvItem.read_encode (i : InvItem) (rest : Bytes) (hk : i.kind < 2 ^ 32)
    (hh : i.hash.length = 32) : InvItem.read (i.encode ++ rest) = some (i, rest) := by
  simp only [InvItem.read, InvItem.encode, List.append_assoc, bind, Option.bind,
    readLE_headerWordBytes _ _ _ (by norm_num at hk ⊢; omega : i.kind < 256 ^ 4),
    readBytes_prefix _ _ _ hh, pure]

/-- [D] 2026-10-15: the inventory payload of `inv`, `getdata` and `notfound`
reads back from its writer's bytes. [SRC] src/serialize.h:716-726,794-840 and
src/net/net_processing.cpp:2461-2462,2544-2545 at 6504a3af. A view, never a rule. -/
theorem decodeInv_encodeInv (items : List InvItem) (hn : items.length < 2 ^ 64)
    (hi : ∀ i ∈ items, i.kind < 2 ^ 32 ∧ i.hash.length = 32) :
    decodeInv (encodeInv items) = some items := by
  have hm := readMany_ser InvItem.read InvItem.encode
    (fun i => i.kind < 2 ^ 32 ∧ i.hash.length = 32)
    (fun x rest hx => InvItem.read_encode x rest hx.1 hx.2) items hi []
  simp only [List.append_nil] at hm
  unfold decodeInv encodeInv
  have hv := readVarInt_compactSize items.length ((items.map InvItem.encode).flatten) hn
  simp only [bind, Option.bind, hv, hm, ite_true, pure]

/-- [D] 2026-10-15: a string or byte vector within its limit reads back. -/
theorem readVarBytes_encode (limit : Nat) (s rest : Bytes) (hl : s.length ≤ limit)
    (h64 : s.length < 2 ^ 64) :
    readVarBytes limit (encodeVarBytes s ++ rest) = some (s, rest) := by
  have hn : ¬ s.length > limit := by omega
  simp only [readVarBytes, encodeVarBytes, List.append_assoc, bind, Option.bind,
    readVarInt_compactSize _ _ h64, hn, ite_false, readBytes_append]

/-- [D] 2026-10-15: a well-formed `reject` (a command of at most twelve bytes,
a one-byte code, a reason within 111 bytes, a 32-byte hash exactly when the
rejected message is `block` or `tx`) reads back from its writer's bytes.
[SRC] the writer src/validation.cpp:1943-1950, the reader
src/net/net_processing.cpp:1491-1506 at 6504a3af. A view, never a rule. -/
theorem Reject.decode_encode (r : Reject) (hm : r.message.length ≤ commandSize)
    (hc : r.code < 256) (hr : r.reason.length ≤ maxRejectReason)
    (hh : (r.message = Command.block.bytes ∨ r.message = Command.tx.bytes) ↔ r.hash.isSome)
    (h32 : ∀ h, r.hash = some h → h.length = 32) :
    Reject.decode r.encode = some r := by
  obtain ⟨message, code, reason, hash⟩ := r
  simp only at hm hc hr hh h32
  have hm64 : message.length < 2 ^ 64 := by unfold commandSize at hm; omega
  have hr64 : reason.length < 2 ^ 64 := by unfold maxRejectReason at hr; omega
  cases hash with
  | none =>
    have hn : ¬ (message = Command.block.bytes ∨ message = Command.tx.bytes) := by simpa using hh
    have e := readVarBytes_encode commandSize message
      (headerWordBytes 1 code ++ encodeVarBytes reason) hm hm64
    have e2 := readVarBytes_encode maxRejectReason reason [] hr hr64
    simp only [List.append_nil] at e2
    simp only [Reject.decode, Reject.encode, List.append_nil, List.append_assoc, bind,
      Option.bind, e, readLE_headerWordBytes _ _ _ (by norm_num; omega : code < 256 ^ 1), e2, hn,
      ite_false, ite_true, pure]
  | some h =>
    have hy : message = Command.block.bytes ∨ message = Command.tx.bytes := by simpa using hh
    have hl := h32 h rfl
    have e := readVarBytes_encode commandSize message
      (headerWordBytes 1 code ++ (encodeVarBytes reason ++ h)) hm hm64
    have e2 := readVarBytes_encode maxRejectReason reason h hr hr64
    have e3 := readBytes_prefix 32 h [] hl
    simp only [List.append_nil] at e3
    simp only [Reject.decode, Reject.encode, List.append_assoc, bind, Option.bind, e,
      readLE_headerWordBytes _ _ _ (by norm_num; omega : code < 256 ^ 1), e2, hy, ite_true,
      e3, pure]

/-- [D] 2026-10-15: the `ping` and `pong` nonce reads back. [SRC]
src/net/net_processing.cpp:4212-4290 at 6504a3af. A view, never a rule. -/
theorem decodeNonce_encode (n : Nat) (h : n < 2 ^ 64) : decodeNonce (encodeNonce n) = some n := by
  have e := readLE_headerWordBytes 8 n [] (by norm_num at h ⊢; omega)
  simp only [List.append_nil] at e
  simp [decodeNonce, encodeNonce, e]

/-- [D] 2026-10-15: the writer's two-field `protoconf` reads back. [SRC]
src/protocol.h:596-626 at 6504a3af. A view, never a rule. -/
theorem Protoconf.decode_encode (p : Protoconf) (hm : p.maxRecvPayload < 2 ^ 32)
    (hs : p.streamPolicies.length ≤ maxStreamPolicies) :
    Protoconf.decode p.encode = some p := by
  have hs64 : p.streamPolicies.length < 2 ^ 64 := by unfold maxStreamPolicies at hs; omega
  have e2 := readVarBytes_encode maxStreamPolicies p.streamPolicies [] hs hs64
  simp only [List.append_nil] at e2
  have e1 := readVarInt_compactSize 2
    (headerWordBytes 4 p.maxRecvPayload ++ encodeVarBytes p.streamPolicies) (by norm_num)
  simp only [Protoconf.decode, Protoconf.encode, List.append_assoc, bind, Option.bind, e1,
    ne_eq, not_true_eq_false, ite_false,
    readLE_headerWordBytes _ _ _ (by norm_num at hm ⊢; omega : p.maxRecvPayload < 256 ^ 4), e2,
    ite_true, pure]

/-- [D] 2026-10-15: an address with a 64-bit services word, sixteen address
bytes and a 16-bit port reads back. [SRC] src/protocol.h:503-514 and
src/net/netaddress.h:172-178 at 6504a3af. -/
theorem NetAddr.read_encode (a : NetAddr) (rest : Bytes) (hs : a.services < 2 ^ 64)
    (hi : a.ip.length = 16) (hp : a.port < 2 ^ 16) :
    NetAddr.read (a.encode ++ rest) = some (a, rest) := by
  obtain ⟨services, ip, port⟩ := a
  simp only at hs hi hp
  have hport : port / 256 % 256 * 256 + port % 256 = port := by omega
  simp only [NetAddr.read, NetAddr.encode, List.append_assoc, bind, Option.bind,
    readLE_headerWordBytes _ _ _ (by norm_num at hs ⊢; omega : services < 256 ^ 8),
    readBytes_prefix _ _ _ hi, readBytes_prefix 2 [port / 256 % 256, port % 256] _ rfl, hport, pure]

/-- [D] 2026-10-15: the `version` message in the writer's full form reads
back. [SRC] the writer src/net/net_processing.cpp:149-154, the reader
:1704,1744-1770 at 6504a3af. A view, never a rule. -/
theorem Version.decode_encode (v : Version) (hv : v.version < 2 ^ 32)
    (hs : v.services < 2 ^ 64) (ht : v.time < 2 ^ 64)
    (ha : v.addrYou.services < 2 ^ 64 ∧ v.addrYou.ip.length = 16 ∧ v.addrYou.port < 2 ^ 16)
    (hb : v.addrMe.services < 2 ^ 64 ∧ v.addrMe.ip.length = 16 ∧ v.addrMe.port < 2 ^ 16)
    (hn : v.nonce < 2 ^ 64) (hu : v.userAgent.length ≤ maxSubversion)
    (hh : v.startHeight < 2 ^ 32) (hid : v.assocId.length < 2 ^ 64) :
    Version.decode v.encode = some v := by
  obtain ⟨version, services, time, addrYou, addrMe, nonce, userAgent, startHeight, relay,
    assocId⟩ := v
  simp only at hv hs ht ha hb hn hu hh hid
  have hu64 : userAgent.length < 2 ^ 64 := by unfold maxSubversion at hu; omega
  have eid := readVarBytes_encode (encodeVarBytes assocId).length assocId []
    (by simp [encodeVarBytes]) hid
  simp only [List.append_nil] at eid
  have hrel : headerWordBytes 1 (if relay then 1 else 0) ++ encodeVarBytes assocId =
      headerWordBytes 1 (if relay then 1 else 0) ++ (encodeVarBytes assocId ++ []) := by simp
  have rel := readLE_headerWordBytes 1 (if relay then 1 else 0) (encodeVarBytes assocId)
    (by split <;> norm_num)
  have hrb : ((if relay then 1 else 0) != 0) = relay := by cases relay <;> rfl
  simp only [Version.decode, Version.encode, List.append_assoc, bind, Option.bind,
    readLE_headerWordBytes _ _ _ (by norm_num at hv ⊢; omega : version < 256 ^ 4),
    readLE_headerWordBytes _ _ _ (by norm_num at hs ⊢; omega : services < 256 ^ 8),
    readLE_headerWordBytes _ _ _ (by norm_num at ht ⊢; omega : time < 256 ^ 8),
    NetAddr.read_encode _ _ ha.1 ha.2.1 ha.2.2, NetAddr.read_encode _ _ hb.1 hb.2.1 hb.2.2,
    readLE_headerWordBytes _ _ _ (by norm_num at hn ⊢; omega : nonce < 256 ^ 8),
    readVarBytes_encode _ _ _ hu hu64,
    readLE_headerWordBytes _ _ _ (by norm_num at hh ⊢; omega : startHeight < 256 ^ 4),
    rel, eid, ite_true, hrb, pure]

/-! ## 4. The payload caps and the extended header at their boundaries -/

/-- [D] 2026-10-15: a command the frame carries passes the reader's format
check once padded (`CheckCommandFormat`, src/protocol.cpp:128-152 at 6504a3af). -/
theorem commandFormatOk_padCommand (c : Bytes) (hp : ∀ b ∈ c, 0x20 ≤ b ∧ b ≤ 0x7e) : commandFormatOk (padCommand c) = true := by
  have hnz : ∀ b ∈ c, b ≠ 0 := fun b hb => by have := hp b hb; omega
  unfold commandFormatOk
  dsimp only
  rw [stripCommand_padCommand c hnz]
  simp only [padCommand, List.drop_left, Bool.and_eq_true, List.all_eq_true, decide_eq_true_eq]
  refine ⟨fun b hb => ?_, fun b hb => ?_⟩
  · simpa using hp b hb
  · simp [List.eq_of_mem_replicate hb]

/-- [D] 2026-10-15: the extended form's basic command `extmsg` passes the
format check (src/protocol.cpp:128-152,222-229 at 6504a3af). -/
theorem commandFormatOk_extmsg : commandFormatOk (padCommand extmsgPrefix) = true := by decide

/-- [D] 2026-10-15: THE WRITER'S HEADER IS VALID. For a command the frame
carries and a payload within its command's cap, the header the writer makes
passes the reader's validity check at the same magic: the magic, the command's
format, the cap, and for the extended form the extended command's format
(src/protocol.cpp:208-241 the writer, :174-190,329-365 `IsValid` and
`IsOversized` at 6504a3af). A view, never a rule. -/
theorem frame_valid (k : CapInputs) (magic cmd payload : Bytes)
    (hl : payload.length ≤ maxMessageLength k cmd) (hc : CommandOk cmd) :
    (Header.make magic cmd payload).valid k magic = true := by
  obtain ⟨_, hprint, _⟩ := hc
  have hnz : ∀ b ∈ cmd, b ≠ 0 := fun b hb => by have := hprint b hb; omega
  have hf := commandFormatOk_padCommand cmd hprint
  have hn : ¬ payload.length > maxMessageLength k cmd := Nat.not_lt.mpr hl
  unfold Header.make
  split <;>
    simp [Header.valid, Header.oversized, Header.payloadLength, Header.getCommand,
      stripCommand_padCommand cmd hnz, hf, commandFormatOk_extmsg, hn]

/-- [D] 2026-10-15: the scenario's caps: the block-size setting of the run's
two instances (1000001 bytes, `harness/src/scenarios/relay.rs`), every other
input at its default (2 MiB receive, 10^9 bytes the transaction bound). -/
def runCaps : CapInputs := { maxBlockSize := 1000001 }

/-- [D] 2026-10-15: a basic header with a zero checksum. -/
def basicHeader (c : Command) (n : Nat) : Header :=
  { magic := regtestMagic, command := padCommand c.bytes, length := n,
    checksum := [0, 0, 0, 0], extended := none }

/-- [M] 2026-10-15: the 24 bytes step s8 sent (the receipt's
`steps[7].raw.sent`, corpus/p2p/2026-10-15-relay-two-node.receipt.json): the
regtest magic, `ping`, the length field 0x00200001, a zero checksum. -/
def s8Sent : Bytes :=
  [0xda, 0xb5, 0xbf, 0xfa, 0x70, 0x69, 0x6e, 0x67, 0, 0, 0, 0, 0, 0, 0, 0,
   0x01, 0x00, 0x20, 0x00, 0, 0, 0, 0]

/-- [D] 2026-10-15: s8's bytes read as the `ping` header of 2 MiB + 1 bytes,
nothing left over (src/protocol.cpp:244-276 at 6504a3af). -/
theorem s8_header_read : Header.read s8Sent = some (basicHeader .ping (2 * 1024 * 1024 + 1), []) := by
  decide +kernel

/-- [D] 2026-10-15: THE s8 HEADER IS OVER ITS CAP, and invalid; the same
header at exactly 2 MiB is not (src/protocol.cpp:88-93,192-195,329-365 at
6504a3af). A view, never a rule. -/
theorem s8_header_oversized :
    (basicHeader .ping (2 * 1024 * 1024 + 1)).oversized runCaps = true ∧
      (basicHeader .ping (2 * 1024 * 1024 + 1)).valid runCaps regtestMagic = false ∧
      (basicHeader .ping (2 * 1024 * 1024)).oversized runCaps = false ∧
      (basicHeader .ping (2 * 1024 * 1024)).valid runCaps regtestMagic = true := by
  decide +kernel

/-- [D] 2026-10-15: `protoconf` at 1 MiB and 1 MiB + 1 (src/protocol.cpp:65-69
at 6504a3af). A view, never a rule. -/
theorem protoconf_cap_boundary :
    (basicHeader .protoconf (1024 * 1024)).oversized runCaps = false ∧
      (basicHeader .protoconf (1024 * 1024 + 1)).oversized runCaps = true := by
  decide +kernel

/-- [D] 2026-10-15: `getblocktxn` at its estimate, 1000001 / 215 * 6 + 24 =
27930 bytes, and one above (src/protocol.cpp:76-87,304-312 at 6504a3af). A
view, never a rule. -/
theorem getblocktxn_cap_boundary :
    (basicHeader .getblocktxn 27930).oversized runCaps = false ∧
      (basicHeader .getblocktxn 27931).oversized runCaps = true := by
  decide +kernel

/-- [D] 2026-10-15: the block-like commands at the block size and one above
(src/protocol.cpp:55-61,94-98 at 6504a3af): `block` and `hdrsen` at 1000001
and 1000002 bytes. A view, never a rule. -/
theorem blockLike_cap_boundary :
    (basicHeader .block 1000001).oversized runCaps = false ∧
      (basicHeader .block 1000002).oversized runCaps = true ∧
      (basicHeader .hdrsen 1000001).oversized runCaps = false ∧
      (basicHeader .hdrsen 1000002).oversized runCaps = true := by
  decide +kernel

/-- [D] 2026-10-15: `tx` at the consensus transaction-size bound and one above
(`GetMaxTxSize(PostGenesis, true)`, src/protocol.cpp:70-75 at 6504a3af). A
view, never a rule. -/
theorem tx_cap_boundary :
    (basicHeader .tx 1000000000).oversized runCaps = false ∧
      (basicHeader .tx 1000000001).oversized runCaps = true := by
  decide +kernel

/-- [D] 2026-10-15: a basic header whose length field is 0xffffffff, the
largest it holds, reads back from its bytes (src/protocol.cpp:244-276 at
6504a3af). A view, never a rule. -/
theorem basic_header_max_read :
    Header.read (basicHeader .block 0xffffffff).encode =
      some (basicHeader .block 0xffffffff, []) := by
  decide +kernel

/-- [D] 2026-10-15: the extended header the writer makes for a `block` of
2^32 bytes, the least the extended form carries.
(src/protocol.cpp:222-229 at 6504a3af). -/
def extendedBlockHeader : Header :=
  { magic := regtestMagic, command := padCommand extmsgPrefix, length := 0xffffffff,
    checksum := [0, 0, 0, 0], extended := some (padCommand Command.block.bytes, 2 ^ 32) }

/-- [D] 2026-10-15: THE EXTENDED HEADER AT 2^32. It reads back from its 44
bytes, names `block` and 2^32 payload bytes, and is over the cap of a block
size of 1000001 (src/protocol.cpp:244-302,329-365 at 6504a3af). A view, never
a rule. -/
theorem extended_header_read :
    Header.read extendedBlockHeader.encode = some (extendedBlockHeader, []) ∧
      extendedBlockHeader.encode.length = extendedHeaderSize ∧
      extendedBlockHeader.getCommand = Command.block.bytes ∧
      extendedBlockHeader.payloadLength = 2 ^ 32 ∧
      extendedBlockHeader.oversized runCaps = true := by
  decide +kernel

end BsvChain.Wire
