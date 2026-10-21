//! Family-owned realization recipes. Sources and observation boundaries are retained in receipts.
use super::core::*;

fn finality_zero(root: &Path, row: &Value) -> Result<Value> {
    let mut n = start_retry(
        root,
        "finality-lock-zero",
        "genesisactivationheight=10\nchronicleactivationheight=20\n",
    )?;
    let hashes = n.mine(100, 1_699_990_000)?;
    let b = n.call("getblock", json!([hashes[0], 1]))?;
    let coin = n.raw_tx(&b["tx"][0])?;
    let f = spend_to(&coin, 1000, 1, vec![0x51]);
    let (_, funded) = n.submit(&[cb(101, "finality-fund"), f.clone()], 1_699_995_000)?;
    if block_judgment(&funded) != json!({"status":"ok"}) {
        return Err("finality funding refused".into());
    }
    n.mine(99, 1_699_999_000)?;
    let tx = RawTx {
        version: row["version"].as_i64().ok_or("version")? as i32,
        lock_time: row["lockTime"].as_u64().ok_or("lock time")? as u32,
        inputs: vec![RawInput {
            txid: f.txid_internal(),
            vout: 0,
            script: vec![],
            sequence: row["sequences"][0].as_u64().ok_or("sequence")? as u32,
        }],
        outputs: vec![RawOutput {
            satoshis: 900,
            script: vec![0x51],
        }],
    };
    let (hash, reply) = n.submit(&[cb(201, "finality-zero"), tx.clone()], 1_700_000_000)?;
    let verdict = block_judgment(&reply);
    if verdict["status"] != "ok" {
        return Err(format!(
            "zero-lock setup did not pass remaining checks: {reply}"
        ));
    }
    let body = n.call("getblock", json!([hash, 1]))?;
    let observed = body["confirmations"].as_i64().unwrap_or(0) > 0
        && body["tx"]
            .as_array()
            .is_some_and(|a| a.contains(&json!(id(&tx))));
    n.stop()?;
    Ok(measured(row,json!(observed),row["expected"].clone(),"Zero-lock early return, with the row version/lock time/sequence, funded OP_TRUE input and live accepted block. Height/time are rematerialized at 201/1700000000 because this early return ignores them; no claim for height/time comparison rows. Remaining block/input/script checks must all pass.",std::mem::take(&mut n.calls),json!({"funding":material(&f),"transaction":material(&tx),"conf":n.conf})))
}
fn inherited_run(root: &Path) -> Result<Vec<Value>> {
    let rows = row_read("finality")?;
    Ok(vec![finality_zero(
        root,
        rows.iter()
            .find(|r| r["id"] == "finality/lock-zero")
            .ok_or("zero-lock row absent")?,
    )?])
}
pub(super) fn unrealizable(row: &Value) -> Option<&'static str> {
    match row["id"].as_str()? {
        "median/empty-total-extension" | "median/zero-span-total-extension" => Some(
            "model total extension has no nonempty active block index with the pinned median span",
        ),
        "median/configured-span" => {
            Some("medianTimeSpan is a compiled constant with no regtest RPC or launch override")
        }
        "tip/flags-0" | "tip/flags-1" => Some("the admission caller always sets LOCKTIME_MEDIAN_TIME_PAST; no RPC or launch override supplies this stage flag word ([SRC] src/validation.cpp:1096-1106,5998-6028; src/policy/policy.h:246-255 at 6504a3aff65ba97c0f6c80962b033e35ecbfed4b)"),
        "block/absent-csv-unresolved" => Some("regtest CSVHeight is the compiled integer 576, not an absent optional input; no RPC or launch override removes it ([SRC] src/chainparams.cpp:1470; src/validation.cpp:6042-6050 at 6504a3aff65ba97c0f6c80962b033e35ecbfed4b)"),
        "block/configured-span" => Some("the requested median span differs from compiled nMedianTimeSpan=11, with no RPC or launch override ([SRC] src/block_index.h:720-737 at 6504a3aff65ba97c0f6c80962b033e35ecbfed4b)"),
        "sequence/height-vector-mismatch" => Some("the live caller resizes and populates one height per transaction input; mismatched vectors are a model totalization and violate the source assertion ([SRC] src/validation.cpp:261,387-405 at 6504a3aff65ba97c0f6c80962b033e35ecbfed4b)"),
        "sequence/missing-ancestor" => Some("a live active chain retains every required coin predecessor index; this incomplete model ancestor list cannot reach the dereferencing stage ([SRC] src/validation.cpp:295-297,387-405 at 6504a3aff65ba97c0f6c80962b033e35ecbfed4b)"),
        "sequence/flag-off" => Some("before Genesis the admission caller always selects LOCKTIME_VERIFY_SEQUENCE; no RPC or launch override disables that bit while preserving the pre-Genesis CheckSequenceLocks branch ([SRC] src/policy/policy.h:246-255; src/validation.cpp:1096-1106,370-373 at 6504a3aff65ba97c0f6c80962b033e35ecbfed4b)"),
        "fee/max-minus-one" | "fee/max" | "fee/equal-max-values" | "fee/subtract-one" => Some("the exact input amount exceeds all spendable regtest issuance: compiled halving interval 150 and 50-coin initial subsidy bound total issuance below 15000 coins; no RPC or launch override creates this input ([SRC] src/chainparams.cpp:1460; src/validation.cpp:2252-2264,3654-3661 at 6504a3aff65ba97c0f6c80962b033e35ecbfed4b)"),
        "fee/max-plus-one" => Some("the positive input above MAX_MONEY is rejected before the isolated fee stage, and exceeds regtest issuance ([SRC] src/validation.cpp:2637-2663; src/amount.h:130-134 at 6504a3aff65ba97c0f6c80962b033e35ecbfed4b)"),
        "fee/negative-input-stage" => Some("negative output values cannot enter the live UTXO set and input MoneyRange precedes the isolated fee stage ([SRC] src/validation.cpp:542-551,2637-2663 at 6504a3aff65ba97c0f6c80962b033e35ecbfed4b)"),
        "median/eleven-unsorted" | "median/older-twelfth-ignored" => Some("the requested chronological suffix requires its penultimate header time 1 after a parent median at least 5, even with all unknown older headers lower; an equal-offset rematerialization is refused before index insertion ([SRC] src/validation.cpp:5949-5954; src/block_index.h:720-737 at 6504a3aff65ba97c0f6c80962b033e35ecbfed4b)"),
        "median/eleven-duplicates" => Some("the chronological suffix requires another time-1 header after a parent median at least 1; even arbitrarily low older ancestry cannot satisfy the strict header-time check ([SRC] src/validation.cpp:5949-5954; src/block_index.h:720-737 at 6504a3aff65ba97c0f6c80962b033e35ecbfed4b)"),
        "median/short-three" | "median/short-four-upper-middle" => Some("the requested short-chain order places a header below its existing parent median; translating the fixed genesis timestamp preserves that violation ([SRC] src/validation.cpp:5949-5954; src/block_index.h:720-737; src/chainparams.cpp:1507-1516 at 6504a3aff65ba97c0f6c80962b033e35ecbfed4b)"),
        "expiry/below" | "expiry/equal" | "expiry/above" | "expiry/clock-backward" => Some("the row requests expiry 10 seconds; the node launch setting parses integer hours and multiplies by 3600, with no RPC setter for a 10-second purge age ([SRC] src/time_locked_mempool.cpp:403-404; src/init.cpp:463-467 at 6504a3aff65ba97c0f6c80962b033e35ecbfed4b)"),
        "block/before-csv-equal-own-time" => Some("the row's block time 500000010 is below its parent median 500000011; header time-too-old precedes the requested own-time finality stage, and equal-offset rematerialization preserves that failure ([SRC] src/validation.cpp:5949-5954,6042-6074 at 6504a3aff65ba97c0f6c80962b033e35ecbfed4b)"),
        "block/no-parent-zero-lock" => Some("a missing parent is available only for the compiled genesis block, which cannot be replaced with this stage transaction through submitblock ([SRC] src/chainparams.cpp:1507-1516; src/validation.cpp:6042-6056 at 6504a3aff65ba97c0f6c80962b033e35ecbfed4b)"),
        "finality/empty-inputs" => Some("an empty ordinary input vector fails CheckRegularTransaction before contextual finality; the model's vacuous all-final result has no full-transaction observation ([SRC] src/validation.cpp:520-538,5874-5890,6067-6074 at 6504a3aff65ba97c0f6c80962b033e35ecbfed4b)"),
        "finality/threshold-499999998" | "finality/threshold-499999999" => Some("literal candidate height 500000000 cannot be mined on a regtest instance in this harness; LOCKTIME_THRESHOLD at src/script/script.h:36 and src/validation.cpp:227-237 at 6504a3aff65ba97c0f6c80962b033e35ecbfed4b"),
        "finality/threshold-500000000" | "finality/threshold-500000001" | "finality/threshold-500000002" => Some("the exact threshold-adjacent lock requires cutoff 500000000, below fixed regtest genesis time 1296688602; accepted ancestry cannot reach that cutoff, and translating the lock would erase the numeric threshold boundary ([SRC] src/chainparams.cpp:1507-1516; src/validation.cpp:227-237,5949-5954; src/block_index.h:720-737 at 6504a3aff65ba97c0f6c80962b033e35ecbfed4b)"),
        "sequence/genesis-at-tip-short-circuit" | "sequence/genesis-after-tip-short-circuit" => Some("the isolated bypass supplies missing coin/vector/ancestry inputs; live admission must establish input availability before CheckSequenceLocks, so this malformed-input short circuit has no matching RPC path ([SRC] src/validation.cpp:1164-1204,370-373 at 6504a3aff65ba97c0f6c80962b033e35ecbfed4b)"),
        "sequence/zero-relative" | "sequence/time-zero-clamped-ancestor" => Some("the row requires a spendable coin at height zero; the pinned genesis coinbase never enters the spendable UTXO view, and moving the coin would erase the zero-height clamped-ancestor boundary ([SRC] src/validation.cpp:3040-3050; src/chainparams.cpp:1507-1516 at 6504a3aff65ba97c0f6c80962b033e35ecbfed4b)"),
        _ => None,
    }
}

// Lane-local entry point avoids changing the shared driver during the parallel round.
// [SRC] src/validation.cpp:1093-1124,5977-6074; src/chainparams.cpp:1470.
fn signed_boundary(root: &Path, row: &Value) -> Result<Value> {
    let name = text(&row["id"])?.replace('/', "-");
    let mut n = start_retry(
        root,
        &name,
        "genesisactivationheight=10\nchronicleactivationheight=20\n",
    )?;
    let hashes = n.mine(100, 1_699_990_000)?;
    let body = n.call("getblock", json!([hashes[0], 1]))?;
    let coin = n.raw_tx(&body["tx"][0])?;
    let fund = spend_to(&coin, 10000, 1, vec![0x51]);
    let (_, reply) = n.submit(&[cb(101, "fin-fund"), fund.clone()], 1_699_995_000)?;
    require_ok(&reply)?;
    n.mine(488, 1_699_999_000)?;
    for t in row["times"].as_array().ok_or("times")?.iter().rev() {
        let hashes = n.mine(1, t.as_u64().ok_or("time")?)?;
        let header = n.call("getblock", json!([hashes[0], 1]))?;
        if header["time"] != *t {
            return Err("mined timestamp differs from signed-boundary input".into());
        }
    }
    let tip = n.tip()?;
    let mut times: Vec<u64> = row["times"]
        .as_array()
        .or_err("row['times'].as_array()")?
        .iter()
        .map(|v| v.as_u64().or_err("a time"))
        .collect::<Result<_>>()?;
    times.sort();
    if tip["height"] != 600 || tip["mediantime"] != times[5] {
        return Err(format!("signed boundary not reached: {tip}"));
    }
    let tx = RawTx {
        version: row["version"].as_i64().ok_or("version")? as i32,
        lock_time: row["lockTime"].as_u64().ok_or("lock")? as u32,
        inputs: vec![RawInput {
            txid: fund.txid_internal(),
            vout: 0,
            script: vec![],
            sequence: row["sequences"][0].as_u64().ok_or("sequence")? as u32,
        }],
        outputs: vec![RawOutput {
            satoshis: 9000,
            script: vec![0x51],
        }],
    };
    let (observed, expected) = if row["kind"] == "block" {
        let (hash, reply) = n.submit(
            &[cb(601, "signed-boundary"), tx.clone()],
            row["blockTime"].as_u64().ok_or("block time")? as u32,
        )?;
        let judgment = block_judgment(&reply);
        if judgment["status"] == "ok" {
            check_inclusion(&mut n, &hash, &tx)?;
        }
        (
            judgment,
            if row["expected"]["status"] == "final" {
                json!({"status":"ok"})
            } else {
                block_expect(row)
            },
        )
    } else {
        n.call("setmocktime", json!([row["now"]]))?;
        let reply = n.receipt("sendrawtransaction", json!([hex::encode(tx.encode())]))?;
        (
            pool_projection(&mut n, &tx, &reply)?,
            row["expected"].clone(),
        )
    };
    n.stop()?;
    Ok(measured(row, observed, expected,
        "Exact signed-boundary lock, sequences and eleven header times; funded OP_TRUE input. Tip 10 maps to 600, candidate 11 to 601, preserving the post-Genesis/Chronicle and CSV-active branches. Admission observes exact accepted/held pools; block projection observes submitblock reason and active body, since its internal reject code is not an RPC field. [SRC] src/validation.cpp:1093-1124,5977-6074; src/block_index.h:720-737 at 6504a3aff65ba97c0f6c80962b033e35ecbfed4b.",
        std::mem::take(&mut n.calls),json!({"conf":n.conf,"tip":tip,"funding":material(&fund),"transaction":material(&tx)})))
}
fn require_ok(reply: &Value) -> Result<()> {
    if block_judgment(reply) != json!({"status":"ok"}) {
        return Err(format!("setup block refused: {reply}"));
    }
    Ok(())
}
fn check_inclusion(n: &mut Node, hash: &str, tx: &RawTx) -> Result<()> {
    let b = n.call("getblock", json!([hash, 1]))?;
    if b["confirmations"].as_i64().unwrap_or(0) <= 0
        || !b["tx"]
            .as_array()
            .is_some_and(|a| a.contains(&json!(id(tx))))
    {
        return Err("accepted transaction not in active block".into());
    }
    Ok(())
}
fn pool_projection(n: &mut Node, tx: &RawTx, reply: &Value) -> Result<Value> {
    let accepted = n.call("getrawmempool", json!([]))?;
    let held = n.call("getrawnonfinalmempool", json!([]))?;
    if accepted == json!([id(tx)]) && held == json!([]) && reply.get("error").is_none() {
        Ok(json!({"status":"final"}))
    } else if held == json!([id(tx)]) && accepted == json!([]) && reply.get("error").is_none() {
        Ok(json!({"status":"heldNonFinal"}))
    } else if accepted == json!([]) && held == json!([]) {
        node_reject(reply).ok_or("neither admitted nor rejected".into())
    } else {
        Err(format!("unexpected pools: {accepted} / {held}; {reply}"))
    }
}
fn recipe(root: &Path, row: &Value) -> Result<Option<Value>> {
    if text(&row["boundary"])?.starts_with("signed-mtp-") {
        return signed_boundary(root, row).map(Some);
    }
    let boundary = text(&row["boundary"])?;
    if matches!(boundary, "height-below" | "height-equal" | "height-above") {
        return if row["kind"] == "sequence" {
            relative_height(root, row)
        } else {
            ordinary(root, row)
        }
        .map(Some);
    }
    if matches!(boundary, "time-below" | "time-equal" | "time-above") {
        return if row["kind"] == "sequence" {
            relative_time(root, row)
        } else {
            ordinary(root, row)
        }
        .map(Some);
    }
    if matches!(
        boundary,
        "all-final-future-height"
            | "all-final-future-time"
            | "mixed-future-height"
            | "mixed-future-time"
            | "height-ignores-time"
            | "time-ignores-height"
            | "mtp-below"
            | "mtp-equal"
            | "mtp-above"
            | "flags-2"
            | "successor-height"
            | "successor-height-equal"
            | "before-genesis-rejected"
            | "successor-genesis-held"
            | "capacity-0"
            | "capacity-52428800"
            | "final-zero-capacity"
            | "pregenesis-nonstandard"
            | "successor-activation-held"
            | "adjusted-time-does-not-unlock"
            | "before-csv-own-time"
            | "csv-mtp-below"
            | "csv-mtp-equal"
            | "csv-mtp-above"
            | "postgenesis-still-rejected"
    ) {
        return ordinary(root, row).map(Some);
    }
    if row["kind"] == "sequence"
        && matches!(
            boundary,
            "disable-bit"
                | "low-sixteen-mask"
                | "mask-maximum"
                | "version-one"
                | "version-zero"
                | "negative-version-unsigned"
                | "mixed-height-maximum"
                | "disabled-and-active"
        )
    {
        return relative_height(root, row).map(Some);
    }
    match (text(&row["kind"])?, boundary) {
        ("median", "short-one" | "short-two-upper-middle") => {
            return short_median(root, row).map(Some)
        }
        ("fee", "zero" | "one" | "below-out") => return small_fee(root, row).map(Some),
        ("expiry", "zero-expiry" | "backward-zero-expiry") => {
            return zero_expiry(root, row).map(Some)
        }
        ("sequence", "mempool-zero" | "mempool-one" | "time-mempool-one") => {
            return mempool_sequence(root, row).map(Some)
        }
        ("sequence", "missing-coin") => return missing_coin(root, row).map(Some),
        ("sequence", "genesis-minus-one") => return relative_height(root, row).map(Some),
        ("flags", _) => return flags_probe(root, row).map(Some),
        ("tip", "flags-3") | ("mempool", "capacity-1") => return ordinary(root, row).map(Some),
        _ => (),
    }
    if boundary == "time-uses-coin-predecessor" {
        return relative_time(root, row).map(Some);
    }
    if row["id"] == "tip/flags--1" {
        return if Build::of(row)? == Build::Wallet {
            wallet_negative_flag(root, row)
        } else {
            unavailable_wallet_flag(root, row)
        }
        .map(Some);
    }
    Ok(None)
}
pub(super) fn run(root: &Path) -> Result<Vec<Value>> {
    // [D] 2026-10-14 (#121, lane wallet-rows-b): --wallet-only replays only the
    // rows that select the wallet build; every other token is inherited.
    let wallet_only = std::env::args().any(|a| a == "--wallet-only");
    let mut result = if wallet_only {
        vec![]
    } else {
        inherited_run(root)?
    };
    for row in row_read("finality")? {
        if wallet_only && Build::of(&row)? != Build::Wallet {
            continue;
        }
        if let Some(absent) = Build::of(&row)?.absent_row(&row)? {
            result.push(absent);
            continue;
        }
        if let Some(r) = recipe(root, &row)? {
            result.push(r);
        }
    }
    Ok(result)
}

// Translate absolute height/time comparisons without crossing the threshold or
// signed-width boundary. Source cutoff and sequence rules stay independent.
fn ordinary(root: &Path, row: &Value) -> Result<Value> {
    let kind = text(&row["kind"])?;
    let boundary = text(&row["boundary"])?;
    let block = kind == "block" || kind == "finality";
    let pre_csv = boundary.starts_with("before-csv-");
    let tip_height = if kind == "block" {
        // Align the fixture CSV activation itself, not only its active branch.
        575 + row["height"].as_u64().or_err("row['height'].as_u64()")?
            - row["csvHeight"]
                .as_u64()
                .or_err("row['csvHeight'].as_u64()")?
    } else if kind == "finality" {
        600u64
    } else {
        200u64
    };
    let candidate = tip_height + 1;
    let source_height = if kind == "finality" || kind == "block" {
        row["height"].as_u64().or_err("row['height'].as_u64()")?
    } else {
        row["tipHeight"]
            .as_u64()
            .or_err("row['tipHeight'].as_u64()")?
            + 1
    };
    let delta = candidate as i64 - source_height as i64;
    let offset = 1_200_000_000u64;
    let lock = row["lockTime"]
        .as_u64()
        .or_err("row['lockTime'].as_u64()")?;
    let live_lock = if lock == 0 {
        0
    } else if lock < 500_000_000 {
        (lock as i64 + delta) as u64
    } else {
        lock + offset
    };
    if live_lock > u32::MAX as u64 || (lock >= 500_000_000) != (live_lock >= 500_000_000) {
        return Err("translation changed lock domain".into());
    }
    let source_cutoff = if kind == "finality" {
        row["time"].as_u64().or_err("row['time'].as_u64()")?
    } else {
        row["times"][0]
            .as_u64()
            .or_err("row['times'][0].as_u64()")?
    };
    let cutoff = if lock < 500_000_000 {
        1_700_000_000
    } else {
        source_cutoff + offset
    };
    let genesis = if boundary == "flags-3" {
        candidate
    } else if kind == "finality" {
        10
    } else {
        (row["genesisHeight"]
            .as_i64()
            .or_err("row['genesisHeight'].as_i64()")?
            + delta)
            .max(1) as u64
    };
    let chronicle = if kind == "finality" {
        20
    } else {
        (row["chronicleHeight"]
            .as_i64()
            .or_err("row['chronicleHeight'].as_i64()")?
            + delta)
            .max(genesis as i64 + 1) as u64
    };
    let capacity = row["capacity"]
        .as_u64()
        .or_err("row['capacity'].as_u64()")?;
    let extra=format!("genesisactivationheight={genesis}\nchronicleactivationheight={chronicle}\nmaxmempoolnonfinal={capacity}B\n");
    let mut n = start_retry(root, &text(&row["id"])?.replace('/', "-"), &extra)?;
    let seq = row["sequences"].as_array().ok_or("sequences")?;
    let hashes = n.mine(101, cutoff - 20000)?;
    let mut funds = vec![];
    if hashes.len() < seq.len() {
        return Err(format!(
            "{} mined blocks fund {} sequences",
            hashes.len(),
            seq.len()
        ));
    }
    for hash in hashes.iter().take(seq.len()) {
        let b = n.call("getblock", json!([hash, 1]))?;
        let coin = n.raw_tx(&b["tx"][0])?;
        funds.push(spend_to(&coin, 10000, 1, vec![0x51]));
    }
    let txs = [vec![cb(102, "ordinary-fund")], funds.clone()].concat();
    let (_, r) = n.submit(&txs, (cutoff - 10000) as u32)?;
    require_ok(&r)?;
    n.mine(tip_height - 113, cutoff - 1000)?;
    for t in cutoff - 5..=cutoff + 5 {
        n.mine(1, t)?;
    }
    let tip = n.tip()?;
    if tip["height"] != tip_height || tip["mediantime"] != cutoff {
        return Err("ordinary cutoff not reached".into());
    }
    let tx = RawTx {
        version: row["version"].as_i64().or_err("row['version'].as_i64()")? as i32,
        lock_time: live_lock as u32,
        inputs: funds
            .iter()
            .zip(seq)
            .map(|(f, s)| -> Result<RawInput> {
                Ok(RawInput {
                    txid: f.txid_internal(),
                    vout: 0,
                    script: vec![],
                    sequence: s.as_u64().or_err("a sequence")? as u32,
                })
            })
            .collect::<Result<_>>()?,
        outputs: vec![RawOutput {
            satoshis: funds.len() as u64 * 10000 - 1000,
            script: vec![0x51],
        }],
    };
    let (observed, expected) = if block {
        let time = if pre_csv {
            row["blockTime"]
                .as_u64()
                .or_err("row['blockTime'].as_u64()")?
                + offset
        } else {
            cutoff + 100
        };
        let (hash, reply) =
            n.submit(&[cb(candidate as u32, "ordinary"), tx.clone()], time as u32)?;
        let judgment = block_judgment(&reply);
        if judgment["status"] == "ok" {
            check_inclusion(&mut n, &hash, &tx)?;
        }
        if kind == "finality" {
            let b = if judgment["status"] == "ok" {
                true
            } else if judgment == json!({"status":"rejected","reason":"bad-txns-nonfinal"}) {
                false
            } else {
                return Err(format!("earlier check obscures finality: {judgment}"));
            };
            (json!(b), row["expected"].clone())
        } else {
            (
                judgment,
                if row["expected"]["status"] == "final" {
                    json!({"status":"ok"})
                } else {
                    block_expect(row)
                },
            )
        }
    } else {
        let now = if lock < 500_000_000 {
            cutoff + 100
        } else {
            row["now"].as_u64().or_err("row['now'].as_u64()")? + offset
        };
        n.call("setmocktime", json!([now]))?;
        let reply = n.receipt("sendrawtransaction", json!([hex::encode(tx.encode())]))?;
        let observed = pool_projection(&mut n, &tx, &reply)?;
        if kind == "tip" && row["expected"]["status"] == "rejected" {
            // Admission remaps the internal stage's invalid code to nonstandard.
            // Compare only the stage status/reason, preserving raw code in RPC.
            (
                json!({"status":observed["status"],"reason":observed["reason"]}),
                json!({"status":row["expected"]["status"],"reason":row["expected"]["reason"]}),
            )
        } else {
            (observed, row["expected"].clone())
        }
    };
    n.stop()?;
    // R7: the isolated finality gate holds, but full admission reaches insertion.
    // [SRC] src/time_locked_mempool.cpp:447-474 at 6504a3af.
    let isolated_expected = expected.clone();
    let expected = if row["id"] == "mempool/capacity-1" {
        json!({"status":"rejected","namespace":"node","code":259,"reason":"non-final-pool-full"})
    } else {
        expected
    };
    let mut result = measured(row,observed,expected,
        "Funded distinct OP_TRUE inputs retain version and all sequence words. Heights and height locks shift equally to live candidate 201 for tip/admission or 601 for absolute predicates. Block rows map their CSV activation to native height 576, preserving the exact offset: candidate 575 before CSV, 576 at CSV, and 581 at Genesis; time locks and cutoffs shift equally by 1200000000, retaining timestamp type and signed-positive range. Irrelevant alternate cutoff is replaced by a reachable value. The parent median is witnessed at the translated cutoff; own block time is used before CSV. Genesis/Chronicle relative candidate branches and the exact capacity in bytes are retained. For the explicit tip flag-3 row Genesis is placed at the candidate so the predecessor caller supplies word 3 while candidate-era holding stays active. Tip rejection compares status/reason because admission remaps its internal code. [SRC] src/validation.cpp:227-247,1093-1124,5977-6074; src/chainparams.cpp:1470; src/time_locked_mempool.cpp:400; src/util.cpp:311-380 at 6504a3aff65ba97c0f6c80962b033e35ecbfed4b.",
        std::mem::take(&mut n.calls),json!({"conf":n.conf,"tip":tip,"height_delta":delta,"time_offset":offset,"live_lock":live_lock,"funding":funds.iter().map(material).collect::<Vec<_>>(),"transaction":material(&tx)}));
    if row["id"] == "mempool/capacity-1" {
        result["isolated_stage_expected"] = isolated_expected;
        result["comparison_scope"] = json!("full admission; isolated stage says heldNonFinal");
        if result["verdict"] == "agree" {
            result["classification"] = json!("scope limit");
        }
    }
    Ok(result)
}

fn relative_height(root: &Path, row: &Value) -> Result<Value> {
    let mut n = start_retry(
        root,
        &text(&row["id"])?.replace('/', "-"),
        if row["boundary"] == "genesis-minus-one" {
            "genesisactivationheight=201\nchronicleactivationheight=211\n"
        } else {
            "genesisactivationheight=10000\nchronicleactivationheight=15000\n"
        },
    )?;
    let hashes = n.mine(101, 1_699_990_000)?;
    let mut funds = vec![];
    let n_seq = row["sequences"]
        .as_array()
        .or_err("row['sequences'].as_array()")?
        .len();
    if hashes.len() < n_seq {
        return Err(format!(
            "{} mined blocks fund {n_seq} sequences",
            hashes.len()
        ));
    }
    for hash in hashes.iter().take(n_seq) {
        let b = n.call("getblock", json!([hash, 1]))?;
        let coin = n.raw_tx(&b["tx"][0])?;
        funds.push(spend_to(&coin, 10000, 1, vec![0x51]));
    }
    n.mine(98, 1_699_999_000)?;
    let (hash, r) = n.submit(
        &[vec![cb(200, "relative-funds")], funds.clone()].concat(),
        1_700_000_000,
    )?;
    require_ok(&r)?;
    for f in &funds {
        check_inclusion(&mut n, &hash, f)?;
        n.call("gettxout", json!([id(f), 0, false]))?;
    }
    let tx = RawTx {
        version: row["version"].as_i64().or_err("row['version'].as_i64()")? as i32,
        lock_time: row["lockTime"]
            .as_u64()
            .or_err("row['lockTime'].as_u64()")? as u32,
        inputs: funds
            .iter()
            .zip(
                row["sequences"]
                    .as_array()
                    .or_err("row['sequences'].as_array()")?,
            )
            .map(|(f, s)| -> Result<RawInput> {
                Ok(RawInput {
                    txid: f.txid_internal(),
                    vout: 0,
                    script: vec![],
                    sequence: s.as_u64().or_err("a sequence")? as u32,
                })
            })
            .collect::<Result<_>>()?,
        outputs: vec![RawOutput {
            satoshis: funds.len() as u64 * 10000 - 1000,
            script: vec![0x51],
        }],
    };
    let reply = n.receipt("sendrawtransaction", json!([hex::encode(tx.encode())]))?;
    let projection = pool_projection(&mut n, &tx, &reply)?;
    let observed = if projection == json!({"status":"final"}) {
        true
    } else if projection
        == json!({"status":"rejected","namespace":"node","code":64,"reason":"non-BIP68-final"})
    {
        false
    } else {
        return Err(format!("sequence gate obscured: {projection}"));
    };
    let tip = n.tip()?;
    n.stop()?;
    Ok(measured(row,json!(observed),row["expected"].clone(),
        "Mine the funded outputs at live tip 200; row coin and tip heights translate together to 200, preserving candidate-minus-coin distance and all sequence/version words. Keep the tip before Genesis; for genesis-minus-one candidate 201 activates Genesis, retaining the tip-based sequence check. sendrawtransaction must settle into the exact accepted set or return node code 64 non-BIP68-final, with an empty held pool. [SRC] src/validation.cpp:256-341,362-406,1187-1205; src/policy/policy.h:246-255 at 6504a3aff65ba97c0f6c80962b033e35ecbfed4b.",
        std::mem::take(&mut n.calls),json!({"conf":n.conf,"tip":tip,"funding":funds.iter().map(material).collect::<Vec<_>>(),"transaction":material(&tx)})))
}
fn relative_time(root: &Path, row: &Value) -> Result<Value> {
    let coin_at_tip = row["boundary"] == "time-uses-coin-predecessor";
    let delta = if coin_at_tip {
        0
    } else {
        row["times"][1].as_u64().ok_or("relative time delta")?
    };
    let base = 1_700_000_000u64;
    let mut n = start_retry(
        root,
        &text(&row["id"])?.replace('/', "-"),
        "genesisactivationheight=10000\nchronicleactivationheight=15000\n",
    )?;
    let hashes = n.mine(100, base - 20000)?;
    let b = n.call("getblock", json!([hashes[0], 1]))?;
    let coin = n.raw_tx(&b["tx"][0])?;
    n.mine(88, base - 1000)?;
    for t in [
        base - 5,
        base - 4,
        base - 3,
        base - 2,
        base - 1,
        base,
        base + delta,
        base + delta,
        base + delta + 1,
        base + delta + 2,
        base + delta + 3,
    ] {
        n.mine(1, t)?;
    }
    let predecessor = n.tip()?;
    if predecessor["height"] != 199 || predecessor["mediantime"] != base {
        return Err("coin predecessor median not reached".into());
    }
    let fund = spend_to(&coin, 10000, 1, vec![0x51]);
    let (_, r) = n.submit(
        &[cb(200, "relative-time-fund"), fund.clone()],
        (base + 1024) as u32,
    )?;
    require_ok(&r)?;
    if !coin_at_tip {
        n.mine(1, base + 1025)?;
    }
    let tip = n.tip()?;
    if tip["height"] != if coin_at_tip { 200 } else { 201 } || tip["mediantime"] != base + delta {
        return Err("relative-time tip median not reached".into());
    }
    let tx = RawTx {
        version: row["version"].as_i64().or_err("row['version'].as_i64()")? as i32,
        lock_time: 0,
        inputs: vec![RawInput {
            txid: fund.txid_internal(),
            vout: 0,
            script: vec![],
            sequence: row["sequences"][0]
                .as_u64()
                .or_err("row['sequences'][0].as_u64()")? as u32,
        }],
        outputs: vec![RawOutput {
            satoshis: 9000,
            script: vec![0x51],
        }],
    };
    let reply = n.receipt("sendrawtransaction", json!([hex::encode(tx.encode())]))?;
    let projection = pool_projection(&mut n, &tx, &reply)?;
    let observed = if projection == json!({"status":"final"}) {
        true
    } else if projection
        == json!({"status":"rejected","namespace":"node","code":64,"reason":"non-BIP68-final"})
    {
        false
    } else {
        return Err(format!("sequence gate obscured: {projection}"));
    };
    n.stop()?;
    Ok(measured(
        row,
        json!(observed),
        row["expected"].clone(),
        if coin_at_tip {
            "The row coin and tip height 2 map together to 200. Construct and read the coin predecessor at height 199 and the current tip, both with median 1700000000, translating their original median 500 equally. Retain the exact 512-second sequence. The sequence calculation uses the recorded predecessor and rejects with code 64 non-BIP68-final; exact pools are checked. [SRC] src/validation.cpp:295-307,326-341,362-406,1187-1205 at 6504a3aff65ba97c0f6c80962b033e35ecbfed4b."
        } else {
            "The funded coin at live height 200 maps row height 1; tip 201 maps 2. Construct and read coin-predecessor MTP 1700000000 and tip MTP 1700000000 plus the row delta 510, 511 or 512. This retains the 512-second sequence unit and strict last-invalid-time boundary; full ancestry replaces the short synthetic list. Exact version and sequence retained, both tips pre-Genesis. Require exact accepted set or node code 64 non-BIP68-final. [SRC] src/validation.cpp:295-307,326-341,362-406,1187-1205 at 6504a3aff65ba97c0f6c80962b033e35ecbfed4b."
        },
        std::mem::take(&mut n.calls),
        json!({"conf":n.conf,"coin_predecessor":predecessor,"tip":tip,"funding":material(&fund),"transaction":material(&tx)}),
    ))
}

fn short_median(root: &Path, row: &Value) -> Result<Value> {
    let mut n = start_retry(root, &text(&row["id"])?.replace('/', "-"), "")?;
    let genesis = n.tip()?;
    let original = row["times"].as_array().or_err("row['times'].as_array()")?;
    let oldest = original
        .last()
        .or_err("original.last()")?
        .as_u64()
        .or_err("the oldest time")?;
    let offset = genesis["time"]
        .as_u64()
        .or_err("genesis['time'].as_u64()")?
        - oldest;
    for time in original.iter().rev().skip(1) {
        n.mine(1, time.as_u64().or_err("time.as_u64()")? + offset)?;
    }
    let tip = n.tip()?;
    if tip["height"] != original.len() - 1 {
        return Err("short chain height mismatch".into());
    }
    let observed = tip["mediantime"]
        .as_u64()
        .ok_or("median")?
        .checked_sub(offset)
        .ok_or("offset")?;
    n.stop()?;
    Ok(measured(row,json!(observed),row["expected"].clone(),
        "Translate every timestamp by the same offset so the oldest element equals the fixed regtest genesis timestamp. Mine the remaining short ancestry and read getblock mediantime; subtract only that recorded offset. This preserves the one-element and upper-middle two-element medians with the exact short-chain lengths. [SRC] src/block_index.h:720-737; src/chainparams.cpp:1507-1516 at 6504a3aff65ba97c0f6c80962b033e35ecbfed4b.",std::mem::take(&mut n.calls),json!({"conf":n.conf,"genesis":genesis,"tip":tip,"time_offset":offset})))
}
fn small_fee(root: &Path, row: &Value) -> Result<Value> {
    let mut n = start_retry(
        root,
        &text(&row["id"])?.replace('/', "-"),
        "genesisactivationheight=10\nchronicleactivationheight=20\n",
    )?;
    let hashes = n.mine(100, 1_699_990_000)?;
    let b = n.call("getblock", json!([hashes[0], 1]))?;
    let coin = n.raw_tx(&b["tx"][0])?;
    let fund = spend_to(
        &coin,
        row["valueIn"].as_u64().or_err("row['valueIn'].as_u64()")?,
        1,
        vec![0x51],
    );
    let (fund_hash, r) = n.submit(&[cb(101, "fee-fund"), fund.clone()], 1_699_995_000)?;
    require_ok(&r)?;
    check_inclusion(&mut n, &fund_hash, &fund)?;
    let coin_observation = n.call("gettxout", json!([id(&fund), 0, false]))?;
    if coin_observation.is_null() {
        return Err("funding output absent".into());
    }
    let actual_fund = n.raw_tx(&json!(id(&fund)))?;
    let tx = RawTx {
        version: row["version"].as_i64().or_err("row['version'].as_i64()")? as i32,
        lock_time: 0,
        inputs: vec![RawInput {
            txid: fund.txid_internal(),
            vout: 0,
            script: vec![],
            sequence: row["sequences"][0]
                .as_u64()
                .or_err("row['sequences'][0].as_u64()")? as u32,
        }],
        outputs: vec![RawOutput {
            satoshis: row["valueOut"]
                .as_u64()
                .or_err("row['valueOut'].as_u64()")?,
            script: vec![0x51],
        }],
    };
    let (hash, reply) = n.submit(&[cb(102, "fee-spend"), tx.clone()], 1_700_000_000)?;
    let judgment = block_judgment(&reply);
    let (observed, expected) = if judgment["status"] == "ok" {
        check_inclusion(&mut n, &hash, &tx)?;
        let actual_tx = n.raw_tx(&json!(id(&tx)))?;
        if !n.call("gettxout", json!([id(&fund), 0, false]))?.is_null() {
            return Err("accepted input still unspent".into());
        }
        let output = n.call("gettxout", json!([id(&tx), 0, false]))?;
        if output.is_null() {
            return Err("accepted output absent".into());
        }
        let fee = actual_fund.outputs[0]
            .satoshis
            .checked_sub(actual_tx.outputs[0].satoshis)
            .ok_or("negative accepted fee")?;
        (json!({"status":"ok","fee":fee}), row["expected"].clone())
    } else {
        (judgment, block_expect(row))
    };
    n.stop()?;
    Ok(measured(row,observed,expected,
        "Create a mined OP_TRUE output with the exact row input amount and spend it with the exact output amount and sequence. Check active body membership, chain-only output presence/spentness and reread both raw transactions. The accepted fee is the difference of those attested amounts; rejected block comparison retains the exact reason since submitblock omits the internal code. No mempool fee policy is involved. [SRC] src/validation.cpp:2637-2663 at 6504a3aff65ba97c0f6c80962b033e35ecbfed4b.",std::mem::take(&mut n.calls),json!({"conf":n.conf,"coin_observation":coin_observation,"funding":material(&fund),"transaction":material(&tx)})))
}
fn zero_expiry(root: &Path, row: &Value) -> Result<Value> {
    let mut n=start_retry(root,&text(&row["id"])?.replace('/',"-"),"genesisactivationheight=10\nchronicleactivationheight=20\nmempoolexpirynonfinal=0\nchecknonfinalfreq=5000\n")?;
    let hashes = n.mine(101, 1_699_990_000)?;
    let mut funds = vec![];
    for hash in &hashes[..2] {
        let b = n.call("getblock", json!([hash, 1]))?;
        let coin = n.raw_tx(&b["tx"][0])?;
        funds.push(spend_to(&coin, 10000, 1, vec![0x51]));
    }
    let (_, r) = n.submit(
        &[vec![cb(102, "expiry-funds")], funds.clone()].concat(),
        1_699_995_000,
    )?;
    require_ok(&r)?;
    n.mine(98, 1_699_999_000)?;
    let make = |i: usize, lock| RawTx {
        version: 2,
        lock_time: lock,
        inputs: vec![RawInput {
            txid: funds[i].txid_internal(),
            vout: 0,
            script: vec![],
            sequence: 0,
        }],
        outputs: vec![RawOutput {
            satoshis: 9000,
            script: vec![0x51],
        }],
    };
    // Sentinel sorts after the target by unlocking height, so its purge log
    // witnesses a sweep that has already visited the target.
    let target = make(0, 10000);
    let sentinel = make(1, 10001);
    let insertion = 1_700_000_000i64;
    n.call("setmocktime", json!([insertion - 2]))?;
    n.call(
        "sendrawtransaction",
        json!([hex::encode(sentinel.encode())]),
    )?;
    n.call("setmocktime", json!([insertion]))?;
    n.call("sendrawtransaction", json!([hex::encode(target.encode())]))?;
    let held = n.call("getrawnonfinalmempool", json!([]))?;
    let set: BTreeSet<String> = held
        .as_array()
        .ok_or("held")?
        .iter()
        .map(|v| text(v).map(str::to_owned))
        .collect::<Result<_>>()?;
    if set != BTreeSet::from([id(&target), id(&sentinel)]) {
        return Err("expiry setup lost an entry before clock change".into());
    }
    let logfile = n.dir.join("console.log");
    let baseline = fs::read_to_string(&logfile)
        .map_err(|e| e.to_string())?
        .len();
    let now = insertion + row["now"].as_i64().or_err("row['now'].as_i64()")?
        - row["insertionTime"]
            .as_i64()
            .or_err("row['insertionTime'].as_i64()")?;
    n.call("setmocktime", json!([now]))?;
    let needle = format!("Purging expired non-final transaction: {}", id(&sentinel));
    let wait = Instant::now();
    let completion = loop {
        let log = fs::read_to_string(&logfile).map_err(|e| e.to_string())?;
        let suffix = log.get(baseline..).ok_or("log rotated")?;
        if suffix.contains(&needle) {
            break suffix.to_owned();
        }
        if wait.elapsed() > Duration::from_secs(15) {
            return Err("no completed non-final sweep witness".into());
        }
        thread::sleep(Duration::from_millis(50));
    };
    let accepted = n.call("getrawmempool", json!([]))?;
    let held = n.call("getrawnonfinalmempool", json!([]))?;
    if accepted != json!([])
        || held
            .as_array()
            .is_none_or(|v| v.iter().any(|id_| *id_ != json!(id(&target))))
    {
        return Err("unexpected expiry pools".into());
    }
    let observed = held == json!([]);
    if observed
        && !completion.contains(&format!(
            "Purging expired non-final transaction: {}",
            id(&target)
        ))
    {
        return Err("target vanished without purge log".into());
    }
    n.stop()?;
    Ok(measured(row,json!(observed),row["expected"].clone(),
        "Use the exact zero-hour/zero-second expiry and preserve signed elapsed age by translating insertion/now together. Fund a held target that remains height-nonfinal and an older sentinel with a later unlocking height. After changing mock time, require a fresh sentinel purge log, which witnesses a scheduled pass after visiting the target; read exact held/accepted sets and require the target purge log if absent. The expiry scalar does not consume the template transaction, so these future locks prevent finality revalidation from bypassing expiry. [SRC] src/time_locked_mempool.cpp:240-244,400-404,611-663; src/scheduler.h:56 at 6504a3aff65ba97c0f6c80962b033e35ecbfed4b.",std::mem::take(&mut n.calls),json!({"conf":n.conf,"insertion_time":insertion,"now":now,"completion_log":completion,"wait_seconds":wait.elapsed().as_secs_f64(),"target":material(&target),"sentinel":material(&sentinel),"funding":funds.iter().map(material).collect::<Vec<_>>()})))
}
fn mempool_sequence(root: &Path, row: &Value) -> Result<Value> {
    let mut n = start_retry(
        root,
        &text(&row["id"])?.replace('/', "-"),
        "genesisactivationheight=10000\nchronicleactivationheight=15000\n",
    )?;
    let hashes = n.mine(100, 1_699_990_000)?;
    let b = n.call("getblock", json!([hashes[0], 1]))?;
    let coin = n.raw_tx(&b["tx"][0])?;
    let fund = spend(&coin, 100000, 1);
    let (_, r) = n.submit(
        &[cb(101, "mempool-sequence-fund"), fund.clone()],
        1_699_995_000,
    )?;
    require_ok(&r)?;
    n.mine(99, 1_699_999_000)?;
    let parent = spend_to(&fund, 90000, 1, vec![0x51]);
    n.call("sendrawtransaction", json!([hex::encode(parent.encode())]))?;
    if n.call("getrawmempool", json!([]))? != json!([id(&parent)]) {
        return Err("parent not alone in mempool".into());
    }
    let tx = RawTx {
        version: row["version"].as_i64().or_err("row['version'].as_i64()")? as i32,
        lock_time: 0,
        inputs: vec![RawInput {
            txid: parent.txid_internal(),
            vout: 0,
            script: vec![],
            sequence: row["sequences"][0]
                .as_u64()
                .or_err("row['sequences'][0].as_u64()")? as u32,
        }],
        outputs: vec![RawOutput {
            satoshis: 89000,
            script: vec![0x51],
        }],
    };
    let reply = n.receipt("sendrawtransaction", json!([hex::encode(tx.encode())]))?;
    let accepted = n.call("getrawmempool", json!([]))?;
    let set: BTreeSet<String> = accepted
        .as_array()
        .ok_or("accepted")?
        .iter()
        .map(|v| text(v).map(str::to_owned))
        .collect::<Result<_>>()?;
    if n.call("getrawnonfinalmempool", json!([]))? != json!([]) {
        return Err("unexpected held pool".into());
    }
    let observed = if reply.get("error").is_none() && set == BTreeSet::from([id(&parent), id(&tx)])
    {
        true
    } else if set == BTreeSet::from([id(&parent)])
        && node_reject(&reply)
            == Some(
                json!({"status":"rejected","namespace":"node","code":64,"reason":"non-BIP68-final"}),
            )
    {
        false
    } else {
        return Err(format!(
            "unexpected mempool sequence observation {accepted} {reply}"
        ));
    };
    let tip = n.tip()?;
    n.stop()?;
    Ok(measured(row,json!(observed),row["expected"].clone(),
        "Admit a funded parent before its child so the child's input has the actual mempool height sentinel. Keep tip 200 pre-Genesis and retain the child version and sequence. Observe exact parent/child membership or code 64 non-BIP68-final; the sentinel resolves to candidate height or tip MTP as at the pin. [SRC] src/validation.cpp:295-307,362-406,1187-1205 at 6504a3aff65ba97c0f6c80962b033e35ecbfed4b.",std::mem::take(&mut n.calls),json!({"conf":n.conf,"tip":tip,"funding":material(&fund),"parent":material(&parent),"transaction":material(&tx)})))
}
fn missing_coin(root: &Path, row: &Value) -> Result<Value> {
    let mut n = start_retry(
        root,
        "sequence-missing-coin",
        "genesisactivationheight=10000\nchronicleactivationheight=15000\n",
    )?;
    n.mine(10, 1_700_000_000)?;
    let tx = RawTx {
        version: row["version"].as_i64().or_err("row['version'].as_i64()")? as i32,
        lock_time: 0,
        inputs: vec![RawInput {
            txid: [0x42; 32],
            vout: 0,
            script: vec![],
            sequence: 0,
        }],
        outputs: vec![RawOutput {
            satoshis: 0,
            script: vec![0x51],
        }],
    };
    let reply = n.receipt("sendrawtransaction", json!([hex::encode(tx.encode())]))?;
    if reply["error"] != json!({"code":-25,"message":"Missing inputs"}) {
        return Err(format!("missing input not observed: {reply}"));
    }
    if n.call("getrawmempool", json!([]))? != json!([])
        || n.call("getrawnonfinalmempool", json!([]))? != json!([])
    {
        return Err("unexpected pool admission".into());
    }
    n.stop()?;
    Ok(
        json!({"id":row["id"],"label":"[X]","verdict":"rpc-precheck","rpc_precheck":{"code":-25,"message":"Missing inputs","handler":"src/rpc/rawtransaction.cpp:1634-1638"},"recipe":"The exact missing coin reaches the RPC Missing inputs envelope from the earlier HaveInputsLimited gate; CheckSequenceLocks is not observed. [SRC] src/validation.cpp:1170-1204; src/rpc/rawtransaction.cpp:1634-1638 at 6504a3aff65ba97c0f6c80962b033e35ecbfed4b.","expected":row["expected"],"expected_label":"[D]","observed":reply,"fixtures":{"conf":n.conf,"transaction":material(&tx)},"rpc":std::mem::take(&mut n.calls)}),
    )
}
fn flags_probe(root: &Path, row: &Value) -> Result<Value> {
    let mut calls = vec![];
    let mut fixtures = vec![];
    let mut observed = 0u64;
    let delta = 200
        - row["tipHeight"]
            .as_i64()
            .or_err("row['tipHeight'].as_i64()")?;
    let genesis = row["genesisHeight"]
        .as_i64()
        .or_err("row['genesisHeight'].as_i64()")?
        + delta;
    let chronicle = row["chronicleHeight"]
        .as_i64()
        .or_err("row['chronicleHeight'].as_i64()")?
        + delta;
    for time_probe in [true, false] {
        let name = format!(
            "{}-{}",
            text(&row["id"])?.replace('/', "-"),
            if time_probe { "time" } else { "sequence" }
        );
        let mut n = start_retry(
            root,
            &name,
            &format!("genesisactivationheight={genesis}\nchronicleactivationheight={chronicle}\n"),
        )?;
        let hashes = n.mine(100, 1_699_990_000)?;
        let b = n.call("getblock", json!([hashes[0], 1]))?;
        let coin = n.raw_tx(&b["tx"][0])?;
        n.mine(99, 1_699_999_000)?;
        let fund = spend_to(&coin, 10000, 1, vec![0x51]);
        let (_, r) = n.submit(&[cb(200, "flag-fund"), fund.clone()], 1_700_000_000)?;
        require_ok(&r)?;
        let tip = n.tip()?;
        let tx = RawTx {
            version: 2,
            lock_time: if time_probe {
                tip["mediantime"]
                    .as_u64()
                    .or_err("tip['mediantime'].as_u64()")? as u32
            } else {
                0
            },
            inputs: vec![RawInput {
                txid: fund.txid_internal(),
                vout: 0,
                script: vec![],
                sequence: if time_probe { 0 } else { 2 },
            }],
            outputs: vec![RawOutput {
                satoshis: 9000,
                script: vec![0x51],
            }],
        };
        n.call("setmocktime", json!([1_700_001_000]))?;
        let reply = n.receipt("sendrawtransaction", json!([hex::encode(tx.encode())]))?;
        let projection = pool_projection(&mut n, &tx, &reply)?;
        if time_probe {
            if projection == json!({"status":"heldNonFinal"}) {
                observed |= 2
            } else if projection != json!({"status":"final"}) {
                return Err(format!("time flag obscured: {projection}"));
            }
        } else if projection
            == json!({"status":"rejected","namespace":"node","code":64,"reason":"non-BIP68-final"})
        {
            observed |= 1
        } else if projection != json!({"status":"final"}) {
            return Err(format!("sequence flag obscured: {projection}"));
        }
        n.stop()?;
        fixtures.push(json!({"conf":n.conf,"tip":tip,"probe":if time_probe{"median-bit"}else{"sequence-bit"},"transaction":material(&tx),"funding":material(&fund),"projection":projection}));
        calls.extend(std::mem::take(&mut n.calls));
    }
    Ok(measured(row,json!(observed),row["expected"].clone(),
        "Behavioral projection of the two bits returned by StandardNonFinalVerifyFlags, not an RPC numeric flag field. Shift the row tip/activation heights equally to tip 200. In separate owned nodes, a time lock equal to MTP while adjusted time is later identifies bit 2; a version-2 relative height lock equal to candidate-minus-coin plus one identifies bit 1. The flag-selector row consumes only era, so the probe transactions are witnesses of each selected bit. Record both exact settled pool/rejection projections. [SRC] src/policy/policy.h:246-255; src/validation.cpp:1096-1106,1199-1204,5998-6037 at 6504a3aff65ba97c0f6c80962b033e35ecbfed4b.",calls,json!(fixtures)))
}

// [M] 2026-10-14 (#132): called only by the test module's explicit replay, so built with it.
#[cfg(test)]
fn lane_witness(row: &Value, record: &str) -> Result<()> {
    let name = format!("s6-66-fin-{}", text(&row["id"])?.replace('/', "-"));
    let call = row["rpc"]
        .as_array()
        .ok_or("rpc")?
        .iter()
        .rev()
        .find(|c| {
            matches!(
                c["method"].as_str(),
                Some("sendrawtransaction" | "submitblock")
            )
        })
        .ok_or("submission")?;
    let witness = json!({"id":name,"class":"stage projection and live RPC observation differ","classification":"open","source_pin":PIN,"input_label":"[D]","witness":{"family":"finality","row":row["id"],"receipt":record.replace(".md",".json"),"fixtures":row["fixtures"]},"initial_chain":{"recipe":row["recipe"],"complete_rpc_history":record.replace(".md",".json"),"row":row["id"]},"steps":[{"id":"submit","action":{"type":call["method"],"params":call["params"]},"kind":"recorded node observation","rules":[call["source"]],"label":"[D]","expected_observations":row["expected"],"actual_observations":row["observed"],"node":format!("measured diverge [X] {record}")}],"replay":{"record":record,"rpc_handler":call["source"]}});
    fs::write(format!("corpus/scenarios/witnesses/{name}.md"),format!("# {name}\n\n[X] Row {}. Classification is open as data. The live prefix, submitted bytes and exact RPC envelope are retained in the lane receipt.\n\n```json\n{}\n```\n",row["id"],serde_json::to_string_pretty(&witness).or_err("serde_json::to_string_pretty(&witness)")?)).map_err(|e|e.to_string())
}

fn unavailable_wallet_flag(root: &Path, row: &Value) -> Result<Value> {
    let mut n = start_retry_build(
        root,
        "tip-negative-flags-capability",
        1_000_001,
        "",
        Build::of(row)?,
    )?;
    let reply = n
        .rpc
        .as_mut()
        .ok_or("rpc")?
        .call("getwalletinfo", json!([]));
    let error = reply
        .err()
        .ok_or("wallet RPC available; negative-flag wallet recipe remains pending")?;
    let parsed: Value = serde_json::from_str(
        error
            .strip_prefix("rpc error: ")
            .ok_or("wallet probe transport error")?,
    )
    .map_err(|e| e.to_string())?;
    if parsed != json!({"code":-32601,"message":"Method not found"}) {
        return Err(format!(
            "wallet probe did not establish absent command: {parsed}"
        ));
    }
    n.calls.push(json!({"method":"getwalletinfo","params":[],"source":format!("[SRC] src/rpc/server.cpp:567-570; src/wallet/rpcwallet.cpp:3530 at {PIN}"),"reply":{"error":parsed}}));
    n.stop()?;
    Ok(
        json!({"id":row["id"],"label":"[X]","unrealizable":"the pinned owned build has no getwalletinfo command (RPC -32601 Method not found), so the wallet's default negative-flag caller is unavailable; admission and reorg callers supply the median-time flag with no override ([SRC] src/validation.h:1048-1054; src/wallet/rpcwallet.cpp:740-752,3530; src/rpc/server.cpp:567-570; src/validation.cpp:1096-1106; src/txmempool.cpp:2406-2411,2472-2477 at 6504a3aff65ba97c0f6c80962b033e35ecbfed4b)","fixtures":{"conf":n.conf},"rpc":std::mem::take(&mut n.calls)}),
    )
}

// [D] 2026-10-14 (#121, lane wallet-rows-b): the wallet's default-flag caller on
// the wallet build. getreceivedbyaddress tallies a wallet transaction only when
// ContextualCheckTransactionForCurrentBlock passes with its default flags -1
// (src/wallet/rpcwallet.cpp:740-752; src/validation.h:1048-1054), which clamp to
// 0 and select the adjusted-time cutoff (src/validation.cpp:5998-6028). Admission
// evaluates the same transaction under the median flag and holds it in the
// non-final pool (src/validation.cpp:1093-1124; src/policy/policy.h:246-255); a
// held transaction is valid, so the wallet is notified of it
// (src/txn_validator.cpp:203-207; src/wallet/wallet.cpp:1355-1377). An unconfirmed
// wallet transaction has depth 0 (src/wallet/merkle_tx.cpp:24-32), so the tally at
// minconf 0 is the predicate's projection. Heights and times translate as
// `ordinary` translates a tip row (tip 200, time offset 1200000000).
fn wallet_negative_flag(root: &Path, row: &Value) -> Result<Value> {
    let tip_height = 200u64;
    let delta = tip_height as i64 + 1 - (row["tipHeight"].as_i64().ok_or("tipHeight")? + 1);
    let offset = 1_200_000_000u64;
    let lock = row["lockTime"].as_u64().ok_or("lockTime")?;
    if lock < 500_000_000 {
        return Err("the wallet recipe translates a time lock only".into());
    }
    let live_lock = lock + offset;
    if live_lock > u32::MAX as u64 {
        return Err("translation changed lock domain".into());
    }
    let cutoff = row["times"][0].as_u64().ok_or("times")? + offset;
    let now = row["now"].as_u64().ok_or("now")? + offset;
    let genesis = (row["genesisHeight"].as_i64().ok_or("genesisHeight")? + delta).max(1);
    let chronicle =
        (row["chronicleHeight"].as_i64().ok_or("chronicleHeight")? + delta).max(genesis + 1);
    let capacity = row["capacity"].as_u64().ok_or("capacity")?;
    let extra = format!("genesisactivationheight={genesis}\nchronicleactivationheight={chronicle}\nmaxmempoolnonfinal={capacity}B\n");
    let mut n = start_retry_build(
        root,
        "tip-negative-flags-wallet",
        1_000_001,
        &extra,
        Build::of(row)?,
    )?;
    let wallet = n.call("getwalletinfo", json!([]))?;
    let hashes = n.mine(101, cutoff - 20000)?;
    let b = n.call("getblock", json!([hashes[0], 1]))?;
    let coin = n.raw_tx(&b["tx"][0])?;
    let fund = spend_to(&coin, 10000, 1, vec![0x51]);
    let (_, r) = n.submit(
        &[cb(102, "wallet-flag-fund"), fund.clone()],
        (cutoff - 10000) as u32,
    )?;
    require_ok(&r)?;
    n.mine(tip_height - 113, cutoff - 1000)?;
    for t in cutoff - 5..=cutoff + 5 {
        n.mine(1, t)?;
    }
    let tip = n.tip()?;
    if tip["height"] != tip_height || tip["mediantime"] != cutoff {
        return Err("wallet flag cutoff not reached".into());
    }
    let address = n.call("getnewaddress", json!([]))?;
    let lock_script = hex::decode(text(
        &n.call("validateaddress", json!([address]))?["scriptPubKey"],
    )?)
    .map_err(|e| e.to_string())?;
    let seq = row["sequences"].as_array().ok_or("sequences")?;
    if seq.len() != 1 {
        return Err("the wallet recipe funds one input".into());
    }
    let tx = RawTx {
        version: row["version"].as_i64().ok_or("version")? as i32,
        lock_time: live_lock as u32,
        inputs: vec![RawInput {
            txid: fund.txid_internal(),
            vout: 0,
            script: vec![],
            sequence: seq[0].as_u64().ok_or("sequence")? as u32,
        }],
        outputs: vec![RawOutput {
            satoshis: 9000,
            script: lock_script,
        }],
    };
    n.call("setmocktime", json!([now]))?;
    let reply = n.receipt("sendrawtransaction", json!([hex::encode(tx.encode())]))?;
    let admission = pool_projection(&mut n, &tx, &reply)?;
    if admission != json!({"status":"heldNonFinal"}) {
        return Err(format!("admission did not hold the transaction, so the tally cannot separate the flags: {admission}"));
    }
    n.call("gettransaction", json!([id(&tx)]))?;
    let satoshis = |v: &Value| {
        v.as_f64()
            .map(|x| (x * 1e8).round() as u64)
            .ok_or("tally amount")
    };
    // A control at adjusted time equal to the lock: the same caller excludes it.
    n.call("setmocktime", json!([live_lock]))?;
    let control = satoshis(&n.call("getreceivedbyaddress", json!([address, 0]))?)?;
    n.call("setmocktime", json!([now]))?;
    let tally = satoshis(&n.call("getreceivedbyaddress", json!([address, 0]))?)?;
    let observed = match tally {
        9000 => json!({"status":"final"}),
        0 => json!({"status":"heldNonFinal"}),
        other => return Err(format!("tally {other} is neither the output nor zero")),
    };
    n.stop()?;
    Ok(measured(row, observed, row["expected"].clone(),
        "Wallet build, wallet enabled. Tip 10 maps to 200 and Genesis/Chronicle shift equally (200/210); the time lock, the eleven-header median and adjusted now shift by 1200000000, so median <= lock < now holds as in the row. A funded OP_TRUE input with the row's version and sequence pays 9000 satoshis to a fresh wallet address. Admission (the median-time caller) must hold it in the non-final pool, and the wallet must list it (gettransaction). The judged observation is getreceivedbyaddress at minconf 0 under adjusted now, whose caller passes the default flags -1: the output counted is final, zero is heldNonFinal. A recorded control repeats the tally at adjusted time equal to the lock. [SRC] src/wallet/rpcwallet.cpp:680-764,740-752; src/validation.h:1048-1054; src/validation.cpp:227-247,1093-1124,5977-6037; src/txn_validator.cpp:203-207; src/wallet/wallet.cpp:1355-1377; src/wallet/merkle_tx.cpp:24-32 at 6504a3aff65ba97c0f6c80962b033e35ecbfed4b.",
        std::mem::take(&mut n.calls),
        json!({"conf":n.conf,"tip":tip,"height_delta":delta,"time_offset":offset,"live_lock":live_lock,"adjusted_now":now,"wallet":wallet,"address":address,"funding":material(&fund),"transaction":material(&tx),"admission":admission,"control_at_lock":{"adjusted_now":live_lock,"tally_satoshis":control},"tally_satoshis":tally})))
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    #[ignore = "explicit isolated node replay; FIN_RECORD, FIN_BOUNDARY and FIN_RUN_ID required"]
    fn lane_replay() {
        replay().unwrap();
    }
    fn replay() -> Result<()> {
        std::env::set_current_dir(Path::new(env!("CARGO_MANIFEST_DIR")).parent().unwrap())
            .map_err(|e| e.to_string())?;
        signals();
        let record = std::env::var("FIN_RECORD").map_err(|e| e.to_string())?;
        if !record.starts_with("docs/records/") || !record.ends_with("-s6-66-fin-regtest-s3.md") {
            return Err("lane record required".into());
        }
        let boundary = std::env::var("FIN_BOUNDARY").map_err(|e| e.to_string())?;
        let run_id = std::env::var("FIN_RUN_ID").map_err(|e| e.to_string())?;
        if !run_id.starts_with("s6-66-fin-")
            || !run_id
                .bytes()
                .all(|c| c.is_ascii_alphanumeric() || c == b'-')
        {
            return Err("unsafe run id".into());
        }
        let home = PathBuf::from(std::env::var("HOME").map_err(|e| e.to_string())?);
        let version = Command::new(home.join(format!(
            "bsv/targets/sv-{}/bin/bitcoind",
            bsv_script_harness::SV_NODE_TAG
        )))
        .arg("-version")
        .output()
        .map_err(|e| e.to_string())?;
        let version = String::from_utf8_lossy(&version.stdout)
            .lines()
            .next()
            .unwrap_or("")
            .to_owned();
        if version != format!("Bitcoin SV version {VERSION}") {
            return Err("version mismatch".into());
        }
        let root = home.join("bsv/targets/spec-oracle-scenarios").join(&run_id);
        fs::create_dir(&root).map_err(|e| e.to_string())?;
        let start = Instant::now();
        let rows = row_read("finality")?;
        let mut results = vec![];
        for row in rows.iter().filter(|r| r["boundary"] == boundary) {
            let r = if let Some(reason) = unrealizable(row) {
                json!({"id":row["id"],"label":"[X]","unrealizable":reason})
            } else {
                recipe(&root, row)?.ok_or_else(|| format!("unsupported row {}", row["id"]))?
            };
            println!(
                "{}: {} [X]",
                r["id"],
                r.get("verdict").or_else(|| r.get("unrealizable")).unwrap()
            );
            results.push(r);
        }
        if results.is_empty() {
            return Err("empty boundary selection".into());
        }
        let path = PathBuf::from(record.replace(".md", ".json"));
        let mut receipt: Value = if path.exists() {
            serde_json::from_slice(&fs::read(&path).map_err(|e| e.to_string())?)
                .map_err(|e| e.to_string())?
        } else {
            json!({"source_pin":PIN,"version":version,"base_commit":"f052275","record":record,"runs":[],"families":{"finality":[]}})
        };
        let source_hash = hex::encode(bsv_rs::primitives::hash::sha256(
            &fs::read("harness/src/scenarios/finality.rs").map_err(|e| e.to_string())?,
        ));
        receipt["runs"].as_array_mut().unwrap().push(json!({"run_id":run_id,"boundary":boundary,"datadir":instance_pointer(&root),"wall_seconds":start.elapsed().as_secs_f64(),"label":"[M]","finality_rs_sha256":source_hash,"rows":results}));
        let all = receipt["families"]["finality"].as_array_mut().unwrap();
        for r in &results {
            all.retain(|old| old["id"] != r["id"]);
            all.push(r.clone());
        }
        write_json(&path, &receipt)?;
        let mut marks = BTreeMap::new();
        for r in &results {
            let mark = if let Some(reason) = r["unrealizable"].as_str() {
                format!("unrealizable: {reason} [X] {record}")
            } else if r["verdict"] == "rpc-precheck" {
                format!(
                    "rpc-precheck: {} {} ({}) [X] {record}",
                    r["rpc_precheck"]["code"],
                    text(&r["rpc_precheck"]["message"])?,
                    text(&r["rpc_precheck"]["handler"])?
                )
            } else {
                measured_token(r, &record)
            };
            marks.insert(text(&r["id"])?.to_owned(), mark);
        }
        for r in &results {
            if r["verdict"] == "diverge" {
                lane_witness(r, &record)?;
            }
        }
        mark_rows("finality", &marks)?;
        println!(
            "finality lane replay: recorded [X]; boundary {boundary}; wall [M] {:.3}s",
            start.elapsed().as_secs_f64()
        );
        Ok(())
    }
}
