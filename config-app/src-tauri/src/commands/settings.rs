//! Settings tab: read/write default.custom.yaml patch, open Rime folder, reset.
//!
//! NOTE: Commands are NOT yet wired into the Tauri `invoke_handler` —
//! that happens in Task 8 (`commands::register_all(lib.rs)`).

use std::fs;
use std::path::{Path, PathBuf};
use std::process::Command;
use crate::yaml;

#[derive(serde::Serialize, serde::Deserialize, Debug, Clone)]
pub struct DefaultCustomPatch {
    pub candidate_count: Option<u32>,
    pub schema_list: Vec<String>,
}

// Smoodle.app is an IME — installs to /Library/Input Methods/Smoodle.app
#[cfg(target_os = "macos")]
const BUNDLED_DIR: &str = "/Library/Input Methods/Smoodle.app/Contents/Resources/plum";

#[cfg(target_os = "macos")]
fn bundled_dir() -> PathBuf {
    PathBuf::from(BUNDLED_DIR)
}

#[cfg(not(target_os = "macos"))]
fn bundled_dir() -> PathBuf {
    PathBuf::from("/non-macos/path") // placeholder; reset_to_defaults will fail with file-not-found
}

fn rime_dir() -> Result<PathBuf, String> {
    dirs::home_dir()
        .map(|h| h.join("Library/Rime"))
        .ok_or_else(|| "$HOME not set".to_string())
}

#[tauri::command]
pub fn read_default_custom() -> Result<DefaultCustomPatch, String> {
    read_default_custom_at(&rime_dir()?.join("default.custom.yaml")).map_err(|e| e.to_string())
}

#[tauri::command]
pub fn write_default_custom(patch: DefaultCustomPatch) -> Result<(), String> {
    write_default_custom_at(&rime_dir()?.join("default.custom.yaml"), &patch).map_err(|e| e.to_string())
}

#[tauri::command]
pub fn open_rime_folder() -> Result<(), String> {
    let path = rime_dir()?;
    let status = Command::new("/usr/bin/open").arg(&path).status().map_err(|e| e.to_string())?;
    if !status.success() {
        return Err(format!("/usr/bin/open exited with {}", status));
    }
    Ok(())
}

#[cfg(target_os = "macos")]
#[tauri::command]
pub fn reset_to_defaults() -> Result<(), String> {
    reset_to_defaults_with(&bundled_dir(), &rime_dir()?).map_err(|e| e.to_string())
}

#[cfg(not(target_os = "macos"))]
#[tauri::command]
pub fn reset_to_defaults() -> Result<(), String> {
    Err("reset_to_defaults is only supported on macOS".to_string())
}

// --- testable inner helpers ---

pub fn read_default_custom_at(path: &Path) -> Result<DefaultCustomPatch, yaml::YamlError> {
    if !path.exists() {
        return Ok(DefaultCustomPatch { candidate_count: None, schema_list: vec![] });
    }
    let content = fs::read_to_string(path)?;
    let v: serde_yaml::Value = serde_yaml::from_str(&content)?;
    let patch = v.get("patch");
    let candidate_count = patch
        .and_then(|p| p.get("menu/page_size"))
        .and_then(|v| v.as_u64())
        .map(|n| n as u32);
    let schema_list = patch
        .and_then(|p| p.get("schema_list"))
        .and_then(|v| v.as_sequence())
        .map(|seq| {
            seq.iter()
                .filter_map(|s| s.get("schema"))
                .filter_map(|s| s.as_str())
                .map(String::from)
                .collect()
        })
        .unwrap_or_default();
    Ok(DefaultCustomPatch { candidate_count, schema_list })
}

pub fn write_default_custom_at(path: &Path, patch: &DefaultCustomPatch) -> Result<(), yaml::YamlError> {
    // Merge-patch: read existing yaml (preserving unknown keys), mutate the ones we care about, write back.
    let mut v: serde_yaml::Value = if path.exists() {
        serde_yaml::from_str(&fs::read_to_string(path)?)?
    } else {
        serde_yaml::from_str("patch: {}")?
    };
    let patch_map = v
        .get_mut("patch")
        .and_then(|p| p.as_mapping_mut())
        .ok_or(yaml::YamlError::MissingPatchRoot)?;
    // TODO(v0.0.9): candidate_count=None means "don't touch existing key" — there
    // is currently no way to explicitly delete the key (revert to Rime default).
    // Frontend should treat None as "no change" until a Reset action exists.
    if let Some(n) = patch.candidate_count {
        patch_map.insert("menu/page_size".into(), (n as u64).into());
    }
    if !patch.schema_list.is_empty() {
        let mut sl = serde_yaml::Sequence::new();
        for name in &patch.schema_list {
            let mut m = serde_yaml::Mapping::new();
            m.insert("schema".into(), name.clone().into());
            sl.push(serde_yaml::Value::Mapping(m));
        }
        patch_map.insert("schema_list".into(), serde_yaml::Value::Sequence(sl));
    }
    let s = serde_yaml::to_string(&v)?;
    yaml::atomic_write_str(path, &s)
}

pub fn reset_to_defaults_with(bundled: &Path, rime: &Path) -> Result<(), yaml::YamlError> {
    let user_dict = rime.join("thai_phonetic.user.dict.yaml");
    let user_backup = if user_dict.exists() {
        Some(fs::read(&user_dict)?)
    } else {
        None
    };
    for f in &[
        "thai_phonetic.schema.yaml",
        "thai_phonetic.dict.yaml",
        "default.custom.yaml",
    ] {
        let src = bundled.join(f);
        let dst = rime.join(f);
        if src.exists() {
            yaml::atomic_copy(&src, &dst)?;
        }
    }
    if let Some(content) = user_backup {
        let parent = user_dict.parent().ok_or_else(|| {
            std::io::Error::new(std::io::ErrorKind::InvalidInput, "user_dict has no parent")
        })?;
        let mut tmp = tempfile::NamedTempFile::new_in(parent)?;
        std::io::Write::write_all(tmp.as_file_mut(), &content)?;
        tmp.as_file().sync_all()?;
        tmp.persist(&user_dict).map_err(|e| e.error)?;
    }
    Ok(())
}
