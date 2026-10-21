//! The go-sdk `errs.ErrorCode` → `SCRIPT_ERR_*` table (this repo's; #29, `docs/DESIGN.md` §6).
//!
//! go-sdk v1.7.2 (`docs/PROVENANCE.md` §1a) reports an enum, `errs.ErrorCode`
//! (`script/interpreter/errs/error.go:21–346`; `Error{ErrorCode, Description, Cause}` 442–467), whose vocabulary
//! is btcd's, not the reference's `ScriptError` (`src/script/script_error.h:12–87`). Some go-sdk codes
//! cover several reference codes (`ErrNumberTooBig`, `ErrNumberTooSmall`, `ErrMinimalData`,
//! `ErrIllegalForkID`, `ErrDivideByZero`, `ErrDiscourageUpgradableNOPs`), so a row may also match on the
//! message the raise site formats; the first matching row wins, in the order below (the message rows of a
//! code before its bare row). It is a CITED TABLE: every row names the go-sdk raise site(s) at the pin and
//! the reference's site; a vocabulary difference is a `note`, never a guess. Tier 1 (validity) never reads
//! this table; the code is compared as a note (`docs/DESIGN.md` §6). A code outside the table makes the
//! run RED so the table grows.
//!
//! The API-usage codes (`ErrInvalidParams`, `ErrInvalidIndex`, `ErrInternal`, `ErrInvalidProgramCounter`,
//! `ErrScriptUnfinished`, `ErrUnsupportedAddress`, `ErrNotMultisigScript`, `ErrTooManyRequiredSigs`,
//! `ErrTooMuchNullData`) are the adapter's or the engine's fault, never a script verdict. The adapter returns
//! every `errs.Error` as `invalid` under its code (`harness/engines/go/main.go`); `run_engine.rs`'s `side_of` turns
//! an `ADAPTER_CODES` code back into `undecided`, and `is_adapter_failure` (both drivers) skips it as an undecided run,
//! never a witness. `ADAPTER_CODES` also lists the adapter's own codes, split the same way: `panic` (a panic the
//! adapter recovered), `adapter` and the adapter's own `tx-decode` failures are undecided runs; `adapter-died` (the
//! process's death) and an SDK's decode refusal under `tx-decode` (`DECODE_REFUSALS`) are not adapter failures and
//! go on to the classifier as engine aborts under D15 (below).
//!
//! THE SDK'S DECODE REFUSAL (the owner's ruling R3 on #32, 2026-10-05: road 1, D15 as written). An SDK's own
//! transaction decoder refusing a corpus transaction is the ENGINE's, never the adapter's: when the spec decides the
//! entry it is an engine abort under D15 (a witness under its class, the engine's script status `undecided`, never an
//! undecided run as well). The adapters report it under the code `tx-decode`, which the go-sdk adapter also uses for
//! its own failures before the SDK is called; `DECODE_REFUSALS` names, per engine, the message that marks the SDK's
//! decoder, and `is_adapter_failure` is the one predicate both drivers (`run_engine.rs` live, `rules_check.rs` in
//! replay) read. The GoBDK shim's `tx-decode` (`harness/engines/gobdk/main.go`) is not an SDK's and stays the adapter's.

/// One row: the go-sdk code name, an optional message prefix that narrows it, the go-sdk raise site(s)
/// at v1.7.2, the reference's `SCRIPT_ERR_*` name, the reference's site, a note.
#[derive(Clone, Copy, Debug)]
pub struct Row {
    pub code: &'static str,
    pub message_prefix: Option<&'static str>,
    pub gosdk_line: &'static str,
    pub script_err: &'static str,
    pub reference: &'static str,
    pub note: &'static str,
}

pub const TABLE: &[Row] = &[
    Row { code: "ErrEvalFalse", message_prefix: None, gosdk_line: "thread.go:336, 395", script_err: "SCRIPT_ERR_EVAL_FALSE", reference: "interpreter.cpp:2374–2378", note: "" },
    Row { code: "ErrEmptyStack", message_prefix: None, gosdk_line: "thread.go:324", script_err: "SCRIPT_ERR_EVAL_FALSE", reference: "interpreter.cpp:2374–2378 (an empty final stack is the same refusal)", note: "" },
    Row { code: "ErrEarlyReturn", message_prefix: None, gosdk_line: "operations.go:581", script_err: "SCRIPT_ERR_OP_RETURN", reference: "interpreter.cpp:856–871 (pre-Genesis OP_RETURN)", note: "" },
    Row { code: "ErrScriptTooBig", message_prefix: None, gosdk_line: "thread.go:404, 412", script_err: "SCRIPT_ERR_SCRIPT_SIZE", reference: "interpreter.cpp:429–430", note: "" },
    Row { code: "ErrElementTooBig", message_prefix: None, gosdk_line: "thread.go:244, 271; operations.go:974 (OP_CAT)", script_err: "SCRIPT_ERR_PUSH_SIZE", reference: "interpreter.cpp:455–458, 1694–1697", note: "" },
    Row { code: "ErrTooManyOperations", message_prefix: None, gosdk_line: "thread.go:265; operations.go:2280 (the multisig key count)", script_err: "SCRIPT_ERR_OP_COUNT", reference: "interpreter.cpp:466–467, 1533–1537", note: "" },
    Row { code: "ErrStackOverflow", message_prefix: None, gosdk_line: "thread.go:678; stack.go:59–61", script_err: "SCRIPT_ERR_STACK_SIZE", reference: "interpreter.cpp:1800–1803, 1814–1817; limitedstack.cpp:194–207", note: "pre-Genesis element count or the post-Genesis combined memory budget; the SDK default is a policy limit" },
    Row { code: "ErrInvalidPubKeyCount", message_prefix: None, gosdk_line: "operations.go:2268, 2272", script_err: "SCRIPT_ERR_PUBKEY_COUNT", reference: "interpreter.cpp:1527–1531", note: "" },
    Row { code: "ErrInvalidSignatureCount", message_prefix: None, gosdk_line: "operations.go:2313, 2317", script_err: "SCRIPT_ERR_SIG_COUNT", reference: "interpreter.cpp:1555–1558", note: "" },
    // ErrNumberTooBig / ErrNumberTooSmall: one go-sdk code, several reference codes, by the raise site's message
    Row { code: "ErrNumberTooBig", message_prefix: Some("n is larger than length of array"), gosdk_line: "operations.go:1008 (OP_SPLIT)", script_err: "SCRIPT_ERR_INVALID_SPLIT_RANGE", reference: "interpreter.cpp:1723–1726", note: "" },
    Row { code: "ErrNumberTooSmall", message_prefix: Some("n is negative"), gosdk_line: "operations.go:1011 (OP_SPLIT)", script_err: "SCRIPT_ERR_INVALID_SPLIT_RANGE", reference: "interpreter.cpp:1723–1726", note: "" },
    Row { code: "ErrNumberTooBig", message_prefix: Some("n is larger than the max of"), gosdk_line: "operations.go:1052 (OP_NUM2BIN's size)", script_err: "SCRIPT_ERR_PUSH_SIZE", reference: "interpreter.cpp:1749–1752", note: "" },
    Row { code: "ErrNumberTooSmall", message_prefix: Some("cannot fit it into n sized array"), gosdk_line: "operations.go:1064 (OP_NUM2BIN)", script_err: "SCRIPT_ERR_IMPOSSIBLE_ENCODING", reference: "interpreter.cpp:1760–1763", note: "" },
    Row { code: "ErrNumberTooBig", message_prefix: Some("script numbers are limited to"), gosdk_line: "operations.go:1119 (OP_BIN2NUM)", script_err: "SCRIPT_ERR_INVALID_NUMBER_RANGE", reference: "interpreter.cpp:1789–1790", note: "" },
    Row { code: "ErrNumberTooBig", message_prefix: Some("numeric value encoded as"), gosdk_line: "number.go:107 (a number read over the era's width)", script_err: "SCRIPT_ERR_SCRIPTNUM_OVERFLOW", reference: "script_num.cpp:62; interpreter.cpp:1810–1813", note: "" },
    Row { code: "ErrNumberTooSmall", message_prefix: Some("n less than 0"), gosdk_line: "operations.go:1556, 1607 (OP_LSHIFT/OP_RSHIFT)", script_err: "SCRIPT_ERR_INVALID_NUMBER_RANGE", reference: "interpreter.cpp:1139–1141, 1170–1172", note: "" },
    Row { code: "ErrNumberTooBig", message_prefix: Some("OP_SUBSTR: invalid range"), gosdk_line: "operations.go:2641", script_err: "SCRIPT_ERR_INVALID_SPLIT_RANGE", reference: "interpreter.cpp:609–641 (the range checks of OP_SUBSTR)", note: "the reference's code at the OP_SUBSTR range sites is cited by the expansion family (#18)" },
    Row { code: "ErrNumberTooBig", message_prefix: Some("OP_LEFT: invalid length"), gosdk_line: "operations.go:2697", script_err: "SCRIPT_ERR_INVALID_SPLIT_RANGE", reference: "interpreter.cpp:642–666", note: "" },
    Row { code: "ErrNumberTooBig", message_prefix: Some("OP_RIGHT: invalid length"), gosdk_line: "operations.go:2697", script_err: "SCRIPT_ERR_INVALID_SPLIT_RANGE", reference: "interpreter.cpp:667–691", note: "" },
    Row { code: "ErrNumberTooSmall", message_prefix: Some("OP_LSHIFTNUM: negative shift"), gosdk_line: "operations.go:2751", script_err: "SCRIPT_ERR_INVALID_NUMBER_RANGE", reference: "interpreter.cpp:692–727", note: "" },
    Row { code: "ErrNumberTooSmall", message_prefix: Some("OP_RSHIFTNUM: negative shift"), gosdk_line: "operations.go:2751", script_err: "SCRIPT_ERR_INVALID_NUMBER_RANGE", reference: "interpreter.cpp:728–764", note: "" },
    Row { code: "ErrNumberTooBig", message_prefix: None, gosdk_line: "(any other site)", script_err: "SCRIPT_ERR_SCRIPTNUM_OVERFLOW", reference: "interpreter.cpp:1810–1813", note: "a bare ErrNumberTooBig outside the rows above: reported so the table grows" },
    Row { code: "ErrNumberTooSmall", message_prefix: None, gosdk_line: "(any other site)", script_err: "SCRIPT_ERR_INVALID_NUMBER_RANGE", reference: "interpreter.cpp (the negative-operand refusals)", note: "a bare ErrNumberTooSmall outside the rows above: reported so the table grows" },
    Row { code: "ErrDivideByZero", message_prefix: Some("mod by zero"), gosdk_line: "operations.go:1541", script_err: "SCRIPT_ERR_MOD_BY_ZERO", reference: "interpreter.cpp:1325–1328", note: "" },
    Row { code: "ErrDivideByZero", message_prefix: None, gosdk_line: "operations.go:1518", script_err: "SCRIPT_ERR_DIV_BY_ZERO", reference: "interpreter.cpp:1316–1319", note: "" },
    Row { code: "ErrVerify", message_prefix: None, gosdk_line: "operations.go:574", script_err: "SCRIPT_ERR_VERIFY", reference: "interpreter.cpp:849–851", note: "" },
    Row { code: "ErrEqualVerify", message_prefix: None, gosdk_line: "operations.go:1276", script_err: "SCRIPT_ERR_EQUALVERIFY", reference: "interpreter.cpp:1209–1213", note: "" },
    Row { code: "ErrNumEqualVerify", message_prefix: None, gosdk_line: "operations.go:1749", script_err: "SCRIPT_ERR_NUMEQUALVERIFY", reference: "interpreter.cpp:1371–1373", note: "" },
    Row { code: "ErrCheckSigVerify", message_prefix: None, gosdk_line: "operations.go:2189", script_err: "SCRIPT_ERR_CHECKSIGVERIFY", reference: "interpreter.cpp:1502–1507", note: "" },
    Row { code: "ErrCheckMultiSigVerify", message_prefix: None, gosdk_line: "operations.go:2504", script_err: "SCRIPT_ERR_CHECKMULTISIGVERIFY", reference: "interpreter.cpp:1676–1681", note: "" },
    Row { code: "ErrDisabledOpcode", message_prefix: None, gosdk_line: "thread.go:253; operations.go:332", script_err: "SCRIPT_ERR_DISABLED_OPCODE", reference: "interpreter.cpp:360–375, 470–471", note: "" },
    Row { code: "ErrReservedOpcode", message_prefix: None, gosdk_line: "thread.go:258; operations.go:338, 344", script_err: "SCRIPT_ERR_BAD_OPCODE", reference: "interpreter.cpp:1795 (the switch's default:), 470–471", note: "go-sdk names the reserved and the undefined opcodes under one code; the reference reports BAD_OPCODE for both" },
    Row { code: "ErrMalformedPush", message_prefix: None, gosdk_line: "opcodeparser.go:408–444", script_err: "SCRIPT_ERR_BAD_OPCODE", reference: "script.h:190–191 → interpreter.cpp:450–451", note: "" },
    Row { code: "ErrInvalidStackOperation", message_prefix: None, gosdk_line: "stack.go:229, 267, 322, 341, 363, 387, 410", script_err: "SCRIPT_ERR_INVALID_STACK_OPERATION", reference: "interpreter.cpp (the depth check of each opcode)", note: "go-sdk reports the alt stack's underflow under the same code; the reference's OP_FROMALTSTACK says INVALID_ALTSTACK_OPERATION (884–886): a tier-2 note" },
    Row { code: "ErrUnbalancedConditional", message_prefix: None, gosdk_line: "operations.go:505, 515, 542, 2564; thread.go:698", script_err: "SCRIPT_ERR_UNBALANCED_CONDITIONAL", reference: "interpreter.cpp:792–793, 829–831, 836–838, 1828–1830", note: "" },
    Row { code: "ErrInvalidInputLength", message_prefix: None, gosdk_line: "operations.go:1179, 1206, 1233 (OP_AND/OP_OR/OP_XOR)", script_err: "SCRIPT_ERR_INVALID_OPERAND_SIZE", reference: "interpreter.cpp:1078–1080", note: "" },
    Row { code: "ErrMinimalData", message_prefix: Some("numeric value encoded as"), gosdk_line: "number.go:555 (a number read under VerifyMinimalData)", script_err: "SCRIPT_ERR_SCRIPTNUM_MINENCODE", reference: "script_num.cpp:67; interpreter.cpp:1811–1814", note: "" },
    Row { code: "ErrMinimalData", message_prefix: None, gosdk_line: "opcodeparser.go:100–134 (the push forms)", script_err: "SCRIPT_ERR_MINIMALDATA", reference: "interpreter.cpp:474–479, 331–358", note: "" },
    Row { code: "ErrMinimalIf", message_prefix: None, gosdk_line: "operations.go:410, 413", script_err: "SCRIPT_ERR_MINIMALIF", reference: "interpreter.cpp:796–804", note: "" },
    Row { code: "ErrInvalidSigHashType", message_prefix: None, gosdk_line: "thread.go:783, 786, 798", script_err: "SCRIPT_ERR_SIG_HASHTYPE", reference: "interpreter.cpp:298–301", note: "" },
    Row { code: "ErrSigTooShort", message_prefix: None, gosdk_line: "thread.go:906", script_err: "SCRIPT_ERR_SIG_DER", reference: "interpreter.cpp:177–245 (IsValidSignatureEncoding), 275–280", note: "" },
    Row { code: "ErrSigTooLong", message_prefix: None, gosdk_line: "thread.go:909", script_err: "SCRIPT_ERR_SIG_DER", reference: "interpreter.cpp:177–245, 275–280", note: "" },
    Row { code: "ErrSigInvalidSeqID", message_prefix: None, gosdk_line: "thread.go:914", script_err: "SCRIPT_ERR_SIG_DER", reference: "interpreter.cpp:177–245, 275–280", note: "" },
    Row { code: "ErrSigInvalidDataLen", message_prefix: None, gosdk_line: "thread.go:921", script_err: "SCRIPT_ERR_SIG_DER", reference: "interpreter.cpp:177–245, 275–280", note: "" },
    Row { code: "ErrSigMissingSTypeID", message_prefix: None, gosdk_line: "thread.go:942", script_err: "SCRIPT_ERR_SIG_DER", reference: "interpreter.cpp:177–245, 275–280", note: "" },
    Row { code: "ErrSigMissingSLen", message_prefix: None, gosdk_line: "thread.go:945", script_err: "SCRIPT_ERR_SIG_DER", reference: "interpreter.cpp:177–245, 275–280", note: "" },
    Row { code: "ErrSigInvalidSLen", message_prefix: None, gosdk_line: "thread.go:955", script_err: "SCRIPT_ERR_SIG_DER", reference: "interpreter.cpp:177–245, 275–280", note: "" },
    Row { code: "ErrSigInvalidRIntID", message_prefix: None, gosdk_line: "thread.go:960", script_err: "SCRIPT_ERR_SIG_DER", reference: "interpreter.cpp:177–245, 275–280", note: "" },
    Row { code: "ErrSigZeroRLen", message_prefix: None, gosdk_line: "thread.go:966", script_err: "SCRIPT_ERR_SIG_DER", reference: "interpreter.cpp:177–245, 275–280", note: "" },
    Row { code: "ErrSigNegativeR", message_prefix: None, gosdk_line: "thread.go:971", script_err: "SCRIPT_ERR_SIG_DER", reference: "interpreter.cpp:177–245, 275–280", note: "" },
    Row { code: "ErrSigTooMuchRPadding", message_prefix: None, gosdk_line: "thread.go:977", script_err: "SCRIPT_ERR_SIG_DER", reference: "interpreter.cpp:177–245, 275–280", note: "" },
    Row { code: "ErrSigInvalidSIntID", message_prefix: None, gosdk_line: "thread.go:982", script_err: "SCRIPT_ERR_SIG_DER", reference: "interpreter.cpp:177–245, 275–280", note: "" },
    Row { code: "ErrSigZeroSLen", message_prefix: None, gosdk_line: "thread.go:988", script_err: "SCRIPT_ERR_SIG_DER", reference: "interpreter.cpp:177–245, 275–280", note: "" },
    Row { code: "ErrSigNegativeS", message_prefix: None, gosdk_line: "thread.go:993", script_err: "SCRIPT_ERR_SIG_DER", reference: "interpreter.cpp:177–245, 275–280", note: "" },
    Row { code: "ErrSigTooMuchSPadding", message_prefix: None, gosdk_line: "thread.go:999", script_err: "SCRIPT_ERR_SIG_DER", reference: "interpreter.cpp:177–245, 275–280", note: "" },
    Row { code: "ErrSigHighS", message_prefix: None, gosdk_line: "thread.go:1015", script_err: "SCRIPT_ERR_SIG_HIGH_S", reference: "interpreter.cpp:282–288", note: "" },
    Row { code: "ErrNotPushOnly", message_prefix: None, gosdk_line: "thread.go:577, 587", script_err: "SCRIPT_ERR_SIG_PUSHONLY", reference: "interpreter.cpp:2321–2334, 2385–2387", note: "" },
    Row { code: "ErrSigNullDummy", message_prefix: None, gosdk_line: "operations.go:2486", script_err: "SCRIPT_ERR_SIG_NULLDUMMY", reference: "interpreter.cpp:1664–1670", note: "" },
    Row { code: "ErrPubKeyType", message_prefix: None, gosdk_line: "thread.go:837", script_err: "SCRIPT_ERR_PUBKEYTYPE", reference: "interpreter.cpp:314–318", note: "" },
    Row { code: "ErrCleanStack", message_prefix: None, gosdk_line: "thread.go:328", script_err: "SCRIPT_ERR_CLEANSTACK", reference: "interpreter.cpp:2441–2445", note: "" },
    Row { code: "ErrNullFail", message_prefix: None, gosdk_line: "operations.go:2172, 2463", script_err: "SCRIPT_ERR_SIG_NULLFAIL", reference: "interpreter.cpp:1491–1497, 1641–1647", note: "" },
    Row { code: "ErrDiscourageUpgradableNOPs", message_prefix: None, gosdk_line: "operations.go:390, 623, 700, 2615, 2658, 2672, 2716, 2730", script_err: "SCRIPT_ERR_DISCOURAGE_UPGRADABLE_NOPS", reference: "interpreter.cpp:765–771, 522, 565, 613, 646, 671, 696, 732", note: "" },
    Row { code: "ErrNegativeLockTime", message_prefix: None, gosdk_line: "operations.go:651, 728", script_err: "SCRIPT_ERR_NEGATIVE_LOCKTIME", reference: "interpreter.cpp:552–554, 587–589", note: "" },
    Row { code: "ErrUnsatisfiedLockTime", message_prefix: None, gosdk_line: "operations.go:600, 605, 684, 750, 759", script_err: "SCRIPT_ERR_UNSATISFIED_LOCKTIME", reference: "interpreter.cpp:556–558, 591–593, 2166–2250", note: "" },
    Row { code: "ErrIllegalForkID", message_prefix: None, gosdk_line: "thread.go:809", script_err: "SCRIPT_ERR_ILLEGAL_FORKID", reference: "interpreter.cpp:308–310", note: "" },
    Row { code: "ErrMustUseForkID", message_prefix: None, gosdk_line: "thread.go:815", script_err: "SCRIPT_ERR_MUST_USE_FORKID", reference: "interpreter.cpp:305–306", note: "named code added in go-sdk v1.7.2" },
    Row { code: "ErrIllegalChronicle", message_prefix: None, gosdk_line: "thread.go:812", script_err: "SCRIPT_ERR_ILLEGAL_CHRONICLE", reference: "interpreter.cpp:302–303", note: "named code added in go-sdk v1.7.2" },
    Row { code: "ErrBigInt", message_prefix: None, gosdk_line: "operations.go:1466–1468, 2780", script_err: "SCRIPT_ERR_BIG_INT", reference: "interpreter.cpp:1819–1821", note: "named code added in go-sdk v1.7.2" },
    Row { code: "ErrInvalidFlags", message_prefix: None, gosdk_line: "thread.go:528, 549", script_err: "SCRIPT_ERR_INVALID_FLAGS", reference: "interpreter.cpp:2432–2435, 2259–2268 (valid_flags)", note: "" },
];

/// Codes that describe the adapter or the engine's API: the verdict is `undecided`.
/// A plain error returned by Execute is an SDK abort, classified by the data table (D15).
/// `tx-decode` is here for the adapters' own failures under that code; an SDK's decode refusal under it
/// (`DECODE_REFUSALS`) is not an adapter failure (R3 on #32), and neither is `adapter-died` (an abort, D15).
pub const ADAPTER_CODES: &[&str] = &[
    "ErrInvalidParams",
    "ErrInvalidIndex",
    "ErrInternal",
    "ErrInvalidProgramCounter",
    "ErrScriptUnfinished",
    "ErrUnsupportedAddress",
    "ErrNotMultisigScript",
    "ErrTooManyRequiredSigs",
    "ErrTooMuchNullData",
    "ErrExecutionCancelled",
    "panic",
    "tx-decode",
    "adapter",
    "adapter-died",
];

/// One SDK decode refusal: the engine's name (`go-sdk`, `ts-sdk`), the native prefix (`<code>: <message>`, as
/// `RunVerdict::native` and the recorded `reason` carry it) that marks the SDK's own decoder, and the site.
#[derive(Clone, Copy, Debug)]
pub struct DecodeRefusal {
    pub engine: &'static str,
    pub native_prefix: &'static str,
    pub site: &'static str,
}

/// The SDK decode refusals (R3 on #32, 2026-10-05). go-sdk's adapter prefixes the error of
/// `transaction.NewTransactionFromBytes` with `tx decode:` and its own hex and prevout failures otherwise
/// (`harness/engines/go/main.go`, `decodeTx`); the ts-sdk adapter reports under `tx-decode` only the throw of
/// @bsv/sdk's `Transaction.fromHex`, its own request checks under `adapter` (`harness/engines/ts/runner.mjs`).
pub const DECODE_REFUSALS: &[DecodeRefusal] = &[
    DecodeRefusal {
        engine: "go-sdk",
        native_prefix: "tx-decode: tx decode:",
        site: "harness/engines/go/main.go decodeTx (transaction.NewTransactionFromBytes)",
    },
    DecodeRefusal {
        engine: "ts-sdk",
        native_prefix: "tx-decode:",
        site: "harness/engines/ts/runner.mjs handle (Transaction.fromHex)",
    },
];

/// The SDK's own decoder refused the transaction (`engine` is the driver's engine name).
pub fn is_decode_refusal(engine: &str, native: &str) -> bool {
    DECODE_REFUSALS
        .iter()
        .any(|d| d.engine == engine && native.starts_with(d.native_prefix))
}

/// An undecided run that is the adapter's own failure (the harness's business: an undecided run, never a witness):
/// an adapter or API code, unless it is the adapter's death (the drivers' D15 path) or an SDK's decode refusal (R3).
pub fn is_adapter_failure(engine: &str, native: &str) -> bool {
    is_adapter_code(native.split(':').next().unwrap_or(""))
        && !native.starts_with("adapter-died")
        && !is_decode_refusal(engine, native)
}

/// The row for a go-sdk code and its message, or `None` when no row matches (the run reports it so the
/// table grows, never guesses).
pub fn code_of(code: &str, message: &str) -> Option<&'static Row> {
    TABLE
        .iter()
        .find(|r| r.code == code && r.message_prefix.is_none_or(|p| message.starts_with(p)))
}

pub fn is_adapter_code(code: &str) -> bool {
    ADAPTER_CODES.contains(&code)
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn the_message_rows_narrow_before_the_bare_rows() {
        assert_eq!(
            code_of("ErrNumberTooBig", "n is larger than length of array")
                .unwrap()
                .script_err,
            "SCRIPT_ERR_INVALID_SPLIT_RANGE"
        );
        assert_eq!(
            code_of("ErrNumberTooBig", "something new")
                .unwrap()
                .script_err,
            "SCRIPT_ERR_SCRIPTNUM_OVERFLOW"
        );
        assert_eq!(
            code_of(
                "ErrMinimalData",
                "numeric value encoded as 0100 is not minimally encoded"
            )
            .unwrap()
            .script_err,
            "SCRIPT_ERR_SCRIPTNUM_MINENCODE"
        );
        assert_eq!(
            code_of(
                "ErrMinimalData",
                "data push of 1 bytes encoded with opcode OP_PUSHDATA1 instead of OP_DATA_1"
            )
            .unwrap()
            .script_err,
            "SCRIPT_ERR_MINIMALDATA"
        );
        assert_eq!(
            code_of("ErrMustUseForkID", "fork id sighash not set with flag")
                .unwrap()
                .script_err,
            "SCRIPT_ERR_MUST_USE_FORKID"
        );
        assert_eq!(
            code_of("ErrDivideByZero", "mod by zero")
                .unwrap()
                .script_err,
            "SCRIPT_ERR_MOD_BY_ZERO"
        );
        assert_eq!(
            code_of("ErrBigInt", "shift amount is too large")
                .unwrap()
                .script_err,
            "SCRIPT_ERR_BIG_INT"
        );
        assert!(code_of("ErrSomethingNew", "").is_none());
        assert!(is_adapter_code("ErrInvalidParams"));
        assert!(!is_adapter_code("non-engine-error"));
    }
    #[test]
    fn the_sdk_decode_refusal_is_not_the_adapters_failure() {
        // R3 on #32: the SDK's decoder is the engine's; the adapter's own failures under the same code stay the adapter's
        assert!(is_decode_refusal(
            "ts-sdk",
            "tx-decode: Number can only safely store up to 53 bits"
        ));
        assert!(!is_adapter_failure(
            "ts-sdk",
            "tx-decode: Number can only safely store up to 53 bits"
        ));
        assert!(is_decode_refusal(
            "go-sdk",
            "tx-decode: tx decode: unexpected EOF"
        ));
        assert!(!is_decode_refusal(
            "go-sdk",
            "tx-decode: tx hex: encoding/hex: odd length hex string"
        ));
        assert!(is_adapter_failure(
            "go-sdk",
            "tx-decode: tx hex: encoding/hex: odd length hex string"
        ));
        assert!(is_adapter_failure(
            "go-sdk",
            "tx-decode: 2 inputs but 1 prevouts"
        ));
        assert!(is_adapter_failure(
            "gobdk",
            "tx-decode: tx hex: encoding/hex: odd length hex string"
        ));
        assert!(!is_decode_refusal("gobdk", "tx-decode: anything"));
        assert!(is_adapter_failure(
            "ts-sdk",
            "adapter: 2 inputs but 1 prevouts"
        ));
        assert!(!is_adapter_failure("ts-sdk", "adapter-died: signal 9"));
        assert!(!is_adapter_failure(
            "ts-sdk",
            "RangeError: Maximum BigInt size exceeded"
        ));
    }
}
