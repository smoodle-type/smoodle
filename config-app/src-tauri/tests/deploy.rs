use smoodle_config_lib::commands::deploy::{deploy_with, DeployRunner, DeployError};

struct MockRunner {
    should_succeed: bool,
}

impl DeployRunner for MockRunner {
    fn run(&self) -> Result<String, DeployError> {
        if self.should_succeed {
            Ok("Deploy OK".to_string())
        } else {
            Err(DeployError::AppleEvent("Smoodle.app not running".to_string()))
        }
    }
}

#[test]
fn deploy_succeeds_with_mock() {
    let result = deploy_with(&MockRunner { should_succeed: true });
    assert!(result.is_ok());
}

#[test]
fn deploy_fails_with_mock() {
    let result = deploy_with(&MockRunner { should_succeed: false });
    assert!(matches!(result, Err(DeployError::AppleEvent(_))));
}
