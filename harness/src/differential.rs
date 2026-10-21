//! Shared inputs for the conformance drivers (this repo's; [LIT] #31).
//! Corpus hashes, the evaluator's JSON lines and verdict conversion have one reader.
//! Each driver retains its engine calls, classification, stamp checks and reporting.

use std::collections::BTreeMap;
use std::io::BufRead;
use std::path::{Path, PathBuf};

use bsv_rs::primitives::hash::sha256;

use crate::corpus::{ExpectJson, Manifest};

#[derive(Clone, Debug, serde::Deserialize)]
pub struct SpecVerdict {
    pub verdict: String,
    #[serde(default)]
    pub code: Option<String>,
    #[serde(default)]
    pub input: Option<usize>,
}

#[derive(Clone, Debug, serde::Deserialize)]
pub struct SpecLine {
    pub id: String,
    pub spec: SpecVerdict,
    #[serde(rename = "spec-mempool")]
    pub spec_mempool: SpecVerdict,
    pub config: String,
    pub commit: String,
}

pub fn spec_json(s: &SpecVerdict) -> ExpectJson {
    ExpectJson {
        verdict: s.verdict.clone(),
        code: s.code.clone(),
        reason: None,
        input: s.input,
    }
}

/// Read the evaluator's lines with the existing drivers' ID map semantics.
/// Driver-specific checks of commits and configurations remain with the caller.
/// The comparison's reader is strict: a line it cannot read is an error. The stamp gate's reader
/// (`stamp::spec_commits`) is lenient on purpose and names such a line `unknown`; the owner kept the two apart
/// (P6, 2026-10-05), and unifying them would be a new finding.
pub fn read_spec(path: &Path) -> Result<BTreeMap<String, SpecLine>, String> {
    let file = std::fs::File::open(path).map_err(|e| format!("{}: {e}", path.display()))?;
    let mut spec = BTreeMap::new();
    for (index, line) in std::io::BufReader::new(file).lines().enumerate() {
        let line = line.map_err(|e| format!("{}:{}: {e}", path.display(), index + 1))?;
        if line.trim().is_empty() {
            continue;
        }
        let s: SpecLine = serde_json::from_str(&line)
            .map_err(|e| format!("{}:{}: {e}", path.display(), index + 1))?;
        spec.insert(s.id.clone(), s);
    }
    Ok(spec)
}

pub struct CorpusInput {
    pub file_name: String,
    pub corpus_name: String,
    pub bytes: Vec<u8>,
    pub manifest_path: Option<PathBuf>,
    pub manifest: Option<Manifest>,
}

impl CorpusInput {
    /// Read the corpus and check its sibling manifest's hash when present.
    /// The manifest selection matches the drivers' existing selection.
    pub fn load(path: &Path) -> Result<Self, String> {
        let dir = path.parent().unwrap_or_else(|| Path::new(""));
        let file_name = path
            .file_name()
            .ok_or_else(|| format!("{}: no file name", path.display()))?
            .to_string_lossy()
            .to_string();
        let corpus_name = dir
            .file_name()
            .map(|s| s.to_string_lossy().to_string())
            .unwrap_or_else(|| "corpus".into());
        let manifest_path = [dir.join("manifest.json"), dir.join("cases-manifest.json")]
            .into_iter()
            .find(|p| {
                p.exists()
                    && std::fs::read_to_string(p)
                        .map(|s| s.contains(&format!("\"{file_name}\"")))
                        .unwrap_or(false)
            });
        let bytes = std::fs::read(path).map_err(|e| format!("{}: {e}", path.display()))?;
        let manifest = if let Some(mp) = &manifest_path {
            let text = std::fs::read_to_string(mp).map_err(|e| format!("{}: {e}", mp.display()))?;
            let m: Manifest =
                serde_json::from_str(&text).map_err(|e| format!("{}: {e}", mp.display()))?;
            let sha = hex::encode(sha256(&bytes));
            if sha != m.sha256 {
                return Err(format!(
                    "{} sha256 {sha} != manifest {}",
                    path.display(),
                    m.sha256
                ));
            }
            Some(m)
        } else {
            None
        };
        Ok(Self {
            file_name,
            corpus_name,
            bytes,
            manifest_path,
            manifest,
        })
    }
}
