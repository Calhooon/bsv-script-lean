package main

import (
	"bytes"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"strings"
	"testing"

	ec "github.com/bsv-blockchain/go-sdk/primitives/ec"
	"github.com/bsv-blockchain/go-sdk/script"
	"github.com/bsv-blockchain/go-sdk/script/interpreter"
	"github.com/bsv-blockchain/go-sdk/script/interpreter/scriptflag"
	"github.com/bsv-blockchain/go-sdk/transaction"
)

// Public synthetic scalar, not wallet material. Use the generator point so the
// expected public key and P2PKH lock are independent of the adapter's parser.
const testPub = "0279be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798"
const testLock = "76a914751e76e8199196d454941c45d1b3a323f1433bd688ac"

func fixture(t *testing.T) entry {
	t.Helper()
	var e entry
	raw := fmt.Sprintf(`{"id":"test","tx":"0200000001%s0000000000ffffffff01e803000000000000015100000000",
"prevouts":[{"txid":"%s","vout":0,"script":"%s","satoshis":2000}],
"signing":{"version":2,"locktime":42,"inputs":[{"index":0,"template":"p2pkh","privkeys":["%s01"],
"pubkeys":["%s"],"sighash_type":65,"sequence":4294967294,"scriptcode_hex":["%s"],"sig_sites":[0],"unlock_template":"<sig0><pub0>"}]}}`,
		strings.Repeat("11", 32), strings.Repeat("11", 32), testLock, strings.Repeat("00", 31), testPub, testLock)
	if err := json.Unmarshal([]byte(raw), &e); err != nil {
		t.Fatal(err)
	}
	return e
}

func signed(t *testing.T, e entry, method string) (result, *transaction.Transaction) {
	t.Helper()
	r := signRow(e, method)
	if r.TxHex == nil {
		t.Fatalf("%s: %s", method, r.Note)
	}
	tx, err := transaction.NewTransactionFromHex(*r.TxHex)
	if err != nil {
		t.Fatal(err)
	}
	return r, tx
}

func TestP2PKHPathsAndSighashes(t *testing.T) {
	for _, hashType := range []uint32{1, 2, 3, 129, 130, 131, 65, 66, 67, 193, 194, 195, 97, 98, 99, 225, 226, 227} {
		t.Run(fmt.Sprint(hashType), func(t *testing.T) {
			e := fixture(t)
			e.Signing.Inputs[0].SighashType = &hashType
			var previous string
			for _, method := range methods {
				r, tx := signed(t, e, method)
				if previous != "" && previous != *r.TxHex {
					t.Fatal("the public paths disagree for the same P2PKH input")
				}
				previous = *r.TxHex
				if tx.Version != 2 || tx.LockTime != 42 || tx.Inputs[0].SequenceNumber != 4294967294 {
					t.Fatal("version, locktime or sequence was not applied")
				}
				chunks, err := tx.Inputs[0].UnlockingScript.Chunks()
				if err != nil || len(chunks) != 2 {
					t.Fatalf("unlock chunks: %v", err)
				}
				sigBytes := chunks[0].Data
				if uint32(sigBytes[len(sigBytes)-1]) != hashType {
					t.Fatal("signature trailer does not preserve the requested sighash byte")
				}
				sig, err := ec.ParseDERSignature(sigBytes[:len(sigBytes)-1])
				if err != nil {
					t.Fatal(err)
				}
				pub, _ := ec.PublicKeyFromString(testPub)
				digest, _ := hex.DecodeString(r.Inputs[0].DigestHex)
				preimage, _ := hex.DecodeString(r.Inputs[0].PreimageHex)
				h := sha256.Sum256(preimage)
				h = sha256.Sum256(h[:])
				if !bytes.Equal(h[:], digest) {
					t.Fatal("recorded preimage does not hash to the signed digest")
				}
				if !sig.Verify(digest, pub) {
					t.Fatal("signature is not over the recorded digest")
				}
				if again := signRow(e, method); again.TxHex == nil || *again.TxHex != *r.TxHex {
					t.Fatal("signatures are not deterministic")
				}
			}
		})
	}
}

func TestScriptCodeOverrideAndExecutionOrder(t *testing.T) {
	e := fixture(t)
	in := &e.Signing.Inputs[0]
	in.Template = "checksig-in-unlock-a"
	in.Privkeys = append(in.Privkeys, in.Privkeys[0])
	in.Pubkeys = append(in.Pubkeys, in.Pubkeys[0])
	in.SigSites = []uint32{0, 1}
	in.ScriptCodeHex = []string{"21" + testPub + "ad" + testLock, testLock}
	in.UnlockTemplate = "<sig1><pub0><sig0>ab<pub0>ad"
	defaultResult, defaultTx := signed(t, e, "api-default")
	override, overrideTx := signed(t, e, "api-scriptcode")
	if len(override.Inputs) != 2 || override.Inputs[0].DigestHex == defaultResult.Inputs[0].DigestHex || override.Inputs[1] != defaultResult.Inputs[1] {
		t.Fatal("scriptCode substitution did not stay local to its execution site")
	}
	lock, _ := script.NewFromHex(testLock)
	coin := &transaction.TransactionOutput{LockingScript: lock, Satoshis: 2000}
	flags := scriptflag.Chronicle | scriptflag.Genesis | scriptflag.UTXOAfterGenesis | scriptflag.UTXOAfterChronicle | scriptflag.EnableSighashForkID
	if err := interpreter.NewEngine().Execute(interpreter.WithTx(overrideTx, 0, coin), interpreter.WithFlags(flags)); err != nil {
		t.Fatalf("the explicit scriptCode signature does not execute: %v", err)
	}
	if err := interpreter.NewEngine().Execute(interpreter.WithTx(defaultTx, 0, coin), interpreter.WithFlags(flags)); err == nil {
		t.Fatal("locking-script-only signature unexpectedly verifies in the unlocking script")
	}
	if r := signRow(e, "template"); r.TxHex != nil || !strings.Contains(r.Note, "no public") {
		t.Fatal("invented a template for CHECKSIG in the unlock")
	}
}

func TestMultisigAndMissingTemplate(t *testing.T) {
	e := fixture(t)
	in := &e.Signing.Inputs[0]
	in.Template = "multisig-2-of-2"
	in.Privkeys = append(in.Privkeys, in.Privkeys[0])
	in.Pubkeys = append(in.Pubkeys, in.Pubkeys[0])
	in.SigSites = []uint32{0, 0}
	e.Prevouts[0].Script = "5221" + testPub + "21" + testPub + "52ae"
	in.ScriptCodeHex = []string{e.Prevouts[0].Script}
	in.UnlockTemplate = "00<sig0><sig1>"
	for _, method := range methods[1:] {
		_, tx := signed(t, e, method)
		lock, _ := script.NewFromHex(e.Prevouts[0].Script)
		coin := &transaction.TransactionOutput{LockingScript: lock, Satoshis: 2000}
		if err := interpreter.NewEngine().Execute(interpreter.WithTx(tx, 0, coin), interpreter.WithFlags(scriptflag.EnableSighashForkID)); err != nil {
			t.Fatal(err)
		}
	}
	if r := signRow(e, "template"); r.TxHex != nil || !strings.Contains(r.Note, "multisig-2-of-2") {
		t.Fatal("missing multisig template must be reported")
	}
}

func TestLegacySingleSentinel(t *testing.T) {
	e := fixture(t)
	tx, err := decode(e)
	if err != nil {
		t.Fatal(err)
	}
	tx.Outputs = nil
	e.Tx = hex.EncodeToString(tx.Bytes())
	sh := uint32(3)
	e.Signing.Inputs[0].SighashType = &sh
	r, _ := signed(t, e, "api-default")
	if r.Inputs[0].DigestHex != "01"+strings.Repeat("00", 31) || r.Inputs[0].PreimageHex != r.Inputs[0].DigestHex || !strings.Contains(r.Note, "sentinel") {
		t.Fatal("legacy SINGLE sentinel must not be rehashed")
	}
}

func TestVersionOneAndMultipleInputs(t *testing.T) {
	e := fixture(t)
	tx, err := decode(e)
	if err != nil {
		t.Fatal(err)
	}
	copyInput := *tx.Inputs[0]
	copyInput.SourceTxOutIndex = 1
	tx.Inputs = append(tx.Inputs, &copyInput)
	e.Tx = hex.EncodeToString(tx.Bytes())
	e.Prevouts = append(e.Prevouts, e.Prevouts[0])
	e.Prevouts[1].Vout = 1
	version, one, seq := uint32(1), uint32(1), uint32(123)
	e.Signing.Version = &version
	copySigning := e.Signing.Inputs[0]
	copySigning.Index, copySigning.Sequence = &one, &seq
	e.Signing.Inputs = []signingInput{copySigning, e.Signing.Inputs[0]}
	for _, method := range methods {
		r, tx := signed(t, e, method)
		if tx.Version != 1 || tx.Inputs[1].SequenceNumber != 123 || len(r.Inputs) != 2 || r.Inputs[0].Index != 0 || r.Inputs[1].Index != 1 || r.Inputs[0].DigestHex == r.Inputs[1].DigestHex {
			t.Fatal("multiple inputs or version one mishandled")
		}
	}
}

func TestBadRowsRemainVisibleAndDoNotStopStream(t *testing.T) {
	e := fixture(t)
	in := &e.Signing.Inputs[0]
	in.UnlockTemplate = "<missing0>"
	bad, _ := json.Marshal(e)
	good, _ := json.Marshal(fixture(t))
	stream := append(append(append([]byte("{broken json}\n"), bad...), '\n'), good...)
	var output bytes.Buffer
	if err := run(bytes.NewReader(stream), &output); err != nil {
		t.Fatal(err)
	}
	lines := bytes.Split(bytes.TrimSpace(output.Bytes()), []byte{'\n'})
	if len(lines) != 9 {
		t.Fatalf("got %d result rows, want 9", len(lines))
	}
	for i, line := range lines {
		var r result
		if err := json.Unmarshal(line, &r); err != nil {
			t.Fatal(err)
		}
		wantNull := i < 3 || i == 4 || i == 5
		if (r.TxHex == nil) != wantNull || r.Note == "" || r.Method != methods[i%3] {
			t.Fatalf("result %d: %+v", i, r)
		}
	}
}

func TestPreimagePushAndUnsignedRequirement(t *testing.T) {
	e := fixture(t)
	e.Signing.Inputs[0].UnlockTemplate = "<preimage0>75<sig0><pub0>"
	r, tx := signed(t, e, "api-default")
	chunks, err := tx.Inputs[0].UnlockingScript.Chunks()
	if err != nil || hex.EncodeToString(chunks[0].Data) != r.Inputs[0].PreimageHex {
		t.Fatal("OP_PUSH_TX token did not use the measured SDK preimage")
	}
	e.Tx = *r.TxHex
	for _, method := range methods {
		if r := signRow(e, method); r.TxHex != nil || !strings.Contains(r.Note, "empty unlocking") {
			t.Fatal("signed corpus input was silently accepted")
		}
	}
}

func TestKeyMapsToLaterSite(t *testing.T) {
	e := fixture(t)
	in := &e.Signing.Inputs[0]
	in.Template = "checksig-in-unlock-b"
	in.ScriptCodeHex = []string{"51", testLock}
	in.SigSites = []uint32{1}
	in.UnlockTemplate = "<preimage0>75<sig0><pub0>"
	r, tx := signed(t, e, "api-scriptcode")
	if len(r.Inputs) != 2 || r.Inputs[0].Site != 0 || r.Inputs[1].Site != 1 {
		t.Fatal("every site must have an explicit trace, even without a host signing key")
	}
	chunks, err := tx.Inputs[0].UnlockingScript.Chunks()
	if err != nil || len(chunks) != 4 || hex.EncodeToString(chunks[0].Data) != r.Inputs[0].PreimageHex {
		t.Fatal("preimage0 must use site 0")
	}
	sigBytes := chunks[2].Data
	sig, err := ec.ParseDERSignature(sigBytes[:len(sigBytes)-1])
	if err != nil {
		t.Fatal(err)
	}
	pub, _ := ec.PublicKeyFromString(testPub)
	digest, _ := hex.DecodeString(r.Inputs[1].DigestHex)
	other, _ := hex.DecodeString(r.Inputs[0].DigestHex)
	if !sig.Verify(digest, pub) || sig.Verify(other, pub) {
		t.Fatal("key 0 must sign site 1 from sig_sites")
	}
}

func TestFormatRejectionsApplyToEveryMethod(t *testing.T) {
	for _, bad := range []string{"pubkeys", "unlock_template", "unknown template", "sig_sites"} {
		t.Run(bad, func(t *testing.T) {
			e := fixture(t)
			in := &e.Signing.Inputs[0]
			switch bad {
			case "pubkeys":
				in.Pubkeys = nil
			case "unlock_template":
				in.UnlockTemplate = ""
			case "unknown template":
				in.Template = "version"
			case "sig_sites":
				in.SigSites = []uint32{1}
			}
			for _, method := range methods {
				r := signRow(e, method)
				if r.TxHex != nil || !strings.Contains(r.Note, bad) {
					t.Fatalf("%s accepted malformed %s: %+v", method, bad, r)
				}
			}
		})
	}
}
