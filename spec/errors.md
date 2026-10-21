# The error vocabulary

`ScriptError` (`lean/BsvScript/Opcodes.lean`) = `src/script/script_error.h:12–87` without `OK`; the message is `ScriptErrorString` (`script_error.cpp`). The corpus's `code` field carries the name.

| constructor | `SCRIPT_ERR_*` | message |
|---|---|---|
| `unknownError` | `SCRIPT_ERR_UNKNOWN_ERROR` | unknown error |
| `evalFalse` | `SCRIPT_ERR_EVAL_FALSE` | Script evaluated without error but finished with a false/empty top stack element |
| `opReturn` | `SCRIPT_ERR_OP_RETURN` | OP_RETURN was encountered |
| `scriptSize` | `SCRIPT_ERR_SCRIPT_SIZE` | Script is too big |
| `pushSize` | `SCRIPT_ERR_PUSH_SIZE` | Push value size limit exceeded |
| `opCount` | `SCRIPT_ERR_OP_COUNT` | Operation limit exceeded |
| `stackSize` | `SCRIPT_ERR_STACK_SIZE` | Stack size limit exceeded |
| `sigCount` | `SCRIPT_ERR_SIG_COUNT` | Signature count negative or greater than pubkey count |
| `pubkeyCount` | `SCRIPT_ERR_PUBKEY_COUNT` | Pubkey count negative or limit exceeded |
| `invalidOperandSize` | `SCRIPT_ERR_INVALID_OPERAND_SIZE` | Invalid operand size |
| `invalidNumberRange` | `SCRIPT_ERR_INVALID_NUMBER_RANGE` | Given operand is not a number within the valid range [-2^31...2^31] |
| `impossibleEncoding` | `SCRIPT_ERR_IMPOSSIBLE_ENCODING` | The requested encoding is impossible to satisfy |
| `invalidSplitRange` | `SCRIPT_ERR_INVALID_SPLIT_RANGE` | Invalid OP_SPLIT range |
| `scriptnumOverflow` | `SCRIPT_ERR_SCRIPTNUM_OVERFLOW` | Script number overflow |
| `scriptnumMinencode` | `SCRIPT_ERR_SCRIPTNUM_MINENCODE` | Non-minimally encoded script number |
| `verify` | `SCRIPT_ERR_VERIFY` | Script failed an OP_VERIFY operation |
| `equalverify` | `SCRIPT_ERR_EQUALVERIFY` | Script failed an OP_EQUALVERIFY operation |
| `checkmultisigverify` | `SCRIPT_ERR_CHECKMULTISIGVERIFY` | Script failed an OP_CHECKMULTISIGVERIFY operation |
| `checksigverify` | `SCRIPT_ERR_CHECKSIGVERIFY` | Script failed an OP_CHECKSIGVERIFY operation |
| `numequalverify` | `SCRIPT_ERR_NUMEQUALVERIFY` | Script failed an OP_NUMEQUALVERIFY operation |
| `badOpcode` | `SCRIPT_ERR_BAD_OPCODE` | Opcode missing or not understood |
| `disabledOpcode` | `SCRIPT_ERR_DISABLED_OPCODE` | Attempted to use a disabled opcode |
| `invalidStackOperation` | `SCRIPT_ERR_INVALID_STACK_OPERATION` | Operation not valid with the current stack size |
| `invalidAltstackOperation` | `SCRIPT_ERR_INVALID_ALTSTACK_OPERATION` | Operation not valid with the current altstack size |
| `unbalancedConditional` | `SCRIPT_ERR_UNBALANCED_CONDITIONAL` | Invalid OP_IF construction |
| `divByZero` | `SCRIPT_ERR_DIV_BY_ZERO` | Division by zero error |
| `modByZero` | `SCRIPT_ERR_MOD_BY_ZERO` | Modulo by zero error |
| `negativeLocktime` | `SCRIPT_ERR_NEGATIVE_LOCKTIME` | Negative locktime |
| `unsatisfiedLocktime` | `SCRIPT_ERR_UNSATISFIED_LOCKTIME` | Locktime requirement not satisfied |
| `sigHashtype` | `SCRIPT_ERR_SIG_HASHTYPE` | Signature hash type missing or not understood |
| `sigDer` | `SCRIPT_ERR_SIG_DER` | Non-canonical DER signature |
| `minimaldata` | `SCRIPT_ERR_MINIMALDATA` | Data push larger than necessary |
| `sigPushonly` | `SCRIPT_ERR_SIG_PUSHONLY` | Only non-push operators allowed in signatures |
| `sigHighS` | `SCRIPT_ERR_SIG_HIGH_S` | Non-canonical signature: S value is unnecessarily high |
| `sigNulldummy` | `SCRIPT_ERR_SIG_NULLDUMMY` | Dummy CHECKMULTISIG argument must be zero |
| `pubkeytype` | `SCRIPT_ERR_PUBKEYTYPE` | Public key is neither compressed or uncompressed |
| `cleanstack` | `SCRIPT_ERR_CLEANSTACK` | Script did not clean its stack |
| `minimalif` | `SCRIPT_ERR_MINIMALIF` | OP_IF/NOTIF argument must be minimal |
| `sigNullfail` | `SCRIPT_ERR_SIG_NULLFAIL` | Signature must be zero for failed CHECK(MULTI)SIG operation |
| `discourageUpgradableNops` | `SCRIPT_ERR_DISCOURAGE_UPGRADABLE_NOPS` | NOPx reserved for soft-fork upgrades |
| `noncompressedPubkey` | `SCRIPT_ERR_NONCOMPRESSED_PUBKEY` | Using non-compressed public key |
| `illegalForkid` | `SCRIPT_ERR_ILLEGAL_FORKID` | Illegal use of SIGHASH_FORKID |
| `mustUseForkid` | `SCRIPT_ERR_MUST_USE_FORKID` | Signature must use SIGHASH_FORKID |
| `illegalChronicle` | `SCRIPT_ERR_ILLEGAL_CHRONICLE` | Illegal use of SIGHASH_CHRONICLE |
| `bigInt` | `SCRIPT_ERR_BIG_INT` | Big integer OpenSSL error |
| `invalidFlags` | `SCRIPT_ERR_INVALID_FLAGS` | Invalid script verification flag combination |
