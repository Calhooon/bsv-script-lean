//! Family-owned realization recipes. Sources and observation boundaries are retained in receipts.
use super::core::*;

fn block_recipe(boundary: &str, coin: &RawTx, height: u32, high_hash: bool) -> Result<Vec<RawTx>> {
    let mut base = cb(height, boundary);
    let mut tx = spend(coin, 1000, 1);
    let txs = match boundary {
        "block/valid" | "block/root-mismatch" => vec![base, tx],
        _ if high_hash => vec![base, tx],
        "block/duplicate-suffix" | "block/root-before-duplicate" => {
            let child = spend(&tx, 900, 1);
            vec![base, tx, child.clone(), child]
        }
        "block/duplicate-interior" => {
            let child = spend(&tx, 900, 1);
            vec![base.clone(), base, tx, child]
        }
        "block/empty" => vec![],
        "block/missing-coinbase" => vec![tx],
        "block/extra-coinbase" => vec![base, cb(height, "extra")],
        "block/vin-empty" => {
            tx.inputs.clear();
            vec![base, tx]
        }
        "block/vout-empty" => {
            tx.outputs.clear();
            vec![base, tx]
        }
        "block/negative" => {
            tx.outputs[0].satoshis = u64::MAX;
            vec![base, tx]
        }
        "block/over-money" => {
            tx.outputs[0].satoshis = 2_100_000_000_000_001;
            vec![base, tx]
        }
        x if x.starts_with("block/coinbase-script-") => {
            let len: usize = x
                .rsplit('-')
                .next()
                .or_err("x.rsplit('-').next()")?
                .parse()
                .map_err(|_| "script length")?;
            base.inputs[0].script = vec![0x51; len];
            vec![base]
        }
        _ => return Err("recipe not implemented".into()),
    };
    Ok(txs)
}
fn supported_block(id: &str, high_hash: bool) -> bool {
    high_hash
        || matches!(
            id,
            "block/valid"
                | "block/duplicate-suffix"
                | "block/duplicate-interior"
                | "block/root-before-duplicate"
                | "block/root-mismatch"
                | "block/empty"
                | "block/missing-coinbase"
                | "block/extra-coinbase"
                | "block/vin-empty"
                | "block/vout-empty"
                | "block/negative"
                | "block/over-money"
                | "block/coinbase-script-1"
                | "block/coinbase-script-2"
                | "block/coinbase-script-100"
                | "block/coinbase-script-101"
        )
}
fn block_measured(
    row: &Value,
    observed: Value,
    expected: Value,
    recipe: &str,
    calls: Vec<Value>,
    fixtures: Value,
) -> Value {
    let precheck = matches!(
        row["id"].as_str(),
        Some("block/empty" | "block/missing-coinbase")
    ) && observed["status"] == "rpc-error"
        && observed["error"]["code"] == -22
        && observed["error"]["message"] == "Block does not start with a coinbase";
    let mut result = measured(row, observed, expected, recipe, calls, fixtures);
    if precheck {
        result["verdict"] = json!("rpc-precheck");
        result["rpc_precheck"] = json!({"code":-22,"message":"Block does not start with a coinbase","handler":"src/rpc/mining.cpp:830-838"});
    }
    result
}

fn structural_blocks(root: &Path) -> Result<Vec<Value>> {
    let rows = row_read("block")?;
    let mut result = vec![];
    let mut n = start_owned(root, "block", "")?;
    let hashes = n.mine(999, 1_699_999_000)?;
    let b = n.call("getblock", json!([hashes[0], 1]))?;
    let coin = n.raw_tx(&b["tx"][0])?;
    let setup = n.calls.clone();
    for row in &rows {
        let boundary = text(&row["id"])?;
        // [SRC] CheckBlockHeader, src/validation.cpp:5736-5744 at 6504a3aff65b.
        let high_hash = row["expected"]["reason"] == "high-hash";
        if !supported_block(boundary, high_hash) {
            continue;
        }
        let offset = n.calls.len();
        let txs = block_recipe(boundary, &coin, 1000, high_hash)?;
        let (mut hash, mut bytes) = n.block_bytes(&txs, 1_700_000_001)?;
        if high_hash
            || matches!(
                boundary,
                "block/root-mismatch" | "block/root-before-duplicate"
            )
        {
            let tip = n.tip()?;
            let mut h = block_codec::Header {
                version: 4,
                prev: txid_from_display_hex(text(&tip["hash"])?)?,
                merkle: [0; 32],
                time: 1_700_000_001,
                bits: 0x207fffff,
                nonce: 0,
            };
            if high_hash {
                while block_codec::meets_target(&h.hash(), &block_codec::target_of(h.bits)) {
                    h.nonce = h.nonce.wrapping_add(1);
                }
            } else {
                block_codec::grind(&mut h);
            }
            bytes = block_codec::serialize_block(&h, &txs);
            hash = txid_display_hex(&h.hash());
        }
        let receipt = n.receipt("submitblock", json!([hex::encode(&bytes)]))?;
        let observed = block_judgment(&receipt);
        if observed["status"] == "ok" {
            let body = n.call("getblock", json!([hash, 1]))?;
            if body["confirmations"].as_i64().unwrap_or(0) < 1 {
                return Err("accepted block not active".into());
            }
            n.call("invalidateblock", json!([hash]))?;
        }
        result.push(block_measured(row,observed,block_expect(row),"Build on live height 999 with actual mature coinbase prevout; reproduce named body mutation, recompute merkle root except the root-mismatch row and grind valid regtest PoW. Restore tip after accepted rows. Compare submitblock acceptance/reason; validation code and corruption flag are not exposed by this RPC.",n.calls[offset..].to_vec(),json!({"block":hex::encode(bytes),"hash":hash,"funding_coin":material(&coin),"setup":setup,"conf":n.conf})));
    }
    n.stop()?;
    Ok(result)
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn mutations_bind_live_parent_and_preserve_boundary() {
        let c = cb(1, "fund");
        let txs = block_recipe("block/vout-empty", &c, 1000, false).unwrap();
        assert!(txs[1].outputs.is_empty());
        assert_eq!(txs[1].inputs[0].txid, c.txid_internal());
        assert!(block_recipe("unimplemented", &c, 1000, false).is_err());
        for len in [1, 2, 100, 101] {
            let ts =
                block_recipe(&format!("block/coinbase-script-{len}"), &c, 1000, false).unwrap();
            assert_eq!(ts[0].inputs[0].script.len(), len);
        }
    }
}

// Lane entry point stays in the family module so sibling drivers are untouched.
// [SRC] src/validation.cpp:6039-6104; src/chainparams.cpp:1460-1477 at PIN.
fn unavailable(row: &Value, reason: &str) -> Value {
    json!({"id":row["id"],"label":"[X]","unrealizable":reason})
}

fn start_owned(root: &Path, name: &str, extra: &str) -> Result<Node> {
    // Bind probes in core are exclusive. A competing daemon can win the small
    // release-to-spawn interval; retry a fresh datadir after core reaps our child.
    let mut last = String::new();
    for attempt in 0..20 {
        match Node::start(root.join(format!("{name}-{attempt}")), 1_000_001, extra) {
            Ok(n) => return Ok(n),
            Err(e) => {
                let retry = e.contains("bind")
                    || e.contains("startup timeout")
                    || e.contains("no free RPC/P2P pair")
                    || e.contains("HTTP server");
                last = e;
                if !retry {
                    break;
                }
                thread::sleep(Duration::from_millis(250));
            }
        }
    }
    Err(last)
}

fn padded_coinbase(height: u32, tag: &str, size: usize) -> Result<RawTx> {
    let mut tx = cb(height, tag);
    tx.outputs[0].script = vec![0x6a; size];
    let excess = 81 + tx.encode().len() - size;
    tx.outputs[0].script.truncate(size - excess);
    if 81 + tx.encode().len() != size {
        return Err("padding width changed".into());
    }
    Ok(tx)
}

fn observe_block(
    n: &mut Node,
    row: &Value,
    txs: &[RawTx],
    time: u32,
    recipe: &str,
) -> Result<Value> {
    let (hash, bytes) = n.block_bytes(txs, time)?;
    let reply = n.receipt("submitblock", json!([hex::encode(&bytes)]))?;
    let observed = block_judgment(&reply);
    if observed["status"] == "ok" {
        let body = n.call("getblock", json!([hash, 1]))?;
        if body["confirmations"].as_i64().unwrap_or(0) < 1 {
            return Err("accepted block not active".into());
        }
    }
    n.stop()?;
    Ok(measured(
        row,
        observed,
        block_expect(row),
        recipe,
        n.calls.clone(),
        json!({"block":hex::encode(bytes),"hash":hash,"conf":n.conf,"datadir":instance_pointer(&n.dir)}),
    ))
}

fn mine_prefix(n: &mut Node, mut count: u64) -> Result<()> {
    while count > 0 {
        let batch = count.min(250);
        n.mine(batch, 1_699_999_000)?;
        count -= batch;
    }
    Ok(())
}

fn context_blocks(root: &Path, rows: &[Value]) -> Result<Vec<Value>> {
    let mut out = vec![];
    for row in rows.iter().filter(|r| r["kind"] == "context-block") {
        let name = text(&row["id"])?;
        let reason = if matches!(name, "context/size-at-setting" | "context/size-one-over") {
            Some("named excessiveBlockSize is below the launch/RPC setter floor; src/config.cpp:232-245")
        } else if name.contains("bip34")
            || name.contains("height-push")
            || name == "context/finality-before-height"
        {
            Some("named BIP34 activation override is unavailable: regtest compiles height 100000000, with no RPC/launch override; the named small-height prefix/activation boundary cannot be reproduced; src/chainparams.cpp:1461-1469; src/validation.cpp:6085-6099")
        } else {
            None
        };
        if let Some(reason) = reason {
            out.push(unavailable(row, reason));
            continue;
        }
        let mut n = start_owned(root, &name.replace('/', "-"), "")?;
        let size = name.contains("launchable-size");
        let height = if size {
            10000
        } else if name == "context/pre-csv-own-time" {
            575
        } else {
            1000
        };
        // A real OP_TRUE coinbase makes lock-time edits independent of signatures.
        n.call("setmocktime", json!([1_700_000_000]))?;
        let mut funding = cb(1, name);
        funding.outputs[0] = RawOutput {
            satoshis: 100000,
            script: vec![0x51],
        };
        let (_, receipt) = n.submit(&[funding.clone()], 1_699_990_000)?;
        if block_judgment(&receipt)["status"] != "ok" {
            return Err(format!("funding: {receipt}"));
        }
        mine_prefix(&mut n, height - 2)?;
        let tip = n.tip()?;
        let median = tip["mediantime"].as_u64().ok_or("median")?;
        let time = 1_700_000_001u32.max(median as u32 + 1);
        n.call("setmocktime", json!([time]))?;
        let txs = if size {
            vec![padded_coinbase(
                height as u32,
                name,
                1_000_001 + usize::from(name.ends_with("-1")),
            )?]
        } else {
            let mut tx = spend_to(&funding, 99999, 1, vec![0x51]);
            tx.inputs[0].script.clear();
            tx.inputs[0].sequence = u32::MAX - 1;
            tx.lock_time = if name == "context/nonfinal-at-median" {
                median as u32
            } else if name == "context/pre-csv-own-time" {
                time - 1
            } else {
                median as u32 - 1
            };
            vec![cb(height as u32, name), tx]
        };
        out.push(observe_block(&mut n, row, &txs, time,
            "Rematerialize MTP equality/below on height 1000, or pre-CSV own-time below compiled activation at height 575; live mature OP_TRUE funding. Size rows use exact 1000001/1000002-byte blocks at height 10000. BIP34 is inactive in these independent boundaries; its override is not claimed. submitblock acceptance/reason is the projection; duplicate size checks cannot be distinguished by that RPC.")?);
    }
    Ok(out)
}

#[cfg(test)]
mod lane {
    use super::*;
    #[test]
    #[ignore = "explicit owned loopback run; S6_BLOCK_KIND and S6_BLOCK_RECORD required"]
    fn record_kind() {
        std::env::set_current_dir(Path::new(env!("CARGO_MANIFEST_DIR")).parent().unwrap()).unwrap();
        signals();
        let kind = std::env::var("S6_BLOCK_KIND").unwrap();
        let record = std::env::var("S6_BLOCK_RECORD").unwrap();
        assert!(
            record.starts_with("docs/records/") && record.ends_with("-s6-66-blk-regtest-s3.md")
        );
        let now = || {
            String::from_utf8(
                Command::new("date")
                    .args(["-u", "+%Y-%m-%dT%H:%M:%SZ"])
                    .output()
                    .unwrap()
                    .stdout,
            )
            .unwrap()
            .trim()
            .to_owned()
        };
        let start_utc = now();
        let clock = Instant::now();
        let run_id = format!("s6-66-blk-{}-{}", kind, start_utc.replace([':', '-'], ""));
        let root = PathBuf::from(std::env::var("HOME").unwrap())
            .join("bsv/targets/spec-oracle-scenarios")
            .join(&run_id);
        fs::create_dir(&root).unwrap();
        let binary = Build::Record.located();
        let version = String::from_utf8(
            Command::new(binary)
                .arg("-version")
                .output()
                .unwrap()
                .stdout,
        )
        .unwrap();
        let version = version.lines().next().unwrap();
        assert_eq!(version, format!("Bitcoin SV version {VERSION}"));
        let rows = row_read("block").unwrap();
        let results = match kind.as_str() {
            "context-block" => context_blocks(&root, &rows),
            "coinbase-amount" => rewards(&root, &rows),
            "ttor" => ttor_blocks(&root, &rows),
            "subsidy" => subsidies(&root, &rows),
            "compact" => Ok(compact_rows(&rows)),
            "pow" => proof_of_work(&root, &rows),
            "context-header" => context_headers(&root, &rows),
            "nextwork" => next_work(&rows),
            "block" => body_blocks(&root, &rows),
            _ => Err(format!("unsupported kind {kind}")),
        }
        .unwrap();
        assert_eq!(
            results.len(),
            rows.iter().filter(|r| r["kind"] == kind).count()
        );
        let path = PathBuf::from(record.replace(".md", ".json"));
        let mut receipt: Value = if path.exists() {
            serde_json::from_slice(&fs::read(&path).unwrap()).unwrap()
        } else {
            json!({"source_pin":PIN,"version":version,"record":record,"runs":[],"rows":{}})
        };
        let digest = hex::encode(bsv_rs::primitives::hash::sha256(
            &fs::read("harness/src/scenarios/block.rs").unwrap(),
        ));
        receipt["runs"].as_array_mut().unwrap().push(json!({"run_id":run_id,"kind":kind,"started_utc":start_utc,"ended_utc":now(),"wall_seconds":clock.elapsed().as_secs_f64(),"label":"[M]","block_module_sha256":digest,"datadir":instance_pointer(&root)}));
        let mut marks = BTreeMap::new();
        for r in results {
            let id = text(&r["id"]).unwrap().to_owned();
            let mark = if let Some(reason) = r["unrealizable"].as_str() {
                format!("unrealizable: {reason} [X] {record}")
            } else if r["verdict"] == "rpc-precheck" {
                format!(
                    "rpc-precheck: {} {} ({}) [X] {record}",
                    r["rpc_precheck"]["code"],
                    text(&r["rpc_precheck"]["message"]).unwrap(),
                    text(&r["rpc_precheck"]["handler"]).unwrap()
                )
            } else {
                format!(
                    "measured {}: {} [X] {record}",
                    text(&r["verdict"]).unwrap(),
                    r["observed"]
                )
            };
            println!("{id}: {mark}");
            marks.insert(id.clone(), mark);
            receipt["rows"][&id] = r;
        }
        write_json(&path, &receipt).unwrap();
        mark_rows("block", &marks).unwrap();
    }
}

fn body_blocks(root: &Path, rows: &[Value]) -> Result<Vec<Value>> {
    let mut out = structural_blocks(root)?;
    rows.iter()
        .filter(|r| r["kind"] == "block")
        .try_for_each(|r| r["id"].as_str().map(|_| ()).or_err("a block row's id"))?;
    for row in rows.iter().filter(|r| {
        r["kind"] == "block"
            && !supported_block(
                r["id"].as_str().unwrap_or_default(),
                r["expected"]["reason"] == "high-hash",
            )
    }) {
        let name = text(&row["id"])?;
        let reason = match name {
            "block/size-at-setting" | "block/size-one-over-setting" | "block/early-count" | "block/size-before-noncoinbase" | "block/size-disabled" => Some("named excessiveBlockSize is below launch/RPC setter floor; disabling size checks is not a submitblock option; src/config.cpp:232-245; src/rpc/mining.cpp:916-952; src/validation.cpp:5801-5815"),
            "block/merkle-disabled" => Some("submitblock always validates merkle root; no RPC/launch switch supplies the row's disabled check; src/rpc/mining.cpp:916-952; src/validation.cpp:5769-5785"),
            "block/sigops-at-cap" | "block/sigops-above-cap" | "block/sigops-before-next-structure" => Some("row replaces compiled MAX_BLOCK_SIGOPS_PER_MB_BEFORE_GENESIS with 1 or 2; getter has no launch/RPC override; src/config.cpp:825-834"),
            _ => None,
        };
        if let Some(reason) = reason {
            out.push(unavailable(row, reason));
            continue;
        }
        let mut n = start_owned(root, &name.replace('/', "-"), "")?;
        let height = row["height"].as_u64().or_err("row['height'].as_u64()")?;
        let hashes = n.mine(100, 1_699_999_000)?;
        let b = n.call("getblock", json!([hashes[0], 1]))?;
        let coin = n.raw_tx(&b["tx"][0])?;
        mine_prefix(&mut n, height - 101)?;
        let mut base = cb(height as u32, name);
        let txs = if name.contains("launchable-size") {
            vec![padded_coinbase(
                height as u32,
                name,
                1_000_001 + usize::from(name.ends_with("-1")),
            )?]
        } else if name.contains("p2sh") {
            let lock = [vec![0xa9, 0x14], vec![0x22; 20], vec![0x87]].concat();
            vec![base, spend_to(&coin, 1000, 1, lock)]
        } else if name == "block/regular-before-own-sigops" {
            let mut tx = spend_to(&coin, 1000, 1, vec![0xac; 20001]);
            tx.inputs.clear();
            vec![base, tx]
        } else {
            // Above the actual compiled per-MB cap, not merely above the row's
            // synthetic cap: the Genesis bypass is the measured boundary.
            base.outputs[0].script = vec![0xac; 20001];
            vec![base]
        };
        out.push(observe_block(&mut n, row, &txs, 1_700_005_000,
            "Live compiled era height and mature funding; P2SH output on the regular transaction. Input-empty order row uses 20001 sigops, exceeding the actual compiled cap; Genesis bypass uses 20001 coinbase-output sigops. Size rows are exact 1000001/1000002 bytes. Low synthetic setter/cap overrides are individually unavailable.")?);
    }
    Ok(out)
}

fn next_work(rows: &[Value]) -> Result<Vec<Value>> {
    let mut out = vec![];
    for row in rows.iter().filter(|r| r["kind"] == "nextwork") {
        let name = text(&row["id"])?;
        let reason = if name == "next/genesis" {
            "mainnet no-parent powLimit differs from the compiled regtest genesis/limit; no RPC invokes GetNextWorkRequired with an injected null parent and chosen network; src/chainparams.cpp:1471-1477,1513-1518; src/pow.cpp:95-113"
        } else if name == "next/no-retarget-before-daa" {
            "row's height-zero parent bits 0x1c123456 cannot be installed: regtest genesis bits are 0x207fffff and no-retargeting preserves them at every reachable descendant; src/chainparams.cpp:1471-1477,1513-1518; src/pow.cpp:102-113"
        } else {
            "regtest's compiled no-retargeting returns parent bits before EDA, periodic, testnet-delay/backscan or DAA logic; no RPC/launch override enables the named network rule; src/chainparams.cpp:1471-1477; src/pow.cpp:22-117"
        };
        out.push(unavailable(row, reason));
    }
    Ok(out)
}

fn context_headers(root: &Path, rows: &[Value]) -> Result<Vec<Value>> {
    let mut out = vec![];
    for row in rows.iter().filter(|r| r["kind"] == "context-header") {
        let name = text(&row["id"])?;
        if matches!(name, "header/version-bip34" | "header/missing-ancestry") {
            let reason = if name.ends_with("bip34") {
                "named BIP34 height 1000 is a compiled-parameter override unavailable on regtest; src/chainparams.cpp:1461-1469; src/validation.cpp:5964-5974"
            } else {
                "RPC locates a real parent index with complete ancestry before contextual validation; a height-999 index with only one ancestor is not reachable; src/validation.cpp:6164-6190"
            };
            out.push(unavailable(row, reason));
            continue;
        }
        let mut n = start_owned(root, &name.replace('/', "-"), "")?;
        let height = if name.ends_with("bip66") {
            1251
        } else if name.ends_with("bip65") {
            1351
        } else {
            1000
        };
        mine_prefix(&mut n, height - 1)?;
        let tip = n.tip()?;
        let median = tip["mediantime"].as_u64().ok_or("median")? as u32;
        let now = 1_700_000_000u32;
        n.call(
            "setmocktime",
            json!([if name == "header/negative-now" {
                -1i64
            } else {
                now as i64
            }]),
        )?;
        let txs = vec![cb(height as u32, name)];
        let mut h = block_codec::Header {
            version: if name.ends_with("bip66") {
                2
            } else if name.ends_with("bip65") {
                3
            } else {
                4
            },
            prev: txid_from_display_hex(text(&tip["hash"])?)?,
            merkle: block_codec::merkle_root(
                &txs.iter().map(RawTx::txid_internal).collect::<Vec<_>>(),
            ),
            time: match name {
                "header/time-at-median" | "header/difficulty-before-time" => median,
                "header/time-above-median" => median + 1,
                "header/time-at-two-hours" => now + 7200,
                "header/time-over-two-hours" => now + 7201,
                _ => now,
            },
            bits: if name == "header/difficulty-before-time" {
                0x207ffffe
            } else {
                0x207fffff
            },
            nonce: 0,
        };
        block_codec::grind(&mut h);
        let bytes = block_codec::serialize_block(&h, &txs);
        let reply = n.receipt("submitblock", json!([hex::encode(&bytes)]))?;
        let observed = block_judgment(&reply);
        if observed["status"] == "ok" {
            let body = n.call("getblock", json!([txid_display_hex(&h.hash()), 1]))?;
            if body["confirmations"].as_i64().unwrap_or(0) < 1 {
                return Err("header block not active".into());
            }
        }
        n.stop()?;
        out.push(measured(row,observed,block_expect(row),
            "Live MTP and adjusted mocktime remap the timestamp boundaries; BIP66/65 use compiled activation heights 1251/1351. Valid regtest PoW on every header, including wrong-bits plus old-time ordering. Negative adjusted time uses the signed setmocktime RPC argument. Only submitblock acceptance/reason is compared.",
            n.calls.clone(),json!({"block":hex::encode(bytes),"header":hex::encode(h.encode()),"tip":tip,"conf":n.conf,"datadir":instance_pointer(&n.dir)})));
    }
    Ok(out)
}

fn proof_of_work(root: &Path, rows: &[Value]) -> Result<Vec<Value>> {
    let mut out = vec![];
    for row in rows.iter().filter(|r| r["kind"] == "pow") {
        let name = text(&row["id"])?;
        if matches!(
            name,
            "pow/equal-target" | "pow/over-target" | "pow/above-limit"
        ) {
            let reason = if name == "pow/above-limit" {
                "named mainnet powLimit boundary is below the compiled regtest limit; no regtest RPC/launch override supplies the mainnet limit; src/chainparams.cpp:1471-1477; src/pow.cpp:150-165"
            } else {
                "row injects a standalone hash integer 1 or 2 at target 1; RPC validates a serialized header's SHA256d hash and cannot inject that operand, and this preimage boundary cannot be materialized by a regtest RPC; src/validation.cpp:5736-5747; src/pow.cpp:150-171"
            };
            out.push(unavailable(row, reason));
            continue;
        }
        let mut n = start_owned(root, &name.replace('/', "-"), "")?;
        n.mine(1, 1_700_000_000)?;
        let tip = n.tip()?;
        let txs = vec![cb(2, name)];
        let h = block_codec::Header {
            version: 4,
            prev: txid_from_display_hex(text(&tip["hash"])?)?,
            merkle: txs[0].txid_internal(),
            time: 1_700_000_001,
            bits: row["bits"].as_u64().or_err("row['bits'].as_u64()")? as u32,
            nonce: 0,
        };
        let bytes = block_codec::serialize_block(&h, &txs);
        let reply = n.receipt("submitblock", json!([hex::encode(&bytes)]))?;
        n.stop()?;
        // Invalid target decoding precedes the hash comparison, so any actual
        // header hash witnesses these three independent target-range checks.
        let judgment = block_judgment(&reply);
        if judgment != json!({"status":"rejected","reason":"high-hash"}) {
            return Err(format!("unexpected PoW envelope: {reply}"));
        }
        let mut r = measured(row,json!(false),row["expected"].clone(),
            "Submit each row's exact invalid compact bits on a real parent; invalid target decoding rejects independently of the synthetic hash-zero operand. Compare PoW false only after requiring the exact high-hash submitblock reason.",
            n.calls.clone(),json!({"block":hex::encode(bytes),"conf":n.conf,"datadir":instance_pointer(&n.dir)}));
        r["rpc_judgment"] = judgment;
        out.push(r);
    }
    Ok(out)
}

fn compact_rows(rows: &[Value]) -> Vec<Value> {
    rows.iter().filter(|r|r["kind"]=="compact").map(|r|unavailable(r,
        "standalone SetCompact target/negative/overflow tuple is not an RPC observable; header submission collapses these outputs into high-hash or continues to contextual checks, so it cannot compare this tuple; src/arith_uint256.cpp:182-200; src/pow.cpp:150-171; src/validation.cpp:5736-5747")).collect()
}

fn subsidies(root: &Path, rows: &[Value]) -> Result<Vec<Value>> {
    let mut n = start_owned(root, "subsidy", "")?;
    let mut out = vec![];
    for row in rows.iter().filter(|r| r["kind"] == "subsidy") {
        let height = row["height"].as_u64().or_err("row['height'].as_u64()")?;
        // Remap the same schedule era / endpoint from 210000 to 150 slots.
        let target = match height {
            0 => 1,
            209999 => 149,
            210000 => 150,
            6930000 => 4950,
            13440000 => 9600,
            _ => return Err("subsidy height".into()),
        };
        let tip = n.tip()?;
        mine_prefix(
            &mut n,
            target - tip["height"].as_u64().or_err("tip['height'].as_u64()")?,
        )?;
        let tip = n.tip()?;
        let coin = n.raw_tx(&tip["tx"][0])?;
        let actual: u64 = coin.outputs.iter().map(|o| o.satoshis).sum();
        out.push(measured(row,json!(actual),row["expected"].clone(),
            "Remap mainnet subsidy era boundaries to compiled regtest interval 150: era zero at height 1, its final slot 149, era one at 150, zero after 33 halvings at 4950 and shift guard at 9600. Empty-pool generatetoaddress coinbase total observes the subsidy without fees; genesis bypass is not submitted.",
            n.calls.clone(),json!({"live_height":target,"coinbase":material(&coin),"conf":n.conf,"datadir":instance_pointer(&n.dir)})));
    }
    n.stop()?;
    for r in &mut out {
        r["shutdown_rpc"] = json!(n.calls.last());
    }
    Ok(out)
}

fn ttor_blocks(root: &Path, rows: &[Value]) -> Result<Vec<Value>> {
    let mut out = vec![];
    for row in rows.iter().filter(|r| r["kind"] == "ttor") {
        let name = text(&row["id"])?;
        if name == "ttor/no-tip" || name == "ttor/ahead-of-tip" {
            out.push(unavailable(row,if name=="ttor/no-tip" {
                "regtest initializes a genesis tip; genesis connection returns without undo and DisconnectBlock fails without undo, so ordinary RPC invalidation cannot remove that tip to supply the null TTOR operand; src/validation.cpp:3040-3051,4065-4090,5671-5682; src/processing_block_index.cpp:79-96"
            } else {
                "the reversed dependent body above the active tip must connect and fails input availability after the skipped TTOR policy check; submitblock has no isolated TTOR-success result and no RPC bypasses connection at this boundary; src/validation.cpp:5671-5682,6440-6495; src/rpc/mining.cpp:830-875"
            }));
            continue;
        }
        let mut n = start_owned(root, &name.replace('/', "-"), "")?;
        let hashes = n.mine(300, 1_699_999_000)?;
        let funding_block = n.call("getblock", json!([hashes[0], 1]))?;
        let coin = n.raw_tx(&funding_block["tx"][0])?;
        let height = if name == "ttor/distance-one-below" {
            201u32
        } else {
            200
        };
        let parent = &hashes[height as usize - 2];
        let tx = spend(&coin, 1000, 1);
        let child = spend(&tx, 900, 1);
        let txs = if name == "ttor/ordered" {
            vec![cb(height, name), tx, child]
        } else {
            vec![cb(height, name), child, tx]
        };
        let (h, bytes) = block_codec::assemble(
            4,
            txid_from_display_hex(text(parent)?)?,
            1_700_000_000,
            0x207fffff,
            &txs,
        );
        let hash = txid_display_hex(&h.hash());
        let reply = n.receipt("submitblock", json!([hex::encode(&bytes)]))?;
        let observed = if reply["result"] == "inconclusive" {
            let body = n.call("getblock", json!([hash, 1]))?;
            let tips = n.call("getchaintips", json!([]))?;
            if body["confirmations"] != -1
                || !tips
                    .as_array()
                    .or_err("tips.as_array()")?
                    .iter()
                    .any(|t| t["hash"] == hash && t["status"] != "invalid")
            {
                return Err("side-body acceptance evidence absent".into());
            }
            json!({"status":"ok"})
        } else {
            block_judgment(&reply)
        };
        n.stop()?;
        out.push(measured(row,observed,block_expect(row),
            "Remap height/tip together to 200/300 or 201/300, preserving policy distances 100/99 with mature live funding. Submit a side-branch body with parent-child order retained/reversed. An inconclusive RPC is accepted only with getblock confirmations=-1 and a non-invalid getchaintips entry proving stored side body; reversed-at-distance requires exact bad-blk-ttor. No active-connection verdict is inferred.",
            n.calls.clone(),json!({"block":hex::encode(bytes),"hash":hash,"height":height,"active_tip":300,"conf":n.conf,"datadir":instance_pointer(&n.dir)})));
    }
    Ok(out)
}

fn rewards(root: &Path, rows: &[Value]) -> Result<Vec<Value>> {
    let mut out = vec![];
    for row in rows.iter().filter(|r| r["kind"] == "coinbase-amount") {
        let name = text(&row["id"])?;
        let mut n = start_owned(root, &name.replace('/', "-"), "")?;
        let hashes = n.mine(100, 1_699_999_000)?;
        let block = n.call("getblock", json!([hashes[0], 1]))?;
        let coin = n.raw_tx(&block["tx"][0])?;
        let tx = spend(&coin, coin.outputs[0].satoshis - 7, 1);
        let mut base = cb(101, name);
        base.outputs[0].satoshis = 5_000_000_007 + u64::from(name.ends_with("-1"));
        out.push(observe_block(&mut n,row,&[base,tx],1_700_000_000,
            "Rematerialize the era-zero subsidy plus exactly seven satoshis of real fees at height 101, after coinbase maturity. Claim subsidy+7 or subsidy+8; require active inclusion for acceptance and exact bad-cb-amount for rejection. Height zero's connection bypass is not used.")?);
    }
    Ok(out)
}

/// Full family dispatch for the captain's aggregate runner. Each independent
/// recipe also has the explicit ignored-test entry point used by this lane.
pub(super) fn run(root: &Path) -> Result<Vec<Value>> {
    let rows = row_read("block")?;
    let mut results = context_blocks(root, &rows)?;
    results.extend(body_blocks(root, &rows)?);
    results.extend(next_work(&rows)?);
    results.extend(context_headers(root, &rows)?);
    results.extend(proof_of_work(root, &rows)?);
    results.extend(compact_rows(&rows));
    results.extend(subsidies(root, &rows)?);
    results.extend(ttor_blocks(root, &rows)?);
    results.extend(rewards(root, &rows)?);
    let ids: BTreeSet<_> = results
        .iter()
        .map(|r| r["id"].as_str().or_err("a result's id"))
        .collect::<Result<_>>()?;
    if ids.len() != rows.len() || results.len() != rows.len() {
        return Err("block family dispatch omitted or duplicated a row".into());
    }
    Ok(results)
}
