//! #69 era boundaries: the regtest rows on fresh instances; the mainnet rows
//! are the spec projection only. Sources: bitcoin-sv
//! 6504a3aff65ba97c0f6c80962b033e35ecbfed4b; docs/DESIGN-S6.md section 4.2.
use super::core::*;

const MAINNET: &str = "mainnet height, the spec projection only: a private regtest instance compiles regtest's activation heights (src/chainparams.cpp:1463-1490) and no launch option or RPC installs a mainnet height or a mainnet ancestry; DESIGN-S6 4.2";

// [SRC] src/validation.cpp:3070-3077 (the exception is height AND hash);
// src/chainparams.cpp:1463-1464 at PIN.
const REGTEST_EXCEPTION: &str = "the exception needs a regtest block at height 91842 whose hash equals the mainnet block's hash, a SHA256d preimage no recipe can produce; the exception test itself has no network condition (src/validation.cpp:3070-3077)";

// [SRC] src/pow.cpp:95-117 at PIN: the branch is internal; its consequence,
// the parent's bits, is eras/regtest-next-work-bits.
const REGTEST_PATH: &str = "the branch GetNextWorkRequired takes is internal; no RPC reports it. Its consequence, the parent's bits at every height, is measured by eras/regtest-next-work-bits (src/pow.cpp:95-117)";

pub(super) fn unrealizable(row: &Value) -> Option<&'static str> {
    match (row["network"].as_str(), row["id"].as_str()) {
        (Some("mainnet"), _) => Some(MAINNET),
        (_, Some("eras/regtest-bip30-91842-exception")) => Some(REGTEST_EXCEPTION),
        (_, Some("eras/regtest-daa-path-at")) => Some(REGTEST_PATH),
        _ => None,
    }
}

fn row<'a>(rows: &'a [Value], id: &str) -> Result<&'a Value> {
    rows.iter()
        .find(|r| r["id"] == id)
        .ok_or_else(|| format!("eras row {id} absent"))
}

fn mine_to(n: &mut Node, mut count: u64) -> Result<()> {
    while count > 0 {
        let batch = count.min(250);
        n.mine(batch, 1_699_999_000)?;
        count -= batch;
    }
    Ok(())
}

// A solved block of the given header version on the active tip, one second
// after the tip, with adjusted time fixed to the block's time.
// [SRC] src/validation.cpp:5950-5960 at PIN.
fn submit_version(n: &mut Node, version: i32, txs: &[RawTx]) -> Result<(String, Value, Vec<u8>)> {
    let tip = n.tip()?;
    let time = tip["time"].as_u64().ok_or("tip time")? as u32 + 1;
    n.call("setmocktime", json!([time]))?;
    let (h, bytes) = block_codec::assemble(
        version,
        txid_from_display_hex(text(&tip["hash"])?)?,
        time,
        u32::from_str_radix(text(&tip["bits"])?, 16).map_err(|e| e.to_string())?,
        txs,
    );
    let reply = n.receipt("submitblock", json!([hex::encode(&bytes)]))?;
    Ok((txid_display_hex(&h.hash()), reply, bytes))
}

fn height(n: &mut Node) -> Result<u64> {
    n.tip()?["height"]
        .as_u64()
        .ok_or_else(|| "tip height".into())
}

// The P2PKH spend of a coinbase's output 0 with an explicit lock time and a
// non-final sequence, signed with FORKID over that lock time.
// [SRC] src/validation.cpp:227-247; src/script/interpreter.cpp sighash at PIN.
#[allow(
    clippy::expect_used,
    reason = "the scenario key is a fixed valid scalar; the signer refuses only a zero or out-of-range digest scalar"
)]
fn locked(parent: &RawTx, value: u64, lock_time: u32) -> RawTx {
    use bsv_rs::primitives::bsv::sighash::{
        compute_sighash_for_signing, SighashParams, TxInput, TxOutput,
    };
    let mut tx = spend(parent, value, 1);
    tx.lock_time = lock_time;
    tx.inputs[0].sequence = 0xfffffffe;
    let inputs = vec![TxInput {
        txid: parent.txid_internal(),
        output_index: 0,
        script: vec![],
        sequence: 0xfffffffe,
    }];
    let outputs = vec![TxOutput {
        satoshis: value,
        script: script(),
    }];
    let digest = compute_sighash_for_signing(&SighashParams {
        version: 1,
        inputs: &inputs,
        outputs: &outputs,
        locktime: lock_time,
        input_index: 0,
        subscript: &parent.outputs[0].script,
        satoshis: parent.outputs[0].satoshis,
        scope: 0x41,
    });
    let signature = key().sign(&digest).expect("key().sign(&digest)");
    let integer = |x: &[u8; 32]| {
        let mut bytes: Vec<u8> = x.iter().copied().skip_while(|v| *v == 0).collect();
        if bytes.is_empty() {
            bytes.push(0);
        }
        if bytes[0] & 128 != 0 {
            bytes.insert(0, 0);
        }
        [vec![2, bytes.len() as u8], bytes].concat()
    };
    let payload = [integer(signature.r()), integer(signature.s())].concat();
    let der = [vec![0x30, payload.len() as u8], payload, vec![0x41]].concat();
    tx.inputs[0].script.clear();
    bsv_script_harness::gen::push_min(&mut tx.inputs[0].script, &der);
    bsv_script_harness::gen::push_min(
        &mut tx.inputs[0].script,
        &key().public_key().to_compressed(),
    );
    tx
}

fn coinbase_at(n: &mut Node, h: u64) -> Result<RawTx> {
    let hash = n.call("getblockhash", json!([h]))?;
    let block = n.call("getblock", json!([hash, 1]))?;
    n.raw_tx(&block["tx"][0])
}

fn judged(n: &mut Node, row: &Value, reply: &Value, recipe: &str, fixtures: Value) -> Value {
    measured(
        row,
        block_judgment(reply),
        block_expect(row),
        recipe,
        std::mem::take(&mut n.calls),
        fixtures,
    )
}

// [SRC] src/pow.cpp:101-109; src/chainparams.cpp:1471-1477,1490,1513-1518;
// src/rpc/blockchain.cpp:884-1038 at PIN.
fn bits(root: &Path, r: &Value) -> Result<Value> {
    let mut n = start_retry(root, "eras-bits", "")?;
    let blocks = r["blocks"].as_u64().ok_or("blocks")?;
    n.mine(blocks, 1_699_999_000)?;
    let mut bits = vec![];
    for h in 1..=blocks {
        let hash = n.call("getblockhash", json!([h]))?;
        let header = n.call("getblockheader", json!([hash, true]))?;
        bits.push(header["bits"].clone());
    }
    let conf = n.conf.clone();
    let dir = instance_pointer(&n.dir);
    n.stop()?;
    Ok(measured(r, json!({"bits":bits}), r["expected"].clone(),
        "Fresh regtest instance: generate the row's blocks from genesis (daaHeight 0, fPowNoRetargeting true) and read each block's bits with getblockheader. Every next-work computation returns the parent's bits; the DAA branch is never reached.",
        std::mem::take(&mut n.calls), json!({"conf":conf,"datadir":dir})))
}

// [SRC] src/validation.cpp:3070-3117; src/config.cpp:2051-2067;
// src/init.cpp:2514-2520; src/chainparams.cpp:1555-1556 at PIN.
fn bip30(root: &Path, r: &Value) -> Result<Value> {
    let disable = r["disable"].as_bool().ok_or("disable")?;
    let name = text(&r["id"])?.replace('/', "-");
    let mut n = start_retry(
        root,
        &name,
        if disable {
            "disablebip30checks=1\n"
        } else {
            ""
        },
    )?;
    mine_to(&mut n, 101)?;
    let c = cb(102, "eras-bip30");
    let (a, reply_a, _) = submit_version(&mut n, 4, std::slice::from_ref(&c))?;
    if block_judgment(&reply_a) != json!({"status":"ok"}) || height(&mut n)? != 102 {
        return Err(format!("bip30 block A: {reply_a}"));
    }
    let (b, reply, bytes) = submit_version(&mut n, 4, std::slice::from_ref(&c))?;
    let tip = n.call("getbestblockhash", json!([]))?;
    let conf = n.conf.clone();
    let dir = instance_pointer(&n.dir);
    n.stop()?;
    Ok(judged(&mut n, r, &reply,
        "Fresh regtest instance mined to 101. Block A at 102 holds coinbase C; block B at 103 repeats C byte for byte (BIP34's height push is not enforced below 100000000). With the setting at its default the overwrite check runs; with -disablebip30checks=1 (permitted on regtest) it does not.",
        json!({"C":material(&c),"A":a,"B":b,"block":hex::encode(bytes),"tip_after":tip,"conf":conf,"datadir":dir})))
}

// [SRC] src/validation.cpp:5962-5972; src/chainparams.cpp:1463-1468 at PIN.
fn versions(root: &Path, rows: &[Value]) -> Result<Vec<Value>> {
    let mut n = start_retry(root, "eras-versions", "")?;
    let recipe = "One fresh regtest instance. Generate to 1249; submit a version-1 block at 1250; at 1251 submit version-1 and version-2 blocks (each rejected, the tip stays 1250); generate to 1349; submit version 3 at 1350, then version 3 at 1351. Each row is the submitblock reply to its block.";
    let mut out = vec![];
    mine_to(&mut n, 1249)?;
    for (id, version, at) in [
        ("eras/regtest-v1-below-bip66", 1, 1250u64),
        ("eras/regtest-v1-at-bip66", 1, 1251),
        ("eras/regtest-v2-at-bip66", 2, 1251),
        ("eras/regtest-v3-below-bip65", 3, 1350),
        ("eras/regtest-v3-at-bip65", 3, 1351),
    ] {
        let r = row(rows, id)?;
        if r["height"].as_u64() != Some(at) || r["version"].as_i64() != Some(version as i64) {
            return Err(format!("{id}: row inputs changed"));
        }
        let tip = height(&mut n)?;
        if tip + 1 < at {
            mine_to(&mut n, at - 1 - tip)?;
        }
        if height(&mut n)? + 1 != at {
            return Err(format!("{id}: tip not at {}", at - 1));
        }
        let (hash, reply, bytes) = submit_version(
            &mut n,
            version,
            &[cb(at as u32, &format!("eras-v{version}-{at}"))],
        )?;
        let accepted = block_judgment(&reply) == json!({"status":"ok"});
        if accepted != (height(&mut n)? == at) {
            return Err(format!("{id}: acceptance and tip disagree"));
        }
        let fixtures = json!({"hash":hash,"version":version,"height":at,"block":hex::encode(bytes),"datadir":instance_pointer(&n.dir)});
        out.push(judged(&mut n, r, &reply, recipe, fixtures));
    }
    n.stop()?;
    Ok(out)
}

// [SRC] src/validation.cpp:6046-6050,6055-6056,6067-6083,227-247;
// src/chainparams.cpp:1470; src/rpc/blockchain.cpp:1108-1242 at PIN.
fn csv(root: &Path, rows: &[Value]) -> Result<Vec<Value>> {
    let mut n = start_retry(root, "eras-csv", "")?;
    let recipe = "One fresh regtest instance mined to 574. At 575 (below csvHeight 576) a signed spend of block 1's coinbase with lock time equal to the parent's median time past and sequence 0xfffffffe, in a block one second after the parent: final against the block's own time. At 576 the same construction over block 2's coinbase, lock time equal to the new parent's median time past: the cutoff is that median, so the lock is not below it.";
    let mut out = vec![];
    mine_to(&mut n, 574)?;
    for (id, at, source) in [
        ("eras/regtest-csv-cutoff-below", 575u64, 1u64),
        ("eras/regtest-csv-cutoff-at", 576, 2),
    ] {
        let r = row(rows, id)?;
        if r["height"].as_u64() != Some(at) || height(&mut n)? + 1 != at {
            return Err(format!("{id}: tip not at {}", at - 1));
        }
        let coin = coinbase_at(&mut n, source)?;
        let tip = n.tip()?;
        let median = tip["mediantime"].as_u64().ok_or("median")? as u32;
        let tx = locked(&coin, coin.outputs[0].satoshis - 1000, median);
        let (hash, reply, bytes) =
            submit_version(&mut n, 4, &[cb(at as u32, "eras-csv"), tx.clone()])?;
        let fixtures = json!({"hash":hash,"lock_time":median,"parent_median":median,"parent_time":tip["time"],"tx":material(&tx),"block":hex::encode(bytes),"datadir":instance_pointer(&n.dir)});
        out.push(judged(&mut n, r, &reply, recipe, fixtures));
    }
    n.stop()?;
    Ok(out)
}

// [SRC] src/validation.cpp:5795-5816,6058-6065; src/verify_script_flags.cpp:54-59;
// src/chainparams.cpp:1487 at PIN.
fn uahf(root: &Path, r: &Value) -> Result<Value> {
    let mut n = start_retry(root, "eras-uahf", "")?;
    let (hash, reply, bytes) = submit_version(&mut n, 4, &[cb(1, "eras-uahf")])?;
    let size = bytes.len();
    let conf = n.conf.clone();
    let dir = instance_pointer(&n.dir);
    n.stop()?;
    Ok(judged(&mut n, r, &reply,
        "Fresh regtest instance (uahfHeight 0). Submit a coinbase-only block at height 1, far below the legacy 1,000,000-byte bound, under excessiveblocksize 1000001. No fork-block minimum size applies; only the status is compared (the spec row's size is its own block's).",
        json!({"hash":hash,"size":size,"block":hex::encode(bytes),"conf":conf,"datadir":dir})))
}

pub(super) fn run(root: &Path) -> Result<Vec<Value>> {
    let rows = row_read("eras")?;
    let mut out = vec![bits(root, row(&rows, "eras/regtest-next-work-bits")?)?];
    out.push(bip30(root, row(&rows, "eras/regtest-bip30-enforced")?)?);
    out.push(bip30(root, row(&rows, "eras/regtest-bip30-disabled")?)?);
    out.extend(versions(root, &rows)?);
    out.extend(csv(root, &rows)?);
    out.push(uahf(root, row(&rows, "eras/regtest-uahf-size-at")?)?);
    Ok(out)
}
