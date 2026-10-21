//! The maintainers' host values (#177): docs/PROVENANCE.md 1a writes a clone
//! or a built binary as `$NAME`, a path on a maintainers' host. NAME is read
//! from the environment, else from the `NAME="value"` line of
//! tools/host_private.sh (`$HOME` expanded; the file is withheld from the
//! public edition). Unresolved, a tool prints one line and exits 2.
//! tools/host_vars.py is the same reader for the Python tools.
use std::path::PathBuf;

pub const REFERENCE_CLONE: &str = "BSV_SPEC_REFERENCE_CLONE";
pub const REFERENCE_BINARY: &str = "BSV_SPEC_REFERENCE_BINARY";
pub const REFERENCE_BINARY_WALLET: &str = "BSV_SPEC_REFERENCE_BINARY_WALLET";
pub const REFERENCE_BINARY_ZMQ: &str = "BSV_SPEC_REFERENCE_BINARY_ZMQ";

fn host_file() -> PathBuf {
    std::env::var("BSV_SCRIPT_LEAN_ROOT")
        .map_or_else(
            |_| PathBuf::from(env!("CARGO_MANIFEST_DIR")).join(".."),
            PathBuf::from,
        )
        .join("tools/host_private.sh")
}

/// NAME from the environment, else from tools/host_private.sh; None when neither holds it.
pub fn value(name: &str) -> Option<String> {
    value_in(name, std::fs::read_to_string(host_file()).ok().as_deref())
}

fn value_in(name: &str, src: Option<&str>) -> Option<String> {
    if let Some(v) = std::env::var(name).ok().filter(|v| !v.is_empty()) {
        return Some(v);
    }
    let prefix = format!("{name}=\"");
    let v = src?
        .lines()
        .find_map(|l| l.strip_prefix(prefix.as_str())?.strip_suffix('"'))
        .filter(|v| !v.is_empty())?;
    Some(v.replace("$HOME", &std::env::var("HOME").unwrap_or_default()))
}

pub fn refusal(tool: &str, name: &str) -> String {
    format!("{tool}: a maintainers' route; {name} is unset and tools/host_private.sh is absent (tools/README.md)")
}

/// NAME as a path, or the one line on stderr and exit 2.
pub fn need(name: &str) -> PathBuf {
    value(name).map(PathBuf::from).unwrap_or_else(|| {
        let tool = std::env::args()
            .next()
            .and_then(|a| {
                std::path::Path::new(&a)
                    .file_name()
                    .map(|f| f.to_string_lossy().into_owned())
            })
            .unwrap_or_else(|| "harness".into());
        eprintln!("{}", refusal(&tool, name));
        std::process::exit(2)
    })
}

#[cfg(test)]
mod tests {
    use super::*;

    // [D] 2026-10-21 (#177 b): the host file's line form, `$HOME` expanded; an
    // empty or missing line is unresolved (the variable names are unset here).
    #[test]
    fn value_reads_the_host_line() {
        let home = std::env::var("HOME").unwrap_or_default();
        let src = "# c\nBSV_SPEC_TEST_UNSET_A=\"$HOME/x/y\"\nBSV_SPEC_TEST_UNSET_B=\"\"\n";
        assert_eq!(
            value_in("BSV_SPEC_TEST_UNSET_A", Some(src)),
            Some(format!("{home}/x/y"))
        );
        assert_eq!(value_in("BSV_SPEC_TEST_UNSET_B", Some(src)), None);
        assert_eq!(value_in("BSV_SPEC_TEST_UNSET_C", Some(src)), None);
        assert_eq!(value_in("BSV_SPEC_TEST_UNSET_A", None), None);
        assert_eq!(
            refusal("t", "N"),
            "t: a maintainers' route; N is unset and tools/host_private.sh is absent (tools/README.md)"
        );
    }

    // [D] 2026-10-21 (#177 b): the pins block names each of the three node
    // builds by the variable this module reads.
    #[test]
    fn pins_block_names_the_variables() {
        let pins = include_str!("../../docs/PROVENANCE.md");
        for (key, name) in [
            ("reference.binary ", REFERENCE_BINARY),
            ("reference.binary_wallet ", REFERENCE_BINARY_WALLET),
            ("reference.binary_zmq ", REFERENCE_BINARY_ZMQ),
            ("reference.clone ", REFERENCE_CLONE),
        ] {
            let line = pins.lines().find(|l| l.starts_with(key)).unwrap();
            assert_eq!(line.split_once('=').unwrap().1.trim(), format!("${name}"));
        }
    }
}
