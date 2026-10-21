//! #66 cut 2 (S3, lane cut2-66, [D] 2026-10-15): the road that lets the second oracle judge
//! the rows #74 could not. The instance of #41 runs its second recipe (the legacy bridge on,
//! `harness/engines/instance41/legacy.conf`); the reference's own test peer
//! (`harness/peer/peer.py`) delivers blocks and transactions through the bridge
//! (`bridge.rs`), and the RPC reads the answers. Teranode has no mock clock: the clock the
//! runner controls is the chain's own, the timestamps of the blocks it delivers (the median
//! time past), each above the parent's median and at most the host clock plus two hours
//! (the bridge's road, docs/CONFORMANCE-TERANODE-BRIDGE.md row 13). A row this road realizes
//! is measured; a row it cannot realize keeps a cited reason (`reason()`).
use super::bridge::{Bridge, Mark};
use super::*;

/// The block-family rows the road realizes, each by its recipe below.
const BLOCK_ROWS: [&str; 37] = [
    "block/valid",
    "block/pow-precedes-root",
    "block/root-mismatch",
    "block/duplicate-suffix",
    "block/duplicate-interior",
    "block/root-before-duplicate",
    "block/missing-coinbase",
    "block/coinbase-script-1",
    "block/coinbase-script-2",
    "block/coinbase-script-100",
    "block/coinbase-script-101",
    "block/extra-coinbase",
    "block/vin-empty",
    "block/vout-empty",
    "block/negative",
    "block/over-money",
    "block/p2sh-at-genesis",
    "block/regular-before-own-sigops",
    "block/sigops-off-at-genesis",
    "context/nonfinal-at-median",
    "context/final-below-median",
    "context/pre-csv-own-time",
    "header/time-at-median",
    "header/time-above-median",
    "header/time-at-two-hours",
    "header/time-over-two-hours",
    "header/difficulty-before-time",
    "header/version-bip66",
    "header/version-bip65",
    "pow/zero",
    "pow/negative",
    "pow/overflow",
    "reward/limit-plus-0",
    "reward/limit-plus-1",
    "ttor/ordered",
    "ttor/reversed",
    "ttor/distance-one-below",
];
/// The mempool rows the road realizes: through the bridge's `tx` road (row 10), its
/// orphan map (manager.go:1335-1356) and its rejected filter (manager.go:1298-1301), or
/// by a recipe the RPC already allowed.
const MEMPOOL_ROWS: [&str; 16] = [
    "missing-input-orphan-retained",
    "orphan-revalidation-accepts",
    "orphan-selected-arrival-revalidation",
    "orphan-revalidation-can-refuse",
    "reject-parent-prevents-orphan-retention",
    "reject-filter-p2p-silence",
    "absurd-fee-p2p-no-rpc-ceiling",
    "missing-input-rpc-no-handler",
    "missing-input-known-output",
    "rejects-silence-until-reset",
    "rejects-lazy-reset-tip-returns",
    "rejects-commit-refusal-not-remembered",
    "rejects-rpc-neither-reads-nor-writes",
    "rejects-budget-low-timeout-remembered",
    "rejects-budget-ample-accepted",
    "orphan-parent-only-enqueues",
];
/// The chain rows the road realizes over RPC (#74's two pending rows).
const CHAIN_CASES: [&str; 2] = ["readmit", "invalidate-reconsider"];
/// The block rows whose rule DESIGN-S6 2.2 names a local policy (TTOR, "a local policy and
/// not a consensus rule" in the reference's words, src/validation.h:350): a difference is non-judging.
const BLOCK_POLICY: [&str; 3] = ["ttor/ordered", "ttor/reversed", "ttor/distance-one-below"];
const TERANODE: &str = "Teranode v0.16.0 (4edb60a4)";
/// go-chaincfg v1.6.2, the version the Teranode tag's go.mod:15 requires: params.go:463-478.
const BIP66: u64 = 1251;
const BIP65: u64 = 1351;
const CSV: u64 = 576;
const SUBSIDY_INTERVAL: u64 = 150;

pub(super) fn handles(family: &str, row: &Value) -> bool {
    let id = row["id"].as_str().unwrap_or("");
    match family {
        "block" => BLOCK_ROWS.contains(&id),
        "mempool" => MEMPOOL_ROWS.contains(&id),
        "chain" => {
            row["case"]
                .as_str()
                .is_some_and(|c| CHAIN_CASES.contains(&c) || CHAIN_BLOCK_CASES.contains(&c))
                || super::branch::handles(row)
        }
        "utxo" => utxo_era_fits(row) && utxo_obstacle(row).is_none(),
        "finality" => {
            (matches!(row["kind"].as_str(), Some("finality" | "block" | "tip"))
                && finality_obstacle(row).is_none())
                || SHORT_MEDIAN.contains(&id)
        }
        _ => false,
    }
}

/// The reason a block-family row stays unrealizable on cut 2's road (the bridge on).
pub(super) fn block_reason(row: &Value) -> String {
    let id = row["id"].as_str().unwrap_or("");
    let kind = row["kind"].as_str().unwrap_or("");
    let s = match (kind, id) {
        (_, "block/size-at-setting" | "block/size-one-over-setting" | "block/early-count" | "block/size-before-noncoinbase" | "context/size-at-setting" | "context/size-one-over") =>
            format!("the row selects excessiveBlockSize {}; the bridge reads blocks up to its compiled 4,000,000,000-byte bound (services/legacy/config.go:29,45) and the setting policy.ExcessiveBlockSize only lowers the size it advertises (services/legacy/config.go:145-151), so the row's small size bound has no Teranode setting this road can select", row["config"]["excessiveBlockSize"]),
        (_, "block/size-disabled" | "block/merkle-disabled") => "the row switches a CheckBlock gate off (its options); Teranode's block validation has no such switch on the bridge's road (services/legacy/netsync/handle_block.go:52-348)".to_owned(),
        (_, "block/sigops-at-cap" | "block/sigops-above-cap" | "block/sigops-before-next-structure") => "the row replaces the pre-Genesis block sigop cap with 1 or 2; a pre-Genesis block on the instance's chain is below height 100 (go-chaincfg v1.6.2 params.go:475) and the reference itself has no override for the cap (src/config.cpp:825-834 at 6504a3af)".to_owned(),
        (_, "block/p2sh-before-genesis") => "the row spends a coin in a block before Genesis; the instance's Genesis is height 100 and no coin matures below height 101 (go-chaincfg v1.6.2 params.go:463,475), so no pre-Genesis block can carry a spend".to_owned(),
        (_, "block/launchable-size-plus-0" | "block/launchable-size-plus-1" | "context/launchable-size-plus-0" | "context/launchable-size-plus-1") => "the row selects excessiveBlockSize 1,000,001; the bridge's read bound is a compiled 4,000,000,000 bytes (services/legacy/config.go:29,45) and policy.ExcessiveBlockSize only lowers the advertised size (:145-151), so no setting this road can select bounds a block at 1,000,001 bytes".to_owned(),
        (_, x) if x.contains("bip34") || x.contains("height-push") || x == "context/finality-before-height" => "the row selects a BIP34 activation height; go-chaincfg v1.6.2's regtest compiles BIP0034Height 100000000 (params.go:464), as the reference's regtest does (src/chainparams.cpp:1461-1469 at 6504a3af), with no setting".to_owned(),
        (_, "header/negative-now") => "the row sets the node's adjusted time to -1; Teranode has no mock clock (setmocktime has no handler, services/rpc/Server.go:160-226,277-285), its now is the host's".to_owned(),
        (_, "header/missing-ancestry") => "the row needs a parent index with one ancestor at height 999; the bridge validates a block against a parent the blockchain service already stores with its whole ancestry (services/legacy/netsync/handle_block.go:52-348)".to_owned(),
        ("pow", _) => "the row injects a standalone hash operand or the mainnet limit; a block on the bridge's road is checked by its serialized header's hash against the regtest limit (go-chaincfg v1.6.2 params.go:461), so the operand cannot be selected".to_owned(),
        ("compact", _) => "the row asks the standalone compact-target tuple; no surface of the instance answers SetCompact for an input (services/blockchain/Difficulty.go:74 is internal)".to_owned(),
        ("nextwork", _) => "the row asks GetNextWorkRequired on a named network and parent; the instance's regtest computes its own next bits (services/blockchain/Difficulty.go:74) with no per-input surface and no other network".to_owned(),
        ("subsidy", _) => "the row's subsidy height (remapped to the regtest interval of 150, go-chaincfg v1.6.2 params.go:478) is read from a generated coinbase on the reference; cut 2 does not mine the instance to the remapped heights (up to 9,600 blocks)".to_owned(),
        ("ttor", _) => "the row needs a null tip or a reversed body above the active tip; the bridge's road connects every block it accepts onto a stored parent (services/legacy/netsync/handle_block.go:52-348) and the reference's own recipe found the cell unreachable".to_owned(),
        (_, "block/empty") => "the row delivers a block that carries no transactions; the bridge's legacy sync manager reads the body's coinbase before it checks the body is non-empty, so a zero-length body ends the node's process on an out-of-range index (services/legacy/netsync/handle_block.go:205, reached from the block handler of services/legacy/netsync/manager.go); the road withholds the frame rather than end the node, and the behavior is recorded as a Finding in docs/records/20261015-040959-s6-66-cut2-instance-exit-s3.md".to_owned(),
        _ => "the row has no recipe on cut 2's road".to_owned(),
    };
    format!("{s} [SRC] at {TERANODE}")
}

pub(super) struct Road<'a> {
    pub(super) t: &'a mut Tera,
    pub(super) b: Bridge,
    pub(super) well: &'a mut Well,
    pub(super) addr: String,
    pub(super) log: Vec<Value>,
    pub(super) started: Instant,
}

/// A version-2 frame of one OP_TRUE input and one OP_TRUE output (the reference's `frame`).
pub(super) fn frame(parent: &RawTx, vout: u32, value: u64) -> RawTx {
    let mut tx = op_true_spend(parent, vout, value, 0, u32::MAX);
    tx.version = 2;
    tx
}

pub(super) fn unix_now() -> u64 {
    std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map(|d| d.as_secs())
        .unwrap_or(0)
}

impl Road<'_> {
    /// One line per row on stderr and in the road's log, with the seconds since the road began.
    pub(super) fn progress(&mut self, row: &str, r: &Value) {
        let at = self.started.elapsed().as_secs_f64();
        eprintln!(
            "road {at:7.1}s {row}: {} {}",
            r["verdict"], r["observed"]["status"]
        );
        self.log
            .push(json!({"row":row,"verdict":r["verdict"],"seconds":at}));
        // lane cut2-66q: the row and its verdict alone, so a stopped run is placed by them.
        use std::io::Write;
        if let Ok(mut f) = fs::OpenOptions::new()
            .create(true)
            .append(true)
            .open(self.b.dir.join("progress.jsonl"))
        {
            let _ = writeln!(
                f,
                "{}",
                json!({"row":row,"verdict":r["verdict"],"seconds":at})
            );
        }
    }
    /// A fresh OP_TRUE coin of 100,000 satoshis from the run's funding transaction.
    pub(super) fn coin(&mut self) -> (RawTx, u32) {
        let k = self.well.take();
        (self.well.funding.clone(), k)
    }

    /// The tip, its bits and its median time past from the last eleven block times.
    pub(super) fn tip(&mut self) -> Result<(u64, String, u32, u32)> {
        let (h, hash) = self.t.tip()?;
        let block = self.t.call("getblockbyheight", json!([h, 1]))?;
        let bits = u32::from_str_radix(block["bits"].as_str().ok_or("tip bits")?, 16)
            .map_err(|e| e.to_string())?;
        let mut times = vec![];
        for k in 0..11u64.min(h + 1) {
            let b = self.t.call("getblockbyheight", json!([h - k, 1]))?;
            times.push(b["time"].as_u64().ok_or("block time")? as u32);
        }
        times.sort_unstable();
        Ok((h, hash, bits, times[times.len() / 2]))
    }

    /// A block time the instance accepts: above the median, the host clock where it is later.
    pub(super) fn time(&mut self) -> Result<u32> {
        let (_, _, _, mtp) = self.tip()?;
        Ok((unix_now() as u32).max(mtp + 1))
    }

    /// A `reject` naming `hash` since `mark`: the peer is asked for `wait` seconds (its journal
    /// only grows on a step, so a reject after the send's ping barrier is read here), then the
    /// journal.
    pub(super) fn poll_reject(
        &mut self,
        hash: &str,
        mark: Mark,
        wait: f64,
    ) -> Result<Option<Value>> {
        if self.b.expect("reject", hash, mark, wait)? {
            return Ok(Some(
                self.b.received("reject", hash, mark).unwrap_or(Value::Null),
            ));
        }
        Ok(self.b.received("reject", hash, mark))
    }

    /// [D] 2026-10-15, lane cut2-66q2: the block's record in the instance's store through the
    /// asset service's header route (services/asset/httpimpl/GetBlockHeader.go:115-143, the
    /// fields of block_header_response.go at the Teranode pin): `(stored, invalid)`, the
    /// invalid flag the block validation service sets when it refuses a stored block (its
    /// background validation under optimistic mining, services/blockvalidation/BlockValidation.go:2270-2375;
    /// blockvalidation_optimistic_mining defaults true, settings/blockvalidation_settings.go:56).
    pub(super) fn header_flags(&mut self, hash: &str) -> Result<(bool, Option<bool>)> {
        let a = self.t.asset(&format!("header/{hash}/json"))?;
        Ok((a["http"] == 200, a["body"]["invalid"].as_bool()))
    }

    /// Deliver a block through the bridge and read its fate: active on the tip (`ok`), a
    /// `reject` naming it (`rejected`), or, after 20 s, the later reads of lane cut2-66q2
    /// (`late`); neither within 60 s is `no-verdict` with what the store holds.
    pub(super) fn deliver(&mut self, bytes: &[u8], hash: &str) -> Result<Value> {
        let mark = self.b.mark()?;
        let sent = self.b.send_block(bytes)?;
        let start = Instant::now();
        loop {
            if let Some((true, height)) = self.t.on_active(hash)? {
                return Ok(json!({"status":"ok","height":height,"send":sent["ok"]}));
            }
            if let Some(r) = self.poll_reject(hash, mark, 0.5)? {
                return Ok(
                    json!({"status":"rejected","code":r["code"],"reason":r["reason"],"wire":"reject","send":sent["ok"],
                    "ended":self.b.ended_since(mark),"seconds":start.elapsed().as_secs_f64()}),
                );
            }
            if start.elapsed() > Duration::from_secs(20) {
                return self.late(hash, mark, sent, start);
            }
            thread::sleep(Duration::from_millis(250));
        }
    }

    /// [D] 2026-10-15, lane cut2-66q2: the reads after the 20-second window, up to 60 s from the
    /// send. A block refused without a reject still leaves a mark: the store's invalid flag
    /// (`header_flags`), or, for a body the bridge reads as corrupt (a merkle mismatch or a
    /// duplicate, not bound to the header), a `getdata` for the same hash: the bridge drops such
    /// a body without a reject and re-requests it ([SRC] services/legacy/netsync/manager.go:2008-2075
    /// at the Teranode pin; the peer serves the same bytes again, harness/peer/peer.py
    /// `on_getdata`). The reference's mutated block is likewise refused without marking the
    /// hash failed (the row's `corruptionPossible`). Each mark is the instance's refusal of the
    /// block; none of them within 60 s is `no-verdict`, with the store's record.
    fn late(&mut self, hash: &str, mark: Mark, sent: Value, start: Instant) -> Result<Value> {
        loop {
            if let Some((true, height)) = self.t.on_active(hash)? {
                return Ok(
                    json!({"status":"ok","height":height,"send":sent["ok"],"late":true,"seconds":start.elapsed().as_secs_f64()}),
                );
            }
            if let Some(r) = self.poll_reject(hash, mark, 1.0)? {
                return Ok(
                    json!({"status":"rejected","code":r["code"],"reason":r["reason"],"wire":"reject","send":sent["ok"],
                    "ended":self.b.ended_since(mark),"late":true,"seconds":start.elapsed().as_secs_f64()}),
                );
            }
            let (stored, invalid) = self.header_flags(hash)?;
            if invalid == Some(true) {
                return Ok(
                    json!({"status":"rejected","wire":"invalid","stored":stored,"invalid":true,"send":sent["ok"],"late":true,"seconds":start.elapsed().as_secs_f64()}),
                );
            }
            if self.b.received("getdata", hash, mark).is_some() {
                return Ok(
                    json!({"status":"rejected","wire":"getdata","stored":stored,"send":sent["ok"],"late":true,"seconds":start.elapsed().as_secs_f64()}),
                );
            }
            if start.elapsed() > Duration::from_secs(60) {
                // The bridge sends a block reject only while the node's state machine is
                // RUNNING (services/legacy/netsync/manager.go:1787,2098-2101,4097-4102 at the Teranode
                // pin); its state is read from the asset service's FSM route
                // (services/asset/httpimpl/http.go:486,492; fsm_handler.go:46-51).
                let fsm = self.t.asset("fsm/state")?;
                return Ok(
                    json!({"status":"no-verdict","send":sent["ok"],"ended":self.b.ended_since(mark),"stored":stored,"invalid":invalid,
                    "fsm_state_value":fsm["body"]["state_value"],"fsm_running":fsm["body"]["state"] == "RUNNING",
                    "connection_ended":!self.b.ended_since(mark).is_empty(),
                    "known":self.t.receipt("getblock", json!([hash, 1]))?,"seconds":start.elapsed().as_secs_f64()}),
                );
            }
            thread::sleep(Duration::from_millis(500));
        }
    }

    /// [D] 2026-10-15, lane cut2-66q2: the durability read of an accepted block the reference
    /// refuses. The bridge's blocks are added before their full validation (optimistic mining,
    /// settings/blockvalidation_settings.go:56 at the Teranode pin, default true), which can
    /// still mark the block invalid and take it off the chain
    /// (services/blockvalidation/BlockValidation.go:2270-2375). Read for up to 60 s, nothing else
    /// delivered or mined meanwhile: `withdrawn` when the invalid flag is set or the block
    /// leaves the active chain, `held` otherwise.
    pub(super) fn durable(&mut self, hash: &str) -> Result<Value> {
        let start = Instant::now();
        loop {
            let (stored, invalid) = self.header_flags(hash)?;
            let active = matches!(self.t.on_active(hash)?, Some((true, _)));
            if invalid == Some(true) || !active {
                return Ok(
                    json!({"durability":"withdrawn","invalid":invalid,"active":active,"stored":stored,"seconds":start.elapsed().as_secs_f64()}),
                );
            }
            if start.elapsed() > Duration::from_secs(60) {
                return Ok(
                    json!({"durability":"held","invalid":invalid,"active":active,"stored":stored,"seconds":start.elapsed().as_secs_f64()}),
                );
            }
            thread::sleep(Duration::from_secs(1));
        }
    }

    /// Assemble `txs` on the tip at `time` with the tip's bits, ground; deliver it.
    pub(super) fn block(&mut self, txs: &[RawTx], time: u32) -> Result<(Value, Value)> {
        let (_, hash, bits, _) = self.tip()?;
        let (h, bytes) = block_codec::assemble(4, txid_from_display_hex(&hash)?, time, bits, txs);
        let id = txid_display_hex(&h.hash());
        let observed = self.deliver(&bytes, &id)?;
        Ok((
            observed,
            json!({"block":hex::encode(&bytes),"hash":id,"parent":hash}),
        ))
    }

    /// Deliver a header-built block (the caller ground it or chose not to).
    pub(super) fn header_block(
        &mut self,
        h: &block_codec::Header,
        txs: &[RawTx],
    ) -> Result<(Value, Value)> {
        let bytes = block_codec::serialize_block(h, txs);
        let id = txid_display_hex(&h.hash());
        let observed = self.deliver(&bytes, &id)?;
        Ok((
            observed,
            json!({"block":hex::encode(&bytes),"hash":id,"header":hex::encode(h.encode())}),
        ))
    }

    /// Mine `n` blocks to the harness key by generatetoaddress (100 at a time).
    pub(super) fn mine_to(&mut self, height: u64) -> Result<()> {
        loop {
            let (h, _) = self.t.tip()?;
            if h >= height {
                return Ok(());
            }
            self.t.call(
                "generatetoaddress",
                json!([(height - h).min(100), self.addr]),
            )?;
        }
    }

    pub(super) fn pool_has(&mut self, tx: &RawTx) -> Result<bool> {
        Ok(self.t.pool()?.iter().any(|x| *x == id(tx)))
    }

    /// Wait until block assembly lists `tx` (10 s), as the RPC rows do.
    pub(super) fn settle(&mut self, tx: &RawTx) -> Result<bool> {
        self.t.settle_in_pool(&id(tx))
    }
}

/// The verdict of a block-family row: its status against the row's (the reason recorded,
/// never compared: every block refusal on the bridge is `0x10 block rejected`, manager.go:2100).
fn block_verdict(
    road: &mut Road,
    row: &Value,
    observed: Value,
    recipe: &str,
    fixtures: Value,
    offset: usize,
    note: &str,
) -> Value {
    let id = row["id"].as_str().unwrap_or("");
    let expected = &row["expected"];
    let refused = if row["kind"] == "pow" {
        expected.as_bool() == Some(false)
    } else {
        expected["status"] == "rejected"
    };
    // lane cut2-66q2: an accepted block the reference refuses is read again for durability.
    let mut observed = observed;
    let hash = fixture_hash(&fixtures);
    if refused && observed["status"] == "ok" {
        if let Some(h) = &hash {
            match road.durable(h) {
                Ok(d) => {
                    if d["durability"] == "withdrawn" {
                        observed["status"] = json!("rejected");
                        observed["wire"] = json!("withdrawn");
                    }
                    observed["durability"] = d;
                }
                Err(e) => observed["durability"] = json!({"durability":"unread","error":e}),
            }
        }
    }
    let (want, got) = if row["kind"] == "pow" {
        (
            json!(expected.as_bool().unwrap_or(true)),
            json!(observed["status"] == "ok"),
        )
    } else {
        (expected["status"].clone(), observed["status"].clone())
    };
    let verdict = if observed["status"] == "no-verdict" {
        "no-verdict"
    } else if want == got {
        "agree"
    } else if BLOCK_POLICY.contains(&id) {
        "non-judging"
    } else {
        "diverge"
    };
    let mut r = json!({"id":row["id"],"label":"[X]","verdict":verdict,"expected":{"value":want,"reason":expected["reason"]},"expected_label":"[D]",
        "observed":observed,"observed_value":got,"road":"block","recipe":recipe,"fixtures":fixtures,"reference_token":row["node"],
        "comparison_scope":"the block's verdict (accepted onto the tip, or refused); the reason is recorded and never compared: the bridge answers every refusal with reject 0x10 'block rejected' (services/legacy/netsync/manager.go:2098-2101; docs/CONFORMANCE-TERANODE-BRIDGE.md B10)",
        "rpc":road.t.calls[offset..].to_vec()});
    if !note.is_empty() {
        r["note"] = json!(note);
    }
    if verdict == "non-judging" {
        r["qualifier"] = json!("TTOR is a local policy (DESIGN-S6 2.2; src/validation.h:350 at 6504a3af): the second oracle's answer is never the rule");
    }
    // lane cut2-66q2: an accepted block is read again at the road's end (`sweep`).
    if let (Some(h), true) = (hash, r["observed"]["status"] == "ok") {
        r["sweep_hash"] = json!(h);
    }
    r
}

/// The hash of the block a row delivered, from its fixtures (`hash`, or `block.hash`).
fn fixture_hash(fixtures: &Value) -> Option<String> {
    fixtures["hash"]
        .as_str()
        .or_else(|| fixtures["block"]["hash"].as_str())
        .map(str::to_owned)
}

/// [D] 2026-10-15, lane cut2-66q2: the road's last read. Every block a row read accepted is
/// read again from the store's invalid flag and the active chain (`Road::header_flags`); a block
/// the instance marked invalid after the row's read is refused, and the row's verdict is taken
/// again on that status. A block off the active chain but not invalid stays accepted (the chain
/// rows that follow build and rearrange branches of their own).
fn sweep(road: &mut Road, by: &mut BTreeMap<String, Vec<Value>>) -> Result<()> {
    for rows in by.values_mut() {
        for r in rows.iter_mut() {
            let Some(h) = r["sweep_hash"].as_str().map(str::to_owned) else {
                continue;
            };
            let (stored, invalid) = road.header_flags(&h)?;
            let active = matches!(road.t.on_active(&h)?, Some((true, _)));
            r["observed"]["sweep"] = json!({"stored":stored,"invalid":invalid,"active":active});
            if invalid == Some(true) {
                r["observed"]["status"] = json!("rejected");
                r["observed"]["wire"] = json!("invalid-at-sweep");
                let got = if r["expected"]["value"].is_boolean() {
                    json!(false)
                } else {
                    json!("rejected")
                };
                r["observed_value"] = got.clone();
                let id = r["id"].as_str().unwrap_or("");
                r["verdict"] = json!(if r["expected"]["value"] == got {
                    "agree"
                } else if BLOCK_POLICY.contains(&id) {
                    "non-judging"
                } else {
                    "diverge"
                });
            }
        }
    }
    Ok(())
}

const ERA_NOTE: &str = "the reference's row sits at height 1000 under its recipe's genesisactivationheight 10000 (pre-Genesis); the instance's block is past its Genesis at 100 (go-chaincfg v1.6.2 params.go:475): the gate is judged at the instance's era";

fn block_rows(road: &mut Road, rows: &[Value]) -> Result<Vec<Value>> {
    let mut out = vec![];
    let ordered: Vec<&Value> = rows
        .iter()
        .filter(|r| BLOCK_ROWS.contains(&r["id"].as_str().unwrap_or("")))
        .collect();
    // The rows that need a taller chain run last, in height order: the median cells past the
    // CSV height (lane cut2-66q2), the TTOR distances, the BIP66 and BIP65 versions.
    let late = |id: &str| {
        POST_CSV.contains(&id)
            || id.starts_with("ttor/")
            || id.ends_with("bip66")
            || id.ends_with("bip65")
    };
    let mut rows: Vec<&Value> = ordered
        .iter()
        .copied()
        .filter(|r| !late(r["id"].as_str().unwrap_or("")))
        .collect();
    rows.extend(
        ordered
            .iter()
            .copied()
            .filter(|r| POST_CSV.contains(&r["id"].as_str().unwrap_or(""))),
    );
    rows.extend(
        ordered
            .iter()
            .copied()
            .filter(|r| r["id"].as_str().unwrap_or("").starts_with("ttor/")),
    );
    rows.extend(
        ordered
            .iter()
            .copied()
            .filter(|r| r["id"].as_str().unwrap_or("").ends_with("bip66")),
    );
    rows.extend(
        ordered
            .iter()
            .copied()
            .filter(|r| r["id"].as_str().unwrap_or("").ends_with("bip65")),
    );
    for row in rows {
        let id = text(&row["id"])?.to_owned();
        let offset = road.t.calls.len();
        let r = match row["kind"].as_str().unwrap_or("") {
            "block" => structural(road, row, &id, offset)?,
            "context-block" => context_block(road, row, &id, offset)?,
            "context-header" => context_header(road, row, &id, offset)?,
            "pow" => pow_row(road, row, &id, offset)?,
            "coinbase-amount" => reward_row(road, row, &id, offset)?,
            "ttor" => ttor_row(road, row, &id, offset)?,
            k => return Err(format!("{id}: no road recipe for kind {k}")),
        };
        road.progress(&id, &r);
        out.push(r);
    }
    Ok(out)
}

fn structural(road: &mut Road, row: &Value, id: &str, offset: usize) -> Result<Value> {
    let (height, _, bits, _) = road.tip()?;
    let next = height as u32 + 1;
    let (fund, k) = road.coin();
    let mut base = cb(next, id);
    let mut tx = frame(&fund, k, 1000);
    let high_hash = row["expected"]["reason"] == "high-hash";
    let txs = match id {
        "block/valid" | "block/root-mismatch" | "block/pow-precedes-root" => vec![base, tx],
        "block/duplicate-suffix" | "block/root-before-duplicate" => {
            let child = frame(&tx, 0, 900);
            vec![base, tx, child.clone(), child]
        }
        "block/duplicate-interior" => {
            let child = frame(&tx, 0, 900);
            vec![base.clone(), base, tx, child]
        }
        "block/missing-coinbase" => vec![tx],
        "block/extra-coinbase" => vec![base, cb(next, "extra")],
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
        "block/p2sh-at-genesis" => {
            tx.outputs[0].script = [vec![0xa9, 0x14], vec![0x22; 20], vec![0x87]].concat();
            vec![base, tx]
        }
        "block/regular-before-own-sigops" => {
            tx.outputs[0].script = vec![0xac; 20001];
            tx.inputs.clear();
            vec![base, tx]
        }
        "block/sigops-off-at-genesis" => {
            base.outputs[0].script = vec![0xac; 20001];
            vec![base]
        }
        x if x.starts_with("block/coinbase-script-") => {
            let len: usize = x
                .rsplit('-')
                .next()
                .ok_or("script length")?
                .parse()
                .map_err(|_| "script length")?;
            base.inputs[0].script = vec![0x51; len];
            vec![base]
        }
        _ => return Err(format!("{id}: no structural recipe")),
    };
    let time = road.time()?;
    let (observed, fixtures) =
        if high_hash || matches!(id, "block/root-mismatch" | "block/root-before-duplicate") {
            let (_, parent, _, _) = road.tip()?;
            let ids: Vec<[u8; 32]> = txs.iter().map(RawTx::txid_internal).collect();
            let mut h = block_codec::Header {
                version: 4,
                prev: txid_from_display_hex(&parent)?,
                merkle: if high_hash {
                    block_codec::merkle_root(&ids)
                } else {
                    [0; 32]
                },
                time,
                bits,
                nonce: 0,
            };
            if high_hash {
                while block_codec::meets_target(&h.hash(), &block_codec::target_of(h.bits)) {
                    h.nonce = h.nonce.wrapping_add(1);
                }
            } else {
                block_codec::grind(&mut h);
            }
            road.header_block(&h, &txs)?
        } else {
            road.block(&txs, time)?
        };
    let note = if matches!(id, "block/p2sh-at-genesis" | "block/sigops-off-at-genesis") {
        format!("the reference's row sits at its Genesis height (10000 under its recipe); the instance's block is at height {next}, past its Genesis at 100 (go-chaincfg v1.6.2 params.go:475), so the post-Genesis class is judged and the equality edge itself is not reproduced (no coin matures at height 100, params.go:463)")
    } else {
        ERA_NOTE.to_owned()
    };
    Ok(block_verdict(road, row, observed,
        "Build on the instance's tip with a fresh mined OP_TRUE coin (the run's funding transaction) in place of the reference's signed P2PKH coinbase spend; reproduce the named body mutation, recompute the merkle root except the root-mismatch rows, grind regtest proof of work (the high-hash row ground to fail it); deliver the block from the loopback peer through the bridge (block, row 13); read getblock's confirmations and the peer's reject",
        fixtures, offset, &note))
}

/// [D] 2026-10-15, lane cut2-66q2: the context cells whose cutoff is the parent's median time
/// past. Both nodes compare a block's lock times with the median only from the CSV height on
/// (the reference: src/validation.cpp:6046-6049,6067-6069 at 6504a3af, measured at its height
/// 1000, block.rs; Teranode: services/legacy/netsync/handle_block.go:986-993 at the Teranode pin,
/// the block's own time below CSVHeight, 576 on regtest, go-chaincfg v1.6.2 params.go:467).
/// Lane cut2-66q built them at height 123, below 576, where both cut off at the block's own
/// time: the cell's equality was the block time's, not the median's.
const POST_CSV: [&str; 2] = ["context/nonfinal-at-median", "context/final-below-median"];

fn context_block(road: &mut Road, row: &Value, id: &str, offset: usize) -> Result<Value> {
    if POST_CSV.contains(&id) {
        road.mine_to(CSV - 1)?;
    }
    let (height, _, _, mtp) = road.tip()?;
    if id == "context/pre-csv-own-time" && height + 1 >= CSV {
        return Err(format!(
            "{id}: the tip {height} is past the CSV height {CSV}"
        ));
    }
    let next = height as u32 + 1;
    let time = road.time()?;
    let (fund, k) = road.coin();
    let mut tx = op_true_spend(&fund, k, 99_000, 0, u32::MAX - 1);
    tx.lock_time = match id {
        "context/nonfinal-at-median" => mtp,
        "context/pre-csv-own-time" => time - 1,
        _ => mtp - 1,
    };
    let (observed, fixtures) = road.block(&[cb(next, id), tx.clone()], time)?;
    Ok(block_verdict(road, row, observed,
        "On the instance's tip, a block at the later of the host clock and the median plus one carrying a spend of a fresh OP_TRUE coin, sequence 0xfffffffe, lock time the parent's median (non-final at equality) or one below it, at a height past the CSV height 576 (go-chaincfg v1.6.2 params.go:467; the chain mined to 575 by generatetoaddress, lane cut2-66q2), or one below the block's own time below that height (the pre-CSV own-time cutoff); delivered through the bridge",
        json!({"block":fixtures,"tx":material(&tx),"median_time_past":mtp,"block_time":time,"height":next}), offset,
        "the instance's median time past and block time are its own chain's (the host clock), the reference's were its mock clock's; the equality and the one-below cells are rebuilt on the instance's median"))
}

fn context_header(road: &mut Road, row: &Value, id: &str, offset: usize) -> Result<Value> {
    let floor = if id.ends_with("bip66") {
        Some(BIP66)
    } else if id.ends_with("bip65") {
        Some(BIP65)
    } else {
        None
    };
    if let Some(f) = floor {
        road.mine_to(f - 1)?;
    }
    let (height, parent, bits, mtp) = road.tip()?;
    let next = height as u32 + 1;
    let txs = vec![cb(next, id)];
    // Wait for a fresh second so the node's now matches the one read here.
    let start = unix_now();
    while unix_now() == start {
        thread::sleep(Duration::from_millis(20));
    }
    let now = unix_now() as u32;
    let mut h = block_codec::Header {
        version: if id.ends_with("bip66") {
            2
        } else if id.ends_with("bip65") {
            3
        } else {
            4
        },
        prev: txid_from_display_hex(&parent)?,
        merkle: block_codec::merkle_root(&[txs[0].txid_internal()]),
        time: match id {
            "header/time-at-median" | "header/difficulty-before-time" => mtp,
            "header/time-above-median" => (mtp + 1).max(now),
            "header/time-at-two-hours" => now + 7200,
            "header/time-over-two-hours" => now + 7201,
            _ => now.max(mtp + 1),
        },
        bits: if id == "header/difficulty-before-time" {
            0x207ffffe
        } else {
            bits
        },
        nonce: 0,
    };
    block_codec::grind(&mut h);
    let (observed, fixtures) = road.header_block(&h, &txs)?;
    Ok(block_verdict(road, row, observed,
        "On the instance's tip, a coinbase-only block whose header carries the row's boundary: the time at the parent's median (refused) or above it, the host clock plus 7200 s or 7201 s read at the start of a second (the bridge's now is the host's; Teranode has no mock clock), the wrong bits 0x207ffffe with the old time, or version 2 or 3 at the compiled BIP66/BIP65 heights 1251/1351 (go-chaincfg v1.6.2 params.go:465-466, the chain mined to the height below by generatetoaddress); valid regtest proof of work on every header; delivered through the bridge",
        json!({"block":fixtures,"tip":{"height":height,"hash":parent,"median_time_past":mtp},"now":now}), offset,
        "the two-hour cells read the host clock at the start of a second; the node reads its own clock when it validates, so a validation in a later second moves the edge by that much"))
}

fn pow_row(road: &mut Road, row: &Value, id: &str, offset: usize) -> Result<Value> {
    let (height, parent, _, _) = road.tip()?;
    let txs = vec![cb(height as u32 + 1, id)];
    let time = road.time()?;
    let h = block_codec::Header {
        version: 4,
        prev: txid_from_display_hex(&parent)?,
        merkle: txs[0].txid_internal(),
        time,
        bits: row["bits"].as_u64().ok_or("pow bits")? as u32,
        nonce: 0,
    };
    let (observed, fixtures) = road.header_block(&h, &txs)?;
    Ok(block_verdict(road, row, observed,
        "On the instance's tip, a coinbase-only block carrying the row's exact invalid compact bits, not ground; the proof-of-work verdict is false when the block is refused and true when it is accepted",
        fixtures, offset, ""))
}

fn reward_row(road: &mut Road, row: &Value, id: &str, offset: usize) -> Result<Value> {
    let (height, _, _, _) = road.tip()?;
    let next = height + 1;
    // go-chaincfg v1.6.2 params.go:478: the subsidy halves every 150 regtest blocks.
    let subsidy = 5_000_000_000u64 >> (next / SUBSIDY_INTERVAL).min(63);
    let (fund, k) = road.coin();
    let tx = op_true_spend(&fund, k, 100_000 - 7, 0, u32::MAX);
    let mut base = cb(next as u32, id);
    base.outputs[0].satoshis = subsidy + 7 + u64::from(id.ends_with("-1"));
    let time = road.time()?;
    let (observed, fixtures) = road.block(&[base, tx.clone()], time)?;
    Ok(block_verdict(road, row, observed,
        "On the instance's tip, a block whose one spend pays exactly seven satoshis of fee and whose coinbase claims the regtest subsidy at its height (5,000,000,000 halved every 150 blocks, go-chaincfg v1.6.2 params.go:478) plus 7 or 8; delivered through the bridge",
        json!({"block":fixtures,"tx":material(&tx),"subsidy":subsidy,"height":next}), offset,
        "the reference's row claims at height 0 its recipe remapped to height 101; the instance's height is its tip's successor"))
}

fn ttor_row(road: &mut Road, row: &Value, id: &str, offset: usize) -> Result<Value> {
    // The reference's distances: a side body at 200 or 201 beside an active tip at 300.
    let (height, _, bits, _) = road.tip()?;
    let tip = height.max(300);
    road.mine_to(tip)?;
    let at = if id == "ttor/distance-one-below" {
        tip - 99
    } else {
        tip - 100
    };
    let parent = road.t.call("getblockbyheight", json!([at - 1, 1]))?;
    let parent_hash = text(&parent["hash"])?.to_owned();
    let parent_time = parent["time"].as_u64().ok_or("parent time")? as u32;
    let (fund, k) = road.coin();
    let tx = frame(&fund, k, 1000);
    let child = frame(&tx, 0, 900);
    let txs = if id == "ttor/ordered" {
        vec![cb(at as u32, id), tx, child]
    } else {
        vec![cb(at as u32, id), child, tx]
    };
    let (h, bytes) = block_codec::assemble(
        4,
        txid_from_display_hex(&parent_hash)?,
        parent_time + 1,
        bits,
        &txs,
    );
    let hash = txid_display_hex(&h.hash());
    let mark = road.b.mark()?;
    let sent = road.b.send_block(&bytes)?;
    // A side body is never active: its fate is getblock's record (stored, confirmations -1) or a reject.
    let start = Instant::now();
    let observed = loop {
        if let Some(r) = road.poll_reject(&hash, mark, 0.5)? {
            break json!({"status":"rejected","code":r["code"],"reason":r["reason"],"wire":"reject"});
        }
        let known = road.t.receipt("getblock", json!([hash, 1]))?;
        if known.get("result").is_some() && start.elapsed() > Duration::from_secs(3) {
            break json!({"status":"ok","stored":known["result"]["confirmations"],"note":"stored beside the active chain, no reject"});
        }
        if start.elapsed() > Duration::from_secs(20) {
            break json!({"status":"no-verdict","known":known,"send":sent["ok"],"ended":road.b.ended_since(mark)});
        }
        thread::sleep(Duration::from_millis(250));
    };
    let tips = road.t.receipt("getchaintips", json!([]))?;
    Ok(block_verdict(road, row, observed,
        "Mine the instance to 300 by generatetoaddress; a side body at 200 (distance 100) or 201 (distance 99) on the active block below it, its parent and child spends in order or reversed; delivered through the bridge; stored with no reject is ok, a reject is a refusal",
        json!({"block":hex::encode(&bytes),"hash":hash,"height":at,"active_tip":tip,"chaintips":tips}), offset,
        "Teranode's chain tips answer is cached up to 300 s (services/rpc/handlers.go:2963-2964), so the side body's acceptance is read from getblock and the reject, not from getchaintips"))
}

// ---- The mempool rows on the bridge's tx road ----

/// One frame's class on the wire: a reject (its code), accepted (block assembly lists it), or silent.
fn tx_answer(road: &mut Road, tx: &RawTx, mark: Mark, wait: f64) -> Result<Value> {
    let rejected = road.b.expect("reject", &id(tx), mark, wait)?;
    if rejected {
        let r = road
            .b
            .received("reject", &id(tx), mark)
            .unwrap_or(Value::Null);
        return Ok(
            json!({"class":format!("rejected {}", r["code"]),"code":r["code"],"reason":r["reason"]}),
        );
    }
    if road.settle(tx)? {
        return Ok(json!({"class":"accepted"}));
    }
    Ok(json!({"class":"silent"}))
}

/// The row's comparison: a field the reference observed that Teranode has no surface for is
/// listed and left out; an accept/refuse class that differs is a divergence; any other
/// difference is the orphan road's or the reject filter's, a structure of the node
/// (DESIGN-S6 2.1 row 6, kind P), non-judging.
#[allow(
    clippy::too_many_arguments,
    reason = "one comparison's nine parts, each named at the call site"
)]
fn mempool_verdict(
    road: &mut Road,
    row: &Value,
    reference: Value,
    observed: Value,
    judged: &[&str],
    unobserved: Value,
    recipe: &str,
    fixtures: Value,
    offset: usize,
) -> Value {
    let mut differs = vec![];
    let mut judged_differs = vec![];
    if let (Some(r), Some(o)) = (reference.as_object(), observed.as_object()) {
        for (k, v) in r {
            if let Some(w) = o.get(k) {
                if v != w {
                    if judged.contains(&k.as_str()) {
                        judged_differs.push(k.clone());
                    } else {
                        differs.push(k.clone());
                    }
                }
            }
        }
    }
    let verdict = if !judged_differs.is_empty() {
        "diverge"
    } else if differs.is_empty() {
        "agree"
    } else {
        "non-judging"
    };
    let mut r = json!({"id":row["id"],"label":"[X]","verdict":verdict,"expected":reference,"expected_label":"the reference's observation (the row's measured token, which agrees with the row's expectation [D])",
        "observed":observed,"unobserved":unobserved,"judged_fields":judged,"road":"tx","recipe":recipe,"fixtures":fixtures,"reference_token":row["node"],
        "comparison_scope":"the fields both nodes expose: a transaction's accept or refuse class is judged; the parent request, the reject message's presence and the reject filter are the node's machine (DESIGN-S6 2.1 row 6 and the paragraph after the table, kind P); the reason is never compared (the bridge answers every refusal 0x10 'rejected', services/legacy/netsync/manager.go:1368)",
        "rpc":road.t.calls[offset..].to_vec()});
    if verdict == "non-judging" {
        r["qualifier"] = json!(format!("the fields {} differ: the orphan road and the reject filter are a structure of the node (DESIGN-S6 2.1 row 6, kind P); the second oracle's machine is never the rule", differs.join(", ")));
    }
    if verdict == "diverge" {
        r["diverging_fields"] = json!(judged_differs);
    }
    r
}

/// The reference's observation for the row, parsed from its measured token.
fn reference_of(row: &Value) -> Value {
    let node = row["node"].as_str().unwrap_or("");
    let body = node.split_once(": ").map(|(_, b)| b).unwrap_or("");
    let mut d = serde_json::Deserializer::from_str(body).into_iter::<Value>();
    d.next().and_then(|v| v.ok()).unwrap_or(Value::Null)
}

fn labels(road: &mut Road, named: &[(&str, &RawTx)]) -> Result<Vec<String>> {
    let pool = road.t.pool()?;
    let mut out: Vec<String> = named
        .iter()
        .filter(|(_, t)| pool.contains(&id(t)))
        .map(|(l, _)| (*l).to_owned())
        .collect();
    out.sort();
    Ok(out)
}

fn mempool_rows(road: &mut Road, rows: &[Value]) -> Result<Vec<Value>> {
    let mut out = vec![];
    for row in rows
        .iter()
        .filter(|r| MEMPOOL_ROWS.contains(&r["id"].as_str().unwrap_or("")))
    {
        let id_ = text(&row["id"])?.to_owned();
        let offset = road.t.calls.len();
        let r = match id_.as_str() {
            "missing-input-orphan-retained"
            | "orphan-revalidation-accepts"
            | "orphan-selected-arrival-revalidation"
            | "orphan-revalidation-can-refuse" => retain_row(road, row, offset)?,
            "reject-parent-prevents-orphan-retention" | "reject-filter-p2p-silence" => {
                reject_row(road, row, offset)?
            }
            "absurd-fee-p2p-no-rpc-ceiling" => absurd_row(road, row, offset)?,
            "missing-input-rpc-no-handler" => rpc_missing_row(road, row, offset)?,
            "missing-input-known-output" => known_output_row(road, row, offset)?,
            "orphan-parent-only-enqueues" => parent_only_row(road, row, offset)?,
            _ => trace_row(road, row, offset)?,
        };
        road.progress(&id_, &r);
        out.push(r);
    }
    Ok(out)
}

/// The reference's `retain` and its tail: the child sent with its parent withheld, the parent
/// requested or not, the parent released, the pool read.
fn retain_row(road: &mut Road, row: &Value, offset: usize) -> Result<Value> {
    let refuse = row["id"] == "orphan-revalidation-can-refuse";
    let (fund, k) = road.coin();
    let p = frame(&fund, k, 900);
    let c = frame(&p, 0, if refuse { 901 } else { 800 });
    let rpc_child = road
        .t
        .receipt("sendrawtransaction", json!([hex::encode(c.encode())]))?;
    let mark = road.b.mark()?;
    road.b.send_tx(&c)?;
    let requested = road.b.expect("getdata", &id(&p), mark, 10.0)?;
    let child_after_send = road.pool_has(&c)?;
    let child_reject_before = road.b.received("reject", &id(&c), mark);
    let mark2 = road.b.mark()?;
    road.b.send_tx(&p)?;
    let parent_in = road.settle(&p)?;
    let child_in = if refuse { false } else { road.settle(&c)? };
    let child_reject = if refuse {
        road.b.expect("reject", &id(&c), mark2, 5.0)?;
        road.b
            .received("reject", &id(&c), mark2)
            .map(|r| json!({"code":r["code"],"reason":r["reason"]}))
    } else {
        road.b
            .received("reject", &id(&c), mark2)
            .map(|r| json!({"code":r["code"],"reason":r["reason"]}))
    };
    let accepted = labels(road, &[("C", &c), ("P", &p)])?;
    // The child was sent once and never again: in the pool after its parent, it was retained.
    let retained = child_reject_before.is_none() && !child_after_send && (child_in || refuse);
    let observed = json!({"accepted":accepted,"child_reject":child_reject,"missing_parent_request":requested,
        "orphan_retained":if child_in { json!(1) } else { json!("unobservable") },"orphans_final":"unobservable"});
    let unobserved = json!({"orphans_final":"the bridge's orphan map has no RPC, asset or gRPC surface (services/legacy/netsync/manager.go:487; docs/CONFORMANCE-TERANODE-BRIDGE.md B8)",
        "orphan_retained":"read as 1 only when the child, sent once and refused nowhere, entered block assembly after its parent (manager.go:1385-1390, processOrphanTransactions)"});
    Ok(mempool_verdict(road, row, reference_of(row), observed, &["accepted"], unobserved,
        "Fund F (a fresh mined OP_TRUE coin); P = frame(F, 900) and C = frame(P, 800, or 901 for the refusal row); sendrawtransaction(C) (the RPC keeps no orphan); send C from the loopback peer with P withheld (the peer never offers it unasked); expect a getdata for P for 10 s; send P; read block assembly for P and C (and a reject for C for 5 s on the refusal row)",
        json!({"P":material(&p),"C":material(&c),"rpc_child":rpc_child,"child_in_pool_before_parent":child_after_send,"parent_accepted":parent_in,"retained_inferred":retained}), offset))
}

/// The reference's `reject_row`: an invalid target requested, refused, then silently filtered
/// until the tip moves.
fn reject_row(road: &mut Road, row: &Value, offset: usize) -> Result<Value> {
    let filter = row["id"] == "reject-filter-p2p-silence";
    let (fund, k) = road.coin();
    let mut fixtures = json!({});
    let target = if filter {
        // A conflict: K accepted over RPC, then P (the same coin) from the peer.
        let kx = frame(&fund, k, 850);
        let rk = road
            .t
            .receipt("sendrawtransaction", json!([hex::encode(kx.encode())]))?;
        road.settle(&kx)?;
        fixtures["K"] = material(&kx);
        fixtures["rpc_K"] = rk;
        frame(&fund, k, 900)
    } else {
        frame(&fund, k, 1001)
    };
    // Withheld so the peer answers no getdata on its own; it is then sent explicitly.
    road.b.step(json!({"op":"withhold","hash":id(&target)}))?;
    let mark = road.b.mark()?;
    road.b.send_inv(&target)?;
    let requested_before = road.b.expect("getdata", &id(&target), mark, 10.0)?;
    let mark = road.b.mark()?;
    road.b.send_tx(&target)?;
    let wire_rejected = road.b.expect("reject", &id(&target), mark, 5.0)?;
    let mark = road.b.mark()?;
    road.b.send_inv(&target)?;
    let silence = road.b.expect("none", &id(&target), mark, 2.0)?;
    let mut observed =
        json!({"requested_before_rejection":requested_before,"cached_silence":silence});
    let mut unobserved = json!({});
    if filter {
        unobserved["silence_after_conflict_expiry"] = json!("the reference expires K on its mock clock (mempoolexpiry=1 then setmocktime +3601 s); Teranode has no mock clock (setmocktime has no handler, services/rpc/Server.go:160-226,277-285) and no expiry of block assembly's transactions of that kind (DESIGN-S6 5.2)");
    } else {
        observed["wire_rejected_parent"] = json!(wire_rejected);
        let child = frame(&target, 0, 800);
        road.b.send_tx(&child)?;
        fixtures["child"] = material(&child);
        observed["orphans"] = json!("unobservable");
        unobserved["orphans"] = json!("the bridge's orphan map has no surface (services/legacy/netsync/manager.go:487); the bridge parks a child of a rejected parent like any orphan: handleTxMsg reads no reject filter for parents (manager.go:1271-1356)");
    }
    // The tip moves: one block by generatetoaddress (the bridge clears its filter at each block, manager.go:2181).
    let (before, _) = road.t.tip()?;
    road.t.call("generatetoaddress", json!([1, road.addr]))?;
    let (after, _) = road.t.tip()?;
    thread::sleep(Duration::from_secs(2));
    let mark = road.b.mark()?;
    road.b.send_inv(&target)?;
    let requested_after = road.b.expect("getdata", &id(&target), mark, 10.0)?;
    observed["tip_changed"] = json!(after > before);
    observed["requested_after_reset"] = json!(requested_after);
    fixtures["target"] = material(&target);
    Ok(mempool_verdict(road, row, reference_of(row), observed, &[], unobserved,
        "The target (P paying 1001 from 1000, or for the filter row P conflicting with K accepted over RPC) withheld; inv, expect getdata 10 s; send it, expect a reject 5 s; inv again, expect silence 2 s; (the child of the refused parent sent); one block by generatetoaddress; after 2 s inv again, expect getdata 10 s",
        fixtures, offset))
}

fn absurd_row(road: &mut Road, row: &Value, offset: usize) -> Result<Value> {
    let (big, vout) = road.well.big.clone().ok_or("the 4e9-satoshi coin")?;
    let p = frame(&big, vout, 1000);
    let rpc = road
        .t
        .receipt("sendrawtransaction", json!([hex::encode(p.encode())]))?;
    let ceiling = rpc["error"]["message"].as_str().unwrap_or("").to_owned();
    let mark = road.b.mark()?;
    road.b.send_tx(&p)?;
    let answer = tx_answer(road, &p, mark, 3.0)?;
    let accepted = labels(road, &[("P", &p)])?;
    let observed = json!({"accepted":accepted,"orphans":"unobservable","rpc_ceiling_reject":rpc.get("error").is_some()});
    Ok(mempool_verdict(road, row, reference_of(row), observed, &["accepted"],
        json!({"orphans":"the bridge's orphan map has no surface (services/legacy/netsync/manager.go:487)"}),
        "A coin of 4,000,000,000 satoshis (the run's funding transaction); P = frame(coin, 1000) pays the rest as fee; sendrawtransaction(P) meets Teranode's own RPC ceiling (maxrawtxfee default 10,000,000, settings/settings.go:110; services/rpc/handlers.go:913-916), the reference's at its maxtxfee; then P from the loopback peer, which no RPC ceiling reads (manager.go:1271-1320); read block assembly",
        json!({"P":material(&p),"rpc":rpc,"rpc_message":ceiling,"wire":answer}), offset))
}

fn rpc_missing_row(road: &mut Road, row: &Value, offset: usize) -> Result<Value> {
    let tx = RawTx::decode(&hex::decode(text(&row["tx"])?).map_err(|e| e.to_string())?)?;
    let meta = road.t.txmeta(&txid_display_hex(&tx.inputs[0].txid))?;
    let reply = road
        .t
        .receipt("sendrawtransaction", json!([hex::encode(tx.encode())]))?;
    let judgment = match reply.get("error") {
        Some(e) => {
            json!({"status":"rejected","namespace":"teranode-rpc","code":e["code"],"word":verdict_word(e["message"].as_str().unwrap_or("")),"message":e["message"]})
        }
        None => json!({"status":"accepted"}),
    };
    let accepted: Vec<String> = road
        .t
        .pool()?
        .into_iter()
        .filter(|x| *x == id(&tx))
        .collect();
    let observed = json!({"judgment":{"status":if judgment["status"] == "rejected" { "orphan" } else { "accepted" }},"accepted":accepted,"held":[],"orphans":"unobservable"});
    let mut r = mempool_verdict(road, row, reference_of(row), observed, &["accepted"],
        json!({"orphans":"no surface (the RPC keeps no orphan; the bridge's map is not reached from RPC)","judgment":"Teranode's RPC refuses a missing parent before validation (the absurd-fee parent read, services/rpc/handlers.go:880-904): its refusal is read as the row's missing-input class"}),
        "The row's exact frame, its outpoint symbolic (no such coin on the instance: the asset txmeta read), through sendrawtransaction; read block assembly",
        json!({"tx":material(&tx),"parent_meta":meta,"reply":reply,"teranode_judgment":judgment}), offset);
    r["road"] = json!("rpc");
    Ok(r)
}

fn known_output_row(road: &mut Road, row: &Value, offset: usize) -> Result<Value> {
    let (fund, k) = road.coin();
    let tx = frame(&fund, k, 900);
    let initial = road
        .t
        .receipt("sendrawtransaction", json!([hex::encode(tx.encode())]))?;
    road.settle(&tx)?;
    let pending = road.t.pool()?.len() as u64;
    let mined = road.t.mine_pending(pending, &road.addr.clone())?;
    let reply = road
        .t
        .receipt("sendrawtransaction", json!([hex::encode(tx.encode())]))?;
    let judgment = match reply.get("error") {
        Some(e) => {
            json!({"status":"rejected","namespace":"teranode-rpc","code":e["code"],"word":verdict_word(e["message"].as_str().unwrap_or("")),"message":e["message"]})
        }
        None => json!({"status":"accepted"}),
    };
    let accepted: Vec<String> = road
        .t
        .pool()?
        .into_iter()
        .filter(|x| *x == id(&tx))
        .collect();
    let mut reference = reference_of(row);
    reference["judgment"] = json!({"status":reference["judgment"]["status"]});
    let observed = json!({"judgment":{"status":judgment["status"]},"accepted":accepted,"held":[],"orphans":"unobservable"});
    let mut r = mempool_verdict(road, row, reference, observed, &[],
        json!({"orphans":"no surface on RPC","judgment":"compared on its status only: the reference's code 257 txn-already-known is internal (REJECT_ALREADY_KNOWN, src/validation.h:1157-1163 at 6504a3af), Teranode's RPC answers a transaction already in its store with its id (services/validator/Validator.go:1106-1141)"}),
        "A frame of a fresh OP_TRUE coin admitted and mined (generatetoaddress after block assembly counts it), then the same frame resubmitted through sendrawtransaction: its inputs are spent and its outputs are known",
        json!({"tx":material(&tx),"first":initial,"mined":mined,"reply":reply,"teranode_judgment":judgment}), offset);
    r["road"] = json!("rpc");
    Ok(r)
}

fn parent_only_row(road: &mut Road, row: &Value, offset: usize) -> Result<Value> {
    // The reference's queue state (P accepted, C still pending) needs its asynchronous
    // validator (txnvalidationasynchrunfreq=5000); the bridge revalidates orphans inline.
    let (fund, k) = road.coin();
    let p = frame(&fund, k, 900);
    let c = frame(&p, 0, 800);
    let mark = road.b.mark()?;
    road.b.send_tx(&c)?;
    let requested = road.b.expect("getdata", &id(&p), mark, 10.0)?;
    road.b.send_tx(&p)?;
    let p_in = road.settle(&p)?;
    let c_in = road.settle(&c)?;
    let observed = json!({"retried_without_resubmission":c_in,"orphans_final":"unobservable","queued":"unobservable","fence_rejected":"unobservable"});
    Ok(mempool_verdict(road, row, reference_of(row), observed, &["retried_without_resubmission"],
        json!({"queued":"the reference's queue state needs its asynchronous validator held for 5 s (txnvalidationasynchrunfreq); the bridge revalidates a parent's orphans inline in the same call (services/legacy/netsync/manager.go:1385-1444), so no state between P's acceptance and C's exists to read","fence_rejected":"the fence is the reference's queue barrier (an input-empty RPC frame); it has no counterpart without the queue","orphans_final":"the bridge's orphan map has no surface (manager.go:487)"}),
        "Fund F; P = frame(F, 900), C = frame(P, 800); C from the loopback peer, P withheld; expect getdata for P 10 s; send P; read block assembly for P and C (C never resent)",
        json!({"P":material(&p),"C":material(&c),"parent_requested":requested,"parent_accepted":p_in}), offset))
}

/// The p2pTrace rows (rejects.rs's driver): each step's answer on the wire, projected to the
/// classes both nodes expose: request or silence for an inv; a refusal (with its code),
/// accepted, or silent for a tx (the reference's suppressed, orphan and rejected-unanswered are
/// all silent on the wire); tip for a block step.
fn trace_row(road: &mut Road, row: &Value, offset: usize) -> Result<Value> {
    let mut frames: BTreeMap<String, RawTx> = BTreeMap::new();
    let mut points: Points = BTreeMap::new();
    for u in row["utxo"].as_array().into_iter().flatten() {
        let h: [u8; 32] = hex::decode(text(&u["hash"])?)
            .map_err(|e| e.to_string())?
            .try_into()
            .map_err(|_| "utxo hash")?;
        // [D] 2026-10-15, lane cut2-66q: every declared coin is funded as the reference funds
        // it (rejects.rs `fund`: the row's value, default 1000, on the row's lock, default
        // OP_TRUE; the heavy one on hashing_lock(8)), never the well's 100,000-satoshi coin,
        // so a frame that overspends its prevout (bad-txns-in-belowout) still overspends.
        let (fund, k) = {
            let (fund, k) = road.coin();
            let mut lock = frame(&fund, k, u["value"].as_u64().unwrap_or(1000));
            lock.outputs[0].script = if u["heavy"] == true {
                super::super::rejects::hashing_lock(8)
            } else {
                hex::decode(u["script"].as_str().unwrap_or("51")).map_err(|e| e.to_string())?
            };
            let r = road
                .t
                .receipt("sendrawtransaction", json!([hex::encode(lock.encode())]))?;
            if r.get("error").is_some() {
                // The answer stays in the run's receipt; the error names the row only.
                return Err(format!(
                    "{}: the declared coin's funding was refused",
                    row["id"]
                ));
            }
            road.settle(&lock)?;
            (lock, 0)
        };
        points.insert(
            (h, u["index"].as_u64().unwrap_or(0) as u32),
            (fund.txid_internal(), k),
        );
    }
    let pending = road.t.pool()?.len() as u64;
    if pending > 0 {
        road.t.mine_pending(pending, &road.addr.clone())?;
    }
    for (label, hexed) in row["txs"].as_object().into_iter().flatten() {
        let mut tx = RawTx::decode(&hex::decode(text(hexed)?).map_err(|e| e.to_string())?)?;
        for input in &mut tx.inputs {
            if let Some((h, i)) = points.get(&(input.txid, input.vout)) {
                input.txid = *h;
                input.vout = *i;
            }
        }
        road.b.step(json!({"op":"withhold","hash":id(&tx)}))?;
        frames.insert(label.clone(), tx);
    }
    let expected: Vec<String> = row["expected"]["answers"]
        .as_array()
        .into_iter()
        .flatten()
        .filter_map(Value::as_str)
        .map(str::to_owned)
        .collect();
    let mut answers = vec![];
    let mut mined: Vec<String> = vec![];
    for (i, s) in row["steps"].as_array().into_iter().flatten().enumerate() {
        let want = expected.get(i).cloned().unwrap_or_default();
        let op = s["op"].as_str().unwrap_or("");
        let tx = s["tx"].as_str().and_then(|l| frames.get(l)).cloned();
        let answer = match (op, tx) {
            ("inv", Some(tx)) => {
                let mark = road.b.mark()?;
                road.b.send_inv(&tx)?;
                let wait = if want == "request" { 10.0 } else { 2.0 };
                if road.b.expect("getdata", &id(&tx), mark, wait)? {
                    "request".to_owned()
                } else {
                    "silence".to_owned()
                }
            }
            ("tx", Some(tx)) => {
                let mark = road.b.mark()?;
                road.b.send_tx(&tx)?;
                let wait = if want.starts_with("rejected") {
                    5.0
                } else {
                    1.5
                };
                text(&tx_answer(road, &tx, mark, wait)?["class"])?.to_owned()
            }
            ("rpc", Some(tx)) => {
                let r = road
                    .t
                    .receipt("sendrawtransaction", json!([hex::encode(tx.encode())]))?;
                if r.get("error").is_some() {
                    "rejected".to_owned()
                } else if road.settle(&tx)? {
                    "accepted".to_owned()
                } else {
                    "absent".to_owned()
                }
            }
            ("mine", _) => {
                let h = road.t.call("generatetoaddress", json!([1, road.addr]))?;
                mined.push(text(&h[0])?.to_owned());
                thread::sleep(Duration::from_secs(2));
                "tip".to_owned()
            }
            ("invalidate", _) => {
                let last = mined.pop().ok_or("invalidate with no mined block")?;
                road.t.call("invalidateblock", json!([last]))?;
                thread::sleep(Duration::from_secs(2));
                "tip".to_owned()
            }
            _ => return Err(format!("{}: step {s}", row["id"])),
        };
        answers.push(answer);
    }
    // The reference's answers projected to the wire classes; the reason is never compared.
    let project = |a: &str, op: &str| -> String {
        let parts: Vec<&str> = a.split(' ').collect();
        match (op, parts.first().copied().unwrap_or("")) {
            ("rpc", "rejected" | "heldNonFinal" | "rpc-error")
                if a.starts_with("rejected") || a.starts_with("rpc-error") =>
            {
                "rejected".to_owned()
            }
            (_, "rejected") if parts.len() > 1 && a != "rejected-unanswered" => {
                format!("rejected {}", parts[1])
            }
            (_, "suppressed" | "orphan" | "rejected-unanswered") => "silent".to_owned(),
            _ => a.to_owned(),
        }
    };
    let ops: Vec<String> = row["steps"]
        .as_array()
        .into_iter()
        .flatten()
        .map(|s| s["op"].as_str().unwrap_or("").to_owned())
        .collect();
    let reference: Vec<String> = expected
        .iter()
        .zip(&ops)
        .map(|(a, op)| project(a, op))
        .collect();
    // A tx step whose accept/refuse class differs is judged (consensus classes); an inv,
    // filter or hold difference is the node's machine.
    let mut judged = vec![];
    let mut machine = vec![];
    for (i, (r, o)) in reference.iter().zip(&answers).enumerate() {
        if r != o {
            fn class(a: &str) -> &str {
                if a.starts_with("rejected") {
                    "refused"
                } else {
                    a
                }
            }
            let tx_step = matches!(ops[i].as_str(), "tx" | "rpc");
            if tx_step
                && matches!(
                    (class(r), class(o)),
                    ("refused", "accepted") | ("accepted", "refused")
                )
                && !r.contains("64")
            {
                judged.push(i);
            } else {
                machine.push(i);
            }
        }
    }
    let reference_non_judging = row["nonJudging"].as_array().is_some_and(|a| !a.is_empty());
    let verdict = if !judged.is_empty() && !reference_non_judging {
        "diverge"
    } else if machine.is_empty() && judged.is_empty() {
        "agree"
    } else {
        "non-judging"
    };
    let mut r = json!({"id":row["id"],"label":"[X]","verdict":verdict,"expected":{"answers":reference,"reference_answers":expected},"expected_label":"the reference's answers [D], projected to the wire classes",
        "observed":{"answers":answers},"road":"trace","steps":row["steps"],
        "recipe":"Fund each declared coin (a fresh mined OP_TRUE coin; the heavy one on the reference's hashing lock, rejects.rs hashing_lock(8), admitted and mined ahead of the others); remap the frames, withhold every frame; per step: inv and expect getdata (10 s for an expected request, else 2 s); tx and expect a reject (5 s for an expected refusal, else 1.5 s), else read block assembly; rpc through sendrawtransaction; mine one block by generatetoaddress; invalidate the last mined block",
        "fixtures":frames.iter().map(|(l, t)| (l.clone(), material(t))).collect::<serde_json::Map<String, Value>>(),"reference_token":row["node"],
        "comparison_scope":"each step's class on the wire; a refusal's reason is never compared (the bridge answers 0x10 'rejected', services/legacy/netsync/manager.go:1368); the reference's suppressed, orphan and rejected-unanswered are one class on the wire (no answer)",
        "rpc":road.t.calls[offset..].to_vec()});
    if verdict == "non-judging" {
        r["qualifier"] = json!(if reference_non_judging && !judged.is_empty() {
            format!("the steps {judged:?} differ on a class the reference's own row marks non-judging (its CPU validation clock or its non-final pool, #71): the second oracle's machine is never the rule")
        } else {
            format!("the steps {machine:?} differ on the relay answer, the reject filter or the hold: the node's machine (DESIGN-S6 2.1, kind P; the reject filter is the bridge's own, cleared at each block, manager.go:2181)")
        });
    }
    if verdict == "diverge" {
        r["diverging_steps"] = json!(judged);
    }
    Ok(r)
}

// ---- The chain rows over RPC ----

/// The chain-only snapshot of F's and T's outputs: a coin is on the chain when its
/// transaction is in an active block and no active block's transaction spends it.
pub(super) fn snapshot(road: &mut Road, f: &(RawTx, u32), t: &RawTx, base: u64) -> Result<Value> {
    let (height, _) = road.t.tip()?;
    let mut coins = vec![];
    for (label, tx, vout) in [("F", &f.0, f.1), ("T", t, 0)] {
        let meta = road.t.txmeta(&id(tx))?;
        let mut mined = false;
        for h in meta["body"]["blockHashes"]
            .as_array()
            .into_iter()
            .flatten()
            .filter_map(Value::as_str)
        {
            if let Some((true, _)) = road.t.on_active(h)? {
                mined = true;
            }
        }
        if !mined {
            continue;
        }
        let outs = road.t.utxos(&id(tx))?;
        let spender = outs["body"]
            .as_array()
            .into_iter()
            .flatten()
            .find(|o| o["vout"] == vout)
            .and_then(|o| o["spendingData"]["txId"].as_str().map(str::to_owned));
        let mut spent = false;
        if let Some(s) = spender {
            let smeta = road.t.txmeta(&s)?;
            for h in smeta["body"]["blockHashes"]
                .as_array()
                .into_iter()
                .flatten()
                .filter_map(Value::as_str)
            {
                if let Some((true, _)) = road.t.on_active(h)? {
                    spent = true;
                }
            }
        }
        if !spent {
            coins.push(label);
        }
    }
    let pool: Vec<&str> = if road.pool_has(t)? { vec!["T"] } else { vec![] };
    // The reference's heights (101 before T's block, 102 with it) remapped from the instance's base.
    Ok(
        json!({"height":101 + height - base,"instance_height":height,"coins":coins,"pool":pool,"held":[]}),
    )
}

fn chain_rows(road: &mut Road, rows: &[Value]) -> Result<Vec<Value>> {
    let mut out = vec![];
    for row in rows
        .iter()
        .filter(|r| r["case"].as_str().is_some_and(|c| CHAIN_CASES.contains(&c)))
    {
        let offset = road.t.calls.len();
        let f = road.coin();
        let t = op_true_spend(&f.0, f.1, 99_000, 0, u32::MAX);
        let (base, _) = road.t.tip()?;
        let pending = road.t.pool()?.len() as u64;
        if pending > 0 {
            road.t.mine_pending(pending, &road.addr.clone())?;
        }
        let (base, _) = (road.t.tip()?.0.max(base), ());
        let admitted = road
            .t
            .receipt("sendrawtransaction", json!([hex::encode(t.encode())]))?;
        road.settle(&t)?;
        let hash = road.t.mine_pending(1, &road.addr.clone())?;
        let body: Vec<String> = road.t.txmeta(&id(&t))?["body"]["blockHashes"]
            .as_array()
            .into_iter()
            .flatten()
            .filter_map(Value::as_str)
            .map(str::to_owned)
            .collect();
        let mut snaps = vec![snapshot(road, &f, &t, base)?];
        road.t.call("invalidateblock", json!([hash]))?;
        road.settle(&t)?;
        snaps.push(snapshot(road, &f, &t, base)?);
        let observed = if row["case"] == "readmit" {
            snaps[1].clone()
        } else {
            // The answer is the row's evidence either way (an error is recorded, not raised).
            let reconsider = road.t.receipt("reconsiderblock", json!([hash]))?;
            let start = Instant::now();
            while road.t.tip()?.1 != hash && start.elapsed() < Duration::from_secs(20) {
                thread::sleep(Duration::from_millis(250));
            }
            thread::sleep(Duration::from_secs(1));
            let mut last = snapshot(road, &f, &t, base)?;
            if reconsider.get("error").is_some() {
                last["reconsiderblock_error"] = reconsider["error"].clone();
                last["reconsiderblock_code"] = reconsider["error"]["code"].clone();
                last["reconsiderblock_stage"] = json!(revalidation_stage(&reconsider["error"]));
            }
            snaps.push(last);
            json!(snaps)
        };
        let strip = |v: &Value| -> Value {
            let mut v = v.clone();
            if let Some(a) = v.as_array_mut() {
                for s in a {
                    if let Some(o) = s.as_object_mut() {
                        for k in STRIPPED {
                            o.remove(k);
                        }
                    }
                }
            } else if let Some(o) = v.as_object_mut() {
                for k in STRIPPED {
                    o.remove(k);
                }
            }
            v
        };
        let same = strip(&observed) == row["expected"];
        let verdict = if same { "agree" } else { "diverge" };
        // lane cut2-66q2: the reconsider refusal's stage, an enumerated class (`revalidation_stage`).
        let stage = observed
            .as_array()
            .and_then(|a| a.last())
            .and_then(|s| s["reconsiderblock_stage"].as_str())
            .map(str::to_owned);
        let r = json!({"id":row["id"],"label":"[X]","verdict":verdict,"expected":row["expected"],"expected_label":"[D]","observed":observed,"road":"rpc",
            "recipe":"A fresh mined OP_TRUE coin F; T = its spend admitted through sendrawtransaction and mined alone (generatetoaddress after block assembly counts it); invalidateblock of T's block, and for the second row reconsiderblock; each snapshot reads the chain-only coins of F and T (an output whose transaction is in an active block, per txmeta's block hashes and getblock's confirmations, and whose spender is in none, per the asset utxos route), block assembly for T, and the tip's height remapped to the reference's 101 base",
            "fixtures":{"F":material(&f.0),"F_vout":f.1,"T":material(&t),"block":hash,"T_blocks":body,"admitted":admitted,"base":base},
            "reference_token":row["node"],"comparison_scope":"the snapshot's height (remapped), chain-only coins, pool and held lists; the held list is empty by construction (Teranode has no non-final pool, services/validator/Validator.go:976-983)",
            "rpc":road.t.calls[offset..].to_vec()});
        let mut r = r;
        if let Some(stage) = stage {
            r["stage"] = json!(stage);
        }
        road.progress(row["id"].as_str().unwrap_or(""), &r);
        out.push(r);
    }
    Ok(out)
}

/// The harness's own fields of a chain snapshot, never compared with the row's expectation.
const STRIPPED: [&str; 4] = [
    "instance_height",
    "reconsiderblock_error",
    "reconsiderblock_code",
    "reconsiderblock_stage",
];

/// The stages of a reconsiderblock refusal, by the fixed texts of the instance's source
/// ([SRC] services/rpc/handlers.go:1935-1952: the service's absence, or -25 wrapping
/// RevalidateBlock's error, services/blockvalidation/Server.go:1409-1450: the block's read, its
/// header's read, the subtree fetch, the re-validation; at the Teranode pin). The harness judges
/// the answer in code and only the stage enters the record (lane cut2-66q2, the quarantine rule).
pub(super) const REVALIDATION_STAGES: [&str; 6] = [
    "service-absent",
    "block-read",
    "header-read",
    "subtree-fetch",
    "re-validation",
    "other",
];

pub(super) fn revalidation_stage(error: &Value) -> &'static str {
    let m = error["message"].as_str().unwrap_or("");
    if m.contains("Block validation service not available") {
        "service-absent"
    } else if m.contains("failed block re-validation") {
        "re-validation"
    } else if m.contains("failed to fetch missing subtree data") {
        "subtree-fetch"
    } else if m.contains("failed to get block header") {
        "header-read"
    } else if m.contains("failed to get block") {
        "block-read"
    } else {
        "other"
    }
}

// ---- The chain rows that are one block's verdict (lane cut2-66q) ----

/// [D] 2026-10-15, lane cut2-66q: chain.rs's single-block recipes, rebuilt on the instance's
/// tip through the bridge: the reference's T (a signed P2PKH spend of a funded coin, fee 1000)
/// and U (T's signed child), each body delivered as a block.
const CHAIN_BLOCK_CASES: [&str; 6] = [
    "missing-input",
    "reward",
    "queued-script",
    "sequential-inputs",
    "reversed-inputs",
    "reward-before-script",
];

/// A row's expectation as a block verdict: a refusal's reason (a string) is `rejected`, any
/// other expectation is the accepted block (`ok`).
fn as_block_row(row: &Value, status: &str) -> Value {
    let mut r = row.clone();
    r["expected"] = json!({"status":status,"reason":row["expected"]});
    r["kind"] = json!("block");
    r
}

/// A block of `txs` on the tip; `Some(observed)` when it was not accepted (the setup failed).
fn setup_block(road: &mut Road, txs: &[RawTx]) -> Result<Option<Value>> {
    let time = road.time()?;
    let (observed, _) = road.block(txs, time)?;
    Ok((observed["status"] != "ok").then_some(observed))
}

fn chain_block_rows(road: &mut Road, rows: &[Value]) -> Result<Vec<Value>> {
    let mut out = vec![];
    for row in rows.iter().filter(|r| {
        r["case"]
            .as_str()
            .is_some_and(|c| CHAIN_BLOCK_CASES.contains(&c))
    }) {
        let id_ = text(&row["id"])?.to_owned();
        let case = text(&row["case"])?.to_owned();
        let offset = road.t.calls.len();
        let status = if row["expected"].is_string() {
            "rejected"
        } else {
            "ok"
        };
        let as_row = as_block_row(row, status);
        // F: a coin of 100,000 satoshis locked to the harness key (the reference's seed F).
        let (fund, k) = road.coin();
        let mut f = frame(&fund, k, 99_000);
        f.version = 1;
        f.outputs[0].script = script();
        let (height, _) = road.t.tip()?;
        if let Some(observed) = setup_block(road, &[cb(height as u32 + 1, &id_), f.clone()])? {
            let mut r = block_verdict(
                road,
                &as_row,
                json!({"status":"no-verdict","setup":observed["status"]}),
                "the funding block of F was not accepted; the row is not measured",
                json!({"F":material(&f)}),
                offset,
                "",
            );
            r["verdict"] = json!("no-verdict");
            road.progress(&id_, &r);
            out.push(r);
            continue;
        }
        let t = spend(&f, 98_000, 1);
        let u = spend(&t, 97_000, 1);
        let mut bad = t.clone();
        bad.inputs[0].script.clear();
        bsv_script_harness::gen::push_min(&mut bad.inputs[0].script, &[]);
        bsv_script_harness::gen::push_min(
            &mut bad.inputs[0].script,
            &key().public_key().to_compressed(),
        );
        let (height, _) = road.t.tip()?;
        let next = height + 1;
        let subsidy = 5_000_000_000u64 >> (next / SUBSIDY_INTERVAL).min(63);
        let base = block_codec::coinbase_tx(next as u32, 0, script(), id_.as_bytes());
        let overpay =
            block_codec::coinbase_tx(next as u32, subsidy + 1000 + 1, script(), id_.as_bytes());
        let mut missing = t.clone();
        missing.inputs[0].txid = [9; 32];
        missing.inputs[0].script = vec![1, 0x51];
        let (txs, recipe) = match case.as_str() {
            "missing-input" => (vec![base, missing], "T with its prevout replaced by the absent 32-byte 0x09 outpoint (chain.rs missing_input_recipe)"),
            "reward" => (vec![overpay, t.clone()], "T with a coinbase claiming the regtest subsidy at the height plus T's fee 1000 plus one satoshi (chain.rs reward_recipe; go-chaincfg v1.6.2 params.go:478)"),
            "queued-script" => (vec![base, bad.clone()], "T with an empty signature beside its compressed public key (chain.rs queued_script_recipe)"),
            "reward-before-script" => (vec![overpay, bad.clone()], "the empty-signature T with the coinbase one satoshi above subsidy plus fee (chain.rs reward_before_script_recipe)"),
            "sequential-inputs" => (vec![base, t.clone(), u.clone()], "T then its child U, fee 1000 each (chain.rs sequential_inputs_recipe)"),
            _ => (vec![base, u.clone(), t.clone()], "U before its parent T (chain.rs reversed_inputs_recipe)"),
        };
        let time = road.time()?;
        let (observed, fixtures) = road.block(&txs, time)?;
        let r = block_verdict(road, &as_row, observed,
            &format!("Fund F (100,000 satoshis to the harness key) in a block on the instance's tip; then deliver, through the bridge, a block of {recipe}; read getblock's confirmations and the peer's reject"),
            json!({"block":fixtures,"F":material(&f),"T":material(&t),"U":material(&u),"bad":material(&bad),"height":next}), offset,
            "the reference's row sits at height 102 on its fresh prefix; the instance's block is its tip's successor, past Genesis and Chronicle; the reference's expectation is a reason (compared as its class, refused) or an accepted body (compared as ok)");
        road.progress(&id_, &r);
        out.push(r);
    }
    Ok(out)
}

// ---- The utxo rows in block context (lane cut2-66q) ----

const MEMPOOL_HEIGHT: u64 = 0x7fff_ffff;

/// The utxo row's block-context cell fits the instance's chain past both eras.
fn utxo_era_fits(row: &Value) -> bool {
    let c = &row["context"];
    c["onBlock"] == true
        && c["network"] == "regtest"
        && c["genesisHeight"] == 10
        && c["chronicleHeight"] == 20
        && c["height"].as_u64().is_some_and(|h| h > 20)
}

/// The obstacle for a utxo row in a fitting block context that the road does not realize, or
/// `None` when the road realizes it (`utxo_rows`).
fn utxo_obstacle(row: &Value) -> Option<String> {
    let id = row["id"].as_str().unwrap_or("");
    let node = row["node"].as_str().unwrap_or("");
    if !node.starts_with("measured") {
        let token = node.split(':').next().unwrap_or("");
        return Some(format!("the reference realized no block-context measurement of the row (its token is {token}, the reason in it), so no measurement of the row stands beside the second oracle's"));
    }
    if row["kind"] == "inputs" {
        return Some("the reference judged the row through sendrawtransaction (the inputs kind), not a block; the second oracle's RPC admission is #74's road".to_owned());
    }
    let coins = row["utxo"].as_array().cloned().unwrap_or_default();
    let frozen = &row["frozen"];
    let listed = |k: &str| frozen[k].as_array().is_some_and(|a| !a.is_empty());
    if coins.iter().any(|u| u["isConfiscation"] == true)
        || listed("whitelist")
        || id.starts_with("confiscation")
    {
        return Some("the row's coin is a confiscation transaction's output or the row whitelists one; Teranode has no confiscation transaction: its counterpart is the alert system's reassignment of a frozen output to a new output hash (services/alert/node.go:397-511; stores/utxo/sql/alert_system.go:147-177, spendable after utxostore_reassignedUtxoSpendableAfterBlocks, settings/utxostore_settings.go:54), a different object, so the row's coin and its maturity have no Teranode realization".to_owned());
    }
    if listed("policy") && !listed("block") {
        return Some("the row freezes its coin at the policy level only; Teranode's freeze has one level (the freeze RPC, services/rpc/handlers.go:2708-2730, into the UTXO store's FreezeUTXOs, stores/utxo/sql/alert_system.go:52-103), so a policy-only freeze has no Teranode setting".to_owned());
    }
    if coins.iter().any(|u| u["height"] == MEMPOOL_HEIGHT)
        || row["context"]["height"] == MEMPOOL_HEIGHT
    {
        return Some("the row's coin or context carries the reference's mempool height (2147483647, a pool parent's height); a block on the bridge's road assigns every coin its block's height, so the cell is not a block on the instance's chain".to_owned());
    }
    let value_in = if row["family"] == "fee-stage" {
        row["valueIn"].as_u64()
    } else {
        Some(
            coins
                .iter()
                .map(|u| u["value"].as_i64().unwrap_or(0).max(10) as u64)
                .sum(),
        )
    };
    if value_in.is_none_or(|v| v > 99_000) {
        return Some(
            "the row's input value exceeds the road's funded coin (100,000 satoshis each)"
                .to_owned(),
        );
    }
    None
}

fn utxo_rows(road: &mut Road, rows: &[Value]) -> Result<Vec<Value>> {
    let mut out = vec![];
    for row in rows
        .iter()
        .filter(|r| utxo_era_fits(r) && utxo_obstacle(r).is_none())
    {
        let id_ = text(&row["id"])?.to_owned();
        let offset = road.t.calls.len();
        let status = if row["expected"]["status"] == "rejected" {
            "rejected"
        } else {
            "ok"
        };
        let as_row = as_block_row(row, status);
        let as_row = {
            let mut r = as_row;
            r["expected"]["reason"] = row["expected"]["reason"].clone();
            r
        };
        let family = row["family"].as_str().unwrap_or("");
        let operator = matches!(family, "availability" | "frozen");
        let fee_stage = family == "fee-stage";
        let coin = &row["utxo"][0];
        let mut tx = RawTx::decode(&hex::decode(text(&row["tx"])?).map_err(|e| e.to_string())?)?;
        let mut setup = vec![];
        let mut fail: Option<Value> = None;
        // The coin, as the reference's utxo.rs funds it: a coinbase at its depth below the
        // spend, or a funding output of the row's value and lock (the operator families:
        // 10 satoshis on OP_TRUE).
        let funded: Option<RawTx> = if row["utxo"].as_array().is_none_or(|a| a.is_empty()) {
            None
        } else if coin["isCoinbase"] == true {
            let depth = row["context"]["height"]
                .as_u64()
                .unwrap_or(0)
                .saturating_sub(coin["height"].as_u64().unwrap_or(0));
            let (height, _) = road.t.tip()?;
            let lock =
                hex::decode(coin["script"].as_str().unwrap_or("51")).map_err(|e| e.to_string())?;
            let c = block_codec::coinbase_tx(
                height as u32 + 1,
                coin["value"].as_u64().unwrap_or(10),
                lock,
                id_.as_bytes(),
            );
            fail = setup_block(road, std::slice::from_ref(&c))?;
            setup.push(material(&c));
            if fail.is_none() {
                road.mine_to(height + depth)?;
            }
            Some(c)
        } else {
            let value = if fee_stage {
                row["valueIn"].as_u64().unwrap_or(10)
            } else if operator {
                10
            } else {
                coin["value"].as_u64().unwrap_or(10)
            };
            let lock = if operator {
                vec![0x51]
            } else {
                hex::decode(coin["script"].as_str().unwrap_or("51")).map_err(|e| e.to_string())?
            };
            let (fund, k) = road.coin();
            let mut f = frame(&fund, k, value);
            f.outputs[0].script = lock;
            let (height, _) = road.t.tip()?;
            fail = setup_block(road, &[cb(height as u32 + 1, &id_), f.clone()])?;
            setup.push(material(&f));
            Some(f)
        };
        if let Some(f) = &funded {
            if id_ != "availability/missing" {
                for input in &mut tx.inputs {
                    input.txid = f.txid_internal();
                }
            }
        }
        if fee_stage {
            tx.outputs[0].satoshis = row["valueOut"].as_u64().ok_or("valueOut")?;
        }
        // availability/spent: the coin is spent by an earlier block (utxo.rs operator_rows).
        if fail.is_none() && id_.contains("spent") {
            let mut other = tx.clone();
            other.outputs[0].satoshis = 8;
            let (height, _) = road.t.tip()?;
            fail = setup_block(
                road,
                &[cb(height as u32 + 1, "spent-prefix"), other.clone()],
            )?;
            setup.push(material(&other));
        }
        // The consensus freeze: Teranode's freeze RPC (services/rpc/handlers.go:2708-2730). The
        // store answers it only once it holds the coin's transaction (stores/utxo/sql/alert_system.go:56-70,
        // the row read by the coin's id), which a block added before its full validation may not
        // yet carry (optimistic mining, settings/blockvalidation_settings.go:56): lane cut2-66q2
        // asks once a second for up to 30 s and records the attempts.
        let mut froze = Value::Null;
        if fail.is_none() && (family == "frozen" || id_ == "availability/precedes-frozen") {
            if let Some(f) = &funded {
                let start = Instant::now();
                let mut attempts = 0u32;
                let accepted = loop {
                    attempts += 1;
                    let r = road.t.receipt("freeze", json!([id(f), 0]))?;
                    if r.get("error").is_none() {
                        break true;
                    }
                    if start.elapsed() > Duration::from_secs(30) {
                        break false;
                    }
                    thread::sleep(Duration::from_secs(1));
                };
                froze = json!(accepted);
                if !accepted {
                    fail = Some(json!({"status":"freeze-refused","attempts":attempts}));
                }
                setup.push(json!({"freeze_attempts":attempts}));
            }
        }
        let note = "the reference's row sits at height 1200 on its recipe's Genesis 10 and Chronicle 20 with its coin at its own height; the instance's spend is its tip's successor past Genesis 100 and Chronicle 200 (go-chaincfg v1.6.2 params.go:475-476), the coin funded in the block before it (a coinbase coin at the row's depth below the spend): a value, structure, fee or script row does not depend on the coin's era, and every script row's coin is post-Genesis on both";
        let r = if let Some(setup_observed) = fail {
            let mut r = block_verdict(road, &as_row, json!({"status":"no-verdict","setup":setup_observed["status"]}),
                "the row's setup (its coin, its spend or its freeze) was not accepted; the row is not measured", json!({"setup":setup}), offset, note);
            r["verdict"] = json!("no-verdict");
            r
        } else {
            let (height, _) = road.t.tip()?;
            let time = road.time()?;
            let (mut observed, fixtures) =
                road.block(&[cb(height as u32 + 1, &id_), tx.clone()], time)?;
            if !froze.is_null() {
                observed["frozen"] = froze;
            }
            block_verdict(road, &as_row, observed,
                "Fund the row's coin as the reference's utxo.rs does (its value and lock; the operator families 10 satoshis on OP_TRUE; fee-stage rows valueIn; a coinbase coin by a delivered block whose coinbase pays it, the chain then mined by generatetoaddress to the row's depth); spend it in an earlier block for the spent rows; freeze it by the freeze RPC for the frozen rows; remap the row's transaction prevouts (fee-stage rows: valueOut); deliver the spend in a block through the bridge; read getblock's confirmations and the peer's reject",
                json!({"block":fixtures,"setup":setup,"transaction":material(&tx)}), offset, note)
        };
        road.progress(&id_, &r);
        out.push(r);
    }
    Ok(out)
}

// ---- The finality rows (lane cut2-66q) ----

/// The lock-time threshold: a lock below it is a height, at or above it a time.
const LOCKTIME_THRESHOLD: u64 = 500_000_000;

/// The reference's median of a row's `times` (sorted, the middle; DESIGN-S6's median).
fn median_of(row: &Value) -> Option<u64> {
    let mut t: Vec<u64> = row["times"]
        .as_array()?
        .iter()
        .filter_map(Value::as_u64)
        .collect();
    if t.is_empty() {
        return None;
    }
    t.sort_unstable();
    Some(t[t.len() / 2])
}

/// The obstacle for a finality row of a kind the road reaches, or `None` when the road
/// realizes it (`finality_rows`).
fn finality_obstacle(row: &Value) -> Option<String> {
    let id = row["id"].as_str().unwrap_or("");
    let node = row["node"].as_str().unwrap_or("");
    if !node.starts_with("measured") {
        let token = node.split(':').next().unwrap_or("");
        return Some(format!("the reference realized no measurement of the row (its token is {token}, the reason in it), so no measurement of the row stands beside the second oracle's"));
    }
    if id.contains("signed-mtp-") {
        return Some("the row's block times sit at 2^31 seconds (the year 2038); a block of the instance's chain is at most the host clock plus two hours (model/Block.go:689-697) and above its parent's median, so no block the road delivers carries them".to_owned());
    }
    if id.starts_with("tip/flags-") {
        return Some("the row selects the tip check's lock-time flags word; the instance's mempool finality compares the lock with the median time past unconditionally (services/validator/Validator.go:550-590,968-979), with no flags selector".to_owned());
    }
    if row["kind"] == "tip" && row["tipHeight"].as_u64().is_some_and(|h| h < 10) {
        return Some("the row's tip sits below its recipe's Genesis height 10; the instance's Genesis is 100 (go-chaincfg v1.6.2 params.go:475) and no coin matures below height 101 (params.go:463), so no pre-Genesis tip can carry a spend".to_owned());
    }
    None
}

/// The finality rows the road realizes: the `finality` predicate and the `block` cells in a
/// block delivered through the bridge, the `tip` cells through sendrawtransaction; the lock
/// rebuilt at the row's distance from the instance's own height or median time past.
fn finality_rows(road: &mut Road, rows: &[Value], early: bool) -> Result<Vec<Value>> {
    let mut out = vec![];
    for row in rows.iter().filter(|r| {
        matches!(r["kind"].as_str(), Some("finality" | "block" | "tip"))
            && finality_obstacle(r).is_none()
            && (r["id"] == "block/before-csv-own-time") == early
    }) {
        let id_ = text(&row["id"])?.to_owned();
        let kind = text(&row["kind"])?.to_owned();
        let offset = road.t.calls.len();
        let lock = row["lockTime"].as_u64().unwrap_or(0);
        let seqs: Vec<u32> = row["sequences"]
            .as_array()
            .into_iter()
            .flatten()
            .filter_map(Value::as_u64)
            .map(|q| q as u32)
            .collect();
        let (h, _, _, mtp) = road.tip()?;
        let next = h + 1;
        let time = road.time()?;
        // The row's reference point: the height and the time its predicate compares with.
        let (ref_height, ref_time, here_height, here_time) = match kind.as_str() {
            "finality" => (
                row["height"].as_u64().unwrap_or(0),
                row["time"].as_u64().unwrap_or(0),
                next,
                mtp as u64,
            ),
            "tip" => (
                row["tipHeight"].as_u64().unwrap_or(0) + 1,
                median_of(row).unwrap_or(0),
                next,
                mtp as u64,
            ),
            _ if early => (
                row["height"].as_u64().unwrap_or(0),
                row["blockTime"].as_u64().unwrap_or(0),
                next,
                time as u64,
            ),
            _ => (
                row["height"].as_u64().unwrap_or(0),
                median_of(row).unwrap_or(0),
                next,
                mtp as u64,
            ),
        };
        let shifted = if lock == 0 {
            0
        } else if lock < LOCKTIME_THRESHOLD {
            (here_height + lock).saturating_sub(ref_height)
        } else {
            (here_time + lock).saturating_sub(ref_time)
        };
        let mut tx = RawTx {
            version: row["version"].as_i64().unwrap_or(2) as i32,
            inputs: vec![],
            outputs: vec![RawOutput {
                satoshis: 100_000 * seqs.len().max(1) as u64 - 1000,
                script: vec![0x51],
            }],
            lock_time: shifted as u32,
        };
        for q in if seqs.is_empty() {
            vec![0]
        } else {
            seqs.clone()
        } {
            let (fund, k) = road.coin();
            tx.inputs.push(RawInput {
                txid: fund.txid_internal(),
                vout: k,
                script: vec![],
                sequence: q,
            });
        }
        let note = "the reference's row sits on its recipe's mock clock and remapped heights (Genesis 10, CSV 5); the instance's cell is rebuilt at the same distance from its own next height and median time past (its block's own time before its CSV height 576, go-chaincfg v1.6.2 params.go:467), past its Genesis 100";
        let r = if kind == "tip" {
            let reply = road
                .t
                .receipt("sendrawtransaction", json!([hex::encode(tx.encode())]))?;
            let class = if reply.get("error").is_some() {
                "rejected"
            } else if road.settle(&tx)? {
                "accepted"
            } else {
                "accepted-not-in-assembly"
            };
            let want = row["expected"]["status"].as_str().unwrap_or("");
            let verdict = match (want, class) {
                ("final", "accepted") | ("rejected", "rejected") => "agree",
                ("heldNonFinal", "accepted") => "diverge",
                ("heldNonFinal", _) => "non-judging",
                _ => "diverge",
            };
            let mut r = json!({"id":row["id"],"label":"[X]","verdict":verdict,"expected":{"status":want},"expected_label":"[D]",
                "observed":{"status":class},"road":"tx",
                "recipe":"Spend fresh OP_TRUE coins (one per row sequence) with the row's version and sequences, the lock time at the row's distance from the instance's next height (a height lock) or its tip's median time past (a time lock); submit through sendrawtransaction; read block assembly",
                "fixtures":{"transaction":material(&tx),"tip_height":h,"median_time_past":mtp,"lock_time":shifted},"reference_token":row["node"],"note":note,
                "comparison_scope":"the admission class against the tip: final is accepted, a refusal is refused; the reference's hold of a non-final transaction is policy (DESIGN-S6 2.1 row 3), and Teranode has no non-final pool (services/validator/Validator.go:976-983): a refusal there is non-judging, an admission of a transaction non-final for the next block diverges",
                "rpc":road.t.calls[offset..].to_vec()});
            if verdict == "non-judging" {
                r["qualifier"] = json!("policy: the hold, DESIGN-S6 2.1 row 3");
            }
            r
        } else {
            let want = match (&row["expected"], row["expected"]["status"].as_str()) {
                (Value::Bool(true), _) | (_, Some("final")) => "ok",
                _ => "rejected",
            };
            let as_row = as_block_row(row, want);
            let observed = {
                let (observed, fixtures) =
                    road.block(&[cb(next as u32, &id_), tx.clone()], time)?;
                (observed, fixtures)
            };
            block_verdict(road, &as_row, observed.0,
                "Spend fresh OP_TRUE coins (one per row sequence) with the row's version and sequences, the lock time at the row's distance from the block's height (a height lock) or from the parent's median time past (its own block time before CSV); deliver the spend in a block through the bridge; read getblock's confirmations and the peer's reject",
                json!({"block":observed.1,"transaction":material(&tx),"tip_height":h,"median_time_past":mtp,"block_time":time,"lock_time":shifted}), offset, note)
        };
        road.progress(&id_, &r);
        out.push(r);
    }
    Ok(out)
}

// ---- The short median rows on the fresh chain (lane cut2-66q2) ----

/// The two median rows the reference measured on a fresh chain of one and two headers.
const SHORT_MEDIAN: [&str; 2] = ["median/short-one", "median/short-two-upper-middle"];

/// [D] 2026-10-15, lane cut2-66q2: the short median rows, run on the instance's fresh chain
/// before the column's prefix, as finality.rs's `short_median` runs them on the reference: every
/// time of the row translated by one offset so its oldest is the genesis block's own time, the
/// rest delivered as blocks through the bridge, and the median read back from getblock's
/// `mediantime` minus that offset. The instance's getblock computes it over the eleven headers
/// ending at the block (services/rpc/handlers.go:310,1592-1626 at the Teranode pin), with the
/// function its header rule uses (model/Block.go:717, CalculateMedianTimestamp :3014). The
/// delivered block's coinbase pays the regtest subsidy to the harness key, so the column's
/// funding (block 1's coinbase) is unchanged. A row whose block or read does not settle is
/// `no-verdict`; nothing here stops the run.
pub(super) fn median_rows(t: &mut Tera, b: &mut Bridge, rows: &[Value]) -> Vec<Value> {
    let mut out = vec![];
    let mut ordered: Vec<&Value> = rows
        .iter()
        .filter(|r| SHORT_MEDIAN.contains(&r["id"].as_str().unwrap_or("")))
        .collect();
    ordered.sort_by_key(|r| r["times"].as_array().map(Vec::len).unwrap_or(0));
    for row in ordered {
        let offset = t.calls.len();
        let r = match short_median(t, b, row) {
            Ok(r) => r,
            Err(e) => {
                json!({"id":row["id"],"label":"[X]","verdict":"no-verdict","observed":{"status":"no-verdict","error":e},"expected":row["expected"],"expected_label":"[D]","road":"median",
                "reference_token":row["node"],"rpc":t.calls[offset..].to_vec()})
            }
        };
        eprintln!("road median {}: {}", row["id"], r["verdict"]);
        out.push(r);
    }
    out
}

fn short_median(t: &mut Tera, b: &mut Bridge, row: &Value) -> Result<Value> {
    let offset = t.calls.len();
    let times: Vec<u64> = row["times"]
        .as_array()
        .ok_or("median times")?
        .iter()
        .filter_map(Value::as_u64)
        .collect();
    let oldest = *times.last().ok_or("median oldest")?;
    let (h, _) = t.tip()?;
    if h != 0 && times.len() > 1 {
        return Err(format!("the chain is not fresh: height {h}"));
    }
    let genesis = t.call("getblockbyheight", json!([0, 1]))?;
    let g_time = genesis["time"].as_u64().ok_or("genesis time")?;
    let shift = g_time.checked_sub(oldest).ok_or("median offset")?;
    let bits = u32::from_str_radix(text(&genesis["bits"])?, 16).map_err(|e| e.to_string())?;
    let mut parent = text(&genesis["hash"])?.to_owned();
    let mut delivered = vec![];
    // The row lists its times newest to oldest; the blocks go oldest to newest, the genesis block standing for the oldest.
    for (k, time) in times.iter().rev().skip(1).enumerate() {
        let height = 1 + k as u32;
        let coinbase = block_codec::coinbase_tx(
            height,
            5_000_000_000,
            script(),
            row["id"].as_str().unwrap_or("median").as_bytes(),
        );
        let (header, bytes) = block_codec::assemble(
            4,
            txid_from_display_hex(&parent)?,
            (time + shift) as u32,
            bits,
            &[coinbase],
        );
        let hash = txid_display_hex(&header.hash());
        let mark = b.mark()?;
        let sent = b.send_block(&bytes)?;
        let start = Instant::now();
        let active = loop {
            if let Some((true, _)) = t.on_active(&hash)? {
                break true;
            }
            if b.expect("reject", &hash, mark, 0.5)? || start.elapsed() > Duration::from_secs(30) {
                break false;
            }
            thread::sleep(Duration::from_millis(250));
        };
        delivered.push(json!({"hash":hash,"block":hex::encode(&bytes),"time":time + shift,"send":sent["ok"],"active":active}));
        if !active {
            return Ok(
                json!({"id":row["id"],"label":"[X]","verdict":"no-verdict","observed":{"status":"no-verdict","setup":"block-not-active"},"expected":row["expected"],"expected_label":"[D]","road":"median",
                "fixtures":{"delivered":delivered,"time_offset":shift},"reference_token":row["node"],"rpc":t.calls[offset..].to_vec()}),
            );
        }
        parent = hash;
    }
    let block = t.call("getblock", json!([parent, 1]))?;
    let median = block["mediantime"].as_u64().ok_or("mediantime")?;
    let value = median.checked_sub(shift).ok_or("median below the offset")?;
    let verdict = if json!(value) == row["expected"] {
        "agree"
    } else {
        "diverge"
    };
    Ok(
        json!({"id":row["id"],"label":"[X]","verdict":verdict,"expected":row["expected"],"expected_label":"[D]",
        "observed":{"status":"ok","value":value,"height":block["height"]},"road":"median",
        "recipe":"On the instance's fresh chain (the genesis block alone), before the column's prefix: translate the row's times by one offset so the oldest is the genesis block's own time, deliver the rest from the oldest as coinbase-only blocks through the bridge (the coinbase paying the regtest subsidy to the harness key), read getblock's mediantime at the newest and subtract the offset (finality.rs short_median's recipe on the reference)",
        "fixtures":{"genesis":genesis["hash"],"genesis_time":g_time,"time_offset":shift,"delivered":delivered},
        "comparison_scope":"the median of the one or two headers ending at the newest block, as the instance's getblock reports it (services/rpc/handlers.go:310,1592-1626; model/Block.go:3014 at the Teranode pin), against the row's value",
        "reference_token":row["node"],"rpc":t.calls[offset..].to_vec()}),
    )
}

/// Every row the road realizes, by family, and the road's receipt.
pub(super) fn run(road: &mut Road) -> Result<(BTreeMap<String, Vec<Value>>, Value)> {
    let mut by = BTreeMap::new();
    by.insert(
        "mempool".to_owned(),
        mempool_rows(road, &selected("mempool")?)?,
    );
    by.insert("chain".to_owned(), chain_rows(road, &selected("chain")?)?);
    // lane cut2-66q: the pre-CSV finality cell runs below the instance's CSV height 576.
    let mut finality = finality_rows(road, &selected("finality")?, true)?;
    by.insert("block".to_owned(), block_rows(road, &selected("block")?)?);
    // lane cut2-66q5: the whole column reaches the rows below past the BIP65 header row's
    // floor (context_header mines to BIP65 - 1), so past CSV 576 where the instance compares
    // a block's lock times with the median; a run of selected rows (teranode::selected) that
    // skips that row is brought to the same height here, which a whole column never needs.
    if road.t.tip()?.0 < BIP65 - 1 {
        road.mine_to(BIP65 - 1)?;
    }
    finality.extend(finality_rows(road, &selected("finality")?, false)?);
    by.insert("finality".to_owned(), finality);
    // lane cut2-66q: the single-block chain rows and the utxo rows, on the tall chain (past
    // Chronicle 200).
    let more = chain_block_rows(road, &selected("chain")?)?;
    by.entry("chain".to_owned()).or_default().extend(more);
    // lane cut2-66q4: a run of selected rows (teranode::selected) reaches the utxo rows on a
    // short chain; their spend is past Chronicle 200 as in the whole column (utxo_rows' note).
    let utxo = selected("utxo")?;
    if !utxo.is_empty() && road.t.tip()?.0 < 201 {
        road.mine_to(201)?;
    }
    by.insert("utxo".to_owned(), utxo_rows(road, &utxo)?);
    // lane cut2-66q2: every accepted block read again before the branch rows rearrange the chain.
    sweep(road, &mut by)?;
    let branches = super::branch::rows(road, &selected("chain")?);
    by.entry("chain".to_owned()).or_default().extend(branches);
    // lane cut2-66q2: #90's and #91's scenarios on the second oracle (spends.rs).
    let scenarios = super::spends::run(road);
    road.b.close()?;
    let receipt = json!({"peer":road.b.receipt(),"log":road.log,"scenarios":scenarios});
    Ok((by, receipt))
}

/// The obstacle for a row of these families that the road leaves (the bridge on).
pub(super) fn reason(family: &str, row: &Value) -> Option<String> {
    let id = row["id"].as_str().unwrap_or("");
    let s = match family {
        "block" => return Some(block_reason(row)),
        "chain" if super::branch::reason(row).is_some() => return super::branch::reason(row),
        "chain" => "the row reads the reference's undo or block-index records, its disconnect pool, its held or orphan pools across an era crossing, its frozen list, or a model-only operand; Teranode reverses a block's spends in the UTXO store and the subtree processor (stores/utxo/Interface.go:458; services/blockassembly/subtreeprocessor/SubtreeProcessor.go:4720) with no undo record, has no non-final pool (services/validator/Validator.go:976-983) and no such disconnect queue".to_owned(),
        "utxo" if utxo_era_fits(row) => utxo_obstacle(row)?,
        "utxo" if row["context"]["onBlock"] == true => format!("the row's context sits at an era boundary of the reference's recipe (genesisHeight {}, chronicleHeight {}, height {}, network {}); the instance's eras are fixed at Genesis 100 / Chronicle 200 with no setting (go-chaincfg v1.6.2 params.go:475-476) and its network is regtest, so the row's era cell is not the instance's", row["context"]["genesisHeight"], row["context"]["chronicleHeight"], row["context"]["height"], row["context"]["network"]),
        "finality" if matches!(row["kind"].as_str(), Some("finality" | "block" | "tip" | "median")) => finality_obstacle(row)?,
        "finality" => "the row's input is the mock clock (the pool's capacity and expiry, adjusted time, a backward clock), a fee-stage value outside what a funded coin can carry, a configured span, or an operand no block carries; Teranode has no mock clock (setmocktime has no handler, services/rpc/Server.go:160-226,277-285), no non-final pool (services/validator/Validator.go:976-983), and its eras are fixed (go-chaincfg v1.6.2 params.go:475-476)".to_owned(),
        "mempool" => match id {
            "orphan-hysteresis-skips-expiry" => "the row selects maxOrphanTxSize 100 and the trim hysteresis and expires the orphan on the mock clock; the bridge caps its orphan map by count (legacy_maxOrphanTxs, settings/legacy_settings.go:14, default 100) and evicts by a duration on the host clock (legacy_orphanEvictionDuration, :13, default 10m; services/legacy/netsync/manager.go:3615,3674-3686): no byte cap, no hysteresis, no mock clock".to_owned(),
            "orphan-admission-aggregate-134" | "orphan-admission-aggregate-135" => format!("the row selects maxOrphanTxSize {} (a byte cap on the orphan pool); the bridge caps its orphan map by count (legacy_maxOrphanTxs, settings/legacy_settings.go:14), so the byte boundary has no Teranode setting, and the map has no surface to read the retained set (services/legacy/netsync/manager.go:487)", row["cfg"]["maxOrphanTxSize"]),
            "orphan-p2p-size-60" | "orphan-p2p-size-61" => "the row selects maxTxSizePolicy 60 or 61; the reference refused the launch (its token: unrealizable, src/configscriptpolicy.cpp:415-440 at 6504a3af), so no measurement of the row stands beside the second oracle's, and the bridge's orphan map has no surface to read the retained child (services/legacy/netsync/manager.go:487)".to_owned(),
            _ => return None,
        },
        _ => return None,
    };
    Some(format!("{s} [SRC] at {TERANODE}"))
}
