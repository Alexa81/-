# MOONAR Curve Lab v0.8.2-preview — the NEW synthesizer

This experimental synth is **separate from** the original red MOONAR 0.7.14, which is preserved on `main` and in branch `moonar-v0.7.14-preserved`.

## Interface
The new single **midnight violet** Lua-gfx interface was built to match the agreed visual direction, not the old red MOONAR shell. Both envelopes appear simultaneously:

- **AMP ENVELOPE** (left): volume ADSR, edit stage points and bend handles. Separate A, D, S, R knobs.
- **MOOG-STYLE FILTER** (middle): a four-pole resonant lowpass approximation with Cutoff, Resonance, Drive and Envelope Amount; Filter On/Off.
- **FILTER ENVELOPE** (right): separate per-voice filter ADSR, stage and bend handles, plus A, D, S, R knobs.
- **SOURCE SAMPLE** waveform at the top with native Finder drag/drop, LOAD SAMPLE, trimming and zoom.
- **PRESETS**, **MORE**, and **UPDATE** at top right.
- **TRANSPOSE**, **FINE DETUNE**, **OUTPUT**, MONO/POLY and TEST NOTE in the bottom section.

The original 26 DSP sliders retain their indices; 13 new parameters (27–39) stay separate. The 39 JSFX sliders are hidden from the host's ordinary display, while REAPER and the Lua controller can still manipulate them.

## Single synth architecture

Exactly one named JSFX engine (`MOONAR_CurveLab_080.jsfx`) handles resynthesis, MIDI, voices and audio. **Only one Lua-gfx window** is displayed; JSFX has no second `@gfx` UI. The Lua window has `gfx.getdropfile(0)` to accept files dragged from Finder.

The JSFX engine is unchanged from 0.8.1 in this 0.8.2 update so an existing Curve Lab track will not need a second audio engine. The filter algorithm is a 4-pole lowpass approximation, not a hardware-identical Moog simulation.

## Installation and updating

1. **Save your REAPER project.**
2. If Curve Lab 0.8.1 is already installed, click **UPDATE** in its upper toolbar. The independent update manifest `moonar/curve-lab/latest.txt` now points to 0.8.2-preview.
3. For a new installation, download [MOONAR_CURVELAB_INSTALL.lua](MOONAR_CURVELAB_INSTALL.lua) using **Raw**. In REAPER open **Actions → Show action list → New action → Load ReaScript** and run the installer.
4. Drag a WAV/AIFF/FLAC from Finder into the **MOONAR CURVE LAB** Lua window (not into REAPER FX Chain), or use **LOAD SAMPLE**.
5. Use the new simultaneous AMP/FILTER panels; use **PRESETS** to manage your sounds and **MORE** for the original secondary synthesis parameters.

## Isolation / rollback

- Original MOONAR 0.7.14 source unchanged.
- Original `moonar/latest.txt` still points to 0.7.14.
- Curve Lab has its own controller, FX, memory bridge, preset bank and update channel.
- The original saved presets and old release remain available.

**Test status:** Changes are committed to GitHub and release paths/structure checked. REAPER/macOS runtime behavior, audio sound quality, gesture responsiveness and file drop must be tested by running on your Mac; do not treat this preview as production-tested.

## Source

- [v0.8.2-preview Lua window](v0.8.2-preview/MOONAR_CURVELAB_LIVE.lua)
- [v0.8.2-preview JSFX audio engine](v0.8.2-preview/MOONAR_CurveLab_080.jsfx)
- [Installer](MOONAR_CURVELAB_INSTALL.lua)
- [Independent updater](MOONAR_CURVELAB_UPDATE.lua)
