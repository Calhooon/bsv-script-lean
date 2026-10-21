//! The ts-sdk message → `SCRIPT_ERR_*` table (this repo's; #29, `docs/DESIGN.md` §6).
//!
//! @bsv/sdk 3.0.0 (`docs/PROVENANCE.md` §1a; the source `bsv-blockchain/ts-stack` at `4d0ea63c8`,
//! `packages/sdk/src/script/Spend.ts`, byte-identical to 2.8.10's at `5a4053223`, so every line below holds) reports no error enum: `ScriptEvaluationError.message` is a sentence
//! (`Spend.ts:2307–2319`, `#scriptEvaluationError`, one site per condition; the error's `message` is
//! `Script evaluation error: <sentence>\nTXID: …\nContext: …`, of which the harness keeps the sentence).
//! bsv-rs's messages were ported from this file, so most rows are `bsvrs_codes.rs`'s twins with the ts-sdk
//! line instead. It is a CITED TABLE: every row names the Spend.ts line at the pin and the reference's site
//! (`src/script/script_error.h:12–87`); a vocabulary difference is a `note`. Tier 1 (validity) never reads
//! this table; a message outside it makes the run RED so the table grows.
//!
//! Matching is by prefix on the sentence with its `${…}` holes removed; the first matching row wins, the
//! more specific prefixes first. Rows whose sentence is `<OP_NAME> requires …` are matched on the clause
//! (`CLAUSES`), as in `bsvrs_codes.rs`.

#[derive(Clone, Copy, Debug)]
pub struct Row {
    pub prefix: &'static str,
    pub tssdk_line: &'static str,
    pub code: &'static str,
    pub reference: &'static str,
    pub note: &'static str,
}

pub const TABLE: &[Row] = &[
    Row { prefix: "OP_NUM2BIN size exceeds the node int32 push limit.", tssdk_line: "Spend.ts:1942", code: "SCRIPT_ERR_PUSH_SIZE", reference: "interpreter.cpp:1749", note: "the node int32 bound on a produced element" },
    Row { prefix: "OP_CHECKLOCKTIMEVERIFY lock time is unsatisfied.", tssdk_line: "Spend.ts:904", code: "SCRIPT_ERR_UNSATISFIED_LOCKTIME", reference: "interpreter.cpp:556–558", note: "" },
    Row { prefix: "OP_CHECKLOCKTIMEVERIFY requires one stack item.", tssdk_line: "Spend.ts:894", code: "SCRIPT_ERR_INVALID_STACK_OPERATION", reference: "interpreter.cpp:533–535", note: "" },
    Row { prefix: "Negative lock time.", tssdk_line: "Spend.ts:896", code: "SCRIPT_ERR_NEGATIVE_LOCKTIME", reference: "interpreter.cpp:552–554", note: "" },
    Row { prefix: "OP_LSHIFTNUM shift count exceeds INT_MAX.", tssdk_line: "Spend.ts:1059", code: "SCRIPT_ERR_BIG_INT", reference: "interpreter.cpp:1819–1821; big_int.cpp:359–369", note: "" },
    Row { prefix: "OP_RSHIFTNUM shift count exceeds INT_MAX.", tssdk_line: "Spend.ts:1085", code: "SCRIPT_ERR_BIG_INT", reference: "interpreter.cpp:1819–1821; big_int.cpp:383–393", note: "" },
    Row { prefix: "Unlocking scripts can only contain push operations", tssdk_line: "Spend.ts:2062", code: "SCRIPT_ERR_SIG_PUSHONLY", reference: "interpreter.cpp:2321–2334", note: "under SIGPUSHONLY when explicit flags are given; in the default mode for version <= 1 only (`#shouldEnforceSigPushOnly`, 364–368)" },
    Row { prefix: "P2SH unlocking scripts can only contain push operations", tssdk_line: "Spend.ts:2073", code: "SCRIPT_ERR_SIG_PUSHONLY", reference: "interpreter.cpp:2385–2387", note: "" },
    Row { prefix: "P2SH evaluation requires a redeem script on the stack", tssdk_line: "Spend.ts:2085, 2089", code: "SCRIPT_ERR_EVAL_FALSE", reference: "interpreter.cpp:2389–2392 (an empty stack after the unlocking phase under P2SH)", note: "" },
    Row { prefix: "Every OP_IF, OP_NOTIF, or OP_ELSE must be terminated with OP_ENDIF", tssdk_line: "Spend.ts:759, 2266", code: "SCRIPT_ERR_UNBALANCED_CONDITIONAL", reference: "interpreter.cpp:1828–1830", note: "" },
    Row { prefix: "The clean stack rule requires exactly one item", tssdk_line: "Spend.ts:2103", code: "SCRIPT_ERR_CLEANSTACK", reference: "interpreter.cpp:2441–2445", note: "under CLEANSTACK when explicit flags are given; in the default mode for version <= 1 only (`#shouldEnforceCleanStack`, 370–374)" },
    Row { prefix: "The top stack element must be truthy after script evaluation", tssdk_line: "Spend.ts:2290, 2293", code: "SCRIPT_ERR_EVAL_FALSE", reference: "interpreter.cpp:2374–2378", note: "" },
    Row { prefix: "Missing opcode in ", tssdk_line: "Spend.ts:776", code: "SCRIPT_ERR_BAD_OPCODE", reference: "interpreter.cpp:450–451", note: "" },
    Row { prefix: "Malformed push data in ", tssdk_line: "Spend.ts:781", code: "SCRIPT_ERR_BAD_OPCODE", reference: "script.h:190–191 → interpreter.cpp:450–451", note: "" },
    Row { prefix: "Data push > ", tssdk_line: "Spend.ts:786", code: "SCRIPT_ERR_PUSH_SIZE", reference: "interpreter.cpp:455–458", note: "520 bytes for an explicit pre-Genesis coin; otherwise no finite element bound (`#maxPushSize`, 405–408)" },
    Row { prefix: "Script size exceeds ", tssdk_line: "Spend.ts:2259", code: "SCRIPT_ERR_SCRIPT_SIZE", reference: "interpreter.cpp:429–430", note: "pre-Genesis with explicit flags only" },
    Row { prefix: "Script executed more than ", tssdk_line: "Spend.ts:823", code: "SCRIPT_ERR_OP_COUNT", reference: "interpreter.cpp:466–467", note: "pre-Genesis with explicit flags only" },
    Row { prefix: "Stack item count has exceeded ", tssdk_line: "Spend.ts:946", code: "SCRIPT_ERR_STACK_SIZE", reference: "interpreter.cpp:1800–1803", note: "pre-Genesis with explicit flags only" },
    Row { prefix: "This data is not minimally-encoded", tssdk_line: "Spend.ts:809", code: "SCRIPT_ERR_MINIMALDATA", reference: "interpreter.cpp:474–479, 331–358", note: "under MINIMALDATA when explicit flags are given; in the default mode for version <= 1 only (`#shouldEnforceMinimalData`, 347–351)" },
    Row { prefix: "OP_IF and OP_NOTIF require at least one item on the stack", tssdk_line: "Spend.ts:1170", code: "SCRIPT_ERR_UNBALANCED_CONDITIONAL", reference: "interpreter.cpp:792–793", note: "" },
    Row { prefix: "OP_IF and OP_NOTIF require minimal truth values", tssdk_line: "Spend.ts:1179", code: "SCRIPT_ERR_MINIMALIF", reference: "interpreter.cpp:796–804", note: "" },
    Row { prefix: "OP_VERIF and OP_VERNOTIF require at least one item on the stack", tssdk_line: "Spend.ts:1148", code: "SCRIPT_ERR_UNBALANCED_CONDITIONAL", reference: "interpreter.cpp:783–785", note: "" },
    Row { prefix: "OP_ELSE may only be used once", tssdk_line: "Spend.ts:1198", code: "SCRIPT_ERR_UNBALANCED_CONDITIONAL", reference: "interpreter.cpp:829–831; conditional_tracker.cpp:51–55", note: "" },
    Row { prefix: "OP_ELSE requires a preceeding OP_IF", tssdk_line: "Spend.ts:1191", code: "SCRIPT_ERR_UNBALANCED_CONDITIONAL", reference: "interpreter.cpp:829–831", note: "" },
    Row { prefix: "OP_ENDIF requires a preceeding OP_IF", tssdk_line: "Spend.ts:1208", code: "SCRIPT_ERR_UNBALANCED_CONDITIONAL", reference: "interpreter.cpp:836–838", note: "" },
    Row { prefix: "OP_VERIFY requires the top stack value to be truthy", tssdk_line: "Spend.ts:1222", code: "SCRIPT_ERR_VERIFY", reference: "interpreter.cpp:849–851", note: "" },
    Row { prefix: "OP_VERIFY requires at least one item", tssdk_line: "Spend.ts:1217", code: "SCRIPT_ERR_INVALID_STACK_OPERATION", reference: "interpreter.cpp:844–846", note: "" },
    Row { prefix: "OP_RETURN is invalid before Genesis", tssdk_line: "Spend.ts:1229", code: "SCRIPT_ERR_OP_RETURN", reference: "interpreter.cpp:856–871", note: "" },
    Row { prefix: "OP_TOALTSTACK requires at oeast one item", tssdk_line: "Spend.ts:1243", code: "SCRIPT_ERR_INVALID_STACK_OPERATION", reference: "interpreter.cpp:876–878", note: "the SDK's own typo" },
    Row { prefix: "OP_FROMALTSTACK requires at least one item to be on the stack", tssdk_line: "Spend.ts:1249", code: "SCRIPT_ERR_INVALID_ALTSTACK_OPERATION", reference: "interpreter.cpp:884–886", note: "" },
    Row { prefix: "Attempted to pop from an empty alt stack", tssdk_line: "Spend.ts:514, 518", code: "SCRIPT_ERR_INVALID_ALTSTACK_OPERATION", reference: "interpreter.cpp:884–886", note: "" },
    Row { prefix: "OP_SPLIT requires the first stack item to be a non-negative number", tssdk_line: "Spend.ts:1916", code: "SCRIPT_ERR_INVALID_SPLIT_RANGE", reference: "interpreter.cpp:1723–1726", note: "" },
    Row { prefix: "OP_NUM2BIN requires that the size expressed in the top stack item is large enough", tssdk_line: "Spend.ts:1959", code: "SCRIPT_ERR_IMPOSSIBLE_ENCODING", reference: "interpreter.cpp:1760–1763", note: "" },
    Row { prefix: "It's not currently possible to push data larger than", tssdk_line: "Spend.ts:1901, 1938", code: "SCRIPT_ERR_PUSH_SIZE", reference: "interpreter.cpp:1749–1752, 1694–1697", note: "the finite element bound is 520 bytes for an explicit pre-Genesis coin; a negative size is refused, and OP_NUM2BIN has a separate int32 bound" },
    Row { prefix: "OP_BIN2NUM requires that the resulting number is valid", tssdk_line: "Spend.ts:1995", code: "SCRIPT_ERR_INVALID_NUMBER_RANGE", reference: "interpreter.cpp:1789–1790", note: "" },
    Row { prefix: "OP_EQUALVERIFY requires the top two stack items to be equal", tssdk_line: "Spend.ts:1487", code: "SCRIPT_ERR_EQUALVERIFY", reference: "interpreter.cpp:1209–1213", note: "" },
    Row { prefix: "OP_NUMEQUALVERIFY requires the top stack item to be truthy", tssdk_line: "Spend.ts:1619", code: "SCRIPT_ERR_NUMEQUALVERIFY", reference: "interpreter.cpp:1371–1373", note: "" },
    Row { prefix: "OP_DIV cannot divide by zero", tssdk_line: "Spend.ts:1584", code: "SCRIPT_ERR_DIV_BY_ZERO", reference: "interpreter.cpp:1316–1319", note: "" },
    Row { prefix: "OP_MOD cannot divide by zero", tssdk_line: "Spend.ts:1588", code: "SCRIPT_ERR_MOD_BY_ZERO", reference: "interpreter.cpp:1325–1328", note: "" },
    Row { prefix: "OP_CHECKSIGVERIFY requires that a valid signature is provided", tssdk_line: "Spend.ts:1722", code: "SCRIPT_ERR_CHECKSIGVERIFY", reference: "interpreter.cpp:1502–1507", note: "" },
    Row { prefix: "OP_CHECKMULTISIGVERIFY requires that a sufficient number", tssdk_line: "Spend.ts:1884", code: "SCRIPT_ERR_CHECKMULTISIGVERIFY", reference: "interpreter.cpp:1676–1681", note: "" },
    Row { prefix: "OP_SUBSTR offset (", tssdk_line: "Spend.ts:1006", code: "SCRIPT_ERR_INVALID_SPLIT_RANGE", reference: "interpreter.cpp:609–641", note: "" },
    Row { prefix: "OP_LEFT length (", tssdk_line: "Spend.ts:1023", code: "SCRIPT_ERR_INVALID_SPLIT_RANGE", reference: "interpreter.cpp:642–666", note: "" },
    Row { prefix: "OP_RIGHT length (", tssdk_line: "Spend.ts:1041", code: "SCRIPT_ERR_INVALID_SPLIT_RANGE", reference: "interpreter.cpp:667–691", note: "" },
    Row { prefix: "OP_LSHIFTNUM bits to shift must not be negative", tssdk_line: "Spend.ts:1056", code: "SCRIPT_ERR_INVALID_NUMBER_RANGE", reference: "interpreter.cpp:692–727", note: "" },
    Row { prefix: "OP_RSHIFTNUM bits to shift must not be negative", tssdk_line: "Spend.ts:1082", code: "SCRIPT_ERR_INVALID_NUMBER_RANGE", reference: "interpreter.cpp:728–764", note: "" },
    Row { prefix: "OP_CHECKSEQUENCEVERIFY requires a non-negative lock time", tssdk_line: "Spend.ts:917", code: "SCRIPT_ERR_NEGATIVE_LOCKTIME", reference: "interpreter.cpp:587–589", note: "" },
    Row { prefix: "OP_CHECKSEQUENCEVERIFY lock time is unsatisfied", tssdk_line: "Spend.ts:931", code: "SCRIPT_ERR_UNSATISFIED_LOCKTIME", reference: "interpreter.cpp:591–593, 2204–2250", note: "" },
    Row { prefix: "Invalid opcode ", tssdk_line: "Spend.ts:2004", code: "SCRIPT_ERR_BAD_OPCODE", reference: "interpreter.cpp:1795", note: "" },
    Row { prefix: "non-minimally encoded script number", tssdk_line: "Spend.ts:547; primitives/BigNumber.ts:1684", code: "SCRIPT_ERR_SCRIPTNUM_MINENCODE", reference: "script_num.cpp:67; interpreter.cpp:1811–1814", note: "" },
    Row { prefix: "script number overflow", tssdk_line: "Spend.ts:544, 1064, 1068; primitives/BigNumber.ts:1678", code: "SCRIPT_ERR_SCRIPTNUM_OVERFLOW", reference: "script_num.cpp:62; interpreter.cpp:1807–1810", note: "the pinned BigNumber.fromScriptNum and Spend number readers report this width refusal" },
    Row { prefix: "The signature format is invalid", tssdk_line: "Spend.ts:611, 624", code: "SCRIPT_ERR_SIG_DER", reference: "interpreter.cpp:275–280", note: "" },
    Row { prefix: "The signature hash type is invalid before Chronicle", tssdk_line: "Spend.ts:591", code: "SCRIPT_ERR_SIG_HASHTYPE", reference: "interpreter.cpp:298–301", note: "" },
    Row { prefix: "The signature hash type is invalid", tssdk_line: "Spend.ts:584", code: "SCRIPT_ERR_SIG_HASHTYPE", reference: "interpreter.cpp:298–301", note: "" },
    Row { prefix: "The signature must have a low S value", tssdk_line: "Spend.ts:619", code: "SCRIPT_ERR_SIG_HIGH_S", reference: "interpreter.cpp:282–288", note: "under LOW_S when explicit flags are given; in the default mode for version <= 1 only (`#shouldEnforceLowS`, 353–356)" },
    Row { prefix: "The signature must use SIGHASH_FORKID", tssdk_line: "Spend.ts:599", code: "SCRIPT_ERR_MUST_USE_FORKID", reference: "interpreter.cpp:304–306", note: "" },
    Row { prefix: "The signature must not use SIGHASH_FORKID", tssdk_line: "Spend.ts:602", code: "SCRIPT_ERR_ILLEGAL_FORKID", reference: "interpreter.cpp:308–310", note: "" },
    Row { prefix: "Public key is empty", tssdk_line: "Spend.ts:690", code: "SCRIPT_ERR_PUBKEYTYPE", reference: "interpreter.cpp:314–318", note: "" },
    Row { prefix: "The public key is too short", tssdk_line: "Spend.ts:694", code: "SCRIPT_ERR_PUBKEYTYPE", reference: "interpreter.cpp:314–318", note: "" },
    Row { prefix: "The non-compressed public key must be 65 bytes", tssdk_line: "Spend.ts:699", code: "SCRIPT_ERR_PUBKEYTYPE", reference: "interpreter.cpp:314–318", note: "" },
    Row { prefix: "The compressed public key must be 33 bytes", tssdk_line: "Spend.ts:704", code: "SCRIPT_ERR_PUBKEYTYPE", reference: "interpreter.cpp:314–318", note: "" },
    Row { prefix: "The public key is in an unknown format", tssdk_line: "Spend.ts:708, 714", code: "SCRIPT_ERR_PUBKEYTYPE", reference: "interpreter.cpp:314–318", note: "" },
    Row { prefix: "The selected script-verification backend rejected the spend", tssdk_line: "Spend.ts:2043", code: "SCRIPT_ERR_UNKNOWN_ERROR", reference: "(no reference site: an SDK backend hook)", note: "never expected: the runner uses the built-in evaluator" },
    Row { prefix: "Stack underflow accessing element", tssdk_line: "Spend.ts:482", code: "SCRIPT_ERR_INVALID_STACK_OPERATION", reference: "interpreter.cpp (the depth check of each opcode)", note: "" },
    Row { prefix: "Attempted to pop from an empty stack", tssdk_line: "Spend.ts:462, 466", code: "SCRIPT_ERR_INVALID_STACK_OPERATION", reference: "interpreter.cpp (the depth check of each opcode)", note: "" },
];

/// Rows whose sentence is an opcode name followed by a clause (`${OP[currentOpcode]} requires …`): matched on the clause.
pub const CLAUSES: &[Row] = &[
    Row { prefix: " is disabled until Chronicle", tssdk_line: "Spend.ts:802, 849, 857", code: "SCRIPT_ERR_DISABLED_OPCODE", reference: "interpreter.cpp:360–375, 470–471", note: "OP_2MUL/OP_2DIV, OP_VER/OP_VERIF/OP_VERNOTIF, the expansion opcodes before Chronicle" },
    Row { prefix: " is discouraged by verification flags", tssdk_line: "Spend.ts:839, 887", code: "SCRIPT_ERR_DISCOURAGE_UPGRADABLE_NOPS", reference: "interpreter.cpp:765–771", note: "" },
    Row { prefix: " requires the top stack element to be 0 or a positive number less than the current size of the stack", tssdk_line: "Spend.ts:1350", code: "SCRIPT_ERR_INVALID_STACK_OPERATION", reference: "interpreter.cpp:1018–1021", note: "OP_PICK/OP_ROLL" },
    Row { prefix: " requires the top item on the stack not to be negative", tssdk_line: "Spend.ts:1445", code: "SCRIPT_ERR_INVALID_NUMBER_RANGE", reference: "interpreter.cpp:1139–1141, 1170–1172", note: "OP_LSHIFT/OP_RSHIFT" },
    Row { prefix: " requires the top two stack items to be the same size", tssdk_line: "Spend.ts:1408", code: "SCRIPT_ERR_INVALID_OPERAND_SIZE", reference: "interpreter.cpp:1078–1080", note: "" },
    Row { prefix: " requires the extra stack item (dummy) to be empty", tssdk_line: "Spend.ts:1876", code: "SCRIPT_ERR_SIG_NULLDUMMY", reference: "interpreter.cpp:1664–1670", note: "under NULLDUMMY when explicit flags are given; in the default mode for version <= 1 only (`#shouldEnforceNullDummy`, 358–362)" },
    Row { prefix: " requires failing signatures to be empty", tssdk_line: "Spend.ts:1715, 1849", code: "SCRIPT_ERR_SIG_NULLFAIL", reference: "interpreter.cpp:1491–1497, 1641–1647", note: "under NULLFAIL with explicit flags only (`#hasFlag('NULLFAIL')` and `#enforceNonMalleability`, 1710–1711, 1844–1845): the default mode has no NULLFAIL" },
    Row { prefix: " requires at least 1 item for nKeys", tssdk_line: "Spend.ts:1735", code: "SCRIPT_ERR_INVALID_STACK_OPERATION", reference: "interpreter.cpp:1517–1519", note: "" },
    Row { prefix: " requires a key count between 0 and ", tssdk_line: "Spend.ts:1747", code: "SCRIPT_ERR_PUBKEY_COUNT", reference: "interpreter.cpp:1527–1531", note: "the SDK's bound is 2^31 − 1 (`maxMultisigKeyCount`, 30) or 20 pre-Genesis with explicit flags" },
    Row { prefix: " stack too small for nKeys and keys", tssdk_line: "Spend.ts:1757", code: "SCRIPT_ERR_INVALID_STACK_OPERATION", reference: "interpreter.cpp:1540–1542", note: "" },
    Row { prefix: " requires the number of signatures to be no greater than the number of keys", tssdk_line: "Spend.ts:1765", code: "SCRIPT_ERR_SIG_COUNT", reference: "interpreter.cpp:1555–1558", note: "" },
    Row { prefix: " stack too small for N, keys, M, sigs, and dummy", tssdk_line: "Spend.ts:1774", code: "SCRIPT_ERR_INVALID_STACK_OPERATION", reference: "interpreter.cpp:1561–1563, 1660–1662", note: "" },
    Row { prefix: " requires correct encoding for the public key and signature", tssdk_line: "Spend.ts:1672, 1813", code: "SCRIPT_ERR_SIG_DER", reference: "interpreter.cpp:1600–1610", note: "the multisig site folds the signature and key encoding refusals into one message; the reference reports SIG_DER/SIG_HIGH_S/SIG_HASHTYPE/PUBKEYTYPE per check" },
    Row { prefix: " requires at least ", tssdk_line: "Spend.ts:489 (#requireStackItems; call sites 912–1991)", code: "SCRIPT_ERR_INVALID_STACK_OPERATION", reference: "interpreter.cpp (the `stack.size() < n` check of each opcode)", note: "" },
];

/// The sentence of a ts-sdk error: the message without the SDK's `Script evaluation error: ` prefix and
/// without the context lines it appends.
pub fn sentence(message: &str) -> &str {
    let line = message.lines().next().unwrap_or("");
    line.strip_prefix("Script evaluation error: ")
        .unwrap_or(line)
}

/// The row for a ts-sdk message, or `None` when no row matches (the run reports it so the table grows).
pub fn code_of(message: &str) -> Option<&'static Row> {
    let s = sentence(message);
    if let Some(r) = TABLE.iter().find(|r| s.starts_with(r.prefix)) {
        return Some(r);
    }
    CLAUSES.iter().find(|r| s.contains(r.prefix))
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn the_seed_message_shapes_have_rows() {
        for m in [
            "Script evaluation error: The top stack element must be truthy after script evaluation.\nTXID: x, OutputIdx: 0\nContext: LockingScript, PC: 3",
            "This data is not minimally-encoded. (PC: 3)",
            "OP_2DUP requires at least two items to be on the stack.",
            "OP_PICK requires the top stack element to be 0 or a positive number less than the current size of the stack.",
            "script number overflow",
            "Unlocking scripts can only contain push operations, and no other opcodes.",
            "OP_CHECKMULTISIG requires the extra stack item (dummy) to be empty.",
            "OP_2MUL is disabled until Chronicle.",
            "OP_NOP1 is discouraged by verification flags.",
        ] {
            assert!(code_of(m).is_some(), "{m}");
        }
        assert!(code_of("a message the table does not know").is_none());
        assert_eq!(sentence("Script evaluation error: X.\nTXID: y"), "X.");
    }
}
