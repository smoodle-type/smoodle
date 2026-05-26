# Smoodle Install

## macOS (recommended for v0.0.8a+)

### Drag-install

1. Download `Smoodle-v0.0.8a-universal.dmg` from
   [GitHub Releases](https://github.com/smoodle-type/smoodle-app/releases/latest).
2. Open the DMG. Drag `Smoodle.app` onto the **Input Methods** folder
   shortcut. (You may be asked for your password — that's macOS
   authorizing the install into `/Library/Input Methods`.)
3. First launch will be blocked by Gatekeeper ("cannot verify
   developer"). This is expected — smoodle is unsigned for v0.0.8.
   Right-click `Smoodle.app` → **Open** → click **Open** in the dialog.
   You only need to do this once.
4. System Settings → Keyboard → Input Sources → **+** → Thai →
   **Smoodle** → Add.
5. Switch to Smoodle from the menubar input source picker (or
   Ctrl+Space).
6. Open any text field. Type `sawadee`. You should see `สวัสดี` appear
   in the candidate window. Press space to commit.

### Auto-update

Smoodle.app checks for updates daily in the background via Sparkle.
When a new version is available, you'll see a small dialog asking
whether to install. You can also check manually via the menubar S icon
→ **Check for updates...**

### Custom words (v0.0.8a hand-edit workaround)

The graphical config app for adding personal vocabulary arrives in
v0.0.8b (auto-updates via Sparkle when it lands). Until then, you can
hand-edit:

1. Open Finder. Press **⌘⇧G**. Type `~/Library/Rime/` and Enter.
2. If `thai_phonetic.user.dict.yaml` doesn't exist, create it with this
   header in any text editor:

   ```yaml
   # Rime user dictionary
   ---
   name: thai_phonetic.user
   version: "1"
   sort: by_weight
   ...
   ```

3. After the `...` line, add one line per word:

   ```
   ลีเอ็กซ์	lex	100
   ```

   Format is `<thai>\t<romanization>\t<weight>` (tabs, not spaces).
   Weights are log frequencies — 100 is normal, 1000 is very common.

4. Click the menubar S icon → **Deploy**. Your word will be usable in
   ~2 seconds.

### Uninstall

1. Quit Smoodle.app (menubar S icon → Quit).
2. System Settings → Keyboard → Input Sources → select Smoodle → "−".
3. `sudo rm -rf /Library/Input\ Methods/Smoodle.app`
4. Optional: delete `~/Library/Rime/thai_phonetic.{schema,dict}.yaml`
   and `~/Library/Rime/default.custom.yaml` if you don't want the
   schema available even after reinstalling Squirrel.
5. Optional: delete `~/.smoodle/` (telemetry opt-in state + bearer
   token cache).

## Windows (legacy install script — v0.0.7 path)

See `scripts/install-windows.ps1`. v0.0.8 is macOS-only; Windows
finish is queued in v0.0.7 W1.

## Linux (legacy install script — v0.0.7 path)

See `scripts/install-linux.sh`. v0.0.8 is macOS-only.
