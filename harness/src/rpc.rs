//! rpc: the node's JSON-RPC over loopback (this repo's; #27; moved out of `run_svnode.rs` on 2026-09-26 so the
//! block road's tools share it). Cookie auth (`<datadir>/regtest/.cookie`; no password exists in this repo), one
//! HTTP/1.1 POST per call over a fresh TCP connection, a read timeout; a JSON-RPC error is an `Err` carrying the
//! node's error object as text. Nothing here reaches a peer: the RPC is loopback on the Studio, or the mini through
//! the ssh tunnel `spec-node.sh mini tunnel` (CLAUDE.md rule 10).

use std::io::{Read, Write};
use std::net::TcpStream;
use std::time::Duration;

pub struct Rpc {
    pub host: String,
    pub port: u16,
    auth: String,
    pub timeout: Duration,
    pub calls: u64,
}

pub fn base64(input: &[u8]) -> String {
    const T: &[u8; 64] = b"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
    let mut out = String::new();
    for chunk in input.chunks(3) {
        let b = [
            chunk[0],
            *chunk.get(1).unwrap_or(&0),
            *chunk.get(2).unwrap_or(&0),
        ];
        let n = ((b[0] as u32) << 16) | ((b[1] as u32) << 8) | b[2] as u32;
        out.push(T[(n >> 18) as usize & 63] as char);
        out.push(T[(n >> 12) as usize & 63] as char);
        out.push(if chunk.len() > 1 {
            T[(n >> 6) as usize & 63] as char
        } else {
            '='
        });
        out.push(if chunk.len() > 2 {
            T[n as usize & 63] as char
        } else {
            '='
        });
    }
    out
}

/// HTTP/1.1 chunked transfer decoding (RFC 9112 §7.1): `<hex size>\r\n<chunk>\r\n` repeated, a zero size ending it.
pub(crate) fn dechunk(body: &str) -> String {
    let mut out = String::new();
    let mut rest = body;
    while let Some((size_line, after)) = rest.split_once("\r\n") {
        let size =
            usize::from_str_radix(size_line.trim().split(';').next().unwrap_or("0").trim(), 16)
                .unwrap_or(0);
        if size == 0 {
            break;
        }
        if after.len() < size {
            out.push_str(after);
            break;
        }
        out.push_str(&after[..size]);
        rest = after[size..].strip_prefix("\r\n").unwrap_or(&after[size..]);
    }
    out
}

impl Rpc {
    /// `url` is `http://host:port`; `cookie_path` the node's cookie file.
    pub fn new(url: &str, cookie_path: &str, timeout: Duration) -> Result<Rpc, String> {
        let rest = url
            .strip_prefix("http://")
            .ok_or("--rpc must be http://host:port")?;
        let (host, port) = rest
            .trim_end_matches('/')
            .split_once(':')
            .ok_or("--rpc must be http://host:port")?;
        let port: u16 = port.parse().map_err(|_| "--rpc port")?;
        let cookie = std::fs::read_to_string(cookie_path)
            .map_err(|e| format!("cookie {cookie_path}: {e}"))?;
        let auth = base64(cookie.trim().as_bytes());
        Ok(Rpc {
            host: host.to_string(),
            port,
            auth,
            timeout,
            calls: 0,
        })
    }

    pub fn call(
        &mut self,
        method: &str,
        params: serde_json::Value,
    ) -> Result<serde_json::Value, String> {
        self.calls += 1;
        let body = serde_json::json!({"jsonrpc": "1.0", "id": self.calls, "method": method, "params": params}).to_string();
        let mut s = TcpStream::connect((self.host.as_str(), self.port))
            .map_err(|e| format!("rpc connect {}:{}: {e}", self.host, self.port))?;
        s.set_read_timeout(Some(self.timeout)).ok();
        s.set_write_timeout(Some(self.timeout)).ok();
        let req = format!(
            "POST / HTTP/1.1\r\nHost: {}:{}\r\nAuthorization: Basic {}\r\nContent-Type: application/json\r\nContent-Length: {}\r\nConnection: close\r\n\r\n",
            self.host, self.port, self.auth, body.len()
        );
        s.write_all(req.as_bytes())
            .and_then(|_| s.write_all(body.as_bytes()))
            .map_err(|e| format!("rpc write: {e}"))?;
        let mut raw = Vec::new();
        s.read_to_end(&mut raw)
            .map_err(|e| format!("rpc read: {e}"))?;
        let text = String::from_utf8_lossy(&raw);
        let (head, body) = text.split_once("\r\n\r\n").ok_or_else(|| {
            format!(
                "rpc: no header/body split in {}",
                text.chars().take(200).collect::<String>()
            )
        })?;
        let status = head.lines().next().unwrap_or("");
        // the node answers larger results with `Transfer-Encoding: chunked` (hex length, CRLF, the chunk, CRLF, ... 0): de-chunk
        let chunked = head.lines().any(|l| {
            l.to_ascii_lowercase().starts_with("transfer-encoding:")
                && l.to_ascii_lowercase().contains("chunked")
        });
        let body: String = if chunked {
            dechunk(body)
        } else {
            body.to_string()
        };
        let v: serde_json::Value = serde_json::from_str(body.trim()).map_err(|e| {
            format!(
                "rpc json ({status}): {e}: {}",
                body.chars().take(300).collect::<String>()
            )
        })?;
        if !v["error"].is_null() {
            return Err(format!("rpc error: {}", v["error"]));
        }
        Ok(v["result"].clone())
    }

    /// The node's error object of a refused call, when the `Err` is one (`{"code": -26, "message": "..."}`).
    pub fn error_message(err: &str) -> Option<String> {
        let j = err.strip_prefix("rpc error: ")?;
        let v: serde_json::Value = serde_json::from_str(j).ok()?;
        v["message"].as_str().map(|m| m.to_string())
    }
}
