//! Telemetry tab: read state, set opt-in, and forget (purge server + local files).
//!
//! Mirrors the semantics of `scripts/lib/telemetry-forget.sh` and
//! `scripts/lib/telemetry.sh`.
//!
//! State files live in `~/.smoodle/`:
//!   - `install_id`    — opaque SHA256 hash; present iff opted-in at least once
//!   - `telemetry-on`  — empty marker file; present iff currently opted-in
//!   - `forget_token`  — bearer token (single line); present iff token was saved
//!
//! NOTE: Commands are NOT yet wired into the Tauri `invoke_handler` —
//! that happens in Task 8 (`commands::register_all(lib.rs)`).

use std::fs;
use std::path::{Path, PathBuf};

// ---------------------------------------------------------------------------
// Error type
// ---------------------------------------------------------------------------

#[derive(Debug, thiserror::Error)]
pub enum ForgetError {
    #[error("network error: {0}")]
    Network(String),

    #[error("bad response from forget API: {0}")]
    BadResponse(String),

    #[error("no install_id file — nothing to forget")]
    NoInstallId,
}

// ---------------------------------------------------------------------------
// ForgetRunner trait + production impl
// ---------------------------------------------------------------------------

pub trait ForgetRunner {
    fn delete(
        &self,
        url: &str,
        install_id_hash: &str,
        token: Option<&str>,
    ) -> Result<u64, ForgetError>;
}

pub struct ReqwestRunner;

impl ForgetRunner for ReqwestRunner {
    fn delete(
        &self,
        url: &str,
        install_id_hash: &str,
        token: Option<&str>,
    ) -> Result<u64, ForgetError> {
        let client = reqwest::blocking::Client::new();
        let mut req = client
            .delete(url)
            .query(&[("install_id_hash", install_id_hash)]);
        if let Some(t) = token {
            req = req.bearer_auth(t);
        }
        let resp = req.send().map_err(|e| ForgetError::Network(e.to_string()))?;
        if !resp.status().is_success() {
            return Err(ForgetError::BadResponse(format!(
                "HTTP {}",
                resp.status()
            )));
        }
        let body: serde_json::Value = resp
            .json()
            .map_err(|e| ForgetError::BadResponse(e.to_string()))?;
        let deleted = body
            .get("deleted")
            .and_then(|v| v.as_u64())
            .ok_or_else(|| {
                ForgetError::BadResponse(format!("missing 'deleted' key in: {body}"))
            })?;
        Ok(deleted)
    }
}

// ---------------------------------------------------------------------------
// Public surface
// ---------------------------------------------------------------------------

#[derive(serde::Serialize, Debug, PartialEq)]
pub struct TelemetryState {
    pub enabled: bool,
    pub has_install_id: bool,
    pub has_token: bool,
}

// ---------------------------------------------------------------------------
// smoodle_dir helper — mirrors rime_dir() pattern from settings.rs
// ---------------------------------------------------------------------------

fn smoodle_dir() -> Result<PathBuf, String> {
    dirs::home_dir()
        .map(|h| h.join(".smoodle"))
        .ok_or_else(|| "$HOME not set — cannot resolve ~/.smoodle directory".to_string())
}

// ---------------------------------------------------------------------------
// Tauri commands (thin adapters over testable helpers)
// ---------------------------------------------------------------------------

#[tauri::command]
pub fn telemetry_state() -> Result<TelemetryState, String> {
    telemetry_state_at(&smoodle_dir()?)
}

#[tauri::command]
pub fn telemetry_set_opt_in(enabled: bool, token: Option<String>) -> Result<(), String> {
    set_opt_in_at(&smoodle_dir()?, enabled, token.as_deref())
}

#[tauri::command]
pub fn telemetry_forget() -> Result<u64, String> {
    let url = std::env::var("SMOODLE_FORGET_URL")
        .unwrap_or_else(|_| "https://forget.0dl.me/api/forget".to_string());
    forget_at(&smoodle_dir()?, &ReqwestRunner, &url)
}

// ---------------------------------------------------------------------------
// Testable inner helpers
// ---------------------------------------------------------------------------

/// Read telemetry state from an explicit smoodle_dir path.
pub fn telemetry_state_at(smoodle_dir: &Path) -> Result<TelemetryState, String> {
    let enabled = smoodle_dir.join("telemetry-on").exists();
    let has_install_id = smoodle_dir.join("install_id").exists();
    // Token source: env var wins, then file
    let has_token = std::env::var("SMOODLE_FORGET_TOKEN").is_ok()
        || smoodle_dir.join("forget_token").exists();
    Ok(TelemetryState {
        enabled,
        has_install_id,
        has_token,
    })
}

/// Set or clear opt-in. Optionally write a bearer token file.
///
/// `set_opt_in_at(dir, false, _)` removes the `telemetry-on` marker but
/// intentionally leaves `forget_token` intact so that `telemetry_forget()`
/// can still authenticate a purge after the user opts out.
pub fn set_opt_in_at(
    smoodle_dir: &Path,
    enabled: bool,
    token: Option<&str>,
) -> Result<(), String> {
    fs::create_dir_all(smoodle_dir).map_err(|e| e.to_string())?;
    let marker = smoodle_dir.join("telemetry-on");
    let token_file = smoodle_dir.join("forget_token");

    if enabled {
        // Touch the marker file (empty)
        fs::write(&marker, b"").map_err(|e| e.to_string())?;
        // Persist bearer token if provided
        if let Some(t) = token {
            fs::write(&token_file, t).map_err(|e| e.to_string())?;
        }
    } else {
        // Remove the opt-in marker; leave the token so forget still works
        if marker.exists() {
            fs::remove_file(&marker).map_err(|e| e.to_string())?;
        }
    }
    Ok(())
}

/// Call the forget API and remove all local telemetry files on success.
///
/// Returns the number of server-side events deleted.
/// Returns `Err` (without touching local files) on network / API failure.
pub fn forget_at(
    smoodle_dir: &Path,
    runner: &dyn ForgetRunner,
    url: &str,
) -> Result<u64, String> {
    let install_id_file = smoodle_dir.join("install_id");

    // Read install_id; if absent there is nothing to purge.
    let install_id_hash = if install_id_file.exists() {
        fs::read_to_string(&install_id_file).map_err(|e| e.to_string())?
    } else {
        return Err(ForgetError::NoInstallId.to_string());
    };
    let install_id_hash = install_id_hash.trim();

    // Resolve token: env var wins, then file
    let token_file = smoodle_dir.join("forget_token");
    let token_from_env = std::env::var("SMOODLE_FORGET_TOKEN").ok();
    let token_from_file = if token_file.exists() {
        fs::read_to_string(&token_file).ok()
    } else {
        None
    };
    let token: Option<String> = token_from_env.or(token_from_file);
    let token_ref = token.as_deref().map(str::trim);

    // Hit the API
    let deleted = runner
        .delete(url, install_id_hash, token_ref)
        .map_err(|e| e.to_string())?;

    // Remove all three local telemetry files
    for path in &[
        smoodle_dir.join("install_id"),
        smoodle_dir.join("telemetry-on"),
        smoodle_dir.join("forget_token"),
    ] {
        if path.exists() {
            fs::remove_file(path).map_err(|e| e.to_string())?;
        }
    }

    Ok(deleted)
}
