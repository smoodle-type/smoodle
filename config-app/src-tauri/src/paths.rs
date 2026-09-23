//! Filesystem locations Smoodle Config shares with Smoodle.app (the IME).
//!
//! Smoodle.app (smoodle-app/sources) starts Rime with
//!   shared_data_dir = /Library/Input Methods/Smoodle.app/Contents/SharedSupport
//!   user_data_dir   = ~/Library/Rime/Smoodle
//!   log_dir         = $TMPDIR/rime.squirrel
//! and Rime looks up every data file in the user dir first, falling back to
//! the shared dir (librime `FallbackResourceResolver`). `resolve` mirrors that
//! lookup so the Config app reads what Smoodle.app actually uses.

use std::path::{Path, PathBuf};

pub const SMOODLE_APP: &str = "/Library/Input Methods/Smoodle.app";

pub const BASE_DICT_FILE: &str = "thai_phonetic.dict.yaml";
pub const USER_DICT_FILE: &str = "thai_phonetic.user.dict.yaml";
pub const DEFAULT_CUSTOM_FILE: &str = "default.custom.yaml";

pub fn shared_data_dir() -> PathBuf {
    Path::new(SMOODLE_APP).join("Contents/SharedSupport")
}

pub fn info_plist() -> PathBuf {
    Path::new(SMOODLE_APP).join("Contents/Info.plist")
}

pub fn smoodle_executable() -> PathBuf {
    Path::new(SMOODLE_APP).join("Contents/MacOS/Smoodle")
}

/// Rime user data dir used by Smoodle.app (`SquirrelApp.userDir`).
pub fn rime_user_dir() -> Result<PathBuf, String> {
    dirs::home_dir()
        .map(|h| h.join("Library/Rime/Smoodle"))
        .ok_or_else(|| "$HOME not set — cannot locate ~/Library/Rime/Smoodle".to_string())
}

/// The file Rime reads for `name`: the user-dir copy when present, otherwise
/// the bundled one. When neither exists, returns the user-dir path.
pub fn resolve(user_dir: &Path, shared_dir: &Path, name: &str) -> PathBuf {
    let user = user_dir.join(name);
    if user.exists() {
        return user;
    }
    let shared = shared_dir.join(name);
    if shared.exists() {
        shared
    } else {
        user
    }
}

/// Smoodle.app's Rime log directory, `$TMPDIR/rime.squirrel`. glog keeps
/// `rime.squirrel.INFO` and `rime.squirrel.ERROR` pointing at the current
/// process's log files there.
pub fn rime_log_dir() -> PathBuf {
    user_temp_dir().join("rime.squirrel")
}

/// Per-user temp dir, the same one Swift's `FileManager.temporaryDirectory`
/// returns inside Smoodle.app. A GUI app's TMPDIR is not guaranteed, so ask
/// the OS directly.
fn user_temp_dir() -> PathBuf {
    #[cfg(target_os = "macos")]
    {
        let mut buf = vec![0u8; 1024];
        // SAFETY: `buf` is writable for `buf.len()` bytes; confstr writes at
        // most that many bytes, NUL included, and returns the length it needs.
        let needed = unsafe {
            libc::confstr(libc::_CS_DARWIN_USER_TEMP_DIR, buf.as_mut_ptr().cast(), buf.len())
        };
        if needed > 0 && needed <= buf.len() {
            buf.truncate(needed - 1);
            if let Ok(dir) = String::from_utf8(buf) {
                return PathBuf::from(dir);
            }
        }
    }
    std::env::temp_dir()
}
