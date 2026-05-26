//! User-dict CRUD: read_user_dict, add_user_word, delete_user_word.

use std::path::{Path, PathBuf};
use crate::yaml;

#[derive(serde::Serialize, serde::Deserialize, Debug, PartialEq, Clone)]
pub struct DictEntry {
    pub word: String,
    pub romanization: String,
    pub weight: i32,
}

const HEADER: &str = "# Rime user dictionary\n---\nname: thai_phonetic.user\nversion: \"1\"\nsort: by_weight\n...\n";

fn user_dict_path() -> PathBuf {
    dirs::home_dir().expect("$HOME").join("Library/Rime/thai_phonetic.user.dict.yaml")
}

/// Public Tauri command (registered via tauri::generate_handler).
#[tauri::command]
pub fn read_user_dict() -> Result<Vec<DictEntry>, String> {
    read_user_dict_at(&user_dict_path()).map_err(|e| e.to_string())
}

#[tauri::command]
pub fn add_user_word(word: String, romanization: String, weight: i32) -> Result<(), String> {
    add_user_word_at(&user_dict_path(), &word, &romanization, weight).map_err(|e| e.to_string())
}

#[tauri::command]
pub fn delete_user_word(line_id: usize) -> Result<(), String> {
    delete_user_word_at(&user_dict_path(), line_id).map_err(|e| e.to_string())
}

// --- testable inner helpers ---

pub fn read_user_dict_at(path: &Path) -> Result<Vec<DictEntry>, yaml::YamlError> {
    if !path.exists() {
        if let Some(parent) = path.parent() {
            std::fs::create_dir_all(parent)?;
        }
        std::fs::write(path, HEADER)?;
        return Ok(vec![]);
    }
    let content = std::fs::read_to_string(path)?;
    let mut entries = Vec::new();
    let mut after_separator = false;
    for line in content.lines() {
        if line.trim() == "..." {
            after_separator = true;
            continue;
        }
        if !after_separator {
            continue;
        }
        if line.starts_with('#') || line.trim().is_empty() {
            continue;
        }
        // Split on tab, expect 3 fields
        let parts: Vec<&str> = line.splitn(3, '\t').collect();
        if parts.len() == 3 {
            if let Ok(weight) = parts[2].trim().parse::<i32>() {
                entries.push(DictEntry {
                    word: parts[0].to_string(),
                    romanization: parts[1].to_string(),
                    weight,
                });
            }
        }
    }
    Ok(entries)
}

pub fn add_user_word_at(path: &Path, word: &str, romanization: &str, weight: i32) -> Result<(), yaml::YamlError> {
    let mut entries = read_user_dict_at(path)?;
    // Idempotency: if (word, romanization) already present, update weight in place.
    if let Some(existing) = entries.iter_mut().find(|e| e.word == word && e.romanization == romanization) {
        existing.weight = weight;
    } else {
        entries.push(DictEntry {
            word: word.to_string(),
            romanization: romanization.to_string(),
            weight,
        });
    }
    write_entries_at(path, &entries)
}

pub fn delete_user_word_at(path: &Path, line_id: usize) -> Result<(), yaml::YamlError> {
    let mut entries = read_user_dict_at(path)?;
    if line_id < entries.len() {
        entries.remove(line_id);
    }
    write_entries_at(path, &entries)
}

fn write_entries_at(path: &Path, entries: &[DictEntry]) -> Result<(), yaml::YamlError> {
    let mut out = String::from(HEADER);
    for e in entries {
        out.push_str(&format!("{}\t{}\t{}\n", e.word, e.romanization, e.weight));
    }
    yaml::atomic_write_str(path, &out)
}
