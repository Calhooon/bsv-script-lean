//! #66 cut 2 (S3, lane cut2-66, [D] 2026-10-15): the loopback peer pointed at Teranode's
//! legacy bridge. The reference's own test peer at core::PIN (`harness/peer/peer.py`,
//! mininode.py:48,2118-2690) speaks the wire; the bridge (Teranode v0.16.0 at
//! 4edb60a40c6628ff0ef60231c2628efd7103fde5, `services/legacy/`) translates it
//! (docs/CONFORMANCE-TERANODE-BRIDGE.md section 1: `tx` row 10 into the validator, `block`
//! row 13 into block validation, `inv` row 4, `getdata` row 5). The instance runs the
//! second recipe (`harness/engines/instance41/legacy.conf`), its listener on 127.0.0.1.
//! A step the peer refuses ends its process (peer.py's loop); the next step reconnects,
//! and the receipt names every connection.
use super::*;
use std::io::{BufRead, BufReader, Write};
use std::process::{ChildStdin, Stdio};
use std::sync::mpsc::{self, Receiver};

/// The bridge's listener (legacy.conf's LEGACY_P2P_PORT, inside peer.py's reserved range).
pub(super) const PORT: u16 = 18590;
/// The user agent the version message carries: the bridge rejects and bans an agent without
/// `Bitcoin SV` or `BSV` ([SRC] services/legacy/peer_server.go:762-764,802-814 at the Teranode pin).
pub(super) const AGENT: &str = "/python-mininode-tester:0.0.3/harness-peer-BSV/";

struct Proc {
    child: Child,
    input: ChildStdin,
    output: Receiver<std::io::Result<String>>,
    next: u64,
}

pub(super) struct Bridge {
    pub(super) dir: PathBuf,
    proc: Option<Proc>,
    /// Every peer event of every connection, each tagged with its connection number.
    pub(super) events: Vec<Value>,
    pub(super) connections: u32,
    /// Each connection's end: closed by the runner, or the step whose refusal ended it.
    pub(super) ends: Vec<Value>,
}

/// A point in the event journal: the local index and the live connection's own cursor.
#[derive(Clone, Copy)]
pub(super) struct Mark {
    pub(super) local: usize,
    connection: u32,
    peer: u64,
}

fn now() -> u64 {
    std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map(|d| d.as_secs())
        .unwrap_or(0)
}

impl Bridge {
    pub(super) fn new(dir: PathBuf) -> Self {
        Self {
            dir,
            proc: None,
            events: vec![],
            connections: 0,
            ends: vec![],
        }
    }

    fn connect(&mut self) -> Result<()> {
        self.connections += 1;
        let n = self.connections;
        let mut child = Command::new("python3")
            .args(["-u", "harness/peer/peer.py", "--receipt"])
            .arg(self.dir.join(format!("peer-{n}.jsonl")))
            .stdin(Stdio::piped())
            .stdout(Stdio::piped())
            .stderr(
                fs::File::create(self.dir.join(format!("peer-{n}.err")))
                    .map_err(|e| e.to_string())?,
            )
            .spawn()
            .map_err(|e| e.to_string())?;
        let input = child.stdin.take().ok_or("peer stdin")?;
        let stdout = child.stdout.take().ok_or("peer stdout")?;
        let (tx, output) = mpsc::channel();
        thread::spawn(move || {
            for line in BufReader::new(stdout).lines() {
                if tx.send(line).is_err() {
                    break;
                }
            }
        });
        self.proc = Some(Proc {
            child,
            input,
            output,
            next: 0,
        });
        // The advertised time is the host clock the instance reads (Teranode has no mock clock).
        let r = self.raw(
            json!({"op":"connect","host":"127.0.0.1","port":PORT,"time":now(),"user_agent":AGENT}),
        )?;
        if r["ok"] != true {
            return Err(format!("bridge connect refused: {}", r["error"]));
        }
        Ok(())
    }

    // One step on the live process; a refusal ends the process (peer.py breaks its loop).
    fn raw(&mut self, request: Value) -> Result<Value> {
        let n = self.connections;
        let p = self.proc.as_mut().ok_or("no peer process")?;
        writeln!(p.input, "{request}").map_err(|e| e.to_string())?;
        p.input.flush().map_err(|e| e.to_string())?;
        let line = p
            .output
            .recv_timeout(Duration::from_secs(40))
            .map_err(|e| format!("peer response: {e}"))?
            .map_err(|e| e.to_string())?;
        let response: Value =
            serde_json::from_str(&line).map_err(|e| format!("peer JSON {e}: {line}"))?;
        if response["source_pin"] != PIN {
            return Err("peer pin receipt mismatch".into());
        }
        for e in response["events"].as_array().ok_or("peer events")? {
            let mut e = e.clone();
            e["connection"] = json!(n);
            self.events.push(e);
        }
        p.next = response["next_index"].as_u64().ok_or("peer cursor")?;
        if response["ok"] != true {
            self.ends
                .push(json!({"connection":n,"ended_by":request,"error":response["error"]}));
            if let Some(mut p) = self.proc.take() {
                let _ = p.child.wait();
            }
        }
        Ok(response)
    }

    /// One step, reconnecting beforehand when the previous connection ended. The whole response
    /// (`ok`, `result`, `error`) is returned; only a transport failure is an `Err`.
    pub(super) fn step(&mut self, request: Value) -> Result<Value> {
        if self.proc.is_none() {
            self.connect()?;
        }
        self.raw(request)
    }

    pub(super) fn mark(&mut self) -> Result<Mark> {
        if self.proc.is_none() {
            self.connect()?;
        }
        Ok(Mark {
            local: self.events.len(),
            connection: self.connections,
            peer: self.proc.as_ref().map(|p| p.next).unwrap_or(0),
        })
    }

    pub(super) fn send_tx(&mut self, tx: &RawTx) -> Result<Value> {
        self.step(json!({"op":"send_tx","hex":hex::encode(tx.encode())}))
    }

    pub(super) fn send_block(&mut self, bytes: &[u8]) -> Result<Value> {
        self.step(json!({"op":"send_block","hex":hex::encode(bytes)}))
    }

    pub(super) fn send_inv(&mut self, tx: &RawTx) -> Result<Value> {
        self.step(json!({"op":"send_inv","kind":"tx","hash":id(tx)}))
    }

    /// Wait for a received message of `kind` (`getdata`, `inv`, `reject`; `none` for silence)
    /// naming `hash` since `mark` on the same connection; a later connection has no such
    /// message, so the answer is read from the journal.
    pub(super) fn expect(
        &mut self,
        kind: &str,
        hash: &str,
        mark: Mark,
        timeout: f64,
    ) -> Result<bool> {
        if self.proc.is_some() && self.connections == mark.connection {
            let r = self.raw(
                json!({"op":"expect","kind":kind,"hash":hash,"since":mark.peer,"timeout":timeout}),
            )?;
            if r["ok"] == true {
                return Ok(r["result"]["matched"] == true);
            }
        }
        let seen = self.received(kind, hash, mark).is_some();
        Ok(if kind == "none" { !seen } else { seen })
    }

    /// The received message of `kind` naming `hash` since `mark`, from the journal.
    pub(super) fn received(&self, kind: &str, hash: &str, mark: Mark) -> Option<Value> {
        self.events[mark.local.min(self.events.len())..]
            .iter()
            .find(|e| {
                e["direction"] == "receive"
                    && (if kind == "none" {
                        matches!(e["command"].as_str(), Some("inv" | "getdata" | "reject"))
                    } else {
                        e["command"] == kind
                    })
                    && (e["hash"] == hash
                        || e["inventory"]
                            .as_array()
                            .is_some_and(|i| i.iter().any(|x| x["hash"] == hash)))
            })
            .cloned()
    }

    /// The connections that ended since `mark` (a disconnect by the bridge).
    pub(super) fn ended_since(&self, mark: Mark) -> Vec<Value> {
        self.ends
            .iter()
            .filter(|e| e["connection"].as_u64().unwrap_or(0) >= mark.connection as u64)
            .cloned()
            .collect()
    }

    pub(super) fn close(&mut self) -> Result<()> {
        if self.proc.is_some() {
            let n = self.connections;
            let r = self.raw(json!({"op":"close"}))?;
            if let Some(mut p) = self.proc.take() {
                p.child.wait().map_err(|e| e.to_string())?;
            }
            self.ends
                .push(json!({"connection":n,"ended_by":"the runner's close","ok":r["ok"]}));
        }
        Ok(())
    }

    pub(super) fn receipt(&self) -> Value {
        json!({"source_pin":PIN,"protocol_version":70016,"user_agent":AGENT,"port":PORT,
            "connections":self.connections,"ends":self.ends,"events":self.events.len(),
            "receipts":(1..=self.connections).map(|n| format!("peer-{n}.jsonl")).collect::<Vec<_>>(),
            "source":"harness/peer/peer.py (mininode.py:48,2118-2690 at the reference pin); the bridge's handlers: docs/CONFORMANCE-TERANODE-BRIDGE.md section 1 rows 4, 5, 10, 13"})
    }
}

impl Drop for Bridge {
    fn drop(&mut self) {
        if let Some(mut p) = self.proc.take() {
            let _ = p.child.kill();
            let _ = p.child.wait();
        }
    }
}
