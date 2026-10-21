//! The bsv-rs message → `SCRIPT_ERR_*` table (this repo's; #15, `docs/DESIGN.md` §6;
//! re-cited at bsv-rs 0.4.4 on 2026-10-12 (S3, lane bump-044).
//! Source locations moved; the message prefixes and mapped codes are unchanged.
//!
//! bsv-rs reports no error enum: `ScriptEvaluationError.message` is a sentence
//! (`src/script/spend.rs`, every `self.error(...)` site; the resource errors
//! carry `resource_limit`, `evaluation_error.rs`, and are `undecided`, never
//! mapped). The corpus's tier-2 `code` is the reference's `ScriptError` name at
//! the pin (`src/script/script_error.h:12–87`), so this table maps each bsv-rs
//! message to the code the reference reports for the same condition, citing the
//! bsv-rs line the message is raised at (`spend.rs` at 0.4.4, the crates.io copy of
//! commit `5c15528` by its `.cargo_vcs_info.json`, 4,322 lines; 0.3.30's = tag `v0.3.30`, `c7ff2c3`, 3,995 lines) and the reference's site. It
//! is a CITED TABLE: a divergence in the table (bsv-rs raising a message whose
//! condition the reference reports under another code) is itself a finding,
//! recorded in the `note` of the row. Tier 1 (validity) is never affected by this
//! table (`docs/DESIGN.md` §6: the code is compared as a note).
//!
//! Since 0.3.26 the engine runs under the node's flag word (`Spend::set_flags`,
//! `spend.rs:471–494` at 0.4.4): MINIMALDATA, LOW_S, CLEANSTACK, NULLDUMMY, NULLFAIL,
//! MINIMALIF, SIGPUSHONLY, DISCOURAGE_UPGRADABLE_NOPS and COMPRESSED_PUBKEYTYPE
//! are the word's rules under the reference's version gate (`flags.rs`, the
//! table on `ScriptFlags`); the notes below say "under the word" where the
//! 0.3.24 note said "gated on version ≤ 1 (spend.rs:240–242)". The four
//! messages of 0.3.26 (NULLFAIL, MINIMALIF, the discouraged NOPs, an invalid
//! word) and the messages of 0.3.27's five consensus fixes (the truncated push,
//! the single `OP_ELSE`, the Chronicle-disabled version opcodes, the number
//! shifts' counts, the `OP_SUBSTR` family's ranges) have their rows; 0.3.28 adds the
//! `Script number overflow` row (the reference's number-length limit under a word,
//! `SCRIPT_ERR_SCRIPTNUM_OVERFLOW`) and closes the s = n note of the low-S row (an `r`
//! or `s` at or above the curve order is the zero signature for the check, as the
//! reference's lax parse makes it). 0.3.29 adds three rows (an undefined base hash type,
//! `SCRIPT_ERR_SIG_HASHTYPE`; SIGHASH_CHRONICLE before Chronicle, `SCRIPT_ERR_ILLEGAL_CHRONICLE`;
//! a shift count that does not fit an int, `SCRIPT_ERR_BIG_INT`) and the left shift's size test
//! to the `Script number overflow` row (bsv-rs#21, #22, #23). 0.3.30 adds two (the node's stack memory
//! policy under a word, `SCRIPT_ERR_STACK_SIZE`; `OP_NUM2BIN`'s size operand bounded by `INT32_MAX`,
//! `SCRIPT_ERR_PUSH_SIZE`) (bsv-rs#30). 0.3.33 adds no prefix: checked splice conversion uses the existing number-overflow row.
//!
//! Matching is by prefix on the message with its `{}` holes removed (the
//! messages are `format!` strings); the first matching row wins, in the order
//! below (the more specific prefixes first); the `CLAUSES` are matched on a
//! substring when the message starts with an opcode name.

/// One row: the bsv-rs message prefix (up to the first `{}`), the bsv-rs line
/// at 0.4.4, the reference's `SCRIPT_ERR_*` name, the reference's site, a note.
#[derive(Clone, Copy, Debug)]
pub struct Row {
    pub prefix: &'static str,
    pub bsvrs_line: &'static str,
    pub code: &'static str,
    pub reference: &'static str,
    pub note: &'static str,
}

pub const TABLE: &[Row] = &[
    Row { prefix: "Invalid verification flags: ", bsvrs_line: "spend.rs:614 (ScriptFlags::check, flags.rs)", code: "SCRIPT_ERR_INVALID_FLAGS", reference: "interpreter.cpp:2312–2313, 2432–2435", note: "a word the crate cannot honor (no SIGHASH_FORKID, no GENESIS, no UTXO_AFTER_GENESIS: rules it does not implement) or one the reference refuses (CHRONICLE without GENESIS, UTXO_AFTER_CHRONICLE without UTXO_AFTER_GENESIS, CLEANSTACK without P2SH); the first two are the crate's own scope, not the reference's error" },
    Row { prefix: "Unlocking scripts can only contain push operations", bsvrs_line: "spend.rs:620", code: "SCRIPT_ERR_SIG_PUSHONLY", reference: "interpreter.cpp:2321–2334", note: "under the word: SIGPUSHONLY with Genesis-without-Chronicle, or Chronicle with version <= 1 (flags.rs, the table on ScriptFlags); the default mode requires push-only regardless of version (spend.rs:288, REQUIRE_PUSH_ONLY_UNLOCKING)" },
    Row { prefix: "Every OP_IF, OP_NOTIF, or OP_ELSE must be terminated with OP_ENDIF", bsvrs_line: "spend.rs:637, 695", code: "SCRIPT_ERR_UNBALANCED_CONDITIONAL", reference: "interpreter.cpp:1828–1830", note: "" },
    Row { prefix: "The clean stack rule requires exactly one item", bsvrs_line: "spend.rs:644", code: "SCRIPT_ERR_CLEANSTACK", reference: "interpreter.cpp:2441–2445", note: "under the word: CLEANSTACK and the version gate (a standard-only bit, never in a block word); the default mode gates it on version <= 1 (spend.rs:296)" },
    Row { prefix: "The top stack element must be truthy after script evaluation", bsvrs_line: "spend.rs:652, 658", code: "SCRIPT_ERR_EVAL_FALSE", reference: "interpreter.cpp:2374–2378", note: "" },
    Row { prefix: "A push declares more bytes than the script holds", bsvrs_line: "spend.rs:736 (Script::truncated_push, script.rs)", code: "SCRIPT_ERR_BAD_OPCODE", reference: "script.h:190–191 (GetOp2 returns false) → interpreter.cpp:450–451", note: "0.3.27 (bsv-rs#12): refused where the walk reaches it, executed or not, as the reference; Script::from_binary stays lenient as a container" },
    Row { prefix: "Data push > ", bsvrs_line: "spend.rs:745", code: "SCRIPT_ERR_PUSH_SIZE", reference: "interpreter.cpp:455–456", note: "bsv-rs's 1 GiB element limit (spend.rs:90, MAX_SCRIPT_ELEMENT_SIZE) is not the reference's pre-Genesis 520-byte rule nor its post-Genesis memory budget: reachable only above 1 GiB" },
    Row { prefix: "This opcode is currently disabled", bsvrs_line: "spend.rs:757", code: "SCRIPT_ERR_DISABLED_OPCODE", reference: "interpreter.cpp:360–375, 470–471", note: "OP_2MUL/OP_2DIV for a UTXO the word or the default mode takes as pre-Chronicle (0.3.27 executes them under UTXO_AFTER_CHRONICLE, 1247–1254)" },
    Row { prefix: "This data is not minimally-encoded", bsvrs_line: "spend.rs:768", code: "SCRIPT_ERR_MINIMALDATA", reference: "interpreter.cpp:474–479, 331–358", note: "under the word: MINIMALDATA and the version gate (a standard-only bit); the default mode gates it on version <= 1 (spend.rs:294)" },
    Row { prefix: "OP_VER is disabled until Chronicle", bsvrs_line: "spend.rs:852", code: "SCRIPT_ERR_BAD_OPCODE", reference: "interpreter.cpp:598–608", note: "0.3.27: for a UTXO taken as pre-Chronicle; under UTXO_AFTER_CHRONICLE OP_VER pushes the version" },
    Row { prefix: "OP_IF and OP_NOTIF require at least one item on the stack", bsvrs_line: "spend.rs:864", code: "SCRIPT_ERR_UNBALANCED_CONDITIONAL", reference: "interpreter.cpp:792–793", note: "" },
    Row { prefix: "OP_IF and OP_NOTIF require minimal truth values", bsvrs_line: "spend.rs:872", code: "SCRIPT_ERR_MINIMALIF", reference: "interpreter.cpp:796–804", note: "0.3.26: under the word's MINIMALIF and the version gate (never set by a node at the pin)" },
    Row { prefix: "OP_VERIF and OP_VERNOTIF require at least one item on the stack", bsvrs_line: "spend.rs:901", code: "SCRIPT_ERR_UNBALANCED_CONDITIONAL", reference: "interpreter.cpp:792–793", note: "0.3.27: the Chronicle conditionals under UTXO_AFTER_CHRONICLE" },
    Row { prefix: "OP_ELSE may only be used once", bsvrs_line: "spend.rs:923", code: "SCRIPT_ERR_UNBALANCED_CONDITIONAL", reference: "conditional_tracker.cpp:51–55; interpreter.cpp:829–831", note: "0.3.27 (bsv-rs#12): a second OP_ELSE for one OP_IF is unbalanced post-Genesis (every UTXO here)" },
    Row { prefix: "OP_ELSE requires a preceeding OP_IF", bsvrs_line: "spend.rs:918", code: "SCRIPT_ERR_UNBALANCED_CONDITIONAL", reference: "interpreter.cpp:829–831", note: "" },
    Row { prefix: "OP_ENDIF requires a preceeding OP_IF", bsvrs_line: "spend.rs:935", code: "SCRIPT_ERR_UNBALANCED_CONDITIONAL", reference: "interpreter.cpp:836–838", note: "" },
    Row { prefix: "OP_VERIFY requires the top stack value to be truthy", bsvrs_line: "spend.rs:948", code: "SCRIPT_ERR_VERIFY", reference: "interpreter.cpp:849–851", note: "" },
    Row { prefix: "OP_VERIFY requires at least one item", bsvrs_line: "spend.rs:943", code: "SCRIPT_ERR_INVALID_STACK_OPERATION", reference: "interpreter.cpp:844–846", note: "" },
    Row { prefix: "OP_FROMALTSTACK requires at least one item to be on the alt stack", bsvrs_line: "spend.rs:986", code: "SCRIPT_ERR_INVALID_ALTSTACK_OPERATION", reference: "interpreter.cpp:884–886", note: "" },
    Row { prefix: "Attempted to pop from an empty alt stack", bsvrs_line: "spend.rs:2405", code: "SCRIPT_ERR_INVALID_ALTSTACK_OPERATION", reference: "interpreter.cpp:884–886", note: "" },
    Row { prefix: "OP_SPLIT requires the first stack item to be a non-negative number", bsvrs_line: "spend.rs:2288", code: "SCRIPT_ERR_INVALID_SPLIT_RANGE", reference: "interpreter.cpp:1718–1719", note: "" },
    Row { prefix: "OP_NUM2BIN requires that the size expressed in the top stack item is large enough", bsvrs_line: "spend.rs:1287", code: "SCRIPT_ERR_IMPOSSIBLE_ENCODING", reference: "interpreter.cpp:1760–1763", note: "" },
    Row { prefix: "OP_NUM2BIN requires a size from 0 to 2147483647, found ", bsvrs_line: "spend.rs:1256–1260", code: "SCRIPT_ERR_PUSH_SIZE", reference: "interpreter.cpp:1748–1749", note: "0.3.30 (bsv-rs#30): the size operand refused outside 0 to INT32_MAX, as the reference refuses it; an element after Genesis is otherwise bounded by the stack memory budget alone" },
    Row { prefix: "Stack size limit exceeded: ", bsvrs_line: "spend.rs:2467–2471", code: "SCRIPT_ERR_STACK_SIZE", reference: "limitedstack.cpp:202–205 (the combined size over both stacks, 32 bytes per element, limitedstack.h:43), interpreter.cpp:1815–1817", note: "0.3.30 (bsv-rs#30): under a word the stack memory policy is the node's (maxstackmemoryusagepolicy, policy.h:153 by default), charged before the growth; above the crate's local budget it is a resource limit, never a verdict" },
    Row { prefix: "It's not currently possible to push data larger than", bsvrs_line: "spend.rs:1216, 1265", code: "SCRIPT_ERR_PUSH_SIZE", reference: "interpreter.cpp:1748–1749 (OP_NUM2BIN's size operand), 1698–1701 (OP_CAT pre-Genesis)", note: "bsv-rs's bound is its 1 GiB element limit; the reference's OP_NUM2BIN refuses a negative size or one above INT32_MAX with PUSH_SIZE and OP_CAT only pre-Genesis at 520 bytes" },
    Row { prefix: "OP_BIN2NUM requires that the resulting number is valid", bsvrs_line: "spend.rs:1337–1342", code: "SCRIPT_ERR_INVALID_NUMBER_RANGE", reference: "interpreter.cpp:1789–1790", note: "since 0.3.28 also a result longer than the limit in force (`IsMinimallyEncoded(max)` on the reference), the same code" },
    Row { prefix: "OP_EQUALVERIFY requires the top two stack items to be equal", bsvrs_line: "spend.rs:1399", code: "SCRIPT_ERR_EQUALVERIFY", reference: "interpreter.cpp:1209–1213", note: "" },
    Row { prefix: "OP_NUMEQUALVERIFY requires the top stack item to be truthy", bsvrs_line: "spend.rs:1645", code: "SCRIPT_ERR_NUMEQUALVERIFY", reference: "interpreter.cpp:1371–1373", note: "" },
    Row { prefix: "OP_DIV cannot divide by zero", bsvrs_line: "spend.rs:1557", code: "SCRIPT_ERR_DIV_BY_ZERO", reference: "interpreter.cpp:1316–1319", note: "" },
    Row { prefix: "OP_MOD cannot divide by zero", bsvrs_line: "spend.rs:1563", code: "SCRIPT_ERR_MOD_BY_ZERO", reference: "interpreter.cpp:1325–1328", note: "" },
    Row { prefix: "OP_CHECKSIGVERIFY requires that a valid signature is provided", bsvrs_line: "spend.rs:1760", code: "SCRIPT_ERR_CHECKSIGVERIFY", reference: "interpreter.cpp:1502–1507", note: "" },
    Row { prefix: "OP_CHECKMULTISIGVERIFY requires that a sufficient number", bsvrs_line: "spend.rs:1971", code: "SCRIPT_ERR_CHECKMULTISIGVERIFY", reference: "interpreter.cpp:1676–1681", note: "" },
    Row { prefix: "Invalid opcode ", bsvrs_line: "spend.rs:1788", code: "SCRIPT_ERR_BAD_OPCODE", reference: "interpreter.cpp:1795", note: "a reserved opcode, and since 0.3.27 (bsv-rs#12) an executed undefined opcode 0xba–0xff, as the reference's default:" },
    Row { prefix: "Script number overflow", bsvrs_line: "spend.rs:2567–2571 (overflow_error), also read_splice_operand 2310–2316 at 0.4.4; raised by read_number_within 2525–2538 for every number read (read_number 2541 under the limit in force; read_count 2549 at 4 bytes for OP_CHECKMULTISIG's counts) and by push_number 2557–2565 for every arithmetic result before its push; since 0.3.29 also by a left shift's size test before the shift, 2206–2217 (overflow_error at 2210 with the size sum; the a-shift-by message at 2212–2215 when the count or the sum does not fit a u64)", code: "SCRIPT_ERR_SCRIPTNUM_OVERFLOW", reference: "script_num.cpp:62–68 (the length test before the decode), 164, 194, 214, 301–315; interpreter.cpp:1807–1810, 1519–1525, 1550–1552", note: "0.3.28 (bsv-rs#17, the spec's #20 Finding, eras-00041): the limit of the coin's era under a block word (750,000 bytes after Genesis, 32,000,000 after Chronicle: Spend::set_utxo_after_chronicle 399 decides the era) and the node's policy default of 10,000 under a mempool word (Spend::set_script_num_length_policy 430, 0 = the consensus limit; flags.rs max_script_num_length 369–380); the default mode reads a number of any length; 0.3.29 (bsv-rs#21): under a word a left shift's result size, the value's serialized length plus count / 8, is tested against the era's number length before the shift (script_num.cpp:305–308), the message naming that size, or, when the count or the size sum does not fit a u64, 'Script number overflow: a shift by N bits, the limit is M bytes.'; both carry this row's prefix" },
    Row { prefix: "Invalid script number", bsvrs_line: "spend.rs:2536 (read_number_within); reached through read_number 2541 and read_count 2549; OP_BIN2NUM result 1337–1342", code: "SCRIPT_ERR_SCRIPTNUM_MINENCODE", reference: "script_num.cpp:67; interpreter.cpp:1811–1814", note: "a non-minimal encoding under the word's MINIMALDATA with the version gate; since 0.3.28 the length test precedes this decode (2103–2107, the `Script number overflow` row) as script_num.cpp:62 precedes :67 on the reference (the 0.3.27 note said bsv-rs had no length limit: struck at the bump of 2026-09-24)" },
    Row { prefix: "The signature format is invalid", bsvrs_line: "spend.rs:1992, 1997", code: "SCRIPT_ERR_SIG_DER", reference: "interpreter.cpp:275–280", note: "" },
    Row { prefix: "The signature must have a low S value", bsvrs_line: "spend.rs:2003–2005 (signature_overflows_the_order 2372)", code: "SCRIPT_ERR_SIG_HIGH_S", reference: "interpreter.cpp:282–288", note: "under the word: LOW_S and the version gate; since 0.3.28 (bsv-rs#14) an r or s at or above the curve order is the zero signature for this check, as the reference's lax parse makes it (pubkey.cpp:146–173, CheckLowS 353–363): s = n is no longer refused here, it fails to verify and is SIG_NULLFAIL under NULLFAIL as on the reference (the tier-2 note of #19 closed; 0.3.24 to 0.3.27 said SIG_HIGH_S)" },
    Row { prefix: "The signature must use SIGHASH_FORKID", bsvrs_line: "spend.rs:2044", code: "SCRIPT_ERR_MUST_USE_FORKID", reference: "interpreter.cpp:304–306", note: "bsv-rs requires it always (a word must carry SIGHASH_FORKID, flags.rs check); the reference only when SCRIPT_ENABLE_SIGHASH_FORKID is set (always on mainnet since UAHF)" },
    Row { prefix: "The signature's hash type (", bsvrs_line: "spend.rs:2021–2024 (check_signature_encoding: under a word carrying STRICTENC and in the default mode, 1872–1878)", code: "SCRIPT_ERR_SIG_HASHTYPE", reference: "interpreter.cpp:291–294; sighashtype.h:80–83 (isDefined)", note: "0.3.29 (bsv-rs#23; gen-00969 to gen-00971): an undefined base type (the CHRONICLE, FORKID and ANYONECANPAY bits cleared, the rest not ALL, NONE or SINGLE) is refused after DER and low-S and before the CHRONICLE and FORKID rules; the default mode tests it too" },
    Row { prefix: "The signature must not use SIGHASH_CHRONICLE before Chronicle.", bsvrs_line: "spend.rs:2037–2039 (check_signature_encoding: a word carrying STRICTENC and not CHRONICLE, 1890–1894)", code: "SCRIPT_ERR_ILLEGAL_CHRONICLE", reference: "interpreter.cpp:296–303", note: "0.3.29 (bsv-rs#22): the CHRONICLE bit (0x20) is legal only under a word carrying SCRIPT_CHRONICLE; the default mode has no word and admits it" },
    Row { prefix: "Public key is empty", bsvrs_line: "spend.rs:2052", code: "SCRIPT_ERR_PUBKEYTYPE", reference: "interpreter.cpp:314–318", note: "the reference reports PUBKEYTYPE under STRICTENC for a key that is neither 33 nor 65 bytes; an empty key without STRICTENC fails the check itself (2138–2139)" },
    Row { prefix: "The public key is too short", bsvrs_line: "spend.rs:2056", code: "SCRIPT_ERR_PUBKEYTYPE", reference: "interpreter.cpp:314–318", note: "" },
    Row { prefix: "The non-compressed public key must be 65 bytes", bsvrs_line: "spend.rs:2061", code: "SCRIPT_ERR_PUBKEYTYPE", reference: "interpreter.cpp:314–318", note: "" },
    Row { prefix: "The compressed public key must be 33 bytes", bsvrs_line: "spend.rs:2065", code: "SCRIPT_ERR_PUBKEYTYPE", reference: "interpreter.cpp:314–318", note: "" },
    Row { prefix: "The public key is in an unknown format", bsvrs_line: "spend.rs:2068, 2079", code: "SCRIPT_ERR_PUBKEYTYPE", reference: "interpreter.cpp:314–318", note: "" },
    Row { prefix: "The public key must be compressed", bsvrs_line: "spend.rs:2074", code: "SCRIPT_ERR_NONCOMPRESSED_PUBKEY", reference: "interpreter.cpp:322–327", note: "0.3.26: under the word's COMPRESSED_PUBKEYTYPE (never set by a node at the pin)" },
    Row { prefix: "OP_WITHIN requires at least three items", bsvrs_line: "spend.rs:1653", code: "SCRIPT_ERR_INVALID_STACK_OPERATION", reference: "interpreter.cpp:1382–1384", note: "" },
    Row { prefix: "Stack underflow accessing element", bsvrs_line: "spend.rs:2387", code: "SCRIPT_ERR_INVALID_STACK_OPERATION", reference: "interpreter.cpp (the depth check of each opcode)", note: "" },
    Row { prefix: "Stack is empty", bsvrs_line: "spend.rs:2380", code: "SCRIPT_ERR_INVALID_STACK_OPERATION", reference: "interpreter.cpp (the depth check of each opcode)", note: "" },
    Row { prefix: "Attempted to pop from an empty stack", bsvrs_line: "spend.rs:2370", code: "SCRIPT_ERR_INVALID_STACK_OPERATION", reference: "interpreter.cpp (the depth check of each opcode)", note: "" },
];

/// Rows whose prefix is an opcode name followed by a clause
/// (`format!("{} requires ...", name)`): matched on the clause.
pub const CLAUSES: &[Row] = &[
    Row { prefix: " is discouraged by verification flags", bsvrs_line: "spend.rs:822, 835", code: "SCRIPT_ERR_DISCOURAGE_UPGRADABLE_NOPS", reference: "interpreter.cpp:765–771, 522, 565, 613, 646, 671, 696, 732", note: "0.3.26: an executed OP_NOP1–OP_NOP10 under the word's DISCOURAGE_UPGRADABLE_NOPS (a policy bit, in the standard word only)" },
    Row { prefix: " is disabled until Chronicle", bsvrs_line: "spend.rs:893", code: "SCRIPT_ERR_BAD_OPCODE", reference: "interpreter.cpp:773–781", note: "0.3.27: OP_VERIF/OP_VERNOTIF executed for a UTXO taken as pre-Chronicle" },
    Row { prefix: " requires failing signatures to be empty", bsvrs_line: "spend.rs:1750, 1945", code: "SCRIPT_ERR_SIG_NULLFAIL", reference: "interpreter.cpp:1491–1497, 1640–1646", note: "0.3.26: under the word's NULLFAIL and the version gate (OP_CHECKSIG; every signature of a failed OP_CHECKMULTISIG)" },
    Row { prefix: " requires at least ", bsvrs_line: "spend.rs:978–1713 (the per-opcode depth checks), 1122, 1387, 1408, 1491, 1541, 1725, 2145", code: "SCRIPT_ERR_INVALID_STACK_OPERATION", reference: "interpreter.cpp (the `stack.size() < n` check of each opcode)", note: "" },
    Row { prefix: " requires the top stack element to be 0 or a positive number less than the current size of the stack", bsvrs_line: "spend.rs:1132", code: "SCRIPT_ERR_INVALID_STACK_OPERATION", reference: "interpreter.cpp:1018–1021", note: "OP_PICK/OP_ROLL: the reference refuses n < 0 or n >= size with INVALID_STACK_OPERATION" },
    Row { prefix: " requires the top item on the stack not to be negative", bsvrs_line: "spend.rs:1420", code: "SCRIPT_ERR_INVALID_NUMBER_RANGE", reference: "interpreter.cpp:1130–1131, 1163–1164", note: "OP_LSHIFT/OP_RSHIFT: a negative count" },
    Row { prefix: " bits to shift must not be negative", bsvrs_line: "spend.rs:2195", code: "SCRIPT_ERR_INVALID_NUMBER_RANGE", reference: "interpreter.cpp:713–716, 749–752", note: "0.3.27: OP_LSHIFTNUM/OP_RSHIFTNUM's count (script_num.cpp:206–330 on the reference; a negative count refused before the shift)" },
    Row { prefix: " must be in range ", bsvrs_line: "spend.rs:2163, 2178", code: "SCRIPT_ERR_INVALID_NUMBER_RANGE", reference: "interpreter.cpp:628–634, 659–660, 684–685", note: "0.3.27: OP_SUBSTR's offset and length, OP_LEFT's and OP_RIGHT's length outside the element" },
    Row { prefix: " requires the top two stack items to be the same size", bsvrs_line: "spend.rs:1369", code: "SCRIPT_ERR_INVALID_OPERAND_SIZE", reference: "interpreter.cpp:1078–1080", note: "" },
    Row { prefix: " requires an extra item (dummy)", bsvrs_line: "spend.rs:1954", code: "SCRIPT_ERR_INVALID_STACK_OPERATION", reference: "interpreter.cpp:1660–1662", note: "" },
    Row { prefix: " requires the extra stack item (dummy) to be empty", bsvrs_line: "spend.rs:1961", code: "SCRIPT_ERR_SIG_NULLDUMMY", reference: "interpreter.cpp:1664–1670", note: "under the word: NULLDUMMY and the version gate (0.3.26); the default mode gates it on version <= 1 (spend.rs:297)" },
    Row { prefix: " requires at least 1 item for nKeys", bsvrs_line: "spend.rs:1805", code: "SCRIPT_ERR_INVALID_STACK_OPERATION", reference: "interpreter.cpp:1517–1519", note: "" },
    Row { prefix: " requires a key count between 0 and ", bsvrs_line: "spend.rs:1816", code: "SCRIPT_ERR_PUBKEY_COUNT", reference: "interpreter.cpp:1527–1531", note: "bsv-rs's bound is i32::MAX (spend.rs:77); the reference's is MaxPubKeysPerMultiSig" },
    Row { prefix: " stack too small for keys", bsvrs_line: "spend.rs:1826", code: "SCRIPT_ERR_INVALID_STACK_OPERATION", reference: "interpreter.cpp:1540–1542", note: "" },
    Row { prefix: " requires item for nSigs", bsvrs_line: "spend.rs:1841", code: "SCRIPT_ERR_INVALID_STACK_OPERATION", reference: "interpreter.cpp:1544–1546", note: "" },
    Row { prefix: " requires the number of signatures to be no greater than the number of keys", bsvrs_line: "spend.rs:1852", code: "SCRIPT_ERR_SIG_COUNT", reference: "interpreter.cpp:1555–1558", note: "" },
    Row { prefix: " stack too small for sigs", bsvrs_line: "spend.rs:1861", code: "SCRIPT_ERR_INVALID_STACK_OPERATION", reference: "interpreter.cpp:1561–1563", note: "" },
    Row { prefix: " requires correct encoding for the public key and signature", bsvrs_line: "spend.rs:1919", code: "SCRIPT_ERR_SIG_DER", reference: "interpreter.cpp:1600–1610", note: "bsv-rs folds the signature and key encoding refusals of CHECKMULTISIG into one message; the reference reports SIG_DER/SIG_HIGH_S/SIG_HASHTYPE/PUBKEYTYPE per check" },
    Row { prefix: " requires at least two items on the stack", bsvrs_line: "spend.rs:1361", code: "SCRIPT_ERR_INVALID_STACK_OPERATION", reference: "interpreter.cpp:1071–1073", note: "" },
    Row { prefix: ") does not fit an int.", bsvrs_line: "spend.rs:2224–2228 (the shift arm, under a word, on both shifts after the left shift's size test)", code: "SCRIPT_ERR_BIG_INT", reference: "big_int.cpp:359–369, 383–393 (bint::operator<<= and operator>>= throw big_int_error on a count above INT_MAX); interpreter.cpp:1819–1821", note: "0.3.29 (bsv-rs#21; gen-00835): '<opcode> count (N) does not fit an int.' for a count above INT_MAX, before any allocation" },
];

/// The code for a bsv-rs message, or `None` when no row matches (a new bsv-rs
/// message: the run reports it so the table grows, never guesses).
pub fn code_of(message: &str) -> Option<&'static Row> {
    if let Some(r) = TABLE.iter().find(|r| message.starts_with(r.prefix)) {
        return Some(r);
    }
    CLAUSES.iter().find(|r| message.contains(r.prefix))
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn every_seed_message_shape_has_a_row() {
        for m in [
            "The top stack element must be truthy after script evaluation.",
            "The top stack element must be truthy after script evaluation (stack is empty).",
            "This data is not minimally-encoded. (PC: 3)",
            "OP_2DUP requires at least two items to be on the stack.",
            "OP_PICK/ROLL requires the top stack element to be 0 or a positive number less than the current size of the stack.",
            "Invalid script number: [1, 0]",
            "Unlocking scripts can only contain push operations, and no other opcodes.",
            "OP_CHECKMULTISIG requires the extra stack item (dummy) to be empty.",
            "OP_CHECKSIG requires failing signatures to be empty.",
            "OP_NOP7 is discouraged by verification flags.",
            "OP_IF and OP_NOTIF require minimal truth values.",
            "Invalid verification flags: CLEANSTACK without P2SH.",
            "A push declares more bytes than the script holds; the script cannot be parsed past it (pc=1).",
            "OP_ELSE may only be used once for each OP_IF or OP_NOTIF after Genesis.",
            "OP_VERIF is disabled until Chronicle.",
            "OP_LSHIFTNUM bits to shift must not be negative.",
            "OP_LEFT length (5) must be in range [0, 3]",
            "Invalid opcode 186 (pc=0).",
        ] {
            assert!(code_of(m).is_some(), "{m}");
        }
        assert!(code_of("a message the table does not know").is_none());
    }
}
