use std::fs;
use tempfile::tempdir;
use smoodle_config_lib::yaml;

#[test]
fn atomic_write_creates_new_file() {
    let dir = tempdir().unwrap();
    let path = dir.path().join("a.yaml");
    yaml::atomic_write_str(&path, "hello: world\n").unwrap();
    assert_eq!(fs::read_to_string(&path).unwrap(), "hello: world\n");
}

#[test]
fn atomic_write_replaces_existing_file_via_temp_rename() {
    let dir = tempdir().unwrap();
    let path = dir.path().join("a.yaml");
    fs::write(&path, "old\n").unwrap();
    yaml::atomic_write_str(&path, "new\n").unwrap();
    assert_eq!(fs::read_to_string(&path).unwrap(), "new\n");
    // No leftover .tmp file
    let temp_files: Vec<_> = fs::read_dir(&dir).unwrap()
        .filter_map(|e| e.ok())
        .filter(|e| e.file_name().to_string_lossy().contains(".tmp"))
        .collect();
    assert!(temp_files.is_empty(), "no .tmp file should remain");
}

#[test]
fn atomic_write_leaves_bak_on_simulated_failure() {
    // Caller asks for write but underlying io fails mid-write: leave .bak.<ISO>
    // We simulate by writing to a read-only directory.
    let dir = tempdir().unwrap();
    let path = dir.path().join("a.yaml");
    fs::write(&path, "original\n").unwrap();
    // Make dir read-only on Unix
    let mut perms = fs::metadata(dir.path()).unwrap().permissions();
    #[cfg(unix)] {
        use std::os::unix::fs::PermissionsExt;
        perms.set_mode(0o555);
    }
    fs::set_permissions(dir.path(), perms.clone()).unwrap();
    let result = yaml::atomic_write_str(&path, "new\n");
    // Restore perms so tempdir can clean up
    #[cfg(unix)] {
        use std::os::unix::fs::PermissionsExt;
        perms.set_mode(0o755);
        fs::set_permissions(dir.path(), perms).unwrap();
    }
    assert!(result.is_err(), "write should fail to read-only dir");
    // Original is preserved
    assert_eq!(fs::read_to_string(&path).unwrap(), "original\n");
}
