// bsv-script-lean #28: the cited code table of the GoBDK shim (this repo's; docs/DESIGN.md §6 tier 2).
//
// GoBDK's own error codes, mapped to the reference's vocabulary; never Teranode's remap of them
// (services/validator/ScriptVerifierGoBDK.go:351–443 at v0.16.0, which folds codes into policy and
// processing errors for the node's pipeline).
//
// The script domain. GoBDK's Go enum (module/gobdk/script/scripterror.go:19–97 at 4eab3acd, the same lines as at cdfa7814) is the C++
// ScriptError_t of bitcoin-sv v1.2.2 (src/script/script_error.h:12–87 at 879fc8b42) ordinal by ordinal:
// translateTxError hands the C++ value through (txvalidator.go:545–546; core/txerror.h:52 TxErrorScript), so
// the code IS the reference's. The one name that differs is the ordinal GoBDK calls SCRIPT_ERR_ILLEGAL_RELAX
// (scripterror.go:86), the reference's SCRIPT_ERR_ILLEGAL_CHRONICLE (script_error.h:80; the reference-
// documentation finding of the v1 review, docs/DESIGN.md §11). Every row carries the reference's name, GoBDK's
// name, the reference's ScriptErrorString text at the pin and the three lines; `--selftest` checks every row
// against the text the LINKED library returns for the ordinal (script_error_cgo.cpp:4–10 → ScriptErrorString)
// and the library's SCRIPT_ERR_ERROR_COUNT, so a table that drifts from the library refuses to run.
//
// The transaction (DoS) domain (core/doserror.hpp:18–42, its strings core/doserror.cpp:3–26; the Go mirror
// module/gobdk/script/doserror.go:12–33): VerifyScript reaches it only for a MEMPOOL_HEIGHT coin in consensus
// mode (core/txvalidator.cpp:903–904); the rows are GoBDK's own, reported under GoBDK's names.
//
// The exception domain (core/txerror.h:17; the C++ side catches an exception at txvalidator.cpp:837–839 and
// returns it for a fired cancellation token at 939–940): translateTxError reports it as the Go-only ordinal
// SCRIPT_ERR_CGO_EXCEPTION (txvalidator.go:549–550; scripterror.go:96), whose text is "Exception thrown from
// C++ code" (scripterror.go:104–107).
package main

import (
	"fmt"

	bdkscript "github.com/bitcoin-sv/bdk/module/gobdk/script"
)

type scriptRow struct {
	code bdkscript.ScriptErrorCode
	// the reference's name (script_error.h at 879fc8b42): what the harness compares
	reference string
	// GoBDK's Go constant for the same ordinal (scripterror.go at 4eab3acd)
	gobdk string
	// the reference's ScriptErrorString text for the name (script_error.cpp at 879fc8b42)
	description string
	cite        string
}

var scriptTable = []scriptRow{
	{bdkscript.SCRIPT_ERR_OK, "SCRIPT_ERR_OK", "SCRIPT_ERR_OK", "No error", "script_error.h:14 · script_error.cpp:11 · scripterror.go:20"},
	{bdkscript.SCRIPT_ERR_UNKNOWN_ERROR, "SCRIPT_ERR_UNKNOWN_ERROR", "SCRIPT_ERR_UNKNOWN_ERROR", "unknown error", "script_error.h:15 · script_error.cpp:106–111 (the default arm) · scripterror.go:21"},
	{bdkscript.SCRIPT_ERR_EVAL_FALSE, "SCRIPT_ERR_EVAL_FALSE", "SCRIPT_ERR_EVAL_FALSE", "Script evaluated without error but finished with a false/empty top stack element", "script_error.h:16 · script_error.cpp:13 · scripterror.go:22"},
	{bdkscript.SCRIPT_ERR_OP_RETURN, "SCRIPT_ERR_OP_RETURN", "SCRIPT_ERR_OP_RETURN", "OP_RETURN was encountered", "script_error.h:17 · script_error.cpp:59 · scripterror.go:23"},
	{bdkscript.SCRIPT_ERR_SCRIPT_SIZE, "SCRIPT_ERR_SCRIPT_SIZE", "SCRIPT_ERR_SCRIPT_SIZE", "Script is too big", "script_error.h:20 · script_error.cpp:26 · scripterror.go:26"},
	{bdkscript.SCRIPT_ERR_PUSH_SIZE, "SCRIPT_ERR_PUSH_SIZE", "SCRIPT_ERR_PUSH_SIZE", "Push value size limit exceeded", "script_error.h:21 · script_error.cpp:28 · scripterror.go:27"},
	{bdkscript.SCRIPT_ERR_OP_COUNT, "SCRIPT_ERR_OP_COUNT", "SCRIPT_ERR_OP_COUNT", "Operation limit exceeded", "script_error.h:22 · script_error.cpp:30 · scripterror.go:28"},
	{bdkscript.SCRIPT_ERR_STACK_SIZE, "SCRIPT_ERR_STACK_SIZE", "SCRIPT_ERR_STACK_SIZE", "Stack size limit exceeded", "script_error.h:23 · script_error.cpp:32 · scripterror.go:29"},
	{bdkscript.SCRIPT_ERR_SIG_COUNT, "SCRIPT_ERR_SIG_COUNT", "SCRIPT_ERR_SIG_COUNT", "Signature count negative or greater than pubkey count", "script_error.h:24 · script_error.cpp:34 · scripterror.go:30"},
	{bdkscript.SCRIPT_ERR_PUBKEY_COUNT, "SCRIPT_ERR_PUBKEY_COUNT", "SCRIPT_ERR_PUBKEY_COUNT", "Pubkey count negative or limit exceeded", "script_error.h:25 · script_error.cpp:36 · scripterror.go:31"},
	{bdkscript.SCRIPT_ERR_INVALID_OPERAND_SIZE, "SCRIPT_ERR_INVALID_OPERAND_SIZE", "SCRIPT_ERR_INVALID_OPERAND_SIZE", "Invalid operand size", "script_error.h:28 · script_error.cpp:38 · scripterror.go:34"},
	{bdkscript.SCRIPT_ERR_INVALID_NUMBER_RANGE, "SCRIPT_ERR_INVALID_NUMBER_RANGE", "SCRIPT_ERR_INVALID_NUMBER_RANGE", "Given operand is not a number within the valid range [-2^31...2^31]", "script_error.h:29 · script_error.cpp:40 · scripterror.go:35"},
	{bdkscript.SCRIPT_ERR_IMPOSSIBLE_ENCODING, "SCRIPT_ERR_IMPOSSIBLE_ENCODING", "SCRIPT_ERR_IMPOSSIBLE_ENCODING", "The requested encoding is impossible to satisfy", "script_error.h:30 · script_error.cpp:43 · scripterror.go:36"},
	{bdkscript.SCRIPT_ERR_INVALID_SPLIT_RANGE, "SCRIPT_ERR_INVALID_SPLIT_RANGE", "SCRIPT_ERR_INVALID_SPLIT_RANGE", "Invalid OP_SPLIT range", "script_error.h:31 · script_error.cpp:45 · scripterror.go:37"},
	{bdkscript.SCRIPT_ERR_SCRIPTNUM_OVERFLOW, "SCRIPT_ERR_SCRIPTNUM_OVERFLOW", "SCRIPT_ERR_SCRIPTNUM_OVERFLOW", "Script number overflow", "script_error.h:32 · script_error.cpp:47 · scripterror.go:38"},
	{bdkscript.SCRIPT_ERR_SCRIPTNUM_MINENCODE, "SCRIPT_ERR_SCRIPTNUM_MINENCODE", "SCRIPT_ERR_SCRIPTNUM_MINENCODE", "Non-minimally encoded script number", "script_error.h:33 · script_error.cpp:49 · scripterror.go:39"},
	{bdkscript.SCRIPT_ERR_VERIFY, "SCRIPT_ERR_VERIFY", "SCRIPT_ERR_VERIFY", "Script failed an OP_VERIFY operation", "script_error.h:36 · script_error.cpp:16 · scripterror.go:42"},
	{bdkscript.SCRIPT_ERR_EQUALVERIFY, "SCRIPT_ERR_EQUALVERIFY", "SCRIPT_ERR_EQUALVERIFY", "Script failed an OP_EQUALVERIFY operation", "script_error.h:37 · script_error.cpp:18 · scripterror.go:43"},
	{bdkscript.SCRIPT_ERR_CHECKMULTISIGVERIFY, "SCRIPT_ERR_CHECKMULTISIGVERIFY", "SCRIPT_ERR_CHECKMULTISIGVERIFY", "Script failed an OP_CHECKMULTISIGVERIFY operation", "script_error.h:38 · script_error.cpp:20 · scripterror.go:44"},
	{bdkscript.SCRIPT_ERR_CHECKSIGVERIFY, "SCRIPT_ERR_CHECKSIGVERIFY", "SCRIPT_ERR_CHECKSIGVERIFY", "Script failed an OP_CHECKSIGVERIFY operation", "script_error.h:39 · script_error.cpp:22 · scripterror.go:45"},
	{bdkscript.SCRIPT_ERR_NUMEQUALVERIFY, "SCRIPT_ERR_NUMEQUALVERIFY", "SCRIPT_ERR_NUMEQUALVERIFY", "Script failed an OP_NUMEQUALVERIFY operation", "script_error.h:40 · script_error.cpp:24 · scripterror.go:46"},
	{bdkscript.SCRIPT_ERR_BAD_OPCODE, "SCRIPT_ERR_BAD_OPCODE", "SCRIPT_ERR_BAD_OPCODE", "Opcode missing or not understood", "script_error.h:43 · script_error.cpp:51 · scripterror.go:49"},
	{bdkscript.SCRIPT_ERR_DISABLED_OPCODE, "SCRIPT_ERR_DISABLED_OPCODE", "SCRIPT_ERR_DISABLED_OPCODE", "Attempted to use a disabled opcode", "script_error.h:44 · script_error.cpp:53 · scripterror.go:50"},
	{bdkscript.SCRIPT_ERR_INVALID_STACK_OPERATION, "SCRIPT_ERR_INVALID_STACK_OPERATION", "SCRIPT_ERR_INVALID_STACK_OPERATION", "Operation not valid with the current stack size", "script_error.h:45 · script_error.cpp:55 · scripterror.go:51"},
	{bdkscript.SCRIPT_ERR_INVALID_ALTSTACK_OPERATION, "SCRIPT_ERR_INVALID_ALTSTACK_OPERATION", "SCRIPT_ERR_INVALID_ALTSTACK_OPERATION", "Operation not valid with the current altstack size", "script_error.h:46 · script_error.cpp:57 · scripterror.go:52"},
	{bdkscript.SCRIPT_ERR_UNBALANCED_CONDITIONAL, "SCRIPT_ERR_UNBALANCED_CONDITIONAL", "SCRIPT_ERR_UNBALANCED_CONDITIONAL", "Invalid OP_IF construction", "script_error.h:47 · script_error.cpp:61 · scripterror.go:53"},
	{bdkscript.SCRIPT_ERR_DIV_BY_ZERO, "SCRIPT_ERR_DIV_BY_ZERO", "SCRIPT_ERR_DIV_BY_ZERO", "Division by zero error", "script_error.h:50 · script_error.cpp:63 · scripterror.go:56"},
	{bdkscript.SCRIPT_ERR_MOD_BY_ZERO, "SCRIPT_ERR_MOD_BY_ZERO", "SCRIPT_ERR_MOD_BY_ZERO", "Modulo by zero error", "script_error.h:51 · script_error.cpp:65 · scripterror.go:57"},
	{bdkscript.SCRIPT_ERR_NEGATIVE_LOCKTIME, "SCRIPT_ERR_NEGATIVE_LOCKTIME", "SCRIPT_ERR_NEGATIVE_LOCKTIME", "Negative locktime", "script_error.h:54 · script_error.cpp:67 · scripterror.go:60"},
	{bdkscript.SCRIPT_ERR_UNSATISFIED_LOCKTIME, "SCRIPT_ERR_UNSATISFIED_LOCKTIME", "SCRIPT_ERR_UNSATISFIED_LOCKTIME", "Locktime requirement not satisfied", "script_error.h:55 · script_error.cpp:69 · scripterror.go:61"},
	{bdkscript.SCRIPT_ERR_SIG_HASHTYPE, "SCRIPT_ERR_SIG_HASHTYPE", "SCRIPT_ERR_SIG_HASHTYPE", "Signature hash type missing or not understood", "script_error.h:58 · script_error.cpp:71 · scripterror.go:64"},
	{bdkscript.SCRIPT_ERR_SIG_DER, "SCRIPT_ERR_SIG_DER", "SCRIPT_ERR_SIG_DER", "Non-canonical DER signature", "script_error.h:59 · script_error.cpp:73 · scripterror.go:65"},
	{bdkscript.SCRIPT_ERR_MINIMALDATA, "SCRIPT_ERR_MINIMALDATA", "SCRIPT_ERR_MINIMALDATA", "Data push larger than necessary", "script_error.h:60 · script_error.cpp:75 · scripterror.go:66"},
	{bdkscript.SCRIPT_ERR_SIG_PUSHONLY, "SCRIPT_ERR_SIG_PUSHONLY", "SCRIPT_ERR_SIG_PUSHONLY", "Only non-push operators allowed in signatures", "script_error.h:61 · script_error.cpp:77 · scripterror.go:67"},
	{bdkscript.SCRIPT_ERR_SIG_HIGH_S, "SCRIPT_ERR_SIG_HIGH_S", "SCRIPT_ERR_SIG_HIGH_S", "Non-canonical signature: S value is unnecessarily high", "script_error.h:62 · script_error.cpp:79 · scripterror.go:68"},
	{bdkscript.SCRIPT_ERR_SIG_NULLDUMMY, "SCRIPT_ERR_SIG_NULLDUMMY", "SCRIPT_ERR_SIG_NULLDUMMY", "Dummy CHECKMULTISIG argument must be zero", "script_error.h:63 · script_error.cpp:81 · scripterror.go:69"},
	{bdkscript.SCRIPT_ERR_PUBKEYTYPE, "SCRIPT_ERR_PUBKEYTYPE", "SCRIPT_ERR_PUBKEYTYPE", "Public key is neither compressed or uncompressed", "script_error.h:64 · script_error.cpp:90 · scripterror.go:70"},
	{bdkscript.SCRIPT_ERR_CLEANSTACK, "SCRIPT_ERR_CLEANSTACK", "SCRIPT_ERR_CLEANSTACK", "Script did not clean its stack", "script_error.h:65 · script_error.cpp:92 · scripterror.go:71"},
	{bdkscript.SCRIPT_ERR_MINIMALIF, "SCRIPT_ERR_MINIMALIF", "SCRIPT_ERR_MINIMALIF", "OP_IF/NOTIF argument must be minimal", "script_error.h:66 · script_error.cpp:83 · scripterror.go:72"},
	{bdkscript.SCRIPT_ERR_SIG_NULLFAIL, "SCRIPT_ERR_SIG_NULLFAIL", "SCRIPT_ERR_SIG_NULLFAIL", "Signature must be zero for failed CHECK(MULTI)SIG operation", "script_error.h:67 · script_error.cpp:85 · scripterror.go:73"},
	{bdkscript.SCRIPT_ERR_DISCOURAGE_UPGRADABLE_NOPS, "SCRIPT_ERR_DISCOURAGE_UPGRADABLE_NOPS", "SCRIPT_ERR_DISCOURAGE_UPGRADABLE_NOPS", "NOPx reserved for soft-fork upgrades", "script_error.h:70 · script_error.cpp:88 · scripterror.go:76"},
	{bdkscript.SCRIPT_ERR_NONCOMPRESSED_PUBKEY, "SCRIPT_ERR_NONCOMPRESSED_PUBKEY", "SCRIPT_ERR_NONCOMPRESSED_PUBKEY", "Using non-compressed public key", "script_error.h:73 · script_error.cpp:94 · scripterror.go:79"},
	{bdkscript.SCRIPT_ERR_ILLEGAL_FORKID, "SCRIPT_ERR_ILLEGAL_FORKID", "SCRIPT_ERR_ILLEGAL_FORKID", "Illegal use of SIGHASH_FORKID", "script_error.h:76 · script_error.cpp:96 · scripterror.go:82"},
	{bdkscript.SCRIPT_ERR_MUST_USE_FORKID, "SCRIPT_ERR_MUST_USE_FORKID", "SCRIPT_ERR_MUST_USE_FORKID", "Signature must use SIGHASH_FORKID", "script_error.h:77 · script_error.cpp:98 · scripterror.go:83"},
	{bdkscript.SCRIPT_ERR_ILLEGAL_RELAX, "SCRIPT_ERR_ILLEGAL_CHRONICLE", "SCRIPT_ERR_ILLEGAL_RELAX", "Illegal use of SIGHASH_CHRONICLE", "script_error.h:80 · script_error.cpp:100 · scripterror.go:86"},
	{bdkscript.SCRIPT_ERR_BIG_INT, "SCRIPT_ERR_BIG_INT", "SCRIPT_ERR_BIG_INT", "Big integer OpenSSL error", "script_error.h:82 · script_error.cpp:102 · scripterror.go:88"},
	{bdkscript.SCRIPT_ERR_INVALID_FLAGS, "SCRIPT_ERR_INVALID_FLAGS", "SCRIPT_ERR_INVALID_FLAGS", "Invalid script verification flag combination", "script_error.h:84 · script_error.cpp:104 · scripterror.go:90"},
	{bdkscript.SCRIPT_ERR_ERROR_COUNT, "SCRIPT_ERR_ERROR_COUNT", "SCRIPT_ERR_ERROR_COUNT", "unknown error", "script_error.h:86 · script_error.cpp:107–111 · scripterror.go:94"},
}

type dosRow struct {
	code bdkscript.DoSErrorCode
	// GoBDK's Go constant (doserror.go) and the C++ enumerator (doserror.hpp)
	gobdk, cpp, reason, cite string
}

var dosTable = []dosRow{
	{bdkscript.DOS_ERR_NULL_PREVOUT, "DOS_ERR_NULL_PREVOUT", "NullPrevout", "bad-txns-prevout-null", "doserror.hpp:21 · doserror.cpp:6 · doserror.go:14"},
	{bdkscript.DOS_ERR_P2SH_OUTPUT_POST_GENESIS, "DOS_ERR_P2SH_OUTPUT_POST_GENESIS", "P2SHOutputPostGenesis", "bad-txns-vout-p2sh", "doserror.hpp:22 · doserror.cpp:7 · doserror.go:15"},
	{bdkscript.DOS_ERR_SIGOPS_CONSENSUS, "DOS_ERR_SIGOPS_CONSENSUS", "SigopsConsensus", "bad-txn-sigops", "doserror.hpp:23 · doserror.cpp:8 · doserror.go:16"},
	{bdkscript.DOS_ERR_SIGOPS_POLICY, "DOS_ERR_SIGOPS_POLICY", "SigopsPolicy", "bad-txns-too-many-sigops", "doserror.hpp:25 · doserror.cpp:9 · doserror.go:17"},
	{bdkscript.DOS_ERR_NOT_FREE_CONSOLIDATION, "DOS_ERR_NOT_FREE_CONSOLIDATION", "NotFreeConsolidation", "not-free-consolidation", "doserror.hpp:26 · doserror.cpp:10 · doserror.go:18"},
	{bdkscript.DOS_ERR_NOT_STANDARD, "DOS_ERR_NOT_STANDARD", "NotStandard", "not-standard", "doserror.hpp:27 · doserror.cpp:11 · doserror.go:19"},
	{bdkscript.DOS_ERR_VIN_EMPTY, "DOS_ERR_VIN_EMPTY", "VinEmpty", "bad-txns-vin-empty", "doserror.hpp:29 · doserror.cpp:12 · doserror.go:20"},
	{bdkscript.DOS_ERR_VOUT_EMPTY, "DOS_ERR_VOUT_EMPTY", "VoutEmpty", "bad-txns-vout-empty", "doserror.hpp:30 · doserror.cpp:13 · doserror.go:21"},
	{bdkscript.DOS_ERR_OVERSIZE, "DOS_ERR_OVERSIZE", "Oversize", "bad-txns-oversize", "doserror.hpp:31 · doserror.cpp:14 · doserror.go:22"},
	{bdkscript.DOS_ERR_OUTPUT_NEGATIVE, "DOS_ERR_OUTPUT_NEGATIVE", "OutputNegative", "bad-txns-vout-negative", "doserror.hpp:32 · doserror.cpp:15 · doserror.go:23"},
	{bdkscript.DOS_ERR_OUTPUT_TOO_LARGE, "DOS_ERR_OUTPUT_TOO_LARGE", "OutputTooLarge", "bad-txns-vout-toolarge", "doserror.hpp:33 · doserror.cpp:16 · doserror.go:24"},
	{bdkscript.DOS_ERR_OUTPUT_TOTAL_TOO_LARGE, "DOS_ERR_OUTPUT_TOTAL_TOO_LARGE", "OutputTotalTooLarge", "bad-txns-txouttotal-toolarge", "doserror.hpp:34 · doserror.cpp:17 · doserror.go:25"},
	{bdkscript.DOS_ERR_COINBASE_NOT_ALLOWED, "DOS_ERR_COINBASE_NOT_ALLOWED", "CoinbaseNotAllowed", "bad-tx-coinbase", "doserror.hpp:35 · doserror.cpp:18 · doserror.go:26"},
	{bdkscript.DOS_ERR_DUPLICATE_INPUTS, "DOS_ERR_DUPLICATE_INPUTS", "DuplicateInputs", "bad-txns-inputs-duplicate", "doserror.hpp:36 · doserror.cpp:19 · doserror.go:27"},
	{bdkscript.DOS_ERR_UNCONFIRMED_INPUT_IN_BLOCK, "DOS_ERR_UNCONFIRMED_INPUT_IN_BLOCK", "UnconfirmedInputInBlock", "bad-txns-unconfirmed-input-in-block", "doserror.hpp:37 · doserror.cpp:20 · doserror.go:28"},
	{bdkscript.DOS_ERR_INPUT_VALUES_OUT_OF_RANGE, "DOS_ERR_INPUT_VALUES_OUT_OF_RANGE", "InputValuesOutOfRange", "bad-txns-inputvalues-outofrange", "doserror.hpp:38 · doserror.cpp:21 · doserror.go:29"},
	{bdkscript.DOS_ERR_INPUTS_BELOW_OUTPUTS, "DOS_ERR_INPUTS_BELOW_OUTPUTS", "InputsBelowOutputs", "bad-txns-in-belowout", "doserror.hpp:39 · doserror.cpp:22 · doserror.go:30"},
	{bdkscript.DOS_ERR_INSUFFICIENT_FEE, "DOS_ERR_INSUFFICIENT_FEE", "InsufficientFee", "insufficient-fee", "doserror.hpp:40 · doserror.cpp:23 · doserror.go:31"},
}

func scriptRowOf(c bdkscript.ScriptErrorCode) (scriptRow, bool) {
	for _, r := range scriptTable {
		if r.code == c {
			return r, true
		}
	}
	return scriptRow{}, false
}

func dosRowOf(c bdkscript.DoSErrorCode) (dosRow, bool) {
	for _, r := range dosTable {
		if r.code == c {
			return r, true
		}
	}
	return dosRow{}, false
}

// selftest checks the tables against the LINKED library: every script row's text is the library's
// ScriptErrorString for the ordinal, the rows cover 0 … SCRIPT_ERR_ERROR_COUNT once each, the Go
// SCRIPT_ERR_ERROR_COUNT equals the C++ one, and every DoS row's reason is the library's DoSErrorString.
func selftest() error {
	if got, want := bdkscript.CPP_SCRIPT_ERR_ERROR_COUNT(), int(bdkscript.SCRIPT_ERR_ERROR_COUNT); got != want {
		return fmt.Errorf("the library's SCRIPT_ERR_ERROR_COUNT is %d, GoBDK's Go enum says %d", got, want)
	}
	if len(scriptTable) != int(bdkscript.SCRIPT_ERR_ERROR_COUNT)+1 {
		return fmt.Errorf("%d script rows for the ordinals 0 … %d", len(scriptTable), int(bdkscript.SCRIPT_ERR_ERROR_COUNT))
	}
	for i, r := range scriptTable {
		if int(r.code) != i {
			return fmt.Errorf("row %d carries the ordinal %d (%s)", i, int(r.code), r.gobdk)
		}
		if got := bdkscript.NewScriptError(r.code).Error(); got != r.description {
			return fmt.Errorf("ordinal %d (%s = the reference's %s): the library says %q, the table %q", i, r.gobdk, r.reference, got, r.description)
		}
	}
	if len(dosTable) != int(bdkscript.DOS_ERR_COUNT)-1 {
		return fmt.Errorf("%d DoS rows for the codes 1 … %d", len(dosTable), int(bdkscript.DOS_ERR_COUNT)-1)
	}
	for i, r := range dosTable {
		if int(r.code) != i+1 {
			return fmt.Errorf("DoS row %d carries the code %d (%s)", i, int(r.code), r.gobdk)
		}
		if got := bdkscript.NewDoSError(r.code).Error(); got != r.reason {
			return fmt.Errorf("DoS code %d (%s): the library says %q, the table %q", int(r.code), r.gobdk, got, r.reason)
		}
	}
	return nil
}
