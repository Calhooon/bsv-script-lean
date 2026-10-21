//! The reference's `ScriptErrorString` table, reversed (this repo's; #27, `docs/DESIGN.md` §6).
//!
//! The `verifyscript` RPC (bitcoin-sv v1.2.2 `src/rpc/misc.cpp:509–917`) reports an invalid script as
//! `{"result": "error", "description": ScriptErrorString(err)}` (`:893–894`, `:907–910`): the description, not the
//! enum name. This table maps every description of `src/script/script_error.cpp:9–116` at the pin back to
//! its `ScriptError` name (`script_error.h:12–87`), so the node's tier-2 code is compared like every other
//! implementation's. It is a CITED TABLE (every row the `case` of `script_error.cpp`); a description outside
//! it (the `default:` "unknown error", or a future release's text) makes the run RED so the table grows.
//! The RPC's other results are `ok` (valid), `timeout` and `skipped` (`undecided`: the node did not judge
//! the script; `:880–885`, `:846–854`; `ok` at `:899`).

#[derive(Clone, Copy, Debug)]
pub struct Row {
    pub description: &'static str,
    pub code: &'static str,
    /// the `case` line in script_error.cpp at the pin
    pub line: &'static str,
}

pub const TABLE: &[Row] = &[
    Row {
        description: "No error",
        code: "SCRIPT_ERR_OK",
        line: "11",
    },
    Row {
        description:
            "Script evaluated without error but finished with a false/empty top stack element",
        code: "SCRIPT_ERR_EVAL_FALSE",
        line: "13",
    },
    Row {
        description: "Script failed an OP_VERIFY operation",
        code: "SCRIPT_ERR_VERIFY",
        line: "16",
    },
    Row {
        description: "Script failed an OP_EQUALVERIFY operation",
        code: "SCRIPT_ERR_EQUALVERIFY",
        line: "18",
    },
    Row {
        description: "Script failed an OP_CHECKMULTISIGVERIFY operation",
        code: "SCRIPT_ERR_CHECKMULTISIGVERIFY",
        line: "20",
    },
    Row {
        description: "Script failed an OP_CHECKSIGVERIFY operation",
        code: "SCRIPT_ERR_CHECKSIGVERIFY",
        line: "22",
    },
    Row {
        description: "Script failed an OP_NUMEQUALVERIFY operation",
        code: "SCRIPT_ERR_NUMEQUALVERIFY",
        line: "24",
    },
    Row {
        description: "Script is too big",
        code: "SCRIPT_ERR_SCRIPT_SIZE",
        line: "26",
    },
    Row {
        description: "Push value size limit exceeded",
        code: "SCRIPT_ERR_PUSH_SIZE",
        line: "28",
    },
    Row {
        description: "Operation limit exceeded",
        code: "SCRIPT_ERR_OP_COUNT",
        line: "30",
    },
    Row {
        description: "Stack size limit exceeded",
        code: "SCRIPT_ERR_STACK_SIZE",
        line: "32",
    },
    Row {
        description: "Signature count negative or greater than pubkey count",
        code: "SCRIPT_ERR_SIG_COUNT",
        line: "34",
    },
    Row {
        description: "Pubkey count negative or limit exceeded",
        code: "SCRIPT_ERR_PUBKEY_COUNT",
        line: "36",
    },
    Row {
        description: "Invalid operand size",
        code: "SCRIPT_ERR_INVALID_OPERAND_SIZE",
        line: "38",
    },
    Row {
        description: "Given operand is not a number within the valid range [-2^31...2^31]",
        code: "SCRIPT_ERR_INVALID_NUMBER_RANGE",
        line: "40",
    },
    Row {
        description: "The requested encoding is impossible to satisfy",
        code: "SCRIPT_ERR_IMPOSSIBLE_ENCODING",
        line: "43",
    },
    Row {
        description: "Invalid OP_SPLIT range",
        code: "SCRIPT_ERR_INVALID_SPLIT_RANGE",
        line: "45",
    },
    Row {
        description: "Script number overflow",
        code: "SCRIPT_ERR_SCRIPTNUM_OVERFLOW",
        line: "47",
    },
    Row {
        description: "Non-minimally encoded script number",
        code: "SCRIPT_ERR_SCRIPTNUM_MINENCODE",
        line: "49",
    },
    Row {
        description: "Opcode missing or not understood",
        code: "SCRIPT_ERR_BAD_OPCODE",
        line: "51",
    },
    Row {
        description: "Attempted to use a disabled opcode",
        code: "SCRIPT_ERR_DISABLED_OPCODE",
        line: "53",
    },
    Row {
        description: "Operation not valid with the current stack size",
        code: "SCRIPT_ERR_INVALID_STACK_OPERATION",
        line: "55",
    },
    Row {
        description: "Operation not valid with the current altstack size",
        code: "SCRIPT_ERR_INVALID_ALTSTACK_OPERATION",
        line: "57",
    },
    Row {
        description: "OP_RETURN was encountered",
        code: "SCRIPT_ERR_OP_RETURN",
        line: "59",
    },
    Row {
        description: "Invalid OP_IF construction",
        code: "SCRIPT_ERR_UNBALANCED_CONDITIONAL",
        line: "61",
    },
    Row {
        description: "Division by zero error",
        code: "SCRIPT_ERR_DIV_BY_ZERO",
        line: "63",
    },
    Row {
        description: "Modulo by zero error",
        code: "SCRIPT_ERR_MOD_BY_ZERO",
        line: "65",
    },
    Row {
        description: "Negative locktime",
        code: "SCRIPT_ERR_NEGATIVE_LOCKTIME",
        line: "67",
    },
    Row {
        description: "Locktime requirement not satisfied",
        code: "SCRIPT_ERR_UNSATISFIED_LOCKTIME",
        line: "69",
    },
    Row {
        description: "Signature hash type missing or not understood",
        code: "SCRIPT_ERR_SIG_HASHTYPE",
        line: "71",
    },
    Row {
        description: "Non-canonical DER signature",
        code: "SCRIPT_ERR_SIG_DER",
        line: "73",
    },
    Row {
        description: "Data push larger than necessary",
        code: "SCRIPT_ERR_MINIMALDATA",
        line: "75",
    },
    Row {
        description: "Only non-push operators allowed in signatures",
        code: "SCRIPT_ERR_SIG_PUSHONLY",
        line: "77",
    },
    Row {
        description: "Non-canonical signature: S value is unnecessarily high",
        code: "SCRIPT_ERR_SIG_HIGH_S",
        line: "79",
    },
    Row {
        description: "Dummy CHECKMULTISIG argument must be zero",
        code: "SCRIPT_ERR_SIG_NULLDUMMY",
        line: "81",
    },
    Row {
        description: "OP_IF/NOTIF argument must be minimal",
        code: "SCRIPT_ERR_MINIMALIF",
        line: "83",
    },
    Row {
        description: "Signature must be zero for failed CHECK(MULTI)SIG operation",
        code: "SCRIPT_ERR_SIG_NULLFAIL",
        line: "85",
    },
    Row {
        description: "NOPx reserved for soft-fork upgrades",
        code: "SCRIPT_ERR_DISCOURAGE_UPGRADABLE_NOPS",
        line: "88",
    },
    Row {
        description: "Public key is neither compressed or uncompressed",
        code: "SCRIPT_ERR_PUBKEYTYPE",
        line: "90",
    },
    Row {
        description: "Script did not clean its stack",
        code: "SCRIPT_ERR_CLEANSTACK",
        line: "92",
    },
    Row {
        description: "Using non-compressed public key",
        code: "SCRIPT_ERR_NONCOMPRESSED_PUBKEY",
        line: "94",
    },
    Row {
        description: "Illegal use of SIGHASH_FORKID",
        code: "SCRIPT_ERR_ILLEGAL_FORKID",
        line: "96",
    },
    Row {
        description: "Signature must use SIGHASH_FORKID",
        code: "SCRIPT_ERR_MUST_USE_FORKID",
        line: "98",
    },
    Row {
        description: "Illegal use of SIGHASH_CHRONICLE",
        code: "SCRIPT_ERR_ILLEGAL_CHRONICLE",
        line: "100",
    },
    Row {
        description: "Big integer OpenSSL error",
        code: "SCRIPT_ERR_BIG_INT",
        line: "102",
    },
    Row {
        description: "Invalid script verification flag combination",
        code: "SCRIPT_ERR_INVALID_FLAGS",
        line: "104",
    },
];

/// The `ScriptError` name for a `verifyscript` description, or `None` (the run reports it so the table grows).
pub fn code_of(description: &str) -> Option<&'static Row> {
    TABLE.iter().find(|r| r.description == description)
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn the_descriptions_are_exact() {
        assert_eq!(
            code_of("Script did not clean its stack").unwrap().code,
            "SCRIPT_ERR_CLEANSTACK"
        );
        assert_eq!(
            code_of(
                "Script evaluated without error but finished with a false/empty top stack element"
            )
            .unwrap()
            .code,
            "SCRIPT_ERR_EVAL_FALSE"
        );
        assert!(code_of("unknown error").is_none());
        // no name appears twice in TABLE (uniqueness only: completeness against script_error.h is not checked here)
        let mut names: Vec<&str> = TABLE.iter().map(|r| r.code).collect();
        names.sort();
        names.dedup();
        assert_eq!(names.len(), TABLE.len());
    }
    #[test]
    fn the_tx_reasons_unwrap_and_split() {
        // #32 P6: the grace-window wrappers, the bare blk-bad-inputs and the bad-version form (validation.cpp at the pin)
        assert_eq!(
            tx_reason_code("genesis-script-verify-flag-failed (Script did not clean its stack)")
                .as_deref(),
            Some("SCRIPT_ERR_CLEANSTACK")
        );
        assert_eq!(
            tx_reason_code("chronicle-script-verify-flag-failed (Script did not clean its stack)")
                .as_deref(),
            Some("SCRIPT_ERR_CLEANSTACK")
        );
        assert_eq!(
            tx_reason_code("chronicle-script-verify-flag-failed (no such error)"),
            None
        );
        assert_eq!(
            tx_reason_code("blk-bad-inputs (Script did not clean its stack)").as_deref(),
            Some("SCRIPT_ERR_CLEANSTACK")
        );
        assert_eq!(
            tx_reason_code("blk-bad-inputs").as_deref(),
            Some("blk-bad-inputs")
        );
        assert_eq!(
            tx_reason_code("bad-version(0x00000001)").as_deref(),
            Some("bad-version")
        );
        assert_eq!(
            tx_reason_code("bad-txns-nonfinal").as_deref(),
            Some("bad-txns-nonfinal")
        );
        assert_eq!(tx_reason_code("something-new"), None);
    }
}

// ---------------------------------------------------------------------------------------------------------------------
// THE TRANSACTION-LEVEL REASONS (the block road, #27 D97; S3, set 4, 2026-09-26): the `REJECT_INVALID` reason strings of
// `src/validation.cpp` at the pin that a `submitblock` (`BIP22ValidationResult`, `rpc/mining.cpp:348–354`) or a
// `sendrawtransaction` refusal (`rpc/rawtransaction.cpp:1642–1644`, `"<code>: <reason>"`) can carry for a transaction or
// its block; each row's `line` is the string's first occurrence in validation.cpp at 879fc8b42 (a grep, 2026-09-26).
// The reason IS the code (the node's own word is what the spec's `TxRules` gate names, `Bsvs.Run.rejectCode`). The
// script-carrying reasons `blk-bad-inputs (…)`, `mandatory-script-verify-flag-failed (…)`, `non-mandatory-script-verify-flag (…)`,
// the two grace-window reasons `genesis-script-verify-flag-failed (…)` and `chronicle-script-verify-flag-failed (…)`, and the
// two policy reasons below carry `ScriptErrorString(err)` in their parentheses (validation.cpp:3431, 3706, :2834, :2766,
// :2789, :2813, :2761, :2823) and map through TABLE above; a block can also be refused with the BARE `blk-bad-inputs`
// (validation.cpp:3714, the parallel check's failure, no script error in the reason), which maps as the reason itself.
// `bad-version(0x%08x)` (validation.cpp:5923) carries the block's version with no space before its parenthesis.
// A reason outside this table, or a wrapped script error outside TABLE, is RED (the table grows, never guesses).

#[derive(Clone, Copy, Debug)]
pub struct TxRow {
    pub reason: &'static str,
    /// the first line carrying the string in validation.cpp at the pin
    pub line: &'static str,
}

pub const TX_TABLE: &[TxRow] = &[
    TxRow {
        reason: "bad-txns-vin-empty",
        line: "528",
    },
    TxRow {
        reason: "bad-txns-vout-empty",
        line: "532",
    },
    TxRow {
        reason: "bad-txns-oversize",
        line: "537",
    },
    TxRow {
        reason: "bad-txns-vout-negative",
        line: "545",
    },
    TxRow {
        reason: "bad-txns-vout-toolarge",
        line: "550",
    },
    TxRow {
        reason: "bad-txns-txouttotal-toolarge",
        line: "556",
    },
    TxRow {
        reason: "bad-txn-sigops",
        line: "565",
    },
    TxRow {
        reason: "bad-cb-missing",
        line: "579",
    },
    TxRow {
        reason: "bad-cb-length",
        line: "589",
    },
    TxRow {
        reason: "bad-tx-coinbase",
        line: "602",
    },
    TxRow {
        reason: "bad-txns-vout-p2sh",
        line: "621",
    },
    TxRow {
        reason: "bad-txns-prevout-null",
        line: "630",
    },
    TxRow {
        reason: "bad-txns-inputs-duplicate",
        line: "635",
    },
    TxRow {
        reason: "bad-txns-nonfinal",
        line: "3348",
    },
    TxRow {
        reason: "bad-txns-too-many-sigops",
        line: "1245",
    },
    TxRow {
        reason: "non-BIP68-final",
        line: "1203",
    },
    // D123 (2026-09-27): the policy instance at the node's default (requireStandard true) refuses by standardness.
    // IsStandardTx's reasons (script/standard.cpp:427–500) are refused at validation.cpp:1087 under the conditions of
    // 1082–1089; AreInputsStandard's at 1222 (run when non-standard outputs are not accepted: before Genesis under
    // requireStandard, configscriptpolicy.cpp:468–471). The line names validation.cpp's, then where the string is set.
    TxRow {
        reason: "version",
        line: "1087 (script/standard.cpp:436)",
    },
    TxRow {
        reason: "tx-size",
        line: "1087 (script/standard.cpp:447)",
    },
    TxRow {
        reason: "scriptsig-size",
        line: "1087 (script/standard.cpp:459)",
    },
    TxRow {
        reason: "scriptsig-not-pushonly",
        line: "1087 (script/standard.cpp:463)",
    },
    TxRow {
        reason: "bare-multisig",
        line: "1087 (script/standard.cpp:479)",
    },
    TxRow {
        reason: "dust",
        line: "1087 (script/standard.cpp:482)",
    },
    TxRow {
        reason: "datacarrier-size-exceeded",
        line: "1087 (script/standard.cpp:489)",
    },
    TxRow {
        reason: "scriptpubkey",
        line: "1087 (script/standard.cpp:495)",
    },
    TxRow {
        reason: "bad-txns-nonstandard-inputs",
        line: "1222",
    },
    TxRow {
        reason: "bad-txns-inputs-missingorspent",
        line: "3331",
    },
    TxRow {
        reason: "bad-txns-premature-spend-of-coinbase",
        line: "2622",
    },
    TxRow {
        reason: "bad-txns-inputvalues-outofrange",
        line: "2643",
    },
    TxRow {
        reason: "bad-txns-in-belowout",
        line: "2648",
    },
    TxRow {
        reason: "bad-txns-fee-outofrange",
        line: "2661",
    },
    TxRow {
        reason: "bad-cb-amount",
        line: "3662",
    },
    TxRow {
        reason: "bad-txns-duplicate",
        line: "5735",
    },
    TxRow {
        reason: "bad-txns-BIP30",
        line: "3110",
    },
    TxRow {
        reason: "bad-blk-length",
        line: "5759",
    },
    TxRow {
        reason: "bad-txnmrklroot",
        line: "5728",
    },
    TxRow {
        reason: "bad-blk-sigops",
        line: "3366",
    },
    TxRow {
        reason: "time-too-old",
        line: "5905",
    },
    TxRow {
        reason: "time-too-new",
        line: "5911",
    },
    TxRow {
        reason: "bad-diffbits",
        line: "5899",
    },
    TxRow {
        reason: "bad-prevblk",
        line: "6070",
    },
    TxRow {
        reason: "high-hash",
        line: "5701",
    },
    TxRow {
        reason: "bad-version",
        line: "5923",
    },
    TxRow {
        reason: "blk-bad-inputs",
        line: "3431",
    },
    TxRow {
        reason: "mandatory-script-verify-flag-failed",
        line: "2834",
    },
    TxRow {
        reason: "non-mandatory-script-verify-flag",
        line: "2766",
    },
    // the mempool's grace-window refusals (a spend inside Genesis's or Chronicle's grace window that the inverse era's
    // flags would accept, 2770–2815): REJECT_NONSTANDARD, the script error in the parentheses
    TxRow {
        reason: "genesis-script-verify-flag-failed",
        line: "2789",
    },
    TxRow {
        reason: "chronicle-script-verify-flag-failed",
        line: "2813",
    },
    TxRow {
        reason: "bad-txns-inputs-too-large",
        line: "1176",
    },
    // the mempool's two script refusals that wrap a script error of their own (2026-09-28, package B): a script that
    // passes the consensus flags and fails the policy flags with SCRIPT_ERR_SCRIPTNUM_OVERFLOW (2757–2761), and
    // SCRIPT_ERR_BIG_INT, the big-number library's overflow (2818–2824)
    TxRow {
        reason: "max-script-num-length-policy-limit-violated",
        line: "2761",
    },
    TxRow {
        reason: "max-script-num-overflow",
        line: "2823",
    },
];

/// A transaction-level verdict of the node: the reason as the code, or the script error a script-carrying reason
/// wraps. `None` = outside both tables.
pub fn tx_reason_code(reason: &str) -> Option<String> {
    let reason = reason.trim();
    for wrap in [
        "blk-bad-inputs (",
        "mandatory-script-verify-flag-failed (",
        "non-mandatory-script-verify-flag (",
        "genesis-script-verify-flag-failed (",
        "chronicle-script-verify-flag-failed (",
        "max-script-num-length-policy-limit-violated (",
        "max-script-num-overflow (",
    ] {
        if let Some(inner) = reason.strip_prefix(wrap) {
            let inner = inner.strip_suffix(')').unwrap_or(inner);
            return code_of(inner).map(|r| r.code.to_string());
        }
    }
    // the Genesis grace period's prefix on a mempool rejection (validation.cpp:1049, :1389: `"flexible-" + the reason`):
    // the verdict is a refusal either way; the reason beneath is the code
    let reason = reason.strip_prefix("flexible-").unwrap_or(reason);
    // the reason before its parenthesis: `name (detail)`, or `bad-version(0x…)` with no space (validation.cpp:5923)
    let bare = reason.split('(').next().unwrap_or(reason).trim_end();
    TX_TABLE
        .iter()
        .find(|r| r.reason == bare)
        .map(|r| r.reason.to_string())
}

/// The reason of a `sendrawtransaction` refusal: the node's message `"<code>: <reason>"` (`rawtransaction.cpp:1643`).
pub fn mempool_reason(message: &str) -> &str {
    match message.split_once(": ") {
        Some((code, rest)) if code.chars().all(|c| c.is_ascii_digit()) => rest,
        _ => message,
    }
}
