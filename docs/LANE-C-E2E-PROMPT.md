# Lane C GHA E2E — Next-Session Prompt

> Paste this at the start of a new Claude Code session in the smoodle
> repo root, or say: "read docs/LANE-C-E2E-PROMPT.md and continue."

---

## What was accomplished in the previous session (2026-05-07)

Lane B hardening is **complete** — commit `1b6504c` on `LoneExile/smoodle` main.

Three hardening fixes landed and smoke-verified on the th-dc dockur/windows VM:

**Fix #1 — Schema timestamp touch + forced redeploy** (`install-windows.ps1`)
- `$_.LastWriteTime = Get-Date` on all `*.yaml` after copy — eliminates
  rsync/Copy-Item timestamp preservation bug that caused WeaselDeployer to
  silently skip recompilation (schema files dated 2026-05-03/04 < Weasel
  build 2026-05-06 10:38 PM → silent skip).
- `build/thai_phonetic.*` cleared when `$schemasChanged = $true`.
- Default `SMOODLE_DEPLOY_TIMEOUT_SECS` raised 10s → 60s.

**Fix #2 — Vendored `rime.dll`** (`install-librime-fork.ps1`)
- `vendor/windows/rime.dll` (BSD-3, 2786 KB, from CI run 25429514636) added
  to repo (gitignore updated with `!vendor/windows/rime.dll` exception).
- Script checks `\\host.lan\Data\vendor\windows\rime.dll` (share, dev loop)
  first, then `$ScriptDir\..\vendor\windows\rime.dll` (git-clone path),
  then falls back to gh CLI + 7-Zip CI download.
- gh CLI + 7-Zip installs skipped entirely when vendored DLL found.
- Stop WeaselServer + WeaselDeployer before copy + 5-retry loop on IOException.
- `[System.Console]::IsInputRedirected` check auto-skips `Read-Host` in SSH.

**Fix #3 — WARN message + docs** (`install-windows.ps1`, `docs/LANE-B-WINDOWS.md`)
- Expanded `[WARN]` output with manual tray fallback instructions.
- `LANE-B-WINDOWS.md` WeaselDeployer section updated with full failure modes.

**Tests:** 47 passed, 3 skipped (7 new assertions). Both .ps1 files ASCII-clean.

---

## Mission for this session

Two tasks, ~1.5 hrs total:

1. **Update TODOS.md** (5 min) — mark the three hardening items in TODO 7
   as done (discoveries 3, 4, and tray note are now closed in commit `1b6504c`).

2. **TODO 8 — Lane C GHA E2E** (~1 hr) — `scripts/install-linux.sh` is
   fully implemented with 7 shape tests passing. Write
   `.github/workflows/install-linux-e2e.yml` that runs on `ubuntu-latest`,
   installs `ibus-rime` via apt, runs the installer, and verifies schema
   deployment. This closes the last open code task before dogfood.

---

## Read these first

1. **TODOS.md item 8** — Lane C status, concrete steps (only step 5 remains).
2. **`scripts/install-linux.sh`** — fully implemented (IM detection, schema
   copy, auto-deploy, ranking-limitation note). The GHA workflow mirrors what
   this script does.
3. **`tests/test_installers.py` `InstallLinuxScriptShape`** class — 7 tests
   covering the shape assertions the GHA workflow should also satisfy.
4. **`vendor/librime/.github/workflows/linux-build.yml`** (LoneExile/librime
   fork) — reference for how upstream bootstraps the Ubuntu CI environment.

---

## Task 1 — Update TODOS.md (5 min)

In TODO 7's "Next hardening steps" section, mark all three items done:

```
- Fix schema timestamp issue in install-windows.ps1  ✓ DONE 2026-05-07
  (touch LastWriteTime + clear build/thai_phonetic.* — commit 1b6504c)
- Decide rime.dll distribution: vendor/windows/rime.dll  ✓ DONE 2026-05-07
  (vendor/windows/rime.dll added to repo, BSD-3 — commit 1b6504c)
- Add WARN note for manual Deploy  ✓ DONE 2026-05-07
  (LANE-B-WINDOWS.md + expanded WARN message — commit 1b6504c)
```

---

## Task 2 — Lane C GHA E2E workflow

### Goal

File: `.github/workflows/install-linux-e2e.yml`

Trigger: `push` to `main` and `pull_request` (paths: `scripts/install-linux.sh`,
`schema/**`, `.github/workflows/install-linux-e2e.yml`).

Runner: `ubuntu-latest`.

### Steps the workflow should perform

1. **Checkout** (`actions/checkout@v4`)

2. **Install ibus-rime**
   ```bash
   sudo apt-get update -qq
   sudo apt-get install -y ibus-rime
   ```

3. **Run installer** with env overrides so it doesn't try to restart ibus:
   ```bash
   SMOODLE_AUTO_DEPLOY=0 SMOODLE_IM=ibus bash scripts/install-linux.sh
   ```
   The `SMOODLE_IM=ibus` override bypasses the `pgrep -x ibus-daemon`
   detection (ibus-daemon won't be running in the GHA runner).
   `SMOODLE_AUTO_DEPLOY=0` skips the `ibus-daemon -drxR` restart.

4. **Verify schema files installed**
   ```bash
   for f in thai_phonetic.schema.yaml thai_phonetic.dict.yaml default.custom.yaml; do
     test -f "$HOME/.config/ibus/rime/$f" || (echo "MISSING: $f" && exit 1)
   done
   echo "All schema files installed."
   ```

5. **Verify file content** (sanity: not empty, contains expected keys)
   ```bash
   grep -q "thai_phonetic" "$HOME/.config/ibus/rime/thai_phonetic.schema.yaml"
   grep -q "thai_phonetic" "$HOME/.config/ibus/rime/thai_phonetic.dict.yaml"
   ```

### Known subtlety: ibus-rime path vs fcitx5-rime path

`install-linux.sh` puts schemas at:
- fcitx5: `~/.local/share/fcitx5/rime/`
- ibus:   `~/.config/ibus/rime/`

With `SMOODLE_IM=ibus`, the workflow verifies the ibus path. Add a comment
in the workflow noting the fcitx5 path is not tested in this workflow
(would need `fcitx5-rime` apt package + different dir).

### Workflow name and job name

```yaml
name: install-linux e2e
jobs:
  install-linux:
    name: Lane C schema install (ubuntu-latest / ibus)
    runs-on: ubuntu-latest
```

### Example reference

`vendor/librime/.github/workflows/linux-build.yml` for the
`apt-get install` bootstrap pattern.

---

## Verification criteria

**Done when:**

- `TODOS.md` TODO 7 hardening items are marked done.
- `.github/workflows/install-linux-e2e.yml` exists and triggers on the right
  paths.
- Workflow passes on `ubuntu-latest` (push to main triggers it; verify via
  `gh run list --workflow install-linux-e2e`).
- `tests/test_installers.py` still 47 passed, 3 skipped after any edits.
- TODO 8 in TODOS.md updated to CLOSED with the GHA run ID.

---

## Current repo state

- `LoneExile/smoodle` private GitHub repo
- Latest commit: `1b6504c` on `main`
- 47 tests pass (47 active + 3 skipped)
- th-dc dockur/windows VM: running, Win 11 + Weasel 0.17.4 + patched
  rime.dll (2786 KB) + Thai phonetic schema — all verified working

## SSH access to Windows VM (if needed)

```bash
# 1. Recreate the nc-proxy script on th-dc
ssh th-dc 'cat > /tmp/ssh-proxy-vm.sh << '"'"'EOF'"'"'
#!/bin/bash
docker exec -i smoodle-lane-b nc 172.30.0.2 22
EOF
chmod +x /tmp/ssh-proxy-vm.sh'

# 2. Create the local SSH config
cat > /tmp/smoodle-win-ssh.conf << 'EOF'
Host smoodle-win
  HostName win
  User smoodle
  ProxyCommand ssh th-dc /tmp/ssh-proxy-vm.sh
  StrictHostKeyChecking no
  UserKnownHostsFile /dev/null
EOF

# 3. Test (should return: win-k7ufab5802l\smoodle)
ssh -F /tmp/smoodle-win-ssh.conf smoodle-win 'whoami'
```

## Not in scope for this session

- Dogfood distribution to real users (next step after TODO 8 closes)
- Windows MSI packaging (pre-public-ship gate)
- Weasel auto-update overwrite protection (Phase 1.5)
- Upstream librime PR (TODO 1, DEFERRED)
- Lane C fcitx5 E2E variant (ibus is sufficient for Phase 1)
