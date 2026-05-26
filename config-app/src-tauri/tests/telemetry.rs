use smoodle_config_lib::commands::telemetry::{
    telemetry_state_at, set_opt_in_at, forget_at, TelemetryState, ForgetRunner, ForgetError,
};
use std::fs;
use tempfile::tempdir;

// ---------------------------------------------------------------------------
// MockForgetRunner — returns canned responses without network
// ---------------------------------------------------------------------------

struct MockForgetRunner {
    result: Result<u64, ForgetError>,
}

impl MockForgetRunner {
    fn ok(n: u64) -> Self {
        Self { result: Ok(n) }
    }
}

impl ForgetRunner for MockForgetRunner {
    fn delete(
        &self,
        _url: &str,
        _install_id_hash: &str,
        _token: Option<&str>,
    ) -> Result<u64, ForgetError> {
        match &self.result {
            Ok(n) => Ok(*n),
            Err(e) => Err(match e {
                ForgetError::Network(s) => ForgetError::Network(s.clone()),
                ForgetError::BadResponse(s) => ForgetError::BadResponse(s.clone()),
                ForgetError::NoInstallId => ForgetError::NoInstallId,
            }),
        }
    }
}

// ---------------------------------------------------------------------------
// Test 1: state returns disabled when no files exist
// ---------------------------------------------------------------------------

#[test]
fn state_returns_disabled_when_no_files() {
    let dir = tempdir().unwrap();
    let state: TelemetryState = telemetry_state_at(dir.path()).unwrap();
    assert!(!state.enabled, "enabled should be false with no files");
    assert!(!state.has_install_id, "has_install_id should be false");
    assert!(!state.has_token, "has_token should be false");
}

// ---------------------------------------------------------------------------
// Test 2: state returns enabled when marker file is present
// ---------------------------------------------------------------------------

#[test]
fn state_returns_enabled_when_marker_present() {
    let dir = tempdir().unwrap();
    fs::write(dir.path().join("telemetry-on"), "").unwrap();
    let state: TelemetryState = telemetry_state_at(dir.path()).unwrap();
    assert!(state.enabled, "enabled should be true when telemetry-on exists");
    assert!(!state.has_install_id);
    assert!(!state.has_token);
}

// ---------------------------------------------------------------------------
// Test 3: set_opt_in(true) creates marker file and token file
// ---------------------------------------------------------------------------

#[test]
fn set_opt_in_true_creates_marker_and_token_file() {
    let dir = tempdir().unwrap();
    set_opt_in_at(dir.path(), true, Some("test-bearer-token")).unwrap();
    assert!(
        dir.path().join("telemetry-on").exists(),
        "telemetry-on marker should be created"
    );
    let token = fs::read_to_string(dir.path().join("forget_token")).unwrap();
    assert_eq!(token.trim(), "test-bearer-token");
}

// ---------------------------------------------------------------------------
// Test 4: set_opt_in(false) removes marker only; token file is preserved
// ---------------------------------------------------------------------------

#[test]
fn set_opt_in_false_removes_marker_only() {
    let dir = tempdir().unwrap();
    // Pre-condition: both marker and token exist
    fs::write(dir.path().join("telemetry-on"), "").unwrap();
    fs::write(dir.path().join("forget_token"), "my-secret-token").unwrap();

    set_opt_in_at(dir.path(), false, None).unwrap();

    assert!(
        !dir.path().join("telemetry-on").exists(),
        "telemetry-on marker should be removed on opt-out"
    );
    // Token survives so forget can still be called after opt-out
    assert!(
        dir.path().join("forget_token").exists(),
        "forget_token must be preserved (forget still works after opt-out)"
    );
    let token = fs::read_to_string(dir.path().join("forget_token")).unwrap();
    assert_eq!(token.trim(), "my-secret-token");
}

// ---------------------------------------------------------------------------
// Test 5: forget calls runner, returns count, and removes local files
// ---------------------------------------------------------------------------

#[test]
fn forget_calls_runner_and_removes_local_files() {
    let dir = tempdir().unwrap();
    // Pre-condition: all three local files exist
    fs::write(dir.path().join("install_id"), "abc123hash").unwrap();
    fs::write(dir.path().join("telemetry-on"), "").unwrap();
    fs::write(dir.path().join("forget_token"), "bearer-xyz").unwrap();

    let runner = MockForgetRunner::ok(42);
    let count = forget_at(dir.path(), &runner, "https://forget.example.com/api/forget").unwrap();

    assert_eq!(count, 42, "forget should return the server-reported deletion count");
    assert!(
        !dir.path().join("install_id").exists(),
        "install_id should be removed after forget"
    );
    assert!(
        !dir.path().join("telemetry-on").exists(),
        "telemetry-on should be removed after forget"
    );
    assert!(
        !dir.path().join("forget_token").exists(),
        "forget_token should be removed after forget"
    );
}
