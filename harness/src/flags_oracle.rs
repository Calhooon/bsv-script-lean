//! The flags oracle (this repo's; #29): the reference flag word an input is verified under, asked of
//! the SPEC'S OWN EXECUTABLE (`eval/bsvs eval`, whose `inputs[].params.flags.word` echoes
//! `Params.derive`, `lean/BsvScript/Flags.lean`, `docs/PARAMETERS.md` §6) and cached per
//! `(spend_height, utxo_height, consensus)`. The harness never derives a word itself: a second
//! derivation would be a second semantics (`docs/DESIGN.md` §5.4, constitution 03). The engines that take
//! a flag word (go-sdk, ts-sdk in its explicit mode, the `verifyscript` RPC) receive exactly the word the
//! spec judged the same input under, so both columns of the differential compare like with like.
//!
//! The probe transaction is a fixed one-input, one-output version-2 spend of a synthetic non-null
//! outpoint (a coinbase-shaped input would be skipped by the CLI, `docs/DESIGN.md` §5.5), whose prevout
//! carries the height asked about; the CLI evaluates it and echoes the parameters, which is all the
//! oracle reads.
//!
//! THE RECORDED WORDS (#31, 2026-09-29): `FlagsOracle::recorded` serves the words a witness manifest recorded
//! for a corpus (`corpus/witnesses/<engine>/manifest.json`, `[<corpus>].words`: the triples a live run asked of
//! the CLI, with the word it echoed), so a machine without the Lean build runs the differentials. It asks the
//! CLI nothing: a triple the table lacks is an error naming it, never a word derived here.
//!
//! THE TEST'S OWN CHAIN (2026-10-06, lane cpp-era-49: #49's `txvalidationcache` rows at their era): `with_heights`
//! passes `--genesis-height`/`--chronicle-height` to every `eval/bsvs eval` call, so the words are the ones the spec
//! derives on a chain with those activation heights (`lean/Bsvs/Main.lean` `withHeights`; the CLI's `--config` is the
//! chain, `sv-regtest` for the reference's unit-test fixture). Still the spec's own derivation: nothing is derived here.

use std::collections::{BTreeSet, HashMap};
use std::path::{Path, PathBuf};
use std::process::Command;

pub struct FlagsOracle {
    bsvs: PathBuf,
    config: String,
    cache: HashMap<(u32, u32, bool), u32>,
    /// how many CLI calls were made (the report prints it: the cache is the whole cost)
    pub calls: u32,
    /// Some(the table's source) when the words are a recorded table (#31), never the CLI's
    recorded: Option<String>,
    /// the triples a run asked of a recorded table (its `table()` lists these, as a live run lists the ones it asked)
    used: BTreeSet<(u32, u32, bool)>,
    /// further CLI arguments every `eval/bsvs eval` call carries (`--genesis-height`/`--chronicle-height`, `with_heights`)
    extra: Vec<String>,
}

/// The probe: version 2 · one input (outpoint 01…01:0, empty scriptSig, sequence ffffffff) · one output
/// (1 satoshi, OP_1) · lock time 0. Assembled here, never a transaction of anything (`tools/mechanism_check.sh`
/// refuses a long hex literal in the source for that reason).
pub fn probe_tx_hex() -> String {
    let mut b: Vec<u8> = Vec::new();
    b.extend_from_slice(&2u32.to_le_bytes()); // version
    b.push(1); // one input
    b.extend_from_slice(&[0x01u8; 32]); // the outpoint's txid (synthetic, non-null)
    b.extend_from_slice(&0u32.to_le_bytes()); // vout 0
    b.push(0); // an empty scriptSig
    b.extend_from_slice(&0xffff_ffffu32.to_le_bytes()); // sequence
    b.push(1); // one output
    b.extend_from_slice(&1u64.to_le_bytes()); // 1 satoshi
    b.extend_from_slice(&[1, 0x51]); // the script OP_1
    b.extend_from_slice(&0u32.to_le_bytes()); // lock time
    hex::encode(b)
}

impl FlagsOracle {
    /// Select a prebuilt evaluator whose Lean sources the caller has checked.
    pub fn with_executable(mut self, executable: &Path) -> Self {
        self.bsvs = executable.to_path_buf();
        self
    }

    /// `root` is the repository root (`eval/bsvs` under it); `config` is the CLI's `--config` (`sv` | `teranode`).
    pub fn new(root: &Path, config: &str) -> FlagsOracle {
        FlagsOracle {
            bsvs: root.join("eval").join("bsvs"),
            config: config.to_string(),
            cache: HashMap::new(),
            calls: 0,
            recorded: None,
            used: BTreeSet::new(),
            extra: Vec::new(),
        }
    }

    /// The configuration's two activation heights, as the CLI's `--genesis-height`/`--chronicle-height` set them (a node's
    /// `-genesisactivationheight`/`-chronicleactivationheight`, `init.cpp:2474–2481`): every word asked carries them.
    pub fn with_heights(mut self, genesis: u32, chronicle: u32) -> FlagsOracle {
        self.extra = vec![
            "--genesis-height".into(),
            genesis.to_string(),
            "--chronicle-height".into(),
            chronicle.to_string(),
        ];
        self
    }

    /// The words a witness manifest recorded for `corpus` (#31): `manifest[corpus].words`, each row
    /// `{spend_height, utxo_height, consensus, word}`. Refused when the manifest or the corpus's row is absent, a row
    /// is malformed, or one triple carries two words.
    pub fn recorded(manifest: &Path, corpus: &str) -> Result<FlagsOracle, String> {
        let text = std::fs::read_to_string(manifest)
            .map_err(|e| format!("recorded words: {}: {e}", manifest.display()))?;
        let m: serde_json::Value = serde_json::from_str(&text)
            .map_err(|e| format!("recorded words: {}: {e}", manifest.display()))?;
        let rows = m[corpus]["words"].as_array().ok_or_else(|| {
            format!(
                "recorded words: {} has no words for the corpus `{corpus}`",
                manifest.display()
            )
        })?;
        let mut cache = HashMap::new();
        for r in rows {
            let field = |k: &str| r[k].as_u64().and_then(|v| u32::try_from(v).ok());
            let (Some(sh), Some(uh), Some(c), Some(w)) = (
                field("spend_height"),
                field("utxo_height"),
                r["consensus"].as_bool(),
                field("word"),
            ) else {
                return Err(format!(
                    "recorded words: {} [{corpus}]: a malformed row {r}",
                    manifest.display()
                ));
            };
            if cache.insert((sh, uh, c), w).is_some_and(|old| old != w) {
                return Err(format!("recorded words: {} [{corpus}]: two words for (spend {sh}, utxo {uh}, consensus {c})", manifest.display()));
            }
        }
        Ok(FlagsOracle {
            bsvs: PathBuf::new(),
            config: String::new(),
            cache,
            calls: 0,
            recorded: Some(format!("{} [{corpus}]", manifest.display())),
            used: BTreeSet::new(),
            extra: Vec::new(),
        })
    }

    /// Where the words come from, for the report: `eval/bsvs` (live) or the recorded table's source.
    pub fn source(&self) -> String {
        match &self.recorded {
            Some(src) => format!("the words recorded in {src}"),
            None if self.extra.is_empty() => "the words from eval/bsvs".to_string(),
            None => format!(
                "the words from eval/bsvs (--config {} {})",
                self.config,
                self.extra.join(" ")
            ),
        }
    }

    /// The word of `Params.derive cfg spend_height utxo_height consensus`, as the CLI echoes it.
    pub fn word(
        &mut self,
        spend_height: u32,
        utxo_height: u32,
        consensus: bool,
    ) -> Result<u32, String> {
        if let Some(src) = &self.recorded {
            return match self.cache.get(&(spend_height, utxo_height, consensus)) {
                Some(w) => {
                    self.used.insert((spend_height, utxo_height, consensus));
                    Ok(*w)
                }
                None => Err(format!(
                    "flags oracle: the words recorded in {src} have none for (spend {spend_height}, utxo {utxo_height}, consensus {consensus}); \
                     run with the live words (eval/bsvs, the Lean build) or re-record the manifest"
                )),
            };
        }
        if let Some(w) = self.cache.get(&(spend_height, utxo_height, consensus)) {
            return Ok(*w);
        }
        let prevouts = format!(
            "[{{\"txid\":\"{}\",\"vout\":0,\"script\":\"51\",\"satoshis\":1,\"height\":{}}}]",
            "01".repeat(32),
            utxo_height
        );
        let out = Command::new(&self.bsvs)
            .args([
                "eval",
                "--tx",
                &probe_tx_hex(),
                "--prevouts",
                &prevouts,
                "--spend-height",
                &spend_height.to_string(),
                "--consensus",
                if consensus { "true" } else { "false" },
                "--config",
                &self.config,
            ])
            .args(&self.extra)
            .output()
            .map_err(|e| format!("flags oracle: cannot run {}: {e}", self.bsvs.display()))?;
        self.calls += 1;
        if !out.status.success() {
            return Err(format!(
                "flags oracle: eval/bsvs failed: {}",
                String::from_utf8_lossy(&out.stderr)
            ));
        }
        let j: serde_json::Value =
            serde_json::from_slice(&out.stdout).map_err(|e| format!("flags oracle: json: {e}"))?;
        let w = j["inputs"][0]["params"]["flags"]["word"]
            .as_u64()
            .ok_or_else(|| {
                format!(
                    "flags oracle: no inputs[0].params.flags.word in {}",
                    String::from_utf8_lossy(&out.stdout)
                )
            })?;
        let w =
            u32::try_from(w).map_err(|_| "flags oracle: the word is not a uint32".to_string())?;
        self.cache.insert((spend_height, utxo_height, consensus), w);
        Ok(w)
    }

    /// The distinct parameter triples asked so far (the report lists them with their words).
    pub fn table(&self) -> Vec<((u32, u32, bool), u32)> {
        let mut v: Vec<_> = self
            .cache
            .iter()
            .filter(|(k, _)| self.recorded.is_none() || self.used.contains(*k))
            .map(|(k, w)| (*k, *w))
            .collect();
        v.sort();
        v
    }
}
