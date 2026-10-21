/-!
# BsvScript.Opcodes

The opcode table (`src/script/opcodes.h:13–160` at the pin, `docs/PROVENANCE.md`)
and the error vocabulary (`src/script/script_error.h:12–87`). The families'
semantics land in `BsvScript.Ops.*` (#9 arithmetic and bitwise, #10 stack and
splice, #11 crypto, #18 the rest) and are assembled in `BsvScript.Eval`; the
flow opcodes and the pushes are the machine's own (`BsvScript.Machine`, #8).
[LIT] https://protocol.bsvblockchain.org/specification/opcodes#how-to-read-this-page at v1.2.2 (the byte values only).
-/

namespace BsvScript

-- The opcode bytes (`opcodes.h:13–160`). Names as in the reference; the
-- aliases (`OP_NOP2` = `OP_CHECKLOCKTIMEVERIFY` …) are omitted in favour of the
-- functional name.
namespace Op
-- push value (13–36)
def OP_0 : Nat := 0x00
def OP_FALSE : Nat := OP_0
def OP_PUSHDATA1 : Nat := 0x4c
def OP_PUSHDATA2 : Nat := 0x4d
def OP_PUSHDATA4 : Nat := 0x4e
def OP_1NEGATE : Nat := 0x4f
def OP_RESERVED : Nat := 0x50
def OP_1 : Nat := 0x51
def OP_TRUE : Nat := OP_1
def OP_2 : Nat := 0x52
def OP_3 : Nat := 0x53
def OP_4 : Nat := 0x54
def OP_5 : Nat := 0x55
def OP_6 : Nat := 0x56
def OP_7 : Nat := 0x57
def OP_8 : Nat := 0x58
def OP_9 : Nat := 0x59
def OP_10 : Nat := 0x5a
def OP_11 : Nat := 0x5b
def OP_12 : Nat := 0x5c
def OP_13 : Nat := 0x5d
def OP_14 : Nat := 0x5e
def OP_15 : Nat := 0x5f
def OP_16 : Nat := 0x60
-- control (38–48)
def OP_NOP : Nat := 0x61
def OP_VER : Nat := 0x62
def OP_IF : Nat := 0x63
def OP_NOTIF : Nat := 0x64
def OP_VERIF : Nat := 0x65
def OP_VERNOTIF : Nat := 0x66
def OP_ELSE : Nat := 0x67
def OP_ENDIF : Nat := 0x68
def OP_VERIFY : Nat := 0x69
def OP_RETURN : Nat := 0x6a
-- stack ops (50–69)
def OP_TOALTSTACK : Nat := 0x6b
def OP_FROMALTSTACK : Nat := 0x6c
def OP_2DROP : Nat := 0x6d
def OP_2DUP : Nat := 0x6e
def OP_3DUP : Nat := 0x6f
def OP_2OVER : Nat := 0x70
def OP_2ROT : Nat := 0x71
def OP_2SWAP : Nat := 0x72
def OP_IFDUP : Nat := 0x73
def OP_DEPTH : Nat := 0x74
def OP_DROP : Nat := 0x75
def OP_DUP : Nat := 0x76
def OP_NIP : Nat := 0x77
def OP_OVER : Nat := 0x78
def OP_PICK : Nat := 0x79
def OP_ROLL : Nat := 0x7a
def OP_ROT : Nat := 0x7b
def OP_SWAP : Nat := 0x7c
def OP_TUCK : Nat := 0x7d
-- splice ops (71–76)
def OP_CAT : Nat := 0x7e
def OP_SPLIT : Nat := 0x7f
def OP_NUM2BIN : Nat := 0x80
def OP_BIN2NUM : Nat := 0x81
def OP_SIZE : Nat := 0x82
-- bit logic (78–87)
def OP_INVERT : Nat := 0x83
def OP_AND : Nat := 0x84
def OP_OR : Nat := 0x85
def OP_XOR : Nat := 0x86
def OP_EQUAL : Nat := 0x87
def OP_EQUALVERIFY : Nat := 0x88
def OP_RESERVED1 : Nat := 0x89
def OP_RESERVED2 : Nat := 0x8a
-- numeric (89–117)
def OP_1ADD : Nat := 0x8b
def OP_1SUB : Nat := 0x8c
def OP_2MUL : Nat := 0x8d
def OP_2DIV : Nat := 0x8e
def OP_NEGATE : Nat := 0x8f
def OP_ABS : Nat := 0x90
def OP_NOT : Nat := 0x91
def OP_0NOTEQUAL : Nat := 0x92
def OP_ADD : Nat := 0x93
def OP_SUB : Nat := 0x94
def OP_MUL : Nat := 0x95
def OP_DIV : Nat := 0x96
def OP_MOD : Nat := 0x97
def OP_LSHIFT : Nat := 0x98
def OP_RSHIFT : Nat := 0x99
def OP_BOOLAND : Nat := 0x9a
def OP_BOOLOR : Nat := 0x9b
def OP_NUMEQUAL : Nat := 0x9c
def OP_NUMEQUALVERIFY : Nat := 0x9d
def OP_NUMNOTEQUAL : Nat := 0x9e
def OP_LESSTHAN : Nat := 0x9f
def OP_GREATERTHAN : Nat := 0xa0
def OP_LESSTHANOREQUAL : Nat := 0xa1
def OP_GREATERTHANOREQUAL : Nat := 0xa2
def OP_MIN : Nat := 0xa3
def OP_MAX : Nat := 0xa4
def OP_WITHIN : Nat := 0xa5
-- crypto (120–130)
def OP_RIPEMD160 : Nat := 0xa6
def OP_SHA1 : Nat := 0xa7
def OP_SHA256 : Nat := 0xa8
def OP_HASH160 : Nat := 0xa9
def OP_HASH256 : Nat := 0xaa
def OP_CODESEPARATOR : Nat := 0xab
def OP_CHECKSIG : Nat := 0xac
def OP_CHECKSIGVERIFY : Nat := 0xad
def OP_CHECKMULTISIG : Nat := 0xae
def OP_CHECKMULTISIGVERIFY : Nat := 0xaf
-- expansion (133–149)
def OP_NOP1 : Nat := 0xb0
def OP_CHECKLOCKTIMEVERIFY : Nat := 0xb1
def OP_CHECKSEQUENCEVERIFY : Nat := 0xb2
def OP_SUBSTR : Nat := 0xb3
def OP_LEFT : Nat := 0xb4
def OP_RIGHT : Nat := 0xb5
def OP_LSHIFTNUM : Nat := 0xb6
def OP_RSHIFTNUM : Nat := 0xb7
def OP_NOP9 : Nat := 0xb8
def OP_NOP10 : Nat := 0xb9
/-- The first byte after the defined opcodes (`opcodes.h:152`). -/
def FIRST_UNDEFINED_OP_VALUE : Nat := 0xba
def OP_INVALIDOPCODE : Nat := 0xff

/-- The opcodes that have a `case` label in `EvalScript`'s switch at the pin
(the case-label map, `docs/DESIGN.md` §3): `OP_1NEGATE`, `OP_1`–`OP_16`, the
flow, stack, splice, bitwise and equality opcodes `0x61`–`0x88`, the numeric,
crypto and expansion opcodes `0x8b`–`0xb9`. Everything else above the pushes
(`OP_RESERVED` `0x50`, `OP_RESERVED1/2` `0x89`/`0x8a`, `0xba`–`0xff`) reaches
the `default:` case, `SCRIPT_ERR_BAD_OPCODE` when executed (`interpreter.cpp:1795`). -/
def hasCase (op : Nat) : Bool :=
  op == OP_1NEGATE || (OP_1 ≤ op && op ≤ OP_EQUALVERIFY) || (OP_1ADD ≤ op && op ≤ OP_NOP10)
end Op

/-- The reference's error vocabulary, `script_error.h:12–87`, without `OK` (a
verdict is `valid` or `invalid` with one of these) and without `ERROR_COUNT`.
`name` is the `SCRIPT_ERR_*` identifier the corpus's `code` field carries
(`docs/DESIGN.md` §6); `message` is `ScriptErrorString` (`script_error.cpp`). -/
inductive ScriptError where
  | unknownError
  | evalFalse
  | opReturn
  | scriptSize
  | pushSize
  | opCount
  | stackSize
  | sigCount
  | pubkeyCount
  | invalidOperandSize
  | invalidNumberRange
  | impossibleEncoding
  | invalidSplitRange
  | scriptnumOverflow
  | scriptnumMinencode
  | verify
  | equalverify
  | checkmultisigverify
  | checksigverify
  | numequalverify
  | badOpcode
  | disabledOpcode
  | invalidStackOperation
  | invalidAltstackOperation
  | unbalancedConditional
  | divByZero
  | modByZero
  | negativeLocktime
  | unsatisfiedLocktime
  | sigHashtype
  | sigDer
  | minimaldata
  | sigPushonly
  | sigHighS
  | sigNulldummy
  | pubkeytype
  | cleanstack
  | minimalif
  | sigNullfail
  | discourageUpgradableNops
  | noncompressedPubkey
  | illegalForkid
  | mustUseForkid
  | illegalChronicle
  | bigInt
  | invalidFlags
  deriving DecidableEq, Repr

namespace ScriptError

def name : ScriptError → String
  | unknownError => "SCRIPT_ERR_UNKNOWN_ERROR"
  | evalFalse => "SCRIPT_ERR_EVAL_FALSE"
  | opReturn => "SCRIPT_ERR_OP_RETURN"
  | scriptSize => "SCRIPT_ERR_SCRIPT_SIZE"
  | pushSize => "SCRIPT_ERR_PUSH_SIZE"
  | opCount => "SCRIPT_ERR_OP_COUNT"
  | stackSize => "SCRIPT_ERR_STACK_SIZE"
  | sigCount => "SCRIPT_ERR_SIG_COUNT"
  | pubkeyCount => "SCRIPT_ERR_PUBKEY_COUNT"
  | invalidOperandSize => "SCRIPT_ERR_INVALID_OPERAND_SIZE"
  | invalidNumberRange => "SCRIPT_ERR_INVALID_NUMBER_RANGE"
  | impossibleEncoding => "SCRIPT_ERR_IMPOSSIBLE_ENCODING"
  | invalidSplitRange => "SCRIPT_ERR_INVALID_SPLIT_RANGE"
  | scriptnumOverflow => "SCRIPT_ERR_SCRIPTNUM_OVERFLOW"
  | scriptnumMinencode => "SCRIPT_ERR_SCRIPTNUM_MINENCODE"
  | verify => "SCRIPT_ERR_VERIFY"
  | equalverify => "SCRIPT_ERR_EQUALVERIFY"
  | checkmultisigverify => "SCRIPT_ERR_CHECKMULTISIGVERIFY"
  | checksigverify => "SCRIPT_ERR_CHECKSIGVERIFY"
  | numequalverify => "SCRIPT_ERR_NUMEQUALVERIFY"
  | badOpcode => "SCRIPT_ERR_BAD_OPCODE"
  | disabledOpcode => "SCRIPT_ERR_DISABLED_OPCODE"
  | invalidStackOperation => "SCRIPT_ERR_INVALID_STACK_OPERATION"
  | invalidAltstackOperation => "SCRIPT_ERR_INVALID_ALTSTACK_OPERATION"
  | unbalancedConditional => "SCRIPT_ERR_UNBALANCED_CONDITIONAL"
  | divByZero => "SCRIPT_ERR_DIV_BY_ZERO"
  | modByZero => "SCRIPT_ERR_MOD_BY_ZERO"
  | negativeLocktime => "SCRIPT_ERR_NEGATIVE_LOCKTIME"
  | unsatisfiedLocktime => "SCRIPT_ERR_UNSATISFIED_LOCKTIME"
  | sigHashtype => "SCRIPT_ERR_SIG_HASHTYPE"
  | sigDer => "SCRIPT_ERR_SIG_DER"
  | minimaldata => "SCRIPT_ERR_MINIMALDATA"
  | sigPushonly => "SCRIPT_ERR_SIG_PUSHONLY"
  | sigHighS => "SCRIPT_ERR_SIG_HIGH_S"
  | sigNulldummy => "SCRIPT_ERR_SIG_NULLDUMMY"
  | pubkeytype => "SCRIPT_ERR_PUBKEYTYPE"
  | cleanstack => "SCRIPT_ERR_CLEANSTACK"
  | minimalif => "SCRIPT_ERR_MINIMALIF"
  | sigNullfail => "SCRIPT_ERR_SIG_NULLFAIL"
  | discourageUpgradableNops => "SCRIPT_ERR_DISCOURAGE_UPGRADABLE_NOPS"
  | noncompressedPubkey => "SCRIPT_ERR_NONCOMPRESSED_PUBKEY"
  | illegalForkid => "SCRIPT_ERR_ILLEGAL_FORKID"
  | mustUseForkid => "SCRIPT_ERR_MUST_USE_FORKID"
  | illegalChronicle => "SCRIPT_ERR_ILLEGAL_CHRONICLE"
  | bigInt => "SCRIPT_ERR_BIG_INT"
  | invalidFlags => "SCRIPT_ERR_INVALID_FLAGS"

/-- `ScriptErrorString` (`script_error.cpp:9–111`). -/
def message : ScriptError → String
  | unknownError => "unknown error"
  | evalFalse => "Script evaluated without error but finished with a false/empty top stack element"
  | opReturn => "OP_RETURN was encountered"
  | scriptSize => "Script is too big"
  | pushSize => "Push value size limit exceeded"
  | opCount => "Operation limit exceeded"
  | stackSize => "Stack size limit exceeded"
  | sigCount => "Signature count negative or greater than pubkey count"
  | pubkeyCount => "Pubkey count negative or limit exceeded"
  | invalidOperandSize => "Invalid operand size"
  | invalidNumberRange => "Given operand is not a number within the valid range [-2^31...2^31]"
  | impossibleEncoding => "The requested encoding is impossible to satisfy"
  | invalidSplitRange => "Invalid OP_SPLIT range"
  | scriptnumOverflow => "Script number overflow"
  | scriptnumMinencode => "Non-minimally encoded script number"
  | verify => "Script failed an OP_VERIFY operation"
  | equalverify => "Script failed an OP_EQUALVERIFY operation"
  | checkmultisigverify => "Script failed an OP_CHECKMULTISIGVERIFY operation"
  | checksigverify => "Script failed an OP_CHECKSIGVERIFY operation"
  | numequalverify => "Script failed an OP_NUMEQUALVERIFY operation"
  | badOpcode => "Opcode missing or not understood"
  | disabledOpcode => "Attempted to use a disabled opcode"
  | invalidStackOperation => "Operation not valid with the current stack size"
  | invalidAltstackOperation => "Operation not valid with the current altstack size"
  | unbalancedConditional => "Invalid OP_IF construction"
  | divByZero => "Division by zero error"
  | modByZero => "Modulo by zero error"
  | negativeLocktime => "Negative locktime"
  | unsatisfiedLocktime => "Locktime requirement not satisfied"
  | sigHashtype => "Signature hash type missing or not understood"
  | sigDer => "Non-canonical DER signature"
  | minimaldata => "Data push larger than necessary"
  | sigPushonly => "Only non-push operators allowed in signatures"
  | sigHighS => "Non-canonical signature: S value is unnecessarily high"
  | sigNulldummy => "Dummy CHECKMULTISIG argument must be zero"
  | pubkeytype => "Public key is neither compressed or uncompressed"
  | cleanstack => "Script did not clean its stack"
  | minimalif => "OP_IF/NOTIF argument must be minimal"
  | sigNullfail => "Signature must be zero for failed CHECK(MULTI)SIG operation"
  | discourageUpgradableNops => "NOPx reserved for soft-fork upgrades"
  | noncompressedPubkey => "Using non-compressed public key"
  | illegalForkid => "Illegal use of SIGHASH_FORKID"
  | mustUseForkid => "Signature must use SIGHASH_FORKID"
  | illegalChronicle => "Illegal use of SIGHASH_CHRONICLE"
  | bigInt => "Big integer OpenSSL error"
  | invalidFlags => "Invalid script verification flag combination"

end ScriptError

end BsvScript
