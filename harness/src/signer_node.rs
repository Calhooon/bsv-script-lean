//! The signer column's shared pieces (#145, #147; moved out of `run_signer.rs` by lane chain-152, 2026-10-17, for
//! #152's chain leg `run_signer_chain.rs`): the owned regtest node (an ordinary foreground child, never daemonized,
//! reaped before its owner returns), its `verifyscript` judgment kept to verdict fields and cited tokens, the
//! adapters' output line and the adapter runner. The hand signer stays in `signer.rs`.

use std::path::{Path, PathBuf};
use std::process::{Child, Command, Stdio};
use std::time::{Duration, Instant};

use bsv_rs::primitives::hash::sha256;
use serde::{Deserialize, Serialize};
use serde_json::{json, Value};

use crate::engines::{GO_SDK_VERSION, TS_SDK_VERSION};
use crate::rpc::Rpc;
use crate::signer::Row;
use crate::svnode_codes;
use crate::txraw::RawTx;
use crate::BSV_RS_VERSION;

type Result<T> = std::result::Result<T, String>;

pub const METHODS: [&str; 3] = ["template", "api-default", "api-scriptcode"];
pub const ENGINES: [(&str, &str); 3] = [
    ("go-sdk", GO_SDK_VERSION),
    ("ts-sdk", TS_SDK_VERSION),
    ("bsv-rs", BSV_RS_VERSION),
];

pub fn read(path: &Path) -> Result<String> {
    std::fs::read_to_string(path).map_err(|e| format!("read {}: {e}", path.display()))
}

pub fn output(cmd: &mut Command, label: &str) -> Result<String> {
    let out = cmd.output().map_err(|e| format!("{label}: {e}"))?;
    if !out.status.success() {
        return Err(format!("{label}: exit {}", out.status));
    }
    String::from_utf8(out.stdout).map_err(|_| format!("{label}: non-UTF8 output"))
}

pub fn file_hash(path: &Path) -> Result<String> {
    Ok(hex::encode(sha256(
        &std::fs::read(path).map_err(|e| format!("hash {}: {e}", path.display()))?,
    )))
}

pub fn decode(text: &str) -> Result<RawTx> {
    RawTx::decode(&hex::decode(text).map_err(|e| e.to_string())?)
}

pub fn write_json(path: &Path, value: &impl Serialize) -> Result<()> {
    let text = serde_json::to_string_pretty(value).map_err(|e| e.to_string())?;
    std::fs::write(path, text + "\n").map_err(|e| format!("write {}: {e}", path.display()))
}

/// A scratch directory removed when its owner returns, whatever the road.
pub struct RunDir(pub PathBuf);
impl Drop for RunDir {
    fn drop(&mut self) {
        let _ = std::fs::remove_dir_all(&self.0);
    }
}

/// What a node instance is started from: the binary (the pinned v1.2.3 build or its wallet twin, both banner
/// `v1.2.3.0-g6504a3aff-dev`, docs/PROVENANCE.md §1a) and the whole bitcoin.conf text.
pub struct NodeSpec {
    pub binary: PathBuf,
    pub conf: String,
}

pub struct Node {
    child: Child,
    rpc: Option<Rpc>,
    pub port: u16,
    pub binary_sha256: String,
}

impl Node {
    /// The column's instance: `reference.binary` (`$BSV_SPEC_REFERENCE_BINARY`, #177) with
    /// `harness/oracle/bitcoin.conf` as it stands.
    pub fn start(root: &Path, run: &Path) -> Result<Self> {
        let binary = crate::host::need(crate::host::REFERENCE_BINARY);
        let conf = read(&root.join("harness/oracle/bitcoin.conf"))?;
        Self::start_with(run, NodeSpec { binary, conf })
    }

    pub fn start_with(run: &Path, spec: NodeSpec) -> Result<Self> {
        let version = output(
            Command::new(&spec.binary).arg("-version"),
            "node version check",
        )?;
        if !version.contains("v1.2.3.0-g6504a3aff-dev") {
            return Err("node binary is not the pinned v1.2.3 build".into());
        }
        let binary_sha256 = hex::encode(sha256(
            &std::fs::read(&spec.binary).map_err(|e| e.to_string())?,
        ));
        // The same free pair band as tools/rpc_probe.py. Bind both while choosing.
        let mut pair = None;
        for port in 18571..18590 {
            if let (Ok(a), Ok(b)) = (
                std::net::TcpListener::bind(("127.0.0.1", port)),
                std::net::TcpListener::bind(("127.0.0.1", port + 1)),
            ) {
                pair = Some((port, a, b));
                break;
            }
        }
        let (port, a, b) = pair.ok_or("no free RPC/P2P pair in 18571..18590")?;
        let dir = run.join("node");
        std::fs::create_dir(&dir).map_err(|e| e.to_string())?;
        let conf = dir.join("bitcoin.conf");
        std::fs::write(&conf, &spec.conf).map_err(|e| e.to_string())?;
        drop((a, b));
        let child = Command::new(&spec.binary)
            .args(["-daemon=0", "-connect=0", "-maxconnections=0"])
            .arg(format!("-datadir={}", dir.display()))
            .arg(format!("-conf={}", conf.display()))
            .arg(format!("-rpcport={port}"))
            .arg(format!("-port={}", port + 1))
            .stdin(Stdio::null())
            .stdout(Stdio::null())
            .stderr(Stdio::null())
            .spawn()
            .map_err(|e| format!("start node: {e}"))?;
        let mut node = Self {
            child,
            rpc: None,
            port,
            binary_sha256,
        };
        let cookie = dir.join("regtest/.cookie");
        let deadline = Instant::now() + Duration::from_secs(60);
        while Instant::now() < deadline {
            if node.child.try_wait().map_err(|e| e.to_string())?.is_some() {
                return Err("owned regtest node exited during startup".into());
            }
            if cookie.exists() {
                let rpc = Rpc::new(
                    &format!("http://127.0.0.1:{port}"),
                    cookie.to_str().ok_or("cookie path is not UTF8")?,
                    Duration::from_secs(65),
                );
                if let Ok(mut rpc) = rpc {
                    if rpc.call("getblockcount", json!([])).is_ok() {
                        node.rpc = Some(rpc);
                        node.check()?;
                        return Ok(node);
                    }
                }
            }
            std::thread::sleep(Duration::from_millis(25));
        }
        Err("owned regtest node startup timed out".into())
    }

    pub fn call(&mut self, method: &str, params: Value) -> Result<Value> {
        self.call_raw(method, params)
            .map_err(|_| format!("node RPC {method} failed (reply suppressed)"))
    }

    /// The call with the node's error kept, for a caller that reduces it to a cited token (`sendrawtransaction`'s
    /// refusal); never printed as it stands.
    pub fn call_raw(&mut self, method: &str, params: Value) -> Result<Value> {
        self.rpc
            .as_mut()
            .ok_or("node RPC is not ready")?
            .call(method, params)
    }

    fn check(&mut self) -> Result<()> {
        let chain = self.call("getblockchaininfo", json!([]))?;
        let net = self.call("getnetworkinfo", json!([]))?;
        if chain["chain"] != "regtest"
            || chain["blocks"] != 0
            || net["subversion"] != "/Bitcoin SV:1.2.3/"
        {
            return Err("node pin, regtest or empty-chain check failed".into());
        }
        let settings = self.call("getsettings", json!([]))?;
        for key in [
            "maxscriptsizepolicy",
            "maxopsperscriptpolicy",
            "maxpubkeyspermultisigpolicy",
        ] {
            if settings[key].as_u64() != Some(u32::MAX as u64) {
                return Err(format!("node configuration drift: {key}"));
            }
        }
        if settings["maxstackmemoryusagepolicy"].as_i64() != Some(i64::MAX) {
            return Err("node configuration drift: maxstackmemoryusagepolicy".into());
        }
        // Every actual judgment also checks the entire applied flag word.
        Ok(())
    }

    /// `verifyscript` of every input of `tx` against the row's prevouts (their heights as `txo.height`) under one
    /// word per input.
    pub fn judge(&mut self, row: &Row, tx: &str, words: &[u32]) -> Result<Vec<Verdict>> {
        let scripts: Vec<_> = row
            .entry
            .prevouts
            .iter()
            .enumerate()
            .map(|(i, p)| {
                json!({
                    "tx": tx, "n": i, "flags": words[i], "reportflags": true,
                    "txo": {"lock": p.script, "value": p.satoshis, "height": p.height}
                })
            })
            .collect();
        // false is essential: a refused input must not hide the remaining inputs.
        let result = self.call("verifyscript", json!([scripts, false, 60000]))?;
        verdicts(&result, words)
    }

    pub fn stop(&mut self) -> Result<()> {
        self.call("stop", json!([]))?;
        let deadline = Instant::now() + Duration::from_secs(15);
        while Instant::now() < deadline {
            if let Some(status) = self.child.try_wait().map_err(|e| e.to_string())? {
                return if status.success() {
                    Ok(())
                } else {
                    Err("node shutdown failed".into())
                };
            }
            std::thread::sleep(Duration::from_millis(25));
        }
        Err("node shutdown timed out; owned child will be killed and reaped".into())
    }
}

impl Drop for Node {
    fn drop(&mut self) {
        if !matches!(self.child.try_wait(), Ok(Some(_))) {
            let _ = self.child.kill();
            let _ = self.child.wait();
        }
    }
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize)]
pub struct Verdict {
    pub verdict: String,
    pub code: Option<String>,
}

pub fn verdicts(value: &Value, words: &[u32]) -> Result<Vec<Verdict>> {
    let rows = value.as_array().ok_or("node result is not an array")?;
    if rows.len() != words.len() {
        return Err("node result count differs from input count".into());
    }
    rows.iter()
        .zip(words)
        .map(|(r, word)| {
            if r["flags"].as_u64() != Some(u64::from(*word)) {
                return Err("node applied flag-word drift".into());
            }
            let (verdict, code) = match r["result"].as_str() {
                Some("ok") => ("valid", None),
                Some("error") => {
                    let code = svnode_codes::code_of(r["description"].as_str().unwrap_or(""))
                        .ok_or("node reject description outside the cited token table")?;
                    ("invalid", Some(code.code.to_string()))
                }
                Some("timeout" | "skipped") => {
                    return Err("node verdict undecided (timeout/skipped)".into())
                }
                _ => return Err("unknown node verdict field".into()),
            };
            Ok(Verdict {
                verdict: verdict.into(),
                code,
            })
        })
        .collect()
}

#[derive(Clone, Deserialize, Serialize)]
pub struct Trace {
    pub index: usize,
    pub site: usize,
    pub preimage_hex: String,
    pub digest_hex: String,
    pub scriptcode_used_hex: String,
}

/// One line of a signer adapter's output (`corpus/signer/README.md`).
#[derive(Deserialize)]
pub struct Signed {
    pub id: String,
    pub engine: String,
    pub method: String,
    pub tx_hex: Option<String>,
    pub inputs: Vec<Trace>,
    pub note: String,
}

/// Run one adapter over `rows` (written to `<run>/<stem>.corpus.jsonl`), its banner checked against the pin before it runs;
/// its lines as it wrote them to `<run>/<stem>.<engine>.jsonl`.
pub fn adapter(
    root: &Path,
    run: &Path,
    engine: &str,
    rows: &[Row],
    stem: &str,
) -> Result<Vec<Signed>> {
    let input = run.join(format!("{stem}.corpus.jsonl"));
    let text = rows
        .iter()
        .map(|r| serde_json::to_string(r).map(|s| s + "\n"))
        .collect::<std::result::Result<String, _>>()
        .map_err(|e| e.to_string())?;
    std::fs::write(&input, text).map_err(|e| e.to_string())?;
    let dest = run.join(format!("{stem}.{engine}.jsonl"));
    let mut cmd = if engine == "go-sdk" {
        Command::new(
            std::env::var("GOSDK_SIGNER_BIN")
                .map_err(|_| "GOSDK_SIGNER_BIN absent; use make check-signer")?,
        )
    } else if engine == "bsv-rs" {
        Command::new(
            std::env::current_exe()
                .map_err(|e| e.to_string())?
                .with_file_name("signer_bsvrs"),
        )
    } else {
        let node = output(
            &mut Command::new(root.join("tools/node_bin.sh")),
            "select Node 22",
        )?;
        let mut cmd = Command::new(node.trim());
        cmd.arg(root.join("harness/engines/ts/signer.mjs"));
        cmd
    };
    let banner = output(
        Command::new(cmd.get_program())
            .args(cmd.get_args())
            .arg("--version"),
        "signer pin check",
    )?;
    let expected_banner = if engine == "go-sdk" {
        format!("gosdk-signer (bsv-script-lean #145) go-sdk {GO_SDK_VERSION}")
    } else if engine == "bsv-rs" {
        format!("bsvrs-signer (bsv-script-lean #147) bsv-rs {BSV_RS_VERSION}")
    } else {
        format!("ts-sdk-signer@{TS_SDK_VERSION}")
    };
    if banner.trim() != expected_banner {
        return Err("signer adapter pin mismatch".into());
    }
    output(
        cmd.args(["--corpus"]).arg(&input).arg("--out").arg(&dest),
        "signer adapter",
    )?;
    read(&dest)?
        .lines()
        .filter(|l| !l.trim().is_empty())
        .map(|l| serde_json::from_str(l).map_err(|e| format!("adapter JSON: {e}")))
        .collect()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn rpc_drift_missing_inputs_and_undecided_are_errors() {
        assert!(verdicts(&json!([]), &[1]).is_err());
        assert!(verdicts(&json!([{"flags":2,"result":"ok"}]), &[1]).is_err());
        assert!(verdicts(&json!([{"flags":1,"result":"timeout"}]), &[1]).is_err());
        assert!(verdicts(&json!([{"flags":1,"result":"skipped"}]), &[1]).is_err());
        assert!(verdicts(
            &json!([{"flags":1,"result":"error","description":"unmapped text"}]),
            &[1]
        )
        .is_err());
    }

    #[test]
    fn rpc_results_keep_only_verdicts_and_tokens() -> Result<()> {
        let got = verdicts(
            &json!([
                {"flags":1,"result":"ok","description":"do not retain"},
                {"flags":1,"result":"error","description":"Script evaluated without error but finished with a false/empty top stack element"}
            ]),
            &[1, 1],
        )?;
        assert_eq!(got[0].verdict, "valid");
        assert_eq!(got[1].code.as_deref(), Some("SCRIPT_ERR_EVAL_FALSE"));
        assert!(!serde_json::to_string(&got)
            .map_err(|e| e.to_string())?
            .contains("description"));
        Ok(())
    }
}
