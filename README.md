# MOONAR RESYNTH — GitHub updates and whole-plugin repair

MOONAR RESYNTH is a REAPER/macOS Lua UI plus a separate JSFX instrument engine.

**Latest release: MOONAR 0.7.7** (interface) + **JSFX 0.6.3 Infinite Sustain** (audio engine).

## UPDATE button

Select the target track in REAPER, open the MOONAR LIVE interface, and click **UPDATE**.

- Existing 0.7.6 updater sees 0.7.7 and installs the new controller and JSFX engine, without closing REAPER.
- The 0.7.7 controller automatically installs its bundled **MOONAR UPDATE 1.4** script locally on startup, making future updates and repairs one-click.
- Starting with updater 1.4, pressing UPDATE verifies **both** the Lua UI and the JSFX engine against `latest.txt` SHA-256 checksums, including when the UI is already the latest version.
- Missing or corrupted components are downloaded and repaired, each with a backup of the previous file.
- On the selected track, the updater looks for the latest compatible JSFX. If only a legacy MOONAR is attached, it attempts to add the new engine. It preserves the previous FX and does not delete presets.
- After a repair, the updater reopens MOONAR LIVE on the selected track; REAPER itself stays open.

The separate JSFX instrument needs sample audio plus MIDI notes to make sound. Updating the files alone does **not** prove audio output is functioning.

## Source links

- [Current manifest](moonar/latest.txt)
- [Whole-plugin UPDATE 1.4](moonar/MOONAR_UPDATE.lua)
- [MOONAR LIVE 0.7.7](moonar/releases/v0.7.7/MOONAR_RESYNTH_LIVE.lua)
- [JSFX 0.6.3](moonar/releases/v0.7.7/MOONAR_Resynth_063.jsfx)
- [macOS auto-check setup](moonar/MOONAR_GITHUB_SETUP.sh)
- [Background checker](moonar/MOONAR_AUTOUPDATE.sh)

## Infinite Sustain / holding a note

Starting in 0.7.7, **HOLD NOTE / C5** in the Lua window sends a MIDI note-on that remains active indefinitely. The button switches to **RELEASE NOTE / C5**; pressing it sends MIDI note-off and begins the configured ADSR Release (up to 32 seconds). Closing MOONAR LIVE releases the test note for safety. Notes played from REAPER MIDI items or MIDI keyboards follow the same held-note ADSR semantics.

The recorded PCM plays first for natural attack; the JSFX 0.6.3 spectral engine overlaps into a sustained tone earlier, over a longer crossfade window, and keeps oscillators running after the source sample ends. The quality of an individual sample transition depends on that sample's body and spectrum; end-to-end real-time audio on the user's Mac is not yet validated.

## Troubleshooting

If UPDATE reports **Already current, 0.7.6**, GitHub still advertises the same version or a cached updater/manifest is in use. Verify the [current manifest](moonar/latest.txt) and rerun UPDATE.

If UPDATE reports **MOONAR 0.7.7 fully up to date**, both installed files passed checksums. This does not automatically prove that the active REAPER FX is audible. Reopen MOONAR LIVE on the selected track, verify `MOONAR Resynth 0.6.3 Infinite Sustain` is enabled in its FX chain, import a sample, and send MIDI.

Do not delete older JSFX instances or user presets during troubleshooting.

**Testing:** GitHub file contents and checksums have been verified. End-to-end audio output, local macOS permissions, and REAPER FX refresh behavior have not been tested on the user's computer. The release should be treated as a tested-publication but not a confirmed working audio build.

## If the old UPDATE button does nothing

On macOS, run this one-time verified repair from Terminal:

```sh
curl -fsSL "https://raw.githubusercontent.com/Alexa81/-/main/moonar/MOONAR_REPAIR_ONCE.sh" -o /tmp/MOONAR_REPAIR_ONCE.sh && /bin/bash /tmp/MOONAR_REPAIR_ONCE.sh
```

The [repair script](moonar/MOONAR_REPAIR_ONCE.sh) checks for REAPER's standard resource directory, downloads the current Lua UI, JSFX and updater, verifies each SHA-256 digest against [latest.txt](moonar/latest.txt), and installs them with backups. It does not delete presets, FX chains, or older engines. It prints success or a specific error rather than silently quitting. This repair is a one-time escape hatch when the local UPDATE script itself is stale. After it runs, open `MOONAR_RESYNTH_LIVE.lua` from REAPER Actions on the selected track.
