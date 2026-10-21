// bsv-script-lean #144 (lane xsig-144): go-sdk v1.7.2's SIGNER side for the checksig-in-unlock witness.
//
// One JSON request on stdin, one JSON reply on stdout. The transaction's input `input` is given its source
// output (satoshis, locking script) by SetSourceTxOutput, as a wallet does, and then:
//   - template_sig: the leading push of transaction/template/p2pkh's Unlock(key, nil).Sign(tx, input): the digest is
//     CalcInputSignatureHash (p2pkh.go:85), whose BIP143 preimage embeds the source output's locking script
//     (signaturehash.go:277); the signature a toolkit gets from the SDK's documented signing path;
//   - preimage_lock: CalcInputPreimage(input, ALL|FORKID), the preimage over the locking script alone;
//   - preimage_sub, sighash_sub: the same two calls after the source output's locking script is SUBSTITUTED by the
//     caller's scriptCode (SetSourceTxOutput with the scriptCode; SourceTxOutput falls back to it when no
//     SourceTransaction is attached, input.go:43-51). The digest reads SourceTxOutput().LockingScript; set it to the
//     scriptCode (via SetSourceTxOutput with no SourceTransaction, as here, or by swapping the field in place as
//     go-sdk's own test signer does, chronicle_sighash_test.go:32-43) and call CalcInputSignatureHash/CalcInputPreimage.
package main

import (
	"encoding/hex"
	"encoding/json"
	"fmt"
	"os"

	ec "github.com/bsv-blockchain/go-sdk/primitives/ec"
	"github.com/bsv-blockchain/go-sdk/script"
	"github.com/bsv-blockchain/go-sdk/transaction"
	sighash "github.com/bsv-blockchain/go-sdk/transaction/sighash"
	"github.com/bsv-blockchain/go-sdk/transaction/template/p2pkh"
)

type request struct {
	Tx         string `json:"tx"`
	Input      uint32 `json:"input"`
	Lock       string `json:"lock"`
	Satoshis   uint64 `json:"satoshis"`
	Key        string `json:"key"`
	ScriptCode string `json:"script_code"`
}

type reply struct {
	TemplateSig  string `json:"template_sig"`
	PreimageLock string `json:"preimage_lock"`
	SighashLock  string `json:"sighash_lock"`
	PreimageSub  string `json:"preimage_sub"`
	SighashSub   string `json:"sighash_sub"`
}

func scriptOf(h string) (*script.Script, error) {
	b, err := hex.DecodeString(h)
	if err != nil {
		return nil, err
	}
	return script.NewFromBytes(b), nil
}

func run() (*reply, error) {
	var req request
	if err := json.NewDecoder(os.Stdin).Decode(&req); err != nil {
		return nil, err
	}
	tx, err := transaction.NewTransactionFromHex(req.Tx)
	if err != nil {
		return nil, err
	}
	if int(req.Input) >= len(tx.Inputs) {
		return nil, fmt.Errorf("input %d out of range", req.Input)
	}
	lock, err := scriptOf(req.Lock)
	if err != nil {
		return nil, err
	}
	sub, err := scriptOf(req.ScriptCode)
	if err != nil {
		return nil, err
	}
	kb, err := hex.DecodeString(req.Key)
	if err != nil {
		return nil, err
	}
	// PrivateKeyFromBytes returns (*PrivateKey, *PublicKey) and no error (privatekey.go:46), so the key is checked here.
	if len(kb) != 32 {
		return nil, fmt.Errorf("key: %d bytes, want 32", len(kb))
	}
	key, _ := ec.PrivateKeyFromBytes(kb)
	if key.D.Sign() == 0 || key.D.Cmp(ec.S256().N) >= 0 {
		return nil, fmt.Errorf("key: the scalar is not in [1, n-1]")
	}
	in := tx.Inputs[req.Input]
	in.SourceTransaction = nil
	shf := sighash.AllForkID
	out := &reply{}

	in.SetSourceTxOutput(&transaction.TransactionOutput{Satoshis: req.Satoshis, LockingScript: lock})
	unlocker, err := p2pkh.Unlock(key, nil)
	if err != nil {
		return nil, err
	}
	signed, err := unlocker.Sign(tx, req.Input)
	if err != nil {
		return nil, err
	}
	chunks, err := signed.Chunks()
	if err != nil || len(chunks) != 2 {
		return nil, fmt.Errorf("the template's unlocking script is not <sig> <pubkey>: %v", err)
	}
	out.TemplateSig = hex.EncodeToString(chunks[0].Data)
	pre, err := tx.CalcInputPreimage(req.Input, shf)
	if err != nil {
		return nil, err
	}
	out.PreimageLock = hex.EncodeToString(pre)
	sh, err := tx.CalcInputSignatureHash(req.Input, shf)
	if err != nil {
		return nil, err
	}
	out.SighashLock = hex.EncodeToString(sh)

	in.SetSourceTxOutput(&transaction.TransactionOutput{Satoshis: req.Satoshis, LockingScript: sub})
	if pre, err = tx.CalcInputPreimage(req.Input, shf); err != nil {
		return nil, err
	}
	out.PreimageSub = hex.EncodeToString(pre)
	if sh, err = tx.CalcInputSignatureHash(req.Input, shf); err != nil {
		return nil, err
	}
	out.SighashSub = hex.EncodeToString(sh)
	return out, nil
}

func main() {
	out, err := run()
	if err != nil {
		fmt.Fprintln(os.Stderr, "gosign:", err)
		os.Exit(1)
	}
	if err := json.NewEncoder(os.Stdout).Encode(out); err != nil {
		os.Exit(1)
	}
}
