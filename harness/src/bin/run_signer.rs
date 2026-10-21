//! The signer column (#145, #147): foreground adapters, an owned regtest node, and
//! per-input judgments with the supplied synthetic prevouts. No transaction is sent.
//! The hand signer and scriptCodes are the corpus self-check's control. The node
//! decides both sides, under the same block/relay words from FlagsOracle.

use std::collections::{BTreeMap, BTreeSet};
use std::path::{Path, PathBuf};
use std::process::Command;

use bsv_rs::primitives::bsv::sighash::{build_sighash_preimage, SighashParams};
use bsv_rs::primitives::hash::sha256;
use bsv_script_harness::cases::sighash_parts;
use bsv_script_harness::corpus::ExpectJson;
use bsv_script_harness::flags_oracle::FlagsOracle;
use bsv_script_harness::rules::{self, RuleSet, UNEXPLAINED};
use bsv_script_harness::signer::{load_rules as table, sign_input, Row, SiteDigest};
#[cfg(test)]
use bsv_script_harness::signer_node::Trace;
use bsv_script_harness::signer_node::{
    adapter, decode, file_hash, output, read, write_json, Node, RunDir, Signed, Verdict, ENGINES,
    METHODS,
};
#[cfg(test)]
use bsv_script_harness::{engines::GO_SDK_VERSION, BSV_RS_VERSION};
use serde::Serialize;
use serde_json::{json, Value};

type Result<T> = std::result::Result<T, String>;
/// #148 (d-bis): bsv-rs 0.7.0 also signs through its public scriptCode override.
const BSVRS_METHODS: [&str; 4] = [
    "template",
    "api-default",
    "api-scriptcode",
    "api-context-scriptcode",
];
fn methods(engine: &str) -> &'static [&'static str] {
    if engine == "bsv-rs" {
        &BSVRS_METHODS
    } else {
        &METHODS
    }
}
fn explicit_scriptcode(engine: &str, method: &str) -> bool {
    engine == "bsv-rs" && matches!(method, "api-scriptcode" | "api-context-scriptcode")
}
#[cfg(test)]
const LOCK_ONLY: &str = "sighash.scriptcode.in-unlock.lock-only";
const SINGLE: &str = "sighash.single.out-of-range.one";

fn txid(tx: &str) -> Result<String> {
    let bytes = hex::decode(tx).map_err(|e| e.to_string())?;
    let mut hash = sha256(&sha256(&bytes));
    hash.reverse();
    Ok(hex::encode(hash))
}

struct Case {
    row: Row,
    control: String,
    digests: BTreeMap<(usize, usize), SiteDigest>,
    words: [Vec<u32>; 2],
}

fn cases(root: &Path, oracle: &mut FlagsOracle) -> Result<Vec<Case>> {
    let dir = root.join("corpus/signer");
    let manifest: Value =
        serde_json::from_str(&read(&dir.join("manifest.json"))?).map_err(|e| e.to_string())?;
    let mut files: Vec<_> = std::fs::read_dir(&dir)
        .map_err(|e| e.to_string())?
        .filter_map(|p| p.ok().map(|p| p.path()))
        .filter(|p| p.extension().is_some_and(|x| x == "jsonl"))
        .collect();
    files.sort();
    let listed = manifest["files"]
        .as_array()
        .ok_or("manifest files absent")?;
    if listed.len() != files.len() || files.is_empty() {
        return Err("signer manifest file coverage differs".into());
    }
    let mut cases = Vec::new();
    let mut ids = BTreeSet::new();
    for path in files {
        let text = read(&path)?;
        let name = path
            .file_name()
            .and_then(|x| x.to_str())
            .ok_or("corpus filename")?;
        let meta = listed
            .iter()
            .find(|x| x["file"] == name)
            .ok_or("unlisted corpus file")?;
        if meta["sha256"] != hex::encode(sha256(text.as_bytes())) {
            return Err(format!("corpus hash differs: {name}"));
        }
        let lines: Vec<_> = text.lines().filter(|x| !x.trim().is_empty()).collect();
        if meta["count"].as_u64() != Some(lines.len() as u64) {
            return Err(format!("corpus row count differs: {name}"));
        }
        for line in lines {
            let row: Row = serde_json::from_str(line).map_err(|e| e.to_string())?;
            row.entry.check()?;
            if !ids.insert(row.entry.id.clone()) {
                return Err("duplicate corpus id".into());
            }
            let raw = decode(&row.entry.tx)?;
            if raw.inputs.len() != row.signing.inputs.len()
                || raw.inputs.iter().any(|i| !i.script.is_empty())
                || raw.version != row.signing.version
                || raw.lock_time != row.signing.locktime
            {
                return Err("signing metadata differs from unsigned transaction".into());
            }
            let mut signed = raw.clone();
            let mut digests = BTreeMap::new();
            let mut words = [Vec::new(), Vec::new()];
            for (i, si) in row.signing.inputs.iter().enumerate() {
                if si.index != i
                    || si.sequence != raw.inputs[i].sequence
                    || si.scriptcode_hex.is_empty()
                {
                    return Err("signing input index, sequence or scriptCode invalid".into());
                }
                let p = &row.entry.prevouts[i];
                let (unlock, sites) = sign_input(&raw, p.satoshis, si, None)?;
                signed.inputs[i].script = unlock;
                for s in sites {
                    digests.insert((i, s.site), s);
                }
                words[0].push(match &row.entry.flags {
                    Some(f) => f[i],
                    None => oracle.word(
                        row.entry.params.spend_height,
                        p.height,
                        row.entry.params.consensus,
                    )?,
                });
                words[1].push(oracle.word(row.entry.params.spend_height, p.height, false)?);
            }
            cases.push(Case {
                row,
                control: hex::encode(signed.encode()),
                digests,
                words,
            });
        }
    }
    Ok(cases)
}

fn validate(signed: &Signed, case: &Case) -> Result<()> {
    let Some(tx) = &signed.tx_hex else {
        return if signed.note.trim().is_empty() {
            Err("unsigned row has no reason".into())
        } else {
            Ok(())
        };
    };
    let mut raw = decode(tx)?;
    for input in &mut raw.inputs {
        input.script.clear();
    }
    if raw != decode(&case.row.entry.tx)? {
        return Err("adapter changed the unsigned transaction".into());
    }
    let mut keys = BTreeSet::new();
    for trace in &signed.inputs {
        if !keys.insert((trace.index, trace.site))
            || !case.digests.contains_key(&(trace.index, trace.site))
        {
            return Err("adapter has duplicate or extra site trace".into());
        }
        for h in [
            &trace.preimage_hex,
            &trace.digest_hex,
            &trace.scriptcode_used_hex,
        ] {
            hex::decode(h).map_err(|_| "adapter trace contains invalid hex")?;
        }
        if trace.digest_hex.len() != 64 {
            return Err("adapter digest length".into());
        }
    }
    if keys != case.digests.keys().copied().collect() {
        return Err("adapter omitted a site trace".into());
    }
    Ok(())
}

fn consistent(signed: &Signed, case: &Case) -> bool {
    signed.tx_hex.is_some()
        && signed.inputs.len() == case.digests.len()
        && signed.inputs.iter().all(|t| {
            case.digests
                .get(&(t.index, t.site))
                .is_some_and(|c| c.digest_hex == t.digest_hex)
        })
}

/// The classifier's native field holds these measured predicates, never node text.
/// Selection still requires the table's method, control verdict and reject token.
fn markers(case: &Case, signed: &Signed, index: usize) -> Result<String> {
    let si = &case.row.signing.inputs[index];
    let traces: Vec<_> = signed.inputs.iter().filter(|t| t.index == index).collect();
    let mut markers = Vec::new();
    if si.template.starts_with("checksig-in-unlock-")
        && traces.iter().any(|t| {
            t.scriptcode_used_hex == case.row.entry.prevouts[index].script
                && case.digests[&(index, t.site)].scriptcode_hex != t.scriptcode_used_hex
                && case.digests[&(index, t.site)].digest_hex != t.digest_hex
        })
    {
        markers.push("lock-only");
    }
    let one = format!("01{}", "00".repeat(31));
    if si.sighash_type & 0x1f == 3
        && traces
            .iter()
            .any(|t| case.digests[&(index, t.site)].digest_hex == one && t.digest_hex != one)
    {
        markers.push("single-one-mismatch");
    }
    if signed.engine == "bsv-rs" && si.sighash_type & 0x20 != 0 {
        let tx = decode(&case.row.entry.tx)?;
        let (inputs, outputs) = sighash_parts(&tx);
        for t in &traces {
            let ctl = &case.digests[&(index, t.site)];
            // Isolate dispatch from scriptCode selection: this marker requires
            // the correct scriptCode and the exact library BIP143 preimage.
            if t.scriptcode_used_hex != ctl.scriptcode_hex || t.digest_hex == ctl.digest_hex {
                continue;
            }
            let code = hex::decode(&t.scriptcode_used_hex).map_err(|e| e.to_string())?;
            let pre = build_sighash_preimage(&SighashParams {
                version: tx.version,
                inputs: &inputs,
                outputs: &outputs,
                locktime: tx.lock_time,
                input_index: index,
                subscript: &code,
                satoshis: case.row.entry.prevouts[index].satoshis,
                scope: si.sighash_type,
            });
            if t.preimage_hex == hex::encode(&pre)
                && t.digest_hex == hex::encode(sha256(&sha256(&pre)))
            {
                markers.push("chronicle-bip143");
                break;
            }
        }
    }
    Ok(markers.join(" "))
}

fn classify(
    table: &RuleSet,
    case: &Case,
    signed: &Signed,
    index: usize,
    control: &Verdict,
    node: &Verdict,
) -> Result<Option<String>> {
    if node.verdict == "valid" && control.verdict == "valid" {
        return Ok(None);
    }
    let observation = rules::observe(
        &case.row.entry,
        &decode(signed.tx_hex.as_deref().ok_or("unsigned")?)?,
        &signed.method,
        &control.verdict,
        control.code.as_deref(),
        &node.verdict,
        node.code.as_deref(),
        &markers(case, signed, index)?,
    );
    Ok(Some(
        table
            .explain(&observation)
            .map(|x| x.rule)
            .unwrap_or_else(|| UNEXPLAINED.into()),
    ))
}

#[derive(Default, Serialize)]
struct Counts {
    signed: usize,
    valid: BTreeMap<String, usize>,
    refused: BTreeMap<String, BTreeMap<String, usize>>,
    unsigned: BTreeMap<String, usize>,
}

#[derive(Serialize)]
struct Record {
    label: &'static str,
    engine: String,
    pin: String,
    stamp: String,
    source_commit: String,
    source_sha256: BTreeMap<String, String>,
    runner_sha256: String,
    node_sha256: String,
    rpc_port: u16,
    rows: usize,
    traces_judged: usize,
    control_traces_judged: usize,
    digest_equal: usize,
    digest_unequal: usize,
    api_scriptcode_rows: usize,
    api_scriptcode_equal: usize,
    api_scriptcode_unequal: usize,
    context_scriptcode_rows: usize,
    context_scriptcode_equal: usize,
    context_scriptcode_unequal: usize,
    single_decisions: Vec<Value>,
    divergent: BTreeMap<String, usize>,
    red: usize,
    counts: BTreeMap<String, Counts>,
    words: Value,
    results: Vec<Value>,
    witnesses: BTreeMap<String, Value>,
    verdict_line: String,
}

fn measure(
    root: &Path,
    run: &Path,
    node: &mut Node,
    cases: &[Case],
    engine_pin: (&str, &str),
    stamp: &str,
    words: &Value,
) -> Result<Record> {
    let (engine, pin) = engine_pin;
    let table = table(root, engine, pin)?;
    let corpus: Vec<Row> = cases.iter().map(|c| c.row.clone()).collect();
    let rows = adapter(root, run, engine, &corpus, "corpus")?;
    let mut keyed = BTreeMap::new();
    for row in rows {
        if row.engine != engine
            || !methods(engine).contains(&row.method.as_str())
            || keyed
                .insert((row.id.clone(), row.method.clone()), row)
                .is_some()
        {
            return Err("adapter engine/method mismatch or duplicate row".into());
        }
    }
    let expected: BTreeSet<_> = cases
        .iter()
        .flat_map(|c| {
            methods(engine)
                .iter()
                .map(|m| (c.row.entry.id.clone(), m.to_string()))
        })
        .collect();
    if keyed.keys().cloned().collect::<BTreeSet<_>>() != expected {
        return Err("adapter row coverage differs from corpus times methods".into());
    }
    let mut record = Record {
        label: "[M]",
        engine: engine.into(),
        pin: pin.into(),
        stamp: stamp.into(),
        source_commit: output(
            Command::new("git")
                .args(["rev-parse", "HEAD"])
                .current_dir(root),
            "source commit",
        )?
        .trim()
        .into(),
        source_sha256: [
            "harness/src/bin/run_signer.rs",
            "harness/src/bin/signer_bsvrs.rs",
            "harness/src/signer.rs",
            "harness/src/rules.rs",
            "harness/src/flags_oracle.rs",
            "harness/src/svnode_codes.rs",
            "harness/Cargo.lock",
            "harness/oracle/bitcoin.conf",
            "corpus/signer/manifest.json",
            "harness/engines/go/signer/main.go",
            "harness/engines/go/go.sum",
            "harness/engines/ts/signer.mjs",
            "harness/engines/ts/package-lock.json",
            "harness/rules/go-sdk-signer.json",
            "harness/rules/ts-sdk-signer.json",
            "harness/rules/bsv-rs-signer.json",
        ]
        .into_iter()
        .map(|p| Ok((p.to_string(), file_hash(&root.join(p))?)))
        .collect::<Result<_>>()?,
        runner_sha256: file_hash(&std::env::current_exe().map_err(|e| e.to_string())?)?,
        node_sha256: node.binary_sha256.clone(),
        rpc_port: node.port,
        rows: cases.len(),
        traces_judged: 0,
        control_traces_judged: 0,
        digest_equal: 0,
        digest_unequal: 0,
        api_scriptcode_rows: 0,
        api_scriptcode_equal: 0,
        api_scriptcode_unequal: 0,
        context_scriptcode_rows: 0,
        context_scriptcode_equal: 0,
        context_scriptcode_unequal: 0,
        single_decisions: Vec::new(),
        divergent: BTreeMap::new(),
        red: 0,
        counts: methods(engine)
            .iter()
            .map(|m| (m.to_string(), Counts::default()))
            .collect(),
        words: words.clone(),
        results: Vec::new(),
        witnesses: BTreeMap::new(),
        verdict_line: String::new(),
    };
    'cases: for case in cases {
        for &method in methods(engine) {
            let signed = &keyed[&(case.row.entry.id.clone(), method.to_string())];
            validate(signed, case)?;
            if explicit_scriptcode(engine, method) && !consistent(signed, case) {
                record.red += 1;
            }
            let counts = record.counts.get_mut(method).ok_or("method count")?;
            let Some(tx) = &signed.tx_hex else {
                *counts.unsigned.entry(signed.note.clone()).or_default() += 1;
                record
                    .results
                    .push(json!({"id": signed.id, "method": method, "unsigned": signed.note}));
                if explicit_scriptcode(engine, method) {
                    break 'cases;
                }
                continue;
            };
            counts.signed += 1;
            if method == "api-scriptcode" {
                record.api_scriptcode_rows += 1;
            } else if method == "api-context-scriptcode" {
                record.context_scriptcode_rows += 1;
            }
            let mut columns = Vec::new();
            for (c, column) in ["block", "relay"].iter().enumerate() {
                let control = node.judge(&case.row, &case.control, &case.words[c])?;
                let judged = node.judge(&case.row, tx, &case.words[c])?;
                let mut inputs = Vec::new();
                let mut refused = BTreeSet::new();
                let expected = case
                    .row
                    .entry
                    .reference
                    .as_ref()
                    .ok_or("corpus reference absent")?;
                let control_valid = control.iter().all(|v| v.verdict == "valid");
                if control_valid != (expected.expect == "valid") {
                    record.red += 1;
                }
                if !control_valid {
                    let expected_code = case
                        .row
                        .entry
                        .note
                        .as_deref()
                        .unwrap_or("")
                        .split("expect ")
                        .nth(1)
                        .and_then(|s| s.strip_suffix(')'));
                    let actual = control
                        .iter()
                        .find(|v| v.verdict != "valid")
                        .and_then(|v| v.code.as_deref());
                    if expected_code != actual {
                        record.red += 1;
                    }
                }
                for (i, (ctl, verdict)) in control.iter().zip(&judged).enumerate() {
                    record.traces_judged += 1;
                    record.control_traces_judged += 1;
                    let class = classify(&table, case, signed, i, ctl, verdict)?;
                    let divergent = ctl != verdict;
                    if let Some(class) = &class {
                        if class == UNEXPLAINED {
                            record.red += 1;
                        }
                        if verdict.verdict != "valid" {
                            refused.insert(class.clone());
                        }
                        if divergent {
                            *record.divergent.entry(class.clone()).or_default() += 1;
                        }
                        // Control-refusal classes also get a reproducible witness.
                        record.witnesses.entry(class.clone()).or_insert(json!({
                            "id": signed.id, "method": method, "input": i, "column": column,
                            "txid": txid(tx)?, "tx_hex": tx, "control_txid": txid(&case.control)?,
                            "control_tx_hex": case.control, "node": verdict, "control": ctl,
                            "flags": case.words[c], "prevouts": case.row.entry.prevouts
                        }));
                    }
                    let mut digests = Vec::new();
                    for trace in signed.inputs.iter().filter(|t| t.index == i) {
                        let ctl = &case.digests[&(i, trace.site)];
                        let equal = trace.digest_hex == ctl.digest_hex;
                        if ctl.digest_hex == format!("01{}", "00".repeat(31)) {
                            record
                                .single_decisions
                                .push(json!({"id": signed.id, "method": method,
                                "input": i, "site": trace.site, "column": column,
                                "scope": case.row.signing.inputs[i].sighash_type,
                                "txid": txid(tx)?, "node": verdict, "control": control[i],
                                "sdk_digest": trace.digest_hex, "control_digest": ctl.digest_hex,
                                "equal": equal}));
                        }
                        if c == 0 {
                            if method == "api-scriptcode" {
                                if equal {
                                    record.api_scriptcode_equal += 1;
                                } else {
                                    record.api_scriptcode_unequal += 1;
                                }
                            } else if method == "api-context-scriptcode" {
                                if equal {
                                    record.context_scriptcode_equal += 1;
                                } else {
                                    record.context_scriptcode_unequal += 1;
                                }
                            }
                            if equal {
                                record.digest_equal += 1;
                            } else {
                                record.digest_unequal += 1;
                            }
                        }
                        digests.push(json!({"sdk": trace, "control": ctl, "equal": equal}));
                    }
                    inputs.push(json!({"index": i, "flags": case.words[c][i], "node": verdict,
                        "control": ctl, "class": class, "divergent": divergent, "digests": digests}));
                }
                if judged.iter().all(|v| v.verdict == "valid") {
                    *counts.valid.entry(column.to_string()).or_default() += 1;
                } else {
                    for class in refused {
                        *counts
                            .refused
                            .entry(column.to_string())
                            .or_default()
                            .entry(class)
                            .or_default() += 1;
                    }
                }
                columns.push(json!({"column": column, "inputs": inputs}));
            }
            record
                .results
                .push(json!({"id": signed.id, "method": method, "txid": txid(tx)?,
                "control_txid": txid(&case.control)?, "columns": columns}));
            if record.red != 0 {
                break 'cases;
            }
        }
    }
    if record.traces_judged == 0 {
        record.red += 1;
    }
    record.verdict_line = format!("signer: {} [X] ({} rows, {} traces judged, divergent by class [{}], RED {}) engine={engine}",
        if record.red == 0 { "GREEN" } else { "RED" }, record.rows, record.traces_judged, tally(&record.divergent), record.red);
    Ok(record)
}

fn tally(counts: &BTreeMap<String, usize>) -> String {
    if counts.is_empty() {
        return "none".into();
    }
    counts
        .iter()
        .map(|(name, n)| format!("{name}: {n}"))
        .collect::<Vec<_>>()
        .join("; ")
}

fn consistency_line(r: &Record) -> String {
    // #148 lens: the fourth method is held to the hand digests in the line too.
    let context = methods(&r.engine).contains(&"api-context-scriptcode");
    let held = r.api_scriptcode_rows == r.rows
        && r.api_scriptcode_equal > 0
        && r.api_scriptcode_unequal == 0;
    let context_held = !context
        || (r.context_scriptcode_rows == r.rows
            && r.context_scriptcode_equal > 0
            && r.context_scriptcode_unequal == 0);
    let context_part = if context {
        format!(
            " ({} api-context-scriptcode rows, {} site digests equal, {} unequal)",
            r.context_scriptcode_rows, r.context_scriptcode_equal, r.context_scriptcode_unequal
        )
    } else {
        String::new()
    };
    format!("signer self-consistency: {} [X] ({} api-scriptcode rows, {} site digests equal, {} unequal){} engine={}",
        if held && context_held { "GREEN" } else { "RED" },
        r.api_scriptcode_rows, r.api_scriptcode_equal, r.api_scriptcode_unequal, context_part, r.engine)
}

fn markdown(records: &[Record], stopped: bool) -> String {
    let env_or_unset = |key: &str| {
        std::env::var(key)
            .ok()
            .filter(|v| !v.is_empty())
            .unwrap_or_else(|| "<unset>".into())
    };
    let mut s = format!(
        "# The signer column: node judgments\n\n[M] Lane {}, assigned {}; GitHub Calgooon. Runtime variant and tier are not independently exposed.\n\n",
        env_or_unset("SIGNER_LANE"),
        env_or_unset("SIGNER_MODEL")
    );
    s.push_str("[D] Synthetic outpoints are judged by `verifyscript` with the corpus prevouts; no coins are funded and nothing is submitted or broadcast. Each signed engine transaction and the self-check's hand-signed control are judged under both derived words. Both columns use the oracle's zeroed policy caps (consensus limits); relay means the relay flag word, not mempool admission or default policy limits. Locktime/finality and fees are outside this script judgment. `stopOnFirstInvalid=false` judges every input. A trace is one input in one column; site digests are compared separately, once per signed method. The node exposes input verdicts, not per-site execution verdicts. Refusal counts count each transaction once per class; classes can overlap when different inputs fail for different reasons. The refused union is signed minus valid for each column.\n\n| engine | method | signed [M] | valid block / relay [M] | refused by class block / relay [M] | unsigned by reason [M] |\n|---|---|---|---|---|---|\n");
    for r in records {
        for &method in methods(&r.engine) {
            let c = &r.counts[method];
            s += &format!(
                "| {} | {} | {} | {} / {} | {} / {} | {} |\n",
                r.engine,
                method,
                c.signed,
                c.valid.get("block").unwrap_or(&0),
                c.valid.get("relay").unwrap_or(&0),
                c.refused
                    .get("block")
                    .map(tally)
                    .unwrap_or_else(|| "none".into()),
                c.refused
                    .get("relay")
                    .map(tally)
                    .unwrap_or_else(|| "none".into()),
                tally(&c.unsigned)
            );
        }
    }
    for r in records {
        s += &format!("\n[M] `{}`\n\n[M] Signer site digests: {} equal, {} unequal; control input judgments: {}. Source base commit `{}`; the JSON carries hashes of the measured source files, the evaluator path and executable, and the runner executable, measured from the committed lane source. Node binary SHA256 `{}`; RPC port {}.\n\n",
            r.verdict_line, r.digest_equal, r.digest_unequal, r.control_traces_judged, r.source_commit, r.node_sha256, r.rpc_port);
        if r.engine == "bsv-rs" {
            s += &format!("[M] `{}`. This compares two callers of the same library digest primitives; it is a self-consistency check. Every signed result is separately judged by the node.\n\n", consistency_line(r));
            s += "[SRC] bsv-rs 0.7.0 `src/script/template.rs:133-154` signs over the context's scriptCode, the locking script unless `with_script_code` (`:114-117`) supplies another (`:142`), through `compute_sighash_dispatched_for_signing` (`src/primitives/bsv/sighash.rs:970-976`), whose original digest returns constant one for SINGLE beyond outputs (`:983-992`). The 0.5.0 mechanisms that follow are history (#148): at 0.5.0 `src/script/template.rs:85-99` selected the source locking script and called the BIP143-only function `src/primitives/bsv/sighash.rs:941-944`; its dispatched function at `:962-983` selected the original digest for Chronicle and returned constant one for original SINGLE beyond outputs. The node selects scriptCode at bitcoin-sv v1.2.3 `6504a3af` `src/script/interpreter.cpp:1471-1481`, dispatches at `:2112-2124` and returns original SINGLE constant one at `:2086-2100`. [SRC] At 0.5.0 `src/primitives/bsv/sighash.rs:941-944` built the BIP143 preimage (`:384`, `SighashCache::preimage` `:546-570`) whose hashOutputs is 32 zero bytes for SINGLE beyond outputs (`SighashCache::hash_outputs` `:534-536`), whatever the CHRONICLE bit; the node returns constant one for the same scope (`interpreter.cpp:2086-2100`, `:2112-2124`).\n\n[SRC] The public `unlock` paths are bsv-rs 0.7.0 `src/script/templates/p2pkh.rs:151` (`context.compute_sighash` `:162`), `src/script/templates/p2pk.rs:66` (`:76`) and `src/script/templates/multisig.rs:158` (`:169`). The options at `src/script/template.rs:209-217` (`compute_sighash_scope`, FORKID always) cannot express Chronicle or omit FORKID, so those template rows are unsigned. Transaction signing at `src/transaction/transaction.rs:1462` uses the same context.\n\n[D] Class precedence is lock-only, constant-one, then Chronicle BIP143. In-unlock Chronicle rows can have both scriptCode and dispatch differences; the lock-only count is not proof that scriptCode is the sole cause. The Chronicle BIP143 marker requires scriptCode equal to the control and an exact BIP143 preimage/digest. Control refusals are separate classes: SIG_PUSHONLY (`interpreter.cpp:2321-2334`), ILLEGAL_CHRONICLE (`:296-303`) and MUST_USE_FORKID (`:296-306`) at the same node pin; they are not signer disagreements.\n\n";
            for &method in methods(&r.engine) {
                let decisions: Vec<_> = r
                    .single_decisions
                    .iter()
                    .filter(|d| d["method"] == method)
                    .collect();
                let accepted = decisions
                    .iter()
                    .filter(|d| {
                        d["control"]["verdict"] == "valid" && d["node"]["verdict"] == "valid"
                    })
                    .count();
                let refused = decisions
                    .iter()
                    .filter(|d| {
                        d["control"]["verdict"] == "valid" && d["node"]["verdict"] == "invalid"
                    })
                    .count();
                let equal = decisions.iter().filter(|d| d["equal"] == true).count();
                s += &format!("[M] bsv-rs `{method}` original SINGLE constant-one subset: {} input/column decisions, {accepted} accepted beside valid control, {refused} refused beside valid control, {equal} equal digests. Encoding refusals are included in the total and excluded from accepted/refused beside valid control.\n\n", decisions.len());
            }
        }
        if let Some(w) = r.witnesses.get(SINGLE) {
            s += &format!("[M] SIGHASH_SINGLE decision: the node refused {}'s nonconstant-digest signature and accepted the control signed over constant `one`; witness txid `{}`. The no-FORKID sentinel is counted separately as MUST_USE_FORKID and cannot decide digest behavior.\n\n", r.engine, w["txid"].as_str().unwrap_or(""));
        } else {
            let accepted = r
                .single_decisions
                .iter()
                .filter(|d| d["control"]["verdict"] == "valid" && d["node"]["verdict"] == "valid")
                .count();
            s += &format!("[M] SIGHASH_SINGLE: {accepted} input/column decisions accepted beside a valid constant-one control for {}; individual digests and any encoding refusals are in the JSON record.\n\n", r.engine);
        }
        for (class, w) in &r.witnesses {
            s += &format!("[M] Witness for `{class}`: engine `{}`, row `{}`, method `{}`, input {}, column `{}`; txid `{}`; control txid `{}`. The hex below identifies a transaction judged on the lane's empty regtest chain, not a mined transaction.\n\n```json\n{}\n```\n\n",
                r.engine, w["id"].as_str().unwrap_or(""), w["method"].as_str().unwrap_or(""), w["input"],
                w["column"].as_str().unwrap_or(""), w["txid"].as_str().unwrap_or(""),
                w["control_txid"].as_str().unwrap_or(""), w);
        }
    }
    s += "[D] Decisions whose control digest is constant one, including the 0x03 encoding refusal, are in each JSON record's `single_decisions` array; the 0x43 BIP143 decisions and other SINGLE decisions are in `results`.\n\n";
    s += if stopped {
        "[M] RED: classifier/control stop. The run is partial; no later engine was run.\n"
    } else {
        "[M] The owned node stopped and its run directory was removed before this record was written.\n"
    };
    s
}

/// Build the hand-signed CONTROL transaction of every signer corpus row (the control is signed over the
/// scriptCode the reference computes, exactly as `cases()` builds `Case.control`; `signer.rs`), and write them as
/// a corpus-shaped jsonl per family under `dir`. Each entry carries the row's prevouts, params and, under the
/// `node@v1.2.3` key of its `expect`, the RECORDED node verdict word (the row's `reference`, the signer column's
/// judgment). No node and no flag oracle are consulted here: the controls are the signer's own bytes, judged
/// elsewhere (the GoBDK shim, a hazard-class lane). Returns (family files written, control rows written).
fn dump_controls_to(root: &Path, dir: &Path) -> Result<(usize, usize)> {
    let src = root.join("corpus/signer");
    let mut files: Vec<_> = std::fs::read_dir(&src)
        .map_err(|e| e.to_string())?
        .filter_map(|p| p.ok().map(|p| p.path()))
        .filter(|p| p.extension().is_some_and(|x| x == "jsonl"))
        .collect();
    files.sort();
    let mut family_files = 0usize;
    let mut total = 0usize;
    for path in files {
        let text = read(&path)?;
        let stem = path
            .file_stem()
            .and_then(|x| x.to_str())
            .ok_or("corpus filename")?;
        let mut out = String::new();
        for line in text.lines().filter(|x| !x.trim().is_empty()) {
            let row: Row = serde_json::from_str(line).map_err(|e| e.to_string())?;
            row.entry.check()?;
            let raw = decode(&row.entry.tx)?;
            if raw.inputs.len() != row.signing.inputs.len() {
                return Err("signing input count differs from the transaction".into());
            }
            let mut signed = raw.clone();
            for (i, si) in row.signing.inputs.iter().enumerate() {
                let (unlock, _sites) = sign_input(&raw, row.entry.prevouts[i].satoshis, si, None)?;
                signed.inputs[i].script = unlock;
            }
            let reference = row
                .entry
                .reference
                .as_ref()
                .ok_or("corpus reference absent")?;
            let code = row
                .entry
                .note
                .as_deref()
                .unwrap_or("")
                .split("expect ")
                .nth(1)
                .and_then(|s| s.strip_suffix(')'))
                .map(str::to_string);
            let mut entry = row.entry.clone();
            entry.tx = hex::encode(signed.encode());
            entry.divergence = None;
            entry.expect = BTreeMap::new();
            entry.expect.insert(
                "node@v1.2.3".to_string(),
                ExpectJson {
                    code: if reference.expect == "valid" {
                        None
                    } else {
                        code
                    },
                    verdict: reference.expect.clone(),
                    reason: None,
                    input: None,
                },
            );
            out.push_str(&serde_json::to_string(&entry).map_err(|e| e.to_string())?);
            out.push('\n');
            total += 1;
        }
        std::fs::write(dir.join(format!("{stem}.jsonl")), out).map_err(|e| e.to_string())?;
        family_files += 1;
    }
    Ok((family_files, total))
}

fn run() -> Result<()> {
    let args: Vec<String> = std::env::args().collect();
    let check_rules = args.iter().any(|a| a == "--check-rules");
    let dump_controls = args
        .iter()
        .position(|a| a == "--dump-controls")
        .map(|i| {
            args.get(i + 1)
                .cloned()
                .ok_or_else(|| "--dump-controls needs a directory".to_string())
        })
        .transpose()?;
    let expected = 1 + usize::from(check_rules) + if dump_controls.is_some() { 2 } else { 0 };
    if args.len() != expected {
        return Err("usage: run_signer [--check-rules] [--dump-controls <dir>]".into());
    }
    let root = Path::new(env!("CARGO_MANIFEST_DIR"))
        .parent()
        .ok_or("repository root")?;
    for (engine, pin) in ENGINES {
        table(root, engine, pin)?;
    }
    if check_rules {
        println!("signer rules: GREEN [X] (3 pinned classifier tables validated)");
        return Ok(());
    }
    if let Some(dir) = dump_controls {
        let dir = PathBuf::from(dir);
        std::fs::create_dir_all(&dir).map_err(|e| format!("create {}: {e}", dir.display()))?;
        let (files, rows) = dump_controls_to(root, &dir)?;
        println!(
            "signer dump-controls: GREEN [X] ({rows} control transactions in {files} family files under {})",
            dir.display()
        );
        return Ok(());
    }
    let stamp = output(
        Command::new("date").args(["-u", "+%Y%m%d-%H%M%S"]),
        "UTC stamp",
    )?
    .trim()
    .to_string();
    let base =
        PathBuf::from(std::env::var("TMPDIR").map_err(|_| "TMPDIR required for run directory")?);
    let path = base.join(format!("rs-147-{stamp}-{}", std::process::id()));
    std::fs::create_dir(&path).map_err(|e| e.to_string())?;
    let run = RunDir(path);
    let evaluator = std::env::var_os("SIGNER_BSVS").map(PathBuf::from);
    let evaluator_path = evaluator
        .clone()
        .unwrap_or_else(|| root.join("lean/.lake/build/bin/bsvs"))
        .canonicalize()
        .map_err(|e| format!("resolve evaluator: {e}"))?;
    let evaluator_sha256 = file_hash(&evaluator_path)?;
    let mut oracle = FlagsOracle::new(root, "sv");
    if let Some(binary) = evaluator {
        oracle = oracle.with_executable(&binary);
    }
    let cases = cases(root, &mut oracle)?;
    let words = json!(oracle
        .table()
        .iter()
        .map(|((sh, uh, c), w)| json!({
            "spend_height": sh, "utxo_height": uh, "consensus": c, "word": w
        }))
        .collect::<Vec<_>>());
    let mut node = Node::start(root, &run.0)?;
    let mut records = Vec::new();
    for (engine, pin) in ENGINES {
        let mut record = measure(
            root,
            &run.0,
            &mut node,
            &cases,
            (engine, pin),
            &stamp,
            &words,
        )?;
        record.source_sha256.insert(
            evaluator_path.display().to_string(),
            evaluator_sha256.clone(),
        );
        let red = record.red != 0;
        println!("{}", record.verdict_line);
        if engine == "bsv-rs" {
            println!("{}", consistency_line(&record));
        }
        records.push(record);
        if red {
            break;
        }
    }
    node.stop()?;
    drop(node);
    std::fs::remove_dir_all(&run.0).map_err(|e| format!("remove run directory: {e}"))?;
    let stopped = records.iter().any(|r| r.red != 0);
    let record_dir = std::env::var_os("SIGNER_RECORD_DIR")
        .map(PathBuf::from)
        .unwrap_or_else(|| root.join("docs/records"));
    std::fs::create_dir_all(&record_dir).map_err(|e| e.to_string())?;
    for record in &records {
        write_json(
            &record_dir.join(format!(
                "{stamp}-s3-147-signer-column-{}-s3.json",
                record.engine
            )),
            record,
        )?;
    }
    let record_path = record_dir.join(format!("{stamp}-s3-147-signer-column-s3.md"));
    std::fs::write(&record_path, markdown(&records, stopped))
        .map_err(|e| format!("write record: {e}"))?;
    println!("record: {}", record_path.display());
    if stopped {
        return Err(
            "classifier/control stop; inspect the partial record before any further work".into(),
        );
    }
    println!("signer cleanup: GREEN [X] (owned node reaped; run directory removed)");
    Ok(())
}

fn main() -> std::process::ExitCode {
    match run() {
        Ok(()) => std::process::ExitCode::SUCCESS,
        Err(e) => {
            eprintln!("signer: RED [X] ({e})");
            std::process::ExitCode::FAILURE
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn sample() -> Result<(Case, Signed)> {
        let line = include_str!("../../../corpus/signer/checksig-in-unlock-a.jsonl")
            .lines()
            .next()
            .ok_or("empty fixture")?;
        let row: Row = serde_json::from_str(line).map_err(|e| e.to_string())?;
        let raw = decode(&row.entry.tx)?;
        let mut control = raw.clone();
        let mut default = raw.clone();
        let mut digests = BTreeMap::new();
        let mut traces = Vec::new();
        for si in &row.signing.inputs {
            let i = si.index;
            let amount = row.entry.prevouts[i].satoshis;
            let (unlock, sites) = sign_input(&raw, amount, si, None)?;
            control.inputs[i].script = unlock;
            for site in sites {
                digests.insert((i, site.site), site);
            }
            let lock = hex::decode(&row.entry.prevouts[i].script).map_err(|e| e.to_string())?;
            let (unlock, sites) = sign_input(&raw, amount, si, Some(&lock))?;
            default.inputs[i].script = unlock;
            for site in sites {
                traces.push(Trace {
                    index: i,
                    site: site.site,
                    preimage_hex: String::new(),
                    digest_hex: site.digest_hex,
                    scriptcode_used_hex: hex::encode(&lock),
                });
            }
        }
        let signed = Signed {
            id: row.entry.id.clone(),
            engine: "go-sdk".into(),
            method: "api-default".into(),
            tx_hex: Some(hex::encode(default.encode())),
            inputs: traces,
            note: String::new(),
        };
        Ok((
            Case {
                row,
                control: hex::encode(control.encode()),
                digests,
                words: [Vec::new(), Vec::new()],
            },
            signed,
        ))
    }

    #[test]
    fn adapter_must_preserve_transaction_and_every_site() -> Result<()> {
        let (case, mut signed) = sample()?;
        validate(&signed, &case)?;
        signed.inputs.pop();
        assert!(validate(&signed, &case).is_err());
        let (case, mut signed) = sample()?;
        let mut raw = decode(signed.tx_hex.as_deref().ok_or("no signed tx")?)?;
        raw.lock_time += 1;
        signed.tx_hex = Some(hex::encode(raw.encode()));
        assert!(validate(&signed, &case).is_err());
        signed.tx_hex = None;
        assert!(validate(&signed, &case).is_err());
        signed.note = "unsupported template".into();
        validate(&signed, &case)
    }

    #[test]
    fn explicit_digest_mismatch_is_red_even_without_a_node_disagreement() -> Result<()> {
        let (case, mut signed) = sample()?;
        assert!(!consistent(&signed, &case));
        for t in &mut signed.inputs {
            t.digest_hex = case.digests[&(t.index, t.site)].digest_hex.clone();
        }
        assert!(consistent(&signed, &case));
        signed.inputs.pop();
        assert!(!consistent(&signed, &case));
        signed.tx_hex = None;
        assert!(!consistent(&signed, &case));
        Ok(())
    }

    #[test]
    fn chronicle_class_requires_exact_bip143_trace_and_valid_control() -> Result<()> {
        let line = include_str!("../../../corpus/signer/p2pkh.jsonl")
            .lines()
            .next()
            .ok_or("empty fixture")?;
        let mut row: Row = serde_json::from_str(line).map_err(|e| e.to_string())?;
        row.signing.inputs[0].sighash_type = 0x61;
        let tx = decode(&row.entry.tx)?;
        let si = &row.signing.inputs[0];
        let (_, sites) = sign_input(&tx, row.entry.prevouts[0].satoshis, si, None)?;
        let (inputs, outputs) = sighash_parts(&tx);
        let code = hex::decode(&si.scriptcode_hex[0]).map_err(|e| e.to_string())?;
        let pre = build_sighash_preimage(&SighashParams {
            version: tx.version,
            inputs: &inputs,
            outputs: &outputs,
            locktime: tx.lock_time,
            input_index: 0,
            subscript: &code,
            satoshis: row.entry.prevouts[0].satoshis,
            scope: 0x61,
        });
        let mut signed = Signed {
            id: row.entry.id.clone(),
            engine: "bsv-rs".into(),
            method: "api-default".into(),
            tx_hex: Some(row.entry.tx.clone()),
            note: String::new(),
            inputs: vec![Trace {
                index: 0,
                site: 0,
                preimage_hex: hex::encode(&pre),
                digest_hex: hex::encode(sha256(&sha256(&pre))),
                scriptcode_used_hex: hex::encode(code),
            }],
        };
        let case = Case {
            row,
            control: String::new(),
            words: [vec![], vec![]],
            digests: sites.into_iter().map(|s| ((0, s.site), s)).collect(),
        };
        let root = Path::new(env!("CARGO_MANIFEST_DIR"))
            .parent()
            .ok_or("root")?;
        let rules = table(root, "bsv-rs", BSV_RS_VERSION)?;
        let good = Verdict {
            verdict: "valid".into(),
            code: None,
        };
        let bad = Verdict {
            verdict: "invalid".into(),
            code: Some("SCRIPT_ERR_EVAL_FALSE".into()),
        };
        assert_eq!(
            classify(&rules, &case, &signed, 0, &good, &bad)?.as_deref(),
            Some("sighash.chronicle.bip143")
        );
        assert_eq!(
            classify(&rules, &case, &signed, 0, &bad, &bad)?.as_deref(),
            Some(UNEXPLAINED)
        );
        signed.inputs[0].preimage_hex.clear();
        assert_eq!(
            classify(&rules, &case, &signed, 0, &good, &bad)?.as_deref(),
            Some(UNEXPLAINED)
        );
        Ok(())
    }

    #[test]
    fn classifier_requires_the_measured_mechanism_method_and_control() -> Result<()> {
        let (case, mut signed) = sample()?;
        let root = Path::new(env!("CARGO_MANIFEST_DIR"))
            .parent()
            .ok_or("root")?;
        let good = Verdict {
            verdict: "valid".into(),
            code: None,
        };
        let bad = Verdict {
            verdict: "invalid".into(),
            code: Some("SCRIPT_ERR_CHECKSIGVERIFY".into()),
        };
        for (engine, pin) in ENGINES {
            let rules = table(root, engine, pin)?;
            assert_eq!(
                classify(&rules, &case, &signed, 0, &good, &bad)?.as_deref(),
                Some(LOCK_ONLY)
            );
            assert_eq!(
                classify(&rules, &case, &signed, 0, &bad, &bad)?.as_deref(),
                Some(UNEXPLAINED)
            );
            signed.method = "api-scriptcode".into();
            assert_eq!(
                classify(&rules, &case, &signed, 0, &good, &bad)?.as_deref(),
                Some(UNEXPLAINED)
            );
            signed.method = "api-default".into();
        }
        signed.inputs[0].digest_hex = case.digests[&(0, 0)].digest_hex.clone();
        assert_eq!(
            classify(
                &table(root, "go-sdk", GO_SDK_VERSION)?,
                &case,
                &signed,
                0,
                &good,
                &bad
            )?
            .as_deref(),
            Some(UNEXPLAINED)
        );
        Ok(())
    }
}
