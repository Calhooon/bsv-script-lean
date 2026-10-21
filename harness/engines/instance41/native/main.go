// JSON-lines client of the instance's own gRPC services at the pinned tag: the
// validator (the block-context submission) and the blockchain service (the reads
// of the observation contract, docs/CONFORMANCE-TERANODE-OBSERVATION.md section 6).
// [SRC] v0.16.0 @ 4edb60a: services/validator/Server.go:606-777;
// services/subtreevalidation/check_block_subtrees.go:1278-1291 (block options);
// services/blockchain/Server.go:1256-1404,1679-1806,2814,1993,3210 (the reads);
// services/blockchain/blockchain_api/blockchain_api.proto:20-237 (the service).
// This client does not run a script interpreter. Validation runs in
// the node. Accepted submissions spend distinct outputs for the two paths.
// It is the gRPC transport of harness/engines/teranode/contract.rs and is
// called from nowhere else (S4b, lane trait-97, 2026-10-15).
package main

import (
	"bufio"
	"context"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"os"
	"time"

	"github.com/bsv-blockchain/go-bt/v2/chainhash"
	"github.com/bsv-blockchain/teranode/errors"
	"github.com/bsv-blockchain/teranode/model"
	bc "github.com/bsv-blockchain/teranode/services/blockchain/blockchain_api"
	api "github.com/bsv-blockchain/teranode/services/validator/validator_api"
	"google.golang.org/grpc"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/credentials/insecure"
	"google.golang.org/grpc/status"
	"google.golang.org/protobuf/encoding/protojson"
	"google.golang.org/protobuf/proto"
	"google.golang.org/protobuf/types/known/emptypb"
)

type request struct {
	Method  string   `json:"method"`
	Hex     string   `json:"hex"`
	Height  uint32   `json:"height"`
	Time    uint32   `json:"time"`
	MTP     uint32   `json:"mtp"`
	Hash    string   `json:"hash"`
	ID      uint32   `json:"id"`
	IDs     []uint32 `json:"ids"`
	Heights []uint32 `json:"heights"`
}

type clients struct {
	validator  api.ValidatorAPIClient
	blockchain bc.BlockchainAPIClient
}

// A gRPC failure: the transport's own codes are a transport error; any other status is the node's answer,
// kept whole (the unwrapped TError chain, the status text, the code, the details).
func fail(err error, needDetails bool) map[string]any {
	st := status.Convert(err)
	if st.Code() == codes.Unavailable || st.Code() == codes.DeadlineExceeded || st.Code() == codes.Canceled {
		return map[string]any{"transport_error": err.Error()}
	}
	details := []json.RawMessage{}
	for _, detail := range st.Details() {
		if msg, ok := detail.(proto.Message); ok {
			b, marshalErr := protojson.Marshal(msg)
			if marshalErr == nil {
				details = append(details, b)
			}
		}
	}
	if needDetails && len(details) == 0 {
		return map[string]any{"transport_error": err.Error()}
	}
	return map[string]any{"error": map[string]any{"message": errors.UnwrapGRPC(err).Error(), "grpc_error": err.Error(), "grpc_code": st.Code().String(), "details": details}}
}

// The header's own fields, the hash in display order ([SRC] model/BlockHeader.go:75,244).
func header(raw []byte) map[string]any {
	h, err := model.NewBlockHeaderFromBytes(raw)
	if err != nil {
		return map[string]any{"header": hex.EncodeToString(raw), "decode_error": err.Error()}
	}
	return map[string]any{"header": hex.EncodeToString(raw), "hash": h.Hash().String(),
		"previousblockhash": h.HashPrevBlock.String(), "merkleroot": h.HashMerkleRoot.String(), "time": h.Timestamp}
}

func headerMeta(r *bc.GetBlockHeaderResponse) map[string]any {
	out := header(r.BlockHeader)
	out["id"], out["height"], out["tx_count"], out["chain_work"] = r.Id, r.Height, r.TxCount, hex.EncodeToString(r.ChainWork)
	out["median_time_past"], out["block_time"], out["timestamp"] = r.MedianTimePast, r.BlockTime, r.Timestamp
	out["invalid"], out["mined_set"], out["subtrees_set"], out["peer_id"] = r.Invalid, r.MinedSet, r.SubtreesSet, r.PeerId
	return out
}

func block(r *bc.GetBlockResponse) map[string]any {
	out := header(r.Header)
	subtrees := []string{}
	for _, s := range r.SubtreeHashes {
		if h, err := chainhash.NewHash(s); err == nil {
			subtrees = append(subtrees, h.String())
		}
	}
	out["id"], out["height"], out["transaction_count"] = r.Id, r.Height, r.TransactionCount
	out["coinbase_tx"], out["subtrees"] = hex.EncodeToString(r.CoinbaseTx), subtrees
	return out
}

func hashBytes(s string) ([]byte, error) {
	h, err := chainhash.NewHashFromStr(s)
	if err != nil {
		return nil, err
	}
	return h.CloneBytes(), nil
}

func validate(c clients, req request) map[string]any {
	data, err := hex.DecodeString(req.Hex)
	if err != nil {
		return map[string]any{"transport_error": err.Error()}
	}
	yes, no := true, false
	ctx, cancel := context.WithTimeout(context.Background(), 60*time.Second)
	defer cancel()
	// All parents are mined, so the candidate-height option changes no height. No script bypass is set.
	// SkipUtxoCreation is false: this is a submission and it spends its inputs.
	response, err := c.validator.ValidateTransaction(ctx, &api.ValidateTransactionRequest{
		TransactionData: data, BlockHeight: req.Height,
		SkipPolicyChecks: &yes, InBlock: &yes, AddTxToBlockAssembly: &yes,
		CreateConflicting: &yes,
		// Explicit at v0.16.0 (validator_api.proto:62-82): full script validation
		// and full spend; unconfirmed parents at the candidate height as the block
		// path sets it (check_block_subtrees.go:1283-1291). All parents are mined.
		SkipScriptValidation: &no, OutpointOnlySpend: &no,
		UnconfirmedParentsAtCandidateHeight: &yes,
		SkipTxmetaPublishing: &no, CandidateBlockTime: &req.Time,
		CandidateParentMedianTime: &req.MTP,
	})
	if err == nil {
		return map[string]any{"result": map[string]any{"valid": response.Valid, "txid": hex.EncodeToString(response.Txid), "reason": response.Reason}}
	}
	return fail(err, true)
}

// One blockchain read. [SRC] services/blockchain/Server.go at the pin: GetBestBlockHeader :1679 (no id, no
// invalid mark in its answer), GetBestHeightAndTime :3210 (the median of the tip's last 11 timestamps, the tip
// included), GetChainTips :1747, CheckBlockIsInCurrentChain :1705 (ANY of the ids,
// stores/blockchain/sql/CheckBlockIsInCurrentChain.go:19-24), GetBlockHeader :1765, GetBlockByHeight :1332,
// GetBlockByID :1368, GetFSMCurrentState :2814, GetMedianTimePastByHeights :1993.
func read(c clients, req request) map[string]any {
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()
	switch req.Method {
	case "best_header":
		r, err := c.blockchain.GetBestBlockHeader(ctx, &emptypb.Empty{})
		if err != nil {
			return fail(err, false)
		}
		t, err := c.blockchain.GetBestHeightAndTime(ctx, &emptypb.Empty{})
		if err != nil {
			return fail(err, false)
		}
		out := headerMeta(r)
		out["best_height_and_time"] = map[string]any{"height": t.Height, "time": t.Time}
		return map[string]any{"result": out}
	case "chain_tips":
		r, err := c.blockchain.GetChainTips(ctx, &emptypb.Empty{})
		if err != nil {
			return fail(err, false)
		}
		tips := []map[string]any{}
		for _, t := range r.Tips {
			tips = append(tips, map[string]any{"height": t.Height, "hash": t.Hash, "branchlen": t.Branchlen, "status": t.Status})
		}
		return map[string]any{"result": tips}
	case "in_current_chain":
		r, err := c.blockchain.CheckBlockIsInCurrentChain(ctx, &bc.CheckBlockIsCurrentChainRequest{BlockIDs: req.IDs})
		if err != nil {
			return fail(err, false)
		}
		return map[string]any{"result": r.IsPartOfCurrentChain}
	case "header":
		h, err := hashBytes(req.Hash)
		if err != nil {
			return map[string]any{"transport_error": err.Error()}
		}
		r, err := c.blockchain.GetBlockHeader(ctx, &bc.GetBlockHeaderRequest{BlockHash: h})
		if err != nil {
			return fail(err, false)
		}
		return map[string]any{"result": headerMeta(r)}
	case "block_by_height":
		r, err := c.blockchain.GetBlockByHeight(ctx, &bc.GetBlockByHeightRequest{Height: req.Height})
		if err != nil {
			return fail(err, false)
		}
		return map[string]any{"result": block(r)}
	case "block_by_id":
		r, err := c.blockchain.GetBlockByID(ctx, &bc.GetBlockByIDRequest{Id: uint64(req.ID)})
		if err != nil {
			return fail(err, false)
		}
		return map[string]any{"result": block(r)}
	case "fsm_state":
		r, err := c.blockchain.GetFSMCurrentState(ctx, &emptypb.Empty{})
		if err != nil {
			return fail(err, false)
		}
		return map[string]any{"result": r.State.String()}
	case "mtp":
		r, err := c.blockchain.GetMedianTimePastByHeights(ctx, &bc.GetMedianTimePastByHeightsRequest{Heights: req.Heights})
		if err != nil {
			return fail(err, false)
		}
		return map[string]any{"result": r.MedianTimePast}
	case "unimplemented_probe":
		// F1's witness: the two rpcs of the proto whose server methods carry a Request suffix
		// (services/blockchain/Server.go:1576,1616); each call's status is the answer.
		h, err := hashBytes(req.Hash)
		if err != nil {
			return map[string]any{"transport_error": err.Error()}
		}
		out := map[string]any{}
		_, err = c.blockchain.GetLatestBlockHeaderFromBlockLocator(ctx, &bc.GetLatestBlockHeaderFromBlockLocatorRequest{BestBlockHash: h, BlockLocatorHashes: [][]byte{h}})
		out["GetLatestBlockHeaderFromBlockLocator"] = map[string]any{"grpc_code": status.Code(err).String(), "status": fmt.Sprint(err)}
		_, err = c.blockchain.GetBlockHeadersFromOldest(ctx, &bc.GetBlockHeadersFromOldestRequest{ChainTipHash: h, TargetHash: h, NumberOfHeaders: 1})
		out["GetBlockHeadersFromOldest"] = map[string]any{"grpc_code": status.Code(err).String(), "status": fmt.Sprint(err)}
		return map[string]any{"result": out}
	}
	return map[string]any{"transport_error": "unknown native operation"}
}

func execute(c clients, req request) map[string]any {
	if req.Method == "validate" {
		return validate(c, req)
	}
	return read(c, req)
}

func main() {
	// grpc.NewClient connects lazily: a run without --validator never dials 8081
	// ([SRC] settings.conf:91,139 at the pin: BLOCKCHAIN_GRPC_PORT 8087, VALIDATOR_GRPC_PORT 8081).
	vconn, err := grpc.NewClient("127.0.0.1:8081", grpc.WithTransportCredentials(insecure.NewCredentials()))
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
	defer vconn.Close()
	bconn, err := grpc.NewClient("127.0.0.1:8087", grpc.WithTransportCredentials(insecure.NewCredentials()))
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
	defer bconn.Close()
	c := clients{validator: api.NewValidatorAPIClient(vconn), blockchain: bc.NewBlockchainAPIClient(bconn)}
	scanner := bufio.NewScanner(os.Stdin)
	scanner.Buffer(make([]byte, 4096), 32*1024*1024)
	encoder := json.NewEncoder(os.Stdout)
	for scanner.Scan() {
		var req request
		var answer map[string]any
		if err := json.Unmarshal(scanner.Bytes(), &req); err != nil {
			answer = map[string]any{"transport_error": err.Error()}
		} else {
			answer = execute(c, req)
		}
		if err := encoder.Encode(answer); err != nil {
			fmt.Fprintln(os.Stderr, err)
			os.Exit(1)
		}
	}
	if err := scanner.Err(); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}
