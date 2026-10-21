//! The corpus entry and manifest format (this repo's; `docs/DESIGN.md` §6).
//! One JSON object per line in a `.jsonl` file; the manifest beside it names
//! the generator, its seed, the count, the file's sha256 and the implementation
//! configuration every recorded verdict was produced under.

use std::collections::BTreeMap;

use serde::{Deserialize, Serialize};

use crate::engine::Prevout;
use crate::txraw::{txid_display_hex, txid_from_display_hex};

/// A previous output, aligned with the transaction's input of the same index.
#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub struct PrevoutJson {
    /// Display-order hex (what explorers show).
    pub txid: String,
    pub vout: u32,
    /// Locking script bytes, hex.
    pub script: String,
    pub satoshis: u64,
    /// The height the output was created at (selects the UTXO's era). Required:
    /// `null`/`MEMPOOL_HEIGHT` is not a corpus value (`docs/DESIGN.md` §6; BDK
    /// rejects it in consensus mode, SV-node substitutes the live tip).
    pub height: u32,
}

impl PrevoutJson {
    pub fn to_prevout(&self) -> Result<Prevout, String> {
        Ok(Prevout {
            txid: txid_from_display_hex(&self.txid)?,
            vout: self.vout,
            script: hex::decode(&self.script).map_err(|e| format!("prevout script hex: {e}"))?,
            satoshis: self.satoshis,
        })
    }
    pub fn from_prevout(p: &Prevout) -> Self {
        PrevoutJson {
            txid: txid_display_hex(&p.txid),
            vout: p.vout,
            script: hex::encode(&p.script),
            satoshis: p.satoshis,
            height: DEFAULT_SPEND_HEIGHT,
        }
    }
}

/// The spec's default spending height (`docs/PARAMETERS.md` §3,
/// `lean/BsvScript/Params.lean` `defaultSpendHeight`): the mainnet tip at the pin date.
pub const DEFAULT_SPEND_HEIGHT: u32 = 967_896;

/// The parameters an entry is evaluated under (`docs/DESIGN.md` §6). The flag
/// word and the limits are derived from these by `Params.derive` (#13/#20)
/// unless `Entry.flags` gives the word directly.
#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub struct ParamsJson {
    /// The height of the block the spend is in (the consensus convention; a
    /// runner converts to its own, DESIGN §6).
    pub spend_height: u32,
    /// `pre-genesis` · `post-genesis` · `post-chronicle`: a label derived from
    /// `spend_height` for readers; never an input to a runner.
    pub era: String,
    /// true = the consensus limits; false = a node's policy limits (an argument
    /// of the derivation, not of the semantics).
    pub consensus: bool,
    /// The spending transaction's version (also in the tx bytes; repeated so a
    /// reader sees the branch without decoding).
    pub tx_version: i32,
}

impl ParamsJson {
    /// The era label of a mainnet height (`docs/PARAMETERS.md` §3: Genesis 620,538,
    /// Chronicle 943,816; "the height of the block where the new rules are active").
    pub fn era_of(height: u32) -> &'static str {
        if height >= 943_816 {
            "post-chronicle"
        } else if height >= 620_538 {
            "post-genesis"
        } else {
            "pre-genesis"
        }
    }
}

/// One implementation's verdict on the entry (`docs/DESIGN.md` §6, the comparison):
/// `verdict` is tier 1 (the only divergence class); `code` is tier 2, compared as
/// a note; `reason` is the raw message, never compared across implementations;
/// `input` is advisory, compared only when both sides report it.
#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub struct ExpectJson {
    /// `valid` · `invalid` · `undecided` (`engine::Verdict::kind`).
    pub verdict: String,
    /// The reference's `SCRIPT_ERR_*` name at the pin (`script_error.h:12–87`),
    /// when the implementation reports the enum (SV-node, GoBDK) or a cited
    /// message-to-code table maps it (bsv-rs, #15).
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub code: Option<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub reason: Option<String>,
    /// The input that decided a non-valid verdict, when reported.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub input: Option<usize>,
}

/// A witness's record of the divergence it exhibits (constitution 04: a record,
/// never a sentence). `a`/`b` index `Entry.expect`.
#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub struct Divergence {
    /// The rule id (`corpus/INDEX.md` §2).
    pub rule: String,
    pub a: String,
    pub b: String,
    pub a_verdict: ExpectJson,
    pub b_verdict: ExpectJson,
    /// The `[SRC]` file:line at the pin that decides it.
    pub decided_by: String,
    /// `spec-wrong` · `impl-wrong` · `open`.
    pub ruling: String,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub minimized: Option<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub minimized_prevouts: Option<Vec<PrevoutJson>>,
    pub note: String,
}

/// The reference model's expectation, when the generator has one.
#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub struct RefJson {
    pub model: String,
    pub expect: String,
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub struct Entry {
    pub id: String,
    /// The generator family (a histogram key).
    pub family: String,
    /// The rule id the entry exercises (`corpus/INDEX.md`).
    pub rule: String,
    /// The spending transaction, hex.
    pub tx: String,
    pub prevouts: Vec<PrevoutJson>,
    pub params: ParamsJson,
    /// The explicit flag word per input (`script_flags.h`); absent = derived from
    /// the heights by `Params.derive` (#13). Both oracles accept it directly.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub flags: Option<Vec<u32>>,
    /// Verdicts keyed by `name@version` (`spec@<commit>` for the spec's own).
    pub expect: BTreeMap<String, ExpectJson>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub reference: Option<RefJson>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub note: Option<String>,
    /// For a witness: the divergence it exhibits (filled by the report, #15/#30).
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub divergence: Option<Divergence>,
}

impl Entry {
    /// The well-formedness every entry must satisfy (`docs/DESIGN.md` §6): at
    /// least one input and one output (BDK throws on zero inputs and uses a
    /// constant-false checker on zero outputs), one prevout per input, a flag
    /// word per input when given, satoshis within `i64`, and the era label
    /// consistent with the spend height.
    pub fn check(&self) -> Result<(), String> {
        let tx = crate::txraw::RawTx::decode(
            &hex::decode(&self.tx).map_err(|e| format!("{}: tx hex: {e}", self.id))?,
        )
        .map_err(|e| format!("{}: tx frame: {e}", self.id))?;
        if tx.inputs.is_empty() {
            return Err(format!("{}: no inputs", self.id));
        }
        if tx.outputs.is_empty() {
            return Err(format!("{}: no outputs", self.id));
        }
        if tx.inputs.len() != self.prevouts.len() {
            return Err(format!(
                "{}: {} inputs but {} prevouts",
                self.id,
                tx.inputs.len(),
                self.prevouts.len()
            ));
        }
        if let Some(f) = &self.flags {
            if f.len() != tx.inputs.len() {
                return Err(format!(
                    "{}: {} inputs but {} flag words",
                    self.id,
                    tx.inputs.len(),
                    f.len()
                ));
            }
        }
        for p in &self.prevouts {
            if p.satoshis > i64::MAX as u64 {
                return Err(format!("{}: satoshis above i64::MAX", self.id));
            }
        }
        if self.params.era != ParamsJson::era_of(self.params.spend_height) {
            return Err(format!(
                "{}: era label {} does not match spend height {}",
                self.id, self.params.era, self.params.spend_height
            ));
        }
        if self.params.tx_version != tx.version {
            return Err(format!(
                "{}: params.tx_version {} but the transaction says {}",
                self.id, self.params.tx_version, tx.version
            ));
        }
        Ok(())
    }
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub struct ImplConfigJson {
    pub name: String,
    pub version: String,
    pub config: BTreeMap<String, serde_json::Value>,
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub struct Manifest {
    pub corpus: String,
    pub file: String,
    pub generator: String,
    pub seed: String,
    pub count: u64,
    pub sha256: String,
    pub families: BTreeMap<String, u64>,
    pub rules: BTreeMap<String, u64>,
    pub verdicts: BTreeMap<String, u64>,
    pub implementations: Vec<ImplConfigJson>,
    pub engine_executions: u64,
    pub generated: String,
    pub provenance: String,
}
