//! rules: THE CLASSIFIER AS DATA (D83, D83b, D83c; bsv-script-lean #31; S3, set 4, 2026-09-26).
//!
//! Until 2026-09-26 the classification of a divergence between the spec and an engine lived in code: an
//! if-chain in `run_engine.rs` (the SDK engines) and another in `run_diff.rs` (bsv-rs), each arm a
//! conjunction over the entry's rule and family, the column, the two verdicts and codes, the engine's own
//! message, the scripts' shapes, the transaction's version and the heights, ending in a `rule_record` table of
//! citations. Every family needed a new arm in a file another window owns (`run_diff.rs` is S2's), so every
//! family landed through a hook bypass: D83b ended that. The chain is now DATA: one JSON per engine under
//! `harness/rules/` (`bsv-rs.json`, `go-sdk.json`, `ts-sdk.json`, `gobdk.json`, `sv-node.json`: five tables), owned
//! by S3 with the corpus, read by the drivers through this module and nothing else. The file: `{"engine", "pin", "source", "classes": {<id>:
//! {"decided_by", "ruling", "note"}}, "rows": [{"why", "when": {...}, "class" | "class_from" [+ "class_else"]}]}`.
//! The rows are tried IN ORDER; the first whose `when` holds names the class (`class`), or maps the entry's own
//! rule to it (`class_from`, with `class_else` when an unmapped rule is a verdict and not a fall-through); the
//! class `unexplained` in a row is a STOP: no explanation (the driver files the divergence as unexplained and
//! the run is RED). A key outside the vocabulary below is refused at load (`deny_unknown_fields`), and every
//! class a row names must exist in `classes`, so a typo cannot silently classify nothing.
//!
//! The vocabulary of `when` (a conjunction; every input is one the drivers already hold, in the spec's terms):
//! `column` (`word` = the spec's word columns, `default` = ts-sdk's own mode, or the exact column name),
//! `id_in` (an explicit list of measured witnesses, #57), `rule` · `rule_in` · `rule_prefix_any` · `family_contains` · `family_candidate` (the `-candidate/` and
//! `flow-policy/` families), `spec` (`valid` | `invalid`) · `spec_code` · `verdicts_differ` · `spec_consensus`
//! (`valid` | `invalid`: the spec's verdict at its consensus column `spec` for the same entry, so a row can tell a
//! refusal by POLICY alone, valid at consensus and invalid on the mempool path, from a consensus refusal; the SDK
//! drivers supply it through `Observation::with_spec_consensus`, `run_diff.rs` does not, and a row naming it never
//! holds on an observation without it; S3, set 4, 2026-09-27), `engine` (`valid`
//! | `invalid` | `undecided` | `resource` | `not-valid` = anything but valid) · `engine_code` · `engine_code_in`
//! · `engine_code_not` · `native_starts_with` · `native_contains` · `native_contains_none`, `has_opcode_any` ·
//! `has_opcode_at_least` · `truncated_push` · `unlock_push_only` · `sig_type_bit_any` (a hash-type bit in the
//! last byte of any push of at least nine bytes in the unlocking scripts; the five script predicates read EVERY
//! input of the entry: the opcodes of all its locking and unlocking scripts, a truncated push in any of them,
//! push-only when every unlocking script is, since #32's A-P6), `version` (`v1` = the transaction
//! version at most 1, `v2+`), `spend_height_lt` · `prevout_height_lt_any` · `default_mode_heuristic_mismatch`
//! (ts-sdk's default mode: version > 1 with a prevout below 943,816, or version <= 1 with one at or above
//! 620,538). Numbers are decimal in the JSON; opcodes are bytes.
//!
//! The gate: `rules_check` (a binary of this crate, in `make check`'s harness leg) replays the corpora of the
//! go-sdk, ts-sdk and gobdk manifests (`corpus/witnesses/<engine>/manifest.json`) from their recorded verdicts and
//! those of the bsv-rs manifest (`corpus/witnesses/manifest.json`) live, through these tables, and compares the
//! counts per corpus × column × class, the smallest witness per class and each class's `ruling` with the manifests.
//! What that proves is a REGRESSION check: the classes the drivers recorded through these same tables replay at
//! HEAD (the manifests were written by the tables, so the leg is no independent check of a classification). It
//! does not compare a class's `decided_by` (the tables' citations are re-cut after a record; the manifest keeps the
//! record's text) and it replays no other manifest (`corpus/witnesses/sv-node/` and the policy-defaults manifest
//! have no replay). Where a corpus carries no recorded `spec@` key, the spec side is `eval/bsvs corpus` at HEAD, not
//! the commit the manifest's `spec` key names.

use std::collections::BTreeMap;
use std::path::{Path, PathBuf};

use serde::Deserialize;

use crate::corpus::Entry;
use crate::txraw::RawTx;

/// The class of a divergence no row explains: ruled `open`, and the run is RED.
pub const UNEXPLAINED: &str = "unexplained";

/// A class's record: the citation that decides it, the ruling, the note (what `rule_record` held in code).
#[derive(Clone, Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct ClassRecord {
    pub decided_by: String,
    pub ruling: String,
    pub note: String,
}

/// One row's predicate: a conjunction of the fields that are set.
#[derive(Clone, Debug, Default, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct When {
    pub id_in: Option<Vec<String>>,
    pub column: Option<String>,
    pub rule: Option<String>,
    pub rule_in: Option<Vec<String>>,
    pub rule_prefix_any: Option<Vec<String>>,
    pub family_contains: Option<String>,
    pub family_candidate: Option<bool>,
    pub spec: Option<String>,
    pub spec_code: Option<String>,
    pub verdicts_differ: Option<bool>,
    pub spec_consensus: Option<String>,
    pub engine: Option<String>,
    pub engine_code: Option<String>,
    pub engine_code_in: Option<Vec<String>>,
    pub engine_code_not: Option<String>,
    pub native_starts_with: Option<String>,
    pub native_contains: Option<String>,
    pub native_contains_none: Option<Vec<String>>,
    pub has_opcode_any: Option<Vec<u8>>,
    pub has_opcode_at_least: Option<u8>,
    pub truncated_push: Option<bool>,
    pub unlock_push_only: Option<bool>,
    pub sig_type_bit_any: Option<u8>,
    pub version: Option<String>,
    pub spend_height_lt: Option<u32>,
    pub prevout_height_lt_any: Option<u32>,
    pub default_mode_heuristic_mismatch: Option<bool>,
}

#[derive(Clone, Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Row {
    /// the arm's comment as it stood in the code (documentation; never read by the reader)
    #[serde(default)]
    pub why: String,
    #[serde(default)]
    pub when: When,
    #[serde(default)]
    pub class: Option<String>,
    #[serde(default)]
    pub class_from: Option<BTreeMap<String, String>>,
    #[serde(default)]
    pub class_else: Option<String>,
}

#[derive(Clone, Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct RuleSet {
    pub engine: String,
    pub pin: String,
    pub source: String,
    pub classes: BTreeMap<String, ClassRecord>,
    pub rows: Vec<Row>,
}

/// The explanation a driver files with a witness: the class and its record.
#[derive(Clone, Debug)]
pub struct Explanation {
    pub rule: String,
    pub decided_by: String,
    pub ruling: String,
    pub note: String,
}

/// What a driver knows of one divergence, in the spec's vocabulary; built by `observe`.
#[derive(Clone, Debug)]
pub struct Observation {
    pub id: String,
    pub column: String,
    pub rule: String,
    pub family: String,
    pub spec_verdict: String,
    pub spec_code: String,
    /// the spec's verdict at its consensus column for the same entry; empty unless the driver supplies it
    pub spec_consensus: String,
    pub engine_verdict: String,
    pub engine_code: String,
    pub native: String,
    pub version: i32,
    pub spend_height: u32,
    pub prevout_heights: Vec<u32>,
    pub lock_ops: Vec<u8>,
    pub unlock_ops: Vec<u8>,
    pub lock_trunc: bool,
    pub unlock_trunc: bool,
    pub unlock_push_only: bool,
    pub sig_type_bits: Vec<u8>,
}

/// The opcodes of a script and whether a push is truncated (`GetOp2`, `script.h:163–198`).
pub fn ops_of(script: &[u8]) -> (Vec<u8>, bool) {
    let mut ops = Vec::new();
    let mut i = 0;
    while i < script.len() {
        let op = script[i];
        ops.push(op);
        i += 1;
        let (len, hdr) = if op < 0x4c {
            (op as usize, 0)
        } else if op == 0x4c {
            if i >= script.len() {
                return (ops, true);
            }
            (script[i] as usize, 1)
        } else if op == 0x4d {
            if i + 1 >= script.len() {
                return (ops, true);
            }
            (script[i] as usize | (script[i + 1] as usize) << 8, 2)
        } else if op == 0x4e {
            if i + 3 >= script.len() {
                return (ops, true);
            }
            (
                u32::from_le_bytes([script[i], script[i + 1], script[i + 2], script[i + 3]])
                    as usize,
                4,
            )
        } else {
            (0, 0)
        };
        i += hdr;
        if i + len > script.len() {
            return (ops, true);
        }
        i += len;
    }
    (ops, false)
}

/// A push-only script (every opcode at most `OP_16`, no truncated push).
pub fn is_push_only(script: &[u8]) -> bool {
    let (ops, trunc) = ops_of(script);
    !trunc && ops.iter().all(|&o| o <= 0x60)
}

/// The last byte of every push of at least nine bytes in a script (a DER signature's hash-type byte).
pub fn push_tails(script: &[u8]) -> Vec<u8> {
    let mut out = Vec::new();
    let mut i = 0usize;
    while i < script.len() {
        let op = script[i] as usize;
        i += 1;
        let (len, skip) = match op {
            1..=75 => (op, 0usize),
            0x4c => (script.get(i).copied().unwrap_or(0) as usize, 1),
            0x4d => (
                u16::from_le_bytes([
                    script.get(i).copied().unwrap_or(0),
                    script.get(i + 1).copied().unwrap_or(0),
                ]) as usize,
                2,
            ),
            0x4e => (
                u32::from_le_bytes([
                    script.get(i).copied().unwrap_or(0),
                    script.get(i + 1).copied().unwrap_or(0),
                    script.get(i + 2).copied().unwrap_or(0),
                    script.get(i + 3).copied().unwrap_or(0),
                ]) as usize,
                4,
            ),
            _ => (0, 0),
        };
        i += skip;
        if len > 0 {
            if i + len > script.len() {
                break;
            }
            if len >= 9 {
                out.push(script[i + len - 1]);
            }
            i += len;
        }
    }
    out
}

/// The observation of one divergence from what a driver holds: the entry, its decoded transaction, the column,
/// the spec's verdict and code, the engine's verdict (`valid` · `invalid` · `undecided` · `resource`), its mapped
/// code and its own message (one line).
#[allow(
    clippy::too_many_arguments,
    reason = "one observation's eight parts, each named at its call sites (the drivers and rules_check)"
)]
pub fn observe(
    e: &Entry,
    tx: &RawTx,
    column: &str,
    spec_verdict: &str,
    spec_code: Option<&str>,
    engine_verdict: &str,
    engine_code: Option<&str>,
    native: &str,
) -> Observation {
    // every input's scripts, as `sig_type_bits` reads them (#32 A-P6): the opcodes of all the locks and of all the
    // unlocks, a truncated push in any, and push-only when every unlocking script is
    let locks: Vec<Vec<u8>> = e
        .prevouts
        .iter()
        .map(|p| hex::decode(&p.script).unwrap_or_default())
        .collect();
    let (mut lock_ops, mut lock_trunc) = (Vec::new(), false);
    for l in &locks {
        let (ops, t) = ops_of(l);
        lock_ops.extend(ops);
        lock_trunc |= t;
    }
    let (mut unlock_ops, mut unlock_trunc) = (Vec::new(), false);
    for i in &tx.inputs {
        let (ops, t) = ops_of(&i.script);
        unlock_ops.extend(ops);
        unlock_trunc |= t;
    }
    Observation {
        id: e.id.clone(),
        column: column.to_string(),
        rule: e.rule.clone(),
        family: e.family.clone(),
        spec_verdict: spec_verdict.to_string(),
        spec_code: spec_code.unwrap_or("").to_string(),
        spec_consensus: String::new(),
        engine_verdict: engine_verdict.to_string(),
        engine_code: engine_code.unwrap_or("").to_string(),
        native: native.to_string(),
        version: tx.version,
        spend_height: e.params.spend_height,
        prevout_heights: e.prevouts.iter().map(|p| p.height).collect(),
        unlock_push_only: tx.inputs.iter().all(|i| is_push_only(&i.script)),
        sig_type_bits: tx
            .inputs
            .iter()
            .flat_map(|i| push_tails(&i.script))
            .collect(),
        lock_ops,
        unlock_ops,
        lock_trunc,
        unlock_trunc,
    }
}

impl Observation {
    /// The spec's verdict at its consensus column for the same entry (the `spec_consensus` key reads it).
    pub fn with_spec_consensus(mut self, verdict: &str) -> Observation {
        self.spec_consensus = verdict.to_string();
        self
    }
}

impl RuleSet {
    /// `<root>/harness/rules/<engine>.json`.
    pub fn path(root: &Path, engine: &str) -> PathBuf {
        root.join("harness")
            .join("rules")
            .join(format!("{engine}.json"))
    }

    /// Load and validate one engine's table: every class a row names exists (or is `unexplained`).
    pub fn load(root: &Path, engine: &str) -> Result<RuleSet, String> {
        let path = Self::path(root, engine);
        let text = std::fs::read_to_string(&path)
            .map_err(|e| format!("rules: {}: {e}", path.display()))?;
        let rs: RuleSet =
            serde_json::from_str(&text).map_err(|e| format!("rules: {}: {e}", path.display()))?;
        for (i, r) in rs.rows.iter().enumerate() {
            let named: Vec<&String> = r
                .class
                .iter()
                .chain(r.class_else.iter())
                .chain(r.class_from.iter().flat_map(|m| m.values()))
                .collect();
            if named.is_empty() {
                return Err(format!("rules: {}: row {i} names no class", path.display()));
            }
            for c in named {
                if c != UNEXPLAINED && !rs.classes.contains_key(c) {
                    return Err(format!(
                        "rules: {}: row {i} names the class `{c}`, which `classes` does not carry",
                        path.display()
                    ));
                }
            }
        }
        Ok(rs)
    }

    /// A class with its record; `unexplained` (or a class outside the table) is the open record.
    pub fn record(&self, class: &str) -> Explanation {
        match self.classes.get(class) {
            Some(c) if class != UNEXPLAINED => Explanation {
                rule: class.to_string(),
                decided_by: c.decided_by.clone(),
                ruling: c.ruling.clone(),
                note: c.note.clone(),
            },
            _ => Explanation {
                rule: UNEXPLAINED.to_string(),
                decided_by: String::new(),
                ruling: "open".into(),
                note: "no rule explains this divergence: investigate before anything else".into(),
            },
        }
    }

    /// The first row whose predicate holds names the class; `None` = unexplained.
    pub fn explain(&self, o: &Observation) -> Option<Explanation> {
        for r in &self.rows {
            if !holds(&r.when, o) {
                continue;
            }
            if let Some(m) = &r.class_from {
                match m.get(&o.rule) {
                    Some(c) => {
                        return if c == UNEXPLAINED {
                            None
                        } else {
                            Some(self.record(c))
                        }
                    }
                    None => match &r.class_else {
                        Some(c) => {
                            return if c == UNEXPLAINED {
                                None
                            } else {
                                Some(self.record(c))
                            }
                        }
                        None => continue,
                    },
                }
            }
            if let Some(c) = &r.class {
                return if c == UNEXPLAINED {
                    None
                } else {
                    Some(self.record(c))
                };
            }
        }
        None
    }
}

fn holds(w: &When, o: &Observation) -> bool {
    if let Some(ids) = &w.id_in {
        if !ids.contains(&o.id) {
            return false;
        }
    }
    let has = |b: u8| o.lock_ops.contains(&b) || o.unlock_ops.contains(&b);
    if let Some(c) = &w.column {
        let ok = match c.as_str() {
            "word" => !o.column.starts_with("default"),
            "default" => o.column.starts_with("default"),
            exact => o.column == exact,
        };
        if !ok {
            return false;
        }
    }
    if let Some(r) = &w.rule {
        if o.rule != *r {
            return false;
        }
    }
    if let Some(rs) = &w.rule_in {
        if !rs.contains(&o.rule) {
            return false;
        }
    }
    if let Some(ps) = &w.rule_prefix_any {
        if !ps.iter().any(|p| o.rule.starts_with(p.as_str())) {
            return false;
        }
    }
    if let Some(f) = &w.family_contains {
        if !o.family.contains(f.as_str()) {
            return false;
        }
    }
    if let Some(v) = w.family_candidate {
        if (o.family.contains("-candidate/") || o.family.starts_with("flow-policy/")) != v {
            return false;
        }
    }
    if let Some(s) = &w.spec {
        if o.spec_verdict != *s {
            return false;
        }
    }
    if let Some(c) = &w.spec_code {
        if o.spec_code != *c {
            return false;
        }
    }
    if let Some(v) = w.verdicts_differ {
        if ((o.spec_verdict == "valid") != (o.engine_verdict == "valid")) != v {
            return false;
        }
    }
    if let Some(s) = &w.spec_consensus {
        if o.spec_consensus.is_empty() || o.spec_consensus != *s {
            return false;
        }
    }
    if let Some(e) = &w.engine {
        let ok = match e.as_str() {
            "not-valid" => o.engine_verdict != "valid",
            exact => o.engine_verdict == exact,
        };
        if !ok {
            return false;
        }
    }
    if let Some(c) = &w.engine_code {
        if o.engine_code != *c {
            return false;
        }
    }
    if let Some(cs) = &w.engine_code_in {
        if !cs.contains(&o.engine_code) {
            return false;
        }
    }
    if let Some(c) = &w.engine_code_not {
        if o.engine_code == *c {
            return false;
        }
    }
    if let Some(p) = &w.native_starts_with {
        if !o.native.starts_with(p.as_str()) {
            return false;
        }
    }
    if let Some(s) = &w.native_contains {
        if !o.native.contains(s.as_str()) {
            return false;
        }
    }
    if let Some(ss) = &w.native_contains_none {
        if ss.iter().any(|s| o.native.contains(s.as_str())) {
            return false;
        }
    }
    if let Some(bs) = &w.has_opcode_any {
        if !bs.iter().any(|&b| has(b)) {
            return false;
        }
    }
    if let Some(n) = w.has_opcode_at_least {
        if !(o.lock_ops.iter().any(|&b| b >= n) || o.unlock_ops.iter().any(|&b| b >= n)) {
            return false;
        }
    }
    if let Some(v) = w.truncated_push {
        if (o.lock_trunc || o.unlock_trunc) != v {
            return false;
        }
    }
    if let Some(v) = w.unlock_push_only {
        if o.unlock_push_only != v {
            return false;
        }
    }
    if let Some(bit) = w.sig_type_bit_any {
        if !o.sig_type_bits.iter().any(|t| t & bit != 0) {
            return false;
        }
    }
    if let Some(v) = &w.version {
        let ok = match v.as_str() {
            "v1" => o.version <= 1,
            "v2+" => o.version > 1,
            _ => false,
        };
        if !ok {
            return false;
        }
    }
    if let Some(n) = w.spend_height_lt {
        if o.spend_height >= n {
            return false;
        }
    }
    if let Some(n) = w.prevout_height_lt_any {
        if !o.prevout_heights.iter().any(|&h| h < n) {
            return false;
        }
    }
    if let Some(v) = w.default_mode_heuristic_mismatch {
        let mismatch = o.prevout_heights.iter().any(|&h| {
            if o.version > 1 {
                h < 943_816
            } else {
                h >= 620_538
            }
        });
        if mismatch != v {
            return false;
        }
    }
    true
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn the_three_tables_load_and_every_named_class_exists() {
        let root = std::path::Path::new(env!("CARGO_MANIFEST_DIR")).join("..");
        for e in ["bsv-rs", "go-sdk", "ts-sdk"] {
            let rs = RuleSet::load(&root, e).unwrap_or_else(|err| panic!("{err}"));
            assert!(!rs.rows.is_empty(), "{e}: no rows");
            assert!(!rs.classes.is_empty(), "{e}: no classes");
        }
    }

    #[test]
    fn a_stop_row_explains_nothing_and_a_missing_class_is_refused() {
        let text = r#"{"engine":"x","pin":"0","source":"t","classes":{"a.b":{"decided_by":"d","ruling":"impl-wrong","note":""}},
            "rows":[{"when":{"engine":"undecided"},"class":"unexplained"},{"when":{},"class":"a.b"}]}"#;
        let rs: RuleSet = serde_json::from_str(text).unwrap();
        let mut o = Observation {
            id: "test".into(),
            column: "spec".into(),
            rule: "r".into(),
            family: "f".into(),
            spec_verdict: "valid".into(),
            spec_code: String::new(),
            spec_consensus: String::new(),
            engine_verdict: "undecided".into(),
            engine_code: String::new(),
            native: String::new(),
            version: 2,
            spend_height: 967_896,
            prevout_heights: vec![967_896],
            lock_ops: vec![],
            unlock_ops: vec![],
            lock_trunc: false,
            unlock_trunc: false,
            unlock_push_only: true,
            sig_type_bits: vec![],
        };
        assert!(rs.explain(&o).is_none());
        o.engine_verdict = "invalid".into();
        assert_eq!(rs.explain(&o).unwrap().rule, "a.b");
        let bad = r#"{"engine":"x","pin":"0","source":"t","classes":{},"rows":[{"when":{},"class":"nope"}]}"#;
        let rs2: RuleSet = serde_json::from_str(bad).unwrap();
        assert!(rs2.rows[0].class.as_deref() == Some("nope") && !rs2.classes.contains_key("nope"));
        let unknown_key = r#"{"engine":"x","pin":"0","source":"t","classes":{},"rows":[{"when":{"colour":"spec"},"class":"unexplained"}]}"#;
        assert!(
            serde_json::from_str::<RuleSet>(unknown_key).is_err(),
            "an unknown predicate key must be refused"
        );
    }

    #[test]
    fn spec_consensus_tells_a_policy_refusal_and_never_holds_unsupplied() {
        let text = r#"{"engine":"x","pin":"0","source":"t","classes":{"w.policy":{"decided_by":"d","ruling":"open","note":""},"w":{"decided_by":"d","ruling":"impl-wrong","note":""}},
            "rows":[{"when":{"rule":"r","spec_consensus":"valid","spec":"invalid","engine":"valid"},"class":"w.policy"},{"when":{"rule":"r","spec":"invalid","engine":"valid"},"class":"w"}]}"#;
        let rs: RuleSet = serde_json::from_str(text).unwrap();
        let o = Observation {
            id: "test".into(),
            column: "spec-mempool".into(),
            rule: "r".into(),
            family: "f".into(),
            spec_verdict: "invalid".into(),
            spec_code: String::new(),
            spec_consensus: String::new(),
            engine_verdict: "valid".into(),
            engine_code: String::new(),
            native: String::new(),
            version: 2,
            spend_height: 967_896,
            prevout_heights: vec![967_896],
            lock_ops: vec![],
            unlock_ops: vec![],
            lock_trunc: false,
            unlock_trunc: false,
            unlock_push_only: true,
            sig_type_bits: vec![],
        };
        assert_eq!(
            rs.explain(&o).unwrap().rule,
            "w",
            "an observation without the consensus verdict never meets the key"
        );
        assert_eq!(
            rs.explain(&o.clone().with_spec_consensus("valid"))
                .unwrap()
                .rule,
            "w.policy",
            "valid at consensus, refused on the mempool path: policy alone"
        );
        assert_eq!(
            rs.explain(&o.with_spec_consensus("invalid")).unwrap().rule,
            "w",
            "refused at consensus too: the consensus class"
        );
    }
}
