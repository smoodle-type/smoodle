//! Deploy: ask the running Smoodle.app to rebuild its Rime data and wait until
//! the rebuild has finished.
//!
//! `Smoodle --reload` posts the `SquirrelReloadNotification` distributed
//! notification that every Smoodle build observes (SquirrelApplicationDelegate
//! `addObservers`). Unlike an Apple Event it needs no Automation consent, so it
//! cannot stall behind a privacy prompt. Rime rewrites user.yaml with
//! `var/last_build_time` when a deploy finishes; that is the completion signal.

use std::path::PathBuf;
use std::process::Command;
use std::time::{Duration, Instant, SystemTime, UNIX_EPOCH};
use crate::commands::status;
use crate::paths;

const DEPLOY_TIMEOUT: Duration = Duration::from_secs(30);
const POLL_INTERVAL: Duration = Duration::from_millis(100);
/// `Smoodle --reload` only posts a notification, so it should exit at once.
const RELOAD_EXIT_TIMEOUT: Duration = Duration::from_secs(10);

#[derive(Debug, thiserror::Error)]
pub enum DeployError {
    #[error("Smoodle isn't running — switch to Smoodle once; it loads your changes when it starts")]
    NotRunning,
    #[error("couldn't ask Smoodle to deploy: {0}")]
    Request(String),
    #[error("Smoodle didn't finish deploying within {0}s")]
    Timeout(u64),
}

/// Identifies one finished deploy: when user.yaml was written, and the
/// `var/last_build_time` Rime stored in it.
#[derive(Debug, Clone, Copy, PartialEq)]
pub struct BuildStamp {
    pub modified: SystemTime,
    pub last_build_time: i64,
}

pub trait DeployRunner {
    fn is_running(&self) -> bool;
    /// Ask Smoodle.app to redeploy. Returns once the request has been posted.
    fn request_reload(&self) -> Result<(), DeployError>;
    /// The latest finished deploy, or None if Rime has never deployed.
    fn build_stamp(&self) -> Option<BuildStamp>;
}

pub struct SmoodleRunner {
    user_yaml: PathBuf,
}

impl SmoodleRunner {
    pub fn new() -> Result<Self, String> {
        Ok(Self { user_yaml: paths::rime_user_dir()?.join("user.yaml") })
    }
}

impl DeployRunner for SmoodleRunner {
    fn is_running(&self) -> bool {
        status::is_smoodle_running()
    }

    fn request_reload(&self) -> Result<(), DeployError> {
        let mut child = Command::new(paths::smoodle_executable())
            .arg("--reload")
            .spawn()
            .map_err(|e| DeployError::Request(e.to_string()))?;
        let started = Instant::now();
        loop {
            match child.try_wait() {
                Ok(Some(exit)) if exit.success() => return Ok(()),
                Ok(Some(exit)) => {
                    return Err(DeployError::Request(format!("Smoodle --reload exited with {}", exit)))
                }
                Ok(None) if started.elapsed() < RELOAD_EXIT_TIMEOUT => std::thread::sleep(POLL_INTERVAL),
                Ok(None) => {
                    let _ = child.kill();
                    let _ = child.wait();
                    return Err(DeployError::Request("Smoodle --reload did not exit".into()));
                }
                Err(e) => return Err(DeployError::Request(e.to_string())),
            }
        }
    }

    fn build_stamp(&self) -> Option<BuildStamp> {
        let modified = std::fs::metadata(&self.user_yaml).ok()?.modified().ok()?;
        let last_build_time = status::last_build_time(&self.user_yaml)?;
        Some(BuildStamp { modified, last_build_time })
    }
}

/// Request a deploy and block until Rime reports one that finished after the
/// request. A stamp counts only if it differs from the one seen before the
/// request and its `last_build_time` is not older than the request, so an
/// earlier deploy finishing in the same second is not mistaken for this one.
pub fn deploy_with(
    runner: &dyn DeployRunner,
    timeout: Duration,
    poll: Duration,
) -> Result<Duration, DeployError> {
    if !runner.is_running() {
        return Err(DeployError::NotRunning);
    }
    let before = runner.build_stamp();
    let requested_at = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|d| d.as_secs() as i64)
        .unwrap_or(0);
    let started = Instant::now();
    runner.request_reload()?;
    loop {
        if let Some(stamp) = runner.build_stamp() {
            if Some(stamp) != before && stamp.last_build_time >= requested_at {
                return Ok(started.elapsed());
            }
        }
        if started.elapsed() >= timeout {
            return Err(DeployError::Timeout(timeout.as_secs()));
        }
        std::thread::sleep(poll);
    }
}

/// Runs off the main thread (`async`): a deploy takes seconds and must not
/// freeze the window.
#[tauri::command(async)]
pub fn deploy_squirrel() -> Result<String, String> {
    let runner = SmoodleRunner::new()?;
    deploy_with(&runner, DEPLOY_TIMEOUT, POLL_INTERVAL)
        .map(|took| format!("deployed in {:.1}s", took.as_secs_f64()))
        .map_err(|e| e.to_string())
}
