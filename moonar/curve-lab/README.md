# MOONAR Curve Lab v0.8.1-preview — single-window Drag & Drop fix

This experimental version restores the **one visible Lua instrument interface** with native drag-and-drop from Finder and the built-in file picker. Its **one JSFX DSP engine** runs invisibly in the track FX chain. All 39 native JSFX parameter sliders are hidden (but still available to the DSP and host automation). It is **not** a VST3 plug-in.

## Changes from 0.8.0

- Restored REAPER Lua `gfx.getdropfile(0)` in the real MOONAR window; drop WAV/AIFF/FLAC onto the window.
- Removed the second graphical JSFX interface. Only the Lua gfx window is shown when the script runs.
- Prefixed the names of all 39 JSFX sliders with `-`, the documented REAPER hidden parameter syntax.
- Added an independent **FILTER** tab (Moog-style low-pass cutoff, resonance, drive, envelope depth, editable Filter ADSR and bend handles). The **AMP** tab preserves the existing MOONAR volume ADSR and audio rendering.
- Original 26 parameters, resynthesis engine, MIDI support, loop, spectral mode, pitch, saved presets, and waveform trim from v0.7.14 remain.
- **UPDATE** in the Lua window uses the separate Curve Lab manifest at [latest.txt](latest.txt).
- This is a 4-pole lowpass approximation; it does not claim to be the proprietary Moog circuit.

## Install the preview

1. Save your REAPER project first.
2. Download [MOONAR_CURVELAB_INSTALL.lua](MOONAR_CURVELAB_INSTALL.lua) using GitHub **Raw**.
3. In REAPER use **Actions → Show action list → New action → Load ReaScript** and select the installer. Run it once.
4. The installer fetches and checksum-verifies both Curve Lab files, installs the JSFX under Effects and the Lua script under Scripts, then launches the one visible GUI. If it does not open, run `MOONAR_CURVELAB_LIVE.lua` from the Actions list.
5. Drag an audio file from Finder into the **MOONAR CURVE LAB 0.8.1** window, or click **LOAD SAMPLE**. Do **not** drop onto the headless JSFX FX-chain window.
6. Click **FILTER** for the Moog-style filter and its own ADSR. Click **AMP** for the volume ADSR. Use **UPDATE** on the upper toolbar for future Curve Lab versions.

## Isolation and rollback

- Original [MOONAR 0.7.14](../releases/v0.7.14) has **not been modified**.
- An archived copy of the original release is on branch `moonar-v0.7.14-preserved`.
- Original `moonar/latest.txt` still points to 0.7.14.
- Curve Lab has its own FX name, script, update manifest, global-memory bus and preset folder.
- Curve Lab's old presets remain in its independent directory. The installer does not delete preset files.

**Testing status:** Code and release paths have been inspected; the GUI and DSP have **not been run on the user's macOS/REAPER**, so real-time drag/drop, JSFX compilation and audio output still require hands-on testing. If a problem persists, send the first REAPER console/compiler error.

## Source files

- [Lua single-window UI](v0.8.1-preview/MOONAR_CURVELAB_LIVE.lua)
- [Headless JSFX DSP](v0.8.1-preview/MOONAR_CurveLab_080.jsfx)
- [Independent updater](MOONAR_CURVELAB_UPDATE.lua)
