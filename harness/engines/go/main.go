// bsv-script-lean #29: the go-sdk adapter (this repo's; docs/DESIGN.md §7, docs/PROVENANCE.md §1).
//
// One process, JSON lines: a request per corpus entry on stdin, a response per request on stdout.
// The reference's flag word (script_flags.h at the pin, bit by bit) is mapped to go-sdk's
// scriptflag.Flag by the table below; a bit go-sdk has no flag for is reported as unmapped, never
// silently dropped. Every input of the transaction is run in order through
// interpreter.Engine.Execute(WithTx(tx, i, prevout), WithFlags(flags)); the transaction's verdict is
// the first non-valid input's (DESIGN §6, Q5). The engine's own error code name (errs.ErrorCode.String())
// and message are returned verbatim; the harness maps the code to the reference's SCRIPT_ERR_* through
// its cited table (harness/src/gosdk_codes.rs). A panic or a transaction the engine cannot decode is
// `undecided`: a verdict about the adapter or the engine's parser, never about the script.
//
// Request:  {"id":..,"tx":"<hex>","prevouts":[{"script":"<hex>","satoshis":N},..],"runs":[{"key":"block","flags":[w,..]},..]}
// Response: {"id":..,"runs":{"block":{"verdict":"valid|invalid|undecided","input":i,"code":"ErrX","message":"..","engine_flags":[f,..],"unmapped_bits":[..]},..}}
package main

import (
	"bufio"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"runtime/debug"

	"github.com/bsv-blockchain/go-sdk/script"
	"github.com/bsv-blockchain/go-sdk/script/interpreter"
	"github.com/bsv-blockchain/go-sdk/script/interpreter/errs"
	"github.com/bsv-blockchain/go-sdk/script/interpreter/scriptflag"
	"github.com/bsv-blockchain/go-sdk/transaction"
)

type prevout struct {
	Script   string `json:"script"`
	Satoshis uint64 `json:"satoshis"`
}

type run struct {
	Key   string   `json:"key"`
	Flags []uint32 `json:"flags"`
}

type request struct {
	ID       string    `json:"id"`
	Tx       string    `json:"tx"`
	Prevouts []prevout `json:"prevouts"`
	Runs     []run     `json:"runs"`
}

type verdict struct {
	Verdict     string   `json:"verdict"`
	Input       *int     `json:"input,omitempty"`
	Code        string   `json:"code,omitempty"`
	Message     string   `json:"message,omitempty"`
	EngineFlags []uint32 `json:"engine_flags"`
	Unmapped    []string `json:"unmapped_bits,omitempty"`
}

type response struct {
	ID    string             `json:"id"`
	Runs  map[string]verdict `json:"runs"`
	Error string             `json:"error,omitempty"`
}

// The reference's flag bits (bitcoin-sv v1.2.3 src/script/script_flags.h:13–115)
// map to go-sdk v1.7.2 script/interpreter/scriptflag/scriptflag.go:8–111.
// Genesis and Chronicle carry the spend era separately from the UTXO-era bits.
// COMPRESSED_PUBKEYTYPE has no go-sdk flag and is reported as unmapped.
// VerifyBip143SigHash has no reference bit and is never set here.
type bitMap struct {
	bit    uint
	name   string
	flag   scriptflag.Flag
	mapped bool
}

var bits = []bitMap{
	{0, "SCRIPT_VERIFY_P2SH", scriptflag.Bip16, true},
	{1, "SCRIPT_VERIFY_STRICTENC", scriptflag.VerifyStrictEncoding, true},
	{2, "SCRIPT_VERIFY_DERSIG", scriptflag.VerifyDERSignatures, true},
	{3, "SCRIPT_VERIFY_LOW_S", scriptflag.VerifyLowS, true},
	{4, "SCRIPT_VERIFY_NULLDUMMY", scriptflag.StrictMultiSig, true},
	{5, "SCRIPT_VERIFY_SIGPUSHONLY", scriptflag.VerifySigPushOnly, true},
	{6, "SCRIPT_VERIFY_MINIMALDATA", scriptflag.VerifyMinimalData, true},
	{7, "SCRIPT_VERIFY_DISCOURAGE_UPGRADABLE_NOPS", scriptflag.DiscourageUpgradableNops, true},
	{8, "SCRIPT_VERIFY_CLEANSTACK", scriptflag.VerifyCleanStack, true},
	{9, "SCRIPT_VERIFY_CHECKLOCKTIMEVERIFY", scriptflag.VerifyCheckLockTimeVerify, true},
	{10, "SCRIPT_VERIFY_CHECKSEQUENCEVERIFY", scriptflag.VerifyCheckSequenceVerify, true},
	{13, "SCRIPT_VERIFY_MINIMALIF", scriptflag.VerifyMinimalIf, true},
	{14, "SCRIPT_VERIFY_NULLFAIL", scriptflag.VerifyNullFail, true},
	{15, "SCRIPT_VERIFY_COMPRESSED_PUBKEYTYPE", 0, false},
	{16, "SCRIPT_ENABLE_SIGHASH_FORKID", scriptflag.EnableSighashForkID, true},
	{18, "SCRIPT_GENESIS", scriptflag.Genesis, true},
	{19, "SCRIPT_UTXO_AFTER_GENESIS", scriptflag.UTXOAfterGenesis, true},
	{20, "SCRIPT_CHRONICLE", scriptflag.Chronicle, true},
	{21, "SCRIPT_UTXO_AFTER_CHRONICLE", scriptflag.UTXOAfterChronicle, true},
}

func goSdkVersion() string {
	if bi, ok := debug.ReadBuildInfo(); ok {
		for _, d := range bi.Deps {
			if d.Path == "github.com/bsv-blockchain/go-sdk" {
				if d.Replace != nil {
					return d.Version + " (replaced: " + d.Replace.Path + " " + d.Replace.Version + ")"
				}
				return d.Version
			}
		}
	}
	return "unknown (no build info)"
}

func mapWord(w uint32) (scriptflag.Flag, []string) {
	var f scriptflag.Flag
	var unmapped []string
	known := uint32(0)
	for _, b := range bits {
		known |= 1 << b.bit
		if w&(1<<b.bit) == 0 {
			continue
		}
		if b.mapped {
			f.AddFlag(b.flag)
		} else {
			unmapped = append(unmapped, b.name)
		}
	}
	if rest := w &^ known; rest != 0 {
		unmapped = append(unmapped, fmt.Sprintf("0x%x (no such reference bit)", rest))
	}
	return f, unmapped
}

func decodeTx(hexTx string, prevouts []prevout) (*transaction.Transaction, error) {
	raw, err := hex.DecodeString(hexTx)
	if err != nil {
		return nil, fmt.Errorf("tx hex: %w", err)
	}
	tx, err := transaction.NewTransactionFromBytes(raw)
	if err != nil {
		return nil, fmt.Errorf("tx decode: %w", err)
	}
	if len(tx.Inputs) != len(prevouts) {
		return nil, fmt.Errorf("%d inputs but %d prevouts", len(tx.Inputs), len(prevouts))
	}
	for i, p := range prevouts {
		lock, err := hex.DecodeString(p.Script)
		if err != nil {
			return nil, fmt.Errorf("prevout %d script hex: %w", i, err)
		}
		tx.Inputs[i].SetSourceTxOutput(&transaction.TransactionOutput{Satoshis: p.Satoshis, LockingScript: script.NewFromBytes(lock)})
	}
	return tx, nil
}

func runInput(tx *transaction.Transaction, i int, flags scriptflag.Flag) (v verdict) {
	defer func() {
		if r := recover(); r != nil {
			idx := i
			v = verdict{Verdict: "undecided", Input: &idx, Code: "panic", Message: fmt.Sprint(r)}
		}
	}()
	out := tx.Inputs[i].SourceTxOutput()
	// WithFlags uses the supplied word and names the coin's era (v1.7.2 options.go:152–174),
	// so the SDK's after-Chronicle default never applies here. Its default stack budget
	// remains 100,000,000 bytes on both columns (config.go:34–40): a policy default.
	err := interpreter.NewEngine().Execute(interpreter.WithTx(tx, i, out), interpreter.WithFlags(flags))
	if err == nil {
		return verdict{Verdict: "valid"}
	}
	idx := i
	var e errs.Error // a value type: errs.NewError returns Error, not *Error (v1.7.2 errs/error.go:442–467)
	if errors.As(err, &e) {
		return verdict{Verdict: "invalid", Input: &idx, Code: e.ErrorCode.String(), Message: e.Error()}
	}
	return verdict{Verdict: "undecided", Input: &idx, Code: "non-engine-error", Message: err.Error()}
}

func handle(req request) response {
	resp := response{ID: req.ID, Runs: map[string]verdict{}}
	for _, r := range req.Runs {
		// a fresh decode per run: the engine clones the transaction per signature check, but the
		// adapter never lets one run's state reach the next
		tx, err := decodeTx(req.Tx, req.Prevouts)
		if err != nil {
			resp.Runs[r.Key] = verdict{Verdict: "undecided", Code: "tx-decode", Message: err.Error()}
			continue
		}
		if len(r.Flags) != len(tx.Inputs) {
			resp.Runs[r.Key] = verdict{Verdict: "undecided", Code: "adapter", Message: fmt.Sprintf("%d inputs but %d flag words", len(tx.Inputs), len(r.Flags))}
			continue
		}
		var engineFlags []uint32
		var unmapped []string
		var result verdict
		result.Verdict = "valid"
		for i := range tx.Inputs {
			f, um := mapWord(r.Flags[i])
			engineFlags = append(engineFlags, uint32(f))
			for _, u := range um {
				seen := false
				for _, x := range unmapped {
					if x == u {
						seen = true
					}
				}
				if !seen {
					unmapped = append(unmapped, u)
				}
			}
			v := runInput(tx, i, f)
			if v.Verdict != "valid" {
				result = v
				break
			}
		}
		result.EngineFlags = engineFlags
		result.Unmapped = unmapped
		resp.Runs[r.Key] = result
	}
	return resp
}

func main() {
	if len(os.Args) > 1 && os.Args[1] == "--version" {
		// the go-sdk version this binary was BUILT with, from the build info (never a string typed here):
		// the harness compares it with docs/PROVENANCE.md §1a at every spawn
		fmt.Printf("gosdk-runner (bsv-script-lean #29) go-sdk %s (docs/PROVENANCE.md §1a)\n", goSdkVersion())
		return
	}
	in := bufio.NewReaderSize(os.Stdin, 1<<20)
	out := bufio.NewWriterSize(os.Stdout, 1<<20)
	defer out.Flush()
	dec := json.NewDecoder(in)
	enc := json.NewEncoder(out)
	for {
		var req request
		if err := dec.Decode(&req); err != nil {
			if err.Error() == "EOF" {
				return
			}
			fmt.Fprintf(os.Stderr, "gosdk-runner: request decode: %v\n", err)
			os.Exit(2)
		}
		if err := enc.Encode(handle(req)); err != nil {
			fmt.Fprintf(os.Stderr, "gosdk-runner: response encode: %v\n", err)
			os.Exit(2)
		}
		out.Flush()
	}
}
