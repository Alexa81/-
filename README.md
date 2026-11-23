# MOONAR RESYNTH — automatic GitHub updates

Public source code for the REAPER/macOS MOONAR RESYNTH prototype.

**Published Lua UI:** v0.7.5. **DSP:** JSFX 0.6.2 is bundled with the new Lua controller and installed when the new UI starts.

## Automatic updates — one-time setup

Open macOS Terminal and run this one-time setup command:

```sh
curl -fsSL "https://raw.githubusercontent.com/Alexa81/-/main/moonar/MOONAR_GITHUB_SETUP.sh" | /bin/bash
```

This installs a per-user macOS LaunchAgent that checks GitHub **about every 15 minutes**, even if REAPER is closed. It does not require downloading a ZIP, manually copying Lua files, or quitting REAPER. It fetches the newest controller and verifies the SHA-256 checksum from [latest.txt](moonar/latest.txt), backs up your previous controller, then atomically installs the new Lua file in the REAPER Scripts directory. The existing live interface detects on-disk updates and restarts its own Lua GUI if already running. The updater is initially launched by macOS at installation.

The background updater replaces only the Lua controller. Upon startup, MOONAR v0.7.5 installs a separately named JSFX 0.6.2 beside the old 0.6.1 engine, preserving previous files and user presets. The EEL2 parser error at line 467 was addressed in source; audio playback on a real Mac has not yet been verified.

Files:
- [moonar/latest.txt](moonar/latest.txt) — current version and expected SHA-256
- [moonar/MOONAR_GITHUB_SETUP.sh](moonar/MOONAR_GITHUB_SETUP.sh) — one-time macOS installation
- [moonar/MOONAR_AUTOUPDATE.sh](moonar/MOONAR_AUTOUPDATE.sh) — background update checker
- [moonar/MOONAR_UPDATE.lua](moonar/MOONAR_UPDATE.lua) — manual Update action and GUI button
- [v0.7.5 Lua interface](moonar/releases/v0.7.5/MOONAR_RESYNTH_LIVE.lua)

To check the update log after installing, open:
`~/Library/Application Support/REAPER/MOONAR_RESYNTH/autoupdate.log`

To disable the background updater on macOS, remove the corresponding LaunchAgent after booting it out:
`launchctl bootout gui/$(id -u)/com.moonar.resynth.autoupdate`.

**Testing status:** Lua syntax parsing and release checksums passed; GitHub files were verified. A running REAPER audio test has not yet been completed on the user's Mac.

The instrument is an independent prototype, not Tim Hox's proprietary RESYNTH source code.
