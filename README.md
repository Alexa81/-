# MOONAR RESYNTH — GitHub updates and whole-plugin repair

MOONAR RESYNTH is a REAPER/macOS Lua UI plus a separate JSFX instrument engine.

**Latest release: MOONAR 0.7.10** (interface) + **JSFX 0.6.4 Natural Sustain** (audio engine unchanged).

## UPDATE button

Select the target track in REAPER, open the MOONAR LIVE interface, and click **UPDATE**.

- Existing 0.7.7 updater sees 0.7.8 and installs the new controller and JSFX engine, without closing REAPER.
- The 0.7.8 controller automatically installs its bundled **MOONAR UPDATE 1.4** script locally on startup, making future updates and repairs one-click.
- Starting with updater 1.4, pressing UPDATE verifies **both** the Lua UI and the JSFX engine against `latest.txt` SHA-256 checksums, including when the UI is already the latest version.
- Missing or corrupted components are downloaded and repaired, each with a backup of the previous file.
- On the selected track, the updater looks for the latest compatible JSFX. If only a legacy MOONAR is attached, it attempts to add the new engine. It preserves the previous FX and does not delete presets.
- After a repair, the updater reopens MOONAR LIVE on the selected track; REAPER itself stays open.

The separate JSFX instrument needs sample audio plus MIDI notes to make sound. Updating the files alone does **not** prove audio output is functioning.

## Source links

- [Current manifest](moonar/latest.txt)
- [Whole-plugin UPDATE 1.4](moonar/MOONAR_UPDATE.lua)
- [MOONAR LIVE 0.7.10](moonar/releases/v0.7.10/MOONAR_RESYNTH_LIVE.lua)
- [JSFX 0.6.4](moonar/releases/v0.7.10/MOONAR_Resynth_064.jsfx)
- [macOS auto-check setup](moonar/MOONAR_GITHUB_SETUP.sh)
- [Background checker](moonar/MOONAR_AUTOUPDATE.sh)

## Infinite Sustain / holding a note

Starting in 0.7.7, **HOLD NOTE / C5** in the Lua window sends a MIDI note-on that remains active indefinitely. The button switches to **RELEASE NOTE / C5**; pressing it sends MIDI note-off and begins the configured ADSR Release (up to 32 seconds). Closing MOONAR LIVE releases the test note for safety. Notes played from REAPER MIDI items or MIDI keyboards follow the same held-note ADSR semantics.

The recorded PCM plays first for natural attack; the JSFX 0.6.3 spectral engine overlaps into a sustained tone earlier, over a longer crossfade window, and keeps oscillators running after the source sample ends. The quality of an individual sample transition depends on that sample's body and spectrum; end-to-end real-time audio on the user's Mac is not yet validated.


## Natural Sustain and working fades (0.7.8)

The **NATURAL** mode (default) keeps the imported PCM attack and continues the recorded sample by looping a selected body segment with an adjustable crossfade. This avoids the metallic partial-tone character of static spectral synthesis, but a short or highly changing sound can still exhibit audible loop repetition. The **SPECTRAL** mode remains accessible for comparison.

**Fade In** (top amber handle) ramps the recorded PCM in at the start of a MIDI note. **LOOP FADE** (bottom amber handle or the named button) controls the crossfade between the loop end and start while a note remains held. This is not a fade to silence during sustain; a note ends only after MIDI Note Off and the ADSR **Release**.

The ADSR drawing shows a dedicated Sustain handle where the horizontal segment meets Release. Drag it vertically to change Sustain independently of Decay and Release time. Sustain height and the Sustain knob use a dB-scaled display; the audio engine still converts that dB value to linear gain. Legacy 22-parameter presets remain loadable and new presets can save 23 parameters, including the Natural/Spectral choice.

When switching sound engines on the selected REAPER track, previous MOONAR FX instances are preserved but bypassed after the imported sample has been passed to the newest engine. This avoids accidentally layering an older metallic-sounding engine with the new natural loop.

**Audio quality caveat:** source compatibility and hashes have been checked. Sample-specific looping and end-to-end audio playback must still be validated within REAPER on macOS. The presence of the 0.7.8 version number alone does not verify sound quality.

## ADSR plot and gain preview (0.7.9)

The upper panel is the original source waveform. The lower ADSR panel now renders an **ADSR-gain-modulated illustrative waveform preview**, rather than showing a full-strength raw sample behind an envelope indicating silence.

The GUI uses a **nonlinear per-stage horizontal scale**, so short attacks remain visible and a full 32-second Decay does not look like an arbitrarily short slice of the original 0.5-second WAV. The lower panel is a control/shape preview, **not a literal 32-second audio render or sample-length timeline**. For real measured audio, use REAPER rendering/meters.

The lower preview's vertical level is the **actual linear-amplitude gain** computed from the Sustain parameter in decibels: 0 dB corresponds to a gain of 1, -48 dB to roughly 0.004. The preview shows a linear-amplitude attack and decay plus an exponential Release, following the JSFX envelope law. The Sustain/Note Off handle is separate; Release begins at the Sustain level. A zero-millisecond Release is a vertical drop; a longer Release moves its end to the right.

The UI now uses the inverse of the same nonlinear stage-time mapping for dragging Attack, Decay and Release handles. **This release does not change the 0.6.4 audio DSP**, preserving the recorded Natural Sustain sound and existing presets.

## Paired DECAY control nodes (0.7.10)

In the custom MOONAR LIVE ADSR panel, the DECAY position now has **two linked amber control points**, one at the top of a vertical guide and one at the bottom. Turning DECAY moves **both points left or right together**. Dragging either point or the guide horizontally adjusts only the DECAY time (0–32 seconds).

SUSTAIN is a separate gain-level control. Dragging the DECAY guides does not adjust SUSTAIN. Dragging the Sustain/Note Off node still controls its vertical level, while the Release endpoint separately controls release time.

The two DECAY dots are **time-position guides**, not two separate ADSR stages. The gain curve remains the actual ADSR attack-decay-sustain-release envelope. This version changes the custom Lua GUI only; the JSFX 0.6.4 audio engine and user presets are unchanged.

## Troubleshooting

If UPDATE reports **Already current, 0.7.9**, GitHub still advertises the same version or a cached updater/manifest is in use. Verify the [current manifest](moonar/latest.txt) and rerun UPDATE.

If UPDATE reports **MOONAR 0.7.10 fully up to date**, both installed files passed checksums. This does not automatically prove that the active REAPER FX is audible. Reopen MOONAR LIVE on the selected track, verify `MOONAR Resynth 0.6.4 Natural Sustain` is enabled in its FX chain, import a sample, and send MIDI.

Do not delete older JSFX instances or user presets during troubleshooting.

**Testing:** GitHub file contents and checksums have been verified. End-to-end audio output, local macOS permissions, and REAPER FX refresh behavior have not been tested on the user's computer. The release should be treated as a tested-publication but not a confirmed working audio build.

## If the old UPDATE button does nothing

On macOS, run this one-time verified repair from Terminal:

```sh
curl -fsSL "https://raw.githubusercontent.com/Alexa81/-/main/moonar/MOONAR_REPAIR_ONCE.sh" -o /tmp/MOONAR_REPAIR_ONCE.sh && /bin/bash /tmp/MOONAR_REPAIR_ONCE.sh
```

The [repair script](moonar/MOONAR_REPAIR_ONCE.sh) checks for REAPER's standard resource directory, downloads the current Lua UI, JSFX and updater, verifies each SHA-256 digest against [latest.txt](moonar/latest.txt), and installs them with backups. It does not delete presets, FX chains, or older engines. It prints success or a specific error rather than silently quitting. This repair is a one-time escape hatch when the local UPDATE script itself is stale. After it runs, open `MOONAR_RESYNTH_LIVE.lua` from REAPER Actions on the selected track.
