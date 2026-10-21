//! [D] 2026-10-13: #67 independent status witnesses. Views are never rules.
//! Producer contexts and Lean projections are derived; only RPC/P2P evidence is observed.
use super::core::*;
use std::io::{Read, Write};
use std::net::TcpStream;

// [SRC] bitcoin-sv src/chainparams.cpp:1504-1507 and src/net/net.cpp at PIN.
// This peer connects only to the owned fresh node's loopback listener.
struct Peer {
    stream: TcpStream,
    buffer: Vec<u8>,
    messages: Vec<Value>,
    ready: bool,
}
impl Peer {
    fn send(&mut self, command: &str, payload: &[u8]) -> Result<()> {
        let mut packet = vec![0xda, 0xb5, 0xbf, 0xfa];
        let mut name = [0u8; 12];
        name[..command.len()].copy_from_slice(command.as_bytes());
        packet.extend(name);
        packet.extend((payload.len() as u32).to_le_bytes());
        packet.extend(&bsv_script_harness::txraw::sha256d(payload)[..4]);
        packet.extend(payload);
        self.stream.write_all(&packet).map_err(|e| e.to_string())?;
        self.messages.push(json!({"direction":"sent","command":command,"payload_hex":hex::encode(payload),"label":"[M]"}));
        Ok(())
    }
    fn poll(&mut self) -> Result<()> {
        let mut bytes = [0u8; 65536];
        match self.stream.read(&mut bytes) {
            Ok(0) => return Err("owned loopback peer disconnected".into()),
            Ok(n) => self.buffer.extend_from_slice(&bytes[..n]),
            Err(e)
                if matches!(
                    e.kind(),
                    std::io::ErrorKind::WouldBlock | std::io::ErrorKind::TimedOut
                ) =>
            {
                return Ok(())
            }
            Err(e) => return Err(e.to_string()),
        }
        while self.buffer.len() >= 24 {
            if self.buffer[..4] != [0xda, 0xb5, 0xbf, 0xfa] {
                return Err("peer magic mismatch".into());
            }
            let length = u32::from_le_bytes(
                self.buffer[16..20]
                    .try_into()
                    .or_err("self.buffer[16..20].try_into()")?,
            ) as usize;
            if length > 4_000_000 {
                return Err("peer payload bound".into());
            }
            if self.buffer.len() < 24 + length {
                break;
            }
            let name = String::from_utf8_lossy(&self.buffer[4..16])
                .trim_end_matches('\0')
                .to_owned();
            let payload = self.buffer[24..24 + length].to_vec();
            if self.buffer[20..24] != bsv_script_harness::txraw::sha256d(&payload)[..4] {
                return Err("peer checksum mismatch".into());
            }
            self.buffer.drain(..24 + length);
            self.messages.push(json!({"direction":"received","command":name,"payload_hex":hex::encode(&payload),"label":"[M]"}));
            match name.as_str() {
                "version" => self.send("verack", &[])?,
                "verack" => self.ready = true,
                "ping" => self.send("pong", &payload)?,
                _ => (),
            }
        }
        Ok(())
    }
    fn connect(n: &Node) -> Result<Self> {
        let port = n
            .conf
            .lines()
            .find_map(|l| l.strip_prefix("port="))
            .ok_or("peer port missing")?;
        let stream = TcpStream::connect(format!("127.0.0.1:{port}")).map_err(|e| e.to_string())?;
        stream
            .set_read_timeout(Some(Duration::from_millis(100)))
            .map_err(|e| e.to_string())?;
        stream
            .set_write_timeout(Some(Duration::from_secs(2)))
            .map_err(|e| e.to_string())?;
        let mut peer = Self {
            stream,
            buffer: vec![],
            messages: vec![],
            ready: false,
        };
        let mut version = vec![];
        version.extend(70016i32.to_le_bytes());
        version.extend(1u64.to_le_bytes());
        // [D] 2026-10-13 (#72): advertise the node's mock time, never a
        // constant or the host clock, so the offset sample is zero
        // ([SRC] src/net/net_processing.cpp:1896-1898 at PIN).
        version.extend((n.clock as i64).to_le_bytes());
        for _ in 0..2 {
            version.extend(1u64.to_le_bytes());
            version.extend([0u8; 26 - 8]);
        }
        version.extend(67u64.to_le_bytes());
        let agent = b"/s6-status-views:0.1/";
        version.push(agent.len() as u8);
        version.extend(agent);
        version.extend(101i32.to_le_bytes());
        version.push(1);
        peer.send("version", &version)?;
        let start = Instant::now();
        while !peer.ready {
            peer.poll()?;
            if start.elapsed() > Duration::from_secs(10) {
                return Err("peer handshake timeout".into());
            }
        }
        Ok(peer)
    }
}

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
fn sweep(n: &mut Node) -> Result<()> {
    let probes: Vec<Value> = (0..2)
        .map(|lock_time| {
            let tx = RawTx {
                version: 1,
                inputs: vec![],
                outputs: vec![RawOutput {
                    satoshis: 1,
                    script: script(),
                }],
                lock_time,
            };
            json!({"hex":hex::encode(tx.encode())})
        })
        .collect();
    let reply = n.call("sendrawtransactions", json!([probes]))?;
    if reply["invalid"].as_array().is_none_or(|a| {
        a.len() != 2 || a.iter().any(|r| r["reject_reason"] != "bad-txns-vin-empty")
    }) {
        return Err("expiry trigger rejected-work receipts missing".into());
    }
    Ok(())
}
fn observe(
    n: &mut Node,
    tx: &RawTx,
    f: &RawTx,
    mined: Option<&String>,
    rejection: Option<Value>,
    orphan: bool,
) -> Result<(Value, Value)> {
    let txid = id(tx);
    let pool = n.call("getrawmempool", json!([]))?;
    let held = n.call("getrawnonfinalmempool", json!([]))?;
    let orphans = n.call("getorphaninfo", json!([]))?;
    let tips = n.call("getchaintips", json!([]))?;
    let best = n.call("getbestblockhash", json!([]))?;
    let out = n.call("gettxout", json!([id(f), 0, false]))?;
    let mut evidence = Evidence {
        accepted: pool.as_array().is_some_and(|a| a.contains(&json!(txid))),
        held: held.as_array().is_some_and(|a| a.contains(&json!(txid))),
        rejection,
        ..Default::default()
    };
    if orphan {
        if orphans["size"] != 1 {
            return Err(format!("isolated orphan count not one: {orphans}"));
        }
        evidence.isolated_orphan = true;
    } else if orphans["size"] != 0 {
        return Err("unexpected orphan".into());
    }
    let mut bodies = vec![];
    if let Some(hash) = mined {
        let body = n.call("getblock", json!([hash, 1]))?;
        if body["tx"]
            .as_array()
            .is_some_and(|a| a.contains(&json!(txid)))
        {
            if body["confirmations"].as_i64().is_some_and(|v| v > 0) {
                evidence
                    .active_heights
                    .push(body["height"].as_u64().ok_or("height")?);
            } else if body["confirmations"] == -1 {
                evidence.stale = true;
            }
        }
        bodies.push(body);
    }
    // Bind any conflict to a different actual active-chain spender of the exact input.
    let active = n.call("getblock", json!([best, 1]))?;
    for spender in active["tx"].as_array().ok_or("active tx list")? {
        if spender == &json!(txid) {
            continue;
        }
        let raw = n.call("getrawtransaction", json!([spender, 1]))?;
        for input in &tx.inputs {
            let previous = txid_display_hex(&input.txid);
            let coin = n.call("gettxout", json!([previous, input.vout, false]))?;
            if coin.is_null()
                && raw["vin"].as_array().is_some_and(|a| {
                    a.iter()
                        .any(|i| i["txid"] == previous && i["vout"] == input.vout)
                })
            {
                evidence.exact_active_conflict = true;
            }
        }
    }
    let result = status(&evidence);
    Ok((
        result,
        json!({"mempool":pool,"non_final_pool":held,"orphans":orphans,"chain_tips":tips,"best":best,"funding_output":out,"selected_bodies":bodies,"active_body":active,"exact_active_conflict":evidence.exact_active_conflict}),
    ))
}

// [D] 2026-10-13: independent replay of source predicates, never producer runtimes.
// Arcade models/transaction.go:90-93,167-176 at 1ae1208e;
// wallet sdk/types.ts:22-34,48 and storage/methods/processAction.ts:359-370;
// TaskFailAbandoned.ts:36-46, ListActionsSpecOp.ts:123-139 at edf6e03d;
// validator Server.go:970-974,992-1002; services/validator/http_options_guard.go:57-59; propagation Server.go:759-790 at 4edb60a4.
fn context_words(row: &str, c: &Value) -> Option<Value> {
    let b = |key: &str| c[key].as_bool();
    if !c["arcade_prior"].as_str()?.ends_with("UNKNOWN") || b("later_arcade_event")? {
        return None;
    }
    let arcade = if b("receipt_delivered")? {
        "RECEIVED"
    } else {
        "UNKNOWN"
    };
    let request = if row == "rejected" {
        if b("structurally_valid")?
            || b("signed_complete")?
            || b("no_send")?
            || b("delayed")?
            || !b("believed_sent")?
            || b("send_with")?
        {
            return None;
        }
        if b("rejection_delivered")? {
            "invalid"
        } else {
            "unknown"
        }
    } else {
        if !b("structurally_valid")?
            || !b("signed_complete")?
            || b("send_with")?
            || b("believed_sent")?
            || b("rejection_delivered")?
        {
            return None;
        }
        match (b("no_send")?, b("delayed")?) {
            (true, false) => "nosend",
            (false, true) => "unsent",
            _ => return None,
        }
    };
    let prior = c["wallet_before_failure"].as_str()?;
    if !(prior.ends_with("unprocessed") || prior.ends_with("unsigned"))
        || c["wallet_updated_at"].as_u64()?
            >= c["wallet_now"]
                .as_u64()?
                .saturating_sub(c["wallet_abandoned_msecs"].as_u64()?)
        || !b("wallet_failure_applied")?
        || !b("failed_filter_selected")?
    {
        return None;
    }
    let wallet = if b("recovery_label")? {
        "unfail"
    } else {
        "failed"
    };
    let validator = if b("validator_skip_policy_checks")? {
        "BadRequest"
    } else if c["validator_error_cause"] == ""
        && b("validator_response_valid")?
        && b("structurally_valid")?
    {
        "OK"
    } else if !b("validator_response_valid")?
        && !c["validator_reason"].as_str()?.is_empty()
        && ((c["validator_error_cause"] == "ErrTxMissingParent"
            && !b("validator_parent_known")?
            && b("structurally_valid")?)
            || (c["validator_error_cause"] == "ErrTxInvalid" && !b("structurally_valid")?))
    {
        "InternalServerError"
    } else {
        return None;
    };
    let propagation = match c["propagation_cause"].as_str()? {
        "ErrInvalidArgument" => "BadRequest",
        "ErrServiceError" => "InternalServerError",
        _ => return None,
    };
    Some(
        json!({"Arcade":arcade,"ProvenTxReqStatus":request,"TransactionStatus":wallet,
        "Teranode validator":validator,"Teranode propagation":propagation}),
    )
}

// [D] 2026-10-14 (#72): classify from the complete call history, including
// setup and completion calls outside the step RPC slices.
fn gate_offsets(steps: &mut [Value], calls: &Value, record: &str) {
    if offset_uncontrolled(calls) {
        for step in steps {
            step["verdict"] = json!("non-judging");
            step["node"] = json!(format!(
                "measured non-judging: #72 adjusted-time offset not controlled [X] {record}"
            ));
        }
    }
}

pub(super) fn run(root: &Path, record: &str, write: bool) -> Result<Vec<Value>> {
    let lean = Command::new("lean/.lake/build/bin/chaincheck")
        .arg("--status-views")
        .output()
        .map_err(|e| e.to_string())?;
    if !lean.status.success() {
        return Err(format!(
            "Lean status-view replay: {}",
            String::from_utf8_lossy(&lean.stderr)
        ));
    }
    let projections: Vec<Value> = String::from_utf8_lossy(&lean.stdout)
        .lines()
        .map(|line| serde_json::from_str(line).map_err(|e| e.to_string()))
        .collect::<Result<_>>()?;
    if projections.len() != 8 {
        return Err("Lean status view row count".into());
    }
    let mut results = vec![];
    for projection in projections {
        let row = text(&projection["row"])?;
        let name = format!("2026-10-13-status-view-{row}");
        let path = PathBuf::from(format!("corpus/scenarios/{name}.md"));
        let declared = scenario(&path)?;
        let steps_declared = declared["steps"].as_array().ok_or("declared steps")?;
        if steps_declared.len() != 2
            || steps_declared[0]["action"]["type"] != "statusFixture"
            || steps_declared[0]["action"]["recipe"] != row
            || steps_declared[1]["action"]["type"] != "observeClient"
            || steps_declared[1]["action"]["node_transition"] != false
        {
            return Err("status witness action contract mismatch".into());
        }
        let extra = if row == "orphan" {
            "genesisactivationheight=100\nlisten=1\nbind=127.0.0.1\nconnect=0\ndebug=net\ndebug=txnval\ndebug=mempool\n"
        } else {
            "genesisactivationheight=100\n"
        };
        let mut n = start_retry(root, &name, extra)?;
        let (f, parent, base) = seed(&mut n)?;
        let mut tx = parent.clone();
        if row == "orphan" {
            tx = spend(&parent, 98000, 1);
        }
        if row == "heldNonFinal" {
            // An OP_TRUE funding output removes any signature mutation issue.
            let funding = spend_to(&f, 99000, 1, vec![0x51]);
            let (hash, receipt) = n.submit(&[cb(102, "held-fund"), funding.clone()], 1700000000)?;
            if block_judgment(&receipt) != json!({"status":"ok"}) {
                return Err(format!("held funding {receipt}"));
            }
            tx = RawTx {
                version: 2,
                inputs: vec![RawInput {
                    txid: funding.txid_internal(),
                    vout: 0,
                    script: vec![],
                    sequence: 0,
                }],
                outputs: vec![RawOutput {
                    satoshis: 98000,
                    script: vec![0x51],
                }],
                lock_time: 103,
            };
            // The witness names the held transaction's live tip 102 explicitly.
            n.calls.push(json!({"event":"held-funding","block":hash,"transaction":material(&funding),"label":"[M]"}));
        }
        if row == "rejected" {
            tx.inputs.clear();
        }
        let setup = n.calls.clone();
        let mut peer = None;
        let mut mined = None;
        let mut rejected = None;
        // [D] 2026-10-13 (#72): the observed body of the mined block, judged
        // only when it is the body [T] the Lean projection mined.
        let mut assembly: Option<Vec<String>> = None;
        let offset = n.calls.len();
        if row == "orphan" {
            let empty = n.call("getorphaninfo", json!([]))?;
            if empty["size"] != 0 {
                return Err("orphan baseline nonempty".into());
            }
            let mut p = Peer::connect(&n)?;
            let clock = n.clock;
            super::peer::peer_clock(&mut n, clock)?;
            p.send("tx", &tx.encode())?;
            let start = Instant::now();
            loop {
                p.poll()?;
                let count = n.call("getorphaninfo", json!([]))?;
                let requested = p.messages.iter().any(|m| {
                    m["command"] == "getdata"
                        && m["payload_hex"]
                            .as_str()
                            .is_some_and(|s| s.contains(&hex::encode(parent.txid_internal())))
                });
                if count["size"] == 1 && requested {
                    break;
                }
                if start.elapsed() > Duration::from_secs(15) {
                    return Err(format!(
                        "orphan retention/request timeout: {count}; peer {}",
                        serde_json::to_string(&p.messages)
                            .or_err("serde_json::to_string(&p.messages)")?
                    ));
                }
            }
            peer = Some(p);
        } else if row != "unknown" {
            let receipt = n.receipt("sendrawtransaction", json!([hex::encode(tx.encode())]))?;
            if row == "rejected" {
                rejected = node_reject(&receipt);
            } else if receipt.get("error").is_some() {
                return Err(format!("status-view admission {row}: {receipt}"));
            }
        }
        if row == "minedActive" || row == "onStaleBranch" {
            mined = Some(text(&n.mine(1, 1700000001)?[0])?.to_owned());
            let body = n.body(&json!(mined))?;
            n.calls.push(json!({"event":"assembly-gate","label":"[X]","observed_body":body,"required_body":[id(&tx)]}));
            assembly = Some(body);
            if row == "onStaleBranch" {
                n.call("invalidateblock", json!([mined]))?;
                n.call("setmocktime", json!([1701209602]))?;
                sweep(&mut n)?;
            }
        }
        if row == "conflictedByMinedSpend" {
            let conflict = spend(&f, 98000, 2);
            let (hash, receipt) = n.submit(&[cb(102, "conflict"), conflict.clone()], 1700000001)?;
            if block_judgment(&receipt) != json!({"status":"ok"}) {
                return Err(format!("conflict block {receipt}"));
            }
            mined = Some(hash);
        }
        let mut steps = vec![];
        for (index, step) in declared["steps"]
            .as_array()
            .ok_or("declared steps")?
            .iter()
            .enumerate()
        {
            let before = if index == 0 { offset } else { n.calls.len() };
            let (observed, raw) = observe(
                &mut n,
                &tx,
                &f,
                mined.as_ref(),
                rejected.clone(),
                row == "orphan",
            )?;
            let expected = &step["expected_observations"]["transactions"]["T"];
            let mut expected_status = expected.clone();
            for key in ["label", "node", "rules"] {
                expected_status
                    .as_object_mut()
                    .ok_or("expected status")?
                    .remove(key);
            }
            let context = if index == 0 { "initial" } else { "alternate" };
            let producer = &projection["producer_contexts"][context];
            let words = &producer["words"];
            let predicates = context_words(row, &producer["inputs"]).as_ref() == Some(words)
                && producer["inputs"] == step["action"]["producer_inputs"]
                && producer["predicates_checked"] == true
                && projection["incompatible_contexts_rejected"] == true
                && producer["inputs"]["structurally_valid"] == json!(!tx.inputs.is_empty());
            let mut bad_inputs = Vec::new();
            for (key, value) in [
                ("wallet_failure_applied", json!(false)),
                ("arcade_prior", json!("BsvChain.Views.Arcade.MINED")),
                ("propagation_cause", json!("unsupported")),
            ] {
                let mut bad = producer["inputs"].clone();
                bad[key] = value;
                bad_inputs.push(bad);
            }
            let mut bad = producer["inputs"].clone();
            bad["validator_skip_policy_checks"] = json!(false);
            bad["validator_response_valid"] = json!(false);
            bad["validator_reason"] = json!("");
            bad_inputs.push(bad);
            let mut bad = producer["inputs"].clone();
            bad["validator_skip_policy_checks"] = json!(false);
            bad["validator_error_cause"] = json!("");
            bad_inputs.push(bad);
            if row == "rejected" {
                let mut bad = producer["inputs"].clone();
                bad["validator_skip_policy_checks"] = json!(false);
                bad["validator_response_valid"] = json!(true);
                bad["validator_error_cause"] = json!("");
                bad_inputs.push(bad);
                let mut bad = producer["inputs"].clone();
                bad["signed_complete"] = json!(true);
                bad["no_send"] = json!(true);
                bad_inputs.push(bad);
            }
            let rejects_incompatible = bad_inputs
                .iter()
                .all(|bad| context_words(row, bad).is_none());
            let cells = &projection["cells"];
            let all_cells = cells.as_object().is_some_and(|object| {
                object.len() == 6
                    && object.iter().all(|(name, cell)| {
                        if name == "node rejection" {
                            cell["kind"] == "function"
                                && (if observed["value"] == "rejected" {
                                    cell["output"]["reason"] == observed["reason"]
                                        && cell["output"]["word"]
                                            .as_str()
                                            .is_some_and(|w| w.ends_with("REJECT_INVALID"))
                                } else {
                                    cell["output"].is_null()
                                })
                        } else if name == "Arcade"
                            && (row == "minedActive" || row == "onStaleBranch")
                        {
                            cell["kind"] == "function"
                                && cell["partial"] == true
                                && cell["output"] == "MINED"
                                && raw["selected_bodies"].as_array().is_some_and(|bodies| {
                                    bodies.iter().any(|body| {
                                        (if row == "minedActive" {
                                            body["confirmations"].as_i64().is_some_and(|n| n > 0)
                                        } else {
                                            body["confirmations"] == -1
                                                && body["hash"] != raw["best"]
                                                && observed["value"] == "onStaleBranch"
                                        }) && body["tx"]
                                            .as_array()
                                            .is_some_and(|txs| txs.contains(&json!(id(&tx))))
                                    })
                                })
                        } else if name == "Arcade" && row == "rejected" {
                            // [SRC] 2026-10-13: REJECTED means rejected, transaction.go:104-105
                            // at 1ae1208e. Stored transitions :227-237 are separate.
                            cell["kind"] == "function"
                                && cell["partial"] == true
                                && cell["output"] == "REJECTED"
                                && observed["namespace"] == "node"
                                && observed["code"] == 16
                                && observed["reason"] == "bad-txns-vin-empty"
                                && tx.inputs.is_empty()
                                && n.calls[offset..].iter().any(|call| {
                                    call["method"] == "sendrawtransaction"
                                        && call["reply"]["error"]["code"] == -26
                                        && node_reject(&call["reply"]).is_some_and(|receipt| {
                                            receipt["namespace"] == observed["namespace"]
                                                && receipt["code"] == observed["code"]
                                                && receipt["reason"] == observed["reason"]
                                        })
                                })
                                && cell["stored_lifecycle_obstruction"]
                                    .as_str()
                                    .is_some_and(|reason| !reason.is_empty())
                        } else if name == "ProvenTxReqStatus" && row == "conflictedByMinedSpend" {
                            cell["kind"] == "function"
                                && cell["partial"] == true
                                && cell["output"] == "doubleSpend"
                                && observed["value"] == "conflictedByMinedSpend"
                                && raw["exact_active_conflict"] == true
                        } else if name == "ProvenTxReqStatus" && row == "rejected" {
                            cell["kind"] == "function"
                                && cell["partial"] == true
                                && cell["output"] == "invalid"
                                && observed["namespace"] == "node"
                                && observed["code"] == 16
                                && observed["reason"] == "bad-txns-vin-empty"
                                && tx.inputs.is_empty()
                        } else {
                            cell["kind"] == "no function"
                                && projection["producer_contexts"]["initial"]["words"][name]
                                    != projection["producer_contexts"]["alternate"]["words"][name]
                                && cell["witness"] == declared["id"]
                                && cell["reason"].as_str().is_some_and(|r| !r.is_empty())
                        }
                    })
            });
            let semantic_outputs: serde_json::Map<String, Value> = cells
                .as_object()
                .ok_or("cell map")?
                .iter()
                .filter(|(_, cell)| cell["partial"] == true)
                .map(|(name, cell)| (name.clone(), cell["output"].clone()))
                .collect();
            let semantic_expected = &step["expected_observations"]["semantic_views"];
            let matches = semantic_expected["label"] == "[D]"
                && semantic_expected["outputs"] == Value::Object(semantic_outputs)
                && expected_status == observed
                && projection["status"] == observed
                && words == &step["expected_observations"]["client_views"]
                && all_cells
                && predicates
                && rejects_incompatible;
            let unchanged = steps.last().is_none_or(|earlier: &Value| {
                earlier["observed"] == observed && earlier["raw"] == raw
            });
            let verdict = if assembly.as_ref().is_some_and(|b| b != &vec![id(&tx)]) {
                "non-judging"
            } else if matches && unchanged {
                "agree"
            } else {
                "diverge"
            };
            let node_words = json!({"kind":"OBSERVED","label":"[M]","accepted_pool_rpc":raw["mempool"],"held_pool_rpc":raw["non_final_pool"],"orphan_count_rpc":raw["orphans"],"chain_tip_words":raw["chain_tips"],"selected_body_confirmations":raw["selected_bodies"].as_array().map(|a|a.iter().map(|b|b["confirmations"].clone()).collect::<Vec<_>>()),"submission_rpc_receipts":n.calls[offset..].iter().filter(|c|c["method"]=="sendrawtransaction").map(|c|c["reply"].clone()).collect::<Vec<_>>(),"note":"RPC has no single unknown/conflict/stale transaction status word; Status is the derived journal/body/pool projection"});
            steps.push(json!({"id":step["id"],"verdict":verdict,"node":format!("measured {verdict} [X] {record}"),"expected":expected_status,"expected_label":"[D]","observed":observed,"raw":raw,"node_vocabulary":node_words,"rpc":n.calls[before..],"derived_client_words":words,"producer_context":producer,"predicates_verified":predicates,"incompatible_context_rejected":rejects_incompatible,"expected_semantic_views":semantic_expected,"derived_cells":cells,"label":"[D]","scope":"node state/RPC measured; Lean status and producer context outputs derived; no external producer runs"}));
        }
        let mut completion = json!(null);
        if let Some(p) = &mut peer {
            p.send("tx", &parent.encode())?;
            let start = Instant::now();
            loop {
                p.poll()?;
                let pool = n.call("getrawmempool", json!([]))?;
                let count = n.call("getorphaninfo", json!([]))?;
                if pool
                    .as_array()
                    .is_some_and(|a| a.contains(&json!(id(&tx))) && a.contains(&json!(id(&parent))))
                    && count["size"] == 0
                {
                    completion = json!({"accepted":pool,"orphans":count,"child_resubmitted":false,"label":"[M]"});
                    break;
                }
                if start.elapsed() > Duration::from_secs(15) {
                    return Err("orphan parent-arrival revalidation timeout".into());
                }
            }
        }
        n.stop()?;
        gate_offsets(&mut steps, &json!(n.calls), record);
        let agree = steps.iter().filter(|s| s["verdict"] == "agree").count();
        let non_judging = steps
            .iter()
            .filter(|s| s["verdict"] == "non-judging")
            .count();
        let result = json!({"scenario":name,"source_pin":PIN,"record":record,"setup":setup,"conf":n.conf,"base":base,"fixtures":{"funding":material(&f),"transaction":material(&tx),"withheld_parent":material(&parent)},"steps":steps,"lean_projection":projection,"producer_label":"[D]","p2p":peer.map(|p|p.messages),"orphan_completion":completion,"counts":{"label":"[M]","rows":2,"realized":2-non_judging,"agree":agree,"diverge":2-non_judging-agree,"rpc-precheck":0,"unrealizable":0,"non-judging":non_judging,"needs-peer":0,"pending":0}});
        if write {
            super::intake::mark_scenario(&path, &result)?;
            write_json(
                &PathBuf::from(format!("corpus/scenarios/{name}.node.json")),
                &result,
            )?;
        }
        println!("status-view scenario {name}: [M] {agree}/2 agree [X]");
        results.push(result);
    }
    Ok(results)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn complete_view_offset_classification() {
        let original = vec![
            json!({"verdict":"agree","node":"measured agree [X] record","rpc":[]}),
            json!({"verdict":"diverge","node":"measured diverge [X] record","rpc":[]}),
        ];
        for (clock, peer, gated) in [(0, 0, false), (3, 0, true), (0, -1, true)] {
            let calls = json!([
                {"event":"clock","timeoffset":clock},
                {"event":"peer-clock","timeoffset":0,"peer_timeoffsets":[0,peer]}
            ]);
            let mut steps = original.clone();
            gate_offsets(&mut steps, &calls, "record");
            if gated {
                assert!(steps.iter().all(|s| s["verdict"] == "non-judging"
                    && s["node"]
                        .as_str()
                        .unwrap()
                        .starts_with("measured non-judging:")));
            } else {
                assert_eq!(steps, original);
            }
        }
    }
}
