use smoodle_config_lib::commands::status::{
    schema_compile_log_at, dict_counts_at,
};
use std::fs;
use tempfile::tempdir;

#[test]
fn schema_compile_log_returns_last_5_lines() {
    let dir = tempdir().unwrap();
    let log = dir.path().join("deploy.log");
    fs::write(&log, "[INFO] line1\n[INFO] line2\n[error] something broke\n[INFO] line4\n[INFO] line5\n[INFO] line6\n").unwrap();
    let result = schema_compile_log_at(&log).unwrap();
    let lines: Vec<&str> = result.lines().collect();
    assert_eq!(lines.len(), 5);
    assert_eq!(lines[0], "[INFO] line2");
}

#[test]
fn schema_compile_log_returns_helpful_msg_when_missing() {
    let dir = tempdir().unwrap();
    let log = dir.path().join("missing.log");
    let result = schema_compile_log_at(&log).unwrap();
    assert!(result.contains("not yet"));
}

#[test]
fn dict_counts_reads_base_and_user() {
    let dir = tempdir().unwrap();
    let base = dir.path().join("base.dict.yaml");
    let user = dir.path().join("user.dict.yaml");
    // base: a yaml with 3 word entries after the ... marker
    fs::write(&base, "---\nname: x\n...\nword1\trom1\t100\nword2\trom2\t200\nword3\trom3\t300\n").unwrap();
    fs::write(&user, "---\nname: y\n...\nuw1\turom1\t100\n").unwrap();
    let counts = dict_counts_at(&base, &user).unwrap();
    assert_eq!(counts.base, 3);
    assert_eq!(counts.user, 1);
    assert_eq!(counts.total, 4);
}
