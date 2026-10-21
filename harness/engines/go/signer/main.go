// The #145 signer column records go-sdk's public signing paths without repairing
// their output. The module and checksums are shared with the verifier runner.
package main

import (
	"bufio"
	"bytes"
	"encoding/hex"
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"io"
	"math/big"
	"os"
	"regexp"
	"runtime/debug"
	"strconv"
	"strings"

	ec "github.com/bsv-blockchain/go-sdk/primitives/ec"
	hash "github.com/bsv-blockchain/go-sdk/primitives/hash"
	"github.com/bsv-blockchain/go-sdk/script"
	"github.com/bsv-blockchain/go-sdk/transaction"
	sighash "github.com/bsv-blockchain/go-sdk/transaction/sighash"
	"github.com/bsv-blockchain/go-sdk/transaction/template/p2pkh"
)

var methods = []string{"template", "api-default", "api-scriptcode"}

var multisigTemplate = regexp.MustCompile(`^multisig-[1-9][0-9]*-of-[1-9][0-9]*$`)

func knownTemplate(name string) bool {
	return name == "p2pkh" || name == "p2pk" || name == "checksig-in-unlock-a" ||
		name == "checksig-in-unlock-b" || multisigTemplate.MatchString(name)
}

type signingInput struct {
	Index          *uint32  `json:"index"`
	Template       string   `json:"template"`
	Privkeys       []string `json:"privkeys"`
	Pubkeys        []string `json:"pubkeys"`
	SighashType    *uint32  `json:"sighash_type"`
	Sequence       *uint32  `json:"sequence"`
	ScriptCodeHex  []string `json:"scriptcode_hex"`
	SigSites       []uint32 `json:"sig_sites"`
	UnlockTemplate string   `json:"unlock_template"`
}

type entry struct {
	ID       string `json:"id"`
	Tx       string `json:"tx"`
	Prevouts []struct {
		TxID     string  `json:"txid"`
		Vout     uint32  `json:"vout"`
		Script   string  `json:"script"`
		Satoshis *uint64 `json:"satoshis"`
	} `json:"prevouts"`
	Signing *struct {
		Version  *uint32        `json:"version"`
		LockTime *uint32        `json:"locktime"`
		Inputs   []signingInput `json:"inputs"`
	} `json:"signing"`
}

type inputResult struct {
	Index             uint32 `json:"index"`
	Site              uint32 `json:"site"`
	PreimageHex       string `json:"preimage_hex"`
	DigestHex         string `json:"digest_hex"`
	ScriptCodeUsedHex string `json:"scriptcode_used_hex"`
}

type result struct {
	ID     string        `json:"id"`
	Engine string        `json:"engine"`
	Method string        `json:"method"`
	TxHex  *string       `json:"tx_hex"`
	Inputs []inputResult `json:"inputs"`
	Note   string        `json:"note"`
}

func emptyResult(id, method string) result {
	return result{ID: id, Engine: "go-sdk", Method: method, Inputs: []inputResult{}}
}

func decode(e entry) (*transaction.Transaction, error) {
	if e.ID == "" || e.Signing == nil || e.Signing.Version == nil || e.Signing.LockTime == nil {
		return nil, errors.New("id, signing.version and signing.locktime are required")
	}
	tx, err := transaction.NewTransactionFromHex(e.Tx)
	if err != nil {
		return nil, fmt.Errorf("unsigned tx: %w", err)
	}
	if len(tx.Inputs) == 0 || len(e.Prevouts) != len(tx.Inputs) || len(e.Signing.Inputs) != len(tx.Inputs) {
		return nil, errors.New("one prevout and one signing input required per transaction input")
	}
	for i, in := range tx.Inputs {
		if in.UnlockingScript != nil && len(*in.UnlockingScript) != 0 {
			return nil, fmt.Errorf("input %d: corpus transaction must have an empty unlocking script", i)
		}
		p := e.Prevouts[i]
		if in.SourceTXID == nil || !strings.EqualFold(p.TxID, in.SourceTXID.String()) || p.Vout != in.SourceTxOutIndex || p.Satoshis == nil {
			return nil, fmt.Errorf("input %d: missing value or prevout does not match the unsigned transaction", i)
		}
		lock, err := script.NewFromHex(p.Script)
		if err != nil {
			return nil, fmt.Errorf("input %d: prevout script: %w", i, err)
		}
		in.SourceTransaction = nil
		in.SetSourceTxOutput(&transaction.TransactionOutput{LockingScript: lock, Satoshis: *p.Satoshis})
	}
	seen := make(map[uint32]bool)
	for _, in := range e.Signing.Inputs {
		if in.Index == nil || int(*in.Index) >= len(tx.Inputs) || seen[*in.Index] {
			return nil, errors.New("signing input index missing, duplicated or out of range")
		}
		seen[*in.Index] = true
		if in.SighashType == nil || *in.SighashType > 255 || in.Sequence == nil {
			return nil, fmt.Errorf("input %d: byte sighash_type and sequence are required", *in.Index)
		}
		if !knownTemplate(in.Template) {
			return nil, fmt.Errorf("input %d: unknown template %q", *in.Index, in.Template)
		}
		if in.Pubkeys == nil || in.UnlockTemplate == "" {
			return nil, fmt.Errorf("input %d: pubkeys and unlock_template are required", *in.Index)
		}
		if len(in.ScriptCodeHex) == 0 || len(in.Privkeys) == 0 || len(in.SigSites) != len(in.Privkeys) || len(in.Pubkeys) != len(in.Privkeys) {
			return nil, fmt.Errorf("input %d: scriptcode_hex must list sites; pubkeys and sig_sites must match privkeys", *in.Index)
		}
		for _, site := range in.SigSites {
			if int(site) >= len(in.ScriptCodeHex) {
				return nil, fmt.Errorf("input %d: sig_sites index out of range", *in.Index)
			}
		}
		tx.Inputs[*in.Index].SequenceNumber = *in.Sequence
	}
	tx.Version, tx.LockTime = *e.Signing.Version, *e.Signing.LockTime
	return tx, nil
}

func privateKeys(in signingInput) ([]*ec.PrivateKey, error) {
	if len(in.Privkeys) == 0 {
		return nil, errors.New("no private keys supplied")
	}
	keys := make([]*ec.PrivateKey, len(in.Privkeys))
	for i, h := range in.Privkeys {
		b, err := hex.DecodeString(h)
		if err != nil || len(b) != 32 {
			return nil, fmt.Errorf("private key %d must be 32-byte hex", i)
		}
		d := new(big.Int).SetBytes(b)
		if d.Sign() == 0 || d.Cmp(ec.S256().N) >= 0 {
			return nil, fmt.Errorf("private key %d is outside the curve's scalar range", i)
		}
		keys[i], _ = ec.PrivateKeyFromBytes(b)
	}
	return keys, nil
}

// CalcInputPreimage is always BIP143 at this pin. Follow the digest API's
// selection (signaturehash.go:26-29, 89-116), using its exported legacy reader.
func measure(tx *transaction.Transaction, index uint32, sh sighash.Flag) (inputResult, error) {
	r := inputResult{Index: index, ScriptCodeUsedHex: hex.EncodeToString(*tx.Inputs[index].SourceTxScript())}
	digest, err := tx.CalcInputSignatureHash(index, sh)
	if err != nil {
		return r, err
	}
	var preimage []byte
	if sh.Has(sighash.ForkID) && !sh.Has(sighash.Chronicle) {
		preimage, err = tx.CalcInputPreimage(index, sh)
	} else {
		preimage, err = tx.CalcInputPreimageLegacy(index, sh)
	}
	if err != nil {
		return r, err
	}
	defaultHex := append([]byte{1}, make([]byte, 31)...)
	if !bytes.Equal(digest, defaultHex) && !bytes.Equal(hash.Sha256d(preimage), digest) {
		return r, errors.New("SDK preimage reader disagrees with CalcInputSignatureHash")
	}
	r.DigestHex, r.PreimageHex = hex.EncodeToString(digest), hex.EncodeToString(preimage)
	return r, err
}

// Each token expands to a complete SDK push, including its length prefix.
// Literal script bytes are copied exactly, never decoded and re-encoded.
func fillUnlock(pattern string, values map[string][]byte) (*script.Script, error) {
	var assembled []byte
	for len(pattern) != 0 {
		at := strings.IndexByte(pattern, '<')
		if at < 0 {
			at = len(pattern)
		}
		literal, err := hex.DecodeString(pattern[:at])
		if err != nil {
			return nil, errors.New("unlock_template contains non-hex literal bytes")
		}
		assembled = append(assembled, literal...)
		pattern = pattern[at:]
		if pattern == "" {
			break
		}
		end := strings.IndexByte(pattern, '>')
		if end < 0 {
			return nil, errors.New("unterminated unlock_template token")
		}
		token := pattern[1:end]
		value, ok := values[token]
		if !ok {
			return nil, fmt.Errorf("unsupported or unavailable unlock_template token <%s>", token)
		}
		push := &script.Script{}
		if err := push.AppendPushData(value); err != nil {
			return nil, err
		}
		assembled = append(assembled, *push...)
		pattern = pattern[end+1:]
	}
	return script.NewFromBytes(assembled), nil
}

func signInput(tx *transaction.Transaction, in signingInput, method string, r *result) error {
	index, sh := *in.Index, sighash.Flag(*in.SighashType)
	keys, err := privateKeys(in)
	if err != nil {
		return err
	}
	if method == "template" {
		if in.Template != "p2pkh" {
			return fmt.Errorf("go-sdk has no public %s unlocking template", in.Template)
		}
		if len(keys) != 1 {
			return errors.New("P2PKH template requires one private key")
		}
		m, err := measure(tx, index, sh)
		if err != nil {
			return err
		}
		r.Inputs = append(r.Inputs, m)
		unlocker, err := p2pkh.Unlock(keys[0], &sh)
		if err != nil {
			return err
		}
		// Use the complete template output, including the SDK's compressed key.
		tx.Inputs[index].UnlockingScript, err = unlocker.Sign(tx, index)
		return err
	}
	signatures := make([][]byte, len(in.ScriptCodeHex))
	values := make(map[string][]byte)
	actual := tx.Inputs[index].SourceTxOutput()
	for site, code := range in.ScriptCodeHex {
		if method == "api-scriptcode" {
			lock, err := script.NewFromHex(code)
			if err != nil {
				return fmt.Errorf("scriptCode site %d: %w", site, err)
			}
			tx.Inputs[index].SetSourceTxOutput(&transaction.TransactionOutput{LockingScript: lock, Satoshis: actual.Satoshis})
		}
		m, err := measure(tx, index, sh)
		if err != nil {
			return err
		}
		m.Site = uint32(site)
		r.Inputs = append(r.Inputs, m)
		signatures[site], _ = hex.DecodeString(m.DigestHex)
		values["preimage"+strconv.Itoa(site)], _ = hex.DecodeString(m.PreimageHex)
	}
	tx.Inputs[index].SetSourceTxOutput(actual)
	for k, key := range keys {
		site := in.SigSites[k]
		sig, err := key.Sign(signatures[site])
		if err != nil {
			return err
		}
		values["sig"+strconv.Itoa(k)] = append(sig.Serialize(), byte(sh))
	}
	for k, h := range in.Pubkeys {
		pub, err := hex.DecodeString(h)
		if err != nil {
			return fmt.Errorf("public key %d is not hex", k)
		}
		values["pub"+strconv.Itoa(k)] = pub
	}
	tx.Inputs[index].UnlockingScript, err = fillUnlock(in.UnlockTemplate, values)
	return err
}

func signRow(e entry, method string) (r result) {
	r = emptyResult(e.ID, method)
	defer func() {
		if p := recover(); p != nil {
			r.TxHex = nil
			r.Note = fmt.Sprintf("SDK panic: %v", p)
		}
	}()
	tx, err := decode(e)
	if err != nil {
		r.Note = err.Error()
		return r
	}
	// Keep input ordering independent of the ordering of signing descriptors.
	inputs := make([]signingInput, len(tx.Inputs))
	for _, in := range e.Signing.Inputs {
		inputs[*in.Index] = in
	}
	for _, in := range inputs {
		if err := signInput(tx, in, method, &r); err != nil {
			r.Note = fmt.Sprintf("input %d: %v", *in.Index, err)
			return r
		}
	}
	h := hex.EncodeToString(tx.Bytes())
	r.TxHex = &h
	r.Note = "SDK CalcInputSignatureHash and matching exported preimage reader; deterministic SDK RFC6979 signatures."
	for _, in := range r.Inputs {
		if in.PreimageHex == "0100000000000000000000000000000000000000000000000000000000000000" {
			r.Note += " Legacy SINGLE out-of-range: preimage_hex is the SDK sentinel, not a serialized preimage; digest is the un-hashed sentinel."
			break
		}
	}
	return r
}

func run(input io.Reader, output io.Writer) error {
	reader := bufio.NewReader(input)
	encoder := json.NewEncoder(output)
	for line := 1; ; line++ {
		b, readErr := reader.ReadBytes('\n')
		if len(bytes.TrimSpace(b)) != 0 {
			var e entry
			err := json.Unmarshal(b, &e)
			for _, method := range methods {
				var r result
				if err != nil {
					r = emptyResult(e.ID, method)
					r.Note = fmt.Sprintf("line %d: invalid corpus entry: %v", line, err)
				} else {
					r = signRow(e, method)
				}
				if err := encoder.Encode(r); err != nil {
					return err
				}
			}
		}
		if readErr != nil {
			if errors.Is(readErr, io.EOF) {
				return nil
			}
			return readErr
		}
	}
}

func sdkVersion() string {
	if info, ok := debug.ReadBuildInfo(); ok {
		for _, dep := range info.Deps {
			if dep.Path == "github.com/bsv-blockchain/go-sdk" {
				if dep.Replace != nil {
					return dep.Version + " (replaced by " + dep.Replace.Path + " " + dep.Replace.Version + ")"
				}
				return dep.Version
			}
		}
	}
	return "unknown"
}

func cli() error {
	corpus := flag.String("corpus", "-", "signer corpus JSONL file, or - for stdin")
	out := flag.String("out", "-", "output JSONL file, or - for stdout")
	version := flag.Bool("version", false, "print the linked SDK version")
	flag.Parse()
	if *version {
		fmt.Printf("gosdk-signer (bsv-script-lean #145) go-sdk %s\n", sdkVersion())
		return nil
	}
	if flag.NArg() != 0 {
		return errors.New("usage: gosdk-signer --corpus <file|-> --out <file|->")
	}
	input, output := os.Stdin, os.Stdout
	if *corpus != "-" {
		var err error
		input, err = os.Open(*corpus)
		if err != nil {
			return err
		}
		defer input.Close()
	}
	if *out != "-" {
		if a, err := input.Stat(); err == nil {
			if b, err := os.Stat(*out); err == nil && os.SameFile(a, b) {
				return errors.New("output must not overwrite the input corpus")
			}
		}
		var err error
		output, err = os.Create(*out)
		if err != nil {
			return err
		}
	}
	buffer := bufio.NewWriter(output)
	err := run(input, buffer)
	flushErr := buffer.Flush()
	if output != os.Stdout {
		err = errors.Join(err, output.Close())
	}
	return errors.Join(err, flushErr)
}

func main() {
	if err := cli(); err != nil {
		fmt.Fprintln(os.Stderr, "gosdk-signer:", err)
		os.Exit(2)
	}
}
