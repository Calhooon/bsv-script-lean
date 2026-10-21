//! The spec stamp's gate (lean #32's second lens, B-4, and its re-lenses; S1's patch for S3): a record names the
//! sources its verdicts came from, so a spec column stamped with no commit (`spec@<commit>+dirty`: `lean/` had
//! uncommitted changes; `spec@unknown`: no HEAD at the root, the binary run without the wrapper, or no spec line;
//! `eval/bsvs`) never reaches the corpus, neither its entries (`--record`) nor its witnesses (a directory under
//! `corpus/`, read on the path itself, so a directory not made yet counts). Every line's commit is read: a column whose
//! lines name different commits is refused too (a hand-merged file). The runners call it before any engine or node is
//! touched.
//! THE FORM (the applied set's lens, Sol and Astra): a commit is read in the forms the wrapper `eval/bsvs` emits and
//! nothing else: `git rev-parse --short` of the HEAD (lowercase hex, 7 to 40 digits: git's default abbreviation is at
//! least 7, the full name 40), that with `+dirty`, or `unknown`. An empty, spaced or arbitrary value names no commit,
//! so the gate counts it with `+dirty` and `unknown` and refuses it for the corpus, the value named after the gate's
//! report; a recorded key read back (`spec_recorded`) must name a commit.
//! THE OWNER'S RULINGS (2026-10-05, `docs/records/20261005-224016-owner-rulings-32-p.md`): the runners call the gate
//! right after the repository root is set and before the corpus or the column is read (P4), so for a column missing,
//! unreadable or stamped without a commit its report, exit 2, comes ahead of any file-read error (P5); and this reader
//! stays lenient where the comparison reader (`differential::read_spec`) is strict (P6): a line it cannot read names
//! `unknown` state, and off the corpus every stamp passes the gate.
use std::path::Path;

/// What a commit stamp names.
#[derive(Debug, PartialEq, Eq)]
pub enum Stamp {
    /// a commit: `git rev-parse --short` of a HEAD whose `lean/` had no uncommitted change
    Commit,
    /// `<commit>+dirty`: `lean/` had uncommitted changes
    Dirty,
    /// `unknown`: no HEAD at the root, the binary run without the wrapper, or no readable spec line
    Unknown,
}

fn is_abbrev(c: &str) -> bool {
    (7..=40).contains(&c.len())
        && c.bytes()
            .all(|b| b.is_ascii_digit() || (b'a'..=b'f').contains(&b))
}

/// The form of a commit stamp (the text after `spec@`), or an error naming the value.
pub fn stamp_form(c: &str) -> Result<Stamp, String> {
    if is_abbrev(c) {
        Ok(Stamp::Commit)
    } else if c.strip_suffix("+dirty").is_some_and(is_abbrev) {
        Ok(Stamp::Dirty)
    } else if c == "unknown" {
        Ok(Stamp::Unknown)
    } else {
        Err(format!("the commit stamp {c:?} is none of the forms eval/bsvs emits (7 to 40 lowercase hex digits, that with +dirty, or unknown)"))
    }
}

/// The distinct commits of a spec column file's lines (`eval/bsvs corpus`'s output), in their first order; a line
/// without a readable commit counts as `unknown`, and a file without lines gives `["unknown"]`.
pub fn spec_commits(spec_path: &str) -> Vec<String> {
    let mut out: Vec<String> = Vec::new();
    for l in std::fs::read_to_string(spec_path)
        .unwrap_or_default()
        .lines()
        .filter(|l| !l.trim().is_empty())
    {
        let c = serde_json::from_str::<serde_json::Value>(l)
            .ok()
            .and_then(|v| {
                v.get("commit")
                    .and_then(|c| c.as_str())
                    .map(|s| s.to_string())
            })
            .unwrap_or_else(|| "unknown".into());
        if !out.contains(&c) {
            out.push(c);
        }
    }
    if out.is_empty() {
        out.push("unknown".into());
    }
    out
}

/// Whether `dir` lies under `<root>/corpus`, read the way the run would make it (below).
pub fn under_corpus(dir: &str, root: &Path) -> bool {
    let p = Path::new(dir);
    let abs = if p.is_absolute() {
        p.to_path_buf()
    } else {
        std::env::current_dir()
            .map(|c| c.join(p))
            .unwrap_or_else(|_| p.to_path_buf())
    };
    // component by component, as the run would make the directory: an existing prefix resolved by the file system
    // (its symlinks and `..` physically), a part not made yet lexically (a `..` there pops a directory the run would
    // make), so neither a directory not made yet nor a `..` after one slips out (re-lens 3, B3N-5)
    let mut cur = std::path::PathBuf::new();
    for c in abs.components() {
        match c {
            std::path::Component::CurDir => {}
            std::path::Component::ParentDir if !cur.exists() => {
                cur.pop();
            }
            c => {
                cur.push(c.as_os_str());
                if let Ok(real) = cur.canonicalize() {
                    cur = real;
                }
            }
        }
    }
    root.join("corpus")
        .canonicalize()
        .map(|c| cur.starts_with(c))
        .unwrap_or(false)
}

/// Exit 2, before anything is written, when the run would write into the corpus and the column's stamp names no
/// commit or its lines name more than one.
pub fn refuse_unnamed_stamp(
    tool: &str,
    spec_path: &str,
    record: bool,
    witnesses_dir: &str,
    root: &Path,
) {
    if let Some(why) = stamp_refusal(spec_path, record, witnesses_dir, root) {
        eprintln!("{tool}: {why}");
        std::process::exit(2);
    }
}

/// The gate's verdict without the exit: why the run is refused, or None.
pub fn stamp_refusal(
    spec_path: &str,
    record: bool,
    witnesses_dir: &str,
    root: &Path,
) -> Option<String> {
    let commits = spec_commits(spec_path);
    let unnamed = commits.len() > 1 || commits.iter().any(|c| stamp_form(c) != Ok(Stamp::Commit));
    if unnamed && (record || under_corpus(witnesses_dir, root)) {
        // the report stays the gate's own (P5); a stamp in no form the wrapper emits is named after it
        let form = commits
            .iter()
            .find_map(|c| stamp_form(c).err())
            .map(|e| format!("; {e}"))
            .unwrap_or_default();
        return Some(format!("refusing to write spec@{} into the corpus (a stamp no commit names, or several: lean/ uncommitted, no HEAD at the root, the binary run without the wrapper, a merged column, or no readable spec line); commit the Lean sources, rebuild, and run again (lean #32, B-4){form}", commits.join(", spec@")));
    }
    None
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn the_forms_eval_bsvs_emits_are_read() {
        assert_eq!(stamp_form("8e449b5"), Ok(Stamp::Commit));
        assert_eq!(stamp_form("8e449b5c0ffee"), Ok(Stamp::Commit));
        assert_eq!(stamp_form(&"a".repeat(40)), Ok(Stamp::Commit));
        assert_eq!(stamp_form("8e449b5+dirty"), Ok(Stamp::Dirty));
        assert_eq!(stamp_form("unknown"), Ok(Stamp::Unknown));
    }

    #[test]
    fn every_other_stamp_is_refused_with_its_value() {
        for bad in [
            "",
            " ",
            "\t",
            " 8e449b5",
            "8e449b5 ",
            "8e44 9b5",
            "8E449B5",
            "8e449b",
            "abc",
            &"a".repeat(41),
            "8e449bz",
            "+dirty",
            "8e449b5+dirty+dirty",
            "8e449b5-dirty",
            "Unknown",
            "unknown+dirty",
            "HEAD",
            "main",
            "spec@8e449b5",
        ] {
            let e = stamp_form(bad).expect_err(bad);
            assert!(e.contains(&format!("{bad:?}")), "{e}");
        }
    }

    #[test]
    fn a_column_reads_every_lines_commit() {
        let d = std::env::temp_dir().join(format!("stamp-test-{}", std::process::id()));
        std::fs::create_dir_all(&d).unwrap();
        let f = d.join("spec.jsonl");
        std::fs::write(
            &f,
            "{\"commit\": \"\", \"id\": \"a\"}\n{\"commit\": \"8e449b5\", \"id\": \"b\"}\n",
        )
        .unwrap();
        let p = f.to_str().unwrap();
        let root = std::env::current_dir().unwrap().join("..");
        let out = d.join("out").to_str().unwrap().to_string();
        assert_eq!(spec_commits(p), vec!["".to_string(), "8e449b5".to_string()]);
        // an empty commit among clean ones is refused for the corpus, the gate's report first and the value named
        let why = stamp_refusal(p, true, &out, &root).expect("an empty stamp is refused");
        assert!(why.starts_with("refusing to write spec@, spec@8e449b5 into the corpus") && why.ends_with("; the commit stamp \"\" is none of the forms eval/bsvs emits (7 to 40 lowercase hex digits, that with +dirty, or unknown)"), "{why}");
        let col = |c: &str| {
            std::fs::write(&f, format!("{{\"commit\": \"{c}\", \"id\": \"a\"}}\n")).unwrap()
        };
        for bad in ["", " ", "8e44 9b5", "spec@8e449b5"] {
            col(bad);
            for (record, dir) in [(true, out.as_str()), (false, "../corpus/witnesses")] {
                let why = stamp_refusal(p, record, dir, &root).expect(bad);
                assert!(
                    why.starts_with("refusing to write spec@")
                        && why.contains(&format!("; the commit stamp {bad:?} is none")),
                    "{why}"
                );
            }
            // off the corpus the lenient reader lets it pass, as it does +dirty and unknown (P6)
            assert_eq!(stamp_refusal(p, false, &out, &root), None, "{bad}");
        }
        // a missing column reads as unknown: the gate's report, not a file-read error (P5)
        let gone = d.join("no-such-spec.jsonl");
        let why = stamp_refusal(gone.to_str().unwrap(), true, &out, &root)
            .expect("a missing column is refused");
        assert!(
            why.starts_with("refusing to write spec@unknown into the corpus")
                && why.ends_with("(lean #32, B-4)"),
            "{why}"
        );
        // the accepted forms: a commit everywhere; +dirty and unknown off the corpus only, never with a form error
        col("8e449b5");
        assert_eq!(stamp_refusal(p, true, "../corpus/witnesses", &root), None);
        for c in ["8e449b5+dirty", "unknown"] {
            col(c);
            assert_eq!(stamp_refusal(p, false, &out, &root), None, "{c}");
            assert!(
                stamp_refusal(p, true, &out, &root).is_some_and(|w| w.ends_with("(lean #32, B-4)")),
                "{c}"
            );
            assert!(
                stamp_refusal(p, false, "../corpus/witnesses", &root).is_some(),
                "{c}"
            );
        }
        std::fs::remove_dir_all(&d).unwrap();
    }

    #[test]
    fn a_new_directory_under_corpus_counts() {
        let root = std::env::current_dir().unwrap().join("..");
        assert!(under_corpus("../corpus/witnesses", &root));
        assert!(under_corpus(
            "../corpus/a-directory-not-made-yet/sub",
            &root
        ));
        assert!(!under_corpus("/tmp/not-the-corpus", &root));
        // a `..` after a directory not made yet pops that directory (re-lens 3, B3N-5)
        assert!(under_corpus(
            "../harness/a-dir-not-made/../../corpus/witnesses",
            &root
        ));
        assert!(!under_corpus(
            "../corpus/a-dir-not-made/../../harness/x",
            &root
        ));
        let back = format!(
            "{}/harness/zz-not-made/../../corpus/witnesses",
            root.canonicalize().unwrap().display()
        );
        assert!(under_corpus(&back, &root), "{back}");
    }
}
