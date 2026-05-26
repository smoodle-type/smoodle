//! User-dict CRUD: read_user_dict, add_user_word, delete_user_word.
//!
//! NOTE 1: Commands are NOT yet wired into the Tauri `invoke_handler` —
//! that happens in Task 8 (`commands::register_all(lib.rs)`).
//!
//! NOTE 2: `write_entries_at` always emits the canonical `HEADER`. User
//! edits to the front-matter or mid-file comments are NOT preserved.
//! This file is Tauri-owned; manual edits are intentionally discouraged.

use std::path::{Path, PathBuf};
use crate::yaml;

#[derive(serde::Serialize, serde::Deserialize, Debug, PartialEq, Clone)]
pub struct DictEntry {
    pub word: String,
    pub romanization: String,
    pub weight: i32,
}

const HEADER: &str = "# Rime user dictionary\n---\nname: thai_phonetic.user\nversion: \"1\"\nsort: by_weight\n...\n";

fn user_dict_path() -> Result<PathBuf, yaml::YamlError> {
    dirs::home_dir()
        .map(|h| h.join("Library/Rime/thai_phonetic.user.dict.yaml"))
        .ok_or_else(|| yaml::YamlError::Io(std::io::Error::new(
            std::io::ErrorKind::NotFound, "$HOME not set"
        )))
}

fn validate_single_line(s: &str, field: &str) -> Result<(), String> {
    if s.contains('\t') || s.contains('\n') || s.contains('\r') {
        return Err(format!(
            "{}: must not contain tab, newline, or carriage return", field
        ));
    }
    Ok(())
}

/// Public Tauri command (registered via tauri::generate_handler).
#[tauri::command]
pub fn read_user_dict() -> Result<Vec<DictEntry>, String> {
    let path = user_dict_path().map_err(|e| e.to_string())?;
    read_user_dict_at(&path).map_err(|e| e.to_string())
}

#[tauri::command]
pub fn add_user_word(word: String, romanization: String, weight: i32) -> Result<(), String> {
    validate_single_line(&word, "word")?;
    validate_single_line(&romanization, "romanization")?;
    let path = user_dict_path().map_err(|e| e.to_string())?;
    add_user_word_at(&path, &word, &romanization, weight)
        .map_err(|e| e.to_string())
}

#[tauri::command]
pub fn delete_user_word(line_id: usize) -> Result<(), String> {
    let path = user_dict_path().map_err(|e| e.to_string())?;
    delete_user_word_at(&path, line_id).map_err(|e| e.to_string())
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
    if line_id >= entries.len() {
        return Ok(()); // out-of-range: no-op, skip the write
    }
    entries.remove(line_id);
    write_entries_at(path, &entries)
}

fn write_entries_at(path: &Path, entries: &[DictEntry]) -> Result<(), yaml::YamlError> {
    let mut out = String::from(HEADER);
    for e in entries {
        out.push_str(&format!("{}\t{}\t{}\n", e.word, e.romanization, e.weight));
    }
    yaml::atomic_write_str(path, &out)
}
