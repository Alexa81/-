# MOONAR RESYNTH for REAPER / macOS

**Current published version: MOONAR RESYNTH 0.7.14** (Lua controller) with
**JSFX 0.6.6 Curved ADSR** (unchanged since 0.7.13).

This is an original, experimental REAPER Lua + JSFX sampler/resynth instrument.

## Install / UPDATE

Select the REAPER track on which you want MOONAR to run, open the MOONAR LIVE
window, and click **UPDATE**. The updater checks the SHA-256 integrity of the
Lua controller and JSFX and restores missing or damaged components. It may
reopen the controller window on the selected track.

- [Current GitHub release manifest](moonar/latest.txt)
- [MOONAR RESYNTH 0.7.14 controller](moonar/releases/v0.7.14/MOONAR_RESYNTH_LIVE.lua)
- [MOONAR Resynth 0.6.6 JSFX engine](moonar/releases/v0.7.14/MOONAR_Resynth_066.jsfx)
- [Whole-plugin repair updater](moonar/MOONAR_UPDATE.lua)
- [One-time macOS updater recovery script](moonar/MOONAR_REPAIR_ONCE.sh)

If an old or unregistered in-plugin UPDATE button does nothing, run the
one-time recovery script from a Terminal on the Mac:

```sh
curl -fsSL "https://raw.githubusercontent.com/Alexa81/-/main/moonar/MOONAR_REPAIR_ONCE.sh" -o /tmp/MOONAR_REPAIR_ONCE.sh && /bin/bash /tmp/MOONAR_REPAIR_ONCE.sh
```

This backs up replaced plugin files and checks downloaded checksums. It does
not require reinstalling REAPER or deleting sound presets.

## Four-stage ADSR and curve handles

- **Attack, Decay, Sustain, Release:** four main ADSR stages, no HOLD.
- **Attack, Decay, Release curve handles:** three small cyan mid-segment dots
  allow bending each curve separately, affecting actual JSFX audio gain rather
  than merely changing the GUI drawing.
- **Sustain:** remains a level in dB and is not redefined by the other changes.
- **Release:** begins on MIDI Note Off and fades out from the note's actual
  level, including if the note was released during Attack or Decay.
- **Time ranges:** Attack, Decay, Release each range from 0 ms to 32 s.

The envelope graph uses a shared time axis and illustrates Note Off at
the Decay/Sustain boundary. In real playback, Sustain can last indefinitely
while the MIDI note is held.

## Extended waveform preview (0.7.14)

The lower ADSR waveform now shows the sample evolving for the **entire visible
Decay and Release time**, including when the imported WAV is shorter than
the programmed envelope. The preview is generated from the actual imported
PCM samples: first the original attack is played, then the Natural Loop mode's
stable sample body is replayed with a crossfade, extending the waveform rather
than horizontally stretching a static image.

The graphics follow the same Natural Loop boundaries (20–65% of the selected
region) and fade control as the JSFX engine. They are a **visual approximation**
of the resulting audio at the root pitch, not a rendered audio export.
The original upper source waveform is preserved.

**Important:** this is natural PCM looping/crossfading, **not a full
pitch-preserving WSOLA or phase-vocoder time-stretch algorithm**. It preserves
the original sample material but may reveal repetitions or tonal changes on
very short or noisy sources; it cannot reconstruct recorded details that do
not exist in the WAV.

## Natural and spectral modes

The default **NATURAL** mode loops the sample body while a note remains held
and during its ADSR Release; the **SPECTRAL** mode remains an alternative.
The audio engine already supported indefinite held-note playback before
0.7.14, and is not modified in this release. The new release fixes the
waveform preview's correspondence to the actual audio duration.

## Verification and limitations

Release source and integrity hashes have been checked. Audio playback,
click-free looping on individual sources, GUI rendering and hardware I/O
routing are **not yet verified on the user's REAPER/macOS system**. Always
save a backup of the REAPER project before using an experimental release.
