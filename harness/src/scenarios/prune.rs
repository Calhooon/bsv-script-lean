//! [D] 2026-10-15, lane s7-82: #82 pruning on fresh isolated regtest instances of the
//! node of record. Phase A (`-prune=1`, 4096-byte block files) mines past
//! `nPruneAfterHeight`, asks `pruneblockchain` below and at the bound, at the clamp and
//! at the refusals, reads every block's data and undo bits, the block files on disk and
//! `getblockchaininfo`, asks every request the harness reads for a pruned block, a pruned
//! block whose merkle tree was asked for before pruning, and a retained block, restarts
//! (the tree's memory cache gone, its store kept), then invalidates a block below the
//! pruned bound (s10, held in the record under the discretion group until routed). Phase B keeps 2000 blocks
//! (the negative clamp), phase C runs unpruned, phase D reads the launch refusals and an
//! automatic target. Every answer is compared with the compiled Lean function
//! (`chaincheck --prune`, `lean/BsvChain/Views/Prune.lean`) fed the node's own block
//! sizes in arrival order. Views, never rules: pruning is a node setting. Nothing is
//! broadcast (rule 10).
//! [SRC] src/blockfileinfostore.cpp:21-39,74-103,177-300; src/validation.cpp:3840-3860,
//! 4065-4080,6584-6635; src/rpc/blockchain.cpp:1810-1875,2454-2480; src/init.cpp:2815-2849
//! at PIN.
use super::core::*;
use std::io::{Read, Write};

const SCENARIO: &str = "2026-10-15-prune-retention";
const PREFERRED: u64 = 4096;
const AFTER: u64 = 1000;
const KEEP: u64 = 288;
// The probe blocks hold a second transaction: the node serves no proof for a lone coinbase
// (src/merkletree.cpp:335-339, #75's Finding), which is not what pruning decides.
const PROBES: [(&str, u64, bool); 3] = [("P", 140, false), ("T", 141, true), ("R", 1250, false)];

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

/// The compiled Lean function over one instance's events (lean/Test/PruneCheck.lean).
fn lean_prune(root: &Path, name: &str, input: &Value) -> Result<Value> {
    let path = root.join(format!("{name}-lean-input.json"));
    write_json(&path, input)?;
    let out = Command::new("lean/.lake/build/bin/chaincheck")
        .arg("--prune")
        .arg(&path)
        .output()
        .map_err(|e| e.to_string())?;
    if !out.status.success() {
        return Err(format!(
            "Lean prune check failed: {}",
            String::from_utf8_lossy(&out.stderr)
        ));
    }
    serde_json::from_str(String::from_utf8_lossy(&out.stdout).trim()).map_err(|e| e.to_string())
}

/// The bytes of one call read until the node closes the socket: a reply the node begins
/// as 200 and then replaces (#85 Finding R2) is no single JSON document.
fn raw_call(n: &mut Node, method: &str, params: Value) -> Result<String> {
    let rpc = n.rpc.as_ref().ok_or("RPC not ready")?;
    let (host, port) = (rpc.host.clone(), rpc.port);
    let cookie = fs::read_to_string(n.dir.join("regtest/.cookie")).map_err(|e| e.to_string())?;
    let auth = bsv_script_harness::rpc::base64(cookie.trim().as_bytes());
    let body =
        json!({"jsonrpc":"1.0","id":"s7-82","method":method,"params":params.clone()}).to_string();
    let mut s = std::net::TcpStream::connect((host.as_str(), port)).map_err(|e| e.to_string())?;
    s.set_read_timeout(Some(Duration::from_secs(30)))
        .map_err(|e| e.to_string())?;
    let req = format!(
        "POST / HTTP/1.1\r\nHost: {host}:{port}\r\nAuthorization: Basic {auth}\r\nContent-Type: application/json\r\nContent-Length: {}\r\nConnection: close\r\n\r\n{body}",
        body.len()
    );
    s.write_all(req.as_bytes()).map_err(|e| e.to_string())?;
    let mut raw = Vec::new();
    // A reset after the bytes arrived ends the read; what was read is the observation.
    let read = s.read_to_end(&mut raw);
    let text = String::from_utf8_lossy(&raw).into_owned();
    n.calls.push(json!({"method":method,"params":params,"source":format!("[SRC] {} at {PIN}",handler(method)?),"raw_reply":text,"read_end":read.map(|_| "closed".to_owned()).unwrap_or_else(|e| e.to_string()),"instance_id":instance_pointer(&n.dir)}));
    Ok(text)
}

/// Mine `count` blocks in batches and return their hashes and serialized sizes.
fn mine(n: &mut Node, count: u64) -> Result<Vec<(String, u64)>> {
    let mut out = vec![];
    let mut left = count;
    while left > 0 {
        let batch = left.min(100);
        let hashes = n.call("generatetoaddress", json!([batch, address()]))?;
        for h in hashes.as_array().ok_or("generated hashes")? {
            let hash = text(h)?.to_owned();
            let hex = n.call("getblock", json!([hash, 0]))?;
            out.push((hash, text(&hex)?.len() as u64 / 2));
        }
        left -= batch;
    }
    Ok(out)
}

/// Submit a block at `height` holding its coinbase and one spend of the coinbase of block
/// `coin_height`; return its hash, its size and the spend's id.
fn submit_two(
    n: &mut Node,
    height: u64,
    coin_height: u64,
    tag: &str,
) -> Result<(String, u64, String)> {
    let hash = text(&n.call("getblockhash", json!([coin_height]))?)?.to_owned();
    let body = n.call("getblock", json!([hash, 1]))?;
    let coin = n.raw_tx(&body["tx"][0])?;
    let tx = spend(&coin, 100000, 1);
    let time = n.tip()?["time"].as_u64().ok_or("tip time")? + 1;
    let height32 = u32::try_from(height).map_err(|e| e.to_string())?;
    let time32 = u32::try_from(time).map_err(|e| e.to_string())?;
    let (h, receipt) = n.submit(&[cb(height32, tag), tx.clone()], time32)?;
    if block_judgment(&receipt) != json!({"status":"ok"}) {
        return Err(format!("probe block {tag}: {receipt}"));
    }
    let size = text(&n.call("getblock", json!([h, 0]))?)?.len() as u64 / 2;
    Ok((h, size, id(&tx)))
}

/// The genesis block's hash and size (written at startup).
fn genesis(n: &mut Node) -> Result<(String, u64)> {
    let hash = text(&n.call("getblockhash", json!([0]))?)?.to_owned();
    let hex = n.call("getblock", json!([hash, 0]))?;
    Ok((hash, text(&hex)?.len() as u64 / 2))
}

/// Every block's data and undo bits and whether `size` is present, by height.
fn bits(n: &mut Node, hashes: &[String]) -> Result<Value> {
    let (mut data, mut undo, mut size) = (vec![], vec![], vec![]);
    for h in hashes {
        let header = n.call("getblockheader", json!([h, true]))?;
        data.push(header["status"]["data"].as_bool().ok_or("status data")?);
        undo.push(header["status"]["undo"].as_bool().ok_or("status undo")?);
        size.push(header.get("size").is_some());
    }
    Ok(json!({"data":data,"undo":undo,"size_present":size}))
}

/// The block files present in the instance's `blocks/` directory, by number.
fn files(n: &Node, prefix: &str) -> Result<Vec<u64>> {
    let mut out = vec![];
    for entry in fs::read_dir(n.dir.join("regtest/blocks")).map_err(|e| e.to_string())? {
        let name = entry
            .map_err(|e| e.to_string())?
            .file_name()
            .to_string_lossy()
            .into_owned();
        if let Some(num) = name
            .strip_prefix(prefix)
            .and_then(|r| r.strip_suffix(".dat"))
        {
            out.push(num.parse::<u64>().map_err(|e| e.to_string())?);
        }
    }
    out.sort_unstable();
    Ok(out)
}

/// The node's reply as Lean's `Answer` words.
fn reply_words(r: &Value) -> Value {
    match r.get("error") {
        Some(e) => json!({"kind":"error","code":e["code"],"message":e["message"]}),
        None => json!({"kind":"served"}),
    }
}

fn pieces_ok(raw: &str, code: i64, message: &str) -> bool {
    raw.contains("HTTP/1.1 200 OK")
        && raw.contains("{\"result\": \"")
        && raw.contains("HTTP/1.1 500 Internal Server Error")
        && raw.contains(&format!(
            "\"error\":{{\"code\":{code},\"message\":\"{message}\"}}"
        ))
}

/// One probe request against Lean's answer.
fn probe(
    n: &mut Node,
    req: &str,
    hash: &str,
    height: u64,
    tx: &str,
    lean: &Value,
) -> Result<Value> {
    let kind = text(&lean["kind"])?;
    let (observed, agree) = if req == "getblock0" && kind == "head-then-error" {
        let raw = raw_call(n, "getblock", json!([hash, 0]))?;
        let ok = pieces_ok(
            &raw,
            lean["code"].as_i64().ok_or("code")?,
            text(&lean["message"])?,
        );
        (json!({"kind":"head-then-error","raw":raw}), ok)
    } else {
        let (method, params) = match req {
            "getblock0" => ("getblock", json!([hash, 0])),
            "getblock1" => ("getblock", json!([hash, 1])),
            "getblockheader" => ("getblockheader", json!([hash, true])),
            "getblockheader2" => ("getblockheader", json!([hash, 2])),
            "getrawtransaction" => ("getrawtransaction", json!([tx, 1])),
            "getmerkleproof" => ("getmerkleproof", json!([tx, hash])),
            "getmerkleproof2" => ("getmerkleproof2", json!([hash, tx])),
            "gettxout" => ("gettxout", json!([tx, 0])),
            "getblockhash" => ("getblockhash", json!([height])),
            _ => ("getchaintxstats", json!([0, hash])),
        };
        let r = n.receipt(method, params)?;
        let words = reply_words(&r);
        let mut ok = words["kind"] == lean["kind"]
            && (kind != "error"
                || (words["code"] == lean["code"] && words["message"] == lean["message"]));
        if kind == "served" {
            let result = &r["result"];
            ok &= !result.is_null();
            let absent: Vec<&str> = lean["absent"]
                .as_array()
                .map(|a| a.iter().filter_map(Value::as_str).collect())
                .unwrap_or_default();
            for field in &absent {
                ok &= result.get(*field).is_none();
            }
            let present: &[&str] = match req {
                "getblockheader" => &["size"],
                "getblockheader2" => &["size", "tx", "merkleproof"],
                _ => &[],
            };
            for field in present.iter().filter(|f| !absent.contains(f)) {
                ok &= result.get(*field).is_some();
            }
        }
        (
            json!({"kind":words["kind"],"code":words["code"],"message":words["message"],"fields":r["result"].as_object().map(|o| o.keys().cloned().collect::<Vec<_>>())}),
            ok,
        )
    };
    Ok(json!({"request":req,"lean":lean,"observed":observed,"agree":agree}))
}

fn compare_bits(node: &Value, lean: &Value) -> Value {
    let differ = |a: &Value, b: &Value| -> Vec<usize> {
        let (a, b) = (
            a.as_array().cloned().unwrap_or_default(),
            b.as_array().cloned().unwrap_or_default(),
        );
        let mut out: Vec<usize> = (0..a.len().max(b.len()))
            .filter(|i| a.get(*i) != b.get(*i))
            .collect();
        out.truncate(20);
        out
    };
    let data = differ(&node["data"], &lean["data"]);
    let undo = differ(&node["undo"], &lean["undo"]);
    let retained = node["data"]
        .as_array()
        .map(|a| a.iter().filter(|v| **v == true).count())
        .unwrap_or(0);
    json!({"blocks":node["data"].as_array().map(Vec::len),"retained":retained,"data_disagree":data,"undo_disagree":undo,"agree":data.is_empty() && undo.is_empty()})
}

fn step(id: &str, record: &str, agree: bool, observed: Value, expected: Value) -> Value {
    let verdict = if agree { "agree" } else { "diverge" };
    json!({"id":id,"verdict":verdict,"node":format!("measured {verdict} [X] {record}"),"label":"[D]","expected":expected,"expected_label":"[D]","observed":observed})
}

fn cfg(keep: u64) -> Value {
    json!({"mode":"manual","minBlocksToKeep":keep,"hysteresis":25,"preferredBlockFileSize":PREFERRED})
}

/// Phase A: manual pruning, the probes, the restart, the disconnect.
fn manual(root: &Path, record: &str, rows: &mut Vec<Value>) -> Result<Value> {
    let mut n = start_retry(
        root,
        "prune-manual",
        "prune=1\npreferredblockfilesize=4096\n",
    )?;
    let mut chain = vec![genesis(&mut n)?];
    let mut events = vec![json!({"block":[0, chain[0].1, false]})];
    let push =
        |chain: &mut Vec<(String, u64)>, events: &mut Vec<Value>, mined: Vec<(String, u64)>| {
            for (h, size) in mined {
                events.push(json!({"block":[chain.len(), size, true]}));
                chain.push((h, size));
            }
        };
    let mut cbs = BTreeMap::new();
    let mined = mine(&mut n, 139)?;
    push(&mut chain, &mut events, mined);
    for (name, height, coin) in [("P", 140, 1), ("T", 141, 2)] {
        let (h, size, tx) = submit_two(&mut n, height, coin, &format!("prune-{name}"))?;
        push(&mut chain, &mut events, vec![(h, size)]);
        cbs.insert(name, tx);
    }
    let mined = mine(&mut n, 858)?;
    push(&mut chain, &mut events, mined);
    // Before any pruning: T's merkle tree asked for.
    let t_hash = chain[141].0.clone();
    let before_proof = n.receipt("getmerkleproof", json!([cbs["T"], t_hash]))?;
    let before_proof2 = n.receipt("getmerkleproof2", json!([t_hash, cbs["T"]]))?;
    let mut node_replies = vec![];
    let mut node_bits = vec![];
    let mut node_files = vec![];
    let mut prune = |n: &mut Node,
                     events: &mut Vec<Value>,
                     tip: u64,
                     param: i64,
                     snap: bool,
                     chain: &[(String, u64)]|
     -> Result<()> {
        events.push(json!({"prune":{"tip":tip,"param":param}}));
        node_replies.push(n.receipt("pruneblockchain", json!([param]))?);
        if snap {
            let hashes: Vec<String> = chain.iter().map(|(h, _)| h.clone()).collect();
            node_bits.push(bits(n, &hashes)?);
            node_files.push(json!({"blk":files(n, "blk")?,"rev":files(n, "rev")?}));
        } else {
            node_bits.push(Value::Null);
            node_files.push(Value::Null);
        }
        Ok(())
    };
    prune(&mut n, &mut events, 999, 500, false, &chain)?;
    let mined = mine(&mut n, 1)?;
    push(&mut chain, &mut events, mined);
    prune(&mut n, &mut events, 1000, 500, true, &chain)?;
    let mined = mine(&mut n, 249)?;
    push(&mut chain, &mut events, mined);
    // R is mined only now, spending block 1000's coinbase (mature at 1100); it is never pruned.
    let (h, size, tx) = submit_two(&mut n, 1250, 1000, "prune-R")?;
    push(&mut chain, &mut events, vec![(h, size)]);
    cbs.insert("R", tx);
    let mined = mine(&mut n, 50)?;
    push(&mut chain, &mut events, mined);
    prune(&mut n, &mut events, 1300, 1100, true, &chain)?;
    prune(&mut n, &mut events, 1300, 0, true, &chain)?;
    prune(&mut n, &mut events, 1300, 5000, false, &chain)?;
    prune(&mut n, &mut events, 1300, -1, false, &chain)?;
    let probes: Vec<Value> = PROBES
        .iter()
        .map(|(name, h, tree)| json!({"index":h,"hash":chain[*h as usize].0,"treeHeld":tree,"name":name}))
        .collect();
    let lean = lean_prune(
        root,
        "manual",
        &json!({"config":cfg(KEEP),"pruneAfterHeight":AFTER,"events":events,"probes":probes}),
    )?;
    let replies = lean["replies"].as_array().ok_or("lean replies")?.clone();
    let ids = ["s1", "s2", "s3", "s4", "s5", "s6"];
    for (k, id) in ids.iter().enumerate() {
        let (lr, nr) = (&replies[k], &node_replies[k]);
        let mut agree = match lr["reply"].get("error") {
            Some(e) => nr["error"]["code"] == e["code"] && nr["error"]["message"] == e["message"],
            None => nr["result"] == lr["reply"]["result"],
        };
        let mut observed = json!({"reply":nr});
        if !node_bits[k].is_null() {
            let cmp = compare_bits(&node_bits[k], lr);
            agree &= cmp["agree"] == true;
            // [X] the files on disk are the Lean store's files less the removed ones.
            let removed: BTreeSet<u64> = lean["replies"]
                .as_array()
                .ok_or("replies")?
                .iter()
                .take(k + 1)
                .flat_map(|r| r["removed"].as_array().cloned().unwrap_or_default())
                .filter_map(|v| v.as_u64())
                .collect();
            let count = lr["count"].as_u64().ok_or("lean file count")?;
            let expect_files: Vec<u64> = (0..count).filter(|f| !removed.contains(f)).collect();
            let blk = node_files[k]["blk"].clone();
            let files_agree = blk == json!(expect_files);
            agree &= files_agree && node_files[k]["rev"] == blk;
            observed["bits"] = cmp;
            observed["files"] = json!({"blk":blk,"rev":node_files[k]["rev"],"lean":expect_files,"agree":files_agree});
        }
        rows.push(step(
            id,
            record,
            agree,
            observed,
            json!({"reply":lr["reply"],"removed":lr["removed"],"pruneheight":lr["pruneheight"]}),
        ));
    }
    // s7: getblockchaininfo after the clamp.
    let info = n.call("getblockchaininfo", json!([]))?;
    let lean_ph = &replies[2]["pruneheight"];
    rows.push(step(
        "s7",
        record,
        info["pruned"] == true && info["pruneheight"] == *lean_ph,
        json!({"pruned":info["pruned"],"pruneheight":info["pruneheight"]}),
        json!({"pruned":true,"pruneheight":lean_ph}),
    ));
    // s8: every request for the three probe blocks.
    let mut answers = vec![];
    for p in lean["probes"].as_array().ok_or("lean probes")? {
        let k = p["index"].as_u64().ok_or("probe index")?;
        let name = PROBES
            .iter()
            .find(|(_, h, _)| *h == k)
            .map(|(n, _, _)| *n)
            .ok_or("probe")?;
        let hash = text(&p["hash"])?.to_owned();
        let mut asked = vec![];
        for (req, lean_answer) in p["answers"].as_object().ok_or("answers")? {
            asked.push(probe(&mut n, req, &hash, k, &cbs[name], lean_answer)?);
        }
        answers.push(json!({"probe":name,"height":k,"data":p["data"],"treeHeld":p["treeHeld"],"requests":asked}));
    }
    let probes_agree = answers.iter().all(|a| {
        a["requests"]
            .as_array()
            .is_some_and(|r| r.iter().all(|q| q["agree"] == true))
    });
    rows.push(step("s8", record, probes_agree && before_proof.get("result").is_some() && before_proof2.get("result").is_some(),
        json!({"tree_asked_before_pruning":{"getmerkleproof":reply_words(&before_proof),"getmerkleproof2":reply_words(&before_proof2)},"probes":answers}),
        json!({"probes":lean["probes"]})));
    // s9: a restart empties the trees' memory cache; the store keeps T's tree.
    n.restart()?;
    let t_after = n.receipt("getmerkleproof", json!([cbs["T"], t_hash]))?;
    let p_after = n.receipt("getmerkleproof", json!([cbs["P"], chain[140].0]))?;
    let p_lean = &lean["probes"][0]["answers"]["getmerkleproof"];
    rows.push(step(
        "s9",
        record,
        t_after.get("result").is_some()
            && p_after["error"]["code"] == p_lean["code"]
            && p_after["error"]["message"] == p_lean["message"],
        json!({"T":reply_words(&t_after),"P":reply_words(&p_after)}),
        json!({"T":{"kind":"served","treeHeld":"store"},"P":p_lean}),
    ));
    // s10: invalidate below the pruned bound: the disconnect reaches a block without data.
    let last = replies[3]["data"].as_array().ok_or("final bits")?;
    let highest_pruned = last
        .iter()
        .rposition(|v| *v == false)
        .ok_or("nothing pruned")?;
    let _ = n.receipt("invalidateblock", json!([chain[900].0]));
    // WITHHELD: s7-82-record (s10 held in the record under the discretion group until routed)
    let held = "held in the record under the discretion group until routed";
    rows.push(json!({"id":"s10","verdict":"held","node":held,"label":"[D]",
        "expected":{"tip_stops_at":highest_pruned,"held":held},"expected_label":"[D]","observed":{"held":held}}));
    n.stop().ok();
    Ok(
        json!({"conf":n.conf,"lean":{"files":lean["files"],"last":lean["last"],"removed":lean["removed"],"fileOf":lean["fileOf"]},"sizes":chain.iter().map(|(_, s)| *s).collect::<Vec<_>>(),"hashes":chain.iter().map(|(h, _)| h.clone()).collect::<Vec<_>>(),"rpc":n.calls}),
    )
}

/// Phase B: `minBlocksToKeep` above the tip: the negative clamp.
fn negative(root: &Path, record: &str, rows: &mut Vec<Value>) -> Result<Value> {
    let mut n = start_retry(
        root,
        "prune-keep2000",
        "prune=1\npreferredblockfilesize=4096\npruneminblockstokeep=2000\n",
    )?;
    let mut chain = vec![genesis(&mut n)?];
    let mut events = vec![json!({"block":[0, chain[0].1, false]})];
    for (h, size) in mine(&mut n, 1000)? {
        events.push(json!({"block":[chain.len(), size, true]}));
        chain.push((h, size));
    }
    let blk_before = files(&n, "blk")?;
    events.push(json!({"prune":{"tip":1000,"param":10}}));
    let reply = n.receipt("pruneblockchain", json!([10]))?;
    let hashes: Vec<String> = chain.iter().map(|(h, _)| h.clone()).collect();
    let node_bits = bits(&mut n, &hashes)?;
    let blk_after = files(&n, "blk")?;
    n.stop()?;
    let lean = lean_prune(
        root,
        "keep2000",
        &json!({"config":cfg(2000),"pruneAfterHeight":AFTER,"events":events,"probes":[]}),
    )?;
    let lr = &lean["replies"][0];
    let cmp = compare_bits(&node_bits, lr);
    rows.push(step(
        "s11",
        record,
        reply["result"] == lr["reply"]["result"] && cmp["agree"] == true && blk_before == blk_after,
        json!({"reply":reply,"bits":cmp,"blk_before":blk_before.len(),"blk_after":blk_after.len()}),
        json!({"reply":lr["reply"],"removed":lr["removed"]}),
    ));
    Ok(json!({"conf":n.conf,"rpc":n.calls}))
}

/// Phase C: an unpruned node refuses the RPC and reports no prune height.
fn unpruned(root: &Path, record: &str, rows: &mut Vec<Value>) -> Result<Value> {
    let mut n = start_retry(root, "prune-off", "")?;
    let reply = n.receipt("pruneblockchain", json!([10]))?;
    let info = n.call("getblockchaininfo", json!([]))?;
    n.stop()?;
    let lean = lean_prune(
        root,
        "off",
        &json!({"config":{"mode":"off","minBlocksToKeep":KEEP,"hysteresis":25,"preferredBlockFileSize":134217728u64},"pruneAfterHeight":AFTER,"events":[{"block":[0,285,false]},{"prune":{"tip":0,"param":10}}],"probes":[]}),
    )?;
    let lr = &lean["replies"][0]["reply"];
    rows.push(step(
        "s12",
        record,
        reply["error"]["code"] == lr["error"]["code"]
            && reply["error"]["message"] == lr["error"]["message"]
            && info["pruned"] == false
            && info.get("pruneheight").is_none(),
        json!({"reply":reply,"pruned":info["pruned"],"pruneheight_present":info.get("pruneheight").is_some()}),
        json!({"reply":lr,"pruned":false,"pruneheight_present":false}),
    ));
    Ok(json!({"conf":n.conf,"rpc":n.calls}))
}

/// Phase D: the launch reading of `-prune` and an automatic target far above usage.
fn launch(root: &Path, record: &str, rows: &mut Vec<Value>) -> Result<Value> {
    let lean = lean_prune(
        root,
        "launch",
        &json!({"config":{"mode":{"auto":576716800u64},"minBlocksToKeep":KEEP,"hysteresis":25,"preferredBlockFileSize":PREFERRED},"pruneAfterHeight":AFTER,"events":[],"probes":[],"launchArgs":[549,-1]}),
    )?;
    let mut refusals = vec![];
    for (k, arg) in [549, -1].iter().enumerate() {
        let message = text(&lean["launch"][k]["error"])?.to_owned();
        let dir = root.join(format!("prune-launch-{k}"));
        let outcome = match Node::start(dir.clone(), 1_000_001, &format!("prune={arg}\n")) {
            Ok(mut n) => {
                n.stop().ok();
                json!({"started":true})
            }
            Err(e) => json!({"started":false,"error":e}),
        };
        let err = fs::read_to_string(dir.join("bitcoind.err")).unwrap_or_default();
        let console = fs::read_to_string(dir.join("console.log")).unwrap_or_default();
        let agree =
            outcome["started"] == false && (err.contains(&message) || console.contains(&message));
        refusals.push(
            json!({"arg":arg,"lean":message,"node":outcome,"stderr":err.trim(),"agree":agree}),
        );
    }
    rows.push(step(
        "s13",
        record,
        refusals.iter().all(|r| r["agree"] == true),
        json!({"refusals":refusals}),
        json!({"refusals":lean["launch"]}),
    ));
    let mut n = start_retry(
        root,
        "prune-auto",
        "prune=550\npreferredblockfilesize=4096\n",
    )?;
    let mut chain = vec![genesis(&mut n)?];
    let mut events = vec![json!({"block":[0, chain[0].1, false]})];
    for (h, size) in mine(&mut n, 1100)? {
        events.push(json!({"block":[chain.len(), size, true]}));
        chain.push((h, size));
    }
    events.push(json!({"auto":{"tip":1100,"flushed":1100}}));
    let hashes: Vec<String> = chain.iter().map(|(h, _)| h.clone()).collect();
    let node_bits = bits(&mut n, &hashes)?;
    let info = n.call("getblockchaininfo", json!([]))?;
    n.stop()?;
    let lean = lean_prune(
        root,
        "auto",
        &json!({"config":{"mode":{"auto":576716800u64},"minBlocksToKeep":KEEP,"hysteresis":25,"preferredBlockFileSize":PREFERRED},"pruneAfterHeight":AFTER,"events":events,"probes":[]}),
    )?;
    let lr = &lean["replies"][0];
    let cmp = compare_bits(&node_bits, lr);
    rows.push(step(
        "s14",
        record,
        cmp["agree"] == true && info["pruned"] == true && info["pruneheight"] == lr["pruneheight"],
        json!({"bits":cmp,"pruned":info["pruned"],"pruneheight":info["pruneheight"]}),
        json!({"removed":lr["removed"],"pruneheight":lr["pruneheight"]}),
    ));
    Ok(json!({"conf":n.conf,"rpc":n.calls}))
}

pub(super) fn main(record: &str, run_id: Option<String>, write: bool) -> Result<()> {
    let stem = record
        .strip_prefix("docs/records/")
        .and_then(|r| r.strip_suffix("-s7-82-prune-s1.md"));
    if !stem.is_some_and(|s| !s.is_empty() && s.bytes().all(|c| c.is_ascii_digit() || c == b'-')) {
        return Err("record must be docs/records/<stamp>-s7-82-prune-s1.md".into());
    }
    let run_id = run_id.unwrap_or_else(|| format!("prune-82-{}", stem.unwrap_or("run")));
    if !run_id
        .bytes()
        .all(|c| c.is_ascii_alphanumeric() || c == b'-')
    {
        return Err("unsafe run id".into());
    }
    let declared = scenario(&PathBuf::from(format!("corpus/scenarios/{SCENARIO}.md")))?;
    let ids: Vec<&str> = declared["steps"]
        .as_array()
        .ok_or("declared steps")?
        .iter()
        .filter_map(|s| s["id"].as_str())
        .collect();
    let home = PathBuf::from(std::env::var("HOME").map_err(|e| e.to_string())?);
    let root = home.join("bsv/targets/spec-oracle-scenarios").join(&run_id);
    fs::create_dir_all(&root).map_err(|e| e.to_string())?;
    let head = Command::new("git")
        .args(["rev-parse", "HEAD"])
        .output()
        .map_err(|e| e.to_string())?;
    let started = Command::new("date")
        .args(["-u", "+%Y-%m-%dT%H:%M:%SZ"])
        .output()
        .map_err(|e| e.to_string())?;
    let start = Instant::now();
    let mut rows = vec![];
    let a = manual(&root, record, &mut rows)?;
    let b = negative(&root, record, &mut rows)?;
    let c = unpruned(&root, record, &mut rows)?;
    let d = launch(&root, record, &mut rows)?;
    let got: Vec<&str> = rows.iter().filter_map(|r| r["id"].as_str()).collect();
    if got != ids {
        return Err(format!(
            "step contract mismatch: declared {ids:?}, ran {got:?}"
        ));
    }
    let held = rows.iter().filter(|r| r["verdict"] == "held").count();
    let agree = rows.iter().filter(|r| r["verdict"] == "agree").count();
    let mut out = json!({"scenario":SCENARIO,"source_pin":PIN,"record":record,"run_id":run_id,
        "base_commit":String::from_utf8_lossy(&head.stdout).trim(),
        "started_utc":String::from_utf8_lossy(&started.stdout).trim(),
        "wall_seconds":{"label":"[M]","value":start.elapsed().as_secs_f64()},
        "instances":{"manual":a,"keep2000":b,"off":c,"launch":d},"steps":rows,
        "counts":{"label":"[M]","rows":got.len(),"realized":got.len(),"agree":agree,"held":held,"diverge":got.len()-agree-held}});
    let full = root.join("receipt.json");
    write_json(&full, &out)?;
    let bytes = fs::read(&full).map_err(|e| e.to_string())?;
    out["full_receipt"] = json!({"label":"[M]","path":instance_pointer(&full),"bytes":bytes.len(),
        "sha256":hex::encode(bsv_rs::primitives::hash::sha256(&bytes))});
    for phase in ["manual", "keep2000", "off", "launch"] {
        if let Some(o) = out["instances"][phase].as_object_mut() {
            o.remove("rpc");
            o.remove("hashes");
        }
    }
    write_json(&PathBuf::from(record.replace(".md", ".json")), &out)?;
    if write {
        let path = format!("corpus/scenarios/{SCENARIO}.md");
        let mut raw = fs::read_to_string(&path).map_err(|e| e.to_string())?;
        for row in &rows {
            raw = raw.replacen(
                "\"node\": \"pending #66\"",
                &format!("\"node\": \"{}\"", text(&row["node"])?),
                1,
            );
        }
        fs::write(&path, raw).map_err(|e| e.to_string())?;
        write_json(
            &PathBuf::from(format!("corpus/scenarios/{SCENARIO}.node.json")),
            &json!({"scenario":SCENARIO,"record":record,"steps":out["steps"],"counts":out["counts"]}),
        )?;
    }
    let failed = agree + held != got.len();
    println!(
        "prune node: {} [X] ([M] {agree}/{} steps agree, {held} held; wall {:.3}s)",
        if failed { "RED" } else { "GREEN" },
        got.len(),
        start.elapsed().as_secs_f64()
    );
    if failed {
        Err("prune divergence".into())
    } else {
        Ok(())
    }
}
