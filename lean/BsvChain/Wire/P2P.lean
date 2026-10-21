import BsvChain.Header
import BsvScript.Sighash

/-!
# The P2P wire formats (#78), 2026-10-15 [D]

Nothing in this module is a block-validity rule. The P2P layer decides what a
node hears and when, never whether a transaction or a block is valid: every
payload cap here is a node setting or a constant of the message reader, and
the reject codes are a vocabulary the node answers with, never a verdict of
its own. The settings are the fields of the auxiliary `RelayConfig`
(`lean/BsvChain/Wire/Relay.lean`; docs/PARAMETERS.md section 8.6), each
labeled policy with its default and source (rule 1).

The frame: a 24-byte header (four bytes of network magic, a twelve-byte
NUL-padded command, a 32-bit little-endian payload length, the leading four
bytes of the payload's double SHA-256), or for a payload above 2^32 - 1 bytes
the 44-byte extended header: the command `extmsg`, the length field
0xffffffff, a zero checksum, then the real command (twelve bytes) and a 64-bit
length; the payload follows. The reader recognizes the extended form by the
basic command's six-byte prefix `extmsg` and skips the checksum for it.

[SRC] bitcoin-sv v1.2.3 at 6504a3aff65ba97c0f6c80962b033e35ecbfed4b:
src/protocol.h:28-63 (the caps),:68-86 (the field sizes),:93-119 (the extended
header),:131-191 (the header),:525-593 (`CInv`),:596-626 (`CProtoconf`);
src/protocol.cpp:15-53 (the command names),:55-99 (`IsBlockLike`,
`GetMaxMessageLength`),:107-121 (the registered list),:128-152
(`CheckCommandFormat`),:154-365 (the header's constructor, reader, accessors
and validity); src/net/net_message.cpp:12-53 (the frame reader);
src/net/net_processing.cpp:5029-5090 (magic and checksum at processing);
src/consensus/validation.h:13-24, src/validation.h:1150-1163 and
src/net/net_types.h:26, src/net/authconn.h:25 (the reject codes);
src/serialize.h:296-340,429,497-520,698-726 (the integer, CompactSize and
string encodings); src/chainparams.cpp:1087-1090,1504-1507 (the magics).
-/

namespace BsvChain.Wire
open BsvScript.Numbers BsvScript.Tx BsvScript.Hash BsvScript.Sighash

/-! ## 1. The header's fields -/

/-- [SRC] 2026-10-15: `MESSAGE_START_SIZE`, src/protocol.h:72 at 6504a3af. -/
def magicSize : Nat := 4
/-- [SRC] 2026-10-15: `COMMAND_SIZE`, src/protocol.h:73 at 6504a3af. -/
def commandSize : Nat := 12
/-- [SRC] 2026-10-15: `BASIC_HEADER_SIZE` = 4 + 12 + 4 + 4, src/protocol.h:83 at 6504a3af. -/
def basicHeaderSize : Nat := 24
/-- [SRC] 2026-10-15: `EXTENDED_HEADER_SIZE` = the basic header + 12 + 8,
src/protocol.h:84 at 6504a3af. -/
def extendedHeaderSize : Nat := 44

/-- [SRC] 2026-10-15: the regtest network magic, src/chainparams.cpp:1504-1507 at 6504a3af. -/
def regtestMagic : Bytes := [0xda, 0xb5, 0xbf, 0xfa]
/-- [SRC] 2026-10-15: the mainnet network magic, src/chainparams.cpp:1087-1090 at 6504a3af. -/
def mainnetMagic : Bytes := [0xe3, 0xe1, 0xf3, 0xe8]

/-- [D] 2026-10-15: a string's characters as bytes; every name here is ASCII. -/
def asciiBytes (s : String) : Bytes := s.toList.map Char.toNat

/-! ## 2. The message vocabulary -/

/-- [SRC] 2026-10-15: the thirty-eight command names of `NetMsgType`, in
src/protocol.cpp:16-53 at 6504a3af (declared at src/protocol.h:199-436). -/
inductive Command where
  | version | verack | addr | inv | getdata | merkleblock | getblocks | getheaders
  | gethdrsen | tx | headers | hdrsen | block | getaddr | mempool | ping | pong
  | notfound | filterload | filteradd | filterclear | reject | sendheaders
  | sendhdrsen | feefilter | sendcmpct | cmpctblock | getblocktxn | blocktxn
  | protoconf | createstrm | streamack | dsdetected | extmsg | revokemid | authch
  | authresp | datareftx
  deriving DecidableEq, Repr

/-- [SRC] 2026-10-15: the wire name of each command, src/protocol.cpp:16-53 at
6504a3af. `createstrm` is the constant `CREATESTREAM` (:46). -/
def Command.name : Command → String
  | .version => "version" | .verack => "verack" | .addr => "addr" | .inv => "inv"
  | .getdata => "getdata" | .merkleblock => "merkleblock" | .getblocks => "getblocks"
  | .getheaders => "getheaders" | .gethdrsen => "gethdrsen" | .tx => "tx"
  | .headers => "headers" | .hdrsen => "hdrsen" | .block => "block"
  | .getaddr => "getaddr" | .mempool => "mempool" | .ping => "ping" | .pong => "pong"
  | .notfound => "notfound" | .filterload => "filterload" | .filteradd => "filteradd"
  | .filterclear => "filterclear" | .reject => "reject" | .sendheaders => "sendheaders"
  | .sendhdrsen => "sendhdrsen" | .feefilter => "feefilter" | .sendcmpct => "sendcmpct"
  | .cmpctblock => "cmpctblock" | .getblocktxn => "getblocktxn" | .blocktxn => "blocktxn"
  | .protoconf => "protoconf" | .createstrm => "createstrm" | .streamack => "streamack"
  | .dsdetected => "dsdetected" | .extmsg => "extmsg" | .revokemid => "revokemid"
  | .authch => "authch" | .authresp => "authresp" | .datareftx => "datareftx"

/-- [SRC] 2026-10-15: every command once, in src/protocol.cpp:16-53's order at 6504a3af. -/
def Command.all : List Command :=
  [.version, .verack, .addr, .inv, .getdata, .merkleblock, .getblocks, .getheaders,
   .gethdrsen, .tx, .headers, .hdrsen, .block, .getaddr, .mempool, .ping, .pong,
   .notfound, .filterload, .filteradd, .filterclear, .reject, .sendheaders,
   .sendhdrsen, .feefilter, .sendcmpct, .cmpctblock, .getblocktxn, .blocktxn,
   .protoconf, .createstrm, .streamack, .dsdetected, .extmsg, .revokemid, .authch,
   .authresp, .datareftx]

/-- [SRC] 2026-10-15: `allNetMessageTypes`, the thirty-seven names the node
registers (src/protocol.cpp:107-121 at 6504a3af); the per-command byte
counters are keyed by this list (`getpeerinfo`'s `bytessent_per_msg`,
src/net/net.cpp's `mapSendBytesPerMsg`). It omits `revokemid`, which the
comment at :103-106 says the list keeps in step with the declarations: the
source disagrees with its own comment (rule 15), recorded here, never
repaired. -/
def Command.registered : List Command :=
  [.version, .verack, .addr, .inv, .getdata, .merkleblock, .getblocks, .getheaders,
   .gethdrsen, .tx, .headers, .hdrsen, .block, .getaddr, .mempool, .ping, .pong,
   .notfound, .filterload, .filteradd, .filterclear, .reject, .sendheaders,
   .sendhdrsen, .feefilter, .sendcmpct, .cmpctblock, .getblocktxn, .blocktxn,
   .protoconf, .createstrm, .streamack, .dsdetected, .extmsg, .authch, .authresp,
   .datareftx]

/-- [D] 2026-10-15: the command's name as bytes. -/
def Command.bytes (c : Command) : Bytes := asciiBytes c.name

/-- [SRC] 2026-10-15: `IsBlockLike`, src/protocol.cpp:55-61 at 6504a3af: the
commands whose cap is the block size. -/
def Command.blockLike : Command → Bool
  | .block | .cmpctblock | .blocktxn | .hdrsen => true
  | _ => false

/-! ## 3. The command field -/

/-- [SRC] 2026-10-15: the command written into its twelve bytes, NUL-padded
(`strncpy`, src/protocol.cpp:164,225,233 at 6504a3af). -/
def padCommand (c : Bytes) : Bytes := c ++ List.replicate (commandSize - c.length) 0

/-- [SRC] 2026-10-15: `GetCommand`: the bytes before the earliest NUL
(`strnlen`, src/protocol.cpp:168-172,278-287 at 6504a3af). -/
def stripCommand (raw : Bytes) : Bytes := raw.takeWhile (· != 0)

/-- [SRC] 2026-10-15: `CheckCommandFormat`, src/protocol.cpp:128-152 at
6504a3af: printable ASCII up to the earliest NUL, then only NULs. -/
def commandFormatOk (raw : Bytes) : Bool :=
  let name := stripCommand raw
  name.all (fun b => 0x20 ≤ b && b ≤ 0x7e) && (raw.drop name.length).all (· == 0)

/-- [SRC] 2026-10-15: the six bytes `extmsg` the reader compares the basic
command's prefix with (`strncmp` over `strlen(EXTMSG)`, src/protocol.cpp:259-266
at 6504a3af). -/
def extmsgPrefix : Bytes := asciiBytes "extmsg"

/-- [D] 2026-10-15: a command the frame carries and reads back: at most twelve
printable bytes, not beginning with `extmsg` (a basic header whose command
begins so is read as an extended header, src/protocol.cpp:259-266). -/
def CommandOk (c : Bytes) : Prop :=
  c.length ≤ commandSize ∧ (∀ b ∈ c, 0x20 ≤ b ∧ b ≤ 0x7e) ∧ (padCommand c).take 6 ≠ extmsgPrefix

instance (c : Bytes) : Decidable (CommandOk c) := by unfold CommandOk; infer_instance

/-! ## 4. The header -/

/-- [SRC] 2026-10-15: `CMessageHeader` (src/protocol.h:131-191 at 6504a3af):
the magic, the raw command field, the 32-bit length field, the checksum and,
for the extended form, the extended command field and the 64-bit length
(`CExtendedMessageHeader`, :93-119). -/
structure Header where
  magic : Bytes
  command : Bytes
  length : Nat
  checksum : Bytes
  extended : Option (Bytes × Nat)
  deriving DecidableEq, Repr

/-- [SRC] 2026-10-15: the checksum, the leading four bytes of the payload's
double SHA-256 (`msg.Hash()`, src/protocol.cpp:203-206,237; src/hash.h:24-56
at 6504a3af). -/
def checksumOf (payload : Bytes) : Bytes := (sha256d payload).take 4

/-- [SRC] 2026-10-15: the writer's header (src/protocol.cpp:208-241 at
6504a3af): above 2^32 - 1 bytes the extended form with the command `extmsg`,
the length field 0xffffffff and a zero checksum (:222-229); else the basic
form with the payload's checksum (:230-238). -/
def Header.make (magic cmd payload : Bytes) : Header :=
  if payload.length > 0xffffffff then
    { magic, command := padCommand extmsgPrefix, length := 0xffffffff,
      checksum := [0, 0, 0, 0], extended := some (padCommand cmd, payload.length) }
  else
    { magic, command := padCommand cmd, length := payload.length,
      checksum := checksumOf payload, extended := none }

/-- [SRC] 2026-10-15: the header's serialization, field by field
(src/protocol.h:99-105,155-168; little-endian integers src/serialize.h:71-116
at 6504a3af). -/
def Header.encode (h : Header) : Bytes :=
  h.magic ++ h.command ++ headerWordBytes 4 h.length ++ h.checksum ++
    match h.extended with
    | some (c, n) => c ++ headerWordBytes 8 n
    | none => []

/-- [SRC] 2026-10-15: the header's reader (`CMessageHeader::Read`,
src/protocol.cpp:244-276 at 6504a3af): the 24 basic bytes; when the command
field begins with `extmsg`, twenty more bytes of the extended fields. -/
def Header.read (bs : Bytes) : Option (Header × Bytes) := do
  let (magic, r1) ← readBytes magicSize bs
  let (command, r2) ← readBytes commandSize r1
  let (length, r3) ← readLE 4 r2
  let (checksum, r4) ← readBytes 4 r3
  if command.take 6 = extmsgPrefix then
    let (ec, r5) ← readBytes commandSize r4
    let (el, r6) ← readLE 8 r5
    pure ({ magic, command, length, checksum, extended := some (ec, el) }, r6)
  else
    pure ({ magic, command, length, checksum, extended := none }, r4)

/-- [SRC] 2026-10-15: `GetCommand`: the extended command for the extended
form (src/protocol.cpp:278-287 at 6504a3af). -/
def Header.getCommand (h : Header) : Bytes :=
  match h.extended with
  | some (c, _) => stripCommand c
  | none => stripCommand h.command

/-- [SRC] 2026-10-15: `GetPayloadLength` (src/protocol.cpp:294-302 at 6504a3af). -/
def Header.payloadLength (h : Header) : Nat :=
  match h.extended with
  | some (_, n) => n
  | none => h.length

/-- [SRC] 2026-10-15: `GetLength` (src/protocol.cpp:289-292 at 6504a3af). -/
def Header.size (h : Header) : Nat :=
  if h.extended.isSome then extendedHeaderSize else basicHeaderSize

/-! ## 5. The frame -/

/-- [SRC] 2026-10-15: a message on the wire, its header then its payload
(src/net/stream.cpp:240-275 at 6504a3af). -/
def frame (magic cmd payload : Bytes) : Bytes :=
  (Header.make magic cmd payload).encode ++ payload

/-- [SRC] 2026-10-15: one message read from the front of a stream
(src/net/net_message.cpp:12-53; the checksum compared for a basic header only,
src/net/net_processing.cpp:5054-5090 at 6504a3af): the command, the payload
and the rest. A wrong checksum yields `none`. The magic and the caps are
judged separately (`Header.valid`), as the node judges them. -/
def unframe (bs : Bytes) : Option ((Bytes × Bytes) × Bytes) := do
  let (h, r) ← Header.read bs
  let (payload, rest) ← readBytes h.payloadLength r
  if h.extended.isNone && checksumOf payload != h.checksum then none
  else pure ((h.getCommand, payload), rest)

/-! ## 6. The payload caps -/

/-- [SRC] 2026-10-15: the caps' constants. `DEFAULT_MAX_PROTOCOL_RECV_PAYLOAD_LENGTH`
2 MiB (src/protocol.h:33), `LEGACY_MAX_PROTOCOL_PAYLOAD_LENGTH` 1 MiB (:40),
the setting's upper bound `MAX_PROTOCOL_RECV_PAYLOAD_LENGTH` one gigabyte
(:45; `ONE_GIGABYTE` = 1000 * 1000 * 1000, src/consensus/consensus.h:13-17) at 6504a3af. -/
def defaultMaxRecvPayload : Nat := 2 * 1024 * 1024
def legacyMaxPayload : Nat := 1 * 1024 * 1024
def maxMaxRecvPayload : Nat := 1000 * 1000 * 1000

/-- [SRC] 2026-10-15: the inputs `GetMaxMessageLength` reads
(src/protocol.cpp:63-99 at 6504a3af): the setting `-maxprotocolrecvpayloadlength`
(policy), the consensus transaction-size bound after Genesis (`GetMaxTxSize(PostGenesis,
true)`, the census row `maxTxSizeConsensusAfterGenesis`) and the block-size
setting (`-excessiveblocksize`, the census row `excessiveBlockSize`). -/
structure CapInputs where
  maxRecvPayload : Nat := defaultMaxRecvPayload
  maxTxSizeConsensus : Nat := 1000000000
  maxBlockSize : Nat
  deriving Repr

/-- [SRC] 2026-10-15: `GetMaxMessageLength`, src/protocol.cpp:63-99 at
6504a3af: `protoconf` at 1 MiB, `tx` and `datareftx` at the consensus
transaction-size bound, `getblocktxn` at an estimate from the block size
(215-byte transactions, six-byte short ids, plus its header size), the
block-like commands at the block size, every other command at the receive
setting. -/
def maxMessageLength (k : CapInputs) (cmd : Bytes) : Nat :=
  if cmd = Command.protoconf.bytes then legacyMaxPayload
  else if cmd = Command.tx.bytes ∨ cmd = Command.datareftx.bytes then k.maxTxSizeConsensus
  else if cmd = Command.getblocktxn.bytes then
    let p := k.maxBlockSize / 215 * 6
    p + (if p > 0xffffffff then extendedHeaderSize else basicHeaderSize)
  else if Command.all.any (fun c => c.blockLike && c.bytes == cmd) then k.maxBlockSize
  else k.maxRecvPayload

/-- [SRC] 2026-10-15: `IsOversized` (src/protocol.cpp:192-195,362-365 at 6504a3af). -/
def Header.oversized (k : CapInputs) (h : Header) : Bool :=
  h.payloadLength > maxMessageLength k h.getCommand

/-- [SRC] 2026-10-15: `IsValid` (src/protocol.cpp:174-190,329-360 at
6504a3af): the magic, the command field's format, the cap, and for the
extended form the extended command's format and cap. -/
def Header.valid (k : CapInputs) (magic : Bytes) (h : Header) : Bool :=
  h.magic == magic && commandFormatOk h.command && !h.oversized k &&
    match h.extended with
    | some (c, _) => commandFormatOk c
    | none => true

/-! ## 7. The payloads -/

/-- [SRC] 2026-10-15: the inventory types, `GetDataMsg` (src/protocol.h:531-542
at 6504a3af); the type is a 32-bit word whose low 29 bits are the kind
(`MSG_TYPE_MASK`, :525). -/
def msgTx : Nat := 1
def msgBlock : Nat := 2
def msgFilteredBlock : Nat := 3
def msgCmpctBlock : Nat := 4
def msgDatarefTx : Nat := 5

/-- [SRC] 2026-10-15: `CInv`: a 32-bit type and a 32-byte hash
(src/protocol.h:545-561 at 6504a3af). -/
structure InvItem where
  kind : Nat
  hash : Bytes
  deriving DecidableEq, Repr

/-- [SRC] 2026-10-15: `CInv`'s serialization (src/protocol.h:555-561 at 6504a3af). -/
def InvItem.encode (i : InvItem) : Bytes := headerWordBytes 4 i.kind ++ i.hash

/-- [SRC] 2026-10-15: `CInv`'s reader (src/protocol.h:555-561 at 6504a3af). -/
def InvItem.read (bs : Bytes) : Option (InvItem × Bytes) := do
  let (kind, r1) ← readLE 4 bs
  let (hash, r2) ← readBytes 32 r1
  pure ({ kind, hash }, r2)

/-- [SRC] 2026-10-15: the payload of `inv`, `getdata` and `notfound`: a
CompactSize count and the items (`std::vector<CInv>`, src/serialize.h:716-726
and 794-840; `vRecv >> vInv` src/net/net_processing.cpp:2462,2545 at
6504a3af). [M] 2026-10-15: no per-message item cap other than the payload's
at the pin (`git grep MAX_INV_SZ 6504a3af -- src` finds nothing). -/
def encodeInv (items : List InvItem) : Bytes :=
  compactSize items.length ++ (items.map InvItem.encode).flatten

/-- [SRC] 2026-10-15: the inventory payload's reader; the whole payload is the
vector (src/net/net_processing.cpp:2461-2462 at 6504a3af). -/
def decodeInv (bs : Bytes) : Option (List InvItem) := do
  let (n, r) ← readVarInt bs
  let (items, rest) ← readMany InvItem.read n r
  if rest = [] then pure items else none

/-- [SRC] 2026-10-15: a string or byte vector: a CompactSize length then the
bytes (src/serialize.h:696-726 at 6504a3af). -/
def encodeVarBytes (s : Bytes) : Bytes := compactSize s.length ++ s

/-- [SRC] 2026-10-15: `LIMITED_STRING`: a longer length is refused
("Array length limit exceeded", src/serialize.h:429,503-520 at 6504a3af). -/
def readVarBytes (limit : Nat) (bs : Bytes) : Option (Bytes × Bytes) := do
  let (n, r) ← readVarInt bs
  if n > limit then none else readBytes n r

/-- [SRC] 2026-10-15: the reject codes on the wire: src/consensus/validation.h:14-24
(0x01 malformed, 0x10 invalid, 0x11 obsolete, 0x12 duplicate, 0x13 soft
consensus freeze, 0x40 nonstandard, 0x41 dust, 0x42 insufficient fee, 0x43
checkpoint, 0x44 too busy, 0x45 rate exceeded), src/net/net_types.h:26 (0x60
stream setup) and src/net/authconn.h:25 (0x70 authenticated-connection setup)
at 6504a3af. -/
def rejectMalformed : Nat := 0x01
def rejectInvalid : Nat := 0x10
def rejectObsolete : Nat := 0x11
def rejectDuplicate : Nat := 0x12
def rejectSoftConsensusFreeze : Nat := 0x13
def rejectNonstandard : Nat := 0x40
def rejectDust : Nat := 0x41
def rejectInsufficientFee : Nat := 0x42
def rejectCheckpoint : Nat := 0x43
def rejectTooBusy : Nat := 0x44
def rejectRateExceeded : Nat := 0x45
def rejectStreamSetup : Nat := 0x60
def rejectAuthConnSetup : Nat := 0x70

/-- [SRC] 2026-10-15: the validator's internal codes, at or above
`REJECT_INTERNAL` = 0x100, never sent (src/validation.h:1150-1163;
`CreateTxRejectMsgForP2PTxn` sends a code only when `0 < code < 0x100`,
src/validation.cpp:1940-1941 at 6504a3af): 0x100 high fee, 0x101 already
known, 0x102 conflict, 0x103 mempool full. -/
def rejectInternal : Nat := 0x100

/-- [SRC] 2026-10-15: the wire codes, in the headers' order. -/
def rejectCodes : List Nat :=
  [rejectMalformed, rejectInvalid, rejectObsolete, rejectDuplicate, rejectSoftConsensusFreeze,
   rejectNonstandard, rejectDust, rejectInsufficientFee, rejectCheckpoint, rejectTooBusy,
   rejectRateExceeded, rejectStreamSetup, rejectAuthConnSetup]

/-- [SRC] 2026-10-15: `MAX_REJECT_MESSAGE_LENGTH` = 111, the reason's cap on
both sides (src/validation.h:155; the writer's `substr`,
src/validation.cpp:1949; the reader's `LIMITED_STRING`,
src/net/net_processing.cpp:1494-1496 at 6504a3af). -/
def maxRejectReason : Nat := 111

/-- [SRC] 2026-10-15: a `reject` payload: the rejected message's command, the
code (one byte), the reason, and for `block` and `tx` the object's hash
(the writer src/validation.cpp:1943-1950, src/net/net_processing.cpp:4890-4896;
the reader :1485-1521 at 6504a3af). -/
structure Reject where
  message : Bytes
  code : Nat
  reason : Bytes
  hash : Option Bytes
  deriving DecidableEq, Repr

/-- [SRC] 2026-10-15: the `reject` payload's writer (`CNetMsgMaker::Make`
over the fields in order, src/validation.cpp:1946-1950 at 6504a3af). -/
def Reject.encode (r : Reject) : Bytes :=
  encodeVarBytes r.message ++ headerWordBytes 1 r.code ++ encodeVarBytes r.reason ++
    match r.hash with
    | some h => h
    | none => []

/-- [SRC] 2026-10-15: the `reject` payload's reader, src/net/net_processing.cpp:1491-1506
at 6504a3af: the hash is read for `block` and `tx` only. -/
def Reject.decode (bs : Bytes) : Option Reject := do
  let (message, r1) ← readVarBytes commandSize bs
  let (code, r2) ← readLE 1 r1
  let (reason, r3) ← readVarBytes maxRejectReason r2
  if message = Command.block.bytes ∨ message = Command.tx.bytes then
    let (h, r4) ← readBytes 32 r3
    if r4 = [] then pure { message, code, reason, hash := some h } else none
  else if r3 = [] then pure { message, code, reason, hash := none } else none

/-- [SRC] 2026-10-15: `ping` and `pong` carry a 64-bit nonce
(src/net/net_processing.cpp:4212-4290 at 6504a3af). -/
def encodeNonce (n : Nat) : Bytes := headerWordBytes 8 n

/-- [SRC] 2026-10-15: the nonce's reader (src/net/net_processing.cpp:4212-4290 at 6504a3af). -/
def decodeNonce (bs : Bytes) : Option Nat := do
  let (n, r) ← readLE 8 bs
  if r = [] then pure n else none

/-- [SRC] 2026-10-15: `CProtoconf`: a CompactSize field count (2 by the
writer), the receive cap, the stream policies' names (src/protocol.h:596-626;
the name limit `MAX_STREAM_POLICY_NAME_LENGTH` 64, src/net/net_types.h:29, ten
names) at 6504a3af. -/
structure Protoconf where
  maxRecvPayload : Nat
  streamPolicies : Bytes
  deriving DecidableEq, Repr

/-- [SRC] 2026-10-15: the stream policies' limit, (64 + 1) * 10 bytes
(src/protocol.h:598,619 at 6504a3af). -/
def maxStreamPolicies : Nat := (64 + 1) * 10

/-- [SRC] 2026-10-15: the writer's two-field form (src/protocol.h:602,614-625 at 6504a3af). -/
def Protoconf.encode (p : Protoconf) : Bytes :=
  compactSize 2 ++ headerWordBytes 4 p.maxRecvPayload ++ encodeVarBytes p.streamPolicies

/-- [SRC] 2026-10-15: the reader of the two-field form; zero fields is refused
(src/protocol.h:614-625 at 6504a3af). [D] The one-field form and extra fields
are read by the node and not modelled here. -/
def Protoconf.decode (bs : Bytes) : Option Protoconf := do
  let (n, r1) ← readVarInt bs
  if n ≠ 2 then none else
  let (m, r2) ← readLE 4 r1
  let (s, r3) ← readVarBytes maxStreamPolicies r2
  if r3 = [] then pure { maxRecvPayload := m, streamPolicies := s } else none

/-- [SRC] 2026-10-15: an address as the version message carries it, without a
time (the stream's version `INIT_PROTO_VERSION` 209 is below
`CADDR_TIME_VERSION` 31402, src/version.h:14,24; src/protocol.h:503-514): the
services word, sixteen bytes of address and a big-endian port
(src/net/netaddress.h:172-178 at 6504a3af). -/
structure NetAddr where
  services : Nat
  ip : Bytes
  port : Nat
  deriving DecidableEq, Repr

/-- [SRC] 2026-10-15: the address's serialization (src/protocol.h:503-514,
src/net/netaddress.h:172-178 at 6504a3af). -/
def NetAddr.encode (a : NetAddr) : Bytes :=
  headerWordBytes 8 a.services ++ a.ip ++ [a.port / 256 % 256, a.port % 256]

/-- [SRC] 2026-10-15: the address's reader (as above). -/
def NetAddr.read (bs : Bytes) : Option (NetAddr × Bytes) := do
  let (services, r1) ← readLE 8 bs
  let (ip, r2) ← readBytes 16 r1
  let (p, r3) ← readBytes 2 r2
  match p with
  | [hi, lo] => pure ({ services, ip, port := hi * 256 + lo }, r3)
  | _ => none

/-- [SRC] 2026-10-15: the `version` message as the node writes it
(`PushNodeVersion`, src/net/net_processing.cpp:127-166 at 6504a3af): the
protocol version, the services, the time, the two addresses, the nonce, the
user agent, the starting height, the relay flag and the association id. The
32- and 64-bit signed fields are carried as their unsigned words. -/
structure Version where
  version : Nat
  services : Nat
  time : Nat
  addrYou : NetAddr
  addrMe : NetAddr
  nonce : Nat
  userAgent : Bytes
  startHeight : Nat
  relay : Bool
  assocId : Bytes
  deriving DecidableEq, Repr

/-- [SRC] 2026-10-15: the writer's field order (src/net/net_processing.cpp:149-154 at 6504a3af). -/
def Version.encode (v : Version) : Bytes :=
  headerWordBytes 4 v.version ++ headerWordBytes 8 v.services ++ headerWordBytes 8 v.time ++
    v.addrYou.encode ++ v.addrMe.encode ++ headerWordBytes 8 v.nonce ++
    encodeVarBytes v.userAgent ++ headerWordBytes 4 v.startHeight ++
    headerWordBytes 1 (if v.relay then 1 else 0) ++ encodeVarBytes v.assocId

/-- [SRC] 2026-10-15: `MAX_SUBVERSION_LENGTH` 256 (src/net/net.h:95 at 6504a3af). -/
def maxSubversion : Nat := 256

/-- [SRC] 2026-10-15: the reader of the writer's full form
(`ProcessVersionMessage`, src/net/net_processing.cpp:1704,1744-1770 at
6504a3af). [D] The node also accepts a payload that stops after any field
from the address of the sender on (each tail read under `!vRecv.empty()`);
that tail rule is not modelled here, and the association id's own limit is
taken as the payload's. The relay byte reads any nonzero value as true. -/
def Version.decode (bs : Bytes) : Option Version := do
  let (version, r1) ← readLE 4 bs
  let (services, r2) ← readLE 8 r1
  let (time, r3) ← readLE 8 r2
  let (addrYou, r4) ← NetAddr.read r3
  let (addrMe, r5) ← NetAddr.read r4
  let (nonce, r6) ← readLE 8 r5
  let (userAgent, r7) ← readVarBytes maxSubversion r6
  let (startHeight, r8) ← readLE 4 r7
  let (relay, r9) ← readLE 1 r8
  let (assocId, r10) ← readVarBytes r9.length r9
  if r10 = [] then
    pure { version, services, time, addrYou, addrMe, nonce, userAgent, startHeight,
           relay := relay != 0, assocId }
  else none

end BsvChain.Wire
