//! VENDORED (adapted from a predecessor harness of the owner's, mechanism-free):
//! its harness module (the run_lock pattern: a synthetic
//! outpoint carrying the lock, a version-2 spend with one output, the unlock as
//! pushes, the Spend wiring), its fuzz binary lines 71–168 (Verdict,
//! SpendCase, Mode, run_case: catch_unwind around Spend::validate) and
//! its library root lines 458–519 (verify_tx: the per-input SpendParams wiring,
//! other_inputs with empty scripts, outputs) @ 0fc5ced on 2026-09-22
//! (bsv-script-lean #4).
//! Mechanism check: no covenant, no builder, no PUSHTX/preimage machinery, no
//! sighash construction, no key, no transaction, txid or block of any private
//! program crossed; the only bytes this module ever sees are the corpus entry's
//! own transaction and prevouts. Modifications below are this repo's: the case is
//! a raw transaction plus its prevouts (`txraw`, the corpus format) instead of a
//! the predecessor library's Transaction; the engine configuration is explicit and recorded
//! (`EngineConfig`); resource exhaustion and panics are `undecided`, not
//! `invalid`; since the pin moved to bsv-rs 0.3.27 (2026-09-23, #24's engine
//! leg, #40's pin; 0.4.4 since 2026-10-12, 0.3.33 from 2026-10-07, 0.3.32 from 2026-10-06, 0.3.30 from 2026-09-27, 0.3.28 from 2026-09-24, 0.3.29 and 0.3.31 never pinned; the lines below at 0.4.4, the crates.io copy of `5c15528`) the engine runs under the NODE'S FLAG WORD
//! (`Spend::set_flags`, `bsv_rs::script::ScriptFlags`: the reference's two
//! derivations `block(era)` and `standard(era)`, `verify_script_flags.cpp:11–81`
//! with `policy.h:226–245`, transcribed in the crate), the TypeScript SDK's
//! default mode being neither word.

use std::collections::BTreeMap;
use std::panic::{catch_unwind, AssertUnwindSafe};

use bsv_rs::primitives::bsv::sighash::{TxInput as SigTxInput, TxOutput as SigTxOutput};
use bsv_rs::script::spend::{Spend, SpendParams};
use bsv_rs::script::{LockingScript, ProtocolEra, ScriptFlags, UnlockingScript};

use crate::txraw::RawTx;

/// What an implementation said about one spend.
#[derive(Clone, PartialEq, Eq, Debug)]
pub enum Verdict {
    /// The scripts ran and left a true top element: the spend is valid.
    Accept,
    /// The scripts ran and left a false top element.
    RejectFalse,
    /// The interpreter stopped with an error (the implementation's message).
    ErrorV(String),
    /// A LOCAL budget of the implementation was exhausted (bsv-rs's
    /// `resource_limit`): a verdict about the evaluator, not the script.
    Resource(String),
    /// The implementation crashed.
    Panic(String),
    /// The implementation could not parse the lock or unlock bytes as a script.
    Unparseable(String),
    /// The implementation does not model the rules the input needs (bsv-rs: a
    /// pre-Genesis block or coin, `flags.rs`: "the post-Genesis rule set only"):
    /// the corpus's `undecided`, reported and never counted (#20).
    NotApplicable(String),
}

impl Verdict {
    pub fn accepted(&self) -> bool {
        matches!(self, Verdict::Accept)
    }
    /// The corpus vocabulary (`docs/DESIGN.md` §6): valid · invalid · undecided.
    pub fn kind(&self) -> &'static str {
        match self {
            Verdict::Accept => "valid",
            Verdict::RejectFalse | Verdict::ErrorV(_) | Verdict::Unparseable(_) => "invalid",
            Verdict::Resource(_) | Verdict::Panic(_) | Verdict::NotApplicable(_) => "undecided",
        }
    }
    pub fn reason(&self) -> Option<String> {
        match self {
            Verdict::Accept => None,
            Verdict::RejectFalse => Some("false top element".into()),
            Verdict::ErrorV(m) => Some(m.clone()),
            Verdict::Resource(m) => Some(format!("resource limit: {m}")),
            Verdict::Panic(m) => Some(format!("panic: {m}")),
            Verdict::Unparseable(m) => Some(format!("unparseable: {m}")),
            Verdict::NotApplicable(m) => Some(format!("not applicable: {m}")),
        }
    }
}

/// A previous output the transaction spends, aligned with `tx.inputs[i]`.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Prevout {
    /// Internal byte order.
    pub txid: [u8; 32],
    pub vout: u32,
    pub script: Vec<u8>,
    pub satoshis: u64,
}

/// The engine mode of the differential (the predecessor's O1).
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum Mode {
    /// The transaction's own version (2 → the relaxed branch under the word's version gate).
    Native,
    /// The version forced to 1: the gate ON (MINIMALDATA, LOW_S, CLEANSTACK, NULLDUMMY,
    /// NULLFAIL, SIGPUSHONLY under the word).
    V1Strict,
    /// The native version with `require_minimal` forced on: isolates the
    /// encoding axis from the sighash axis.
    V2MinimalOnly,
}

/// The reference's per-input word of a spend in block `spend_height` of a coin created
/// at `utxo_height` on mainnet, as bsv-rs can carry it (#20): the block word or the
/// standard word of the spend's era (`ScriptFlags::block`/`standard`,
/// `verify_script_flags.cpp:32–81`, `11–30`) with the coin's Chronicle marker set by the
/// COIN's era, not the block's (`InputScriptVerifyFlags`, `policy.h:235–242`; the crate's
/// `block(era)` sets both markers from the one era). `None` when the spend or the coin is
/// pre-Genesis: bsv-rs models neither a pre-Genesis block (`ProtocolEra::at_height`, `None`
/// below the Genesis height) nor a pre-Genesis coin (`ScriptFlags::check`: "UTXO_AFTER_GENESIS
/// is not set: pre-Genesis UTXO rules are not implemented by this interpreter"), so such an
/// input is `Verdict::NotApplicable`, the corpus's `undecided`.
pub fn word_for(spend_height: u32, utxo_height: u32, consensus: bool) -> Option<ScriptFlags> {
    let era = ProtocolEra::mainnet(spend_height)?;
    let utxo_era = ProtocolEra::mainnet(utxo_height)?;
    let base = if consensus {
        ScriptFlags::block(era)
    } else {
        ScriptFlags::standard(era)
    };
    let w = base.without(ScriptFlags::UTXO_AFTER_CHRONICLE);
    Some(if utxo_era.is_chronicle() {
        w | ScriptFlags::UTXO_AFTER_CHRONICLE
    } else {
        w
    })
}

/// The bsv-rs knobs the runner sets, recorded in every manifest so a verdict is
/// never quoted without its configuration.
///
/// * `flags`: the node's flag word the engine runs under (`Spend::set_flags`; the
///   word's rules under the reference's version gate at every site,
///   `interpreter.cpp:40–44`). `None` = the TypeScript SDK's default mode
///   (`spend.rs:399–402`, `412` at 0.4.4: MINIMALDATA, LOW_S, CLEANSTACK, NULLDUMMY for
///   version ≤ 1 only, push-only at every version, never NULLFAIL, MINIMALIF or
///   DISCOURAGE_UPGRADABLE_NOPS, the Chronicle opcodes for version > 1, a number of
///   any length), which is neither of the node's words.
/// * `require_push_only`: the default mode's knob (read only when `flags` is `None`;
///   under a word push-only is the word's rule, `interpreter.cpp:2321–2334`).
/// * `memory_limit`: `None` = bsv-rs's `DEFAULT_MEMORY_LIMIT` (32,000,000 bytes per
///   stack, `spend.rs:109`), a LOCAL budget reported as `undecided`.
/// * the script-number length limit (0.3.28, bsv-rs#17): under a word the crate applies
///   the reference's limit by itself (`Spend::max_script_num_length`, `spend.rs:525–537`:
///   the coin's era's consensus width on the block path, the policy default of 10,000 on
///   the mempool path, `flags.rs:379–390`); the runner sets no policy (`set_script_num_length_policy`
///   stays at the node's default, `docs/PARAMETERS.md` §3).
///
/// The default is the **standard word of a post-Chronicle block**
/// (`ScriptFlags::standard(PostChronicle)` = `0x3D47FF`, the mempool word of
/// SV-node's mainnet defaults, `docs/PARAMETERS.md` §6): what every generated
/// corpus records as `bsv-rs@<version>`, the word the Lean legs compare the spec
/// under (`Test/Common.lean` `relayFlags`). `run_diff` runs the block word and the
/// standard word of the entry's era beside it.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct EngineConfig {
    pub require_push_only: bool,
    pub memory_limit: Option<usize>,
    pub flags: Option<ScriptFlags>,
    /// The word is derived PER INPUT from the entry's spend height and the coin's height
    /// (`word_for`; the block word when the entry's `params.consensus` is true): the
    /// eras corpus (#20), whose coins are not at the spend height. `flags` is then unused.
    pub per_input_words: bool,
}

impl Default for EngineConfig {
    fn default() -> Self {
        EngineConfig {
            require_push_only: true,
            memory_limit: None,
            flags: Some(ScriptFlags::standard(ProtocolEra::PostChronicle)),
            per_input_words: false,
        }
    }
}

impl EngineConfig {
    /// The configuration under a given word (the block word for the consensus column).
    pub fn under(flags: ScriptFlags) -> Self {
        EngineConfig {
            flags: Some(flags),
            ..Default::default()
        }
    }
    /// The TypeScript SDK's default mode (neither word; the predecessor's mode).
    pub fn default_mode() -> Self {
        EngineConfig {
            require_push_only: true,
            memory_limit: None,
            flags: None,
            per_input_words: false,
        }
    }
    /// The words derived per input from the heights (`word_for`).
    pub fn per_input() -> Self {
        EngineConfig {
            require_push_only: true,
            memory_limit: None,
            flags: None,
            per_input_words: true,
        }
    }
    /// The manifest record of this configuration (`docs/DESIGN.md` §6: a verdict is
    /// never quoted without its configuration).
    pub fn to_json(&self) -> BTreeMap<String, serde_json::Value> {
        let mut config = BTreeMap::new();
        config.insert(
            "require_push_only".into(),
            serde_json::json!(self.require_push_only),
        );
        config.insert(
            "memory_limit".into(),
            serde_json::json!(self.memory_limit.unwrap_or(32_000_000)),
        );
        if self.per_input_words {
            config.insert("words".into(), serde_json::json!("per-input"));
            config.insert("mode".into(), serde_json::json!("the reference's word per input from the entry's spend height and the coin's height (engine::word_for: the block word of the spend's era when params.consensus, the standard word otherwise, the coin's Chronicle marker by the coin's era; a pre-Genesis spend or coin is not applicable = undecided), the transaction's own version"));
            return config;
        }
        match self.flags {
            Some(w) => {
                config.insert("flags".into(), serde_json::json!(w.bits()));
                config.insert("flags_names".into(), serde_json::json!(w.names().join(",")));
                config.insert("mode".into(), serde_json::json!(format!("under the flag word 0x{:X} (Spend::set_flags: the word's rules under the reference's version gate at every site), the transaction's own version", w.bits())));
            }
            None => {
                config.insert("mode".into(), serde_json::json!("the TypeScript SDK's default mode (no flag word; neither of the node's words), the transaction's own version"));
            }
        }
        config
    }
    /// The configuration a manifest records (the inverse of `to_json`; a manifest
    /// without `flags` is one recorded before the pin moved to 0.3.27: the default mode).
    /// A flag word the crate does not know is an `Err` naming it (#132).
    pub fn try_from_json(config: &BTreeMap<String, serde_json::Value>) -> Result<Self, String> {
        let mut cfg = EngineConfig::default_mode();
        if let Some(v) = config.get("require_push_only").and_then(|v| v.as_bool()) {
            cfg.require_push_only = v;
        }
        if let Some(v) = config.get("memory_limit").and_then(|v| v.as_u64()) {
            // `to_json` records the effective budget; the crate's default (32,000,000,
            // `spend.rs:109`) reads back as `None` so a record round-trips
            cfg.memory_limit = if v == 32_000_000 {
                None
            } else {
                Some(v as usize)
            };
        }
        if let Some(bits) = config.get("flags").and_then(|v| v.as_u64()) {
            cfg.flags = Some(ScriptFlags::from_bits(bits as u32).map_err(|e| {
                format!("a manifest's flag word {bits:#x} is not one the crate knows: {e}")
            })?);
        }
        if config.get("words").and_then(|v| v.as_str()) == Some("per-input") {
            cfg.per_input_words = true;
        }
        Ok(cfg)
    }
    /// `try_from_json` for the caller that takes a configuration: rules_check (a checker that writes nothing), and
    /// harness/src/bin/run_diff.rs (S2's seat) until S2's patch record moves it to `try_from_json` (docs/LINT.md
    /// section 1b).
    #[allow(
        clippy::panic,
        reason = "rules_check (a checker that writes nothing) calls this signature, and run_diff.rs (S2's file) until its patch record lands; a manifest's unknown flag word is a corrupted manifest, and the panic names it"
    )]
    pub fn from_json(config: &BTreeMap<String, serde_json::Value>) -> Self {
        Self::try_from_json(config).unwrap_or_else(|e| panic!("{e}"))
    }
}

fn panic_message(p: Box<dyn std::any::Any + Send>) -> String {
    p.downcast_ref::<&str>()
        .map(|s| s.to_string())
        .or_else(|| p.downcast_ref::<String>().cloned())
        .unwrap_or_else(|| "<non-string panic payload>".into())
}

/// Run input `i` of `tx` against `prevouts[i]` through the pinned bsv-rs engine.
#[allow(
    clippy::result_large_err,
    reason = "the closure returns Spend::validate's own error, the pinned bsv-rs crate's type"
)]
pub fn run_input(
    tx: &RawTx,
    prevouts: &[Prevout],
    i: usize,
    mode: Mode,
    cfg: &EngineConfig,
) -> Verdict {
    let input = &tx.inputs[i];
    let prev = &prevouts[i];
    let lock = match LockingScript::from_binary(&prev.script) {
        Ok(l) => l,
        Err(e) => return Verdict::Unparseable(format!("lock: {e:?}")),
    };
    let unlock = match UnlockingScript::from_binary(&input.script) {
        Ok(u) => u,
        Err(e) => return Verdict::Unparseable(format!("unlock: {e:?}")),
    };
    let version = match mode {
        Mode::V1Strict => 1,
        _ => tx.version,
    };
    let other_inputs: Vec<SigTxInput> = tx
        .inputs
        .iter()
        .enumerate()
        .filter(|(idx, _)| *idx != i)
        .map(|(_, inp)| SigTxInput {
            txid: inp.txid,
            output_index: inp.vout,
            script: vec![],
            sequence: inp.sequence,
        })
        .collect();
    let outputs: Vec<SigTxOutput> = tx
        .outputs
        .iter()
        .map(|o| SigTxOutput {
            satoshis: o.satoshis,
            script: o.script.clone(),
        })
        .collect();
    let result = catch_unwind(AssertUnwindSafe(|| {
        let mut spend = Spend::new(SpendParams {
            source_txid: prev.txid,
            source_output_index: prev.vout,
            source_satoshis: prev.satoshis,
            locking_script: lock,
            transaction_version: version,
            other_inputs,
            outputs,
            input_index: i,
            unlocking_script: unlock,
            input_sequence: input.sequence,
            lock_time: tx.lock_time,
            memory_limit: cfg.memory_limit,
            // No opt-in local work cap: retain the recorded evaluator configuration.
            work_limit: None,
        });
        // under a word every rule is the word's (`Spend::set_flags`, `spend.rs:471–494`);
        // without one, the default mode with its push-only knob (`spend.rs:445–447`)
        match cfg.flags {
            Some(w) => spend.set_flags(w),
            None => spend.set_require_push_only(cfg.require_push_only),
        }
        if mode == Mode::V2MinimalOnly {
            spend.set_require_minimal(true);
        }
        spend.validate()
    }));
    match result {
        Ok(Ok(true)) => Verdict::Accept,
        Ok(Ok(false)) => Verdict::RejectFalse,
        Ok(Err(e)) => {
            if let Some(r) = e.resource_limit {
                Verdict::Resource(format!(
                    "{} limit {} attempted {}",
                    r.resource, r.limit, r.attempted
                ))
            } else {
                Verdict::ErrorV(e.message)
            }
        }
        Err(p) => Verdict::Panic(panic_message(p)),
    }
}

/// Run every input under its own word (`word_for`; `None` = not applicable): the eras
/// corpus (#20). The transaction's verdict is the first non-accepting input's.
pub fn run_tx_words(
    tx: &RawTx,
    prevouts: &[Prevout],
    mode: Mode,
    cfg: &EngineConfig,
    words: &[Option<ScriptFlags>],
) -> (Verdict, Option<usize>) {
    if tx.inputs.len() != prevouts.len() || words.len() != prevouts.len() {
        return (
            Verdict::Unparseable(format!(
                "{} inputs but {} prevouts and {} words",
                tx.inputs.len(),
                prevouts.len(),
                words.len()
            )),
            None,
        );
    }
    for (i, word) in words.iter().enumerate() {
        let v = match *word {
            Some(w) => run_input(tx, prevouts, i, mode, &EngineConfig { flags: Some(w), per_input_words: false, ..*cfg }),
            None => Verdict::NotApplicable("bsv-rs implements the post-Genesis rule set only (flags.rs: ProtocolEra::at_height is None below the Genesis height; ScriptFlags::check refuses a word without UTXO_AFTER_GENESIS): a pre-Genesis spend or coin has no word here".into()),
        };
        if !v.accepted() {
            return (v, Some(i));
        }
    }
    (Verdict::Accept, None)
}

/// The per-input words of an entry from its heights (`word_for`), for `run_tx_words`.
pub fn words_of(
    spend_height: u32,
    utxo_heights: &[u32],
    consensus: bool,
) -> Vec<Option<ScriptFlags>> {
    utxo_heights
        .iter()
        .map(|&u| word_for(spend_height, u, consensus))
        .collect()
}

/// Run every input. The transaction's verdict is the first non-accepting
/// input's verdict with its index, else `Accept`.
pub fn run_tx(
    tx: &RawTx,
    prevouts: &[Prevout],
    mode: Mode,
    cfg: &EngineConfig,
) -> (Verdict, Option<usize>) {
    if tx.inputs.len() != prevouts.len() {
        return (
            Verdict::Unparseable(format!(
                "{} inputs but {} prevouts",
                tx.inputs.len(),
                prevouts.len()
            )),
            None,
        );
    }
    for i in 0..tx.inputs.len() {
        let v = run_input(tx, prevouts, i, mode, cfg);
        if !v.accepted() {
            return (v, Some(i));
        }
    }
    (Verdict::Accept, None)
}

#[cfg(test)]
mod tests {
    use super::*;

    /// The two words of a post-Chronicle block are the reference's numbers
    /// (`docs/PARAMETERS.md` §6: the block word `0x3D462F`, the mempool word `0x3D47FF`),
    /// and the default configuration records the mempool word.
    #[test]
    fn the_words_are_the_reference_numbers() {
        assert_eq!(
            ScriptFlags::block(ProtocolEra::PostChronicle).bits(),
            0x3D462F
        );
        assert_eq!(
            ScriptFlags::standard(ProtocolEra::PostChronicle).bits(),
            0x3D47FF
        );
        assert_eq!(
            EngineConfig::default().flags.map(|f| f.bits()),
            Some(0x3D47FF)
        );
        let j = EngineConfig::default().to_json();
        assert_eq!(EngineConfig::from_json(&j), EngineConfig::default());
        // the pre-Genesis asserts are S2's below (#20): a spend or coin below Genesis has NO word, never a fallback era
        // the per-input words (#20): the coin's Chronicle marker is the coin's era's
        assert_eq!(
            word_for(967_896, 967_896, true).map(|w| w.bits()),
            Some(0x3D462F)
        );
        assert_eq!(
            word_for(967_896, 943_815, true).map(|w| w.bits()),
            Some(0x3D462F & !(1 << 21))
        );
        assert_eq!(word_for(967_896, 620_537, true), None);
        assert_eq!(word_for(620_537, 100, true), None);
        assert_eq!(
            word_for(943_816, 943_816, false).map(|w| w.bits()),
            Some(0x3D47FF)
        );
        let j = EngineConfig::per_input().to_json();
        assert_eq!(EngineConfig::from_json(&j), EngineConfig::per_input());
    }
}
