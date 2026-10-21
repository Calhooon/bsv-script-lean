// bsv-script-lean #146 (lane fixtures-146, 2026-10-16): the loader proof of corpus/fixtures/go-sdk/.
//
// Loads each go-sdk fixture file the way go-sdk v1.7.2's own test loads it and runs every row through the
// SDK's own interpreter, printing per row the SDK's verdict against the file's. The test files cannot be
// imported (they are `_test.go`), so their loading steps are copied here, each cited [SRC] at v1.7.2 (2ca481c5):
//
//   - node_vectors.json: harnessLoadNodeVectors (script/interpreter/node_vectors_test.go:101-114), the word as
//     strconv.ParseUint(word, 0, 32) through harnessNodeWordFlags (:47-66, :70-84), harnessNodeVectorTx
//     (:118-138) and harnessExecute (:149-163: every input, math.MaxInt64 stack memory under consensus, the
//     SDK's default otherwise); the verdict compared with `valid` (:200).
//   - script_tests.json: TestScripts (script/interpreter/reference_test.go:435-528) with parseScriptTest
//     (:150-201), parseShortForm's `0x` token (:111-115), parseScriptFlags (:217-272, CLEANSTACK adds P2SH at
//     :477-479), parseExpectedResult (:275-390), createSpendingTx (:397-429), and the exact error-code
//     assertions (:481-525).
//   - evaluation.json: dispatchNodeSighashFixture (internal/conformance/scripts/evaluation_conformance_test.go:521-591).
//
// A divergent row is named by the class the classifier gives the same spend and column: the listing
// `RULES_CHECK_LIST=<file> rules_check --engine go-sdk` writes (harness/src/bin/rules_check.rs, list_class), a class
// of harness/rules/go-sdk.json; a divergent row under no class is RED. No network; the files are read only.
//
// Run from harness/engines/go: go run ./fixtures --root ../../.. --classes <the listing>
package main

import (
	"bufio"
	"bytes"
	"encoding/hex"
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"math"
	"os"
	"path/filepath"
	"sort"
	"strconv"
	"strings"

	"github.com/bsv-blockchain/go-sdk/chainhash"
	crypto "github.com/bsv-blockchain/go-sdk/primitives/hash"
	"github.com/bsv-blockchain/go-sdk/script"
	"github.com/bsv-blockchain/go-sdk/script/interpreter"
	"github.com/bsv-blockchain/go-sdk/script/interpreter/errs"
	"github.com/bsv-blockchain/go-sdk/script/interpreter/scriptflag"
	"github.com/bsv-blockchain/go-sdk/transaction"
	"github.com/bsv-blockchain/go-sdk/util"
)

// node_vectors_test.go:25-43
type nodeResult struct {
	Word      string `json:"word"`
	Consensus bool   `json:"consensus"`
	Valid     bool   `json:"valid"`
	NodeError string `json:"nodeError"`
}

type nodeVector struct {
	ID      string       `json:"id"`
	Name    string       `json:"name"`
	Source  string       `json:"source"`
	Tx      string       `json:"tx"`
	Locks   []string     `json:"locks"`
	Sats    []uint64     `json:"sats"`
	Results []nodeResult `json:"results"`
}

// node_vectors_test.go:47-66
var wordFlags = map[uint32]scriptflag.Flag{
	1 << 0: scriptflag.Bip16, 1 << 1: scriptflag.VerifyStrictEncoding, 1 << 2: scriptflag.VerifyDERSignatures,
	1 << 3: scriptflag.VerifyLowS, 1 << 4: scriptflag.StrictMultiSig, 1 << 5: scriptflag.VerifySigPushOnly,
	1 << 6: scriptflag.VerifyMinimalData, 1 << 7: scriptflag.DiscourageUpgradableNops, 1 << 8: scriptflag.VerifyCleanStack,
	1 << 9: scriptflag.VerifyCheckLockTimeVerify, 1 << 10: scriptflag.VerifyCheckSequenceVerify,
	1 << 13: scriptflag.VerifyMinimalIf, 1 << 14: scriptflag.VerifyNullFail, 1 << 16: scriptflag.EnableSighashForkID,
	1 << 18: scriptflag.Genesis, 1 << 19: scriptflag.UTXOAfterGenesis, 1 << 20: scriptflag.Chronicle,
	1 << 21: scriptflag.UTXOAfterChronicle,
}

// reference_test.go:217-272
var nameFlags = map[string]scriptflag.Flag{
	"": 0, "NONE": 0, "CHECKLOCKTIMEVERIFY": scriptflag.VerifyCheckLockTimeVerify,
	"CHECKSEQUENCEVERIFY": scriptflag.VerifyCheckSequenceVerify, "CLEANSTACK": scriptflag.VerifyCleanStack,
	"DERSIG": scriptflag.VerifyDERSignatures, "DISCOURAGE_UPGRADABLE_NOPS": scriptflag.DiscourageUpgradableNops,
	"LOW_S": scriptflag.VerifyLowS, "MINIMALDATA": scriptflag.VerifyMinimalData, "NULLDUMMY": scriptflag.StrictMultiSig,
	"NULLFAIL": scriptflag.VerifyNullFail, "P2SH": scriptflag.Bip16, "SIGPUSHONLY": scriptflag.VerifySigPushOnly,
	"STRICTENC": scriptflag.VerifyStrictEncoding, "UTXO_AFTER_GENESIS": scriptflag.UTXOAfterGenesis,
	"UTXO_AFTER_CHRONICLE": scriptflag.UTXOAfterChronicle, "GENESIS": scriptflag.Genesis,
	"CHRONICLE": scriptflag.Genesis | scriptflag.Chronicle, "MINIMALIF": scriptflag.VerifyMinimalIf,
	"SIGHASH_FORKID": scriptflag.EnableSighashForkID,
}

// VENDORED from bsv-blockchain/go-sdk script/interpreter/reference_test.go:278-390
// @ 2ca481c5931b987a0c8f48bb341c70b7477b6b07 on 2026-10-16 (#146).
func parseExpectedResult(expected string) ([]errs.ErrorCode, error) {
	switch expected {
	case "OK":
		return nil, nil
	case "INVALID_NUMBER_RANGE", "SPLIT_RANGE":
		return []errs.ErrorCode{errs.ErrNumberTooBig, errs.ErrNumberTooSmall}, nil
	case "OPERAND_SIZE":
		return []errs.ErrorCode{errs.ErrInvalidInputLength}, nil
	case "PUBKEYTYPE":
		return []errs.ErrorCode{errs.ErrPubKeyType}, nil
	case "SIG_DER":
		return []errs.ErrorCode{
			errs.ErrSigTooShort, errs.ErrSigTooLong,
			errs.ErrSigInvalidSeqID, errs.ErrSigInvalidDataLen, errs.ErrSigMissingSTypeID,
			errs.ErrSigMissingSLen, errs.ErrSigInvalidSLen,
			errs.ErrSigInvalidRIntID, errs.ErrSigZeroRLen, errs.ErrSigNegativeR,
			errs.ErrSigTooMuchRPadding, errs.ErrSigInvalidSIntID,
			errs.ErrSigZeroSLen, errs.ErrSigNegativeS, errs.ErrSigTooMuchSPadding,
			errs.ErrInvalidSigHashType,
		}, nil
	case "EVAL_FALSE":
		// The node checks the final stack element before CLEANSTACK
		// (VerifyScript), the SDK after, so a false top element with extra
		// items below it reports ErrCleanStack; both reject.
		return []errs.ErrorCode{errs.ErrEvalFalse, errs.ErrEmptyStack, errs.ErrCleanStack}, nil
	case "EQUALVERIFY":
		return []errs.ErrorCode{errs.ErrEqualVerify}, nil
	case "NULLFAIL":
		return []errs.ErrorCode{errs.ErrNullFail}, nil
	case "SIG_HIGH_S":
		return []errs.ErrorCode{errs.ErrSigHighS}, nil
	case "SIG_HASHTYPE":
		return []errs.ErrorCode{errs.ErrInvalidSigHashType}, nil
	case "ILLEGAL_CHRONICLE":
		return []errs.ErrorCode{errs.ErrIllegalChronicle}, nil
	case "MISSING_FORKID", "MUST_USE_FORKID":
		// script_tests.cpp names SCRIPT_ERR_MUST_USE_FORKID "MISSING_FORKID".
		return []errs.ErrorCode{errs.ErrMustUseForkID}, nil
	case "BIG_INT":
		return []errs.ErrorCode{errs.ErrBigInt}, nil
	case "INVALID_FLAGS":
		return []errs.ErrorCode{errs.ErrInvalidFlags}, nil
	case "IMPOSSIBLE_ENCODING":
		// OP_NUM2BIN whose value does not fit the requested size.
		return []errs.ErrorCode{errs.ErrNumberTooSmall}, nil
	case "CHECKMULTISIGVERIFY":
		return []errs.ErrorCode{errs.ErrCheckMultiSigVerify}, nil
	case "NUMEQUALVERIFY":
		return []errs.ErrorCode{errs.ErrNumEqualVerify}, nil
	case "NONCOMPRESSED_PUBKEY":
		return []errs.ErrorCode{errs.ErrPubKeyType}, nil
	case "UNKNOWN_ERROR":
		return []errs.ErrorCode{errs.ErrInternal}, nil
	case "SIG_NULLDUMMY":
		return []errs.ErrorCode{errs.ErrSigNullDummy}, nil
	case "SIG_PUSHONLY":
		return []errs.ErrorCode{errs.ErrNotPushOnly}, nil
	case "CLEANSTACK":
		return []errs.ErrorCode{errs.ErrCleanStack}, nil
	case "BAD_OPCODE":
		return []errs.ErrorCode{errs.ErrReservedOpcode, errs.ErrMalformedPush}, nil
	case "UNBALANCED_CONDITIONAL":
		return []errs.ErrorCode{
			errs.ErrUnbalancedConditional,
			errs.ErrInvalidStackOperation,
		}, nil
	case "OP_RETURN":
		return []errs.ErrorCode{errs.ErrEarlyReturn}, nil
	case "VERIFY":
		return []errs.ErrorCode{errs.ErrVerify}, nil
	case "INVALID_STACK_OPERATION", "INVALID_ALTSTACK_OPERATION":
		return []errs.ErrorCode{errs.ErrInvalidStackOperation}, nil
	case "DISABLED_OPCODE":
		return []errs.ErrorCode{errs.ErrDisabledOpcode}, nil
	case "DISCOURAGE_UPGRADABLE_NOPS":
		return []errs.ErrorCode{errs.ErrDiscourageUpgradableNOPs}, nil
	case "SCRIPTNUM_OVERFLOW":
		return []errs.ErrorCode{errs.ErrNumberTooBig}, nil
	case "NUMBER_SIZE":
		return []errs.ErrorCode{errs.ErrNumberTooBig, errs.ErrNumberTooSmall}, nil
	case "PUSH_SIZE":
		// OP_NUM2BIN reports an out-of-range size as SCRIPT_ERR_PUSH_SIZE on
		// the node and as ErrNumberTooBig/ErrNumberTooSmall in the SDK.
		return []errs.ErrorCode{errs.ErrElementTooBig, errs.ErrNumberTooBig, errs.ErrNumberTooSmall}, nil
	case "OP_COUNT":
		return []errs.ErrorCode{errs.ErrTooManyOperations}, nil
	case "STACK_SIZE":
		return []errs.ErrorCode{errs.ErrStackOverflow}, nil
	case "SCRIPT_SIZE":
		return []errs.ErrorCode{errs.ErrScriptTooBig}, nil
	case "ELEMENT_SIZE":
		return []errs.ErrorCode{errs.ErrElementTooBig}, nil
	case "PUBKEY_COUNT":
		return []errs.ErrorCode{errs.ErrInvalidPubKeyCount}, nil
	case "SIG_COUNT":
		return []errs.ErrorCode{errs.ErrInvalidSignatureCount}, nil
	case "MINIMALDATA":
		return []errs.ErrorCode{errs.ErrMinimalData}, nil
	case "MINIMALIF":
		return []errs.ErrorCode{errs.ErrMinimalIf}, nil
	case "NEGATIVE_LOCKTIME":
		return []errs.ErrorCode{errs.ErrNegativeLockTime}, nil
	case "UNSATISFIED_LOCKTIME":
		return []errs.ErrorCode{errs.ErrUnsatisfiedLockTime}, nil
	case "SCRIPTNUM_MINENCODE":
		return []errs.ErrorCode{errs.ErrMinimalData}, nil
	case "DIV_BY_ZERO", "MOD_BY_ZERO":
		return []errs.ErrorCode{errs.ErrDivideByZero}, nil
	case "CHECKSIGVERIFY":
		return []errs.ErrorCode{errs.ErrCheckSigVerify}, nil
	case "ILLEGAL_FORKID":
		return []errs.ErrorCode{errs.ErrIllegalForkID}, nil
	}

	return nil, fmt.Errorf("unrecognized expected result in test data: %v",
		expected)
}

var errPanic = errors.New("interpreter reported an internal error")

// tally counts one file's rows: agree, divergent by class, RED.
type tally struct {
	agree, red int
	classes    map[string]int
	reds       []string
}

func newTally() *tally { return &tally{classes: map[string]int{}} }

// classes: the classifier's own class per (spend txid, column), read from the listing rules_check writes under
// RULES_CHECK_LIST (harness/src/bin/rules_check.rs, list_class): engine key, column, txid, class, entry id.
type classes map[string][]string

func loadClasses(root, list string) (classes, map[string]bool, error) {
	var rules struct {
		Classes map[string]json.RawMessage `json:"classes"`
	}
	b, err := os.ReadFile(filepath.Join(root, "harness", "rules", "go-sdk.json"))
	if err != nil {
		return nil, nil, err
	}
	if err := json.Unmarshal(b, &rules); err != nil {
		return nil, nil, err
	}
	known := map[string]bool{}
	for k := range rules.Classes {
		known[k] = true
	}
	w := classes{}
	fh, err := os.Open(list)
	if err != nil {
		return nil, nil, err
	}
	defer func() { _ = fh.Close() }()
	sc := bufio.NewScanner(fh)
	for sc.Scan() {
		f := strings.Split(sc.Text(), "\t")
		if len(f) != 5 || !strings.HasPrefix(f[0], "go-sdk@") {
			continue
		}
		col := map[string]string{"spec": "block", "spec-mempool": "relay"}[f[1]]
		if col == "" {
			continue
		}
		w[f[2]+"|"+col] = append(w[f[2]+"|"+col], f[3])
	}
	return w, known, sc.Err()
}

// txid of a transaction's hex, in display order
func txid(txHex string) string {
	b, err := hex.DecodeString(txHex)
	if err != nil {
		return ""
	}
	return hex.EncodeToString(util.ReverseBytes(crypto.Sha256d(b)))
}

func (t *tally) judge(w classes, known map[string]bool, file, id, tx, col string, want, got, matches bool, detail string) {
	verdict := func(v bool) string {
		if v {
			return "valid"
		}
		return "invalid"
	}
	if matches {
		t.agree++
		fmt.Printf("ROW %s %s %s file=%s sdk=%s AGREE\n", file, id, col, verdict(want), verdict(got))
		return
	}
	for _, c := range w[txid(tx)+"|"+col] {
		if known[c] && want != got {
			t.classes[c]++
			fmt.Printf("ROW %s %s %s file=%s sdk=%s DIVERGE class=%s (%s)\n", file, id, col, verdict(want), verdict(got), c, detail)
			return
		}
	}
	t.red++
	t.reds = append(t.reds, id+" "+col)
	fmt.Printf("ROW %s %s %s file=%s sdk=%s RED no class (%s)\n", file, id, col, verdict(want), verdict(got), detail)
}

func execute(tx *transaction.Transaction, prev []*transaction.TransactionOutput, flags scriptflag.Flag, mem int64) error {
	for i := range tx.Inputs {
		if err := interpreter.NewEngine().Execute(interpreter.WithTx(tx, i, prev[i]), interpreter.WithFlags(flags), interpreter.WithMaxStackMemory(mem)); err != nil {
			if errs.IsErrorCode(err, errs.ErrInternal) {
				return fmt.Errorf("input %d: %w: %w", i, errPanic, err)
			}
			return fmt.Errorf("input %d: %w", i, err)
		}
	}
	return nil
}

func nodeVectors(path, label string, w classes, known map[string]bool) (*tally, error) {
	b, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}
	var corpus struct {
		Vectors []nodeVector `json:"vectors"`
	}
	if err := json.Unmarshal(b, &corpus); err != nil {
		return nil, err
	}
	t := newTally()
	for _, v := range corpus.Vectors {
		tx, err := transaction.NewTransactionFromHex(v.Tx)
		if err != nil || len(v.Locks) != len(tx.Inputs) || len(v.Sats) != len(tx.Inputs) {
			return nil, fmt.Errorf("%s: the vector does not decode", v.ID)
		}
		prev := make([]*transaction.TransactionOutput, len(tx.Inputs))
		for i, in := range tx.Inputs {
			lock, err := hex.DecodeString(v.Locks[i])
			if err != nil {
				return nil, err
			}
			prev[i] = &transaction.TransactionOutput{LockingScript: script.NewFromBytes(lock), Satoshis: v.Sats[i]}
			in.SetSourceTxOutput(prev[i])
		}
		for _, r := range v.Results {
			word, err := strconv.ParseUint(r.Word, 0, 32)
			if err != nil {
				return nil, err
			}
			var flags scriptflag.Flag
			for bit := uint32(1); bit != 0; bit <<= 1 {
				if uint32(word)&bit == 0 {
					continue
				}
				f, ok := wordFlags[bit]
				if !ok {
					return nil, fmt.Errorf("%s: word bit 0x%x has no SDK counterpart", v.ID, bit)
				}
				flags |= f
			}
			mem := int64(interpreter.DefaultMaxStackMemory)
			col := "relay"
			if r.Consensus {
				mem, col = math.MaxInt64, "block"
			}
			sdkErr := execute(tx, prev, flags, mem)
			detail := fmt.Sprintf("node %s; sdk %v", r.NodeError, sdkErr)
			if errors.Is(sdkErr, errPanic) {
				return nil, sdkErr
			}
			if !r.Valid && sdkErr == nil && strings.HasPrefix(v.ID, "bsl:signer:") {
				fmt.Printf("NEW FINDING go-sdk/%s %s %s: verifier accepts node-refused signer transaction\n", label, v.ID, col)
			}
			t.judge(w, known, label, v.ID, v.Tx, col, r.Valid, sdkErr == nil, r.Valid == (sdkErr == nil), detail)
		}
	}
	return t, nil
}

// parseShortForm for the export's tokens: `0x<hex>` raw bytes (reference_test.go:111-115); empty is empty.
func shortForm(s string) (*script.Script, error) {
	var scr script.Script
	for _, tok := range strings.Fields(s) {
		if !strings.HasPrefix(tok, "0x") {
			return nil, fmt.Errorf("token %q is not a 0x token", tok)
		}
		b, err := hex.DecodeString(tok[2:])
		if err != nil {
			return nil, err
		}
		scr = append(scr, b...)
	}
	return &scr, nil
}

// createSpendingTx, reference_test.go:397-429
func spendingTx(sig, pk *script.Script, amount int64, version uint32) *transaction.Transaction {
	coinbase := transaction.NewTransaction()
	coinbase.AddInput(&transaction.TransactionInput{SourceTXID: &chainhash.Hash{}, SourceTxOutIndex: ^uint32(0),
		UnlockingScript: script.NewFromBytes([]byte{script.Op0, script.Op0}), SequenceNumber: 0xffffffff})
	coinbase.AddOutput(&transaction.TransactionOutput{Satoshis: uint64(amount), LockingScript: pk}) //nolint:gosec // non-negative amounts
	spend := &transaction.Transaction{Version: version, Inputs: []*transaction.TransactionInput{{
		SourceTXID: coinbase.TxID(), SourceTxOutIndex: 0, UnlockingScript: sig, SequenceNumber: 0xffffffff}},
		Outputs: []*transaction.TransactionOutput{{Satoshis: uint64(amount), LockingScript: script.NewFromBytes([]byte{})}}} //nolint:gosec // non-negative amounts
	spend.Inputs[0].SetSourceTxOutput(&transaction.TransactionOutput{LockingScript: pk})
	return spend
}

func scriptTests(path string, w classes, known map[string]bool) (*tally, error) {
	b, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}
	var tests [][]any
	if err := json.Unmarshal(b, &tests); err != nil {
		return nil, err
	}
	t := newTally()
	for _, test := range tests {
		if len(test) == 1 {
			continue // a comment row (reference_test.go:449)
		}
		// parseScriptTest (:150-201) for the export's 7-field row: [[amount], version, sig, pk, flags, result, comment]
		if len(test) != 7 {
			return nil, fmt.Errorf("expected 7 fields, got %d", len(test))
		}
		wit, ok := test[0].([]any)
		if !ok || len(wit) == 0 || len(test) != 7 {
			return nil, fmt.Errorf("row shape: %v", test)
		}
		f, _ := wit[0].(float64)
		amount := int64(math.Round(f * 1e8))
		strs := make([]string, 6)
		for i := range strs {
			s, ok := test[i+1].(string)
			if !ok {
				return nil, fmt.Errorf("field %d is not a string", i)
			}
			strs[i] = s
		}
		v, err := strconv.ParseInt(strs[0], 10, 32)
		if err != nil {
			return nil, err
		}
		sig, err := shortForm(strs[1])
		if err != nil {
			return nil, err
		}
		pk, err := shortForm(strs[2])
		if err != nil {
			return nil, err
		}
		var flags scriptflag.Flag
		for _, n := range strings.Split(strs[3], ",") {
			fl, ok := nameFlags[n]
			if !ok {
				return nil, fmt.Errorf("invalid flag %s", n)
			}
			flags |= fl
		}
		if flags.HasFlag(scriptflag.VerifyCleanStack) {
			flags |= scriptflag.Bip16
		}
		allowed, parseErr := parseExpectedResult(strs[4])
		if parseErr != nil {
			return nil, parseErr
		}
		tx := spendingTx(sig, pk, amount, uint32(int32(v)))                                                                                                                         //nolint:gosec // nVersion is a signed int32 on the wire
		err = interpreter.NewEngine().Execute(interpreter.WithTx(tx, 0, &transaction.TransactionOutput{LockingScript: pk, Satoshis: uint64(amount)}), interpreter.WithFlags(flags)) //nolint:gosec // non-negative amounts
		idFields := strings.Fields(strs[5])
		if len(idFields) == 0 {
			return nil, errors.New("missing script row id")
		}
		id := idFields[0]
		matches := strs[4] == "OK" && err == nil
		for _, code := range allowed {
			matches = matches || errs.IsErrorCode(err, code)
		}
		// the spend's own transaction, for the class lookup: the comment's id is bsl:<corpus>:<entry>
		t.judge(w, known, "script_tests.json", id, txOf[id], "block", strs[4] == "OK", err == nil, matches, fmt.Sprintf("file %s; sdk %v", strs[4], err))
	}
	return t, nil
}

// txOf maps a vector id to its transaction hex, filled from node_vectors.json (the same ids).
var txOf = map[string]string{}

func sighash(path string) (*tally, error) {
	b, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}
	var file struct {
		Vectors []struct {
			ID       string         `json:"id"`
			Input    map[string]any `json:"input"`
			Expected map[string]any `json:"expected"`
		} `json:"vectors"`
	}
	if err := json.Unmarshal(b, &file); err != nil {
		return nil, err
	}
	t := newTally()
	for _, v := range file.Vectors {
		str := func(m map[string]any, k string) string { s, _ := m[k].(string); return s }
		num := func(k string) float64 { n, _ := v.Input[k].(float64); return n }
		tx, err := transaction.NewTransactionFromHex(str(v.Input, "tx_hex"))
		if err != nil {
			return nil, err
		}
		idx := int(num("input_index"))
		sub, err := script.NewFromHex(str(v.Input, "script_hex"))
		if err != nil {
			return nil, err
		}
		tx.Inputs[idx].SetSourceTxOutput(&transaction.TransactionOutput{LockingScript: sub, Satoshis: 0})
		ht := uint32(int32(num("hash_type"))) //nolint:gosec // the bit pattern, as the loader keeps it (:544)
		ignore := false
		if srcs, ok := v.Input["sources"].([]any); ok {
			for _, s := range srcs {
				ignore = ignore || s == "teranode"
			}
		}
		regular, err := tx.CalcInputSignatureHashFull(uint32(idx), ht, ignore) //nolint:gosec // idx from the file
		if err != nil {
			return nil, err
		}
		pre, err := tx.CalcInputPreimageLegacyFull(uint32(idx), ht) //nolint:gosec // idx from the file
		if err != nil {
			return nil, err
		}
		original := pre
		sentinel := make([]byte, 32)
		sentinel[0] = 1
		if !bytes.Equal(pre, sentinel) {
			original = crypto.Sha256d(pre)
		}
		gotR, gotO := hex.EncodeToString(util.ReverseBytes(regular)), hex.EncodeToString(util.ReverseBytes(original))
		ok := gotR == str(v.Expected, "regular_hash") && gotO == str(v.Expected, "original_hash")
		if ok {
			t.agree++
			fmt.Printf("ROW evaluation.json %s node-sighash file=%s sdk=%s AGREE\n", v.ID, str(v.Expected, "regular_hash"), gotR)
		} else {
			t.red++
			t.reds = append(t.reds, v.ID)
			fmt.Printf("ROW evaluation.json %s node-sighash file=%s/%s sdk=%s/%s RED\n", v.ID, str(v.Expected, "regular_hash"), str(v.Expected, "original_hash"), gotR, gotO)
		}
	}
	return t, nil
}

// Validate all files before executing a row. Comment rows do not count as tests.
func validateCoverage(root string) error {
	dir := filepath.Join(root, "corpus", "fixtures")
	var manifest struct {
		Files map[string]map[string]json.RawMessage `json:"files"`
	}
	b, err := os.ReadFile(filepath.Join(dir, "manifest.json"))
	if err != nil {
		return err
	}
	if err := json.Unmarshal(b, &manifest); err != nil {
		return err
	}
	for _, name := range []string{"node_vectors.json", "script_tests.json", "evaluation.json", "signer/node_vectors.json"} {
		key := "go-sdk/" + name
		b, err := os.ReadFile(filepath.Join(dir, key))
		if err != nil {
			return err
		}
		counts := map[string]int{}
		if name == "script_tests.json" {
			var tests [][]any
			if err := json.Unmarshal(b, &tests); err != nil {
				return err
			}
			counts["rows"] = 0
			for _, row := range tests {
				if len(row) != 1 {
					counts["rows"]++
				}
			}
		} else {
			var file struct {
				Vectors []struct {
					Results []nodeResult `json:"results"`
					Input   struct {
						Kind string `json:"fixture_type"`
					} `json:"input"`
				} `json:"vectors"`
			}
			if err := json.Unmarshal(b, &file); err != nil {
				return err
			}
			counts["vectors"] = len(file.Vectors)
			for _, v := range file.Vectors {
				if filepath.Base(name) == "node_vectors.json" {
					if len(v.Results) == 0 {
						return fmt.Errorf("%s: empty results", key)
					}
					counts["results"] += len(v.Results)
				} else {
					if v.Input.Kind != "node-sighash" {
						return fmt.Errorf("%s: unsupported class %q", key, v.Input.Kind)
					}
					counts["node-sighash"]++
				}
			}
		}
		for field, n := range counts {
			var expected int
			if err := json.Unmarshal(manifest.Files[key][field], &expected); err != nil || n <= 0 || expected != n {
				return fmt.Errorf("%s: %s coverage %d, manifest %d (must be positive and equal)", key, field, n, expected)
			}
		}
		for field := range manifest.Files[key] {
			if strings.HasPrefix(field, "node-") && counts[field] == 0 {
				return fmt.Errorf("%s: missing advertised class %s", key, field)
			}
		}
	}
	return nil
}

func main() {
	root := flag.String("root", "../../..", "the repository root")
	list := flag.String("classes", "", "the RULES_CHECK_LIST file rules_check wrote for this tree")
	flag.Parse()
	if err := validateCoverage(*root); err != nil {
		fmt.Fprintln(os.Stderr, "fixtures: RED:", err)
		os.Exit(2)
	}
	dir := filepath.Join(*root, "corpus", "fixtures", "go-sdk")
	w, known, err := loadClasses(*root, *list)
	if err != nil {
		fmt.Fprintln(os.Stderr, "fixtures: RED:", err)
		os.Exit(2)
	}
	// the ids' transactions, for script_tests.json's class lookup
	if b, err := os.ReadFile(filepath.Join(dir, "node_vectors.json")); err == nil {
		var c struct {
			Vectors []nodeVector `json:"vectors"`
		}
		if json.Unmarshal(b, &c) == nil {
			for _, v := range c.Vectors {
				txOf[v.ID] = v.Tx
			}
		}
	}
	type run struct {
		name string
		f    func() (*tally, error)
	}
	runs := []run{
		{"node_vectors.json", func() (*tally, error) {
			return nodeVectors(filepath.Join(dir, "node_vectors.json"), "node_vectors.json", w, known)
		}},
		{"script_tests.json", func() (*tally, error) { return scriptTests(filepath.Join(dir, "script_tests.json"), w, known) }},
		{"evaluation.json", func() (*tally, error) { return sighash(filepath.Join(dir, "evaluation.json")) }},
		{"signer/node_vectors.json", func() (*tally, error) {
			return nodeVectors(filepath.Join(dir, "signer/node_vectors.json"), "signer/node_vectors.json", w, known)
		}},
	}
	red := 0
	for _, r := range runs {
		t, err := r.f()
		if err != nil {
			fmt.Fprintf(os.Stderr, "fixtures: RED: %s: %v\n", r.name, err)
			os.Exit(2)
		}
		keys := make([]string, 0, len(t.classes))
		div := 0
		for k, n := range t.classes {
			keys = append(keys, k)
			div += n
		}
		sort.Strings(keys)
		parts := make([]string, 0, len(keys))
		for _, k := range keys {
			parts = append(parts, fmt.Sprintf("%s %d", k, t.classes[k]))
		}
		fmt.Printf("SUMMARY go-sdk/%s: %d rows, agree %d, divergent by class %d [%s], RED %d\n",
			r.name, t.agree+div+t.red, t.agree, div, strings.Join(parts, "; "), t.red)
		for _, id := range t.reds {
			fmt.Printf("RED go-sdk/%s %s\n", r.name, id)
		}
		red += t.red
	}
	if red > 0 {
		os.Exit(1)
	}
}
