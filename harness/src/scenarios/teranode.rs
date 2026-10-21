//! #74 (S3, lane tera-74, [D] 2026-10-14; lane fix-tera-74 after the lens): the Teranode
//! column. The scenario corpus (the six families of #66 and the eight status witnesses of
//! #67) driven against the instance of #41 (Teranode v0.16.0 at
//! 4edb60a40c6628ff0ef60231c2628efd7103fde5) on a fresh data directory, through the client
//! and observation set of `harness/engines/teranode/client.rs`
//! (docs/CONFORMANCE-TERANODE-MACHINE.md section 5). A row the instance cannot realize
//! carries its cited reason (`unrealizable`), a row this cut does not realize but could
//! carries what cut 2 needs (`pending`), and a realized row is judged on the admission
//! verdict (DESIGN-S6 section 2.1's `TxVerdict`) read from Teranode's own observables.
//! **The second oracle's defaults are never the rule**: a verdict that differs at a policy
//! stage is recorded `non-judging`, never `diverge`.
use super::core::*;
#[path = "../../engines/teranode/client.rs"]
mod client;
use client::{verdict_word, Tera, PIN as TPIN, TAG as TTAG};
// #66 cut 2 (lane cut2-66): the loopback peer on the legacy bridge, and the road it drives.
#[path = "bridge.rs"]
mod bridge;
#[path = "road.rs"]
mod road;
// lane cut2-66q2: the chain rows that build or rearrange branches.
#[path = "branch.rs"]
mod branch;
// lane cut2-66q2: #90's and #91's scenarios on the road.
#[path = "spends.rs"]
mod spends;

const SRC: &str = "at Teranode v0.16.0 (4edb60a4)";
/// #66 cut 2: the funding transaction's coins for the road's rows (100,000 satoshis each).
const ROAD_COINS: usize = 400;
// The reference's admission stages whose kind is P in DESIGN-S6 section 2.1's kind column
// (the row named): a verdict there that differs is non-judging. Not policy: `regular` (row 1,
// C), `alreadyKnown` (row 4, a node fact), `sequence` (row 7, C), `scripts` (row 12, C).
const POLICY_STAGES: [(&str, &str); 10] = [
    ("standard", "row 2"),
    ("finality", "row 3, the tip judge and the hold"),
    ("conflict", "row 5"),
    ("inputs", "row 6, a structure of the node"),
    ("inputStandard", "row 8"),
    ("sigops", "row 9"),
    ("fee", "row 10"),
    ("ancestors", "row 11"),
    ("detector", "row 13"),
    ("commit", "row 14, and row 3's hold"),
];
// The reference settings the mempool rows select, each with Teranode's same-named setting
// ([SRC] settings/settings.go at the tag) or the line that shows its absence.
// A funding point (txid, vout) of a row remapped to its point in the fan-out.
type Points = BTreeMap<([u8; 32], u32), ([u8; 32], u32)>;
// One setting: the reference's name, Teranode's key and line, or the line that shows its absence.
type Setting = (&'static str, Option<(&'static str, u32)>, &'static str);
const SETTINGS: [Setting; 16] = [
    ("acceptNonStdOutputs", Some(("acceptnonstdoutputs", 122)), ""),
    ("requireStandard", Some(("requirestandard", 123)), ""),
    ("maxTxSigOpsCountPolicy", Some(("maxtxsigopscountspolicy", 117)), ""),
    ("maxTxFee", Some(("maxrawtxfee", 110)), ""),
    ("maxCoinsViewCacheSize", Some(("maxcoinsviewcachesize", 135)), ""),
    ("minConsolidationFactor", Some(("minconsolidationfactor", 130)), ""),
    ("acceptNonStdConsolidationInput", Some(("acceptnonstdconsolidationinput", 134)), ""),
    ("limitAncestorCount", None, "limitancestorcount is commented out at settings/settings.go:120"),
    ("limitSecondaryMempoolAncestorCount", None, "no limitsecondarymempoolancestorcount key in the tag's Go sources or settings.conf (git grep empty)"),
    ("maxMempool", None, "no maxmempool key in the tag's Go sources or settings.conf (git grep empty): block assembly has no size cap of the reference's kind"),
    ("maxMempoolSizeDisk", None, "no maxmempoolsizedisk key in the tag's Go sources or settings.conf (git grep empty)"),
    ("maxMempoolNonFinal", None, "no maxmempoolnonfinal key in the tag's Go sources or settings.conf (git grep empty): there is no non-final pool (services/validator/Validator.go:976-983)"),
    ("minDebugRejectionFee", None, "no mindebugrejectionfee key in the tag's Go sources or settings.conf (git grep empty)"),
    ("maxTxSigOpsCountConsensusBeforeGenesis", None, "no maxtxsigopscountconsensusbeforegenesis key in the tag's Go sources or settings.conf (git grep empty)"),
    ("maxTxSizeConsensusBeforeGenesis", None, "no maxtxsizeconsensusbeforegenesis key in the tag's Go sources or settings.conf (git grep empty)"),
    ("chronicleGracefulPeriod", None, "no chroniclegracefulperiod key in the tag's Go sources or settings.conf (git grep empty)"),
];
// Absent like its pre-Genesis twin (no maxtxsizeconsensusaftergenesis key, git grep empty).
const SETTINGS_AFTER: (&str, &str) = ("maxTxSizeConsensusAfterGenesis", "no maxtxsizeconsensusaftergenesis key in the tag's Go sources or settings.conf (git grep empty)");
const NO_METHOD: &str = "no entry in the handler table services/rpc/Server.go:160-226 nor the unimplemented list :277-285 (git grep of the name in Server.go at the tag: empty)";

/// lane cut2-66q4 (#66 cut 2): the rows one run selects. ORACLE_ROWS, a comma-separated list of
/// corpus row ids (and `scenario:<name>` for #90's and #91's scenarios), runs those rows alone
/// (a run under the foreground's ten minutes); unset, every row of the family.
fn selection() -> Option<BTreeSet<String>> {
    std::env::var("ORACLE_ROWS").ok().map(|v| {
        v.split(',')
            .map(str::trim)
            .filter(|s| !s.is_empty())
            .map(str::to_owned)
            .collect()
    })
}
pub(super) fn selected(family: &str) -> Result<Vec<Value>> {
    let rows = row_read(family)?;
    Ok(match selection() {
        Some(ids) => rows
            .into_iter()
            .filter(|r| r["id"].as_str().is_some_and(|i| ids.contains(i)))
            .collect(),
        None => rows,
    })
}
pub(super) fn scenario_selected(name: &str) -> bool {
    selection().is_none_or(|ids| ids.contains(&format!("scenario:{name}")))
}

/// [D] 2026-10-15, lane cut2-66q4 (#66 cut 2, the settings restarts): a mempool row whose one
/// obstacle was a reference setting with Teranode's same-named key (the rows `pending` named
/// "not selected in this cut") gets its overlay, one `key = value` line per setting: the row
/// is realized on a fresh instance funded on the recipe's settings and restarted on the same
/// data with the overlay (`settings_rows`). The reference ran these rows with acceptnonstdtxn=0
/// unless the row says otherwise (harness/src/scenarios/mempool.rs, `requireStandard` default
/// true; [SRC] src/init.cpp at 6504a3af), so the overlay sets Teranode's requirestandard
/// (settings/settings.go:123) to the row's requireStandard, true by default, and
/// acceptnonstdoutputs (:122) to the row's acceptNonStdOutputs, true by default. A row with a
/// pool selector stays out (the rolling-rate rows go to `unrealizable`).
fn overlay(family: &str, row: &Value) -> Option<String> {
    if family != "mempool" || own_output(row) || !row["tx"].is_string() {
        return None;
    }
    let cfg = row["cfg"].as_object()?;
    if ["binary", "context", "pool"]
        .iter()
        .any(|k| row.get(*k).is_some())
        || !matches!(
            row["expected"]["status"].as_str(),
            Some("accepted" | "rejected")
        )
    {
        return None;
    }
    if row.get("request").is_some() && !bypass(row) {
        return None;
    }
    let mut lines = vec![
        format!(
            "requirestandard = {}",
            cfg.get("requireStandard")
                .and_then(Value::as_bool)
                .unwrap_or(true)
        ),
        format!(
            "acceptnonstdoutputs = {}",
            cfg.get("acceptNonStdOutputs")
                .and_then(Value::as_bool)
                .unwrap_or(true)
        ),
    ];
    for (k, v) in cfg {
        if matches!(k.as_str(), "requireStandard" | "acceptNonStdOutputs") {
            continue;
        }
        let (_, tn, _) = SETTINGS.iter().find(|(name, _, _)| name == k)?;
        let (tn, _) = (*tn)?;
        let value = match v {
            Value::Bool(b) => b.to_string(),
            Value::Number(n) if n.as_u64().is_some() => n.to_string(),
            _ => return None,
        };
        lines.push(format!("{tn} = {value}"));
    }
    Some(lines.join("\n") + "\n")
}
/// The request's absurdFee 0 alone: Teranode's per-call allowhighfees (services/rpc/handlers.go:879-880).
fn bypass(row: &Value) -> bool {
    row["request"]
        .as_object()
        .is_some_and(|r| r.len() == 1 && r.get("absurdFee").is_some_and(|f| f == 0))
}

/// A row this cut does not realize but cut 2 can, with what it needs.
fn pending(family: &str, row: &Value) -> Option<String> {
    // #66 cut 2: the other families' rows are the road's (road.rs, branch.rs) or carry their
    // obstacle; since lane cut2-66q2 none of them is pending.
    if family != "mempool" {
        return None;
    }
    // lane cut2-66q4: a row that judges the reference's rolling minimum fee is unrealizable.
    if row["pool"].get("rollingRate").is_some() {
        return None;
    }
    if own_output(row) {
        return Some("pending (#66 cut 2): the known output is a coin at the transaction's own id, which the funding remap cannot create; realize it by mining the frame's parent and the frame, then resubmitting (Teranode's existing-record path answers success there, services/validator/Validator.go:1106-1141)".to_owned());
    }
    // A row that also selects the reference's wallet build stays with the binary rows below;
    // a row that also selects a request mode or an era context goes to `unrealizable()`,
    // which names its setting beside that obstacle, save the per-call absurd-fee bypass.
    if let (Some(cfg), None) = (row["cfg"].as_object(), row.get("binary")) {
        let bypass = row["request"]
            .as_object()
            .is_some_and(|r| r.len() == 1 && r.get("absurdFee").is_some_and(|f| f == 0));
        if row.get("context").is_some() || (row.get("request").is_some() && !bypass) {
            return None;
        }
        let mut found = vec![];
        for k in cfg.keys() {
            match SETTINGS.iter().find(|(name, _, _)| name == k) {
                Some((_, Some((tn, line)), _)) => {
                    found.push(format!("{tn} (settings/settings.go:{line})"))
                }
                _ => return None,
            }
        }
        let also = if bypass {
            "; the request's absurdFee 0 is Teranode's per-call allowhighfees, which skips the ceiling (services/rpc/handlers.go:879-880)"
        } else {
            ""
        };
        return Some(format!("pending (#66 cut 2): Teranode's setting {} not selected in this cut{also}; policy, never the rule", found.join(" and ")));
    }
    if !realizable(row) && !has_unrealizable_selector(row) {
        let keys: Vec<&str> = SPECIAL
            .iter()
            .copied()
            .filter(|k| row.get(*k).is_some())
            .collect();
        return Some(format!(
            "pending (#66 cut 2): the row's selector {} has no Teranode recipe in this cut",
            keys.join(" and ")
        ));
    }
    None
}

// The mempool rows whose selector has a cited obstacle below (the binary, the orphan and
// reject machinery, the non-final pool, the mock clock, a setting, a request or context).
fn has_unrealizable_selector(row: &Value) -> bool {
    let status = row["expected"]["status"].as_str().unwrap_or("");
    row.get("binary").is_some()
        || matches!(status, "orphan" | "suppressed" | "trace" | "maintenance")
        || row["expected"]["orphans"]
            .as_array()
            .is_some_and(|o| !o.is_empty())
        || row["pool"]["nonFinal"]
            .as_array()
            .is_some_and(|p| !p.is_empty())
        || (status == "deferred" && row["boundary"] == "commit")
        || row["boundary"] == "orphanRetry"
        || row.get("frozen").is_some()
        || row.get("detectorValidating").is_some()
        || row.get("detectorCommitted").is_some()
        || row.get("cfg").is_some()
        || row.get("request").is_some()
        || row.get("context").is_some()
}

// Each reference setting a row selects, with Teranode's same-named setting or its absence.
// Ok: the cited Teranode setting; Err: the line that shows its absence.
fn settings_named(row: &Value) -> Vec<(&str, std::result::Result<String, &'static str>)> {
    row["cfg"]
        .as_object()
        .into_iter()
        .flatten()
        .map(|(k, _)| {
            let found = match SETTINGS.iter().find(|(name, _, _)| name == k) {
                Some((_, Some((tn, line)), _)) => Ok(format!("{tn} (settings/settings.go:{line})")),
                Some((_, None, why)) => Err(*why),
                None if k == SETTINGS_AFTER.0 => Err(SETTINGS_AFTER.1),
                None => Err("a setting this driver has not looked up"),
            };
            (k.as_str(), found)
        })
        .collect()
}

// A prevout at the frame's own id (internal byte order): the reference's "known output".
fn own_output(row: &Value) -> bool {
    let Some(tx) = row["tx"]
        .as_str()
        .and_then(|h| hex::decode(h).ok())
        .and_then(|b| RawTx::decode(&b).ok())
    else {
        return false;
    };
    let own = hex::encode(tx.txid_internal());
    row["utxo"]
        .as_array()
        .into_iter()
        .flatten()
        .any(|u| u["hash"].as_str() == Some(own.as_str()))
}

fn unrealizable(family: &str, row: &Value) -> Option<String> {
    // #66 cut 2: the bridge is on; the families whose old reasons named it off are re-cut in road.rs.
    if let Some(reason) = road::reason(family, row) {
        if !(family == "mempool" && realizable(row)) {
            return Some(reason);
        }
    }
    let has = |k: &str| row.get(k).is_some();
    let status = row["expected"]["status"].as_str().unwrap_or("");
    let reason = match family {
        "oracle" => format!("the row asks a script verdict through verifyscript, which the instance's RPC does not serve ([SRC] {NO_METHOD}); the script layer's Teranode column is #41's (docs/records/20261006-013805-instance41-corpora.md)"),
        "block" => "the row judges a block or header the harness assembles; submitblock is unimplemented (services/rpc/Server.go:211 into handleUnimplemented :389) and the recipe runs the legacy P2P bridge off (-legacy=0, daemon/daemon.go:577-600), so no surface delivers it; the header arithmetic (services/blockchain/Difficulty.go:74; services/blockchain/Server.go:1522) has no per-input RPC".to_owned(),
        "utxo" if row["context"]["onBlock"] == true => "the row judges the UTXO stage in block context (context.onBlock) on a block the harness assembles; submitblock is unimplemented (services/rpc/Server.go:211,389) and the legacy bridge is off (daemon/daemon.go:577-600)".to_owned(),
        "utxo" => "the row's config and context (maturities, frozen lists, the policy flag) are selected through the reference's settings and blacklist RPCs; the instance runs its recipe's settings and Teranode's alert-system freeze (stores/utxo/Interface.go:522-532) is not that list".to_owned(),
        "chain" => "the row builds or rearranges branches with blocks the harness assembles, or reads the reference's undo and block-index records; submitblock is unimplemented (services/rpc/Server.go:211,389), and a block's spends are reversed by the UTXO store and the subtree processor (stores/utxo/Interface.go:458; services/blockassembly/subtreeprocessor/SubtreeProcessor.go:4720), not by undo records".to_owned(),
        "finality" => format!("the row's inputs (tip height, median time past, block times, era heights, the pool's capacity and expiry) are set by the reference recipe through setmocktime, harness-assembled blocks and launch-time era heights (harness/src/scenarios/finality.rs:761-765, genesisactivationheight=10); setmocktime is not served ([SRC] {NO_METHOD}), submitblock is unimplemented (services/rpc/Server.go:211,389), generatetoaddress stamps the host clock, and Teranode's regtest eras are fixed at Genesis 100 / Chronicle 200 (go-chaincfg v1.6.2 params.go:475-476); the non-final class is witnessed by mempool/nonfinal-held-height-equality and the heldNonFinal status witness"),
        // lane cut2-66q4 (#66 cut 2): the consolidation rows' minConsolidationFactor and
        // acceptNonStdConsolidationInput have Teranode keys, but the row's verdict is the rolling
        // minimum fee after an eviction history, which the reference's recipe builds.
        "mempool" if row["pool"].get("rollingRate").is_some() => format!("the row judges the reference's rolling minimum fee (pool.rollingRate {}): its recipe evicts a calibrated history under maxmempool 0 and a disk cap one byte below it, then moves the mock clock 43,200 s (harness/src/scenarios/mempool.rs, ROLLING_RECIPE; [SRC] src/txmempool.cpp:1368-1383,2624-2647 at 6504a3af); Teranode has no mempool size cap and no rolling minimum fee (no maxmempool key and no GetMinFee in the tag's Go sources or settings.conf, git grep empty), and setmocktime is not served ([SRC] {NO_METHOD}; its nine git grep hits are the test harness calling an SV node, test/utils/svnode/docker.go:286-306); the consolidation keys (minconsolidationfactor, acceptnonstdconsolidationinput, settings/settings.go:130,134) exist, the history they are judged against does not", row["pool"]["rollingRate"]),
        "mempool" if realizable(row) => return None,
        "mempool" if row.get("binary").is_some() => "the row selects the reference's wallet build or its maxtxfee ceiling; Teranode has no wallet and its own RPC absurd-fee ceiling (services/rpc/handlers.go:913-916) is its default, never the rule".to_owned(),
        "mempool" if status == "orphan" || status == "suppressed" || status == "trace" || row["expected"]["orphans"].as_array().is_some_and(|o| !o.is_empty()) =>
            "the row judges the orphan pool or the recent-reject filter through a P2P peer; Teranode keeps orphans only in the legacy bridge's netsync map (services/legacy/netsync/manager.go:487,1335-1352; settings/settings.go:719-720), which has no RPC or asset surface, and the recipe runs that bridge off (daemon/daemon.go:577-600); on RPC a missing parent is refused before validation by the absurd-fee parent read, -25 TX rejected: PROCESSING (4): failed to decorate previous outputs (services/rpc/handlers.go:880-904; maxrawtxfee default 10,000,000, settings/settings.go:110) [M] this run; TX_MISSING_PARENT 34 (services/validator/Validator.go:1657-1663) is the validator's answer, reached when the ceiling is off".to_owned(),
        "mempool" if row["pool"]["nonFinal"].as_array().is_some_and(|p| !p.is_empty()) || matches!(status, "deferred") && row["boundary"] == "commit" =>
            "the row's setup holds a parent in the non-final pool; Teranode has none: a non-final transaction is rejected at admission (services/validator/Validator.go:976-983; util/lock_time.go:38-40)".to_owned(),
        "mempool" if status == "maintenance" =>
            format!("the row judges the reference mempool's maintenance machine (expiry, trimming, the rolling minimum fee, the time-locked pool, orphan expiry) on the mock clock; setmocktime is not served ([SRC] {NO_METHOD}) and Teranode has no such pool: block assembly holds the validated transactions in its subtrees (services/blockassembly/subtreeprocessor/SubtreeProcessor.go:267-298) and lets one go when a block that holds it moves the processor forward (moveForwardBlock, :5711-5713) or on an explicit removal (RemoveTx, services/blockassembly/BlockAssembler.go:1830) and the UTXO store prunes old unmined records by its own retention (stores/utxo/Interface.go:491-496)"),
        "mempool" if row["boundary"] == "orphanRetry" => format!("the row's selector action {} re-evaluates the orphan pool when a parent arrives; that machinery is the legacy bridge's (services/legacy/netsync/manager.go:1390-1440), which the recipe runs off (-legacy=0, daemon/daemon.go:577-600); realizable on cut 2's bridge road", row["action"]),
        "mempool" if has("frozen") => "the row's selector frozen is the reference's frozen-output admission list, as utxo/frozen/admission's; Teranode's alert-system freeze (stores/utxo/Interface.go:522-532) is not that list".to_owned(),
        "mempool" if has("detectorValidating") || has("detectorCommitted") => format!("the row's selector {} seeds the reference's double-spend detector (DESIGN-S6 section 2.1 row 13); Teranode has no admission-time detector to seed: a spend is decided by the UTXO store's spend-then-create (stores/utxo/Interface.go:432-454). A git grep -n -i -E 'double.?spend.?detect' over the tag's Go sources prints 21 lines: the admission entry's doc comment lists \"Double-spend detection\" (services/validator/Validator.go:619), which is that store's spend; block assembly's DoubleSpendWindow (settings/blockassembly_settings.go:41, double_spend_window_millis, default 0) only holds a queued batch back from assembly for the window (services/blockassembly/subtreeprocessor/SubtreeProcessor.go:1164-1168; queue.go:318-327) and seeds nothing at admission; the other 19 are the block-time fork checks (model/update-tx-mined.go:28; services/blockchain/Client.go:754; services/blockvalidation/BlockValidation.go:1651), comments in the stores and the block-validation settings (stores/utxo/aerospike/get.go:1439), an error test and five sequential tests", if has("detectorValidating") { "detectorValidating" } else { "detectorCommitted" }),
        "mempool" if has("request") || has("context") => {
            let mut sel = vec![];
            let mut why = vec![];
            // An era height the instance does not have, and any other request or context
            // key, which sendrawtransaction cannot select.
            let era = row["context"]["genesisHeight"].as_u64().is_some_and(|h| h != 100)
                || row["context"]["chronicleHeight"].as_u64().is_some_and(|h| h != 200);
            let era_key = |k: &str| matches!(k, "genesisHeight" | "chronicleHeight" | "tipHeight");
            let other = row["request"]
                .as_object()
                .is_some_and(|r| r.keys().any(|k| k != "source"))
                || row["context"]
                    .as_object()
                    .is_some_and(|c| c.keys().any(|k| !era_key(k)));
            if has("request") {
                sel.push(format!("request mode {}", row["request"]));
            }
            if has("context") {
                sel.push(format!("context {}", row["context"]));
            }
            if row["request"]["source"] == "p2p" {
                why.push("a P2P origin needs the legacy P2P bridge, which the recipe runs off (-legacy=0, daemon/daemon.go:577-600)");
            }
            if other {
                why.push("Teranode's sendrawtransaction has no selector for it: it takes the transaction and the absurd-fee boolean only (services/rpc/handlers.go:830-935)");
            }
            if era {
                why.push("the instance's chain is go-chaincfg v1.6.2's regtest, its eras fixed at Genesis 100 / Chronicle 200 with no settings key (params.go:475-476) and block 1's coinbase mature at 101, so the row's era heights are not the instance's");
            }
            if why.is_empty() {
                why.push("this driver has no Teranode recipe for it");
            }
            let beside: Vec<String> = settings_named(row)
                .into_iter()
                .map(|(k, f)| match f {
                    Ok(tn) => format!("{k} is Teranode's {tn}"),
                    Err(why) => format!("{k} has no Teranode setting ([SRC] {why})"),
                })
                .collect();
            let beside = if beside.is_empty() {
                String::new()
            } else {
                format!("; beside it the row's setting: {}", beside.join("; "))
            };
            format!("the row selects the reference {}; {}{beside}", sel.join(" and "), why.join("; "))
        }
        "mempool" if has("cfg") => {
            let absent: Vec<(&str, &str)> = settings_named(row)
                .into_iter()
                .filter_map(|(k, f)| f.err().map(|why| (k, why)))
                .collect();
            let keys: Vec<&str> = absent.iter().map(|(k, _)| *k).collect();
            let why: Vec<&str> = absent.iter().map(|(_, w)| *w).collect();
            format!("the row selects the reference setting {}; Teranode has no same-named setting for {} ([SRC] {})", row["cfg"], keys.join(" and "), why.join("; "))
        }
        "mempool" => return None,
        _ => return Some(format!("unknown family {family}")),
    };
    Some(reason)
}

// The selectors that keep a row from this cut's realized set.
const SPECIAL: [&str; 13] = [
    "cfg",
    "context",
    "request",
    "action",
    "steps",
    "txs",
    "frozen",
    "limit",
    "queued",
    "batchSize",
    "detectorValidating",
    "detectorCommitted",
    "binary",
];

// The admission rows this cut realizes: an exact frame and its prevouts, with
// at most accepted parents, and no reference setting, context or request selected.
fn realizable(row: &Value) -> bool {
    row["tx"].is_string()
        && !SPECIAL.iter().any(|k| row.get(*k).is_some())
        && row["pool"]["nonFinal"]
            .as_array()
            .is_none_or(|p| p.is_empty())
        && matches!(
            row["expected"]["status"].as_str(),
            Some("accepted" | "rejected" | "heldNonFinal")
        )
        && !own_output(row)
}

/// One P2PKH input of the harness key spent to `outs`, signed with SIGHASH_ALL|FORKID.
/// The signer's refusal is an `Err` (#132): the funding road reports it and stops, never a panic.
fn fan(parent: &RawTx, vout: u32, outs: Vec<RawOutput>) -> Result<RawTx> {
    use bsv_rs::primitives::bsv::sighash::{
        compute_sighash_for_signing, SighashParams, TxInput, TxOutput,
    };
    let mut tx = RawTx {
        version: 1,
        inputs: vec![RawInput {
            txid: parent.txid_internal(),
            vout,
            script: vec![],
            sequence: u32::MAX,
        }],
        outputs: outs,
        lock_time: 0,
    };
    let inputs = vec![TxInput {
        txid: parent.txid_internal(),
        output_index: vout,
        script: vec![],
        sequence: u32::MAX,
    }];
    let outputs: Vec<TxOutput> = tx
        .outputs
        .iter()
        .map(|o| TxOutput {
            satoshis: o.satoshis,
            script: o.script.clone(),
        })
        .collect();
    let prev = &parent.outputs[vout as usize];
    let digest = compute_sighash_for_signing(&SighashParams {
        version: 1,
        inputs: &inputs,
        outputs: &outputs,
        locktime: 0,
        input_index: 0,
        subscript: &prev.script,
        satoshis: prev.satoshis,
        scope: 0x41,
    });
    let signature = key()
        .sign(&digest)
        .map_err(|e| format!("fan: the signer refused the funding input: {e}"))?;
    let integer = |x: &[u8; 32]| {
        let mut b: Vec<u8> = x.iter().copied().skip_while(|v| *v == 0).collect();
        if b.is_empty() {
            b.push(0);
        }
        if b[0] & 128 != 0 {
            b.insert(0, 0);
        }
        let mut v = vec![2, b.len() as u8];
        v.extend(b);
        v
    };
    let payload = [integer(signature.r()), integer(signature.s())].concat();
    let mut der = vec![0x30, payload.len() as u8];
    der.extend(payload);
    der.push(0x41);
    bsv_script_harness::gen::push_min(&mut tx.inputs[0].script, &der);
    bsv_script_harness::gen::push_min(
        &mut tx.inputs[0].script,
        &key().public_key().to_compressed(),
    );
    Ok(tx)
}

fn op_true_spend(parent: &RawTx, vout: u32, value: u64, lock_time: u32, sequence: u32) -> RawTx {
    RawTx {
        version: 1,
        inputs: vec![RawInput {
            txid: parent.txid_internal(),
            vout,
            script: vec![],
            sequence,
        }],
        outputs: vec![RawOutput {
            satoshis: value,
            script: vec![0x51],
        }],
        lock_time,
    }
}

/// The journal the derived status reads besides the node: the answers of every
/// submission and the blocks each watched transaction was seen in (DESIGN-S6 1.4).
#[derive(Default)]
struct Journal {
    rejected: BTreeMap<String, Value>,
    seen_in: BTreeMap<String, BTreeSet<String>>,
    seen: BTreeMap<String, RawTx>,
}

fn submit(t: &mut Tera, j: &mut Journal, tx: &RawTx) -> Result<Value> {
    let reply = t.receipt("sendrawtransaction", json!([hex::encode(tx.encode())]))?;
    j.seen.insert(id(tx), tx.clone());
    if let Some(err) = reply.get("error") {
        let message = err["message"].as_str().unwrap_or("").to_owned();
        j.rejected.insert(id(tx), json!({"namespace":"teranode-rpc","code":err["code"],"word":verdict_word(&message),"message":message}));
    } else {
        j.rejected.remove(&id(tx));
    }
    Ok(reply)
}

// After a block: record the blocks the store says contain each watched transaction.
fn journal_blocks(t: &mut Tera, j: &mut Journal) -> Result<()> {
    let ids: Vec<String> = j.seen.keys().cloned().collect();
    for i in ids {
        let meta = t.txmeta(&i)?;
        for h in meta["body"]["blockHashes"]
            .as_array()
            .into_iter()
            .flatten()
            .filter_map(Value::as_str)
        {
            j.seen_in.entry(i.clone()).or_default().insert(h.to_owned());
        }
    }
    Ok(())
}

/// The derived status of `id` read from Teranode's observables, clause by clause
/// in DESIGN-S6 section 3's order. heldNonFinal has no function (no non-final pool,
/// services/validator/Validator.go:976-983) and orphan is not observable (the legacy
/// bridge's map has no surface and is off), so neither clause can hold here.
fn derive(t: &mut Tera, j: &Journal, id_: &str) -> Result<Value> {
    let meta = t.txmeta(id_)?;
    let mut blocks: BTreeSet<String> = meta["body"]["blockHashes"]
        .as_array()
        .into_iter()
        .flatten()
        .filter_map(Value::as_str)
        .map(str::to_owned)
        .collect();
    blocks.extend(j.seen_in.get(id_).cloned().unwrap_or_default());
    let (mut active, mut stale) = (vec![], false);
    for h in &blocks {
        match t.on_active(h)? {
            Some((true, height)) => active.push(height),
            Some((false, _)) => stale = true,
            None => {}
        }
    }
    if let Some(h) = active.iter().max() {
        return Ok(json!({"value":"minedActive","height":h}));
    }
    if t.pool()?.iter().any(|x| x == id_) {
        return Ok(json!({"value":"inMempool"}));
    }
    if stale {
        return Ok(json!({"value":"onStaleBranch"}));
    }
    if let Some(tx) = j.seen.get(id_) {
        for input in &tx.inputs {
            let parent = txid_display_hex(&input.txid);
            let outs = t.utxos(&parent)?;
            let spender = outs["body"]
                .as_array()
                .into_iter()
                .flatten()
                .find(|o| o["vout"] == input.vout)
                .and_then(|o| o["spendingData"]["txId"].as_str().map(str::to_owned));
            if let Some(s) = spender.filter(|s| s != id_) {
                let smeta = t.txmeta(&s)?;
                for h in smeta["body"]["blockHashes"]
                    .as_array()
                    .into_iter()
                    .flatten()
                    .filter_map(Value::as_str)
                {
                    if let Some((true, _)) = t.on_active(h)? {
                        return Ok(json!({"value":"conflictedByMinedSpend","spender":s}));
                    }
                }
            }
        }
    }
    if let Some(r) = j.rejected.get(id_) {
        let mut v = r.clone();
        v["value"] = json!("rejected");
        return Ok(v);
    }
    Ok(json!({"value":"unknown"}))
}

/// A run's path relative to the instance's home, `~/bsv/targets/spec-teranode`.
pub(super) fn pointer(path: &Path) -> String {
    let parts: Vec<_> = path.components().collect();
    // A quarantined run (lane cut2-66q) is named from its directory, the parent kept.
    if let Some(i) = parts
        .iter()
        .position(|p| p.as_os_str() == "spec-oracle-quarantine")
    {
        return format!(
            "~/bsv/targets/{}",
            parts[i..].iter().collect::<PathBuf>().to_string_lossy()
        );
    }
    match parts.iter().position(|p| p.as_os_str() == "spec-teranode") {
        Some(i) => parts[i + 1..]
            .iter()
            .collect::<PathBuf>()
            .to_string_lossy()
            .into_owned(),
        None => path.to_string_lossy().into_owned(),
    }
}

/// [D] 2026-10-15, lane cut2-66q: one line per stage of the run in `phases.jsonl` (the stage's
/// fixed name and the time), so a run that stops is placed without reading any answer.
fn phase(root: &Path, name: &str) {
    use std::io::Write;
    let at = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map(|d| d.as_secs())
        .unwrap_or(0);
    if let Ok(mut f) = fs::OpenOptions::new()
        .create(true)
        .append(true)
        .open(root.join("phases.jsonl"))
    {
        let _ = writeln!(f, "{}", json!({"phase":name,"unix":at}));
    }
}

/// [D] 2026-10-15, lane cut2-66q (#66 cut 2, the quarantine rule): the column's record as
/// the committed page carries it. Every field is a count, an enumerated verdict or class, a
/// row id, a hash, a path or the harness's own text computed before the instance started
/// (the pending and unrealizable reasons, `run`'s classifying loop); every answer of the instance
/// (an RPC reply, a reject message, a log) stays in the full receipt in the quarantine
/// directory, named by its sha256.
pub(super) fn projection(column: &Value) -> Value {
    const VERDICTS: [&str; 5] = [
        "agree",
        "diverge",
        "non-judging",
        "rpc-precheck",
        "no-verdict",
    ];
    const STATUS: [&str; 6] = [
        "ok",
        "rejected",
        "no-verdict",
        "accepted",
        "accepted-not-in-assembly",
        "heldNonFinal",
    ];
    const ANSWERS: [&str; 7] = [
        "request", "silence", "accepted", "silent", "tip", "absent", "rejected",
    ];
    let enum_of = |v: &Value, set: &[&str]| -> Value {
        match v.as_str() {
            Some(s) if set.contains(&s) => json!(s),
            Some(_) => json!("other"),
            None => Value::Null,
        }
    };
    // A wire class: one of ANSWERS, or `rejected <number>`.
    let answer = |v: &Value| -> Value {
        let s = v.as_str().unwrap_or("");
        let ok = ANSWERS.contains(&s)
            || s.strip_prefix("rejected ")
                .is_some_and(|c| !c.is_empty() && c.bytes().all(|b| b.is_ascii_digit()));
        json!(if ok { s } else { "other" })
    };
    let hash = |v: &Value| -> Value {
        match v.as_str() {
            Some(s) if s.len() == 64 && s.bytes().all(|b| b.is_ascii_hexdigit()) => json!(s),
            _ => Value::Null,
        }
    };
    // lane cut2-66q2: the marks of a refusal read after the window (road.rs `late`, `durable`,
    // `sweep`) and the durability read's outcome.
    const WIRES: [&str; 5] = [
        "reject",
        "invalid",
        "getdata",
        "withdrawn",
        "invalid-at-sweep",
    ];
    const DURABILITY: [&str; 3] = ["withdrawn", "held", "unread"];
    let flags = |v: &Value| -> Value {
        let mut m = serde_json::Map::new();
        for (k, x) in v.as_object().into_iter().flatten() {
            if x.is_boolean() || x.is_null() {
                m.insert(k.clone(), x.clone());
            }
        }
        Value::Object(m)
    };
    let numbers = |v: &Value| -> Value {
        let mut m = serde_json::Map::new();
        for (k, x) in v.as_object().into_iter().flatten() {
            if x.is_number() || x.is_boolean() || k == "label" {
                m.insert(k.clone(), x.clone());
            }
        }
        Value::Object(m)
    };
    let mut families = serde_json::Map::new();
    for (family, rows) in column["families"].as_object().into_iter().flatten() {
        let mut out = vec![];
        for r in rows.as_array().into_iter().flatten() {
            let mut p = json!({"id":r["id"],"label":r["label"]});
            for k in ["pending", "unrealizable", "reference_token", "road"] {
                if r.get(k).is_some() {
                    p[k] = r[k].clone();
                }
            }
            if r.get("verdict").is_some() {
                p["verdict"] = enum_of(&r["verdict"], &VERDICTS);
                let o = &r["observed"];
                let mut seen = serde_json::Map::new();
                if o.get("status").is_some() {
                    seen.insert("status".into(), enum_of(&o["status"], &STATUS));
                }
                if o["code"].is_number() {
                    seen.insert("code".into(), o["code"].clone());
                }
                if o.get("class").is_some() {
                    seen.insert("class".into(), answer(&o["class"]));
                }
                if let Some(a) = o["answers"].as_array() {
                    seen.insert(
                        "answers".into(),
                        json!(a.iter().map(answer).collect::<Vec<_>>()),
                    );
                }
                for (k, x) in o.as_object().into_iter().flatten() {
                    if x.is_boolean() || (x.is_number() && k != "code") {
                        seen.insert(k.clone(), x.clone());
                    }
                }
                // lane cut2-66q2: the later reads' enumerated marks and the sweep's booleans.
                if o.get("wire").is_some() {
                    seen.insert("wire".into(), enum_of(&o["wire"], &WIRES));
                }
                if o["durability"].is_object() {
                    seen.insert(
                        "durability".into(),
                        enum_of(&o["durability"]["durability"], &DURABILITY),
                    );
                }
                if o["sweep"].is_object() {
                    seen.insert("sweep".into(), flags(&o["sweep"]));
                }
                p["observed"] = Value::Object(seen);
                if r.get("stage").is_some() {
                    p["stage"] = enum_of(&r["stage"], &road::REVALIDATION_STAGES);
                }
                // lane cut2-66q4: the settings row's overlay hash and the step a no-verdict ended at.
                if r["restart"].is_object() {
                    p["restart"] = json!({"overlay_sha256":hash(&r["restart"]["overlay_sha256"]),"failed_at":enum_of(&r["restart"]["failed_at"], &RESTART_STEPS)});
                }
                if r["adjudication"].is_object() {
                    p["adjudication"] = json!({"class":r["adjudication"]["class"],"ruling":r["adjudication"]["ruling"]});
                }
                for k in ["diverging_fields", "diverging_steps", "judged_fields"] {
                    if r.get(k).is_some() {
                        p[k] = r[k].clone();
                    }
                }
            }
            out.push(p);
        }
        families.insert(family.clone(), json!(out));
    }
    let steps: Vec<Value> = column["status_witnesses"]["steps"]
        .as_array()
        .into_iter()
        .flatten()
        .map(|s| {
            json!({"witness":s["witness"],"verdict":enum_of(&s["verdict"], &VERDICTS),"expected_value":s["expected"]["value"],
                "observed_equals_expected":s["observed"]["value"] == s["expected"]["value"]})
        })
        .collect();
    let i = &column["instance"];
    let peer = &column["road"]["peer"];
    json!({"record":column["record"],"run_id":column["run_id"],"base_commit":column["base_commit"],
        "started_utc":column["started_utc"],"wall_seconds":column["wall_seconds"],"full_receipt":column["full_receipt"],
        "quarantine":"the full receipt, the peer receipts, the instance's data and every output of the run are closed to model turns (lane cut2-66q, the quarantine rule); this page carries counts, enumerated verdicts and classes, row ids, hashes and paths only",
        "instance":{"tag":i["tag"],"pin":i["pin"],"binary_sha256":i["binary_sha256"],"funding_height":i["funding_height"],
            "tip_end":{"height":i["tip_end"]["height"],"hash":hash(&i["tip_end"]["hash"])}},
        "recipe":{"recipe":column["recipe"]["recipe"],"settings_local_sha256":hash(&column["recipe"]["settings_local_sha256"]),"sha256":hash(&column["recipe"]["sha256"]),"services":column["recipe"]["services"]},
        "road":{"connections":peer["connections"],"events":peer["events"],"ends":peer["ends"].as_array().map(Vec::len),"port":peer["port"],"protocol_version":peer["protocol_version"],
            "rows":column["road"]["log"].as_array().into_iter().flatten().map(|l| json!({"row":l["row"],"verdict":enum_of(&l["verdict"], &VERDICTS)})).collect::<Vec<_>>()},
        "counts":column["counts"].as_object().into_iter().flatten().map(|(k, v)| (k.clone(), numbers(v))).collect::<serde_json::Map<String, Value>>(),
        "totals":numbers(&column["totals"]),
        "status_witnesses":{"counts":numbers(&column["status_witnesses"]["counts"]),"steps":steps},
        "scenarios":column["scenarios"].as_array().into_iter().flatten().map(|sc| json!({"scenario":sc["scenario"],"counts":numbers(&sc["counts"]),
            "steps":sc["steps"].as_array().into_iter().flatten().filter(|s| s.get("verdict").is_some()).map(|s| json!({"id":s["id"],"trace":s["trace"],
                "verdict":enum_of(&s["verdict"], &VERDICTS),"diverging_fields":s["diverging_fields"]})).collect::<Vec<_>>()})).collect::<Vec<_>>(),
        "calls":column["calls"],"families":families,"source":column["source"],"rows_selected":column["rows_selected"]})
}

struct Well {
    funding: RawTx,
    next: u32,
    // #66 cut 2: the one coin of 4,000,000,000 satoshis (the P2P absurd-fee row).
    big: Option<(RawTx, u32)>,
}
impl Well {
    fn take(&mut self) -> u32 {
        self.next += 1;
        self.next - 1
    }
}

/// [D] 2026-10-15, lane cut2-66q2: the classifier as data for the scenario column (D83): the
/// table `harness/rules/second-oracle-scenarios.json` (S3's), read through `rules::RuleSet::load`
/// (every class a row names exists), names the class of a diverging row by its id
/// (`when.id_in`, the one key this table uses: `the_table_keys_rows_by_id_only`). Each diverging row
/// carries its `adjudication`: the class, its ruling and its citation, or `unexplained` (a
/// Finding drafted with the witness hash, rule 4). Returns the count of unexplained rows.
fn adjudicate(by: &mut BTreeMap<String, Vec<Value>>) -> Result<usize> {
    let table = bsv_script_harness::rules::RuleSet::load(Path::new("."), SCENARIO_RULES)?;
    let mut unexplained = 0;
    for r in by.values_mut().flatten() {
        if r["verdict"] != "diverge" {
            continue;
        }
        let id = r["id"].as_str().unwrap_or("").to_owned();
        let class = table.rows.iter().find_map(|row| {
            row.when
                .id_in
                .as_ref()
                .is_some_and(|ids| ids.contains(&id))
                .then(|| row.class.clone())
                .flatten()
        });
        r["adjudication"] = match class.map(|c| table.record(&c)) {
            Some(e) if e.rule != bsv_script_harness::rules::UNEXPLAINED => {
                json!({"class":e.rule,"ruling":e.ruling,"decided_by":e.decided_by,"table":format!("harness/rules/{SCENARIO_RULES}.json")})
            }
            _ => {
                unexplained += 1;
                json!({"class":bsv_script_harness::rules::UNEXPLAINED,"ruling":"open"})
            }
        };
    }
    Ok(unexplained)
}

/// The scenario column's classifier table under harness/rules/ (lane cut2-66q2).
const SCENARIO_RULES: &str = "second-oracle-scenarios";

pub(super) fn run(root: &Path) -> Result<Value> {
    let mut families = BTreeMap::new();
    let mut counts = BTreeMap::new();
    let mut realize = vec![];
    // lane cut2-66q4: the settings rows, each with its overlay (`overlay`, `settings_rows`).
    let mut restart = vec![];
    for family in FAMILIES {
        let mut out = vec![];
        for row in selected(family)? {
            // #66 cut 2: a row the road realizes is measured there (road.rs).
            if road::handles(family, &row) {
                continue;
            }
            if let Some(lines) = overlay(family, &row) {
                restart.push((row, lines));
                continue;
            }
            if let Some(reason) = pending(family, &row) {
                out.push(json!({"id":row["id"],"label":"[X]","pending":reason,"reference_token":row["node"]}));
                continue;
            }
            match unrealizable(family, &row) {
                Some(reason) => out.push(json!({"id":row["id"],"label":"[X]","unrealizable":reason,"reference_token":row["node"]})),
                None => realize.push(row.clone()),
            }
        }
        families.insert(family.to_owned(), out);
    }
    phase(root, "classified");
    let mut t = Tera::start(root.join("data"))?;
    phase(root, "started");
    // #66 cut 2: the road, on the second recipe only (the legacy bridge on, its listener on loopback).
    let recipe: Value = fs::read_to_string(root.join("data/instance.json"))
        .ok()
        .and_then(|s| serde_json::from_str(&s).ok())
        .unwrap_or(Value::Null);
    if recipe["recipe"] != "legacy" {
        return Err(format!(
            "cut 2's road needs the second recipe (INSTANCE41_RECIPE=legacy); the instance runs {}",
            recipe["recipe"]
        ));
    }
    // lane cut2-66q2: the bridge's peer from the start, and the short median rows on the fresh
    // chain before the prefix (road::median_rows).
    let mut b = bridge::Bridge::new(root.to_path_buf());
    let medians = road::median_rows(&mut t, &mut b, &selected("finality")?);
    phase(root, "median");
    let addr = address();
    let mut j = Journal::default();
    // The prefix: 101 blocks to the harness key; block 1's coinbase is mature at 101
    // (go-chaincfg v1.6.2 params.go:463). Its id is block 1's merkle root (one transaction).
    t.call("generatetoaddress", json!([101, addr]))?;
    let b1 = t.call("getblockbyheight", json!([1, 1]))?;
    let coin = RawTx::decode(
        &hex::decode(text(
            &t.call("getrawtransaction", json!([b1["merkleroot"], 0]))?,
        )?)
        .map_err(|e| e.to_string())?,
    )?;
    // One OP_TRUE (or the row's script) output per prevout the rows name, 64 more for
    // the witnesses, the change back to the key. Fee 100,000 satoshis.
    let mut outs = vec![];
    let mut slots: Vec<Vec<usize>> = vec![];
    for row in &realize {
        let mut s = vec![];
        for u in row["utxo"].as_array().into_iter().flatten() {
            s.push(outs.len());
            outs.push(RawOutput {
                satoshis: u["value"].as_u64().unwrap_or(1000),
                script: hex::decode(u["script"].as_str().unwrap_or("51"))
                    .map_err(|e| e.to_string())?,
            });
        }
        slots.push(s);
    }
    let witness_base = outs.len() as u32;
    // 64 coins for the witnesses and ROAD_COINS for cut 2's road, then its 4e9 coin.
    for _ in 0..64 + ROAD_COINS {
        outs.push(RawOutput {
            satoshis: 100_000,
            script: vec![0x51],
        });
    }
    let big_vout = outs.len() as u32;
    outs.push(RawOutput {
        satoshis: 4_000_000_000,
        script: vec![0x51],
    });
    let spent: u64 = outs.iter().map(|o| o.satoshis).sum();
    outs.push(RawOutput {
        satoshis: coin.outputs[0].satoshis - spent - 100_000,
        script: script(),
    });
    let f = fan(&coin, 0, outs)?;
    let reply = submit(&mut t, &mut j, &f)?;
    if reply.get("error").is_some() {
        return Err(format!("funding refused: {reply}"));
    }
    let fb = t.mine_pending(1, &addr)?;
    phase(root, "funded");
    journal_blocks(&mut t, &mut j)?;
    let funding_height = t.tip()?.0;
    let mut well = Well {
        funding: f.clone(),
        next: witness_base,
        big: Some((f.clone(), big_vout)),
    };
    // The admission rows, each frame exact except its remapped outpoints.
    let mut measured_rows = vec![];
    for (row, slot) in realize.iter().zip(&slots) {
        let offset = t.calls.len();
        let mut points: Points = BTreeMap::new();
        for (u, k) in row["utxo"].as_array().into_iter().flatten().zip(slot) {
            let h: [u8; 32] = hex::decode(text(&u["hash"])?)
                .map_err(|e| e.to_string())?
                .try_into()
                .map_err(|_| "utxo hash")?;
            points.insert(
                (h, u["index"].as_u64().unwrap_or(0) as u32),
                (f.txid_internal(), *k as u32),
            );
        }
        let remap = |tx: &mut RawTx, points: &Points| {
            for input in &mut tx.inputs {
                if let Some((h, i)) = points.get(&(input.txid, input.vout)) {
                    input.txid = *h;
                    input.vout = *i;
                }
            }
        };
        let decode = |v: &Value| -> Result<RawTx> {
            RawTx::decode(&hex::decode(text(v)?).map_err(|e| e.to_string())?)
        };
        let mut setup = vec![];
        for entry in row["pool"]["accepted"].as_array().into_iter().flatten() {
            let old = decode(&entry["tx"])?;
            let mut p = old.clone();
            remap(&mut p, &points);
            let r = submit(&mut t, &mut j, &p)?;
            if r.get("error").is_some() {
                return Err(format!("{}: pool setup refused: {r}", row["id"]));
            }
            t.settle_in_pool(&id(&p))?;
            for k in 0..p.outputs.len() as u32 {
                points.insert((old.txid_internal(), k), (p.txid_internal(), k));
            }
            setup.push(material(&p));
        }
        let mut tx = decode(&row["tx"])?;
        remap(&mut tx, &points);
        let reply = submit(&mut t, &mut j, &tx)?;
        let in_pool = reply.get("error").is_none() && t.settle_in_pool(&id(&tx))?;
        let observed = match reply.get("error") {
            Some(e) => {
                json!({"status":"rejected","namespace":"teranode-rpc","code":e["code"],"word":verdict_word(e["message"].as_str().unwrap_or("")),"message":e["message"]})
            }
            None if in_pool => json!({"status":"accepted"}),
            None => json!({"status":"accepted-not-in-assembly"}),
        };
        let e = &row["expected"];
        let stage = row["boundary"].as_str().unwrap_or("");
        let same = observed["status"] == e["status"];
        let policy = POLICY_STAGES.iter().find(|(s, _)| *s == stage);
        // The reference answered this row from its RPC precheck, ahead of validation: the class the
        // SV column counts beside measured (its reference token `rpc-precheck: ...`), never inside it.
        let precheck = row["node"]
            .as_str()
            .is_some_and(|t| t.starts_with("rpc-precheck:"));
        let verdict = if precheck {
            "rpc-precheck"
        } else if same {
            "agree"
        } else if policy.is_some() {
            "non-judging"
        } else {
            "diverge"
        };
        let mut r = json!({"id":row["id"],"label":"[X]","verdict":verdict,"expected":{"status":e["status"],"reason":e["reason"],"stage":stage},"expected_label":"[D]","observed":observed,
            "comparison_scope":"the admission verdict (TxVerdict, DESIGN-S6 2.1: accepted, rejected, heldNonFinal); the reason is recorded in both namespaces and never compared: every refusal of a decodable transaction is -25 on Teranode's RPC (services/rpc/handlers.go:900-904,913-916,926-930)",
            "recipe":"Fund the row's prevouts as outputs of one funding transaction mined at the funding height, remap the outpoints (and any accepted parent's, submitted before the row), submit the exact frame through sendrawtransaction, read block assembly (getrawmempool, the placeholder node removed) for up to 10 s",
            "fixtures":{"transaction":material(&tx),"original_transaction":row["tx"],"setup_transactions":setup},"reference_token":row["node"],"rpc":t.calls[offset..].to_vec()});
        if let (true, Some((_, design_row))) = (verdict == "non-judging", policy) {
            r["qualifier"] = json!(if e["status"] == "heldNonFinal" {
                "policy: the hold, DESIGN-S6 2.1 row 3".to_owned()
            } else {
                format!("policy stage {stage}, DESIGN-S6 2.1 {design_row}: the second oracle's defaults are never the rule")
            });
        }
        if precheck {
            r["qualifier"] = json!("the reference's RPC precheck answered it ahead of validation (src/rpc/rawtransaction.cpp:1598-1664 at 6504a3af); a node fact (DESIGN-S6 2.1 row 4), counted beside measured as the SV column counts it");
        }
        measured_rows.push(r);
    }
    phase(root, "admission");
    // The eight status-class witnesses of #67, each establishing its class on the instance.
    let mut steps = vec![];
    // The expected value is the driver's expectation from the SV witness of that value
    // (corpus/scenarios/2026-10-13-status-view-<value>.md), not derived through the evaluator.
    let mut step = |t: &mut Tera,
                    j: &Journal,
                    name: &str,
                    id_: &str,
                    expected: Value,
                    establish: &str,
                    note: &str|
     -> Result<()> {
        let observed = derive(t, j, id_)?;
        let same = observed["value"] == expected["value"]
            && (expected["height"].is_null() || observed["height"] == expected["height"]);
        let value = expected["value"].as_str().unwrap_or("");
        let sv = if name.starts_with("orphan") {
            "orphan"
        } else if name.starts_with("onStaleBranch") {
            "onStaleBranch"
        } else {
            value
        };
        // Holding a non-final transaction is policy (DESIGN-S6 2.1 row 3): a difference there is non-judging.
        let verdict = if same {
            "agree"
        } else if value == "heldNonFinal" {
            "non-judging"
        } else {
            "diverge"
        };
        let mut s = json!({"witness":name,"txid":id_,"establish":establish,"expected":expected,
            "expected_label":format!("the driver's expectation from the SV witness corpus/scenarios/2026-10-13-status-view-{sv}.md"),"observed":observed,"verdict":verdict,"note":note});
        if verdict == "non-judging" {
            s["qualifier"] = json!("policy: the hold, DESIGN-S6 2.1 row 3");
        }
        steps.push(s);
        Ok(())
    };
    // unknown: a signed spend never submitted.
    let k = well.take();
    let ghost = op_true_spend(&well.funding, k, 99_000, 0, u32::MAX);
    j.seen.insert(id(&ghost), ghost.clone());
    step(
        &mut t,
        &j,
        "unknown",
        &id(&ghost),
        json!({"value":"unknown"}),
        "a transaction built and never submitted",
        "no positive match in the journal or the node",
    )?;
    j.seen.remove(&id(&ghost));
    // rejected: the input-empty frame (the reference's 16 bad-txns-vin-empty).
    let empty = RawTx {
        version: 1,
        inputs: vec![],
        outputs: vec![RawOutput {
            satoshis: 1000,
            script: vec![0x51],
        }],
        lock_time: 0,
    };
    submit(&mut t, &mut j, &empty)?;
    step(
        &mut t,
        &j,
        "rejected",
        &id(&empty),
        json!({"value":"rejected"}),
        "submit an input-empty transaction",
        "the class is judged; the reason's namespace is Teranode's",
    )?;
    // orphan: on RPC both nodes answer an error; the retained orphan needs the legacy P2P bridge.
    let k = well.take();
    let absent_parent = op_true_spend(&well.funding, k, 99_000, 0, u32::MAX);
    let child = op_true_spend(&absent_parent, 0, 98_000, 0, u32::MAX);
    submit(&mut t, &mut j, &child)?;
    step(&mut t, &j, "orphan (RPC path)", &id(&child), json!({"value":"rejected"}), "submit a child whose parent was never submitted",
        "the reference's RPC path keeps no orphan either (DESIGN-S6 5.1); the retained orphan class is unrealizable here: the legacy bridge's netsync map (services/legacy/netsync/manager.go:487,1335-1352) has no surface and the bridge is off")?;
    // inMempool, then minedActive.
    let k = well.take();
    let tm = op_true_spend(&well.funding, k, 99_000, 0, u32::MAX);
    submit(&mut t, &mut j, &tm)?;
    t.settle_in_pool(&id(&tm))?;
    step(
        &mut t,
        &j,
        "inMempool",
        &id(&tm),
        json!({"value":"inMempool"}),
        "submit a valid spend of a mined OP_TRUE output",
        "block assembly lists it",
    )?;
    // heldNonFinal: a height lock two blocks ahead, sequence zero.
    let (tip, _) = t.tip()?;
    let k = well.take();
    let th = op_true_spend(&well.funding, k, 99_000, tip as u32 + 2, 0);
    submit(&mut t, &mut j, &th)?;
    step(&mut t, &j, "heldNonFinal", &id(&th), json!({"value":"heldNonFinal"}), "submit a spend with lockTime tip+2 and sequence zero",
        "the reference holds it in the non-final pool; Teranode has no such pool (services/validator/Validator.go:976-983)")?;
    // conflictedByMinedSpend: a spend mined, then a second spend of the same output.
    let k = well.take();
    let ta = op_true_spend(&well.funding, k, 99_000, 0, u32::MAX);
    let tb = op_true_spend(&well.funding, k, 98_000, 0, u32::MAX);
    submit(&mut t, &mut j, &ta)?;
    t.settle_in_pool(&id(&ta))?;
    let pending = t.pool()?.len() as u64;
    let mined = t.mine_pending(pending, &addr)?;
    journal_blocks(&mut t, &mut j)?;
    let (h_mined, _) = t.tip()?;
    step(
        &mut t,
        &j,
        "minedActive",
        &id(&tm),
        json!({"value":"minedActive","height":h_mined}),
        "mine the next block (generatetoaddress after the candidate counts the pool)",
        "the store's block hashes and getblock's confirmations",
    )?;
    submit(&mut t, &mut j, &tb)?;
    step(
        &mut t,
        &j,
        "conflictedByMinedSpend",
        &id(&tb),
        json!({"value":"conflictedByMinedSpend"}),
        "after a spend of F:k is mined, submit a second spend of F:k",
        "the spender read from the asset utxos route (spendingData) and its active block",
    )?;
    // onStaleBranch: mine T in a block A, invalidate A.
    let k = well.take();
    let ts = op_true_spend(&well.funding, k, 99_000, 0, u32::MAX);
    submit(&mut t, &mut j, &ts)?;
    t.settle_in_pool(&id(&ts))?;
    let pending = t.pool()?.len() as u64;
    let a = t.mine_pending(pending.max(1), &addr)?;
    journal_blocks(&mut t, &mut j)?;
    let inval = t.receipt("invalidateblock", json!([a]))?;
    thread::sleep(Duration::from_secs(3));
    let readmitted = t.settle_in_pool(&id(&ts))?;
    step(&mut t, &j, "onStaleBranch (after invalidation)", &id(&ts), json!({"value":"inMempool"}),
        "mine T in block A, invalidateblock A, read the pool",
        "the reference re-admits a disconnected transaction (corpus/scenarios/2026-10-13-status-view-onStaleBranch.md: 'Invalidate A; T is re-admitted'), and inMempool stands above onStaleBranch in section 3's order; the SV witness then empties the pool on the mock clock, which has no Teranode surface (setmocktime absent), so the onStaleBranch value itself is unrealizable here and A's off-active inclusion is read from the journal")?;
    let stale_probe = json!({"invalidateblock":inval,"readmitted":readmitted,"block_a":a,"block_a_active":t.on_active(&a)?});
    phase(root, "witnesses");
    let (mut road_rows, road_receipt) = {
        let mut r = road::Road {
            t: &mut t,
            b,
            well: &mut well,
            addr: addr.clone(),
            log: vec![],
            started: Instant::now(),
        };
        road::run(&mut r)?
    };
    road_rows
        .entry("finality".to_owned())
        .or_default()
        .extend(medians);
    let (tip_end, tip_hash) = t.tip()?;
    let chaintips = t.receipt("getchaintips", json!([]))?;
    t.stop()?;
    phase(root, "stopped");
    let mut calls = std::mem::take(&mut t.calls);
    // lane cut2-66q4: the settings rows, each on its own instance after the column's has stopped.
    let (settings_measured, settings_calls) = settings_rows(root, &restart, &addr);
    calls.extend(settings_calls);
    phase(root, "settings");
    // Every measured row by family: the RPC rows (mempool) and the road's.
    let mut measured_by: BTreeMap<String, Vec<Value>> = road_rows;
    measured_by
        .entry("mempool".to_owned())
        .or_default()
        .extend(measured_rows.iter().cloned().chain(settings_measured));
    let unexplained = adjudicate(&mut measured_by)?;
    let mut pending_total = 0;
    let mut totals = BTreeMap::new();
    for (family, out) in families.iter_mut() {
        let rows = selected(family)?.len();
        let pend = out.iter().filter(|r| r.get("pending").is_some()).count();
        let un = out
            .iter()
            .filter(|r| r.get("unrealizable").is_some())
            .count();
        pending_total += pend;
        let mine = measured_by.remove(family).unwrap_or_default();
        let of = |v: &str| mine.iter().filter(|r| r["verdict"] == v).count();
        let (agree, diverge, non_judging) = (of("agree"), of("diverge"), of("non-judging"));
        for (k, v) in [
            ("agree", agree),
            ("diverge", diverge),
            ("non-judging", non_judging),
            ("rpc-precheck", of("rpc-precheck")),
            ("no-verdict", of("no-verdict")),
        ] {
            *totals.entry(k).or_insert(0) += v;
        }
        counts.insert(family.clone(), json!({"label":"[M]","rows":rows,"measured":agree + diverge + non_judging,"agree":agree,"diverge":diverge,"non-judging":non_judging,"rpc-precheck":of("rpc-precheck"),"no-verdict":of("no-verdict"),"pending":pend,"unrealizable":un}));
        out.extend(mine);
    }
    if let Some((family, _)) = measured_by.iter().next() {
        return Err(format!("measured rows of an unknown family {family}"));
    }
    let total = |k: &str| totals.get(k).copied().unwrap_or(0);
    let (agree, diverge, non_judging, precheck) = (
        total("agree"),
        total("diverge"),
        total("non-judging"),
        total("rpc-precheck"),
    );
    let realized = agree + diverge + non_judging;
    let of_steps = |v: &str| steps.iter().filter(|s| s["verdict"] == v).count();
    let witness_counts = json!({"label":"[M]","steps":steps.len(),"agree":of_steps("agree"),"diverge":of_steps("diverge"),"non-judging":of_steps("non-judging")});
    Ok(
        json!({"instance":{"tag":TTAG,"pin":TPIN,"binary_sha256":client::BINARY_SHA256,"data":pointer(&root.join("data")),"funding":material(&f),"funding_block":fb,"funding_height":funding_height,
        "witness_block":mined,"tip_end":{"height":tip_end,"hash":tip_hash},"chaintips_cached_300s":chaintips,"stale_probe":stale_probe},
        "counts":counts,"totals":{"label":"[M]","measured":realized,"agree":agree,"diverge":diverge,"diverge-unexplained":unexplained,"non-judging":non_judging,"rpc-precheck":precheck,"no-verdict":total("no-verdict"),"pending":pending_total},"road":road_receipt,"recipe":recipe,
        "families":families,"status_witnesses":{"counts":witness_counts,"steps":steps},"scenarios":road_receipt["scenarios"],"calls":calls.len(),"rpc":calls,"source":SRC,
        "rows_selected":selection().map(|s| s.into_iter().collect::<Vec<_>>())}),
    )
}

/// The steps of a settings row, enumerated for the projection (lane cut2-66q4).
const RESTART_STEPS: [&str; 6] = ["start", "prefix", "fund", "stop", "restart", "submit"];

/// [D] 2026-10-15, lane cut2-66q4 (#66 cut 2, the settings restarts): each row of `restart` on
/// its own instance (a fresh data directory beside the column's, under the run's root): start
/// the recipe, mine 101 blocks to the harness key, fund the row's prevouts as outputs of one
/// transaction spending block 1's coinbase (mature at 101, go-chaincfg v1.6.2 params.go:463),
/// mine it, stop; write the row's overlay as overlay.conf in the data directory (instance.py
/// appends it after the recipe's settings) and start again on the same data; submit the
/// row's exact frame, its outpoints remapped, through sendrawtransaction (with allowhighfees
/// when the row's request is absurdFee 0), read block assembly for up to 10 s, stop. Judged as
/// the column's admission rows: a difference at a policy stage is non-judging. A step that
/// fails gives the row no-verdict with the step's name.
fn settings_rows(root: &Path, rows: &[(Value, String)], addr: &str) -> (Vec<Value>, Vec<Value>) {
    let mut out = vec![];
    let mut calls = vec![];
    for (i, (row, lines)) in rows.iter().enumerate() {
        let dir = root.join(format!("data-settings-{i:02}"));
        let mut step = "start";
        let mut held: Option<Tera> = None;
        let r = (|| -> Result<Value> {
            let t = held.insert(Tera::start(dir.clone())?);
            step = "prefix";
            t.call("generatetoaddress", json!([101, addr]))?;
            let b1 = t.call("getblockbyheight", json!([1, 1]))?;
            let coin = RawTx::decode(
                &hex::decode(text(
                    &t.call("getrawtransaction", json!([b1["merkleroot"], 0]))?,
                )?)
                .map_err(|e| e.to_string())?,
            )?;
            step = "fund";
            let mut outs = vec![];
            for u in row["utxo"].as_array().into_iter().flatten() {
                outs.push(RawOutput {
                    satoshis: u["value"].as_u64().unwrap_or(1000),
                    script: hex::decode(u["script"].as_str().unwrap_or("51"))
                        .map_err(|e| e.to_string())?,
                });
            }
            let spent: u64 = outs.iter().map(|o| o.satoshis).sum();
            outs.push(RawOutput {
                satoshis: coin.outputs[0].satoshis - spent - 100_000,
                script: script(),
            });
            let f = fan(&coin, 0, outs)?;
            let reply = t.receipt("sendrawtransaction", json!([hex::encode(f.encode())]))?;
            if reply.get("error").is_some() {
                return Err("funding refused".into());
            }
            t.settle_in_pool(&id(&f))?;
            t.mine_pending(1, addr)?;
            step = "stop";
            t.stop()?;
            fs::write(dir.join("overlay.conf"), lines).map_err(|e| e.to_string())?;
            step = "restart";
            t.restart()?;
            step = "submit";
            let mut tx =
                RawTx::decode(&hex::decode(text(&row["tx"])?).map_err(|e| e.to_string())?)?;
            for (u, k) in row["utxo"].as_array().into_iter().flatten().zip(0u32..) {
                let h: [u8; 32] = hex::decode(text(&u["hash"])?)
                    .map_err(|e| e.to_string())?
                    .try_into()
                    .map_err(|_| "utxo hash")?;
                let at = (h, u["index"].as_u64().unwrap_or(0) as u32);
                for input in &mut tx.inputs {
                    if (input.txid, input.vout) == at {
                        input.txid = f.txid_internal();
                        input.vout = k;
                    }
                }
            }
            let params = if bypass(row) {
                json!([hex::encode(tx.encode()), true])
            } else {
                json!([hex::encode(tx.encode())])
            };
            let reply = t.receipt("sendrawtransaction", params)?;
            let in_pool = reply.get("error").is_none() && t.settle_in_pool(&id(&tx))?;
            let observed = match reply.get("error") {
                Some(e) => {
                    json!({"status":"rejected","namespace":"teranode-rpc","code":e["code"],"word":verdict_word(e["message"].as_str().unwrap_or("")),"message":e["message"]})
                }
                None if in_pool => json!({"status":"accepted"}),
                None => json!({"status":"accepted-not-in-assembly"}),
            };
            t.stop()?;
            let e = &row["expected"];
            let stage = row["boundary"].as_str().unwrap_or("");
            let policy = POLICY_STAGES.iter().find(|(s, _)| *s == stage);
            let verdict = if observed["status"] == e["status"] {
                "agree"
            } else if policy.is_some() {
                "non-judging"
            } else {
                "diverge"
            };
            let mut r = json!({"id":row["id"],"label":"[X]","verdict":verdict,"expected":{"status":e["status"],"reason":e["reason"],"stage":stage},"expected_label":"[D]","observed":observed,
                "comparison_scope":"the admission verdict (TxVerdict, DESIGN-S6 2.1), as the column's admission rows",
                "recipe":"settings_rows (lane cut2-66q4): a fresh instance funded on the recipe's settings, restarted on the same data with the row's overlay, the exact frame submitted",
                "restart":{"overlay":lines,"overlay_sha256":hex::encode(bsv_rs::primitives::hash::sha256(lines.as_bytes())),"data":pointer(&dir)},
                "fixtures":{"funding":material(&f),"transaction":material(&tx),"original_transaction":row["tx"]},"reference_token":row["node"]});
            if let (true, Some((_, design_row))) = (verdict == "non-judging", policy) {
                r["qualifier"] = json!(format!("policy stage {stage}, DESIGN-S6 2.1 {design_row}: the second oracle's defaults are never the rule"));
            }
            Ok(r)
        })();
        let mut r = match r {
            Ok(r) => r,
            Err(e) => {
                json!({"id":row["id"],"label":"[X]","verdict":"no-verdict","observed":{"status":"no-verdict","error":e},"expected":row["expected"],"expected_label":"[D]",
                    "restart":{"failed_at":step,"overlay":lines,"overlay_sha256":hex::encode(bsv_rs::primitives::hash::sha256(lines.as_bytes())),"data":pointer(&dir)},"reference_token":row["node"]})
            }
        };
        if let Some(mut t) = held.take() {
            let _ = t.stop();
            r["rpc"] = json!(t.calls.clone());
            calls.append(&mut t.calls);
        }
        phase(root, &format!("settings-{i:02}"));
        out.push(r);
    }
    (out, calls)
}

#[cfg(test)]
mod lane {
    use super::*;

    /// lane cut2-66q2: the scenario column's table loads (every class a row names exists), keys
    /// its rows by id alone, and names only rows of the corpus.
    #[test]
    fn the_table_keys_rows_by_id_only() -> Result<()> {
        let root = Path::new(env!("CARGO_MANIFEST_DIR")).join("..");
        let table = bsv_script_harness::rules::RuleSet::load(&root, SCENARIO_RULES)?;
        let raw: Value = serde_json::from_str(
            &fs::read_to_string(root.join(format!("harness/rules/{SCENARIO_RULES}.json")))
                .map_err(|e| e.to_string())?,
        )
        .map_err(|e| e.to_string())?;
        let mut ids = BTreeSet::new();
        for family in FAMILIES {
            let text =
                fs::read_to_string(root.join(format!("corpus/chain/{family}/{family}.jsonl")))
                    .map_err(|e| e.to_string())?;
            for line in text.lines() {
                let row: Value = serde_json::from_str(line).map_err(|e| e.to_string())?;
                ids.insert(row["id"].as_str().unwrap_or("").to_owned());
            }
        }
        for (row, json_row) in table
            .rows
            .iter()
            .zip(raw["rows"].as_array().into_iter().flatten())
        {
            let keys: Vec<&String> = json_row["when"]
                .as_object()
                .into_iter()
                .flatten()
                .map(|(k, _)| k)
                .collect();
            if keys != ["id_in"] {
                return Err(format!("a row keyed by {keys:?}, not id_in alone"));
            }
            if row.class.is_none() {
                return Err("a row names no class".into());
            }
            for id in row.when.id_in.iter().flatten() {
                if !ids.contains(id) {
                    return Err(format!("{id} is no row of the corpus"));
                }
            }
        }
        Ok(())
    }
}
