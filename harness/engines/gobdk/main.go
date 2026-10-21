// bsv-script-lean #28: the GoBDK shim (this repo's; docs/DESIGN.md §7, docs/PROVENANCE.md §1, the ruling D14).
//
// Teranode v0.16.0 validates scripts only through GoBDK: its go.mod:12 at the tag pins
// github.com/bitcoin-sv/bdk/module/gobdk at 4eab3acd (#54, 2026-10-06; v0.15.9's cdfa7814 until then), services/validator/TxValidator.go:115 constructs
// newScriptVerifierGoBDK, and the module's prebuilt libGoBDK carries bitcoin-sv v1.2.2 at 879fc8b42
// (docs/PROVENANCE.md §1; `--version` prints the version block the linked library reports). This adapter calls
// GoBDK's own entry point and nothing of Teranode's wrapper (never ValidateTransaction's standardness, sigops and
// fee checks, never the error remap of ScriptVerifierGoBDK.go:351–443):
//
//	TxValidator.VerifyScriptWithCustomFlags(extendedTX, utxoHeights, blockHeight, consensus, customFlags)
//
// (module/gobdk/script/txvalidator.go:120–142 at 4eab3acd; core/txvalidator.cpp:781–799 VerifyScript and
// 878–921 implVerifyScript: every input in order under customFlags[index] (905), the first failing input's error
// returned (917–918), the reference's ::VerifyScript through bsvVerifyScript 923–946 with the limits of
// make_verify_script_params(policySettings, flags, consensus) at 931).
//
// One process, JSON lines, the protocol of harness/engines/go/main.go (harness/src/engines.rs): a request per corpus
// entry on stdin, a response per request on stdout.
//
//	Request:  {"id":..,"tx":"<hex>","spend_height":N,"prevouts":[{"script":"<hex>","satoshis":N,"height":N},..],
//	           "runs":[{"key":"block","flags":[w,..],"consensus":true},{"key":"mempool","flags":[w,..],"consensus":false}]}
//	Response: {"id":..,"runs":{"block":{"verdict":"valid|invalid|undecided","input":0,"code":"SCRIPT_ERR_…",
//	           "message":"..","engine_flags":{"flags":[..],"consensus":..,"block_height":..,"utxo_heights":[..]}},..}}
//
// The words: every run carries the reference flag word of every input, the word the spec judged the same input
// under (harness/src/flags_oracle.rs asks eval/bsvs; this adapter derives no word), and the run's `consensus`
// boolean; a run without either is refused as `adapter`, never defaulted. The heights: utxoHeights[i] is the
// prevout's height; blockHeight is spend_height when consensus is true and spend_height − 1 when it is false
// (docs/DESIGN.md §6's convention; Teranode makes the same conversion, ScriptVerifierGoBDK.go:261–271). Under a
// custom word implVerifyScript reads blockHeight nowhere (CalculateFlags at 905 is skipped) and a utxo height only
// against MEMPOOL_HEIGHT in consensus mode (903–904), a height no corpus entry carries (DESIGN §6). Every run's
// response echoes the words, the boolean and the heights it passed (`engine_flags`).
//
// The modes: a run's `mode` is "flags" (the driver's) or absent, the words above; or, never sent by the driver, one
// of two DERIVED modes that carry no words and run under GoBDK's own (CalculateFlags, txvalidator.go:89, per input
// at the same heights; echoed as `engine_flags.flags` with `engine_flags.entry`): "gobdk-verify" calls VerifyScript
// (txvalidator.go:100), the script check alone; "gobdk-validate" calls ValidateTransaction (txvalidator.go:515), the
// call Teranode v0.16.0 makes (ScriptVerifierGoBDK.go:297). Any other mode is refused as `adapter`.
//
// The extended transaction (core/extendedTx.hpp:99–108): nVersion ‖ 00 00 00 00 00 EF ‖ CompactSize(n) ‖
// (CTxIn ‖ the prevout's CTxOut) × n ‖ the outputs vector ‖ nLockTime, built from the entry's raw transaction (framed
// by its CompactSize lengths, the input and output bytes copied verbatim, never a script parsed) and its prevouts.
//
// The verdict: no error is `valid`; a script-domain error is `invalid` with the reference's SCRIPT_ERR_* name through
// the cited table codes.go and the linked library's own text as the message; a DoS-domain error is `invalid` with
// GoBDK's DOS_ERR_* name; the exception domain is `undecided` with the code `exception` (the harness files an
// engine's abort on an entry the spec decides as a witness, D15). GoBDK returns ONE error and NO input index:
// `input` is reported only for a one-input transaction (index 0, the loop's only iteration); a multi-input entry
// gets no index here (the generator's single-input projections carry it, DESIGN §6). A panic, a frame the adapter
// cannot read or a request it cannot serve is `undecided` with an adapter code (`panic`, `tx-decode`, `adapter`).
package main

import (
	"bufio"
	"encoding/binary"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"math"
	"os"
	"runtime/debug"
	"strings"

	gobdk "github.com/bitcoin-sv/bdk/module/gobdk"
	"github.com/bitcoin-sv/bdk/module/gobdk/bdkcgo"
	bdkscript "github.com/bitcoin-sv/bdk/module/gobdk/script"
)

const modulePath = "github.com/bitcoin-sv/bdk/module/gobdk"

// the chain whose parameters the validator is created with: Teranode maps its "mainnet" to BDK's "main"
// (ScriptVerifierGoBDK.go:127–128); the policy settings stay GoBDK's defaults (`--describe` prints them)
const chainName = "main"

type prevout struct {
	Script   string `json:"script"`
	Satoshis uint64 `json:"satoshis"`
	Height   *int64 `json:"height"`
}

type run struct {
	Key       string   `json:"key"`
	Mode      string   `json:"mode"`
	Flags     []uint32 `json:"flags"`
	Consensus *bool    `json:"consensus"`
}

type request struct {
	ID          string    `json:"id"`
	Tx          string    `json:"tx"`
	SpendHeight *int64    `json:"spend_height"`
	Prevouts    []prevout `json:"prevouts"`
	Runs        []run     `json:"runs"`
}

// what a run passed to GoBDK, echoed so a record can say which boolean and which word each column passes; a derived
// run (the modes below) names the entry it called, and its flags are the words GoBDK's own CalculateFlags returns
type applied struct {
	Flags       []uint32 `json:"flags"`
	Consensus   bool     `json:"consensus"`
	BlockHeight int32    `json:"block_height"`
	UtxoHeights []int32  `json:"utxo_heights"`
	Entry       string   `json:"entry,omitempty"`
}

type verdict struct {
	Verdict     string   `json:"verdict"`
	Input       *int     `json:"input,omitempty"`
	Code        string   `json:"code,omitempty"`
	Message     string   `json:"message,omitempty"`
	EngineFlags *applied `json:"engine_flags,omitempty"`
}

type response struct {
	ID    string             `json:"id"`
	Runs  map[string]verdict `json:"runs"`
	Error string             `json:"error,omitempty"`
}

// readCompactSize reads a CompactSize at p and returns the value and the offset after it. Every encoding the
// four prefixes allow is read (a non-canonical length is left for GoBDK's own deserializer to judge: the bytes
// are copied verbatim).
func readCompactSize(b []byte, p int) (uint64, int, error) {
	if p >= len(b) {
		return 0, p, errors.New("truncated CompactSize")
	}
	switch c := b[p]; {
	case c < 0xfd:
		return uint64(c), p + 1, nil
	case c == 0xfd:
		if p+3 > len(b) {
			return 0, p, errors.New("truncated CompactSize (0xfd)")
		}
		return uint64(binary.LittleEndian.Uint16(b[p+1:])), p + 3, nil
	case c == 0xfe:
		if p+5 > len(b) {
			return 0, p, errors.New("truncated CompactSize (0xfe)")
		}
		return uint64(binary.LittleEndian.Uint32(b[p+1:])), p + 5, nil
	default:
		if p+9 > len(b) {
			return 0, p, errors.New("truncated CompactSize (0xff)")
		}
		return binary.LittleEndian.Uint64(b[p+1:]), p + 9, nil
	}
}

func writeCompactSize(out []byte, n uint64) []byte {
	switch {
	case n < 0xfd:
		return append(out, byte(n))
	case n <= 0xffff:
		out = append(out, 0xfd)
		return binary.LittleEndian.AppendUint16(out, uint16(n))
	case n <= 0xffffffff:
		out = append(out, 0xfe)
		return binary.LittleEndian.AppendUint32(out, uint32(n))
	default:
		out = append(out, 0xff)
		return binary.LittleEndian.AppendUint64(out, n)
	}
}

// skip returns p+n when n bytes remain at p
func skip(b []byte, p int, n uint64, what string) (int, error) {
	if n > uint64(len(b)-p) {
		return p, fmt.Errorf("truncated %s (%d bytes wanted, %d left)", what, n, len(b)-p)
	}
	return p + int(n), nil
}

// frame is the raw transaction cut at its field boundaries (primitives/transaction.h's serialization): the version,
// every CTxIn as it stands, the outputs vector with its count as it stands, the lock time.
type frame struct {
	version  []byte
	inputs   [][]byte
	outputs  []byte
	lockTime []byte
}

func frameOf(raw []byte) (frame, error) {
	var f frame
	if len(raw) < 4 {
		return f, errors.New("no version")
	}
	f.version = raw[:4]
	p := 4
	nin, p2, err := readCompactSize(raw, p)
	if err != nil {
		return f, fmt.Errorf("input count: %w", err)
	}
	p = p2
	for i := uint64(0); i < nin; i++ {
		start := p
		if p, err = skip(raw, p, 36, fmt.Sprintf("input %d outpoint", i)); err != nil {
			return f, err
		}
		var n uint64
		if n, p, err = readCompactSize(raw, p); err != nil {
			return f, fmt.Errorf("input %d scriptSig length: %w", i, err)
		}
		if p, err = skip(raw, p, n, fmt.Sprintf("input %d scriptSig", i)); err != nil {
			return f, err
		}
		if p, err = skip(raw, p, 4, fmt.Sprintf("input %d sequence", i)); err != nil {
			return f, err
		}
		f.inputs = append(f.inputs, raw[start:p])
	}
	ostart := p
	nout, p2, err := readCompactSize(raw, p)
	if err != nil {
		return f, fmt.Errorf("output count: %w", err)
	}
	p = p2
	for i := uint64(0); i < nout; i++ {
		if p, err = skip(raw, p, 8, fmt.Sprintf("output %d value", i)); err != nil {
			return f, err
		}
		var n uint64
		if n, p, err = readCompactSize(raw, p); err != nil {
			return f, fmt.Errorf("output %d script length: %w", i, err)
		}
		if p, err = skip(raw, p, n, fmt.Sprintf("output %d script", i)); err != nil {
			return f, err
		}
	}
	f.outputs = raw[ostart:p]
	if len(raw)-p != 4 {
		return f, fmt.Errorf("%d bytes after the outputs where the 4-byte lock time is expected", len(raw)-p)
	}
	f.lockTime = raw[p:]
	return f, nil
}

// extended builds the extended transaction of core/extendedTx.hpp:99–108 from the frame and the prevouts.
func extended(f frame, prevouts []prevout) ([]byte, error) {
	if len(f.inputs) != len(prevouts) {
		return nil, fmt.Errorf("%d inputs but %d prevouts", len(f.inputs), len(prevouts))
	}
	out := make([]byte, 0, 256)
	out = append(out, f.version...)
	out = append(out, 0x00, 0x00, 0x00, 0x00, 0x00, 0xEF) // the extended marker, extendedTx.hpp:101
	out = writeCompactSize(out, uint64(len(f.inputs)))
	for i, in := range f.inputs {
		lock, err := hex.DecodeString(prevouts[i].Script)
		if err != nil {
			return nil, fmt.Errorf("prevout %d script hex: %w", i, err)
		}
		if prevouts[i].Satoshis > math.MaxInt64 {
			return nil, fmt.Errorf("prevout %d satoshis above i64::MAX", i)
		}
		out = append(out, in...)                                          // the CTxIn as it stands
		out = binary.LittleEndian.AppendUint64(out, prevouts[i].Satoshis) // the CTxOut: nValue
		out = writeCompactSize(out, uint64(len(lock)))                    // and scriptPubKey
		out = append(out, lock...)
	}
	out = append(out, f.outputs...)
	out = append(out, f.lockTime...)
	return out, nil
}

func undecided(code, msg string) verdict {
	return verdict{Verdict: "undecided", Code: code, Message: msg}
}

// verify runs one request's run through GoBDK and reports the verdict in the harness's vocabulary.
func verify(se *bdkscript.TxValidator, ext []byte, nInputs int, a applied) (v verdict) {
	defer func() {
		if r := recover(); r != nil {
			v = undecided("panic", fmt.Sprint(r))
			v.EngineFlags = &a
		}
	}()
	var err error
	switch a.Entry {
	case "":
		err = se.VerifyScriptWithCustomFlags(ext, a.UtxoHeights, a.BlockHeight, a.Consensus, a.Flags)
	case "VerifyScript":
		err = se.VerifyScript(ext, a.UtxoHeights, a.BlockHeight, a.Consensus)
	case "ValidateTransaction":
		err = se.ValidateTransaction(ext, a.UtxoHeights, a.BlockHeight, a.Consensus)
	}
	v = classify(err, nInputs)
	v.EngineFlags = &a
	return v
}

// the derived modes: GoBDK's own words for the heights instead of the spec's (never sent by the driver, which sends
// "flags"). gobdk-verify calls VerifyScript (txvalidator.go:100; core/txvalidator.cpp:905 takes CalculateFlags when no
// custom word is given); gobdk-validate calls ValidateTransaction (txvalidator.go:515; core/txvalidator.cpp:1058–1109),
// the call Teranode v0.16.0 makes (services/validator/ScriptVerifierGoBDK.go:297): its transaction checks, in the
// policy column its standardness, sigops and fee checks, then implVerifyScript under the same derived words.
var derivedEntry = map[string]string{"gobdk-verify": "VerifyScript", "gobdk-validate": "ValidateTransaction"}

func classify(err error, nInputs int) verdict {
	if err == nil {
		return verdict{Verdict: "valid"}
	}
	var dosErr bdkscript.DoSError
	if errors.As(err, &dosErr) {
		r, ok := dosRowOf(dosErr.Code())
		if !ok {
			return undecided("gobdk-dos-code-outside-the-table", fmt.Sprintf("DoS code %d: %s", int(dosErr.Code()), err.Error()))
		}
		return verdict{Verdict: "invalid", Code: r.gobdk, Message: fmt.Sprintf("DoS %d %s: %s", int(r.code), r.gobdk, err.Error())}
	}
	var scriptErr bdkscript.ScriptError
	if errors.As(err, &scriptErr) {
		c := scriptErr.Code()
		if c == bdkscript.SCRIPT_ERR_CGO_EXCEPTION {
			return undecided("exception", fmt.Sprintf("GoBDK's exception domain (txvalidator.go:549–550; a C++ exception or the cancellation token, core/txvalidator.cpp:837–839, 939–940): %s", err.Error()))
		}
		r, ok := scriptRowOf(c)
		if !ok || c == bdkscript.SCRIPT_ERR_OK || c == bdkscript.SCRIPT_ERR_ERROR_COUNT {
			return undecided("gobdk-code-outside-the-table", fmt.Sprintf("script code %d: %s", int(c), err.Error()))
		}
		v := verdict{Verdict: "invalid", Code: r.reference, Message: fmt.Sprintf("%s (GoBDK %s, ordinal %d): %s", r.reference, r.gobdk, int(c), err.Error())}
		if nInputs == 1 {
			zero := 0
			v.Input = &zero
		}
		return v
	}
	return undecided("gobdk-unknown-error", err.Error())
}

func handle(se *bdkscript.TxValidator, req request) response {
	resp := response{ID: req.ID, Runs: map[string]verdict{}}
	fail := func(code, msg string) response {
		for _, r := range req.Runs {
			resp.Runs[r.Key] = undecided(code, msg)
		}
		return resp
	}
	raw, err := hex.DecodeString(req.Tx)
	if err != nil {
		return fail("tx-decode", fmt.Sprintf("tx hex: %v", err))
	}
	f, err := frameOf(raw)
	if err != nil {
		return fail("tx-decode", err.Error())
	}
	ext, err := extended(f, req.Prevouts)
	if err != nil {
		return fail("tx-decode", err.Error())
	}
	if req.SpendHeight == nil {
		return fail("adapter", "no spend_height in the request (the shim needs the entry's spend height; it never defaults one)")
	}
	utxo := make([]int32, len(req.Prevouts))
	for i, p := range req.Prevouts {
		if p.Height == nil || *p.Height < 0 || *p.Height > math.MaxInt32 {
			return fail("adapter", fmt.Sprintf("prevout %d: no height in int32 range in the request", i))
		}
		utxo[i] = int32(*p.Height)
	}
	for _, r := range req.Runs {
		if r.Consensus == nil {
			resp.Runs[r.Key] = undecided("adapter", "no consensus boolean in the run (never defaulted)")
			continue
		}
		entry, derived := derivedEntry[r.Mode]
		if !derived && r.Mode != "" && r.Mode != "flags" {
			resp.Runs[r.Key] = undecided("adapter", fmt.Sprintf("mode %q is not served (flags, gobdk-verify, gobdk-validate)", r.Mode))
			continue
		}
		if derived && len(r.Flags) != 0 {
			resp.Runs[r.Key] = undecided("adapter", fmt.Sprintf("mode %q runs under GoBDK's own words: the run carries no flags", r.Mode))
			continue
		}
		if !derived && len(r.Flags) != len(f.inputs) {
			resp.Runs[r.Key] = undecided("adapter", fmt.Sprintf("%d inputs but %d flag words", len(f.inputs), len(r.Flags)))
			continue
		}
		bh := *req.SpendHeight
		if !*r.Consensus {
			bh-- // DESIGN §6: the policy path takes the tip below the spending block
		}
		if bh < 0 || bh > math.MaxInt32 {
			resp.Runs[r.Key] = undecided("adapter", fmt.Sprintf("block height %d out of int32 range", bh))
			continue
		}
		a := applied{Flags: append([]uint32(nil), r.Flags...), Consensus: *r.Consensus, BlockHeight: int32(bh), UtxoHeights: utxo}
		if derived {
			a.Entry = entry
			a.Flags = make([]uint32, len(utxo))
			for i, h := range utxo {
				a.Flags[i] = se.CalculateFlags(h, int32(bh), *r.Consensus)
			}
		}
		resp.Runs[r.Key] = verify(se, ext, len(f.inputs), a)
	}
	return resp
}

// moduleVersion is the gobdk module version this binary was BUILT with, from the build info (never typed here).
func moduleVersion() (string, string) {
	bi, ok := debug.ReadBuildInfo()
	if !ok {
		return "unknown (no build info)", ""
	}
	for _, d := range bi.Deps {
		if d.Path == modulePath {
			replaced := ""
			if d.Replace != nil {
				replaced = d.Replace.Path
			}
			return d.Version, replaced
		}
	}
	return "unknown (not in the build info)", ""
}

// pin8 is the commit prefix of a pseudo-version (v1.2.5-0.20260918043653-4eab3acdbbb9 → 4eab3acd).
func pin8(version string) string {
	parts := strings.Split(version, "-")
	last := parts[len(parts)-1]
	if len(parts) < 3 || len(last) < 8 {
		return "unknown"
	}
	return last[:8]
}

func banner() string {
	v, replaced := moduleVersion()
	via := ""
	if replaced != "" {
		via = " built from the local clone " + replaced
	}
	// the version block of the linked library (bdkcgo/version_cgo.h:15–40, filled by cmake from version_cgo.cpp.in)
	return fmt.Sprintf("gobdk-runner (bsv-script-lean #28) gobdk %s (module %s %s%s; libGoBDK: bitcoin-sv %s %s %s %s; BDK %s source %s %s %s built %s; Go binding %s; %s; chain %q) (docs/PROVENANCE.md §1a)",
		pin8(v), modulePath, v, via,
		gobdk.BSV_VERSION_STRING(), gobdk.BSV_GIT_COMMIT_TAG_OR_BRANCH(), gobdk.BSV_GIT_COMMIT_HASH(), gobdk.BSV_GIT_COMMIT_DATETIME(),
		gobdk.BDK_VERSION_STRING(), gobdk.SOURCE_GIT_COMMIT_TAG_OR_BRANCH(), gobdk.SOURCE_GIT_COMMIT_HASH(), gobdk.SOURCE_GIT_COMMIT_DATETIME(), gobdk.BDK_BUILD_DATETIME_UTC(),
		gobdk.BDK_GOLANG_VERSION_STRING(), bdkcgo.BDKCGOInfo, chainName)
}

// describe prints the validator's settings as the linked library reports them: the limits every column runs under
// (the consensus column's are the consensus values; the mempool column's are GoBDK's policy defaults).
func describe(se *bdkscript.TxValidator) map[string]any {
	d := map[string]any{"banner": banner(), "chain": chainName}
	d["genesis_activation_height"] = se.GetGenesisActivationHeight()
	d["chronicle_activation_height"] = se.GetChronicleActivationHeight()
	d["genesis_graceful_period"] = se.GetGenesisGracefulPeriod()
	d["chronicle_graceful_period"] = se.GetChronicleGracefulPeriod()
	d["require_standard"] = se.GetRequireStandard()
	d["permit_bare_multisig"] = se.GetPermitBareMultisig()
	d["data_carrier"] = se.GetDataCarrier()
	d["data_carrier_size"] = se.GetDataCarrierSize()
	// the three eras as GoBDK's getters take them: (genesis, chronicle) = (false, false) pre-Genesis, (true, false)
	// post-Genesis, (false, true) post-Chronicle; both true throws (core/txvalidator.cpp:432–443, 605–619, 632–646)
	eras := []struct {
		name               string
		genesis, chronicle bool
	}{{"pre-genesis", false, false}, {"post-genesis", true, false}, {"post-chronicle", false, true}}
	limits := []map[string]any{}
	for _, e := range eras {
		for _, c := range []bool{false, true} {
			// the one-boolean getters read Genesis only: post-Chronicle is post-Genesis for them
			g := e.genesis || e.chronicle
			limits = append(limits, map[string]any{"era": e.name, "consensus": c,
				"max_ops_per_script":         se.GetMaxOpsPerScript(g, c),
				"max_script_size":            se.GetMaxScriptSize(g, c),
				"max_pubkeys_per_multisig":   se.GetMaxPubKeysPerMultiSig(g, c),
				"max_stack_memory_usage":     se.GetMaxStackMemoryUsage(g, c),
				"max_script_num_length":      se.GetMaxScriptNumLength(e.genesis, e.chronicle, c),
				"max_tx_size":                se.GetMaxTxSize(e.genesis, e.chronicle, c),
				"accept_non_standard_output": se.GetAcceptNonStandardOutput(e.genesis, e.chronicle),
			})
		}
	}
	d["limits"] = limits
	return d
}

func main() {
	if len(os.Args) > 1 && os.Args[1] == "--version" {
		fmt.Println(banner())
		return
	}
	if len(os.Args) > 1 && os.Args[1] == "--selftest" {
		if err := selftest(); err != nil {
			fmt.Fprintf(os.Stderr, "gobdk-runner --selftest: FAIL: %v\n", err)
			os.Exit(1)
		}
		fmt.Printf("gobdk-runner --selftest: ok (%d script rows and %d DoS rows agree with the linked library's own texts; SCRIPT_ERR_ERROR_COUNT %d on both sides)\n",
			len(scriptTable), len(dosTable), bdkscript.CPP_SCRIPT_ERR_ERROR_COUNT())
		return
	}
	se := bdkscript.NewTxValidator(chainName)
	if se == nil {
		fmt.Fprintf(os.Stderr, "gobdk-runner: NewTxValidator(%q) returned nil\n", chainName)
		os.Exit(2)
	}
	if len(os.Args) > 1 && os.Args[1] == "--describe" {
		b, _ := json.MarshalIndent(describe(se), "", "  ")
		fmt.Println(string(b))
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
			fmt.Fprintf(os.Stderr, "gobdk-runner: request decode: %v\n", err)
			os.Exit(2)
		}
		if err := enc.Encode(handle(se, req)); err != nil {
			fmt.Fprintf(os.Stderr, "gobdk-runner: response encode: %v\n", err)
			os.Exit(2)
		}
		out.Flush()
	}
}
