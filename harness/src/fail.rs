//! fail: the error road of the node drivers and the record writers (#132, 2026-10-14, lane gate-132). The lint table of
//! harness/Cargo.toml denies `unwrap`, `expect` and `panic`; where one of those stood, `or_err("what")?` carries the same
//! words into an `Err(String)` that the caller reports and turns into an exit code, never an unwinding panic.
use std::fmt::Display;

pub trait OrErr<T> {
    /// `Ok` unchanged; an `Err` (or a `None`) becomes `Err("<what>: <the error>")`.
    fn or_err(self, what: &str) -> Result<T, String>;
}

impl<T, E: Display> OrErr<T> for Result<T, E> {
    fn or_err(self, what: &str) -> Result<T, String> {
        self.map_err(|e| format!("{what}: {e}"))
    }
}

impl<T> OrErr<T> for Option<T> {
    fn or_err(self, what: &str) -> Result<T, String> {
        self.ok_or_else(|| format!("{what}: absent"))
    }
}

#[cfg(test)]
mod tests {
    use super::OrErr;

    #[test]
    fn or_err_names_what_failed() {
        assert_eq!(Ok::<u8, String>(1).or_err("x"), Ok(1));
        assert_eq!(
            Err::<u8, &str>("boom").or_err("getblockcount"),
            Err("getblockcount: boom".to_string())
        );
        assert_eq!(
            None::<u8>.or_err("tip hash"),
            Err("tip hash: absent".to_string())
        );
    }
}
