# MOONAR RESYNTH — automatic GitHub updates

Public source code for the REAPER/macOS MOONAR RESYNTH prototype.

**Published Lua UI:** v0.7.3. **DSP:** JSFX v0.6.1 (not updated by the automatic updater).

## Automatic updates — one-time setup

Open macOS Terminal and run this one-time setup command:

```sh
curl -fsSL "https://raw.githubusercontent.com/Alexa81/-/main/moonar/MOONAR_GITHUB_SETUP.sh" | /bin/bash
```

This installs a per-user macOS LaunchAgent that checks GitHub **about every 15 minutes**, even if REAPER is closed. It does not require downloading a ZIP, manually copying Lua files, or quitting REAPER. It fetches the newest controller and verifies the SHA-256 checksum from [latest.txt](moonar/latest.txt), backs up your previous controller, then atomically installs the new Lua file in the REAPER Scripts directory. The existing live interface detects on-disk updates and restarts its own Lua GUI if already running. The updater is initially launched by macOS at installation.

The updater does **not** replace the JSFX audio engine or user preset data, and does not delete projects. The sound-output problem reported in earlier releases is **not** confirmed fixed.

Files:
- [moonar/latest.txt](moonar/latest.txt) — current version and expected SHA-256
- [moonar/MOONAR_GITHUB_SETUP.sh](moonar/MOONAR_GITHUB_SETUP.sh) — one-time macOS installation
- [moonar/MOONAR_AUTOUPDATE.sh](moonar/MOONAR_AUTOUPDATE.sh) — background update checker
- [moonar/MOONAR_UPDATE.lua](moonar/MOONAR_UPDATE.lua) — manual Update action and GUI button
- [v0.7.3 Lua interface](moonar/releases/v0.7.3/MOONAR_RESYNTH_LIVE.lua)

To check the update log after installing, open:
`~/Library/Application Support/REAPER/MOONAR_RESYNTH/autoupdate.log`

To disable the background updater on macOS, remove the corresponding LaunchAgent after booting it out:
`launchctl bootout gui/$(id -u)/com.moonar.resynth.autoupdate`.

**Testing status:** shell syntax was checked and repository files were verified. End-to-end execution in REAPER and a macOS LaunchAgent were not tested on the user's Mac.

The instrument is an independent prototype, not Tim Hox's proprietary RESYNTH source code.
