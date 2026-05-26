use tempfile::tempdir;
use smoodle_config_lib::commands::user_dict::{
    read_user_dict_at, add_user_word_at, delete_user_word_at, DictEntry,
};

const SAMPLE_DICT: &str = r#"# Rime user dictionary
---
name: thai_phonetic.user
version: "1"
sort: by_weight
...
ลีเอ็กซ์	lex	100
สมูดเดิล	smoodle	500
"#;

#[test]
fn read_returns_two_entries() {
    let dir = tempdir().unwrap();
    let path = dir.path().join("user.dict.yaml");
    std::fs::write(&path, SAMPLE_DICT).unwrap();
    let entries = read_user_dict_at(&path).unwrap();
    assert_eq!(entries.len(), 2);
    assert_eq!(entries[0], DictEntry { word: "ลีเอ็กซ์".into(), romanization: "lex".into(), weight: 100 });
    assert_eq!(entries[1], DictEntry { word: "สมูดเดิล".into(), romanization: "smoodle".into(), weight: 500 });
}

#[test]
fn read_missing_file_returns_empty_with_header_written() {
    let dir = tempdir().unwrap();
    let path = dir.path().join("user.dict.yaml");
    let entries = read_user_dict_at(&path).unwrap();
    assert_eq!(entries.len(), 0);
    // Side effect: header was written
    let content = std::fs::read_to_string(&path).unwrap();
    assert!(content.contains("name: thai_phonetic.user"));
    assert!(content.contains("..."));
}

#[test]
fn add_appends_and_preserves_header() {
    let dir = tempdir().unwrap();
    let path = dir.path().join("user.dict.yaml");
    std::fs::write(&path, SAMPLE_DICT).unwrap();
    add_user_word_at(&path, "ขนม", "khanom", 200).unwrap();
    let entries = read_user_dict_at(&path).unwrap();
    assert_eq!(entries.len(), 3);
    assert_eq!(entries[2], DictEntry { word: "ขนม".into(), romanization: "khanom".into(), weight: 200 });
    // header preserved
    let content = std::fs::read_to_string(&path).unwrap();
    assert!(content.starts_with("# Rime user dictionary"));
}

#[test]
fn add_is_idempotent_on_word_rom_collision() {
    let dir = tempdir().unwrap();
    let path = dir.path().join("user.dict.yaml");
    std::fs::write(&path, SAMPLE_DICT).unwrap();
    // Re-adding the same word+rom updates the weight, doesn't duplicate
    add_user_word_at(&path, "lex", "lex", 999).unwrap(); // collision on rom only -> NEW row
    add_user_word_at(&path, "ลีเอ็กซ์", "lex", 999).unwrap(); // collision on (word,rom) -> UPDATE
    let entries = read_user_dict_at(&path).unwrap();
    let lex_entries: Vec<_> = entries.iter().filter(|e| e.word == "ลีเอ็กซ์" && e.romanization == "lex").collect();
    assert_eq!(lex_entries.len(), 1);
    assert_eq!(lex_entries[0].weight, 999);
}

#[test]
fn delete_by_index_removes_and_preserves_others() {
    let dir = tempdir().unwrap();
    let path = dir.path().join("user.dict.yaml");
    std::fs::write(&path, SAMPLE_DICT).unwrap();
    delete_user_word_at(&path, 0).unwrap();
    let entries = read_user_dict_at(&path).unwrap();
    assert_eq!(entries.len(), 1);
    assert_eq!(entries[0].word, "สมูดเดิล");
}
