//! #84 (S7, lane events-84): the reference's ZMQ topics and invalid-transaction
//! sinks observed on one fresh regtest instance of the zmq build, through a
//! reorg and a double spend. Each step's declared machine transitions are
//! mapped to messages by a transcription of `Events.events`
//! (lean/BsvChain/Views/Events.lean); every recorded message is matched to one
//! of them or filed as a witness, and every mapped message the node did not
//! publish is filed too. Sources: bitcoin-sv 6504a3aff65ba97c0f6c80962b033e35ecbfed4b.
use super::core::*;

const SCENARIO: &str = "corpus/scenarios/2026-10-15-events-reorg-doublespend.md";
// [SRC] the eleven factories, src/zmq/zmqnotificationinterface.cpp:59-80 at PIN.
const TOPICS: [&str; 11] = [
    "hashblock",
    "hashtx",
    "rawblock",
    "rawtx",
    "invalidtx",
    "discardedfrommempool",
    "removedfrommempoolblock",
    "hashblock2",
    "rawblock2",
    "hashtx2",
    "rawtx2",
];

// The launch extras: every notifier on one loopback address, both sinks.
fn extras() -> String {
    let mut lines: Vec<String> = TOPICS
        .iter()
        .map(|t| format!("zmqpub{t}=tcp://127.0.0.1:{{ZMQ_PORT}}"))
        .collect();
    lines.extend(
        [
            "invalidtxsink=ZMQ",
            "invalidtxsink=FILE",
            "debug=mempool",
            "debug=zmq",
        ]
        .map(str::to_owned),
    );
    lines.join("\n")
}

// [SRC] the reason each removal site passes (src/txmempool.cpp at PIN) and the
// word its topic publishes (src/zmq/zmqpublishnotifier.cpp:181-248): the
// transcription of RemovalSite.reason, removalTopic and reasonWord.
fn removal_word(site: &str) -> Result<(&'static str, &'static str)> {
    Ok(match site {
        "removeForBlockMined" => ("removedfrommempoolblock", "included-in-block"),
        "removeForBlockConflict" => ("discardedfrommempool", "collision-in-block-tx"),
        "expire" | "minerInfoDataref" => ("discardedfrommempool", "expired"),
        "trimToSize" => ("discardedfrommempool", "mempool-sizelimit-exceeded"),
        "removeForReorg"
        | "reorgFiltered"
        | "reorgNotReadmitted"
        | "removeFromMempoolForReorg"
        | "capDisconnectPool" => ("removedfrommempoolblock", "reorg"),
        "removeFrozenInput" | "removeNotWhitelisted" => ("discardedfrommempool", "unknown-reason"),
        _ => return Err(format!("unknown removal site {site}")),
    })
}

fn key(topic: &str, k: Value) -> String {
    json!({"topic":topic,"key":k}).to_string()
}

struct Names {
    txs: BTreeMap<String, String>,
    blocks: BTreeMap<String, String>,
}
impl Names {
    fn tx(&self, name: &str) -> Result<String> {
        self.txs
            .get(name)
            .cloned()
            .ok_or_else(|| format!("unbound transaction {name}"))
    }
    fn block(&self, name: &str) -> Result<String> {
        self.blocks
            .get(name)
            .cloned()
            .ok_or_else(|| format!("unbound block {name}"))
    }
    fn of_tx(&self, txid: &str) -> String {
        self.txs
            .iter()
            .find(|(_, v)| v.as_str() == txid)
            .map_or_else(|| txid.to_owned(), |(k, _)| k.clone())
    }
    fn of_block(&self, hash: &str) -> String {
        self.blocks
            .iter()
            .find(|(_, v)| v.as_str() == hash)
            .map_or_else(|| hash.to_owned(), |(k, _)| k.clone())
    }
}

fn strings(v: &Value) -> Result<Vec<String>> {
    v.as_array()
        .ok_or("expected a list")?
        .iter()
        .map(|s| text(s).map(str::to_owned))
        .collect()
}

// The transcription of Events.events for one declared transition.
fn mapped(t: &Value, names: &Names) -> Result<Vec<String>> {
    let tx_pair =
        |hash: &str, raw: &str, txid: &str| vec![key(hash, json!(txid)), key(raw, json!(txid))];
    let mut out = vec![];
    if let Some(name) = t.get("accept") {
        let txid = names.tx(text(name)?)?;
        let source = text(&t["source"])?;
        let invalid = |missing: bool, code: u64, reason: &str| {
            key(
                "invalidtx",
                json!({"txid":txid,"fromBlock":false,"source":source,"isMissingInputs":missing,"rejectionCode":code,"rejectionReason":reason}),
            )
        };
        match &t["outcome"] {
            v if v == "accepted" || v == "heldNonFinal" => {
                out.extend(tx_pair("hashtx", "rawtx", &txid));
                out.extend(tx_pair("hashtx2", "rawtx2", &txid));
            }
            v if v == "orphan" => out.push(invalid(true, 0, "")),
            v => {
                let rejected = v["rejected"].as_array().ok_or("accept outcome")?;
                let code = rejected
                    .first()
                    .and_then(Value::as_u64)
                    .ok_or("rejected code")?;
                let reason = rejected.get(1).map(text).transpose()?.ok_or("reason")?;
                if code != 257 {
                    out.push(invalid(false, code, reason));
                }
            }
        }
    } else if let Some(site) = t.get("removal") {
        let (topic, word) = removal_word(text(site)?)?;
        let (collided, block) = match t.get("spender") {
            Some(s) => (
                json!(names.tx(text(s)?)?),
                json!(names.block(text(&t["block"])?)?),
            ),
            None => (Value::Null, Value::Null),
        };
        for id in strings(&t["ids"])? {
            out.push(key(
                topic,
                json!({"txid":names.tx(&id)?,"reason":word,"collidedWith":collided,"blockhash":block}),
            ));
        }
    } else if let Some(range) = t.get("connectRange") {
        let bounds = range.as_array().ok_or("connectRange")?;
        let (a, b) = (
            bounds
                .first()
                .and_then(Value::as_u64)
                .ok_or("range start")?,
            bounds.get(1).and_then(Value::as_u64).ok_or("range end")?,
        );
        for h in a..=b {
            let one =
                json!({"connect":format!("g{h}"),"pre_pool":[],"body":[format!("g{h}:coinbase")]});
            out.extend(mapped(&one, names)?);
            let tip = json!({"tip":format!("g{h}"),"fork":format!("g{}", h - 1)});
            out.extend(mapped(&tip, names)?);
        }
    } else if let Some(block) = t.get("connect") {
        // ibd is false for every declared connect: the instance leaves initial download at genesis
        let hash = names.block(text(block)?)?;
        let pre = strings(&t["pre_pool"])?;
        for name in strings(&t["body"])? {
            if !pre.contains(&name) {
                out.extend(tx_pair("hashtx2", "rawtx2", &names.tx(&name)?));
            }
        }
        out.push(key("hashblock2", json!(hash)));
        out.push(key("rawblock2", json!(hash)));
        for name in strings(&t["body"])? {
            out.extend(tx_pair("hashtx", "rawtx", &names.tx(&name)?));
        }
    } else if t.get("disconnect").is_some() {
        for name in strings(&t["body"])? {
            out.extend(tx_pair("hashtx", "rawtx", &names.tx(&name)?));
        }
    } else if let Some(tip) = t.get("tip") {
        if tip != &t["fork"] {
            let hash = names.block(text(tip)?)?;
            out.push(key("hashblock", json!(hash)));
            out.push(key("rawblock", json!(hash)));
        }
    } else if t.get("silent").is_none() {
        return Err(format!("unknown transition {t}"));
    }
    Ok(out)
}

// A recorded message's key, by its topic's payload (zmqpublishnotifier.cpp:118-292;
// invalid_txn_publisher.cpp:76-181 at PIN).
fn observed(m: &ZmqMessage) -> String {
    let parsed = || serde_json::from_slice::<Value>(&m.body).unwrap_or(Value::Null);
    let k = match m.topic.as_str() {
        "hashtx" | "hashtx2" | "hashblock" | "hashblock2" if m.body.len() == 32 => {
            json!(hex::encode(&m.body))
        }
        "rawtx" | "rawtx2" => RawTx::decode(&m.body).map_or(Value::Null, |tx| json!(id(&tx))),
        "rawblock" | "rawblock2" if m.body.len() >= 80 => {
            let mut h = bsv_rs::primitives::hash::sha256d(&m.body[..80]);
            h.reverse();
            json!(hex::encode(h))
        }
        "discardedfrommempool" | "removedfrommempoolblock" => {
            let v = parsed();
            json!({"txid":v["txid"],"reason":v["reason"],"collidedWith":v["collidedWith"]["txid"],"blockhash":v["blockhash"]})
        }
        "invalidtx" => invalid_key(&parsed()),
        _ => json!({"unparsed":hex::encode(&m.body)}),
    };
    key(&m.topic, k)
}

fn invalid_key(v: &Value) -> Value {
    json!({"txid":v["txid"],"fromBlock":v["fromBlock"],"source":v["source"],"isMissingInputs":v["isMissingInputs"],
        "rejectionCode":v["rejectionCode"],"rejectionReason":v["rejectionReason"]})
}

// Multiset matching: each mapped key consumes one equal recorded key.
fn matching(expected: &[String], recorded: &[String]) -> (usize, Vec<String>, Vec<String>) {
    let mut pool: BTreeMap<&String, usize> = BTreeMap::new();
    for r in recorded {
        *pool.entry(r).or_default() += 1;
    }
    let (mut matched, mut missing) = (0, vec![]);
    for e in expected {
        match pool.get_mut(e) {
            Some(n) if *n > 0 => {
                *n -= 1;
                matched += 1;
            }
            _ => missing.push(e.clone()),
        }
    }
    let unmapped = pool
        .into_iter()
        .flat_map(|(k, n)| std::iter::repeat_n(k.clone(), n))
        .collect();
    (matched, unmapped, missing)
}

fn summary(m: &ZmqMessage) -> Value {
    json!({"index":m.index,"topic":m.topic,"sequence":m.sequence,"frames":m.frames,"bytes":m.body.len(),
        "body_sha256":hex::encode(bsv_rs::primitives::hash::sha256(&m.body)),"key":serde_json::from_str::<Value>(&observed(m)).map(|v| v["key"].clone()).unwrap_or(Value::Null)})
}

fn mempool_names(n: &mut Node, names: &Names) -> Result<Vec<String>> {
    let mut pool: Vec<String> = n
        .call("getrawmempool", json!([]))?
        .as_array()
        .ok_or("getrawmempool")?
        .iter()
        .map(|t| text(t).map(|t| names.of_tx(t)))
        .collect::<Result<_>>()?;
    pool.sort();
    Ok(pool)
}

fn bind_block(n: &mut Node, names: &mut Names, name: &str, hash: &str) -> Result<Vec<String>> {
    names.blocks.insert(name.to_owned(), hash.to_owned());
    let block = n.call("getblock", json!([hash, 1]))?;
    let txs = strings(&block["tx"])?;
    if let Some(cb) = txs.first() {
        names.txs.insert(format!("{name}:coinbase"), cb.clone());
    }
    Ok(txs)
}

struct Fixture {
    bodies: BTreeMap<String, RawTx>,
    clock: u64,
}

// One step's action; the RPC receipts are returned for the record.
fn act(n: &mut Node, names: &mut Names, fx: &mut Fixture, action: &Value) -> Result<Value> {
    fx.clock += 10;
    let kind = text(&action["type"])?;
    match kind {
        "seed" => {
            let (f, t, base) = seed(n)?;
            for h in 1..=100u64 {
                let hash = n.call("getblockhash", json!([h]))?;
                bind_block(n, names, &format!("g{h}"), text(&hash)?)?;
            }
            let genesis = n.call("getblockhash", json!([0]))?;
            names.blocks.insert("g0".into(), text(&genesis)?.to_owned());
            bind_block(n, names, "base", &base)?;
            let g4 = n.call("getblockhash", json!([4]))?;
            let cb4 = n.call("getblock", json!([g4, 1]))?;
            let cb4 = n.raw_tx(&cb4["tx"][0])?;
            let k = spend(&f, 98000, 1);
            let u = spend(&t, 98000, 1);
            let m = spend(&cb4, 4_999_990_000, 1);
            for (name, tx) in [("F", f), ("T", t), ("K", k), ("U", u), ("M", m)] {
                names.txs.insert(name.into(), id(&tx));
                fx.bodies.insert(name.into(), tx);
            }
            Ok(json!({"seeded":"g1..g100, base"}))
        }
        "submit" => {
            let tx = fx.bodies.get(text(&action["tx"])?).ok_or("unknown body")?;
            n.receipt("sendrawtransaction", json!([hex::encode(tx.encode())]))
        }
        "submitblock" => {
            let block = text(&action["block"])?;
            let parent = txid_from_display_hex(&names.block(text(&action["parent"])?)?)?;
            let height = n.call(
                "getblockheader",
                json!([names.block(text(&action["parent"])?)?]),
            )?["height"]
                .as_u64()
                .ok_or("parent height")?
                + 1;
            let mut txs = vec![];
            for name in strings(&action["transactions"])? {
                if name == format!("{block}:coinbase") {
                    let coinbase = cb(height as u32, block);
                    names.txs.insert(name, id(&coinbase));
                    txs.push(coinbase);
                } else {
                    txs.push(fx.bodies.get(&name).ok_or("unknown body")?.clone());
                }
            }
            let bits =
                u32::from_str_radix(text(&n.tip()?["bits"])?, 16).map_err(|e| e.to_string())?;
            n.call("setmocktime", json!([fx.clock]))?;
            let (header, bytes) = block_codec::assemble(4, parent, fx.clock as u32, bits, &txs);
            names
                .blocks
                .insert(block.to_owned(), txid_display_hex(&header.hash()));
            n.receipt("submitblock", json!([hex::encode(bytes)]))
        }
        "generate" => {
            let hashes = n.mine(1, fx.clock)?;
            let hash = text(hashes.first().ok_or("no generated block")?)?.to_owned();
            bind_block(n, names, text(&action["block"])?, &hash)?;
            Ok(json!({"generated":hash}))
        }
        "invalidateblock" | "reconsiderblock" => {
            let hash = names.block(text(&action["block"])?)?;
            n.receipt(kind, json!([hash]))
        }
        _ => Err(format!("unknown action {kind}")),
    }
}

// The declared body of a connection or disconnection against the block the node holds.
fn body_check(n: &mut Node, names: &Names, t: &Value) -> Result<Option<Value>> {
    let Some(block) = t.get("connect").or_else(|| t.get("disconnect")) else {
        return Ok(None);
    };
    let hash = names.block(text(block)?)?;
    let held = strings(&n.call("getblock", json!([hash, 1]))?["tx"])?;
    let declared = strings(&t["body"])?
        .iter()
        .map(|name| names.tx(name))
        .collect::<Result<Vec<_>>>()?;
    Ok(Some(
        json!({"block":text(block)?,"declared":declared,"held":held,"equal":declared == held}),
    ))
}

fn sequences(messages: &[ZmqMessage]) -> Value {
    let mut out = serde_json::Map::new();
    for topic in TOPICS {
        let seen: Vec<u32> = messages
            .iter()
            .filter(|m| m.topic == topic)
            .filter_map(|m| m.sequence)
            .collect();
        let contiguous = seen.iter().enumerate().all(|(i, s)| *s as usize == i);
        out.insert(
            topic.into(),
            json!({"count":seen.len(),"lowest":seen.first(),"highest":seen.last(),"contiguous_from_zero":contiguous}),
        );
    }
    Value::Object(out)
}

// [SRC] the notifiers' own log lines under debug=zmq (src/zmq/zmqpublishnotifier.cpp:120,132,154,270 at PIN):
// a second, independent count of the sends of every topic that logs, and each logged send no message matched,
// with its console line (an earlier line precedes the subscription).
fn console_counts(dir: &Path, messages: &[ZmqMessage]) -> Result<Value> {
    let log = fs::read_to_string(dir.join("console.log")).map_err(|e| e.to_string())?;
    let mut out = serde_json::Map::new();
    for topic in TOPICS {
        let mut logged = vec![];
        for (line, l) in log.lines().enumerate() {
            let words: Vec<&str> = l.split_whitespace().collect();
            if let Some(w) = words
                .windows(4)
                .find(|w| w[0] == "zmq:" && w[1] == "Publish" && w[2] == topic)
            {
                logged.push((line + 1, w[3].to_owned()));
            } else if topic == "invalidtx" && l.contains("zmq: Publish text with topic: invalidtx")
            {
                logged.push((line + 1, String::new()));
            }
        }
        let mut received: BTreeMap<String, usize> = BTreeMap::new();
        for m in messages.iter().filter(|m| m.topic == topic) {
            let k = serde_json::from_str::<Value>(&observed(m))
                .map_or(Value::Null, |v| v["key"].clone());
            *received
                .entry(k.as_str().unwrap_or("").to_owned())
                .or_default() += 1;
        }
        let count = messages.iter().filter(|m| m.topic == topic).count();
        let mut unreceived = vec![];
        for (line, k) in &logged {
            match received.get_mut(k) {
                Some(n) if *n > 0 => *n -= 1,
                _ if topic == "invalidtx" => {}
                _ => unreceived.push(json!({"console_line":line,"key":k})),
            }
        }
        let first_received_line = logged
            .iter()
            .find(|(_, k)| !unreceived.iter().any(|u| u["key"] == k.as_str()))
            .map(|(line, _)| *line);
        let logs = !matches!(topic, "discardedfrommempool" | "removedfrommempoolblock");
        out.insert(
            topic.into(),
            json!({"logged":logged.len(),"received":count,"logs_at_pin":logs,"equal":!logs || logged.len() == count,
                "logged_not_received":unreceived,"first_received_console_line":first_received_line}),
        );
    }
    Ok(Value::Object(out))
}

// [SRC] the FILE sink's files (src/invalid_txn_sinks/file_sink.cpp:12-40,44-46 at PIN) against the ZMQ sink's messages.
fn file_sink(dir: &Path, messages: &[ZmqMessage]) -> Result<Value> {
    let folder = dir.join("regtest/invalidtxs");
    let mut files = vec![];
    if folder.is_dir() {
        for entry in fs::read_dir(&folder).map_err(|e| e.to_string())? {
            let path = entry.map_err(|e| e.to_string())?.path();
            let v: Value = serde_json::from_slice(&fs::read(&path).map_err(|e| e.to_string())?)
                .map_err(|e| e.to_string())?;
            let name = path
                .file_name()
                .map(|n| n.to_string_lossy().into_owned())
                .unwrap_or_default();
            files.push(json!({"name":name,"key":invalid_key(&v),"has_hex":v.get("hex").is_some()}));
        }
    }
    files.sort_by_key(|f| f["name"].as_str().map(str::to_owned));
    let mut from_files: Vec<String> = files.iter().map(|f| f["key"].to_string()).collect();
    let mut from_zmq: Vec<String> = messages
        .iter()
        .filter(|m| m.topic == "invalidtx")
        .map(|m| invalid_key(&serde_json::from_slice(&m.body).unwrap_or(Value::Null)).to_string())
        .collect();
    from_files.sort();
    from_zmq.sort();
    let names_ok = files.iter().all(|f| {
        let name = f["name"].as_str().unwrap_or("");
        let txid = f["key"]["txid"].as_str().unwrap_or("-");
        name.len() > 20 && name.contains(&format!("_{txid}_")) && name.ends_with(".json")
    });
    let mut seen = BTreeSet::new();
    let hex_rule = files.iter().all(|f| {
        let earliest = seen.insert(f["key"]["txid"].to_string());
        f["has_hex"].as_bool() == Some(earliest)
    });
    Ok(
        json!({"files":files,"equal_to_zmq":from_files == from_zmq,"file_names_match":names_ok,
        "hex_only_in_a_txids_earliest_file":hex_rule}),
    )
}

fn steps(fence: &Value) -> Result<&Vec<Value>> {
    fence["steps"]
        .as_array()
        .ok_or_else(|| "scenario steps".into())
}

pub(super) fn run(root: &Path) -> Result<Value> {
    let raw = fs::read_to_string(SCENARIO).map_err(|e| e.to_string())?;
    let fence: Value = serde_json::from_str(
        raw.split("```json\n")
            .nth(1)
            .and_then(|r| r.split("\n```").next())
            .ok_or("scenario fence")?,
    )
    .map_err(|e| e.to_string())?;
    let binary = Build::Zmq.path()?;
    let banner = Build::Zmq.version_at(&binary)?;
    let digest = hex::encode(bsv_rs::primitives::hash::sha256(
        &fs::read(&binary).map_err(|e| e.to_string())?,
    ));
    let mut n = start_retry_build(root, "events", 1_000_001, &extras(), Build::Zmq)?;
    let port: u16 = n
        .conf
        .lines()
        .find_map(|l| l.strip_prefix("zmqpubhashtx=tcp://127.0.0.1:"))
        .and_then(|p| p.parse().ok())
        .ok_or("zmq port in the instance configuration")?;
    let sub = Subscriber::connect(port)?;
    thread::sleep(Duration::from_millis(500));
    let before_steps = sub.settle(Duration::from_millis(1500), Duration::from_secs(30))?;
    let mut names = Names {
        txs: BTreeMap::new(),
        blocks: BTreeMap::new(),
    };
    let mut fx = Fixture {
        bodies: BTreeMap::new(),
        clock: 1_700_000_100,
    };
    let mut results = vec![];
    for step in steps(&fence)? {
        let start = sub.count()?;
        let receipt = act(&mut n, &mut names, &mut fx, &step["action"])?;
        let end = sub.settle(Duration::from_millis(1500), Duration::from_secs(120))?;
        let messages = sub.since(start)?;
        let mut expected = vec![];
        let mut bodies = vec![];
        for t in step["transitions"].as_array().ok_or("transitions")? {
            expected.extend(mapped(t, &names)?);
            if let Some(check) = body_check(&mut n, &names, t)? {
                bodies.push(check);
            }
        }
        let recorded: Vec<String> = messages.iter().map(observed).collect();
        let (matched, unmapped, missing) = matching(&expected, &recorded);
        let pool = mempool_names(&mut n, &names)?;
        let tip = names.of_block(text(&n.call("getbestblockhash", json!([]))?)?);
        let mut declared_pool = strings(&step["expected_observations"]["mempool"])?;
        declared_pool.sort();
        let state_ok = pool == declared_pool
            && tip == text(&step["expected_observations"]["tip"])?
            && bodies.iter().all(|b| b["equal"] == true);
        let agree = unmapped.is_empty() && missing.is_empty() && state_ok;
        println!(
            "events {}: {} [X] ({} recorded, {} mapped, {} matched, {} witnesses)",
            text(&step["id"])?,
            if agree { "agree" } else { "diverge" },
            recorded.len(),
            expected.len(),
            matched,
            unmapped.len() + missing.len()
        );
        results.push(json!({"id":step["id"],"verdict":if agree {"agree"} else {"diverge"},"label":"[X]",
            "messages":{"from":start,"to":end,"recorded":recorded.len(),"mapped":expected.len(),"matched":matched},
            "witness_recorded_without_transition":unmapped.iter().map(|k| serde_json::from_str::<Value>(k).unwrap_or(Value::Null)).collect::<Vec<_>>(),
            "witness_transition_without_message":missing.iter().map(|k| serde_json::from_str::<Value>(k).unwrap_or(Value::Null)).collect::<Vec<_>>(),
            "state":{"mempool":pool,"declared_mempool":declared_pool,"tip":tip,"bodies":bodies,"equal":state_ok},
            "receipt":receipt}));
    }
    let all = sub.since(0)?;
    let console = console_counts(&n.dir, &all)?;
    let files = file_sink(&n.dir, &all)?;
    let seq = sequences(&all);
    n.stop()?;
    let handshake = json!({"zmtp":sub.handshake.clone(),"instance":instance_pointer(&n.dir),
        "protocol":"ZMTP 3.0 NULL mechanism, SUB, the empty prefix"});
    let ending = sub.close()?;
    let agree = results.iter().filter(|r| r["verdict"] == "agree").count();
    Ok(
        json!({"scenario":fence["id"],"binary":{"build":Build::Zmq.name(),"banner":banner,"sha256":digest,
            "option":"BUILD_BITCOIN_ZMQ=ON (src/CMakeLists.txt:13 at PIN); every other option the node of record's"},
        "subscriber":handshake,"messages_before_steps":before_steps,"reader_ending":ending,
        "counts":{"label":"[M]","steps":results.len(),"agree":agree,"diverge":results.len()-agree,"messages":all.len()},
        "sequences":seq,"console":console,"file_sink":files,"names":{"transactions":names.txs.iter().filter(|(k, _)| !k.starts_with('g')).collect::<BTreeMap<_, _>>(),"blocks":names.blocks.iter().filter(|(k, _)| !k.starts_with('g')).collect::<BTreeMap<_, _>>()},"steps":results,
        "messages":all.iter().map(summary).collect::<Vec<_>>(),"rpc":n.calls}),
    )
}

// The record's projection without RPC bodies; the full receipt stays in the run.
pub(super) fn main(record: &str, run_id: Option<String>, write: bool) -> Result<()> {
    let stem = record
        .strip_prefix("docs/records/")
        .and_then(|r| r.strip_suffix("-s7-84-events-s1.md"));
    if !stem.is_some_and(|s| !s.is_empty() && s.bytes().all(|c| c.is_ascii_digit() || c == b'-')) {
        return Err("record must be docs/records/<stamp>-s7-84-events-s1.md".into());
    }
    let run_id = run_id.unwrap_or_else(|| format!("events-84-{}", stem.unwrap_or("run")));
    if !run_id
        .bytes()
        .all(|c| c.is_ascii_alphanumeric() || c == b'-')
    {
        return Err("unsafe run id".into());
    }
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
    let mut out = run(&root)?;
    out["record"] = json!(record);
    out["run_id"] = json!(run_id);
    out["source_pin"] = json!(PIN);
    out["base_commit"] = json!(String::from_utf8_lossy(&head.stdout).trim());
    out["started_utc"] = json!(String::from_utf8_lossy(&started.stdout).trim());
    out["wall_seconds"] = json!({"label":"[M]","value":start.elapsed().as_secs_f64()});
    let full = root.join("receipt.json");
    write_json(&full, &out)?;
    let bytes = fs::read(&full).map_err(|e| e.to_string())?;
    out["full_receipt"] = json!({"label":"[M]","path":instance_pointer(&full),"bytes":bytes.len(),
        "sha256":hex::encode(bsv_rs::primitives::hash::sha256(&bytes))});
    out.as_object_mut().ok_or("receipt")?.remove("rpc");
    write_json(&PathBuf::from(record.replace(".md", ".json")), &out)?;
    if write {
        let mut raw = fs::read_to_string(SCENARIO).map_err(|e| e.to_string())?;
        for step in out["steps"].as_array().ok_or("steps")? {
            let token = format!("measured {} [X] {record}", text(&step["verdict"])?);
            raw = raw.replacen(
                "\"node\": \"pending #66\"",
                &format!("\"node\": \"{token}\""),
                1,
            );
        }
        fs::write(SCENARIO, raw).map_err(|e| e.to_string())?;
    }
    let failed = out["counts"]["diverge"] != 0;
    println!(
        "events node: {} [X] ({}; wall [M] {:.3}s)",
        if failed { "RED" } else { "GREEN" },
        out["counts"],
        start.elapsed().as_secs_f64()
    );
    if failed {
        Err("event divergence or witness".into())
    } else {
        Ok(())
    }
}
