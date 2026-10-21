//! [D] 2026-10-13, lane s6-75: #75 the proof surface on a fresh isolated regtest
//! instance. For every transaction of bodies of 2, 3, 5, 6 and 8 transactions
//! (odd terminal padding at two levels, two consecutive markers, the virtual
//! parent as a hash) the runner fetches `getmerkleproof`, `getmerkleproof2` with
//! every `targetType` and with `includeFullTx`, measures the `binary` format
//! refusal, asks the node's own `verifymerkleproof` for the served object and for
//! a mutated one, and feeds every proof to the compiled Lean check
//! (`chaincheck --verify-tsc`): `verifyTsc` against the block's header, the
//! binary TSC round trip, the re-rendered JSON words compared field by field
//! with the node's reply, and the model of the node's branch generator over the
//! body's identifiers. The one-transaction block's answer is quoted from the
//! node's output. Views, never rules; nothing is broadcast (rule 10).
//! [SRC] src/rpc/rawtransaction.cpp:2242-2339,2342-2525,2527-2612 and
//! src/merkletree.cpp:275-346 at PIN.
use super::core::*;

const SCENARIO: &str = "2026-10-13-tsc-proof-surface";
const SIZES: [usize; 5] = [2, 3, 5, 6, 8];
const NOT_FOUND: &str = "Transaction(s) not found in provided block";

fn scenario(path: &Path) -> Result<Value> {
    let raw = fs::read_to_string(path).map_err(|e| e.to_string())?;
    serde_json::from_str(
        raw.split_once("```json\n")
            .ok_or("scenario fence")?
            .1
            .split_once("\n```")
            .ok_or("scenario close")?
            .0,
    )
    .map_err(|e| e.to_string())
}

/// The compiled Lean check of one proof object (lean/Test/ChainCheck.lean `--verify-tsc`).
fn lean_tsc(input: &Value) -> Result<Value> {
    let out = Command::new("lean/.lake/build/bin/chaincheck")
        .args(["--verify-tsc", &input.to_string()])
        .output()
        .map_err(|e| e.to_string())?;
    if !out.status.success() {
        return Err(format!(
            "Lean TSC check failed: {}",
            String::from_utf8_lossy(&out.stderr)
        ));
    }
    serde_json::from_str(String::from_utf8_lossy(&out.stdout).trim()).map_err(|e| e.to_string())
}

/// The positions of the `*` markers in a served node list.
fn markers(nodes: &Value) -> Vec<usize> {
    nodes
        .as_array()
        .map(|a| {
            a.iter()
                .enumerate()
                .filter(|(_, n)| *n == "*")
                .map(|(i, _)| i)
                .collect()
        })
        .unwrap_or_default()
}

struct Block<'a> {
    hash: &'a str,
    header_hex: &'a str,
    merkle_root: &'a str,
    txids: &'a [String],
}

/// One served proof through the Lean view: verification, round trip, words.
fn check_proof(
    label: &str,
    reply: &Value,
    v2: bool,
    block: &Block,
    index: usize,
    full_tx_hex: Option<&str>,
) -> Result<Value> {
    let txid = &block.txids[index];
    let target_type = if v2 {
        reply
            .get("targetType")
            .and_then(Value::as_str)
            .unwrap_or("hash")
            .to_owned()
    } else {
        "header".to_owned()
    };
    // [D] getmerkleproof's target is the verbose header object; the view takes
    // the same header's 80-byte frame and binds its hash to the object's hash.
    let target = if v2 {
        text(&reply["target"])?.to_owned()
    } else {
        block.header_hex.to_owned()
    };
    let input = json!({"index":reply["index"],"txOrId":reply["txOrId"],"targetType":target_type,"target":target,"nodes":reply["nodes"],"header_hex":block.header_hex,"block_hash":block.hash,"block_txids":block.txids});
    let lean = lean_tsc(&input)?;
    let view = &lean["view"];
    let mut checks = BTreeMap::new();
    checks.insert("lean_verifyTsc", lean["verifyTsc"] == true);
    checks.insert("lean_roundTrip", lean["roundTrip"] == true);
    checks.insert("lean_blockHashBound", lean["blockHashBound"] == true);
    checks.insert("lean_modelBranchEqual", lean["modelBranchEqual"] == true);
    checks.insert("view_index", view["index"] == reply["index"]);
    checks.insert("view_txOrId", view["txOrId"] == reply["txOrId"]);
    checks.insert("view_nodes", view["nodes"] == reply["nodes"]);
    checks.insert("index_is_position", reply["index"] == json!(index as u64));
    checks.insert(
        "txOrId_word",
        match full_tx_hex {
            Some(hex) => reply["txOrId"] == json!(hex),
            None => reply["txOrId"] == json!(txid),
        },
    );
    if v2 {
        checks.insert("view_target", view["target"] == reply["target"]);
        checks.insert(
            "view_targetType",
            match reply.get("targetType") {
                Some(t) => view["targetType"] == *t,
                None => view["targetType"].is_null(),
            },
        );
        let kind = match target_type.as_str() {
            "hash" => 0,
            "header" => 2,
            _ => 4,
        };
        checks.insert(
            "flags",
            lean["flags"] == json!(u64::from(full_tx_hex.is_some()) + kind),
        );
        checks.insert(
            "target_word",
            match target_type.as_str() {
                "hash" => reply["target"] == json!(block.hash),
                "header" => reply["target"] == json!(block.header_hex),
                _ => reply["target"] == json!(block.merkle_root),
            },
        );
    } else {
        checks.insert("flags_2", reply["flags"] == 2 && lean["flags"] == 2);
        checks.insert(
            "target_object_hash",
            reply["target"]["hash"] == json!(block.hash),
        );
        checks.insert(
            "target_object_merkleroot",
            reply["target"]["merkleroot"] == json!(block.merkle_root),
        );
        checks.insert(
            "view_target_header",
            view["target"] == json!(block.header_hex),
        );
    }
    let agree = checks.values().all(|v| *v);
    Ok(
        json!({"label":label,"txid":txid,"index":index,"agree":agree,"checks":checks,"markers":markers(&reply["nodes"]),"node_count":reply["nodes"].as_array().map(|a| a.len()),"binary_hex":lean["binary_hex"],"binary_len":lean["binary_len"],"flags":lean["flags"],"lean":lean,"node_reply":reply,"lean_input":input}),
    )
}

/// The node's `verifymerkleproof` on a proof object and Lean's verdict on the same object.
fn cross_verdict(n: &mut Node, object: &Value, block: &Block, label: &str) -> Result<Value> {
    let node_verdict = n.call("verifymerkleproof", json!([object]))?;
    let input = json!({"index":object["index"],"txOrId":object["txOrId"],"targetType":"header","target":block.header_hex,"nodes":object["nodes"],"header_hex":block.header_hex,"block_hash":block.hash});
    let lean = lean_tsc(&input)?;
    let agree = lean["verifyTsc"] == node_verdict;
    Ok(
        json!({"label":label,"node_verifymerkleproof":node_verdict,"lean_verifyTsc":lean["verifyTsc"],"agree":agree,"object":object}),
    )
}

fn block_step(
    n: &mut Node,
    record: &str,
    step: &Value,
    hash: &str,
    offset: usize,
) -> Result<Value> {
    let body = n.call("getblock", json!([hash, 1]))?;
    let header_hex = text(&n.call("getblockheader", json!([hash, false]))?)?.to_owned();
    let merkle_root = text(&body["merkleroot"])?.to_owned();
    let txids: Vec<String> = body["tx"]
        .as_array()
        .ok_or("body tx")?
        .iter()
        .map(|t| t.as_str().unwrap_or("").to_owned())
        .collect();
    let block = Block {
        hash,
        header_hex: &header_hex,
        merkle_root: &merkle_root,
        txids: &txids,
    };
    let mut proofs = vec![];
    let mut cross = vec![];
    let mut observed_markers = serde_json::Map::new();
    for (index, txid) in txids.iter().enumerate() {
        let v1 = n.call("getmerkleproof", json!([txid, hash]))?;
        proofs.push(check_proof(
            "getmerkleproof",
            &v1,
            false,
            &block,
            index,
            None,
        )?);
        cross.push(cross_verdict(n, &v1, &block, "served object")?);
        // [D] 2026-10-14: labels are an editorial projection of the retained receipt labels.
        // [D] mutations: the index with its low bit flipped; the earliest hash node replaced by the leaf.
        let mut flipped = v1.clone();
        flipped["index"] = json!((index as u64) ^ 1);
        cross.push(cross_verdict(n, &flipped, &block, "index low bit flipped")?);
        let mut replaced = v1.clone();
        if let Some(nodes) = replaced["nodes"].as_array_mut() {
            if let Some(slot) = nodes.iter_mut().find(|node| *node != "*") {
                *slot = json!(txid);
            }
        }
        cross.push(cross_verdict(
            n,
            &replaced,
            &block,
            "earliest hash node replaced by the leaf",
        )?);
        let positions = markers(&v1["nodes"]);
        if !positions.is_empty() {
            observed_markers.insert(index.to_string(), json!(positions));
        }
        let raw = n.call("getrawtransaction", json!([txid, 0]))?;
        let raw_hex = text(&raw)?.to_owned();
        for (target_type, full) in [
            ("hash", false),
            ("header", false),
            ("merkleroot", false),
            ("hash", true),
        ] {
            let v2 = n.call(
                "getmerkleproof2",
                json!([hash, txid, full, target_type, "json"]),
            )?;
            let label = format!("getmerkleproof2 targetType={target_type} includeFullTx={full}");
            proofs.push(check_proof(
                &label,
                &v2,
                true,
                &block,
                index,
                if full { Some(&raw_hex) } else { None },
            )?);
        }
    }
    // [SRC] the binary format is refused at the pin with RPC_INVALID_PARAMS, the JSON-RPC code -32602:
    // src/rpc/rawtransaction.cpp:2429-2436, src/rpc/protocol.h (RPC_INVALID_PARAMS = -32602).
    let binary = n.receipt(
        "getmerkleproof2",
        json!([hash, txids[0], false, "hash", "binary"]),
    )?;
    let binary_refused = binary["error"]["code"] == -32602
        && binary["error"]["message"]
            .as_str()
            .is_some_and(|m| m.starts_with("format is 'binary',  must be 'json'"));
    let expected = &step["expected_observations"];
    let expected_markers = expected["marker_positions"].clone();
    let proofs_agree = proofs.iter().all(|p| p["agree"] == true);
    let cross_agree = cross.iter().all(|c| c["agree"] == true);
    let served_true = cross
        .iter()
        .filter(|c| c["label"] == "served object")
        .all(|c| c["node_verifymerkleproof"] == true);
    let observed = json!({"transactions":txids.len(),"height":body["height"],"proofs_checked":proofs.len(),"proofs_agree":proofs_agree,"verifymerkleproof_served_true":served_true,"cross_verdicts":cross.len(),"cross_agree":cross_agree,"marker_positions":Value::Object(observed_markers),"binary_format_refused":binary_refused,"binary_format_code":binary["error"]["code"]});
    let agree = proofs_agree
        && cross_agree
        && served_true
        && binary_refused
        && observed["marker_positions"] == expected_markers
        && expected["transactions"] == json!(txids.len());
    let verdict = if agree { "agree" } else { "diverge" };
    Ok(
        json!({"id":step["id"],"verdict":verdict,"node":format!("measured {verdict} [X] {record}"),"label":"[D]","block":hash,"header_hex":header_hex,"merkleroot":merkle_root,"txids":txids,"expected":{"transactions":expected["transactions"],"marker_positions":expected_markers,"binary_format_refused":true,"verifymerkleproof_served_true":true},"expected_label":"[D]","observed":observed,"proofs":proofs,"cross_verdicts":cross,"binary_format_receipt":binary,"scope":"node proofs measured; the Lean TSC view, round trip and model branch derived from the node's output; inclusion keeps #65's premises","rpc":n.calls[offset..]}),
    )
}

fn single_step(n: &mut Node, record: &str, step: &Value, offset: usize) -> Result<Value> {
    let hash = n.call("getblockhash", json!([1]))?;
    let hash = text(&hash)?.to_owned();
    let body = n.call("getblock", json!([hash, 1]))?;
    let txids: Vec<String> = body["tx"]
        .as_array()
        .ok_or("body tx")?
        .iter()
        .map(|t| t.as_str().unwrap_or("").to_owned())
        .collect();
    if txids.len() != 1 {
        return Err("height-one block is not a one-transaction body".into());
    }
    let header_hex = text(&n.call("getblockheader", json!([hash, false]))?)?.to_owned();
    let v1 = n.receipt("getmerkleproof", json!([txids[0], hash]))?;
    let v2 = n.receipt("getmerkleproof2", json!([hash, txids[0]]))?;
    let v2_header = n.receipt("getmerkleproof2", json!([hash, txids[0], false, "header"]))?;
    let quoted = |r: &Value| json!({"code":r["error"]["code"],"message":r["error"]["message"],"result":r.get("result").cloned()});
    let refused = |r: &Value| r["error"]["code"] == -5 && r["error"]["message"] == json!(NOT_FOUND);
    // [D] the body-derived reading, never a node output: index 0, the empty branch, the leaf as the root.
    let derived = lean_tsc(
        &json!({"index":0,"txOrId":txids[0],"targetType":"merkleroot","target":body["merkleroot"],"nodes":[],"header_hex":header_hex,"block_hash":hash,"block_txids":txids}),
    )?;
    let observed = json!({"transactions":1,"height":body["height"],"getmerkleproof":quoted(&v1),"getmerkleproof2":quoted(&v2),"getmerkleproof2_header":quoted(&v2_header),"no_proof_fields":v1.get("result").is_none() && v2.get("result").is_none(),"body_derived":{"label":"[D]","index":0,"nodes":[],"merkleroot_equals_txid":body["merkleroot"]==json!(txids[0]),"lean_verifyTsc":derived["verifyTsc"],"lean_modelBranchEqual":derived["modelBranchEqual"],"lean_roundTrip":derived["roundTrip"]}});
    let agree = refused(&v1)
        && refused(&v2)
        && refused(&v2_header)
        && derived["verifyTsc"] == true
        && derived["modelBranchEqual"] == true
        && body["merkleroot"] == json!(txids[0]);
    let verdict = if agree { "agree" } else { "diverge" };
    Ok(
        json!({"id":step["id"],"verdict":verdict,"node":format!("measured {verdict} [X] {record}"),"label":"[D]","block":hash,"txids":txids,"expected":step["expected_observations"],"expected_label":"[D]","observed":observed,"scope":"the node's own answer quoted; the offset-0 reading is body-derived [D], never a node output","rpc":n.calls[offset..]}),
    )
}

pub(super) fn run(root: &Path, record: &str, write: bool) -> Result<Vec<Value>> {
    let path = PathBuf::from(format!("corpus/scenarios/{SCENARIO}.md"));
    let declared = scenario(&path)?;
    let steps = declared["steps"].as_array().ok_or("declared steps")?;
    if steps.len() != SIZES.len() + 1
        || steps[0]["action"]["type"] != "proofSurface"
        || steps[0]["action"]["transactions"] != 1
        || steps
            .iter()
            .skip(1)
            .zip(SIZES)
            .any(|(step, size)| step["action"]["transactions"] != json!(size))
    {
        return Err("proof surface step contract mismatch".into());
    }
    let mut n = start_retry(root, SCENARIO, "")?;
    let (f, t, base) = seed(&mut n)?;
    let setup_end = n.calls.len();
    // [D] chained spends: every block holds its coinbase and a chain of spends of
    // the previous transaction, so a body of k transactions needs k - 1 spends.
    let mut parent = t.clone();
    let mut value = 99_000u64;
    let mut blocks = vec![];
    let mut fixtures = BTreeMap::from([
        ("F".to_owned(), material(&f)),
        ("T1".to_owned(), material(&t)),
    ]);
    let mut counter = 1;
    for (height, (k, size)) in (102u32..).zip(SIZES.iter().enumerate()) {
        let mut txs = vec![cb(height, &format!("proof-surface-{size}"))];
        for _ in 0..size - 1 {
            let child = if counter == 1 {
                t.clone()
            } else {
                value -= 1_000;
                spend(&parent, value, 1)
            };
            fixtures.insert(format!("T{counter}"), material(&child));
            parent = child.clone();
            txs.push(child);
            counter += 1;
        }
        let (hash, receipt) = n.submit(&txs, 1_700_000_000 + k as u32)?;
        if block_judgment(&receipt) != json!({"status":"ok"}) {
            return Err(format!("proof-surface block of {size}: {receipt}"));
        }
        blocks.push((hash, *size));
    }
    let setup = n.calls[..setup_end].to_vec();
    let mut rows = vec![];
    let offset = n.calls.len();
    rows.push(single_step(&mut n, record, &steps[0], offset)?);
    for (step, (hash, _)) in steps.iter().skip(1).zip(&blocks) {
        let offset = n.calls.len();
        rows.push(block_step(&mut n, record, step, hash, offset)?);
    }
    n.stop()?;
    let agree = rows.iter().filter(|r| r["verdict"] == "agree").count();
    let proofs: usize = rows
        .iter()
        .filter_map(|r| r["proofs"].as_array().map(Vec::len))
        .sum();
    let cross: usize = rows
        .iter()
        .filter_map(|r| r["cross_verdicts"].as_array().map(Vec::len))
        .sum();
    let result = json!({"scenario":SCENARIO,"source_pin":PIN,"record":record,"setup":setup,"conf":n.conf,"base":base,"blocks":blocks.iter().map(|(h,s)| json!({"hash":h,"transactions":s})).collect::<Vec<_>>(),"fixtures":fixtures,"steps":rows,"counts":{"label":"[M]","rows":rows.len(),"realized":rows.len(),"agree":agree,"diverge":rows.len()-agree,"rpc-precheck":0,"unrealizable":0,"needs-peer":0,"pending":0,"proofs_checked":proofs,"cross_verdicts":cross}});
    if write {
        super::intake::mark_scenario(&path, &result)?;
        write_json(
            &PathBuf::from(format!("corpus/scenarios/{SCENARIO}.node.json")),
            &result,
        )?;
    }
    println!("proof-surface scenario {SCENARIO}: [M] {agree}/{} steps agree; {proofs} proofs checked; {cross} cross verdicts [X]", rows.len());
    Ok(vec![result])
}
