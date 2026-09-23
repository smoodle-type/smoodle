use smoodle_config_lib::commands::deploy::{deploy_with, BuildStamp, DeployError, DeployRunner};
use std::cell::Cell;
use std::time::{Duration, SystemTime, UNIX_EPOCH};

fn now_secs() -> i64 {
    SystemTime::now().duration_since(UNIX_EPOCH).unwrap().as_secs() as i64
}

/// Fake Smoodle.app. After a reload request, the deploy "finishes" once
/// `finishes_after` build_stamp polls have passed (never, if None).
struct FakeSmoodle {
    running: bool,
    initial: Option<BuildStamp>,
    finishes_after: Option<u32>,
    requested: Cell<bool>,
    polls: Cell<u32>,
}

impl FakeSmoodle {
    fn new(running: bool, initial: Option<BuildStamp>, finishes_after: Option<u32>) -> Self {
        Self { running, initial, finishes_after, requested: Cell::new(false), polls: Cell::new(0) }
    }
}

impl DeployRunner for FakeSmoodle {
    fn is_running(&self) -> bool {
        self.running
    }
    fn request_reload(&self) -> Result<(), DeployError> {
        self.requested.set(true);
        Ok(())
    }
    fn build_stamp(&self) -> Option<BuildStamp> {
        if self.requested.get() {
            self.polls.set(self.polls.get() + 1);
            if matches!(self.finishes_after, Some(n) if self.polls.get() > n) {
                return Some(BuildStamp { modified: SystemTime::now(), last_build_time: now_secs() });
            }
        }
        self.initial
    }
}

const FAST: Duration = Duration::from_millis(1);

#[test]
fn not_running_fails_without_requesting_a_reload() {
    let smoodle = FakeSmoodle::new(false, None, Some(0));
    let result = deploy_with(&smoodle, Duration::from_secs(1), FAST);
    assert!(matches!(result, Err(DeployError::NotRunning)));
    assert!(!smoodle.requested.get());
}

#[test]
fn waits_until_rime_reports_a_deploy_after_the_request() {
    let old = BuildStamp { modified: UNIX_EPOCH, last_build_time: 1_778_222_277 };
    let smoodle = FakeSmoodle::new(true, Some(old), Some(3));
    let result = deploy_with(&smoodle, Duration::from_secs(5), FAST);
    assert!(result.is_ok(), "got {result:?}");
    assert!(smoodle.polls.get() > 3, "returned before the deploy finished");
}

#[test]
fn first_deploy_ever_counts_as_completion() {
    let smoodle = FakeSmoodle::new(true, None, Some(0));
    assert!(deploy_with(&smoodle, Duration::from_secs(5), FAST).is_ok());
}

#[test]
fn times_out_when_no_deploy_finishes() {
    let old = BuildStamp { modified: UNIX_EPOCH, last_build_time: 1_778_222_277 };
    let smoodle = FakeSmoodle::new(true, Some(old), None);
    let result = deploy_with(&smoodle, Duration::from_millis(50), FAST);
    assert!(matches!(result, Err(DeployError::Timeout(_))), "got {result:?}");
}

#[test]
fn deploy_finished_in_the_same_second_before_the_request_is_not_completion() {
    // A deploy that finished moments before this request (same wall-clock
    // second) must not satisfy the wait: only a new user.yaml write does.
    let just_before = BuildStamp { modified: SystemTime::now(), last_build_time: now_secs() };
    let smoodle = FakeSmoodle::new(true, Some(just_before), None);
    let result = deploy_with(&smoodle, Duration::from_millis(50), FAST);
    assert!(matches!(result, Err(DeployError::Timeout(_))), "got {result:?}");
}
