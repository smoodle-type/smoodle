//! Status tab queries.
//!
//! - smoodle_running       → Status tab "Running" indicator + version badge
//! - schema_compile_log    → Status tab deploy report (last deploy + log lines)
//! - dict_counts           → Status tab "Entries" row (base + user + total)

use std::collections::BTreeSet;
use std::fs;
use std::path::Path;
use std::process::Command;
use crate::paths;

/// Deploy-related Rime log lines shown under "Last deploy".
const LOG_LINES: usize = 5;

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

/// Extract CFBundleShortVersionString from a plist via `/usr/bin/plutil`.
fn plutil_version(plist: &Path) -> Result<String, String> {
    let output = Command::new("/usr/bin/plutil")
        .args(["-extract", "CFBundleShortVersionString", "raw"])
        .arg(plist)
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

/// Is a process named exactly `Smoodle` running? (`pgrep -x` so
/// "Smoodle Config" does not count.)
pub fn is_smoodle_running() -> bool {
    Command::new("/usr/bin/pgrep")
        .arg("-x")
        .arg("Smoodle")
        .output()
        .map(|o| o.status.success())
        .unwrap_or(false)
}

/// Query whether Smoodle.app is running and, if so, its version string.
#[tauri::command]
pub fn smoodle_running() -> Result<SmoodleStatus, String> {
    let running = is_smoodle_running();
    // Known TOCTOU: if Smoodle.app quits between pgrep and plutil, this returns
    // SmoodleStatus { running: true, version: None }. Bounded, non-crashing —
    // acceptable for v0.0.8b dogfood. v0.0.9 async refactor candidate.
    let version = if running {
        plutil_version(&paths::info_plist()).ok()
    } else {
        None
    };
    Ok(SmoodleStatus { running, version })
}

/// When Rime last finished a deploy, and the deploy lines of Smoodle's log.
#[tauri::command]
pub fn schema_compile_log() -> Result<String, String> {
    let user_yaml = paths::rime_user_dir()?.join("user.yaml");
    Ok(compile_report(&user_yaml, &paths::rime_log_dir()))
}

/// Testable inner helper for `schema_compile_log`: the last deploy time from
/// user.yaml, then the last deploy-related lines of Smoodle's Rime log.
/// glog buffers `rime.squirrel.INFO` — even warnings and errors reach it only
/// on its next flush — but flushes `rime.squirrel.WARNING` (warnings and
/// errors) line by line, so both files are merged by timestamp.
pub fn compile_report(user_yaml: &Path, log_dir: &Path) -> String {
    let mut out = match last_build_time(user_yaml).and_then(format_local) {
        Some(when) => format!("Last deploy: {}", when),
        None => "Last deploy: never".to_string(),
    };
    let mut entries = BTreeSet::new();
    let mut found_log = false;
    for name in ["rime.squirrel.INFO", "rime.squirrel.WARNING"] {
        if let Ok(content) = fs::read_to_string(log_dir.join(name)) {
            found_log = true;
            entries.extend(content.lines().filter_map(deploy_line));
        }
    }
    if !found_log {
        out.push_str("\nNo Rime log yet — Smoodle writes one once it starts.");
        return out;
    }
    let lines: Vec<(String, String)> = entries.into_iter().collect();
    for (_, text) in &lines[lines.len().saturating_sub(LOG_LINES)..] {
        out.push('\n');
        out.push_str(text);
    }
    out
}

/// `var/last_build_time` from Rime's user.yaml: seconds since the epoch at
/// which the last deploy finished. None if Rime has never deployed.
pub fn last_build_time(user_yaml: &Path) -> Option<i64> {
    let content = fs::read_to_string(user_yaml).ok()?;
    let v: serde_yaml::Value = serde_yaml::from_str(&content).ok()?;
    v.get("var")?.get("last_build_time")?.as_i64()
}

fn format_local(epoch_secs: i64) -> Option<String> {
    let utc = chrono::DateTime::from_timestamp(epoch_secs, 0)?;
    Some(utc.with_timezone(&chrono::Local).format("%Y-%m-%d %H:%M:%S").to_string())
}

/// A glog line from a deploy task, or any warning/error, as
/// (sortable `yyyymmdd hh:mm:ss.uuuuuu`, display `HH:MM:SS <severity> <message>`).
/// Engine start/stop and config loads are dropped.
/// Input: `I20260923 13:31:42.310823 0x1f1356180 deployment_tasks.cc:83] msg`
fn deploy_line(line: &str) -> Option<(String, String)> {
    let severity = line.chars().next()?;
    if !matches!(severity, 'I' | 'W' | 'E' | 'F') {
        return None;
    }
    let mut fields = line.splitn(5, ' ');
    let date = fields.next()?.get(1..)?;
    let time = fields.next()?;
    let _thread = fields.next()?;
    let source = fields.next()?;
    let message = fields.next()?;
    let from_deploy = ["deployment_tasks.cc:", "dict_compiler.cc:", "deployer.cc:"]
        .iter()
        .any(|s| source.starts_with(s));
    if severity == 'I' && !from_deploy {
        return None;
    }
    Some((format!("{} {}", date, time), format!("{} {} {}", time.get(..8)?, severity, message)))
}

/// Return entry counts for the base dict, user dict, and their sum — the
/// files Rime actually compiles (user-dir copy first, else the bundled one).
#[tauri::command]
pub fn dict_counts() -> Result<DictCounts, String> {
    let user = paths::rime_user_dir()?;
    let shared = paths::shared_data_dir();
    dict_counts_at(
        &paths::resolve(&user, &shared, paths::BASE_DICT_FILE),
        &paths::resolve(&user, &shared, paths::USER_DICT_FILE),
    )
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
