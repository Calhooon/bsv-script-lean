// bsv-script-lean #86 (lane wire-86, 2026-10-15): the go-sdk column of the wire views.
//
// Reads corpus/wire/<format>.jsonl files named on the command line and writes one JSON line per row:
// the fields of the spec column (lean/Test/WireCheck.lean), from go-sdk v1.7.2's own codecs. The calls,
// [SRC] go-sdk v1.7.2 (2ca481c5): transaction.NewTransactionFromBytes, the one reader of a plain and
// an extended transaction (transaction/transaction.go:56-66,80-200; the EF branch at :129-148) and
// Transaction.EF (:349-358); transaction.NewMerklePathFromBinary and MerklePath.Bytes and ComputeRoot
// (transaction/merklepath.go:190-276,293-320,339); transaction.NewBeefFromBytes (transaction/beef.go:227-338),
// Beef.Bytes, Beef.AtomicBytes and Beef.IsValid (:1030,1532,1700). go-sdk keeps a BEEF's transactions
// in a map, so this column lists them by txid ("order": "unordered") and the comparison matches them
// as a set. `parse` for an EF row is the reader's success on the EF branch: every input carries the
// spent output. No network; the corpus is read only.
package main

import (
	"bufio"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"os"
	"sort"

	"github.com/bsv-blockchain/go-sdk/chainhash"
	"github.com/bsv-blockchain/go-sdk/transaction"
)

type row struct {
	ID      string `json:"id"`
	Format  string `json:"format"`
	Hex     string `json:"hex"`
	Subject string `json:"subject"`
	BumpHex string `json:"bump_hex"`
}

type out map[string]any

func efFields(b []byte) out {
	tx, err := transaction.NewTransactionFromBytes(b)
	if err != nil {
		return out{"parse": false}
	}
	spent := make([]any, 0, len(tx.Inputs))
	for _, in := range tx.Inputs {
		o := in.SourceTxOutput()
		if o == nil {
			return out{"parse": false, "plain": true}
		}
		spent = append(spent, []any{o.Satoshis, hex.EncodeToString(*o.LockingScript)})
	}
	if len(b) < 10 || hex.EncodeToString(b[4:10]) != "0000000000ef" {
		return out{"parse": false, "plain": true}
	}
	m := out{"parse": true, "valid": nil, "txid": tx.TxID().String(), "tx": tx.Hex(), "spent": spent}
	if ef, err := tx.EF(); err == nil {
		m["reencode"] = hex.EncodeToString(ef)
	}
	return m
}

func rootOf(mp *transaction.MerklePath, txid *chainhash.Hash) any {
	r, err := mp.ComputeRoot(txid)
	if err != nil {
		return nil
	}
	return r.String()
}

func bumpObjects(mp *transaction.MerklePath) out {
	txids := []any{}
	if len(mp.Path) > 0 {
		for _, l := range mp.Path[0] {
			if l.Txid != nil && *l.Txid && l.Hash != nil {
				txids = append(txids, out{"offset": l.Offset, "txid": l.Hash.String(), "root": rootOf(mp, l.Hash)})
			}
		}
	}
	return out{"height": mp.BlockHeight, "root": rootOf(mp, nil), "txids": txids}
}

func bumpFields(b []byte) out {
	mp, err := transaction.NewMerklePathFromBinary(b)
	if err != nil {
		return out{"parse": false}
	}
	m := bumpObjects(mp)
	m["parse"] = true
	m["valid"] = nil
	m["reencode"] = hex.EncodeToString(mp.Bytes())
	return m
}

func beefFields(b []byte, atomic bool) out {
	isAtomic := len(b) >= 4 && hex.EncodeToString(b[:4]) == "01010101"
	if isAtomic != atomic {
		return out{"parse": false}
	}
	beef, err := transaction.NewBeefFromBytes(b)
	if err != nil {
		return out{"parse": false}
	}
	version := 2
	if beef.Version == transaction.BEEF_V1 {
		version = 1
	}
	bumps := make([]any, 0, len(beef.BUMPs))
	for _, x := range beef.BUMPs {
		bumps = append(bumps, out{"height": x.BlockHeight, "root": rootOf(x, nil)})
	}
	ids := make([]string, 0, len(beef.Transactions))
	for id := range beef.Transactions {
		ids = append(ids, id.String())
	}
	sort.Strings(ids)
	txs := make([]any, 0, len(ids))
	for _, s := range ids {
		h, _ := chainhash.NewHashFromHex(s)
		t := beef.Transactions[*h]
		e := out{"txid": s, "kind": "raw", "bump": nil, "mined": nil}
		switch {
		case t.DataFormat == transaction.TxIDOnly:
			e["kind"] = "txid"
		case t.DataFormat == transaction.RawTxAndBumpIndex:
			e["kind"] = "raw+bump"
			e["bump"] = t.BumpIndex
			if t.BumpIndex < len(beef.BUMPs) && len(beef.BUMPs[t.BumpIndex].Path) > 0 {
				x := beef.BUMPs[t.BumpIndex]
				e["mined"] = "unresolved"
				for _, l := range x.Path[0] {
					if l.Hash != nil && l.Hash.Equal(*h) {
						e["mined"] = out{"height": x.BlockHeight, "index": l.Offset, "root": rootOf(x, h)}
					}
				}
			}
		}
		txs = append(txs, e)
	}
	m := out{"parse": true, "valid": beef.IsValid(true), "version": version, "bumps": bumps, "txs": txs,
		"order": "unordered"}
	if atomic {
		subject, _ := chainhash.NewHash(b[4:36])
		m["subject"] = subject.String()
		if enc, err := beef.AtomicBytes(subject); err == nil {
			m["reencode"] = hex.EncodeToString(enc)
		}
	} else if enc, err := beef.Bytes(); err == nil {
		m["reencode"] = hex.EncodeToString(enc)
	}
	return m
}

// tscFields: go-sdk has no TSC codec; the engine reads the BUMP WhatsOnChain serves for the same
// transaction and computes the subject's root, which the comparison sets against the spec's.
func tscFields(r row) out {
	m := out{"parse": nil, "read_bump_root": nil}
	mp, err := transaction.NewMerklePathFromHex(r.BumpHex)
	if err != nil {
		return m
	}
	if h, err := chainhash.NewHashFromHex(r.Subject); err == nil {
		m["read_bump_root"] = rootOf(mp, h)
	}
	return m
}

func line(r row) (out, error) {
	b, err := hex.DecodeString(r.Hex)
	if err != nil {
		return nil, fmt.Errorf("%s: %w", r.ID, err)
	}
	var m out
	switch r.Format {
	case "ef":
		m = efFields(b)
	case "bump":
		m = bumpFields(b)
	case "beef":
		m = beefFields(b, false)
	case "atomic-beef":
		m = beefFields(b, true)
	case "tsc":
		m = tscFields(r)
	default:
		return nil, fmt.Errorf("%s: unknown format %s", r.ID, r.Format)
	}
	m["id"], m["format"], m["impl"] = r.ID, r.Format, "go-sdk@v1.7.2"
	return m, nil
}

// safeLine turns an engine panic into a refusal of the row, named, never a crash of the column.
func safeLine(r row) (m out, err error) {
	defer func() {
		if p := recover(); p != nil {
			m, err = out{"id": r.ID, "format": r.Format, "impl": "go-sdk@v1.7.2", "parse": false,
				"panic": fmt.Sprint(p)}, nil
		}
	}()
	return line(r)
}

func main() {
	if len(os.Args) < 2 {
		fmt.Fprintln(os.Stderr, "usage: wire corpus/wire/<format>.jsonl ...")
		os.Exit(2)
	}
	w := bufio.NewWriter(os.Stdout)
	defer w.Flush()
	rows, bad := 0, 0
	for _, path := range os.Args[1:] {
		f, err := os.Open(path)
		if err != nil {
			fmt.Fprintln(os.Stderr, "wire:", err)
			os.Exit(2)
		}
		sc := bufio.NewScanner(f)
		sc.Buffer(make([]byte, 1<<20), 1<<28)
		for sc.Scan() {
			var r row
			if err := json.Unmarshal(sc.Bytes(), &r); err != nil {
				bad++
				continue
			}
			m, err := safeLine(r)
			if err != nil {
				bad++
				fmt.Fprintln(os.Stderr, "wire:", err)
				continue
			}
			enc, _ := json.Marshal(m)
			fmt.Fprintln(w, string(enc))
			rows++
		}
		f.Close()
	}
	fmt.Fprintf(os.Stderr, "wire: %d rows, %d unreadable (go-sdk@v1.7.2)\n", rows, bad)
	if bad > 0 {
		w.Flush()
		os.Exit(1)
	}
}
