use smoodle_config_lib::commands::settings::{
    read_default_custom_at, write_default_custom_at, DefaultCustomPatch, reset_to_defaults_with,
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
    write_default_custom_at(&path, &patch).unwrap();
    let new_content = fs::read_to_string(&path).unwrap();
    assert!(new_content.contains("menu/page_size: 9"));
    assert!(new_content.contains("unrelated_key: true"), "unknown keys must be preserved");
    assert!(new_content.contains("schema: thai_phonetic"));
}

#[test]
fn reset_copies_bundled_files_but_preserves_user_dict() {
    let dir = tempdir().unwrap();
    let rime = dir.path().join("rime");
    let bundled = dir.path().join("bundled");
    fs::create_dir_all(&rime).unwrap();
    fs::create_dir_all(&bundled).unwrap();
    fs::write(bundled.join("thai_phonetic.schema.yaml"), "bundled-schema-content").unwrap();
    fs::write(bundled.join("thai_phonetic.dict.yaml"), "bundled-dict-content").unwrap();
    fs::write(bundled.join("default.custom.yaml"), "bundled-custom").unwrap();
    fs::write(rime.join("thai_phonetic.schema.yaml"), "old").unwrap();
    fs::write(rime.join("thai_phonetic.user.dict.yaml"), "user-words-here").unwrap();
    reset_to_defaults_with(&bundled, &rime).unwrap();
    assert_eq!(fs::read_to_string(rime.join("thai_phonetic.schema.yaml")).unwrap(), "bundled-schema-content");
    // user.dict preserved!
    assert_eq!(fs::read_to_string(rime.join("thai_phonetic.user.dict.yaml")).unwrap(), "user-words-here");
}
