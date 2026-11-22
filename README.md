# MOONAR RESYNTH — GitHub update channel

Public files for the REAPER/macOS MOONAR RESYNTH prototype.

**Current LIVE UI:** v0.7.3. **DSP:** JSFX v0.6.1 (not updated by the GitHub updater).

## One-time setup

Open macOS Terminal and paste:

```sh
mkdir -p "$HOME/Library/Application Support/REAPER/Scripts" && curl -fsSL "https://raw.githubusercontent.com/Alexa81/-/main/moonar/MOONAR_UPDATE.lua" -o "$HOME/Library/Application Support/REAPER/Scripts/MOONAR_UPDATE.lua"
```

Keep REAPER running. In REAPER choose **Actions → Show action list → Load ReaScript**, select `MOONAR_UPDATE.lua` from your REAPER Scripts folder, then **Run**.

The updater checks [latest.txt](moonar/latest.txt), downloads [the newest UI](moonar/releases/v0.7.3/MOONAR_RESYNTH_LIVE.lua), checks its SHA-256 digest, saves a backup of the currently installed UI, and replaces the controller. The open MOONAR LIVE GUI watches its Lua file and will restart the GUI when the file changes. Once updated to v0.7.3, click **UPDATE** inside the plugin for future releases.

**Safety:** This updater deliberately does not change FX/JSFX DSP, synth audio state or user presets. It rejects downgrades, invalid manifests, and hash mismatches. No app signing is supplied. The REAPER/macOS integration has not yet been tested on the user's actual Mac. If a sound is missing, use the separate troubleshooting steps rather than assuming the UI update resolves DSP problems.

## Files

- [latest.txt](moonar/latest.txt) — versioned manifest and checksum
- [MOONAR_UPDATE.lua](moonar/MOONAR_UPDATE.lua) — ReaScript updater
- [MOONAR_RESYNTH_LIVE.lua v0.7.3](moonar/releases/v0.7.3/MOONAR_RESYNTH_LIVE.lua) — companion UI

The instrument is an independent prototype, not Tim Hox's proprietary RESYNTH source code.
