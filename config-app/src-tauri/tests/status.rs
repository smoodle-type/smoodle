use smoodle_config_lib::commands::status::{compile_report, dict_counts_at, last_build_time};
use std::fs;
use tempfile::tempdir;

const LOG: &str = "\
Log file created at: 2026/09/23 13:31:42
Log line format: [IWEF]yyyymmdd hh:mm:ss.uuuuuu threadid file:line] msg
I20260923 13:31:42.310612 0x1f1356180 registry.cc:14] registering component: cleanup_trash
I20260923 13:31:42.310823 0x1f1356180 deployment_tasks.cc:83] updating rime installation info.
I20260923 13:31:42.311521 0x1f1356180 deployer.cc:119] starting work thread for 3 tasks.
I20260923 13:31:42.313243 0x16d547000 deployment_tasks.cc:167] updating workspace.
E20260923 13:31:42.318101 0x16d547000 deployment_tasks.cc:212] missing input schema: luna_pinyin
I20260923 13:31:42.412000 0x16d547000 dict_compiler.cc:126] thai_phonetic.extended.dict.yaml[3 file(s)] (123)
I20260923 13:31:42.520000 0x16d547000 deployment_tasks.cc:247] finished updating schemas: 1 success, 1 failure.
I20260923 13:31:43.100000 0x1f1356180 engine.cc:72] starting engine.
";

#[test]
fn compile_report_shows_last_deploy_and_only_deploy_lines() {
    let dir = tempdir().unwrap();
    let user_yaml = dir.path().join("user.yaml");
    fs::write(dir.path().join("rime.squirrel.INFO"), LOG).unwrap();
    fs::write(&user_yaml, "var:\n  last_build_time: 1790145102\n").unwrap();

    let report = compile_report(&user_yaml, dir.path());
    let lines: Vec<&str> = report.lines().collect();

    assert!(lines[0].starts_with("Last deploy: ") && !lines[0].contains("never"), "{report}");
    assert_eq!(lines.len(), 6, "header + last 5 deploy lines:\n{report}");
    assert_eq!(lines[5], "13:31:42 I finished updating schemas: 1 success, 1 failure.");
    assert!(report.contains("13:31:42 E missing input schema: luna_pinyin"), "{report}");
    assert!(!report.contains("starting engine"), "engine noise leaked:\n{report}");
    assert!(!report.contains("registering component"), "noise leaked:\n{report}");
}

#[test]
fn errors_show_before_glog_flushes_the_info_log() {
    // glog buffers rime.squirrel.INFO (even error lines) but flushes
    // rime.squirrel.WARNING per line; right after a failed deploy only the
    // latter has the error. Once INFO catches up, the line must not repeat.
    let dir = tempdir().unwrap();
    let info = "I20260923 13:59:08.900000 0x1 deployment_tasks.cc:167] updating workspace.\n";
    let warning = "\
W20260923 13:59:09.026540 0x16d5ff000 config_data.cc:70] nonexistent config file 'build/luna_pinyin.schema.yaml'.
E20260923 13:59:09.026550 0x16d5ff000 deployment_tasks.cc:212] missing input schema: luna_pinyin
";
    fs::write(dir.path().join("rime.squirrel.INFO"), info).unwrap();
    fs::write(dir.path().join("rime.squirrel.WARNING"), warning).unwrap();
    let user_yaml = dir.path().join("user.yaml");

    let report = compile_report(&user_yaml, dir.path());
    let lines: Vec<&str> = report.lines().skip(1).collect();
    assert_eq!(
        lines,
        [
            "13:59:08 I updating workspace.",
            "13:59:09 W nonexistent config file 'build/luna_pinyin.schema.yaml'.",
            "13:59:09 E missing input schema: luna_pinyin",
        ],
        "{report}"
    );

    fs::write(dir.path().join("rime.squirrel.INFO"), format!("{info}{warning}")).unwrap();
    let flushed = compile_report(&user_yaml, dir.path());
    assert_eq!(flushed.matches("missing input schema").count(), 1, "{flushed}");
}

#[test]
fn compile_report_before_any_deploy_or_log() {
    let dir = tempdir().unwrap();
    let report = compile_report(&dir.path().join("user.yaml"), dir.path());
    assert!(report.starts_with("Last deploy: never"), "{report}");
    assert!(report.contains("No Rime log yet"), "{report}");
}

#[test]
fn last_build_time_reads_rime_user_yaml() {
    let dir = tempdir().unwrap();
    let user_yaml = dir.path().join("user.yaml");
    fs::write(&user_yaml, "var:\n  last_build_time: 1778222277\n").unwrap();
    assert_eq!(last_build_time(&user_yaml), Some(1778222277));
    assert_eq!(last_build_time(&dir.path().join("missing.yaml")), None);
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
