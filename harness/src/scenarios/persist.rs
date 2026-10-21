//! #81 (S7, lane s7-81): mempool persistence across restarts. One fresh
//! regtest instance is filled with transactions of the kinds a load keeps and
//! drops, then restarted on its own data directory with `-persistmempool` on,
//! off and on; every step's pools, entry times, fee deltas, the two dump files
//! (parsed), the load's per-record fates and its logged counts are compared
//! with the scenario's declarations, which `chaincheck --persist` checks
//! against `lean/BsvChain/Persist.lean`. Sources: bitcoin-sv
//! 6504a3aff65ba97c0f6c80962b033e35ecbfed4b, src/init.cpp:237-240,1901-1905,
//! src/txmempool.cpp:2996-3344, src/time_locked_mempool.cpp:247-378.
use super::core::*;

const SCENARIO: &str = "corpus/scenarios/2026-10-15-persist-restart.md";
// [D] the launch input that makes the held pool reachable: before Genesis a
// non-final transaction is refused (src/validation.cpp:5977-5993 at PIN).
// `debug=mempool` makes the transaction database's launch cross-check
// observable (LogPrint(BCLog::MEMPOOL), src/txmempool.cpp:3050-3053,3070-3073).
const EXTRAS: &str = "genesisactivationheight=100\ndebug=txnval\ndebug=mempool";

struct Fixture {
    txs: Vec<(String, RawTx)>,
    blocks: BTreeMap<String, String>,
    coins: BTreeMap<String, RawTx>,
    clock: BTreeMap<String, u64>,
    tip_height: u64,
}

impl Fixture {
    fn name_of(&self, txid: &str) -> String {
        self.txs
            .iter()
            .find(|(_, t)| id(t) == txid)
            .map_or_else(|| format!("unnamed:{txid}"), |(n, _)| n.clone())
    }
    fn tx(&self, name: &str) -> Result<&RawTx> {
        self.txs
            .iter()
            .find(|(n, _)| n == name)
            .map(|(_, t)| t)
            .ok_or_else(|| format!("unknown fixture {name}"))
    }
    fn clock_of(&self, v: &Value) -> Result<u64> {
        let sym = text(v)?;
        self.clock
            .get(sym)
            .copied()
            .ok_or_else(|| format!("unknown clock {sym}"))
    }
}

fn sorted(mut v: Vec<String>) -> Value {
    v.sort();
    json!(v)
}

fn take<'a>(b: &'a [u8], p: &mut usize, n: usize) -> Result<&'a [u8]> {
    let s = b
        .get(*p..*p + n)
        .ok_or_else(|| format!("dump file ends at {p} reading {n} bytes"))?;
    *p += n;
    Ok(s)
}
fn u64_le(b: &[u8], p: &mut usize) -> Result<u64> {
    let mut a = [0u8; 8];
    a.copy_from_slice(take(b, p, 8)?);
    Ok(u64::from_le_bytes(a))
}
fn compact(b: &[u8], p: &mut usize) -> Result<u64> {
    let prefix = take(b, p, 1)?[0];
    Ok(match prefix {
        0xfd => {
            let s = take(b, p, 2)?;
            u16::from_le_bytes([s[0], s[1]]) as u64
        }
        0xfe => {
            let s = take(b, p, 4)?;
            u32::from_le_bytes([s[0], s[1], s[2], s[3]]) as u64
        }
        0xff => u64_le(b, p)?,
        n => n as u64,
    })
}
// A serialized fixture body at the cursor, found by its exact encoding.
fn body(b: &[u8], p: &mut usize, fx: &Fixture) -> Result<String> {
    let rest = b.get(*p..).ok_or("dump cursor out of range")?;
    for (name, tx) in &fx.txs {
        let enc = tx.encode();
        if rest.starts_with(&enc) {
            *p += enc.len();
            return Ok(name.clone());
        }
    }
    Err(format!("an unknown transaction body at offset {p}"))
}

// [SRC] the accepted pool's file: version, the instance id (version 2), the
// count, each record (in-memory flag, body or txid, entry time, fee delta),
// then the residual delta map: src/txmempool.cpp:2996-3021,3296-3328 and the
// uuid's 16 raw bytes, src/serialize.h:984-1000 at PIN.
fn parse_mempool_dat(b: &[u8], fx: &Fixture) -> Result<Value> {
    let mut p = 0;
    let version = u64_le(b, &mut p)?;
    if version >= 2 {
        take(b, &mut p, 16)?;
    }
    let count = u64_le(b, &mut p)?;
    let mut records = vec![];
    for _ in 0..count {
        let in_memory = version < 2 || take(b, &mut p, 1)?[0] != 0;
        let name = if in_memory {
            body(b, &mut p, fx)?
        } else {
            let mut a = [0u8; 32];
            a.copy_from_slice(take(b, &mut p, 32)?);
            fx.name_of(&txid_display_hex(&a))
        };
        let time = u64_le(b, &mut p)? as i64;
        let delta = u64_le(b, &mut p)? as i64;
        records.push(json!({"name":name,"in_memory":in_memory,"time":time,"fee_delta":delta}));
    }
    let n = compact(b, &mut p)?;
    let mut deltas = vec![];
    for _ in 0..n {
        let mut a = [0u8; 32];
        a.copy_from_slice(take(b, &mut p, 32)?);
        let delta = u64_le(b, &mut p)? as i64;
        deltas.push(json!({"name":fx.name_of(&txid_display_hex(&a)),"delta":delta}));
    }
    Ok(
        json!({"version":version,"records":records,"deltas":deltas,"trailing_bytes":b.len()-p,
        "source":format!("[SRC] src/txmempool.cpp:2996-3021,3296-3328; src/serialize.h:984-1000 at {PIN}")}),
    )
}

// [SRC] the held pool's file: version 1, the count, each body and entry time,
// src/time_locked_mempool.h:98 and src/time_locked_mempool.cpp:262-272 at PIN.
fn parse_nonfinal_dat(b: &[u8], fx: &Fixture) -> Result<Value> {
    let mut p = 0;
    let version = u64_le(b, &mut p)?;
    let count = u64_le(b, &mut p)?;
    let mut records = vec![];
    for _ in 0..count {
        let name = body(b, &mut p, fx)?;
        let time = u64_le(b, &mut p)? as i64;
        records.push(json!({"name":name,"time":time}));
    }
    Ok(
        json!({"version":version,"records":records,"trailing_bytes":b.len()-p,
        "source":format!("[SRC] src/time_locked_mempool.cpp:262-272 at {PIN}")}),
    )
}

// Both files of a stopped instance: bytes, sha256 and the parsed records.
fn read_files(dir: &Path, fx: &Fixture) -> Result<Value> {
    let mut out = serde_json::Map::new();
    for (key, file) in [
        ("mempool", "mempool.dat"),
        ("non_final", "non-final-mempool.dat"),
    ] {
        let path = dir.join("regtest").join(file);
        let v = match fs::read(&path) {
            Ok(b) => {
                let parsed = if key == "mempool" {
                    parse_mempool_dat(&b, fx)?
                } else {
                    parse_nonfinal_dat(&b, fx)?
                };
                json!({"bytes":b.len(),"sha256":hex::encode(bsv_rs::primitives::hash::sha256(&b)),"parsed":parsed})
            }
            Err(_) => Value::Null,
        };
        out.insert(key.to_owned(), v);
    }
    Ok(Value::Object(out))
}

// The files as the scenario names them: the accepted file in order, the
// residual deltas, the held file as a set.
fn files_view(files: &Value) -> Value {
    let names = |v: &Value| -> Vec<String> {
        v.as_array()
            .map(|a| {
                a.iter()
                    .filter_map(|r| r["name"].as_str().map(str::to_owned))
                    .collect()
            })
            .unwrap_or_default()
    };
    json!({"mempool":names(&files["mempool"]["parsed"]["records"]),
        "deltas":names(&files["mempool"]["parsed"]["deltas"]),
        "non_final":sorted(names(&files["non_final"]["parsed"]["records"]))})
}

fn set_conf(n: &mut Node, key: &str, value: Option<String>) {
    let mut lines: Vec<String> = n
        .conf
        .lines()
        .filter(|l| !l.starts_with(&format!("{key}=")))
        .map(str::to_owned)
        .collect();
    if let Some(v) = value {
        lines.push(format!("{key}={v}"));
    }
    n.conf = lines.join("\n");
}

fn console_len(n: &Node) -> Result<usize> {
    Ok(fs::read_to_string(n.dir.join("console.log"))
        .map_err(|e| e.to_string())?
        .len())
}
fn console_since(n: &Node, offset: usize) -> Result<Vec<String>> {
    let log = fs::read_to_string(n.dir.join("console.log")).map_err(|e| e.to_string())?;
    Ok(log
        .get(offset.min(log.len())..)
        .unwrap_or("")
        .lines()
        .map(str::to_owned)
        .collect())
}

// [SRC] the per-file counts the load logs: src/txmempool.cpp:3259-3261 and
// src/time_locked_mempool.cpp:368-369 at PIN.
fn counts_from(lines: &[String], prefix: &str) -> Option<Value> {
    let line = lines.iter().find(|l| l.contains(prefix))?;
    let tail = line.split(prefix).nth(1)?;
    let nums: Vec<u64> = tail
        .split(|c: char| !c.is_ascii_digit())
        .filter(|s| !s.is_empty())
        .filter_map(|s| s.parse().ok())
        .take(3)
        .collect();
    (nums.len() == 3).then(|| json!(nums))
}

// The node's fate of one record, from evidence: the pools after the start,
// then the validator's own line for the file source (debug=txnval;
// LogTxnInvalidStatus, src/validation.cpp:1668-1688 at PIN: "detected orphan"
// for missing inputs, "rejected <reason>" otherwise); a record with no such
// line and absent from both pools was never validated: expired.
fn node_fate(
    name: &str,
    fx: &Fixture,
    pool: &[String],
    held: &[String],
    lines: &[String],
) -> Result<String> {
    if pool.iter().any(|p| p == name) {
        return Ok("accepted".into());
    }
    if held.iter().any(|p| p == name) {
        return Ok("heldNonFinal".into());
    }
    let txid = id(fx.tx(name)?);
    let mine: Vec<&String> = lines
        .iter()
        .filter(|l| l.contains("file: ") && l.contains(&format!("txn= {txid}")))
        .collect();
    if mine.iter().any(|l| l.contains("detected orphan")) {
        return Ok("missingInputs".into());
    }
    if let Some(l) = mine.iter().find(|l| l.contains(" rejected ")) {
        let reason = l.split(" rejected ").nth(1).unwrap_or("").trim();
        return Ok(format!("rejected:{reason}"));
    }
    Ok(if mine.is_empty() {
        "expired".into()
    } else {
        "unattributed".into()
    })
}

fn observe(n: &mut Node, fx: &Fixture) -> Result<serde_json::Map<String, Value>> {
    let verbose = n.call("getrawmempool", json!([true]))?;
    let entries = verbose.as_object().ok_or("getrawmempool verbose")?;
    let mut pool = vec![];
    let mut times = serde_json::Map::new();
    let mut deltas = serde_json::Map::new();
    for (txid, e) in entries {
        let name = fx.name_of(txid);
        pool.push(name.clone());
        times.insert(name.clone(), e["time"].clone());
        // [SRC] fee and modifiedfee in the currency unit, src/rpc/blockchain.cpp:361-367,391-394 at PIN.
        let fee = e["fee"].as_f64().ok_or("fee")?;
        let modified = e["modifiedfee"].as_f64().ok_or("modifiedfee")?;
        let delta = ((modified - fee) * 1e8).round() as i64;
        if delta != 0 {
            deltas.insert(name, json!(delta));
        }
    }
    let held: Vec<String> = n
        .call("getrawnonfinalmempool", json!([]))?
        .as_array()
        .ok_or("getrawnonfinalmempool")?
        .iter()
        .map(|t| text(t).map(|t| fx.name_of(t)))
        .collect::<Result<_>>()?;
    let best = n.call("getbestblockhash", json!([]))?;
    let best = text(&best)?.to_owned();
    let tip = fx
        .blocks
        .iter()
        .find(|(_, h)| **h == best)
        .map_or_else(|| format!("unnamed:{best}"), |(k, _)| k.clone());
    let mut spent = vec![];
    for (name, coin) in &fx.coins {
        if n.call("gettxout", json!([id(coin), 0, false]))?.is_null() {
            spent.push(name.clone());
        }
    }
    let mut m = serde_json::Map::new();
    m.insert("mempool".into(), sorted(pool));
    m.insert("non_final_pool".into(), sorted(held));
    m.insert("tip".into(), json!(tip));
    m.insert("entry_times".into(), Value::Object(times));
    m.insert("fee_deltas".into(), Value::Object(deltas));
    m.insert("spent_on_chain".into(), sorted(spent));
    Ok(m)
}

fn prefix(n: &mut Node, fx: &mut Fixture, fence: &Value) -> Result<Value> {
    let blocks = fence["initial_chain"]["prefix_blocks"]
        .as_u64()
        .ok_or("prefix_blocks")?;
    for h in 1..=blocks {
        n.mine(1, START_CLOCK + h)?;
    }
    fx.tip_height = blocks;
    for (name, height) in fence["initial_chain"]["named_blocks"]
        .as_object()
        .ok_or("named_blocks")?
    {
        let hash = n.call("getblockhash", json!([height]))?;
        fx.blocks.insert(name.clone(), text(&hash)?.to_owned());
    }
    for (name, height) in fence["initial_chain"]["coins"].as_object().ok_or("coins")? {
        let hash = n.call("getblockhash", json!([height]))?;
        let block = n.call("getblock", json!([hash, 1]))?;
        let coinbase = n.raw_tx(&block["tx"][0])?;
        fx.coins.insert(name.clone(), coinbase);
    }
    for f in fence["fixtures"].as_array().ok_or("fixtures")? {
        let name = text(&f["name"])?.to_owned();
        let spends = text(&f["spends"])?;
        let variant = f["variant"].as_u64().ok_or("variant")?;
        let parent = match fx.coins.get(spends) {
            Some(c) => c.clone(),
            None => fx.tx(spends)?.clone(),
        };
        let lock_time = match text(&f["lock"])? {
            "tip" => fx.tip_height as u32,
            "far" => fx.tip_height as u32 + 880,
            _ => 0,
        };
        let sequence = f["sequence"].as_u64().map_or(u32::MAX, |s| s as u32);
        let value = parent.outputs[0].satoshis - 10_000 * variant;
        let tx = spend_locked(&parent, value, 1, script(), lock_time, sequence);
        fx.txs.push((name, tx));
    }
    Ok(
        json!({"generated":blocks,"blocks":fx.blocks,"fixtures":fx.txs.iter().map(|(k, t)| (k.clone(), material(t))).collect::<BTreeMap<_, _>>()}),
    )
}

// One restart on the instance's own data directory: the settings rewritten
// (the configuration file's earlier value wins, src/util.cpp:600-607 at PIN,
// so a key is replaced, never appended), the stop that writes or keeps the
// files, the files read while the node is down, the relaunch and its load.
fn restart(n: &mut Node, fx: &Fixture, action: &Value) -> Result<(Value, Vec<String>)> {
    let clock = fx.clock_of(&action["clock"])?;
    match &action["persistmempool"] {
        Value::Bool(b) => set_conf(n, "persistmempool", Some(if *b { "1" } else { "0" }.into())),
        _ => set_conf(n, "persistmempool", None),
    }
    set_conf(n, "mocktime", Some(clock.to_string()));
    set_conf(
        n,
        "mempoolexpirynonfinal",
        action["mempoolexpirynonfinal"]
            .as_u64()
            .map(|h| h.to_string()),
    );
    n.clock = clock;
    let offset = console_len(n)?;
    let files = n.restart_edited("", |dir| {
        // Nothing is edited; the files the start will read are recorded.
        let files = read_files(dir, fx)?;
        Ok(json!({"edit":"none","read":files}))
    })?;
    let lines = console_since(n, offset)?;
    Ok((files["read"].clone(), lines))
}

fn compare(
    expected: &Value,
    observed: &serde_json::Map<String, Value>,
    fx: &Fixture,
) -> Result<Vec<Value>> {
    let mut out = vec![];
    for (key, want) in expected.as_object().ok_or("expected_observations")? {
        let want = if key == "entry_times" {
            let mut m = serde_json::Map::new();
            for (k, sym) in want.as_object().ok_or("entry_times")? {
                m.insert(k.clone(), json!(fx.clock_of(sym)?));
            }
            Value::Object(m)
        } else {
            want.clone()
        };
        let seen = observed.get(key).cloned().unwrap_or(Value::Null);
        let seen = if key == "entry_times" {
            let mut m = serde_json::Map::new();
            for k in want.as_object().ok_or("entry_times")?.keys() {
                m.insert(k.clone(), seen[k].clone());
            }
            Value::Object(m)
        } else {
            seen
        };
        if seen != want {
            out.push(json!({"key":key,"expected":want,"observed":seen}));
        }
    }
    Ok(out)
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
    let mut fx = Fixture {
        txs: vec![],
        blocks: BTreeMap::new(),
        coins: BTreeMap::new(),
        clock: fence["clock"]
            .as_object()
            .ok_or("clock")?
            .iter()
            .map(|(k, v)| v.as_u64().map(|x| (k.clone(), x)).ok_or("clock value"))
            .collect::<std::result::Result<_, _>>()?,
        tip_height: 0,
    };
    let mut n = start_retry(root, "persist", EXTRAS)?;
    let mut results = vec![];
    let mut held_files = Value::Null;
    for step in fence["steps"].as_array().ok_or("steps")? {
        let sid = text(&step["id"])?.to_owned();
        let action = &step["action"];
        let mut extra = serde_json::Map::new();
        let receipt = match text(&action["type"])? {
            "prefix" => prefix(&mut n, &mut fx, &fence)?,
            "submit" => {
                n.call("setmocktime", json!([fx.clock_of(&action["clock"])?]))?;
                let tx = fx.tx(text(&action["tx"])?)?.clone();
                n.receipt("sendrawtransaction", json!([hex::encode(tx.encode())]))?
            }
            "prioritise" => {
                let tx = fx.tx(text(&action["tx"])?)?.clone();
                n.receipt(
                    "prioritisetransaction",
                    json!([id(&tx), 0.0, action["delta"].as_i64().ok_or("delta")?]),
                )?
            }
            "restart" => {
                let (files, lines) = restart(&mut n, &fx, action)?;
                held_files = files.clone();
                extra.insert("files_read".into(), files_view(&files));
                let persisting = action["persistmempool"] != json!(false);
                let pool: Vec<String> = n
                    .call("getrawmempool", json!([]))?
                    .as_array()
                    .ok_or("getrawmempool")?
                    .iter()
                    .map(|t| text(t).map(|t| fx.name_of(t)))
                    .collect::<Result<_>>()?;
                let held: Vec<String> = n
                    .call("getrawnonfinalmempool", json!([]))?
                    .as_array()
                    .ok_or("getrawnonfinalmempool")?
                    .iter()
                    .map(|t| text(t).map(|t| fx.name_of(t)))
                    .collect::<Result<_>>()?;
                let main_counts = counts_from(&lines, "Imported mempool transactions from disk:");
                let held_counts =
                    counts_from(&lines, "Imported non-final mempool transactions from disk:");
                if persisting {
                    let view = files_view(&files);
                    let mut fates = serde_json::Map::new();
                    for (key, list) in [
                        ("mempool", &view["mempool"]),
                        ("non_final", &view["non_final"]),
                    ] {
                        let mut m = serde_json::Map::new();
                        for name in list.as_array().ok_or("files view")? {
                            let name = text(name)?;
                            m.insert(
                                name.to_owned(),
                                json!(node_fate(name, &fx, &pool, &held, &lines)?),
                            );
                        }
                        fates.insert(key.into(), Value::Object(m));
                    }
                    extra.insert("load".into(), Value::Object(fates));
                    extra.insert(
                        "counts".into(),
                        json!({"mempool":main_counts,"non_final":held_counts}),
                    );
                } else {
                    // No load line and no load: src/init.cpp:1901-1905 at PIN.
                    let any = main_counts.is_some() || held_counts.is_some();
                    extra.insert(
                        "load".into(),
                        if any {
                            json!("a load line appeared")
                        } else {
                            Value::Null
                        },
                    );
                    extra.insert(
                        "counts".into(),
                        if any {
                            json!([main_counts, held_counts])
                        } else {
                            Value::Null
                        },
                    );
                }
                let keys = [
                    "Imported mempool transactions",
                    "Imported non-final mempool transactions",
                    "Dumped mempool",
                    "txns to non-final mempool",
                    "Failed to deserialize",
                    "Failed to dump",
                    "Mempool file and transaction database",
                    "No mempool file from previous session",
                    "file: ",
                ];
                let evidence: Vec<&String> = lines
                    .iter()
                    .filter(|l| keys.iter().any(|k| l.contains(k)))
                    .collect();
                json!({"console":evidence,"persistmempool":action["persistmempool"],"clock":action["clock"]})
            }
            "invalidateblock" => {
                let hash = fx
                    .blocks
                    .get(text(&action["block"])?)
                    .ok_or("unknown block")?
                    .clone();
                n.receipt("invalidateblock", json!([hash]))?
            }
            "generate" => {
                let hashes = n.mine(1, fx.clock_of(&action["clock"])?)?;
                let hash = text(hashes.first().ok_or("no generated block")?)?.to_owned();
                let body: Vec<String> = n
                    .body(&json!(hash))?
                    .iter()
                    .map(|t| fx.name_of(t))
                    .collect();
                fx.blocks
                    .insert(text(&action["block"])?.to_owned(), hash.clone());
                json!({"generated":hash,"body":body})
            }
            "stop" => {
                let offset = console_len(&n)?;
                n.stop()?;
                let files = read_files(&n.dir, &fx)?;
                extra.insert("files_written".into(), files_view(&files));
                held_files = files.clone();
                json!({"stopped":true,"console":console_since(&n, offset)?.into_iter().filter(|l| l.contains("Dumped")).collect::<Vec<_>>(),"files":files})
            }
            other => return Err(format!("unknown persist action {other}")),
        };
        let mut observed = if text(&action["type"])? == "stop" {
            serde_json::Map::new()
        } else {
            observe(&mut n, &fx)?
        };
        observed.extend(extra);
        let witnesses = compare(&step["expected_observations"], &observed, &fx)?;
        let agree = witnesses.is_empty();
        println!(
            "persist {sid}: {} [X] ({} observations compared, {} witnesses)",
            if agree { "agree" } else { "diverge" },
            step["expected_observations"]
                .as_object()
                .map_or(0, |o| o.len()),
            witnesses.len()
        );
        results.push(
            json!({"id":sid,"verdict":if agree {"agree"} else {"diverge"},"label":"[X]",
            "observed":observed,"witnesses":witnesses,"receipt":receipt}),
        );
    }
    n.stop()?;
    let agree = results.iter().filter(|r| r["verdict"] == "agree").count();
    Ok(
        json!({"scenario":fence["id"],"instance":instance_pointer(&n.dir),
        "counts":{"label":"[M]","steps":results.len(),"agree":agree,"diverge":results.len()-agree},
        "names":{"transactions":fx.txs.iter().map(|(k, t)| (k.clone(), id(t))).collect::<BTreeMap<_, _>>(),"blocks":fx.blocks,
            "coins":fx.coins.iter().map(|(k, t)| (k.clone(), id(t))).collect::<BTreeMap<_, _>>()},
        "final_files":held_files,"steps":results,"rpc":n.calls}),
    )
}

// The record's projection without RPC bodies; the full receipt stays in the run.
pub(super) fn main(record: &str, run_id: Option<String>, write: bool) -> Result<()> {
    let stem = record
        .strip_prefix("docs/records/")
        .and_then(|r| r.strip_suffix("-s7-81-persist-s1.md"));
    if !stem.is_some_and(|s| !s.is_empty() && s.bytes().all(|c| c.is_ascii_digit() || c == b'-')) {
        return Err("record must be docs/records/<stamp>-s7-81-persist-s1.md".into());
    }
    let run_id = run_id.unwrap_or_else(|| format!("persist-81-{}", stem.unwrap_or("run")));
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
    // [D] the node of record's binary, measured at the run (docs/PROVENANCE.md 1a).
    let binary = Build::Record.located();
    let binary_bytes = fs::read(&binary).map_err(|e| format!("{}: {e}", binary.display()))?;
    let binary_row = json!({"label":"[M]","build":Build::Record.name(),
        "path":binary.strip_prefix(&home).map_or_else(|_| binary.display().to_string(), |p| format!("~/{}", p.display())),
        "source":format!("docs/PROVENANCE.md 1a {}", Build::Record.pin_key()),
        "sha256":hex::encode(bsv_rs::primitives::hash::sha256(&binary_bytes))});
    let start = Instant::now();
    let mut out = run(&root)?;
    out["binary"] = binary_row;
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
        "persist node: {} [X] ({}; wall [M] {:.3}s)",
        if failed { "RED" } else { "GREEN" },
        out["counts"],
        start.elapsed().as_secs_f64()
    );
    if failed {
        Err("persistence divergence or witness".into())
    } else {
        Ok(())
    }
}
