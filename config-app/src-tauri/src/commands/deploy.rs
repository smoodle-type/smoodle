//! Apple Event "Deploy" shim — tells Smoodle.app to rebuild Rime data.

use std::process::Command;

#[derive(Debug, thiserror::Error)]
pub enum DeployError {
    #[error("Smoodle.app not running or Apple Event failed: {0}")]
    AppleEvent(String),
}

pub trait DeployRunner {
    /// Fires the Rime "Deploy" Apple Event. Ok(stdout) on success, Err(...) on non-zero exit or spawn failure.
    fn run(&self) -> Result<String, DeployError>;
}

pub struct OsaScriptRunner;

impl DeployRunner for OsaScriptRunner {
    fn run(&self) -> Result<String, DeployError> {
        let output = Command::new("/usr/bin/osascript")
            .arg("-e")
            // Apple Event class 'Rime', ID 'Rdpl' — handled by Smoodle.app (wired in Task 16, smoodle-app menubar).
            .arg(r#"tell application "Smoodle" to «event RimeRdpl»"#)
            .output()
            .map_err(|e| DeployError::AppleEvent(format!("spawn: {}", e)))?;
        // TODO(v0.0.9): wrap spawn in a timeout. osascript's default 60s Apple Event timeout is the current ceiling.
        // KNOWN: osascript can exit 0 with "error" on stdout when the receiver app is running
        // but the event handler is missing (rare; Ventura+ behavior). status check covers
        // receiver-not-running and most failure modes — the rest surface via stderr.
        if !output.status.success() {
            let stderr = String::from_utf8_lossy(&output.stderr).to_string();
            return Err(DeployError::AppleEvent(stderr));
        }
        // osascript output on macOS is always UTF-8. from_utf8_lossy is defensive only.
        Ok(String::from_utf8_lossy(&output.stdout).to_string())
    }
}

pub fn deploy_with(runner: &dyn DeployRunner) -> Result<String, DeployError> {
    runner.run()
}

#[tauri::command]
pub fn deploy_squirrel() -> Result<String, String> {
    deploy_with(&OsaScriptRunner).map_err(|e| e.to_string())
}
