# MOONAR Curve Lab — v0.8.0-preview

**Experimental insert GUI for REAPER**, built as an isolated companion to MOONAR Resynth 0.7.14.

## Preservation

- Original 0.7.14 remains unchanged: [original version](../../releases/v0.7.14).
- Archived repository branch: `moonar-v0.7.14-preserved`.
- Main `moonar/latest.txt` still selects 0.7.14.
- Curve Lab uses its own JSFX filename, Lua filename, gmem bus, preset directory and update manifest.
- When launched with an original MOONAR track selected, the controller creates/chooses a **separate Curve Lab instrument track**, never removing the original.
- Filter is **OFF** by default so the unfiltered engine can be compared to the original.

## Features

- The original 26 JSFX parameters remain in their original sequence and with their original definitions.
- Original PCM engine, optional spectral sustain, MIDI, per-voice AMP ADSR, fine tuning, organic motion, residual noise, glide/legato and MIDI polyphony.
- Separate 4-pole resonant Moog-style **approximation** (not an emulation of proprietary Moog circuitry), with cutoff, resonance and drive.
- Independent per-voice filter ADSR, envelope amount and distinct attack/decay/release curve shapes.
- Filter envelope independently retriggers on MIDI note-on and releases on MIDI note-off; volume ADSR remains separate.
- One instrument FX insert per Curve Lab track, with GUI drawn inside JSFX.
- Own preset bank, saving an independent 32-bit float WAV copy and **39** settings; explicit import of prior MOONAR presets makes copies rather than modifying them.
- **UPDATE** button in the insert GUI checks `moonar/curve-lab/latest.txt`, uses checksum validation, backups and separate scripts. It never changes the normal MOONAR update channel.

## Install and test on macOS / REAPER 7

1. Download [MOONAR_CURVELAB_INSTALL.lua](../MOONAR_CURVELAB_INSTALL.lua) from GitHub using the **Raw** link.
2. In REAPER: **Actions → Show action list → ReaScript: Load** (or the **New action → Load ReaScript** control). Select the downloaded installer.
3. Run **MOONAR_CURVELAB_INSTALL.lua** once. It uses HTTPS and `shasum -a 256` on macOS to verify the independent JSFX, controller and updater.
4. The installer registers/launches `MOONAR_CURVELAB_LIVE.lua`. If required, select a blank track and launch that ReaScript from Actions.
5. In the Curve Lab insert, click **LOAD SAMPLE**. Use **ON** to enable the Moog-style filter and edit the green Filter ADSR independently of purple Volume ADSR.
6. Click **PRESETS** to save, load, rename, delete or import *copies* of old MOONAR presets.
7. Click **UPDATE** in this new insert, never the original MOONAR, to check for updates on the experimental channel.

If the insert shows **RUN LAB LUA CONTROLLER**, run `MOONAR_CURVELAB_LIVE.lua` from the REAPER Actions list. The controller handles file dialogs and on-disk presets; the insert handles real-time DSP and graphics.

## Known limitations / test status

This is a **preview**. Source files were checked for structural invariants and verified on GitHub, but **could not be compiled or auditioned in a live REAPER/macOS session from this environment**. Report any JSFX compiler message, missing sound or UI/ADSR behavior before relying on it in production.

For safety, back up your REAPER project before enabling new DSP or importing presets. **Do not point the original MOONAR auto-updater to this experimental channel.**

## Source

- [JSFX insert + DSP](v0.8.0-preview/MOONAR_CurveLab_080.jsfx)
- [Lua headless controller](v0.8.0-preview/MOONAR_CURVELAB_LIVE.lua)
- [Updater](MOONAR_CURVELAB_UPDATE.lua)
- [Update manifest](latest.txt)
