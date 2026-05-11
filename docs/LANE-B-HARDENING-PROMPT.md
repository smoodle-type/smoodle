# Lane B Hardening — Next-Session Prompt

> Paste this at the start of a new Claude Code session in the smoodle
> repo root, or say: "read docs/LANE-B-HARDENING-PROMPT.md and continue."

---

## What was accomplished in the previous session (2026-05-07)

Lane B Windows smoke is **complete**. `sawatd → สวัสดี` (candidate #1) on
the th-dc dockur/windows test bed with:
- Patched librime DLL (`rime.dll`, 2786 KB, from `smoodle-type/librime`
  fork `1.16.0-smoodle.1`) swapped into Weasel's install dir
- Thai phonetic schema compiled by WeaselDeployer (705 KB table)

All scripts are in the repo and pushed to `smoodle-type/smoodle` (private).
Latest commit: `ee6efbb` on `main`.

## Mission for this session

**Harden the Lane B installer before it's handed to a dogfood user.**
Three concrete fixes, ~3 hrs total. After this session, someone who has
never used smoodle can install it on a fresh Windows 11 box without
manual workarounds.

## Read these first

1. **TODOS.md item 7** — `Discoveries during smoke (hardening needed)` —
   five empirical findings + three next hardening steps with time estimates.
2. **`scripts/install-windows.ps1`** — user-scope installer (schema copy +
   WeaselDeployer). Hardening fix #1 + #3 land here.
3. **`scripts/install-librime-fork.ps1`** — admin DLL swap. Hardening fix
   #2 lands here (rime.dll distribution).
4. **`infra/lane-b-windows/README.md`** — test bed access + dev loop docs.

## Current state of the Windows test bed

dockur/windows container `smoodle-lane-b` running on `th-dc` remote docker
context (10.159.0.63). SSH access is set up — **but `/tmp/` state does not
survive a new session**. Reconstruct it first thing:

```bash
# 1. Recreate the nc-proxy script on th-dc (VM is at 172.30.0.2 internally)
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

If `smoodle-lane-b` is down: `docker --context th-dc compose -f infra/lane-b-windows/docker-compose.yml up -d`

Dev loop (after any script edit):
```bash
./scripts/dev-sync-windows.sh   # rsync to th-dc:/root/smoodle-shared
# Then run via SSH:
ssh -F /tmp/smoodle-win-ssh.conf smoodle-win \
  'cmd /c "powershell -ExecutionPolicy Bypass -File \\host.lan\Data\scripts\install-windows.ps1 2>&1"'
```

## Hardening fix #1 — Schema timestamp + forced redeploy in install-windows.ps1

**Problem discovered 2026-05-07:** `rsync` preserves the Mac's file
timestamps when pushing schema files to th-dc (via `dev-sync-windows.sh`).
When `install-windows.ps1` copies schemas from `\\host.lan\Data\schema\`
to `%APPDATA%\Rime\`, PowerShell's `Copy-Item` also preserves source
timestamps. If those timestamps are OLDER than Weasel's last build,
`WeaselDeployer.exe /deploy` skips recompilation — schemas never update.

**Fix:** after copying the three YAML files, explicitly set their
`LastWriteTime` to `Get-Date` (now). Also clear `%APPDATA%\Rime\build\`
on first install (or when schema files changed) to force a full rebuild.

```powershell
# After the copy loop, before WeaselDeployer:
$now = Get-Date
Get-ChildItem "$RimeDir\*.yaml" | ForEach-Object { $_.LastWriteTime = $now }
```

Also wipe the build dir when we detect fresh schema files:
```powershell
$buildDir = Join-Path $RimeDir 'build'
if ((Test-Path $buildDir) -and $schemasChanged) {
    Remove-Item "$buildDir\thai_phonetic.*" -Force -ErrorAction SilentlyContinue
}
```

($schemasChanged can be a boolean set to `$true` any time a file was
backed up or copied fresh — you already track this in the copy loop.)

**Also fix WeaselDeployer timeout:** 10s is not enough for the first compile
of `thai_phonetic.dict.yaml` (1.1 MB). Change default from 10s to 60s.
Update `$DeployTimeoutSecs` default + `SMOODLE_DEPLOY_TIMEOUT_SECS` doc.

## Hardening fix #2 — rime.dll distribution in install-librime-fork.ps1

**Problem discovered 2026-05-07:** `install-librime-fork.ps1` tries to
install `gh` CLI and `7-Zip` via winget as prereqs (to download + extract
the CI artifact). The winget installs either hang silently or block in
non-interactive contexts, making the script unreliable for dogfood users.

**Recommended fix: ship `rime.dll` directly in the repo.**

The patched DLL is 2786 KB (~2.7 MB). It's built from a BSD-3 licensed
source — fine to distribute. Add it to `vendor/windows/rime.dll`.

Extraction recipe (run this once on a Mac with th-dc access):
```bash
# The CI artifact is at: smoodle-type/librime run 25429514636
# artifact-Windows-msvc-x64 contains rime-69fc239-Windows-msvc-x64.7z
# which contains dist/lib/rime.dll

gh run download 25429514636 -R smoodle-type/librime \
  -n artifact-Windows-msvc-x64 -D /tmp/rime-artifact/
# Then on th-dc (has 7z):
scp /tmp/rime-artifact/rime-*.7z th-dc:/tmp/
ssh th-dc '7z e /tmp/rime-*.7z dist/lib/rime.dll -o/tmp/rime-extracted/ -y'
scp th-dc:/tmp/rime-extracted/rime.dll vendor/windows/rime.dll
```

Then rewrite `install-librime-fork.ps1` to:
1. Check if `\\host.lan\Data\vendor\windows\rime.dll` exists in the share
   (for dogfood iteration) — if yes, use that
2. Otherwise look for `$ScriptDir\..\vendor\windows\rime.dll` (for git clone
   installs where the file is in the repo)
3. Fall back to the gh+7zip CI download path (keep it, just not the primary
   path)

This means dogfood users who `git clone` the repo get the DLL immediately
with no network fetch during install. CI download is the "always latest"
fallback for developers.

## Hardening fix #3 — README note on WeaselDeployer

**Problem discovered 2026-05-07:** `WeaselDeployer.exe /deploy` is a GUI
app that:
- Silently fails or produces no output when started from a headless context
- Sometimes times out before the large Thai dict finishes compiling

**Fix:** add a note to the output of `install-windows.ps1` that explicitly
tells the user what to do if they see the "timed out" warning:

```
  [WARN] Auto-deploy failed or timed out after 60s.
    This is normal on first install (Thai dict is large).
    Manual fix: look for the Weasel icon in your taskbar.
    If missing: Start > Weasel Server > open it.
    Then: right-click the Weasel tray icon > Deploy.
    Wait for the "Under maintenance" notification to clear (~30s).
```

Also: add the Weasel tray note to `docs/LANE-B-WINDOWS.md` as a known
limitation. Link to the README for end users.

## PowerShell 5.1 encoding rules (do not regress)

The worst bug in this session: em-dashes and non-ASCII chars in `.ps1`
files cause parse errors on Windows PowerShell 5.1, because PS5.1 reads
scripts as Windows-1252 by default and the UTF-8 em-dash (E2 80 **94**)
contains byte 0x94 = `"` (smart double-quote) which closes strings
unexpectedly.

**Rule: all `.ps1` files must be pure ASCII.** Before committing any .ps1
change, run:
```bash
python3 -c "
for f in ['scripts/install-windows.ps1', 'scripts/install-librime-fork.ps1']:
    with open(f,'rb') as x: data = x.read()
    bad = [(i+1, b) for i,b in enumerate(data) if b > 127]
    print(f'{f}: {len(bad)} non-ASCII bytes' if bad else f'{f}: clean')
"
```

Replacements already applied:
- `—` → ` - ` (em dash → space-hyphen-space)
- `สวัสดี` → `sawatdee`

Do not re-introduce Thai script or typographic punctuation in .ps1 files.

## Verification criteria

**Done when:**
- `install-windows.ps1` on a fresh Weasel VM (schemas NOT previously
  deployed) runs end-to-end without the timestamp workaround, and
  `thai_phonetic.table.bin` appears in build dir within 60s.
- `install-librime-fork.ps1` finds `vendor/windows/rime.dll` in the repo,
  swaps it without gh/7-zip, and the DLL size is ~2786 KB after swap.
- `tests/test_installers.py` passes 43+ tests with updated assertions.
- README/LANE-B-WINDOWS.md has the WeaselDeployer manual fallback note.
- Smoke on the th-dc VM: fresh `install-windows.ps1` + `install-librime-fork.ps1`
  → `sawatdee → สวัสดี` candidate without manual workarounds.

Estimated: ~3 hrs focused work.

## Useful SSH one-liners for this session

```bash
# Run a script on the Windows VM
ssh -F /tmp/smoodle-win-ssh.conf smoodle-win \
  'cmd /c "powershell -ExecutionPolicy Bypass -File \\host.lan\Data\scripts\SCRIPT.ps1 2>&1"'

# Run raw PowerShell
ssh -F /tmp/smoodle-win-ssh.conf smoodle-win \
  'cmd /c "powershell -Command \"<command>\" 2>&1"'

# Check file exists
ssh -F /tmp/smoodle-win-ssh.conf smoodle-win \
  'cmd /c "dir C:\Users\smoodle\AppData\Roaming\Rime\build\thai_phonetic.table.bin 2>&1"'

# Rsync latest scripts to th-dc
./scripts/dev-sync-windows.sh
```

## Not in scope for this session

- Lane C Linux installer GHA E2E (see TODO 8)
- install-librime-fork.ps1 PowerShell shape tests for the vendored DLL path
  (add once the vendor path is landed)
- Upstream librime PR (TODO 1, DEFERRED)
- Windows MSI packaging (pre-public-ship gate)
- Weasel auto-update overwrite protection (Phase 1.5)
