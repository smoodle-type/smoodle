//! Status tab queries.
//!
//! - smoodle_running       → Status tab "Running" indicator + version badge
//! - schema_compile_log    → Status tab "Compile log" textarea (last 5 lines)
//! - dict_counts           → Status tab "Entries" row (base + user + total)
//!
//! NOTE: commands not yet wired into Tauri invoke_handler — Task 8.

use std::fs;
use std::path::{Path, PathBuf};
use std::process::Command;

const SMOODLE_PLIST: &str =
    "/Library/Input Methods/Smoodle.app/Contents/Info.plist";

#[derive(serde::Serialize)]
pub struct SmoodleStatus {
    pub running: bool,
    pub version: Option<String>,
}

#[derive(serde::Serialize)]
pub struct DictCounts {
    pub base: usize,
    pub user: usize,
    pub total: usize,
}

/// Returns `~/Library/Rime` as a `PathBuf`, or a descriptive error string.
fn rime_dir() -> Result<PathBuf, String> {
    dirs::home_dir()
        .map(|h| h.join("Library/Rime"))
        .ok_or_else(|| "$HOME not set — cannot resolve Rime directory".to_string())
}

/// Extract CFBundleShortVersionString from a plist via `/usr/bin/plutil`.
fn plutil_version(plist: &str) -> Result<String, String> {
    let output = Command::new("/usr/bin/plutil")
        .args(["-extract", "CFBundleShortVersionString", "raw", plist])
        .output()
        .map_err(|e| e.to_string())?;
    if !output.status.success() {
        return Err(format!(
            "plutil failed (exit {}): {}",
            output.status,
            String::from_utf8_lossy(&output.stderr).trim()
        ));
    }
    Ok(String::from_utf8_lossy(&output.stdout).trim().to_string())
}

/// Query whether Smoodle.app is running and, if so, its version string.
#[tauri::command]
pub fn smoodle_running() -> Result<SmoodleStatus, String> {
    // pgrep -x: exact-match process name; -x avoids matching processes like "SmoodleConfig"
    let running = Command::new("/usr/bin/pgrep")
        .arg("-x")
        .arg("Smoodle")
        .output()
        .map(|o| o.status.success())
        .unwrap_or(false);
    // Known TOCTOU: if Smoodle.app quits between pgrep and plutil, this returns
    // SmoodleStatus { running: true, version: None }. Bounded, non-crashing —
    // acceptable for v0.0.8b dogfood. v0.0.9 async refactor candidate.
    let version = if running {
        plutil_version(SMOODLE_PLIST).ok()
    } else {
        None
    };
    Ok(SmoodleStatus { running, version })
}

/// Return last 5 lines of the Rime deploy log (`~/Library/Rime/build/deploy.log`).
#[tauri::command]
pub fn schema_compile_log() -> Result<String, String> {
    let path = rime_dir()?.join("build/deploy.log");
    schema_compile_log_at(&path)
}

/// Testable inner helper — reads the log at `path` and returns last 5 lines.
pub fn schema_compile_log_at(path: &Path) -> Result<String, String> {
    if !path.exists() {
        return Ok("Deploy log not yet present — run Smoodle.app menubar → Deploy first.".into());
    }
    let content = fs::read_to_string(path).map_err(|e| e.to_string())?;
    let lines: Vec<&str> = content.lines().collect();
    let start = lines.len().saturating_sub(5);
    Ok(lines[start..]
        .iter()
        .filter(|l| !l.trim().is_empty())
        .copied()
        .collect::<Vec<_>>()
        .join("\n"))
}

/// Return entry counts for the base dict, user dict, and their sum.
#[tauri::command]
pub fn dict_counts() -> Result<DictCounts, String> {
    let rime = rime_dir()?;
    let base = rime.join("thai_phonetic.dict.yaml");
    let user = rime.join("thai_phonetic.user.dict.yaml");
    dict_counts_at(&base, &user)
}

/// Testable inner helper — counts tab-separated entries after the `...` separator
/// in each dict file. Missing files contribute 0 (not an error).
pub fn dict_counts_at(base: &Path, user: &Path) -> Result<DictCounts, String> {
    let count = |p: &Path| -> usize {
        let Ok(s) = fs::read_to_string(p) else { return 0; };
        let mut n = 0usize;
        let mut after = false;
        for line in s.lines() {
            if line.trim() == "..." { after = true; continue; }
            if !after { continue; }
            if line.starts_with('#') || line.trim().is_empty() { continue; }
            if line.splitn(3, '\t').count() == 3 { n += 1; }
        }
        n
    };
    let b = count(base);
    let u = count(user);
    Ok(DictCounts { base: b, user: u, total: b + u })
}
