//! Scenario runner driver; family recipes live in their respective modules.
mod block;
mod chain;
mod core;
// [D] 2026-10-13: #69 era boundaries, replayed alone by --eras-only.
mod eras;
// [D] 2026-10-15, lane events-84: #84 the event vocabulary on the zmq build, run alone by --events.
mod events;
mod finality;
// [D] 2026-10-14, lane s6-70: #70 operator lists, replayed alone by --frozen-only.
mod frozen;
mod intake;
mod mempool;
mod oracle;
// [D] 2026-10-15, lane s7-81: #81 mempool persistence across restarts, run alone by --persist.
mod persist;
// [D] 2026-10-13: pinned reference-framework loopback receipts.
mod peer;
mod proofs;
// [D] 2026-10-15, lane s7-82: #82 pruning on fresh instances, run alone by --prune.
mod prune;
mod status_views;
mod utxo;
// [D] 2026-10-14: #71 reject-cache and time-budget traces over that peer.
mod rejects;
// [D] 2026-10-15, lane s7-78: #78 two instances and the relay machine, run alone by --relay.
mod relay;
// [D] 2026-10-15, lane s7-79: #79 compact blocks on #78's two instances, run alone by --compact.
mod compact;
// [D] 2026-10-15, lane s7-80: #80 double-spend notifications on two instances, run alone by --dsnt.
mod dsnt;
// [D] 2026-10-14, lane s6-73: #73 validation depth and safe mode.
mod depth;
// [D] 2026-10-14, lane tera-74: #74 the Teranode column on the instance of #41.
mod teranode;
use core::*;
use intake::{mark_scenario, scenario_run};

fn family_run(family: &str, root: &Path) -> Result<Vec<Value>> {
    match family {
        "mempool" => mempool::run(root),
        "finality" => finality::run(root),
        "block" => block::run(root),
        "utxo" => utxo::run(root),
        "chain" => chain::run(root),
        "oracle" => oracle::run(root),
        "eras" => eras::run(root),
        "frozen" => frozen::run(root),
        _ => Err(format!("unknown family {family}")),
    }
}
fn unrealizable(family: &str, row: &Value) -> Option<&'static str> {
    match family {
        "finality" => finality::unrealizable(row),
        "utxo" => utxo::unrealizable(row),
        "eras" => eras::unrealizable(row),
        _ => None,
    }
}
// A run's record names its lane: docs/records/<stamp>-s6-<lane>-regtest-s3.md,
// the lane token lowercase ASCII, digits and hyphens (cut 1's lane was 66c).
fn record_name_ok(record: &str) -> bool {
    let Some(stem) = record
        .strip_prefix("docs/records/")
        .and_then(|name| name.strip_suffix("-regtest-s3.md"))
    else {
        return false;
    };
    // main's s6-65 hunk (2026-10-13): the stamp is digits and hyphens.
    match stem.split_once("-s6-") {
        Some((stamp, lane)) => {
            !stamp.is_empty()
                && stamp.bytes().all(|c| c.is_ascii_digit() || c == b'-')
                && !lane.is_empty()
                && lane
                    .bytes()
                    .all(|c| c.is_ascii_lowercase() || c.is_ascii_digit() || c == b'-')
        }
        None => false,
    }
}
fn main_run() -> Result<()> {
    let args: Vec<String> = std::env::args().collect();
    let arg = |name: &str| {
        args.iter()
            .position(|s| s == name)
            .and_then(|i| args.get(i + 1))
            .cloned()
    };
    let record=arg("--record").ok_or("usage: run_scenarios --record docs/records/<stamp>-s6-<lane>-regtest-s3.md [--run-id ID] [--write]")?;
    // [D] 2026-10-14, lane tera-74 (#74): the Teranode column; its record is
    // docs/records/<stamp>-s6-74-second-oracle-s4b.md (lane fix-tera-74: a name outside the
    // closed record-name patterns, so every brief can open it) and its run lives beside the
    // instance of #41 (~/bsv/targets/spec-teranode/runs-74/<run id>).
    // [D] 2026-10-15, lane cut2-66 (#66 cut 2): the same column on the road (the legacy
    // bridge on); its record is docs/records/<stamp>-s6-66-cut2-second-oracle-s3.md and its run
    // lives in ~/bsv/targets/spec-teranode/runs-66/<run id>.
    if args.iter().any(|a| a == "--teranode") {
        let (stem, runs) = match record.strip_prefix("docs/records/") {
            Some(r) if r.ends_with("-s6-66-cut2-second-oracle-s3.md") => {
                (r.strip_suffix("-s6-66-cut2-second-oracle-s3.md"), "runs-66")
            }
            Some(r) => (r.strip_suffix("-s6-74-second-oracle-s4b.md"), "runs-74"),
            None => (None, "runs-74"),
        };
        if !stem
            .is_some_and(|s| !s.is_empty() && s.bytes().all(|c| c.is_ascii_digit() || c == b'-'))
        {
            return Err("record must be docs/records/<stamp>-s6-66-cut2-second-oracle-s3.md (or #74's <stamp>-s6-74-second-oracle-s4b.md)".into());
        }
        let home = PathBuf::from(std::env::var("HOME").map_err(|e| e.to_string())?);
        let run_id = arg("--run-id").unwrap_or_else(|| {
            format!(
                "tera-74-{}",
                std::time::SystemTime::now()
                    .duration_since(std::time::UNIX_EPOCH)
                    .map(|d| d.as_secs())
                    .unwrap_or(0)
            )
        });
        if run_id.is_empty()
            || !run_id
                .bytes()
                .all(|c| c.is_ascii_alphanumeric() || c == b'-')
        {
            return Err("unsafe run id".into());
        }
        // [D] 2026-10-15, lane cut2-66q (the quarantine rule of #66 cut 2): ORACLE_QUARANTINE
        // names the run's directory, ~/bsv/targets/spec-oracle-quarantine/teranode-<UTC stamp>;
        // the instance's data, the peer receipts and the full receipt live there, and the
        // record's JSON is the projection (teranode::projection) of counts, verdicts, ids,
        // hashes and paths.
        let quarantine = std::env::var("ORACLE_QUARANTINE").ok().map(PathBuf::from);
        if let Some(q) = &quarantine {
            let parent_ok = q.parent() == Some(&home.join("bsv/targets/spec-oracle-quarantine"));
            let name_ok = q
                .file_name()
                .and_then(|n| n.to_str())
                .and_then(|n| n.strip_prefix("teranode-"))
                .is_some_and(|s| {
                    !s.is_empty() && s.bytes().all(|c| c.is_ascii_alphanumeric() || c == b'-')
                });
            if !(parent_ok && name_ok) {
                return Err("ORACLE_QUARANTINE must be ~/bsv/targets/spec-oracle-quarantine/teranode-<UTC stamp>".into());
            }
        }
        let root = quarantine.clone().unwrap_or_else(|| {
            home.join("bsv/targets/spec-teranode")
                .join(runs)
                .join(&run_id)
        });
        fs::create_dir_all(&root).map_err(|e| e.to_string())?;
        let started = Command::new("date")
            .args(["-u", "+%Y-%m-%dT%H:%M:%SZ"])
            .output()
            .map_err(|e| e.to_string())?;
        let head = Command::new("git")
            .args(["rev-parse", "HEAD"])
            .output()
            .map_err(|e| e.to_string())?;
        let start = Instant::now();
        let mut column = teranode::run(&root)?;
        column["record"] = json!(record);
        column["run_id"] = json!(run_id);
        column["base_commit"] = json!(String::from_utf8_lossy(&head.stdout).trim());
        column["started_utc"] = json!(String::from_utf8_lossy(&started.stdout).trim());
        column["wall_seconds"] = json!({"label":"[M]","value":start.elapsed().as_secs_f64()});
        let full = root.join("receipt.json");
        write_json(&full, &column)?;
        let bytes = fs::read(&full).map_err(|e| e.to_string())?;
        column["full_receipt"] = json!({"label":"[M]","path":teranode::pointer(&full),"bytes":bytes.len(),"sha256":hex::encode(bsv_rs::primitives::hash::sha256(&bytes))});
        column.as_object_mut().ok_or("column")?.remove("rpc");
        if quarantine.is_some() {
            write_json(
                &PathBuf::from(record.replace(".md", ".json")),
                &teranode::projection(&column),
            )?;
            println!(
                "column: totals {} [X]; wall [M] {:.3}s",
                teranode::projection(&column)["totals"],
                start.elapsed().as_secs_f64()
            );
            return Ok(());
        }
        write_json(&PathBuf::from(record.replace(".md", ".json")), &column)?;
        println!(
            "teranode column: totals {} witnesses {} [X]; wall [M] {:.3}s",
            column["totals"],
            column["status_witnesses"]["counts"],
            start.elapsed().as_secs_f64()
        );
        return Ok(());
    }
    // [D] 2026-10-15 (#84, lane events-84): its record is docs/records/<stamp>-s7-84-events-s1.md.
    if args.iter().any(|a| a == "--events") {
        return events::main(
            &record,
            arg("--run-id"),
            args.iter().any(|a| a == "--write"),
        );
    }
    // [D] 2026-10-15 (#78, lane s7-78): its record is docs/records/<stamp>-s7-78-p2p-machine-s1.md.
    if args.iter().any(|a| a == "--relay") {
        return relay::main(&record, arg("--run-id"));
    }
    // [D] 2026-10-15 (#79, lane s7-79): its record is docs/records/<stamp>-s7-79-compact-blocks-s1.md.
    if args.iter().any(|a| a == "--compact") {
        return compact::main(&record, arg("--run-id"));
    }
    // [D] 2026-10-15 (#80, lane s7-80): its record is docs/records/<stamp>-s7-80-double-spend-s1.md.
    if args.iter().any(|a| a == "--dsnt") {
        return dsnt::main(&record, arg("--run-id"));
    }
    // [D] 2026-10-15 (#81, lane s7-81): its record is docs/records/<stamp>-s7-81-persist-s1.md.
    if args.iter().any(|a| a == "--persist") {
        return persist::main(
            &record,
            arg("--run-id"),
            args.iter().any(|a| a == "--write"),
        );
    }
    // [D] 2026-10-15 (#82, lane s7-82): its record is docs/records/<stamp>-s7-82-prune-s1.md.
    if args.iter().any(|a| a == "--prune") {
        return prune::main(
            &record,
            arg("--run-id"),
            args.iter().any(|a| a == "--write"),
        );
    }
    if !record_name_ok(&record) {
        return Err("record must name this lane's record".into());
    }
    let run_id = arg("--run-id").unwrap_or_else(|| {
        format!(
            "s6-66-{}",
            std::time::SystemTime::now()
                .duration_since(std::time::UNIX_EPOCH)
                .map(|d| d.as_secs())
                .unwrap_or(0)
        )
    });
    if run_id.is_empty()
        || !run_id
            .bytes()
            .all(|c| c.is_ascii_alphanumeric() || c == b'-')
    {
        return Err("unsafe run id".into());
    }
    let home = PathBuf::from(std::env::var("HOME").map_err(|e| e.to_string())?);
    let binary = Build::Record.located();
    let version = Command::new(&binary)
        .arg("-version")
        .output()
        .map_err(|e| e.to_string())?;
    let version = String::from_utf8_lossy(&version.stdout)
        .lines()
        .next()
        .unwrap_or("")
        .to_owned();
    if version != format!("Bitcoin SV version {VERSION}") {
        return Err(format!("node version mismatch: {version}"));
    }
    let parent = home.join("bsv/targets/spec-oracle-scenarios");
    fs::create_dir_all(&parent).map_err(|e| e.to_string())?;
    let root = parent.join(&run_id);
    fs::create_dir(&root).map_err(|e| e.to_string())?;
    let started = Command::new("date")
        .args(["-u", "+%Y-%m-%dT%H:%M:%SZ"])
        .output()
        .map_err(|e| e.to_string())?;
    let head = Command::new("git")
        .args(["rev-parse", "HEAD"])
        .output()
        .map_err(|e| e.to_string())?;
    let mut runner_sources = vec![
        PathBuf::from("harness/src/bin/run_scenarios.rs"),
        PathBuf::from("tools/receipt_trim.py"),
    ];
    runner_sources.extend(
        fs::read_dir("harness/src/scenarios")
            .map_err(|e| e.to_string())?
            .map(|entry| entry.map(|e| e.path()).map_err(|e| e.to_string()))
            .collect::<Result<Vec<_>>>()?,
    );
    runner_sources.sort();
    let mut source_bytes = vec![];
    for path in runner_sources {
        source_bytes.extend(path.to_string_lossy().as_bytes());
        source_bytes.push(0);
        source_bytes.extend(fs::read(path).map_err(|e| e.to_string())?);
    }
    let runner_hash = hex::encode(bsv_rs::primitives::hash::sha256(&source_bytes));
    // [D] 2026-10-13: replay only the 20 peer rows while retaining inherited counts.
    if args.iter().any(|a| a == "--peer-only") {
        return peer::suite(&root, &record, &run_id, args.iter().any(|a| a == "--write"));
    }
    let start = Instant::now();
    // [D] 2026-10-13: retain the full-plus-trimmed writer for the O-1 replay.
    let one_peer_only = args.iter().any(|a| a == "--one-peer-only");
    // [D] 2026-10-13, lane reclass-66b: the eleven limited mempool rows only.
    let reclass_only = args.iter().any(|a| a == "--reclass-only");
    // [D] 2026-10-13, lane s6-69: the eras family alone; the six families' tokens are untouched.
    let eras_only = args.iter().any(|a| a == "--eras-only");
    // [D] 2026-10-14, lane attr-o2: the nine disk-counter rows and O-2's witness.
    let attr_o2_only = args.iter().any(|a| a == "--attr-o2-only");
    // [D] 2026-10-14, lane s6-71b: the #71 trace rows only.
    let rejects_only = args.iter().any(|a| a == "--rejects-only");
    let frozen_only = args.iter().any(|a| a == "--frozen-only");
    // [D] 2026-10-14 (#121, lane wallet-rows-b): the rows that select the wallet build only.
    let wallet_only = args.iter().any(|a| a == "--wallet-only");
    let replay_only = one_peer_only
        || reclass_only
        || eras_only
        || attr_o2_only
        || rejects_only
        || frozen_only
        || wallet_only;
    let wallet_version = if wallet_only {
        // [D] 2026-10-14, lane fix-121: absent builds are reported by each row.
        let path = Build::Wallet.located();
        json!(Build::Wallet.version_at(&path)?)
    } else {
        Value::Null
    };
    // [D] 2026-10-13: a dedicated replay of the generated #67 table witnesses.
    if args.iter().any(|a| a == "--status-views-only") {
        let scenarios = status_views::run(&root, &record, args.iter().any(|a| a == "--write"))?;
        let failures = scenarios.iter().any(|s| s["counts"]["diverge"] != 0);
        let output = json!({"source_pin":PIN,"version":version,"base_commit":String::from_utf8_lossy(&head.stdout).trim(),"runner_sha256":runner_hash,"started_utc":String::from_utf8_lossy(&started.stdout).trim(),"run_id":run_id,"record":record,"datadir":instance_pointer(&root),"wall_seconds":{"label":"[M]","value":start.elapsed().as_secs_f64()},"scenarios":scenarios,"scope":"#67 status views; producers not run"});
        write_json(&PathBuf::from(record.replace(".md", ".json")), &output)?;
        println!(
            "status views node: {} [X] ([M] 8 scenarios, 16 steps, 48 cells; wall {:.3}s)",
            if failures { "RED" } else { "GREEN" },
            start.elapsed().as_secs_f64()
        );
        return if failures {
            Err("status-view divergence".into())
        } else {
            Ok(())
        };
    }
    // [D] 2026-10-13, lane s6-75: #75 the proof surface on one fresh instance; the
    // full receipt stays in the run, git gets the trimmed projection.
    if args.iter().any(|a| a == "--proofs-only") {
        let scenarios = proofs::run(&root, &record, args.iter().any(|a| a == "--write"))?;
        let failures = scenarios.iter().any(|s| s["counts"]["diverge"] != 0);
        let output = json!({"source_pin":PIN,"version":version,"base_commit":String::from_utf8_lossy(&head.stdout).trim(),"runner_sha256":runner_hash,"started_utc":String::from_utf8_lossy(&started.stdout).trim(),"run_id":run_id,"record":record,"datadir":instance_pointer(&root),"wall_seconds":{"label":"[M]","value":start.elapsed().as_secs_f64()},"scenarios":scenarios,"scope":"#75 proof surface: getmerkleproof, getmerkleproof2 and verifymerkleproof through the Lean TSC view; nothing broadcast"});
        let full_receipt = root.join("receipt.json");
        write_json(&full_receipt, &output)?;
        let trimmed = Command::new("python3")
            .arg("tools/receipt_trim.py")
            .arg(&full_receipt)
            .arg(record.replace(".md", ".json"))
            .args(["--record", &record])
            .output()
            .map_err(|e| e.to_string())?;
        if !trimmed.status.success() {
            return Err(format!(
                "receipt trim: {}",
                String::from_utf8_lossy(&trimmed.stderr)
            ));
        }
        print!("{}", String::from_utf8_lossy(&trimmed.stdout));
        println!(
            "proof surface node: {} [X] ([M] {} steps; wall {:.3}s)",
            if failures { "RED" } else { "GREEN" },
            scenarios[0]["counts"]["rows"],
            start.elapsed().as_secs_f64()
        );
        return if failures {
            Err("proof-surface divergence".into())
        } else {
            Ok(())
        };
    }
    // [D] 2026-10-14, lane fix-73: six dedicated assumevalid instances and two
    // shared safe-mode instances; ten safe-mode rows in file order (see the recipe).
    if args.iter().any(|a| a == "--depth-only") {
        let depth = depth::run(&root, &record, args.iter().any(|a| a == "--write"))?;
        let failures = depth["counts"]["diverge"] != 0 || depth["counts"]["pending"] != 0;
        let output = json!({"source_pin":PIN,"version":version,"base_commit":String::from_utf8_lossy(&head.stdout).trim(),"runner_sha256":runner_hash,"started_utc":String::from_utf8_lossy(&started.stdout).trim(),"run_id":run_id,"record":record,"datadir":instance_pointer(&root),"wall_seconds":{"label":"[M]","value":start.elapsed().as_secs_f64()},"counts":{"depth":depth["counts"]},"families":{"depth":depth["rows"]},"scope":"#73 validation depth and safe mode; no other family replayed"});
        write_json(&root.join("receipt.json"), &output)?;
        write_json(&PathBuf::from(record.replace(".md", ".json")), &output)?;
        println!(
            "depth node: {} [X] ({}; wall [M] {:.3}s)",
            if failures { "RED" } else { "GREEN" },
            depth["counts"],
            start.elapsed().as_secs_f64()
        );
        return if failures {
            Err("depth divergence or pending row".into())
        } else {
            Ok(())
        };
    }
    let mut summaries = BTreeMap::new();
    let mut all = BTreeMap::new();
    let mut pending_marks = BTreeMap::new();
    let write = args.iter().any(|a| a == "--write");
    let families: Vec<&str> = if eras_only {
        vec!["eras"]
    } else if frozen_only {
        vec!["frozen"]
    } else {
        FAMILIES.to_vec()
    };
    // [D] 2026-10-15, lane cut2-66q5 (#66 cut 2): `--family <name>` runs one family's rows
    // alone (the reference's whole column, about 800 s, in foreground calls under ten minutes);
    // the scenarios then run only when `--scenario` names one.
    let family_only = arg("--family");
    for family in families.into_iter().filter(|family| {
        family_only.as_deref().is_none_or(|f| f == *family)
            && !args.iter().any(|a| a == "--intake-only")
            && (!one_peer_only || *family == "chain")
            && (!reclass_only || *family == "mempool")
            && (!attr_o2_only || *family == "mempool")
            && (!rejects_only || *family == "mempool")
            && (!wallet_only || matches!(*family, "mempool" | "finality"))
    }) {
        let family_start = Instant::now();
        let mut results = if rejects_only {
            rejects::rows(&root)?
        } else {
            family_run(family, &root)?
        };
        if family == "mempool" && !replay_only {
            results.extend(rejects::rows(&root)?);
        }
        // [D] 2026-10-13 (#72): a row measured on an instance whose
        // adjusted-time offset or peer offset sample is not zero is recorded,
        // never judged (src/timedata.cpp:28-35 at PIN; DESIGN-S6 4.5).
        for r in &mut results {
            if matches!(r["verdict"].as_str(), Some("agree" | "diverge")) && offset_uncontrolled(r)
            {
                r["verdict"] = json!("non-judging");
                r["qualifier"] = json!("#72: adjusted-time offset not controlled");
            }
        }
        let rows = row_read(family)?;
        let mut marks = BTreeMap::new();
        for row in &rows {
            if wallet_only && Build::of(row)? != Build::Wallet {
                continue;
            }
            if let Some(reason) = unrealizable(family, row) {
                results.push(json!({"id":row["id"],"unrealizable":reason,"label":"[X]"}));
            }
        }
        for r in &mut results {
            let mark = if let Some(reason) = r["unrealizable"].as_str() {
                format!("unrealizable: {reason} [X] {record}")
            } else if r["needs_peer"].is_string() {
                format!("needs-peer #71 [X] {record}")
            } else if r["verdict"] == "rpc-precheck" {
                format!(
                    "rpc-precheck: {} {} ({}) [X] {record}",
                    r["rpc_precheck"]["code"],
                    text(&r["rpc_precheck"]["message"])?,
                    text(&r["rpc_precheck"]["handler"])?
                )
            } else {
                measured_token_dated(r, &record, &String::from_utf8_lossy(&started.stdout)[..10])
            };
            r["token"] = json!(mark);
            marks.insert(text(&r["id"])?.to_owned(), mark);
        }
        let realized = results
            .iter()
            .filter(|r| matches!(r["verdict"].as_str(), Some("agree" | "diverge")))
            .count();
        let agree = results.iter().filter(|r| r["verdict"] == "agree").count();
        let pre = results
            .iter()
            .filter(|r| r["verdict"] == "rpc-precheck")
            .count();
        let un = results
            .iter()
            .filter(|r| r.get("unrealizable").is_some())
            .count();
        let peer = results
            .iter()
            .filter(|r| r.get("needs_peer").is_some())
            .count();
        let non_judging = results
            .iter()
            .filter(|r| r["verdict"] == "non-judging")
            .count();
        let counts = json!({"label":"[M]","rows":rows.len(),"realized":realized,"agree":agree,"diverge":realized-agree,"rpc-precheck":pre,"unrealizable":un,"non-judging":non_judging,"needs-peer":peer,"pending":if replay_only {0} else {rows.len()-results.len()},"replayed":results.len(),"inherited":if replay_only {rows.len()-results.len()} else {0},"wall_seconds":family_start.elapsed().as_secs_f64()});
        println!("node-scenarios {family}: {counts}");
        summaries.insert(family, counts);
        all.insert(family, json!(results));
        pending_marks.insert(family, marks);
    }
    let mut scenarios = vec![];
    for name in [
        "2026-10-12-mempool-presence-terminal",
        "2026-10-12-bumpless-beef-stored-proof",
        "2026-10-13-orphaned-block-proof",
        // [D] 2026-10-13 (#72): the done-bar, assembly excluding a low fee.
        "2026-10-13-assembly-excludes-low-fee",
        // [D] 2026-10-15, lane cut2-66q2 (#90): conflicting spends under arrival order,
        // concurrency and reorg.
        "2026-10-14-conflicting-spends-order",
        // [D] 2026-10-15, lane cut2-66q2 (#91): the sentinel's refusal pair.
        "2026-10-15-sentinel-refusal-pair",
    ]
    .into_iter()
    .filter(|name| {
        !replay_only
            && (family_only.is_none() || arg("--scenario").is_some())
            && arg("--scenario").is_none_or(|selected| selected == *name)
    }) {
        let v = scenario_run(
            &PathBuf::from(format!("corpus/scenarios/{name}.md")),
            &root,
            &record,
        )?;
        if write {
            mark_scenario(&PathBuf::from(format!("corpus/scenarios/{name}.md")), &v)?;
            write_json(
                &PathBuf::from(format!("corpus/scenarios/{name}.node.json")),
                &v,
            )?;
        }
        scenarios.push(v);
    }
    let witness = if attr_o2_only {
        mempool::o2_witness(&root)?
    } else {
        Value::Null
    };
    let mut output = json!({"source_pin":PIN,"version":version,"base_commit":String::from_utf8_lossy(&head.stdout).trim(),"runner_sha256":runner_hash,"started_utc":String::from_utf8_lossy(&started.stdout).trim(),"run_id":run_id,"record":record,"datadir":instance_pointer(&root),"wall_seconds":{"label":"[M]","value":start.elapsed().as_secs_f64()},"counts":summaries,"families":all,"scenarios":scenarios,"scope":if eras_only {"#69 era boundaries: the eras family only; the six #66 families are untouched"} else if one_peer_only {"O-1: two header recipes; other tokens inherited"} else if reclass_only {"reclass-66b: eleven limited mempool rows over the loopback peer; other tokens inherited"} else if attr_o2_only {"attr-o2: the nine disk-counter mempool rows and O-2's witness; other tokens inherited"} else if rejects_only {"#71: the reject-cache and time-budget trace rows over the loopback peer; other tokens inherited"} else if frozen_only {"#70 operator lists: the frozen family only; the other families are untouched"} else if wallet_only {"#121: the rows that select the wallet build (\"binary\":\"wallet\"), each on a fresh wallet-enabled instance of that build; other tokens inherited"} else if family_only.is_some() {"#66 cut 2: one family's rows (--family); the other families are untouched"} else {"partial cut 1; unimplemented boundaries remain pending #66"}});
    if attr_o2_only {
        output["o2_witness"] = witness;
    }
    if wallet_only {
        output["wallet_version"] = wallet_version;
    }
    // [D] 2026-10-13 S3: full evidence stays in the run; git gets the projection.
    let full_receipt = root.join("receipt.json");
    write_json(&full_receipt, &output)?;
    let trimmed = Command::new("python3")
        .arg("tools/receipt_trim.py")
        .arg(&full_receipt)
        .arg(record.replace(".md", ".json"))
        .args(["--record", &record])
        .output()
        .map_err(|e| e.to_string())?;
    if !trimmed.status.success() {
        return Err(format!(
            "receipt trim: {}",
            String::from_utf8_lossy(&trimmed.stderr)
        ));
    }
    print!("{}", String::from_utf8_lossy(&trimmed.stdout));
    if write {
        for (family, rows) in output["families"].as_object().ok_or("families")? {
            for row in rows.as_array().ok_or("family rows")? {
                if row["verdict"] == "diverge" {
                    write_witness(family, row, &record, &full_receipt)?;
                }
            }
        }
        for (family, marks) in pending_marks {
            mark_rows(family, &marks)?;
        }
    }
    println!(
        "node-scenarios: recorded partial [X]; wall [M] {:.3}s",
        start.elapsed().as_secs_f64()
    );
    Ok(())
}
pub fn main() {
    signals();
    if let Err(e) = main_run() {
        eprintln!("node-scenarios: ERROR {e}");
        std::process::exit(1);
    }
}

#[cfg(test)]
mod record_name {
    #[test]
    fn lane_suffix_widened_and_bounded() {
        for ok in [
            "docs/records/20261013-041541-s6-66c-regtest-s3.md",
            "docs/records/20261013-140000-s6-pend-66-regtest-s3.md",
        ] {
            assert!(super::record_name_ok(ok), "{ok}");
        }
        for bad in [
            "docs/records/20261013-140000-s6-66c-regtest-s3.json",
            "docs/records/x/../20261013-s6-66c-regtest-s3.md",
            "docs/records/-s6-66c-regtest-s3.md",
            "docs/records/20261013-s6--regtest-s3.md",
            "docs/records/20261013-s6-Pend-regtest-s3.md",
            "records/20261013-s6-66c-regtest-s3.md",
        ] {
            assert!(!super::record_name_ok(bad), "{bad}");
        }
    }
}
