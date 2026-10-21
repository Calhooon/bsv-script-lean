//! The engine adapters (this repo's; #29, `docs/DESIGN.md` §7): the SDK engines run out of process,
//! one adapter each, over JSON lines. The harness sends a corpus entry with the flag word of every input
//! for each run it wants and reads back the engine's verdict, its own code name or message, and the
//! flags it applied. The adapters are `harness/engines/go/main.go` (go-sdk) and
//! `harness/engines/ts/runner.mjs` (ts-sdk), and the GoBDK shim `harness/engines/gobdk/main.go` (#28, D14); their pins are `docs/PROVENANCE.md` §1a and are checked
//! at every spawn against the version each adapter reports (`--version`).

use std::collections::BTreeMap;
use std::io::{BufRead, BufReader, BufWriter, Write};
use std::path::{Path, PathBuf};
use std::process::{Child, ChildStdin, Command, Stdio};
use std::sync::mpsc::{self, Receiver, RecvTimeoutError};
use std::time::Duration;

use serde::{Deserialize, Serialize};

/// The pinned engine releases (`docs/PROVENANCE.md` §1a: `go-sdk.version`, `ts-sdk.version`; `make check-pins`
/// refuses a drift between these strings and the pins block).
pub const GO_SDK_VERSION: &str = "v1.7.2";
pub const TS_SDK_VERSION: &str = "3.0.0";
/// The GoBDK shim (#28, D14; `harness/engines/gobdk/`): the prefix of the pinned module commit (`docs/PROVENANCE.md` §1a
/// `gobdk.commit`), which the shim's banner derives from its build info.
pub const GOBDK_VERSION: &str = "4eab3acd";

#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum EngineKind {
    GoSdk,
    TsSdk,
    GoBdk,
}

impl EngineKind {
    pub fn parse(s: &str) -> Option<EngineKind> {
        match s {
            "gosdk" | "go-sdk" => Some(EngineKind::GoSdk),
            "tssdk" | "ts-sdk" => Some(EngineKind::TsSdk),
            "gobdk" | "go-bdk" => Some(EngineKind::GoBdk),
            _ => None,
        }
    }
    /// The implementation name of the corpus key (`name@version`, `docs/DESIGN.md` §6).
    pub fn name(self) -> &'static str {
        match self {
            EngineKind::GoSdk => "go-sdk",
            EngineKind::TsSdk => "ts-sdk",
            EngineKind::GoBdk => "gobdk",
        }
    }
    pub fn version(self) -> &'static str {
        match self {
            EngineKind::GoSdk => GO_SDK_VERSION,
            EngineKind::TsSdk => TS_SDK_VERSION,
            EngineKind::GoBdk => GOBDK_VERSION,
        }
    }
    /// `go-sdk@v1.7.2` · `ts-sdk@3.0.0`: the key of the verdict under the entry's own parameters.
    pub fn key(self) -> String {
        format!("{}@{}", self.name(), self.version())
    }
    /// `go-sdk-mempool@v1.7.2`: the verdict under the mempool word of the same configuration.
    pub fn mempool_key(self) -> String {
        format!("{}-mempool@{}", self.name(), self.version())
    }
    /// `ts-sdk-default@3.0.0`: the SDK's own derivation from the version, no explicit word (ts-sdk only).
    pub fn default_key(self) -> String {
        format!("{}-default@{}", self.name(), self.version())
    }
    pub fn has_default_mode(self) -> bool {
        matches!(self, EngineKind::TsSdk)
    }
}

#[derive(Serialize, Debug, Clone)]
pub struct PrevoutReq {
    pub txid: String,
    pub vout: u32,
    pub script: String,
    pub satoshis: u64,
    /// the coin's height (the GoBDK shim passes it as utxoHeights[i]; the SDK adapters are sent none)
    #[serde(skip_serializing_if = "Option::is_none")]
    pub height: Option<u32>,
}

#[derive(Serialize, Debug, Clone)]
pub struct RunReq {
    pub key: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub mode: Option<&'static str>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub flags: Option<Vec<u32>>,
    /// the `consensus` boolean of the run (the GoBDK shim passes it to VerifyScriptWithCustomFlags; the SDKs have none)
    #[serde(skip_serializing_if = "Option::is_none")]
    pub consensus: Option<bool>,
}

#[derive(Serialize, Debug, Clone)]
pub struct Request {
    pub id: String,
    pub tx: String,
    pub prevouts: Vec<PrevoutReq>,
    pub runs: Vec<RunReq>,
    /// the entry's spend height (the GoBDK shim's blockHeight, DESIGN §6's convention; the SDKs are sent none)
    #[serde(skip_serializing_if = "Option::is_none")]
    pub spend_height: Option<u32>,
}

#[derive(Deserialize, Debug, Clone)]
pub struct RunVerdict {
    pub verdict: String,
    #[serde(default)]
    pub input: Option<usize>,
    #[serde(default)]
    pub code: Option<String>,
    #[serde(default)]
    pub message: Option<String>,
    #[serde(default)]
    pub engine_flags: serde_json::Value,
    /// go-sdk: the reference bits the engine has no flag for
    #[serde(default)]
    pub unmapped_bits: Option<Vec<String>>,
    /// ts-sdk: the names passed that Spend never reads
    #[serde(default)]
    pub unconsulted: Option<Vec<String>>,
}

impl RunVerdict {
    pub fn kind(&self) -> &str {
        &self.verdict
    }
    pub fn accepted(&self) -> bool {
        self.verdict == "valid"
    }
    /// The engine's own vocabulary, one line: `<code>: <first line of the message>`.
    pub fn native(&self) -> String {
        let msg = self.message.as_deref().unwrap_or("");
        let first = msg.lines().next().unwrap_or("");
        match &self.code {
            Some(c) if !first.is_empty() => format!("{c}: {first}"),
            Some(c) => c.clone(),
            None => first.to_string(),
        }
    }
}

/// An engine's error text can embed the whole element it refused: go-sdk v1.5.2 prints the number's hex in
/// `MakeScriptNumber`'s message (`number.go:72–79`), 64 MB for a 32,000,001-byte number, and a recorded reason that
/// long put `corpus/gen/gen.jsonl` at 129 MB (2026-09-24). Every message and error is capped HERE, at receipt, so no
/// corpus, witness file or manifest carries more than this many characters of an engine's text; the cap names the
/// original length. The verdict and the code are never touched.
pub const MESSAGE_CAP: usize = 240;

pub fn cap_text(s: String) -> String {
    let n = s.chars().count();
    if n <= MESSAGE_CAP {
        return s;
    }
    let head: String = s.chars().take(MESSAGE_CAP).collect();
    format!("{head} …[capped by the harness at {MESSAGE_CAP} of {n} chars]")
}

#[derive(Deserialize, Debug, Clone)]
pub struct Response {
    pub id: String,
    pub runs: BTreeMap<String, RunVerdict>,
    #[serde(default)]
    pub error: Option<String>,
}

pub struct Adapter {
    pub kind: EngineKind,
    child: Child,
    stdin: BufWriter<ChildStdin>,
    /// the adapter's stdout, read on its own thread and forwarded line by line, so a call can time out
    lines: Receiver<Result<String, String>>,
    /// what the adapter said about itself (`--version`)
    pub banner: String,
    /// the wall one entry may take before the adapter is killed and the entry recorded `undecided` as an
    /// `adapter-timeout` (2026-09-24: the go-sdk adapter sat at full CPU for four minutes on one entry of
    /// `corpus/gen` with no way out; under D15 an engine that returns no verdict on an input the reference decides
    /// is a witness). ENGINE_ADAPTER_TIMEOUT_S overrides the default of 120 s; the manifest records the value.
    pub timeout: Duration,
}

/// The per-entry wall (`ENGINE_ADAPTER_TIMEOUT_S`, default 120 s).
pub fn adapter_timeout() -> Duration {
    Duration::from_secs(
        std::env::var("ENGINE_ADAPTER_TIMEOUT_S")
            .ok()
            .and_then(|v| v.parse().ok())
            .unwrap_or(120),
    )
}

/// The node the ts-sdk adapter runs on (`tools/node_bin.sh`: $NODE_BIN, the newest nvm v22, `node`).
pub fn node_bin(root: &Path) -> Result<PathBuf, String> {
    if let Ok(n) = std::env::var("NODE_BIN") {
        return Ok(PathBuf::from(n));
    }
    let out = Command::new(root.join("tools").join("node_bin.sh"))
        .output()
        .map_err(|e| format!("tools/node_bin.sh: {e}"))?;
    if !out.status.success() {
        return Err(format!(
            "tools/node_bin.sh: {}",
            String::from_utf8_lossy(&out.stderr)
        ));
    }
    Ok(PathBuf::from(String::from_utf8_lossy(&out.stdout).trim()))
}

impl Adapter {
    fn command(kind: EngineKind, root: &Path) -> Result<Command, String> {
        match kind {
            EngineKind::GoSdk => {
                let bin = std::env::var("GOSDK_RUNNER")
                    .map(PathBuf::from)
                    .unwrap_or_else(|_| {
                        root.join("harness")
                            .join("target")
                            .join("engines")
                            .join("gosdk-runner")
                    });
                if !bin.exists() {
                    return Err(format!("{} is not built (make gosdk-build)", bin.display()));
                }
                Ok(Command::new(bin))
            }
            EngineKind::TsSdk => {
                let node = node_bin(root)?;
                let script = root
                    .join("harness")
                    .join("engines")
                    .join("ts")
                    .join("runner.mjs");
                if !root
                    .join("harness")
                    .join("engines")
                    .join("ts")
                    .join("node_modules")
                    .join("@bsv")
                    .join("sdk")
                    .exists()
                {
                    return Err("harness/engines/ts/node_modules/@bsv/sdk is not installed (make tssdk-install)".into());
                }
                let mut c = Command::new(node);
                c.arg(script);
                Ok(c)
            }
            EngineKind::GoBdk => {
                let bin = std::env::var("GOBDK_RUNNER")
                    .map(PathBuf::from)
                    .unwrap_or_else(|_| {
                        root.join("harness")
                            .join("target")
                            .join("engines")
                            .join("gobdk-runner")
                    });
                if !bin.exists() {
                    return Err(format!(
                        "{} is not built (harness/engines/gobdk/build.sh)",
                        bin.display()
                    ));
                }
                Ok(Command::new(bin))
            }
        }
    }

    /// Spawn the adapter and check the version it reports against the pin (the per-entry wall `adapter_timeout()`).
    pub fn spawn(kind: EngineKind, root: &Path) -> Result<Adapter, String> {
        Self::spawn_with_timeout(kind, root, adapter_timeout())
    }

    /// Spawn the adapter with a given per-entry wall: the D15a re-run (2026-09-24, #42) serves an entry that timed out
    /// once more in a fresh adapter at ten times the wall; decided within it, the verdict is the engine's; not decided,
    /// the entry is an abort by D15 (`engine.timeout`, both walls named).
    pub fn spawn_with_timeout(
        kind: EngineKind,
        root: &Path,
        timeout: Duration,
    ) -> Result<Adapter, String> {
        let mut vcmd = Self::command(kind, root)?;
        let vout = vcmd
            .arg("--version")
            .output()
            .map_err(|e| format!("{}: --version: {e}", kind.name()))?;
        let banner = String::from_utf8_lossy(&vout.stdout).trim().to_string();
        let expected = format!(" {} ", kind.version());
        if !format!("{banner} ").contains(&expected) {
            return Err(format!(
                "{} adapter reports \"{banner}\", the pin is {} (docs/PROVENANCE.md §1a): rebuild or reinstall the adapter",
                kind.name(),
                kind.version()
            ));
        }
        let mut cmd = Self::command(kind, root)?;
        let mut child = cmd
            .stdin(Stdio::piped())
            .stdout(Stdio::piped())
            .stderr(Stdio::inherit())
            .spawn()
            .map_err(|e| format!("{}: spawn: {e}", kind.name()))?;
        let stdin = BufWriter::with_capacity(
            1 << 20,
            child
                .stdin
                .take()
                .ok_or_else(|| format!("{}: the piped stdin is absent", kind.name()))?,
        );
        let mut stdout = BufReader::with_capacity(
            1 << 20,
            child
                .stdout
                .take()
                .ok_or_else(|| format!("{}: the piped stdout is absent", kind.name()))?,
        );
        let (tx, lines) = mpsc::channel::<Result<String, String>>();
        std::thread::spawn(move || {
            let mut line = String::new();
            loop {
                line.clear();
                match stdout.read_line(&mut line) {
                    Ok(0) => {
                        let _ = tx.send(Err("closed".into()));
                        break;
                    }
                    Ok(_) => {
                        if tx.send(Ok(line.clone())).is_err() {
                            break;
                        }
                    }
                    Err(e) => {
                        let _ = tx.send(Err(format!("read: {e}")));
                        break;
                    }
                }
            }
        });
        Ok(Adapter {
            kind,
            child,
            stdin,
            lines,
            banner,
            timeout,
        })
    }

    /// One request, one response (the adapters answer in order).
    pub fn call(&mut self, req: &Request) -> Result<Response, String> {
        let line = serde_json::to_string(req).map_err(|e| format!("request json: {e}"))?;
        self.stdin
            .write_all(line.as_bytes())
            .and_then(|_| self.stdin.write_all(b"\n"))
            .and_then(|_| self.stdin.flush())
            .map_err(|e| format!("{}: write: {e}", self.kind.name()))?;
        let resp = loop {
            match self.lines.recv_timeout(self.timeout) {
                Ok(Ok(l)) => {
                    if !l.trim().is_empty() {
                        break l;
                    }
                }
                Ok(Err(why)) => {
                    return Err(format!(
                        "{}: the adapter closed its output ({why}; exit {:?})",
                        self.kind.name(),
                        self.child.try_wait().ok().flatten()
                    ));
                }
                Err(RecvTimeoutError::Timeout) => {
                    let _ = self.child.kill();
                    let _ = self.child.wait();
                    return Err(format!("{}: adapter-timeout: no answer within {} s on this entry (the adapter killed; ENGINE_ADAPTER_TIMEOUT_S)", self.kind.name(), self.timeout.as_secs()));
                }
                Err(RecvTimeoutError::Disconnected) => {
                    return Err(format!(
                        "{}: the adapter closed its output (exit {:?})",
                        self.kind.name(),
                        self.child.try_wait().ok().flatten()
                    ));
                }
            }
        };
        let mut r: Response = serde_json::from_str(resp.trim())
            .map_err(|e| format!("{}: response json: {e}: {}", self.kind.name(), resp.trim()))?;
        if r.id != req.id {
            return Err(format!(
                "{}: answered {} for {}",
                self.kind.name(),
                r.id,
                req.id
            ));
        }
        for v in r.runs.values_mut() {
            if let Some(m) = v.message.take() {
                v.message = Some(cap_text(m));
            }
        }
        if let Some(e) = r.error.take() {
            r.error = Some(cap_text(e));
        }
        Ok(r)
    }

    pub fn close(mut self) {
        drop(self.stdin);
        let _ = self.child.wait();
    }
}
