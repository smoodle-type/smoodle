//! YAML read/write helpers with atomic write + on-failure backup.
//!
//! # Safety note
//! Caller is responsible for confining `path` to an allowed directory tree — these
//! helpers do not enforce path-traversal protection. Tauri command wrappers in
//! `commands/` MUST validate before calling.

use std::fs;
use std::io::Write;
use std::path::Path;

#[derive(Debug, thiserror::Error)]
pub enum YamlError {
    #[error("io error: {0}")]
    Io(#[from] std::io::Error),
    #[error("yaml parse error: {0}")]
    Parse(#[from] serde_yaml::Error),
}

pub type Result<T> = std::result::Result<T, YamlError>;

/// Write `content` to `path` atomically: write to `<path>.tmp`, fsync, then rename.
/// On rename failure, removes the .tmp file so no orphan remains. On rename failure,
/// the temp file is removed via `NamedTempFile`'s `Drop` impl when the returned
/// `PersistError` is dropped.
pub fn atomic_write_str(path: &Path, content: &str) -> Result<()> {
    let parent = path.parent().ok_or_else(|| {
        std::io::Error::new(std::io::ErrorKind::InvalidInput, "path has no parent")
    })?;
    // Use NamedTempFile so the temp lives in the same dir (atomic rename requires same fs)
    let mut tmp = tempfile::NamedTempFile::new_in(parent)?;
    tmp.write_all(content.as_bytes())?;
    tmp.as_file().sync_all()?;
    // Persist replaces the target atomically on POSIX.
    // On persist() failure: e.file (NamedTempFile) is dropped via map_err's
    // move-into-closure, deleting the .tmp via NamedTempFile's Drop impl.
    tmp.persist(path).map_err(|e| e.error)?;
    Ok(())
}

/// Read `path` into `T`. Returns `YamlError::Io` if missing, `YamlError::Parse` if not valid YAML for `T`.
pub fn read<T: serde::de::DeserializeOwned>(path: &Path) -> Result<T> {
    let content = fs::read_to_string(path)?;
    let value = serde_yaml::from_str(&content)?;
    Ok(value)
}

/// Backup an existing file to `<full-filename>.bak.<ISO>`. Returns `Ok(None)` if
/// `path` does not exist (no-op, not an error).
pub fn backup(path: &Path) -> Result<Option<std::path::PathBuf>> {
    if !path.exists() {
        return Ok(None);
    }
    let ts = chrono::Utc::now().format("%Y%m%dT%H%M%SZ").to_string();
    let fname = path
        .file_name()
        .and_then(|s| s.to_str())
        .ok_or_else(|| {
            std::io::Error::new(std::io::ErrorKind::InvalidInput, "path has no filename")
        })?;
    let bak = path.with_file_name(format!("{}.bak.{}", fname, ts));
    fs::copy(path, &bak)?;
    Ok(Some(bak))
}
