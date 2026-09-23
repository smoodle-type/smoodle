//! Settings tab: candidate count + schema list (default.custom.yaml), Rime
//! folder, reset to defaults.
//!
//! Rime reads `default.custom.yaml` from ~/Library/Rime/Smoodle when present
//! and otherwise the copy bundled in Smoodle.app. Reads resolve the same way.
//! A user-dir file replaces the bundled one wholesale, so the first write
//! starts from the bundled copy and keeps its schema list.

use std::fs;
use std::path::{Path, PathBuf};
use std::process::Command;
use crate::{paths, yaml};

#[derive(serde::Serialize, serde::Deserialize, Debug, Clone)]
pub struct DefaultCustomPatch {
    pub candidate_count: Option<u32>,
    pub schema_list: Vec<String>,
}

/// User-dir files that replace a file bundled in Smoodle.app. Reset moves
/// them aside so the bundled copies apply again. Custom words
/// (thai_phonetic.user.dict.yaml) and learned history are left alone.
pub const OVERRIDES: [&str; 4] = [
    "default.custom.yaml",
    "thai_phonetic.custom.yaml",
    "thai_phonetic.schema.yaml",
    "thai_phonetic.dict.yaml",
];

#[tauri::command]
pub fn read_default_custom() -> Result<DefaultCustomPatch, String> {
    let user = paths::rime_user_dir()?;
    let path = paths::resolve(&user, &paths::shared_data_dir(), paths::DEFAULT_CUSTOM_FILE);
    read_default_custom_at(&path).map_err(|e| e.to_string())
}

#[tauri::command]
pub fn write_default_custom(patch: DefaultCustomPatch) -> Result<(), String> {
    let target = paths::rime_user_dir()?.join(paths::DEFAULT_CUSTOM_FILE);
    let bundled = paths::shared_data_dir().join(paths::DEFAULT_CUSTOM_FILE);
    write_default_custom_at(&target, &bundled, &patch).map_err(|e| e.to_string())
}

#[tauri::command]
pub fn open_rime_folder() -> Result<(), String> {
    let path = paths::rime_user_dir()?;
    fs::create_dir_all(&path).map_err(|e| e.to_string())?;
    let status = Command::new("/usr/bin/open").arg(&path).status().map_err(|e| e.to_string())?;
    if !status.success() {
        return Err(format!("/usr/bin/open exited with {}", status));
    }
    Ok(())
}

#[tauri::command]
pub fn reset_to_defaults() -> Result<(), String> {
    reset_to_defaults_in(&paths::rime_user_dir()?)
        .map(|_| ())
        .map_err(|e| e.to_string())
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

/// Merge `patch` into `target` (the user-dir file), preserving keys the UI
/// does not edit. A missing `target` starts from `bundled`.
pub fn write_default_custom_at(
    target: &Path,
    bundled: &Path,
    patch: &DefaultCustomPatch,
) -> Result<(), yaml::YamlError> {
    let base = if target.exists() {
        Some(target)
    } else if bundled.exists() {
        Some(bundled)
    } else {
        None
    };
    let mut v: serde_yaml::Value = match base {
        Some(p) => serde_yaml::from_str(&fs::read_to_string(p)?)?,
        None => serde_yaml::from_str("patch: {}")?,
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
    if let Some(parent) = target.parent() {
        fs::create_dir_all(parent)?;
    }
    let s = serde_yaml::to_string(&v)?;
    yaml::atomic_write_str(target, &s)
}

/// Move every user-dir override aside (`<name>.bak.<UTC timestamp>`) so Rime
/// falls back to Smoodle.app's bundled files. Returns the backups created.
pub fn reset_to_defaults_in(user_dir: &Path) -> Result<Vec<PathBuf>, yaml::YamlError> {
    let mut moved = Vec::new();
    for name in OVERRIDES {
        if let Some(bak) = yaml::move_aside(&user_dir.join(name))? {
            moved.push(bak);
        }
    }
    Ok(moved)
}
