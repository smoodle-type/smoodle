# Smoodle Install

## macOS (recommended for v0.0.8a+)

### Drag-install

1. Download the latest `Smoodle-v*.dmg` from
   [GitHub Releases](https://github.com/smoodle-type/smoodle-app/releases/latest).
2. Open the DMG. Drag `Smoodle.app` onto the **Input Methods** folder
   shortcut. (You may be asked for your password — that's macOS
   authorizing the install into `/Library/Input Methods`.)
   Also drag `Smoodle Config.app` onto the **Applications** shortcut — it
   is the settings window for custom words and the candidate count.
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

Smoodle.app v0.0.8b.1 and later check for updates daily in the background
via Sparkle. When a new version is available, you'll see a small dialog
asking whether to install. You can also check manually via the menubar S
icon → **Check for updates...**

v0.0.8a, v0.0.8a.1 and v0.0.8b cannot update themselves (Sparkle was not
wired in). Download the latest DMG once and drag-install it; updates work
from then on.

Smoodle Config.app is not updated by Sparkle — drag the copy from each new
DMG onto **Applications**.

### Where Smoodle keeps your data

Smoodle.app runs its own Rime setup, separate from Squirrel:

- `/Library/Input Methods/Smoodle.app/Contents/SharedSupport/` — schema,
  dictionary and default settings shipped with the app (replaced on update).
- `~/Library/Rime/Smoodle/` — your custom words
  (`thai_phonetic.user.dict.yaml`), your settings (`default.custom.yaml`,
  once you change one) and the words Smoodle learns from your typing.
  A file here takes precedence over the bundled file of the same name.

`~/Library/Rime/` itself belongs to Squirrel (the v0.0.6 install path);
Smoodle.app does not read it.

### Custom words

Open the menubar S icon → **Open Smoodle Config…** → **Words**. Add the Thai
word, the romanization you want to type, and a weight (100 is normal, 1000 is
very common). With **Deploy on save** checked, the word is usable as soon as
the toast says "deployed". Needs v0.0.8b.3 or later — earlier builds never
loaded custom words.

To edit by hand instead, open `~/Library/Rime/Smoodle/thai_phonetic.user.dict.yaml`
(Config creates it; you can also create it with the header below), add one
line per word, then menubar S → **Deploy**:

```yaml
# Rime user dictionary
---
name: thai_phonetic.user
version: "1"
sort: by_weight
...
ลีเอ็กซ์	lex	100
```

Format is `<thai>\t<romanization>\t<weight>` (tabs, not spaces). Smoodle
Config rewrites this file on every change and drops comments you add.

### Uninstall

1. Quit Smoodle.app (menubar S icon → Quit).
2. System Settings → Keyboard → Input Sources → select Smoodle → "−".
3. `sudo rm -rf /Library/Input\ Methods/Smoodle.app`
4. `rm -rf "/Applications/Smoodle Config.app"` if you installed it.
5. Optional: `rm -rf ~/Library/Rime/Smoodle` — removes your custom words,
   settings and learned history.
6. Optional: delete `~/.smoodle/` (telemetry opt-in state + bearer
   token cache).

## Windows (legacy install script — v0.0.7 path)

See `scripts/install-windows.ps1`. v0.0.8 is macOS-only; Windows
finish is queued in v0.0.7 W1.

## Linux (legacy install script — v0.0.7 path)

See `scripts/install-linux.sh`. v0.0.8 is macOS-only.
