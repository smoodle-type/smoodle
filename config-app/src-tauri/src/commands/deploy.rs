//! Apple Event "Deploy" shim — tells Smoodle.app to rebuild Rime data.
//!
//! NOTE: deploy_squirrel is NOT yet wired into Tauri invoke_handler —
//! that happens in Task 8.

use std::process::Command;

#[derive(Debug, thiserror::Error)]
pub enum DeployError {
    #[error("Smoodle.app not running or Apple Event failed: {0}")]
    AppleEvent(String),
}

pub trait DeployRunner {
    fn run(&self) -> Result<String, DeployError>;
}

pub struct OsaScriptRunner;

impl DeployRunner for OsaScriptRunner {
    fn run(&self) -> Result<String, DeployError> {
        let output = Command::new("osascript")
            .arg("-e")
            .arg(r#"tell application "Smoodle" to «event RimeRdpl»"#)
            .output()
            .map_err(|e| DeployError::AppleEvent(format!("spawn: {}", e)))?;
        if !output.status.success() {
            let stderr = String::from_utf8_lossy(&output.stderr).to_string();
            return Err(DeployError::AppleEvent(stderr));
        }
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
