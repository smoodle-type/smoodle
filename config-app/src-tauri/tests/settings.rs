use smoodle_config_lib::commands::settings::{
    read_default_custom_at, reset_to_defaults_in, write_default_custom_at, DefaultCustomPatch,
};
use tempfile::tempdir;
use std::fs;

const SAMPLE: &str = r#"# default.custom.yaml
patch:
  menu/page_size: 5
  schema_list:
    - schema: thai_phonetic
"#;

#[test]
fn read_extracts_page_size_and_schema_list() {
    let dir = tempdir().unwrap();
    let path = dir.path().join("default.custom.yaml");
    fs::write(&path, SAMPLE).unwrap();
    let patch = read_default_custom_at(&path).unwrap();
    assert_eq!(patch.candidate_count, Some(5));
    assert_eq!(patch.schema_list, vec!["thai_phonetic".to_string()]);
}

#[test]
fn write_round_trips_and_preserves_unknown_keys() {
    let dir = tempdir().unwrap();
    let path = dir.path().join("default.custom.yaml");
    // Pre-existing file has an unknown key that we should preserve
    fs::write(&path, "patch:\n  menu/page_size: 5\n  unrelated_key: true\n").unwrap();
    let patch = DefaultCustomPatch { candidate_count: Some(9), schema_list: vec!["thai_phonetic".into()] };
    write_default_custom_at(&path, &dir.path().join("no-bundle.yaml"), &patch).unwrap();
    let new_content = fs::read_to_string(&path).unwrap();
    assert!(new_content.contains("menu/page_size: 9"));
    assert!(new_content.contains("unrelated_key: true"), "unknown keys must be preserved");
    assert!(new_content.contains("schema: thai_phonetic"));
}

#[test]
fn first_write_starts_from_bundled_copy_so_schema_list_survives() {
    // A user-dir default.custom.yaml replaces the bundled one wholesale. If the
    // first save dropped the bundled schema_list, Rime would fall back to
    // default.yaml's stock schemas and Smoodle would lose its Thai schema.
    let dir = tempdir().unwrap();
    let bundled = dir.path().join("SharedSupport/default.custom.yaml");
    let target = dir.path().join("Rime/Smoodle/default.custom.yaml");
    fs::create_dir_all(bundled.parent().unwrap()).unwrap();
    fs::write(&bundled, SAMPLE).unwrap();
    let patch = DefaultCustomPatch { candidate_count: Some(3), schema_list: vec![] };
    write_default_custom_at(&target, &bundled, &patch).unwrap();
    let written = read_default_custom_at(&target).unwrap();
    assert_eq!(written.candidate_count, Some(3));
    assert_eq!(written.schema_list, vec!["thai_phonetic".to_string()]);
    assert_eq!(fs::read_to_string(&bundled).unwrap(), SAMPLE, "bundled copy must stay untouched");
}

#[test]
fn reset_moves_overrides_aside_and_keeps_custom_words() {
    let dir = tempdir().unwrap();
    let user = dir.path();
    fs::write(user.join("default.custom.yaml"), SAMPLE).unwrap();
    fs::write(user.join("thai_phonetic.custom.yaml"), "patch: {}\n").unwrap();
    fs::write(user.join("thai_phonetic.user.dict.yaml"), "user-words-here").unwrap();
    fs::create_dir_all(user.join("thai_phonetic.userdb")).unwrap();

    let moved = reset_to_defaults_in(user).unwrap();

    assert_eq!(moved.len(), 2);
    assert!(!user.join("default.custom.yaml").exists(), "override still shadows the bundled file");
    assert!(!user.join("thai_phonetic.custom.yaml").exists(), "override still shadows the bundled file");
    for bak in &moved {
        assert!(bak.exists(), "backup {} missing", bak.display());
    }
    assert_eq!(fs::read_to_string(user.join("thai_phonetic.user.dict.yaml")).unwrap(), "user-words-here");
    assert!(user.join("thai_phonetic.userdb").is_dir(), "learned history must survive a reset");
}

#[test]
fn write_returns_error_when_patch_root_absent() {
    let dir = tempdir().unwrap();
    let path = dir.path().join("bad.yaml");
    fs::write(&path, "not_a_patch_key: true\n").unwrap();
    let patch = DefaultCustomPatch { candidate_count: Some(5), schema_list: vec![] };
    let result = write_default_custom_at(&path, &dir.path().join("no-bundle.yaml"), &patch);
    assert!(result.is_err());
    assert!(
        format!("{}", result.unwrap_err()).contains("patch"),
        "error message should mention 'patch'"
    );
}
